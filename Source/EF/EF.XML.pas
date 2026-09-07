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

///	<summary>
///	 Support for XML format.
///	</summary>
unit EF.XML;

{$I EF.Defines.inc}

interface

uses
  System.SysUtils,
  System.StrUtils,
  EF.Types;

const
  /// <summary>
  ///   Standard XML declaration header (UTF-8).
  /// </summary>
  XMLHeader = '<?xml version="1.0" encoding="UTF-8" ?>';
  /// <summary>
  ///   Format string for an XML element: tag name, content, tag name.
  /// </summary>
  XMLTagFormat = '<%s>%s</%s>';
  /// <summary>
  ///   Opening text of a DOCTYPE declaration.
  /// </summary>
  DocTypeHeader = '<!DOCTYPE';
  /// <summary>
  ///   Opening text of an xmlns namespace attribute.
  /// </summary>
  XmlNameSpace = 'xmlns="';

/// <summary>
///   Escapes control characters in the XML string.
/// </summary>
function XMLEscape(const AString: string): string;

/// <summary>
///   Clear the XMLHeader from an XML string.
///   Returns true if the header was found and cleared
/// </summary>
function ClearXMLHeader(var AText: string): Boolean;

/// <summary>
///   Returns the position of the XMLHeader if found
/// </summary>
function XMLHeaderPos(const AText: string): Integer;

/// <summary>
///   Clear the DOCTYPE node from an XML string.
///   Returns true if the DOCTYPE node was found and cleared
/// </summary>
function ClearDOCTYPE(var Text: string): boolean;

/// <summary>
///   Removes every default namespace declaration (xmlns="...") from an XML
///   string. Namespace declarations bound to a prefix (xmlns:p="...") are left
///   alone: the pattern searched for is xmlns=" and does not match them.
///   Returns true if at least one declaration was found and removed.
/// </summary>
function ClearXmlNameSpaces(var Text: string): boolean;

implementation

uses
  System.NetEncoding,
  EF.StrUtils;

function XMLEscape(const AString: string): string;
begin
  Result := TNetEncoding.HTML.Encode(AString);
end;

function XMLHeaderPos(const AText: string): Integer;
begin
  Result := Pos(Copy(XMLHeader, 1, 36), AText);
end;

function ClearXMLHeader(var AText: string): Boolean;
var
  LXmlHeaderPos, LClosedTagPos: Integer;
begin
  Result := False;
  LXmlHeaderPos := XMLHeaderPos(AText);
  if LXmlHeaderPos > 0 then
  begin
    // Search from the declaration, not from the start of the text: the first
    // '>' of the whole string is not necessarily the one that closes it. And
    // keep whatever precedes the declaration instead of discarding it, which
    // is what cutting from position 1 did.
    LClosedTagPos := PosEx('>', AText, LXmlHeaderPos);
    if LClosedTagPos > 0 then
    begin
      AText := Copy(AText, 1, LXmlHeaderPos - 1) +
        Copy(AText, LClosedTagPos + 1, MaxInt);
      Result := True;
    end;
  end;
end;

/// <summary>
///  Returns the position of the '>' that closes the DOCTYPE declaration
///  starting at AStart, or 0 if the declaration is not terminated.
///  A plain search for the first '>' is not enough: a SYSTEM or PUBLIC literal
///  may contain one, and so does every declaration of the internal subset
///  between '[' and ']'.
/// </summary>
function DOCTYPEEndPos(const AText: string; const AStart: Integer): Integer;
var
  I: Integer;
  LQuote: Char;
  LInSubset: Boolean;
begin
  Result := 0;
  LQuote := #0;
  LInSubset := False;
  for I := AStart to Length(AText) do
  begin
    if LQuote <> #0 then
    begin
      if AText[I] = LQuote then
        LQuote := #0;
    end
    else if CharInSet(AText[I], ['"', '''']) then
      LQuote := AText[I]
    else if AText[I] = '[' then
      LInSubset := True
    else if AText[I] = ']' then
      LInSubset := False
    else if (AText[I] = '>') and not LInSubset then
    begin
      Result := I;
      Break;
    end;
  end;
end;

function ClearDOCTYPE(var Text: string): boolean;
var
  LDOCTYPEPos, LClosedTagPos: Integer;
begin
  Result := False;
  LDOCTYPEPos := Pos(DocTypeHeader, Text);
  if LDOCTYPEPos > 0 then
  begin
    // The end of THIS declaration, not the first '>' of the text. Looking for
    // the latter cut in the wrong place whenever anything carrying a '>' came
    // before the DOCTYPE (a comment, an XML declaration still in place), and
    // whenever the declaration itself contained one -- inside a SYSTEM literal
    // or in the internal subset -- leaving broken remains such as ']>' at the
    // front of the document while reporting success.
    LClosedTagPos := DOCTYPEEndPos(Text, LDOCTYPEPos);
    if LClosedTagPos > 0 then
    begin
      Text := Copy(Text, 1, LDOCTYPEPos - 1) +
        Copy(Text, LClosedTagPos + 1, MaxInt);
      Result := True;
    end;
  end;
end;

function ClearXmlNameSpaces(var Text: string): boolean;
var
  LPos, LQuotePos: Integer;
begin
  Result := False;
  LPos := Pos(XmlNameSpace, Text);
  while LPos > 0 do
  begin
    // Absolute position of the quote that closes the attribute value. The old
    // code folded a relative offset into an absolute one -- Pos of '"' in a
    // copy starting at LPos + Length(XmlNameSpace), plus LPos - 1 -- which is
    // seven short of the real position, and then cut two characters past that.
    // The two errors cancelled out for LPos = 6 and nowhere else, so the cut
    // drifted by LPos - 6 characters: it ate the '>' of the element it was
    // cleaning, and part of the content for any longer element name.
    LQuotePos := PosEx('"', Text, LPos + Length(XmlNameSpace));
    if LQuotePos = 0 then
      // Unterminated attribute value: there is no sane place to cut, so leave
      // the text as it is. The former guard tested LClosedBraket > 0, which was
      // LPos - 1 in this case and therefore true for any LPos > 1: it cut
      // anyway, at a position that meant nothing.
      Break;
    Delete(Text, LPos, LQuotePos - LPos + 1);
    Result := True;
    // Iteratively, not by recursion: the old version went one stack level
    // deeper per namespace declaration in the document.
    LPos := PosEx(XmlNameSpace, Text, LPos);
  end;
end;

end.
