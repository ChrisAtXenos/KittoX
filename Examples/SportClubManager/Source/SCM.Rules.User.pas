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

/// <summary>Business rules of the application user model: public registration with
/// privacy consent and age check, generation and hashing of the password, and
/// creation of the matching person and family.</summary>
unit SCM.Rules.User;

interface

uses
  Kitto.Rules, KItto.Store;

type

///--- MODEL RULES
  TUserCheck = class(TKRuleImpl)
  private
    procedure UpdateEditors(ARecord: TKRecord);
    function GetPasswordHash(const AClearPassword: string): string;
  public
    procedure NewRecord(const ARecord: TKRecord); override;
    procedure AfterShowEditWindow(const ARecord: TKRecord); override;
    procedure AfterAddOrUpdate(const ARecord: TKRecord); override;
    procedure BeforeAddOrUpdate(const ARecord: TKRecord); override;
    procedure AfterFieldChange(const AField: TKField; const AOldValue, ANewValue: Variant); override;
  end;

implementation

uses
  System.SysUtils
  ,System.DateUtils
  ,Data.DB
  ,SCM.Mail
  ,Kitto.Web.Application
  ,EF.Localization
  ,EF.VariantUtils
  ,EF.StrUtils
  ,Kitto.Config
  ,Kitto.Metadata.DataView
  ,Kitto.Web.Session
  ,SCM.DbUtils, Kitto.DbUtils
  ,EF.DB
  ,SCM.Utils;


{ TUserCheck }
procedure TUserCheck.AfterAddOrUpdate(const ARecord: TKRecord);
begin
  inherited;

  if not TKWebApplication.Current.Authenticator.IsAuthenticated then
  begin
    //Create or update the person tied to the new account
    InsertOrUpdatePerson(ARecord);

    TKWebApplication.Current.Toast(_('An e-mail with the instructions to activate the user has been sent'));
  end;
end;

procedure TUserCheck.AfterFieldChange(const AField: TKField; const AOldValue,
  ANewValue: Variant);
var
  LCommandText: string;
  LQuery: TEFDBQuery;
begin
  inherited;
  if AField.FieldName = 'Mobile' then
    UpdateEditors(AField.ParentRecord);

  if (AField.FieldName = 'TaxCode') and (not AField.IsNull) then
  begin
    //Check up front that no active user already has this tax code
    if (not TKWebApplication.Current.Authenticator.IsAuthenticated) and ActiveUserExists(ANewValue) then
      RaiseError(_('Warning: a user with this tax code already exists: request a new password!'));

    //Read the remaining data when it already exists
    Try
      LCommandText := 'SELECT COGNOME, NOME, CELLULARE, EMAIL FROM NOMINATIVI WHERE CODFISC = :ID';
      LQuery := TKConfig.Database.CreateDBQuery;
      LQuery.CommandText := LCommandText;
      try
        LQuery.Params.ParamByName('ID').AsString := ANewValue;
        LQuery.Open;
        if not LQuery.DataSet.IsEmpty then
        begin
          AField.ParentRecord.FieldByName('LastName').AsString := LQuery.DataSet.FieldByName('COGNOME').AsString;
          AField.ParentRecord.FieldByName('FirstName').AsString := LQuery.DataSet.FieldByName('NOME').AsString;
          AField.ParentRecord.FieldByName('Mobile').AsString := LQuery.DataSet.FieldByName('CELLULARE').AsString;
          AField.ParentRecord.FieldByName('Email').AsString := LQuery.DataSet.FieldByName('EMAIL').AsString;
        end;
      finally
        LQuery.Close;
      end;
    finally
      FreeAndNil(LQuery);
    end;

  end;
end;

procedure TUserCheck.BeforeAddOrUpdate(const ARecord: TKRecord);
var
  LBirthDate: TDateTime;
  LEta: Integer;
  LFrom, LSubject, LHTMLBody, LCc: string;
  LTaxCode, LUserName, LEmailAddress, LPassword, LMailMessageId, LLastName, LFirstName: string;
  LPasswordField: TKField;
begin
  inherited;
  LPasswordField := ARecord.FindField('Password');

  //The checks differ depending on whether a new user is being entered
  //Coming from the RegisterNewUser view
  if not TKWebApplication.Current.Authenticator.IsAuthenticated then
  begin
    //Check the privacy consent:
    if not ARecord.FieldByName('PrivacyConsent').AsBoolean then
      RaiseError(_('Privacy consent is required to continue!'));
    //Check the age of the registering person: a minor is not allowed to
    LBirthDate := BirthDateFromTaxCode(ARecord.FieldByName('TaxCode').AsString);
    LEta := Age(LBirthDate);
    if LEta < 18 then
      RaiseError(_('A user who is a minor cannot be registered.'));

    //Check the password strength
    LPassword := LPasswordField.AsString;
    if LPassword <> '' then
      CheckPasswordStrength(LPassword)
    else
    begin
      //Generate a random password when none is given
      LPassword := GeneratePassword(8);
      LPasswordField.AsString := LPassword;
    end;

    //While registering a new user:
    LTaxCode := ARecord.FieldByName('TaxCode').AsString;

    //Check up front that no active user already has this tax code
    if ActiveUserExists(LTaxCode) then
       RaiseError(_('Warning: a user with this tax code already exists: request a new password!'));

    //set ID = tax code
    ARecord.FieldByName('Id').AsString := LTaxCode;   //do not move this after the delete statement

    //A user registered with MUST_CHANGE_PASSWORD = 1 and ACCESS_DENIED = 1
    //has not completed the activation: registering again is allowed so the
    //activation mail can be sent once more, hence the record is deleted
    if UserToActivateExists(LTaxCode) then
      DeleteRecord('APPUSER', ' ID', ARecord.FieldByName('ID').AsString);

    //Set the flags: user blocked, password must be changed
    ARecord.FieldByName('PasswordMustBeChanged').AsBoolean := True;
    ARecord.FieldByName('AccessBlocked').AsBoolean := True;

    //Send the activation mail carrying the password in clear
    LUserName := ARecord.FieldByName('TaxCode').AsString;
    LEmailAddress := ARecord.FieldByName('Email').AsString;
    LMailMessageId := 'RegisterMailMessage';
    LLastName := ARecord.FieldByName('LastName').AsString;
    LFirstName := ARecord.FieldByName('FirstName').AsString;

    GetEmailMsg(LMailMessageId, LFrom, LSubject, LHTMLBody, LCc);
    ARecord.ExpandExpression(LHTMLBody);
    InsertMailQueue(LMailMessageId, LEmailAddress, LFrom, LSubject, LHTMLBody, LCc, '', '', True);

    //Hash the password before storing it in the table
    ARecord.FieldByName('Password').AsString := GetPasswordHash(LPassword);
  end
  else
  begin
    //Authenticated but the view has no password field:
    //this is the ConfirmAccess view
    if not Assigned(LPasswordField) then
    begin
      //Check the privacy consent:
      if not ARecord.FieldByName('PrivacyConsent').AsBoolean then
        RaiseError(_('Privacy consent is required to continue!'));

      //Drop the condition for ConfirmAccess
      TKWebApplication.Current.Authenticator.AuthData.SetInteger('PRIVACY_CONFIRM',1);
      //Restart from the home page
      TKWebApplication.Current.ReloadOrDisplayHomeView;
    end;
  end;
end;

procedure TUserCheck.AfterShowEditWindow(const ARecord: TKRecord);
var
  LPasswordField: TKField;
begin
  inherited;
  LPasswordField := ARecord.FindField('Password');
  if not Assigned(LPasswordField) then
  begin
    //Editing the ConfirmAccess form
    //A field value must be forced,
    //otherwise the save method is not triggered
    //and the privacy flag cannot be checked
    ARecord.FieldByName('CreationDateTime').AsDateTime := Now;
  end
  else
    UpdateEditors(ARecord);
end;

function TUserCheck.GetPasswordHash(const AClearPassword: string): string;
begin
  if TKWebApplication.Current.Authenticator.IsClearPassword then
    Result := AClearPassword
  else
    Result := GetStringHash(AClearPassword);
end;

procedure TUserCheck.NewRecord(const ARecord: TKRecord);
begin
  inherited;
  if not TKWebApplication.Current.Authenticator.IsAuthenticated then
    ARecord.FieldByName('ProfileId').AsString := 'USER'
  else
    ARecord.FieldByName('ProfileId').AsString := 'ADMIN';
end;

procedure TUserCheck.UpdateEditors(ARecord: TKRecord);
var
  LDescriptionField : TKField;
  LMobileField: TKField;
begin
  if Assigned(ARecord) then
  begin
    LDescriptionField := ARecord.FieldByName('Description');
    LMobileField := ARecord.FieldByName('Mobile');
    LDescriptionField.SetTransientProperty('Visible', (LMobileField.AsString <> ''));
    LDescriptionField.SetTransientProperty('CharWidth', Length(LMobileField.AsString)*2);
  end;
end;

initialization
  TKRuleImplRegistry.Instance.RegisterClass(TUserCheck.GetClassId, TUserCheck);

finalization
  TKRuleImplRegistry.Instance.UnregisterClass(TUserCheck.GetClassId);

end.
