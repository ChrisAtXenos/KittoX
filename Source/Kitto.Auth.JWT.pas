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
///   Opt-in JWT engine. Implements <see cref="IKXJWTEngine" /> and registers
///   itself so the base <c>TKAuthenticator</c> can issue and validate a
///   self-contained JWT (in an HttpOnly <c>kx_token</c> cookie) on top of ANY
///   authenticator that declares a <c>JWT:</c> block under its <c>Auth</c> node.
///
///   There is no wrapper/Inner authenticator any more: an app configures a plain
///   authenticator (<c>Auth: DB</c>, <c>Auth: LDAP</c>, a custom one, ...) and adds
///   an optional <c>JWT:</c> sub-block. The base decides WHEN to issue/validate/clear
///   a token (from the presence of that block) and delegates the crypto — and the
///   third-party JOSE dependency, which lives in <c>Kitto.Web.JWT</c> — to this
///   engine. Apps that do not use JWT never link JOSE.
///
///   Per-authenticator parsed configuration is cached as an opaque state object
///   attached to the authenticator (<c>TKAuthenticator.JWTState</c>), so the engine
///   itself stays a stateless singleton.
/// </summary>
unit Kitto.Auth.JWT;

{$I Kitto.Defines.inc}

interface

uses
  System.SysUtils,
  System.Classes,
  EF.Tree,
  EF.Types,
  Kitto.Auth,
  Kitto.Web.JWT;

type
  /// <summary>
  ///  Opaque per-authenticator state owned by the authenticator (assigned to its
  ///  JWTState property, which frees it). Holds the parsed JWT configuration and
  ///  the resolved app name for this authenticator.
  /// </summary>
  TKJWTEngineState = class
  public
    Config: TKJWTConfig;
    AppName: string;
    destructor Destroy; override;
  end;

  /// <summary>
  ///  Process-wide JWT engine. Registered in this unit's initialization via
  ///  RegisterJWTEngine; the base TKAuthenticator retrieves it through
  ///  GetJWTEngine when a JWT block is configured.
  /// </summary>
  TKJWTEngine = class(TInterfacedObject, IKXJWTEngine)
  strict private
    /// <summary>Lazily builds (once, under a per-authenticator lock) and returns
    /// the parsed JWT state for the given authenticator, reading the settings
    /// from its Auth/JWT sub-node.</summary>
    function EnsureState(const AAuthenticator: TKAuthenticator): TKJWTEngineState;
    function ResolveAppName: string;
    /// <summary>Snapshots the user's permissions/roles into a TKJWTAclArray for
    /// the kx_acl claim (only when AccessControl: JWT is configured).</summary>
    function BuildAclFromDB(const AUserId: string): TKJWTAclArray;
    /// <summary>Fills the token context from the authenticator identity and the
    /// session state, plus the ACL snapshot when enabled.</summary>
    procedure BuildContext(const AAuthenticator: TKAuthenticator;
      const AConfig: TKJWTConfig; out AContext: TKJWTContext);
    /// <summary>Re-issues the cookie with a fresh expiration, preserving the
    /// identity claims from the validated context.</summary>
    function SlideToken(const AConfig: TKJWTConfig; const AContext: TKJWTContext): string;
  public
    // IKXJWTEngine
    function IssueToken(const AAuthenticator: TKAuthenticator): string;
    function AuthorizeRequest(const AAuthenticator: TKAuthenticator): Boolean;
    procedure ClearToken(const AAuthenticator: TKAuthenticator);

    /// <summary>
    ///  True when AuthorizeRequest has just validated a JWT for the current
    ///  thread/request and the result is cached in CurrentContext. Used by
    ///  TKJWTAccessController to read the kx_acl claim without a second
    ///  signature verification per ACL call.
    /// </summary>
    class function HasContext: Boolean; static;
    /// <summary>The validated context cached by AuthorizeRequest for the current
    /// thread/request. Caller must check HasContext first.</summary>
    class function CurrentContext: TKJWTContext; static;
    /// <summary>Clears the thread-local context cache. Called by AuthorizeRequest
    /// when validation fails so subsequent ACL checks within the same request
    /// fall back to the unauthenticated path.</summary>
    class procedure ClearCurrentContext; static;
  end;

implementation

uses
  System.SyncObjs,
  System.Generics.Collections,
  EF.Logger,
  Kitto.Config,
  Kitto.Web.Application,
  Kitto.Web.Session,
  Kitto.AccessControl.DB,
  Kitto.Store;

type
  // Per-thread holder for the validated JWT context. Lives in the
  // FContextsByThread dictionary keyed by ThreadID. The dictionary owns the
  // holders, so finalization disposes of every record (and its managed
  // members — strings, dynamic arrays) in one shot.
  TKJWTContextHolder = class
  public
    Context: TKJWTContext;
    HasContext: Boolean;
    destructor Destroy; override;
  end;

destructor TKJWTContextHolder.Destroy;
begin
  Context.Clear;
  inherited;
end;

// Per-thread context cache populated by TKJWTEngine.AuthorizeRequest and read
// by TKJWTAccessController.InternalGetAccessGrantValue. Each request runs on its
// own Indy worker thread; the dictionary keyed by ThreadID isolates the cache so
// concurrent requests do not see each other's claims.
//
// Why a dictionary instead of a threadvar: Delphi's threadvar finalization does
// NOT release managed members (strings, dynamic arrays) of records when a worker
// thread exits. With Indy's TIdSchedulerOfThreadPool keeping ~20 workers alive
// for the server's lifetime, every populated context record was leaking its
// strings and the kx_acl array on shutdown. Owning the holders from a unit-level
// TObjectDictionary lets the finalization section free them deterministically.
var
  FContextsLock: TCriticalSection;
  FContextsByThread: TObjectDictionary<TThreadID, TKJWTContextHolder>;

function GetThreadContextHolder: TKJWTContextHolder;
var
  LTID: TThreadID;
begin
  LTID := TThread.Current.ThreadID;
  FContextsLock.Enter;
  try
    if not FContextsByThread.TryGetValue(LTID, Result) then
    begin
      Result := TKJWTContextHolder.Create;
      FContextsByThread.Add(LTID, Result);
    end;
  finally
    FContextsLock.Leave;
  end;
end;

{ TKJWTEngineState }

destructor TKJWTEngineState.Destroy;
begin
  FreeAndNil(Config);
  inherited;
end;

{ TKJWTEngine }

function TKJWTEngine.ResolveAppName: string;
begin
  // Read AppName directly from the loaded Config.yaml. TKConfig.AppName (class
  // function) can return the binary file name as a last-resort fallback when
  // called too early in the init chain, and that fallback gets cached for the
  // rest of the process lifetime — which would then never match the AppName
  // declared in Config.yaml, silently breaking TKJWTSigningKeyRegistry lookups
  // registered from UseKitto.pas with the YAML name.
  Result := '';
  if Assigned(TKConfig.Instance) then
    Result := TKConfig.Instance.Config.GetString('AppName', '');
  if Result = '' then
    Result := TKConfig.AppName;
  if Result = '' then
    Result := 'KittoXApp';
end;

function TKJWTEngine.EnsureState(const AAuthenticator: TKAuthenticator): TKJWTEngineState;
var
  LState: TKJWTEngineState;
  LJWTNode: TEFNode;
begin
  // Fast path: once the state is attached to the authenticator it is stable. The
  // double-checked lock (on the authenticator instance) avoids two concurrent
  // first-wave requests both building a state (the loser would be freed and
  // could leak). The Indy thread pool can reach IssueToken / AuthorizeRequest in
  // parallel before the state is attached.
  if not Assigned(AAuthenticator.JWTState) then
  begin
    TMonitor.Enter(AAuthenticator);
    try
      if not Assigned(AAuthenticator.JWTState) then
      begin
        LState := TKJWTEngineState.Create;
        try
          LState.AppName := ResolveAppName;
          // The JWT settings live under the Auth/JWT sub-node.
          LJWTNode := AAuthenticator.Config.FindNode('JWT');
          LState.Config := TKJWTConfig.Create(LState.AppName, LJWTNode);
          // Default the cookie path to the app path so other apps on the same
          // host do not see this token.
          if LState.Config.CookiePath = '' then
          begin
            if Assigned(TKWebApplication.Current) and (TKWebApplication.Current.Path <> '') then
              LState.Config.CookiePath := TKWebApplication.Current.Path
            else
              LState.Config.CookiePath := '/';
          end;
        except
          LState.Free;
          raise;
        end;
        // The authenticator takes ownership (frees it in its Destroy / setter).
        AAuthenticator.JWTState := LState;
      end;
    finally
      TMonitor.Exit(AAuthenticator);
    end;
  end;
  Result := TKJWTEngineState(AAuthenticator.JWTState);
end;

function TKJWTEngine.BuildAclFromDB(const AUserId: string): TKJWTAclArray;
var
  LStorage: TKUserPermissionStorage;
  LAclConfig: TEFNode;
  I: Integer;
begin
  Result := nil;
  if AUserId = '' then
    Exit;

  LStorage := TKUserPermissionStorage.Create;
  try
    // Read the SQL templates from the AccessControl YAML node. The node exists
    // for both AccessControl: DB and AccessControl: JWT (the latter uses the same
    // keys for fallback queries). When absent, fall back to the defaults baked
    // into TKDBAccessController.
    LAclConfig := TKConfig.Instance.Config.FindNode('AccessControl');
    if Assigned(LAclConfig) then
    begin
      LStorage.ReadPermissionsCommandText :=
        LAclConfig.GetString('ReadPermissionsCommandText', DEFAULT_READPERMISSIONCOMMANDTEXT);
      LStorage.ReadRolesCommandText :=
        LAclConfig.GetString('ReadRolesCommandText', DEFAULT_READROLESCOMMANDTEXT);
      // Carry over DatabaseRouter / extra config so GetDatabaseName resolves the
      // same way the runtime DB controller would.
      for I := 0 to LAclConfig.ChildCount - 1 do
        if LStorage.Config.FindChild(LAclConfig.Children[I].Name) = nil then
          LStorage.Config.AddChild(TEFNode.Clone(LAclConfig.Children[I]));
    end
    else
    begin
      LStorage.ReadPermissionsCommandText := DEFAULT_READPERMISSIONCOMMANDTEXT;
      LStorage.ReadRolesCommandText := DEFAULT_READROLESCOMMANDTEXT;
    end;

    // Setting UserId triggers the actual load (user permissions + role
    // permissions). Failures bubble up as DB exceptions and abort the login.
    LStorage.UserId := AUserId;

    SetLength(Result, LStorage.Permissions.RecordCount);
    for I := 0 to LStorage.Permissions.RecordCount - 1 do
    begin
      Result[I].Pattern    := LStorage.Permissions.Records[I].Fields[0].AsString;
      Result[I].Modes      := LStorage.Permissions.Records[I].Fields[1].AsString;
      Result[I].GrantValue := LStorage.Permissions.Records[I].Fields[2].AsString;
    end;

    TEFLogger.Instance.LogFmt('JWT ACL snapshot built for %s: %d rows',
      [AUserId, Length(Result)], TEFLogger.LOG_DETAILED);
  finally
    LStorage.Free;
  end;
end;

procedure TKJWTEngine.BuildContext(const AAuthenticator: TKAuthenticator;
  const AConfig: TKJWTConfig; out AContext: TKJWTContext);
var
  LSession: TKWebSession;
begin
  AContext.Clear;
  LSession := TKWebSession.Current;

  AContext.UserName := AAuthenticator.UserName;
  if AConfig.IncludeDisplayName then
    AContext.DisplayName := LSession.DisplayName;
  if AConfig.IncludeDB then
    AContext.DatabaseName := LSession.DatabaseName;
  if AConfig.IncludeLanguage then
    AContext.Language := LSession.Language;

  if AConfig.IncludeACL then
  begin
    AContext.Acl := BuildAclFromDB(AContext.UserName);
    AContext.HasAcl := Length(AContext.Acl) > 0;
  end;

  // Sid keeps the JWT correlated to the server-side TKWebSession that holds
  // non-serializable state (open controllers, in-memory stores).
  AContext.Sid := LSession.SessionId;
  // Jti left empty — TKJWTBuilder generates a fresh GUID.
end;

function TKJWTEngine.IssueToken(const AAuthenticator: TKAuthenticator): string;
var
  LState: TKJWTEngineState;
  LContext: TKJWTContext;
begin
  LState := EnsureState(AAuthenticator);
  BuildContext(AAuthenticator, LState.Config, LContext);
  Result := TKJWTBuilder.Build(LContext, LState.Config);
  TKJWTCookieHelper.Issue(Result, LState.Config);
  TEFLogger.Instance.LogFmt('JWT issued for user %s, sid %s, app %s',
    [LContext.UserName, LContext.Sid, LState.AppName], TEFLogger.LOG_DETAILED);
end;

function TKJWTEngine.SlideToken(const AConfig: TKJWTConfig; const AContext: TKJWTContext): string;
var
  LContext: TKJWTContext;
begin
  // Re-issue with a fresh exp but preserve sid/sub/etc. from the validated
  // context. We do not rebuild from the current session — the validated token is
  // the source of truth for identity claims.
  LContext := AContext;
  LContext.CompactToken := '';
  LContext.IsValid := False;
  Result := TKJWTBuilder.Build(LContext, AConfig);
  TKJWTCookieHelper.Issue(Result, AConfig);
end;

function TKJWTEngine.AuthorizeRequest(const AAuthenticator: TKAuthenticator): Boolean;
var
  LState: TKJWTEngineState;
  LCookie: string;
  LContext: TKJWTContext;
  LErr: string;
  LHolder: TKJWTContextHolder;
begin
  // Reset any context left over from a previous request on this thread.
  ClearCurrentContext;

  LState := EnsureState(AAuthenticator);
  LCookie := TKJWTCookieHelper.ReadFromRequest(LState.Config);
  if Trim(LCookie) = '' then
  begin
    // No token: treat the request as unauthenticated. Public endpoints (Home,
    // Login) keep working; protected ones get redirected to login.
    TKWebSession.Current.IsAuthenticated := False;
    Exit(False);
  end;
  if not TKJWTValidator.Validate(LCookie, LState.Config, LContext, LErr) then
  begin
    TEFLogger.Instance.LogFmt('JWT cookie validation failed: %s', [LErr],
      TEFLogger.LOG_DETAILED);
    TKJWTCookieHelper.Clear(LState.Config);
    TKWebSession.Current.IsAuthenticated := False;
    Exit(False);
  end;
  // Token verified: this request is authenticated. Hydrate session state from
  // the validated claims, but only fields the server-side session does not
  // already carry.
  TKWebSession.Current.IsAuthenticated := True;
  TKWebSession.Current.AuthData.SetString('UserName', LContext.UserName);
  if (TKWebSession.Current.DatabaseName = '') and (LContext.DatabaseName <> '') then
    TKWebSession.Current.DatabaseName := LContext.DatabaseName;
  if (TKWebSession.Current.Language = '') and (LContext.Language <> '') then
    TKWebSession.Current.Language := LContext.Language;
  if TKWebSession.Current.DisplayName = '' then
    TKWebSession.Current.DisplayName := LContext.DisplayName;

  // Cache the validated context on the thread for the rest of this request.
  // TKJWTAccessController reads it (especially the kx_acl claim) without having
  // to re-validate the JWT on every IsAccessGranted call.
  LHolder := GetThreadContextHolder;
  LHolder.Context := LContext;
  LHolder.HasContext := True;

  if TKJWTCookieHelper.ShouldSlide(LContext, LState.Config) then
    SlideToken(LState.Config, LContext);

  Result := True;
end;

procedure TKJWTEngine.ClearToken(const AAuthenticator: TKAuthenticator);
begin
  TKJWTCookieHelper.Clear(EnsureState(AAuthenticator).Config);
end;

class function TKJWTEngine.HasContext: Boolean;
begin
  Result := GetThreadContextHolder.HasContext;
end;

class function TKJWTEngine.CurrentContext: TKJWTContext;
begin
  Result := GetThreadContextHolder.Context;
end;

class procedure TKJWTEngine.ClearCurrentContext;
var
  LHolder: TKJWTContextHolder;
begin
  LHolder := GetThreadContextHolder;
  LHolder.Context.Clear;
  LHolder.HasContext := False;
end;

initialization
  FContextsLock := TCriticalSection.Create;
  FContextsByThread := TObjectDictionary<TThreadID, TKJWTContextHolder>.Create([doOwnsValues]);
  RegisterJWTEngine(TKJWTEngine.Create);

finalization
  RegisterJWTEngine(nil);
  FreeAndNil(FContextsByThread);
  FreeAndNil(FContextsLock);

end.
