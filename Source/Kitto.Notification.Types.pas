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
///  Base value types for the KittoX notification / background-job subsystem:
///  the server-to-client event (<see cref="TKXEvent" />), its kind/severity
///  enumerations and the job status enumeration. TKXEvent is a plain value
///  record of immutable fields (strings + enums), so it can be safely copied
///  into per-session queues and passed across threads without any ownership
///  concern; structured extra data travels as a JSON string in Payload.
/// </summary>
unit Kitto.Notification.Types;

{$I Kitto.Defines.inc}

interface

type
  /// <summary>The kind of a notification event, used to pick the client-side
  /// SSE event name and the UI treatment.</summary>
  TKXEventKind = (
    /// <summary>Generic informational message.</summary>
    ekInfo,
    /// <summary>A background job has been accepted and started.</summary>
    ekJobStarted,
    /// <summary>Progress update of a running job (Payload carries percent).</summary>
    ekJobProgress,
    /// <summary>A job finished successfully (Action carries the result URL).</summary>
    ekJobCompleted,
    /// <summary>A job ended with an error (Body carries the message).</summary>
    ekJobFailed,
    /// <summary>A system-wide broadcast message.</summary>
    ekBroadcast);

  /// <summary>Visual severity of an event, mapped to icon/color on the client.</summary>
  TKXEventSeverity = (esInfo, esSuccess, esWarning, esError);

  /// <summary>Lifecycle status of a background job. <c>jsInterrupted</c> is
  /// assigned on startup to a job that was still pending/running when the process
  /// last stopped (its worker is gone and it cannot be resumed).</summary>
  TKXJobStatus = (jsPending, jsRunning, jsCompleted, jsFailed, jsCancelled, jsInterrupted);

  /// <summary>
  ///  A server-to-client notification event. A pure value type: all fields are
  ///  strings or enums, so an event is trivially copyable and thread-safe. It is
  ///  published on the <c>TKXEventBus</c> to a <c>Topic</c> and delivered to
  ///  subscribed sessions over SSE.
  /// </summary>
  TKXEvent = record
    /// <summary>The event kind (drives the SSE event name and UI treatment).</summary>
    Kind: TKXEventKind;
    /// <summary>Visual severity.</summary>
    Severity: TKXEventSeverity;
    /// <summary>Short title shown in the notification center / toast.</summary>
    Title: string;
    /// <summary>Longer descriptive text (optional).</summary>
    Body: string;
    /// <summary>Delivery channel, e.g. <c>user:carlo</c>, <c>system</c>, <c>job:{id}</c>.</summary>
    Topic: string;
    /// <summary>Associated action: a URL (e.g. a download link) or an action id;
    /// empty when the event has no action.</summary>
    Action: string;
    /// <summary>Optional structured extra data, carried as a JSON object string
    /// (e.g. <c>{"jobId":"..","percent":42}</c>). Empty when not used.</summary>
    Payload: string;
    /// <summary>Server timestamp of creation.</summary>
    Created: TDateTime;
    /// <summary>When True the client also shows a transient toast for this event.</summary>
    Toast: Boolean;

    /// <summary>Builds a "job started" event for the given user job.</summary>
    class function JobStarted(const AUser, ATitle, AJobId: string): TKXEvent; static;
    /// <summary>Builds a "job progress" event carrying percent and message.</summary>
    class function JobProgress(const AUser, AJobId, AMessage: string; APercent: Integer): TKXEvent; static;
    /// <summary>Builds a "job completed" event whose Action is the result URL.</summary>
    class function JobCompleted(const AUser, ATitle, AJobId, AResultUrl: string): TKXEvent; static;
    /// <summary>Builds a "job failed" event whose Body carries the error text.</summary>
    class function JobFailed(const AUser, ATitle, AJobId, AError: string): TKXEvent; static;

    /// <summary>The client-side SSE event name for this event's Kind
    /// (e.g. <c>job-progress</c>, <c>job-completed</c>).</summary>
    function EventName: string;
    /// <summary>Serializes the event to a compact JSON object (the SSE data
    /// payload). The Payload field, if non-empty and valid JSON, is embedded
    /// as a nested object.</summary>
    function ToJSON: string;
    /// <summary>Formats the event as a complete SSE frame
    /// (<c>event: name\n data: {json}\n\n</c>).</summary>
    function ToSSEFrame: string;
  end;

/// <summary>Returns the lowercase string form of a severity (info/success/warning/error).</summary>
function SeverityToStr(const ASeverity: TKXEventSeverity): string;

/// <summary>Formats a job id as a URL-safe token (hyphenated hex, no braces).</summary>
function JobIdToUrl(const AJobId: TGUID): string;
/// <summary>Parses a URL job-id token back to a TGUID; returns False if invalid.</summary>
function TryUrlToJobId(const AToken: string; out AJobId: TGUID): Boolean;

const
  /// <summary>Topic prefix for per-user delivery: full topic is <c>user:{username}</c>.</summary>
  KX_TOPIC_USER   = 'user:';
  /// <summary>Topic for system-wide broadcast delivery.</summary>
  KX_TOPIC_SYSTEM = 'system';

implementation

uses
  System.SysUtils,
  System.DateUtils,
  System.JSON;

function SeverityToStr(const ASeverity: TKXEventSeverity): string;
begin
  case ASeverity of
    esSuccess: Result := 'success';
    esWarning: Result := 'warning';
    esError:   Result := 'error';
  else
    Result := 'info';
  end;
end;

function JobIdToUrl(const AJobId: TGUID): string;
begin
  // Strip the enclosing braces of the {8-4-4-4-12} GUIDToString form.
  Result := Copy(GUIDToString(AJobId), 2, 36);
end;

function TryUrlToJobId(const AToken: string; out AJobId: TGUID): Boolean;
begin
  Result := True;
  try
    AJobId := StringToGUID('{' + AToken + '}');
  except
    Result := False;
    AJobId := TGUID.Empty;
  end;
end;

function KindToStr(const AKind: TKXEventKind): string;
begin
  case AKind of
    ekJobStarted:   Result := 'job-started';
    ekJobProgress:  Result := 'job-progress';
    ekJobCompleted: Result := 'job-completed';
    ekJobFailed:    Result := 'job-failed';
    ekBroadcast:    Result := 'broadcast';
  else
    Result := 'info';
  end;
end;

{ TKXEvent }

class function TKXEvent.JobStarted(const AUser, ATitle, AJobId: string): TKXEvent;
begin
  Result := Default(TKXEvent);
  Result.Kind := ekJobStarted;
  Result.Severity := esInfo;
  Result.Title := ATitle;
  Result.Topic := KX_TOPIC_USER + AUser;
  Result.Payload := Format('{"jobId":"%s"}', [AJobId]);
  Result.Created := Now;
  Result.Toast := True;
end;

class function TKXEvent.JobProgress(const AUser, AJobId, AMessage: string; APercent: Integer): TKXEvent;
begin
  Result := Default(TKXEvent);
  Result.Kind := ekJobProgress;
  Result.Severity := esInfo;
  Result.Title := AMessage;
  Result.Topic := KX_TOPIC_USER + AUser;
  Result.Payload := Format('{"jobId":"%s","percent":%d}', [AJobId, APercent]);
  Result.Created := Now;
  Result.Toast := False;
end;

class function TKXEvent.JobCompleted(const AUser, ATitle, AJobId, AResultUrl: string): TKXEvent;
begin
  Result := Default(TKXEvent);
  Result.Kind := ekJobCompleted;
  Result.Severity := esSuccess;
  Result.Title := ATitle;
  Result.Topic := KX_TOPIC_USER + AUser;
  Result.Action := AResultUrl;
  Result.Payload := Format('{"jobId":"%s"}', [AJobId]);
  Result.Created := Now;
  Result.Toast := True;
end;

class function TKXEvent.JobFailed(const AUser, ATitle, AJobId, AError: string): TKXEvent;
begin
  Result := Default(TKXEvent);
  Result.Kind := ekJobFailed;
  Result.Severity := esError;
  Result.Title := ATitle;
  Result.Body := AError;
  Result.Topic := KX_TOPIC_USER + AUser;
  Result.Payload := Format('{"jobId":"%s"}', [AJobId]);
  Result.Created := Now;
  Result.Toast := True;
end;

function TKXEvent.EventName: string;
begin
  Result := KindToStr(Kind);
end;

function TKXEvent.ToJSON: string;
var
  LObj: TJSONObject;
  LPayload: TJSONValue;
begin
  LObj := TJSONObject.Create;
  try
    LObj.AddPair('kind', KindToStr(Kind));
    LObj.AddPair('severity', SeverityToStr(Severity));
    LObj.AddPair('title', Title);
    LObj.AddPair('body', Body);
    LObj.AddPair('action', Action);
    LObj.AddPair('toast', TJSONBool.Create(Toast));
    LObj.AddPair('created', DateToISO8601(Created, False));
    if Payload <> '' then
    begin
      LPayload := TJSONObject.ParseJSONValue(Payload);
      if LPayload <> nil then
        LObj.AddPair('payload', LPayload);
    end;
    Result := LObj.ToJSON;
  finally
    LObj.Free;
  end;
end;

function TKXEvent.ToSSEFrame: string;
begin
  // SSE frame: an "event:" line naming the client listener, a single-line
  // "data:" line with the JSON payload, terminated by a blank line.
  Result := 'event: ' + EventName + #10 + 'data: ' + ToJSON + #10#10;
end;

end.
