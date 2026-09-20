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

/// <summary>Business rules of the customer and supplier model: administrative office
/// flag, registry data derived from the tax code and consistency checks.</summary>
unit SCM.Rules.CustomerSupplier;

interface

uses
  Kitto.Rules, KItto.Store;

type

///--- FIELD RULES
  TCustomerSupplierSetAdminOfficeFlag = class(TKRuleImpl)
  public
    procedure AfterFieldChange(const AField: TKField; const AOldValue, ANewValue: Variant); override;
  end;

  TCustomerSupplierSetDataFromTaxCode = class(TKRuleImpl)
  public
    procedure AfterFieldChange(const AField: TKField; const AOldValue, ANewValue: Variant); override;
  end;


///--- MODEL RULES
  TCustomerSupplierCheck = class(TKRuleImpl)
  strict protected
    procedure BeforeAddOrUpdate(const ARecord: TKRecord); override;
  public
    procedure NewRecord(const ARecord: TKRecord); override;
  end;


implementation

uses
  System.SysUtils
  , Kitto.Config
  , Data.DB
  , EF.DB
  , SCM.DbUtils, Kitto.DbUtils
  , EF.Localization;

{ TCustomerSupplierSetAdminOfficeFlag }

procedure TCustomerSupplierSetAdminOfficeFlag.AfterFieldChange(const AField: TKField;
  const AOldValue, ANewValue: Variant);
begin
  inherited;
  if AField.Name = 'AdminAddressSameAsRegistered' then
  begin
    if AField.AsBoolean then
    begin
      AField.ParentRecord.FieldByName('AdminAddress').AsString := AField.ParentRecord.FieldByName('Address').AsString;
      AField.ParentRecord.FieldByName('AdminPostalCode').AsString := AField.ParentRecord.FieldByName('PostalCode').AsString;
      AField.ParentRecord.FieldByName('AdminMunicipalityId').AsString := AField.ParentRecord.FieldByName('MunicipalityId').AsString;
      AField.ParentRecord.FieldByName('AdminProvinceId').AsString := AField.ParentRecord.FieldByName('ProvinceId').AsString;
    end;
  end;
end;

{ TCustomerSupplierCheck }

procedure TCustomerSupplierCheck.BeforeAddOrUpdate(const ARecord: TKRecord);
begin
  inherited;
  if ARecord.FieldByName('LegalForm_RequiresTaxCode').AsBoolean then
  begin
    if ARecord.FieldByName('TaxCode').IsNull then
      RaiseError(_('Tax code is required.'));
  end;
  if ARecord.FieldByName('LegalForm_RequiresVatNumber').AsBoolean then
  begin
    if ARecord.FieldByName('VatNumber').IsNull then
      RaiseError(_('VAT number is required.'));
  end;
  if ARecord.FieldByName('LegalForm_IsNaturalPerson').AsBoolean then
  begin
    if ARecord.FieldByName('LastName').IsNull then
      RaiseError(_('Last name is required.'));
    if ARecord.FieldByName('FirstName').IsNull then
      RaiseError(_('First name is required.'));
  end;
end;

procedure TCustomerSupplierCheck.NewRecord(const ARecord: TKRecord);
var
  IdProgress : string;
begin
  inherited;
  if ModelByRecord(ARecord).ModelName = 'Customer' then
    IdProgress := 'TISCliente'
  else
    IdProgress := 'TISFornitore';

  ARecord.FieldByName('Id').AsString := CalcNewProgress(IdProgress, 10);
end;

{ TCustomerSupplierSetDataFromTaxCode }

procedure TCustomerSupplierSetDataFromTaxCode.AfterFieldChange(const AField: TKField;
  const AOldValue, ANewValue: Variant);
var
  LQuery: TEFDBQuery;
  LCommandText: string;

  procedure AssignFieldValue(const AFieldName: string; AFieldValue: Variant);
  var
    LField: TKField;
  begin
    LField := AField.ParentRecord.FindField(AFieldName);
    if Assigned(LField) then
      LField.Value := AFieldValue;
  end;

begin
  inherited;
  if SameText(AField.Name,'TaxCode') and not AField.IsNull then
  begin

    //Read the data when the person is already in the registry
    Try
      LCommandText := 'SELECT ID, COGNOME, NOME, TELEFONO, CELLULARE, EMAIL, INDIRIZZO, CAP, '+
                      'PROVINCIAID, COMUNEID, DATANASC, LUOGONASCID, PROVNASCID, SESSO, NAZIONALITAID, IBAN '+
                      'FROM NOMINATIVI WHERE CODFISC = :ID';
      LQuery := TKConfig.Database.CreateDBQuery;
      LQuery.CommandText := LCommandText;
      try
        LQuery.Params.ParamByName('ID').AsString := ANewValue;
        LQuery.Open;
        if not LQuery.DataSet.IsEmpty then
        begin
          AssignFieldValue('LastName', LQuery.DataSet.FieldByName('COGNOME').AsString);
          AssignFieldValue('FirstName', LQuery.DataSet.FieldByName('NOME').AsString);
          AssignFieldValue('Phone', LQuery.DataSet.FieldByName('TELEFONO').AsString);
          AssignFieldValue('Mobile', LQuery.DataSet.FieldByName('CELLULARE').AsString);
          AssignFieldValue('Email', LQuery.DataSet.FieldByName('EMAIL').AsString);
          AssignFieldValue('Address', LQuery.DataSet.FieldByName('INDIRIZZO').AsString);
          AssignFieldValue('PostalCode', LQuery.DataSet.FieldByName('CAP').AsString);
          AssignFieldValue('MunicipalityId', LQuery.DataSet.FieldByName('COMUNEID').AsString);
          AssignFieldValue('ProvinceId', LQuery.DataSet.FieldByName('PROVINCIAID').AsString);
          AssignFieldValue('AdminAddressSameAsRegistered', True);
          AssignFieldValue('AdminAddress', LQuery.DataSet.FieldByName('INDIRIZZO').AsString);
          AssignFieldValue('AdminPostalCode', LQuery.DataSet.FieldByName('CAP').AsString);
          AssignFieldValue('AdminMunicipalityId', LQuery.DataSet.FieldByName('COMUNEID').AsString);
          AssignFieldValue('AdminProvinceId', LQuery.DataSet.FieldByName('PROVINCIAID').AsString);
          AssignFieldValue('Iban', LQuery.DataSet.FieldByName('IBAN').AsString);

        end;
      finally
        LQuery.Close;
      end;
    finally
      FreeAndNil(LQuery);
    end;
  end;
end;

initialization
  TKRuleImplRegistry.Instance.RegisterClass(TCustomerSupplierSetAdminOfficeFlag.GetClassId, TCustomerSupplierSetAdminOfficeFlag);
  TKRuleImplRegistry.Instance.RegisterClass(TCustomerSupplierCheck.GetClassId, TCustomerSupplierCheck);
  TKRuleImplRegistry.Instance.RegisterClass(TCustomerSupplierSetDataFromTaxCode.GetClassId, TCustomerSupplierSetDataFromTaxCode);

finalization
  TKRuleImplRegistry.Instance.UnregisterClass(TCustomerSupplierSetAdminOfficeFlag.GetClassId);
  TKRuleImplRegistry.Instance.UnregisterClass(TCustomerSupplierCheck.GetClassId);
  TKRuleImplRegistry.Instance.UnregisterClass(TCustomerSupplierSetDataFromTaxCode.GetClassId);

end.
