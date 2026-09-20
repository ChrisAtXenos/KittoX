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

/// <summary>Application-specific macro expander, which adds the macros used by the report
/// templates and by the e-mail texts, such as %NUM2LET(...)%.</summary>
unit SCM.Macros;

interface

uses
  SysUtils
  , Generics.Collections
  , Classes
  , EF.Macros
  , EF.Tree
  , SCM.Utils
  ;


type
  TEFMacroExpansionSCMEngine = class(TEFMacroExpander)
  strict protected
    procedure InternalExpand(var AString: string); override;
  public
    class procedure AddMacroExpander;
  end;


implementation

uses
  System.StrUtils
  , Kitto.Config;

{ TEFMacroExpansionSCMEngine }

class procedure TEFMacroExpansionSCMEngine.AddMacroExpander;
begin
  Assert(Assigned(TKConfig.Instance.MacroExpansionEngine));
  TKConfig.Instance.MacroExpansionEngine.AddExpander(TEFMacroExpansionSCMEngine.Create);
end;

procedure TEFMacroExpansionSCMEngine.InternalExpand(var AString: string);
const
  NUM2LET_MACRO_HEAD = '%NUM2LET(';
  MACRO_TAIL = ')%';
var
  LNumber, LRest, LNumAsChar : string;
  LPosHead : integer;
  LPosTail : integer;
  LParamsCurr : Currency;
begin
  inherited InternalExpand(AString);

  LPosHead := Pos(NUM2LET_MACRO_HEAD, AString);
  if LPosHead > 0 then
  begin
    LPosTail := PosEx(MACRO_TAIL, AString, LPosHead + 1);
    if LPosTail > 0 then
    begin
      LNumber := Copy(AString, LPosHead + Length(NUM2LET_MACRO_HEAD),
        LPosTail - (LPosHead + Length(NUM2LET_MACRO_HEAD)));
      LRest := Copy(AString, LPosTail + Length(MACRO_TAIL), MaxInt);
      InternalExpand(LRest);
      LParamsCurr := StrToCurrDef(LNumber, 0);
      LNumAsChar := Num2Let(LParamsCurr,2);
      Delete(AString, LPosHead, MaxInt);
      Insert(LNumAsChar, AString, Length(AString) + 1);
      Insert(LRest, AString, Length(AString) + 1);
    end;
  end;
end;

end.
