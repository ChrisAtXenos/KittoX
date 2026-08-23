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
///  Background job runner for KittoX: a worker thread pool, separate from the
///  Indy request pool, that executes long-running operations (exports, reports,
///  imports) off the request/response cycle. A job (<see cref="TKXJob" />) is
///  submitted to the <see cref="TKXJobQueue" />, runs on a worker, reports
///  progress and completion through its <see cref="TKXJobContext" /> — which
///  publishes events on the notification EventBus — and typically produces a
///  downloadable artifact under <c>{AppHome}\Jobs\{JobId}\</c>. Job status is
///  observable (for the notification center and the status/download endpoints).
///  Scope v1: single-instance, in-memory job registry, cooperative cancellation.
/// </summary>
unit Kitto.Notification.Jobs;

{$I Kitto.Defines.inc}

interface

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  System.Generics.Collections,
  Kitto.Notification.Types;

type
  /// <summary>An observable snapshot of a job's state, returned by the queue for
  /// the notification center and the status/download endpoints.</summary>
  TKXJobInfo = record
    JobId: TGUID;
    Title: string;
    OwnerUser: string;
    Status: TKXJobStatus;
    Percent: Integer;
    Message: string;
    ResultUrl: string;
    ResultFilePath: string;
    ResultFileName: string;
    ResultContentType: string;
    Error: string;
    Submitted: TDateTime;
    Finished: TDateTime;
  end;

  /// <summary>Callback that mutates a job info record in place under the queue lock.</summary>
  TKXJobInfoUpdateProc = reference to procedure (var AInfo: TKXJobInfo);

  TKXJob = class;
  TKXJobQueue = class;

  /// <summary>Internal work item queued for a worker (job + identity).</summary>
  TKXJobItem = record
    JobId: TGUID;
    Job: TKXJob;
    Title: string;
    OwnerUser: string;
  end;

  /// <summary>
  ///  Runtime context passed to a running job. Offers progress reporting,
  ///  cooperative cancellation, event emission (to the job owner's notification
  ///  channel), the per-job artifact directory, and a way to declare the result
  ///  file that the download endpoint will later serve.
  /// </summary>
  TKXJobContext = class
  strict private
    FQueue: TKXJobQueue;
    FJobId: TGUID;
    FOwnerUser: string;
    FTitle: string;
    FCancelled: Boolean;
  private
    class threadvar FCurrent: TKXJobContext;
  public
    constructor Create(const AQueue: TKXJobQueue; const AJobId: TGUID;
      const ATitle, AOwnerUser: string);
    /// <summary>The job context of the job currently executing on this worker
    /// thread, or nil on a normal request thread. Lets deep code (e.g. an export
    /// loop) report progress/cancellation without threading a context parameter
    /// through every call.</summary>
    class function Current: TKXJobContext; static;
    /// <summary>Updates the job's percent/message and publishes a JobProgress
    /// event to the owner.</summary>
    procedure ReportProgress(const APercent: Integer; const AMessage: string);
    /// <summary>Publishes an arbitrary event to the job owner's channel.</summary>
    procedure EmitEvent(const AEvent: TKXEvent);
    /// <summary>True once cancellation has been requested; a well-behaved job
    /// checks this periodically and returns early.</summary>
    function IsCancelled: Boolean;
    /// <summary>The job's artifact directory (<c>{AppHome}\Jobs\{JobId}</c>),
    /// created on demand.</summary>
    function ArtifactDir: string;
    /// <summary>Full path of a file inside this job's artifact directory
    /// (<c>{AppHome}\Jobs\{JobId}\AFileName</c>), creating the directory.</summary>
    function ArtifactPath(const AFileName: string): string;
    /// <summary>Declares the file produced by the job as its downloadable result;
    /// on successful completion the queue emits a JobCompleted event whose action
    /// is the job download URL, and the download endpoint serves this file.</summary>
    procedure SetResultFile(const AFullPath, AClientFileName, AContentType: string);
    /// <summary>Requests cancellation (used internally by TKXJobQueue.Cancel).</summary>
    procedure RequestCancel;
    property JobId: TGUID read FJobId;
    property OwnerUser: string read FOwnerUser;
    property Title: string read FTitle;
  end;

  /// <summary>
  ///  Abstract background job. Descendants implement <see cref="Execute" /> with
  ///  the long-running work, using the context to report progress, honour
  ///  cancellation and declare the produced artifact.
  /// </summary>
  TKXJob = class abstract
  public
    /// <summary>Runs the job's work. Raising an exception marks the job failed.</summary>
    procedure Execute(const AContext: TKXJobContext); virtual; abstract;
  end;

  /// <summary>
  ///  Worker-pool job runner. Submitted jobs run on a fixed pool of worker
  ///  threads (config <c>Server/Jobs/PoolSize</c>, default 4), independent of the
  ///  Indy request threads. The queue keeps an in-memory registry of job status
  ///  for observability. Process-global single instance.
  /// </summary>
  TKXJobQueue = class
  private
    FSubmissions: TThreadedQueue<TKXJobItem>;
    FWorkers: TObjectList<TThread>;
    FInfoLock: TCriticalSection;
    FInfos: TDictionary<TGUID, TKXJobInfo>;
    FContexts: TDictionary<TGUID, TKXJobContext>;
    procedure RunItem(const AItem: TKXJobItem);
    procedure UpdateInfo(const AJobId: TGUID; const AProc: TKXJobInfoUpdateProc);
    function TryGetContext(const AJobId: TGUID): TKXJobContext;
    // Called by TKXJobContext.
    procedure InternalReportProgress(const AJobId: TGUID; const APercent: Integer; const AMessage: string);
    procedure InternalSetResultFile(const AJobId: TGUID; const AFullPath, AClientFileName, AContentType: string);
    procedure PersistJob(const AJobId: TGUID);
    procedure HydrateFromDisk;
  public
    constructor Create(const APoolSize: Integer);
    destructor Destroy; override;

    /// <summary>Submits a job for background execution and returns its id. The
    /// queue takes ownership of AJob and frees it after it runs.</summary>
    function Submit(const AJob: TKXJob; const ATitle, AOwnerUser: string): TGUID;
    /// <summary>Returns the current status snapshot of a job, if known.</summary>
    function TryGetInfo(const AJobId: TGUID; out AInfo: TKXJobInfo): Boolean;
    /// <summary>Returns the known jobs owned by the given user, newest first.</summary>
    function GetUserJobs(const AUser: string): TArray<TKXJobInfo>;
    /// <summary>Requests cooperative cancellation of a running/pending job.</summary>
    procedure Cancel(const AJobId: TGUID);
    /// <summary>Removes a job from the list (stopping it first if running) and
    /// deletes its artifact directory. Used by cancel, delete, dismiss and by the
    /// download endpoint (a downloaded job leaves the list).</summary>
    procedure RemoveJob(const AJobId: TGUID);
    /// <summary>Retention: removes finished jobs (completed/failed/cancelled)
    /// whose completion is older than AMaxAgeHours, deleting their artifacts.
    /// A no-op when AMaxAgeHours &lt;= 0.</summary>
    procedure RemoveExpired(const AMaxAgeHours: Integer);

    /// <summary>The process-global job queue, created on first use with the pool
    /// size from <c>Server/Jobs/PoolSize</c> (default 4).</summary>
    class function Instance: TKXJobQueue; static;
  end;

implementation

uses
  System.IOUtils,
  System.DateUtils,
  System.JSON,
  System.Generics.Defaults,
  Kitto.Config,
  Kitto.Config.Server,
  Kitto.Notification.EventBus;

type
  TKXJobWorker = class(TThread)
  strict private
    FQueue: TKXJobQueue;
  protected
    procedure Execute; override;
  public
    constructor Create(const AQueue: TKXJobQueue);
  end;

var
  FInstance: TKXJobQueue;
  FInstanceLock: TCriticalSection;

// Turns a user name into a filesystem-safe folder name (e.g. LDAP "DOMAIN\user"
// -> "DOMAIN_user"). The real owner is also stored inside job.json, which is the
// authority for filtering — so a sanitized-name collision is harmless.
function SanitizeUserKey(const AUser: string): string;
var
  LChar: Char;
begin
  Result := '';
  for LChar in AUser do
    if CharInSet(LChar, ['A'..'Z', 'a'..'z', '0'..'9', '-', '_', '.']) then
      Result := Result + LChar
    else
      Result := Result + '_';
  if Result = '' then
    Result := '_';
end;

// Base jobs directory: Server/Jobs/Directory (macro-expanded, same pattern as
// UploadPath), defaulting to {AppHome}\Jobs.
function JobsBaseDir: string;
begin
  Result := TKConfig.Instance.Config.GetExpandedString('Server/Jobs/Directory');
  if Result = '' then
    Result := TPath.Combine(TKConfig.AppHomePath, 'Jobs');
end;

function UserJobsDir(const AUser: string): string;
begin
  Result := TPath.Combine(JobsBaseDir, SanitizeUserKey(AUser));
end;

function JobDir(const AUser: string; const AJobId: TGUID): string;
begin
  Result := TPath.Combine(UserJobsDir(AUser), GUIDToString(AJobId));
end;

function StatusName(const AStatus: TKXJobStatus): string;
begin
  case AStatus of
    jsRunning:     Result := 'running';
    jsCompleted:   Result := 'completed';
    jsFailed:      Result := 'failed';
    jsCancelled:   Result := 'cancelled';
    jsInterrupted: Result := 'interrupted';
  else
    Result := 'pending';
  end;
end;

function StatusFromName(const AName: string): TKXJobStatus;
begin
  if SameText(AName, 'running') then Result := jsRunning
  else if SameText(AName, 'completed') then Result := jsCompleted
  else if SameText(AName, 'failed') then Result := jsFailed
  else if SameText(AName, 'cancelled') then Result := jsCancelled
  else if SameText(AName, 'interrupted') then Result := jsInterrupted
  else Result := jsPending;
end;

function JStr(const AObj: TJSONObject; const AName, ADefault: string): string;
var
  LVal: TJSONValue;
begin
  LVal := AObj.GetValue(AName);
  if LVal is TJSONString then
    Result := TJSONString(LVal).Value
  else
    Result := ADefault;
end;

// Writes a job's metadata to {JobDir}\job.json (called at submit and at the
// terminal state). Progress is intentionally not persisted (transient).
procedure SaveJobInfo(const AInfo: TKXJobInfo);
var
  LObj: TJSONObject;
  LDir, LFinished: string;
begin
  LDir := JobDir(AInfo.OwnerUser, AInfo.JobId);
  TDirectory.CreateDirectory(LDir);
  if AInfo.Finished > 0 then
    LFinished := DateToISO8601(AInfo.Finished, False)
  else
    LFinished := '';
  LObj := TJSONObject.Create;
  try
    LObj.AddPair('jobId', GUIDToString(AInfo.JobId));
    LObj.AddPair('owner', AInfo.OwnerUser);
    LObj.AddPair('title', AInfo.Title);
    LObj.AddPair('status', StatusName(AInfo.Status));
    LObj.AddPair('resultFileName', AInfo.ResultFileName);
    LObj.AddPair('resultContentType', AInfo.ResultContentType);
    LObj.AddPair('submitted', DateToISO8601(AInfo.Submitted, False));
    LObj.AddPair('finished', LFinished);
    LObj.AddPair('error', AInfo.Error);
    TFile.WriteAllText(TPath.Combine(LDir, 'job.json'), LObj.ToJSON, TEncoding.UTF8);
  finally
    LObj.Free;
  end;
end;

function LoadJobInfo(const AJsonFile: string; out AInfo: TKXJobInfo): Boolean;
var
  LObj: TJSONObject;
  LFinished: string;
begin
  Result := False;
  AInfo := Default(TKXJobInfo);
  try
    LObj := TJSONObject.ParseJSONValue(TFile.ReadAllText(AJsonFile, TEncoding.UTF8)) as TJSONObject;
  except
    LObj := nil;
  end;
  if LObj = nil then
    Exit;
  try
    try
      AInfo.JobId := StringToGUID(JStr(LObj, 'jobId', ''));
    except
      Exit;
    end;
    AInfo.OwnerUser := JStr(LObj, 'owner', '');
    AInfo.Title := JStr(LObj, 'title', '');
    AInfo.Status := StatusFromName(JStr(LObj, 'status', 'pending'));
    AInfo.ResultFileName := JStr(LObj, 'resultFileName', '');
    AInfo.ResultContentType := JStr(LObj, 'resultContentType', '');
    try
      AInfo.Submitted := ISO8601ToDate(JStr(LObj, 'submitted', ''), False);
    except
      AInfo.Submitted := 0;
    end;
    LFinished := JStr(LObj, 'finished', '');
    if LFinished = '' then
      AInfo.Finished := 0
    else
      try
        AInfo.Finished := ISO8601ToDate(LFinished, False);
      except
        AInfo.Finished := 0;
      end;
    AInfo.Error := JStr(LObj, 'error', '');
    Result := True;
  finally
    LObj.Free;
  end;
end;

{ TKXJobContext }

constructor TKXJobContext.Create(const AQueue: TKXJobQueue; const AJobId: TGUID;
  const ATitle, AOwnerUser: string);
begin
  inherited Create;
  FQueue := AQueue;
  FJobId := AJobId;
  FTitle := ATitle;
  FOwnerUser := AOwnerUser;
  FCancelled := False;
end;

class function TKXJobContext.Current: TKXJobContext;
begin
  Result := FCurrent;
end;

procedure TKXJobContext.ReportProgress(const APercent: Integer; const AMessage: string);
begin
  FQueue.InternalReportProgress(FJobId, APercent, AMessage);
end;

procedure TKXJobContext.EmitEvent(const AEvent: TKXEvent);
begin
  TKXEventBus.Instance.PublishToUser(FOwnerUser, AEvent);
end;

function TKXJobContext.IsCancelled: Boolean;
begin
  Result := FCancelled;
end;

procedure TKXJobContext.RequestCancel;
begin
  FCancelled := True;
end;

function TKXJobContext.ArtifactDir: string;
begin
  Result := JobDir(FOwnerUser, FJobId);
  TDirectory.CreateDirectory(Result);
end;

function TKXJobContext.ArtifactPath(const AFileName: string): string;
begin
  Result := TPath.Combine(ArtifactDir, AFileName);
end;

procedure TKXJobContext.SetResultFile(const AFullPath, AClientFileName, AContentType: string);
begin
  FQueue.InternalSetResultFile(FJobId, AFullPath, AClientFileName, AContentType);
end;

{ TKXJobWorker }

constructor TKXJobWorker.Create(const AQueue: TKXJobQueue);
begin
  FQueue := AQueue;
  inherited Create(False);
end;

procedure TKXJobWorker.Execute;
var
  LItem: TKXJobItem;
begin
  while not Terminated do
  begin
    if FQueue.FSubmissions.PopItem(LItem) = wrSignaled then
    begin
      // On DoShutDown some RTL versions unblock PopItem with wrSignaled but a
      // default (empty) item; a legitimately submitted item always carries a
      // non-nil Job, so a nil Job is the shutdown sentinel — stop the worker.
      if LItem.Job = nil then
        Break;
      try
        FQueue.RunItem(LItem);
      finally
        // The queue owns submitted jobs and frees them after running.
        FreeAndNil(LItem.Job);
      end;
    end
    else
      Break; // shutdown / abandoned
  end;
end;

{ TKXJobQueue }

constructor TKXJobQueue.Create(const APoolSize: Integer);
var
  I: Integer;
  LSize: Integer;
begin
  inherited Create;
  LSize := APoolSize;
  if LSize < 1 then
    LSize := 1;
  FInfoLock := TCriticalSection.Create;
  FInfos := TDictionary<TGUID, TKXJobInfo>.Create;
  FContexts := TDictionary<TGUID, TKXJobContext>.Create;
  FSubmissions := TThreadedQueue<TKXJobItem>.Create(1000, INFINITE, INFINITE);
  // Reload persisted jobs from disk (they survive process restarts); best-effort.
  try
    HydrateFromDisk;
  except
    // ignore: a corrupt/inaccessible jobs folder must not stop the queue
  end;
  FWorkers := TObjectList<TThread>.Create(True);
  for I := 1 to LSize do
    FWorkers.Add(TKXJobWorker.Create(Self));
end;

destructor TKXJobQueue.Destroy;
var
  LThread: TThread;
begin
  if Assigned(FSubmissions) then
    FSubmissions.DoShutDown; // wakes the workers blocked in PopItem
  if Assigned(FWorkers) then
    for LThread in FWorkers do
      LThread.Terminate;
  FreeAndNil(FWorkers); // frees/joins each worker
  FreeAndNil(FSubmissions);
  FreeAndNil(FContexts);
  FreeAndNil(FInfos);
  FreeAndNil(FInfoLock);
  inherited;
end;

function TKXJobQueue.Submit(const AJob: TKXJob; const ATitle, AOwnerUser: string): TGUID;
var
  LItem: TKXJobItem;
  LInfo: TKXJobInfo;
begin
  CreateGUID(Result);

  LInfo := Default(TKXJobInfo);
  LInfo.JobId := Result;
  LInfo.Title := ATitle;
  LInfo.OwnerUser := AOwnerUser;
  LInfo.Status := jsPending;
  LInfo.Submitted := Now;
  FInfoLock.Enter;
  try
    FInfos.AddOrSetValue(Result, LInfo);
  finally
    FInfoLock.Leave;
  end;
  SaveJobInfo(LInfo); // persist (Pending) so it survives a restart

  LItem.JobId := Result;
  LItem.Job := AJob;
  LItem.Title := ATitle;
  LItem.OwnerUser := AOwnerUser;
  FSubmissions.PushItem(LItem);
end;

procedure TKXJobQueue.RunItem(const AItem: TKXJobItem);
var
  LContext: TKXJobContext;
  LResultUrl: string;
  LError: string;
begin
  LContext := TKXJobContext.Create(Self, AItem.JobId, AItem.Title, AItem.OwnerUser);
  try
    FInfoLock.Enter;
    try
      FContexts.AddOrSetValue(AItem.JobId, LContext);
    finally
      FInfoLock.Leave;
    end;
    TKXJobContext.FCurrent := LContext; // per-worker-thread current context
    UpdateInfo(AItem.JobId,
      procedure (var AInfo: TKXJobInfo)
      begin
        AInfo.Status := jsRunning;
      end);
    TKXEventBus.Instance.PublishToUser(AItem.OwnerUser,
      TKXEvent.JobStarted(AItem.OwnerUser, AItem.Title, GUIDToString(AItem.JobId)));

    try
      AItem.Job.Execute(LContext);

      if LContext.IsCancelled then
        UpdateInfo(AItem.JobId,
          procedure (var AInfo: TKXJobInfo)
          begin
            AInfo.Status := jsCancelled;
            AInfo.Finished := Now;
          end)
      else
      begin
        LResultUrl := '';
        FInfoLock.Enter;
        try
          if FInfos.ContainsKey(AItem.JobId) and (FInfos[AItem.JobId].ResultFilePath <> '') then
            LResultUrl := 'kx/job/' + JobIdToUrl(AItem.JobId) + '/download';
        finally
          FInfoLock.Leave;
        end;
        UpdateInfo(AItem.JobId,
          procedure (var AInfo: TKXJobInfo)
          begin
            AInfo.Status := jsCompleted;
            AInfo.Percent := 100;
            AInfo.Finished := Now;
            AInfo.ResultUrl := LResultUrl;
          end);
        TKXEventBus.Instance.PublishToUser(AItem.OwnerUser,
          TKXEvent.JobCompleted(AItem.OwnerUser, AItem.Title, GUIDToString(AItem.JobId), LResultUrl));
        PersistJob(AItem.JobId);
      end;
    except
      on E: Exception do
      begin
        LError := E.Message;
        UpdateInfo(AItem.JobId,
          procedure (var AInfo: TKXJobInfo)
          begin
            AInfo.Status := jsFailed;
            AInfo.Finished := Now;
            AInfo.Error := LError;
          end);
        TKXEventBus.Instance.PublishToUser(AItem.OwnerUser,
          TKXEvent.JobFailed(AItem.OwnerUser, AItem.Title, GUIDToString(AItem.JobId), LError));
        PersistJob(AItem.JobId);
      end;
    end;
  finally
    TKXJobContext.FCurrent := nil;
    FInfoLock.Enter;
    try
      FContexts.Remove(AItem.JobId);
    finally
      FInfoLock.Leave;
    end;
    LContext.Free;
  end;
end;

procedure TKXJobQueue.UpdateInfo(const AJobId: TGUID; const AProc: TKXJobInfoUpdateProc);
var
  LInfo: TKXJobInfo;
begin
  FInfoLock.Enter;
  try
    if FInfos.TryGetValue(AJobId, LInfo) then
    begin
      AProc(LInfo);
      FInfos.AddOrSetValue(AJobId, LInfo);
    end;
  finally
    FInfoLock.Leave;
  end;
end;

function TKXJobQueue.TryGetContext(const AJobId: TGUID): TKXJobContext;
begin
  FInfoLock.Enter;
  try
    if not FContexts.TryGetValue(AJobId, Result) then
      Result := nil;
  finally
    FInfoLock.Leave;
  end;
end;

procedure TKXJobQueue.InternalReportProgress(const AJobId: TGUID; const APercent: Integer; const AMessage: string);
var
  LOwner: string;
begin
  LOwner := '';
  FInfoLock.Enter;
  try
    if FInfos.ContainsKey(AJobId) then
      LOwner := FInfos[AJobId].OwnerUser;
  finally
    FInfoLock.Leave;
  end;
  UpdateInfo(AJobId,
    procedure (var AInfo: TKXJobInfo)
    begin
      AInfo.Percent := APercent;
      AInfo.Message := AMessage;
    end);
  if LOwner <> '' then
    TKXEventBus.Instance.PublishToUser(LOwner,
      TKXEvent.JobProgress(LOwner, GUIDToString(AJobId), AMessage, APercent));
end;

procedure TKXJobQueue.InternalSetResultFile(const AJobId: TGUID; const AFullPath, AClientFileName, AContentType: string);
begin
  UpdateInfo(AJobId,
    procedure (var AInfo: TKXJobInfo)
    begin
      AInfo.ResultFilePath := AFullPath;
      AInfo.ResultFileName := AClientFileName;
      AInfo.ResultContentType := AContentType;
    end);
end;

function TKXJobQueue.TryGetInfo(const AJobId: TGUID; out AInfo: TKXJobInfo): Boolean;
begin
  FInfoLock.Enter;
  try
    Result := FInfos.TryGetValue(AJobId, AInfo);
  finally
    FInfoLock.Leave;
  end;
end;

function TKXJobQueue.GetUserJobs(const AUser: string): TArray<TKXJobInfo>;
var
  LInfo: TKXJobInfo;
  LList: TList<TKXJobInfo>;
begin
  LList := TList<TKXJobInfo>.Create;
  try
    FInfoLock.Enter;
    try
      for LInfo in FInfos.Values do
        if SameText(LInfo.OwnerUser, AUser) then
          LList.Add(LInfo);
    finally
      FInfoLock.Leave;
    end;
    LList.Sort(TComparer<TKXJobInfo>.Construct(
      function (const A, B: TKXJobInfo): Integer
      begin
        Result := CompareDateTime(B.Submitted, A.Submitted); // newest first
      end));
    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

procedure TKXJobQueue.Cancel(const AJobId: TGUID);
var
  LContext: TKXJobContext;
begin
  LContext := TryGetContext(AJobId);
  if Assigned(LContext) then
    LContext.RequestCancel
  else
    UpdateInfo(AJobId,
      procedure (var AInfo: TKXJobInfo)
      begin
        if AInfo.Status = jsPending then
          AInfo.Status := jsCancelled;
      end);
end;

procedure TKXJobQueue.RemoveJob(const AJobId: TGUID);
var
  LContext: TKXJobContext;
  LOwner: string;
  LDir: string;
begin
  // Stop it first if it is currently running (cooperative — the worker checks
  // IsCancelled and aborts without producing a file).
  LContext := TryGetContext(AJobId);
  if Assigned(LContext) then
    LContext.RequestCancel;

  // Remove it from the list, capturing the owner to locate its folder.
  LOwner := '';
  FInfoLock.Enter;
  try
    if FInfos.ContainsKey(AJobId) then
      LOwner := FInfos[AJobId].OwnerUser;
    FInfos.Remove(AJobId);
  finally
    FInfoLock.Leave;
  end;
  if LOwner = '' then
    Exit;

  // Delete the whole job directory (metadata + artifact). Best-effort: a
  // just-cancelled worker may still hold a handle; the retention pass retries.
  LDir := JobDir(LOwner, AJobId);
  if TDirectory.Exists(LDir) then
    try
      TDirectory.Delete(LDir, True);
    except
      // ignore — retention cleanup retries
    end;
end;

procedure TKXJobQueue.RemoveExpired(const AMaxAgeHours: Integer);
var
  LNow: TDateTime;
  LExpired: TArray<TGUID>;
  LPair: TPair<TGUID, TKXJobInfo>;
  I: Integer;
begin
  if AMaxAgeHours <= 0 then
    Exit;
  LNow := Now;
  LExpired := [];
  FInfoLock.Enter;
  try
    for LPair in FInfos do
      if (LPair.Value.Status in [jsCompleted, jsFailed, jsCancelled, jsInterrupted])
        and (LPair.Value.Finished > 0)
        and (HoursBetween(LNow, LPair.Value.Finished) >= AMaxAgeHours) then
        LExpired := LExpired + [LPair.Key];
  finally
    FInfoLock.Leave;
  end;
  for I := 0 to High(LExpired) do
    RemoveJob(LExpired[I]);
end;

procedure TKXJobQueue.PersistJob(const AJobId: TGUID);
var
  LInfo: TKXJobInfo;
begin
  if TryGetInfo(AJobId, LInfo) then
    SaveJobInfo(LInfo);
end;

procedure TKXJobQueue.HydrateFromDisk;
var
  LBase, LUserDir, LJobDir, LJsonFile, LArtifact: string;
  LInfo: TKXJobInfo;
begin
  LBase := JobsBaseDir;
  if not TDirectory.Exists(LBase) then
    Exit;
  for LUserDir in TDirectory.GetDirectories(LBase) do
    for LJobDir in TDirectory.GetDirectories(LUserDir) do
    begin
      LJsonFile := TPath.Combine(LJobDir, 'job.json');
      if not TFile.Exists(LJsonFile) then
        Continue;
      if not LoadJobInfo(LJsonFile, LInfo) then
        Continue;
      // A job still pending/running at the last shutdown cannot be resumed.
      if LInfo.Status in [jsPending, jsRunning] then
      begin
        LInfo.Status := jsInterrupted;
        if LInfo.Finished <= 0 then
          LInfo.Finished := Now;
      end;
      // Completed: reconstruct the artifact path/url; if the file is gone, fail.
      if (LInfo.Status = jsCompleted) and (LInfo.ResultFileName <> '') then
      begin
        LArtifact := TPath.Combine(LJobDir, LInfo.ResultFileName);
        if TFile.Exists(LArtifact) then
        begin
          LInfo.ResultFilePath := LArtifact;
          LInfo.ResultUrl := 'kx/job/' + JobIdToUrl(LInfo.JobId) + '/download';
        end
        else
        begin
          LInfo.Status := jsFailed;
          LInfo.Error := 'Artifact file missing after restart.';
        end;
      end;
      FInfos.AddOrSetValue(LInfo.JobId, LInfo);
    end;
end;

class function TKXJobQueue.Instance: TKXJobQueue;
begin
  if FInstance = nil then
  begin
    FInstanceLock.Enter;
    try
      if FInstance = nil then
        FInstance := TKXJobQueue.Create(TKConfig.Instance.Server.Jobs.PoolSize);
    finally
      FInstanceLock.Leave;
    end;
  end;
  Result := FInstance;
end;

initialization
  FInstanceLock := TCriticalSection.Create;

finalization
  FreeAndNil(FInstance);
  FreeAndNil(FInstanceLock);

end.
