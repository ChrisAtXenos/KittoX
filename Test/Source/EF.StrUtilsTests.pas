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
unit EF.StrUtilsTests;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TEFStrUtilsTests = class
  public
    // ReplaceAllCaseSensitive
    [Test]
    [TestCase('every occurrence', 'abcabc|abc|Z|ZZ', '|')]
    [TestCase('single occurrence', 'a-b|-|+|a+b', '|')]
    [TestCase('overlapping',       'aaaa|aa|b|bb', '|')]
    [TestCase('pattern absent',    'abc|X|Y|abc', '|')]
    [TestCase('shorter result',    'a..b|..|.|a.b', '|')]
    procedure ReplaceAllCaseSensitive_Replaces(const AInput, AOld, ANew, AExpected: string);

    [Test]
    [TestCase('lower vs upper', 'abc|ABC|Z|abc', '|')]
    procedure ReplaceAllCaseSensitive_IsCaseSensitive(const AInput, AOld, ANew, AExpected: string);

    /// <summary>
    ///  Regression: the replacement containing the pattern used to make the
    ///  search restart from the beginning of the string and find it again
    ///  inside the text just written, looping forever while the string grew by
    ///  one step per pass. Macro values are the way in: they can carry the very
    ///  name of the macro being expanded (a request header, a user field).
    /// </summary>
    [Test]
    [TestCase('replacement contains pattern', 'aXa|X|YXY|aYXYa', '|')]
    [TestCase('self-referencing macro', 'H=%HOST%|%HOST%|x%HOST%|H=x%HOST%', '|')]
    procedure ReplaceAllCaseSensitive_WhenReplacementContainsPattern_Terminates(
      const AInput, AOld, ANew, AExpected: string);

    [Test]
    procedure ReplaceAllCaseSensitive_WithEmptyPattern_LeavesStringAlone;
  end;

  /// <summary>
  ///  Tests for the random string functions. What they produce feeds
  ///  TKDBAuthenticator.GenerateRandomPassword, the provisional password mailed
  ///  to a user who asked for a reset, so the property under test is not that
  ///  the output looks varied but that it cannot be reproduced by someone who
  ///  has seen other output from the same generator.
  /// </summary>
  [TestFixture]
  TEFRandomStringTests = class
  public
    /// <summary>
    ///  Regression, and the heart of finding 8. Every character used to come
    ///  from the RTL's Random, a linear generator whose entire state is the
    ///  global RandSeed: setting that back to the same value replayed the same
    ///  password. Someone who asks for a reset of their own account sees eight
    ///  characters of that output, which is enough to recover the state and
    ///  predict what other users are issued next. The bytes now come from the
    ///  operating system's cryptographic source, which has no seed to set.
    /// </summary>
    [Test]
    procedure GetRandomString_DoesNotDependOnRandSeed;
    [Test]
    procedure GetRandomStringEx_DoesNotDependOnRandSeed;
    /// <summary>
    ///  The same for GetRandomChar, which is where the special character of a
    ///  generated password comes from.
    /// </summary>
    [Test]
    procedure GetRandomChar_DoesNotDependOnRandSeed;

    [Test]
    [TestCase('one', '1')]
    [TestCase('eight - the length a generated password has', '8')]
    [TestCase('sixty-four', '64')]
    procedure GetRandomString_ReturnsTheRequestedLength(const ALength: Integer);
    [Test]
    procedure GetRandomString_StaysInItsAlphabet;
    /// <summary>
    ///  Every symbol of the alphabet has to turn up. A source stuck on one
    ///  value, or a range computed wrongly, shows up here and nowhere else --
    ///  the tests above would all still pass.
    /// </summary>
    [Test]
    procedure GetRandomString_CoversItsWholeAlphabet;
    [Test]
    procedure GetRandomString_ExcludesTheGivenCharacters;
    [Test]
    procedure GetRandomChar_ReturnsOneOfTheGivenCharacters;
    [Test]
    procedure GetRandomChar_WithNoCharacters_Raises;
    /// <summary>
    ///  The RTL's Random keeps its state in one global, so two threads drawing
    ///  at once can walk away with the same value. This cannot prove a race
    ///  absent, but a generator that shares state across threads has a real
    ///  chance of showing it here, and one that does not, cannot.
    /// </summary>
    [Test]
    procedure GetRandomString_FromSeveralThreads_KeepsItsOutputDistinct;
  end;

  /// <summary>
  ///  Tests for reading a text file back as a string.
  /// </summary>
  [TestFixture]
  TEFTextFileTests = class
  strict private
    FTempPath: string;
    /// <summary>Writes AContent as UTF-8, with or without a byte order mark,
    /// and returns the file name.</summary>
    function WriteFile(const AName, AContent: string;
      const AWithBOM: Boolean): string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    /// <summary>
    ///  Regression. TextFileToString built its TStreamReader with DetectBOM at
    ///  its default of False, so a file carrying a byte order mark was decoded
    ///  with the ANSI codepage: the mark came back as characters at the head of
    ///  the text, and every accented character with it. Found while writing the
    ///  test for finding 24, where the %FILE()% macro returned a stray U+FEFF
    ///  in front of each fragment it had loaded.
    /// </summary>
    [Test]
    procedure TextFileToString_WithABOM_ReadsTheTextWithoutIt;
    /// <summary>
    ///  And a file with no mark still goes through the encoding it is given,
    ///  which is what everything that worked before relies on.
    /// </summary>
    [Test]
    procedure TextFileToString_WithoutABOM_UsesTheGivenEncoding;
    [Test]
    procedure TextFileToString_OnAMissingFile_ReturnsEmpty;
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  System.Classes,
  System.Threading,
  System.Generics.Collections,
  EF.StrUtils,
  Kitto.TestUtils;

{ TEFStrUtilsTests }

procedure TEFStrUtilsTests.ReplaceAllCaseSensitive_Replaces(
  const AInput, AOld, ANew, AExpected: string);
var
  S: string;
begin
  S := AInput;
  ReplaceAllCaseSensitive(S, AOld, ANew);
  Assert.AreEqual(AExpected, S);
end;

procedure TEFStrUtilsTests.ReplaceAllCaseSensitive_IsCaseSensitive(
  const AInput, AOld, ANew, AExpected: string);
var
  S: string;
begin
  S := AInput;
  ReplaceAllCaseSensitive(S, AOld, ANew);
  Assert.AreEqual(AExpected, S);
end;

procedure TEFStrUtilsTests.ReplaceAllCaseSensitive_WhenReplacementContainsPattern_Terminates(
  const AInput, AOld, ANew, AExpected: string);
var
  S: string;
begin
  S := AInput;
  Assert.IsTrue(
    TKTestUtils.RunsWithin(
      procedure
      begin
        ReplaceAllCaseSensitive(S, AOld, ANew);
      end),
    'ReplaceAllCaseSensitive did not return: the replacement contains the pattern.');
  Assert.AreEqual(AExpected, S);
end;

procedure TEFStrUtilsTests.ReplaceAllCaseSensitive_WithEmptyPattern_LeavesStringAlone;
var
  S: string;
begin
  S := 'abc';
  Assert.IsTrue(
    TKTestUtils.RunsWithin(
      procedure
      begin
        ReplaceAllCaseSensitive(S, '', 'X');
      end),
    'ReplaceAllCaseSensitive did not return on an empty pattern.');
  Assert.AreEqual('abc', S);
end;

{ TEFRandomStringTests }

procedure TEFRandomStringTests.GetRandomString_DoesNotDependOnRandSeed;
var
  LFirst, LSecond: string;
begin
  RandSeed := 12345;
  LFirst := GetRandomString(24);
  RandSeed := 12345;
  LSecond := GetRandomString(24);
  Assert.AreNotEqual(LFirst, LSecond,
    'The same RandSeed produced the same string twice: the characters are ' +
    'still coming from the RTL generator, whose whole state is that one ' +
    'global, and anyone who sees enough output can predict what comes next.');
end;

procedure TEFRandomStringTests.GetRandomStringEx_DoesNotDependOnRandSeed;
var
  LFirst, LSecond: string;
begin
  RandSeed := 999;
  LFirst := GetRandomStringEx(24);
  RandSeed := 999;
  LSecond := GetRandomStringEx(24);
  Assert.AreNotEqual(LFirst, LSecond,
    'The same RandSeed produced the same string twice.');
end;

procedure TEFRandomStringTests.GetRandomChar_DoesNotDependOnRandSeed;
const
  ALPHABET = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
var
  LFirst, LSecond: string;
  I: Integer;
begin
  // One character at a time would match by chance once in sixty-two, so the
  // comparison is over a sequence of them.
  LFirst := '';
  LSecond := '';
  RandSeed := 4242;
  for I := 1 to 24 do
    LFirst := LFirst + GetRandomChar(ALPHABET);
  RandSeed := 4242;
  for I := 1 to 24 do
    LSecond := LSecond + GetRandomChar(ALPHABET);
  Assert.AreNotEqual(LFirst, LSecond,
    'The same RandSeed produced the same characters twice.');
end;

procedure TEFRandomStringTests.GetRandomString_ReturnsTheRequestedLength(
  const ALength: Integer);
begin
  Assert.AreEqual(ALength, Length(GetRandomString(ALength)));
  Assert.AreEqual(ALength, Length(GetRandomStringEx(ALength)));
end;

procedure TEFRandomStringTests.GetRandomString_StaysInItsAlphabet;
var
  LValue: string;
  LChar: Char;
begin
  LValue := GetRandomString(2000);
  for LChar in LValue do
    Assert.IsTrue(CharInSet(LChar, ['0'..'9', 'A'..'Z']),
      'GetRandomString produced ' + LChar + ', outside its alphabet.');
  LValue := GetRandomStringEx(2000);
  for LChar in LValue do
    Assert.IsTrue(CharInSet(LChar, ['0'..'9', 'A'..'Z', 'a'..'z']),
      'GetRandomStringEx produced ' + LChar + ', outside its alphabet.');
end;

procedure TEFRandomStringTests.GetRandomString_CoversItsWholeAlphabet;
var
  LValue: string;
  LChar: Char;
begin
  LValue := GetRandomString(2000);
  for LChar := '0' to '9' do
    Assert.IsTrue(LValue.Contains(LChar), 'Never produced ' + LChar + '.');
  for LChar := 'A' to 'Z' do
    Assert.IsTrue(LValue.Contains(LChar), 'Never produced ' + LChar + '.');
  LValue := GetRandomStringEx(3000);
  for LChar := 'a' to 'z' do
    Assert.IsTrue(LValue.Contains(LChar), 'Never produced ' + LChar + '.');
end;

procedure TEFRandomStringTests.GetRandomString_ExcludesTheGivenCharacters;
var
  LValue: string;
  LChar: Char;
begin
  // '01' is what TKDBAuthenticator.GenerateRandomPassword excludes, to keep
  // zero and one out of a password a user has to read off an email.
  LValue := GetRandomString(2000, '01');
  for LChar in LValue do
    Assert.IsFalse(CharInSet(LChar, ['0', '1']),
      'An excluded character came out of GetRandomString.');
  LValue := GetRandomStringEx(2000, 'aeiou');
  for LChar in LValue do
    Assert.IsFalse(CharInSet(LChar, ['a', 'e', 'i', 'o', 'u']),
      'An excluded character came out of GetRandomStringEx.');
end;

procedure TEFRandomStringTests.GetRandomChar_ReturnsOneOfTheGivenCharacters;
const
  CHARS = '!@#$%^&*()';
var
  LSeen: string;
  I: Integer;
  LChar: Char;
begin
  LSeen := '';
  for I := 1 to 2000 do
  begin
    LChar := GetRandomChar(CHARS);
    Assert.IsTrue(string(CHARS).Contains(LChar),
      'GetRandomChar returned ' + LChar + ', which is not in the set.');
    if not LSeen.Contains(LChar) then
      LSeen := LSeen + LChar;
  end;
  Assert.AreEqual(Length(CHARS), Length(LSeen),
    'GetRandomChar never produced some of the characters in the set.');
end;

procedure TEFRandomStringTests.GetRandomChar_WithNoCharacters_Raises;
begin
  Assert.WillRaise(
    procedure
    begin
      GetRandomChar('');
    end);
end;

procedure TEFRandomStringTests.GetRandomString_FromSeveralThreads_KeepsItsOutputDistinct;
const
  THREAD_COUNT = 8;
  PER_THREAD = 200;
var
  LResults: array[0..THREAD_COUNT - 1] of TArray<string>;
  LErrors: array[0..THREAD_COUNT - 1] of string;
  LTasks: array[0..THREAD_COUNT - 1] of ITask;
  LAll: TDictionary<string, Boolean>;
  I, J: Integer;

  // A function of its own so that each task closes over its own AIndex: an
  // anonymous method written inside the loop below would capture the loop
  // variable itself, and every task would see the last value it took.
  function RunOne(const AIndex: Integer): ITask;
  begin
    Result := TTask.Run(
      procedure
      var
        K: Integer;
      begin
        try
          SetLength(LResults[AIndex], PER_THREAD);
          for K := 0 to PER_THREAD - 1 do
            LResults[AIndex][K] := GetRandomStringEx(12);
        except
          on E: Exception do
            LErrors[AIndex] := E.ClassName + ': ' + E.Message;
        end;
      end);
  end;

begin
  for I := 0 to THREAD_COUNT - 1 do
  begin
    LErrors[I] := '';
    LTasks[I] := RunOne(I);
  end;
  for I := 0 to THREAD_COUNT - 1 do
    LTasks[I].Wait;

  LAll := TDictionary<string, Boolean>.Create;
  try
    for I := 0 to THREAD_COUNT - 1 do
    begin
      Assert.AreEqual('', LErrors[I], 'A thread failed: ' + LErrors[I]);
      for J := 0 to Length(LResults[I]) - 1 do
      begin
        Assert.IsFalse(LAll.ContainsKey(LResults[I][J]),
          'Two threads produced the same string: ' + LResults[I][J]);
        LAll.Add(LResults[I][J], True);
      end;
    end;
    // TDictionary.Count is a NativeInt on this RTL, hence the cast: without
    // it Assert.AreEqual<T> cannot infer T from two different types.
    Assert.AreEqual(Integer(THREAD_COUNT * PER_THREAD), Integer(LAll.Count));
  finally
    LAll.Free;
  end;
end;

{ TEFTextFileTests }

procedure TEFTextFileTests.Setup;
begin
  FTempPath := TKTestUtils.CreateTempPath;
end;

procedure TEFTextFileTests.TearDown;
begin
  TKTestUtils.RemoveTempPath(FTempPath);
end;

function TEFTextFileTests.WriteFile(const AName, AContent: string;
  const AWithBOM: Boolean): string;
var
  LBytes: TBytes;
begin
  Result := TPath.Combine(FTempPath, AName);
  LBytes := TEncoding.UTF8.GetBytes(AContent);
  if AWithBOM then
    LBytes := TEncoding.UTF8.GetPreamble + LBytes;
  TFile.WriteAllBytes(Result, LBytes);
end;

procedure TEFTextFileTests.TextFileToString_WithABOM_ReadsTheTextWithoutIt;
const
  // Accented characters as well as the mark: with the ANSI codepage they came
  // back as something else, which is the other half of the same defect.
  CONTENT = 'accented text: ' + #$00E0#$00E8#$00EC#$00F2#$00F9 + ' and more';
var
  LFileName: string;
begin
  LFileName := WriteFile('with_bom.txt', CONTENT, True);
  Assert.AreEqual(CONTENT, TextFileToString(LFileName),
    'The byte order mark, or the encoding it announces, did not survive the read.');
  // Explicitly, so that a failure says which half broke.
  Assert.IsFalse(TextFileToString(LFileName).StartsWith(#$FEFF),
    'The byte order mark came through as a character.');
end;

procedure TEFTextFileTests.TextFileToString_WithoutABOM_UsesTheGivenEncoding;
const
  CONTENT = 'plain ASCII, no mark';
var
  LFileName: string;
begin
  LFileName := WriteFile('no_bom.txt', CONTENT, False);
  Assert.AreEqual(CONTENT, TextFileToString(LFileName));
  Assert.AreEqual(CONTENT, TextFileToString(LFileName, TEncoding.UTF8));
end;

procedure TEFTextFileTests.TextFileToString_OnAMissingFile_ReturnsEmpty;
begin
  Assert.AreEqual('', TextFileToString(TPath.Combine(FTempPath, 'nope.txt')));
end;

initialization
  TDUnitX.RegisterTestFixture(TEFStrUtilsTests);
  TDUnitX.RegisterTestFixture(TEFRandomStringTests);
  TDUnitX.RegisterTestFixture(TEFTextFileTests);

end.
