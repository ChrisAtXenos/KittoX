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

unit Kitto.Config.Defaults;

{$I Kitto.Defines.inc}

interface

uses
  EF.YAML.Attributes,
  Kitto.Config.Reader;

type
  /// <summary>Help-link defaults. YAML path: Defaults/Help</summary>
  TKDefaultsHelpConfig = class(TKConfigReader)
  private
    FHRef: string;
    FHRefStyle: string;
    FShortText: string;
    FLongText: string;
  protected
    procedure ReadConfig; override;
  public
    [YamlNode('HRef', 'Help hyperlink URL (empty = no help link)')]
    property HRef: string read FHRef;

    [YamlNode('HRefStyle', 'font-size: small', 'CSS style for the help link')]
    property HRefStyle: string read FHRefStyle;

    [YamlNode('ShortText', '', 'Short help link text', True)]
    property ShortText: string read FShortText;

    [YamlNode('LongText', '', 'Long help link text / tooltip', True)]
    property LongText: string read FLongText;
  end;

  /// <summary>UI spacing defaults. YAML path: Defaults/Spacing</summary>
  TKDefaultsSpacingConfig = class(TKConfigReader)
  private
    FSingle: Integer;
    FDouble: Integer;
  protected
    procedure ReadConfig; override;
  public
    [YamlNode('Single', '10', 'Single spacing (pixels)')]
    property SingleSpacing: Integer read FSingle;

    [YamlNode('Double', '20', 'Double spacing (pixels)')]
    property DoubleSpacing: Integer read FDouble;
  end;

  /// <summary>Form panel defaults. YAML path: Defaults/FormPanel</summary>
  TKDefaultsFormPanelConfig = class(TKConfigReader)
  private
    FLabelWidth: Integer;
    FHideLabels: Boolean;
  protected
    procedure ReadConfig; override;
  public
    [YamlNode('LabelWidth', 'Default form label width (pixels)')]
    property LabelWidth: Integer read FLabelWidth;

    [YamlNode('HideLabels', 'False', 'Hide field labels in form layouts by default')]
    property HideLabels: Boolean read FHideLabels;
  end;

  /// <summary>Layout defaults. YAML path: Defaults/Layout</summary>
  TKDefaultsLayoutConfig = class(TKConfigReader)
  private
    FMemoWidth: Integer;
    FMaxFieldWidth: Integer;
    FMinFieldWidth: Integer;
    FRequiredLabelTemplate: string;
    FLabelSeparator: string;
    FCharWidthFactor: string;
    FCharHeightFactor: string;
  protected
    procedure ReadConfig; override;
  public
    [YamlNode('Char_Width_Factor', 'Pixels-per-character factor used to convert character widths to pixels')]
    property CharWidthFactor: string read FCharWidthFactor;

    [YamlNode('Char_Height_Factor', 'Pixels-per-line factor used to convert character heights to pixels')]
    property CharHeightFactor: string read FCharHeightFactor;

    [YamlNode('MemoWidth', '60', 'Default width in characters for memo fields')]
    property MemoWidth: Integer read FMemoWidth;

    [YamlNode('MaxFieldWidth', '60', 'Maximum field width in characters')]
    property MaxFieldWidth: Integer read FMaxFieldWidth;

    [YamlNode('MinFieldWidth', '5', 'Minimum field width in characters')]
    property MinFieldWidth: Integer read FMinFieldWidth;

    [YamlNode('RequiredLabelTemplate', '<b>{label}*</b>', 'HTML template for required field labels')]
    property RequiredLabelTemplate: string read FRequiredLabelTemplate;

    [YamlNode('LabelSeparator', ':', 'String appended after field labels (empty to hide it)')]
    property LabelSeparator: string read FLabelSeparator;
  end;

  /// <summary>Popup window size defaults. YAML path: Defaults/Window</summary>
  TKDefaultsWindowConfig = class(TKConfigReader)
  private
    FWidth: Integer;
    FHeight: Integer;
  protected
    procedure ReadConfig; override;
  public
    [YamlNode('Width', '0', 'Default popup window width (pixels; 0 = auto)')]
    property Width: Integer read FWidth;

    [YamlNode('Height', '0', 'Default popup window height (pixels; 0 = auto)')]
    property Height: Integer read FHeight;
  end;

  /// <summary>Grid defaults. YAML path: Defaults/Grid</summary>
  /// <example>
  ///  Defaults:
  ///    Grid:
  ///      PageRecordCount: 100
  ///      DefaultAction: Edit
  /// </example>
  TKDefaultsGridConfig = class(TKConfigReader)
  private
    FPageRecordCount: Integer;
    FDefaultAction: string;
  protected
    procedure ReadConfig; override;
  public
    [YamlNode('PageRecordCount', '100', 'Number of records per grid page')]
    property PageRecordCount: Integer read FPageRecordCount;

    [YamlNode('DefaultAction', 'Edit', 'Default action on grid row double-click')]
    property DefaultAction: string read FDefaultAction;
  end;

  /// <summary>
  ///  Application-wide UI defaults from Config.yaml.
  ///  YAML path: Defaults
  /// </summary>
  TKDefaultsConfig = class(TKConfigReader)
  private
    FAlwaysNotifyChange: Boolean;
    FHelp: TKDefaultsHelpConfig;
    FSpacing: TKDefaultsSpacingConfig;
    FFormPanel: TKDefaultsFormPanelConfig;
    FWindow: TKDefaultsWindowConfig;
    FGrid: TKDefaultsGridConfig;
    FLayout: TKDefaultsLayoutConfig;
  protected
    procedure ReadConfig; override;
  public
    destructor Destroy; override;

    [YamlNode('AlwaysNotifyChange', 'False', 'Fire change notifications for every field edit')]
    property AlwaysNotifyChange: Boolean read FAlwaysNotifyChange;

    [YamlSubNode('Help', TKDefaultsHelpConfig, 'Help link defaults (HRef, texts, style)')]
    property Help: TKDefaultsHelpConfig read FHelp;

    [YamlSubNode('Spacing', TKDefaultsSpacingConfig, 'UI spacing defaults (Single, Double)')]
    property Spacing: TKDefaultsSpacingConfig read FSpacing;

    [YamlSubNode('FormPanel', TKDefaultsFormPanelConfig, 'Form panel defaults (LabelWidth)')]
    property FormPanel: TKDefaultsFormPanelConfig read FFormPanel;

    [YamlSubNode('Window', TKDefaultsWindowConfig, 'Popup window size defaults (Width, Height)')]
    property Window: TKDefaultsWindowConfig read FWindow;

    [YamlSubNode('Grid', TKDefaultsGridConfig, 'Grid defaults (PageRecordCount, DefaultAction)')]
    property Grid: TKDefaultsGridConfig read FGrid;

    [YamlSubNode('Layout', TKDefaultsLayoutConfig, 'Layout defaults (MemoWidth, field widths, label template/separator)')]
    property Layout: TKDefaultsLayoutConfig read FLayout;
  end;

  TKDefaults = class
  public
    /// <summary>Default single spacing (in pixels) used for UI layout gaps.</summary>
    class function GetSingleSpacing: Integer;
    /// <summary>Default double spacing (in pixels) used for UI layout gaps.</summary>
    class function GetDoubleSpacing: Integer;
  end;

implementation

uses
  Kitto.Config;

{ TKDefaultsHelpConfig }

procedure TKDefaultsHelpConfig.ReadConfig;
begin
  FHRef := GetString('HRef');
  FHRefStyle := GetString('HRefStyle', 'font-size: small');
  FShortText := GetString('ShortText');
  FLongText := GetString('LongText');
end;

{ TKDefaultsSpacingConfig }

procedure TKDefaultsSpacingConfig.ReadConfig;
begin
  FSingle := GetInteger('Single', 10);
  FDouble := GetInteger('Double', FSingle * 2);
end;

{ TKDefaultsFormPanelConfig }

procedure TKDefaultsFormPanelConfig.ReadConfig;
begin
  FLabelWidth := GetInteger('LabelWidth', 0);
  FHideLabels := GetBoolean('HideLabels', False);
end;

{ TKDefaultsLayoutConfig }

procedure TKDefaultsLayoutConfig.ReadConfig;
begin
  FMemoWidth := GetInteger('MemoWidth', 60);
  FMaxFieldWidth := GetInteger('MaxFieldWidth', 60);
  FMinFieldWidth := GetInteger('MinFieldWidth', 5);
  FRequiredLabelTemplate := GetString('RequiredLabelTemplate', '<b>{label}*</b>');
  FLabelSeparator := GetString('LabelSeparator', ':');
  FCharWidthFactor := GetString('Char_Width_Factor');
  FCharHeightFactor := GetString('Char_Height_Factor');
end;

{ TKDefaultsWindowConfig }

procedure TKDefaultsWindowConfig.ReadConfig;
begin
  FWidth := GetInteger('Width', 0);
  FHeight := GetInteger('Height', 0);
end;

{ TKDefaultsGridConfig }

procedure TKDefaultsGridConfig.ReadConfig;
begin
  FPageRecordCount := GetInteger('PageRecordCount', 100);
  FDefaultAction := GetString('DefaultAction', 'Edit');
end;

{ TKDefaultsConfig }

procedure TKDefaultsConfig.ReadConfig;
begin
  FAlwaysNotifyChange := GetBoolean('AlwaysNotifyChange', False);
  // Nested readers (nil-safe when the subtree is absent).
  if FHelp = nil then
    FHelp := TKDefaultsHelpConfig.Create(SubNode('Help'))
  else
    FHelp.Refresh(SubNode('Help'));
  if FSpacing = nil then
    FSpacing := TKDefaultsSpacingConfig.Create(SubNode('Spacing'))
  else
    FSpacing.Refresh(SubNode('Spacing'));
  if FFormPanel = nil then
    FFormPanel := TKDefaultsFormPanelConfig.Create(SubNode('FormPanel'))
  else
    FFormPanel.Refresh(SubNode('FormPanel'));
  if FWindow = nil then
    FWindow := TKDefaultsWindowConfig.Create(SubNode('Window'))
  else
    FWindow.Refresh(SubNode('Window'));
  if FGrid = nil then
    FGrid := TKDefaultsGridConfig.Create(SubNode('Grid'))
  else
    FGrid.Refresh(SubNode('Grid'));
  if FLayout = nil then
    FLayout := TKDefaultsLayoutConfig.Create(SubNode('Layout'))
  else
    FLayout.Refresh(SubNode('Layout'));
end;

destructor TKDefaultsConfig.Destroy;
begin
  FHelp.Free;
  FSpacing.Free;
  FFormPanel.Free;
  FWindow.Free;
  FGrid.Free;
  FLayout.Free;
  inherited;
end;

{ TKDefaults }

class function TKDefaults.GetDoubleSpacing: Integer;
begin
  Result := TKConfig.Instance.Config.GetInteger('Defaults/Spacing/Double', GetSingleSpacing * 2);
end;

class function TKDefaults.GetSingleSpacing: Integer;
begin
  Result := TKConfig.Instance.Config.GetInteger('Defaults/Spacing/Single', 10);
end;

end.
