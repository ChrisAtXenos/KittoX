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

/// <summary>Business rules of the federation registration model: generation of the next
/// membership card number.</summary>
unit SCM.Rules.FederationRegistration;

interface

uses
  Kitto.Rules, KItto.Store;

type

///--- MODEL RULES
  //Model rule: generate the next card number
  TGenerateNewCardNumber = class(TKRuleImpl)
  public
    procedure NewRecord(const ARecord: TKRecord); override;
  end;

implementation

uses
  System.SysUtils
  , System.StrUtils
  , System.Variants
  , Data.DB
  , EF.Localization
  , EF.VariantUtils
  , EF.DB
  , EF.StrUtils
  , Kitto.Config
  , Kitto.Metadata.DataView
  , SCM.DbUtils
  , SCM.Utils;

{ TGenerateNewCardNumber }

procedure TGenerateNewCardNumber.NewRecord(const ARecord: TKRecord);
var
  LQueryLen, LQueryNumb, LNumb: string;
  LLen: integer;
begin
  LQueryNumb := 'SELECT COALESCE(MAX(CAST(TESSERA AS INT)),0)+1 FROM TESSERAMENTI';
  LQueryLen := 'SELECT MAX(LEN(TESSERA)) FROM TESSERAMENTI';
  LNumb:= EFVarToStr(TKConfig.Database.GetSingletonValue(LQueryNumb));
  LLen:= EFVarToInt(TKConfig.Database.GetSingletonValue(LQueryLen));
  ARecord.FieldByName('TESSERA').AsString := PadLeft(LNumb,LLen,'0');
end;

initialization
  TKRuleImplRegistry.Instance.RegisterClass(TGenerateNewCardNumber.GetClassId, TGenerateNewCardNumber);

finalization
  TKRuleImplRegistry.Instance.UnregisterClass(TGenerateNewCardNumber.GetClassId);

end.