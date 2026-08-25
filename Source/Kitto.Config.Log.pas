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
    [YamlNode('IsEnabled', 'True', 'Enable text file logging')]
    property IsEnabled: Boolean read FIsEnabled;

    [YamlNode('FileName', 'Log file path')]
    property FileName: string read FFileName;
  end;

implementation

{ TKLogTextFileConfig }

procedure TKLogTextFileConfig.ReadConfig;
begin
  FIsEnabled := GetBoolean('IsEnabled', False);
  FFileName := GetString('FileName');
end;

end.
