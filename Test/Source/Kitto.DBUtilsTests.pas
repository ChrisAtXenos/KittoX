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

/// <summary>
///  The SQL-string helpers in Kitto.DBUtils embed a value inside a quoted
///  literal. The value comes from a record field, i.e. from the user, so a
///  single quote in it must be doubled or it breaks out of the literal (SQL
///  injection). These are pure string builders — no database is needed to test
///  that the value is escaped.
/// </summary>
unit Kitto.DBUtilsTests;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TKDBUtilsSQLEscapingTests = class
  public
    /// <summary>A value with a single quote is doubled, not left to break out.</summary>
    [Test]
    procedure CountValue_EscapesSingleQuote;
    [Test]
    procedure DeleteStatement_EscapesSingleQuote;
    [Test]
    procedure FieldValue_EscapesSingleQuote;
    [Test]
    procedure CountValue_WithIdToExclude_EscapesBoth;
    /// <summary>A plain value is unchanged (no over-escaping).</summary>
    [Test]
    procedure PlainValue_IsUnchanged;
  end;

implementation

uses
  Kitto.DBUtils;

procedure TKDBUtilsSQLEscapingTests.CountValue_EscapesSingleQuote;
begin
  // Input value: a'b  (Pascal literal 'a''b')
  Assert.AreEqual(
    'SELECT COUNT(*) TOT FROM T WHERE F = ''a''''b''',
    GetSQLCountValue('T', 'F', 'a''b'),
    'A single quote in the value must be doubled, not left to close the literal.');
end;

procedure TKDBUtilsSQLEscapingTests.DeleteStatement_EscapesSingleQuote;
begin
  Assert.AreEqual(
    'DELETE FROM T WHERE K = ''x''''y''',
    GetSQLDeleteStatement('T', 'K', 'x''y'));
end;

procedure TKDBUtilsSQLEscapingTests.FieldValue_EscapesSingleQuote;
begin
  // Signature is (ATableName, AFieldName, AKeyFieldName, AKeyFieldValue), and it
  // SELECTs the field from the table: so ('T','F',...) => SELECT F ... FROM T.
  Assert.AreEqual(
    'SELECT F TOT FROM T WHERE K = ''x''''y''',
    GetSQLFieldValue('T', 'F', 'K', 'x''y'));
end;

procedure TKDBUtilsSQLEscapingTests.CountValue_WithIdToExclude_EscapesBoth;
begin
  Assert.AreEqual(
    'SELECT COUNT(*) TOT FROM T WHERE Id <> ''1''''2'' and F = ''a''''b''',
    GetSQLCountValue('T', 'F', 'a''b', '1''2'));
end;

procedure TKDBUtilsSQLEscapingTests.PlainValue_IsUnchanged;
begin
  Assert.AreEqual(
    'SELECT COUNT(*) TOT FROM T WHERE F = ''plain''',
    GetSQLCountValue('T', 'F', 'plain'));
end;

initialization
  TDUnitX.RegisterTestFixture(TKDBUtilsSQLEscapingTests);

end.
