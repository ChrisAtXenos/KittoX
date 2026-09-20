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
///  Typed config reader for the logging domain (Config.yaml node <c>Log</c>,
///  sub-node <c>TextFile</c>). Part of the per-domain organization of the config
///  metadata (replacing the monolithic Kitto.Metadata.SubNodes). Carries the
///  [YamlNode] attributes that KIDE reads via RTTI for the Config editor.
/// </summary>
unit Kitto.Config.Log;

{$I Kitto.Defines.inc}

interface

uses
  EF.YAML.Attributes,
  Kitto.Config.Reader;

type
  /// <summary>
  ///  Text file logging settings from Config.yaml.
  ///  YAML path: Log/TextFile
  /// </summary>
  /// <example>
  ///  Log:
  ///    TextFile:
  ///      IsEnabled: False
  ///      FileName: log.txt
  /// </example>
  TKLogTextFileConfig = class(TKConfigReader)
  private
    FIsEnabled: Boolean;
    FFileName: string;
  protected
    procedure ReadConfig; override;
  public
    [YamlNode('IsEnabled', 'False', 'Enable text file logging')]
    property IsEnabled: Boolean read FIsEnabled;

    [YamlNode('FileName', 'Log file path')]
    property FileName: string read FFileName;
  end;

  /// <summary>
  ///  Console logging settings from Config.yaml.
  ///  YAML path: Log/Console
  /// </summary>
  /// <example>
  ///  Log:
  ///    Console:
  ///      IsEnabled: True
  /// </example>
  TKLogConsoleConfig = class(TKConfigReader)
  private
    FIsEnabled: Boolean;
  protected
    procedure ReadConfig; override;
  public
    [YamlNode('IsEnabled', 'False', 'Enable console logging')]
    property IsEnabled: Boolean read FIsEnabled;
  end;

  /// <summary>
  ///  Logging settings from Config.yaml.
  ///  YAML path: Log
  /// </summary>
  /// <example>
  ///  Log:
  ///    Level: medium
  ///    TextFile:
  ///      IsEnabled: False
  ///      FileName: log.txt
  /// </example>
  TKLogConfig = class(TKConfigReader)
  private
    FLevel: string;
    FTextFile: TKLogTextFileConfig;
    FConsole: TKLogConsoleConfig;
  protected
    procedure ReadConfig; override;
  public
    destructor Destroy; override;

    [YamlNode('Level', 'Log verbosity: low / medium / high / detailed / debug, or an integer')]
    [YamlEnumValue('low', 'Lowest verbosity (always-logged messages only)')]
    [YamlEnumValue('medium', 'Medium verbosity')]
    [YamlEnumValue('high', 'High verbosity')]
    [YamlEnumValue('detailed', 'Detailed verbosity')]
    [YamlEnumValue('debug', 'Highest (debug) verbosity')]
    // Open set: the five names are the suggested values, but an integer (1..5) is
    // also accepted at runtime, so an unlisted value is a warning, not an error.
    [YamlEnumOpen]
    property Level: string read FLevel;

    [YamlSubNode('TextFile', TKLogTextFileConfig, 'Text file logging settings')]
    property TextFile: TKLogTextFileConfig read FTextFile;

    [YamlSubNode('Console', TKLogConsoleConfig, 'Console logging settings')]
    property Console: TKLogConsoleConfig read FConsole;
  end;

implementation

{ TKLogTextFileConfig }

procedure TKLogTextFileConfig.ReadConfig;
begin
  FIsEnabled := GetBoolean('IsEnabled', False);
  FFileName := GetString('FileName');
end;

{ TKLogConsoleConfig }

procedure TKLogConsoleConfig.ReadConfig;
begin
  FIsEnabled := GetBoolean('IsEnabled', False);
end;

{ TKLogConfig }

procedure TKLogConfig.ReadConfig;
begin
  FLevel := GetString('Level');
  // Nested readers bound to the TextFile/Console subtrees (nil-safe when absent).
  if FTextFile = nil then
    FTextFile := TKLogTextFileConfig.Create(SubNode('TextFile'))
  else
    FTextFile.Refresh(SubNode('TextFile'));
  if FConsole = nil then
    FConsole := TKLogConsoleConfig.Create(SubNode('Console'))
  else
    FConsole.Refresh(SubNode('Console'));
end;

destructor TKLogConfig.Destroy;
begin
  FTextFile.Free;
  FConsole.Free;
  inherited;
end;

end.
