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
///  View builders that auto-generate a data view from a model at runtime: a
///  list view (TKAutoListViewBuilder) and a form view (TKAutoFormViewBuilder),
///  registered as 'AutoList' and 'AutoForm'. Used when a view is referenced
///  through a 'Build ...' expression instead of a YAML file.
/// </summary>
unit Kitto.Metadata.ViewBuilders;

{$I Kitto.Defines.inc}

interface

uses
  EF.Tree,
  Kitto.Metadata.Models,
  Kitto.Metadata.Views,
  Kitto.Metadata.DataView;

type
  /// <summary>
  ///  Base class for the auto view builders. Builds a data view for a model,
  ///  adding all fields, detail tables and a free-search filter; descendants
  ///  supply the controller type and any view customization.
  /// </summary>
  TKAutoViewBuilderBase = class(TKViewBuilder)
  strict private
    function BuildSearchString(const AFields: TKViewFields): string;
    /// <summary>
    ///  Gives AViewTable its Fields node. ASourceFields, when passed, is a
    ///  Fields node the caller already has and wins over the list generated
    ///  from AModel; it must be passed per table, never looked up from the
    ///  builder's configuration, or the main table's fields would be applied to
    ///  every nested detail table as well.
    /// </summary>
    procedure AddFields(const AViewTable: TKViewTable; const AModel: TKModel;
      const ASourceFields: TEFNode = nil);
    procedure AddDetailTables(const AViewTable: TKViewTable;
      const AModel: TKModel);
  strict protected
    function GetControllerType: string; virtual; abstract;
    function GetModel: TKModel;
    procedure CustomizeView(const AView: TKView); virtual;
  public
    /// <summary>Builds and returns the data view for the configured model.</summary>
    function BuildView(const AViews: TKViews;
      const APersistentName: string = '';
      const ANode: TEFNode = nil): TKView; override;
  end;

  /// <summary>Auto view builder that produces a List (grid) view. Registered as 'AutoList'.</summary>
  TKAutoListViewBuilder = class(TKAutoViewBuilderBase)
  strict protected
    function GetControllerType: string; override;
  end;

  /// <summary>Auto view builder that produces a Form view (in Add mode). Registered as 'AutoForm'.</summary>
  TKAutoFormViewBuilder = class(TKAutoViewBuilderBase)
  strict protected
    function GetControllerType: string; override;
    procedure CustomizeView(const AView: TKView); override;
  end;

implementation

uses
  System.SysUtils,
  EF.Localization,
  Kitto.Config;

{ TKAutoViewBuilderBase }

procedure TKAutoViewBuilderBase.AddFields(const AViewTable: TKViewTable;
  const AModel: TKModel; const ASourceFields: TEFNode);
var
  LFields: TKViewFields;
  I: Integer;
begin
  Assert(Assigned(AViewTable), 'Assigned(AViewTable)');
  Assert(Assigned(AModel), 'Assigned(AModel)');

  LFields := AViewTable.AddChild(TKViewFields.Create('Fields')) as TKViewFields;

  // The case that needs this is a detail table declared under
  // DetailTables/Table in a master view with no ViewName of its own: that node
  // is the only place carrying what the master view says about those columns --
  // IsVisible, DisplayLabel, DisplayWidth, the order they appear in -- and
  // rebuilding the list from the model discards all of it.
  //
  // Assign, not TEFNode.Clone: Clone is a (virtual) constructor, so calling it
  // on TEFNode yields plain TEFNodes, while TKViewFields must hold TKViewField
  // children -- BuildView casts this very node to TKViewFields. Assign creates
  // each child through the destination's GetChildClass.
  if Assigned(ASourceFields) and (ASourceFields.ChildCount > 0) then
    LFields.Assign(ASourceFields)
  else
    for I := 0 to AModel.FieldCount - 1 do
      LFields.AddChild(TKViewField.Create(AModel.Fields[I].FieldName));
end;

procedure TKAutoViewBuilderBase.AddDetailTables(const AViewTable: TKViewTable;
  const AModel: TKModel);
var
  I: Integer;
  LDetailTable: TKViewTable;
begin
  Assert(Assigned(AViewTable), 'Assigned(AViewTable)');
  Assert(Assigned(AModel), 'Assigned(AModel)');

  for I := 0 to AModel.DetailReferenceCount - 1 do
  begin
    LDetailTable := TKViewTable.Create;
    try
      LDetailTable.Name := 'Table';
      LDetailTable.SetString('Model', AModel.DetailReferences[I].DetailModel.ModelName);
      AViewTable.AddDetailTable(LDetailTable);
      AddFields(LDetailTable, LDetailTable.Model);
      AddDetailTables(LDetailTable, LDetailTable.Model);
    except
      FreeAndNil(LDetailTable);
    end;
  end;
end;

function TKAutoViewBuilderBase.BuildView(const AViews: TKViews;
  const APersistentName: string; const ANode: TEFNode): TKView;
var
  LMainTable: TKViewTable;
  LModel: TKModel;
  LFilters: TEFNode;
  LFilterItems: TEFNode;
  LSearchItem: TEFNode;
  LSourceControllerNode: TEFNode;
  LSourceMainTableControllerNode: TEFNode;
  LSourceDisplayLabelNode: TEFNode;
  LControllerNode: TEFNode;
  LResourceName: TEFNode;
begin
  inherited;
  LModel := GetModel;
  Result := TKDataView.Create;
  try
    Result.SetString('Type', 'Data');
    if APersistentName <> '' then
    begin
      Result.PersistentName := APersistentName;
      AViews.AddObject(Result);
    end
    else if ANode <> nil then
      AViews.AddNonpersistentObject(Result, ANode);

    LResourceName := FindNode('ResourceName');
    if Assigned(LResourceName) then
      Result.SetString('ResourceName', LResourceName.AsString);

    if TKConfig.Instance.UseAltLanguage then
    begin
      LSourceDisplayLabelNode := FindNode('DisplayLabel2');
      if Assigned(LSourceDisplayLabelNode) then
        Result.SetString('DisplayLabel2', LSourceDisplayLabelNode.AsString);
    end
    else
    begin
      LSourceDisplayLabelNode := FindNode('DisplayLabel');
      if Assigned(LSourceDisplayLabelNode) then
        Result.SetString('DisplayLabel', LSourceDisplayLabelNode.AsString);
    end;

    LSourceControllerNode := FindNode('Controller');
    if Assigned(LSourceControllerNode) then
      Result.AddChild(TEFNode.Clone(LSourceControllerNode));
    LControllerNode := Result.SetString('Controller', GetControllerType);

    LMainTable := Result.AddChild(TKViewTable.Create('MainTable')) as TKViewTable;
    LMainTable.SetString('Model', LModel.ModelName);

    // MainTable/Fields, when declared, wins over the list generated from the
    // model. See AddFields.
    AddFields(LMainTable, LModel, FindNode('MainTable/Fields'));
    AddDetailTables(LMainTable, LModel);

    LFilters := LControllerNode.AddChild('Filters');
    if TKConfig.Instance.UseAltLanguage then
      LFilters.SetString('DisplayLabel2', _(Format(_('Search %s'), [LModel.PluralDisplayLabel])))
    else
      LFilters.SetString('DisplayLabel', _(Format(_('Search %s'), [LModel.PluralDisplayLabel])));
    LFilterItems := LFilters.AddChild('Items');
    LSearchItem := LFilterItems.AddChild('FreeSearch', _('Free Search'));
    LSearchItem.SetString('ExpressionTemplate', BuildSearchString(
      LMainTable.ChildByName('Fields') as TKViewFields));

    LSourceMainTableControllerNode := FindNode('MainTable/Controller');
    if Assigned(LSourceMainTableControllerNode) then
      {LMainTableController := }LMainTable.AddChild(TEFNode.Clone(LSourceMainTableControllerNode))
    else
      {LMainTableController := }LMainTable.AddChild('Controller');
    CustomizeView(Result);
  except
    if APersistentName <> '' then
      AViews.RemoveObject(Result)
    else if ANode <> nil then
      AViews.DeleteNonpersistentObject(ANode);
    FreeAndNil(Result);
    raise;
  end;
end;

procedure TKAutoViewBuilderBase.CustomizeView(const AView: TKView);
begin
end;

function TKAutoViewBuilderBase.BuildSearchString(const AFields: TKViewFields): string;
var
  I: Integer;
begin
  Assert(Assigned(AFields), 'Assigned(AFields)');

  Result := '';
  for I := 0 to AFields.FieldCount - 1 do
  begin
    if AFields[I].IsVisible and AFields[I].DataType.IsText then
    begin
      if Result = '' then
        Result := '(' + AFields[I].QualifiedDBName + ' like ''%{value}%'')'
      else
        Result := Result + ' or (' + AFields[I].QualifiedDBName + ' like ''%{value}%'')';
    end;
  end;
end;

function TKAutoViewBuilderBase.GetModel: TKModel;
begin
  Assert(Assigned(Views), 'Assigned(Views)');
  Assert(Assigned(Views.Models), 'Assigned(Views.Models)');

  Result := Views.Models.ModelByName(GetString('Model'));
end;

{ TKAutoListViewBuilder }

function TKAutoListViewBuilder.GetControllerType: string;
begin
  Result := 'List';
end;

{ TKAutoFormViewBuilder }

procedure TKAutoFormViewBuilder.CustomizeView(const AView: TKView);
begin
  inherited;
  AView.SetString('Controller/Operation', 'Add');
end;

function TKAutoFormViewBuilder.GetControllerType: string;
begin
  Result := 'Form';
end;

initialization
  TKViewBuilderRegistry.Instance.RegisterClass('AutoList', TKAutoListViewBuilder);
  TKViewBuilderRegistry.Instance.RegisterClass('AutoForm', TKAutoFormViewBuilder);

finalization
  TKViewBuilderRegistry.Instance.UnregisterClass('AutoList');
  TKViewBuilderRegistry.Instance.UnregisterClass('AutoForm');

end.
