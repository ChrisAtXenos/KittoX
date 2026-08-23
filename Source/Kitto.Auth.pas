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
///   Defines the base authenticator and related classes and services.
///   Authenticators allow the creation of applications that require user
///   anthentication at startup.
/// </summary>
unit Kitto.Auth;

{$I Kitto.Defines.inc}

interface

uses
  System.Classes,
  EF.Types,
  EF.Classes,
  EF.Tree;

type
  /// <summary>
  ///   <para>Abstract base authenticator. An authenticator defines a method
  ///   for user authentication.</para>
  ///   <para>Only one authenticator may be active at any one time.</para>
  ///   <para>Applications wanting to use a custom authentication scheme should
  ///   create and register an authenticator, and then make it active through
  ///   the configuration.</para>
  /// </summary>
  TKAuthenticator = class(TEFComponent)
  strict private
    class threadvar FCurrent: TKAuthenticator;
    procedure ClearAuthData;
  strict
  private
    FIsBCrypted: Boolean;
    function GetAuthData: TEFNode; protected
    class function GetCurrent: TKAuthenticator; static;
    class procedure SetCurrent(const AValue: TKAuthenticator); static; protected
    function GetIsAuthenticated: Boolean; virtual;
    function GetIsBCrypted: Boolean; virtual;

    /// <summary>
    ///  Implements the IsClearPassword property.
    /// </summary>
    function GetIsClearPassword: Boolean; virtual;

    /// <summary>Called at the beginning of the authentication process, before
    /// InternalAuthenticate.</summary>
    procedure InternalBeforeAuthenticate(const AAuthData: TEFNode); virtual;

    /// <summary>Called at the end of the authentication process, in case of
    /// successful authentication.</summary>
    procedure InternalAfterAuthenticate(const AAuthData: TEFNode); virtual;

    /// <summary>Implements Authenticate. Descendants should verify that
    /// AAuthData contains all required items, query whatever authentication
    /// mechanism they encapsulate, and return True if a match is found and
    /// False otherwise.</summary>
    function InternalAuthenticate(const AAuthData: TEFNode): Boolean; virtual; abstract;

    /// <summary>Implements DefineAuthData.</summary>
    procedure InternalDefineAuthData(const AAuthData: TEFNode); virtual; abstract;

    /// <summary>Assign default values to AuthData.</summary>
    procedure InternalDefaultToAuthData(const AAuthData: TEFNode); virtual;

    /// <summary>
    ///  The body of the default InternalDefaultToAuthData: fills each auth item
    ///  from Config's Defaults/&lt;ItemName&gt; node. Not virtual, and kept apart
    ///  from the virtual method so that a decorator (see TKAuthenticatorDecorator)
    ///  which re-declares InternalDefaultToAuthData as abstract can still reach
    ///  this behaviour when it has to answer locally.
    /// </summary>
    procedure ApplyConfigDefaults(const AAuthData: TEFNode);

    /// <summary>This function should return a unique user identifier, to be
    /// used for example for access control. The default implementation returns
    /// 'PUBLIC', while a descendant will return the user name or something
    /// else, as needed.</summary>
    function GetUserName: string; virtual;

    /// <summary>For password-based authenticators, this function should return
    /// the current user's password (or hash). The default implementation
    /// returns a blank string.</summary>
    function GetPassword: string; virtual;

    /// <summary>Changes the current user's password in whatever underlying
    /// storage the authenticator uses. Only makes sense for password-based
    /// authenticator. The default implementation does nothing.</summary>
    /// <remarks>After calling this method, the user stays authenticated and
    /// the session's password is updated (the password used when first
    /// authenticating is lost). This allows a user to change his password more
    /// than once per session.</remarks>
    procedure SetPassword(const AValue: string); virtual;

    /// <summary>For PIN-based authenticators, this function should return
    /// the current user's secret code (to generate the 6-digit one time PIN).
    /// The default implementation returns a blank string.</summary>
    function GetSecretCode: string; virtual;

    /// <summary>Returns True if the authentication data contains a custom field
    /// called MUST_CHANGE_PASSWORD with value 1. Override this method to implement a
    /// custom way of signaling that the user needs to change his password.</summary>
    function GetMustChangePassword: Boolean; virtual;

    /// <summary>Returns True if the authentication data contains a custom field
    /// called MUST_CONFIRM_ACCESS with value 1. Override this method to implement a
    /// custom way of signaling that the user needs to confirm the access to the system.</summary>
    function GetMustConfirmAccess: Boolean; virtual;
  public
    /// <summary>Defines the auth data on the current session and creates the
    /// auth macro expander.</summary>
    procedure AfterConstruction; override;
    /// <summary>Frees the auth macro expander.</summary>
    destructor Destroy; override;
  public
    /// <summary>
    ///   <para>Receives an empty node which it should fill with the
    ///   definitions (names and types, not values) of all required auth items.
    ///   The system uses this information at login time, so that the user can
    ///   supply any auth data needed by the currently active authenticator.
    ///   The most common example of auth data is a UserName + Password
    ///   combination.</para>
    ///   <para>If no auth items are defined, then the system will not prompt
    ///   the user but will still call Authenticate passing in an empty
    ///   node.</para>
    /// </summary>
    procedure DefineAuthData(const AAuthData: TEFNode);

    /// <summary>
    ///  Checks whether the specified auth data designates a valid user
    ///  or not, and returns False if the authentication fails.
    /// </summary>
    function Authenticate(const AAuthData: TEFNode): Boolean;

    /// <summary>Gives access to a copy of the auth data that was last passed
    /// to Authenticate (and possibly modified by the object during
    /// authentication).</summary>
    property AuthData: TEFNode read GetAuthData;

    /// <summary>Clears AuthData and turns off IsAuthenticated.</summary>
    procedure Logout; virtual;

    /// <summary>A unique identifier for the currently logged in user. The
    /// value depends on the particular descendant. By default, it's
    /// 'PUBLIC'.</summary>
    property UserName: string read GetUserName;

    /// <summary>For password-based authenticators, returns the current user's
    /// password or hash. The default implementation returns a blank
    /// string.</summary>
    property Password: string read GetPassword write SetPassword;

    /// <summary>For PIN-based authenticators, returns the current user's
    /// secret code (to generate the 6-digit one time PIN).
    /// The default implementation returns a blank string.</summary>
    property SecretCode: string read GetSecretCode;

    /// <summary>Returns True if the autheticator uses clear passwords, False
    /// if hashing is used. Only meaningful for password-based authenticators.
    /// By default, returns True.</summary>
    property IsClearPassword: Boolean read GetIsClearPassword;

    /// <summary>Returns True if authentication has successfully taken
    /// place.</summary>
    property IsAuthenticated: Boolean read GetIsAuthenticated;

    /// <summary>Returns True if the authentication data signals that the user
    /// must change his password. By default, this happens when a custom field
    /// called MUST_CHANGE_PASSWORD with value 1 is added to the authentication data.
    /// Querying this property is only meaningful after successful authentication.</summary>
    property MustChangePassword: Boolean read GetMustChangePassword;

    /// <summary>Returns True if the authentication need to confirm
    /// a pre-requisite to access to system.</summary>
    property MustConfirmAccess: Boolean read GetMustConfirmAccess;

    /// <summary>
    ///  Called (with no authenticated user) when a password reset is initiated.
    ///  Override this method to implement an application-defined scheme, such
    ///  as generating a random password and emailing it to the user.
    ///  The specified params depend on the calling controller.
    ///  A standard controller might specify the user name (UserName) or
    ///  email address (EmailAddress) to which the generated password should be sent.
    /// </summary>
    procedure ResetPassword(const AParams: TEFNode); virtual; abstract;

    /// <summary>Thread-local reference to the currently active authenticator
    /// instance for the request being served.</summary>
    class property Current: TKAuthenticator read GetCurrent write SetCurrent;

    /// <summary>
    ///  Called (with no authenticated user) when a QR code (for PIN authentication)
    ///  is requested. Override this method to implement an application-defined
    ///  scheme, such as generating a QR code containing the secret to share with
    ///  the third party authenticator app and emailing it to the user.
    ///  The specified params depend on the calling controller.
    ///  A standard controller might specify the user name (UserName) and
    ///  email address (EmailAddress) to which the generated QR code should be sent.
    /// </summary>
    procedure QRGenerate(const AParams: TEFNode); virtual; abstract;

    /// <summary>Returns True if the supplied password hash matches the stored
    /// one. Concrete authenticators define the actual matching rules.</summary>
    function IsPasswordMatching(const ASuppliedPasswordHash: string;
      const AStoredPasswordHash: string): Boolean; virtual; abstract;

    /// <summary>Indicates whether the stored password is hashed with the BCrypt
    /// algorithm (as opposed to the legacy hash or clear text).</summary>
    property IsBCrypted: Boolean read GetIsBCrypted write FIsBCrypted;
  public
    /// <summary>
    ///  Tells whether this authenticator is able to write a new password to
    ///  wherever it keeps credentials. The default is True: every password-based
    ///  authenticator overrides SetPassword and can honour a change.
    ///
    ///  Authenticators that do NOT own the credentials return False — the
    ///  directory-backed ones (Auth: LDAP) being the case in point: passwords
    ///  live in the directory and must be changed there. Returning False is not
    ///  cosmetic: SetPassword's base implementation has an EMPTY body, so
    ///  without this the change-password handler would report success and write
    ///  nothing at all. Callers MUST consult this before writing (see
    ///  Kitto.Web.Handler.Auth.HandleChangePassword) and SHOULD consult it
    ///  before offering the UI (see Kitto.Html.ChangePassword).
    /// </summary>
    function SupportsPasswordChange: Boolean; virtual;

    /// <summary>
    ///  Returns the configuration node that callers should consult when they
    ///  read user-facing auth options like DatabaseChoices, ValidatePassword,
    ///  IsPassepartoutEnabled, etc. For a plain authenticator this is just
    ///  the authenticator's own Config. For wrapping authenticators (notably
    ///  TKJWTAuthenticator) it returns the wrapped Inner authenticator's
    ///  Config, so that the same YAML keys keep working whether or not the
    ///  app sits behind a JWT envelope.
    /// </summary>
    function EffectiveConfigNode: TEFTree; virtual;

    /// <summary>
    ///  Per-request hook invoked by TKWebApplication just after ActivateInstance
    ///  and before any route dispatch. Default does nothing. Authenticators
    ///  that carry a request-bound credential (e.g. TKJWTAuthenticator) override
    ///  this to validate the credential, hydrate the session, slide expirations,
    ///  etc. — without forcing the framework runtime layer to depend on the
    ///  authenticator's third-party libraries.
    /// </summary>
    procedure AuthorizeRequest; virtual;

    /// <summary>
    ///  Tells the framework whether this authenticator's credential already
    ///  carries the session id (e.g. JWT 'sid' claim). When True, the engine
    ///  must NOT emit a separate session id cookie because the credential
    ///  itself binds the request to the server-side TKWebSession. Default is
    ///  False — Auth: DB / TextFile / Null and similar plain authenticators
    ///  rely on a separate session id cookie named after AppName.
    ///
    ///  Class function so the engine can probe the registered authenticator
    ///  class at startup, well before any request thread sets up
    ///  TKAuthenticator.Current — which is nil again by the time the engine's
    ///  AfterHandleRequest runs (DeactivateInstance has already cleared it).
    /// </summary>
    class function CarriesSessionIdInCredential: Boolean; virtual;
  end;
  /// <summary>Metaclass reference used to register and create authenticators
  /// by class.</summary>
  TKAuthenticatorClass = class of TKAuthenticator;

  /// <summary>
  ///   <para>An abstract authenticator that requires UserName and Password as
  ///   auth data.</para>
  ///   <para>How the auth data is checked is deferred to the concrete
  ///   descendants. The value of the UserName auth item is also used as the
  ///   value for the UserName property.</para>
  /// </summary>
  TKClassicAuthenticator = class(TKAuthenticator)
  protected
    procedure InternalDefineAuthData(const AAuthData: TEFNode); override;
    function GetUserName: string; override;
    function GetPassword: string; override;
    function GetSecretCode: string; override;

    /// <summary>
    ///  The body of InternalDefineAuthData: declares the UserName, Password,
    ///  Language and SecretCode auth items. Not virtual, and kept apart from the
    ///  virtual method for the same reason as TKAuthenticator.ApplyConfigDefaults
    ///  — a decorator that re-declares InternalDefineAuthData as abstract can
    ///  still reach this behaviour when it has to answer locally.
    /// </summary>
    procedure DefineStandardAuthData(const AAuthData: TEFNode);
  end;

  /// <summary>
  ///  <para>Base class for an authenticator that WRAPS another one (the "Inner"
  ///  authenticator) and stands in front of it: every call reaches the decorator
  ///  first, which then decides whether to answer itself or pass the call on.
  ///  TKJWTAuthenticator is the only such class in the framework today.</para>
  ///
  ///  <para><b>Why this class exists.</b> A decorator that simply inherits the
  ///  members it forgets to pass on does not fail: it answers with the base
  ///  implementation, which is a plausible-looking value, and the Inner
  ///  authenticator's own version is never called — silently. That is not a
  ///  hypothetical: it is how the framework shipped SetPassword (base body is
  ///  EMPTY: the change-password dialog reported success and wrote nothing) and
  ///  GetMustConfirmAccess (the privacy consent was never asked for), both
  ///  eventually found and fixed as bugs; and it is why an application override
  ///  of InternalDefaultToAuthData and TKOSDBAuthenticator's OS-user login are
  ///  bypassed under Auth: JWT.</para>
  ///
  ///  <para><b>What it does about it.</b> Every member on which a decorator must
  ///  take a decision is re-declared here as abstract, so a decorator CANNOT
  ///  inherit it by accident — it has to write something, and what it writes is
  ///  the decision, visible in code. Note that the enforcement needs the guard
  ///  procedure at the bottom of the decorator's unit: the compiler only checks
  ///  completeness where a class is constructed BY NAME, and authenticators are
  ///  created through a factory (metaclass), which it cannot check.</para>
  ///
  ///  <para><b>If the compiler stopped you here</b> with E1020 "Constructing
  ///  instance of ... containing abstract method ...": a member was added to this
  ///  contract and your decorator does not implement it yet. Implement it, and
  ///  make it one of two things — either pass the call on to the Inner
  ///  authenticator, or answer locally AND write down why the Inner must not be
  ///  asked. Do not add a member here just to silence something: the list is
  ///  meant to stay short and deliberate.</para>
  ///
  ///  <para><b>Members deliberately NOT in the contract</b>, because a decorator
  ///  needs the base implementation to run and cannot re-abstract it:
  ///  Logout (the base clears auth data and the session flag), AuthorizeRequest,
  ///  EffectiveConfigNode, CarriesSessionIdInCredential, InternalAfterAuthenticate
  ///  and InternalBeforeAuthenticate. The last two also need no forwarding at all:
  ///  a decorator authenticates by calling the Inner's public Authenticate, which
  ///  runs the Inner's own before/after hooks. InternalAuthenticate, ResetPassword,
  ///  QRGenerate and IsPasswordMatching need no entry either — they are already
  ///  abstract in TKAuthenticator, so the compiler already demands them.</para>
  /// </summary>
  TKAuthenticatorDecorator = class(TKClassicAuthenticator)
  protected
    function GetIsAuthenticated: Boolean; override; abstract;
    function GetIsBCrypted: Boolean; override; abstract;
    function GetIsClearPassword: Boolean; override; abstract;
    procedure InternalDefineAuthData(const AAuthData: TEFNode); override; abstract;
    procedure InternalDefaultToAuthData(const AAuthData: TEFNode); override; abstract;
    function GetUserName: string; override; abstract;
    function GetPassword: string; override; abstract;
    procedure SetPassword(const AValue: string); override; abstract;
    function GetSecretCode: string; override; abstract;
    function GetMustChangePassword: Boolean; override; abstract;
    function GetMustConfirmAccess: Boolean; override; abstract;
  public
    /// <summary>Re-abstracted like the members above: whether a password can be
    /// written at all is the wrapped authenticator's business, and answering it
    /// here with the inherited True would offer the user a change that then
    /// silently does nothing.</summary>
    function SupportsPasswordChange: Boolean; override; abstract;
  end;

  /// <summary>The Null authenticator does not require authentication data and
  /// always grants authentication. It is used by default.</summary>
  TKNullAuthenticator = class(TKAuthenticator)
  protected
    procedure InternalDefineAuthData(const AAuthData: TEFNode); override;
    function InternalAuthenticate(
      const AAuthData: TEFNode): Boolean; override;
    function GetIsAuthenticated: Boolean; override;
  public
    /// <summary>
    ///  There is no credential store at all here, so the three members below
    ///  cannot do anything meaningful. They are implemented rather than left
    ///  abstract because abstract members of a factory-created class do not
    ///  fail at build time: they raise "Abstract Error" the first time a user
    ///  reaches the feature, which is a crash instead of an explanation.
    /// </summary>
    function SupportsPasswordChange: Boolean; override;
    /// <summary>Raises: there is no account whose password could be reset.</summary>
    procedure ResetPassword(const AParams: TEFNode); override;
    /// <summary>Raises: no per-user secret exists to enrol a device with.</summary>
    procedure QRGenerate(const AParams: TEFNode); override;
    /// <summary>Always False. No password is stored, so nothing can match one,
    /// and returning True would make an empty password look verified.</summary>
    function IsPasswordMatching(const ASuppliedPasswordHash: string;
      const AStoredPasswordHash: string): Boolean; override;
  end;

  /// <summary>This class holds a list of registered authenticator
  /// classes.</summary>
  TKAuthenticatorRegistry = class(TEFRegistry)
  private
    class var FInstance: TKAuthenticatorRegistry;
    class function GetInstance: TKAuthenticatorRegistry; static;
  public
    /// <summary>Frees the singleton registry instance.</summary>
    class destructor Destroy;
    /// <summary>The lazily-created singleton registry instance.</summary>
    class property Instance: TKAuthenticatorRegistry read GetInstance;

    /// <summary>Adds an authenticator class to the registry.</summary>
    procedure RegisterClass(const AId: string; const AClass: TKAuthenticatorClass);
  end;

  /// <summary>Creates authenticators by Id.</summary>
  TKAuthenticatorFactory = class(TEFFactory)
  private
    class var FInstance: TKAuthenticatorFactory;
    class function GetInstance: TKAuthenticatorFactory; static;
  public
    /// <summary>Frees the singleton factory instance.</summary>
    class destructor Destroy;
    /// <summary>The lazily-created singleton factory instance.</summary>
    class property Instance: TKAuthenticatorFactory read GetInstance;

    /// <summary>Creates and returns an instance of the authenticator class
    /// identified by AClassId. Raises an exception if said class is not
    /// registered.</summary>
    function CreateObject(const AClassId: string): TKAuthenticator;
  end;

implementation

uses
  System.SysUtils,
  EF.StrUtils,
  EF.Localization,
  Kitto.Types,
  Kitto.Web.Application,
  Kitto.Web.Session;

{ TKNullAuthenticator }

procedure TKNullAuthenticator.InternalDefineAuthData(const AAuthData: TEFNode);
begin
  // No authentication data required.
end;

function TKNullAuthenticator.GetIsAuthenticated: Boolean;
begin
  Result := True;
end;

function TKNullAuthenticator.InternalAuthenticate(const AAuthData: TEFNode): Boolean;
begin
  Result := True;
end;

function TKNullAuthenticator.SupportsPasswordChange: Boolean;
begin
  // No credentials are stored, so there is nothing to change. Without this the
  // base SetPassword — whose body is empty — would run and the dialog would
  // report success while writing nothing.
  Result := False;
end;

procedure TKNullAuthenticator.ResetPassword(const AParams: TEFNode);
begin
  raise EKError.Create(_('Password reset is not available: this application does not authenticate users.'));
end;

procedure TKNullAuthenticator.QRGenerate(const AParams: TEFNode);
begin
  raise EKError.Create(_('PIN/QR authentication is not available: this application does not authenticate users.'));
end;

function TKNullAuthenticator.IsPasswordMatching(const ASuppliedPasswordHash,
  AStoredPasswordHash: string): Boolean;
begin
  // Never reached: authentication always succeeds without looking at a
  // password, and the password-change flow is refused by
  // SupportsPasswordChange before it gets here.
  Result := False;
end;

{ TKAuthenticatorRegistry }

class destructor TKAuthenticatorRegistry.Destroy;
begin
  FreeAndNil(FInstance);
end;

class function TKAuthenticatorRegistry.GetInstance: TKAuthenticatorRegistry;
begin
  if FInstance = nil then
    FInstance := TKAuthenticatorRegistry.Create;
  Result := FInstance;
end;

procedure TKAuthenticatorRegistry.RegisterClass(const AId: string; const AClass: TKAuthenticatorClass);
begin
  inherited RegisterClass(AId, AClass);
end;

{ TKAuthenticatorFactory }

function TKAuthenticatorFactory.CreateObject(const AClassId: string): TKAuthenticator;
begin
  Result := inherited CreateObject(AClassId) as TKAuthenticator;
end;

class destructor TKAuthenticatorFactory.Destroy;
begin
  FreeAndNil(FInstance);
end;

class function TKAuthenticatorFactory.GetInstance: TKAuthenticatorFactory;
begin
  if FInstance = nil then
    FInstance := TKAuthenticatorFactory.Create(TKAuthenticatorRegistry.Instance);
  Result := FInstance;
end;

{ TKAuthenticator }

function TKAuthenticator.GetAuthData: TEFNode;
begin
  Result := TKWebSession.Current.AuthData;
end;

class function TKAuthenticator.GetCurrent: TKAuthenticator;
begin
  Result := FCurrent;
end;

class procedure TKAuthenticator.SetCurrent(const AValue: TKAuthenticator);
begin
  FCurrent := AValue;
end;

procedure TKAuthenticator.AfterConstruction;
begin
  inherited;
  DefineAuthData(TKWebSession.Current.AuthData);
  TKWebSession.Current.IsAuthenticated := False;
  // Object state, not session state — see GetIsBCrypted. Explicit even though
  // Delphi zeroes the field, to mirror Kitto1 and to keep the pairing with the
  // line above readable.
  FIsBCrypted := False;
end;

destructor TKAuthenticator.Destroy;
begin
  inherited;
end;

procedure TKAuthenticator.DefineAuthData(const AAuthData: TEFNode);
begin
  Assert(Assigned(AAuthData));

  InternalDefineAuthData(AAuthData);

  InternalDefaultToAuthData(AAuthData);
end;

function TKAuthenticator.GetIsAuthenticated: Boolean;
begin
  Result := TKWebSession.Current.IsAuthenticated;
end;

function TKAuthenticator.GetIsBCrypted: Boolean;
begin
  // Reads the authenticator's OWN field, not the session's: whether credentials
  // are BCrypt-hashed is a property of the configured authenticator class, the
  // same for every user, and it is set once in TKDBCryptAuthenticator's
  // AfterConstruction. This is what Kitto1 did (Kitto.Auth.pas:370-372 in the
  // 3.x sources).
  //
  // It used to read TKWebSession.Current.IsBCrypted, which could never be True:
  // the port moved AuthData, IsAuthenticated and this flag from the object to the
  // session — right for the first two, which ARE per-user — but only the getter
  // and the initialisation were moved, while the one writer that sets it True
  // kept writing the object field through the property. Nothing ever assigned
  // the session flag anything but False, so IsBCrypted always answered False and
  // the BCrypt branch of the change-password comparison was dead code. On top of
  // that, a per-session home cannot work here anyway: the authenticator is a
  // single instance per application, so its AfterConstruction runs once, in
  // whichever session happened to create it, and every other session would have
  // read False regardless.
  Result := FIsBCrypted;
end;

function TKAuthenticator.GetIsClearPassword: Boolean;
begin
  Result := True;
end;

function TKAuthenticator.GetPassword: string;
begin
  Result := '';
end;

function TKAuthenticator.GetSecretCode: string;
begin
  Result := '';
end;

function TKAuthenticator.GetMustChangePassword: Boolean;
begin
  Result := TKWebSession.Current.AuthData.GetInteger('MUST_CHANGE_PASSWORD') = 1;
end;

function TKAuthenticator.GetMustConfirmAccess: Boolean;
begin
  Result := TKWebSession.Current.AuthData.GetInteger('MUST_CONFIRM_ACCESS') = 1;
end;

function TKAuthenticator.GetUserName: string;
begin
  Result := 'PUBLIC';
end;

procedure TKAuthenticator.InternalBeforeAuthenticate(const AAuthData: TEFNode);
begin
end;

procedure TKAuthenticator.InternalDefaultToAuthData(const AAuthData: TEFNode);
begin
  ApplyConfigDefaults(AAuthData);
end;

procedure TKAuthenticator.ApplyConfigDefaults(const AAuthData: TEFNode);
var
  I: Integer;
begin
  // Get meaningful defaults.
  for I := 0 to AAuthData.ChildCount - 1 do
    AAuthData.Children[I].AssignValue(Config.FindNode('Defaults/' + AAuthData.Children[I].Name));
end;

function TKAuthenticator.SupportsPasswordChange: Boolean;
begin
  // Every password-based authenticator overrides SetPassword and can honour a
  // change. Those that do not own the credentials (Auth: LDAP) override this
  // with False, so callers can refuse instead of reporting a silent success.
  Result := True;
end;

function TKAuthenticator.EffectiveConfigNode: TEFTree;
begin
  Result := Config;
end;

procedure TKAuthenticator.AuthorizeRequest;
begin
  // Default no-op. Descendants override.
end;

class function TKAuthenticator.CarriesSessionIdInCredential: Boolean;
begin
  Result := False;
end;

procedure TKAuthenticator.Logout;
begin
  ClearAuthData;
  TKWebSession.Current.IsAuthenticated := False;
end;

procedure TKAuthenticator.SetPassword(const AValue: string);
begin
end;

procedure TKAuthenticator.ClearAuthData;
begin
  TKWebSession.Current.AuthData.Clear;
  DefineAuthData(TKWebSession.Current.AuthData);
end;

procedure TKAuthenticator.InternalAfterAuthenticate(
  const AAuthData: TEFNode);
begin
end;

function TKAuthenticator.Authenticate(const AAuthData: TEFNode): Boolean;
begin
  Assert(Assigned(AAuthData));

  Result := False;
  // Make sure the macros are enabled while authenticating.
  TKWebSession.Current.AuthData.Assign(AAuthData);
  try
    InternalBeforeAuthenticate(AAuthData);
    Result := InternalAuthenticate(AAuthData);
    TKWebSession.Current.IsAuthenticated := Result;
    if Result then
    begin
      InternalAfterAuthenticate(AAuthData);
      // Pick up any data changed by InternalAfterAuthenticate.
      TKWebSession.Current.AuthData.Assign(AAuthData);
    end;
  finally
    if not Result then
      // Make sure we don't expand any macro that hasn't passed
      // authentication.
      Logout;
  end;
end;

{ TKClassicAuthenticator }

function TKClassicAuthenticator.GetPassword: string;
begin
  Result := TKWebSession.Current.AuthData.GetString('Password');
end;

function TKClassicAuthenticator.GetSecretCode: string;
begin
  Result := TKWebSession.Current.AuthData.GetString('SecretCode');
end;

function TKClassicAuthenticator.GetUserName: string;
begin
  Result := TKWebSession.Current.AuthData.GetString('UserName');
end;

procedure TKClassicAuthenticator.InternalDefineAuthData(const AAuthData: TEFNode);
begin
  DefineStandardAuthData(AAuthData);
end;

procedure TKClassicAuthenticator.DefineStandardAuthData(const AAuthData: TEFNode);
begin
  AAuthData.SetString('UserName', '');
  AAuthData.SetString('Password', '');
  AAuthData.SetString('Language', '');
  AAuthData.SetString('SecretCode','');
end;

initialization
  TKAuthenticatorRegistry.Instance.RegisterClass(NODE_NULL_VALUE, TKNullAuthenticator);

finalization
  TKAuthenticatorRegistry.Instance.UnregisterClass(NODE_NULL_VALUE);

end.

