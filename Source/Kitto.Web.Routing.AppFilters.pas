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
///   Application-level request filters (Sprint E.1 of the routing refactor).
///   These are the concrete IKXRequestFilter implementations that need the web
///   application / session / response services; they are kept out of the
///   dependency-free Kitto.Web.Routing.Filters unit to avoid a circular uses.
///
///   Registered globally (in this unit's initialization) in the order that
///   makes the error handler the OUTERMOST layer:
///     1. TKXErrorHandlerFilter  — turns exceptions into a modal error dialog
///     2. TKXJWTAuthFilter       — hydrates the session from the JWT cookie
///     3. TKXAuthorizationFilter — session-lost + unauthenticated gate
///
///   Both the attribute pipeline (TKXRoutingRoute) and the legacy
///   TKWebApplication.DoHandleRequest run their dispatch through this chain, so
///   the gate and the error handling apply uniformly and are defined once.
/// </summary>
unit Kitto.Web.Routing.AppFilters;

{$I Kitto.Defines.inc}

interface

uses
  System.SysUtils,
  Kitto.Web.Routing.Filters;

type
  /// Hydrates the session from the kx_token cookie (no-op for non-JWT auth).
  TKXJWTAuthFilter = class(TInterfacedObject, IKXRequestFilter)
  public
    /// <summary>Validates the JWT cookie and hydrates the session from it (no-op otherwise).</summary>
    procedure BeforeInvoke(const AContext: IKXRequestContext);
    /// <summary>No-op.</summary>
    procedure AfterInvoke(const AContext: IKXRequestContext);
    /// <summary>Does not handle exceptions (returns False).</summary>
    function OnException(const AContext: IKXRequestContext; E: Exception): Boolean;
  end;

  /// Bounces a top-level browser navigation (no X-KittoX header) aimed at an
  /// HTML-fragment endpoint back to the app root, so pasting/typing a `/kx/...`
  /// URL never serves a bare fragment. Navigable endpoints (home, [TKXAnonymous],
  /// [TKXNavigable] — e.g. blob downloads) are exempt via AllowDirectNavigation.
  TKXNavigationGuardFilter = class(TInterfacedObject, IKXRequestFilter)
  public
    /// <summary>Redirects a top-level navigation to a fragment endpoint to the app
    /// root (sets Handled); passes through SPA requests and navigable endpoints.</summary>
    procedure BeforeInvoke(const AContext: IKXRequestContext);
    /// <summary>No-op.</summary>
    procedure AfterInvoke(const AContext: IKXRequestContext);
    /// <summary>Does not handle exceptions (returns False).</summary>
    function OnException(const AContext: IKXRequestContext; E: Exception): Boolean;
  end;

  /// Session-lost fatal check + unauthenticated 404 gate, honouring the context
  /// AllowSessionLost / AllowUnauthenticated flags computed by the pipeline.
  TKXAuthorizationFilter = class(TInterfacedObject, IKXRequestFilter)
  public
    /// <summary>Raises on a lost session, and 404s an unauthenticated request to a
    /// protected endpoint (sets Handled), honouring the context exemptions.</summary>
    procedure BeforeInvoke(const AContext: IKXRequestContext);
    /// <summary>No-op.</summary>
    procedure AfterInvoke(const AContext: IKXRequestContext);
    /// <summary>Does not handle exceptions (returns False).</summary>
    function OnException(const AContext: IKXRequestContext; E: Exception): Boolean;
  end;

  /// Renders any exception escaping the dispatch as a non-fatal modal dialog,
  /// keeping the session alive (same behaviour as the old DoHandleRequest except).
  TKXErrorHandlerFilter = class(TInterfacedObject, IKXRequestFilter)
  public
    /// <summary>No-op.</summary>
    procedure BeforeInvoke(const AContext: IKXRequestContext);
    /// <summary>No-op.</summary>
    procedure AfterInvoke(const AContext: IKXRequestContext);
    /// <summary>Renders the exception as a non-fatal modal dialog and returns True
    /// (session stays alive).</summary>
    function OnException(const AContext: IKXRequestContext; E: Exception): Boolean;
  end;

implementation

uses
  System.Classes,
  System.StrUtils,
  EF.Localization,
  EF.Logger,
  Kitto.Config,
  Kitto.Auth,
  Kitto.Web.Application,
  Kitto.Web.Session,
  Kitto.Web.Request,
  Kitto.Web.Response;

{ TKXJWTAuthFilter }

procedure TKXJWTAuthFilter.BeforeInvoke(const AContext: IKXRequestContext);
begin
  // Validate the kx_token cookie's signature/claims, hydrate session state from
  // the verified payload, slide the cookie near expiry. No effect for non-JWT auth.
  TKWebApplication.Current.AuthorizeJWTRequest;
end;

procedure TKXJWTAuthFilter.AfterInvoke(const AContext: IKXRequestContext);
begin
end;

function TKXJWTAuthFilter.OnException(const AContext: IKXRequestContext;
  E: Exception): Boolean;
begin
  Result := False;
end;

{ TKXNavigationGuardFilter }

procedure TKXNavigationGuardFilter.BeforeInvoke(const AContext: IKXRequestContext);
var
  LSecFetchMode: string;
begin
  // Endpoints meant to be reached directly (home page, auth recovery, blob/file
  // downloads opened in a new tab) are exempt.
  if AContext.AllowDirectNavigation then
    Exit;

  // A genuine SPA sub-request always carries X-KittoX: true (the body hx-headers
  // for HTMX, an explicit header for every fetch). Its presence means "not a
  // top-level navigation": never bounce it.
  if SameText(TKWebRequest.Current.GetHeaderField('X-KittoX'), 'true') then
    Exit;

  // Only a REAL top-level navigation (address bar / clicked link / window.open)
  // should be bounced. The Fetch Metadata header Sec-Fetch-Mode (sent by all
  // current browsers) tells them apart authoritatively:
  //   'navigate'                      -> top-level navigation      -> bounce
  //   'cors' / 'same-origin' / 'no-cors' -> programmatic fetch/XHR or a
  //     subresource load (img/iframe/script src) -> DO NOT bounce.
  // This is what lets endpoints loaded by a library that cannot add X-KittoX
  // (e.g. the calendar's event fetch via EventCalendar's dataUrl) reach the auth
  // gate normally, instead of being redirected to the app root — which, combined
  // with logout-on-root, was silently logging the user out.
  // Absent header (very old / non-browser clients): fall back to the previous
  // X-KittoX-only heuristic (treat as navigation and bounce).
  LSecFetchMode := TKWebRequest.Current.GetHeaderField('Sec-Fetch-Mode');
  if (LSecFetchMode <> '') and not SameText(LSecFetchMode, 'navigate') then
    Exit;

  if Assigned(TKWebResponse.Current) then
  begin
    TKWebResponse.Current.StatusCode := 302;
    TKWebResponse.Current.SetCustomHeader('Location',
      TKWebApplication.Current.Path + '/');
  end;
  TEFLogger.Instance.LogFmt(
    'Direct navigation to fragment endpoint bounced to home: %s',
    [AContext.Path], TEFLogger.LOG_DETAILED);
  AContext.Handled := True;
end;

procedure TKXNavigationGuardFilter.AfterInvoke(const AContext: IKXRequestContext);
begin
end;

function TKXNavigationGuardFilter.OnException(const AContext: IKXRequestContext;
  E: Exception): Boolean;
begin
  Result := False;
end;

{ TKXAuthorizationFilter }

const
  // The two views an imposed step is completed through. Same names
  // TKWebApplication.DisplayHomeView looks up when it renders the dialog.
  VIEW_CHANGE_PASSWORD = 'ChangePassword';
  VIEW_CONFIRM_ACCESS = 'ConfirmAccess';

procedure TKXAuthorizationFilter.BeforeInvoke(const AContext: IKXRequestContext);
var
  LRequiredView: string;
begin
  // Session lost after a server restart: raise so the error filter shows a fatal
  // dialog with reload. Recovery endpoints (home + login/reset/change) pass through.
  if TKWebSession.Current.IsSessionLost and not AContext.AllowSessionLost then
    raise Exception.Create(_('Session lost or expired, please restart!'));

  // Authentication gate: a protected endpoint must not be served to a session
  // whose IsAuthenticated flag is False. 404 keeps the same response shape used
  // for ACL deny / not-found, so probing cannot distinguish "protected" from
  // "absent". Exempt: the recovery endpoints, and views declared public via
  // ACName (both folded into AllowUnauthenticated by the pipeline).
  if (not TKWebSession.Current.IsAuthenticated) and not AContext.AllowUnauthenticated then
  begin
    if Assigned(TKWebResponse.Current) then
    begin
      // REST (/api) clients get a JSON 401; the SPA keeps the opaque 404 (so
      // probing can't tell "protected" from "absent"). The envelope shape matches
      // TKXApiErrorFilter; no JSON framework is linked into the core for this.
      if ContainsText(AContext.Path, TKWebApplication.Current.Config.RestBasePath) then
      begin
        TKWebResponse.Current.StatusCode := 401;
        TKWebResponse.Current.ContentType := 'application/json; charset=utf-8';
        TKWebResponse.Current.ReplaceContentStream(TStringStream.Create(
          '{"error":"Authentication required","code":"unauthorized"}', TEncoding.UTF8));
      end
      else
        TKWebResponse.Current.StatusCode := 404;
    end;
    TEFLogger.Instance.LogFmt(
      'Unauthenticated request to protected endpoint: %s',
      [AContext.Path], TEFLogger.LOG_DETAILED);
    AContext.Handled := True;
    Exit;
  end;

  // Imposed-step gate. A user who still has to choose a new password (first
  // access, or after a reset) or to accept the privacy terms IS authenticated,
  // so the gate above lets every endpoint through — and TKWebApplication only
  // uses these two flags to decide which view the HOME PAGE renders. Verified:
  // logging in with MUST_CHANGE_PASSWORD = 1 and then asking for
  // kx/view/<V>/data served the rows, while the home page was correctly showing
  // the imposed dialog. The step was therefore a UI convention, not a control:
  // anything that skipped the home page skipped it too, and for the privacy
  // consent that is a compliance gate that did not hold.
  //
  // Exempt: whatever is already exempt from the authentication gate (the home
  // page — which is what renders the dialog — the [TKXAnonymous] endpoints
  // including kx/changepassword itself, and views declared public), plus every
  // endpoint scoped to the very view the step needs, so that dialog can read
  // and save.
  if not AContext.AllowUnauthenticated then
  begin
    LRequiredView := '';
    if TKAuthenticator.Current.MustChangePassword then
      LRequiredView := VIEW_CHANGE_PASSWORD
    else if TKAuthenticator.Current.MustConfirmAccess then
      LRequiredView := VIEW_CONFIRM_ACCESS;

    if (LRequiredView <> '') and not SameText(AContext.MatchedViewName, LRequiredView) then
    begin
      // Same opaque 404 as above, for the same reason.
      if Assigned(TKWebResponse.Current) then
        TKWebResponse.Current.StatusCode := 404;
      TEFLogger.Instance.LogFmt(
        'Request blocked: the user must first complete %s. Endpoint: %s',
        [LRequiredView, AContext.Path], TEFLogger.LOG_DETAILED);
      AContext.Handled := True;
    end;
  end;
end;

procedure TKXAuthorizationFilter.AfterInvoke(const AContext: IKXRequestContext);
begin
end;

function TKXAuthorizationFilter.OnException(const AContext: IKXRequestContext;
  E: Exception): Boolean;
begin
  Result := False;
end;

{ TKXErrorHandlerFilter }

procedure TKXErrorHandlerFilter.BeforeInvoke(const AContext: IKXRequestContext);
begin
end;

procedure TKXErrorHandlerFilter.AfterInvoke(const AContext: IKXRequestContext);
begin
end;

function TKXErrorHandlerFilter.OnException(const AContext: IKXRequestContext;
  E: Exception): Boolean;
begin
  // Log before rendering. The dialog reaches the user, not the operator: an
  // exception used to leave NO trace at all, so an access violation or any
  // other failure escaping a handler was invisible in the log even at
  // Level: 5 — which makes a bug report impossible to act on. Class, message
  // and endpoint, at LOG_HIGH so it survives a low log level. Same reasoning
  // as LogSaveError in Kitto.Web.Handler.View.
  TEFLogger.Instance.LogFmt('Unhandled %s on %s: %s',
    [E.ClassName, AContext.Path, E.Message], TEFLogger.LOG_HIGH);

  // Every exception bubbling out of a handler is shown as a NON-FATAL modal
  // dialog so the session stays alive and the user can retry. E.Message already
  // carries the formatted "Errore <sql-error> nella query: {GUID}" wrapping for
  // EEFDBError (see EF.DB.pas). Matches the legacy DoHandleRequest except block.
  TKWebApplication.Current.RenderErrorDialog(_('Load error:') + ' ' + E.Message, False);
  Result := True;
end;

initialization
  // Order matters: first registered = outermost. Error handler first so it wraps
  // both the auth filters and the dispatch.
  TKXFilterRegistry.Instance.RegisterFilter(TKXErrorHandlerFilter.Create);
  TKXFilterRegistry.Instance.RegisterFilter(TKXJWTAuthFilter.Create);
  // Navigation guard before the authorization gate: a bounced top-level
  // navigation redirects to the app root instead of getting the 404 the auth
  // gate would return for an anonymous session.
  TKXFilterRegistry.Instance.RegisterFilter(TKXNavigationGuardFilter.Create);
  TKXFilterRegistry.Instance.RegisterFilter(TKXAuthorizationFilter.Create);

end.
