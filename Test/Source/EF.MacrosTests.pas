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
unit EF.MacrosTests;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TEFMacroExpanderTests = class
  strict private
    FTempPath: string;
    function Expand(const AString: string): string;
    /// <summary>Writes AContent to a file of its own and returns its full
    /// name.</summary>
    function WriteTempFile(const AName, AContent: string): string;
    /// <summary>Writes AContent with no byte order mark. TextFileToString,
    /// which is what %FILE()% reads with, creates its TStreamReader without BOM
    /// detection, so a mark would come through as part of the text.</summary>
    procedure WriteTempFileContent(const AFileName, AContent: string);
    /// <summary>The %FILE()% macro that loads AFileName.</summary>
    function FileMacro(const AFileName: string): string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    /// <summary>
    ///  %FILE()% expands what it loads, and what it loads may contain another
    ///  %FILE()%. Two files that include each other -- or one that includes
    ///  itself -- used to recurse until the stack ran out, and a stack overflow
    ///  on Win64 takes the process down rather than raising something an
    ///  application can catch and report. Now it stops at a fixed depth and
    ///  says which file it was expanding.
    ///
    ///  The failing case is not run against the old code, for the same reason
    ///  the long command line of finding 9 is not: a test that exhausts the
    ///  stack of the process running it proves nothing worth the risk.
    /// </summary>
    [Test]
    procedure FileMacro_WithTwoFilesIncludingEachOther_Raises;
    [Test]
    procedure FileMacro_WithAFileIncludingItself_Raises;
    /// <summary>
    ///  And the limit has to leave real use alone: a template that includes a
    ///  header that includes a fragment is three levels deep.
    /// </summary>
    [Test]
    procedure FileMacro_NestedThreeDeep_ExpandsThemAll;

    /// <summary>
    ///  The macro was registered as '%SPACE' without its closing per cent, so
    ///  the pattern matched the first six characters of its own name: the
    ///  documented '%SPACE%' expanded to a space followed by a stray '%', and
    ///  '%SPACES%' to ' S%'.
    /// </summary>
    [Test]
    [TestCase('on its own', 'a%SPACE%b|a b', '|')]
    [TestCase('twice', 'a%SPACE%b%SPACE%c|a b c', '|')]
    [TestCase('next to a similar name', 'x%SPACES%|x%SPACES%', '|')]
    [TestCase('with the tab macro', 'a%TAB%b|a' + #9 + 'b', '|')]
    procedure Expand_SpaceMacro_Expands(const AInput, AExpected: string);

    /// <summary>
    ///  Regression, and the reason this suite exists. An unterminated '_('
    ///  directive used to leave the string untouched while the search restarted
    ///  from the beginning, so the same position was found over and over.
    ///
    ///  It matters because the authenticators expand the supplied user name and
    ///  password BEFORE checking them (Kitto.Auth.DB.GetSuppliedUserName,
    ///  Kitto.Auth.TextFile): a login POST carrying 'a_(b' pinned a worker
    ///  thread at 100% CPU for good, and twenty of them took the application
    ///  down without leaving a trace in the log.
    /// </summary>
    [Test]
    [TestCase('no closing paren',   'a_(b')]
    [TestCase('empty directive',    'a_()')]
    [TestCase('two unterminated',   'a_(b_(c')]
    [TestCase('paren before start', 'a)_(b')]
    procedure Expand_WithUnterminatedDirective_Terminates(const AInput: string);

    [Test]
    [TestCase('leaves it alone', 'a_(b|a_(b', '|')]
    procedure Expand_WithUnterminatedDirective_LeavesItAlone(
      const AInput, AExpected: string);

    // Without a translation catalog the localized text equals the source text,
    // so these check the directive handling, not the translation itself.
    [Test]
    [TestCase('embedded',           'x_(Hello)y|xHelloy', '|')]
    [TestCase('unterminated first', 'a_(b )_(Hello)|ab Hello', '|')]
    [TestCase('nothing to do',      'plain text|plain text', '|')]
    procedure Expand_ExpandsEmbeddedDirectives(const AInput, AExpected: string);

    /// <summary>
    ///  A directive starting at position 1 is left to the caller: the whole
    ///  string is localizable and is handled elsewhere. Pinned down here
    ///  because it looks like an oversight and must not be "fixed" by accident.
    /// </summary>
    [Test]
    [TestCase('whole string', '_(Hello)|_(Hello)', '|')]
    procedure Expand_WithDirectiveAtStart_LeavesItToTheCaller(
      const AInput, AExpected: string);
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  EF.Types,
  EF.Macros,
  Kitto.TestUtils;

{ TEFMacroExpanderTests }

procedure TEFMacroExpanderTests.Expand_SpaceMacro_Expands(
  const AInput, AExpected: string);
var
  LValue: string;
begin
  LValue := AInput;
  TEFMacroExpansionEngine.Instance.Expand(LValue);
  Assert.AreEqual(AExpected, LValue);
end;

procedure TEFMacroExpanderTests.Setup;
begin
  FTempPath := TKTestUtils.CreateTempPath;
end;

procedure TEFMacroExpanderTests.TearDown;
begin
  TKTestUtils.RemoveTempPath(FTempPath);
end;

function TEFMacroExpanderTests.WriteTempFile(const AName, AContent: string): string;
begin
  Result := TPath.Combine(FTempPath, AName);
  WriteTempFileContent(Result, AContent);
end;

procedure TEFMacroExpanderTests.WriteTempFileContent(const AFileName, AContent: string);
begin
  TFile.WriteAllBytes(AFileName, TEncoding.UTF8.GetBytes(AContent));
end;

function TEFMacroExpanderTests.FileMacro(const AFileName: string): string;
begin
  // Absolute, so that it does not depend on the expander's DefaultPath - the
  // one in the shared engine has none and falls back to the current directory.
  Result := '%FILE(' + AFileName + ')%';
end;

procedure TEFMacroExpanderTests.FileMacro_WithTwoFilesIncludingEachOther_Raises;
var
  LFirst, LSecond: string;
begin
  LFirst := TPath.Combine(FTempPath, 'first.txt');
  LSecond := TPath.Combine(FTempPath, 'second.txt');
  WriteTempFileContent(LFirst, FileMacro(LSecond));
  WriteTempFileContent(LSecond, FileMacro(LFirst));

  Assert.WillRaise(
    procedure
    var
      LValue: string;
    begin
      LValue := FileMacro(LFirst);
      TEFMacroExpansionEngine.Instance.Expand(LValue);
    end,
    EEFError,
    'Two files including each other must be reported, not run until the ' +
    'stack gives out.');
end;

procedure TEFMacroExpanderTests.FileMacro_WithAFileIncludingItself_Raises;
var
  LFileName: string;
begin
  LFileName := TPath.Combine(FTempPath, 'itself.txt');
  WriteTempFileContent(LFileName, FileMacro(LFileName));

  Assert.WillRaise(
    procedure
    var
      LValue: string;
    begin
      LValue := FileMacro(LFileName);
      TEFMacroExpansionEngine.Instance.Expand(LValue);
    end,
    EEFError);
end;

procedure TEFMacroExpanderTests.FileMacro_NestedThreeDeep_ExpandsThemAll;
var
  LLeaf, LMiddle, LTop, LValue: string;
begin
  LLeaf := WriteTempFile('leaf.txt', 'the leaf');
  LMiddle := WriteTempFile('middle.txt', 'middle sees [' + FileMacro(LLeaf) + ']');
  LTop := WriteTempFile('top.txt', 'top sees [' + FileMacro(LMiddle) + ']');

  LValue := FileMacro(LTop);
  TEFMacroExpansionEngine.Instance.Expand(LValue);
  Assert.AreEqual('top sees [middle sees [the leaf]]', LValue,
    'Legitimate nesting must go through untouched.');
end;

function TEFMacroExpanderTests.Expand(const AString: string): string;
var
  LExpander: TEFMacroExpander;
begin
  LExpander := TEFMacroExpander.Create;
  try
    Result := AString;
    LExpander.Expand(Result);
  finally
    LExpander.Free;
  end;
end;

procedure TEFMacroExpanderTests.Expand_WithUnterminatedDirective_Terminates(
  const AInput: string);
begin
  Assert.IsTrue(
    TKTestUtils.RunsWithin(
      procedure
      begin
        Expand(AInput);
      end),
    Format('Expand did not return on "%s": unterminated _( directive.', [AInput]));
end;

procedure TEFMacroExpanderTests.Expand_WithUnterminatedDirective_LeavesItAlone(
  const AInput, AExpected: string);
var
  LResult: string;
begin
  Assert.IsTrue(
    TKTestUtils.RunsWithin(
      procedure
      begin
        LResult := Expand(AInput);
      end),
    'Expand did not return.');
  Assert.AreEqual(AExpected, LResult);
end;

procedure TEFMacroExpanderTests.Expand_ExpandsEmbeddedDirectives(
  const AInput, AExpected: string);
var
  LResult: string;
begin
  Assert.IsTrue(
    TKTestUtils.RunsWithin(
      procedure
      begin
        LResult := Expand(AInput);
      end),
    'Expand did not return.');
  Assert.AreEqual(AExpected, LResult);
end;

procedure TEFMacroExpanderTests.Expand_WithDirectiveAtStart_LeavesItToTheCaller(
  const AInput, AExpected: string);
begin
  Assert.AreEqual(AExpected, Expand(AInput));
end;

initialization
  TDUnitX.RegisterTestFixture(TEFMacroExpanderTests);

end.
