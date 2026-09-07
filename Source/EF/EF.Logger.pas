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

///	<summary>
///	 Basic logging services.
///	</summary>
unit EF.Logger;

{$I EF.Defines.inc}

interface

uses
  System.SysUtils,
  System.Types,
  System.Classes,
  EF.ObserverIntf,
  EF.Classes,
  EF.Tree,
  EF.Macros;

type
  ///	<summary>
  ///	  Central logging service: a singleton (see Instance) that dispatches log
  ///	  messages to the attached endpoints (observers) whenever the message
  ///	  level does not exceed the currently configured LogLevel.
  ///	</summary>
  TEFLogger = class(TEFComponent)
  private
    FLogLevel: Integer;
    FMacroExpansionEngine: TEFMacroExpansionEngine;
    class var
      FInstance: TEFLogger;
    procedure SetLogLevelFromConfig(const ALogLevelNode: TEFNode);
  public
    ///	<summary>
    ///	  Creates the singleton Instance.
    ///	</summary>
    class constructor Create;
    ///	<summary>
    ///	  Destroys the singleton Instance.
    ///	</summary>
    class destructor Destroy;
    ///	<summary>
    ///	  Sets the log level to its default value.
    ///	</summary>
    procedure AfterConstruction; override;
    ///	<summary>
    ///	  The macro expansion engine set by the last Configure call. It is only
    ///	  valid while endpoints are processing the '{ConfigChanged}' notification.
    ///	</summary>
    property MacroExpansionEngine: TEFMacroExpansionEngine read FMacroExpansionEngine;
  public
    ///	<summary>
    ///	  Lowest verbosity log level (always logged).
    ///	</summary>
    const LOG_LOW = 1;
    ///	<summary>
    ///	  Medium verbosity log level.
    ///	</summary>
    const LOG_MEDIUM = 2;
    ///	<summary>
    ///	  High verbosity log level.
    ///	</summary>
    const LOG_HIGH = 3;
    ///	<summary>
    ///	  Detailed verbosity log level.
    ///	</summary>
    const LOG_DETAILED = 4;
    ///	<summary>
    ///	  Highest (debug) verbosity log level.
    ///	</summary>
    const LOG_DEBUG = 5;

    ///	<summary>
    ///	  The level for a message that must ALWAYS reach the log: an exception
    ///	  escaping a handler, a failed save, a misconfiguration that stops the
    ///	  application. Same value as LOG_LOW, and named apart because these
    ///	  constants are VERBOSITY THRESHOLDS, not importance: Log emits when
    ///	  LogLevel >= ALogLevel, so the HIGHER the constant the LESS likely the
    ///	  message is written, and LOG_HIGH on an error means it disappears from
    ///	  every configuration that does not raise Level to 'high' -- including
    ///	  the default one, which is LOG_LOW. Every diagnostic in the framework
    ///	  had made exactly that mistake.
    ///	</summary>
    const LOG_ALWAYS = LOG_LOW;

    ///	<summary>
    ///	  Default log level used when none is specified (LOG_LOW).
    ///	</summary>
    const DEFAULT_LOG_LEVEL = LOG_LOW;

    ///	<summary>
    ///	  Applies the given configuration: reads the log level from the 'Level'
    ///	  node (accepting 'low', 'medium', 'high', 'detailed', 'debug' or an
    ///	  integer), then notifies observers so that endpoints can reconfigure
    ///	  themselves against AConfig and AMacroExpansionEngine.
    ///	</summary>
    procedure Configure(const AConfig: TEFTree; const AMacroExpansionEngine: TEFMacroExpansionEngine);

    ///	<summary>
    ///	  Gets or sets the current log level. Messages logged with a level
    ///	  higher than this value are discarded.
    ///	</summary>
    property LogLevel: Integer read FLogLevel write FLogLevel;

    ///	<summary>
    ///	  Logs AString if ALogLevel does not exceed the current LogLevel, by
    ///	  notifying all attached endpoints.
    ///	</summary>
    procedure Log(const AString: string; const ALogLevel: Integer = DEFAULT_LOG_LEVEL);

    ///	<summary>
    ///	  Logs AString at the LOG_LOW level.
    ///	</summary>
    procedure LogLow(const AString: string); inline;
    ///	<summary>
    ///	  Logs AString at the LOG_MEDIUM level.
    ///	</summary>
    procedure LogMedium(const AString: string); inline;
    ///	<summary>
    ///	  Logs AString at the LOG_HIGH level.
    ///	</summary>
    procedure LogHigh(const AString: string); inline;
    ///	<summary>
    ///	  Logs AString at the LOG_DETAILED level.
    ///	</summary>
    procedure LogDetailed(const AString: string); inline;
    ///	<summary>
    ///	  Logs AString at the LOG_DEBUG level.
    ///	</summary>
    procedure LogDebug(const AString: string); inline;

    ///	<summary>
    ///	  Logs a message built by formatting AString with AParams (see
    ///	  System.SysUtils.Format) at the specified log level.
    ///	</summary>
    procedure LogFmt(const AString: string; const AParams: array of const;
      const ALogLevel: Integer = DEFAULT_LOG_LEVEL);

    ///	<summary>
    ///	  The single, application-wide logger instance.
    ///	</summary>
    class property Instance: TEFLogger read FInstance;
  end;

  ///	<summary>
  ///	  Abstract base class for logging endpoints. An endpoint attaches itself as
  ///	  an observer of the logger's Instance and writes each notified message to
  ///	  a concrete destination (see the overridden DoLog). Descendants implement
  ///	  the actual output (for example a text file).
  ///	</summary>
  TEFLogEndpoint = class(TEFSubjectAndObserver)
  strict private
    FIsEnabled: Boolean;
  strict protected
    function GetConfigPath: string; virtual;
    procedure Configure(const AConfig: TEFComponentConfig; const AMacroExpansionEngine: TEFMacroExpansionEngine); virtual;
    procedure DoLog(const AString: string); virtual; abstract;
    property IsEnabled: Boolean read FIsEnabled;
  public
    ///	<summary>
    ///	  Attaches this endpoint as an observer of the logger's Instance.
    ///	</summary>
    procedure AfterConstruction; override;
    ///	<summary>
    ///	  Detaches this endpoint from the logger's Instance.
    ///	</summary>
    destructor Destroy; override;
    ///	<summary>
    ///	  Handles logger notifications: reconfigures the endpoint on
    ///	  '{ConfigChanged}', otherwise writes the context string through DoLog
    ///	  (messages containing 'PASSWORD' are skipped).
    ///	</summary>
    procedure UpdateObserver(const ASubject: IEFSubject; const AContext: string = ''); override;
  end;

implementation

uses
  System.RegularExpressions;

/// <summary>
///  Masks the value assigned to anything whose name contains "password",
///  leaving the rest of the message intact. Covers the forms a message can
///  carry a credential in: Password=value, "Password":"value" and
///  PASSWORD_HASH: value. A message that merely mentions the word - a marker,
///  an error, the name of a method - is returned unchanged, so authentication
///  stays diagnosable.
/// </summary>
function MaskPasswordValues(const AString: string): string;
const
  // name (optionally quoted) + separator + value (quoted, or up to a delimiter)
  PASSWORD_VALUE_PATTERN = '(?i)("?\w*password\w*"?\s*[:=]\s*)("[^"]*"|[^\s,;&}\)]+)';
  MASK = '***';
begin
  if Pos('PASSWORD', UpperCase(AString)) = 0 then
    Exit(AString);
  Result := TRegEx.Replace(AString, PASSWORD_VALUE_PATTERN, '$1' + MASK);
end;

{ TEFLogger }

procedure TEFLogger.AfterConstruction;
begin
  inherited;
  FLogLevel := DEFAULT_LOG_LEVEL;
end;

class constructor TEFLogger.Create;
begin
  FInstance := TEFLogger.Create;
end;

class destructor TEFLogger.Destroy;
begin
  FreeAndNil(FInstance);
end;

procedure TEFLogger.Log(const AString: string; const ALogLevel: Integer);
begin
  if FLogLevel >= ALogLevel then
    NotifyObservers(AString);
end;

procedure TEFLogger.LogDebug(const AString: string);
begin
  Log(AString, LOG_DEBUG);
end;

procedure TEFLogger.LogDetailed(const AString: string);
begin
  Log(AString, LOG_DETAILED);
end;

procedure TEFLogger.LogFmt(const AString: string; const AParams: array of const;
  const ALogLevel: Integer);
begin
  Log(Format(AString, AParams), ALogLevel);
end;

procedure TEFLogger.LogHigh(const AString: string);
begin
  Log(AString, LOG_HIGH);
end;

procedure TEFLogger.LogLow(const AString: string);
begin
  Log(AString, LOG_LOW);
end;

procedure TEFLogger.LogMedium(const AString: string);
begin
  Log(AString, LOG_MEDIUM);
end;

procedure TEFLogger.SetLogLevelFromConfig(const ALogLevelNode: TEFNode);
var
  LValue: string;
begin
  if Assigned(ALogLevelNode) then
  begin
    LValue := ALogLevelNode.AsString.ToLower;
    if LValue <> '' then
    begin
      if LValue = 'low' then
        LogLevel := LOG_LOW
      else if LValue = 'medium' then
        LogLevel := LOG_MEDIUM
      else if LValue = 'high' then
        LogLevel := LOG_HIGH
      else if LValue = 'detailed' then
        LogLevel := LOG_DETAILED
      else if LValue = 'debug' then
        LogLevel := LOG_DEBUG
      else
        LogLevel := ALogLevelNode.AsInteger;
    end;
  end;
end;

procedure TEFLogger.Configure(const AConfig: TEFTree; const AMacroExpansionEngine: TEFMacroExpansionEngine);
begin
  if Assigned(AConfig) then
    SetLogLevelFromConfig(AConfig.FindNode('Level'));
  try
    Config.Assign(AConfig);
    FMacroExpansionEngine := AMacroExpansionEngine;
    NotifyObservers('{ConfigChanged}');
  finally
    Config.Clear;
    FMacroExpansionEngine := nil;
  end;
end;

{ TEFLogEndpoint }

procedure TEFLogEndpoint.AfterConstruction;
begin
  inherited;
  TEFLogger.Instance.AttachObserver(Self);
end;

procedure TEFLogEndpoint.Configure(const AConfig: TEFComponentConfig; const AMacroExpansionEngine: TEFMacroExpansionEngine);
begin
  FIsEnabled := False;
  if Assigned(AConfig) then
    FIsEnabled := AConfig.GetBoolean(GetConfigPath + 'IsEnabled', FIsEnabled);
end;

function TEFLogEndpoint.GetConfigPath: string;
begin
  Result := '';
end;

destructor TEFLogEndpoint.Destroy;
begin
  TEFLogger.Instance.DetachObserver(Self);
  inherited;
end;

procedure TEFLogEndpoint.UpdateObserver(const ASubject: IEFSubject; const AContext: string);
begin
  inherited;
  if SameText(AContext, '{ConfigChanged}') then
    Configure(TEFLogger(ASubject.AsObject).Config, TEFLogger(ASubject.AsObject).MacroExpansionEngine)
  else
    // Credentials must not reach the log, but a message is not a credential
    // just because the word appears in it: dropping the whole line made every
    // marker mentioning a password invisible, and with it any chance of
    // diagnosing authentication. Only the value is masked; the message itself
    // is logged.
    DoLog(MaskPasswordValues(AContext));
end;

end.
