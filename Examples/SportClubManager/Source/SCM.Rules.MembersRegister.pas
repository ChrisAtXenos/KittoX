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

/// <summary>Business rules of the members' book: consistency checks before a member row
/// is written.</summary>
unit SCM.Rules.MembersRegister;

interface

uses
  Kitto.Rules, Kitto.Store, Kitto.Metadata.ModelImplementation, Kitto.Metadata.DataView,
  Data.DB, Kitto.Web.Session;

type
//----------------------- MODEL RULES

  TMembersRegisterCheck = class(TKRuleImpl)
  strict protected
    procedure BeforeAddOrUpdate(const ARecord: TKRecord); override;
  end;

implementation

uses
  EF.Localization;

{ TMembersRegisterCheck }

procedure TMembersRegisterCheck.BeforeAddOrUpdate(const ARecord: TKRecord);
begin
  inherited;
  if not ARecord.FieldByName('RejectionDate').IsNull then
    if ARecord.FieldByName('RejectionReason').IsNull then
      RaiseError(_('Warning: a reason is required when the member is rejected'));
end;

initialization
  TKRuleImplRegistry.Instance.RegisterClass(TMembersRegisterCheck.GetClassId, TMembersRegisterCheck);

finalization
  TKRuleImplRegistry.Instance.UnregisterClass(TMembersRegisterCheck.GetClassId);

end.
