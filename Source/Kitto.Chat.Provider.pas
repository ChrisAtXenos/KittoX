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
///  Provider abstraction for the KittoX in-app help chat. A provider turns the
///  conversation history (plus an optional context: the view the user is on)
///  into an assistant reply. v1 ships a stub provider that returns an honest
///  placeholder; real back-ends (a DocuWiki-grounded Claude provider, a static
///  FAQ matcher, a local LLM) implement the same <see cref="IKXChatProvider" />
///  interface and register themselves in <see cref="TKXChatProviderRegistry" />,
///  so the active provider is selected by name from <c>HelpChat/Provider</c> in
///  Config.yaml with no code change on the call site.
/// </summary>
unit Kitto.Chat.Provider;

{$I Kitto.Defines.inc}

interface

uses
  System.SysUtils,
  System.Generics.Collections;

type
  /// <summary>Author of a chat message.</summary>
  TKXChatRole = (crUser, crAssistant, crSystem);

  /// <summary>
  ///  A single chat message. A plain value record (strings + enums) so it can be
  ///  copied into the per-user store and passed to a worker thread without any
  ///  ownership concern. Assistant messages produced asynchronously start with
  ///  <c>Pending = True</c> and are later completed (or marked <c>IsError</c>).
  /// </summary>
  TKXChatMessage = record
    /// <summary>URL-safe id (used by the poll endpoint to fetch this message).</summary>
    Id: string;
    Role: TKXChatRole;
    Content: string;
    Created: TDateTime;
    /// <summary>True while an assistant reply is still being produced by the runner.</summary>
    Pending: Boolean;
    /// <summary>True when the assistant reply ended in an error (Content is the message).</summary>
    IsError: Boolean;
  end;

  /// <summary>
  ///  Optional context passed to the provider: who is asking and, if the chat was
  ///  opened from a specific screen, which view (its name and display label). A
  ///  DocuWiki/RAG provider uses <c>ViewName</c> to fetch the matching help page.
  /// </summary>
  TKXChatContext = record
    UserName: string;
    ViewName: string;
    ViewLabel: string;
    /// <summary>Controller type of the view the chat was opened from (e.g. List,
    /// Form). Used by the doc-search provider to anchor the answer to the right
    /// framework documentation page when the help is opened contextually.</summary>
    ControllerType: string;
  end;

  /// <summary>Callback invoked by a streaming provider for each produced token.</summary>
  TKXChatTokenProc = reference to procedure(const AToken: string);

  /// <summary>
  ///  Contract every chat back-end implements. <c>Generate</c> returns the full
  ///  assistant reply; a streaming provider (<c>SupportsStreaming = True</c>)
  ///  additionally calls <c>AOnToken</c> for each token as it is produced (the
  ///  returned string is their concatenation, convenient for persistence).
  /// </summary>
  IKXChatProvider = interface
    ['{4C6F8A21-2B3D-4E5F-9A10-7C1B2D3E4F50}']
    /// <summary>The registered provider name (matches HelpChat/Provider).</summary>
    function GetName: string;
    /// <summary>True if the provider emits tokens incrementally via AOnToken.</summary>
    function SupportsStreaming: Boolean;
    /// <summary>Produces the assistant reply for the given history and context.</summary>
    function Generate(const AHistory: TArray<TKXChatMessage>;
      const AContext: TKXChatContext; const AOnToken: TKXChatTokenProc): string;
  end;

  /// <summary>Convenience base class for providers: reference-counted, non-streaming
  /// by default. Descendants override <c>GetName</c> and <c>Generate</c>.</summary>
  TKXChatProviderBase = class abstract (TInterfacedObject, IKXChatProvider)
  public
    /// <summary>Virtual so providers instantiated polymorphically via the
    /// registry (LClass.Create) can override it to read their config once at
    /// creation time (providers are short-lived, one per chat request).</summary>
    constructor Create; virtual;
    function GetName: string; virtual; abstract;
    function SupportsStreaming: Boolean; virtual;
    function Generate(const AHistory: TArray<TKXChatMessage>;
      const AContext: TKXChatContext; const AOnToken: TKXChatTokenProc): string; virtual; abstract;
  end;

  TKXChatProviderClass = class of TKXChatProviderBase;

  /// <summary>
  ///  Process-global registry of chat providers, keyed by name. Providers
  ///  self-register in their unit's initialization section; the active one is
  ///  created on demand from the name configured in <c>HelpChat/Provider</c>.
  /// </summary>
  TKXChatProviderRegistry = class
  strict private
    class var FProviders: TDictionary<string, TKXChatProviderClass>;
    class var FLock: TObject;
  public
    class constructor Create;
    class destructor Destroy;
    /// <summary>Registers a provider class under a (case-insensitive) name.</summary>
    class procedure RegisterProvider(const AName: string; const AClass: TKXChatProviderClass);
    /// <summary>Removes a previously registered provider.</summary>
    class procedure UnregisterProvider(const AName: string);
    /// <summary>True if a provider is registered under the given name.</summary>
    class function IsRegistered(const AName: string): Boolean;
    /// <summary>Instantiates the named provider, or the stub provider if the name
    /// is empty/unknown (so the chat always has a working back-end).</summary>
    class function CreateProvider(const AName: string): IKXChatProvider;
    /// <summary>The names of all registered providers.</summary>
    class function ProviderNames: TArray<string>;
  end;

  /// <summary>
  ///  Default provider (<c>stub</c>): returns a fixed, honest placeholder reply.
  ///  It validates the whole UI/async pipeline end-to-end without any external
  ///  dependency or API key, and is the fallback whenever the configured
  ///  provider name is missing or unknown.
  /// </summary>
  TKXChatStubProvider = class(TKXChatProviderBase)
  public
    function GetName: string; override;
    function Generate(const AHistory: TArray<TKXChatMessage>;
      const AContext: TKXChatContext; const AOnToken: TKXChatTokenProc): string; override;
  end;

const
  /// <summary>Name of the always-available stub provider.</summary>
  KX_CHAT_PROVIDER_STUB = 'stub';

implementation

uses
  EF.Localization;

{ TKXChatProviderBase }

constructor TKXChatProviderBase.Create;
begin
  inherited Create;
end;

function TKXChatProviderBase.SupportsStreaming: Boolean;
begin
  Result := False;
end;

{ TKXChatProviderRegistry }

class constructor TKXChatProviderRegistry.Create;
begin
  FLock := TObject.Create;
  FProviders := TDictionary<string, TKXChatProviderClass>.Create;
end;

class destructor TKXChatProviderRegistry.Destroy;
begin
  FProviders.Free;
  FLock.Free;
end;

class procedure TKXChatProviderRegistry.RegisterProvider(const AName: string;
  const AClass: TKXChatProviderClass);
begin
  TMonitor.Enter(FLock);
  try
    FProviders.AddOrSetValue(AName.ToLower, AClass);
  finally
    TMonitor.Exit(FLock);
  end;
end;

class procedure TKXChatProviderRegistry.UnregisterProvider(const AName: string);
begin
  TMonitor.Enter(FLock);
  try
    FProviders.Remove(AName.ToLower);
  finally
    TMonitor.Exit(FLock);
  end;
end;

class function TKXChatProviderRegistry.IsRegistered(const AName: string): Boolean;
begin
  TMonitor.Enter(FLock);
  try
    Result := FProviders.ContainsKey(AName.ToLower);
  finally
    TMonitor.Exit(FLock);
  end;
end;

class function TKXChatProviderRegistry.CreateProvider(const AName: string): IKXChatProvider;
var
  LClass: TKXChatProviderClass;
begin
  TMonitor.Enter(FLock);
  try
    // Fall back to the stub whenever the configured provider is missing or
    // unknown, so a chat request never fails for a configuration typo.
    if not FProviders.TryGetValue(AName.ToLower, LClass) then
      if not FProviders.TryGetValue(KX_CHAT_PROVIDER_STUB, LClass) then
        LClass := TKXChatStubProvider;
  finally
    TMonitor.Exit(FLock);
  end;
  Result := LClass.Create;
end;

class function TKXChatProviderRegistry.ProviderNames: TArray<string>;
begin
  TMonitor.Enter(FLock);
  try
    Result := FProviders.Keys.ToArray;
  finally
    TMonitor.Exit(FLock);
  end;
end;

{ TKXChatStubProvider }

function TKXChatStubProvider.GetName: string;
begin
  Result := KX_CHAT_PROVIDER_STUB;
end;

function TKXChatStubProvider.Generate(const AHistory: TArray<TKXChatMessage>;
  const AContext: TKXChatContext; const AOnToken: TKXChatTokenProc): string;
begin
  // Honest placeholder: validates the pipeline (send -> async worker -> reply)
  // without pretending to answer. A real provider replaces it via Config.yaml.
  Result := _('Sorry, I have no elements to help you on this topic at the moment.');
end;

initialization
  TKXChatProviderRegistry.RegisterProvider(KX_CHAT_PROVIDER_STUB, TKXChatStubProvider);

finalization
  if TKXChatProviderRegistry.IsRegistered(KX_CHAT_PROVIDER_STUB) then
    TKXChatProviderRegistry.UnregisterProvider(KX_CHAT_PROVIDER_STUB);

end.
