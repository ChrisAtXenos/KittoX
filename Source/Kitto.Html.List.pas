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
///  KittoX List controller — the data-list host: a filterable list of records
///  (filter panel, lookup mode, action flags) shown by the presenters hosted in
///  its regions. The Center presenter is the grid by default
///  (TKXGridPanelController, 'GridPanel'), or whatever CenterController names
///  (ChartPanel, CalendarPanel, ...); a WestController/EastController adds a
///  presenter beside it on the same data; TemplateFileName selects the card
///  presentation. Replaces TKExtListPanelController from Kitto.Ext.List.
/// </summary>
unit Kitto.Html.List;

{$I Kitto.Defines.inc}

interface

uses
  System.Types,
  EF.Tree,
  EF.YAML.Attributes,
  Kitto.Metadata.Types,
  Kitto.Html.DataPanel,
  Kitto.Html.Controller,
  Kitto.Html.Filters,
  Kitto.Metadata.Views,
  Kitto.Metadata.DataView;

type
  /// <summary>
  ///  Data list host: owns the list of records that can be filtered (filter
  ///  panel, lookup mode, action flags) and hosts the presenters that show it.
  ///  Its default Center presenter is TKXGridPanelController ('GridPanel',
  ///  Kitto.Html.GridPanel): "Controller: List" alone renders a grid, and a
  ///  CenterController node without a value (only options) is back-filled with
  ///  it; the card presentation is selected via TemplateFileName. The grid
  ///  helpers live on GridPanel, the shared ones (filters, toolbar, pager,
  ///  hidden state) on TKXDataPanelController.
  /// </summary>
  {$RTTI EXPLICIT PROPERTIES([vcPublic])}
  TKXListPanelController = class(TKXDataPanelCompositeController)
  strict private
    function GetTemplateFileName: string;
    function GetAllowMultipleInstances: Boolean;
  strict protected
    function GetPanelCssClass: string; override;
    function GetRegionDefaultControllerClass(const ARegionName: string): string; override;
    function RenderContent: string; override;
  public
    [YamlNode('TemplateFileName', 'HTML template file for the list (relative to the app resources)')]
    property TemplateFileName: string read GetTemplateFileName;
    [YamlNode('AllowMultipleInstances', 'False', 'Allow opening more than one instance (tab) of this view at once')]
    property AllowMultipleInstances: Boolean read GetAllowMultipleInstances;
  end;

implementation

uses
  System.SysUtils,
  System.Classes,
  System.StrUtils,
  System.Math,
  System.NetEncoding,
  Data.DB,
  EF.DB,
  EF.Localization,
  EF.Types,
  Kitto.Config,
  Kitto.Store,
  Kitto.Html.Base,
  Kitto.Html.Editors,
  Kitto.Html.Utils,
  Kitto.Html.Tools,
  Kitto.Metadata.Models,
  Kitto.Web.Request,
  Kitto.Web.Session,
  Kitto.Html.TemplateDataPanel,
  EF.Macros,
  EF.JSON;

{ TKXListPanelController }

function TKXListPanelController.GetPanelCssClass: string;
begin
  // The Center presenter's class when there is one (grid, chart, calendar);
  // the list's own for the card presentation.
  Result := inherited GetPanelCssClass;
  if Result = '' then
    Result := 'kx-list-panel';
end;

function TKXListPanelController.GetRegionDefaultControllerClass(
  const ARegionName: string): string;
begin
  // The one place that says "a List shows a grid unless told otherwise".
  if SameText(ARegionName, 'Center') then
    Result := 'GridPanel'
  else
    Result := inherited GetRegionDefaultControllerClass(ARegionName);
end;

function TKXListPanelController.GetTemplateFileName: string;
begin
  Result := GetConfigString('TemplateFileName');
end;

function TKXListPanelController.GetAllowMultipleInstances: Boolean;
begin
  Result := Config.GetBoolean('AllowMultipleInstances', False);
end;

function TKXListPanelController.RenderContent: string;
var
  LDataView: TKDataView;
  LViewTable: TKViewTable;
  LStore: TKViewTableStore;
  LTotal: Integer;
  LPageSize: Integer;
  LViewName: string;
  LViewAlias: string;
  LUrlViewName: string;
  LIsLookup: Boolean;
  LFilterPanelHtml: string;
  LDefaultFilterExpr: string;
  LTemplateFile: string;
  LSortExpr: string;
  LSortFieldNames: TStringDynArray;
  LPagingTools: Boolean;
  LAutoOpen: Boolean;
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

  // Detect lookup mode (set by HandleKXLookupRequest via query param)
  LIsLookup := SameText(TKWebRequest.Current.GetQueryField('mode'), 'lookup');
  if LIsLookup then
  begin
    LViewAlias := 'lkp_' + LViewName;
    LUrlViewName := LViewName;
  end
  else
  begin
    LViewAlias := LViewName;
    LUrlViewName := '';  // empty = use AViewName for URLs (backward compat)
  end;

  // IsLarge drives the defaults:
  //   PagingTools default = IsLarge
  //   AutoOpen     default = not IsLarge
  // When AutoOpen is False the grid does not auto-load; user applies a filter
  // or clicks Refresh to populate it.
  LPagingTools := LViewTable.GetBoolean('Controller/PagingTools', LViewTable.IsLarge);
  LAutoOpen := LViewTable.GetBoolean('Controller/AutoOpen', not LViewTable.IsLarge);

  // Card presentation when TemplateFileName is given
  LTemplateFile := Config.GetString('TemplateFileName');
  if LTemplateFile <> '' then
  begin

    // Build filter panel (if Filters/Items defined)
    LFilterPanelHtml := BuildFilterPanel(LViewAlias, LViewTable,
      LDefaultFilterExpr, LUrlViewName);

    // Build sort expression from MainTable/Controller/SortFieldNames
    LSortExpr := '';
    begin
      LSortFieldNames := LViewTable.GetStringArray('Controller/SortFieldNames');
      if Length(LSortFieldNames) > 0 then
      begin
        var J: Integer;
        for J := Low(LSortFieldNames) to High(LSortFieldNames) do
          LSortFieldNames[J] := LViewTable.FieldByName(LSortFieldNames[J]).QualifiedDBNameOrExpression;
        LSortExpr := string.Join(', ', LSortFieldNames);
      end;
    end;

    // Paging: only when PagingTools is enabled
    if LPagingTools then
      LPageSize := LViewTable.GetInteger('Controller/PagingTools/PageRecordCount', DEFAULT_PAGE_RECORD_COUNT)
    else
      LPageSize := 0;

    LStore := LViewTable.CreateStore;
    try
      // AutoOpen=False (default when IsLarge=True) skips the initial load —
      // user populates the grid by applying a filter or clicking Refresh.
      if LAutoOpen then
        LTotal := LStore.Load(CombineWhere(LDefaultFilterExpr, GetLookupContextFilter), LSortExpr, 0, LPageSize)
      else
        LTotal := 0;

      SB := TStringBuilder.Create;
      try
        // Filter panel
        SB.Append(LFilterPanelHtml);

        // Toolbar (CRUD buttons)
        SB.Append(BuildToolbar(LViewAlias, LUrlViewName));

        // Card container (replaces grid table)
        SB.Append('<div class="kx-template-content" id="kx-list-body-')
          .Append(LViewAlias).Append('"');
        // See the grid branch below: in lookup mode a double click selects.
        if LIsLookup then
          SB.Append(' data-dblclick="select"')
        else if IsActionVisible('Edit') and IsActionAllowed('Edit') then
          SB.Append(' data-dblclick="edit"')
        else if IsActionVisible('View') then
          SB.Append(' data-dblclick="view"');
        SB.Append('>');
        SB.Append(TKXTemplateDataPanelController.BuildSelectableCards(
          LStore, LViewTable, Config, LViewAlias));
        SB.Append('</div>');

        // Pager (only when PagingTools is enabled)
        if LPagingTools then
          SB.Append(BuildPager(LViewAlias, LTotal, 0, LPageSize, LUrlViewName));

        // Hidden state
        SB.Append(BuildHiddenState(LViewAlias, LPageSize, '', '', LUrlViewName));

        Result := SB.ToString;
      finally
        SB.Free;
      end;
    finally
      FreeAndNil(LStore);
    end;
    Exit;
  end;

  // Standard presentation: the host renders its filter panel and then the
  // Center presenter, bare, inside this panel's chrome -- the grid by default
  // (GetRegionDefaultControllerClass), or the CenterController the view names.
  Result := inherited RenderContent;
end;

initialization
  TKXControllerRegistry.Instance.RegisterClass('List', TKXListPanelController);

end.
