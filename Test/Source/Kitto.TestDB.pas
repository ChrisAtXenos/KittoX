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
///  Opens the connections the integration tests work on, reading them from
///  Data\TestDatabases.yaml (same shape as the Databases node of an
///  application's Config.yaml).
///
///  A backend that is turned off there, or that does not answer, makes the test
///  pass with a SKIPPED message rather than fail: the suite has to stay
///  meaningful on a machine that only has some of these servers. Read the
///  SKIPPED lines of a run - that is where a server that should have answered
///  and did not shows up.
/// </summary>
unit Kitto.TestDB;

interface

uses
  System.SysUtils,
  EF.Tree,
  EF.DB;

type
  TKTestDB = class
  strict private
    class var FConfig: TEFTree;
    class function GetConfig: TEFTree; static;
  public
    class destructor Destroy;

    /// <summary>Names of the databases declared in the file, enabled or not.
    /// Used to parameterize the test cases.</summary>
    class function DatabaseNames: TArray<string>; static;

    /// <summary>True if the entry exists and is not turned off.</summary>
    class function IsEnabled(const ADatabaseName: string): Boolean; static;

    /// <summary>
    ///  An open connection to ADatabaseName, or nil when the backend is turned
    ///  off or unreachable - in which case AWhyNot says why, ready to be shown
    ///  in a SKIPPED message. The caller owns the connection.
    /// </summary>
    class function TryOpenConnection(const ADatabaseName: string;
      out AWhyNot: string): TEFDBConnection; static;

    /// <summary>
    ///  The same connection TryOpenConnection builds, configured and named but
    ///  NOT opened. For a test that has to look at what a connection does
    ///  before it is open; AWhyNot says why when the result is nil.
    /// </summary>
    class function CreateConnection(const ADatabaseName: string;
      out AWhyNot: string): TEFDBConnection; static;
  end;

implementation

uses
  System.IOUtils,
  EF.YAML,
  Kitto.TestUtils;

{ TKTestDB }

class destructor TKTestDB.Destroy;
begin
  FreeAndNil(FConfig);
end;

class function TKTestDB.GetConfig: TEFTree;
var
  LFileName: string;
begin
  if FConfig = nil then
  begin
    LFileName := TKTestUtils.DataFile('TestDatabases.yaml');
    if not TFile.Exists(LFileName) then
      raise Exception.CreateFmt('Test database configuration not found: %s', [LFileName]);
    FConfig := TEFYAMLReader.LoadTree(LFileName);
  end;
  Result := FConfig;
end;

class function TKTestDB.DatabaseNames: TArray<string>;
var
  LDatabases: TEFNode;
  I: Integer;
begin
  Result := [];
  LDatabases := GetConfig.FindNode('Databases');
  if Assigned(LDatabases) then
    for I := 0 to LDatabases.ChildCount - 1 do
      Result := Result + [LDatabases.Children[I].Name];
end;

class function TKTestDB.IsEnabled(const ADatabaseName: string): Boolean;
var
  LNode: TEFNode;
begin
  LNode := GetConfig.FindNode('Databases/' + ADatabaseName);
  Result := Assigned(LNode) and LNode.GetBoolean('Enabled', True);
end;

class function TKTestDB.TryOpenConnection(const ADatabaseName: string;
  out AWhyNot: string): TEFDBConnection;
begin
  Result := CreateConnection(ADatabaseName, AWhyNot);
  if Result = nil then
    Exit;
  try
    Result.Open;
  except
    on E: Exception do
    begin
      // Server down, wrong credentials, missing client library: all reasons to
      // skip rather than to fail, but the message says exactly which one.
      AWhyNot := Format('%s is not reachable: %s: %s',
        [ADatabaseName, E.ClassName, E.Message]);
      FreeAndNil(Result);
    end;
  end;
end;

class function TKTestDB.CreateConnection(const ADatabaseName: string;
  out AWhyNot: string): TEFDBConnection;
var
  LNode: TEFNode;
  LConnectionNode: TEFNode;
  LAdapterId: string;
begin
  Result := nil;
  AWhyNot := '';

  LNode := GetConfig.FindNode('Databases/' + ADatabaseName);
  if not Assigned(LNode) then
    Exit(nil);
  if not LNode.GetBoolean('Enabled', True) then
  begin
    AWhyNot := Format('%s is turned off in TestDatabases.yaml.', [ADatabaseName]);
    Exit(nil);
  end;

  // The adapter id is the value of the database node itself ('FD', 'ADO', ...),
  // exactly as in an application's Config.yaml.
  LAdapterId := LNode.AsString;
  if not TEFDBAdapterRegistry.Instance.HasDBAdapter(LAdapterId) then
  begin
    AWhyNot := Format('%s needs the "%s" adapter, which is not linked into the test binary.',
      [ADatabaseName, LAdapterId]);
    Exit(nil);
  end;

  LConnectionNode := LNode.FindNode('Connection');
  if not Assigned(LConnectionNode) then
  begin
    AWhyNot := Format('%s has no Connection node.', [ADatabaseName]);
    Exit(nil);
  end;

  Result := TEFDBAdapterRegistry.Instance[LAdapterId].CreateDBConnection;
  try
    Result.Config.AddChild(TEFNode.Clone(LConnectionNode));
    // As TKConfig.CreateDBConnection does: the name identifies the connection
    // pool, so setting it here is what makes these tests exercise the same path
    // an application takes.
    Result.DatabaseName := ADatabaseName;
  except
    FreeAndNil(Result);
    raise;
  end;
end;

end.
