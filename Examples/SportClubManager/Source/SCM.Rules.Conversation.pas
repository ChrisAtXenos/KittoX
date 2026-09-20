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

/// <summary>Business rules of the internal messaging models: creation of a message,
/// enrolment of the participants and rejection of duplicates.</summary>
unit SCM.Rules.Conversation;

interface

uses
  Kitto.Rules, KItto.Store,
  Kitto.Web.Session;

type

  // Rules for a new message
  TCreateMessage = class(TKRuleImpl)
  public
    procedure NewRecord(const ARecord: TKRecord); override;
    procedure AfterFieldChange(const AField: TKField; const AOldValue, ANewValue: Variant); override;
  strict protected
    procedure BeforeAddOrUpdate(const ARecord: TKRecord); override;
  public
    procedure BeforeUpdate(const ARecord: TKRecord); override;
    procedure AfterAdd(const ARecord: TKRecord); override;
  end;

  // Rules that add the participants
  TAddParticipants = class(TKRuleImpl)
  public
    procedure AfterAddOrUpdate(const ARecord: TKRecord); override;
  end;

  TCheckDuplicateParticipants = class(TKRuleImpl)
  strict protected
    procedure BeforeAddOrUpdate(const ARecord: TKRecord); override;
  end;

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

{ TCreateMessage }
procedure TCreateMessage.NewRecord(const ARecord: TKRecord);
begin
  inherited;
  // Read the user id of the message author
  ARecord.FieldByName('CreatedById').AsString := TKConfig.Instance.Authenticator.UserName;
end;

procedure TCreateMessage.AfterAdd(const ARecord: TKRecord);
begin
  var
    LLastMessageDate: TDateTime;
  inherited;
  // Set the date of the last message on the conversation
  LLastMessageDate := ARecord.FieldByName('SentDate').AsDateTime;
  TKViewTableRecord(ARecord).Store.MasterRecord.FieldByName('LastMessageDate').AsCurrency := LLastMessageDate;
end;

procedure TCreateMessage.AfterFieldChange(const AField: TKField;
  const AOldValue, ANewValue: Variant);
begin
  inherited;
  // Set the sender from the data read through CreatedById
  if AField.FieldName = 'CreatedById' then
  begin
    AField.ParentRecord.FieldByName('Sender').AsString :=
      AField.ParentRecord.FieldByName('CreatedBy_FirstName').AsString +' '+
      AField.ParentRecord.FieldByName('CreatedBy_LastName').AsString;
  end;
end;

procedure TCreateMessage.BeforeAddOrUpdate(const ARecord: TKRecord);
var
  LAttachmentDetails: TKViewTableStore;
  LMasterRecord: TKViewTableRecord;
  LMessage: string;
begin
  inherited;
  LMessage := ARecord.FieldByName('Message').AsString;
  LMasterRecord := ARecord as TKViewTableRecord;
  LAttachmentDetails := LMasterRecord.GetDetailStoreByModelName('Attachment');

  // Check that the message carries either text or an attachment
  if (LAttachmentDetails.RecordCount = 0) and (LMessage = '') then
    RaiseError(_('An empty message cannot be sent.'));
end;

procedure TCreateMessage.BeforeUpdate(const ARecord: TKRecord);
begin
  inherited;
  // Mark the edited messages as modified
  ARecord.FieldByName('StatusId').AsString:= '2'
end;

{ TAddParticipants }
procedure TAddParticipants.AfterAddOrUpdate(const ARecord: TKRecord);
begin
  inherited;
  InsertParticipantGroup(ARecord);
end;

{ TCheckDuplicateParticipants }
procedure TCheckDuplicateParticipants.BeforeAddOrUpdate(
  const ARecord: TKRecord);
var
  LPersonIdValue: string;
  LParticipantDetails: TKViewTableStore;
  LParticipantDetail: TKRecord;
  LMasterRecord: TKViewTableRecord;
  i: SmallInt;
begin
  inherited;
  LPersonIdValue := ARecord.FieldByName('PersonId').AsString;
  LMasterRecord := (ARecord as TKViewTableRecord).Store.MasterRecord;
  LParticipantDetails := LMasterRecord.GetDetailStoreByModelName(ModelByRecord(ARecord).ModelName);

  if LPersonIdValue <> '' then
    begin
      for i := 0 to LParticipantDetails.RecordCount -1 do
        begin
          LParticipantDetail := LParticipantDetails.Records[i];

          if (LParticipantDetail.FieldByName('NOMINATIVOID').AsString = LPersonIdValue) and
          (LParticipantDetail.FieldByName('ID').AsString <> ARecord.FieldByName('ID').AsString) then
            RaiseError(_('The same participant cannot be added to the conversation twice.'));
        end;
    end;
end;

initialization
  TKRuleImplRegistry.Instance.RegisterClass(TCreateMessage.GetClassId, TCreateMessage);
  TKRuleImplRegistry.Instance.RegisterClass(TAddParticipants.GetClassId, TAddParticipants);
  TKRuleImplRegistry.Instance.RegisterClass(TCheckDuplicateParticipants.GetClassId, TCheckDuplicateParticipants);

  finalization
  TKRuleImplRegistry.Instance.UnregisterClass(TCreateMessage.GetClassId);
  TKRuleImplRegistry.Instance.UnregisterClass(TAddParticipants.GetClassId);
  TKRuleImplRegistry.Instance.UnregisterClass(TCheckDuplicateParticipants.GetClassId);
end.
