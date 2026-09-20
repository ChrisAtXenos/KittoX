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

/// <summary>Business rules of the enrollment and installment models: fee selection with
/// age-range check, sibling and single-installment discounts, installment
/// generation, and the three enrollment flows (self, child and administrator).</summary>
unit SCM.Rules.Subscription;

interface

uses
  Kitto.Rules, KItto.Store,
  Kitto.Web.Session;

type

  //Field rule: Person
  TSubscriptionSetPerson = class(TKRuleImpl)
  public
    procedure AfterFieldChange(const AField: TKField; const AOldValue, ANewValue: Variant); override;
  end;

  //Field rule: parent Person
  TSubscriptionSetParent = class(TKRuleImpl)
  public
    procedure AfterFieldChange(const AField: TKField; const AOldValue, ANewValue: Variant); override;
  end;

  //Field rules for the subscription fee
  TSubscriptionSetFee = class(TKRuleImpl)
  public
    procedure AfterFieldChange(const AField: TKField; const AOldValue, ANewValue: Variant); override;
  end;

  //Field rules for the sibling discount
  TSubscriptionSetSiblingDiscount = class(TKRuleImpl)
  public
    procedure AfterFieldChange(const AField: TKField; const AOldValue, ANewValue: Variant); override;
  end;

  //Field rules for the single instalment discount
  TSubscriptionSetSingleInstalmentDiscount = class(TKRuleImpl)
  public
    procedure AfterFieldChange(const AField: TKField; const AOldValue, ANewValue: Variant); override;
  end;

  //Rules that apply the subscription fee
  TSubscriptionApplyFee = class(TKRuleImpl)
  public
    procedure AfterFieldChange(const AField: TKField; const AOldValue, ANewValue: Variant); override;
  end;


  //Status check rules
  TSubscriptionCheckForEditing = class(TKRuleImpl)
  public
    procedure EditRecord(const ARecord: TKRecord); override;
    procedure BeforeDelete(const ARecord: TKRecord); override;
  end;

  //Rules for a change of the instalment discount
  TSubscriptionInstalmentCheck = class(TKRuleImpl)
  private
    procedure RecalcSubscriptionDiscountTotal(const ARecord: TKRecord);
  strict protected
    procedure BeforeAddOrUpdate(const ARecord: TKRecord); override;
  end;

  //Rules that apply the subscription fee
  TSubscriptionInstalmentSetDiscount = class(TKRuleImpl)
  public
    procedure AfterFieldChange(const AField: TKField; const AOldValue, ANewValue: Variant); override;
  end;

///--- MODEL RULES
  TSubscriptionCheck = class(TKRuleImpl)
  private
    procedure UpdateSubscriptionInstalments(const ARecord: TKRecord);
    procedure UpdateEditors(ARecord: TKRecord);
  strict protected
    procedure BeforeAddOrUpdate(const ARecord: TKRecord); override;
    procedure AfterAddOrUpdate(const ARecord: TKRecord); override;
  public
    procedure BeforeDelete(const ARecord: TKRecord); override;
    procedure BeforeAdd(const ARecord: TKRecord); override;
    procedure AfterShowEditWindow(const ARecord: TKRecord); override;
    procedure AfterRefreshReferenceField(const AField: TKField); override;
  end;

  //Rules for a new subscription
  TSubscribeUser = class(TKRuleImpl)
  public
    procedure NewRecord(const ARecord: TKRecord); override;
    procedure AfterAdd(const ARecord: TKRecord); override;
  end;

  //Rules for a new subscription of a child
  TSubscribeChild = class(TKRuleImpl)
  public
    procedure NewRecord(const ARecord: TKRecord); override;
    procedure AfterAdd(const ARecord: TKRecord); override;
  end;

  //Rules for a new subscription entered by an administrator
  TSubscribeByAdmin = class(TKRuleImpl)
  public
    procedure NewRecord(const ARecord: TKRecord); override;
    procedure AfterAdd(const ARecord: TKRecord); override;
  end;


  procedure RecalcTotal(const ARecord: TKRecord);
  procedure RecalcSiblingDiscount(const ARecord: TKRecord);
  procedure SendSubscriptionRequestMail(const ASubscriptionRecord: TKRecord);

implementation

uses
  SysUtils
  , Data.DB
  , EF.Localization
  , EF.VariantUtils
  , Kitto.Config
  , Kitto.Metadata.DataView
  , SCM.DbUtils, Kitto.DbUtils
  , EF.DB
  , SCM.Utils
  , SCM.Mail
  , System.Variants;


procedure RecalcTotal(const ARecord: TKRecord);
var
  LTotal: Currency;

begin
  LTotal := 0;
  if not ARecord.FieldByName('SubscriptionFee').IsNull then
  begin
    LTotal := ARecord.FieldByName('CourseFeeAmount').AsCurrency;
    if ARecord.FieldByName('SiblingDiscount').AsBoolean then
      LTotal := LTotal - ARecord.FieldByName('SiblingDiscountAmount').AsCurrency;
    if ARecord.FieldByName('SingleInstalmentDiscount').AsBoolean then
      LTotal := LTotal - ARecord.FieldByName('SingleInstalmentDiscountAmount').AsCurrency;
    if ARecord.FieldByName('InstalmentsDiscountAllowance').AsCurrency >0 then
      LTotal := LTotal - ARecord.FieldByName('InstalmentsDiscountAllowance').AsCurrency;
  end;
  ARecord.FieldByName('SubscriptionTotal').AsCurrency := LTotal;
end;

procedure RecalcSiblingDiscount(const ARecord: TKRecord);
begin
    if ARecord.FieldByName('SiblingDiscount') .AsBoolean then
      begin
        if ARecord.FieldByName('Campaign_SiblingDiscount').AsCurrency <> 0 then
          ARecord.FieldByName('SiblingDiscountAmount').Value := ARecord.FieldByName('Campaign_SiblingDiscount').Value
        else
          ARecord.FieldByName('SiblingDiscountAmount').Value :=
                            (ARecord.FieldByName('CourseFeeAmount').Value-ARecord.FieldByName('SingleInstalmentDiscountAmount').Value) *
                            ARecord.FieldByName('Campaign_SiblingDiscountPercent').AsInteger
                            / 100;
      end
    else
      ARecord.FieldByName('SiblingDiscountAmount').Value := 0;


end;

procedure SendSubscriptionRequestMail(const ASubscriptionRecord: TKRecord);
var
  LFrom, LSubject, LHTMLBody, LCc: string;
  LUserName, LEmailAddress, LMailMessageId: string;
  LSubscriptionInstructions, LSQLStatement: string;
begin
  //Send the request mail to the user
  LUserName := '';

  if not ASubscriptionRecord.FieldByName('ParentEmail').IsNull then
    LEmailAddress := ASubscriptionRecord.FieldByName('ParentEmail').AsString
  else
    LEmailAddress := ASubscriptionRecord.FieldByName('Email').AsString;

  LMailMessageId := 'RichiestaIscrizioneMailMessage';

  //Read the message from the yaml file
  GetEmailMsg(LMailMessageId, LFrom, LSubject, LHTMLBody, LCc);
  //Expand the {fieldname} placeholders against the current record
  ASubscriptionRecord.ExpandExpression(LHTMLBody);
  //Read the additional information, here the subscription notes
  LSQLStatement := GetSQLFieldValue('CAMPAGNE_ISCRIZIONI','NOTE_ISCRIZIONE','ID',
    ASubscriptionRecord.FieldByName('CampaignId').AsString);
  LSubscriptionInstructions := EFVarToStr(TKConfig.Database.GetSingletonValue(LSQLStatement));
  //Replace the #placeholder# in the message with the instructions
  LHTMLBody := StringReplace(LHTMLBody, '#IstruzioniIscrizione#', LSubscriptionInstructions, [rfIgnoreCase]);
  //Send the mail with the complete message
  InsertMailQueue(LMailMessageId, LEmailAddress, LFrom, LSubject, LHTMLBody, LCc);
end;

{ TSubscriptionSetParent }

procedure TSubscriptionSetParent.AfterFieldChange(const AField: TKField; const AOldValue,
  ANewValue: Variant);
var
  LCommandText: string;
  LQuery: TEFDBQuery;
begin
  inherited;
  //read the parent data
  if ((AField.Name = 'EnteredByUserId') or (AField.Name = 'ParentTaxCode'))
      and (not AField.isNull) then
  begin

    Try
      LCommandText := 'SELECT COGNOME, NOME, CELLULARE, EMAIL, INDIRIZZO, COMUNEID, CAP, PROVINCIAID FROM NOMINATIVI WHERE CODFISC = :ID';
      LQuery := TKConfig.Database.CreateDBQuery;
      LQuery.CommandText := LCommandText;
      try
        LQuery.Params.ParamByName('ID').AsString := ANewValue;
        LQuery.Open;
        if not LQuery.DataSet.IsEmpty then
        begin
          AField.ParentRecord.FieldByName('ParentLastName').AsString := LQuery.DataSet.FieldByName('COGNOME').AsString;
          AField.ParentRecord.FieldByName('ParentFirstName').AsString := LQuery.DataSet.FieldByName('NOME').AsString;
          AField.ParentRecord.FieldByName('ParentMobile').AsString := LQuery.DataSet.FieldByName('CELLULARE').AsString;
          AField.ParentRecord.FieldByName('ParentEmail').AsString := LQuery.DataSet.FieldByName('EMAIL').AsString;
          //read the parent address
          if LQuery.DataSet.FieldByName('INDIRIZZO').AsString <> '' then
            AField.ParentRecord.FieldByName('Address').AsString := LQuery.DataSet.FieldByName('INDIRIZZO').AsString;
          if LQuery.DataSet.FieldByName('COMUNEID').AsString <> '' then
            AField.ParentRecord.FieldByName('MunicipalityId').AsString := LQuery.DataSet.FieldByName('COMUNEID').AsString;
          if LQuery.DataSet.FieldByName('CAP').AsString <> '' then
            AField.ParentRecord.FieldByName('PostalCode').AsString := LQuery.DataSet.FieldByName('CAP').AsString;
          if LQuery.DataSet.FieldByName('PROVINCIAID').AsString <> '' then
            AField.ParentRecord.FieldByName('ProvinceId').AsString := LQuery.DataSet.FieldByName('PROVINCIAID').AsString;
          //Child subscription entered by a member: update the parent tax code
          if (AField.Name = 'EnteredByUserId') then
            AField.ParentRecord.FieldByName('ParentTaxCode').AsString := ANewValue;
        end;
      finally
        LQuery.Close;
      end;
    finally
      FreeAndNil(LQuery);
    end;
  end;

end;

{ TSubscriptionSetPerson }

procedure TSubscriptionSetPerson.AfterFieldChange(const AField: TKField;
  const AOldValue, ANewValue: Variant);
var
  LCommandText: string;
  LQuery: TEFDBQuery;
begin
  inherited;
  if (AField.Name = 'Person') then
    begin
    if AField.IsNull then
      // Clear the person data
      begin
        AField.ParentRecord.FieldByName('LastName').Value := Null;
        AField.ParentRecord.FieldByName('FirstName').Value := Null;
        AField.ParentRecord.FieldByName('TaxCode').Value := Null;
        AField.ParentRecord.FieldByName('Mobile').Value := Null;
        AField.ParentRecord.FieldByName('Gender').Value := Null;
        AField.ParentRecord.FieldByName('Email').Value := Null;
        AField.ParentRecord.FieldByName('Address').Value := Null;
        AField.ParentRecord.FieldByName('MunicipalityId').Value := Null;
        AField.ParentRecord.FieldByName('PostalCode').Value := Null;
        AField.ParentRecord.FieldByName('ProvinceId').Value := Null;
        AField.ParentRecord.FieldByName('BirthPlaceId').Value := Null;
        AField.ParentRecord.FieldByName('BirthProvinceId').Value := Null;
        AField.ParentRecord.FieldByName('BirthDate').Value := Null;
        AField.ParentRecord.FieldByName('BirthCountryId').Value := Null;
        AField.ParentRecord.FieldByName('ParentLastName').Value := Null;
        AField.ParentRecord.FieldByName('ParentFirstName').Value := Null;
        AField.ParentRecord.FieldByName('ParentTaxCode').Value := Null;
        AField.ParentRecord.FieldByName('ParentMobile').Value := Null;
        AField.ParentRecord.FieldByName('ParentEmail').Value := Null;
      end
    else
      // Read the person data
      begin
        Try
          LQuery := TKConfig.Database.CreateDBQuery;

          LCommandText := 'SELECT '+
                          '  COGNOME '+
                          '  ,NOME '+
                          '  ,CODFISC '+
                          '  ,CELLULARE '+
                          '  ,SESSO '+
                          '  ,EMAIL '+
                          '  ,INDIRIZZO '+
                          '  ,COMUNEID '+
                          '  ,CAP '+
                          '  ,PROVINCIAID '+
                          '  ,LUOGONASCID '+
                          '  ,PROVNASCID '+
                          '  ,DATANASC '+
                          '  ,NAZIONALITAID '+
                          'FROM '+
                          '  NOMINATIVI '+
                          'WHERE '+
                          '  NOMINATIVI.ID = :ID ';

          LQuery.CommandText := LCommandText;
          try
            LQuery.Params.ParamByName('ID').AsString := AField.ParentRecord.FieldByName('PersonId').AsString;
            LQuery.Open;
            if not LQuery.DataSet.IsEmpty then
            begin
              AField.ParentRecord.FieldByName('LastName').Value := LQuery.DataSet.FieldByName('COGNOME').Value;
              AField.ParentRecord.FieldByName('FirstName').Value := LQuery.DataSet.FieldByName('NOME').Value;
              AField.ParentRecord.FieldByName('TaxCode').Value := LQuery.DataSet.FieldByName('CODFISC').Value;
              AField.ParentRecord.FieldByName('Mobile').Value := LQuery.DataSet.FieldByName('CELLULARE').Value;
              AField.ParentRecord.FieldByName('Gender').Value := LQuery.DataSet.FieldByName('SESSO').Value;
              AField.ParentRecord.FieldByName('Email').Value := LQuery.DataSet.FieldByName('EMAIL').Value;
              AField.ParentRecord.FieldByName('Address').Value := LQuery.DataSet.FieldByName('INDIRIZZO').Value;
              AField.ParentRecord.FieldByName('MunicipalityId').Value := LQuery.DataSet.FieldByName('COMUNEID').Value;
              AField.ParentRecord.FieldByName('PostalCode').Value := LQuery.DataSet.FieldByName('CAP').Value;
              AField.ParentRecord.FieldByName('ProvinceId').Value := LQuery.DataSet.FieldByName('PROVINCIAID').Value;
              AField.ParentRecord.FieldByName('BirthPlaceId').Value := LQuery.DataSet.FieldByName('LUOGONASCID').Value;
              AField.ParentRecord.FieldByName('BirthProvinceId').Value := LQuery.DataSet.FieldByName('PROVNASCID').Value;
              AField.ParentRecord.FieldByName('BirthDate').Value := LQuery.DataSet.FieldByName('DATANASC').Value;
              AField.ParentRecord.FieldByName('BirthCountryId').Value := LQuery.DataSet.FieldByName('NAZIONALITAID').Value;
            end;
          finally
            LQuery.Close;
          end;

          // Read the parent data
          LCommandText := 'SELECT P.FLAGFIGLIO, F.DX '+
                          'FROM MEMBRI_FAMIGLIE MF '+
                          'INNER JOIN PARENTELE P ON '+
                          'MF.PARENTELACLASS = P.CLASS '+
                          'AND MF.PARENTELAID = P.ID '+
                          'INNER JOIN FAMIGLIE F ON '+
                          'MF.FAMIGLIACLASS = F.CLASS '+
                          'AND MF.FAMIGLIAID = F.ID '+
                          'WHERE NOMINATIVOID = :ID';

          LQuery.CommandText := LCommandText;
          try
            LQuery.Params.ParamByName('ID').AsString := AField.ParentRecord.FieldByName('PersonId').AsString;
            LQuery.Open;
            if (not LQuery.DataSet.IsEmpty) and LQuery.DataSet.FieldByName('FLAGFIGLIO').AsBoolean then
              AField.ParentRecord.FieldByName('ParentTaxCode').Value := LQuery.DataSet.FieldByName('DX').Value;
          finally
            LQuery.Close;
          end;
        finally
          FreeAndNil(LQuery);
        end;
      end;
    end;
end;

{ TSubscriptionSetFee }

procedure TSubscriptionSetFee.AfterFieldChange(const AField: TKField;
  const AOldValue, ANewValue: Variant);
var
  LCommandText: string;
  LQuery: TEFDBQuery;
  LDateFrom: TDateTime;
  LDateTo: TDateTime;
begin
  inherited;
  //read the campaign data
  if (AField.Name = 'SubscriptionFee') and (not AField.isNull) then
  begin

    Try
      LQuery := TKConfig.Database.CreateDBQuery;

      LCommandText := 'SELECT '+
                      '   QUOTE_ISCRIZIONI.CAMPAGNAID '+
                      '  ,QUOTE_ISCRIZIONI.TOTALE_QUOTA '+
                      '  ,QUOTE_ISCRIZIONI.ANNO_DAL '+
                      '  ,QUOTE_ISCRIZIONI.ANNO_AL '+
                      '  ,CAMPAGNE_ISCRIZIONI.STAGIONEID '+
                      'FROM '+
                      '  QUOTE_ISCRIZIONI '+
                      'LEFT OUTER JOIN ' +
                      '  CAMPAGNE_ISCRIZIONI ' +
                      'ON ' +
                      '  CAMPAGNE_ISCRIZIONI.ID = QUOTE_ISCRIZIONI.CAMPAGNAID '+
                      'WHERE '+
                      '  QUOTE_ISCRIZIONI.ID = :ID ';

      LQuery.CommandText := LCommandText;
      try
        LQuery.Params.ParamByName('ID').AsString := AField.ParentRecord.FieldByName('SubscriptionFeeId').Value;
        LQuery.Open;
        if not LQuery.DataSet.IsEmpty then
        begin
          // ANNO_DAL/ANNO_AL are optional on the model (Integer, not declared not null)
          // and in the database (IS_NULLABLE=YES): NULL means no constraint on that
          // side. AsInteger on null returns 0 and EncodeDate(0, ...) would raise
          // EConvertError.
          var LBirthYearFrom := LQuery.DataSet.FieldByName('ANNO_DAL');
          var LBirthYearTo  := LQuery.DataSet.FieldByName('ANNO_AL');
          if not LBirthYearFrom.IsNull then
            LDateFrom := EncodeDate(LBirthYearFrom.AsInteger, 1, 1)
          else
            LDateFrom := EncodeDate(1, 1, 1);
          if not LBirthYearTo.IsNull then
            LDateTo := EncodeDate(LBirthYearTo.AsInteger, 12, 31)
          else
            LDateTo := EncodeDate(9999, 12, 31);

          if ( AField.ParentRecord.FieldByName('BirthDate').AsDateTime < LDateFrom ) or
             ( AField.ParentRecord.FieldByName('BirthDate').AsDateTime > LDateTo )  then
            RaiseError(Format(_('Cannot subscribe - the date of birth must be between %s and %s'),
              [DateToStr(LDateFrom), DateToStr(LDateTo)]));



          AField.ParentRecord.FieldByName('CampaignId').Value := LQuery.DataSet.FieldByName('CAMPAGNAID').Value;
          AField.ParentRecord.FieldByName('SeasonId').Value := LQuery.DataSet.FieldByName('STAGIONEID').Value;
          AField.ParentRecord.FieldByName('CourseFeeAmount').Value := LQuery.DataSet.FieldByName('TOTALE_QUOTA').Value;
        end;
      finally
        LQuery.Close;
      end;
    finally
      FreeAndNil(LQuery);
    end;

    RecalcTotal(AField.ParentRecord);
  end;
end;

{ TBeforeAfterStore }

procedure TSubscriptionCheck.AfterAddOrUpdate(const ARecord: TKRecord);
begin
  inherited;
  if ARecord.State = rsNew then
    UpdateSubscriptionInstalments(ARecord);
end;

procedure TSubscriptionCheck.AfterRefreshReferenceField(const AField: TKField);
begin
  inherited;
  if (AField.Name = 'SubscriptionFeeId') then
    UpdateEditors(AField.ParentRecord);
end;

procedure TSubscriptionCheck.AfterShowEditWindow(const ARecord: TKRecord);
begin
  inherited;
  UpdateEditors(ARecord);
end;

procedure TSubscriptionCheck.UpdateSubscriptionInstalments(const ARecord: TKRecord);
var
  LQueryText: string;
  LQuery: TEFDBQuery;
  LInstalmentCount: integer;
  LProportionalAmount,
  LInstalment1DiscountAmount,
  LInstalment2DiscountAmount,
  LInstalment3DiscountAmount,
  LInstalment4DiscountAmount,
  LInstalment5DiscountAmount : Currency;
  Lupdate: Boolean;

  procedure InsertSubscriptionInstalment(const ADescription : string; const ASubscriptionId : string;
    const AAmount : currency; const ADueDate : TDateTime);
  var
    LCommandText: string;
    LCommand: TEFDBCommand;
  begin
    if (AAmount > 0) then
    begin
      LCommand := TKConfig.Database.CreateDBCommand;

      LCommandText := 'INSERT INTO RATE_ISCRIZIONI ' +
                      '(ID, DX, IMPORTO, IMPORTO_TOT, SCONTO_ABBUONO, DATA_SCADENZA, ISCRIZIONEID) ' +
                      'VALUES ' +
                      '(:ID, :DX, :IMPORTO, :IMPORTO_TOT, :SCONTO_ABBUONO, :DATA_SCADENZA, :ISCRIZIONEID) ';
      LCommand.CommandText := LCommandText;
      Try
        LCommand.Params.ParamByName('ID').AsString := GenerateGuid;
        LCommand.Params.ParamByName('DX').AsString := ADescription+'  '+DateToStr(ADueDate);
        LCommand.Params.ParamByName('IMPORTO').AsCurrency := AAmount;
        LCommand.Params.ParamByName('IMPORTO_TOT').AsCurrency := AAmount;
        LCommand.Params.ParamByName('SCONTO_ABBUONO').AsCurrency := 0;
        LCommand.Params.ParamByName('DATA_SCADENZA').AsDateTime := ADueDate;
        LCommand.Params.ParamByName('ISCRIZIONEID').AsString := ASubscriptionId;
        LCommand.Execute;
      Finally
        FreeAndNil(LCommand);
      End;

    end;

  end;


  procedure UpdateSubscriptionInstalment(const ASubscriptionId : string;
    const AAmount : currency;
    const ADueDate : TDateTime);
  var
    I: integer;
  begin
    if (ADueDate <> 0) then
    begin

      for I := 0 to ARecord.DetailStores[0].RecordCount-1 do
      begin
        if ARecord.DetailStores[0].Records[I].FieldByName('DueDate').AsDateTime = ADueDate then
        begin
          ARecord.DetailStores[0].Records[I].FieldByName('Amount').AsCurrency := AAmount ;
          ARecord.DetailStores[0].Records[I].FieldByName('TotalAmount').AsCurrency := AAmount -
            ARecord.DetailStores[0].Records[I].FieldByName('DiscountAllowance').AsCurrency;
        end;
      end;

    {  LCommand := TKConfig.Database.CreateDBCommand;

      LCommandText := 'UPDATE RATE_ISCRIZIONI ' +
                      'SET  ' +
                      'IMPORTO = :IMPORTO, ' +
                      'SCONTO_ABBUONO = :SCONTO_ABBUONO, ' +
                      'IMPORTO_TOT = :IMPORTO_TOT '+
                      'WHERE DATA_SCADENZA = :DATA_SCADENZA AND ISCRIZIONEID = :ISCRIZIONEID ';
      LCommand.CommandText := LCommandText;
      Try
        LCommand.Params.ParamByName('IMPORTO').AsCurrency := AAmount;
        LCommand.Params.ParamByName('SCONTO_ABBUONO').AsCurrency := ADiscount;
        LCommand.Params.ParamByName('IMPORTO_TOT').AsCurrency := AAmount-ADiscount;
        LCommand.Params.ParamByName('DATA_SCADENZA').AsDateTime := ADueDate;
        LCommand.Params.ParamByName('ISCRIZIONEID').AsString := ASubscriptionId;
        LCommand.Execute;
      Finally
        FreeAndNil(LCommand);
      End;
       }
    end;

  end;

begin
  Lupdate:= False;
  if (not ARecord.FieldByName('SubscriptionFee').IsNull) and
     (ARecord.FieldByName('Status').AsString = STS_ENTERED) then
  begin
    LQuery := TKConfig.Database.CreateDBQuery;

    LQueryText := 'SELECT '+
                    '  DATASCADENZA1 ' +
                    '  ,QUOTA1 ' +
                    '  ,DATASCADENZA2 ' +
                    '  ,QUOTA2 ' +
                    '  ,DATASCADENZA3 ' +
                    '  ,QUOTA3 ' +
                    '  ,DATASCADENZA4 ' +
                    '  ,QUOTA4 ' +
                    '  ,DATASCADENZA5 ' +
                    '  ,QUOTA5 '+
                    'FROM '+
                    '  QUOTE_ISCRIZIONI '+
                    'WHERE '+
                    '  QUOTE_ISCRIZIONI.ID = :ID ';

    LQuery.CommandText := LQueryText;
    try
      LQuery.Params.ParamByName('ID').AsString := ARecord.FieldByName('SubscriptionFeeId').Value;
      LQuery.Open;
      if not LQuery.DataSet.IsEmpty then
      begin
        if ARecord.FieldByName('SingleInstalmentDiscount').AsBoolean then
        begin
          if ARecord.State <> rsNew then
          begin
            if ARecord.DetailStores[0].RecordCount = 0 then
              (ARecord as TKViewTableRecord).LoadDetailStores;

            if ARecord.DetailStores[0].RecordCount > 1 then
            begin
              //Delete the instalments
              DeleteRecord('RATE_ISCRIZIONI', 'ISCRIZIONEID', ARecord.FieldByName('Id').AsString);
              ARecord.FieldByName('InstalmentsDiscountAllowance').AsCurrency := 0;
              RecalcTotal(ARecord);
              Lupdate := False;
            end
            else
              Lupdate := True;
          end;
          LInstalment1DiscountAmount := ARecord.FieldByName('InstalmentsDiscountAllowance').AsCurrency;// GetScontoRataFromDate(LQuery.DataSet.FieldByName('DATASCADENZA1').AsDateTime);
          if Lupdate then
            //Update the instalment
            UpdateSubscriptionInstalment( ARecord.FieldByName('Id').AsString,
                                  ARecord.FieldByName('SubscriptionTotal').AsCurrency+LInstalment1DiscountAmount,
                                  LQuery.DataSet.FieldByName('DATASCADENZA1').AsDateTime)

          else
            //Insert a single instalment
            InsertSubscriptionInstalment( ARecord.FieldByName('Description').AsString, ARecord.FieldByName('Id').AsString,
                                  ARecord.FieldByName('SubscriptionTotal').AsCurrency,
                                  LQuery.DataSet.FieldByName('DATASCADENZA1').AsDateTime);


        end
        else
        begin
          LInstalment1DiscountAmount := 0;
          LInstalment2DiscountAmount := 0;
          LInstalment3DiscountAmount := 0;
          LInstalment4DiscountAmount := 0;
          LInstalment5DiscountAmount := 0;
          LInstalmentCount := 0;
          if LQuery.DataSet.FieldByName('QUOTA1').AsCurrency > 0 then
            LInstalmentCount := LInstalmentCount + 1;
          if LQuery.DataSet.FieldByName('QUOTA2').AsCurrency > 0 then
            LInstalmentCount := LInstalmentCount + 1;
          if LQuery.DataSet.FieldByName('QUOTA3').AsCurrency > 0 then
            LInstalmentCount := LInstalmentCount + 1;
          if LQuery.DataSet.FieldByName('QUOTA4').AsCurrency > 0 then
            LInstalmentCount := LInstalmentCount + 1;
          if LQuery.DataSet.FieldByName('QUOTA5').AsCurrency > 0 then
            LInstalmentCount := LInstalmentCount + 1;

          if ARecord.FieldByName('SiblingDiscount').AsBoolean then
          begin
            if ARecord.FieldByName('Campaign_DiscountDeadline').AsInteger = 0 then
            begin

              LProportionalAmount := Round( (ARecord.FieldByName('SiblingDiscountAmount').AsCurrency / LInstalmentCount) * 100)/100;

              if LQuery.DataSet.FieldByName('QUOTA1').AsCurrency > 0 then
              begin
                LInstalment1DiscountAmount := LProportionalAmount;
              end;

              if LQuery.DataSet.FieldByName('QUOTA2').AsCurrency > 0 then
              begin
                if LInstalmentCount = 2 then
                  LInstalment2DiscountAmount := ARecord.FieldByName('SiblingDiscountAmount').AsCurrency-LProportionalAmount
                else
                  LInstalment2DiscountAmount := LProportionalAmount;
              end;

              if LQuery.DataSet.FieldByName('QUOTA3').AsCurrency > 0 then
              begin
                if LInstalmentCount = 3 then
                  LInstalment3DiscountAmount := ARecord.FieldByName('SiblingDiscountAmount').AsCurrency-(LProportionalAmount*2)
                else
                  LInstalment3DiscountAmount := LProportionalAmount;
              end;

              if LQuery.DataSet.FieldByName('QUOTA4').AsCurrency > 0 then
              begin
                if LInstalmentCount = 4 then
                  LInstalment4DiscountAmount := ARecord.FieldByName('SiblingDiscountAmount').AsCurrency-(LProportionalAmount*3)
                else
                  LInstalment4DiscountAmount := LProportionalAmount;
              end;

              if LQuery.DataSet.FieldByName('QUOTA5').AsCurrency > 0 then
              begin
                if LInstalmentCount = 5 then
                  LInstalment5DiscountAmount := ARecord.FieldByName('SiblingDiscountAmount').AsCurrency-(LProportionalAmount*4)
                else
                  LInstalment5DiscountAmount := LProportionalAmount;
              end;

            end
            else if ARecord.FieldByName('Campaign_DiscountDeadline').AsInteger = 1 then
              LInstalment1DiscountAmount := ARecord.FieldByName('SiblingDiscountAmount').AsCurrency
            else if ARecord.FieldByName('Campaign_DiscountDeadline').AsInteger = 2 then
              LInstalment2DiscountAmount := ARecord.FieldByName('SiblingDiscountAmount').AsCurrency
            else if ARecord.FieldByName('Campaign_DiscountDeadline').AsInteger = 3 then
              LInstalment3DiscountAmount := ARecord.FieldByName('SiblingDiscountAmount').AsCurrency
            else if ARecord.FieldByName('Campaign_DiscountDeadline').AsInteger = 4 then
              LInstalment4DiscountAmount := ARecord.FieldByName('SiblingDiscountAmount').AsCurrency
            else
              LInstalment5DiscountAmount := ARecord.FieldByName('SiblingDiscountAmount').AsCurrency
          end;


          if ARecord.State <> rsNew then
          begin
            if ARecord.DetailStores[0].RecordCount = 0 then
              (ARecord as TKViewTableRecord).LoadDetailStores;

            if ARecord.DetailStores[0].RecordCount <> LInstalmentCount then
            begin
              //Delete the instalments
              DeleteRecord('RATE_ISCRIZIONI', 'ISCRIZIONEID', ARecord.FieldByName('Id').AsString);
              ARecord.FieldByName('InstalmentsDiscountAllowance').AsCurrency := 0;
              RecalcTotal(ARecord);
              Lupdate := False;
            end
            else
              Lupdate := True;
          end;

          //update the instalments unless this is a brand new record
          if Lupdate then
          begin
            UpdateSubscriptionInstalment( ARecord.FieldByName('Id').AsString,
                                  LQuery.DataSet.FieldByName('QUOTA1').AsCurrency-LInstalment1DiscountAmount,
                                  LQuery.DataSet.FieldByName('DATASCADENZA1').AsDateTime);
            UpdateSubscriptionInstalment( ARecord.FieldByName('Id').AsString,
                                  LQuery.DataSet.FieldByName('QUOTA2').AsCurrency-LInstalment2DiscountAmount,
                                  LQuery.DataSet.FieldByName('DATASCADENZA2').AsDateTime);
            UpdateSubscriptionInstalment( ARecord.FieldByName('Id').AsString,
                                  LQuery.DataSet.FieldByName('QUOTA3').AsCurrency-LInstalment3DiscountAmount,
                                  LQuery.DataSet.FieldByName('DATASCADENZA3').AsDateTime);
            UpdateSubscriptionInstalment( ARecord.FieldByName('Id').AsString,
                                  LQuery.DataSet.FieldByName('QUOTA4').AsCurrency-LInstalment4DiscountAmount,
                                  LQuery.DataSet.FieldByName('DATASCADENZA4').AsDateTime);
            UpdateSubscriptionInstalment( ARecord.FieldByName('Id').AsString,
                                  LQuery.DataSet.FieldByName('QUOTA5').AsCurrency-LInstalment5DiscountAmount,
                                  LQuery.DataSet.FieldByName('DATASCADENZA5').AsDateTime);

          end
          else
          begin
            InsertSubscriptionInstalment( ARecord.FieldByName('Description').AsString, ARecord.FieldByName('Id').AsString,
                                  LQuery.DataSet.FieldByName('QUOTA1').AsCurrency-LInstalment1DiscountAmount,
                                  LQuery.DataSet.FieldByName('DATASCADENZA1').AsDateTime);
            InsertSubscriptionInstalment( ARecord.FieldByName('Description').AsString, ARecord.FieldByName('Id').AsString,
                                  LQuery.DataSet.FieldByName('QUOTA2').AsCurrency-LInstalment2DiscountAmount,
                                  LQuery.DataSet.FieldByName('DATASCADENZA2').AsDateTime);
            InsertSubscriptionInstalment( ARecord.FieldByName('Description').AsString, ARecord.FieldByName('Id').AsString,
                                  LQuery.DataSet.FieldByName('QUOTA3').AsCurrency-LInstalment3DiscountAmount,
                                  LQuery.DataSet.FieldByName('DATASCADENZA3').AsDateTime);
            InsertSubscriptionInstalment( ARecord.FieldByName('Description').AsString, ARecord.FieldByName('Id').AsString,
                                  LQuery.DataSet.FieldByName('QUOTA4').AsCurrency-LInstalment4DiscountAmount,
                                  LQuery.DataSet.FieldByName('DATASCADENZA4').AsDateTime);
            InsertSubscriptionInstalment( ARecord.FieldByName('Description').AsString, ARecord.FieldByName('Id').AsString,
                                  LQuery.DataSet.FieldByName('QUOTA5').AsCurrency-LInstalment5DiscountAmount,
                                  LQuery.DataSet.FieldByName('DATASCADENZA5').AsDateTime);
          end;
        end;
      end;
      LQuery.Close;
    finally
      FreeAndNil(LQuery);
    end;
  end;
end;

procedure TSubscriptionCheck.BeforeAdd(const ARecord: TKRecord);
var
  LSQLStatement: string;
begin
  inherited;
  LSQLStatement := 'SELECT COUNT(*) TOT FROM ISCRIZIONI WHERE QUOTA_ISCRIZIONEID = '+QuotedStr(ARecord.FieldByName('SubscriptionFeeId').AsString);
  if not ARecord.FieldByName('PersonId').IsNull then
    LSQLStatement := LSQLStatement + 'AND NOMINATIVOID = '+QuotedStr(ARecord.FieldByName('PersonId').AsString)
  else
    LSQLStatement := LSQLStatement + 'AND CODFISC = '+QuotedStr(ARecord.FieldByName('TaxCode').AsString);

 if EFVarToInt(TKConfig.Database.GetSingletonValue(LSQLStatement)) > 0  then
   RaiseError(_('Subscription already exists!'));
end;

procedure TSubscriptionCheck.BeforeAddOrUpdate(const ARecord: TKRecord);
var
  LId: string;
begin
  inherited;
  LId := InsertOrUpdatePerson(ARecord);
  if (LId <> '') and ARecord.FieldByName('PersonId').IsNull then
    ARecord.FieldByName('PersonId').AsString := LId;

  if ARecord.State <> rsNew then
    UpdateSubscriptionInstalments(ARecord);
end;

procedure TSubscriptionCheck.BeforeDelete(const ARecord: TKRecord);
begin
  inherited;
  //Delete the subscription details
  DeleteRecord('RATE_ISCRIZIONI', 'ISCRIZIONEID', ARecord.FieldByName('Id').AsString);
end;

procedure TSubscriptionCheck.UpdateEditors(ARecord: TKRecord);
var
  LSingleInstalmentDiscountField: TKField;
  LSingleInstalmentDiscountAmountField: TKField;
  LFeeSingleInstalmentDiscount: TKField;
begin
  LSingleInstalmentDiscountField := ARecord.FieldByName('SingleInstalmentDiscount');
  LSingleInstalmentDiscountAmountField := ARecord.FieldByName('SingleInstalmentDiscountAmount');
  LFeeSingleInstalmentDiscount := ARecord.FindField('SubscriptionFee_SingleInstalmentDiscount');
  if Assigned(LFeeSingleInstalmentDiscount)  then
  begin
    LSingleInstalmentDiscountField.SetTransientProperty('Visible', LFeeSingleInstalmentDiscount.AsCurrency <> 0);
    LSingleInstalmentDiscountAmountField.SetTransientProperty('Visible', LFeeSingleInstalmentDiscount.AsCurrency <> 0);
  end;
end;

{ TSubscribeUser }

procedure TSubscribeUser.AfterAdd(const ARecord: TKRecord);
begin
  inherited;
  SendSubscriptionRequestMail(ARecord);
end;

procedure TSubscribeUser.NewRecord(const ARecord: TKRecord);
var
  LId: string;
  LSQLStatement: string;
  LTaxCode: string;
begin
  inherited;
  //read the person data of the user
  LTaxCode:= TKConfig.Instance.Authenticator.UserName;
  LSQLStatement := GetSQLFieldValue('NOMINATIVI', 'ID', 'CODFISC', LTaxCode) ;
  LId:= EFVarToStr(TKConfig.Database.GetSingletonValue(LSQLStatement));
  ARecord.FieldByName('PersonId').AsString := LId;
  ARecord.FieldByName('Status').AsString := STS_ENTERED;
end;

{ TSubscribeChild }

procedure TSubscribeChild.AfterAdd(const ARecord: TKRecord);
var
  LId: string;
  LSQLStatement: string;
  LTaxCode: string;
  LFamilyId: string;
  LSQLStatementCount: string;
  LPersonId: string;
  LDx: string;
  LParentDescription: string;
begin
  inherited;
  //read the person data of the user
  LTaxCode:= TKConfig.Instance.Authenticator.UserName;
  LSQLStatement := GetSQLFieldValue('NOMINATIVI', 'ID', 'CODFISC', LTaxCode) ;
  LId:= EFVarToStr(TKConfig.Database.GetSingletonValue(LSQLStatement));

  LSQLStatement := GetSQLFieldValue('MEMBRI_FAMIGLIE', 'FAMIGLIAID', 'NOMINATIVOID', LId) ;
  LFamilyId := EFVarToStr(TKConfig.Database.GetSingletonValue(LSQLStatement));

  //create the family when the parent does not have one yet, the same way
  //TSubscribeByAdmin does for an administrator entered subscription: without it the
  //child would be attached to a family that does not exist and would stay invisible
  //in every view filtered by family. The parent data is not in the record, because
  //this view has no Parent block, so it is read from the parent person instead.
  if (LFamilyId = '') then
  begin
    if (LId = '') then
      RaiseError(_('Parent record not found: the household cannot be created.'));
    LSQLStatement := GetSQLFieldValue('NOMINATIVI', 'COGNOME', 'CODFISC', LTaxCode) ;
    LParentDescription := EFVarToStr(TKConfig.Database.GetSingletonValue(LSQLStatement));
    LSQLStatement := GetSQLFieldValue('NOMINATIVI', 'NOME', 'CODFISC', LTaxCode) ;
    LParentDescription := LParentDescription+' '+EFVarToStr(TKConfig.Database.GetSingletonValue(LSQLStatement));
    LFamilyId := InsertFamily(LTaxCode, LParentDescription, LId);
  end;

  LDx := ARecord.FieldByName('LastName').AsString+' '+ARecord.FieldByName('FirstName').AsString;

  if (ARecord.FieldByName('PersonId').AsString = '') then
  begin
    LSQLStatement := GetSQLFieldValue('NOMINATIVI', 'ID', 'CODFISC', ARecord.FieldByName('TaxCode').AsString) ;
    LPersonId := EFVarToStr(TKConfig.Database.GetSingletonValue(LSQLStatement));
  end
  else
  begin
    LPersonId:= ARecord.FieldByName('PersonId').AsString;
  end;

  LSQLStatementCount := 'SELECT COUNT(*) TOT  FROM MEMBRI_FAMIGLIE WHERE NOMINATIVOID = '+QuotedStr(LPersonId)+
                        ' AND FAMIGLIAID = '+QuotedStr(LFamilyId);
  if EFVarToInt(TKConfig.Database.GetSingletonValue(LSQLStatementCount)) = 0 then
    InsertFamilyMember(LPersonId,
                         LDx,
                         KINSHIP_CHILD,
                         LFamilyId);

  SendSubscriptionRequestMail(ARecord);
end;

procedure TSubscribeChild.NewRecord(const ARecord: TKRecord);
begin
  inherited;
  //read the id of the logged user: it must be set here and not as a model default, otherwise the setter does not fire
  ARecord.FieldByName('EnteredByUserId').AsString:= TKConfig.Instance.Authenticator.UserName;
  ARecord.FieldByName('Status').AsString := STS_ENTERED;
end;

{ TSubscriptionSetSiblingDiscount }

procedure TSubscriptionSetSiblingDiscount.AfterFieldChange(const AField: TKField;
  const AOldValue, ANewValue: Variant);
begin
  inherited;
  if (AField.Name = 'SiblingDiscount') and (not AField.isNull) then
  begin
    RecalcSiblingDiscount(AField.ParentRecord);

    RecalcTotal(AField.ParentRecord);
  end
  else if (AField.Name = 'SiblingDiscountAmount')  then
  begin
    if (AField.ParentRecord.FieldByName('SiblingDiscount').AsBoolean) then
      RecalcTotal(AField.ParentRecord);
  end;


end;

{ TSubscriptionCheckForEditing }

procedure TSubscriptionCheckForEditing.BeforeDelete(const ARecord: TKRecord);
begin
  inherited;
  if (ARecord.FieldByName('Status').AsString <> STS_ENTERED) then
    RaiseError(_('Subscription already confirmed: it cannot be changed'));
end;

procedure TSubscriptionCheckForEditing.EditRecord(const ARecord: TKRecord);
begin
  inherited;
  if (ARecord.FieldByName('Status').AsString <> STS_ENTERED) then
    RaiseError(_('Subscription already confirmed: it cannot be changed'));
end;

{ TSubscribeByAdmin }

procedure TSubscribeByAdmin.AfterAdd(const ARecord: TKRecord);
var
  LId: string;
  LSQLStatement: string;
  LTaxCode: string;
  LFamilyId: string;
  LSQLStatementCount: string;
  LPersonId: string;
  LDx: string;
begin
  inherited;

  // when both parent and child are already on file, create the family
  if not ARecord.FieldByName('ParentTaxCode').IsNull then
  begin

    //read the person data of the parent
    LTaxCode:= ARecord.FieldByName('ParentTaxCode').AsString;
    LSQLStatement := GetSQLFieldValue('NOMINATIVI', 'ID', 'CODFISC', LTaxCode) ;
    LId:= EFVarToStr(TKConfig.Database.GetSingletonValue(LSQLStatement));

    if (LId = '') then // create the person when it does not exist
      LId:= InsertOrUpdatePerson(ARecord, True);

    //read the family from the parent id
    LSQLStatement := GetSQLFieldValue('MEMBRI_FAMIGLIE', 'FAMIGLIAID', 'NOMINATIVOID', LId) ;
    LFamilyId := EFVarToStr(TKConfig.Database.GetSingletonValue(LSQLStatement));
    if (LFamilyId = '') then // create the family when it does not exist
      LFamilyId := InsertFamily(ARecord, LId, True);
  

    LDx := ARecord.FieldByName('LastName').AsString+' '+ARecord.FieldByName('FirstName').AsString;

    if (ARecord.FieldByName('PersonId').AsString = '') then
    begin
      LSQLStatement := GetSQLFieldValue('NOMINATIVI', 'ID', 'CODFISC', ARecord.FieldByName('TaxCode').AsString) ;
      LPersonId := EFVarToStr(TKConfig.Database.GetSingletonValue(LSQLStatement));
    end
    else
    begin
      LPersonId:= ARecord.FieldByName('PersonId').AsString;
    end;

    //add the child as a member of the family
    LSQLStatementCount := 'SELECT COUNT(*) TOT  FROM MEMBRI_FAMIGLIE WHERE NOMINATIVOID = '+QuotedStr(LPersonId)+
                          ' AND FAMIGLIAID = '+QuotedStr(LFamilyId);
    if EFVarToInt(TKConfig.Database.GetSingletonValue(LSQLStatementCount)) = 0 then
      InsertFamilyMember(LPersonId,
                           LDx,
                           KINSHIP_CHILD,
                           LFamilyId);
  end;

  //Send the subscription request mail
  SendSubscriptionRequestMail(ARecord);
end;

procedure TSubscribeByAdmin.NewRecord(const ARecord: TKRecord);
begin
  inherited;
  ARecord.FieldByName('EnteredByUserId').AsString:= TKConfig.Instance.Authenticator.UserName;
  ARecord.FieldByName('Status').AsString := STS_ENTERED;
end;

{ TSubscriptionApplyFee }

procedure TSubscriptionApplyFee.AfterFieldChange(const AField: TKField;
  const AOldValue, ANewValue: Variant);
var
  LSQLStatement: string;
  LBirthYear: word;
  LBirthMonth: word;
  LBirthDay: word;
  LQuery: TEFDBQuery;

begin
  inherited;
  if (not AField.ParentRecord.FieldByName('BirthDate').IsNull) and
     (AField.ParentRecord.FieldByName('SubscriptionFeeId').IsNull) then
  begin
    DecodeDate(AField.ParentRecord.FieldByName('BirthDate').AsDateTime,
               LBirthYear, LBirthMonth, LBirthDay);

    LSQLStatement := 'SELECT ID FROM QUOTE_ISCRIZIONI WHERE ANNO_DAL <= '+IntToStr(LBirthYear)+ ' AND ANNO_AL >= '+IntToStr(LBirthYear)+
                     ' AND (CAMPAGNAID in (SELECT ID FROM CAMPAGNE_ISCRIZIONI where FLAG_ATT_SPORTIVA = 1 and INIZIO < CURRENT_TIMESTAMP and FINE >= CURRENT_TIMESTAMP))';

    LQuery := TKConfig.Database.CreateDBQuery;
    try
      LQuery.CommandText := LSQLStatement;
    try
      LQuery.Open;
      if (not LQuery.DataSet.IsEmpty) and (LQuery.DataSet.RecordCount = 1) then
      begin
        AField.ParentRecord.FieldByName('SubscriptionFeeId').AsString := LQuery.DataSet.FieldByName('ID').AsString;
      end;
    finally
      LQuery.Close;
    end;
    finally
      FreeAndNil(LQuery);
    end;

  end;
end;


{ TSubscriptionInstalmentCheck }

procedure TSubscriptionInstalmentCheck.BeforeAddOrUpdate(const ARecord: TKRecord);
begin
  inherited;
  RecalcSubscriptionDiscountTotal(ARecord);
end;

procedure TSubscriptionInstalmentCheck.RecalcSubscriptionDiscountTotal(
  const ARecord: TKRecord);
var
  LInstalmentsDiscountTotal: currency;
begin
// set the values on the master (payment): calculated field that helps the user and feeds the final reconciliation check
  if Assigned((ARecord as TKViewTableRecord).Store.MasterRecord) then begin
    LInstalmentsDiscountTotal := 0;
    TKViewTableRecord(ARecord).Store.Iterate(
      procedure (ARecord: TKRecord)
      begin
        LInstalmentsDiscountTotal := LInstalmentsDiscountTotal + ARecord.FieldByName('DiscountAllowance').AsCurrency;
      end,
      [TKViewTableRecord(ARecord).Store.ExcludeDeleted()]);
  end;
  TKViewTableRecord(ARecord).Store.MasterRecord.FieldByName('InstalmentsDiscountAllowance').AsCurrency := LInstalmentsDiscountTotal;
  RecalcTotal(TKViewTableRecord(ARecord).Store.MasterRecord);
end;

{ TSubscriptionInstalmentSetDiscount }

procedure TSubscriptionInstalmentSetDiscount.AfterFieldChange(const AField: TKField;
  const AOldValue, ANewValue: Variant);
begin
  inherited;
  if AField.Name = 'DiscountAllowance' then
    AField.ParentRecord.FieldByName('TotalAmount').AsCurrency := AField.ParentRecord.FieldByName('Amount').AsCurrency - AField.AsCurrency;

end;

{ TSubscriptionSetSingleInstalmentDiscount }

procedure TSubscriptionSetSingleInstalmentDiscount.AfterFieldChange(const AField: TKField;
  const AOldValue, ANewValue: Variant);
begin
  inherited;
  if (AField.Name = 'SingleInstalmentDiscount') and (not AField.isNull) then
  begin
    if AField.AsBoolean then
      AField.ParentRecord.FieldByName('SingleInstalmentDiscountAmount').AsCurrency := AField.ParentRecord.FieldByName('SubscriptionFee_SingleInstalmentDiscount').AsCurrency
    else
      AField.ParentRecord.FieldByName('SingleInstalmentDiscountAmount').Value := 0;

    RecalcSiblingDiscount(AField.ParentRecord);

    RecalcTotal(AField.ParentRecord);
  end
  else if (AField.Name = 'SingleInstalmentDiscountAmount') then
  begin
    if (AField.ParentRecord.FieldByName('SingleInstalmentDiscount').AsBoolean) then
    begin
      RecalcSiblingDiscount(AField.ParentRecord);
      RecalcTotal(AField.ParentRecord);
    end;
  end;
end;

initialization
  TKRuleImplRegistry.Instance.RegisterClass(TSubscriptionSetPerson.GetClassId, TSubscriptionSetPerson);
  TKRuleImplRegistry.Instance.RegisterClass(TSubscriptionSetParent.GetClassId, TSubscriptionSetParent);
  TKRuleImplRegistry.Instance.RegisterClass(TSubscriptionSetFee.GetClassId, TSubscriptionSetFee);
  TKRuleImplRegistry.Instance.RegisterClass(TSubscriptionCheck.GetClassId, TSubscriptionCheck);
  TKRuleImplRegistry.Instance.RegisterClass(TSubscribeUser.GetClassId, TSubscribeUser);
  TKRuleImplRegistry.Instance.RegisterClass(TSubscribeChild.GetClassId, TSubscribeChild);
  TKRuleImplRegistry.Instance.RegisterClass(TSubscriptionSetSiblingDiscount.GetClassId, TSubscriptionSetSiblingDiscount);
  TKRuleImplRegistry.Instance.RegisterClass(TSubscriptionCheckForEditing.GetClassId, TSubscriptionCheckForEditing);
  TKRuleImplRegistry.Instance.RegisterClass(TSubscribeByAdmin.GetClassId, TSubscribeByAdmin);
  TKRuleImplRegistry.Instance.RegisterClass(TSubscriptionApplyFee.GetClassId, TSubscriptionApplyFee);
  TKRuleImplRegistry.Instance.RegisterClass(TSubscriptionInstalmentCheck.GetClassId, TSubscriptionInstalmentCheck);
  TKRuleImplRegistry.Instance.RegisterClass(TSubscriptionInstalmentSetDiscount.GetClassId, TSubscriptionInstalmentSetDiscount);
  TKRuleImplRegistry.Instance.RegisterClass(TSubscriptionSetSingleInstalmentDiscount.GetClassId, TSubscriptionSetSingleInstalmentDiscount);

finalization
  TKRuleImplRegistry.Instance.UnregisterClass(TSubscriptionSetPerson.GetClassId);
  TKRuleImplRegistry.Instance.UnregisterClass(TSubscriptionSetParent.GetClassId);
  TKRuleImplRegistry.Instance.UnregisterClass(TSubscriptionSetFee.GetClassId);
  TKRuleImplRegistry.Instance.UnregisterClass(TSubscriptionCheck.GetClassId);
  TKRuleImplRegistry.Instance.UnregisterClass(TSubscribeUser.GetClassId);
  TKRuleImplRegistry.Instance.UnregisterClass(TSubscribeChild.GetClassId);
  TKRuleImplRegistry.Instance.UnregisterClass(TSubscriptionSetSiblingDiscount.GetClassId);
  TKRuleImplRegistry.Instance.UnregisterClass(TSubscriptionCheckForEditing.GetClassId);
  TKRuleImplRegistry.Instance.UnregisterClass(TSubscribeByAdmin.GetClassId);
  TKRuleImplRegistry.Instance.UnregisterClass(TSubscriptionApplyFee.GetClassId);
  TKRuleImplRegistry.Instance.UnregisterClass(TSubscriptionInstalmentCheck.GetClassId);
  TKRuleImplRegistry.Instance.UnregisterClass(TSubscriptionInstalmentSetDiscount.GetClassId);
  TKRuleImplRegistry.Instance.UnregisterClass(TSubscriptionSetSingleInstalmentDiscount.GetClassId);

end.
