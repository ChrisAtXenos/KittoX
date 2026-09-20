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

/// <summary>General-purpose business rules available to every model: id and description
/// calculation, duplicate and range checks, Italian tax code and VAT number
/// validation, IBAN check and password strength.</summary>
unit SCM.Rules;

interface

uses
  Kitto.Rules
  , KItto.Store;

type
  TCheckCondition = (ccLower, ccGreather, ccLowerOrEqual, ccGreatherOrEqual);

  //Model rule: generate a new Id
  //  GenerateNewId:
  //    CharSize: n (default n = 0)
  TGenerateNewId = class(TKRuleImpl)
  public
    procedure NewRecord(const ARecord: TKRecord); override;
  end;

  //Field rule: check that the value is not already in the database
  TCheckFieldDupValue = class(TKRuleImpl)
  public
    procedure AfterFieldChange(const AField: TKField; const AOldValue, ANewValue: Variant); override;
  end;

  //Field rule that computes the description
  TCalcDescription = class(TKRuleImpl)
  public
    procedure AfterFieldChange(const AField: TKField; const AOldValue, ANewValue: Variant); override;
  end;

  //Rule that checks the percentage bounds
  TCheckPercentage = class(TKRuleImpl)
  public
    procedure AfterFieldChange(const AField: TKField; const AOldValue, ANewValue: Variant); override;
  end;

  //Field rule that computes the id
  TCalcId = class(TKRuleImpl)
  public
    procedure AfterFieldChange(const AField: TKField; const AOldValue, ANewValue: Variant); override;
  end;

  // rule that computes province and postal code
  TCalcProvince = class(TKRuleImpl)
  public
    procedure AfterFieldChange(const AField: TKField; const AOldValue, ANewValue: Variant); override;
  end;

  // rule that computes the country
  TCalcCountry = class(TKRuleImpl)
  public
    procedure AfterFieldChange(const AField: TKField; const AOldValue, ANewValue: Variant); override;
  end;

  // rule that fills the registry data from the tax code
  TSetRegistryDataFromTaxCode = class(TKRuleImpl)
  public
    procedure AfterFieldChange(const AField: TKField; const AOldValue, ANewValue: Variant); override;
  end;

  // rule that checks the password strength
  TCheckPasswordStrength = class(TKRuleImpl)
  public
    procedure AfterFieldChange(const AField: TKField; const AOldValue, ANewValue: Variant); override;
  end;

  // rule that checks the current field is greater than the given one
  TGreaterThan = class(TKRuleImpl)
  public
    procedure AfterFieldChange(const AField: TKField; const AOldValue, ANewValue: Variant); override;
  end;

  // rule that checks the current field is greater than or equal to the given one
  TGreaterOrEqualThan = class(TKRuleImpl)
  public
    procedure AfterFieldChange(const AField: TKField; const AOldValue, ANewValue: Variant); override;
  end;

  // rule that checks the current field is lower than the given one
  TLowerThan = class(TKRuleImpl)
  public
    procedure AfterFieldChange(const AField: TKField; const AOldValue, ANewValue: Variant); override;
  end;

  // rule that checks the current field is lower than or equal to the given one
  TLowerOrEqualThan = class(TKRuleImpl)
  public
    procedure AfterFieldChange(const AField: TKField; const AOldValue, ANewValue: Variant); override;
  end;

  ///--- MODEL RULES
  //model rule that checks the registry data against the tax code
  TCheckRegistryDataAgainstTaxCode = class(TKRuleImpl)
  strict protected
    procedure BeforeAddOrUpdate(const ARecord: TKRecord); override;
  end;

  //model rule that checks the tax code format
  TCheckTaxCodeFormat = class(TKRuleImpl)
  public
    procedure AfterFieldChange(const AField: TKField; const AOldValue, ANewValue: Variant); override;
  end;

  //model rule that checks the tax code checksum
  TCheckTaxCodeChecksum = class(TKRuleImpl)
  public
    procedure AfterFieldChange(const AField: TKField; const AOldValue, ANewValue: Variant); override;
  end;

  TCheckIBAN = class(TKRuleImpl)
  public
    procedure AfterFieldChange(const AField: TKField; const AOldValue, ANewValue: Variant); override;
  end;

  TCheckVatNumberFormat = class(TKRuleImpl)
  public
    procedure AfterFieldChange(const AField: TKField; const AOldValue, ANewValue: Variant); override;
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
  , Kitto.Config
  , Kitto.Metadata.DataView
  , SCM.DbUtils, Kitto.DbUtils
  , SCM.Utils;

{ TCheckDuplicateInvitations }

procedure TGenerateNewId.NewRecord(const ARecord: TKRecord);
var
  LProgressiveClass, LId: string;
  LCharSize: Integer;
begin
  inherited;
  //Get a new Id and assign it to the ID field
  LProgressiveClass := ModelByRecord(ARecord).FieldByName('Class').DefaultValue;
  LCharSize := Rule.GetInteger('CharSize', 0);
  LId := CalcNewProgress(LProgressiveClass, LCharSize);
  ARecord.FieldByName('Id').AsString := LId;
end;

{ TCheckFieldDupValue }

procedure TCheckFieldDupValue.AfterFieldChange(const AField: TKField; const AOldValue, ANewValue: Variant);
var
  LIdToExclude: string;
  LTableName: string;
  LFieldName: string;
  LSQLStatement: string;
  LModelPluralDisplayLabel: string;
  LCount: Integer;
begin
  inherited;
  //Check that the entered value does not already exist in the same table
  if VarToStr(ANewValue) <> '' then
  begin
    //Exclude the record itself
    if Rule.GetBoolean('ExcludeCurrentId', True) then
      LIdToExclude := AField.ParentRecord.FieldByName('Id').AsString
    else
      LIdToExclude := '';
    LTableName := GetTableName(AField);
    LFieldName := GetPhysicalName(AField);
    if (LTableName <> '') and (LFieldName <> '') then
    begin
      LSQLStatement := GetSQLCountValue(LTableName, LFieldName, ANewValue, LIdToExclude);
      LCount := EFVarToInt(TKConfig.Database.GetSingletonValue(LSQLStatement));
      if LCount > 0 then
      begin
        //Reject the value because it is a duplicate
        LModelPluralDisplayLabel := ModelByField(AField).PluralDisplayLabel;
        RaiseError(Format(_('Warning: value %s already exists in %s!'),
          [ANewValue, LModelPluralDisplayLabel]));
      end;
    end;
  end;
end;

{ TCalcDescription }

procedure TCalcDescription.AfterFieldChange(const AField: TKField; const AOldValue, ANewValue: Variant);
var
  LExpression: string;
  LDescriptionField: TKField;
begin
  inherited;
  LExpression := Rule.Value;
  AField.ParentRecord.ExpandExpression(LExpression);
  LDescriptionField := AField.ParentRecord.FieldByName('Description');
  LDescriptionField.AsString := LExpression;
end;

{ TCalcProvince }

procedure TCalcProvince.AfterFieldChange(const AField: TKField; const AOldValue, ANewValue: Variant);
var
  LMunicipalityProvince, LMunicipalityPostalCode: string;
  LMunicipalityFieldName, LPostalCodeFieldName, LProvinceIdFieldName: string;
begin
  inherited;
  if AField.Name = 'Municipality' then begin
    LMunicipalityFieldName      := AField.Name;
    LPostalCodeFieldName         := 'PostalCode';
    LProvinceIdFieldName := 'ProvinceId';
  end
  else if AField.Name = 'BirthPlace' then begin
    LMunicipalityFieldName      := AField.Name;
    LPostalCodeFieldName         := '';
    LProvinceIdFieldName := 'BirthProvinceId';
  end
  else if AField.Name = 'AdminMunicipality' then begin
    LMunicipalityFieldName      := AField.Name;
    LPostalCodeFieldName         := 'AdminPostalCode';
    LProvinceIdFieldName := 'AdminProvinceId';
  end;

  if AField.Name = LMunicipalityFieldName then begin
    LMunicipalityProvince := EFVarToStr(GetReferencedModelInstanceValue(LMunicipalityFieldName, 'ProvinceId',  AField.ParentRecord));
    if LMunicipalityProvince <> '' then begin
      AField.ParentRecord.FieldByName(LProvinceIdFieldName).Value :=  LMunicipalityProvince;
      if LPostalCodeFieldName <> '' then
        if (LMunicipalityProvince <> 'EE') then begin
          LMunicipalityPostalCode := EFVarToStr(GetReferencedModelInstanceValue(LMunicipalityFieldName, 'PostalCode',  AField.ParentRecord));
          AField.ParentRecord.FieldByName(LPostalCodeFieldName).Value :=  LMunicipalityPostalCode;
        end;
    end;
  end;
end;

{ TCalcCountry }

procedure TCalcCountry.AfterFieldChange(const AField: TKField; const AOldValue, ANewValue: Variant);
var
  LCountryIdFieldName:  string;
begin
    if AField.Name = 'Province' then
      LCountryIdFieldName   := 'CountryId'
    else
      if AField.Name = 'BirthProvince' then
        LCountryIdFieldName   := 'BirthCountryId';

  if AField.Name = 'BirthProvince' then begin
    if ANewValue <> 'EE' then
      AField.ParentRecord.FieldByName(LCountryIdFieldName).Value :=  'IT'
    else
      AField.ParentRecord.FieldByName(LCountryIdFieldName).Value :=  CountryIdByIstatCode(ANewValue);
  end;
end;

{ TSetRegistryDataFromTaxCode }

procedure TSetRegistryDataFromTaxCode.AfterFieldChange(const AField: TKField; const AOldValue, ANewValue: Variant);
var
  LTaxCode: TKField;
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
    LTaxCode := AField;

    //Read the remaining data when the person is already in the registry
    Try
      LCommandText := 'SELECT ID, COGNOME, NOME, CELLULARE, EMAIL, INDIRIZZO, CAP, '+
                      'PROVINCIAID, COMUNEID, DATANASC, LUOGONASCID, PROVNASCID, SESSO, NAZIONALITAID '+
                      'FROM NOMINATIVI WHERE CODFISC = :ID';
      LQuery := TKConfig.Database.CreateDBQuery;
      LQuery.CommandText := LCommandText;
      try
        LQuery.Params.ParamByName('ID').AsString := ANewValue;
        LQuery.Open;
        if not LQuery.DataSet.IsEmpty then
        begin
          AssignFieldValue('PersonId', LQuery.DataSet.FieldByName('ID').AsString);
          AssignFieldValue('LastName', LQuery.DataSet.FieldByName('COGNOME').AsString);
          AssignFieldValue('FirstName', LQuery.DataSet.FieldByName('NOME').AsString);
          AssignFieldValue('Mobile', LQuery.DataSet.FieldByName('CELLULARE').AsString);
          AssignFieldValue('Email', LQuery.DataSet.FieldByName('EMAIL').AsString);
          AssignFieldValue('Address', LQuery.DataSet.FieldByName('INDIRIZZO').AsString);
          AssignFieldValue('MunicipalityId', LQuery.DataSet.FieldByName('COMUNEID').AsString);
          AssignFieldValue('ProvinceId', LQuery.DataSet.FieldByName('PROVINCIAID').AsString);
          AField.ParentRecord.FieldByName('BirthDate').AsDateTime   := LQuery.DataSet.FieldByName('DATANASC').AsDateTime;
          AField.ParentRecord.FieldByName('Gender').AsString           := LQuery.DataSet.FieldByName('SESSO').AsString;
          AField.ParentRecord.FieldByName('BirthPlaceId').AsString  := LQuery.DataSet.FieldByName('LUOGONASCID').AsString;
          AssignFieldValue('BirthProvinceId', LQuery.DataSet.FieldByName('PROVNASCID').AsString);
          AssignFieldValue('BirthCountryId', LQuery.DataSet.FieldByName('NAZIONALITAID').AsString);
        end
        else
        begin
          AField.ParentRecord.FieldByName('BirthDate').AsDate       := BirthDateFromTaxCode(AField.AsString);
          AField.ParentRecord.FieldByName('Gender').AsString           := GenderFromTaxCode(LTaxCode.AsString);
          AField.ParentRecord.FieldByName('BirthPlaceId').AsString  := BirthPlaceIdFromTaxCode(LTaxCode.AsString);
          AssignFieldValue('BirthProvinceId', BirthProvinceFromTaxCode(LTaxCode.AsString));
          AssignFieldValue('BirthCountryId', BirthCountryFromTaxCode(LTaxCode.AsString));
        end;
      finally
        LQuery.Close;
      end;
    finally
      FreeAndNil(LQuery);
    end;
  end;
end;

{ TCheckTaxCodeChecksum }

procedure TCheckTaxCodeFormat.AfterFieldChange(const AField: TKField;
  const AOldValue, ANewValue: Variant);
begin
  inherited;
  if (AField.Name = 'TaxCode') and not AField.ParentRecord.FieldByName('TaxCode').IsNull then
    if not IsValidTaxCode(AField.ParentRecord.FieldByName('TaxCode').asString) then
      RaiseError(_('Invalid tax code format'));
  if (AField.Name = 'ParentTaxCode') and not AField.ParentRecord.FieldByName('ParentTaxCode').IsNull then
    if not IsValidTaxCode(AField.ParentRecord.FieldByName('ParentTaxCode').asString)  then
      RaiseError(_('Invalid parent tax code format'));
end;

{ TCheckTaxCodeFormat }

procedure TCheckTaxCodeChecksum.AfterFieldChange(const AField: TKField; const AOldValue, ANewValue: Variant);
begin
  inherited;
  if (AField.Name = 'TaxCode') and not AField.ParentRecord.FieldByName('TaxCode').IsNull then
    if not IsValidTaxCodeChecksum(AField.ParentRecord.FieldByName('TaxCode').asString)  then
      RaiseError(_('Invalid tax code checksum'));
  if (AField.Name = 'ParentTaxCode') and not AField.ParentRecord.FieldByName('ParentTaxCode').IsNull then
    if not IsValidTaxCodeChecksum(AField.ParentRecord.FieldByName('ParentTaxCode').asString)  then
      RaiseError(_('Invalid parent tax code checksum'));
end;

{ TCheckRegistryDataAgainstTaxCode }

procedure TCheckRegistryDataAgainstTaxCode.BeforeAddOrUpdate(const ARecord: TKRecord);
var
  LTaxCodeField, LField, LCountryField: TKField;
begin
  inherited;
  LTaxCodeField := ARecord.FindField('TaxCode');
  if Assigned(LTaxCodeField) then
  begin
    //Check the last name
    LField := ARecord.FindField('LastName');
    if Assigned(LField) and not TaxCodeMatchesLastName(Copy(UpperCase(LTaxCodeField.AsString),0,3),
      UpperCase(LField.AsString)) then
        RaiseError(_('The tax code does not match the last name.'));

    //Check the first name
    LField := ARecord.FindField('FirstName');
    if Assigned(LField) and not TaxCodeMatchesFirstName(Copy(UpperCase(LTaxCodeField.AsString),4,3),
      UpperCase(ARecord.FieldByName('FirstName').AsString)) then
        RaiseError(_('The tax code does not match the first name.'));

    //Check the birth date
    LField := ARecord.FindField('BirthDate');
    if Assigned(LField) and (BirthDateFromTaxCode(LTaxCodeField.AsString) <> LField.AsDate) then
        RaiseError(_('The tax code does not match the date of birth.'));

    //Check the birth place
    LField := ARecord.FindField('BirthPlaceId');
    if Assigned(LField) and (BirthPlaceIdFromTaxCode(LTaxCodeField.asString) <> LField.AsString) then
      RaiseError(_('The tax code does not match the place of birth.'));

    //Check the gender
    LField := ARecord.FindField('Gender');
    if Assigned(LField) and (DecodeTaxCodeGender(Copy(LTaxCodeField.asString,10,2)) <> LField.AsString) then
      RaiseError(_('The tax code does not match the gender.'));

    //Check the birth province against the country
    LField := ARecord.FindField('BirthProvinceId');
    LCountryField := ARecord.FindField('BirthCountry_AtCode');
    if Assigned(LField) and Assigned(LCountryField) then
    begin
      if (LField.AsString = 'EE') and(BirthPlaceIdFromTaxCode(LTaxCodeField.AsString) <> LCountryField.AsString) then
        RaiseError(_('The tax code does not match the country of birth.'));
    end;
  end;
end;

{ TCheckPasswordStrength }

procedure TCheckPasswordStrength.AfterFieldChange(const AField: TKField;
  const AOldValue, ANewValue: Variant);
begin
  inherited;
  if AField.AsString <> '' then
    CheckPasswordStrength(AField.Value);
end;

procedure CheckValues(AFirstField, ASecondField: TKField; ACondition: TCheckCondition);
var
  LOK: Boolean;
  LErrorMsg: string;
  LModelFieldDisplayLabel: string;
begin
  if VarIsNull(AFirstField.Value) or VarIsNull(ASecondField.Value) then
    Exit;

  LOK := False;
  case ACondition of
    ccLower: LOK := AFirstField.Value < ASecondField.Value;
    ccGreather: LOK := AFirstField.Value > ASecondField.Value;
    ccLowerOrEqual: LOK := AFirstField.Value <= ASecondField.Value;
    ccGreatherOrEqual: LOK := AFirstField.Value >= ASecondField.Value;
  end;
  if not LOK then
  begin
  case ACondition of
    ccLower: LErrorMsg := _('is not less than');
    ccGreather: LErrorMsg := _('is not greater than');
    ccLowerOrEqual: LErrorMsg := _('is not less than or equal to');
    ccGreatherOrEqual: LErrorMsg := _('is not greater than or equal to');
  end;
  LModelFieldDisplayLabel := ModelFieldByField(ASecondField).DisplayLabel;
    raise Exception.CreateFmt(_('The value %s %s the value %s of field %s'),
      [AFirstField.AsString, LErrorMsg, ASecondField.AsString, LModelFieldDisplayLabel]);
  end;
end;

{ TGreaterThan }

procedure TGreaterThan.AfterFieldChange(const AField: TKField;
  const AOldValue, ANewValue: Variant);
var
  LLowerField: TKField;
begin
  inherited;
  LLowerField := AField.ParentRecord.FindField(Rule.Value);
  if Assigned(LLowerField) then
    CheckValues(AField, LLowerField, ccGreather);
end;

{ TGreaterOrEqualThan }

procedure TGreaterOrEqualThan.AfterFieldChange(const AField: TKField;
  const AOldValue, ANewValue: Variant);
var
  LLowerField: TKField;
begin
  inherited;
  LLowerField := AField.ParentRecord.FindField(Rule.Value);
  if Assigned(LLowerField) then
    CheckValues(AField, LLowerField, ccGreatherOrEqual);
end;

{ TLowerThan }

procedure TLowerThan.AfterFieldChange(const AField: TKField;
  const AOldValue, ANewValue: Variant);
var
  LGreatherField: TKField;
begin
  inherited;
  LGreatherField := AField.ParentRecord.FindField(Rule.Value);
  if Assigned(LGreatherField) then
    CheckValues(AField, LGreatherField, ccLower);
end;

{ TLowerOrEqualThan }

procedure TLowerOrEqualThan.AfterFieldChange(const AField: TKField;
  const AOldValue, ANewValue: Variant);
var
  LGreatherField: TKField;
begin
  inherited;
  LGreatherField := AField.ParentRecord.FindField(Rule.Value);
  if Assigned(LGreatherField) then
    CheckValues(AField, LGreatherField, ccLowerOrEqual);
end;

{ TCheckIBAN }

procedure TCheckIBAN.AfterFieldChange(const AField: TKField; const AOldValue,
  ANewValue: Variant);
var
  ErrMsg : string;
begin
  inherited;
  if (AField.Name = 'Iban') and not AField.ParentRecord.FieldByName('Iban').IsNull then
    if not ValidateIban(AField.ParentRecord.FieldByName('Iban').asString, ErrMsg)  then
      RaiseError(_(ErrMsg));
end;

{ TCheckVatNumberFormat }

procedure TCheckVatNumberFormat.AfterFieldChange(const AField: TKField;
  const AOldValue, ANewValue: Variant);
begin
  inherited;
  if (AField.Name = 'VatNumber') and not AField.ParentRecord.FieldByName('VatNumber').IsNull then
    if not IsValidVatNumber(AField.ParentRecord.FieldByName('VatNumber').asString)  then
      RaiseError(_('Invalid VAT number format'));
end;

{ TCalcId }

procedure TCalcId.AfterFieldChange(const AField: TKField; const AOldValue,
  ANewValue: Variant);
var
  LExpression: string;
  LDescriptionField: TKField;
begin
  inherited;
  LExpression := Rule.Value;
  AField.ParentRecord.ExpandExpression(LExpression);
  LDescriptionField := AField.ParentRecord.FieldByName('Id');
  LDescriptionField.AsString := LExpression;
end;

{ TCheckPercentage }

procedure TCheckPercentage.AfterFieldChange(const AField: TKField;
  const AOldValue, ANewValue: Variant);
begin
  inherited;
  if AField.AsFloat > 100 then
    begin
      RaiseError(_('The percentage value must not exceed 100'));
    end;
  if AField.AsFloat < 0 then
    begin
      RaiseError(_('The percentage value must not be lower than 0'));
    end;
end;

initialization
  TKRuleImplRegistry.Instance.RegisterClass(TGenerateNewId.GetClassId, TGenerateNewId);
  TKRuleImplRegistry.Instance.RegisterClass(TCheckFieldDupValue.GetClassId, TCheckFieldDupValue);
  TKRuleImplRegistry.Instance.RegisterClass(TCalcDescription.GetClassId, TCalcDescription);
  TKRuleImplRegistry.Instance.RegisterClass(TCalcId.GetClassId, TCalcId);
  TKRuleImplRegistry.Instance.RegisterClass(TCalcProvince.GetClassId, TCalcProvince);
  TKRuleImplRegistry.Instance.RegisterClass(TCalcCountry.GetClassId, TCalcCountry);
  TKRuleImplRegistry.Instance.RegisterClass(TCheckRegistryDataAgainstTaxCode.GetClassId, TCheckRegistryDataAgainstTaxCode);
  TKRuleImplRegistry.Instance.RegisterClass(TSetRegistryDataFromTaxCode.GetClassId, TSetRegistryDataFromTaxCode);
  TKRuleImplRegistry.Instance.RegisterClass(TCheckPasswordStrength.GetClassId, TCheckPasswordStrength);
  TKRuleImplRegistry.Instance.RegisterClass(TCheckTaxCodeFormat.GetClassId, TCheckTaxCodeFormat);
  TKRuleImplRegistry.Instance.RegisterClass(TCheckTaxCodeChecksum.GetClassId, TCheckTaxCodeChecksum);
  TKRuleImplRegistry.Instance.RegisterClass(TGreaterThan.GetClassId, TGreaterThan);
  TKRuleImplRegistry.Instance.RegisterClass(TGreaterOrEqualThan.GetClassId, TGreaterOrEqualThan);
  TKRuleImplRegistry.Instance.RegisterClass(TLowerThan.GetClassId, TLowerThan);
  TKRuleImplRegistry.Instance.RegisterClass(TLowerOrEqualThan.GetClassId, TLowerOrEqualThan);
  TKRuleImplRegistry.Instance.RegisterClass(TCheckIBAN.GetClassId, TCheckIBAN);
  TKRuleImplRegistry.Instance.RegisterClass(TCheckVatNumberFormat.GetClassId, TCheckVatNumberFormat);
  TKRuleImplRegistry.Instance.RegisterClass(TCheckPercentage.GetClassId, TCheckPercentage);
finalization
  TKRuleImplRegistry.Instance.UnregisterClass(TGenerateNewId.GetClassId);
  TKRuleImplRegistry.Instance.UnregisterClass(TCheckFieldDupValue.GetClassId);
  TKRuleImplRegistry.Instance.UnregisterClass(TCalcDescription.GetClassId);
  TKRuleImplRegistry.Instance.UnregisterClass(TCalcId.GetClassId);
  TKRuleImplRegistry.Instance.UnregisterClass(TCalcProvince.GetClassId);
  TKRuleImplRegistry.Instance.UnregisterClass(TCalcCountry.GetClassId);
  TKRuleImplRegistry.Instance.UnregisterClass(TCheckRegistryDataAgainstTaxCode.GetClassId);
  TKRuleImplRegistry.Instance.UnregisterClass(TSetRegistryDataFromTaxCode.GetClassId);
  TKRuleImplRegistry.Instance.UnregisterClass(TCheckPasswordStrength.GetClassId);
  TKRuleImplRegistry.Instance.UnregisterClass(TCheckTaxCodeFormat.GetClassId);
  TKRuleImplRegistry.Instance.UnregisterClass(TCheckTaxCodeChecksum.GetClassId);
  TKRuleImplRegistry.Instance.UnregisterClass(TGreaterThan.GetClassId);
  TKRuleImplRegistry.Instance.UnregisterClass(TGreaterOrEqualThan.GetClassId);
  TKRuleImplRegistry.Instance.UnregisterClass(TLowerThan.GetClassId);
  TKRuleImplRegistry.Instance.UnregisterClass(TLowerOrEqualThan.GetClassId);
  TKRuleImplRegistry.Instance.UnregisterClass(TCheckIBAN.GetClassId);
  TKRuleImplRegistry.Instance.UnregisterClass(TCheckVatNumberFormat.GetClassId);
  TKRuleImplRegistry.Instance.UnregisterClass(TCheckPercentage.GetClassId);

end.
