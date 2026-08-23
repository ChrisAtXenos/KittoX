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

/// <summary>
///   Self-contained attribute-based handler for the authentication family
///   (Sprint E.1.d of the routing refactor): login, reset-password,
///   change-password and logout. Replaces the delegating handler that used to
///   live in Kitto.Html.Login and call TKWebApplication.HandleKX*Request.
///
///   The endpoints are [TKXAnonymous] (reachable without prior authentication)
///   and the orchestration is split into virtual hooks so an application can
///   override individual steps by deriving from TKXAuthHandlerBase — e.g. to
///   accept an identity minted by a host web app instead of the built-in login.
///
///   The login PAGE (GET '/') is still served by TKWebApplication.Home; this
///   unit only handles the POST/action endpoints under /kx.
/// </summary>
unit Kitto.Web.Handler.Auth;

{$I Kitto.Defines.inc}

interface

uses
  EF.Tree,
  Kitto.Web.Routing.Attributes;

type
  {$RTTI EXPLICIT METHODS([vcPublic, vcPublished]) PROPERTIES([vcPublic, vcPublished])}
  /// <summary>
  ///   Default auth handler. Register in the resource registry; applications
  ///   override behaviour by subclassing and overriding a hook (or a whole
  ///   endpoint method).
  /// </summary>
  [TKXPath('/kx')]
  TKXAuthHandlerBase = class
  protected
    /// <summary>Populates the auth data node from the POST form (UserName /
    /// Password). Override to source credentials elsewhere.</summary>
    procedure BuildAuthData(const AAuthData: TEFNode); virtual;
    /// <summary>Runs after a successful Authenticate: persists the chosen
    /// database cookie, declares the %Auth:* macros and emits the success
    /// marker the login form's JS reacts to.</summary>
    procedure AfterAuthenticateOK(const ADatabaseName: string); virtual;
    /// <summary>True when the request carries X-KittoX: true, i.e. comes from
    /// the single-page client. A native form submission does not.</summary>
    function IsSPARequest: Boolean;
    /// <summary>Runs after a failed Authenticate: emits the "invalid login"
    /// fragment.</summary>
    procedure AfterAuthenticateFail; virtual;
    /// <summary>Performs the actual password reset (default: delegates to the
    /// authenticator). Override to plug a custom reset/e-mail flow.</summary>
    procedure ResetPasswordEmail(const AParams: TEFNode); virtual;
  public
    /// POST form fields: UserName, Password, Language, DatabaseName.
    [TKXPath('/login')] [TKXPOST] [TKXAnonymous]
    procedure HandleLogin; virtual;
    /// <summary>POST form fields: UserName, EmailAddress. Triggers a password
    /// reset for the matching user and shows a confirmation (or error) dialog.</summary>
    [TKXPath('/resetpassword')] [TKXPOST] [TKXAnonymous]
    procedure HandleResetPassword; virtual;
    /// <summary>POST form fields: OldPassword, NewPassword, ConfirmNewPassword.
    /// Validates and applies the new password, then logs out and redirects to
    /// the login page.</summary>
    [TKXPath('/changepassword')] [TKXPOST] [TKXAnonymous]
    procedure HandleChangePassword; virtual;
    /// Ends the current session. Canonical endpoint; menus still emit
    /// GET kx/view/Logout via TKXLogoutController for now.
    [TKXPath('/logout')] [TKXANY] [TKXAnonymous]
    procedure HandleLogout; virtual;
    /// <summary>Announces a page reload issued by the application, so that the
    /// root does not end the session when it serves the reloaded page.
    /// Counterpart of /logout: that one drops the credential, this one keeps it
    /// across a reload the user did not ask for.
    ///
    /// Reaching the root drops the credential on purpose, so that a fresh page
    /// load starts from the login. Server-side paths that send the user back to
    /// the home raise ReloadingHome themselves; a reload started from the
    /// browser cannot, because by the time it reaches the root there is no
    /// earlier request in which to raise it. This endpoint is that earlier
    /// request: the client POSTs here and only then calls location.reload().
    /// It backs the [Reset] / [Retry] buttons of the standard error dialog
    /// (kxReloadApp in kxgrid.js), which reload to recover from a transient
    /// failure on a session that is still valid.
    ///
    /// It grants nothing: the flag is raised only for an already authenticated
    /// session and merely stops a valid credential from being dropped. It is
    /// one-shot, cleared by ServeHomePage, so a second reload — the user
    /// pressing F5 — signs out as it should. [TKXAnonymous] so the call never
    /// fails on the login page, where the same dialog can appear.</summary>
    [TKXPath('/reloadhome')] [TKXPOST] [TKXAnonymous]
    procedure HandleReloadHome; virtual;
  end;

implementation

uses
  System.SysUtils,
  System.NetEncoding,
  EF.Localization,
  EF.StrUtils,
  Kitto.Auth,
  Kitto.Web.Application,
  Kitto.Web.Session,
  Kitto.Web.Request,
  Kitto.Web.Response,
  Kitto.Web.Routing.Registry;

const
  COOKIE_DB_LIFETIME_DAYS = 30;

{ TKXAuthHandlerBase }

procedure TKXAuthHandlerBase.BuildAuthData(const AAuthData: TEFNode);
var
  LUserName, LPassword: string;
begin
  LUserName := TKWebRequest.Current.GetField('UserName');
  LPassword := TKWebRequest.Current.GetField('Password');
  if LUserName <> '' then
    AAuthData.SetString('UserName', LUserName);
  if LPassword <> '' then
    AAuthData.SetString('Password', LPassword);
end;

procedure TKXAuthHandlerBase.AfterAuthenticateOK(const ADatabaseName: string);
var
  LApp: TKWebApplication;
begin
  LApp := TKWebApplication.Current;

  // Persist the chosen environment as a cookie so the next visit pre-selects
  // the same database (30 days). Skipped when the authenticator carries its own
  // session-bound state (Auth: JWT ships the database in the 'db' claim), to
  // avoid a parallel kx_db cookie.
  if (ADatabaseName <> '')
    and not LApp.Authenticator.CarriesSessionIdInCredential then
    TKWebResponse.Current.SetCookie('kx_db', ADatabaseName,
      Now + COOKIE_DB_LIFETIME_DAYS);

  // Expose the active database to macro consumers (%Auth:DatabaseName% /
  // %Auth:Environment%), matching the StatusBar / login combo label.
  LApp.DeclareDatabaseMacros(TKWebSession.Current.AuthData);

  // Prevent Home from calling Logout on the next (redirect) request.
  TKWebSession.Current.ReloadingHome := True;

  // Native form submission (no X-KittoX): there is no HTMX swap to interpret
  // the hidden marker below, so the browser would render it as the whole page.
  // Redirect instead. 303, not 302: after a POST it makes the browser follow
  // with a GET, so the address bar ends on the app root, not on kx/login.
  if not IsSPARequest then
  begin
    TKWebResponse.Current.Items.Clear;
    TKWebResponse.Current.StatusCode := 303;
    TKWebResponse.Current.SetCustomHeader('Location', LApp.Path + '/');
    Exit;
  end;

  // Success: hidden marker with the redirect URL; the login form's JS detects
  // it after the HTMX swap and performs the redirect. (We don't use HX-Redirect
  // because WebBroker formats custom headers as Name=Value instead of Name: Value.)
  TKWebResponse.Current.Items.Clear;
  TKWebResponse.Current.Items.AddHTML(
    '<div id="kx-login-success" data-redirect="' + LApp.Path + '/" style="display:none"></div>');
end;

procedure TKXAuthHandlerBase.AfterAuthenticateFail;
begin
  TKWebResponse.Current.Items.Clear;
  // Native submission (see AfterAuthenticateOK): the error fragment would be
  // rendered as the whole page. Back to the root, which shows the login again.
  if not IsSPARequest then
  begin
    TKWebResponse.Current.StatusCode := 303;
    TKWebResponse.Current.SetCustomHeader('Location',
      TKWebApplication.Current.Path + '/');
    Exit;
  end;

  TKWebResponse.Current.Items.AddHTML(
    '<div class="kx-login-error">' +
      TNetEncoding.HTML.Encode(_('Invalid login.')) +
    '</div>');
end;

function TKXAuthHandlerBase.IsSPARequest: Boolean;
begin
  // Same marker the navigation guard keys on: every SPA call carries it, a
  // native form submission does not.
  Result := SameText(TKWebRequest.Current.GetHeaderField('X-KittoX'), 'true');
end;

procedure TKXAuthHandlerBase.HandleLogin;
var
  LApp: TKWebApplication;
  LAuthData: TEFNode;
  LLanguage, LDatabaseName: string;
begin
  LApp := TKWebApplication.Current;

  // Always regenerate the session ID at login: recovers transparently from a
  // stale session cookie (server restarted / timed out) and hardens against
  // session fixation (the ID changes after successful authentication).
  TKWebSession.Current.RegenerateId;

  // Reset any previously selected database environment. A stale kx_db cookie
  // from another app (or a removed Databases entry) would make DatabaseFor look
  // up a non-existent name and crash. Re-set below only if the user picks one.
  TKWebSession.Current.DatabaseName := '';
  TKWebResponse.Current.SetCookie('kx_db', '', Now - 1);

  LLanguage := TKWebRequest.Current.GetField('Language');
  LDatabaseName := TKWebRequest.Current.GetField('DatabaseName');

  if LLanguage <> '' then
  begin
    TKWebSession.Current.ReloadingHome := True;
    TKWebSession.Current.Language := LLanguage;
  end;

  // Apply the chosen database BEFORE authenticating, so the auth query (to
  // KITTO_USERS via TKConfig.Database) is routed to the picked database.
  if LDatabaseName <> '' then
    TKWebSession.Current.DatabaseName := LDatabaseName;

  LAuthData := TEFNode.Create;
  try
    LApp.Authenticator.DefineAuthData(LAuthData);
    BuildAuthData(LAuthData);
    if LApp.Authenticator.Authenticate(LAuthData) then
      AfterAuthenticateOK(LDatabaseName)
    else
      AfterAuthenticateFail;
  finally
    LAuthData.Free;
  end;
end;

procedure TKXAuthHandlerBase.ResetPasswordEmail(const AParams: TEFNode);
begin
  TKWebApplication.Current.Authenticator.ResetPassword(AParams);
end;

procedure TKXAuthHandlerBase.HandleResetPassword;
var
  LParams: TEFNode;
  LUserName, LEmailAddress: string;
begin
  LUserName := TKWebRequest.Current.GetField('UserName');
  LEmailAddress := TKWebRequest.Current.GetField('EmailAddress');

  LParams := TEFNode.Create;
  try
    LParams.SetString('UserName', LUserName);
    LParams.SetString('EmailAddress', LEmailAddress);
    try
      ResetPasswordEmail(LParams);
      // Info dialog; OK also closes the ResetPassword overlay behind it.
      TKWebResponse.Current.Items.Clear;
      TKWebResponse.Current.SetCustomHeader('HX-Retarget', 'body');
      TKWebResponse.Current.SetCustomHeader('HX-Reswap', 'beforeend');
      TKWebResponse.Current.Items.AddHTML(
        '<div class="kx-msgbox-overlay" onclick="this.remove()">' +
          '<div class="kx-msgbox-dialog" onclick="event.stopPropagation()">' +
            '<div class="kx-msgbox-header kx-msgbox-info">' +
              '<div class="kx-msgbox-icon kx-msgbox-icon-info"></div>' +
              '<span>' + _('Reset Password') + '</span>' +
            '</div>' +
            '<div class="kx-msgbox-body">' +
              TNetEncoding.HTML.Encode(
                _('A new temporary password was generated and sent to the specified e-mail address.')) +
            '</div>' +
            '<div class="kx-msgbox-footer">' +
              '<button onclick="' +
                'var dlg=document.querySelector(''.kx-dialog-overlay'');' +
                'if(dlg)dlg.remove();' +
                'this.closest(''.kx-msgbox-overlay'').remove();">OK</button>' +
            '</div>' +
          '</div>' +
        '</div>');
    except
      on E: Exception do
      begin
        // Error dialog (same pattern as the global error handler).
        TKWebResponse.Current.Items.Clear;
        TKWebResponse.Current.SetCustomHeader('HX-Retarget', 'body');
        TKWebResponse.Current.SetCustomHeader('HX-Reswap', 'beforeend');
        TKWebResponse.Current.Items.AddHTML(
          '<div class="kx-msgbox-overlay" onclick="this.remove()">' +
            '<div class="kx-msgbox-dialog" onclick="event.stopPropagation()">' +
              '<div class="kx-msgbox-header kx-msgbox-error">' +
                '<div class="kx-msgbox-icon kx-msgbox-icon-error"></div>' +
                '<span>' + _('Error') + '</span>' +
              '</div>' +
              '<div class="kx-msgbox-body">' +
                TNetEncoding.HTML.Encode(E.Message) +
              '</div>' +
              '<div class="kx-msgbox-footer">' +
                '<button onclick="this.closest(''.kx-msgbox-overlay'').remove();">OK</button>' +
              '</div>' +
            '</div>' +
          '</div>');
      end;
    end;
  finally
    LParams.Free;
  end;
end;

procedure TKXAuthHandlerBase.HandleChangePassword;
var
  LApp: TKWebApplication;
  LAuthenticator: TKAuthenticator;
  LOldPassword, LNewPassword, LConfirmNewPassword: string;
  LOldPasswordHash, LStoredHash: string;
  LErrorMsg: string;

  function GetPasswordHash(const AClearPassword: string): string;
  begin
    if LAuthenticator.IsClearPassword then
      Result := AClearPassword
    else
    begin
      Result := GetStringHash(AClearPassword);
      // With BCrypt the stored value is a salted hash that cannot be recomputed
      // from the clear password: the comparison is delegated to the
      // authenticator's own verifier, which expects the clear password. Mirrors
      // Kitto1 (Kitto.Ext.ChangePassword.pas:67-77).
      if LAuthenticator.IsBCrypted then
        Result := AClearPassword;
    end;
  end;

  procedure RespondError(const AMsg: string);
  begin
    TKWebResponse.Current.Items.Clear;
    TKWebResponse.Current.Items.AddHTML(
      '<div class="kx-login-error">' +
        TNetEncoding.HTML.Encode(AMsg) +
      '</div>');
  end;

begin
  LApp := TKWebApplication.Current;
  LAuthenticator := LApp.Authenticator;

  // Refuse before touching anything when the authenticator cannot write a
  // password at all (Auth: LDAP keeps them in the directory). SetPassword's base
  // implementation has an empty body, so without this check the whole flow below
  // would succeed and report "Password changed successfully" while nothing was
  // written anywhere.
  if not LAuthenticator.SupportsPasswordChange then
  begin
    RespondError(_('Changing the password is not supported for this login type. Please contact your administrator.'));
    Exit;
  end;

  LOldPassword := TKWebRequest.Current.GetField('OldPassword');
  LNewPassword := TKWebRequest.Current.GetField('NewPassword');
  LConfirmNewPassword := TKWebRequest.Current.GetField('ConfirmNewPassword');

  LStoredHash := LAuthenticator.Password;
  LOldPasswordHash := GetPasswordHash(LOldPassword);

  LErrorMsg := '';
  // The old password is neither asked for nor checked when the change is
  // imposed (first access, or after a reset): the user has never chosen one.
  // Mirrors Kitto1, where the field was not even rendered and the check was
  // short-circuited by FShowOldPassword.
  // Both comparisons go through IsPasswordMatching, which every authenticator
  // may implement its own way: against a bcrypt credential, which is salted, a
  // literal comparison of hashes could never succeed. Kitto1 did the same, one
  // comparison at a time (Kitto.Ext.ChangePassword.pas:81 and 86).
  // There is nothing to differ from when no password is stored: an account
  // created without one, or an authenticator that keeps none (OSDB on the
  // system user name reports every password as matching, so the check would
  // fire on any new password and make the change impossible).
  if not LAuthenticator.MustChangePassword
     and not LAuthenticator.IsPasswordMatching(LOldPasswordHash, LStoredHash) then
    LErrorMsg := _('Old Password is wrong.')
  else if (LStoredHash <> '')
     and LAuthenticator.IsPasswordMatching(GetPasswordHash(LNewPassword), LStoredHash) then
    LErrorMsg := _('New Password must be different than old password.')
  else if LNewPassword <> LConfirmNewPassword then
    LErrorMsg := _('Confirm New Password is wrong.');

  if LErrorMsg <> '' then
  begin
    RespondError(LErrorMsg);
    Exit;
  end;

  try
    LAuthenticator.Password := LConfirmNewPassword;
    // The session is dropped so the user has to log in again with the new
    // password. The authenticator's own Logout is used here on purpose:
    // TKWebApplication.Logout also calls Reload, which clears the response
    // items - and would therefore wipe the confirmation dialog built below,
    // leaving the user with a silent page reload back to the login screen.
    LAuthenticator.Logout;
    // Success: info dialog, then redirect to home (forces re-login).
    TKWebResponse.Current.Items.Clear;
    TKWebResponse.Current.SetCustomHeader('HX-Retarget', 'body');
    TKWebResponse.Current.SetCustomHeader('HX-Reswap', 'beforeend');
    TKWebResponse.Current.Items.AddHTML(
      '<div class="kx-msgbox-overlay">' +
        '<div class="kx-msgbox-dialog" onclick="event.stopPropagation()">' +
          '<div class="kx-msgbox-header kx-msgbox-info">' +
            '<div class="kx-msgbox-icon kx-msgbox-icon-info"></div>' +
            '<span>' + _('Change Password') + '</span>' +
          '</div>' +
          '<div class="kx-msgbox-body">' +
            TNetEncoding.HTML.Encode(
              _('Password changed successfully. You will be redirected to the login page.')) +
          '</div>' +
          '<div class="kx-msgbox-footer">' +
            '<button onclick="window.location.href=''' + LApp.Path + '/'';">OK</button>' +
          '</div>' +
        '</div>' +
      '</div>');
  except
    on E: Exception do
      RespondError(E.Message);
  end;
end;

procedure TKXAuthHandlerBase.HandleLogout;
begin
  TKWebApplication.Current.Logout;
end;

procedure TKXAuthHandlerBase.HandleReloadHome;
begin
  // Nothing to preserve for a visitor who is not signed in: leave the flag
  // alone so the reload behaves exactly as a plain page load would.
  if TKWebSession.Current.IsAuthenticated then
    TKWebSession.Current.ReloadingHome := True;
  // Empty 200: the client only reloads, it does not read the body.
  TKWebResponse.Current.Items.Clear;
  TKWebResponse.Current.ContentType := 'text/plain; charset=utf-8';
  TKWebResponse.Current.Items.AddHTML('');
end;

initialization
  TKXResourceRegistry.Instance.RegisterResource(TKXAuthHandlerBase);

finalization
  TKXResourceRegistry.Instance.UnregisterResource(TKXAuthHandlerBase);

end.
