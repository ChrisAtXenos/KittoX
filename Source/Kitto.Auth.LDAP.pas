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
///  Defines the LDAP authenticator: it validates the supplied credentials by
///  performing a simple bind against an LDAP directory (typically Active
///  Directory), using the native Windows LDAP API (wldap32.dll). No local user
///  table is needed: the directory itself confirms that the user exists and
///  that the password is correct.
///  After a successful bind, if a SearchBase is configured, the authenticator
///  reads the user's display attributes (first name, last name, e-mail, and
///  optionally the group membership) and stores them into the authentication
///  data, so they are available through the %Auth:...% macros and to the
///  access controller.
/// </summary>
unit Kitto.Auth.LDAP;

{$I Kitto.Defines.inc}

interface

uses
  EF.Tree,
  Kitto.Auth;

type
  /// <summary>
  ///  <para>The LDAP authenticator requires the same auth items as its ancestor
  ///  <see cref="TKClassicAuthenticator" /> (UserName + Password). It does NOT
  ///  use a database table: the user is authenticated by a simple bind against
  ///  an LDAP server (typically an Active Directory domain controller).</para>
  ///  <para>Users normally log in with the <c>DOMAIN\UserName</c> form. If a
  ///  bare user name is supplied (no domain), the <c>DefaultDomain</c> parameter
  ///  is prepended, so users can type just their user name. A UPN form
  ///  (<c>user@domain</c>) is also accepted as-is.</para>
  ///  <para>Configuration parameters (children of the <c>Auth</c> node in
  ///  <c>Config.yaml</c>):</para>
  ///  <list type="table">
  ///    <listheader><term>Term</term><description>Description</description></listheader>
  ///    <item><term>Host</term><description>Host name or IP of the LDAP server
  ///      (domain controller). Required.</description></item>
  ///    <item><term>Port</term><description>TCP port. Default 389 (plain) or 636
  ///      when UseSSL is True.</description></item>
  ///    <item><term>UseSSL</term><description>True to open an LDAPS (SSL)
  ///      connection. Strongly recommended, because a plain simple bind sends
  ///      the password in clear over the wire. Default False.</description></item>
  ///    <item><term>DefaultDomain</term><description>NetBIOS domain prepended to
  ///      a bare user name (so <c>jsmith</c> becomes <c>DOMAIN\jsmith</c> at bind
  ///      time). Optional but recommended. Ignored when BindDNTemplate is set.</description></item>
  ///    <item><term>BindDNTemplate</term><description>For a generic (non-AD) LDAP
  ///      directory that binds by distinguished name: a template with a single
  ///      <c>%s</c> placeholder for the (short) user name, e.g.
  ///      <c>uid=%s,dc=example,dc=com</c>. When set, the user types only the short
  ///      name (e.g. <c>tesla</c>) and it takes precedence over the AD
  ///      DOMAIN\user / DefaultDomain handling.</description></item>
  ///    <item><term>SearchBase</term><description>Base DN used to look up the
  ///      user's attributes after the bind, e.g. <c>DC=corp,DC=local</c>. If
  ///      omitted, the bind still authenticates the user but no attribute is
  ///      read.</description></item>
  ///    <item><term>SearchFilter</term><description>LDAP filter with a single
  ///      <c>%s</c> placeholder for the sAMAccountName. Default
  ///      <c>(sAMAccountName=%s)</c>.</description></item>
  ///    <item><term>Attributes/Email</term><description>LDAP attribute mapped to
  ///      EMAIL_ADDRESS. Default <c>mail</c>.</description></item>
  ///    <item><term>Attributes/FirstName</term><description>Default
  ///      <c>givenName</c> (stored as FIRST_NAME).</description></item>
  ///    <item><term>Attributes/LastName</term><description>Default <c>sn</c>
  ///      (stored as LAST_NAME).</description></item>
  ///    <item><term>Attributes/FullName</term><description>Default
  ///      <c>displayName</c> (stored as FULL_NAME).</description></item>
  ///    <item><term>Attributes/Groups</term><description>Default <c>memberOf</c>
  ///      (stored as MEMBER_OF, a ';'-separated list). Set to empty to skip.</description></item>
  ///  </list>
  /// </summary>
  TKLDAPAuthenticator = class(TKClassicAuthenticator)
  strict private
    /// <summary>Builds the bind name from what the user typed: keeps
    /// DOMAIN\user and user@upn as-is; prepends DefaultDomain to a bare user
    /// name when configured.</summary>
    function BuildBindName(const AUserName: string): string;
    /// <summary>Extracts the sAMAccountName (the part after the backslash, or
    /// before the @) used as the search key and as the canonical UserName.</summary>
    function ExtractSamAccountName(const AUserName: string): string;
    /// <summary>Performs the simple bind and, on success, reads the directory
    /// attributes into AAuthData. Returns True only when the bind succeeds.
    /// ACanonicalSam receives the sAMAccountName as the directory spells it
    /// (when a SearchBase is configured and the entry is found), so the caller
    /// can use a stable identity instead of the one the user happened to type;
    /// empty when there was no search or no such attribute.</summary>
    function BindAndFetchAttributes(const ABindName, ASamAccountName,
      APassword: string; const AAuthData: TEFNode; out ACanonicalSam: string): Boolean;
  strict protected
    /// <summary>The password is sent in clear to the LDAP bind, so no hashing
    /// takes place on our side. Returns True.</summary>
    function GetIsClearPassword: Boolean; override;
    /// <summary>Validates UserName/Password against the directory with a simple
    /// bind and, on success, loads the user's attributes.</summary>
    function InternalAuthenticate(const AAuthData: TEFNode): Boolean; override;
  public
    /// <summary>Not used: the credential check is the LDAP bind itself, so hash
    /// matching never happens. Always returns False.</summary>
    function IsPasswordMatching(const ASuppliedPasswordHash: string;
      const AStoredPasswordHash: string): Boolean; override;
    /// <summary>False: passwords live in the directory and must be changed
    /// there. Without this the base SetPassword — whose body is empty — would
    /// run and the change-password dialog would report success while writing
    /// nothing. Consistent with ResetPassword, which refuses explicitly.</summary>
    function SupportsPasswordChange: Boolean; override;
    /// <summary>Not supported: passwords are managed in the directory.</summary>
    procedure ResetPassword(const AParams: TEFNode); override;
    /// <summary>Not supported: PIN/QR authentication is not available for LDAP.</summary>
    procedure QRGenerate(const AParams: TEFNode); override;
  end;

implementation

uses
  System.SysUtils,
  EF.Localization,
  Kitto.Types;

const
  LDAP_PORT     = 389;
  LDAP_SSL_PORT = 636;

  LDAP_VERSION3 = 3;

  LDAP_OPT_REFERRALS        = $0008;
  LDAP_OPT_PROTOCOL_VERSION = $0011;

  LDAP_OPT_OFF: Pointer = nil;

  LDAP_SCOPE_SUBTREE = 2;

  LDAP_SUCCESS             = 0;
  LDAP_INVALID_CREDENTIALS = 49;

type
  PLDAP = Pointer;
  PLDAPMessage = Pointer;
  // Pointer to the first element of a NULL-terminated array of PWideChar,
  // as returned by ldap_get_valuesW.
  PLDAPValues = ^PWideChar;

{ Native Windows LDAP API (wldap32.dll). The Windows LDAP API uses the __cdecl
  calling convention (LDAPAPI). We use the Unicode (W) entry points. }

function ldap_initW(HostName: PWideChar; PortNumber: Cardinal): PLDAP;
  cdecl; external 'wldap32.dll';

function ldap_sslinitW(HostName: PWideChar; PortNumber: Cardinal; secure: Integer): PLDAP;
  cdecl; external 'wldap32.dll';

function ldap_set_option(ld: PLDAP; option: Integer; const invalue: Pointer): Cardinal;
  cdecl; external 'wldap32.dll';

function ldap_simple_bind_sW(ld: PLDAP; dn: PWideChar; passwd: PWideChar): Cardinal;
  cdecl; external 'wldap32.dll';

function ldap_search_sW(ld: PLDAP; base: PWideChar; scope: Cardinal;
  filter: PWideChar; attrs: Pointer; attrsonly: Cardinal;
  var res: PLDAPMessage): Cardinal; cdecl; external 'wldap32.dll';

function ldap_first_entry(ld: PLDAP; res: PLDAPMessage): PLDAPMessage;
  cdecl; external 'wldap32.dll';

function ldap_get_valuesW(ld: PLDAP; entry: PLDAPMessage; attr: PWideChar): PLDAPValues;
  cdecl; external 'wldap32.dll';

function ldap_value_freeW(vals: PLDAPValues): Cardinal;
  cdecl; external 'wldap32.dll';

function ldap_msgfree(res: PLDAPMessage): Cardinal;
  cdecl; external 'wldap32.dll';

function ldap_unbind_s(ld: PLDAP): Cardinal;
  cdecl; external 'wldap32.dll';

{ Escapes the special characters of an LDAP search filter value (RFC 4515). The
  value comes from a user who has already authenticated, so this is defence in
  depth rather than a primary control. }
function EscapeLDAPFilterValue(const AValue: string): string;
var
  LChar: Char;
begin
  Result := '';
  for LChar in AValue do
    case LChar of
      '*': Result := Result + '\2a';
      '(': Result := Result + '\28';
      ')': Result := Result + '\29';
      '\': Result := Result + '\5c';
      #0:  Result := Result + '\00';
    else
      Result := Result + LChar;
    end;
end;

{ Escapes the special characters of a distinguished name attribute value
  (RFC 4514), used when a short user name is substituted into a BindDNTemplate. }
function EscapeLDAPDNValue(const AValue: string): string;
var
  LIndex: Integer;
  LChar: Char;
begin
  Result := '';
  for LIndex := 1 to Length(AValue) do
  begin
    LChar := AValue[LIndex];
    if CharInSet(LChar, [',', '+', '"', '\', '<', '>', ';', '=']) or
       ((LIndex = 1) and CharInSet(LChar, ['#', ' '])) or
       ((LIndex = Length(AValue)) and (LChar = ' ')) then
      Result := Result + '\' + LChar
    else if LChar = #0 then
      Result := Result + '\00'
    else
      Result := Result + LChar;
  end;
end;

{ TKLDAPAuthenticator }

function TKLDAPAuthenticator.GetIsClearPassword: Boolean;
begin
  Result := True;
end;

function TKLDAPAuthenticator.BuildBindName(const AUserName: string): string;
var
  LBindDNTemplate: string;
  LDefaultDomain: string;
begin
  // Generic (non-AD) LDAP: when a bind DN template is configured, build the full
  // distinguished name from the short user name, e.g. 'uid=%s,dc=example,dc=com'.
  // This lets users log in with just 'tesla' against a plain LDAP directory.
  LBindDNTemplate := Config.GetString('BindDNTemplate');
  if LBindDNTemplate <> '' then
    Exit(StringReplace(LBindDNTemplate, '%s', EscapeLDAPDNValue(AUserName), [rfReplaceAll]));

  // Already qualified (DOMAIN\user) or in UPN form (user@domain): use as-is.
  if (Pos('\', AUserName) > 0) or (Pos('@', AUserName) > 0) then
    Result := AUserName
  else
  begin
    LDefaultDomain := Config.GetString('DefaultDomain');
    if LDefaultDomain <> '' then
      Result := LDefaultDomain + '\' + AUserName
    else
      // No domain available: bind with the bare name (most AD servers will
      // reject it, which correctly results in a failed authentication).
      Result := AUserName;
  end;
end;

function TKLDAPAuthenticator.ExtractSamAccountName(const AUserName: string): string;
var
  LPos: Integer;
begin
  LPos := Pos('\', AUserName);
  if LPos > 0 then
    Result := Copy(AUserName, LPos + 1, MaxInt)
  else
  begin
    LPos := Pos('@', AUserName);
    if LPos > 0 then
      Result := Copy(AUserName, 1, LPos - 1)
    else
      Result := AUserName;
  end;
end;

function TKLDAPAuthenticator.BindAndFetchAttributes(const ABindName,
  ASamAccountName, APassword: string; const AAuthData: TEFNode;
  out ACanonicalSam: string): Boolean;
var
  LLdap: PLDAP;
  LHost: string;
  LPort: Integer;
  LUseSSL: Boolean;
  LVersion: Cardinal;
  LResult: Cardinal;
  LSearchBase: string;
  LFilter: string;
  LSearchResult: PLDAPMessage;
  LEntry: PLDAPMessage;

  function GetAttrValues(const AAttr: string): string;
  var
    LValues: PLDAPValues;
    LCursor: PLDAPValues;
  begin
    Result := '';
    if AAttr = '' then
      Exit;
    LValues := ldap_get_valuesW(LLdap, LEntry, PWideChar(AAttr));
    if LValues = nil then
      Exit;
    try
      LCursor := LValues;
      while LCursor^ <> nil do
      begin
        if Result <> '' then
          Result := Result + ';';
        Result := Result + string(LCursor^);
        Inc(LCursor);
      end;
    finally
      ldap_value_freeW(LValues);
    end;
  end;

begin
  ACanonicalSam := '';
  LHost := Config.GetString('Host');
  if LHost = '' then
    raise EKError.Create(_('LDAP authenticator: the "Host" parameter is required.'));

  LUseSSL := Config.GetBoolean('UseSSL', False);
  if LUseSSL then
    LPort := Config.GetInteger('Port', LDAP_SSL_PORT)
  else
    LPort := Config.GetInteger('Port', LDAP_PORT);

  if LUseSSL then
    // NB (review L6c, da valutare): apre LDAPS ma NON valida il certificato del
    // server, quindi il canale cifrato non protegge da un MITM che presenti un
    // certificato qualsiasi. Verificare il cert richiederebbe un callback
    // LDAP_OPT_SERVER_CERTIFICATE con un opt-out per i certificati self-signed
    // (comuni negli AD interni): lasciato invariato per scelta, tenuto tracciato.
    LLdap := ldap_sslinitW(PWideChar(LHost), LPort, 1)
  else
    LLdap := ldap_initW(PWideChar(LHost), LPort);
  if LLdap = nil then
    raise EKError.CreateFmt(_('LDAP authenticator: cannot initialize a connection to "%s".'), [LHost]);
  try
    LVersion := LDAP_VERSION3;
    ldap_set_option(LLdap, LDAP_OPT_PROTOCOL_VERSION, @LVersion);
    // Do not chase referrals: on Active Directory this avoids spurious bind
    // failures and extra round-trips.
    ldap_set_option(LLdap, LDAP_OPT_REFERRALS, LDAP_OPT_OFF);

    // The credential check IS the simple bind. An empty password has already
    // been rejected by the caller (an anonymous/unauthenticated simple bind can
    // otherwise succeed on some servers without validating the password).
    LResult := ldap_simple_bind_sW(LLdap, PWideChar(ABindName), PWideChar(APassword));
    if LResult = LDAP_INVALID_CREDENTIALS then
      Exit(False);
    if LResult <> LDAP_SUCCESS then
      // Server unreachable, misconfigured base/domain, etc.: surface it instead
      // of silently reporting "wrong password".
      raise EKError.CreateFmt(_('LDAP authenticator: bind failed (error %d).'), [LResult]);

    Result := True;

    // Record the directory that authenticated the user, so it is available as
    // the %Auth:LDAP_HOST% macro (e.g. shown on the Home page) instead of being
    // hard-coded. Set on every successful bind, independent of the attribute read.
    AAuthData.SetString('LDAP_HOST', LHost);

    // Optionally read the user's display attributes.
    LSearchBase := Config.GetString('SearchBase');
    if LSearchBase <> '' then
    begin
      LFilter := Format(Config.GetString('SearchFilter', '(sAMAccountName=%s)'),
        [EscapeLDAPFilterValue(ASamAccountName)]);
      LSearchResult := nil;
      LResult := ldap_search_sW(LLdap, PWideChar(LSearchBase), LDAP_SCOPE_SUBTREE,
        PWideChar(LFilter), nil, 0, LSearchResult);
      if (LResult = LDAP_SUCCESS) and (LSearchResult <> nil) then
      try
        LEntry := ldap_first_entry(LLdap, LSearchResult);
        if LEntry <> nil then
        begin
          // The sAMAccountName as the directory stores it: used by the caller as
          // the canonical identity, so ALICE / alice / Alice all resolve to the
          // one spelling the ACL rows are keyed on.
          ACanonicalSam := GetAttrValues(
            Config.GetString('Attributes/SamAccountName', 'sAMAccountName'));
          AAuthData.SetString('EMAIL_ADDRESS',
            GetAttrValues(Config.GetString('Attributes/Email', 'mail')));
          AAuthData.SetString('FIRST_NAME',
            GetAttrValues(Config.GetString('Attributes/FirstName', 'givenName')));
          AAuthData.SetString('LAST_NAME',
            GetAttrValues(Config.GetString('Attributes/LastName', 'sn')));
          AAuthData.SetString('FULL_NAME',
            GetAttrValues(Config.GetString('Attributes/FullName', 'displayName')));
          AAuthData.SetString('MEMBER_OF',
            GetAttrValues(Config.GetString('Attributes/Groups', 'memberOf')));
        end;
      finally
        ldap_msgfree(LSearchResult);
      end;
    end;
  finally
    ldap_unbind_s(LLdap);
  end;
end;

function TKLDAPAuthenticator.InternalAuthenticate(const AAuthData: TEFNode): Boolean;
var
  LUserName: string;
  LPassword: string;
  LBindName: string;
  LSamAccountName: string;
  LCanonicalSam: string;
begin
  LUserName := AAuthData.GetString('UserName');
  LPassword := AAuthData.GetString('Password');

  // Reject empty credentials up front: an empty password would otherwise turn
  // the simple bind into an unauthenticated bind on some directory servers.
  if (LUserName = '') or (LPassword = '') then
    Exit(False);

  LBindName := BuildBindName(LUserName);
  LSamAccountName := ExtractSamAccountName(LUserName);

  Result := BindAndFetchAttributes(LBindName, LSamAccountName, LPassword,
    AAuthData, LCanonicalSam);

  if Result then
  begin
    // Store the canonical login (without the domain) as the user identifier
    // used by the access controller and the %Auth:UserName% macro. Prefer the
    // spelling the directory returned; when there was no search (no SearchBase)
    // fall back to the typed value folded to lower case, so ALICE and alice do
    // not become two different identities that miss their ACL rows.
    if LCanonicalSam = '' then
      LCanonicalSam := LowerCase(LSamAccountName);
    AAuthData.SetString('UserName', LCanonicalSam);
  end;
end;

function TKLDAPAuthenticator.IsPasswordMatching(const ASuppliedPasswordHash,
  AStoredPasswordHash: string): Boolean;
begin
  // Never reached: authentication is performed by the LDAP bind, not by
  // comparing stored hashes.
  Result := False;
end;

function TKLDAPAuthenticator.SupportsPasswordChange: Boolean;
begin
  Result := False;
end;

procedure TKLDAPAuthenticator.ResetPassword(const AParams: TEFNode);
begin
  raise EKError.Create(_('Password reset is not supported by the LDAP authenticator. Manage passwords in the directory (Active Directory).'));
end;

procedure TKLDAPAuthenticator.QRGenerate(const AParams: TEFNode);
begin
  raise EKError.Create(_('PIN/QR authentication is not supported by the LDAP authenticator.'));
end;

initialization
  TKAuthenticatorRegistry.Instance.RegisterClass('LDAP', TKLDAPAuthenticator);

finalization
  TKAuthenticatorRegistry.Instance.UnregisterClass('LDAP');

end.
