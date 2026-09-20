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

/// <summary>Business rules of the medical visit model: expiry date derived from the visit
/// date, and the check for a valid certificate at a given date.</summary>
unit SCM.Rules.MedicalVisit;

interface

uses
  Kitto.Rules, KItto.Store, EF.VariantUtils, Kitto.Config, SCM.Utils;

type
  //Field rules for the performed flag
  TMedicalVisitSetPerformed = class(TKRuleImpl)
  public
    procedure AfterFieldChange(const AField: TKField; const AOldValue, ANewValue: Variant); override;
  end;

  //Check rules
  TMedicalVisitCheck = class(TKRuleImpl)
  strict protected
    procedure AfterAddOrUpdate(const ARecord: TKRecord); override;
    procedure BeforeAddOrUpdate(const ARecord: TKRecord); override;
  end;

  function ValidMedicalVisitExistsAt(APersonId: string; ADate: TdateTime; AVisitTypeId: string = ''): boolean ;

implementation

uses
  System.DateUtils
  , System.SysUtils
  , EF.Localization;

{ TMedicalVisitSetPerformed }

procedure TMedicalVisitSetPerformed.AfterFieldChange(const AField: TKField;
  const AOldValue, ANewValue: Variant);
begin
  inherited;
  if (AField.Name = 'Performed') or (AField.Name = 'VisitDate') then
  begin
    AField.ParentRecord.FieldByName('ExpiryDate').SetToNull;
    if AField.ParentRecord.FieldByName('Performed').AsBoolean then
      if not AField.ParentRecord.FieldByName('VisitDate').isNull then
        AField.ParentRecord.FieldByName('ExpiryDate').asDate := IncYear(AField.ParentRecord.FieldByName('VisitDate').asDate, 1);
  end;
end;

{ TMedicalVisitCheck }

procedure TMedicalVisitCheck.AfterAddOrUpdate(const ARecord: TKRecord);
begin
  inherited;
  if ARecord.FieldByName('Fitness').asBoolean and not ARecord.FieldByName('Performed').asBoolean then
    RaiseError(_('The fitness outcome is inconsistent with the visit being marked as carried out.'));
  if ARecord.FieldByName('Person').isNull and not ARecord.FieldByName('NotificationDate').isNull then
    RaiseError(_('The person is required when a notification date is set'));
  if ARecord.FieldByName('Person').isNull and ARecord.FieldByName('Performed').asBoolean then
    RaiseError(_('The person is required when the visit is marked as carried out'));
  if ARecord.FieldByName('Fitness').asBoolean and ARecord.FieldByName('DocumentFile').isNull then
    RaiseError(_('Upload the certificate scan'));
end;

function ValidMedicalVisitExistsAt(APersonId: string; ADate: TdateTime; AVisitTypeId: string = ''): boolean ;
var
  LCommandText: string;
begin
  LCommandText :=  'SELECT COUNT(*) FROM VISITEMEDICHE '+
                   ' WHERE NOMINATIVOID  = ''' + APersonId + '''' +
                   ' AND EFFETTUATA = ''1'''+
                   ' AND SCADENZA > ''' + DateToCompactStr(ADate) + '''';
  if AVisitTypeId <> '' then
    LCommandText := LCommandText + ' AND TPVISITAID = ''' + AVisitTypeId + '''';
  Result := EFVarToInt(TKConfig.Database.GetSingletonValue(LCommandText)) > 0;

end;

procedure TMedicalVisitCheck.BeforeAddOrUpdate(const ARecord: TKRecord);
begin
  inherited;
  if IsLoggedUserAMember() then
  begin
    if ARecord.FieldByName('NotificationDate').isNull then
       ARecord.FieldByName('NotificationDate').AsDateTime := now;
    if ARecord.FieldByName('Fitness').isNull then
       ARecord.FieldByName('Fitness').AsBoolean := False;
    if ARecord.FieldByName('Performed').isNull then
       ARecord.FieldByName('Performed').AsBoolean := False
  end;
end;

initialization
  TKRuleImplRegistry.Instance.RegisterClass(TMedicalVisitSetPerformed.GetClassId, TMedicalVisitSetPerformed);
  TKRuleImplRegistry.Instance.RegisterClass(TMedicalVisitCheck.GetClassId, TMedicalVisitCheck);
finalization
  TKRuleImplRegistry.Instance.UnregisterClass(TMedicalVisitSetPerformed.GetClassId);
  TKRuleImplRegistry.Instance.UnregisterClass(TMedicalVisitCheck.GetClassId);

end.
