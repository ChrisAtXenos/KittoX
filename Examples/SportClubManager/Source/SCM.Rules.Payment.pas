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

/// <summary>Business rules of the payment models: amount reconciliation between header
/// and details, obligations tied to the payment method, installment residual
/// calculation and the two payment entry flows (member and administrator).</summary>
unit SCM.Rules.Payment;

interface
uses
  Kitto.Rules, KItto.Store;

Type

///--- FIELD RULES
///
  TPaymentDetailSetInstalment = class(TKRuleImpl)
  public
    procedure AfterFieldChange(const AField: TKField; const AOldValue: Variant; const ANewValue: Variant); override;
  end;

  TPaymentSetDate = class(TKRuleImpl)
  public
    procedure AfterFieldChange(const AField: TKField; const AOldValue: Variant; const ANewValue: Variant); override;
  end;

  TPaymentDetailSetPaidAmount = class(TKRuleImpl)
  public
    procedure AfterFieldChange(const AField: TKField; const AOldValue: Variant; const ANewValue: Variant); override;
  end;

///--- MODEL RULES
  TPaymentCheck = class(TKRuleImpl)
  strict protected
    procedure BeforeAddOrUpdate(const ARecord: TKRecord); override;
  public
    procedure BeforeAdd(const ARecord: TKRecord); override;
    procedure AfterAdd(const ARecord: TKRecord); override;
    procedure BeforeDelete(const ARecord: TKRecord); override;
  end;


  TPaymentDetailCheck = class(TKRuleImpl)
  private
  procedure   RecalcPaymentLinesTotal(const ARecord: TKRecord);
  strict protected
    procedure BeforeAddOrUpdate(const ARecord: TKRecord); override;
  public
    procedure AfterDelete(const ARecord: TKRecord); override;
  end;

  //Rules for a payment entered by a member
  TEnterPayment = class(TKRuleImpl)
  public
    procedure NewRecord(const ARecord: TKRecord); override;
    procedure AfterAdd(const ARecord: TKRecord); override;
  end;

  //Status check rules
  TPaymentCheckForEditing = class(TKRuleImpl)
  public
    procedure EditRecord(const ARecord: TKRecord); override;
    procedure BeforeDelete(const ARecord: TKRecord); override;
  end;

  //Rules for a payment entered by an administrator
  TEnterPaymentByAdmin = class(TKRuleImpl)
  public
    procedure NewRecord(const ARecord: TKRecord); override;
    procedure AfterAdd(const ARecord: TKRecord); override;
  end;

  procedure SendPaymentMail(const ADetailRecord: TKRecord;
    const AMailAddress: string;
    const AMailMessageId: string);


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
  , Kitto.Web.Session
  , Kitto.Web.Application
  , SCM.Accounting
  , SCM.Mail ;

procedure SendPaymentMail(const ADetailRecord: TKRecord;
 const AMailAddress: string;
 const AMailMessageId: string);
var
  LFrom, LSubject, LHTMLBody, LCc: string;

begin
  //Read the message from the yaml file
  GetEmailMsg(AMailMessageId, LFrom, LSubject, LHTMLBody, LCc);
  //Expand the {fieldname} placeholders against the current record
  ADetailRecord.ExpandExpression(LHTMLBody);
  //Send the mail with the complete message
  InsertMailQueue(AMailMessageId, AMailAddress, LFrom, LSubject, LHTMLBody, LCc);
end;

{ TPaymentCheck }

procedure TPaymentCheck.AfterAdd(const ARecord: TKRecord);
var
  LPaymentDetails: TKViewTableStore;
  LPaymentDetail: TKRecord;
  LMasterRecord: TKViewTableRecord;
  i: integer;
  LMailMessageId: string;
begin
  inherited;
  LMasterRecord := ARecord as TKViewTableRecord;
  LPaymentDetails := LMasterRecord.GetDetailStoreByModelName('PaymentDetail');
  if sametext(LMasterRecord.FieldByName('Status').AsString, STS_ACTIVE) then
    LMailMessageId:= 'ConfermaPagamentoMailMessage'
  else
    LMailMessageId:= 'RichiestaPagamentoMailMessage';
  for i := 0 To LPaymentDetails.RecordCount -1 do
  begin
    LPaymentDetail := LPaymentDetails.Records[i];

    SendPaymentMail(LPaymentDetail,
      LMasterRecord.FieldByName('Payer_Email').AsString,
      LMailMessageId);
  end;
end;

procedure TPaymentCheck.BeforeAdd(const ARecord: TKRecord);
var
  LPaymentDetails: TKViewTableStore;
  LPaymentDetail: TKRecord;
  LMasterRecord: TKViewTableRecord;
  i: integer;
begin
  inherited;
  LMasterRecord := ARecord as TKViewTableRecord;
  LPaymentDetails := LMasterRecord.GetDetailStoreByModelName('PaymentDetail');

  if sametext(LMasterRecord.FieldByName('Status').AsString, STS_ACTIVE) then
  begin
    for i := 0 To LPaymentDetails.RecordCount -1 do
    begin
      LPaymentDetail := LPaymentDetails.Records[i];

      InsertCollectionEntryFromPayments(LPaymentDetail);
    end;
  end;
end;

procedure TPaymentCheck.BeforeAddOrUpdate(const ARecord: TKRecord);
begin
  inherited;
  if (ARecord.FieldByName('PaymentMethodId').asString ='CON') or (ARecord.FieldByName('PaymentMethodId').asString ='BON') then
    if not  ARecord.FieldByName('ChequeBank').IsNull
      or  not  ARecord.FieldByName('ChequeNumber').IsNull then
      RaiseError(_('Cheque details are not allowed for the selected payment method'));
  if (ARecord.FieldByName('PaymentMethodId').asString ='CON') or (ARecord.FieldByName('PaymentMethodId').asString ='ASS') then
    if not  ARecord.FieldByName('TransferReference').IsNull then
      RaiseError(_('The transfer reference is not allowed for the selected payment method'));

  if ARecord.FieldByName('PaymentMethod_RequiresBankDetails').AsBoolean and
     (ARecord.FieldByName('DepositBankId').IsNull) then
    RaiseError(_('The deposit bank reference is required'));

  if ARecord.FieldByName('LinesTotalAmount').AsFloat = 0 then
    RaiseError(_('Enter the payment details'));
  if ARecord.FieldByName('LinesTotalAmount').AsFloat <> ARecord.FieldByName('Amount').AsFloat then
    RaiseError(_('The amount paid and the sum of the detail amounts do not match'));
end;



procedure TPaymentCheck.BeforeDelete(const ARecord: TKRecord);
begin
  inherited;
  //Delete the payment details
  DeleteRecord('DETTAGLI_PAGAMENTO', 'MEZZO_PAGAMENTOID', ARecord.FieldByName('Id').AsString);
end;

{ TPaymentDetailSetInstalment }

procedure TPaymentDetailSetInstalment.AfterFieldChange(const AField: TKField; const AOldValue, ANewValue: Variant);
var
  LQuery: TEFDBQuery;
  LDBConnection: TEFDBConnection;
begin
  inherited;
  if AField.Name = 'SubscriptionInstalmentId' then  begin
    LDBConnection := TKConfig.Database;
    LQuery := LDBConnection.CreateDBQuery;
    LQuery.CommandText :=  'SELECT ID, IMPORTO, IMPORTO_PAGATO, IMPORTO_RESIDUO '+
                           ' FROM V_RATE_ISCRIZIONI '+
                           ' WHERE ID = :ID ';
    try
      LQuery.Params.ParamByName('ID').AsString := ANewValue;
      LQuery.Open;
      if not LQuery.DataSet.IsEmpty then begin
        AField.ParentRecord.FieldByName('InstalmentAmount').AsCurrency        := LQuery.DataSet.FieldByName('IMPORTO').AsCurrency;
        AField.ParentRecord.FieldByName('InstalmentPaidAmount').AsCurrency  := LQuery.DataSet.FieldByName('IMPORTO_PAGATO').AsCurrency;
        AField.ParentRecord.FieldByName('InstalmentOutstandingAmount').AsCurrency := LQuery.DataSet.FieldByName('IMPORTO_RESIDUO').AsCurrency;
        if AField.ParentRecord.FieldByName('PaidAmount').IsNull or
          (AField.ParentRecord.FieldByName('PaidAmount').AsCurrency = 0) then
          AField.ParentRecord.FieldByName('PaidAmount').AsCurrency              :=  LQuery.DataSet.FieldByName('IMPORTO_RESIDUO').AsCurrency;

      end;
        LQuery.Close;
      finally
        FreeAndNil(LQuery);
      end;
    end;
end;

{ TPaymentDetailCheck }

procedure TPaymentDetailCheck.AfterDelete(const ARecord: TKRecord);
begin
  inherited;
//update the master
  RecalcPaymentLinesTotal(ARecord);
end;

procedure TPaymentDetailCheck.BeforeAddOrUpdate(const ARecord: TKRecord);
begin
  inherited;
//update the master
  RecalcPaymentLinesTotal(ARecord);
end;

procedure TPaymentDetailCheck.RecalcPaymentLinesTotal(const ARecord: TKRecord);
var
  LLinesTotalAmount: currency;
begin
// set the values on the master (payment): calculated field that helps the user and feeds the final reconciliation check
  if Assigned((ARecord as TKViewTableRecord).Store.MasterRecord) then begin
    LLinesTotalAmount := 0;
    TKViewTableRecord(ARecord).Store.Iterate(
      procedure (ARecord: TKRecord)
      begin
        LLinesTotalAmount := LLinesTotalAmount + ARecord.FieldByName('PaidAmount').Value;
      end,
      [TKViewTableRecord(ARecord).Store.ExcludeDeleted()]);
  end;
  TKViewTableRecord(ARecord).Store.MasterRecord.FieldByName('LinesTotalAmount').AsCurrency := LLinesTotalAmount;
end;

{ TPaymentDetailSetPaidAmount }

procedure TPaymentDetailSetPaidAmount.AfterFieldChange(const AField: TKField; const AOldValue, ANewValue: Variant);
begin
  inherited;
  if AField.Name = 'PaidAmount' then
    if AField.ParentRecord.FieldByName('InstalmentOutstandingAmount').AsCurrency <  AField.ParentRecord.FieldByName('PaidAmount').AsCurrency then
      TKWebApplication.Current.Toast(_('Warning: the amount paid is greater than the outstanding amount of the instalment'));
end;

{ TPaymentSetDate }

procedure TPaymentSetDate.AfterFieldChange(const AField: TKField;
  const AOldValue, ANewValue: Variant);
begin
  inherited;
  if AField.Name = 'PaymentDate' then
    AField.ParentRecord.FieldByName('ValueDate').Value := ANewValue;
end;

{ TEnterPayment }

procedure TEnterPayment.AfterAdd(const ARecord: TKRecord);
begin
  inherited;
  {todo}
end;

procedure TEnterPayment.NewRecord(const ARecord: TKRecord);
var
  LId: string;
  LSQLStatement: string;
  LTaxCode: string;
begin
  inherited;
  //read the person data of the parent
  LTaxCode:= TKConfig.Instance.Authenticator.UserName;
  LSQLStatement := GetSQLFieldValue('NOMINATIVI', 'ID', 'CODFISC', LTaxCode) ;
  LId:= EFVarToStr(TKConfig.Database.GetSingletonValue(LSQLStatement));

  if (LId <> '') then // create the person when it does not exist
    ARecord.FieldByName('PayerId').AsString:= LId;

  ARecord.FieldByName('Status').AsString:= STS_ENTERED;
end;

{ TEnterPaymentByAdmin }

procedure TEnterPaymentByAdmin.AfterAdd(const ARecord: TKRecord);
begin
  inherited;

end;

procedure TEnterPaymentByAdmin.NewRecord(const ARecord: TKRecord);
begin
  inherited;
  ARecord.FieldByName('Status').AsString:= STS_ACTIVE;
  ARecord.FieldByName('ApprovalDate').AsDateTime := now ;
end;

{ TPaymentCheckForEditing }

procedure TPaymentCheckForEditing.BeforeDelete(const ARecord: TKRecord);
begin
  inherited;
  if (ARecord.FieldByName('Status').AsString <> STS_ENTERED) then
    RaiseError(_('Payment already confirmed: it cannot be changed'));
end;

procedure TPaymentCheckForEditing.EditRecord(const ARecord: TKRecord);
begin
  inherited;
  if (ARecord.FieldByName('Status').AsString <> STS_ENTERED) then
    RaiseError(_('Payment already confirmed: it cannot be changed'));
end;

initialization
  TKRuleImplRegistry.Instance.RegisterClass(TPaymentCheckForEditing.GetClassId, TPaymentCheckForEditing);
  TKRuleImplRegistry.Instance.RegisterClass(TPaymentDetailCheck.GetClassId, TPaymentDetailCheck);
  TKRuleImplRegistry.Instance.RegisterClass(TPaymentCheck.GetClassId, TPaymentCheck);
  TKRuleImplRegistry.Instance.RegisterClass(TPaymentDetailSetInstalment.GetClassId, TPaymentDetailSetInstalment);
  TKRuleImplRegistry.Instance.RegisterClass(TPaymentDetailSetPaidAmount.GetClassId, TPaymentDetailSetPaidAmount);
  TKRuleImplRegistry.Instance.RegisterClass(TPaymentSetDate.GetClassId, TPaymentSetDate);
  TKRuleImplRegistry.Instance.RegisterClass(TEnterPayment.GetClassId, TEnterPayment);
  TKRuleImplRegistry.Instance.RegisterClass(TEnterPaymentByAdmin.GetClassId, TEnterPaymentByAdmin);

finalization
  TKRuleImplRegistry.Instance.UnregisterClass(TPaymentCheckForEditing.GetClassId);
  TKRuleImplRegistry.Instance.UnregisterClass(TPaymentDetailCheck.GetClassId);
  TKRuleImplRegistry.Instance.UnregisterClass(TPaymentCheck.GetClassId);
  TKRuleImplRegistry.Instance.UnregisterClass(TPaymentDetailSetInstalment.GetClassId);
  TKRuleImplRegistry.Instance.UnregisterClass(TPaymentDetailSetPaidAmount.GetClassId);
  TKRuleImplRegistry.Instance.UnregisterClass(TPaymentSetDate.GetClassId);
  TKRuleImplRegistry.Instance.UnregisterClass(TEnterPayment.GetClassId);
  TKRuleImplRegistry.Instance.UnregisterClass(TEnterPaymentByAdmin.GetClassId);

end.
