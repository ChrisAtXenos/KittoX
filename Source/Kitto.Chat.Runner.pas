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
///  In-memory conversation store and asynchronous runner for the help chat.
///  <see cref="TKXChatStore" /> keeps one conversation per user (v1: single
///  thread, no DB persistence — the history lives for the session). Sending a
///  message appends the user message plus a <c>Pending</c> assistant message and
///  submits a request to <see cref="TKXChatRunner" />, a small worker pool
///  separate from the Indy request threads (so a slow provider call — e.g. an
///  LLM HTTP round-trip — never blocks the web server) and separate from the
///  notification job queue (so chat replies do not surface in the bell). The
///  worker calls the configured provider and writes the reply back into the
///  store; the client retrieves it by polling the chat poll endpoint.
/// </summary>
unit Kitto.Chat.Runner;

{$I Kitto.Defines.inc}

interface

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  System.Generics.Collections,
  Kitto.Chat.Provider;

type
  /// <summary>
  ///  Per-user, in-memory conversation store. Thread-safe: the web (request)
  ///  threads append messages and read history, while runner (worker) threads
  ///  complete the pending assistant messages. Process-global singleton.
  /// </summary>
  TKXChatStore = class
  strict private
    FLock: TCriticalSection;
    FConversations: TObjectDictionary<string, TList<TKXChatMessage>>;
    function EnsureList(const AUser: string): TList<TKXChatMessage>;
    function IndexOfId(const AList: TList<TKXChatMessage>; const AId: string): Integer;
  public
    constructor Create;
    destructor Destroy; override;

    /// <summary>Appends a user message to the user's conversation and returns it.</summary>
    function AddUserMessage(const AUser, AContent: string): TKXChatMessage;
    /// <summary>Appends a placeholder assistant message (Pending) and returns its id;
    /// the runner later completes it in place.</summary>
    function AddPendingAssistant(const AUser: string): string;
    /// <summary>Marks the pending assistant message AId as completed with AContent.</summary>
    procedure CompleteAssistant(const AUser, AId, AContent: string);
    /// <summary>Marks the pending assistant message AId as failed with an error text.</summary>
    procedure FailAssistant(const AUser, AId, AError: string);
    /// <summary>Returns a copy of the assistant message AId, if present.</summary>
    function TryGetMessage(const AUser, AId: string; out AMessage: TKXChatMessage): Boolean;
    /// <summary>Returns the full conversation of the user, in order.</summary>
    function GetMessages(const AUser: string): TArray<TKXChatMessage>;
    /// <summary>Returns the completed (non-pending, non-error) messages to feed the
    /// provider as context, most recent AMaxMessages kept (0 = all).</summary>
    function GetHistory(const AUser: string; const AMaxMessages: Integer): TArray<TKXChatMessage>;
    /// <summary>Clears the user's conversation.</summary>
    procedure Clear(const AUser: string);

    /// <summary>The process-global conversation store.</summary>
    class function Instance: TKXChatStore; static;
  end;

  /// <summary>
  ///  Worker-pool runner that produces assistant replies off the request thread.
  ///  Submitted requests run the configured provider and write the reply into the
  ///  <see cref="TKXChatStore" />. Pool size from <c>HelpChat/PoolSize</c>
  ///  (default 2). Process-global singleton.
  /// </summary>
  TKXChatRunner = class
  private
  type
    TKXChatRequest = record
      UserName: string;
      AssistantId: string;
      ProviderName: string;
      Context: TKXChatContext;
      MaxHistory: Integer;
    end;
  private
    FSubmissions: TThreadedQueue<TKXChatRequest>;
    FWorkers: TObjectList<TThread>;
    procedure RunRequest(const ARequest: TKXChatRequest);
  public
    constructor Create(const APoolSize: Integer);
    destructor Destroy; override;

    /// <summary>Submits a request: the worker will run AProviderName against the
    /// user's current history and complete the assistant message AAssistantId.</summary>
    procedure Submit(const AUser, AAssistantId, AProviderName: string;
      const AContext: TKXChatContext; const AMaxHistory: Integer);

    /// <summary>The process-global chat runner, created on first use.</summary>
    class function Instance: TKXChatRunner; static;
  end;

/// <summary>Formats a fresh URL-safe message id (hyphenated hex, no braces).</summary>
function NewChatId: string;

implementation

uses
  Kitto.Config;

type
  TKXChatWorker = class(TThread)
  strict private
    FRunner: TKXChatRunner;
  protected
    procedure Execute; override;
  public
    constructor Create(const ARunner: TKXChatRunner);
  end;

var
  FStoreInstance: TKXChatStore;
  FRunnerInstance: TKXChatRunner;
  FSingletonLock: TCriticalSection;

function NewChatId: string;
var
  LGuid: TGUID;
begin
  CreateGUID(LGuid);
  Result := Copy(GUIDToString(LGuid), 2, 36);
end;

{ TKXChatStore }

constructor TKXChatStore.Create;
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FConversations := TObjectDictionary<string, TList<TKXChatMessage>>.Create([doOwnsValues]);
end;

destructor TKXChatStore.Destroy;
begin
  FConversations.Free;
  FLock.Free;
  inherited;
end;

function TKXChatStore.EnsureList(const AUser: string): TList<TKXChatMessage>;
begin
  if not FConversations.TryGetValue(AUser, Result) then
  begin
    Result := TList<TKXChatMessage>.Create;
    FConversations.Add(AUser, Result);
  end;
end;

function TKXChatStore.IndexOfId(const AList: TList<TKXChatMessage>; const AId: string): Integer;
var
  I: Integer;
begin
  for I := 0 to AList.Count - 1 do
    if AList[I].Id = AId then
      Exit(I);
  Result := -1;
end;

function TKXChatStore.AddUserMessage(const AUser, AContent: string): TKXChatMessage;
begin
  Result := Default(TKXChatMessage);
  Result.Id := NewChatId;
  Result.Role := crUser;
  Result.Content := AContent;
  Result.Created := Now;
  FLock.Enter;
  try
    EnsureList(AUser).Add(Result);
  finally
    FLock.Leave;
  end;
end;

function TKXChatStore.AddPendingAssistant(const AUser: string): string;
var
  LMessage: TKXChatMessage;
begin
  LMessage := Default(TKXChatMessage);
  LMessage.Id := NewChatId;
  LMessage.Role := crAssistant;
  LMessage.Created := Now;
  LMessage.Pending := True;
  FLock.Enter;
  try
    EnsureList(AUser).Add(LMessage);
  finally
    FLock.Leave;
  end;
  Result := LMessage.Id;
end;

procedure TKXChatStore.CompleteAssistant(const AUser, AId, AContent: string);
var
  LList: TList<TKXChatMessage>;
  LIndex: Integer;
  LMessage: TKXChatMessage;
begin
  FLock.Enter;
  try
    if FConversations.TryGetValue(AUser, LList) then
    begin
      LIndex := IndexOfId(LList, AId);
      if LIndex >= 0 then
      begin
        LMessage := LList[LIndex];
        LMessage.Content := AContent;
        LMessage.Pending := False;
        LMessage.IsError := False;
        LList[LIndex] := LMessage;
      end;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TKXChatStore.FailAssistant(const AUser, AId, AError: string);
var
  LList: TList<TKXChatMessage>;
  LIndex: Integer;
  LMessage: TKXChatMessage;
begin
  FLock.Enter;
  try
    if FConversations.TryGetValue(AUser, LList) then
    begin
      LIndex := IndexOfId(LList, AId);
      if LIndex >= 0 then
      begin
        LMessage := LList[LIndex];
        LMessage.Content := AError;
        LMessage.Pending := False;
        LMessage.IsError := True;
        LList[LIndex] := LMessage;
      end;
    end;
  finally
    FLock.Leave;
  end;
end;

function TKXChatStore.TryGetMessage(const AUser, AId: string; out AMessage: TKXChatMessage): Boolean;
var
  LList: TList<TKXChatMessage>;
  LIndex: Integer;
begin
  Result := False;
  FLock.Enter;
  try
    if FConversations.TryGetValue(AUser, LList) then
    begin
      LIndex := IndexOfId(LList, AId);
      if LIndex >= 0 then
      begin
        AMessage := LList[LIndex];
        Result := True;
      end;
    end;
  finally
    FLock.Leave;
  end;
end;

function TKXChatStore.GetMessages(const AUser: string): TArray<TKXChatMessage>;
var
  LList: TList<TKXChatMessage>;
begin
  FLock.Enter;
  try
    if FConversations.TryGetValue(AUser, LList) then
      Result := LList.ToArray
    else
      Result := [];
  finally
    FLock.Leave;
  end;
end;

function TKXChatStore.GetHistory(const AUser: string; const AMaxMessages: Integer): TArray<TKXChatMessage>;
var
  LList: TList<TKXChatMessage>;
  LKept: TList<TKXChatMessage>;
  I: Integer;
begin
  FLock.Enter;
  try
    if not FConversations.TryGetValue(AUser, LList) then
      Exit(nil);
    LKept := TList<TKXChatMessage>.Create;
    try
      for I := 0 to LList.Count - 1 do
        if not LList[I].Pending and not LList[I].IsError then
          LKept.Add(LList[I]);
      // Keep only the most recent AMaxMessages (0 or negative = all).
      if (AMaxMessages > 0) and (LKept.Count > AMaxMessages) then
        LKept.DeleteRange(0, LKept.Count - AMaxMessages);
      Result := LKept.ToArray;
    finally
      LKept.Free;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TKXChatStore.Clear(const AUser: string);
begin
  FLock.Enter;
  try
    FConversations.Remove(AUser);
  finally
    FLock.Leave;
  end;
end;

class function TKXChatStore.Instance: TKXChatStore;
begin
  if FStoreInstance = nil then
  begin
    FSingletonLock.Enter;
    try
      if FStoreInstance = nil then
        FStoreInstance := TKXChatStore.Create;
    finally
      FSingletonLock.Leave;
    end;
  end;
  Result := FStoreInstance;
end;

{ TKXChatWorker }

constructor TKXChatWorker.Create(const ARunner: TKXChatRunner);
begin
  FRunner := ARunner;
  inherited Create(False);
end;

procedure TKXChatWorker.Execute;
var
  LRequest: TKXChatRunner.TKXChatRequest;
begin
  while not Terminated do
  begin
    if FRunner.FSubmissions.PopItem(LRequest) = wrSignaled then
    begin
      // On DoShutDown some RTL versions unblock PopItem with wrSignaled but a
      // default (empty) item; a real request always carries a user name, so an
      // empty user name is the shutdown sentinel.
      if LRequest.UserName = '' then
        Break;
      FRunner.RunRequest(LRequest);
    end
    else
      Break; // shutdown / abandoned
  end;
end;

{ TKXChatRunner }

constructor TKXChatRunner.Create(const APoolSize: Integer);
var
  I, LSize: Integer;
begin
  inherited Create;
  LSize := APoolSize;
  if LSize < 1 then
    LSize := 1;
  FSubmissions := TThreadedQueue<TKXChatRequest>.Create(1000, INFINITE, INFINITE);
  FWorkers := TObjectList<TThread>.Create(True);
  for I := 1 to LSize do
    FWorkers.Add(TKXChatWorker.Create(Self));
end;

destructor TKXChatRunner.Destroy;
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
  inherited;
end;

procedure TKXChatRunner.RunRequest(const ARequest: TKXChatRequest);
var
  LProvider: IKXChatProvider;
  LReply: string;
begin
  try
    LProvider := TKXChatProviderRegistry.CreateProvider(ARequest.ProviderName);
    LReply := LProvider.Generate(
      TKXChatStore.Instance.GetHistory(ARequest.UserName, ARequest.MaxHistory),
      ARequest.Context, nil);
    TKXChatStore.Instance.CompleteAssistant(ARequest.UserName, ARequest.AssistantId, LReply);
  except
    on E: Exception do
      TKXChatStore.Instance.FailAssistant(ARequest.UserName, ARequest.AssistantId, E.Message);
  end;
end;

procedure TKXChatRunner.Submit(const AUser, AAssistantId, AProviderName: string;
  const AContext: TKXChatContext; const AMaxHistory: Integer);
var
  LRequest: TKXChatRequest;
begin
  LRequest := Default(TKXChatRequest);
  LRequest.UserName := AUser;
  LRequest.AssistantId := AAssistantId;
  LRequest.ProviderName := AProviderName;
  LRequest.Context := AContext;
  LRequest.MaxHistory := AMaxHistory;
  FSubmissions.PushItem(LRequest);
end;

class function TKXChatRunner.Instance: TKXChatRunner;
begin
  if FRunnerInstance = nil then
  begin
    FSingletonLock.Enter;
    try
      if FRunnerInstance = nil then
        FRunnerInstance := TKXChatRunner.Create(
          TKConfig.Instance.Config.GetInteger('HelpChat/PoolSize', 2));
    finally
      FSingletonLock.Leave;
    end;
  end;
  Result := FRunnerInstance;
end;

initialization
  FSingletonLock := TCriticalSection.Create;

finalization
  FreeAndNil(FRunnerInstance);
  FreeAndNil(FStoreInstance);
  FreeAndNil(FSingletonLock);

end.
