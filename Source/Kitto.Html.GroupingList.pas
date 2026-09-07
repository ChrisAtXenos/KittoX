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
///  KittoX GroupingList controller — renders a data grid with all records
///  grouped by a specified field, with collapsible group headers.
///  No paging (all records loaded). Inherits toolbar and filter support
///  from TKXListPanelController.
///  Replaces ExtJS TKExtGridPanel with Grouping feature.
/// </summary>
unit Kitto.Html.GroupingList;

{$I Kitto.Defines.inc}

interface

uses
  System.Types,
  EF.Tree,
  Kitto.Html.List,
  Kitto.Html.Controller,
  Kitto.Metadata.Views,
  Kitto.Metadata.DataView,
  Kitto.Store;

type
  /// <summary>
  ///  Grouped data grid controller. Loads all records (no paging) and renders
  ///  them under collapsible group headers keyed by a grouping field, reusing
  ///  the toolbar, filter and column support of TKXListPanelController.
  /// </summary>
  TKXGroupingListController = class(TKXListPanelController)
  strict private
    function GetGroupingFieldName: string;
    function GetGroupSortExpr(AViewTable: TKViewTable): string;
  strict protected
    function GetPanelCssClass: string; override;
    function RenderContent: string; override;
  public
    /// <summary>
    ///  Builds grouped data rows: group header rows with expand/collapse
    ///  toggle followed by data rows for each group.
    ///  Class function so it can be called from HandleKXDataRequest.
    ///  ALayout selects and orders the columns exactly as in
    ///  TKXListPanelController.BuildDataRows; when nil, all visible view table
    ///  fields are rendered in model order.
    /// </summary>
    class function BuildGroupedRows(AStore: TKViewTableStore;
      AViewTable: TKViewTable; const AViewName: string;
      const AGroupingFieldName: string;
      AGroupingNode: TEFNode;
      const AUrlViewName: string = '';
      ALayout: TKLayout = nil): string;
  end;

implementation

uses
  System.SysUtils,
  System.Classes,
  System.StrUtils,
  System.NetEncoding,
  Data.DB,
  EF.DB,
  EF.JSON,
  EF.StrUtils,
  EF.Localization,
  Kitto.Config,
  Kitto.Html.Base,
  Kitto.Html.Utils,
  Kitto.Metadata.Models,
  Kitto.Web.Request,
  EF.Logger;

type
  /// <summary>
  ///  One aggregate declared under Grouping/Aggregates: which field to
  ///  aggregate, how, and the label to show before the value.
  /// </summary>
  TKGroupAggregateDef = record
    ViewField: TKViewField;
    Operation: string;
    Caption: string;
    IsCurrency: Boolean;
  end;

  /// <summary>
  ///  Accumulators for a single group: the record count that ShowCount needs,
  ///  plus one slot per declared aggregate. Filled by the pre-scan that walks
  ///  the store once, so the header can be composed while emitting the rows.
  /// </summary>
  TKGroupAccumulator = class
  strict private
    FCount: Integer;
    FSums: TArray<Double>;
    FValueCounts: TArray<Integer>;
    FMins: TArray<Double>;
    FMaxs: TArray<Double>;
  public
    constructor Create(const AAggregateCount: Integer);
    /// <summary>Counts one more record in this group.</summary>
    procedure AddRecord;
    /// <summary>Feeds one non-null value to the aggregate of index AIndex.</summary>
    procedure AddValue(const AIndex: Integer; const AValue: Double);
    /// <summary>The aggregate's result, or False when no value contributed to
    /// it (an empty group, or a column that is null throughout).</summary>
    function TryGetResult(const AIndex: Integer; const AOperation: string;
      out AResult: Double): Boolean;
    property Count: Integer read FCount;
  end;

{ TKGroupAccumulator }

constructor TKGroupAccumulator.Create(const AAggregateCount: Integer);
begin
  inherited Create;
  SetLength(FSums, AAggregateCount);
  SetLength(FValueCounts, AAggregateCount);
  SetLength(FMins, AAggregateCount);
  SetLength(FMaxs, AAggregateCount);
end;

procedure TKGroupAccumulator.AddRecord;
begin
  Inc(FCount);
end;

procedure TKGroupAccumulator.AddValue(const AIndex: Integer; const AValue: Double);
begin
  if (AIndex < 0) or (AIndex > High(FSums)) then
    Exit;
  FSums[AIndex] := FSums[AIndex] + AValue;
  if FValueCounts[AIndex] = 0 then
  begin
    FMins[AIndex] := AValue;
    FMaxs[AIndex] := AValue;
  end
  else
  begin
    if AValue < FMins[AIndex] then
      FMins[AIndex] := AValue;
    if AValue > FMaxs[AIndex] then
      FMaxs[AIndex] := AValue;
  end;
  Inc(FValueCounts[AIndex]);
end;

function TKGroupAccumulator.TryGetResult(const AIndex: Integer;
  const AOperation: string; out AResult: Double): Boolean;
begin
  AResult := 0;
  Result := (AIndex >= 0) and (AIndex <= High(FSums));
  if not Result then
    Exit;
  // Count is the only operation that means something on a group whose values
  // are all null: it answers "how many values are there", and zero is an
  // answer. The others have nothing to report.
  if SameText(AOperation, 'Count') then
    AResult := FValueCounts[AIndex]
  else if FValueCounts[AIndex] = 0 then
    Result := False
  else if SameText(AOperation, 'Avg') then
    AResult := FSums[AIndex] / FValueCounts[AIndex]
  else if SameText(AOperation, 'Min') then
    AResult := FMins[AIndex]
  else if SameText(AOperation, 'Max') then
    AResult := FMaxs[AIndex]
  else
    AResult := FSums[AIndex]; // Sum, and the default for anything unrecognized
end;

{ TKXGroupingListController }

function TKXGroupingListController.GetPanelCssClass: string;
begin
  Result := 'kx-list-panel kx-grouping-list';
end;

function TKXGroupingListController.GetGroupingFieldName: string;
begin
  Result := ViewTable.GetExpandedString('Controller/Grouping/FieldName');
  if Result = '' then
    raise Exception.Create('GroupingList controller requires Grouping/FieldName');
end;

function TKXGroupingListController.GetGroupSortExpr(AViewTable: TKViewTable): string;
var
  LSortFieldNames: TStringDynArray;
  LGroupingFieldName: string;
  I: Integer;
begin
  LSortFieldNames := AViewTable.GetStringArray('Controller/Grouping/SortFieldNames');
  if Length(LSortFieldNames) = 0 then
  begin
    LGroupingFieldName := GetGroupingFieldName;
    Result := AViewTable.FieldByName(LGroupingFieldName).QualifiedDBNameOrExpression;
  end
  else
  begin
    for I := Low(LSortFieldNames) to High(LSortFieldNames) do
      LSortFieldNames[I] := AViewTable.FieldByName(LSortFieldNames[I]).QualifiedDBNameOrExpression;
    Result := Join(LSortFieldNames, ', ');
  end;
end;

function TKXGroupingListController.RenderContent: string;
var
  LDataView: TKDataView;
  LViewTable: TKViewTable;
  LStore: TKViewTableStore;
  LViewName: string;
  LGroupingFieldName: string;
  LGroupingNode: TEFNode;
  LSortExpr: string;
  LFilterPanelHtml: string;
  LDefaultFilterExpr: string;
  LRowClassProvider: string;
  LAutoOpen: Boolean;
  LGridLayout: TKLayout;
  SB: TStringBuilder;
begin
  Result := '';
  if not Assigned(View) or not (View is TKDataView) then
    Exit;

  LDataView := TKDataView(View);
  LViewTable := LDataView.MainTable;
  if not Assigned(LViewTable) then
    Exit;

  LViewName := View.PersistentName;
  LGroupingFieldName := GetGroupingFieldName;
  LGroupingNode := LViewTable.FindNode('Controller/Grouping');

  // Validate that the grouping field exists
  if LViewTable.FindField(LGroupingFieldName) = nil then
    raise Exception.CreateFmt('Grouping field %s not found in view table.', [LGroupingFieldName]);

  // Build sort expression from Grouping/SortFieldNames or grouping field
  LSortExpr := GetGroupSortExpr(LViewTable);

  // Grid layout: selects and orders the columns, exactly as in
  // TKXListPanelController.RenderContent. Must be handed to both the header
  // and the row builder, or the two disagree on the column set.
  LGridLayout := LViewTable.FindLayout('Grid');

  // Build filter panel (if Filters/Items defined)
  LFilterPanelHtml := BuildFilterPanel(LViewName, LViewTable,
    LDefaultFilterExpr);

  // IsLarge drives the default: AutoOpen = not IsLarge.
  // (GroupingList has no paging — PagingTools is irrelevant here.)
  LAutoOpen := LViewTable.GetBoolean('Controller/AutoOpen', not LViewTable.IsLarge);

  // Load ALL records (no paging: start=0, count=0).
  // AutoOpen=False skips the initial load — user populates via filter/Refresh.
  LStore := LViewTable.CreateStore;
  try
    if LAutoOpen then
      LStore.Load(LDefaultFilterExpr, LSortExpr, 0, 0);

    SB := TStringBuilder.Create;
    try
      // Filter panel
      SB.Append(LFilterPanelHtml);

      // Toolbar (CRUD buttons)
      SB.Append(BuildToolbar(LViewName));

      // Grid table: thead + tbody with grouped rows
      LRowClassProvider := LViewTable.GetExpandedString('Controller/RowClassProvider');
      SB.Append('<div class="kx-list-grid"><table class="kx-grid-table">');
      // The grouping field gets no column of its own: its value heads every
      // group. BuildGroupedRows leaves out the same field, or headers and
      // cells would misalign.
      SB.Append(BuildColumnHeaders(LViewTable, LViewName, '', '', '', LGridLayout,
        LGroupingFieldName));
      SB.Append('<tbody id="kx-list-body-').Append(LViewName).Append('"');
      if IsActionVisible('Edit') and IsActionAllowed('Edit') then
        SB.Append(' data-dblclick="edit"')
      else if IsActionVisible('View') then
        SB.Append(' data-dblclick="view"');
      if LRowClassProvider <> '' then
        SB.Append(' data-row-class-provider="').Append(TNetEncoding.HTML.Encode(LRowClassProvider)).Append('"');
      SB.Append('>');
      SB.Append(BuildGroupedRows(LStore, LViewTable, LViewName,
        LGroupingFieldName, LGroupingNode, '', LGridLayout));
      SB.Append('</tbody></table></div>');

      // No pager for GroupingList

      // Hidden state (no paging values, but needed for filter state)
      SB.Append(BuildHiddenState(LViewName, 0, '', ''));

      Result := SB.ToString;
    finally
      SB.Free;
    end;
  finally
    FreeAndNil(LStore);
  end;
end;

class function TKXGroupingListController.BuildGroupedRows(
  AStore: TKViewTableStore; AViewTable: TKViewTable;
  const AViewName, AGroupingFieldName: string;
  AGroupingNode: TEFNode;
  const AUrlViewName: string;
  ALayout: TKLayout): string;
var
  I, J: Integer;
  LRecord: TKViewTableRecord;
  LField: TKViewField;
  LLayoutNode: TEFNode;
  LRecordField: TKViewTableField;
  LGroupField: TKViewField;
  LValue, LGroupValue, LPrevGroup: string;
  LAlign: string;
  LIsBool, LIsDateTime, LIsCurrency: Boolean;
  LChecked: string;
  LUserFmt: TFormatSettings;
  LCurrSymbol: string;
  LCaptionField: TKModelField;
  LCaptionValue: string;
  LGroupIndex: Integer;
  LCellSlots: Integer;
  LStartCollapsed: Boolean;
  LShowCount, LShowName: Boolean;
  LItemName, LPluralItemName, LFieldLabel: string;
  LColCount: Integer;
  LGroupCounts: TStringList;
  LToggleIcon: string;
  LDisplayStyle: string;
  LCountText: string;
  LHeaderText: string;
  LHasRowClassProvider: Boolean;
  LAggregates: TArray<TKGroupAggregateDef>;
  LAggNode: TEFNode;
  LAcc: TKGroupAccumulator;
  LAggValue: Double;
  LAggText: string;
  SB, SBKey: TStringBuilder;

  // Reads the Grouping/Aggregates node. Each child names a field of the view
  // table and may carry Operation (Sum by default) and Label. A field that
  // cannot be aggregated is skipped with a log line rather than silently
  // dropped: a total missing from a header is exactly the kind of failure that
  // goes unnoticed until someone reconciles the numbers by hand.
  procedure ReadAggregates;
  var
    K: Integer;
    LNode: TEFNode;
    LVF: TKViewField;
    LDef: TKGroupAggregateDef;
  begin
    if not Assigned(AGroupingNode) then
      Exit;
    LAggNode := AGroupingNode.FindNode('Aggregates');
    if not Assigned(LAggNode) then
      Exit;
    for K := 0 to LAggNode.ChildCount - 1 do
    begin
      LNode := LAggNode.Children[K];
      LVF := AViewTable.FindField(LNode.Name);
      if not Assigned(LVF) then
      begin
        TEFLogger.Instance.LogFmt(
          'Grouping/Aggregates: field "%s" not found in view table "%s" - aggregate ignored.',
          [LNode.Name, AViewTable.ModelName], TEFLogger.LOG_ALWAYS);
        Continue;
      end;
      if not (LVF.DataType is TEFNumericDataTypeBase) then
      begin
        TEFLogger.Instance.LogFmt(
          'Grouping/Aggregates: field "%s" is not numeric (%s) - aggregate ignored.',
          [LNode.Name, LVF.DataType.GetTypeName], TEFLogger.LOG_ALWAYS);
        Continue;
      end;
      LDef.ViewField := LVF;
      LDef.Operation := LNode.GetString('Operation', 'Sum');
      LDef.Caption := _(LNode.GetString('Label', LVF.DisplayLabel));
      LDef.IsCurrency := LVF.DataType is TEFCurrencyDataType;
      LAggregates := LAggregates + [LDef];
    end;
  end;

  // Formats an aggregate result the way the corresponding column is rendered:
  // the user's format settings, and the currency symbol when the field carries
  // one. Count is always a plain integer, whatever the field's type.
  function FormatAggregate(const ADef: TKGroupAggregateDef; const AValue: Double): string;
  begin
    if SameText(ADef.Operation, 'Count') then
      Result := FormatFloat('#,##0', AValue, LUserFmt)
    else
    begin
      Result := FormatFloat('#,##0.00', AValue, LUserFmt);
      if ADef.IsCurrency and (LCurrSymbol <> '') then
        Result := LCurrSymbol + ' ' + Result;
    end;
  end;

  // Resolves the field to render in column AIndex, mirroring
  // TKXListPanelController.BuildDataRows.GetCellField: with a layout the
  // columns are the layout's Field nodes, in layout order; without one they
  // are the visible view table fields, in model order. Both paths must use
  // the same rule as BuildColumnHeaders, or headers and cells misalign — which
  // is why the grouping field is left out here and there alike: its value is
  // already in every group header, so a column repeating it is noise. Same as
  // Kitto1, where the ExtJS grouping view set HideGroupedColumn := True
  // (Kitto.Ext.GridPanel.pas:225).
  function GetCellField(AIndex: Integer; out AField: TKViewField;
    out ALayoutNode: TEFNode): Boolean;
  var
    LNode: TEFNode;
    LName: string;
  begin
    Result := False;
    ALayoutNode := nil;
    if Assigned(ALayout) then
    begin
      LNode := ALayout.Children[AIndex];
      if not SameText(LNode.Name, 'Field') then
        Exit;
      LName := LNode.AsString;
      AField := AViewTable.FindField(LName);
      if not Assigned(AField) then
        Exit;
      if AField = LGroupField then
        Exit;
      ALayoutNode := LNode;
      Result := True;
    end
    else
    begin
      AField := AViewTable.Fields[AIndex];
      if not AField.IsVisible or (AField.IsBlob and not (AField.DataType is TEFMemoDataType)) then
        Exit;
      if AField = LGroupField then
        Exit;
      Result := True;
    end;
  end;

  // Builds the ' data-fields="{...}"' attribute for a record so that the
  // client-side kxGrid.applyRowClasses can feed the values to the
  // RowClassProvider JS function. Returns '' when no RowClassProvider is
  // defined on the view. For data rows the record is the row's own record;
  // for group header rows it is the first record of the group (all records
  // of a group share the same value of the grouping field, so any record
  // that depends only on that field returns a constant class — this is what
  // lets the header receive the same colour as its data rows).
  function BuildRowDataFieldsAttr(ARecord: TKViewTableRecord): string;
  var
    K: Integer;
    LFld: TKViewField;
    LRecFld: TKViewTableField;
    SBF: TStringBuilder;
  begin
    Result := '';
    if not LHasRowClassProvider then
      Exit;
    SBF := TStringBuilder.Create;
    try
      SBF.Append('{');
      for K := 0 to AViewTable.FieldCount - 1 do
      begin
        LFld := AViewTable.Fields[K];
        if LFld.IsBlob and not (LFld.DataType is TEFMemoDataType) then
          Continue;
        LRecFld := ARecord.FindField(LFld.AliasedName);
        if not Assigned(LRecFld) then
          Continue;
        if SBF.Length > 1 then
          SBF.Append(',');
        SBF.Append('"').Append(LFld.AliasedName).Append('":');
        if LRecFld.IsNull then
          SBF.Append('null')
        else if LFld.DataType is TEFBooleanDataType then
          SBF.Append(IfThen(LRecFld.AsBoolean, 'true', 'false'))
        else if LFld.DataType is TEFNumericDataTypeBase then
          SBF.Append(LRecFld.GetAsJSONValue(False, False))
        else
          SBF.Append(QuoteJSONValue(LRecFld.AsString));
      end;
      SBF.Append('}');
      Result := ' data-fields="' + TNetEncoding.HTML.Encode(SBF.ToString) + '"';
    finally
      SBF.Free;
    end;
  end;

  // Pre-scan: walks the store once and accumulates, per group, the record
  // count and every declared aggregate. One pass serves both, so adding
  // aggregates costs nothing on a view that only shows the count.
  procedure ScanGroups;
  var
    K, LAggIndex: Integer;
    LRec: TKViewTableRecord;
    LGrpField, LAggField: TKViewTableField;
    LGrpVal: string;
    LGroupAcc: TKGroupAccumulator;
  begin
    for K := 0 to AStore.RecordCount - 1 do
    begin
      LRec := AStore.Records[K];
      LGrpField := LRec.FindField(LGroupField.AliasedName);
      if Assigned(LGrpField) then
        LGrpVal := LGrpField.AsString
      else
        LGrpVal := '';
      J := LGroupCounts.IndexOf(LGrpVal);
      if J < 0 then
      begin
        LGroupAcc := TKGroupAccumulator.Create(Length(LAggregates));
        LGroupCounts.AddObject(LGrpVal, LGroupAcc);
      end
      else
        LGroupAcc := TKGroupAccumulator(LGroupCounts.Objects[J]);
      LGroupAcc.AddRecord;
      for LAggIndex := 0 to High(LAggregates) do
      begin
        LAggField := LRec.FindField(LAggregates[LAggIndex].ViewField.AliasedName);
        if Assigned(LAggField) and not LAggField.IsNull then
          LGroupAcc.AddValue(LAggIndex, LAggField.AsFloat);
      end;
    end;
  end;

begin
  LUserFmt := TKConfig.Instance.UserFormatSettings;
  LCurrSymbol := LUserFmt.CurrencyString;
  LHasRowClassProvider := AViewTable.GetExpandedString('Controller/RowClassProvider') <> '';

  // Read grouping config
  LStartCollapsed := False;
  LShowCount := False;
  LShowName := False;
  LItemName := '';
  LPluralItemName := '';
  if Assigned(AGroupingNode) then
  begin
    LStartCollapsed := AGroupingNode.GetBoolean('StartCollapsed', False);
    LShowCount := AGroupingNode.GetBoolean('ShowCount', False);
    LShowName := AGroupingNode.GetBoolean('ShowName', False);
    LItemName := AGroupingNode.GetString('ShowCount/ItemName', '');
    LPluralItemName := AGroupingNode.GetString('ShowCount/PluralItemName', '');
  end;
  ReadAggregates;

  LGroupField := AViewTable.FindField(AGroupingFieldName);
  if not Assigned(LGroupField) then
  begin
    // Fallback: render as regular rows if grouping field not found. The layout
    // must be passed here too, or the rows would not match the headers.
    Result := BuildDataRows(AStore, AViewTable, AViewName, AUrlViewName, ALayout);
    Exit;
  end;

  LFieldLabel := _(LGroupField.DisplayLabel);

  // Cell slots: the layout's nodes when a layout is in force, otherwise the
  // view table fields. Only the slots GetCellField accepts are rendered, so
  // the group header colspan is their count, not the slot count.
  if Assigned(ALayout) then
    LCellSlots := ALayout.ChildCount
  else
    LCellSlots := AViewTable.FieldCount;
  LColCount := 0;
  for I := 0 to LCellSlots - 1 do
    if GetCellField(I, LField, LLayoutNode) then
      Inc(LColCount);

  if AStore.RecordCount = 0 then
  begin
    Result := '<tr class="kx-list-empty"><td colspan="' + IntToStr(LColCount) + '">' +
      TNetEncoding.HTML.Encode(_('No records found.')) + '</td></tr>';
    Exit;
  end;

  // Pre-scan the store: needed by ShowCount and by the aggregates, and skipped
  // when neither is declared.
  LGroupCounts := TStringList.Create;
  LGroupCounts.OwnsObjects := True;
  try
    if LShowCount or (Length(LAggregates) > 0) then
      ScanGroups;

    // Find caption field for data-caption attribute
    LCaptionField := nil;
    if Assigned(AViewTable.Model) then
      LCaptionField := AViewTable.Model.FindCaptionField;

    SB := TStringBuilder.Create;
    SBKey := TStringBuilder.Create;
    try
      LPrevGroup := #1; // sentinel — never matches a real value
      LGroupIndex := -1;

      for I := 0 to AStore.RecordCount - 1 do
      begin
        LRecord := AStore.Records[I];

        // Read current group value
        LRecordField := LRecord.FindField(LGroupField.AliasedName);
        if Assigned(LRecordField) then
          LGroupValue := LRecordField.AsString
        else
          LGroupValue := '';

        // Emit group header when group changes
        if LGroupValue <> LPrevGroup then
        begin
          Inc(LGroupIndex);
          LPrevGroup := LGroupValue;

          // Determine toggle icon and display style based on StartCollapsed
          if LStartCollapsed then
          begin
            LToggleIcon := '&#x25B6;'; // ▶ (right = collapsed)
            LDisplayStyle := ' style="display:none"';
          end
          else
          begin
            LToggleIcon := '&#x25BC;'; // ▼ (down = expanded)
            LDisplayStyle := '';
          end;

          // Build header text
          LHeaderText := '';
          if LShowName then
            LHeaderText := TNetEncoding.HTML.Encode(LFieldLabel) + ': ';
          LHeaderText := LHeaderText + TNetEncoding.HTML.Encode(LGroupValue);

          // The accumulator of this group serves both the count and the
          // aggregates; it is absent only when neither was declared.
          J := LGroupCounts.IndexOf(LGroupValue);
          if J >= 0 then
            LAcc := TKGroupAccumulator(LGroupCounts.Objects[J])
          else
            LAcc := nil;

          // Append count if ShowCount
          if LShowCount and Assigned(LAcc) then
          begin
            LCountText := IntToStr(LAcc.Count);
            if LAcc.Count = 1 then
            begin
              if LItemName <> '' then
                LCountText := LCountText + ' ' + _(LItemName)
            end
            else
            begin
              if LPluralItemName <> '' then
                LCountText := LCountText + ' ' + _(LPluralItemName)
              else if LItemName <> '' then
                LCountText := LCountText + ' ' + _(LItemName);
            end;
            LHeaderText := LHeaderText + ' (' + TNetEncoding.HTML.Encode(LCountText) + ')';
          end;

          // Append the declared aggregates, in the order they appear in the
          // YAML. An aggregate with nothing to report - a column that is null
          // throughout the group - is left out rather than shown as zero,
          // which would read as a real total.
          if Assigned(LAcc) then
            for J := 0 to High(LAggregates) do
              if LAcc.TryGetResult(J, LAggregates[J].Operation, LAggValue) then
              begin
                LAggText := LAggregates[J].Caption + ': ' +
                  FormatAggregate(LAggregates[J], LAggValue);
                LHeaderText := LHeaderText + ' - ' + TNetEncoding.HTML.Encode(LAggText);
              end;

          // Emit group header row. data-fields is built from the first record
          // of the group (LRecord on the iteration where the group changed) so
          // the client-side RowClassProvider, if any, can assign the same class
          // to the header as to the data rows of this group.
          SB.Append('<tr class="kx-group-row" id="kx-grp-hdr-')
            .Append(AViewName).Append('-').Append(IntToStr(LGroupIndex))
            .Append('"');
          SB.Append(BuildRowDataFieldsAttr(LRecord));
          SB.Append(' onclick="kxGrid.toggleGroup(''')
            .Append(AViewName).Append(''',').Append(IntToStr(LGroupIndex)).Append(')">');
          SB.Append('<td colspan="').Append(IntToStr(LColCount)).Append('" class="kx-group-header">');
          SB.Append('<span class="kx-group-toggle">').Append(LToggleIcon).Append('</span>');
          SB.Append(LHeaderText);
          SB.Append('</td></tr>');
        end;

        // Build URL-encoded key string for row selection
        SBKey.Clear;
        for J := 0 to AViewTable.FieldCount - 1 do
        begin
          LField := AViewTable.Fields[J];
          if LField.IsKey then
          begin
            LRecordField := LRecord.FindField(LField.AliasedName);
            if Assigned(LRecordField) then
            begin
              if SBKey.Length > 0 then
                SBKey.Append('&amp;');
              SBKey.Append(TNetEncoding.HTML.Encode(TNetEncoding.URL.Encode(LField.AliasedName)));
              SBKey.Append('=');
              SBKey.Append(TNetEncoding.HTML.Encode(TNetEncoding.URL.Encode(LRecordField.AsString)));
            end;
          end;
        end;

        // Extract caption value
        LCaptionValue := '';
        if Assigned(LCaptionField) then
        begin
          LRecordField := LRecord.FindField(LCaptionField.FieldName);
          if Assigned(LRecordField) and not LRecordField.IsNull then
            LCaptionValue := LRecordField.AsString;
        end;

        // Emit data row with group class and conditional display
        SB.Append('<tr class="kx-group-data kx-grp-').Append(AViewName).Append('-').Append(IntToStr(LGroupIndex)).Append('"');
        SB.Append(LDisplayStyle);
        SB.Append(' data-key="').Append(SBKey.ToString).Append('"');
        SB.Append(' data-caption="').Append(TNetEncoding.HTML.Encode(LCaptionValue)).Append('"');
        SB.Append(BuildRowDataFieldsAttr(LRecord));
        SB.Append(' onclick="kxGrid.select(this,''').Append(AViewName).Append(''')"');
        SB.Append(' ondblclick="kxGrid.rowDblClick(this,''').Append(AViewName).Append(''')">');

        // Render cells (same logic as BuildDataRows)
        for J := 0 to LCellSlots - 1 do
        begin
          if not GetCellField(J, LField, LLayoutNode) then
            Continue;

          // Align override from the layout node, as in BuildDataRows.
          if Assigned(LLayoutNode) and (LLayoutNode.GetString('Align') <> '') then
            LAlign := LLayoutNode.GetString('Align')
          else
            LAlign := LField.DataType.GetDefaultColumnAlignment;
          LIsBool := LField.DataType is TEFBooleanDataType;
          LIsDateTime := LField.DataType is TEFDateTimeDataTypeBase;
          LIsCurrency := LField.DataType is TEFCurrencyDataType;

          LRecordField := LRecord.FindField(LField.AliasedName);
          if Assigned(LRecordField) then
          begin
            if LIsBool then
            begin
              if LRecordField.AsBoolean then
                LChecked := ' checked'
              else
                LChecked := '';
              SB.Append('<td style="text-align:center"><input type="checkbox" disabled');
              SB.Append(LChecked).Append('></td>');
            end
            else if LIsDateTime then
            begin
              LValue := LField.DataType.NodeToJSONValue(True, LRecordField, LUserFmt, False);
              if SameText(LValue, 'null') then
                LValue := '';
              SB.Append('<td style="text-align:').Append(LAlign).Append('"');
              if LValue <> '' then
                SB.Append(' data-full="').Append(TNetEncoding.HTML.Encode(LValue)).Append('"');
              SB.Append('>').Append(TNetEncoding.HTML.Encode(LValue)).Append('</td>');
            end
            else if LIsCurrency then
            begin
              LValue := LField.DataType.NodeToJSONValue(True, LRecordField, LUserFmt, False);
              if SameText(LValue, 'null') then
                LValue := '';
              if (LValue <> '') and (LCurrSymbol <> '') then
                LValue := LCurrSymbol + ' ' + LValue;
              SB.Append('<td style="text-align:right"');
              if LValue <> '' then
                SB.Append(' data-full="').Append(TNetEncoding.HTML.Encode(LValue)).Append('"');
              SB.Append('>').Append(TNetEncoding.HTML.Encode(LValue)).Append('</td>');
            end
            else
            begin
              LValue := LRecordField.GetAsJSONValue(True, False);
              if SameText(LValue, 'null') then
                LValue := '';
              SB.Append('<td style="text-align:').Append(LAlign).Append('"');
              // Same treatment a plain List gives these fields
              // (Kitto.Html.List.pas, BuildDataRows): an HTMLMemo carries
              // trusted markup, so it is emitted as is and gets no tooltip -
              // the tooltip would show the raw tags.
              if (LValue <> '') and not (LField.DataType is TKHTMLMemoDataType) then
                SB.Append(' data-full="').Append(TNetEncoding.HTML.Encode(LValue)).Append('"');
              SB.Append('>');
              if LField.DataType is TKHTMLMemoDataType then
                SB.Append(LValue)
              else
                SB.Append(TNetEncoding.HTML.Encode(LValue));
              SB.Append('</td>');
            end;
          end
          else
            SB.Append('<td></td>');
        end;
        SB.Append('</tr>');
      end;

      Result := SB.ToString;
    finally
      SBKey.Free;
      SB.Free;
    end;
  finally
    LGroupCounts.Free;
  end;
end;

initialization
  TKXControllerRegistry.Instance.RegisterClass('GroupingList', TKXGroupingListController);

end.
