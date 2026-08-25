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
///  Typed config reader for the colour-theme domain (Config.yaml node <c>Theme</c>
///  and its per-mode sub-nodes <c>Light</c> / <c>Dark</c>). Part of the per-domain
///  organization of the config metadata (replacing the monolithic
///  Kitto.Metadata.SubNodes). Carries the [YamlNode]/[YamlSubNode] attributes that
///  KIDE reads via RTTI for the Config editor; runtime consumption goes through the
///  TKThemeConfig class methods (which operate on the raw Theme TEFNode).
/// </summary>
unit Kitto.Config.Theme;

{$I Kitto.Defines.inc}

interface

uses
  EF.Tree,
  EF.YAML.Attributes,
  Kitto.Config.Reader,
  Kitto.Metadata.Types;

type
  /// <summary>
  ///  Per-mode theme palette (sub-node Light / Dark of Theme).
  ///  YAML path: Theme/Light, Theme/Dark
  /// </summary>
  TKThemeModeConfig = class(TKConfigReader)
  private
    function GetPrimaryColor: string;
  public
    [YamlNode('Primary-Color', 'Accent/chrome colour for this mode (CSS colour name or #hex). Empty = neutral default palette.')]
    property PrimaryColor: string read GetPrimaryColor;
  end;

  /// <summary>
  ///  Application colour theme. Single root node with the active Mode, the
  ///  end-user opt-in, the shared font/icon settings, and the per-mode
  ///  palettes (Light / Dark sub-nodes). Replaces the old flat `Theme: &lt;Mode&gt;`
  ///  / sibling-Theme-nodes models.
  ///
  ///  All runtime consumption goes through the class methods (which operate on
  ///  the raw Theme TEFNode), keeping every Theme read encapsulated here:
  ///   - TKWebApplication.RenderHTMLHead → DataThemeAttr / BuildBootScript /
  ///     BuildStyleBlock / ResolveIconStyle / ResolveIconSize
  ///   - TKXThemeSwitcherController → IsUserSelectionEnabled
  ///
  ///  YAML path: Theme
  /// </summary>
  /// <example>
  ///  Theme:
  ///    Mode: Auto
  ///    UserSelection: True
  ///    Font-Family: Segoe UI
  ///    Font-Size: 13px
  ///    IconStyle: outlined
  ///    IconSize: Medium
  ///    Light:
  ///      Primary-Color: FireBrick
  ///    Dark:
  ///      Primary-Color: Gold
  /// </example>
  TKThemeConfig = class(TKConfigReader)
  private
    function GetMode: TKTheme;
    function GetUserSelection: Boolean;
    function GetFontFamily: string;
    function GetFontSize: string;
    function GetIconStyle: TKIconStyle;
    function GetIconSize: TKIconSize;
    function GetLight: TKThemeModeConfig;
    function GetDark: TKThemeModeConfig;
    /// Chrome/accent/status CSS custom properties for a Primary-Color ('' -> '').
    class function BuildChromeVars(const APrimary: string): string; static;
    /// True if the (hex or CSS-named) colour has high luminance (ITU-R BT.601).
    class function IsCssColorLight(const AColor: string): Boolean; static;
    /// Light/Dark Primary-Color with fallback to a flat Primary-Color on the
    /// Theme node (backward-compat with the old single-node model).
    class function ResolvePrimary(const AThemeNode: TEFNode; const ASubNode: string): string; static;
  public
    [YamlNode('Mode', 'Auto', 'Theme mode: Auto (follow OS) | Light | Dark')]
    property Mode: TKTheme read GetMode;

    [YamlNode('UserSelection', 'True', 'Let the end user pick the theme via the ThemeSwitcher controller (only honoured when Mode=Auto). The attribute carries the inverse (True) so adding the node in KIDE writes the meaningful, behaviour-changing value.')]
    property UserSelection: Boolean read GetUserSelection;

    [YamlNode('Font-Family', 'UI font family, shared across modes')]
    property FontFamily: string read GetFontFamily;

    [YamlNode('Font-Size', '12px', 'Base font size in CSS units, shared across modes')]
    property FontSize: string read GetFontSize;

    [YamlNode('IconStyle', 'filled', 'Material Design icon style (resolved server-side, does not switch live)')]
    property IconStyle: TKIconStyle read GetIconStyle;

    [YamlNode('IconSize', 'Medium', 'Default icon size (resolved server-side, does not switch live)')]
    property IconSize: TKIconSize read GetIconSize;

    [YamlSubNode('Light', TKThemeModeConfig, 'Light-mode palette (Primary-Color)')]
    property Light: TKThemeModeConfig read GetLight;

    [YamlSubNode('Dark', TKThemeModeConfig, 'Dark-mode palette (Primary-Color)')]
    property Dark: TKThemeModeConfig read GetDark;

    // --- Runtime API: class methods operating on the raw Theme TEFNode -------
    // (config sub-node getters are RTTI-discovery-only / return nil at runtime,
    //  so consumption is via these class methods, keeping theme logic here.)

    /// Active mode as lowercase 'auto' | 'light' | 'dark'. Reads Theme/Mode,
    /// falling back to the node value (old `Theme: &lt;Mode&gt;` format), else 'auto'.
    class function ResolveMode(const AThemeNode: TEFNode): string; static;

    /// The html data-theme attribute: ' data-theme="light"' / '"dark"', or ''
    /// for Auto (CSS @media handles the OS preference).
    class function DataThemeAttr(const AThemeNode: TEFNode): string; static;

    /// True when Mode=Auto and Theme/UserSelection is True — gates the switcher.
    class function IsUserSelectionEnabled(const AThemeNode: TEFNode): Boolean; static;

    /// Theme/IconStyle as a YAML string (default 'filled'); nil node -> default.
    class function ResolveIconStyle(const AThemeNode: TEFNode): string; static;

    /// Theme/IconSize as a YAML string (default 'Medium'); nil node -> default.
    class function ResolveIconSize(const AThemeNode: TEFNode): string; static;

    /// FOUC-safe inline boot &lt;script&gt; for &lt;head&gt; — applies the localStorage
    /// theme override before CSS paints. '' unless Mode=Auto + UserSelection.
    class function BuildBootScript(const AThemeNode: TEFNode; const AAppName: string): string; static;

    /// The &lt;style&gt; block: :root (light palette) + html[data-theme="dark"] +
    /// prefers-color-scheme media query (dark palette, only if a dark
    /// Primary-Color resolves). '' when nothing to override.
    class function BuildStyleBlock(const AThemeNode: TEFNode): string; static;
  end;

implementation

uses
  System.SysUtils,
  System.StrUtils,
  System.Generics.Collections;

{ TKThemeModeConfig }

function TKThemeModeConfig.GetPrimaryColor: string;
begin
  Result := GetString('Primary-Color');
end;

{ TKThemeConfig }

// --- Decorated property getters (RTTI discovery; not used at runtime) -------

function TKThemeConfig.GetMode: TKTheme;
var
  S: string;
begin
  // RTTI-discovery getter (not called at runtime). Manual map keeps this unit
  // free of the KIDE-side RTTI reader; mirrors the YamlEnumValue mapping of TKTheme.
  S := LowerCase(GetString('Mode', 'Auto'));
  if S = 'light' then Result := thLight
  else if S = 'dark' then Result := thDark
  else Result := thAuto;
end;

function TKThemeConfig.GetUserSelection: Boolean;
begin
  Result := GetBoolean('UserSelection', False);
end;

function TKThemeConfig.GetFontFamily: string;
begin
  Result := GetString('Font-Family');
end;

function TKThemeConfig.GetFontSize: string;
begin
  Result := GetString('Font-Size');
end;

function TKThemeConfig.GetIconStyle: TKIconStyle;
var
  S: string;
begin
  S := LowerCase(GetString('IconStyle', 'filled'));
  if S = 'outlined' then Result := isOutlined
  else if S = 'round' then Result := isRound
  else if S = 'sharp' then Result := isSharp
  else if S = 'two-tone' then Result := isTwoTone
  else Result := isFilled;
end;

function TKThemeConfig.GetIconSize: TKIconSize;
var
  S: string;
begin
  S := LowerCase(GetString('IconSize', 'Medium'));
  if S = 'small' then Result := izSmall
  else if S = 'large' then Result := izLarge
  else Result := izMedium;
end;

function TKThemeConfig.GetLight: TKThemeModeConfig;
begin
  Result := nil; // RTTI discovery only — runtime access uses the class methods
end;

function TKThemeConfig.GetDark: TKThemeModeConfig;
begin
  Result := nil; // RTTI discovery only — runtime access uses the class methods
end;

// --- Private helpers --------------------------------------------------------

class function TKThemeConfig.IsCssColorLight(const AColor: string): Boolean;
var
  LColor, LHex: string;
  R, G, B: Integer;
  LLuminance: Double;
  LColorMap: TDictionary<string, string>;
begin
  // Perceived luminance (ITU-R BT.601). Returns True for light backgrounds so
  // the caller picks dark text on top. Handles #rgb / #rrggbb directly and maps
  // common CSS named colours to hex; unknown names default to dark (safe for
  // light text on chrome).
  LColor := LowerCase(Trim(AColor));
  LHex := '';

  if (LColor <> '') and (LColor[1] = '#') then
    LHex := LColor
  else
  begin
    LColorMap := TDictionary<string, string>.Create;
    try
      // Yellows / Golds
      LColorMap.Add('gold', '#FFD700');
      LColorMap.Add('yellow', '#FFFF00');
      LColorMap.Add('khaki', '#F0E68C');
      LColorMap.Add('darkkhaki', '#BDB76B');
      LColorMap.Add('goldenrod', '#DAA520');
      LColorMap.Add('darkgoldenrod', '#B8860B');
      // Oranges
      LColorMap.Add('orange', '#FFA500');
      LColorMap.Add('darkorange', '#FF8C00');
      LColorMap.Add('coral', '#FF7F50');
      LColorMap.Add('tomato', '#FF6347');
      LColorMap.Add('orangered', '#FF4500');
      // Reds
      LColorMap.Add('red', '#FF0000');
      LColorMap.Add('crimson', '#DC143C');
      LColorMap.Add('firebrick', '#B22222');
      LColorMap.Add('darkred', '#8B0000');
      LColorMap.Add('maroon', '#800000');
      // Pinks
      LColorMap.Add('pink', '#FFC0CB');
      LColorMap.Add('hotpink', '#FF69B4');
      LColorMap.Add('deeppink', '#FF1493');
      LColorMap.Add('salmon', '#FA8072');
      LColorMap.Add('lightsalmon', '#FFA07A');
      // Purples
      LColorMap.Add('purple', '#800080');
      LColorMap.Add('indigo', '#4B0082');
      LColorMap.Add('darkviolet', '#9400D3');
      LColorMap.Add('darkorchid', '#9932CC');
      LColorMap.Add('mediumpurple', '#9370DB');
      LColorMap.Add('slateblue', '#6A5ACD');
      LColorMap.Add('darkslateblue', '#483D8B');
      LColorMap.Add('violet', '#EE82EE');
      LColorMap.Add('plum', '#DDA0DD');
      LColorMap.Add('magenta', '#FF00FF');
      LColorMap.Add('fuchsia', '#FF00FF');
      // Blues
      LColorMap.Add('blue', '#0000FF');
      LColorMap.Add('darkblue', '#00008B');
      LColorMap.Add('navy', '#000080');
      LColorMap.Add('midnightblue', '#191970');
      LColorMap.Add('royalblue', '#4169E1');
      LColorMap.Add('dodgerblue', '#1E90FF');
      LColorMap.Add('steelblue', '#4682B4');
      LColorMap.Add('cornflowerblue', '#6495ED');
      LColorMap.Add('deepskyblue', '#00BFFF');
      LColorMap.Add('lightblue', '#ADD8E6');
      LColorMap.Add('lightskyblue', '#87CEFA');
      // Greens
      LColorMap.Add('green', '#008000');
      LColorMap.Add('darkgreen', '#006400');
      LColorMap.Add('forestgreen', '#228B22');
      LColorMap.Add('seagreen', '#2E8B57');
      LColorMap.Add('olive', '#808000');
      LColorMap.Add('olivedrab', '#6B8E23');
      LColorMap.Add('darkolivegreen', '#556B2F');
      LColorMap.Add('teal', '#008080');
      LColorMap.Add('darkcyan', '#008B8B');
      LColorMap.Add('lime', '#00FF00');
      LColorMap.Add('limegreen', '#32CD32');
      LColorMap.Add('lightgreen', '#90EE90');
      LColorMap.Add('springgreen', '#00FF7F');
      LColorMap.Add('aqua', '#00FFFF');
      LColorMap.Add('cyan', '#00FFFF');
      LColorMap.Add('turquoise', '#40E0D0');
      // Browns
      LColorMap.Add('brown', '#A52A2A');
      LColorMap.Add('saddlebrown', '#8B4513');
      LColorMap.Add('sienna', '#A0522D');
      LColorMap.Add('chocolate', '#D2691E');
      LColorMap.Add('peru', '#CD853F');
      LColorMap.Add('tan', '#D2B48C');
      LColorMap.Add('sandybrown', '#F4A460');
      // Grays
      LColorMap.Add('black', '#000000');
      LColorMap.Add('dimgray', '#696969');
      LColorMap.Add('gray', '#808080');
      LColorMap.Add('darkgray', '#A9A9A9');
      LColorMap.Add('silver', '#C0C0C0');
      LColorMap.Add('lightgray', '#D3D3D3');
      LColorMap.Add('white', '#FFFFFF');
      LColorMap.Add('slategray', '#708090');
      LColorMap.Add('darkslategray', '#2F4F4F');

      if not LColorMap.TryGetValue(LColor, LHex) then
        Exit(False); // unknown name: assume dark (safe for light text)
    finally
      LColorMap.Free;
    end;
  end;

  if Length(LHex) = 4 then // #RGB shorthand
  begin
    R := StrToIntDef('$' + LHex[2] + LHex[2], 0);
    G := StrToIntDef('$' + LHex[3] + LHex[3], 0);
    B := StrToIntDef('$' + LHex[4] + LHex[4], 0);
  end
  else if Length(LHex) >= 7 then // #RRGGBB
  begin
    R := StrToIntDef('$' + Copy(LHex, 2, 2), 0);
    G := StrToIntDef('$' + Copy(LHex, 4, 2), 0);
    B := StrToIntDef('$' + Copy(LHex, 6, 2), 0);
  end
  else
    Exit(False);

  LLuminance := 0.299 * R + 0.587 * G + 0.114 * B;
  Result := LLuminance > 160;
end;

class function TKThemeConfig.BuildChromeVars(const APrimary: string): string;
var
  LText: string;
begin
  if APrimary = '' then
    Exit('');
  if IsCssColorLight(APrimary) then
    LText := '#1a1a1a'   // dark text on a light chrome background
  else
    LText := '#ecf0f1';  // light text on a dark chrome background
  Result :=
    '--kx-chrome:' + APrimary + ';' +
    '--kx-chrome-dark:color-mix(in srgb,' + APrimary + ',black 25%);' +
    '--kx-chrome-hover:color-mix(in srgb,' + APrimary + ',white 15%);' +
    '--kx-chrome-mid:color-mix(in srgb,' + APrimary + ',white 22%);' +
    '--kx-chrome-light:color-mix(in srgb,' + APrimary + ',white 30%);' +
    '--kx-chrome-text:' + LText + ';' +
    '--kx-chrome-btn-hover:' + IfThen(LText = '#ecf0f1',
      'rgba(255,255,255,0.15)', 'rgba(0,0,0,0.10)') + ';' +
    '--kx-status-bg:color-mix(in srgb,' + APrimary + ',black 25%);' +
    '--kx-status-text:' + LText + ';' +
    '--kx-status-border:color-mix(in srgb,' + APrimary + ',black 40%);' +
    '--kx-accent:' + APrimary + ';' +
    '--kx-accent-ring:color-mix(in srgb,' + APrimary + ' 15%,transparent);';
end;

class function TKThemeConfig.ResolvePrimary(const AThemeNode: TEFNode;
  const ASubNode: string): string;
var
  LNode: TEFNode;
begin
  // Per-mode Primary-Color from the Light/Dark sub-node; fall back to a flat
  // Primary-Color on the Theme node itself (old single-node model) so legacy
  // configs keep working.
  Result := '';
  if not Assigned(AThemeNode) then
    Exit;
  LNode := AThemeNode.FindNode(ASubNode);
  if Assigned(LNode) then
    Result := LNode.GetString('Primary-Color');
  if Result = '' then
    Result := AThemeNode.GetString('Primary-Color');
end;

// --- Runtime API ------------------------------------------------------------

class function TKThemeConfig.ResolveMode(const AThemeNode: TEFNode): string;
begin
  if not Assigned(AThemeNode) then
    Exit('auto');
  // Theme/Mode (new model); fall back to the node value (old `Theme: <Mode>`).
  Result := LowerCase(AThemeNode.GetString('Mode', AThemeNode.AsString));
  if Result = '' then
    Result := 'auto';
end;

class function TKThemeConfig.DataThemeAttr(const AThemeNode: TEFNode): string;
var
  LMode: string;
begin
  LMode := ResolveMode(AThemeNode);
  if LMode = 'light' then
    Result := ' data-theme="light"'
  else if LMode = 'dark' then
    Result := ' data-theme="dark"'
  else
    Result := ''; // 'auto' or unset: no attribute, CSS @media handles it
end;

class function TKThemeConfig.IsUserSelectionEnabled(const AThemeNode: TEFNode): Boolean;
begin
  Result := Assigned(AThemeNode)
    and (ResolveMode(AThemeNode) = 'auto')
    and AThemeNode.GetBoolean('UserSelection', False);
end;

class function TKThemeConfig.ResolveIconStyle(const AThemeNode: TEFNode): string;
begin
  if Assigned(AThemeNode) then
    Result := AThemeNode.GetString('IconStyle', 'filled')
  else
    Result := 'filled';
end;

class function TKThemeConfig.ResolveIconSize(const AThemeNode: TEFNode): string;
begin
  if Assigned(AThemeNode) then
    Result := AThemeNode.GetString('IconSize', 'Medium')
  else
    Result := 'Medium';
end;

class function TKThemeConfig.BuildBootScript(const AThemeNode: TEFNode;
  const AAppName: string): string;
begin
  // FOUC-safe: applies the localStorage theme override before CSS paints.
  // Only when the user is allowed to switch (Mode=Auto + UserSelection).
  if not IsUserSelectionEnabled(AThemeNode) then
    Exit('');
  Result :=
    '<script>(function(){try{' +
      'var m=localStorage.getItem(' + AnsiQuotedStr('kx_theme:' + AAppName, '''') + ');' +
      'if(m===''light''||m===''dark'')document.documentElement.setAttribute(''data-theme'',m);' +
    '}catch(e){}})();</script>';
end;

class function TKThemeConfig.BuildStyleBlock(const AThemeNode: TEFNode): string;
var
  LLightPrimary, LDarkPrimary, LFontFamily, LFontSize, LFontBlock, LDarkBlock: string;
begin
  Result := '';
  if not Assigned(AThemeNode) then
    Exit;

  LLightPrimary := ResolvePrimary(AThemeNode, 'Light');
  LDarkPrimary := ResolvePrimary(AThemeNode, 'Dark');
  LFontFamily := AThemeNode.GetString('Font-Family');
  LFontSize := AThemeNode.GetString('Font-Size');

  if (LLightPrimary = '') and (LDarkPrimary = '') and (LFontFamily = '') and (LFontSize = '') then
    Exit; // nothing to override — the static kittox.css palette drives both modes

  LFontBlock := '';
  if LFontFamily <> '' then
    LFontBlock := LFontBlock + '--kx-font:"' + LFontFamily + '",sans-serif;';
  if LFontSize <> '' then
    LFontBlock := LFontBlock + '--kx-font-size:' + LFontSize + ';';

  // :root — light palette: font + chrome + page text derived from primary.
  Result := '<style>:root{' + LFontBlock + BuildChromeVars(LLightPrimary);
  if LLightPrimary <> '' then
    Result := Result +
      '--kx-accent-bg:color-mix(in srgb,' + LLightPrimary + ',white 85%);' +
      '--kx-text:color-mix(in srgb,' + LLightPrimary + ',black 60%);' +
      '--kx-text-secondary:color-mix(in srgb,' + LLightPrimary + ',black 40%);' +
      '--kx-text-muted:color-mix(in srgb,' + LLightPrimary + ',black 20%);' +
      '--kx-tree-folder-text:color-mix(in srgb,' + LLightPrimary + ',black 60%);' +
      '--kx-tree-leaf-text:color-mix(in srgb,' + LLightPrimary + ',black 60%);';
  Result := Result + '}';

  // Dark palette — only when a dark Primary-Color resolves. Resets text vars to
  // the dark defaults at the higher 0,1,1 specificity so the :root light greens
  // never leak into dark. When empty, the static kittox.css dark block wins.
  if LDarkPrimary <> '' then
  begin
    LDarkBlock := BuildChromeVars(LDarkPrimary) +
      '--kx-accent-bg:color-mix(in srgb,' + LDarkPrimary + ',transparent 88%);' +
      '--kx-text:#e5e7eb;' +
      '--kx-text-secondary:#9ca3af;' +
      '--kx-text-muted:#9ca3af;' +
      '--kx-tree-folder-text:#e5e7eb;' +
      '--kx-tree-leaf-text:#e5e7eb;';
    Result := Result +
      'html[data-theme="dark"]{' + LDarkBlock + '}' +
      '@media(prefers-color-scheme:dark){:root:not([data-theme]){' + LDarkBlock + '}}';
  end;

  Result := Result + '</style>';
end;

end.
