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
///  Sub-node classes for YAML config blocks with a fixed set of properties.
///  Each class represents a single named YAML node that contains configuration
///  values (not a collection of N children). Properties are decorated with
///  YAML attributes for KIDE RTTI discovery.
/// </summary>
unit Kitto.Metadata.SubNodes;

{$I Kitto.Defines.inc}

interface

uses
  EF.Tree,
  EF.YAML.Attributes,
  Kitto.Metadata.Types;

type
  // NB: TKHTMLEditorConfig, TKThumbnailConfig, TKPreviewWindowConfig moved to
  // Kitto.Metadata.Models (descriptor next to consumer).

  /// <summary>
  ///  Global form layout defaults read from Config.yaml ? Defaults/Layout.
  ///  YAML path: Defaults/Layout
  /// </summary>
  /// <example>
  ///  Defaults:
  ///    Layout:
  ///      MemoWidth: 60
  ///      MaxFieldWidth: 60
  ///      MinFieldWidth: 5
  ///      Char_Width_Factor: 0.85
  ///      Char_Height_Factor: 0.8
  ///      RequiredLabelTemplate: <b>{label}*</b>
  ///      LabelSeparator: ": "
  /// </example>
  TKLayoutDefaultsConfig = class(TEFNode)
  private
    function GetMemoWidth: Integer;
    function GetMaxFieldWidth: Integer;
    function GetMinFieldWidth: Integer;
    function GetCharWidthFactor: Double;
    function GetCharHeightFactor: Double;
    function GetRequiredLabelTemplate: string;
    function GetLabelSeparator: string;
  public
    [YamlNode('MemoWidth', '60', 'Default width in characters for memo fields')]
    property MemoWidth: Integer read GetMemoWidth;

    [YamlNode('MaxFieldWidth', '60', 'Maximum field width in characters')]
    property MaxFieldWidth: Integer read GetMaxFieldWidth;

    [YamlNode('MinFieldWidth', '5', 'Minimum field width in characters')]
    property MinFieldWidth: Integer read GetMinFieldWidth;

    [YamlNode('Char_Width_Factor', '1.0', 'Multiplier for field widths in ch units')]
    property CharWidthFactor: Double read GetCharWidthFactor;

    [YamlNode('Char_Height_Factor', '1.0', 'Multiplier for HTMLMemo editor heights')]
    property CharHeightFactor: Double read GetCharHeightFactor;

    [YamlNode('RequiredLabelTemplate', '<b>{label}*</b>',
      'HTML template for required field labels ({label} is replaced)')]
    property RequiredLabelTemplate: string read GetRequiredLabelTemplate;

    [YamlNode('LabelSeparator', ': ', 'String appended after field labels')]
    property LabelSeparator: string read GetLabelSeparator;
  end;

  /// <summary>
  ///  Login form local storage options.
  ///  YAML path: Controller/LocalStorage
  /// </summary>
  /// <example>
  ///  LocalStorage:
  ///    Mode: Password
  ///    AskUser: True
  ///    AutoLogin: False
  /// </example>
  TKLocalStorageConfig = class(TEFNode)
  private
    function GetMode: string;
    function GetAskUser: Boolean;
    function GetAutoLogin: Boolean;
    function GetAskUserDefault: Boolean;
  public
    [YamlNode('Mode', '', 'Credentials to store: empty, UserName, or Password')]
    [YamlEnumType(TypeInfo(TKLocalStorageMode))]
    property Mode: string read GetMode;

    [YamlNode('AskUser', 'False', 'Show checkbox asking user to enable local storage')]
    property AskUser: Boolean read GetAskUser;

    [YamlNode('AutoLogin', 'False', 'Automatically submit login if credentials are stored')]
    property AutoLogin: Boolean read GetAutoLogin;

    [YamlNode('AskUser/Default', 'True', 'Default state of the AskUser checkbox')]
    property AskUserDefault: Boolean read GetAskUserDefault;
  end;

  // NB: TKFilterPanelConfig moved to Kitto.Metadata.DataView (Filter panel descriptor).

  // NB: TKChartLegendConfig moved to Kitto.Html.ChartPanel (with the Chart cluster).

  // NB: the Server config schema (TKServerConfig + TKJobsConfig + TKCORSConfig)
  // moved to its own domain unit Kitto.Config.Server. Kitto.Config references it
  // via [YamlSubNode('Server', TKServerConfig)] as before.

  /// <summary>
  ///  Notification Center settings (bell, top-right). Opt-in.
  ///  YAML path: Notifications
  /// </summary>
  /// <example>
  ///  Notifications:
  ///    Enabled: True
  /// </example>
  // NB: TKNotificationsConfig moved to its own domain unit Kitto.Config.Notifications
  // (typed reader). Kitto.Config references it via [YamlSubNode('Notifications')].

type
  // NB: the chat config classes (TKHelpChatConfig root + TKClaudeProviderConfig)
  // now live in the chat domain (Kitto.Chat.Provider / Kitto.Chat.Provider.Claude),
  // decorated with [YamlConfigNode]. KIDE discovers them via RTTI scan; this
  // metadata unit no longer holds any chat config (no coupling to the chat domain).


  // NB: TKDefaultsGridConfig and TKDefaultsWindowConfig moved to
  // Kitto.Config.Defaults (typed readers, per-domain config organization).
  // Both are reached via TKDefaultsConfig's [YamlSubNode] annotations; the old
  // TEFNode duplicates here were unreachable by KIDE discovery and TKDefaultsWindowConfig
  // clashed by name with the new class.


  // NB: TKLogTextFileConfig moved to Kitto.Config.Log (typed reader,
  // per-domain config organization).

  // NB: TKAccessControlConfig moved to Kitto.Config.AccessControl (typed reader,
  // per-domain config organization).

  // NB: TKUserFormatsConfig moved to Kitto.Config.UserFormats (typed reader,
  // per-domain config organization).

  /// <summary>
  ///  Login form panel settings.
  ///  YAML path: Controller/FormPanel
  /// </summary>
  /// <example>
  ///  Controller:
  ///    FormPanel:
  ///      LabelWidth: 100
  ///      BodyStyle: padding:10px
  /// </example>
  TKLoginFormPanelConfig = class(TEFNode)
  private
    function GetLabelWidth: Integer;
    function GetBodyStyle: string;
  public
    [YamlNode('LabelWidth', '100', 'Width in pixels for form field labels')]
    property LabelWidth: Integer read GetLabelWidth;

    [YamlNode('BodyStyle', 'CSS style for form panel body')]
    property BodyStyle: string read GetBodyStyle;
  end;

  // NB: TKDesktopBorderIconsConfig and TKDesktopConfig moved to
  // Kitto.Config.Desktop (typed readers, per-domain config organization).

  // NB: TKThemeModeConfig and TKThemeConfig moved to Kitto.Config.Theme
  // (typed readers + theme runtime class methods, per-domain config organization).

implementation

uses
  System.SysUtils,
  System.StrUtils,
  System.Generics.Collections;

{ TKLayoutDefaultsConfig }

function TKLayoutDefaultsConfig.GetMemoWidth: Integer;
begin
  Result := GetInteger('MemoWidth', 60);
end;

function TKLayoutDefaultsConfig.GetMaxFieldWidth: Integer;
begin
  Result := GetInteger('MaxFieldWidth', 60);
end;

function TKLayoutDefaultsConfig.GetMinFieldWidth: Integer;
begin
  Result := GetInteger('MinFieldWidth', 5);
end;

function TKLayoutDefaultsConfig.GetCharWidthFactor: Double;
begin
  Result := GetFloat('Char_Width_Factor', 1.0);
end;

function TKLayoutDefaultsConfig.GetCharHeightFactor: Double;
begin
  Result := GetFloat('Char_Height_Factor', 1.0);
end;

function TKLayoutDefaultsConfig.GetRequiredLabelTemplate: string;
begin
  Result := GetString('RequiredLabelTemplate', '<b>{label}*</b>');
end;

function TKLayoutDefaultsConfig.GetLabelSeparator: string;
begin
  Result := GetString('LabelSeparator', ': ');
end;

{ TKLocalStorageConfig }

function TKLocalStorageConfig.GetMode: string;
begin
  Result := GetString('Mode');
end;

function TKLocalStorageConfig.GetAskUser: Boolean;
begin
  Result := GetBoolean('AskUser');
end;

function TKLocalStorageConfig.GetAutoLogin: Boolean;
begin
  Result := GetBoolean('AutoLogin', False);
end;

function TKLocalStorageConfig.GetAskUserDefault: Boolean;
begin
  Result := GetBoolean('AskUser/Default', True);
end;

{ TKLoginFormPanelConfig }

function TKLoginFormPanelConfig.GetLabelWidth: Integer;
begin
  Result := GetInteger('LabelWidth', 100);
end;

function TKLoginFormPanelConfig.GetBodyStyle: string;
begin
  Result := GetString('BodyStyle');
end;


end.
