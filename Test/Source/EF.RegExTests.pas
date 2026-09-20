{-------------------------------------------------------------------------------
   Copyright 2012-2026 Ethea S.r.l.

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
-------------------------------------------------------------------------------}
unit EF.RegExTests;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TEFRegExTests = class
  public
    // Plain patterns go to StrMatchesEx, not to the regex engine.
    [Test]
    [TestCase('wildcard tail',  'metadata://View/Ordini|metadata://View/*|True', '|')]
    [TestCase('wildcard miss',  'metadata://View/Ordini|metadata://Model/*|False', '|')]
    [TestCase('exact match',    'kx/view/Ordini|kx/view/Ordini|True', '|')]
    procedure StrMatchesPatternOrRegex_WithPlainPattern(
      const AString, APattern: string; const AExpected: Boolean);

    [Test]
    [TestCase('prefix',       'kx/view/Ordini|REGEX:^kx/view/Ord.*|True', '|')]
    [TestCase('prefix miss',  'kx/view/Clienti|REGEX:^kx/view/Ord.*|False', '|')]
    [TestCase('char classes', 'ABC123|REGEX:^[A-Z]{3}\d{3}$|True', '|')]
    // These two use ';' because the pattern itself contains the '|' alternation
    // operator, which would otherwise be read as the argument separator.
    [TestCase('alternation',  'metadata://View/Admin;REGEX:(Admin|Root)$;True', ';')]
    [TestCase('case matters', 'metadata://View/admin;REGEX:(Admin|Root)$;False', ';')]
    procedure StrMatchesPatternOrRegex_WithRegex(
      const AString, APattern: string; const AExpected: Boolean);

    [Test]
    [TestCase('negated hit',  'kx/view/Clienti|~REGEX:^kx/view/Ord.*|True', '|')]
    [TestCase('negated miss', 'kx/view/Ordini|~REGEX:^kx/view/Ord.*|False', '|')]
    procedure StrMatchesPatternOrRegex_WithNegatedRegex(
      const AString, APattern: string; const AExpected: Boolean);

    /// <summary>
    ///  Case-insensitive matching (AIgnoreCase=True), used by the access
    ///  controller. The 'CS escalation' vs 'CI covers' pair is the security
    ///  fix: with the historical case-sensitive match a negated rule
    ///  ~metadata/views/admin* does NOT cover metadata/views/AdminUsers, so
    ///  'not (no match)' is True and the "everything but admin" rule grants
    ///  the admin view (True below); case-insensitive it is correctly covered
    ///  and denied (False). Case folding leaves ~, * and ? untouched.
    /// </summary>
    [Test]
    [TestCase('CI wildcard hit',   'metadata/views/AdminUsers|metadata/views/admin*|True|True', '|')]
    [TestCase('CI covers negated', 'metadata/views/AdminUsers|~metadata/views/admin*|True|False', '|')]
    [TestCase('CS escalation',     'metadata/views/AdminUsers|~metadata/views/admin*|False|True', '|')]
    [TestCase('CS wildcard miss',  'metadata/views/AdminUsers|metadata/views/admin*|False|False', '|')]
    [TestCase('CI regex hit',      'metadata/views/admin;REGEX:(Admin|Root)$;True;True', ';')]
    [TestCase('CS regex miss',     'metadata/views/admin;REGEX:(Admin|Root)$;False;False', ';')]
    procedure StrMatchesPatternOrRegex_IgnoreCase(
      const AString, APattern: string; const AIgnoreCase, AExpected: Boolean);

    /// <summary>
    ///  Regression. The unit used to keep one TPerlRegEx instance in a unit
    ///  variable and hand it to every caller. Since that instance carries both
    ///  the pattern and the subject, two threads evaluating a permission at the
    ///  same time overwrote each other's values and the access controller could
    ///  answer on somebody else's pattern - granting or denying at random.
    ///
    ///  Each worker checks a pattern that only its own subject satisfies, so a
    ///  single crossed evaluation shows up as a wrong answer.
    /// </summary>
    [Test]
    procedure StrMatchesPatternOrRegex_UnderConcurrency_KeepsPatternsApart;
  end;

implementation

uses
  System.Classes,
  System.SysUtils,
  System.SyncObjs,
  EF.RegEx;

{ TEFRegExTests }

procedure TEFRegExTests.StrMatchesPatternOrRegex_WithPlainPattern(
  const AString, APattern: string; const AExpected: Boolean);
begin
  Assert.AreEqual(AExpected, StrMatchesPatternOrRegex(AString, APattern));
end;

procedure TEFRegExTests.StrMatchesPatternOrRegex_WithRegex(
  const AString, APattern: string; const AExpected: Boolean);
begin
  Assert.AreEqual(AExpected, StrMatchesPatternOrRegex(AString, APattern));
end;

procedure TEFRegExTests.StrMatchesPatternOrRegex_WithNegatedRegex(
  const AString, APattern: string; const AExpected: Boolean);
begin
  Assert.AreEqual(AExpected, StrMatchesPatternOrRegex(AString, APattern));
end;

procedure TEFRegExTests.StrMatchesPatternOrRegex_IgnoreCase(
  const AString, APattern: string; const AIgnoreCase, AExpected: Boolean);
begin
  Assert.AreEqual(AExpected,
    StrMatchesPatternOrRegex(AString, APattern, AIgnoreCase));
end;

procedure TEFRegExTests.StrMatchesPatternOrRegex_UnderConcurrency_KeepsPatternsApart;
const
  THREAD_COUNT = 8;
  ITERATIONS = 400;
var
  LThreads: array of TThread;
  LWrongAnswers: Integer;
  I: Integer;
begin
  LWrongAnswers := 0;
  SetLength(LThreads, THREAD_COUNT);
  for I := 0 to THREAD_COUNT - 1 do
  begin
    LThreads[I] := TThread.CreateAnonymousThread(
      procedure
      var
        LSubject, LPattern: string;
        J: Integer;
      begin
        // Each thread works on a subject of its own, so a crossed evaluation
        // between threads shows up as a wrong answer here.
        LSubject := Format('kx/view/Res%d', [TThread.CurrentThread.ThreadID]);
        LPattern := Format('REGEX:^kx/view/Res%d$', [TThread.CurrentThread.ThreadID]);
        for J := 1 to ITERATIONS do
        begin
          if not StrMatchesPatternOrRegex(LSubject, LPattern) then
            TInterlocked.Increment(LWrongAnswers);
          // ...and a pattern the same subject must NOT satisfy.
          if StrMatchesPatternOrRegex(LSubject, 'REGEX:^kx/view/NoSuchResource$') then
            TInterlocked.Increment(LWrongAnswers);
        end;
      end);
    LThreads[I].FreeOnTerminate := False;
  end;
  try
    for I := 0 to THREAD_COUNT - 1 do
      LThreads[I].Start;
    for I := 0 to THREAD_COUNT - 1 do
      LThreads[I].WaitFor;
  finally
    for I := 0 to THREAD_COUNT - 1 do
      LThreads[I].Free;
  end;

  Assert.AreEqual(0, LWrongAnswers,
    'Concurrent evaluations returned wrong answers: the regex engine state is shared.');
end;

initialization
  TDUnitX.RegisterTestFixture(TEFRegExTests);

end.
