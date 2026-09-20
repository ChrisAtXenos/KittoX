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
///  Typed config readers for the authentication domain (Config.yaml node
///  <c>Auth</c> and its sub-nodes <c>Defaults</c> and the optional <c>JWT</c>
///  envelope, itself carrying <c>Cookie</c> and <c>Claims</c>). Part of the
///  per-domain organization of the config metadata (replacing the monolithic
///  Kitto.Metadata.SubNodes). Each class reads its subtree once into typed
///  fields (see TKConfigReader) AND carries the [YamlNode]/[YamlSubNode]
///  attributes that KIDE reads via RTTI to drive the Config editor.
///
///  Note: the authenticators themselves read their own Auth node directly (they
///  are TEFComponent descendants), so this reader is used by KIDE for the schema
///  and by any runtime code that prefers the typed Config.Auth.* accessors.
/// </summary>
unit Kitto.Config.Auth;

{$I Kitto.Defines.inc}

interface

uses
  EF.Tree,
  EF.YAML.Attributes,
  Kitto.Config.Reader;

const
  /// <summary>
  ///  Default name of the cookie carrying the JWT, overridden by
  ///  Auth/JWT/Cookie/Name. It lives in this unit, which declares the schema of
  ///  that very node, because two unrelated places need the same default and
  ///  neither should have to depend on the other: the JWT engine, which writes
  ///  the cookie, and the web engine, which reads it back to recover the session
  ///  id. Declaring it in Kitto.Web.JWT would drag JOSE into the web engine for
  ///  a single string.
  /// </summary>
  DEFAULT_JWT_COOKIE_NAME = 'kx_token';

type
  /// <summary>
  ///  Default credentials for authentication.
  ///  YAML path: Auth/Defaults
  /// </summary>
  TKAuthDefaultsConfig = class(TKConfigReader)
  private
    FUserName: string;
    FPassword: string;
  protected
    procedure ReadConfig; override;
  public
    [YamlNode('UserName', 'Default user name')]
    property UserName: string read FUserName;

    [YamlNode('Password', 'Default password')]
    property Password: string read FPassword;
  end;

  /// <summary>
  ///  Cookie attributes for the JWT token cookie.
  ///  YAML path: Auth/JWT/Cookie
  /// </summary>
  TKAuthCookieConfig = class(TKConfigReader)
  private
    FName: string;
    FPath: string;
    FHttpOnly: Boolean;
    FSecure: Boolean;
    FSameSite: string;
  protected
    procedure ReadConfig; override;
  public
    [YamlNode('Name', DEFAULT_JWT_COOKIE_NAME, 'Cookie name carrying the JWT')]
    property Name: string read FName;

    [YamlNode('Path', 'Cookie path scope. Default: TKWebApplication.Path (the AppPath of this app)')]
    property Path: string read FPath;

    [YamlNode('HttpOnly', 'True', 'Whether the cookie is invisible to JavaScript (recommended)')]
    property HttpOnly: Boolean read FHttpOnly;

    [YamlNode('Secure', 'True', 'Whether the cookie is only sent over HTTPS (recommended)')]
    property Secure: Boolean read FSecure;

    [YamlNode('SameSite', 'Lax', 'SameSite attribute. Strict | Lax | None | empty (omit attribute)')]
    [YamlEnumValue('Strict', 'Cookie sent only for same-site requests')]
    [YamlEnumValue('Lax', 'Cookie sent on top-level navigations (default)')]
    [YamlEnumValue('None', 'Cookie sent cross-site (requires Secure)')]
    property SameSite: string read FSameSite;
  end;

  /// <summary>
  ///  Selection of optional claims embedded in the JWT.
  ///  YAML path: Auth/JWT/Claims
  /// </summary>
  TKAuthClaimsConfig = class(TKConfigReader)
  private
    FIncludeRoles: Boolean;
    FIncludeDB: Boolean;
    FIncludeDisplayName: Boolean;
    FIncludeLanguage: Boolean;
  protected
    procedure ReadConfig; override;
  public
    [YamlNode('IncludeRoles', 'False', 'Embed the user roles list as a custom claim')]
    property IncludeRoles: Boolean read FIncludeRoles;

    [YamlNode('IncludeDB', 'True', 'Embed the active environment / database name as the db claim')]
    property IncludeDB: Boolean read FIncludeDB;

    [YamlNode('IncludeDisplayName', 'True', 'Embed the user display name as the name claim')]
    property IncludeDisplayName: Boolean read FIncludeDisplayName;

    [YamlNode('IncludeLanguage', 'True', 'Embed the active language as the lang claim')]
    property IncludeLanguage: Boolean read FIncludeLanguage;

    // IncludeACL intentionally not exposed here: it is auto-derived in
    // TKJWTConfig.Parse from the configured AccessControl (JWT vs. anything
    // else). Keeping it out of the user-facing schema prevents the footgun
    // of "AccessControl: JWT but IncludeACL: False" misconfigurations.
  end;

  /// <summary>
  ///  Optional JWT envelope for an authenticator.
  ///  YAML path: Auth/JWT
  ///  The presence of this node turns on issuing/validating a signed
  ///  self-contained credential cookie (kx_token); the engine is provided by
  ///  the opt-in Kitto.Auth.JWT unit. Absence => plain server-side session
  ///  cookie. Works under any Auth: X (DB / TextFile / OSDB / custom).
  /// </summary>
  TKAuthJWTConfig = class(TKConfigReader)
  private
    FSigningAlgorithm: string;
    FSigningKey: string;
    FSigningPublicKey: string;
    FIssuer: string;
    FAudience: string;
    FTokenLifetime: Integer;
    FSlidingThreshold: Integer;
    FMaxSessionLifetime: Integer;
    FClockSkew: Integer;
    FCookie: TKAuthCookieConfig;
    FClaims: TKAuthClaimsConfig;
  protected
    procedure ReadConfig; override;
  public
    destructor Destroy; override;

    [YamlNode('SigningAlgorithm', 'HS256', 'JWT signing algorithm. HS256 / HS384 / HS512 (HMAC, no OpenSSL) or RS256 / RS384 / RS512 / ES256 / ES384 / ES512 (asymmetric, requires OpenSSL DLLs)')]
    [YamlEnumValue('HS256', 'HMAC-SHA256 (symmetric, no OpenSSL)')]
    [YamlEnumValue('HS384', 'HMAC-SHA384 (symmetric)')]
    [YamlEnumValue('HS512', 'HMAC-SHA512 (symmetric)')]
    [YamlEnumValue('RS256', 'RSA-SHA256 (asymmetric, needs OpenSSL)')]
    [YamlEnumValue('RS384', 'RSA-SHA384 (asymmetric)')]
    [YamlEnumValue('RS512', 'RSA-SHA512 (asymmetric)')]
    [YamlEnumValue('ES256', 'ECDSA-SHA256 (asymmetric)')]
    [YamlEnumValue('ES384', 'ECDSA-SHA384 (asymmetric)')]
    [YamlEnumValue('ES512', 'ECDSA-SHA512 (asymmetric)')]
    property SigningAlgorithm: string read FSigningAlgorithm;

    [YamlNode('SigningKey', 'JWT signing key. Accepts env:VAR_NAME (env var), file:/path (raw bytes from a file), or any other value as inline literal (DEV ONLY). A TKJWTSigningKeyRegistry provider registered from UseKitto.pas takes precedence.')]
    property SigningKey: string read FSigningKey;

    [YamlNode('SigningPublicKey', 'PEM public key for verifier-only deploys with asymmetric algorithms (RS*/ES*). Accepts the same env: / file: / inline prefixes as SigningKey.')]
    property SigningPublicKey: string read FSigningPublicKey;

    [YamlNode('Issuer', 'JWT iss claim. Defaults to the application name. Validated on every request.')]
    property Issuer: string read FIssuer;

    [YamlNode('Audience', 'kx-app', 'JWT aud claim. Validated on every request.')]
    property Audience: string read FAudience;

    [YamlNode('TokenLifetime', '3600', 'exp - iat in seconds. Default 1 hour.')]
    property TokenLifetime: Integer read FTokenLifetime;

    [YamlNode('SlidingThreshold', '600', 'When (exp - now) drops below this many seconds, the auth gate re-issues the cookie with a fresh exp on the current response. 0 = disable sliding.')]
    property SlidingThreshold: Integer read FSlidingThreshold;

    [YamlNode('MaxSessionLifetime', '43200', 'Absolute cap in seconds on the total session length, measured from login (the sst claim): past this, sliding stops renewing the token and a fresh login is required. Default 12 hours. 0 = no cap.')]
    property MaxSessionLifetime: Integer read FMaxSessionLifetime;

    [YamlNode('ClockSkew', '60', 'Allowance in seconds for clock skew between client and server during exp/nbf/iat validation.')]
    property ClockSkew: Integer read FClockSkew;

    [YamlSubNode('Cookie', TKAuthCookieConfig, 'JWT cookie attributes (HttpOnly / Secure / SameSite / Path / Name)')]
    property Cookie: TKAuthCookieConfig read FCookie;

    [YamlSubNode('Claims', TKAuthClaimsConfig, 'Optional profile claims embedded in the JWT (roles, db, language, ACL, ...)')]
    property Claims: TKAuthClaimsConfig read FClaims;
  end;

  /// <summary>
  ///  Optional password-strength policy enforced when a user sets a password.
  ///  YAML path: Auth/ValidatePassword
  /// </summary>
  TKAuthValidatePasswordConfig = class(TKConfigReader)
  private
    FRegEx: string;
    FMessage: string;
  protected
    procedure ReadConfig; override;
  public
    [YamlNode('RegEx', '^[ -~]{8,63}$', 'Regular expression a new password must match')]
    property RegEx: string read FRegEx;

    [YamlNode('Message', 'Minimun 8 characters', 'Message shown when the password does not match RegEx')]
    property Message: string read FMessage;
  end;

  /// <summary>
  ///  A templated e-mail message (From/Subject/Body/HTMLBody) used by the
  ///  authentication flows. YAML paths: Auth/ResetMailMessage and
  ///  Auth/NewUserMailMessage. Bodies may contain #Placeholders# (e.g.
  ///  #UserName#, #TempPassword#) and %Config:...% macros.
  /// </summary>
  TKAuthMailMessageConfig = class(TKConfigReader)
  private
    FFrom: string;
    FSubject: string;
    FBody: string;
    FHTMLBody: string;
  protected
    procedure ReadConfig; override;
  public
    [YamlNode('From', 'Sender address for the message')]
    property From: string read FFrom;

    [YamlNode('Subject', 'Message subject (may contain %Config:...% macros)', True)]
    property Subject: string read FSubject;

    [YamlNode('Body', 'Plain-text body (#Placeholders# + %macros%)', True)]
    property Body: string read FBody;

    [YamlNode('HTMLBody', 'HTML body (#Placeholders# + %macros%)', True)]
    property HTMLBody: string read FHTMLBody;
  end;

  /// <summary>
  ///  LDAP attribute-name mapping for the LDAP authenticator (Kitto.Auth.LDAP):
  ///  maps each logical user attribute to the LDAP attribute read after the bind.
  ///  YAML path: Auth/Attributes
  /// </summary>
  TKAuthLDAPAttributesConfig = class(TKConfigReader)
  private
    FSamAccountName: string;
    FEmail: string;
    FFirstName: string;
    FLastName: string;
    FFullName: string;
    FGroups: string;
  protected
    procedure ReadConfig; override;
  public
    [YamlNode('SamAccountName', 'sAMAccountName', 'LDAP attribute holding the login/account name')]
    property SamAccountName: string read FSamAccountName;

    [YamlNode('Email', 'mail', 'LDAP attribute mapped to the user e-mail')]
    property Email: string read FEmail;

    [YamlNode('FirstName', 'givenName', 'LDAP attribute mapped to the first name')]
    property FirstName: string read FFirstName;

    [YamlNode('LastName', 'sn', 'LDAP attribute mapped to the last name')]
    property LastName: string read FLastName;

    [YamlNode('FullName', 'displayName', 'LDAP attribute mapped to the full/display name')]
    property FullName: string read FFullName;

    [YamlNode('Groups', 'memberOf', 'LDAP attribute mapped to the user groups')]
    property Groups: string read FGroups;
  end;

  /// <summary>
  ///  Authentication settings from Config.yaml.
  ///  YAML path: Auth
  /// </summary>
  TKAuthConfig = class(TKConfigReader)
  private
    FIsClearPassword: Boolean;
    FIsPassepartoutEnabled: Boolean;
    FPassepartoutPassword: string;
    FReadUserCommandText: string;
    FSetPasswordCommandText: string;
    FAfterAuthenticateCommandText: string;
    FResetPasswordCommandText: string;
    FRegisterNewUserCommandText: string;
    FLoginType: string;
    FFileName: string;
    FDatabaseChoices: string;
    FHost: string;
    FPort: Integer;
    FUseSSL: Boolean;
    FBindDNTemplate: string;
    FDefaultDomain: string;
    FSearchBase: string;
    FSearchFilter: string;
    FDefaults: TKAuthDefaultsConfig;
    FJWT: TKAuthJWTConfig;
    FValidatePassword: TKAuthValidatePasswordConfig;
    FResetMailMessage: TKAuthMailMessageConfig;
    FNewUserMailMessage: TKAuthMailMessageConfig;
    FLDAPAttributes: TKAuthLDAPAttributesConfig;
  protected
    procedure ReadConfig; override;
  public
    destructor Destroy; override;

    [YamlNode('IsClearPassword', 'Whether passwords are stored in clear text')]
    property IsClearPassword: Boolean read FIsClearPassword;

    [YamlNode('IsPassepartoutEnabled', 'Enable passepartout (master) password')]
    property IsPassepartoutEnabled: Boolean read FIsPassepartoutEnabled;

    [YamlNode('PassepartoutPassword', 'Master password value')]
    property PassepartoutPassword: string read FPassepartoutPassword;

    [YamlNode('ReadUserCommandText', 'SQL command to read user record')]
    property ReadUserCommandText: string read FReadUserCommandText;

    [YamlNode('SetPasswordCommandText', 'SQL command to set user password')]
    property SetPasswordCommandText: string read FSetPasswordCommandText;

    [YamlNode('AfterAuthenticateCommandText', 'SQL command executed after authentication')]
    property AfterAuthenticateCommandText: string read FAfterAuthenticateCommandText;

    [YamlNode('ResetPasswordCommandText', 'SQL command to reset a user password')]
    property ResetPasswordCommandText: string read FResetPasswordCommandText;

    [YamlNode('RegisterNewUserCommandText', 'SQL command to register a new user')]
    property RegisterNewUserCommandText: string read FRegisterNewUserCommandText;

    [YamlNode('LoginType', 'Login form variant / behaviour selector')]
    property LoginType: string read FLoginType;

    [YamlNode('FileName', 'Text file path for text-file authentication')]
    property FileName: string read FFileName;

    [YamlNode('DatabaseChoices', 'Comma-separated list of Databases/<Name> entries the user can pick at login. Empty = no environment combo on the login page. Embedded in the db claim when a JWT envelope is configured.')]
    property DatabaseChoices: string read FDatabaseChoices;

    [YamlSubNode('Defaults', TKAuthDefaultsConfig, 'Default credentials')]
    property Defaults: TKAuthDefaultsConfig read FDefaults;

    [YamlSubNode('JWT', TKAuthJWTConfig, 'Optional JWT envelope. Present = issue/validate a signed self-contained token cookie (kx_token) instead of a plain session cookie. Requires the Kitto.Auth.JWT unit in UseKitto.pas.')]
    property JWT: TKAuthJWTConfig read FJWT;

    [YamlSubNode('ValidatePassword', TKAuthValidatePasswordConfig, 'Optional password-strength policy (RegEx + Message) enforced when a user sets a password')]
    property ValidatePassword: TKAuthValidatePasswordConfig read FValidatePassword;

    [YamlSubNode('ResetMailMessage', TKAuthMailMessageConfig, 'E-mail sent when a user resets their password (carries the temporary password)')]
    property ResetMailMessage: TKAuthMailMessageConfig read FResetMailMessage;

    [YamlSubNode('NewUserMailMessage', TKAuthMailMessageConfig, 'E-mail sent when a new user registers (carries the temporary password)')]
    property NewUserMailMessage: TKAuthMailMessageConfig read FNewUserMailMessage;

    // --- LDAP authenticator (Auth: LDAP, unit Kitto.Auth.LDAP) ---
    [YamlNode('Host', 'LDAP server host name (LDAP authenticator)')]
    property Host: string read FHost;

    [YamlNode('Port', '389', 'LDAP server port (389 plain, 636 with SSL)')]
    property Port: Integer read FPort;

    [YamlNode('UseSSL', 'False', 'Connect to the LDAP server over SSL/LDAPS')]
    property UseSSL: Boolean read FUseSSL;

    [YamlNode('BindDNTemplate', 'Template building the full bind DN from the short user name (e.g. uid=%s,dc=example,dc=com)')]
    property BindDNTemplate: string read FBindDNTemplate;

    [YamlNode('DefaultDomain', 'Default Active Directory domain prefixed to the user name when none is given')]
    property DefaultDomain: string read FDefaultDomain;

    [YamlNode('SearchBase', 'Base DN under which the user entry is searched after the bind')]
    property SearchBase: string read FSearchBase;

    [YamlNode('SearchFilter', '(sAMAccountName=%s)', 'LDAP search filter locating the user entry (%s = user name)')]
    property SearchFilter: string read FSearchFilter;

    [YamlSubNode('Attributes', TKAuthLDAPAttributesConfig, 'Mapping of user attributes to LDAP attribute names')]
    property LDAPAttributes: TKAuthLDAPAttributesConfig read FLDAPAttributes;
  end;

implementation

{ TKAuthDefaultsConfig }

procedure TKAuthDefaultsConfig.ReadConfig;
begin
  FUserName := GetString('UserName');
  FPassword := GetString('Password');
end;

{ TKAuthCookieConfig }

procedure TKAuthCookieConfig.ReadConfig;
begin
  FName := GetString('Name', 'kx_token');
  FPath := GetString('Path');
  FHttpOnly := GetBoolean('HttpOnly', True);
  FSecure := GetBoolean('Secure', True);
  FSameSite := GetString('SameSite', 'Lax');
end;

{ TKAuthClaimsConfig }

procedure TKAuthClaimsConfig.ReadConfig;
begin
  FIncludeRoles := GetBoolean('IncludeRoles', False);
  FIncludeDB := GetBoolean('IncludeDB', True);
  FIncludeDisplayName := GetBoolean('IncludeDisplayName', True);
  FIncludeLanguage := GetBoolean('IncludeLanguage', True);
end;

{ TKAuthJWTConfig }

procedure TKAuthJWTConfig.ReadConfig;
begin
  FSigningAlgorithm := GetString('SigningAlgorithm', 'HS256');
  FSigningKey := GetString('SigningKey');
  FSigningPublicKey := GetString('SigningPublicKey');
  FIssuer := GetString('Issuer');
  FAudience := GetString('Audience', 'kx-app');
  FTokenLifetime := GetInteger('TokenLifetime', 3600);
  FSlidingThreshold := GetInteger('SlidingThreshold', 600);
  FMaxSessionLifetime := GetInteger('MaxSessionLifetime', 43200);
  FClockSkew := GetInteger('ClockSkew', 60);
  // Nested readers: bound to the Cookie/Claims subtrees (nil-safe when absent).
  if FCookie = nil then
    FCookie := TKAuthCookieConfig.Create(SubNode('Cookie'))
  else
    FCookie.Refresh(SubNode('Cookie'));
  if FClaims = nil then
    FClaims := TKAuthClaimsConfig.Create(SubNode('Claims'))
  else
    FClaims.Refresh(SubNode('Claims'));
end;

destructor TKAuthJWTConfig.Destroy;
begin
  FCookie.Free;
  FClaims.Free;
  inherited;
end;

{ TKAuthValidatePasswordConfig }

procedure TKAuthValidatePasswordConfig.ReadConfig;
begin
  FRegEx := GetString('RegEx', '^[ -~]{8,63}$');
  FMessage := GetString('Message', 'Minimun 8 characters');
end;

{ TKAuthMailMessageConfig }

procedure TKAuthMailMessageConfig.ReadConfig;
begin
  FFrom := GetString('From');
  FSubject := GetString('Subject');
  FBody := GetString('Body');
  FHTMLBody := GetString('HTMLBody');
end;

{ TKAuthLDAPAttributesConfig }

procedure TKAuthLDAPAttributesConfig.ReadConfig;
begin
  FSamAccountName := GetString('SamAccountName', 'sAMAccountName');
  FEmail := GetString('Email', 'mail');
  FFirstName := GetString('FirstName', 'givenName');
  FLastName := GetString('LastName', 'sn');
  FFullName := GetString('FullName', 'displayName');
  FGroups := GetString('Groups', 'memberOf');
end;

{ TKAuthConfig }

procedure TKAuthConfig.ReadConfig;
begin
  FIsClearPassword := GetBoolean('IsClearPassword');
  FIsPassepartoutEnabled := GetBoolean('IsPassepartoutEnabled');
  FPassepartoutPassword := GetString('PassepartoutPassword');
  FReadUserCommandText := GetString('ReadUserCommandText');
  FSetPasswordCommandText := GetString('SetPasswordCommandText');
  FAfterAuthenticateCommandText := GetString('AfterAuthenticateCommandText');
  FResetPasswordCommandText := GetString('ResetPasswordCommandText');
  FRegisterNewUserCommandText := GetString('RegisterNewUserCommandText');
  FLoginType := GetString('LoginType');
  FFileName := GetString('FileName');
  FDatabaseChoices := GetString('DatabaseChoices');
  // LDAP authenticator settings (present when Auth: LDAP).
  FHost := GetString('Host');
  FPort := GetInteger('Port', 389);
  FUseSSL := GetBoolean('UseSSL', False);
  FBindDNTemplate := GetString('BindDNTemplate');
  FDefaultDomain := GetString('DefaultDomain');
  FSearchBase := GetString('SearchBase');
  FSearchFilter := GetString('SearchFilter', '(sAMAccountName=%s)');
  // Nested readers: bound to the Defaults/JWT/ValidatePassword subtrees
  // (nil-safe when absent).
  if FDefaults = nil then
    FDefaults := TKAuthDefaultsConfig.Create(SubNode('Defaults'))
  else
    FDefaults.Refresh(SubNode('Defaults'));
  if FJWT = nil then
    FJWT := TKAuthJWTConfig.Create(SubNode('JWT'))
  else
    FJWT.Refresh(SubNode('JWT'));
  if FValidatePassword = nil then
    FValidatePassword := TKAuthValidatePasswordConfig.Create(SubNode('ValidatePassword'))
  else
    FValidatePassword.Refresh(SubNode('ValidatePassword'));
  if FResetMailMessage = nil then
    FResetMailMessage := TKAuthMailMessageConfig.Create(SubNode('ResetMailMessage'))
  else
    FResetMailMessage.Refresh(SubNode('ResetMailMessage'));
  if FNewUserMailMessage = nil then
    FNewUserMailMessage := TKAuthMailMessageConfig.Create(SubNode('NewUserMailMessage'))
  else
    FNewUserMailMessage.Refresh(SubNode('NewUserMailMessage'));
  if FLDAPAttributes = nil then
    FLDAPAttributes := TKAuthLDAPAttributesConfig.Create(SubNode('Attributes'))
  else
    FLDAPAttributes.Refresh(SubNode('Attributes'));
end;

destructor TKAuthConfig.Destroy;
begin
  FDefaults.Free;
  FJWT.Free;
  FValidatePassword.Free;
  FResetMailMessage.Free;
  FNewUserMailMessage.Free;
  FLDAPAttributes.Free;
  inherited;
end;

end.
