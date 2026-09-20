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
///  Typed config reader for the Notification Center domain (Config.yaml node
///  <c>Notifications</c>). Part of the per-domain organization of the config
///  metadata (replacing the monolithic Kitto.Metadata.SubNodes). Reads its
///  subtree once into typed fields (see TKConfigReader) AND carries the
///  [YamlNode] attributes that KIDE reads via RTTI for the Config editor.
/// </summary>
unit Kitto.Config.Notifications;

{$I Kitto.Defines.inc}

interface

uses
  EF.YAML.Attributes,
  Kitto.Config.Reader;

type
  /// <summary>
  ///  Notification Center settings (bell, top-right). Opt-in.
  ///  YAML path: Notifications
  /// </summary>
  /// <example>
  ///  Notifications:
  ///    Enabled: True
  /// </example>
  TKNotificationsConfig = class(TKConfigReader)
  private
    FEnabled: Boolean;
  protected
    procedure ReadConfig; override;
  public
    [YamlNode('Enabled', 'False', 'Enable the Notification Center (bell, top-right)')]
    property Enabled: Boolean read FEnabled;
  end;

implementation

{ TKNotificationsConfig }

procedure TKNotificationsConfig.ReadConfig;
begin
  // Runtime default is False (opt-in). The attribute above carries 'True' as the
  // value KIDE writes when adding the node (inverse-of-default boolean convention).
  FEnabled := GetBoolean('Enabled', False);
end;

end.
