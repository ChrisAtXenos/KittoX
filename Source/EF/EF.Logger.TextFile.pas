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
///   A logging endpoint that appends log messages to a text file.
/// </summary>
unit EF.Logger.TextFile;

interface

uses
  EF.Classes,
  EF.Macros,
  EF.Logger,
  EF.ObserverIntf,
  EF.Streams;

type
  /// <summary>
  ///   Log endpoint that writes each message, prefixed with a timestamp, as a
  ///   new line in a text file. Created as a singleton in the unit's
  ///   initialization section. The target file defaults to the module name with
  ///   a '.log' extension and can be overridden through configuration (see the
  ///   'TextFile/FileName' key) or the FileName property.
  /// </summary>
  TEFTextFileLogEndpoint = class(TEFLogEndpoint)
  strict private
    FStream: TEFTextStream;
    FFileName: string;
  class var
    FInstance: TEFTextFileLogEndpoint;
    function GetStream: TEFTextStream;
  strict protected
    procedure DoLog(const AString: string); override;
    procedure Configure(const AConfig: TEFComponentConfig;
      const AMacroExpansionEngine: TEFMacroExpansionEngine); override;
    property Stream: TEFTextStream read GetStream;
    procedure SetFileName(const AValue: string);
    function GetConfigPath: string; override;
  public
    /// <summary>
    ///   Creates the singleton instance of this endpoint.
    /// </summary>
    class procedure CreateSingletonInstance;
    /// <summary>
    ///   Destroys the singleton instance of this endpoint.
    /// </summary>
    class procedure FreeSingletonInstance;
    /// <summary>
    ///   The singleton instance. Without it the public FileName property below
    ///   could not be reached, so an application had no way to change the log
    ///   file at run time other than through the whole logger configuration.
    /// </summary>
    class property Instance: TEFTextFileLogEndpoint read FInstance;
    /// <summary>
    ///   Sets the default file name (the module name with a '.log' extension).
    /// </summary>
    procedure AfterConstruction; override;
    /// <summary>
    ///   Closes the underlying stream and destroys the endpoint.
    /// </summary>
    destructor Destroy; override;
    /// <summary>
    ///   Full path of the log file. Changing it closes the currently open
    ///   stream so that the new file is used on the next write.
    /// </summary>
    property FileName: string read FFileName write SetFileName;
  end;

implementation

uses
  System.SysUtils,
  System.Classes;

{ TEFTextFileLogger }

procedure TEFTextFileLogEndpoint.AfterConstruction;
begin
  inherited;
  FFileName := ChangeFileExt(GetModuleName(HInstance), '.log');
end;

destructor TEFTextFileLogEndpoint.Destroy;
begin
  MonitorEnter(Self);
  try
    FreeAndNil(FStream);
  finally
    MonitorExit(Self);
  end;
  inherited;
end;

procedure TEFTextFileLogEndpoint.Configure(const AConfig: TEFComponentConfig;
  const AMacroExpansionEngine: TEFMacroExpansionEngine);
var
  LFileName: string;
begin
  inherited;
  if IsEnabled and Assigned(AConfig) and Assigned(AMacroExpansionEngine) then
  begin
    // Explicitly calling Expoand here makes sure macros are
    // expanded even now that we have no session thus no macros.
    LFileName := AConfig.GetString(GetConfigPath + 'FileName', FileName);
    AMacroExpansionEngine.Expand(LFileName);
    FileName := LFileName;
  end;
end;

class procedure TEFTextFileLogEndpoint.CreateSingletonInstance;
begin
  FInstance := TEFTextFileLogEndpoint.Create;
end;

class procedure TEFTextFileLogEndpoint.FreeSingletonInstance;
begin
  FreeAndNil(FInstance);
end;

procedure TEFTextFileLogEndpoint.DoLog(const AString: string);
begin
  if IsEnabled then
  begin
    // The whole write goes inside the lock, not just the creation of the stream
    // as it used to. Two reasons: a single file is being written to, so the
    // writes have to be serialized or the lines of concurrent requests end up
    // interleaved; and SetFileName can free the stream in the window between
    // GetStream returning it and WriteLn using it, which under ISAPI/Apache
    // meant an access violation in a thread that had nothing to do with the
    // reconfiguration. TMonitor is reentrant, so GetStream taking the same lock
    // again is not a problem.
    MonitorEnter(Self);
    try
      Stream.WriteLn(FormatDateTime('[yyyy-mm-dd hh:nn:ss.zzz] ', Now()) +  AString);
    finally
      MonitorExit(Self);
    end;
  end;
end;

function TEFTextFileLogEndpoint.GetConfigPath: string;
begin
  Result := 'TextFile/';
end;

function TEFTextFileLogEndpoint.GetStream: TEFTextStream;
var
  LCreateFlag: Integer;
begin
  MonitorEnter(Self);
  try
    if not Assigned(FStream) then
    begin
      if FileExists(FFileName) then
        LCreateFlag := 0
      else
      begin
        LCreateFlag := fmCreate;
        ForceDirectories(ExtractFilePath(FFileName));
      end;
      FStream := TEFTextStream.Create(TFileStream.Create(FFileName, LCreateFlag or fmOpenWrite or fmShareDenyWrite));
      FStream.Seek(0, soFromEnd);
    end;
    Result := FStream;
  finally
    MonitorExit(Self);
  end;
end;

procedure TEFTextFileLogEndpoint.SetFileName(const AValue: string);
begin
  // Under the same lock as DoLog: this frees the stream other threads may be
  // writing to right now. The next DoLog reopens it on the new name.
  MonitorEnter(Self);
  try
    if AValue <> FFileName then
    begin
      FFileName := AValue;
      FreeAndNil(FStream);
    end;
  finally
    MonitorExit(Self);
  end;
end;

initialization
  TEFTextFileLogEndpoint.CreateSingletonInstance;

finalization
  TEFTextFileLogEndpoint.FreeSingletonInstance;

end.
