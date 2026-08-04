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
///  In-process publish/subscribe event bus for the KittoX notification
///  subsystem. Publishers push a <see cref="TKXEvent" /> onto a topic; each
///  subscriber owns a <see cref="TKXEventQueue" /> (typically one per open SSE
///  connection) that the bus fills. The bus is thread-safe and process-global
///  (single instance); it is deliberately in-process only — multi-instance
///  fan-out (Redis/NATS) is a future strategy behind the same API.
/// </summary>
unit Kitto.Notification.EventBus;

{$I Kitto.Defines.inc}

interface

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  System.Generics.Collections,
  Kitto.Notification.Types;

type
  /// <summary>
  ///  A bounded, thread-safe FIFO of events for a single subscriber. A dedicated
  ///  waiter (the SSE handler thread) blocks on <see cref="Dequeue" /> until an
  ///  event arrives or the timeout elapses; publishers call <see cref="Enqueue" />
  ///  from any thread. When the queue is full the oldest event is dropped
  ///  (bounded backpressure), so a slow/stuck consumer can never exhaust memory.
  /// </summary>
  TKXEventQueue = class
  strict private
    FItems: TQueue<TKXEvent>;
    FLock: TCriticalSection;
    FSignal: TEvent;
    FMaxSize: Integer;
  public
    /// <summary>Creates the queue with the given maximum retained events.</summary>
    constructor Create(const AMaxSize: Integer = 1000);
    destructor Destroy; override;
    /// <summary>Appends an event, dropping the oldest if the queue is full.</summary>
    procedure Enqueue(const AEvent: TKXEvent);
    /// <summary>Waits up to ATimeoutMs for an event. Returns True and the event
    /// when one is available, or False on timeout (used by the SSE loop to emit
    /// a keep-alive).</summary>
    function Dequeue(out AEvent: TKXEvent; const ATimeoutMs: Cardinal): Boolean;
    /// <summary>Discards all pending events.</summary>
    procedure Clear;
  end;

  /// <summary>
  ///  Process-global publish/subscribe bus. Maps each topic to the set of
  ///  subscriber queues and delivers a published event to every queue on its
  ///  topic. The bus owns the per-topic subscriber lists but never the queues
  ///  themselves (each queue is owned and freed by its subscriber).
  /// </summary>
  TKXEventBus = class
  strict private
    FLock: TCriticalSection;
    FSubscribers: TObjectDictionary<string, TList<TKXEventQueue>>;
  public
    constructor Create;
    destructor Destroy; override;

    /// <summary>Adds a queue as a subscriber of the given topic.</summary>
    procedure Subscribe(const ATopic: string; const AQueue: TKXEventQueue);
    /// <summary>Removes a queue from the given topic.</summary>
    procedure Unsubscribe(const ATopic: string; const AQueue: TKXEventQueue);
    /// <summary>Removes a queue from every topic it is subscribed to (call on
    /// connection close, before freeing the queue).</summary>
    procedure UnsubscribeAll(const AQueue: TKXEventQueue);

    /// <summary>Delivers the event to all queues subscribed to its Topic.</summary>
    procedure Publish(const AEvent: TKXEvent);
    /// <summary>Delivers the event to the given user's personal topic
    /// (<c>user:{AUser}</c>), overriding the event's Topic.</summary>
    procedure PublishToUser(const AUser: string; const AEvent: TKXEvent);
    /// <summary>Delivers the event to the system-wide topic.</summary>
    procedure PublishSystem(const AEvent: TKXEvent);

    /// <summary>The process-global event bus instance.</summary>
    class function Instance: TKXEventBus; static;
  end;

implementation

var
  FInstance: TKXEventBus;

{ TKXEventQueue }

constructor TKXEventQueue.Create(const AMaxSize: Integer);
begin
  inherited Create;
  FMaxSize := AMaxSize;
  FItems := TQueue<TKXEvent>.Create;
  FLock := TCriticalSection.Create;
  // Manual-reset: stays signaled while items are pending, reset only when drained.
  FSignal := TEvent.Create(nil, True, False, '');
end;

destructor TKXEventQueue.Destroy;
begin
  FreeAndNil(FSignal);
  FreeAndNil(FLock);
  FreeAndNil(FItems);
  inherited;
end;

procedure TKXEventQueue.Enqueue(const AEvent: TKXEvent);
begin
  FLock.Enter;
  try
    while FItems.Count >= FMaxSize do
      FItems.Dequeue; // drop oldest (bounded backpressure)
    FItems.Enqueue(AEvent);
    FSignal.SetEvent;
  finally
    FLock.Leave;
  end;
end;

function TKXEventQueue.Dequeue(out AEvent: TKXEvent; const ATimeoutMs: Cardinal): Boolean;
begin
  Result := False;
  if FSignal.WaitFor(ATimeoutMs) <> wrSignaled then
    Exit; // timeout: caller emits a keep-alive
  FLock.Enter;
  try
    if FItems.Count > 0 then
    begin
      AEvent := FItems.Dequeue;
      Result := True;
    end;
    if FItems.Count = 0 then
      FSignal.ResetEvent;
  finally
    FLock.Leave;
  end;
end;

procedure TKXEventQueue.Clear;
begin
  FLock.Enter;
  try
    FItems.Clear;
    FSignal.ResetEvent;
  finally
    FLock.Leave;
  end;
end;

{ TKXEventBus }

constructor TKXEventBus.Create;
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FSubscribers := TObjectDictionary<string, TList<TKXEventQueue>>.Create([doOwnsValues]);
end;

destructor TKXEventBus.Destroy;
begin
  FreeAndNil(FSubscribers);
  FreeAndNil(FLock);
  inherited;
end;

procedure TKXEventBus.Subscribe(const ATopic: string; const AQueue: TKXEventQueue);
var
  LList: TList<TKXEventQueue>;
begin
  FLock.Enter;
  try
    if not FSubscribers.TryGetValue(ATopic, LList) then
    begin
      LList := TList<TKXEventQueue>.Create;
      FSubscribers.Add(ATopic, LList);
    end;
    if not LList.Contains(AQueue) then
      LList.Add(AQueue);
  finally
    FLock.Leave;
  end;
end;

procedure TKXEventBus.Unsubscribe(const ATopic: string; const AQueue: TKXEventQueue);
var
  LList: TList<TKXEventQueue>;
begin
  FLock.Enter;
  try
    if FSubscribers.TryGetValue(ATopic, LList) then
    begin
      LList.Remove(AQueue);
      if LList.Count = 0 then
        FSubscribers.Remove(ATopic); // frees the list (doOwnsValues)
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TKXEventBus.UnsubscribeAll(const AQueue: TKXEventQueue);
var
  LTopic: string;
  LList: TList<TKXEventQueue>;
  LEmptyTopics: TArray<string>;
  I: Integer;
begin
  FLock.Enter;
  try
    LEmptyTopics := [];
    for LTopic in FSubscribers.Keys do
    begin
      LList := FSubscribers[LTopic];
      LList.Remove(AQueue);
      if LList.Count = 0 then
        LEmptyTopics := LEmptyTopics + [LTopic];
    end;
    for I := 0 to High(LEmptyTopics) do
      FSubscribers.Remove(LEmptyTopics[I]);
  finally
    FLock.Leave;
  end;
end;

procedure TKXEventBus.Publish(const AEvent: TKXEvent);
var
  LList: TList<TKXEventQueue>;
  LQueue: TKXEventQueue;
begin
  FLock.Enter;
  try
    if FSubscribers.TryGetValue(AEvent.Topic, LList) then
      for LQueue in LList do
        LQueue.Enqueue(AEvent);
  finally
    FLock.Leave;
  end;
end;

procedure TKXEventBus.PublishToUser(const AUser: string; const AEvent: TKXEvent);
var
  LEvent: TKXEvent;
begin
  LEvent := AEvent;
  LEvent.Topic := KX_TOPIC_USER + AUser;
  Publish(LEvent);
end;

procedure TKXEventBus.PublishSystem(const AEvent: TKXEvent);
var
  LEvent: TKXEvent;
begin
  LEvent := AEvent;
  LEvent.Topic := KX_TOPIC_SYSTEM;
  Publish(LEvent);
end;

class function TKXEventBus.Instance: TKXEventBus;
begin
  Result := FInstance;
end;

initialization
  FInstance := TKXEventBus.Create;

finalization
  FreeAndNil(FInstance);

end.
