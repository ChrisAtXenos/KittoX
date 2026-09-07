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
///  Tests for EF.XML, the three functions that strip an XML declaration, a
///  DOCTYPE and the default namespace declarations off a document. They are
///  reached from TEFDataType.NodeToXMLValue, which embeds the XML held in a
///  memo field into the XML export of the data: what they leave behind has to
///  be well formed.
/// </summary>
unit EF.XMLTests;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TEFXMLTests = class
  public
    /// <summary>
    ///  Regression. The cut position was computed by folding a relative offset
    ///  into an absolute one, landing LPos - 6 characters past the end of the
    ///  attribute: right for LPos = 6 and wrong everywhere else, which for a
    ///  real element name means eating the '>' that closes it.
    /// </summary>
    [Test]
    procedure ClearXmlNameSpaces_RemovesTheDeclarationAndNothingElse;
    /// <summary>
    ///  The same, with the declaration at a different offset in every case:
    ///  the drift grew with the length of the element name, so an element
    ///  called 'roo' was the one length that used to work.
    /// </summary>
    [Test]
    [TestCase('one char', 'r')]
    [TestCase('two chars', 'ro')]
    [TestCase('three chars - the only length that used to work', 'roo')]
    [TestCase('four chars', 'root')]
    [TestCase('five chars', 'root5')]
    [TestCase('a long one', 'a_rather_long_element_name')]
    procedure ClearXmlNameSpaces_AtAnyOffset_CutsExactlyTheDeclaration(
      const AElementName: string);
    [Test]
    procedure ClearXmlNameSpaces_WithSeveralDeclarations_RemovesThemAll;
    /// <summary>
    ///  An attribute value with no closing quote has no sane cut point. The
    ///  former guard could not tell: it tested a value that was LPos - 1 in
    ///  this case, true for any LPos > 1, and cut at a meaningless position.
    /// </summary>
    [Test]
    procedure ClearXmlNameSpaces_WithUnterminatedValue_LeavesTheTextAlone;
    [Test]
    procedure ClearXmlNameSpaces_WithoutDeclarations_ReturnsFalse;
    /// <summary>
    ///  Documents a deliberate limit: a declaration bound to a prefix is not
    ///  matched by the 'xmlns="' pattern and stays in the document.
    /// </summary>
    [Test]
    procedure ClearXmlNameSpaces_WithAPrefixedDeclaration_LeavesItAlone;

    [Test]
    procedure ClearDOCTYPE_RemovesTheDeclaration;
    /// <summary>
    ///  Regression. The end of the declaration was taken to be the first '>'
    ///  of the whole text, so the declarations of the internal subset -- which
    ///  carry a '>' each -- cut it short and left ']>' at the front of the
    ///  document.
    /// </summary>
    [Test]
    procedure ClearDOCTYPE_WithInternalSubset_RemovesTheWholeDeclaration;
    /// <summary>
    ///  Regression. Same cause, with the '>' inside the SYSTEM literal.
    /// </summary>
    [Test]
    procedure ClearDOCTYPE_WithGreaterThanInASystemLiteral_RemovesTheWholeDeclaration;
    /// <summary>
    ///  Regression. A comment before the DOCTYPE owns the first '>' of the
    ///  text: the declaration was left in place and True returned anyway.
    /// </summary>
    [Test]
    procedure ClearDOCTYPE_AfterAComment_RemovesTheDeclarationAndKeepsTheComment;
    [Test]
    procedure ClearDOCTYPE_WithoutADOCTYPE_ReturnsFalse;

    [Test]
    procedure ClearXMLHeader_RemovesOnlyTheDeclaration;
    /// <summary>
    ///  What precedes the declaration is not the declaration: cutting from
    ///  position 1 threw it away.
    /// </summary>
    [Test]
    procedure ClearXMLHeader_WithTextBeforeTheDeclaration_KeepsIt;
    [Test]
    procedure ClearXMLHeader_WithoutADeclaration_ReturnsFalse;

    /// <summary>
    ///  End to end through the one caller: a node whose value is a whole XML
    ///  document is embedded into the export with its declaration, DOCTYPE and
    ///  default namespace removed -- and has to come out well formed.
    /// </summary>
    [Test]
    procedure NodeToXMLValue_WithAnXMLDocumentValue_EmbedsItWellFormed;
  end;

implementation

uses
  System.SysUtils,
  EF.Tree,
  EF.XML;

{ TEFXMLTests }

procedure TEFXMLTests.ClearXmlNameSpaces_RemovesTheDeclarationAndNothingElse;
var
  LText: string;
begin
  LText := '<root xmlns="urn:example"><a>1</a></root>';
  Assert.IsTrue(ClearXmlNameSpaces(LText));
  Assert.AreEqual('<root ><a>1</a></root>', LText);
end;

procedure TEFXMLTests.ClearXmlNameSpaces_AtAnyOffset_CutsExactlyTheDeclaration(
  const AElementName: string);
var
  LText: string;
begin
  LText := '<' + AElementName + ' xmlns="urn:x">body</' + AElementName + '>';
  Assert.IsTrue(ClearXmlNameSpaces(LText));
  Assert.AreEqual('<' + AElementName + ' >body</' + AElementName + '>', LText);
end;

procedure TEFXMLTests.ClearXmlNameSpaces_WithSeveralDeclarations_RemovesThemAll;
var
  LText: string;
begin
  LText := '<root xmlns="urn:a"><child xmlns="urn:b">x</child></root>';
  Assert.IsTrue(ClearXmlNameSpaces(LText));
  Assert.AreEqual('<root ><child >x</child></root>', LText);
end;

procedure TEFXMLTests.ClearXmlNameSpaces_WithUnterminatedValue_LeavesTheTextAlone;
const
  BROKEN = '<root xmlns="urn:a><a>1</a></root>';
var
  LText: string;
begin
  LText := BROKEN;
  Assert.IsFalse(ClearXmlNameSpaces(LText),
    'There is nothing to report as removed when the value is not terminated.');
  Assert.AreEqual(BROKEN, LText);
end;

procedure TEFXMLTests.ClearXmlNameSpaces_WithoutDeclarations_ReturnsFalse;
const
  PLAIN = '<root><a>1</a></root>';
var
  LText: string;
begin
  LText := PLAIN;
  Assert.IsFalse(ClearXmlNameSpaces(LText));
  Assert.AreEqual(PLAIN, LText);
end;

procedure TEFXMLTests.ClearXmlNameSpaces_WithAPrefixedDeclaration_LeavesItAlone;
var
  LText: string;
begin
  LText := '<p:root xmlns:p="urn:a" xmlns="urn:b">x</p:root>';
  Assert.IsTrue(ClearXmlNameSpaces(LText));
  Assert.AreEqual('<p:root xmlns:p="urn:a" >x</p:root>', LText);
end;

procedure TEFXMLTests.ClearDOCTYPE_RemovesTheDeclaration;
var
  LText: string;
begin
  LText := '<!DOCTYPE root SYSTEM "r.dtd"><root>x</root>';
  Assert.IsTrue(ClearDOCTYPE(LText));
  Assert.AreEqual('<root>x</root>', LText);
end;

procedure TEFXMLTests.ClearDOCTYPE_WithInternalSubset_RemovesTheWholeDeclaration;
var
  LText: string;
begin
  LText := '<!DOCTYPE root [<!ELEMENT root (#PCDATA)>]><root>x</root>';
  Assert.IsTrue(ClearDOCTYPE(LText));
  Assert.AreEqual('<root>x</root>', LText);
end;

procedure TEFXMLTests.ClearDOCTYPE_WithGreaterThanInASystemLiteral_RemovesTheWholeDeclaration;
var
  LText: string;
begin
  LText := '<!DOCTYPE root SYSTEM "a>b.dtd"><root>x</root>';
  Assert.IsTrue(ClearDOCTYPE(LText));
  Assert.AreEqual('<root>x</root>', LText);
end;

procedure TEFXMLTests.ClearDOCTYPE_AfterAComment_RemovesTheDeclarationAndKeepsTheComment;
var
  LText: string;
begin
  LText := '<!-- generated: a > b --><!DOCTYPE root SYSTEM "r.dtd"><root>x</root>';
  Assert.IsTrue(ClearDOCTYPE(LText));
  Assert.AreEqual('<!-- generated: a > b --><root>x</root>', LText);
end;

procedure TEFXMLTests.ClearDOCTYPE_WithoutADOCTYPE_ReturnsFalse;
const
  PLAIN = '<root>x</root>';
var
  LText: string;
begin
  LText := PLAIN;
  Assert.IsFalse(ClearDOCTYPE(LText));
  Assert.AreEqual(PLAIN, LText);
end;

procedure TEFXMLTests.ClearXMLHeader_RemovesOnlyTheDeclaration;
var
  LText: string;
begin
  LText := XMLHeader + '<root>x</root>';
  Assert.IsTrue(ClearXMLHeader(LText));
  Assert.AreEqual('<root>x</root>', LText);
end;

procedure TEFXMLTests.ClearXMLHeader_WithTextBeforeTheDeclaration_KeepsIt;
var
  LText: string;
begin
  LText := '<!-- a > b -->' + XMLHeader + '<root>x</root>';
  Assert.IsTrue(ClearXMLHeader(LText));
  Assert.AreEqual('<!-- a > b --><root>x</root>', LText);
end;

procedure TEFXMLTests.ClearXMLHeader_WithoutADeclaration_ReturnsFalse;
const
  PLAIN = '<root>x</root>';
var
  LText: string;
begin
  LText := PLAIN;
  Assert.IsFalse(ClearXMLHeader(LText));
  Assert.AreEqual(PLAIN, LText);
end;

procedure TEFXMLTests.NodeToXMLValue_WithAnXMLDocumentValue_EmbedsItWellFormed;
var
  LNode: TEFNode;
  LFormatSettings: TFormatSettings;
  LResult: string;
begin
  LFormatSettings := TFormatSettings.Create;
  LNode := TEFNode.Create('Doc');
  try
    LNode.AsString := XMLHeader + '<!DOCTYPE root SYSTEM "r.dtd">' +
      '<root xmlns="urn:example"><a>1</a></root>';
    LResult := LNode.DataType.NodeToXMLValue(False, LNode, LFormatSettings);
    Assert.AreEqual('<Doc><root ><a>1</a></root></Doc>', LResult);
  finally
    LNode.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TEFXMLTests);

end.
