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

/// <summary>Database helpers shared by rules and tools: progressive id generation,
/// single-value queries, model and field metadata lookup, creation of the person,
/// family and family-member rows, existence checks and password strength.</summary>
unit SCM.DbUtils;

interface

uses
  DB
  , KItto.Store
  , Kitto.Metadata.Models
  , EF.Tree;

const
  PROGRESS_STR = 'Progressivo per';
  KINSHIP_MOTHER = 'M';
  KINSHIP_FATHER = 'P';
  KINSHIP_CHILD = 'F';
  STS_ENTERED = 'INS';
  STS_ACTIVE = 'ATT';
  STS_CANCELLED = 'ANN';
  STS_REJECTED = 'RIF';

function InsertOrUpdatePerson(const ASourceRecord: TKRecord; AIsParent : boolean = false): string;
function InsertFamily(const ASourceRecord: TKRecord; const APersonId: string; AIsParent : boolean = false): string; overload;
//Create the family from the data already known about its creator, without going
//through a record: needed by the callers that took the parent from the logged
//user and do not have it among the fields of the record being saved.
function InsertFamily(const ATaxCode, ADescriptionValue, APersonId: string): string; overload;
function InsertFamilyMember(const APersonId, ADescriptionValue, AKinshipId, AFamilyId: string): string;
function InsertParticipantGroup(const ASourceRecord: TKRecord): string;
function PersonExistsByTaxCode(const ATaxCode, AIdToExclude: string): boolean;
function BirthPlaceExists(const AMunicipalityId: string): boolean;
function ActiveUserExists(const ATaxCode: string): boolean;
function UserToActivateExists(const ATaxCode: string): boolean;
function CountryIdByIstatCode(const AIstatCode: string): string;

//functions that extract data from the tax code
function BirthCountryFromTaxCode(const ATaxCode : string) : string;
function BirthProvinceFromTaxCode(const ATaxCode : string) : string;

implementation

uses
  SCM.Utils
  ,RegularExpressions
  ,EF.Localization
  ,Kitto.Metadata.DataView
  ,EF.DB
  ,Kitto.Config
  ,Kitto.Auth.DB
  ,Kitto.Rules
  ,System.SysUtils
  ,EF.StrUtils
  ,System.Variants
  ,EF.VariantUtils
  ,Kitto.DbUtils; // generic helpers (CalcNewProgress, GetSQL*, UpdateParamValue, ...) moved to the framework

function PersonExistsByTaxCode(const ATaxCode, AIdToExclude: string): boolean;
begin
  Result := EFVarToInt(TKConfig.Database.GetSingletonValue(
    'SELECT COUNT(*) FROM NOMINATIVI WHERE ID <> ''' + AIdToExclude + ''' AND CODFISC  = ''' + ATaxCode + '''')) > 0;
end;

function ActiveUserExists(const ATaxCode: string): boolean;
begin
  Result := EFVarToInt(TKConfig.Database.GetSingletonValue(
    'SELECT COUNT(*) FROM APPUSER WHERE ID = ''' + ATaxCode + ''' AND NOT (MUST_CHANGE_PASSWORD = 1 AND ACCESS_DENIED = 1)')) > 0;
end;

function BirthPlaceExists(const AMunicipalityId: string): boolean;
begin
  Result := EFVarToInt(TKConfig.Database.GetSingletonValue(
    'SELECT COUNT(*) FROM COMUNI WHERE ID = ''' + AMunicipalityId+'''')) > 0;
end;

function UserToActivateExists(const ATaxCode: string): boolean;
begin
  Result := EFVarToInt(TKConfig.Database.GetSingletonValue(
    'SELECT COUNT(*) FROM APPUSER WHERE ID = ''' + ATaxCode + ''' AND MUST_CHANGE_PASSWORD = 1 AND ACCESS_DENIED = 1')) > 0;
end;

function CountryIdByIstatCode(const AIstatCode: string): string;
begin
  Result := EFVarToStr(TKConfig.Database.GetSingletonValue(
    'SELECT ID FROM NAZIONI WHERE CODICEISTAT  = ''' + AIstatCode + ''''));
end;

function InsertOrUpdatePerson(const ASourceRecord: TKRecord; AIsParent : boolean = false): string;
var
  LFirstName: string;
  LLastName: string;
  LTaxCode: string;
  LEmailAddress: string;
  LId: string;
  LGender: string;
  LCommandText: string;
  LCommand: TEFDBCommand;
  LMobile: variant;
  LAddress: variant;
  LMunicipalityId: variant;
  LCap: variant;
  LProvinceId: variant;
  LBirthPlaceId: variant;
  LBirthProvinceId: variant;
  LNationalityId: variant;
  LBirthDateValue: Variant;
  LAthlete: Variant;
  LUpdateFromUser: boolean;
begin
  Result := '';
  Assert(Assigned(ASourceRecord));

  //The data can come either from the User record or from the Subscription record
  //Data common to both models
  if AIsParent then
  begin
    LUpdateFromUser := False;
    LLastName:= ASourceRecord.FieldByName('ParentLastName').Value ;
    LFirstName:= ASourceRecord.FieldByName('ParentFirstName').Value ;
    LTaxCode:= ASourceRecord.FieldByName('ParentTaxCode').Value ;
    LEmailAddress:= ASourceRecord.FieldByName('ParentEmail').AsString;
    LMobile := ASourceRecord.FieldByName('ParentMobile').AsString ;

    LGender := GenderFromTaxCode(LTaxCode);
    //Decode part of the data from the tax code
    LBirthPlaceId := BirthPlaceIdFromTaxCode(LTaxCode);
    LBirthDateValue := BirthDateFromTaxCode(LTaxCode);
    LBirthProvinceId := BirthProvinceFromTaxCode(LTaxCode);
    LNationalityId := BirthCountryFromTaxCode(LTaxCode);
    LAddress := ASourceRecord.FieldByName('Address').Value;
    LMunicipalityId := ASourceRecord.FieldByName('MunicipalityId').Value;
    LCap := ASourceRecord.FieldByName('PostalCode').Value;
    LProvinceId := ASourceRecord.FieldByName('ProvinceId').Value;
    LAthlete:= False;
  end
  else
  begin
    LLastName:= ASourceRecord.FieldByName('LastName').Value ;
    LFirstName:= ASourceRecord.FieldByName('FirstName').Value ;
    LTaxCode:= ASourceRecord.FieldByName('TaxCode').Value ;
    LEmailAddress:= ASourceRecord.FieldByName('Email').AsString;
    LMobile := ASourceRecord.FieldByName('Mobile').AsString ;

    if SameText(ModelByRecord(ASourceRecord).ModelName, 'Subscription')  then
    begin
      //Data source: Subscription
      LUpdateFromUser := False;
      LGender := ASourceRecord.FieldByName('Gender').Value ;
      LAddress := ASourceRecord.FieldByName('Address').Value;
      LMunicipalityId := ASourceRecord.FieldByName('MunicipalityId').Value;
      LCap := ASourceRecord.FieldByName('PostalCode').Value;
      LProvinceId := ASourceRecord.FieldByName('ProvinceId').Value;
      LBirthDateValue := ASourceRecord.FieldByName('BirthDate').Value;
      LBirthPlaceId := ASourceRecord.FieldByName('BirthPlaceId').Value;
      LBirthProvinceId := ASourceRecord.FieldByName('BirthProvinceId').Value;
      LNationalityId := ASourceRecord.FieldByName('BirthCountryId').Value;
      LAthlete:= ASourceRecord.FieldByName('Campaign_SportsActivityFlag').AsBoolean;
    end
    else
    begin
      //Data source: User
      LUpdateFromUser := True;
      LGender := GenderFromTaxCode(LTaxCode);
      //Decode part of the data from the tax code
      LBirthPlaceId := BirthPlaceIdFromTaxCode(LTaxCode);
      //Check that the birth place is valid
      if not BirthPlaceExists(LBirthPlaceId) then
        LBirthPlaceId := '';
      LBirthDateValue := BirthDateFromTaxCode(LTaxCode);
      LBirthProvinceId := BirthProvinceFromTaxCode(LTaxCode);
      LNationalityId := BirthCountryFromTaxCode(LTaxCode);
      LAthlete:= False;
    end;
  end;

  if not PersonExistsByTaxCode(LTaxCode,'-') then
  begin
    //Insert a new person
    LId := CreateCompactGuidStr;
    if LUpdateFromUser then
      LCommandText :=
        'INSERT INTO NOMINATIVI '+
        '( ID, DX, COGNOME, NOME, CODFISC, SESSO, EMAIL, CELLULARE, LUOGONASCID, PROVNASCID, DATANASC, NAZIONALITAID)'+
        'VALUES '+
        '(:ID,:DX,:COGNOME,:NOME,:CODFISC,:SESSO,:EMAIL,:CELLULARE,:LUOGONASCID,:PROVNASCID,:DATANASC,:NAZIONALITAID)'
    else
      LCommandText := 'INSERT INTO NOMINATIVI '+
        '( ID, DX, COGNOME, NOME, CODFISC, SESSO, EMAIL, CELLULARE, INDIRIZZO, COMUNEID, CAP, PROVINCIAID, '+
        'LUOGONASCID, PROVNASCID, DATANASC, NAZIONALITAID, ATLETA)'+
        'VALUES '+
        '(:ID,:DX,:COGNOME,:NOME,:CODFISC,:SESSO,:EMAIL,:CELLULARE,:INDIRIZZO,:COMUNEID,:CAP,:PROVINCIAID,'+
        ':LUOGONASCID,:PROVNASCID,:DATANASC,:NAZIONALITAID, :ATLETA)';
  end
  else
  begin
    LId := '';
    //Update the data of an existing person
    if LUpdateFromUser then
      LCommandText :=
        'UPDATE NOMINATIVI SET '+
        'DX=:DX, COGNOME=:COGNOME, NOME=:NOME, SESSO=:SESSO, EMAIL=:EMAIL, CELLULARE=:CELLULARE'+
        ', LUOGONASCID=:LUOGONASCID, PROVNASCID=:PROVNASCID, DATANASC=:DATANASC, NAZIONALITAID=:NAZIONALITAID'
    else
      LCommandText :=
        'UPDATE NOMINATIVI SET '+
        'DX=:DX, COGNOME=:COGNOME, NOME=:NOME, SESSO=:SESSO, EMAIL=:EMAIL, CELLULARE=:CELLULARE'+
        ', INDIRIZZO=:INDIRIZZO, COMUNEID=:COMUNEID, CAP=:CAP, PROVINCIAID=:PROVINCIAID'+
        ', LUOGONASCID=:LUOGONASCID, PROVNASCID=:PROVNASCID, DATANASC=:DATANASC, NAZIONALITAID=:NAZIONALITAID'+
        ', ATLETA = :ATLETA';

    LCommandText := LCommandText+sLineBreak+
      'WHERE CODFISC = :CODFISC';
  end;

  LCommand := TKConfig.Database.CreateDBCommand;
  try
    LCommand.Connection.StartTransaction;
    try
      LCommand.CommandText := LCommandText;
      if LId <> '' then
        LCommand.Params.ParamByName('ID').AsString := LId;
      //Common parameters
      UpdateParamValue(LCommand.Params,'NOME', LFirstName);
      UpdateParamValue(LCommand.Params,'COGNOME', LLastName);
      UpdateParamValue(LCommand.Params,'DX', LLastName+ ' '+LFirstName+' ('+LTaxCode+')');
      UpdateParamValue(LCommand.Params,'CODFISC', LTaxCode);
      UpdateParamValue(LCommand.Params,'EMAIL', LEmailAddress);
      UpdateParamValue(LCommand.Params,'SESSO', LGender);
      UpdateParamValue(LCommand.Params,'CELLULARE', LMobile);
      UpdateParamValue(LCommand.Params,'LUOGONASCID', LBirthPlaceId);
      UpdateParamValue(LCommand.Params,'DATANASC', LBirthDateValue);
      UpdateParamValue(LCommand.Params,'PROVNASCID', LBirthProvinceId);
      UpdateParamValue(LCommand.Params,'NAZIONALITAID', LNationalityId);

      if not LUpdateFromUser then
      begin
        UpdateParamValue(LCommand.Params,'INDIRIZZO', LAddress);
        UpdateParamValue(LCommand.Params,'COMUNEID', LMunicipalityId);
        UpdateParamValue(LCommand.Params,'CAP', LCap);
        UpdateParamValue(LCommand.Params,'PROVINCIAID', LProvinceId);
        UpdateParamValue(LCommand.Params,'ATLETA', LAthlete);
      end;

      LCommand.Execute;
      LCommand.Connection.CommitTransaction;
      Result := LId;

      if (LUpdateFromUser or AIsParent) and (LId <> '') then
        InsertFamily(ASourceRecord, LId, AIsParent);
    except
      LCommand.Connection.RollbackTransaction;
      raise;
    end;
  finally
    FreeAndNil(LCommand);
  end;

end;

function InsertParticipantGroup(const ASourceRecord: TKRecord): string;
var
  LId, LCommandText: string;
  LCommand: TEFDBCommand;
begin
   Assert(Assigned(ASourceRecord));

   if not ASourceRecord.FieldByName('GRUPPOID').IsNull then
   begin
     LId := ASourceRecord.FieldByName('ID').AsString;

     LCommandText := 'INSERT INTO PARTECIPANTI ' +
       'SELECT ' +
       '''TISPartecipanti'' CLASS, ' +
       'replace(NewID(),''-'','''') ID, ' +
       '1 UPDATECOUNT, ' +
       'NOMINATIVI.DX DX, ' +
       'CURRENT_TIMESTAMP UPDTIMESTAMP, ' +
       'CONVERSAZIONI.CLASS CONVERSAZIONECLASS, ' +
       'CONVERSAZIONI.ID CONVERSAZIONEID, ' +
       'GRUPPI_PARTECIPANTI.CLASS GRUPPOCLASS, ' +
       'GRUPPI_PARTECIPANTI.ID GRUPPOID, ' +
       'NOMINATIVI.CLASS NOMINATIVOCLASS, ' +
       'NOMINATIVI.ID NOMINATIVOID ' +
       'FROM ' +
       'CONVERSAZIONI ' +
       'LEFT OUTER JOIN GRUPPI_PARTECIPANTI ON CONVERSAZIONI.GRUPPOCLASS = GRUPPI_PARTECIPANTI.CLASS AND CONVERSAZIONI.GRUPPOID = GRUPPI_PARTECIPANTI.ID ' +
       'INNER JOIN DETTAGLIO_PARTECIPANTI ON GRUPPI_PARTECIPANTI.CLASS = DETTAGLIO_PARTECIPANTI.GRUPPOCLASS AND GRUPPI_PARTECIPANTI.ID = DETTAGLIO_PARTECIPANTI.GRUPPOID ' +
       'LEFT OUTER JOIN NOMINATIVI ON DETTAGLIO_PARTECIPANTI.NOMINATIVOCLASS = NOMINATIVI.CLASS AND DETTAGLIO_PARTECIPANTI.NOMINATIVOID = NOMINATIVI.ID ' +
       'LEFT OUTER JOIN PARTECIPANTI ON CONVERSAZIONI.CLASS = PARTECIPANTI.CONVERSAZIONECLASS AND CONVERSAZIONI.ID = PARTECIPANTI.CONVERSAZIONEID AND NOMINATIVI.CLASS = PARTECIPANTI.NOMINATIVOCLASS AND NOMINATIVI.ID = PARTECIPANTI.NOMINATIVOID ' +
       'WHERE ' +
       'CONVERSAZIONI.ID = :ID ' +
       'AND PARTECIPANTI.NOMINATIVOCLASS IS NULL AND PARTECIPANTI.NOMINATIVOID IS NULL ';

     LCommand := TKConfig.Database.CreateDBCommand;
     try
       LCommand.Connection.StartTransaction;
       try
         LCommand.CommandText := LCommandText;

         UpdateParamValue(LCommand.Params,'ID', LId);

         LCommand.Execute;
         LCommand.Connection.CommitTransaction;
       except
         LCommand.Connection.RollbackTransaction;
         raise;
       end;
     finally
       FreeAndNil(LCommand);
     end;

   end;

end;

function InsertFamily(const ASourceRecord: TKRecord; const APersonId: string; AIsParent : boolean = false): string;
var
  LTaxCode: string;
  LDx: string;
begin
  Assert(Assigned(ASourceRecord));

  //The data can come either from the User record or from the Subscription record
  //Data common to both models
   if AIsParent then
  begin
    LTaxCode:= ASourceRecord.FieldByName('ParentTaxCode').Value ;

    LDx := ASourceRecord.FieldByName('ParentLastName').Value+ ' '+ASourceRecord.FieldByName('ParentFirstName').Value ;
  end
  else
  begin
    LTaxCode:= ASourceRecord.FieldByName('TaxCode').Value ;

    LDx := ASourceRecord.FieldByName('LastName').Value+ ' '+ASourceRecord.FieldByName('FirstName').Value ;
  end;

  Result := InsertFamily(LTaxCode, LDx, APersonId);
end;

function InsertFamily(const ATaxCode, ADescriptionValue, APersonId: string): string;
var
  LId: string;
  LGender: string;
  LRelationshipId: string;
  LCommandText: string;
  LCommand: TEFDBCommand;
begin
  Result := '';

  LGender := GenderFromTaxCode(ATaxCode);

  if LGender = GENDER_MALE then
    LRelationshipId := KINSHIP_FATHER
  else
    LRelationshipId := KINSHIP_MOTHER;

  //Insert the new family
  LId := CreateCompactGuidStr;
  LCommandText :=
      'INSERT INTO FAMIGLIE '+
      '( ID, DX, NOMINATIVO_CREATOREID)'+
      'VALUES '+
      '(:ID,:DX, :NOMINATIVO_CREATOREID)';

  LCommand := TKConfig.Database.CreateDBCommand;
  try
    LCommand.Connection.StartTransaction;
    try
      LCommand.CommandText := LCommandText;

      UpdateParamValue(LCommand.Params, 'ID', LId);
      UpdateParamValue(LCommand.Params,'DX', ATaxCode);
      UpdateParamValue(LCommand.Params,'NOMINATIVO_CREATOREID', APersonId);

      LCommand.Execute;
      LCommand.Connection.CommitTransaction;
      Result := LId;
      InsertFamilyMember(APersonId, ADescriptionValue, LRelationshipId, LId);
    except
      LCommand.Connection.RollbackTransaction;
      raise;
    end;
  finally
    FreeAndNil(LCommand);
  end;



end;

function InsertFamilyMember(const APersonId, ADescriptionValue, AKinshipId, AFamilyId: string): string;
var
  LId: string;
  LCommandText: string;
  LCommand: TEFDBCommand;
  LIsParentFlag : boolean;
begin
  Result := '';
  //Insert a new person
  LId := CreateCompactGuidStr;

  LCommandText := 'INSERT INTO MEMBRI_FAMIGLIE '+
                   '( ID, DX, NOMINATIVOID, PARENTELAID, FAMIGLIAID, PERC_DETRAZIONI)'+
                   'VALUES '+
                   '(:ID, :DX, :NOMINATIVOID, :PARENTELAID, :FAMIGLIAID, :PERC_DETRAZIONI )';

  LCommand := TKConfig.Database.CreateDBCommand;
  TKConfig.Database.CreateDBQuery;
  try
    LCommand.Connection.StartTransaction;
    try
      LCommand.CommandText := LCommandText;
      LIsParentFlag := EFVarToBoolean(TKConfig.Database.GetSingletonValue('SELECT FLAGGENITORE FROM PARENTELE WHERE ID = '+QuotedStr(AKinshipId)));

      LCommand.Params.ParamByName('ID').AsString := LId;

      UpdateParamValue(LCommand.Params,'DX', ADescriptionValue);
      UpdateParamValue(LCommand.Params,'NOMINATIVOID', APersonId);
      UpdateParamValue(LCommand.Params,'PARENTELAID', AKinshipId);
      UpdateParamValue(LCommand.Params,'FAMIGLIAID', AFamilyId);
      if LIsParentFlag then
        UpdateParamValue(LCommand.Params,'PERC_DETRAZIONI', 100)
      else
        UpdateParamValue(LCommand.Params,'PERC_DETRAZIONI', 0);

      LCommand.Execute;
      LCommand.Connection.CommitTransaction;
      Result := LId;
    except
      LCommand.Connection.RollbackTransaction;
      raise;
    end;
  finally
    FreeAndNil(LCommand);
  end;


end;

function BirthCountryFromTaxCode(const ATaxCode : string) : string;
var
  LQueryText: string;
  LQuery: TEFDBQuery;
  LCountryId : string;
begin
  Result := '';
  if Length(ATaxCode) = 16 then
    LCountryId := BirthPlaceIdFromTaxCode(ATaxCode)
  else
    exit;

  LQueryText := 'SELECT ID FROM NAZIONI WHERE CODICEAT = :Id';
  LQuery := TKConfig.Database.CreateDBQuery;
  Try
    LQuery.CommandText := LQueryText;
    LQuery.Params.ParamByName('Id').AsString := UpperCase(LCountryId);
    LQuery.Open;
    if LQuery.DataSet.IsEmpty then //when it is not found the country is Italy
      Result := 'IT'
    else
      Result := LQuery.DataSet.Fields[0].AsString;
    LQuery.Close;
  Finally
    FreeAndNil(LQuery);
  End;
End;

function BirthProvinceFromTaxCode(const ATaxCode : string) : string;
var
  LQueryText: string;
  LQuery: TEFDBQuery;
  LMunicipalityId2 : string;
begin
  Result := '';
  if Length(ATaxCode) = 16 then
    LMunicipalityId2 := BirthPlaceIdFromTaxCode(ATaxCode)
  else
    exit;

  LQueryText := 'SELECT PROVID FROM COMUNI WHERE ID = :Id';
  LQuery := TKConfig.Database.CreateDBQuery;
  Try
    LQuery.CommandText := LQueryText;
    LQuery.Params.ParamByName('Id').AsString := UpperCase(LMunicipalityId2);
    LQuery.Open;
    if not LQuery.DataSet.IsEmpty then
      Result := LQuery.DataSet.Fields[0].AsString;
    LQuery.Close;
  Finally
    FreeAndNil(LQuery);
  End;
End;

end.
