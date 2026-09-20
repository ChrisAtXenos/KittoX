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
///  Typed config reader for the web-engine domain (Config.yaml node
///  <c>Engine</c>, sub-node <c>Session</c>). Part of the per-domain organization
///  of the config metadata. Carries the [YamlNode]/[YamlSubNode] attributes that
///  KIDE reads via RTTI for the Config editor.
/// </summary>
unit Kitto.Config.Engine;

{$I Kitto.Defines.inc}

interface

uses
  EF.YAML.Attributes,
  Kitto.Config.Reader;

type
  /// <summary>
  ///  Session lifecycle settings for the web engine.
  ///  YAML path: Engine/Session
  /// </summary>
  /// <example>
  ///  Engine:
  ///    Session:
  ///      TimeOut: 10
  ///      CleanupInterval: 5
  /// </example>
  TKEngineSessionConfig = class(TKConfigReader)
  private
    FTimeOut: Integer;
    FCleanupInterval: Integer;
  protected
    procedure ReadConfig; override;
  public
    [YamlNode('TimeOut', '10', 'Session inactivity timeout (minutes)')]
    property TimeOut: Integer read FTimeOut;

    [YamlNode('CleanupInterval', '5', 'Interval between expired-session sweeps (seconds)')]
    property CleanupInterval: Integer read FCleanupInterval;
  end;

  /// <summary>
  ///  Web engine settings from Config.yaml.
  ///  YAML path: Engine
  /// </summary>
  TKEngineConfig = class(TKConfigReader)
  private
    FSession: TKEngineSessionConfig;
  protected
    procedure ReadConfig; override;
  public
    destructor Destroy; override;

    [YamlSubNode('Session', TKEngineSessionConfig, 'Session timeout and cleanup interval')]
    property Session: TKEngineSessionConfig read FSession;
  end;

implementation

{ TKEngineSessionConfig }

procedure TKEngineSessionConfig.ReadConfig;
begin
  FTimeOut := GetInteger('TimeOut', 10);
  FCleanupInterval := GetInteger('CleanupInterval', 5);
end;

{ TKEngineConfig }

procedure TKEngineConfig.ReadConfig;
begin
  // Nested reader bound to the Session subtree (nil-safe when absent).
  if FSession = nil then
    FSession := TKEngineSessionConfig.Create(SubNode('Session'))
  else
    FSession.Refresh(SubNode('Session'));
end;

destructor TKEngineConfig.Destroy;
begin
  FSession.Free;
  inherited;
end;

end.
