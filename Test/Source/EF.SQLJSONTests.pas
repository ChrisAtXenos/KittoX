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
unit EF.SQLJSONTests;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TEFSQLTests = class
  public
    [Test]
    [TestCase('quoted',       '''ABC''|ABC', '|')]
    [TestCase('empty quoted', '''''|', '|')]
    procedure RemoveSQLQuotes_WithQuotedString_StripsTheQuotes(
      const AInput, AExpected: string);

    /// <summary>
    ///  KNOWN DEFECT (review 4.1, finding 36). When the string is long enough
    ///  but not quoted, no branch assigns Result: for a managed type the return
    ///  slot is the caller's own variable, so the function hands back whatever
    ///  that variable held before the call.
    /// </summary>
    [Test]
    procedure RemoveSQLQuotes_WithUnquotedString_ReturnsItUnchanged;
  end;

  [TestFixture]
  TEFJSONTests = class
  public
    [Test]
    [TestCase('backslash', 'a\b')]
    procedure JSONEscape_EscapesBackslash(const AInput: string);

    /// <summary>
    ///  KNOWN DEFECT (review 4.1, finding 23). Only backslash and line breaks
    ///  are escaped: a TAB (or any other character below #32) travels raw into
    ///  a JSON string, which RFC 8259 forbids. One such character in a database
    ///  field makes JSON.parse fail on the client and the whole grid stays
    ///  empty.
    /// </summary>
    [Test]
    procedure JSONEscape_EscapesControlCharacters;
  end;

implementation

uses
  System.SysUtils,
  System.JSON,
  EF.SQL,
  EF.JSON;

{ TEFSQLTests }

procedure TEFSQLTests.RemoveSQLQuotes_WithQuotedString_StripsTheQuotes(
  const AInput, AExpected: string);
begin
  Assert.AreEqual(AExpected, RemoveSQLQuotes(AInput));
end;

procedure TEFSQLTests.RemoveSQLQuotes_WithUnquotedString_ReturnsItUnchanged;
var
  LResult: string;
begin
  // Seed the destination: if the function leaves Result untouched, this is
  // what comes back.
  LResult := 'left over from an earlier call';
  LResult := RemoveSQLQuotes('ABC');
  Assert.AreEqual('ABC', LResult,
    'An unquoted string must be returned as it is, not the previous content ' +
    'of the caller''s variable.');
end;

{ TEFJSONTests }

procedure TEFJSONTests.JSONEscape_EscapesBackslash(const AInput: string);
begin
  Assert.AreEqual('a\\b', JSONEscape(AInput));
end;

procedure TEFJSONTests.JSONEscape_EscapesControlCharacters;
var
  LEscaped: string;
  LParsed: TJSONValue;
begin
  LEscaped := JSONEscape('before' + #9 + 'after');
  Assert.AreEqual('before\tafter', LEscaped, 'A TAB must be escaped as \t.');

  // The point of escaping: the result must survive a real JSON parser.
  LParsed := TJSONObject.ParseJSONValue('{"v":"' + LEscaped + '"}');
  try
    Assert.IsNotNull(LParsed, 'The escaped value does not parse as JSON.');
  finally
    LParsed.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TEFSQLTests);
  TDUnitX.RegisterTestFixture(TEFJSONTests);

end.
