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
///  Typed config reader for one named database connection (an element of the
///  Config.yaml <c>Databases</c> container). Carries the [YamlNode] attributes
///  that KIDE reads via RTTI for the Config editor.
/// </summary>
unit Kitto.Config.Database;

{$I Kitto.Defines.inc}

interface

uses
  EF.YAML.Attributes,
  Kitto.Config.Reader;

type
  /// <summary>
  ///  A single named database connection: one child of the Databases container.
  ///  YAML path: Databases/&lt;Name&gt;
  ///
  ///  The node's own value is the DB adapter id (FD / ODAC / DBX / ADO). The
  ///  Connection (and optional Config) sub-blocks are adapter-specific and
  ///  therefore free-form: their child keys depend on the driver, so they are
  ///  described here only as opaque nodes.
  /// </summary>
  /// <example>
  ///  Databases:
  ///    Main: FD
  ///      Connection:
  ///        DriverID: FB
  ///        Database: ...
  ///      DelimitedIdent: False
  /// </example>
  TKDatabaseConfig = class(TKConfigReader)
  private
    FDelimitedIdent: Boolean;
    FConnection: string;
    FExtraConfig: string;
    FDisplayLabel: string;
  protected
    procedure ReadConfig; override;
  public
    [YamlNode('DisplayLabel', 'Human-readable label for this connection (shown e.g. in the login database chooser)')]
    property DisplayLabel: string read FDisplayLabel;

    [YamlNode('DelimitedIdent', 'False', 'Quote/delimit SQL identifiers for this connection')]
    property DelimitedIdent: Boolean read FDelimitedIdent;

    [YamlNode('Connection', 'Adapter-specific connection parameters (free-form; the child keys depend on the driver)')]
    property Connection: string read FConnection;

    [YamlNode('Config', 'Optional adapter-specific extra configuration (free-form)')]
    property ExtraConfig: string read FExtraConfig;
  end;

implementation

{ TKDatabaseConfig }

procedure TKDatabaseConfig.ReadConfig;
begin
  FDisplayLabel := GetString('DisplayLabel');
  FDelimitedIdent := GetBoolean('DelimitedIdent', False);
  // Connection/Config are subtrees, not scalars; reading them as strings yields
  // '' and merely marks the nodes as known (their free-form children are then
  // left un-flagged by the tree validator).
  FConnection := GetString('Connection');
  FExtraConfig := GetString('Config');
end;

end.
