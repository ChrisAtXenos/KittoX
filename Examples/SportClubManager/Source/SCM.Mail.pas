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

/// <summary>E-mail helpers: reads a message template, expands its macros, queues the
/// message into the outgoing table and optionally sends it immediately.</summary>
unit SCM.Mail;

interface

procedure SendEmail(const AEmailAddresses, AFrom, ASubject, AHTMLBody, ACC: string;
                    const ATableName: string = ''; const AObjectId: string = '');
procedure GetEmailMsg(const AMailMessageId: string; out AFrom, ASubject, AHTMLBody, ACC: string);
procedure InsertMailQueue(const AEmailTemplateId, AEmailAddresses, AFrom, ASubject, AHTMLBody, ACC: string;
                         const ATableName: string = ''; const AObjectId: string = '';
                         const ASendNow : boolean = False);

implementation

uses
  SysUtils
  ,SCM.Utils
  ,StrUtils
  ,Kitto.Config
  ,Kitto.Web.Session
  ,EF.Tree
  ,EF.YAML
  ,IdSMTP
  ,IdMessage
  ,IdEmailAddress
  ,IdAttachmentFile
  ,IdExplicitTLSClientServerBase
  ,IdSSLOpenSSL
  ,IdText
  ,SCM.Mail.Consts
  ,SCM.DbUtils, Kitto.DbUtils
  ,EF.DB
  ,EF.StrUtils
  ,Data.DB
  ,EF.Macros
  ,EF.Logger
  ,System.Variants
  ,System.Classes;

procedure GetEmailMsg(const AMailMessageId: string; out AFrom, ASubject, AHTMLBody, ACC: string);
var
  LCommandText: string;
  LQuery: TEFDBQuery;

  function GetExpandedFieldString( AField: TField): string;
  begin
    Result := AField.AsString;
    TEFMacroExpansionEngine.Instance.Expand(Result);
  end;

begin
  LCommandText := 'SELECT '+
                  '  EMAIL_FROM '+
                  ' ,EMAIL_SUBJECT '+
                  ' ,EMAIL_ATTACH '+
                  ' ,EMAIL_BODYHTML '+
                  ' ,EMAIL_CC '+
                  'FROM TESTI_EMAIL '+
                  'WHERE ID = :ID ';
  LQuery := TKConfig.Database.CreateDBQuery;
  Try
    LQuery.CommandText := LCommandText;
    try
      LQuery.Params.ParamByName('ID').AsString := UpperCase( AMailMessageId );
      LQuery.Open;
      if not LQuery.DataSet.IsEmpty then
      begin
        AFrom :=  GetExpandedFieldString(LQuery.DataSet.FieldByName('EMAIL_FROM'));
        ASubject := GetExpandedFieldString(LQuery.DataSet.FieldByName('EMAIL_SUBJECT'));
        AHTMLBody := GetExpandedFieldString(LQuery.DataSet.FieldByName('EMAIL_BODYHTML'));
        ACC   :=  GetExpandedFieldString(LQuery.DataSet.FieldByName('EMAIL_CC'));
      end;
    finally
      LQuery.Close;
    end;
  Finally
    FreeAndNil(LQuery);
  End;


{  LMailMessageFileName := TKConfig.GetMetadataPath + 'Views\' + AMailMessageId + '.yaml';
  LMessageNode := TEFYAMLReader.LoadTree(LMailMessageFileName);
  Assert(Assigned(LMessageNode));

  AFrom := LMessageNode.GetExpandedString('From');
  ASubject := LMessageNode.GetExpandedString('Subject');
  AHTMLBody := LMessageNode.GetExpandedString('HTMLBody');
}

end;


procedure SendEmail(const AEmailAddresses, AFrom, ASubject, AHTMLBody, ACC: string;
  const ATableName: string = ''; const AObjectId: string = '');
var
  LServerNode: TEFNode;
  LIdSSLIOHandler: TIdSSLIOHandlerSocketOpenSSL;
  LSMTP: TIdSMTP;
  LMessage: TIdMessage;
  LBody: string;
  LAppPath: string;
  LEmailAddress: string;
  LEmailFrom: string;

  LHost: string;
  LUsername: string;
  LPassword: string;
  LPort: Integer;
  LUseTLS: boolean;
  LTLSMode: string;

  List: TStrings;

  procedure AddTextPart(const AContent, AContentType: string; const AParentPart: Integer = -1);
  begin
    with TIdText.Create(LMessage.MessageParts, nil) do
    begin
      Body.Text := AContent;
      ContentType := AContentType;
      ParentPart := AParentPart;
    end;
  end;

begin
  LIdSSLIOHandler := nil;
  LSMTP := TIdSMTP.Create(nil);
  try
    LSMTP.AuthType := satDefault;
    //LSMTP.AuthType := satSASL;

    LAppPath := TKConfig.Instance.Config.GetExpandedString('AppPath');

    if (pos('localhost', LAppPath) > 0) {$IFDEF DEBUG} or True {$ENDIF} then
    begin
      //Read the settings from the constants in SCM.Mail.Consts, for debugging
      LHost := CONST_SMTP_Host;
      LUsername := CONST_SMTP_Username;
      LPassword := CONST_SMTP_Password;
      LPort := CONST_SMTP_Port;
      LUseTLS := CONST_SMTP_UseTLS;
      LEmailAddress := CONST_MAIL;
      LEmailFrom := CONST_SMTP_Username;
      LTLSMode := CONST_SMTP_TLSMode;
    end
    else
    begin
      //Read the settings from the Email/SMTP/Default node of the configuration
      LServerNode := TKConfig.Instance.Config.FindNode('Email/SMTP/Default');
      LHost := LServerNode.GetExpandedString('HostName');
      LUsername := LServerNode.GetExpandedString('UserName');
      LPassword := LServerNode.GetExpandedString('Password');
      LPort := LServerNode.GetInteger('Port', 25);
      LUseTLS := LServerNode.GetBoolean('UseTLS');
      LTLSMode := LServerNode.GetExpandedString('TLSMode','Require');
      LEmailAddress := AEmailAddresses;
      LEmailFrom := AFrom;
    end;

    if (LUseTLS) then
    begin
      LIdSSLIOHandler := TIdSSLIOHandlerSocketOpenSSL.Create;
      LIdSSLIOHandler.DefaultPort := 0;
      LIdSSLIOHandler.SSLOptions.SSLVersions := [sslvTLSv1, sslvTLSv1_1, sslvTLSv1_2];
      LIdSSLIOHandler.SSLOptions.Mode := sslmUnassigned;
      LIdSSLIOHandler.SSLOptions.VerifyMode := [];
      LIdSSLIOHandler.SSLOptions.VerifyDepth := 0;
      LSMTP.IOHandler := LIdSSLIOHandler;
      if sametext(LTLSMode,'Implicit') then
        LSMTP.UseTLS := utUseImplicitTLS
      else if sametext(LTLSMode,'Require') then
        LSMTP.UseTLS := utUseRequireTLS
      else if sametext(LTLSMode,'Explicit') then
        LSMTP.UseTLS := utUseExplicitTLS;
      LIdSSLIOHandler.Host := LHost;
      LIdSSLIOHandler.Port := LPort;
    end
    else
    begin
      LSMTP.UseTLS := utNoTLSSupport;
    end;

    LSMTP.Port := LPort;
    LSMTP.Host := LHost;
    LSMTP.UserName := LUsername;
    LSMTP.Password := LPassword;

    LMessage := TIdMessage.Create;
    try
      LMessage.Encoding := meDefault;

      // From
      LMessage.From.Address := LEmailFrom;
      LMessage.From.Text := LEmailFrom;
      LMessage.Sender.Address := LEmailFrom;
      LMessage.ConvertPreamble := True;

      // To (multiple addresses)
      LMessage.Recipients.EMailAddresses := LEmailAddress;
      List := TStringList.Create;
      try
        List.Delimiter := ';';
        if aCc <> '' then
        begin
          List.DelimitedText := aCC;
          while List.Count > 0 do begin
          if List[0] <> '' then
              LMessage.CCList.Add.Address := List[0];
            List.Delete(0);
          end;
        end;
      finally
        List.Free;
      end;

      // Subject
      LMessage.Subject := ASubject;

      // Body in Text
      LBody := StripHTML(AHTMLBody);
      // HTML + plaintext
      // no attachments
      LMessage.ContentType := 'multipart/alternative';
      AddTextPart(LBody, 'text/plain');
      AddTextPart(AHTMLBody, 'text/html');

      LSMTP.Connect;
      try
        TEFLogger.Instance.Log(
          Format('Sending email from %s to %s', [
            LMessage.From.Text,
            LMessage.Recipients.EMailAddresses]),
           TEFLogger.LOG_DETAILED);
        LSMTP.Send(LMessage);
      finally
        LSMTP.Disconnect;
      end;
    finally
      FreeAndNil(LMessage);
    end;
  finally
    LSMTP.Free;
    LIdSSLIOHandler.Free;
  end;
end;

procedure InsertMailQueue(const AEmailTemplateId, AEmailAddresses, AFrom, ASubject, AHTMLBody, ACC: string;
  const ATableName: string = ''; const AObjectId: string = ''; const ASendNow : boolean = False);
var
  LCommandText : string;
  LCommand: TEFDBCommand;
  LId: string;
  LBody: string;
  LUserName: string;
begin
  if ASendNow then
    SendEmail(AEmailAddresses, AFrom, ASubject, AHTMLBody, ACC, ATableName, AObjectId);

  LCommandText :=  'INSERT INTO CODA_EMAIL '+
                   '  (ID '+
                   '  ,DX '+
                   '  ,EMAIL_FROM '+
                   '  ,EMAIL_TO '+
                   '  ,EMAIL_SUBJECT '+
                   '  ,EMAIL_BODY '+
                   '  ,EMAIL_CC '+
                   '  ,DATA_ORA_INSERIMENTO '+
                   '  ,OPERATORE_INSERIMENTOID '+
                   '  ,TABELLA_ORIGINE '+
                   '  ,OGGETTO_ORIGINE '+
                   '  ,EMAIL_BODYHTML '+
                   '  ,TESTO_EMAILID '+
                   '  ,DATA_ORA_TRASMISSIONE ) '+
                   'VALUES '+
                   '  (:ID '+
                   '  ,:DX '+
                   '  ,:EMAIL_FROM '+
                   '  ,:EMAIL_TO '+
                   '  ,:EMAIL_SUBJECT '+
                   '  ,:EMAIL_BODY '+
                   '  ,:EMAIL_CC '+
                   '  ,:DATA_ORA_INSERIMENTO '+
                   '  ,:OPERATORE_INSERIMENTOID '+
                   '  ,:TABELLA_ORIGINE '+
                   '  ,:OGGETTO_ORIGINE '+
                   '  ,:EMAIL_BODYHTML'+
                   '  ,:TESTO_EMAILID '+
                   '  ,:DATA_ORA_TRASMISSIONE ) ';

  LCommand := TKConfig.Database.CreateDBCommand;
  try
    LCommand.CommandText := LCommandText;
    LId := CreateCompactGuidStr;
    LBody := StripHTML(AHTMLBody);
    LUserName := TKConfig.Instance.Authenticator.UserName;

    UpdateParamValue(LCommand.Params,'ID', LId);
    UpdateParamValue(LCommand.Params,'DX', ASubject);
    UpdateParamValue(LCommand.Params,'EMAIL_FROM', AFrom);
    UpdateParamValue(LCommand.Params,'EMAIL_TO', AEmailAddresses);
    UpdateParamValue(LCommand.Params,'EMAIL_SUBJECT', ASubject);
    UpdateParamValue(LCommand.Params,'EMAIL_BODY', LBody);
    UpdateParamValue(LCommand.Params,'EMAIL_CC', ACC);
    UpdateParamValue(LCommand.Params,'DATA_ORA_INSERIMENTO', Now);
    UpdateParamValue(LCommand.Params,'OPERATORE_INSERIMENTOID', LUserName);
    UpdateParamValue(LCommand.Params,'TABELLA_ORIGINE', ATableName);
    UpdateParamValue(LCommand.Params,'OGGETTO_ORIGINE', AObjectId);
    UpdateParamValue(LCommand.Params,'EMAIL_BODYHTML', AHTMLBody);
    UpdateParamValue(LCommand.Params,'TESTO_EMAILID', UpperCase(AEmailTemplateId));
    if ASendNow then
      UpdateParamValue(LCommand.Params,'DATA_ORA_TRASMISSIONE', now)
    else
      UpdateParamValue(LCommand.Params,'DATA_ORA_TRASMISSIONE', Null);
    LCommand.Execute;
  finally
    FreeAndNil(LCommand);
  end;
end;


end.
