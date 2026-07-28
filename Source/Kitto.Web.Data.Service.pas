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
///  Shared CRUD service layer used by both the HTML/HTMX GUI and the REST API.
///  It resolves a view, enforces ACL, loads stores/records, and applies the
///  full business-rule sequence around persistence (Apply*RecordRules +
///  per-field AfterFieldChange + ApplyBeforeRules + Model.SaveRecord), exactly
///  as the interactive GUI does — so a record created/updated over REST behaves
///  identically to one edited in a form (computed fields, reference captions,
///  master totals, validation).
///
///  This unit is part of the core and has NO dependency on any JSON framework
///  or on HTTP/HTML: values are applied through the caller-supplied AApplyValues
///  callback (the REST serializer injects JSON values there), and errors are
///  surfaced as EKXDataError carrying an HTTP status the caller maps to a
///  response. See KittoX_RestServer.md (service layer, §6/§7).
/// </summary>
unit Kitto.Web.Data.Service;

{$I Kitto.Defines.inc}

interface

uses
  System.SysUtils,
  Kitto.Types,
  Kitto.Store,
  Kitto.Metadata.Views,
  Kitto.Metadata.DataView;

type
  /// <summary>
  ///  Callback that applies caller-supplied values to a record (the REST
  ///  serializer parses the JSON body and calls TKXDataService.ApplyFieldValue
  ///  per field here). Invoked with change notifications disabled.
  /// </summary>
  TKXApplyValuesProc = reference to procedure(const ARecord: TKViewTableRecord);

  /// <summary>
  ///  Optional hook invoked around persistence (before/after save, before/after
  ///  delete). Nil is allowed (no-op).
  /// </summary>
  TKXRecordProc = reference to procedure(const ARecord: TKViewTableRecord);

  /// <summary>
  ///  Describes a menu-referenced autobuild view (a "Build &lt;Builder&gt;" node
  ///  with a Model child, e.g. "Build AutoList / Model: KITTO_USER_ROLES"). The
  ///  REST layer exposes each such view under the endpoint name
  ///  &lt;BuilderName&gt;_&lt;ModelName&gt; (e.g. AutoList_KITTO_USER_ROLES),
  ///  which stays distinct across builders (AutoList/AutoForm/…) on the same model.
  /// </summary>
  TKXAutoViewInfo = record
    /// <summary>The REST endpoint name: BuilderName + '_' + ModelName.</summary>
    Name: string;
    /// <summary>The view builder id (e.g. 'AutoList', 'AutoForm').</summary>
    BuilderName: string;
    /// <summary>The model the view is built from.</summary>
    ModelName: string;
    /// <summary>
    ///  The originating menu node (a TKTreeViewNode, held as TObject to keep this
    ///  record free of an EF.Tree dependency). ResolveAutoView resolves the view
    ///  through it via the same path the GUI uses (TKViews.ViewByNode), so the
    ///  catalog is wired up correctly; callers that only need the endpoint name
    ///  (e.g. the OpenAPI builder) ignore it.
    /// </summary>
    MenuNode: TObject;
  end;

  /// <summary>
  ///  Domain error carrying the HTTP status and a symbolic code that the caller
  ///  (e.g. the REST error filter) maps to a JSON error envelope + real status.
  ///  Descends from EKError so it flows through the normal exception path.
  /// </summary>
  EKXDataError = class(EKError)
  private
    FHTTPStatus: Integer;
    FCode: string;
    FFieldName: string;
  public
    /// <summary>Creates the error with the given HTTP status, symbolic code, message and optional field.</summary>
    constructor Create(const AHTTPStatus: Integer; const ACode, AMessage: string;
      const AFieldName: string = ''); reintroduce;
    /// <summary>The HTTP status to return (404, 403, 409, …).</summary>
    property HTTPStatus: Integer read FHTTPStatus;
    /// <summary>Machine-readable symbolic code (e.g. 'view_not_found', 'access_denied').</summary>
    property Code: string read FCode;
    /// <summary>Optional name of the field the error refers to.</summary>
    property FieldName: string read FFieldName;
  end;

  /// <summary>
  ///  Stateless CRUD service. All methods run inside the current request/app
  ///  context (TKWebApplication.Current) and raise EKXDataError on view-not-found
  ///  (404), not-a-data-view (404) or ACL denial (403).
  /// </summary>
  TKXDataService = class
  strict private
    /// <summary>Resolves the view by name and returns its MainTable, enforcing ACL for AAccessMode. Raises EKXDataError.</summary>
    class function ResolveViewTable(const AViewName, AAccessMode: string;
      out AView: TKView): TKViewTable; static;
    /// <summary>Builds a safe SQL filter from a 'field=val&field2=val2' key string, over IsKey fields only.</summary>
    class function BuildKeyFilter(const AViewTable: TKViewTable; const AKey: string): string; static;
    /// <summary>Fires AfterFieldChange rules per field then ApplyBeforeRules on a freshly-populated record.</summary>
    class procedure FireApplyRules(const AViewTable: TKViewTable; const ARecord: TKViewTableRecord); static;
  public
    /// <summary>
    ///  Applies a single scalar value to a record field, replicating the GUI's
    ///  write guards (CanInsert on insert; not IsKey and CanUpdate on update;
    ///  skip binary blobs and file-reference fields), then sets the value with
    ///  the datatype-aware EF converter (TEFNode.SetAsJSONValue). Request- and
    ///  JSON-agnostic: the value arrives as a string in the chosen convention.
    /// </summary>
    class procedure ApplyFieldValue(const ARecord: TKViewTableRecord;
      const AViewField: TKViewField; const AJSONValue: string; const AIsInsert: Boolean;
      const AUseJSDateFormat: Boolean; const AFormatSettings: TFormatSettings); static;

    /// <summary>
    ///  Loads one page of a view's data. AFilterExpr must already be a safe SQL
    ///  expression (built from the view's configured filters, not raw client
    ///  input); ASort/ADir are field names validated against the view.
    ///  Returns the store (caller owns it and must Free it); ATotal receives the
    ///  full unpaged record count.
    /// </summary>
    class function LoadList(const AViewName, AFilterExpr, ASort, ADir: string;
      const AFrom, AFor: Integer; out ATotal: Integer): TKViewTableStore; static;

    /// <summary>
    ///  Loads a single record by its key string ('field=val&…'). Returns the
    ///  record; AStore receives the owning store (caller frees it). Raises
    ///  EKXDataError(404) if no record matches.
    /// </summary>
    class function LoadRecord(const AViewName, AKey: string;
      out AStore: TKViewTableStore): TKViewTableRecord; static;

    /// <summary>
    ///  Creates a record: appends+initializes, applies new-record rules, applies
    ///  the caller's values (notifications disabled), refreshes derived reference
    ///  values, fires the field/record rule sequence, then persists. Returns the
    ///  persisted record; AStore receives the owning store (caller frees it).
    ///  Rule violations raise EKValidationError; the caller maps them to 422.
    /// </summary>
    class function CreateRecord(const AViewName: string;
      const AApplyValues: TKXApplyValuesProc;
      const AOnBeforeSave, AOnAfterSave: TKXRecordProc;
      out AStore: TKViewTableStore): TKViewTableRecord; static;

    /// <summary>
    ///  Updates the record identified by AKey: loads it, applies edit-record
    ///  rules, applies the caller's values, refreshes derived references, fires
    ///  the rule sequence, then persists. Returns the record; AStore receives the
    ///  owning store (caller frees it). Raises EKXDataError(404) if absent.
    /// </summary>
    class function UpdateRecord(const AViewName, AKey: string;
      const AApplyValues: TKXApplyValuesProc;
      const AOnBeforeSave, AOnAfterSave: TKXRecordProc;
      out AStore: TKViewTableStore): TKViewTableRecord; static;

    /// <summary>
    ///  Deletes the record identified by AKey (marks deleted + persists).
    ///  Raises EKXDataError(404) if absent. Optional hooks run around persistence.
    /// </summary>
    class procedure DeleteRecord(const AViewName, AKey: string;
      const AOnBeforeDelete, AOnAfterDelete: TKXRecordProc); static;

    /// <summary>
    ///  Enumerates the autobuild views referenced by the application menu (the
    ///  'MainMenu' TreeView): every "Build &lt;Builder&gt;" node with a Model
    ///  child whose builder is registered. No side effects (it does not build
    ///  the views). The REST layer uses this to publish exactly the autobuild
    ///  surface the GUI menu exposes, each under the endpoint name
    ///  &lt;Builder&gt;_&lt;Model&gt;.
    /// </summary>
    class function EnumMenuAutoViews: TArray<TKXAutoViewInfo>; static;

    /// <summary>
    ///  Resolves a menu autobuild view by its endpoint name AName
    ///  (&lt;Builder&gt;_&lt;Model&gt;): returns it from the dynamic cache if
    ///  already built, otherwise — only if AName is a menu-referenced autobuild —
    ///  builds it with the registered view builder and caches it as a dynamic
    ///  object under AName. Returns nil if AName is not a menu autobuild.
    ///  Idempotent. This namespace (&lt;Builder&gt;_&lt;Model&gt;) never collides
    ///  with the GUI's own dynamic naming (ModelName) nor with file views.
    /// </summary>
    class function ResolveAutoView(const AName: string): TKView; static;
  end;

implementation

uses
  System.Types,
  System.StrUtils,
  System.NetEncoding,
  System.Classes,
  System.Generics.Collections,
  EF.Tree,
  EF.StrUtils,
  Kitto.Rules,
  Kitto.AccessControl,
  Kitto.Metadata.Models,
  Kitto.Metadata.ViewBuilders,
  Kitto.Web.Application;

{ EKXDataError }

constructor EKXDataError.Create(const AHTTPStatus: Integer; const ACode, AMessage,
  AFieldName: string);
begin
  inherited Create(AMessage);
  FHTTPStatus := AHTTPStatus;
  FCode := ACode;
  FFieldName := AFieldName;
end;

{ TKXDataService }

class function TKXDataService.ResolveViewTable(const AViewName, AAccessMode: string;
  out AView: TKView): TKViewTable;
begin
  AView := TKWebApplication.Current.Config.Views.FindView(AViewName);
  // Fall back to a menu-referenced autobuild view (built on demand and cached as
  // a dynamic object under its <Builder>_<Model> endpoint name). Only autobuilds
  // the GUI menu itself publishes are resolvable — never an arbitrary model.
  if not Assigned(AView) then
    AView := ResolveAutoView(AViewName);
  if not Assigned(AView) then
    raise EKXDataError.Create(404, 'view_not_found',
      Format('View not found: "%s"', [AViewName]));
  if not (AView is TKDataView) then
    raise EKXDataError.Create(404, 'not_a_data_view',
      Format('View "%s" is not a data view', [AViewName]));
  if not AView.IsAccessGranted(AAccessMode) then
    raise EKXDataError.Create(403, 'access_denied',
      Format('Access denied to view "%s" (mode %s)', [AViewName, AAccessMode]));
  Result := TKDataView(AView).MainTable;
  if not Assigned(Result) then
    raise EKXDataError.Create(404, 'no_main_table',
      Format('View "%s" has no main table', [AViewName]));
  // Model-level write control. The REST API deliberately honors the MODEL flags
  // (IsReadOnly global + per-operation PreventAdding/Editing/Deleting) and field
  // rules (CanInsert/CanUpdate), NOT the view Controller's Prevent* — those are
  // GUI-only (a view falls back to the model default for the GUI, but a view can
  // never relax or tighten what the REST API allows). ACM_VIEW is never blocked.
  if not SameText(AAccessMode, ACM_VIEW) then
  begin
    if Result.Model.IsReadOnly then
      raise EKXDataError.Create(405, 'read_only',
        Format('Model "%s" is read-only', [Result.Model.ModelName]));
    if SameText(AAccessMode, ACM_ADD) and Result.Model.PreventAdding then
      raise EKXDataError.Create(405, 'add_not_allowed',
        Format('Model "%s" does not allow adding records', [Result.Model.ModelName]));
    if SameText(AAccessMode, ACM_MODIFY) and Result.Model.PreventEditing then
      raise EKXDataError.Create(405, 'edit_not_allowed',
        Format('Model "%s" does not allow editing records', [Result.Model.ModelName]));
    if SameText(AAccessMode, ACM_DELETE) and Result.Model.PreventDeleting then
      raise EKXDataError.Create(405, 'delete_not_allowed',
        Format('Model "%s" does not allow deleting records', [Result.Model.ModelName]));
  end;
end;

class function TKXDataService.BuildKeyFilter(const AViewTable: TKViewTable;
  const AKey: string): string;
var
  LParts, LPair: TArray<string>;
  I: Integer;
  LFieldName, LFieldValue: string;
  LViewField: TKViewField;
begin
  Result := '';
  if AKey = '' then
    raise EKXDataError.Create(400, 'missing_key', 'Missing record key');
  LParts := AKey.Split(['&']);
  for I := 0 to Length(LParts) - 1 do
  begin
    LPair := LParts[I].Split(['=']);
    if Length(LPair) = 2 then
    begin
      LFieldName := TNetEncoding.URL.Decode(LPair[0]);
      LFieldValue := TNetEncoding.URL.Decode(LPair[1]);
      // Only accept key fields that exist in the view (prevents SQL injection),
      // mirroring TKXViewHandlerBase.HandleDelete.
      LViewField := AViewTable.FindField(LFieldName);
      if Assigned(LViewField) and LViewField.IsKey then
      begin
        if Result <> '' then
          Result := Result + ' and ';
        Result := Result + LViewField.QualifiedDBNameOrExpression +
          ' = ''' + ReplaceStr(LFieldValue, '''', '''''') + '''';
      end;
    end;
  end;
  if Result = '' then
    raise EKXDataError.Create(400, 'invalid_key', 'No valid key field in record key');
end;

class procedure TKXDataService.ApplyFieldValue(const ARecord: TKViewTableRecord;
  const AViewField: TKViewField; const AJSONValue: string; const AIsInsert: Boolean;
  const AUseJSDateFormat: Boolean; const AFormatSettings: TFormatSettings);
begin
  if AIsInsert then
  begin
    if not AViewField.CanInsert then Exit;
  end
  else
  begin
    if AViewField.IsKey then Exit;
    if not AViewField.CanUpdate then Exit;
  end;
  // Binary blobs are served/uploaded via the blob endpoint, not inline; memo
  // (text) blobs are writable. File-reference fields have a dedicated flow.
  if AViewField.IsBlob and not (AViewField.DataType is TEFMemoDataType) then
    Exit;
  if AViewField.DataType is TKFileReferenceDataType then
    Exit;
  ARecord.FieldByName(AViewField.FieldNamesForUpdate).SetAsJSONValue(
    AJSONValue, AUseJSDateFormat, AFormatSettings);
end;

class procedure TKXDataService.FireApplyRules(const AViewTable: TKViewTable;
  const ARecord: TKViewTableRecord);
var
  I: Integer;
  LViewField: TKViewField;
  LRecField: TKField;
begin
  // Apply each field's AfterFieldChange rules on the freshly-populated record so
  // computed fields get set (values were applied with notifications disabled).
  // Then fire the record's Before rules (e.g. master totals). Mirrors
  // TKXViewHandlerBase.HandleDetailSave.
  for I := 0 to AViewTable.FieldCount - 1 do
  begin
    LViewField := AViewTable.Fields[I];
    LRecField := ARecord.FindField(LViewField.AliasedName);
    if Assigned(LRecField) then
      LViewField.EnumRules(
        function (ARuleImpl: TKRuleImpl): Boolean
        begin
          ARuleImpl.AfterFieldChange(LRecField, LRecField.Value, LRecField.Value);
          Result := False; // continue with the next rule
        end);
  end;
  ARecord.ApplyBeforeRules;
end;

class function TKXDataService.LoadList(const AViewName, AFilterExpr, ASort, ADir: string;
  const AFrom, AFor: Integer; out ATotal: Integer): TKViewTableStore;
var
  LView: TKView;
  LViewTable: TKViewTable;
  LSortExpr: string;
begin
  LViewTable := ResolveViewTable(AViewName, ACM_VIEW, LView);
  LSortExpr := TKWebApplication.Current.BuildSortExpression(LViewTable, ASort, ADir);
  Result := LViewTable.CreateStore;
  try
    ATotal := Result.Load(AFilterExpr, LSortExpr, AFrom, AFor);
  except
    FreeAndNil(Result);
    raise;
  end;
end;

class function TKXDataService.LoadRecord(const AViewName, AKey: string;
  out AStore: TKViewTableStore): TKViewTableRecord;
var
  LView: TKView;
  LViewTable: TKViewTable;
  LKeyFilter: string;
begin
  LViewTable := ResolveViewTable(AViewName, ACM_VIEW, LView);
  LKeyFilter := BuildKeyFilter(LViewTable, AKey);
  AStore := LViewTable.CreateStore;
  try
    AStore.Load(LKeyFilter, '', 0, 1);
    if AStore.RecordCount = 0 then
      raise EKXDataError.Create(404, 'record_not_found', 'Record not found');
    Result := AStore.Records[0];
  except
    FreeAndNil(AStore);
    raise;
  end;
end;

class function TKXDataService.CreateRecord(const AViewName: string;
  const AApplyValues: TKXApplyValuesProc;
  const AOnBeforeSave, AOnAfterSave: TKXRecordProc;
  out AStore: TKViewTableStore): TKViewTableRecord;
var
  LView: TKView;
  LViewTable: TKViewTable;
  LRecord: TKViewTableRecord;
  LDefaults: TEFNode;
begin
  LViewTable := ResolveViewTable(AViewName, ACM_ADD, LView);
  AStore := LViewTable.CreateStore;
  try
    LRecord := AStore.Records.AppendAndInitialize;
    // Apply the view/model default values (e.g. %COMPACT_GUID% on a PK) BEFORE
    // the client values and the rules — mirrors the GUI Add flow
    // (TKXViewHandlerBase.HandleSaveCache): without this a not-null PK with a
    // macro default is inserted as NULL and the DB rejects it.
    LDefaults := LViewTable.GetDefaultValues;
    try
      LRecord.ReadFromNode(LDefaults);
    finally
      FreeAndNil(LDefaults);
    end;
    LRecord.MarkAsNew;
    LRecord.ApplyNewRecordRules;
    if Assigned(AApplyValues) then
      AStore.DoWithChangeNotificationsDisabled(
        procedure
        begin
          AApplyValues(LRecord);
        end);
    LRecord.RefreshDerivedReferenceValues;
    FireApplyRules(LViewTable, LRecord);
    if Assigned(AOnBeforeSave) then AOnBeforeSave(LRecord);
    LViewTable.Model.SaveRecord(LRecord, True, nil);
    if Assigned(AOnAfterSave) then AOnAfterSave(LRecord);
    Result := LRecord;
  except
    FreeAndNil(AStore);
    raise;
  end;
end;

class function TKXDataService.UpdateRecord(const AViewName, AKey: string;
  const AApplyValues: TKXApplyValuesProc;
  const AOnBeforeSave, AOnAfterSave: TKXRecordProc;
  out AStore: TKViewTableStore): TKViewTableRecord;
var
  LView: TKView;
  LViewTable: TKViewTable;
  LKeyFilter: string;
  LRecord: TKViewTableRecord;
begin
  LViewTable := ResolveViewTable(AViewName, ACM_MODIFY, LView);
  LKeyFilter := BuildKeyFilter(LViewTable, AKey);
  AStore := LViewTable.CreateStore;
  try
    AStore.Load(LKeyFilter, '', 0, 1);
    if AStore.RecordCount = 0 then
      raise EKXDataError.Create(404, 'record_not_found', 'Record not found');
    LRecord := AStore.Records[0];
    LRecord.ApplyEditRecordRules;
    if Assigned(AApplyValues) then
      AStore.DoWithChangeNotificationsDisabled(
        procedure
        begin
          AApplyValues(LRecord);
        end);
    LRecord.MarkAsModified;
    LRecord.RefreshDerivedReferenceValues;
    FireApplyRules(LViewTable, LRecord);
    if Assigned(AOnBeforeSave) then AOnBeforeSave(LRecord);
    LViewTable.Model.SaveRecord(LRecord, True, nil);
    if Assigned(AOnAfterSave) then AOnAfterSave(LRecord);
    Result := LRecord;
  except
    FreeAndNil(AStore);
    raise;
  end;
end;

class procedure TKXDataService.DeleteRecord(const AViewName, AKey: string;
  const AOnBeforeDelete, AOnAfterDelete: TKXRecordProc);
var
  LView: TKView;
  LViewTable: TKViewTable;
  LKeyFilter: string;
  LStore: TKViewTableStore;
  LRecord: TKViewTableRecord;
begin
  LViewTable := ResolveViewTable(AViewName, ACM_DELETE, LView);
  LKeyFilter := BuildKeyFilter(LViewTable, AKey);
  LStore := LViewTable.CreateStore;
  try
    LStore.Load(LKeyFilter, '', 0, 1);
    if LStore.RecordCount = 0 then
      raise EKXDataError.Create(404, 'record_not_found', 'Record not found');
    LRecord := LStore.Records[0];
    LRecord.MarkAsDeleted;
    if Assigned(AOnBeforeDelete) then AOnBeforeDelete(LRecord);
    LViewTable.Model.SaveRecord(LRecord, True, nil);
    if Assigned(AOnAfterDelete) then AOnAfterDelete(LRecord);
  finally
    FreeAndNil(LStore);
  end;
end;

class function TKXDataService.EnumMenuAutoViews: TArray<TKXAutoViewInfo>;
var
  LViews: TKViews;
  LMenu: TKView;
  LMenuNodes: IKTreeViewNodes;
  LResult: TList<TKXAutoViewInfo>;
  LSeen: TStringList;

  procedure Walk(const ANodes: IKTreeViewNodes);
  var
    I: Integer;
    LNode: TKTreeViewNode;
    LChildNodes: IKTreeViewNodes;
    LWords: TStringDynArray;
    LModel: string;
    LInfo: TKXAutoViewInfo;
  begin
    if not Assigned(ANodes) then
      Exit;
    for I := 0 to ANodes.TreeViewNodeCount - 1 do
    begin
      LNode := ANodes.TreeViewNodes[I];
      // A "Build <Builder>" leaf with a Model child, whose builder is registered:
      // same detection rule as TKViews.FindViewByNode. Expose it under
      // <Builder>_<Model>.
      LWords := Split(LNode.AsExpandedString);
      if (Length(LWords) >= 2) and SameText(LWords[0], 'Build')
        and TKViewBuilderRegistry.Instance.HasClass(LWords[1]) then
      begin
        LModel := LNode.GetString('Model');
        if LModel <> '' then
        begin
          LInfo.BuilderName := LWords[1];
          LInfo.ModelName := LModel;
          LInfo.Name := LInfo.BuilderName + '_' + LInfo.ModelName;
          LInfo.MenuNode := LNode;
          if LSeen.IndexOf(LInfo.Name) < 0 then
          begin
            LSeen.Add(LInfo.Name);
            LResult.Add(LInfo);
          end;
        end;
      end;
      // Recurse into folders (and any node that hosts sub-nodes).
      if Supports(LNode, IKTreeViewNodes, LChildNodes) then
        Walk(LChildNodes);
    end;
  end;

begin
  LResult := TList<TKXAutoViewInfo>.Create;
  LSeen := TStringList.Create;
  try
    LSeen.CaseSensitive := False;
    LViews := TKWebApplication.Current.Config.Views;
    LMenu := LViews.FindView('MainMenu');
    if Assigned(LMenu) and Supports(LMenu, IKTreeViewNodes, LMenuNodes) then
      Walk(LMenuNodes);
    Result := LResult.ToArray;
  finally
    FreeAndNil(LSeen);
    FreeAndNil(LResult);
  end;
end;

class function TKXDataService.ResolveAutoView(const AName: string): TKView;
var
  LViews: TKViews;
  LInfos: TArray<TKXAutoViewInfo>;
  LInfo: TKXAutoViewInfo;
  LFound: Boolean;
  LMatch: TKXAutoViewInfo;
begin
  Result := nil;
  if AName = '' then
    Exit;
  LViews := TKWebApplication.Current.Config.Views;

  // Already built (from a previous REST call or the OpenAPI enumeration)?
  Result := LViews.FindDynamicObject(AName) as TKView;
  if Assigned(Result) then
    Exit;

  // Only menu-referenced autobuilds are resolvable — never an arbitrary model.
  LFound := False;
  LInfos := EnumMenuAutoViews;
  for LInfo in LInfos do
    if SameText(LInfo.Name, AName) then
    begin
      LMatch := LInfo;
      LFound := True;
      Break;
    end;
  if not LFound then
    Exit;

  // Resolve the view through the menu node using the SAME path the GUI takes
  // (TKViews.ViewByNode → FindViewByNode → BuildView), so the view is built,
  // populated and wired to the catalog exactly as for the menu — no half-built
  // orphan. The result is process-global and shared with the GUI (the menu node
  // caches it as a nonpersistent object); we only add a REST alias for it under
  // its <Builder>_<Model> endpoint name. We never touch its PersistentName, so
  // the GUI's own ModelName-keyed dynamic registration is unaffected.
  if not (LMatch.MenuNode is TEFNode) then
    Exit;
  Result := LViews.FindViewByNode(TEFNode(LMatch.MenuNode));
  if Assigned(Result) and (LViews.FindDynamicObject(AName) = nil) then
    LViews.AddDynamicObject(Result, AName);
end;

end.
