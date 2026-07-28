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
///  OpenAPI 3.0 description of the REST API (see Kitto.Web.Rest), generated at
///  runtime from the application's metadata catalog (Models/Views) — NOT from
///  Delphi DTO types, so no delphi-neon or typed-DTO layer is needed: the spec
///  is built with the RTL System.JSON by walking the TKViewField metadata, the
///  same source the serializer uses. Served (anonymously) at
///  GET /api/v4/openapi.json; point any OpenAPI tool (Swagger UI, Postman,
///  openapi-generator) at it. Part of the opt-in REST umbrella.
/// </summary>
unit Kitto.Web.Rest.OpenAPI;

{$I Kitto.Defines.inc}

interface

uses
  System.JSON,
  Kitto.Web.Routing.Attributes;

type
  /// <summary>Builds the OpenAPI 3.0 document for the current application's REST API.</summary>
  TKXOpenAPIBuilder = class
  public
    /// <summary>Returns the OpenAPI document (caller owns and frees it). ARestBaseUrl is
    /// the server base the paths hang off (e.g. '/myapp/api/v4').</summary>
    class function Build(const ARestBaseUrl: string): TJSONObject; static;
  end;

  {$RTTI EXPLICIT METHODS([vcPublic, vcPublished]) PROPERTIES([vcPublic, vcPublished])}
  /// <summary>Serves the OpenAPI document at GET /api/v4/openapi.json (anonymous).</summary>
  [TKXPath('{apibase}/openapi.json')]
  TKXApiDocHandler = class
  public
    /// <summary>Emits the OpenAPI 3.0 JSON describing every REST-exposed data view.</summary>
    [TKXGET] [TKXAnonymous]
    procedure GetOpenAPI; virtual;
  end;

  {$RTTI EXPLICIT METHODS([vcPublic, vcPublished]) PROPERTIES([vcPublic, vcPublished])}
  /// <summary>
  ///  Serves an interactive Swagger UI page at GET /api/v4/docs (anonymous). The
  ///  page loads the vendored swagger-ui assets from /res and points them at
  ///  /api/v4/openapi.json. Try-it-out calls need a token: click "Authorize" and
  ///  paste the JWT obtained from POST /api/v4/token.
  /// </summary>
  [TKXPath('{apibase}/docs')]
  TKXApiSwaggerHandler = class
  public
    /// <summary>Emits the Swagger UI HTML page for the API.</summary>
    [TKXGET] [TKXAnonymous]
    procedure GetSwaggerUI; virtual;
  end;

implementation

uses
  System.SysUtils,
  System.Classes,
  System.NetEncoding,
  EF.Types,
  EF.Tree,
  EF.Localization,
  EF.Logger,
  Kitto.Metadata.Views,
  Kitto.Metadata.DataView,
  Kitto.Metadata.Models,
  Kitto.Web.Response,
  Kitto.Web.Data.Service,
  Kitto.Config,
  Kitto.Web.Application,
  Kitto.Web.Routing.Registry;

{ TKXOpenAPIBuilder }

function FieldSchema(const AField: TKViewField): TJSONObject;
var
  LDT: TEFDataType;
  LPairs: TEFPairs;
  LEnum: TJSONArray;
  I: Integer;
begin
  Result := TJSONObject.Create;
  LDT := AField.DataType;
  if LDT.IsBoolean then
    Result.AddPair('type', 'boolean')
  else if LDT is TEFIntegerDataType then
    Result.AddPair('type', 'integer')
  else if LDT is TEFDecimalNumericDataTypeBase then
    Result.AddPair('type', 'number')
  else if LDT is TEFDateDataType then
  begin
    Result.AddPair('type', 'string');
    Result.AddPair('format', 'date');
  end
  else if LDT is TEFDateTimeDataType then
  begin
    Result.AddPair('type', 'string');
    Result.AddPair('format', 'date-time');
  end
  else if LDT is TEFTimeDataType then
  begin
    Result.AddPair('type', 'string');
    Result.AddPair('format', 'time');
  end
  else
  begin
    Result.AddPair('type', 'string');
    if AField.Size > 0 then
      Result.AddPair('maxLength', TJSONNumber.Create(AField.Size));
  end;

  // Constrained values become an enum. Guarded: AllowedValues may reach into the
  // model field, which some view fields (e.g. expression fields) do not have.
  try
    LPairs := AField.AllowedValues;
  except
    LPairs := nil;
  end;
  if Length(LPairs) > 0 then
  begin
    LEnum := TJSONArray.Create;
    for I := Low(LPairs) to High(LPairs) do
      LEnum.Add(LPairs[I].Key);
    Result.AddPair('enum', LEnum);
  end;

  if not AField.IsRequired then
    Result.AddPair('nullable', TJSONBool.Create(True));
  // A key or a non-writable field is read-only from the client's point of view.
  if AField.IsKey or (not AField.CanInsert and not AField.CanUpdate) then
    Result.AddPair('readOnly', TJSONBool.Create(True));
  if AField.DisplayLabel <> '' then
    Result.AddPair('description', AField.DisplayLabel);
end;

function ViewSchema(const AViewTable: TKViewTable): TJSONObject;
var
  I: Integer;
  LField: TKViewField;
  LProps: TJSONObject;
  LRequired: TJSONArray;
begin
  Result := TJSONObject.Create;
  Result.AddPair('type', 'object');
  LProps := TJSONObject.Create;
  Result.AddPair('properties', LProps);
  LRequired := TJSONArray.Create;
  for I := 0 to AViewTable.FieldCount - 1 do
  begin
    LField := AViewTable.Fields[I];
    if not LField.DataType.SupportsJSON then
      Continue; // blobs are served via the blob endpoint, not inline
    LProps.AddPair(LField.AliasedName, FieldSchema(LField));
    if LField.IsRequired then
      LRequired.Add(LField.AliasedName);
  end;
  if LRequired.Count > 0 then
    Result.AddPair('required', LRequired)
  else
    LRequired.Free;
end;

// A $ref to a component schema.
function RefTo(const ASchemaName: string): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('$ref', '#/components/schemas/' + ASchemaName);
end;

// { "$ref": ... } wrapped as an application/json response/body content object.
function JsonContent(const ASchema: TJSONValue): TJSONObject;
var
  LMedia: TJSONObject;
begin
  LMedia := TJSONObject.Create;
  LMedia.AddPair('schema', ASchema);
  Result := TJSONObject.Create;
  Result.AddPair('application/json', LMedia);
end;

function ResponseObj(const ADescription: string; const ASchema: TJSONValue): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('description', ADescription);
  if Assigned(ASchema) then
    Result.AddPair('content', JsonContent(ASchema));
end;

function QueryParam(const AName, ADescription, AType: string): TJSONObject;
var
  LSchema: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('name', AName);
  Result.AddPair('in', 'query');
  Result.AddPair('description', ADescription);
  LSchema := TJSONObject.Create;
  LSchema.AddPair('type', AType);
  Result.AddPair('schema', LSchema);
end;

class function TKXOpenAPIBuilder.Build(const ARestBaseUrl: string): TJSONObject;
var
  LApp: TKWebApplication;
  LViews: TKViews;
  I: Integer;
  LView: TKView;
  LVT: TKViewTable;
  LName: string;
  LPaths, LSchemas, LComponents, LInfo, LServer, LSec: TJSONObject;
  LServersArr, LSecReq: TJSONArray;
  LAutoViews: TArray<TKXAutoViewInfo>;
  LAuto: TKXAutoViewInfo;

  procedure AddResponses(const AOp: TJSONObject; const AOkDesc: string;
    const AOkSchema: TJSONValue);
  var
    LResponses: TJSONObject;
  begin
    LResponses := TJSONObject.Create;
    if Assigned(AOkSchema) then
      LResponses.AddPair('200', ResponseObj(AOkDesc, AOkSchema))
    else
      LResponses.AddPair('204', ResponseObj(AOkDesc, nil));
    LResponses.AddPair('401', ResponseObj('Unauthorized', nil));
    LResponses.AddPair('403', ResponseObj('Forbidden (ACL)', nil));
    LResponses.AddPair('404', ResponseObj('Not found', nil));
    LResponses.AddPair('422', ResponseObj('Validation / business-rule error', nil));
    AOp.AddPair('responses', LResponses);
  end;

  function IdParam: TJSONObject;
  var
    LSchema: TJSONObject;
  begin
    Result := TJSONObject.Create;
    Result.AddPair('name', 'id');
    Result.AddPair('in', 'path');
    Result.AddPair('required', TJSONBool.Create(True));
    Result.AddPair('description', 'Record key (single PK value, or field=val&field2=val2 for composite keys)');
    LSchema := TJSONObject.Create;
    LSchema.AddPair('type', 'string');
    Result.AddPair('schema', LSchema);
  end;

  procedure BuildViewPaths(const AViewName: string; const AVT: TKViewTable);
  var
    LCollPath, LItemPath, LOp, LListSchema, LDataArr, LEnvProps: TJSONObject;
    LListParams, LItemParams: TJSONArray;
    LModel: TKModel;
    LReadOnly: Boolean;
  begin
    LModel := AVT.Model;
    LReadOnly := LModel.IsReadOnly;

    // ---- Collection path  /{View} ----
    LCollPath := TJSONObject.Create;

    // GET list
    LOp := TJSONObject.Create;
    LOp.AddPair('summary', 'List ' + AViewName);
    // operationId (unique, no whitespace): drives Swagger UI deep-links and is
    // used by OpenAPI client generators. Without it Swagger derives the anchor
    // from the summary (which has spaces) and warns about the '_' escaping.
    LOp.AddPair('operationId', 'list_' + AViewName);
    LListParams := TJSONArray.Create;
    LListParams.Add(QueryParam('start', 'Zero-based row offset (paging)', 'integer'));
    LListParams.Add(QueryParam('limit', 'Max rows to return (0 = all)', 'integer'));
    LListParams.Add(QueryParam('sort', 'Field name to sort by', 'string'));
    LListParams.Add(QueryParam('dir', 'Sort direction: asc | desc', 'string'));
    LOp.AddPair('parameters', LListParams);
    // envelope { data: [ $ref ], total: integer }
    LEnvProps := TJSONObject.Create;
    LDataArr := TJSONObject.Create;
    LDataArr.AddPair('type', 'array');
    LDataArr.AddPair('items', RefTo(AViewName));
    LEnvProps.AddPair('data', LDataArr);
    LEnvProps.AddPair('total', TJSONObject.Create.AddPair('type', 'integer') as TJSONObject);
    LListSchema := TJSONObject.Create;
    LListSchema.AddPair('type', 'object');
    LListSchema.AddPair('properties', LEnvProps);
    AddResponses(LOp, 'A page of records', LListSchema);
    LCollPath.AddPair('get', LOp);

    // POST create
    if not LReadOnly and not LModel.PreventAdding then
    begin
      LOp := TJSONObject.Create;
      LOp.AddPair('summary', 'Create a ' + AViewName + ' record');
      LOp.AddPair('operationId', 'create_' + AViewName);
      LOp.AddPair('requestBody', TJSONObject.Create.AddPair('content', JsonContent(RefTo(AViewName))) as TJSONObject);
      AddResponses(LOp, 'The created record', RefTo(AViewName));
      LCollPath.AddPair('post', LOp);
    end;

    // Path keys are RELATIVE to servers.url (= the REST base): OpenAPI resolves
    // the final URL as servers.url + path key. Prefixing the base here too would
    // double it (…/api/v4/api/v4/…).
    LPaths.AddPair('/' + AViewName, LCollPath);

    // ---- Item path  /{View}/{id} ----
    LItemPath := TJSONObject.Create;
    LItemParams := TJSONArray.Create;
    LItemParams.Add(IdParam);
    LItemPath.AddPair('parameters', LItemParams);

    // GET one
    LOp := TJSONObject.Create;
    LOp.AddPair('summary', 'Read a ' + AViewName + ' record by key');
    LOp.AddPair('operationId', 'get_' + AViewName);
    AddResponses(LOp, 'The record', RefTo(AViewName));
    LItemPath.AddPair('get', LOp);

    // PUT / PATCH update
    if not LReadOnly and not LModel.PreventEditing then
    begin
      LOp := TJSONObject.Create;
      LOp.AddPair('summary', 'Full update');
      LOp.AddPair('operationId', 'update_' + AViewName);
      LOp.AddPair('requestBody', TJSONObject.Create.AddPair('content', JsonContent(RefTo(AViewName))) as TJSONObject);
      AddResponses(LOp, 'The updated record', RefTo(AViewName));
      LItemPath.AddPair('put', LOp);

      LOp := TJSONObject.Create;
      LOp.AddPair('summary', 'Partial update (only the fields in the body)');
      LOp.AddPair('operationId', 'patch_' + AViewName);
      LOp.AddPair('requestBody', TJSONObject.Create.AddPair('content', JsonContent(RefTo(AViewName))) as TJSONObject);
      AddResponses(LOp, 'The updated record', RefTo(AViewName));
      LItemPath.AddPair('patch', LOp);
    end;

    // DELETE
    if not LReadOnly and not LModel.PreventDeleting then
    begin
      LOp := TJSONObject.Create;
      LOp.AddPair('summary', 'Delete the record');
      LOp.AddPair('operationId', 'delete_' + AViewName);
      AddResponses(LOp, 'Deleted (no content)', nil);
      LItemPath.AddPair('delete', LOp);
    end;

    LPaths.AddPair('/' + AViewName + '/{id}', LItemPath);
  end;

  // POST {base}/token — the public authentication endpoint (TKXApiAuthHandler).
  // It is not a data view, so it is emitted explicitly here; otherwise Swagger UI
  // would offer no way to obtain the Bearer token that every other call needs.
  // 'security: []' overrides the global bearerAuth requirement (this call is the
  // one you make BEFORE having a token).
  procedure AddTokenPath;

    // A fresh copy of the credentials schema (JSON DOM nodes can't be shared
    // across media types — each AddPair takes ownership).
    function TokenBodySchema: TJSONObject;
    var
      LProps, LDb: TJSONObject;
      LReq: TJSONArray;
    begin
      LProps := TJSONObject.Create;
      LProps.AddPair('username', TJSONObject.Create.AddPair('type', 'string') as TJSONObject);
      LProps.AddPair('password', TJSONObject.Create.AddPair('type', 'string') as TJSONObject);
      LDb := TJSONObject.Create;
      LDb.AddPair('type', 'string');
      LDb.AddPair('description', 'Optional target database name (multi-DB apps); embedded in the token''s db claim');
      LProps.AddPair('database', LDb);
      LReq := TJSONArray.Create;
      LReq.Add('username');
      LReq.Add('password');
      Result := TJSONObject.Create;
      Result.AddPair('type', 'object');
      Result.AddPair('required', LReq);
      Result.AddPair('properties', LProps);
    end;

  var
    LOp, LReqBody, LContent, LRespSchema, LRespProps,
      LTokenResponses, LTokenPath: TJSONObject;
  begin
    LRespProps := TJSONObject.Create;
    LRespProps.AddPair('token_type', TJSONObject.Create.AddPair('type', 'string') as TJSONObject);
    LRespProps.AddPair('access_token', TJSONObject.Create.AddPair('type', 'string') as TJSONObject);
    LRespSchema := TJSONObject.Create;
    LRespSchema.AddPair('type', 'object');
    LRespSchema.AddPair('properties', LRespProps);

    // Two request media types. Form-urlencoded is listed FIRST so Swagger UI
    // renders individual username/password/database input fields by default
    // (it shows the raw-JSON editor only for application/json). The handler
    // accepts both. application/x-www-form-urlencoded is also the OAuth2-standard
    // token-endpoint encoding.
    LContent := TJSONObject.Create;
    LContent.AddPair('application/x-www-form-urlencoded',
      TJSONObject.Create.AddPair('schema', TokenBodySchema) as TJSONObject);
    LContent.AddPair('application/json',
      TJSONObject.Create.AddPair('schema', TokenBodySchema) as TJSONObject);

    LReqBody := TJSONObject.Create;
    LReqBody.AddPair('required', TJSONBool.Create(True));
    LReqBody.AddPair('content', LContent);

    LTokenResponses := TJSONObject.Create;
    LTokenResponses.AddPair('200', ResponseObj('The signed JWT (use access_token with "Authorize")', LRespSchema));
    LTokenResponses.AddPair('401', ResponseObj('Invalid username or password', nil));

    LOp := TJSONObject.Create;
    LOp.AddPair('summary', 'Obtain a Bearer token');
    LOp.AddPair('operationId', 'postToken');
    LOp.AddPair('description',
      'Authenticate with credentials and receive a JWT. Copy access_token, click ' +
      '"Authorize" at the top and paste it to call the protected endpoints.');
    LOp.AddPair('security', TJSONArray.Create); // [] → this call needs no token
    LOp.AddPair('requestBody', LReqBody);
    LOp.AddPair('responses', LTokenResponses);

    LTokenPath := TJSONObject.Create;
    LTokenPath.AddPair('post', LOp);
    LPaths.AddPair('/token', LTokenPath); // relative to servers.url (see note above)
  end;

begin
  LApp := TKWebApplication.Current;
  LViews := LApp.Config.Views;

  Result := TJSONObject.Create;
  try
    Result.AddPair('openapi', '3.0.3');

    LInfo := TJSONObject.Create;
    LInfo.AddPair('title', _(LApp.Config.AppTitle) + ' — REST API');
    LInfo.AddPair('version', 'v4');
    Result.AddPair('info', LInfo);

    LServersArr := TJSONArray.Create;
    LServer := TJSONObject.Create;
    LServer.AddPair('url', ARestBaseUrl);
    LServersArr.Add(LServer);
    Result.AddPair('servers', LServersArr);

    LPaths := TJSONObject.Create;
    LSchemas := TJSONObject.Create;

    // Public token endpoint first, so it appears at the top of Swagger UI.
    AddTokenPath;

    for I := 0 to LViews.ViewCount - 1 do
    begin
      LView := LViews[I];
      if not (LView is TKDataView) then
        Continue;
      LVT := TKDataView(LView).MainTable;
      if not Assigned(LVT) then
        Continue;
      LName := LView.PersistentName;
      if LName = '' then
        Continue;
      // Skip views whose main table has no resolvable model — a missing 'Model'
      // node, or one naming a model that doesn't exist. These are not REST data
      // endpoints; touching FieldCount would raise ObjectNotFound (checked here
      // with the non-raising ModelName/FindModel instead of relying on the catch).
      if (LVT.ModelName = '') or (LApp.Config.Models.FindModel(LVT.ModelName) = nil) then
      begin
        TEFLogger.Instance.LogFmt('OpenAPI: skipped view "%s" (no resolvable model)',
          [LName], TEFLogger.LOG_DETAILED);
        Continue;
      end;
      // Safety net for any residual metadata issue: a single view must not blow
      // up the whole document.
      try
        LSchemas.AddPair(LName, ViewSchema(LVT));
        BuildViewPaths(LName, LVT);
      except
        on E: Exception do
          TEFLogger.Instance.LogFmt('OpenAPI: skipped view "%s": %s',
            [LName, E.Message], TEFLogger.LOG_DETAILED);
      end;
    end;

    // Menu-referenced autobuild views (no .yaml file). Expose exactly the
    // autobuild surface the GUI menu publishes, each under <Builder>_<Model>.
    // ResolveAutoView builds it on demand and caches it as a dynamic object.
    LAutoViews := TKXDataService.EnumMenuAutoViews;
    for LAuto in LAutoViews do
    begin
      if Assigned(LSchemas.GetValue(LAuto.Name)) then
        Continue; // already emitted (e.g. a file view of the same name)
      try
        LView := TKXDataService.ResolveAutoView(LAuto.Name);
        if not (LView is TKDataView) then
          Continue;
        LVT := TKDataView(LView).MainTable;
        if not Assigned(LVT) or (LVT.ModelName = '')
          or (LApp.Config.Models.FindModel(LVT.ModelName) = nil) then
          Continue;
        LSchemas.AddPair(LAuto.Name, ViewSchema(LVT));
        BuildViewPaths(LAuto.Name, LVT);
      except
        on E: Exception do
          TEFLogger.Instance.LogFmt('OpenAPI: skipped autobuild view "%s": %s',
            [LAuto.Name, E.Message], TEFLogger.LOG_DETAILED);
      end;
    end;

    Result.AddPair('paths', LPaths);

    // components: schemas + bearer security scheme
    LComponents := TJSONObject.Create;
    LComponents.AddPair('schemas', LSchemas);
    LSec := TJSONObject.Create;
    LSec.AddPair('type', 'http');
    LSec.AddPair('scheme', 'bearer');
    LSec.AddPair('bearerFormat', 'JWT');
    LComponents.AddPair('securitySchemes',
      TJSONObject.Create.AddPair('bearerAuth', LSec) as TJSONObject);
    Result.AddPair('components', LComponents);

    // global security requirement
    LSecReq := TJSONArray.Create;
    LSecReq.Add(TJSONObject.Create.AddPair('bearerAuth', TJSONArray.Create) as TJSONObject);
    Result.AddPair('security', LSecReq);
  except
    Result.Free;
    raise;
  end;
end;

{ TKXApiDocHandler }

procedure TKXApiDocHandler.GetOpenAPI;
var
  LDoc: TJSONObject;
begin
  LDoc := TKXOpenAPIBuilder.Build(TKWebApplication.Current.Path +
    TKWebApplication.Current.Config.RestBasePath);
  try
    TKWebResponse.Current.StatusCode := 200;
    TKWebResponse.Current.ContentType := 'application/json; charset=utf-8';
    TKWebResponse.Current.ReplaceContentStream(
      TStringStream.Create(LDoc.ToJSON, TEncoding.UTF8));
  finally
    LDoc.Free;
  end;
end;

{ TKXApiSwaggerHandler }

procedure TKXApiSwaggerHandler.GetSwaggerUI;
var
  LApp: TKWebApplication;
  LRes, LSpec, LHtml: string;
begin
  LApp := TKWebApplication.Current;
  LRes := LApp.Path + '/res';                 // vendored assets (/res/*)
  LSpec := LApp.Path + '/api/v4/openapi.json'; // the spec this UI renders
  // Swagger UI is loaded from the framework's Home/Resources (self-contained,
  // works offline). Try-it-out: use "Authorize" and paste the JWT from
  // POST /api/v4/token as the bearer value.
  LHtml :=
    '<!DOCTYPE html><html lang="en"><head><meta charset="utf-8">' +
    '<meta name="viewport" content="width=device-width, initial-scale=1">' +
    '<title>' + TNetEncoding.HTML.Encode(_(LApp.Config.AppTitle)) + ' — API docs</title>' +
    '<link rel="stylesheet" href="' + LRes + '/css/swagger-ui.css">' +
    '</head><body>' +
    '<div id="swagger-ui"></div>' +
    '<script src="' + LRes + '/js/swagger-ui-bundle.js"></script>' +
    '<script>' +
    // deepLinking is deliberately OFF: swagger-ui v3 treats any '_' in a deep-link
    // segment as legacy escaped-whitespace and logs a deprecation warning. KittoX
    // model/view names (and thus paths and operationIds) legitimately contain '_'
    // (KITTO_USER_ROLES, AutoList_KITTO_PERMISSIONS, …), so deep-linking would warn
    // on every render. Turning it off removes the warning; the operationIds stay
    // (client generators use them regardless of the UI feature).
    'window.ui = SwaggerUIBundle({' +
      'url: ' + QuotedStr(LSpec) + ',' +
      'dom_id: "#swagger-ui",' +
      'deepLinking: false,' +
      'presets: [SwaggerUIBundle.presets.apis],' +
      'layout: "BaseLayout"' +
    '});' +
    '</script>' +
    '</body></html>';
  TKWebResponse.Current.StatusCode := 200;
  TKWebResponse.Current.ContentType := 'text/html; charset=utf-8';
  TKWebResponse.Current.ReplaceContentStream(
    TStringStream.Create(LHtml, TEncoding.UTF8));
end;

initialization
  TKXResourceRegistry.Instance.RegisterResource(TKXApiDocHandler);
  TKXResourceRegistry.Instance.RegisterResource(TKXApiSwaggerHandler);
  // Publish the Swagger UI link for the host UI (VCL MainForm) to show. The
  // path template keeps the '{apibase}' placeholder; the host expands it with
  // the app's configured RestBasePath — no hardcoded '/api/v4' outside config.
  TKXServerLinkRegistry.Register('Swagger UI', '{apibase}/docs');

end.
