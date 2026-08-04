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
///  Opt-in REST/JSON API for a KittoX application. Exposes the same views used
///  by the HTML/HTMX GUI as a parallel tree under /api/v4/{ViewName} with real
///  HTTP verbs, sharing the CRUD service layer (Kitto.Web.Data.Service) — same
///  model, same business rules, same ACL as the GUI.
///
///  This unit is NOT part of the core umbrella (Kitto.Html.All): an application
///  enables the REST API by adding it to its UseKitto.pas, exactly as it opts
///  into Kitto.Web.Enterprise. It depends only on the RTL System.JSON (no
///  third-party JSON framework); delphi-neon support (typed DTOs, OpenAPI) is a
///  separate opt-in unit added later.
///
///  Endpoints (base path /api/v4/{ViewName}), all exempt from the navigation
///  guard ([TKXNavigable] — a REST client does not send X-KittoX):
///    GET    /api/v4/{V}        list        -> { "data": [...], "total": N }
///    GET    /api/v4/{V}/{id}   read one     -> { ... } | 404
///    POST   /api/v4/{V}        create       -> 201 + created record
///    PUT    /api/v4/{V}/{id}   full update  -> 200 + updated record
///    PATCH  /api/v4/{V}/{id}   partial upd. -> 200 + updated record
///    DELETE /api/v4/{V}/{id}   delete       -> 204
///
///  Errors on /api are rendered as a JSON envelope { error, code, field? } with
///  a real HTTP status (see TKXApiErrorFilter). See KittoX_RestServer.md.
/// </summary>
unit Kitto.Web.Rest;

{$I Kitto.Defines.inc}

interface

uses
  System.SysUtils,
  Kitto.Metadata.DataView,
  Kitto.Web.Routing.Attributes,
  Kitto.Web.Routing.Filters;

type
  /// <summary>
  ///  Serialization seam between the REST handler and a concrete JSON provider.
  ///  The default provider uses System.JSON; a Neon-based provider can replace
  ///  it via SetKXApiSerializer. The serializer is PURE — it never fires business
  ///  rules (those run in the service layer); ParseInto only maps JSON to record
  ///  field values.
  /// </summary>
  IKXApiSerializer = interface
    ['{A5C8E2F1-3D4B-4E6A-9C1F-7B2D8E0A4C55}']
    /// <summary>Serializes a store page as a JSON list envelope { "data": [...], "total": N }.</summary>
    function SerializeStore(const AStore: TKViewTableStore; const ATotal: Integer): string;
    /// <summary>Serializes a single record as a JSON object.</summary>
    function SerializeRecord(const ARecord: TKViewTableRecord): string;
    /// <summary>Parses a JSON object body and applies its members to the record's
    /// fields (through TKXDataService.ApplyFieldValue). No business rules here.</summary>
    procedure ParseInto(const AJSON: string; const ARecord: TKViewTableRecord;
      const AIsInsert: Boolean);
  end;

  /// <summary>Default serializer built on the RTL System.JSON DOM (correct escaping, zero deps).</summary>
  TKXSystemJSONSerializer = class(TInterfacedObject, IKXApiSerializer)
  public
    /// <summary>Serializes a store page as a JSON list envelope { "data": [...], "total": N }.</summary>
    function SerializeStore(const AStore: TKViewTableStore; const ATotal: Integer): string;
    /// <summary>Serializes a single record as a JSON object.</summary>
    function SerializeRecord(const ARecord: TKViewTableRecord): string;
    /// <summary>Parses a JSON object body and applies its members to the record's
    /// fields (via TKXDataService.ApplyFieldValue); unknown members are ignored.</summary>
    procedure ParseInto(const AJSON: string; const ARecord: TKViewTableRecord;
      const AIsInsert: Boolean);
  end;

  {$RTTI EXPLICIT METHODS([vcPublic, vcPublished]) PROPERTIES([vcPublic, vcPublished])}
  /// <summary>
  ///  REST API handler for a data view. All endpoints are virtual so an
  ///  application can subclass and RegisterOverride to customize a single verb.
  /// </summary>
  [TKXPath('{apibase}/{ViewName}')]
  TKXApiHandlerBase = class
  public
    /// <summary>GET list: envelope { data, total } with ?start=&limit=&sort=&dir=.</summary>
    [TKXGET] [TKXNavigable]
    procedure GetList([TKXPathParam('ViewName')] const AViewName: string); virtual;
    /// <summary>GET one record by key (404 if absent).</summary>
    [TKXPath('/{id}')] [TKXGET] [TKXNavigable]
    procedure GetItem([TKXPathParam('ViewName')] const AViewName: string;
      [TKXPathParam('id')] const AId: string); virtual;
    /// <summary>POST create: body = JSON record; 201 + created record.</summary>
    [TKXPOST] [TKXNavigable]
    procedure PostItem([TKXPathParam('ViewName')] const AViewName: string); virtual;
    /// <summary>PUT full update: 200 + updated record.</summary>
    [TKXPath('/{id}')] [TKXPUT] [TKXNavigable]
    procedure PutItem([TKXPathParam('ViewName')] const AViewName: string;
      [TKXPathParam('id')] const AId: string); virtual;
    /// <summary>PATCH partial update (only the fields present in the body): 200 + updated record.</summary>
    [TKXPath('/{id}')] [TKXPATCH] [TKXNavigable]
    procedure PatchItem([TKXPathParam('ViewName')] const AViewName: string;
      [TKXPathParam('id')] const AId: string); virtual;
    /// <summary>DELETE by key: 204.</summary>
    [TKXPath('/{id}')] [TKXDELETE] [TKXNavigable]
    procedure DeleteItem([TKXPathParam('ViewName')] const AViewName: string;
      [TKXPathParam('id')] const AId: string); virtual;
  end;

  {$RTTI EXPLICIT METHODS([vcPublic, vcPublished]) PROPERTIES([vcPublic, vcPublished])}
  /// <summary>
  ///  Token endpoint for stateless REST clients. POST /api/v4/token with a JSON
  ///  body { "username", "password", "database"? } authenticates via the app's
  ///  authenticator and returns a Bearer JWT: { "token_type":"Bearer",
  ///  "access_token":"<jwt>" }. Anonymous (no token needed to obtain one).
  ///  Requires Auth: JWT (the only authenticator that issues tokens).
  /// </summary>
  [TKXPath('{apibase}/token')]
  TKXApiAuthHandler = class
  public
    /// <summary>Authenticates the JSON body {username,password,database?} and
    /// returns a Bearer JWT; 401 on invalid credentials.</summary>
    [TKXPOST] [TKXAnonymous]
    procedure PostToken; virtual;
  end;

  {$RTTI EXPLICIT METHODS([vcPublic, vcPublished]) PROPERTIES([vcPublic, vcPublished])}
  /// <summary>
  ///  Matches the CORS preflight (`OPTIONS`) on the two `/api/v4` path shapes so the
  ///  request enters the filter chain, where TKXCorsFilter answers it. If CORS is
  ///  disabled (or the origin is not allowed) the filter does nothing and these
  ///  no-op methods return a bare 204. Anonymous: a preflight carries no credentials.
  /// </summary>
  [TKXPath('{apibase}/{ViewName}')]
  TKXApiCorsHandler = class
  public
    /// <summary>CORS preflight for the collection path /api/v4/{ViewName}.</summary>
    [TKXOPTIONS] [TKXAnonymous]
    procedure PreflightCollection([TKXPathParam('ViewName')] const AViewName: string); virtual;
    /// <summary>CORS preflight for the item path /api/v4/{ViewName}/{id}.</summary>
    [TKXPath('/{id}')] [TKXOPTIONS] [TKXAnonymous]
    procedure PreflightItem([TKXPathParam('ViewName')] const AViewName: string;
      [TKXPathParam('id')] const AId: string); virtual;
  end;

  /// <summary>
  ///  Adds CORS headers to `/api/v4` responses and answers the preflight, when the
  ///  request's Origin is allowed by `Server/CORS/AllowedOrigins` in Config.yaml
  ///  ('*' or a comma-separated list; empty = CORS disabled). Optional
  ///  `Server/CORS/AllowCredentials: True` emits Access-Control-Allow-Credentials.
  /// </summary>
  TKXCorsFilter = class(TInterfacedObject, IKXRequestFilter)
  public
    /// <summary>For an allowed cross-origin /api request, emits the CORS response
    /// headers and, on an OPTIONS preflight, answers 204 and short-circuits the chain.</summary>
    procedure BeforeInvoke(const AContext: IKXRequestContext);
    /// <summary>No-op.</summary>
    procedure AfterInvoke(const AContext: IKXRequestContext);
    /// <summary>Does not handle exceptions (always returns False).</summary>
    function OnException(const AContext: IKXRequestContext; E: Exception): Boolean;
  end;

  /// <summary>
  ///  Renders any exception escaping an /api/v4 request as a JSON error envelope
  ///  { error, code, field? } with a real HTTP status (EKXDataError carries its
  ///  own; rule/validation errors map to 422; anything else to 500). Registered
  ///  after the core filters so its OnException runs first: for /api it wins, for
  ///  every other path it returns False and the HTML error dialog handles it.
  /// </summary>
  TKXApiErrorFilter = class(TInterfacedObject, IKXRequestFilter)
  public
    /// <summary>No-op.</summary>
    procedure BeforeInvoke(const AContext: IKXRequestContext);
    /// <summary>No-op.</summary>
    procedure AfterInvoke(const AContext: IKXRequestContext);
    /// <summary>For an /api request, renders E as a JSON error envelope { error, code, field? }
    /// with a real HTTP status and returns True; returns False for any other path.</summary>
    function OnException(const AContext: IKXRequestContext; E: Exception): Boolean;
  end;

/// <summary>The active API serializer (lazily defaults to TKXSystemJSONSerializer).</summary>
function KXApiSerializer: IKXApiSerializer;
/// <summary>Overrides the active API serializer (e.g. a Neon-based one).</summary>
procedure SetKXApiSerializer(const AValue: IKXApiSerializer);

implementation

uses
  System.Classes,
  System.StrUtils,
  System.JSON,
  EF.Tree,
  Kitto.Config,
  Kitto.Store,
  Kitto.Rules,
  Kitto.Metadata.Views,
  Kitto.Html.Filters,
  Kitto.Web.Request,
  Kitto.Web.Response,
  Kitto.Web.Session,
  Kitto.Web.Application,
  Kitto.Auth.JWT,
  Kitto.Web.Routing.Registry,
  Kitto.Web.Data.Service,
  Kitto.Web.Rest.OpenAPI;   // pulls in + registers the /api/v4/openapi.json handler

var
  FSerializer: IKXApiSerializer;

function KXApiSerializer: IKXApiSerializer;
begin
  if not Assigned(FSerializer) then
    FSerializer := TKXSystemJSONSerializer.Create;
  Result := FSerializer;
end;

procedure SetKXApiSerializer(const AValue: IKXApiSerializer);
begin
  FSerializer := AValue;
end;

procedure WriteJSONResponse(const AStatus: Integer; const AJSON: string);
begin
  TKWebResponse.Current.StatusCode := AStatus;
  TKWebResponse.Current.ContentType := 'application/json; charset=utf-8';
  TKWebResponse.Current.ReplaceContentStream(TStringStream.Create(AJSON, TEncoding.UTF8));
end;

{ TKXSystemJSONSerializer }

function BuildRecordObject(const ARecord: TKViewTableRecord): TJSONObject;
var
  I: Integer;
  LField: TKField;
  LRaw: string;
begin
  Result := TJSONObject.Create;
  try
    for I := 0 to ARecord.FieldCount - 1 do
    begin
      LField := ARecord.Fields[I];
      if not LField.DataType.SupportsJSON then
        Continue;
      if LField.IsNull then
        Result.AddPair(LField.FieldName, TJSONNull.Create)
      else if LField.DataType.IsBoolean then
        Result.AddPair(LField.FieldName, TJSONBool.Create(LField.AsBoolean))
      else
      begin
        // Unquoted raw value in the JS convention (correct number/date formatting);
        // wrap ourselves so System.JSON handles string escaping correctly.
        LRaw := LField.GetAsJSONValue(False, False, False);
        if LField.DataType.NeedsQuotes then
          Result.AddPair(LField.FieldName, TJSONString.Create(LRaw))
        else
          Result.AddPair(LField.FieldName, TJSONNumber.Create(LRaw));
      end;
    end;
  except
    Result.Free;
    raise;
  end;
end;

function TKXSystemJSONSerializer.SerializeStore(const AStore: TKViewTableStore;
  const ATotal: Integer): string;
var
  LRoot: TJSONObject;
  LArray: TJSONArray;
  I: Integer;
begin
  LRoot := TJSONObject.Create;
  try
    LArray := TJSONArray.Create;
    LRoot.AddPair('data', LArray);
    for I := 0 to AStore.RecordCount - 1 do
      LArray.AddElement(BuildRecordObject(AStore.Records[I]));
    LRoot.AddPair('total', TJSONNumber.Create(ATotal));
    Result := LRoot.ToJSON;
  finally
    LRoot.Free;
  end;
end;

function TKXSystemJSONSerializer.SerializeRecord(const ARecord: TKViewTableRecord): string;
var
  LObj: TJSONObject;
begin
  LObj := BuildRecordObject(ARecord);
  try
    Result := LObj.ToJSON;
  finally
    LObj.Free;
  end;
end;

procedure TKXSystemJSONSerializer.ParseInto(const AJSON: string;
  const ARecord: TKViewTableRecord; const AIsInsert: Boolean);
var
  LRoot: TJSONValue;
  LPair: TJSONPair;
  LName, LStr: string;
  LValue: TJSONValue;
  LField: TKViewTableField;
begin
  LRoot := TJSONObject.ParseJSONValue(AJSON);
  if not (LRoot is TJSONObject) then
  begin
    LRoot.Free;
    raise EKXDataError.Create(400, 'bad_json', 'Request body must be a JSON object');
  end;
  try
    for LPair in TJSONObject(LRoot) do
    begin
      LName := LPair.JsonString.Value;
      LField := ARecord.FindField(LName);
      if not Assigned(LField) then
        Continue; // unknown field: ignore (forward-compatible)
      LValue := LPair.JsonValue;
      if LValue is TJSONNull then
        LStr := 'null'
      else if LValue is TJSONBool then
        LStr := IfThen(TJSONBool(LValue).AsBoolean, 'true', 'false')
      else if LValue is TJSONString then
        LStr := TJSONString(LValue).Value
      else
        LStr := LValue.Value; // number: literal text
      TKXDataService.ApplyFieldValue(ARecord, LField.ViewField, LStr, AIsInsert,
        True, TKConfig.JSFormatSettings);
    end;
  finally
    LRoot.Free;
  end;
end;

{ TKXApiHandlerBase }

procedure TKXApiHandlerBase.GetList(const AViewName: string);
var
  LStore: TKViewTableStore;
  LStart, LLimit, LTotal: Integer;
  LSort, LDir, LFilterExpr: string;
  LView: TKView;
  LControllerNode, LItemsNode: TEFNode;
begin
  LStart := StrToIntDef(TKWebRequest.Current.GetField('start'), 0);
  LLimit := StrToIntDef(TKWebRequest.Current.GetField('limit'), 0);
  LSort := TKWebRequest.Current.GetField('sort');
  LDir := TKWebRequest.Current.GetField('dir');

  // Build the filter expression from the view's configured Filters/Items using
  // the ?f_<n>= query params — same mechanism as the GUI list (HandleData), so
  // the client supplies only VALUES mapped through the view's ExpressionTemplates
  // (escaped) — never raw SQL. Unknown view → left empty; LoadList raises 404.
  LFilterExpr := '';
  LView := TKWebApplication.Current.Config.Views.FindView(AViewName);
  if Assigned(LView) then
  begin
    LControllerNode := LView.FindNode('Controller');
    if Assigned(LControllerNode) then
    begin
      LItemsNode := LControllerNode.FindNode('Filters/Items');
      if Assigned(LItemsNode) then
        LFilterExpr := BuildFilterExpression(LItemsNode,
          LControllerNode.GetString('Filters/Connector', 'and'),
          function(AIndex: Integer): string
          begin
            Result := TKWebRequest.Current.GetField('f_' + IntToStr(AIndex));
          end);
    end;
  end;

  LStore := TKXDataService.LoadList(AViewName, LFilterExpr, LSort, LDir, LStart, LLimit, LTotal);
  try
    WriteJSONResponse(200, KXApiSerializer.SerializeStore(LStore, LTotal));
  finally
    FreeAndNil(LStore);
  end;
end;

procedure TKXApiHandlerBase.GetItem(const AViewName, AId: string);
var
  LStore: TKViewTableStore;
  LRecord: TKViewTableRecord;
begin
  LRecord := TKXDataService.LoadRecord(AViewName, AId, LStore);
  try
    WriteJSONResponse(200, KXApiSerializer.SerializeRecord(LRecord));
  finally
    FreeAndNil(LStore);
  end;
end;

procedure TKXApiHandlerBase.PostItem(const AViewName: string);
var
  LStore: TKViewTableStore;
  LRecord: TKViewTableRecord;
  LBody: string;
begin
  LBody := TKWebRequest.Current.Content;
  LRecord := TKXDataService.CreateRecord(AViewName,
    procedure(const ARecord: TKViewTableRecord)
    begin
      KXApiSerializer.ParseInto(LBody, ARecord, True);
    end,
    nil, nil, LStore);
  try
    WriteJSONResponse(201, KXApiSerializer.SerializeRecord(LRecord));
  finally
    FreeAndNil(LStore);
  end;
end;

procedure TKXApiHandlerBase.PutItem(const AViewName, AId: string);
var
  LStore: TKViewTableStore;
  LRecord: TKViewTableRecord;
  LBody: string;
begin
  LBody := TKWebRequest.Current.Content;
  LRecord := TKXDataService.UpdateRecord(AViewName, AId,
    procedure(const ARecord: TKViewTableRecord)
    begin
      KXApiSerializer.ParseInto(LBody, ARecord, False);
    end,
    nil, nil, LStore);
  try
    WriteJSONResponse(200, KXApiSerializer.SerializeRecord(LRecord));
  finally
    FreeAndNil(LStore);
  end;
end;

procedure TKXApiHandlerBase.PatchItem(const AViewName, AId: string);
begin
  // Partial update: ParseInto only touches the fields present in the body
  // (ApplyFieldValue is skipped for absent members), so PATCH and PUT share the
  // same update path — the difference is purely which members the body carries.
  PutItem(AViewName, AId);
end;

procedure TKXApiHandlerBase.DeleteItem(const AViewName, AId: string);
begin
  TKXDataService.DeleteRecord(AViewName, AId, nil, nil);
  WriteJSONResponse(204, '');
end;

{ TKXApiAuthHandler }

procedure TKXApiAuthHandler.PostToken;
var
  LApp: TKWebApplication;
  LRoot: TJSONValue;
  LObj: TJSONObject;
  LAuthData: TEFNode;
  LUser, LPass, LDb, LToken, LCT: string;
  LVal: TJSONValue;

  function JStr(const AName: string): string;
  begin
    LVal := LObj.GetValue(AName);
    if Assigned(LVal) then Result := LVal.Value else Result := '';
  end;

begin
  LApp := TKWebApplication.Current;

  // Accept both encodings, keyed off the Content-Type (NOT ContentFields.Count:
  // the WebBroker RTL fills ContentFields even for a JSON body). A urlencoded/
  // multipart submit — the Swagger UI form, which renders individual fields, and
  // the OAuth2-standard token-endpoint encoding — is read from the form fields;
  // anything else is parsed as a JSON object.
  LCT := LowerCase(TKWebRequest.Current.ContentType);
  if (Pos('x-www-form-urlencoded', LCT) > 0) or (Pos('multipart/form-data', LCT) > 0) then
  begin
    LUser := TKWebRequest.Current.GetFormField('username');
    LPass := TKWebRequest.Current.GetFormField('password');
    LDb := TKWebRequest.Current.GetFormField('database');
  end
  else
  begin
    LRoot := TJSONObject.ParseJSONValue(TKWebRequest.Current.Content);
    if not (LRoot is TJSONObject) then
    begin
      LRoot.Free;
      raise EKXDataError.Create(400, 'bad_json',
        'Request body must be a JSON object or url-encoded form');
    end;
    try
      LObj := TJSONObject(LRoot);
      LUser := JStr('username');
      LPass := JStr('password');
      LDb := JStr('database');
    finally
      LRoot.Free;
    end;
  end;

  // A caller-supplied database name must be a real one
  // (Databases/<Name>/Connection in Config.yaml); otherwise the auth query below
  // fails deep in the DB layer with an opaque 500 ("Nodo Databases/<X>/Connection
  // non trovato"). Reject it up front with a clean 400 instead.
  if (LDb <> '') and
     not Assigned(LApp.Config.Config.FindNode('Databases/' + LDb + '/Connection')) then
    raise EKXDataError.Create(400, 'unknown_database',
      Format('Unknown database "%s"', [LDb]));

  // Route the auth query to the chosen database (multi-DB apps), then harden the
  // session id, exactly like the interactive login (TKXAuthHandlerBase.HandleLogin).
  if LDb <> '' then
    TKWebSession.Current.DatabaseName := LDb;
  TKWebSession.Current.RegenerateId;

  LAuthData := TEFNode.Create;
  try
    LApp.Authenticator.DefineAuthData(LAuthData);
    LAuthData.SetString('UserName', LUser);
    LAuthData.SetString('Password', LPass);
    if not LApp.Authenticator.Authenticate(LAuthData) then
      raise EKXDataError.Create(401, 'invalid_login', 'Invalid username or password');
  finally
    LAuthData.Free;
  end;

  if not (LApp.Authenticator is TKJWTAuthenticator) then
    raise EKXDataError.Create(501, 'jwt_required',
      'Bearer tokens require the JWT authenticator (Auth: JWT)');
  // Build/sign the compact JWT from the now-authenticated session (its sid claim
  // correlates the server session the token hydrates on later requests).
  LToken := TKJWTAuthenticator(LApp.Authenticator).IssueToken;

  LObj := TJSONObject.Create;
  try
    LObj.AddPair('token_type', 'Bearer');
    LObj.AddPair('access_token', LToken);
    WriteJSONResponse(200, LObj.ToJSON);
  finally
    LObj.Free;
  end;
end;

{ TKXApiCorsHandler }

procedure TKXApiCorsHandler.PreflightCollection(const AViewName: string);
begin
  // Reached only when TKXCorsFilter did NOT handle the preflight (CORS disabled
  // or origin not allowed): answer a bare 204 with no CORS headers.
  TKWebResponse.Current.StatusCode := 204;
end;

procedure TKXApiCorsHandler.PreflightItem(const AViewName, AId: string);
begin
  TKWebResponse.Current.StatusCode := 204;
end;

{ TKXCorsFilter }

function CorsOriginAllowed(const AAllowed, AOrigin: string): Boolean;
var
  LParts: TArray<string>;
  I: Integer;
begin
  if Trim(AAllowed) = '*' then
    Exit(True);
  LParts := AAllowed.Split([',']);
  for I := 0 to High(LParts) do
    if SameText(Trim(LParts[I]), AOrigin) then
      Exit(True);
  Result := False;
end;

procedure TKXCorsFilter.BeforeInvoke(const AContext: IKXRequestContext);
var
  LOrigin, LAllowed, LReqHeaders: string;
  LCfg: TEFTree;
  LResp: TKWebResponse;
begin
  if not ContainsText(AContext.Path, TKWebApplication.Current.Config.RestBasePath) then
    Exit;
  LOrigin := TKWebRequest.Current.GetHeaderField('Origin');
  if LOrigin = '' then
    Exit; // not a cross-origin browser request
  LCfg := TKWebApplication.Current.Config.Config;
  LAllowed := LCfg.GetExpandedString('Server/CORS/AllowedOrigins', '');
  if LAllowed = '' then
    Exit; // CORS not configured → disabled
  if not CorsOriginAllowed(LAllowed, LOrigin) then
    Exit; // origin not allowed → no CORS headers (browser will block)

  LResp := TKWebResponse.Current;
  if not Assigned(LResp) then
    Exit;
  // Echo the specific origin (required with credentials, harmless otherwise).
  LResp.SetCustomHeader('Access-Control-Allow-Origin', LOrigin);
  LResp.SetCustomHeader('Vary', 'Origin');
  if LCfg.GetBoolean('Server/CORS/AllowCredentials') then
    LResp.SetCustomHeader('Access-Control-Allow-Credentials', 'true');

  if SameText(AContext.HttpMethod, 'OPTIONS') then
  begin
    LResp.SetCustomHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, PATCH, DELETE, OPTIONS');
    LReqHeaders := TKWebRequest.Current.GetHeaderField('Access-Control-Request-Headers');
    if LReqHeaders = '' then
      LReqHeaders := 'Authorization, Content-Type';
    LResp.SetCustomHeader('Access-Control-Allow-Headers', LReqHeaders);
    LResp.SetCustomHeader('Access-Control-Max-Age', '600');
    LResp.StatusCode := 204;
    AContext.Handled := True; // short-circuit: preflight fully answered
  end;
end;

procedure TKXCorsFilter.AfterInvoke(const AContext: IKXRequestContext);
begin
end;

function TKXCorsFilter.OnException(const AContext: IKXRequestContext;
  E: Exception): Boolean;
begin
  Result := False;
end;

{ TKXApiErrorFilter }

procedure TKXApiErrorFilter.BeforeInvoke(const AContext: IKXRequestContext);
begin
end;

procedure TKXApiErrorFilter.AfterInvoke(const AContext: IKXRequestContext);
begin
end;

function TKXApiErrorFilter.OnException(const AContext: IKXRequestContext;
  E: Exception): Boolean;
var
  LStatus: Integer;
  LCode, LField: string;
  LObj: TJSONObject;
begin
  // Only handle REST requests; every other path falls through to the HTML error
  // dialog filter (this filter runs first in the reverse OnException walk).
  if not ContainsText(AContext.Path, TKWebApplication.Current.Config.RestBasePath) then
    Exit(False);

  LField := '';
  if E is EKXDataError then
  begin
    LStatus := EKXDataError(E).HTTPStatus;
    LCode := EKXDataError(E).Code;
    LField := EKXDataError(E).FieldName;
  end
  else if E is EKRuleError then // includes EKValidationError
  begin
    LStatus := 422;
    LCode := 'validation';
  end
  else
  begin
    LStatus := 500;
    LCode := 'internal_error';
  end;

  LObj := TJSONObject.Create;
  try
    LObj.AddPair('error', E.Message);
    LObj.AddPair('code', LCode);
    if LField <> '' then
      LObj.AddPair('field', LField);
    WriteJSONResponse(LStatus, LObj.ToJSON);
  finally
    LObj.Free;
  end;
  Result := True;
end;

initialization
  TKXResourceRegistry.Instance.RegisterResource(TKXApiHandlerBase);
  TKXResourceRegistry.Instance.RegisterResource(TKXApiAuthHandler);
  TKXResourceRegistry.Instance.RegisterResource(TKXApiCorsHandler);
  // Registered after the core filters (this unit initializes later): its
  // OnException is walked first, so it claims /api errors before the HTML dialog.
  // Fully qualified: Kitto.Html.Filters (used for BuildFilterExpression) also
  // declares a TKXFilterRegistry (the List filter-class registry) that would
  // otherwise shadow the request-filter one here.
  Kitto.Web.Routing.Filters.TKXFilterRegistry.Instance.RegisterFilter(TKXApiErrorFilter.Create);
  // CORS last: its BeforeInvoke runs after the auth gate, adding the CORS headers
  // to the (authenticated) response and answering the preflight OPTIONS.
  Kitto.Web.Routing.Filters.TKXFilterRegistry.Instance.RegisterFilter(TKXCorsFilter.Create);

end.
