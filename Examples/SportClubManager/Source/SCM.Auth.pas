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

/// <summary>Application authenticator, an extension of the database one that adds remote
/// login, generation of a temporary password and password reset by e-mail.</summary>
unit SCM.Auth;

interface

uses
  EF.Tree
  , EF.DB
  , EF.Macros
  , Kitto.Auth.DB
  , Kitto.Config
  ;

const
 SECURE_DELAY = 3000;

type
  TSCMAuthenticator = class(TKDBAuthenticator)
  strict private
    function HasRemoteLoginRequest: Boolean;
  protected
    procedure InternalDefaultToAuthData(const AAuthData: TEFNode); override;
    function GetMustConfirmAccess: Boolean; override;
    function GetReadUserCommandText(const AUserName: string): string; override;
    /// <summary>Generates and returns a random password compatible with special rules defined in SetPassword.</summary>
    function GenerateRandomPassword: string; override;
    /// <summary>Try to extract suppliedusername and suppliedpassword from url.</summary>
    procedure GetSuppliedAuthData(const AAuthData: TEFNode; const AHashNeeded: Boolean;
      out ASuppliedUserName, ASuppliedPasswordHash: string;
      out AIsPassepartoutAuthentication: Boolean); override;
    procedure SetPassword(const AValue: string); override;
    /// <summary>Example of sending email for reset password.</summary>
    procedure AfterResetPassword(const ADBConnection: TEFDBConnection; const AParams: TEFNode); override;
    /// <summary>Raise an exception in auto-login fails.</summary>
    function InternalAuthenticate(const AAuthData: TEFNode): Boolean; override;
  public
    procedure ResetPassword(const AParams: TEFNode); override;
    procedure Logout; override;
  end;

implementation

uses
  SysUtils
  , SCM.Mail
  , EF.Localization
  , EF.Logger
  , EF.StrUtils
  , Kitto.Auth
  , SCM.DbUtils, Kitto.DbUtils
  , SCM.Utils
  , SCM.Macros
  , Kitto.Web.Request
  , EF.VariantUtils;

{ TTasKittoAuth }


function TSCMAuthenticator.GenerateRandomPassword: string;
begin
  Result := GeneratePassword;
end;

function TSCMAuthenticator.GetMustConfirmAccess: Boolean;
begin
  Result := AuthData.GetInteger('PRIVACY_CONFIRM') = 0;
end;

function TSCMAuthenticator.GetReadUserCommandText(
  const AUserName: string): string;
begin
  Result := inherited GetReadUserCommandText(AUserName);
  if HasRemoteLoginRequest then
    Result := StringReplace(Result, 'COALESCE(ACCESS_DENIED,0) = 0',
      'COALESCE(ACCESS_DENIED,0) = 1',[rfIgnoreCase]);
end;

procedure TSCMAuthenticator.GetSuppliedAuthData(const AAuthData: TEFNode;
  const AHashNeeded: Boolean; out ASuppliedUserName,
  ASuppliedPasswordHash: string; out AIsPassepartoutAuthentication: Boolean);
begin
  if HasRemoteLoginRequest then
  begin
    AIsPassepartoutAuthentication := False;
    ASuppliedUserName := TKWebRequest.Current.GetQueryField('LoginUserName');
    ASuppliedPasswordHash := TKWebRequest.Current.Current.GetQueryField('LoginPassword');
  end
  else
    inherited;
end;

function TSCMAuthenticator.HasRemoteLoginRequest: Boolean;
begin
  Result := (TKWebRequest.Current.GetQueryField('LoginUserName') <> '') and
    (TKWebRequest.Current.GetQueryField('LoginPassword') <> '');
end;

function TSCMAuthenticator.InternalAuthenticate(
  const AAuthData: TEFNode): Boolean;
begin
  Result := inherited InternalAuthenticate(AAuthData);
  if not Result then
  begin
    if AAuthData.GetString('UserName') <> '' then
      Sleep(SECURE_DELAY);
    if HasRemoteLoginRequest then
    raise Exception.Create(_('Authentication failed!'));

    TEFMacroExpansionSCMEngine.AddMacroExpander;
  end;
end;

procedure TSCMAuthenticator.InternalDefaultToAuthData(const AAuthData: TEFNode);
begin
  inherited;
  AAuthData.SetString('PROFILEID', 'USER');
end;

procedure TSCMAuthenticator.Logout;
begin
  inherited; //Reload Home
end;

procedure TSCMAuthenticator.ResetPassword(const AParams: TEFNode);
begin
  Try
    inherited;
  Except
    Sleep(SECURE_DELAY);
    raise;
  End;
end;

procedure TSCMAuthenticator.AfterResetPassword(
  const ADBConnection: TEFDBConnection; const AParams: TEFNode);
var
  LUserName, LEmailAddress, LPassword: string;
  LMailMessageId, LFrom, LSubject, LHTMLBody, LCc: string;
begin
  inherited;
  LUserName := AParams.GetString('UserName');
  LEmailAddress := AParams.GetString('EmailAddress');
  LPassword := AParams.GetString('Password');

  LMailMessageId := 'ResetMailMessage';
  GetEmailMsg(LMailMessageId, LFrom, LSubject, LHTMLBody, LCc);
  // Substitute Template UserName
  LHTMLBody := StringReplace(LHTMLBody, '{Utente}', LUserName, [rfReplaceAll]);
  // Substitute Template Password
  LHTMLBody := StringReplace(LHTMLBody, '{Password}', LPassword, [rfReplaceAll]);
  InsertMailQueue(LMailMessageId, LEmailAddress, LFrom, LSubject, LHTMLBody, LCc, '', '', True);
end;

procedure TSCMAuthenticator.SetPassword(const AValue: string);
var
  LEmailAddress : string;
  LMailMessageId, LFrom, LSubject, LHTMLBody, LCc: string;
begin
  CheckPasswordStrength(AValue);

  LEmailAddress :=  EFVarToStr( TKConfig.Database.GetSingletonValue('SELECT EMAIL_ADDRESS FROM APPUSER WHERE ID = '+QuotedStr(UserName)) ) ;
  if LEmailAddress <> '' then
  begin
    LMailMessageId := 'SetPasswordMailMessage';
    GetEmailMsg(LMailMessageId, LFrom, LSubject, LHTMLBody, LCc);
    InsertMailQueue(LMailMessageId, LEmailAddress, LFrom, LSubject, LHTMLBody, LCc, '', '', True);
  end;
  inherited;
end;

initialization
  TKAuthenticatorRegistry.Instance.RegisterClass('SCMAuthenticator', TSCMAuthenticator);

finalization
  TKAuthenticatorRegistry.Instance.UnregisterClass('SCMAuthenticator');

end.
