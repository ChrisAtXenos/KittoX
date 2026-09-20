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

/// <summary>Business rules of the people registry: consistency checks before a person row
/// is written.</summary>
unit SCM.Rules.Person;

interface

uses
  Kitto.Rules, Kitto.Store, Kitto.Metadata.ModelImplementation, Kitto.Metadata.DataView,
  Data.DB, Kitto.Web.Session;

type
//----------------------- MODEL RULES

  TPersonCheck = class(TKRuleImpl)
  strict protected
    procedure BeforeAddOrUpdate(const ARecord: TKRecord); override;
  end;


implementation

uses
  EF.Localization, EF.StrUtils, DateUtils,
  Kitto.Metadata.Models,
  EF.DB, Kitto.Config,  System.Variants,
  SysUtils, EF.Macros, EF.VariantUtils, EF.SQL, SCM.Utils, SCM.DbUtils
  ;


procedure TPersonCheck.BeforeAddOrUpdate(const ARecord: TKRecord);
begin
  inherited;
  if PersonExistsByTaxCode(ARecord.FieldByName('TaxCode').AsString, ARecord.FieldByName('Id').AsString) then
    RaiseError(_('Tax code already on file - use the existing person'));

  ARecord.FieldByName('Description').AsString := ARecord.FieldByName('LastName').AsString + ' ' + ARecord.FieldByName('FirstName').AsString + ' (' + ARecord.FieldByName('TaxCode').AsString + ')';
end;


initialization
  TKRuleImplRegistry.Instance.RegisterClass(TPersonCheck.GetClassId, TPersonCheck);

finalization
  TKRuleImplRegistry.Instance.UnregisterClass(TPersonCheck.GetClassId);

end.
