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

///	<summary>
///	  <para>Defines the DBServer authenticator and related classes and
///	  services.</para>
///	  <para>This authenticator uses the database server to authenticate
///	  users.</para>
///	</summary>
unit Kitto.Auth.DBServer;

{$I Kitto.Defines.inc}

interface

uses
  EF.Tree,
  Kitto.Auth;

type
  ///	<summary>
  ///	  <para>The DBServer authenticator uses the database server to
  ///	  authenticate users.</para>
  ///	  <para>It needs the same items as its ancestor <see cref=
  ///	  "TKClassicAuthenticator" />.</para>
  ///	  <para>In order for this authenticator to work, it is required that the
  ///	  user-name and password placeholders in the database connection strings
  ///	  stored in Config.yaml are written as <c>%Auth:UserName%</c> and
  ///	  <c>%Auth:Password%</c>. When Authenticate is called, the authenticator
  ///	  will allow macro substitution of these items and try to connect to the
  ///	  database.</para>
  ///	</summary>
  TKDBServerAuthenticator = class(TKClassicAuthenticator)
  private
    function GetDatabaseName: string;
  protected
    function InternalAuthenticate(const AAuthData: TEFNode): Boolean; override;
    /// <summary>
    ///  Refuses to run when the target connection does not take its credentials
    ///  from the supplied ones, i.e. when no %Auth:...% macro appears anywhere in
    ///  the Databases/<Name>/Connection block.
    ///
    ///  This authenticator's whole premise is that opening the connection IS the
    ///  credential check. With the credentials written literally in the config
    ///  the connection opens whatever the user typed, so EVERY login succeeds —
    ///  measured: 'SA'/'12345', a non-existent user with a wrong password, and
    ///  even empty credentials, all authenticated. The failure is total and
    ///  silent, so it is refused rather than logged: an application that really
    ///  wants no authentication says so with Auth: Null.
    /// </summary>
    procedure CheckConnectionUsesSuppliedCredentials(const ADatabaseName: string);
  public
    /// <summary>
    ///  The credentials here are the DATABASE SERVER's own: authentication is a
    ///  connection attempt, and the accounts live in the DBMS. Changing or
    ///  resetting one would mean altering a database user, which is a job for
    ///  the DBA, not for this authenticator. The three members below are
    ///  implemented rather than left abstract because abstract members of a
    ///  factory-created class do not fail at build time: they raise "Abstract
    ///  Error" the first time a user reaches the feature.
    /// </summary>
    function SupportsPasswordChange: Boolean; override;
    /// <summary>Raises: resetting one of these accounts means altering a database
    /// server user, which is a DBA operation, not an application one.</summary>
    procedure ResetPassword(const AParams: TEFNode); override;
    /// <summary>Raises: the DBMS owns the credential, so there is no per-user
    /// secret here to enrol a device with.</summary>
    procedure QRGenerate(const AParams: TEFNode); override;
    /// <summary>Always False: authentication here is a connection attempt, so no
    /// hash comparison takes place and no stored hash exists to compare.</summary>
    function IsPasswordMatching(const ASuppliedPasswordHash: string;
      const AStoredPasswordHash: string): Boolean; override;
  end;
  
implementation

uses
  System.SysUtils,
  System.StrUtils,
  EF.DB,
  EF.Localization,
  EF.Logger,
  Kitto.Types,
  Kitto.Config,
  Kitto.DatabaseRouter;

{ TKDBServerAuthenticator }

function TKDBServerAuthenticator.GetDatabaseName: string;
var
  LDatabaseRouterNode: TEFNode;
begin
  LDatabaseRouterNode := Config.FindNode('DatabaseRouter');
  if Assigned(LDatabaseRouterNode) then
    Result := TKDatabaseRouterFactory.Instance.GetDatabaseName(
      LDatabaseRouterNode.AsString, Self, LDatabaseRouterNode)
  else
    Result := TKConfig.Instance.DatabaseName;
end;

procedure TKDBServerAuthenticator.CheckConnectionUsesSuppliedCredentials(
  const ADatabaseName: string);
var
  LConnectionNode: TEFNode;
  I: Integer;
  LUsesAuthMacro: Boolean;
begin
  LConnectionNode := TKConfig.Instance.Config.FindNode(
    'Databases/' + ADatabaseName + '/Connection');
  if not Assigned(LConnectionNode) then
    Exit; // no such block: CreateStandaloneDBConnection will say so
  LUsesAuthMacro := False;
  for I := 0 to LConnectionNode.ChildCount - 1 do
    if ContainsText(LConnectionNode.Children[I].AsString, '%Auth:') then
    begin
      LUsesAuthMacro := True;
      Break;
    end;
  if not LUsesAuthMacro then
  begin
    TEFLogger.Instance.LogFmt('Auth: DBServer refused: the Databases/%s/Connection '+
      'block does not use %%Auth:UserName%% / %%Auth:Password%%, so opening it '+
      'checks nothing and every login would succeed.', [ADatabaseName],
      TEFLogger.LOG_HIGH);
    raise EKError.CreateFmt(
      _('Auth: DBServer cannot authenticate against database %s: its Connection block '+
        'has fixed credentials. This authenticator validates a login by opening the '+
        'connection WITH the supplied ones, so the Connection must read them through '+
        'the %%Auth:UserName%% and %%Auth:Password%% macros. As configured, every '+
        'login would be accepted — use Auth: Null if that is what you want.'),
      [ADatabaseName]);
  end;
end;

function TKDBServerAuthenticator.InternalAuthenticate(const AAuthData: TEFNode): Boolean;
var
  LDBConnection: TEFDBConnection;
begin
  // Outside the try below on purpose: that except turns any failure into a
  // plain "login refused", which would hide the reason from whoever has to fix
  // the configuration. This one must reach the error dialog and the log.
  CheckConnectionUsesSuppliedCredentials(GetDatabaseName);

  // The credential here is the database server's own password, not one stored by
  // the application - but it is still a password the user must type, and an empty
  // one is no credential at all. A DBMS account created without a password (or one
  // whose authentication plugin lets a blank one through) would otherwise become an
  // application login that needs nothing.
  if AAuthData.GetString('Password') = '' then
  begin
    TEFLogger.Instance.LogFmt('Authentication refused for user %s: empty password.',
      [AAuthData.GetString('UserName')], TEFLogger.LOG_DETAILED);
    Exit(False);
  end;

  try
    // Standalone: DBServer authentication resolves dynamic credentials
    // via %Auth:UserName%/%Auth:Password% macros — a cached connection
    // would let subsequent logins reuse the first caller's credentials.
    LDBConnection := TKConfig.CreateStandaloneDBConnection(GetDatabaseName);
    try
      LDBConnection.Open;
      Result := True;
    finally
      FreeAndNil(LDBConnection);
    end;
  except
    Result := False;
  end;
end;


function TKDBServerAuthenticator.SupportsPasswordChange: Boolean;
begin
  // The password belongs to a database account: it cannot be written from here.
  Result := False;
end;

procedure TKDBServerAuthenticator.ResetPassword(const AParams: TEFNode);
begin
  raise EKError.Create(_('Password reset is not supported by the DBServer authenticator: credentials are database accounts, managed on the server.'));
end;

procedure TKDBServerAuthenticator.QRGenerate(const AParams: TEFNode);
begin
  raise EKError.Create(_('PIN/QR authentication is not supported by the DBServer authenticator.'));
end;

function TKDBServerAuthenticator.IsPasswordMatching(const ASuppliedPasswordHash,
  AStoredPasswordHash: string): Boolean;
begin
  // Never reached: the credential check IS the connection attempt in
  // InternalAuthenticate, and no hash is ever stored on our side.
  Result := False;
end;

initialization
  TKAuthenticatorRegistry.Instance.RegisterClass('DBServer', TKDBServerAuthenticator);

finalization
  TKAuthenticatorRegistry.Instance.UnregisterClass('DBServer');

end.

