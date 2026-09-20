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

/// <summary>Business rules of the accounting models: fiscal year and registration dates,
/// balancing of the entry rows, VAT amount calculation and automatic reasons.</summary>
unit SCM.Rules.AccountingEntry;

interface

uses
  Kitto.Rules, KItto.Store;

type
  TAccountingEntrySetFinancialYear = class(TKRuleImpl)
  public
    procedure AfterFieldChange(const AField: TKField; const AOldValue, ANewValue: Variant); override;
  end;

  TVatDetailCalcTax = class(TKRuleImpl)
  public
    procedure AfterFieldChange(const AField: TKField; const AOldValue, ANewValue: Variant); override;
  end;

  TAccountingEntrySetPostingDates = class(TKRuleImpl)
  public
    procedure AfterFieldChange(const AField: TKField; const AOldValue, ANewValue: Variant); override;
  end;

///--- MODEL RULES
  TAccountingEntryCheck = class(TKRuleImpl)
  private
    procedure UpdateEditors(ARecord: TKRecord);
  strict protected
    procedure BeforeAddOrUpdate(const ARecord: TKRecord); override;
  public
    procedure AfterAdd(const ARecord: TKRecord); override;
    procedure BeforeDelete(const ARecord: TKRecord); override;
    procedure AfterShowEditWindow(const ARecord: TKRecord); override;
    procedure AfterFieldChange(const AField: TKField; const AOldValue, ANewValue: Variant); override;
    procedure AfterRefreshReferenceField(const AField: TKField); override;
  end;

  TAccountingLineCheck = class(TKRuleImpl)
  private
    procedure UpdateEditors(ARecord: TKRecord);
    procedure   RecalcEntryLinesTotal(const ARecord: TKRecord);
  strict protected
    procedure BeforeAddOrUpdate(const ARecord: TKRecord); override;
  public
    procedure AfterDelete(const ARecord: TKRecord); override;
    procedure AfterShowEditWindow(const ARecord: TKRecord); override;
    procedure AfterFieldChange(const AField: TKField; const AOldValue, ANewValue: Variant); override;
    procedure AfterRefreshReferenceField(const AField: TKField); override;
  end;

  TAutomaticReasonCheck = class(TKRuleImpl)
  public
    procedure BeforeDelete(const ARecord: TKRecord); override;
  end;

implementation

uses
  SysUtils
  , StrUtils
  , Variants
  , EF.Localization
  , EF.VariantUtils
  , EF.DB
  , Kitto.Config
  , SCM.Accounting
  , Kitto.Metadata.DataView
  , SCM.DbUtils, Kitto.DbUtils;



{ TAccountingEntrySetFinancialYear }

procedure TAccountingEntrySetFinancialYear.AfterFieldChange(const AField: TKField;
  const AOldValue, ANewValue: Variant);
begin
  inherited;
  if (AField.Name = 'FinancialYear') and (not AField.IsNull) then
  begin
    AField.ParentRecord.FieldByName('EntryNumber').AsInteger := NewEntryNumber( AField.ParentRecord.FieldByName('FinancialYearId').AsString);
    AField.ParentRecord.FieldByName('Id').AsString := AField.ParentRecord.FieldByName('FinancialYearId').AsString+'_'+
                                                      AField.ParentRecord.FieldByName('EntryNumber').AsString;
  end;
end;


{ TAccountingEntryCheck }

procedure TAccountingEntryCheck.AfterAdd(const ARecord: TKRecord);
var
  LDate : TDateTime;
begin
  inherited;
  if IsVatEntry(ARecord.FieldByName('EntryType').AsString) then
  begin
    if IsCustomerVatEntry(ARecord.FieldByName('EntryType').AsString) then
      LDate := ARecord.FieldByName('DocumentDate').AsDateTime
    else
      LDate := ARecord.FieldByName('PostingDate').AsDateTime;

    UpdateVatProtocol(ARecord.FieldByName('Id').AsString, ARecord.FieldByName('VatRegisterId').AsString, LDate );
  end;
end;

procedure TAccountingEntryCheck.AfterFieldChange(const AField: TKField;
  const AOldValue, ANewValue: Variant);
begin
  inherited;
  if (AField.Name = 'EntryType') or
     (AField.Name = 'PaymentMethod') or
     (AField.Name = 'AccountingReason') then
    UpdateEditors(AField.ParentRecord);


  if (AField.Name = 'EntryType')  then
  begin
    if(AField.IsNull) or IsVatEntry(AField.AsString) then
    begin
      AField.ParentRecord.FieldByName('VatRegister').Value := null;
      AField.ParentRecord.FieldByName('VatProtocolNumber').Value := null;
    end;
  end;
end;

procedure TAccountingEntryCheck.AfterRefreshReferenceField(const AField: TKField);
begin
  inherited;
  if (AField.Name = 'PaymentMethodId') or
     (AField.Name = 'ReasonId') then
    UpdateEditors(AField.ParentRecord);

  if (AField.Name = 'PaymentMethodId')  then
  begin
    if ( AField.IsNull)  or (not AField.ParentRecord.FieldByName('PaymentMethod_RequiresBankDetails').AsBoolean) then
      AField.ParentRecord.FieldByName('Bank').Value := null;
  end;

  if (AField.Name = 'ReasonId') then
  begin
    if (AField.IsNull) or ( not AField.ParentRecord.FieldByName('Reason_DocumentDateRef').AsBoolean) then
      AField.ParentRecord.FieldByName('DocumentDate').Value := null;
    if (AField.IsNull) or (not AField.ParentRecord.FieldByName('Reason_DocumentNumberRef').AsBoolean) then
      AField.ParentRecord.FieldByName('DocumentNumber').Value := null;
  end;
end;

procedure TAccountingEntryCheck.AfterShowEditWindow(const ARecord: TKRecord);
begin
  inherited;
  UpdateEditors(ARecord);
end;

procedure TAccountingEntryCheck.BeforeAddOrUpdate(const ARecord: TKRecord);
var
  LDebitLinesAmount, LCreditLinesAmount, LHeaderAmount: Currency;
begin
  inherited;

  if ARecord.FieldByName('Reason_DocumentDateRef').AsBoolean and
     ARecord.FieldByName('DocumentDate').IsNull then
    RaiseError(_('Document date is required'));

  if ARecord.FieldByName('Reason_DocumentNumberRef').AsBoolean and
     ARecord.FieldByName('DocumentNumber').IsNull then
    RaiseError(_('Document number is required'));

  LDebitLinesAmount := ARecord.FieldByName('TotalDebitLines').AsCurrency;
  LCreditLinesAmount := ARecord.FieldByName('TotalCreditLines').AsCurrency;
  LHeaderAmount := ARecord.FieldByName('Amount').AsCurrency;

  if LDebitLinesAmount <> LCreditLinesAmount then
    RaiseError(Format(_('Debit line total %s differs from credit line total %s'),
      [FormatCurr('#.##0,##',LDebitLinesAmount), FormatCurr('#.##0,##',LCreditLinesAmount)]));

  if (LDebitLinesAmount <>  LHeaderAmount) or
     (LCreditLinesAmount <>  LHeaderAmount) then
    RaiseError(Format(_('Entry amount %s differs from the line total %s'),
      [FormatCurr('#.##0,##',LHeaderAmount), FormatCurr('#.##0,##',Abs(LCreditLinesAmount))]));

  if (not ARecord.FieldByName('PaymentMethod').IsNull) and
      ARecord.FieldByName('PaymentMethod_RequiresBankDetails').AsBoolean and
     (ARecord.FieldByName('BankId').IsNull) then
    RaiseError(_('Bank reference is required'));

  if (not ARecord.FieldByName('PostingDate').IsNull) and
     not ((ARecord.FieldByName('FinancialYear_StartDate').AsDateTime <= ARecord.FieldByName('PostingDate').AsDateTime) and
          (ARecord.FieldByName('FinancialYear_EndDate').AsDateTime >= ARecord.FieldByName('PostingDate').AsDateTime)) then
    RaiseError(_('The posting date falls outside the financial year'));

  if IsVatEntry(ARecord.FieldByName('EntryType').AsString) then
  begin
     if ARecord.FieldByName('VatRegister').IsNull then
       RaiseError(_('VAT entry type: the VAT register is required'));

     if ARecord.FieldByName('TotalVatLines').AsCurrency <> ARecord.FieldByName('TotalTax').AsCurrency then
       RaiseError(_('VAT line total differs from the tax total of the VAT detail'));
  end;
end;

procedure TAccountingEntryCheck.BeforeDelete(const ARecord: TKRecord);
begin
  inherited;
  //Delete the VAT details
  DeleteRecord('DETTAGLI_IVA', 'MOVIMENTOID', ARecord.FieldByName('Id').AsString);
  //Delete the withholdings
  DeleteRecord('DETTAGLI_RITENUTE', 'MOVIMENTOID', ARecord.FieldByName('Id').AsString);
  //Delete the lines
  DeleteRecord('RIGHE_CONTABILI', 'MOVIMENTOID', ARecord.FieldByName('Id').AsString);
end;

procedure TAccountingEntryCheck.UpdateEditors(ARecord: TKRecord);
var
  LDocumentDateRefField : TKField;
  LDocumentDateField: TKField;
  LDocumentNumberRefField : TKField;
  LDocumentNumberField: TKField;
  LPaymentMethodField : TKField;
  LRequiresBankDetailsField : TKField;
  LBankField: TKField;
  LEntryTypeField : TKField;
  LVatRegistersField: TKField;
  LVatProtocolNumberField: TKField;
begin
  if Assigned(ARecord) then
  begin
    LDocumentDateRefField := ARecord.FieldByName('Reason_DocumentDateRef');
    LDocumentDateField :=  ARecord.FieldByName('DocumentDate');
    LDocumentDateField.SetTransientProperty('Visible', LDocumentDateRefField.AsBoolean);

    LDocumentNumberRefField := ARecord.FieldByName('Reason_DocumentNumberRef');
    LDocumentNumberField :=  ARecord.FieldByName('DocumentNumber');
    LDocumentNumberField.SetTransientProperty('Visible', LDocumentNumberRefField.AsBoolean);

    LPaymentMethodField := ARecord.FieldByName('PaymentMethod');
    LRequiresBankDetailsField := ARecord.FieldByName('PaymentMethod_RequiresBankDetails');
    LBankField :=  ARecord.FieldByName('BankId');
    LBankField.SetTransientProperty('Visible', (not LPaymentMethodField.IsNull and LRequiresBankDetailsField.AsBoolean));

    LEntryTypeField := ARecord.FieldByName('EntryType');
    LVatRegistersField := ARecord.FieldByName('VatRegister');
    LVatProtocolNumberField := ARecord.FieldByName('VatProtocolNumber');
    LVatRegistersField.SetTransientProperty('Visible', IsVatEntry(LEntryTypeField.AsString));
    LVatProtocolNumberField.SetTransientProperty('Visible', IsVatEntry(LEntryTypeField.AsString));
  end;
end;

{ TAccountingLineCheck }

procedure TAccountingLineCheck.AfterDelete(const ARecord: TKRecord);
begin
  inherited;

  RecalcEntryLinesTotal(ARecord);
end;

procedure TAccountingLineCheck.AfterFieldChange(const AField: TKField; const AOldValue,
  ANewValue: Variant);
begin
  inherited;
  if AField.Name = 'LedgerAccount' then
    UpdateEditors(AField.ParentRecord);
end;

procedure TAccountingLineCheck.AfterRefreshReferenceField(const AField: TKField);
begin
  inherited;
  if AField.Name = 'AccountId' then
    UpdateEditors(AField.ParentRecord);
end;

procedure TAccountingLineCheck.AfterShowEditWindow(const ARecord: TKRecord);
begin
  inherited;
  UpdateEditors(ARecord);
end;

procedure TAccountingLineCheck.BeforeAddOrUpdate(const ARecord: TKRecord);
begin
  inherited;
  if ARecord.FieldByName('Account_CustomerReference').AsBoolean and
     ARecord.FieldByName('Customer').IsNull then
    RaiseError(_('Customer is required'));

  if ARecord.FieldByName('Account_SupplierReference').AsBoolean and
     ARecord.FieldByName('Supplier').IsNull then
    RaiseError(_('Supplier is required'));

  if ARecord.FieldByName('Account_BankAccountReference').AsBoolean and
     ARecord.FieldByName('Bank').IsNull then
    RaiseError(_('Bank is required'));

  if ARecord.FieldByName('Account_MemberReference').AsBoolean and
     ARecord.FieldByName('Person').IsNull then
    RaiseError(_('Member is required'));

  if (not ARecord.FieldByName('Account_CustomerReference').AsBoolean) and
     (not ARecord.FieldByName('Customer').IsNull) then
    RaiseError(_('A customer reference is not allowed'));

  if (not ARecord.FieldByName('Account_SupplierReference').AsBoolean) and
     (not ARecord.FieldByName('Supplier').IsNull) then
    RaiseError(_('A supplier reference is not allowed'));

  if (not ARecord.FieldByName('Account_BankAccountReference').AsBoolean) and
     (not ARecord.FieldByName('Bank').IsNull) then
    RaiseError(_('A bank reference is not allowed'));

  if (not ARecord.FieldByName('Account_MemberReference').AsBoolean) and
     (not ARecord.FieldByName('Person').IsNull) then
    RaiseError(_('A member reference is not allowed'));

  RecalcEntryLinesTotal(ARecord);
end;

procedure TAccountingLineCheck.RecalcEntryLinesTotal(const ARecord: TKRecord);
var
  LDebitLinesTotalAmount,
  LCreditLinesTotalAmount: currency;
begin
// set the values on the master (entry): calculated field used for the final reconciliation check
  if Assigned((ARecord as TKViewTableRecord).Store.MasterRecord) then
  begin
    LDebitLinesTotalAmount := 0;
    LCreditLinesTotalAmount := 0;
    TKViewTableRecord(ARecord).Store.Iterate(
      procedure (ARecord: TKRecord)
      begin
        if ARecord.FieldByName('Sign').Value = DEBIT_SIGN then
          LDebitLinesTotalAmount := LDebitLinesTotalAmount + ARecord.FieldByName('Amount').Value
        else
          LCreditLinesTotalAmount := LCreditLinesTotalAmount + ARecord.FieldByName('Amount').Value;
      end,
      [TKViewTableRecord(ARecord).Store.ExcludeDeleted()]);
  end;
  TKViewTableRecord(ARecord).Store.MasterRecord.FieldByName('TotalDebitLines').AsCurrency := LDebitLinesTotalAmount;
  TKViewTableRecord(ARecord).Store.MasterRecord.FieldByName('TotalCreditLines').AsCurrency := LCreditLinesTotalAmount;
end;

procedure TAccountingLineCheck.UpdateEditors(ARecord: TKRecord);
var
  LCustomerReferenceField : TKField;
  LCustomerField: TKField;
  LSupplierReferenceField : TKField;
  LSupplierField: TKField;
  LBankAccountReferenceField : TKField;
  LBankField: TKField;
  LMemberReferenceField : TKField;
  LPersonField: TKField;
begin
  if Assigned(ARecord) then
  begin
    LCustomerReferenceField := ARecord.FieldByName('Account_CustomerReference');
    LCustomerField :=  ARecord.FieldByName('Customer');
    LCustomerField.SetTransientProperty('Visible', LCustomerReferenceField.AsBoolean);

    LSupplierReferenceField := ARecord.FieldByName('Account_SupplierReference');
    LSupplierField := ARecord.FieldByName('Supplier');
    LSupplierField.SetTransientProperty('Visible', LSupplierReferenceField.AsBoolean);

    LBankAccountReferenceField := ARecord.FieldByName('Account_BankAccountReference');
    LBankField := ARecord.FieldByName('Bank');
    LBankField.SetTransientProperty('Visible', LBankAccountReferenceField.AsBoolean);

    LMemberReferenceField := ARecord.FieldByName('Account_MemberReference');
    LPersonField := ARecord.FieldByName('Person');
    LPersonField.SetTransientProperty('Visible', LMemberReferenceField.AsBoolean);
  end;
end;

{ TVatDetailCalcTax }

procedure TVatDetailCalcTax.AfterFieldChange(const AField: TKField;
  const AOldValue, ANewValue: Variant);
begin
  inherited;

  if (not AField.ParentRecord.FieldByName('TaxableAmount').IsNull) and
     (not AField.ParentRecord.FieldByName('VatCode').IsNull) then
  begin
    AField.ParentRecord.FieldByName('Tax').AsCurrency := AField.ParentRecord.FieldByName('TaxableAmount').AsCurrency*
                                                             AField.ParentRecord.FieldByName('VatCode_RatePercent').AsCurrency/100;

    AField.ParentRecord.FieldByName('NonDeductibleTax').AsCurrency := AField.ParentRecord.FieldByName('Tax').AsCurrency *
                                                             AField.ParentRecord.FieldByName('VatCode_NonDeductiblePercent').AsCurrency/100;
    AField.ParentRecord.FieldByName('DeductibleTax').AsCurrency := AField.ParentRecord.FieldByName('Tax').AsCurrency -
                                                             AField.ParentRecord.FieldByName('NonDeductibleTax').AsCurrency ;
  end;
end;

{ TAccountingEntrySetPostingDates }

procedure TAccountingEntrySetPostingDates.AfterFieldChange(const AField: TKField;
  const AOldValue, ANewValue: Variant);
begin
  inherited;
  AField.ParentRecord.FieldByName('FinancialYearId').AsString := GetFinancialYearFromDate(AField.AsDateTime);
end;

{ TAutomaticReasonCheck }

procedure TAutomaticReasonCheck.BeforeDelete(const ARecord: TKRecord);
begin
  inherited;
  //Delete the linked automatic accounts
  DeleteRecord('CONTI_AUTO', 'CAUSALEAUTOID', ARecord.FieldByName('Id').AsString);
end;

initialization
  TKRuleImplRegistry.Instance.RegisterClass(TAccountingEntrySetFinancialYear.GetClassId, TAccountingEntrySetFinancialYear);
  TKRuleImplRegistry.Instance.RegisterClass(TAccountingEntryCheck.GetClassId, TAccountingEntryCheck);
  TKRuleImplRegistry.Instance.RegisterClass(TAccountingLineCheck.GetClassId, TAccountingLineCheck);
  TKRuleImplRegistry.Instance.RegisterClass(TVatDetailCalcTax.GetClassId, TVatDetailCalcTax);
  TKRuleImplRegistry.Instance.RegisterClass(TAccountingEntrySetPostingDates.GetClassId, TAccountingEntrySetPostingDates);
  TKRuleImplRegistry.Instance.RegisterClass(TAutomaticReasonCheck.GetClassId, TAutomaticReasonCheck);

finalization
  TKRuleImplRegistry.Instance.UnregisterClass(TAccountingEntrySetFinancialYear.GetClassId);
  TKRuleImplRegistry.Instance.UnregisterClass(TAccountingEntryCheck.GetClassId);
  TKRuleImplRegistry.Instance.UnregisterClass(TAccountingLineCheck.GetClassId);
  TKRuleImplRegistry.Instance.UnRegisterClass(TVatDetailCalcTax.GetClassId);
  TKRuleImplRegistry.Instance.UnRegisterClass(TAccountingEntrySetPostingDates.GetClassId);
  TKRuleImplRegistry.Instance.UnRegisterClass(TAutomaticReasonCheck.GetClassId);

end.
