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

/// <summary>Tool button controllers of the application: approval and rejection of
/// enrollments and payments, medical visit notification, generation of tax
/// deduction receipts, balance sheet closing and duplication of an enrollment
/// campaign.</summary>
unit SCM.Tools;

interface
uses
  SysUtils,
  Classes,
  SCM.Utils,
  EF.Tree,
  Kitto.Excel,
  SCM.Tool.ExcelExport,
  Kitto.Web.Application,
  Kitto.Html.Controller,
  Kitto.Html.Tools,
  Kitto.Html.Files,
  Kitto.Metadata.DataView,
  Kitto.Tool.Standard,
  Kitto.Tool.SQL,
  Kitto.Tool.Indy,
  Kitto.Store,
  System.StrUtils,
  DBClient,
  SCM.DbUtils, Kitto.DbUtils,
  ShellApi,
  SCM.Mail
  ,Kitto.Tool.DebenuQuickPDF;

Type

  TApprovePayment = class(TKXDataToolController)
  strict protected
    procedure ExecuteTool; override;
  end;

  TRejectPayment = class(TKXDataToolController)
  strict protected
    procedure ExecuteTool; override;
  end;

  TApproveSubscription = class(TKXDataToolController)
  strict protected
    procedure ExecuteTool; override;
  end;

  TRejectSubscription = class(TKXDataToolController)
  strict protected
    procedure ExecuteTool; override;
  end;

  TNotifyMedicalVisit = class(TKXDataToolController)
  strict protected
    procedure ExecuteTool; override;
  end;

  TMembershipRequest = class(TSCMExcelExportTool)
  strict private
  strict protected
    procedure ExecuteTool; override;
    procedure AcceptRecord(ARecord: TKViewTableRecord; var AAccept: boolean); override;
  public
    class function GetDefaultImageName: string; override;
  end;

  TApproveMember = class(TKXDataToolController)
  strict protected
    procedure ExecuteTool; override;
  end;

  TGenerateReceipts = class(TKXDataToolController)
  strict protected
    procedure ExecuteTool; override;
  end;

  TGeneratePaymentReceipts = class(TKXDataToolController)
  strict protected
    procedure ExecuteTool; override;
  end;

  TPrintPaymentReceipts = class(TKXDataToolController)
  strict protected
    procedure ExecuteTool; override;
  end;

  TPrintInvoice = class(TMergePDFToolController)
  strict private
    FFileName: string;
  strict protected
    function GetClientFileName: string; override;
    function GetDefaultFileName: string; override;
    function GetDefaultFileExtension: string; override;
    procedure PrepareFile(const AFileName: string); override;
  end;

  TCloseAndReopenFinancialYear = class(TKXDataToolController)
  strict protected
    procedure ExecuteTool; override;
  end;

  TDuplicateCampaign = class(TKXDataToolController)
  strict protected
    procedure ExecuteTool; override;
  end;

implementation

uses
  Kitto.Web.Session
  , Variants
  , Kitto.Config
  , EF.Localization
  , Math
  , DateUtils
  , EF.DB
  , EF.Sys
  , EF.StrUtils
  , EF.Macros
  , Kitto.Rules
  , EF.VariantUtils
  , SCM.Rules.MedicalVisit
  , SCM.Accounting
  , Kitto.DebenuQuickPDF  ;

{ TApproveSubscription }

procedure TApproveSubscription.ExecuteTool;
var
  I: Integer;
  LEmailAddress, LMailMessageId: string;
  LInsertMembersRegisterSql : string;
  LInsertMembershipFeeCommandText : string;
  LSubscriptionMessage : string;
  LSQLStatementCount : string;
  LMembersRegisterId : string;
  LMembershipFeeId : string;
  LSQLStatement : string;
  LYear, LMonth, LDay : word;
  LFrom, LSubject, LHTMLBody, LCc: string;
  LSubscriptionInstructions: string;
  LInstalments: TKViewTableStore;
  LInstalment: TKViewTableRecord;
begin
  inherited;
  if (ServerRecord.FieldByName('Status').AsString = STS_ACTIVE) then
    raise EKValidationError.Create(_('Subscription already approved'));

  LSubscriptionMessage := '';
  if not ValidMedicalVisitExistsAt(ServerRecord.FieldByName('PersonId').AsString, Date) then
  begin
     LSubscriptionMessage := _('<br> WARNING! There is no valid medical visit for this athlete.');
  end;
  if (ServerRecord.FieldByName('Status').AsString = STS_ENTERED) then
  begin
    TKConfig.Database.StartTransaction;
    try
      //update the status and the acceptance date
      ServerRecord.FieldByName('Status').AsString := STS_ACTIVE ;
      ServerRecord.FieldByName('AcceptanceDate').AsDateTime := now();

      //Save the record through the Model
      ViewTable.Model.SaveRecord(ServerRecord, True, nil, False);

      LSQLStatementCount := GetSQLCountValue('LIBRO_SOCI', 'CODICE_FISCALE', ServerRecord.FieldByName('TaxCode').AsString);
      if EFVarToInt(TKConfig.Database.GetSingletonValue(LSQLStatementCount)) = 0  then
      begin
        LMembersRegisterId := GenerateGuid;

        LInsertMembersRegisterSql :=  'INSERT INTO LIBRO_SOCI '+
                                 ' (ID '+
                                 ' ,DX  '+
                                 ' ,COGNOME  '+
                                 ' ,NOME '+
                                 ' ,DATA_RICHIESTA  '+
                                 ' ,DATA_NASCITA  '+
                                 ' ,LUOGO_NASCITA  '+
                                 ' ,CODICE_FISCALE  '+
                                 ' ,INDIRIZZO) '+
                                 'VALUES '+
                                 '(  '+QuotedStr(LMembersRegisterId)+
                                 ' , '+QuotedStr(ServerRecord.FieldByName('LastName').AsString+' '+ServerRecord.FieldByName('FirstName').AsString)+
                                 ' , '+QuotedStr(ServerRecord.FieldByName('LastName').AsString)+
                                 ' , '+QuotedStr(ServerRecord.FieldByName('FirstName').AsString)+
                                 ' , '+QuotedStr(DateTimeToDelimitedStr(ServerRecord.FieldByName('SubscriptionDate').AsDateTime))+
                                 ' , '+QuotedStr(DateTimeToDelimitedStr(ServerRecord.FieldByName('BirthDate').AsDateTime))+
                                 ' , '+QuotedStr(ServerRecord.FieldByName('Municipality').AsString)+
                                 ' , '+QuotedStr(ServerRecord.FieldByName('TaxCode').AsString)+
                                 ' , '+QuotedStr(ServerRecord.FieldByName('Address').AsString) +')';
        TKConfig.Database.ExecuteImmediate(LInsertMembersRegisterSql);
      end
      else
      begin
        LSQLStatement := GetSQLFieldValue('LIBRO_SOCI', 'ID', 'CODICE_FISCALE', ServerRecord.FieldByName('TaxCode').AsString) ;
        LMembersRegisterId :=  EFVarToStr(TKConfig.Database.GetSingletonValue(LSQLStatement));
      end;

      DecodeDate(ServerRecord.FieldByName('SubscriptionDate').AsDateTime, LYear, LMonth, LDay );

      LSQLStatementCount := 'SELECT COUNT(*) NUM FROM LIBRO_SOCI_QUOTE '+
                            'WHERE SOCIOID = '+QuotedStr(LMembersRegisterId)+' AND '+
                            'ANNO = '+IntToStr(LYear);
      if EFVarToInt(TKConfig.Database.GetSingletonValue(LSQLStatementCount)) = 0  then
      begin
        LMembershipFeeId := GenerateGuid;
        LInsertMembershipFeeCommandText := 'INSERT INTO LIBRO_SOCI_QUOTE '+
              ' (ID '+
              ' ,DX '+
              ' ,SOCIOID '+
              ' ,QUOTA '+
              ' ,NUMERO_TESSERA '+
              ' ,ANNO) '+
              ' VALUES '+
              ' ( '+QuotedStr(LMembershipFeeId)+
              ' , '+QuotedStr(ServerRecord.FieldByName('LastName').AsString+' '+ServerRecord.FieldByName('FirstName').AsString+' '+IntToStr(LYear))+
              ' , '+QuotedStr(LMembersRegisterId)+
              ' , '+ServerRecord.FieldByName('Campaign_MembershipFee').AsString +
              ' , null  '+
              ' , '+IntToStr(LYear)+')  ';
        TKConfig.Database.ExecuteImmediate(LInsertMembershipFeeCommandText);
      end;

      //Insert the accounting entry
      if ServerRecord.FieldByName('SubscriptionTotal').AsCurrency > 0 then
        InsertSubscriptionEntry(ServerRecord);

      //Send the acceptance mail to the user
      if not ServerRecord.FieldByName('ParentEmail').IsNull then
        LEmailAddress := ServerRecord.FieldByName('ParentEmail').AsString
      else
        LEmailAddress := ServerRecord.FieldByName('Email').AsString;

      LMailMessageId := 'ApprovaIscrizioneMailMessage';

      //Send the confirmation mail
      GetEmailMsg(LMailMessageId, LFrom, LSubject, LHTMLBody, LCc);
      ServerRecord.ExpandExpression(LHTMLBody);
      LSQLStatement := GetSQLFieldValue('CAMPAGNE_ISCRIZIONI','NOTE_ISCRIZIONE','ID',
        ServerRecord.FieldByName('CampaignId').AsString);
      LSubscriptionInstructions := EFVarToStr(TKConfig.Database.GetSingletonValue(LSQLStatement));
      LHTMLBody := StringReplace(LHTMLBody, '#IstruzioniIscrizione#', LSubscriptionInstructions, [rfIgnoreCase]);

      //Load every subscription instalment detail into memory
      //so that macros such as
      //{RataIscrizione:1:Amount} or {RataIscrizione:1:DueDate} can be replaced.
      //The prefix below stays Italian on purpose: it is not an identifier of
      //this program but a contract with the mail body stored in TESTI_EMAIL,
      //and it has to keep matching what the text in the table says. It moves
      //only together with that text.
      ServerRecord.LoadDetailStores;
      LInstalments := ServerRecord.GetDetailStoreByModelName('SubscriptionInstalment');
      for I := 0 to LInstalments.RecordCount-1 do
      begin
        LInstalment := LInstalments.Records[I];
        LHTMLBody := StringReplace(LHTMLBody, Format('{RataIscrizione:%d:',[I+1]), '{',
          [rfReplaceAll]);
        LInstalment.ExpandExpression(LHTMLBody);
      end;

      //Queue the mail
      InsertMailQueue(LMailMessageId, LEmailAddress, LFrom, LSubject, LHTMLBody, LCc);

      TKConfig.Database.CommitTransaction;
    except
      TKConfig.Database.RollBackTransaction;
      ServerRecord.FieldByName('Status').AsString := STS_ENTERED;
      ServerRecord.FieldByName('AcceptanceDate').Value := NULL;
      raise;
    end;
    TKWebApplication.Current.Toast(_('A subscription confirmation e-mail has been sent to the user')+LSubscriptionMessage);
  end;
end;

{ TRejectSubscription }

procedure TRejectSubscription.ExecuteTool;
var
  LFrom, LSubject, LHTMLBody, LCc: string;
  LEmailAddress, LMailMessageId: string;
begin
  inherited;
  if (ServerRecord.FieldByName('Status').AsString = STS_ENTERED) then
  begin

    //Update the status and the rejection date
    ServerRecord.FieldByName('Status').AsString := STS_REJECTED ;
    ServerRecord.FieldByName('RejectionDate').AsDateTime := Now();
    (*
    LCommandText := ' update ISCRIZIONI ' +
                    ' set STATUS = ''' + STS_REJECTED + ''''+
                    '     ,DATA_RIFIUTO = ' + QuotedStr(DateTimeToDelimitedStr(Now))+
                    ' WHERE  ID = ''' + ServerRecord.FieldByName('Id').AsString + '''';
    TKConfig.Database.ExecuteImmediate(LCommandText);
    *)
    TKConfig.Database.StartTransaction;
    try
      //Send the rejection mail to the user
      if not ServerRecord.FieldByName('ParentEmail').IsNull then
        LEmailAddress := ServerRecord.FieldByName('ParentEmail').AsString
      else
        LEmailAddress := ServerRecord.FieldByName('Email').AsString;

      LMailMessageId := 'RifiutaIscrizioneMailMessage';
      GetEmailMsg(LMailMessageId, LFrom, LSubject, LHTMLBody, LCc);
      ServerRecord.ExpandExpression(LHTMLBody);

      //Queue the mail
      InsertMailQueue(LMailMessageId, LEmailAddress, LFrom, LSubject, LHTMLBody, LCc);

      //Save the record through the Model
      ViewTable.Model.SaveRecord(ServerRecord, True, nil, False);

      TKConfig.Database.CommitTransaction;
    except
      TKConfig.Database.RollBackTransaction;
      raise;
    end;
    TKWebApplication.Current.Toast(_('A subscription rejection e-mail has been sent to the user'));
  end;
end;

{ TNotifyMedicalVisit }

procedure TNotifyMedicalVisit.ExecuteTool;
var
  LFrom, LSubject, LHTMLBody, LCc: string;
  LEmailAddress, LMailMessageId: string;
begin
  inherited;

  if ServerRecord.FieldByName('NotificationDate').isNull then
    //Update the notification date
    ServerRecord.FieldByName('NotificationDate').AsDateTime := Now()
  else
    begin
      TKWebApplication.Current.Toast(_('The user has already been notified'));
      exit
    end;
  (*
  LCommandText := ' update VISITEMEDICHE ' +
                  ' set DATA_NOTIFICA = ' + QuotedStr(DateTimeToDelimitedStr(Now))+
                  ' WHERE  ID = ''' + ServerRecord.FieldByName('Id').AsString + '''';
  TKConfig.Database.ExecuteImmediate(LCommandText);
  *)
  TKConfig.Database.StartTransaction;
  try
    LEmailAddress := ServerRecord.FieldByName('Person_Email').AsString;
    LMailMessageId := 'NotificaVisitaMedicaMailMessage';
    GetEmailMsg(LMailMessageId, LFrom, LSubject, LHTMLBody, LCc);
    ServerRecord.ExpandExpression(LHTMLBody);

      //Queue the mail
    InsertMailQueue(LMailMessageId, LEmailAddress, LFrom, LSubject, LHTMLBody, LCc);

    //Save the record through the Model
    ViewTable.Model.SaveRecord(ServerRecord, True, nil, False);

    TKConfig.Database.CommitTransaction;
  except
    TKConfig.Database.RollBackTransaction;
    raise;
  raise;

  end;
  //Send the notification mail to the user
  TKWebApplication.Current.Toast(_('An appointment notification e-mail has been sent'));
end;


{ TMembershipRequest }

procedure TMembershipRequest.ExecuteTool;
begin
  TKConfig.Database.StartTransaction;
  try
    inherited ExecuteTool;
    TKConfig.Database.CommitTransaction;
  except
    TKConfig.Database.RollBackTransaction;
    raise;
  end;
end;

procedure TMembershipRequest.AcceptRecord(ARecord: TKViewTableRecord;
  var AAccept: boolean);
begin
  inherited;
  AAccept := ARecord.FieldByName('SubmissionDate').IsNull;

  if AAccept then
  begin
    //Update the notification date
    ARecord.FieldByName('SubmissionDate').AsDateTime := Now();
    (*
    LCommandText := ' update LIBRO_SOCI ' +
                    ' set DATA_PRESENTAZIONE = ' + QuotedStr(DateTimeToDelimitedStr(Now))+
                    ' WHERE  ID = ''' + ARecord.FieldByName('Id').AsString + '''';
    TKConfig.Database.ExecuteImmediate(LCommandText);
    *)

    //Save the record through the Model
    ViewTable.Model.SaveRecord(ARecord, True, nil, False);
  end;
end;

class function TMembershipRequest.GetDefaultImageName: string;
begin
  Result := 'event_available';
end;

{ TApproveMember }

procedure TApproveMember.ExecuteTool;
var
  i : integer;
begin
  inherited;
  TKConfig.Database.StartTransaction;
  try
    //Update the acceptance date
    for i  := 0 to ServerStore.RecordCount -1 do
    begin
      if (not ServerStore.Records.Records[i].FieldByName('SubmissionDate').IsNull) and
         ServerStore.Records.Records[i].FieldByName('AcceptanceDate').IsNull and
         ServerStore.Records.Records[i].FieldByName('RejectionDate').IsNull then
      begin
        ServerStore.Records.Records[i].FieldByName('AcceptanceDate').AsDate := Now();
        (*
        LCommandText := ' update LIBRO_SOCI ' +
                        ' set DATA_ACCETTAZIONE = ' + QuotedStr(DateTimeToDelimitedStr(Now))+
                        ' WHERE  ID = ''' + ServerStore.Records.Records[i].FieldByName('Id').AsString + '''';

        TKConfig.Database.ExecuteImmediate(LCommandText);
        *)
        //Save the record through the Model
        ViewTable.Model.SaveRecord(ServerStore.Records.Records[i], True, nil, False);
      end;
    end;
    TKConfig.Database.CommitTransaction;
  except
    TKConfig.Database.RollBackTransaction;
    raise;
  end;
  TKWebApplication.Current.Toast(_('Members approved'));
end;

{ TGenerateReceipts }

procedure TGenerateReceipts.ExecuteTool;
var
  LCommandText : string;
  LYear, LMonth, LDay : word;
begin
  inherited;
  DecodeDate(Now(), LYear, LMonth, LDay );
  //Generate the tax deduction receipts
  LCommandText := ' INSERT INTO DETRAZIONI_FISCALI '+
                  '(ID '+
                  ',DX '+
                  ',NOMINATIVOID '+
                  ',COGNOME '+
                  ',NOME '+
                  ',CODFISC '+
                  ',INDIRIZZO '+
                  ',CAP '+
                  ',COMUNE '+
                  ',PROVINCIAID '+
                  ',PROVINCIA '+
                  ',PERC_DETRAZIONI '+
                  ',ISCR_COGNOME '+
                  ',ISCR_NOME '+
                  ',ISCR_DATANASC '+
                  ',ISCR_COMUNENASC '+
                  ',ISCR_PROVNASCID '+
                  ',ISCR_PROVNASC '+
                  ',ISCR_CODFISC '+
                  ',IMPORTOPAGATO '+
                  ',IMPORTO_PERC '+
                  ',ANNO '+
                  ',NUMERO '+
                  ',DESC_CAMPAGNA '+
                  ',MOD_PAGAMENTO '+
                  ',PRES_COGNOME '+
                  ',PRES_NOME '+
                  ',DATA_STAMPA '+
                  ',DATA_PAGAMENTO  ) '+
                  'SELECT  '+
                  'REPLACE(CAST(CAST(CRYPT_GEN_RANDOM(16) AS UNIQUEIDENTIFIER) AS VARCHAR(50)),''-'','''') ID '+
                  ',CAST(ANNO_PAGAMENTO AS VARCHAR(10))+''_''+CODFISC+''_''+ISCR_CODFISC DX '+
                  ',NOMINATIVOID '+
                  ',COGNOME '+
                  ',NOME '+
                  ',CODFISC '+
                  ',INDIRIZZO '+
                  ',CAP '+
                  ',COMUNE '+
                  ',PROVINCIAID '+
                  ',PROVINCIA '+
                  ',PERC_DETRAZIONI '+
                  ',ISCR_COGNOME '+
                  ',ISCR_NOME '+
                  ',ISCR_DATANASC '+
                  ',ISCR_COMUNENASC '+
                  ',ISCR_PROVNASCID '+
                  ',ISCR_PROVNASC '+
                  ',ISCR_CODFISC '+
                  ',IMPORTO_PAGATO '+
                  ',IMPORTO_PERC '+
                  ',ANNO_PAGAMENTO '+
                  ',NUMERO '+
                  ',DESC_CAMPAGNA '+
                  ',MOD_PAGAMENTO '+
                  ',PRES_COGNOME '+
                  ',PRES_NOME '+
                  ',CAST(GETDATE() AS DATE)'+
                  ',DATA_PAGAMENTO  '+
                  'FROM V_DETRAZIONI_FAMIGLIA VDF '+
                  'WHERE ANNO_PAGAMENTO = '+IntToStr(LYear-1)+' AND '+
                  'NOT EXISTS(SELECT ID FROM DETRAZIONI_FISCALI DF WHERE '+
                  'VDF.ANNO_PAGAMENTO = DF.ANNO AND VDF.CODFISC = DF.CODFISC '+
                  'AND VDF.ISCR_CODFISC = DF.ISCR_CODFISC ) ';

  TKConfig.Database.ExecuteImmediate(LCommandText);
  TKWebApplication.Current.Toast(_('Completed successfully'));
end;

{ TGeneratePaymentReceipts }

procedure TGeneratePaymentReceipts.ExecuteTool;
var
  LCommandText : string;
  I: Integer;
  LPaymentDetailStore : TKViewTableStore;
  LSubscriptionId : string;
  LYear, LMonth, LDay : word;
  LTaxCode : string;
begin
  inherited;

  //Force the details to load
  ServerRecord.LoadDetailStores;
  //Read the payment details
  LPaymentDetailStore := ServerRecord.GetDetailStoreByModelName('PaymentDetail');

  for I := 0 to LPaymentDetailStore.RecordCount-1 do
  begin
    LSubscriptionId := LPaymentDetailStore.Records[I].FieldByName('SubscriptionInstalment_SubscriptionId').AsString;

    DecodeDate(ServerRecord.FieldByName('PaymentDate').AsDateTime, LYear, LMonth, LDay );
    LTaxCode := EFVarToStr(TKConfig.Database.GetSingletonValue('SELECT CODFISC FROM ISCRIZIONI WHERE ID = '+QuotedStr(LSubscriptionId)));
    //Check whether the deduction already exists
    if EFVarToInt(TKConfig.Database.GetSingletonValue('SELECT COUNT(*) FROM DETRAZIONI_FISCALI WHERE ISCR_CODFISC = '+QuotedStr(LTaxCode)+' AND ANNO = '+IntToStr(LYear))) = 0 then
    begin
      //Generate the tax deduction receipts
      LCommandText := ' INSERT INTO DETRAZIONI_FISCALI '+
                      '(ID '+
                      ',DX '+
                      ',NOMINATIVOID '+
                      ',COGNOME '+
                      ',NOME '+
                      ',CODFISC '+
                      ',INDIRIZZO '+
                      ',CAP '+
                      ',COMUNE '+
                      ',PROVINCIAID '+
                      ',PROVINCIA '+
                      ',PERC_DETRAZIONI '+
                      ',ISCR_COGNOME '+
                      ',ISCR_NOME '+
                      ',ISCR_DATANASC '+
                      ',ISCR_COMUNENASC '+
                      ',ISCR_PROVNASCID '+
                      ',ISCR_PROVNASC '+
                      ',ISCR_CODFISC '+
                      ',IMPORTOPAGATO '+
                      ',IMPORTO_PERC '+
                      ',ANNO '+
                      ',NUMERO '+
                      ',DESC_CAMPAGNA '+
                      ',MOD_PAGAMENTO '+
                      ',PRES_COGNOME '+
                      ',PRES_NOME '+
                      ',DATA_STAMPA '+
                      ',DATA_PAGAMENTO ) '+
                      'SELECT  '+
                      'REPLACE(CAST(CAST(CRYPT_GEN_RANDOM(16) AS UNIQUEIDENTIFIER) AS VARCHAR(50)),''-'','''') ID '+
                      ',CAST(ANNO_PAGAMENTO AS VARCHAR(10))+''_''+CODFISC+''_''+ISCR_CODFISC DX '+
                      ',NOMINATIVOID '+
                      ',COGNOME '+
                      ',NOME '+
                      ',CODFISC '+
                      ',INDIRIZZO '+
                      ',CAP '+
                      ',COMUNE '+
                      ',PROVINCIAID '+
                      ',PROVINCIA '+
                      ',PERC_DETRAZIONI '+
                      ',ISCR_COGNOME '+
                      ',ISCR_NOME '+
                      ',ISCR_DATANASC '+
                      ',ISCR_COMUNENASC '+
                      ',ISCR_PROVNASCID '+
                      ',ISCR_PROVNASC '+
                      ',ISCR_CODFISC '+
                      ',IMPORTO_PAGATO '+
                      ',IMPORTO_PERC '+
                      ',ANNO_PAGAMENTO '+
                      ',NUMERO '+
                      ',DESC_CAMPAGNA '+
                      ',MOD_PAGAMENTO '+
                      ',PRES_COGNOME '+
                      ',PRES_NOME '+
                      ',CAST(GETDATE() AS DATE)'+
                      ',DATA_PAGAMENTO '+
                      'FROM V_DETRAZIONI_FAMIGLIA '+
                      'WHERE ISCR_CODFISC = '+QuotedStr(LTaxCode)+' AND ANNO_PAGAMENTO = '+IntToStr(LYear);

      TKConfig.Database.ExecuteImmediate(LCommandText);
    end;
  end;
  TKWebApplication.Current.Toast(_('Completed successfully'));
end;

{ TPrintPaymentReceipts }

procedure TPrintPaymentReceipts.ExecuteTool;
var
  LMergePDF : TKMergePDFEngine;
  LOriginalFileName, LFileName,
  LLayoutFileName, LBaseFileName: string;
  LPath: string;
  LReceiptRecord: TKViewTableRecord;
  I: Integer;
  LEmailAddress, LMailMessageId: string;
  LFrom, LSubject, LHTMLBody, LCc: string;

begin
  inherited;
  LMergePDF := TKMergePDFEngine.Create(nil);
  Try
    TKConfig.Database.StartTransaction;
    try
      for I := 0 to ServerStore.RecordCount-1 do
      begin
        LReceiptRecord := ServerStore.Records[I];
        if LReceiptRecord.FieldByName('DocumentFile').IsNull then
        begin
          //Read the path
          LPath := IncludeTrailingPathDelimiter(LReceiptRecord.FieldByName('DocumentFile').ViewField.GetExpandedString('Path'));
          LOriginalFileName := 'DF_'+LReceiptRecord.FieldByName('Description').AsString+'.pdf';
          LFileName := GetUniqueFileName(LPath, ExtractFileExt(LOriginalFileName ));
          LLayoutFileName := Config.GetExpandedString('LayoutFileName');
          LBaseFileName := Config.GetExpandedString('BaseFileName');
          LReceiptRecord.ExpandExpression(LBaseFileName);
          //Create the PDF
          LMergePDF.MergePDF(LFileName, LLayoutFileName, LBaseFileName, LReceiptRecord  );
          //Store the file name on the record
          LReceiptRecord.FieldByName('DocumentFile').AsString := ExtractFileName(LFileName);
          LReceiptRecord.FieldByName('OriginalFileName').AsString := LOriginalFileName;

          //Save the record through the Model
          ViewTable.Model.SaveRecord(LReceiptRecord, True, nil, False);

          //Store the file name in the database
          (*
          LCommandText := ' update DETRAZIONI_FISCALI ' +
                          ' set FILE_DOCUMENTO = ' + QuotedStr(ExtractFileName(LFileName)) +
                          '     ,NOME_FILE_ORIGINALE = ' + QuotedStr(LOriginalFileName)+
                          ' WHERE  ID = ' +QuotedStr(LReceiptRecord.FieldByName('Id').AsString);
          TKConfig.Database.ExecuteImmediate(LCommandText);
          *)

          //Send the payment receipt mail
          if not LReceiptRecord.FieldByName('Person_Email').IsNull then
          begin
            LEmailAddress := LReceiptRecord.FieldByName('Person_Email').AsString;
            LMailMessageId := 'RicevutaDisponibileMailMessage';

            //Send the confirmation mail
            GetEmailMsg(LMailMessageId, LFrom, LSubject, LHTMLBody, LCc);
            LReceiptRecord.ExpandExpression(LHTMLBody);

            //Queue the mail
            InsertMailQueue(LMailMessageId, LEmailAddress, LFrom, LSubject, LHTMLBody, LCc);
          end;

        end;
      end;
      TKConfig.Database.CommitTransaction;
    Except
      TKConfig.Database.RollbackTransaction;
      raise;
    end;
    TKWebApplication.Current.Toast(_('Completed successfully'));
  Finally
    FreeAndNil(LMergePDF);
  End;

end;

{ TPrintInvoice }

function TPrintInvoice.GetClientFileName: string;
begin
  Result := FFileName;
end;

function TPrintInvoice.GetDefaultFileExtension: string;
begin
  Result := '.pdf';
end;

function TPrintInvoice.GetDefaultFileName: string;
var
  LPath : string;
begin
  LPath := IncludeTrailingPathDelimiter(ServerRecord.FieldByName('PdfInvoice').ViewField.GetExpandedString('Path'));
  Result := GetUniqueFileName(LPath, '.pdf');
end;

procedure TPrintInvoice.PrepareFile(const AFileName: string);
begin

  if not ServerRecord.FieldByName('PdfInvoiceFileName').IsNull then
    raise EKValidationError.CreateWithAdditionalInfo(_('The PDF invoice already exists.'), _('PDF invoice printing'));

  if not (ServerRecord.FieldByName('EntryType').AsString = CUSTOMER_INVOICE) then
    raise EKValidationError.CreateWithAdditionalInfo(_('Select an invoice.'), _('XML invoice generation'));

  FFileName := 'PdfInvoice_'+ServerRecord.FieldByName('DocumentNumber').AsString+'_'+
               DateToCompactStr(ServerRecord.FieldByName('DocumentDate').AsDateTime)+'.pdf';
  inherited;

  //Update the data on the record
  ServerRecord.FieldByName('PdfInvoice').AsString := ExtractFileName(AFileName);
  ServerRecord.FieldByName('PdfInvoiceFileName').AsString := FFileName;

  //Save the record through the Model
  ViewTable.Model.SaveRecord(ServerRecord, True, nil, False);

  //Store the file name in the database
  (*
  LCommandUpdText := ' update MOVIMENTI_CONTABILI ' +
                     ' set FATTURA_PDF = ' + QuotedStr(ExtractFileName(AFileName)) +
                     '     ,NOME_FATTURA_PDF = ' + QuotedStr(FFileName)+
                     ' WHERE  ID = ' +QuotedStr(ServerRecord.FieldByName('Id').AsString);
  TKConfig.Database.ExecuteImmediate(LCommandUpdText);
  *)
end;

{ TCloseAndReopenFinancialYear }

procedure TCloseAndReopenFinancialYear.ExecuteTool;
begin
  inherited;
  CloseAndReopenBalanceSheet(ServerStore);
  TKWebApplication.Current.Toast(_('Completed successfully'));
end;

{ TDuplicateCampaign }

procedure TDuplicateCampaign.ExecuteTool;
var
  LCommandText: string;
  LQuery: TEFDBQuery;
  LCampaignId : string;
  LDesc: string;
begin
  inherited;
  if ServerRecord.FieldByName('Id').AsString <> '' then
  begin
    LQuery :=  TKConfig.Database.CreateDBQuery;
    Try
      TKConfig.Database.StartTransaction;
      Try
        LCommandText := 'SELECT   '+
                        'ID,  '+
                        'DX '+
                      'FROM   '+
                      '  CAMPAGNE_ISCRIZIONI  '+
                      'WHERE '+
                      '  STAGIONEID in (SELECT ID FROM STAGIONE WHERE DATAFINE = :DateParam ) ';

        LQuery.CommandText := LCommandText;
        LQuery.Params[0].AsDateTime := ServerRecord.FieldByName('StartDate').AsDateTime-1;
        LQuery.Open;
        while not LQuery.DataSet.Eof do
        begin
          LCampaignId := GenerateGuid;
          LDesc := _('Subscriptions') + ' ' + ServerRecord.FieldByName('Description').AsString;
          //insert the new campaign
          LCommandText := 'INSERT INTO '+
                          '	CAMPAGNE_ISCRIZIONI '+
                          '	  ( '+
                          '	  [CLASS] '+
                          '      ,[ID] '+
                          '      ,[UPDATECOUNT] '+
                          '      ,[DX] '+
                          '      ,[UPDTIMESTAMP] '+
                          '      ,[STAGIONECLASS] '+
                          '      ,[STAGIONEID] '+
                          '      ,[NOTE_ISCRIZIONE] '+
                          '      ,[SCONTO_RATA_UNICA] '+
                          '      ,[SCONTO_FRATELLI] '+
                          '      ,[SCADENZA_SCONTO] '+
                          '      ,[INIZIO] '+
                          '      ,[FINE] '+
                          '      ,[QUOTA_ASSOCIATIVA] '+
                          '      ,[FLAG_ATT_SPORTIVA]) '+
                          '	SELECT '+
                          '	  [CLASS] '+
                          '      ,'+QuotedStr(LCampaignId)+' '+
                          '      ,0 '+
                          '      ,'+QuotedStr(LDesc )+' '+
                          '      ,GETDATE() '+
                          '      ,[STAGIONECLASS] '+
                          '      ,'+QuotedStr(ServerRecord.FieldByName('Id').AsString)+' '+
                          '      ,[NOTE_ISCRIZIONE] '+
                          '      ,[SCONTO_RATA_UNICA] '+
                          '      ,[SCONTO_FRATELLI] '+
                          '      ,[SCADENZA_SCONTO] '+
                          '      ,DATEADD(YEAR, 1, [INIZIO]) '+
                          '      ,DATEADD(YEAR, 1, [FINE]) '+
                          '      ,[QUOTA_ASSOCIATIVA] '+
                          '      ,[FLAG_ATT_SPORTIVA] '+
                          '    FROM '+
                          '	  CAMPAGNE_ISCRIZIONI '+
                          '	WHERE '+
                          '  ID = '+QuotedStr(LQuery.DataSet.FieldByName('ID').AsString);
          TKConfig.Database.ExecuteImmediate(LCommandText);
          //insert the fees of the new campaign
          LCommandText := 'INSERT INTO '+
                          '	  QUOTE_ISCRIZIONI '+
                          '	  ([CLASS] '+
                          '      ,[ID] '+
                          '      ,[UPDATECOUNT] '+
                          '      ,[DX] '+
                          '      ,[UPDTIMESTAMP] '+
                          '      ,[CAMPAGNACLASS] '+
                          '      ,[CAMPAGNAID] '+
                          '      ,[ANNO_DAL] '+
                          '      ,[ANNO_AL] '+
                          '      ,[DATASCADENZA1] '+
                          '      ,[QUOTA1] '+
                          '      ,[DATASCADENZA2] '+
                          '      ,[QUOTA2] '+
                          '      ,[DATASCADENZA3] '+
                          '      ,[QUOTA3] '+
                          '      ,[DATASCADENZA4] '+
                          '      ,[QUOTA4] '+
                          '      ,[DATASCADENZA5] '+
                          '      ,[QUOTA5] '+
                          '      ,[TOTALE_QUOTA]) '+
                          '	SELECT '+
                          '	  [CLASS] '+
                          '      ,CAST(REPLACE(NEWID(),''-'','''') AS VARCHAR(32)) '+
                          '      ,0 '+
                          '      ,[DX] '+
                          '      ,GETDATE() '+
                          '      ,[CAMPAGNACLASS] '+
                          '      ,'+QuotedStr(LCampaignId)+' '+
                          '      ,[ANNO_DAL]+1 '+
                          '      ,[ANNO_AL]+1 '+
                          '      ,DATEADD(YEAR, 1, [DATASCADENZA1]) '+
                          '      ,[QUOTA1] '+
                          '      ,DATEADD(YEAR, 1, [DATASCADENZA2]) '+
                          '      ,[QUOTA2] '+
                          '      ,DATEADD(YEAR, 1, [DATASCADENZA3]) '+
                          '      ,[QUOTA3] '+
                          '      ,DATEADD(YEAR, 1, [DATASCADENZA4]) '+
                          '      ,[QUOTA4] '+
                          '      ,DATEADD(YEAR, 1, [DATASCADENZA5]) '+
                          '      ,[QUOTA5] '+
                          '      ,[TOTALE_QUOTA] '+
                          '    FROM '+
                          '	  QUOTE_ISCRIZIONI '+
                          '	WHERE '+
                          '	  CAMPAGNAID = '+QuotedStr(LQuery.DataSet.FieldByName('ID').AsString);
          TKConfig.Database.ExecuteImmediate(LCommandText);
          LQuery.DataSet.Next;
        end;

        TKConfig.Database.CommitTransaction;
      Except
        on E:Exception do
        begin
          TKConfig.Database.RollbackTransaction;
          TKWebApplication.Current.Toast(_('The campaign could not be duplicated: ')+E.Message);
        end;
      End;
    Finally
     FreeAndNil(LQuery);
    End;
  end;


end;

{ TApprovePayment }

procedure TApprovePayment.ExecuteTool;
var
  LMasterRecord: TKViewTableRecord;
  LPaymentDetails: TKViewTableStore;
  LPaymentDetail: TKRecord;
  LEmailAddress,
  LMailMessageId,
  LFrom,
  LSubject,
  LHTMLBody,
  LCc: string;
  i: integer;
begin
  inherited;
  if (ServerRecord.FieldByName('Status').AsString = STS_REJECTED) then
    raise EKValidationError.Create(_('The payment has already been rejected'));
  if (ServerRecord.FieldByName('Status').AsString = STS_ACTIVE) then
    raise EKValidationError.Create(_('Payment already approved'));
  if (ServerRecord.FieldByName('Status').AsString = STS_ENTERED) then
  begin
    //Update the status
    ServerRecord.FieldByName('Status').AsString := STS_ACTIVE ;
    ServerRecord.FieldByName('ApprovalDate').AsDateTime := Now();
    (*
    LCommandText := ' update MEZZI_PAGAMENTO ' +
                    ' set STATUS = ''' + STS_ACTIVE + ''''+
                    '     ,DATA_APPROVAZIONE = ' + QuotedStr(DateTimeToDelimitedStr(Now))+
                    ' WHERE  ID = ''' + ServerRecord.FieldByName('Id').AsString + '''';
    *)
    TKConfig.Database.StartTransaction;
    try
      //TKConfig.Database.ExecuteImmediate(LCommandText);

      //Save the record through the Model
      ViewTable.Model.SaveRecord(ServerRecord, True, nil, False);

      //Send the payment acceptance mail
      ServerRecord.LoadDetailStores;
      LMasterRecord := ServerRecord as TKViewTableRecord;
      LPaymentDetails := LMasterRecord.GetDetailStoreByModelName('PaymentDetail');

      LEmailAddress := ServerRecord.FieldByName('Payer_Email').AsString;
      LMailMessageId := 'ConfermaPagamentoMailMessage';

      for i := 0 To LPaymentDetails.RecordCount -1 do
      begin
        LPaymentDetail := LPaymentDetails.Records[i];

        //Insert the accounting entry
        InsertCollectionEntryFromPayments(LPaymentDetail);

        GetEmailMsg(LMailMessageId, LFrom, LSubject, LHTMLBody, LCc);
        LPaymentDetail.ExpandExpression(LHTMLBody);

        //Queue the mail
        InsertMailQueue(LMailMessageId, LEmailAddress, LFrom, LSubject, LHTMLBody, LCc);
      end;

      TKConfig.Database.CommitTransaction;
    except
      //Update the status
      ServerRecord.FieldByName('Status').AsString := STS_ENTERED ;
      ServerRecord.FieldByName('ApprovalDate').Clear ;

      TKConfig.Database.RollBackTransaction;
      raise;
    end;
    TKWebApplication.Current.Toast(_('A payment confirmation e-mail has been sent to the user'));
  end;
end;

{ TRejectPayment }

procedure TRejectPayment.ExecuteTool;
var
  LMasterRecord: TKViewTableRecord;
  LPaymentDetails: TKViewTableStore;
  LPaymentDetail: TKRecord;
  LEmailAddress,
  LMailMessageId,
  LFrom,
  LSubject,
  LHTMLBody,
  LCc: string;
  i: integer;
begin
  inherited;
  if (ServerRecord.FieldByName('Status').AsString = STS_ACTIVE) then
    raise EKValidationError.Create(_('The payment has already been approved'));
  if (ServerRecord.FieldByName('Status').AsString = STS_REJECTED) then
    raise EKValidationError.Create(_('Payment already rejected'));
  if (ServerRecord.FieldByName('Status').AsString = STS_ENTERED) then
  begin
    //Update the status
    ServerRecord.FieldByName('Status').AsString := STS_REJECTED ;
    ServerRecord.FieldByName('RejectionDate').AsDateTime := Now();
    (*
    LCommandText := ' update MEZZI_PAGAMENTO ' +
                    ' set STATUS = ''' + STS_REJECTED + ''''+
                    '     ,DATA_RIFIUTO = ' + QuotedStr(DateTimeToDelimitedStr(Now))+
                    ' WHERE  ID = ''' + ServerRecord.FieldByName('Id').AsString + '''';
    *)
    TKConfig.Database.StartTransaction;
    try
      //TKConfig.Database.ExecuteImmediate(LCommandText);

      //Save the record through the Model
      ViewTable.Model.SaveRecord(ServerRecord, True, nil, False);

      //Send the payment rejection mail
      ServerRecord.LoadDetailStores;
      LMasterRecord := ServerRecord as TKViewTableRecord;
      LPaymentDetails := LMasterRecord.GetDetailStoreByModelName('PaymentDetail');

      LEmailAddress := ServerRecord.FieldByName('Payer_Email').AsString;
      LMailMessageId := 'ConfermaPagamentoMailMessage';

      for i := 0 To LPaymentDetails.RecordCount -1 do
      begin
        LPaymentDetail := LPaymentDetails.Records[i];
        GetEmailMsg(LMailMessageId, LFrom, LSubject, LHTMLBody, LCc);
        LPaymentDetail.ExpandExpression(LHTMLBody);

        //Queue the mail
        InsertMailQueue(LMailMessageId, LEmailAddress, LFrom, LSubject, LHTMLBody, LCc);
      end;
      TKConfig.Database.CommitTransaction;
    except
      //Update the status
      ServerRecord.FieldByName('Status').AsString := STS_ENTERED ;
      ServerRecord.FieldByName('RejectionDate').Clear ;

      TKConfig.Database.RollBackTransaction;
      raise;
    end;
    TKWebApplication.Current.Toast(_('A payment rejection e-mail has been sent to the user'));
  end;
end;

initialization
  TKXControllerRegistry.Instance.RegisterClass('ApproveSubscription', TApproveSubscription);
  TKXControllerRegistry.Instance.RegisterClass('RejectSubscription', TRejectSubscription);
  TKXControllerRegistry.Instance.RegisterClass('ApprovePayment', TApprovePayment);
  TKXControllerRegistry.Instance.RegisterClass('RejectPayment', TRejectPayment);
  TKXControllerRegistry.Instance.RegisterClass('NotifyMedicalVisit', TNotifyMedicalVisit);
  TKXControllerRegistry.Instance.RegisterClass('MembershipRequest', TMembershipRequest);
  TKXControllerRegistry.Instance.RegisterClass('ApproveMember', TApproveMember);
  TKXControllerRegistry.Instance.RegisterClass('GenerateReceipts', TGenerateReceipts);
  TKXControllerRegistry.Instance.RegisterClass('GeneratePaymentReceipts', TGeneratePaymentReceipts);
  TKXControllerRegistry.Instance.RegisterClass('PrintPaymentReceipts', TPrintPaymentReceipts);
  TKXControllerRegistry.Instance.RegisterClass('PrintInvoice', TPrintInvoice);
  TKXControllerRegistry.Instance.RegisterClass('CloseAndReopenFinancialYear', TCloseAndReopenFinancialYear);
  TKXControllerRegistry.Instance.RegisterClass('DuplicateCampaign', TDuplicateCampaign);

finalization
  TKXControllerRegistry.Instance.UnregisterClass('ApproveSubscription');
  TKXControllerRegistry.Instance.UnregisterClass('RejectSubscription');
  TKXControllerRegistry.Instance.UnregisterClass('ApprovePayment');
  TKXControllerRegistry.Instance.UnregisterClass('RejectPayment');
  TKXControllerRegistry.Instance.UnregisterClass('NotifyMedicalVisit');
  TKXControllerRegistry.Instance.UnregisterClass('MembershipRequest');
  TKXControllerRegistry.Instance.UnregisterClass('ApproveMember');
  TKXControllerRegistry.Instance.UnregisterClass('GenerateReceipts');
  TKXControllerRegistry.Instance.UnregisterClass('GeneratePaymentReceipts');
  TKXControllerRegistry.Instance.UnregisterClass('PrintPaymentReceipts');
  TKXControllerRegistry.Instance.UnregisterClass('PrintInvoice');
  TKXControllerRegistry.Instance.UnregisterClass('CloseAndReopenFinancialYear');
  TKXControllerRegistry.Instance.UnregisterClass('DuplicateCampaign');

end.
