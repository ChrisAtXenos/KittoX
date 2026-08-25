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
///  Typed config reader for the desktop embedded-mode domain (Config.yaml node
///  <c>Desktop</c> and its sub-node <c>BorderIcons</c>). Part of the per-domain
///  organization of the config metadata (replacing the monolithic
///  Kitto.Metadata.SubNodes). Carries the [YamlNode]/[YamlSubNode] attributes
///  that KIDE reads via RTTI for the Config editor.
/// </summary>
unit Kitto.Config.Desktop;

{$I Kitto.Defines.inc}

interface

uses
  EF.Tree,
  EF.YAML.Attributes,
  Kitto.Config.Reader;

type
  /// <summary>
  ///  Border icons for the desktop embedded window.
  ///  YAML path: Desktop/BorderIcons
  /// </summary>
  TKDesktopBorderIconsConfig = class(TKConfigReader)
  private
    FBiSystemMenu: Boolean;
    FBiMinimize: Boolean;
    FBiMaximize: Boolean;
    FBiHelp: Boolean;
  protected
    procedure ReadConfig; override;
  public
    [YamlNode('biSystemMenu', 'False', 'Show system menu icon')]
    property BiSystemMenu: Boolean read FBiSystemMenu;

    [YamlNode('biMinimize', 'False', 'Show minimize button')]
    property BiMinimize: Boolean read FBiMinimize;

    [YamlNode('biMaximize', 'False', 'Show maximize button')]
    property BiMaximize: Boolean read FBiMaximize;

    [YamlNode('biHelp', 'True', 'Show help button')]
    property BiHelp: Boolean read FBiHelp;
  end;

  /// <summary>
  ///  Desktop embedded mode settings — controls the VCL window properties
  ///  when the application runs inside a TEdgeBrowser.
  ///  YAML path: Desktop
  /// </summary>
  TKDesktopConfig = class(TKConfigReader)
  private
    FClientWidth: Integer;
    FClientHeight: Integer;
    FMaximized: Boolean;
    FResizable: Boolean;
    FPosition: string;
    FBorderIcons: TKDesktopBorderIconsConfig;
  protected
    procedure ReadConfig; override;
  public
    destructor Destroy; override;

    [YamlNode('ClientWidth', '1000', 'Window client width in pixels')]
    property ClientWidth: Integer read FClientWidth;

    [YamlNode('ClientHeight', '900', 'Window client height in pixels')]
    property ClientHeight: Integer read FClientHeight;

    [YamlNode('Maximized', 'True', 'Start window maximized')]
    property Maximized: Boolean read FMaximized;

    [YamlNode('Resizable', 'False', 'Allow window resizing (False = fixed size)')]
    property Resizable: Boolean read FResizable;

    [YamlNode('Position', 'poScreenCenter', 'Window position (TPosition value)')]
    property Position: string read FPosition;

    [YamlSubNode('BorderIcons', TKDesktopBorderIconsConfig, 'Window border icons (system menu, minimize, maximize, help)')]
    property BorderIcons: TKDesktopBorderIconsConfig read FBorderIcons;
  end;

implementation

{ TKDesktopBorderIconsConfig }

procedure TKDesktopBorderIconsConfig.ReadConfig;
begin
  FBiSystemMenu := GetBoolean('biSystemMenu', True);
  FBiMinimize := GetBoolean('biMinimize', True);
  FBiMaximize := GetBoolean('biMaximize', True);
  FBiHelp := GetBoolean('biHelp', False);
end;

{ TKDesktopConfig }

procedure TKDesktopConfig.ReadConfig;
begin
  FClientWidth := GetInteger('ClientWidth', 1000);
  FClientHeight := GetInteger('ClientHeight', 900);
  FMaximized := GetBoolean('Maximized', False);
  FResizable := GetBoolean('Resizable', True);
  FPosition := GetString('Position', 'poScreenCenter');
  // Nested reader: bound to the BorderIcons subtree (nil-safe when absent).
  if FBorderIcons = nil then
    FBorderIcons := TKDesktopBorderIconsConfig.Create(SubNode('BorderIcons'))
  else
    FBorderIcons.Refresh(SubNode('BorderIcons'));
end;

destructor TKDesktopConfig.Destroy;
begin
  FBorderIcons.Free;
  inherited;
end;

end.
