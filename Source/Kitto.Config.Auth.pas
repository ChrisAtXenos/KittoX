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
    [YamlNode('Name', 'kx_token', 'Cookie name carrying the JWT')]
    property Name: string read FName;

    [YamlNode('Path', 'Cookie path scope. Default: TKWebApplication.Path (the AppPath of this app)')]
    property Path: string read FPath;

    [YamlNode('HttpOnly', 'True', 'Whether the cookie is invisible to JavaScript (recommended)')]
    property HttpOnly: Boolean read FHttpOnly;

    [YamlNode('Secure', 'True', 'Whether the cookie is only sent over HTTPS (recommended)')]
    property Secure: Boolean read FSecure;

    [YamlNode('SameSite', 'Lax', 'SameSite attribute. Strict | Lax | None | empty (omit attribute)')]
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

    [YamlNode('IncludeDisplayName', 'False', 'Embed the user display name as the name claim')]
    property IncludeDisplayName: Boolean read FIncludeDisplayName;

    [YamlNode('IncludeLanguage', 'False', 'Embed the active language as the lang claim')]
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
    FClockSkew: Integer;
    FCookie: TKAuthCookieConfig;
    FClaims: TKAuthClaimsConfig;
  protected
    procedure ReadConfig; override;
  public
    destructor Destroy; override;

    [YamlNode('SigningAlgorithm', 'HS256', 'JWT signing algorithm. HS256 / HS384 / HS512 (HMAC, no OpenSSL) or RS256 / RS384 / RS512 / ES256 / ES384 / ES512 (asymmetric, requires OpenSSL DLLs)')]
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

    [YamlNode('ClockSkew', '60', 'Allowance in seconds for clock skew between client and server during exp/nbf/iat validation.')]
    property ClockSkew: Integer read FClockSkew;

    [YamlSubNode('Cookie', TKAuthCookieConfig, 'JWT cookie attributes (HttpOnly / Secure / SameSite / Path / Name)')]
    property Cookie: TKAuthCookieConfig read FCookie;

    [YamlSubNode('Claims', TKAuthClaimsConfig, 'Optional profile claims embedded in the JWT (roles, db, language, ACL, ...)')]
    property Claims: TKAuthClaimsConfig read FClaims;
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
    FFileName: string;
    FDatabaseChoices: string;
    FDefaults: TKAuthDefaultsConfig;
    FJWT: TKAuthJWTConfig;
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

    [YamlNode('FileName', 'Text file path for text-file authentication')]
    property FileName: string read FFileName;

    [YamlNode('DatabaseChoices', 'Comma-separated list of Databases/<Name> entries the user can pick at login. Empty = no environment combo on the login page. Embedded in the db claim when a JWT envelope is configured.')]
    property DatabaseChoices: string read FDatabaseChoices;

    [YamlSubNode('Defaults', TKAuthDefaultsConfig, 'Default credentials')]
    property Defaults: TKAuthDefaultsConfig read FDefaults;

    [YamlSubNode('JWT', TKAuthJWTConfig, 'Optional JWT envelope. Present = issue/validate a signed self-contained token cookie (kx_token) instead of a plain session cookie. Requires the Kitto.Auth.JWT unit in UseKitto.pas.')]
    property JWT: TKAuthJWTConfig read FJWT;
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

{ TKAuthConfig }

procedure TKAuthConfig.ReadConfig;
begin
  FIsClearPassword := GetBoolean('IsClearPassword');
  FIsPassepartoutEnabled := GetBoolean('IsPassepartoutEnabled');
  FPassepartoutPassword := GetString('PassepartoutPassword');
  FReadUserCommandText := GetString('ReadUserCommandText');
  FSetPasswordCommandText := GetString('SetPasswordCommandText');
  FAfterAuthenticateCommandText := GetString('AfterAuthenticateCommandText');
  FFileName := GetString('FileName');
  FDatabaseChoices := GetString('DatabaseChoices');
  // Nested readers: bound to the Defaults/JWT subtrees (nil-safe when absent).
  if FDefaults = nil then
    FDefaults := TKAuthDefaultsConfig.Create(SubNode('Defaults'))
  else
    FDefaults.Refresh(SubNode('Defaults'));
  if FJWT = nil then
    FJWT := TKAuthJWTConfig.Create(SubNode('JWT'))
  else
    FJWT.Refresh(SubNode('JWT'));
end;

destructor TKAuthConfig.Destroy;
begin
  FDefaults.Free;
  FJWT.Free;
  inherited;
end;

end.
