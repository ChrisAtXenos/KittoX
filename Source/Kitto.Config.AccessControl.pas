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
///  Typed config reader for the access-control domain (Config.yaml node
///  <c>AccessControl</c>). Part of the per-domain organization of the config
///  metadata (replacing the monolithic Kitto.Metadata.SubNodes). Carries the
///  [YamlNode] attributes that KIDE reads via RTTI for the Config editor.
///
///  NB: the AccessControl: DB plugin and Auth: JWT read these keys from the
///  configuration node handed to them (see Kitto.AccessControl.DB / Kitto.Auth.JWT),
///  so the runtime does not go through this singleton reader; the reader exists
///  for KIDE discovery and for uniform typed access via TKConfig.AccessControl.
/// </summary>
unit Kitto.Config.AccessControl;

{$I Kitto.Defines.inc}

interface

uses
  EF.YAML.Attributes,
  Kitto.Config.Reader;

type
  /// <summary>
  ///  Access control settings from Config.yaml.
  ///  YAML path: AccessControl
  /// </summary>
  /// <example>
  ///  AccessControl:
  ///    ReadPermissionsCommandText: SELECT * FROM PERMISSIONS
  ///    ReadRolesCommandText: SELECT * FROM ROLES
  /// </example>
  TKAccessControlConfig = class(TKConfigReader)
  private
    FReadPermissionsCommandText: string;
    FReadRolesCommandText: string;
  protected
    procedure ReadConfig; override;
  public
    [YamlNode('ReadPermissionsCommandText', 'SQL command to read permissions. Used by AccessControl: DB at runtime and by Auth: JWT at login when AccessControl: JWT is configured (the JWT then snapshots the rows into the kx_acl claim).')]
    property ReadPermissionsCommandText: string read FReadPermissionsCommandText;

    [YamlNode('ReadRolesCommandText', 'SQL command to read roles. Used by AccessControl: DB at runtime and by Auth: JWT at login when AccessControl: JWT is configured.')]
    property ReadRolesCommandText: string read FReadRolesCommandText;

    // AccessControl: JWT has no user-tunable keys: it is closed-world
    // (claim is authoritative). For DB-driven evaluation, configure
    // AccessControl: DB instead — Auth: JWT can still be used independently
    // for authentication.
  end;

implementation

{ TKAccessControlConfig }

procedure TKAccessControlConfig.ReadConfig;
begin
  FReadPermissionsCommandText := GetString('ReadPermissionsCommandText');
  FReadRolesCommandText := GetString('ReadRolesCommandText');
end;

end.
