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
///  Claude-backed help-chat provider (name <c>claude</c>). It sends the
///  conversation to Anthropic's Messages API (<c>POST /v1/messages</c>) with
///  <c>stream: true</c> and forwards each token to the runner via the
///  <c>AOnToken</c> callback as it arrives, so the poll endpoint returns the
///  growing partial reply and the drawer fills in incrementally with no
///  server-push (SSE-to-the-browser) machinery — the existing 1.2s client poll
///  is enough. There is no official Anthropic SDK for Delphi, so the call is
///  made with <c>System.Net.HttpClient</c> and the Anthropic Server-Sent-Events
///  response is parsed by <see cref="TKXAnthropicStream" /> as bytes arrive.
///
///  Answers are grounded on the bundled documentation index (RAG): the pages
///  best matching the question are injected into the system prompt via
///  <see cref="KXSearchHelpPages" /> so the model answers from the real docs and
///  cites the published page instead of inventing details.
///
///  Configuration (Config.yaml, all under <c>HelpChat/Claude/</c>):
///  <code>
///  HelpChat:
///    Provider: claude
///    Claude:
///      ApiKey: %ENV(ANTHROPIC_API_KEY)%   # or the key directly; env var is the fallback
///      Model: claude-haiku-4-5            # default
///      MaxTokens: 1024
///      Version: 2023-06-01                # anthropic-version header
///      BaseUrl: https://api.anthropic.com
///      GroundingMaxPages: 3               # doc pages injected as context (0 = off)
///      SystemPrompt: ''                   # optional override of the base instruction
///      ConnectTimeoutMs: 15000
///      ResponseTimeoutMs: 120000
///  </code>
///  The API key is read from <c>HelpChat/Claude/ApiKey</c> (macro-expanded, so
///  <c>%ENV(...)%</c> works) and falls back to the <c>ANTHROPIC_API_KEY</c>
///  environment variable. When neither is set the provider raises a clear
///  configuration error (surfaced in the chat as an error bubble).
/// </summary>
unit Kitto.Chat.Provider.Claude;

{$I Kitto.Defines.inc}

interface

uses
  Kitto.Metadata.SubNodes,
  Kitto.Chat.Provider;

type
  /// <summary>Streams assistant replies from Anthropic's Claude Messages API.</summary>
  TKXClaudeProvider = class(TKXChatProviderBase)
  private
    FConfig: TKClaudeProviderConfig;
  public
    /// <summary>Reads the HelpChat/Claude/* config once (the provider is created
    /// per chat request), so Generate accesses typed fields instead of the tree.</summary>
    constructor Create; override;
    destructor Destroy; override;
    function GetName: string; override;
    function SupportsStreaming: Boolean; override;
    function Generate(const AHistory: TArray<TKXChatMessage>;
      const AContext: TKXChatContext; const AOnToken: TKXChatTokenProc): string; override;
  end;

const
  /// <summary>Name of the Claude help-chat provider.</summary>
  KX_CHAT_PROVIDER_CLAUDE = 'claude';

implementation

uses
  System.SysUtils,
  System.Classes,
  System.StrUtils,
  System.JSON,
  System.Net.HttpClient,
  System.Net.URLClient,
  EF.Localization,
  Kitto.Config,
  Kitto.Chat.DocSearch;

type
  /// <summary>
  ///  Write-only TStream that receives the Anthropic SSE response body as it is
  ///  streamed by THTTPClient and parses it incrementally. It accumulates raw
  ///  bytes, splits on newlines, and for each complete <c>data:</c> line decodes
  ///  the JSON event; on a <c>content_block_delta</c> / <c>text_delta</c> it
  ///  appends the token to the running text and invokes the token callback. The
  ///  full decoded body is also kept so a non-SSE error response (HTTP >= 400
  ///  returns a plain JSON error, not a stream) can be reported.
  /// </summary>
  TKXAnthropicStream = class(TStream)
  strict private
    FOnToken: TKXChatTokenProc;
    FPending: TBytes;       // bytes not yet forming a complete line
    FText: TStringBuilder;  // accumulated assistant text (the returned reply)
    FRaw: TStringBuilder;   // full decoded body (for error extraction)
    FError: string;         // set on a mid-stream {"type":"error"} event
    FWritten: Int64;
    procedure ProcessLine(const ALine: string);
    procedure Drain(const AFlushRemainder: Boolean);
    function GetText: string;
    function GetRaw: string;
  public
    constructor Create(const AOnToken: TKXChatTokenProc);
    destructor Destroy; override;
    function Read(var Buffer; Count: Longint): Longint; override;
    function Write(const Buffer; Count: Longint): Longint; override;
    function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; override;
    /// <summary>Flushes any trailing partial line (the body may not end in a newline).</summary>
    procedure Finish;
    property Text: string read GetText;
    property Raw: string read GetRaw;
    property Error: string read FError;
  end;

{ TKXAnthropicStream }

constructor TKXAnthropicStream.Create(const AOnToken: TKXChatTokenProc);
begin
  inherited Create;
  FOnToken := AOnToken;
  FText := TStringBuilder.Create;
  FRaw := TStringBuilder.Create;
end;

destructor TKXAnthropicStream.Destroy;
begin
  FText.Free;
  FRaw.Free;
  inherited;
end;

function TKXAnthropicStream.GetText: string;
begin
  Result := FText.ToString;
end;

function TKXAnthropicStream.GetRaw: string;
begin
  Result := FRaw.ToString;
end;

function TKXAnthropicStream.Read(var Buffer; Count: Longint): Longint;
begin
  Result := 0; // write-only sink
end;

function TKXAnthropicStream.Seek(const Offset: Int64; Origin: TSeekOrigin): Int64;
begin
  // THTTPClient treats the response stream as an append sink; report the end.
  Result := FWritten;
end;

function TKXAnthropicStream.Write(const Buffer; Count: Longint): Longint;
var
  LOld: Integer;
begin
  if Count > 0 then
  begin
    LOld := Length(FPending);
    SetLength(FPending, LOld + Count);
    Move(Buffer, FPending[LOld], Count);
    Inc(FWritten, Count);
    Drain(False);
  end;
  Result := Count;
end;

procedure TKXAnthropicStream.Finish;
begin
  Drain(True);
end;

procedure TKXAnthropicStream.Drain(const AFlushRemainder: Boolean);
var
  I, LStart, LLen: Integer;
  LLineBytes: TBytes;
  LRemainder: TBytes;

  procedure Emit(const ABytes: TBytes);
  var
    LDecoded: string;
    LTrimmed: TBytes;
    LN: Integer;
  begin
    LN := Length(ABytes);
    // A complete line ends before the #10; strip a trailing #13 (CRLF).
    if (LN > 0) and (ABytes[LN - 1] = 13) then
    begin
      LTrimmed := System.Copy(ABytes, 0, LN - 1);
      LDecoded := TEncoding.UTF8.GetString(LTrimmed);
    end
    else
      LDecoded := TEncoding.UTF8.GetString(ABytes);
    FRaw.Append(LDecoded).Append(#10);
    ProcessLine(LDecoded);
  end;

begin
  LStart := 0;
  I := 0;
  while I < Length(FPending) do
  begin
    if FPending[I] = 10 then // #10 line feed
    begin
      LLineBytes := System.Copy(FPending, LStart, I - LStart);
      Emit(LLineBytes);
      LStart := I + 1;
    end;
    Inc(I);
  end;

  LLen := Length(FPending) - LStart;
  if LLen > 0 then
    LRemainder := System.Copy(FPending, LStart, LLen)
  else
    LRemainder := nil;

  if AFlushRemainder and (Length(LRemainder) > 0) then
  begin
    Emit(LRemainder);
    LRemainder := nil;
  end;

  FPending := LRemainder;
end;

procedure TKXAnthropicStream.ProcessLine(const ALine: string);
var
  LData: string;
  LRoot, LDelta, LErr: TJSONObject;
  LType, LToken: string;
begin
  // Only SSE payload lines matter; ignore "event:" lines and blank separators.
  if not ALine.StartsWith('data:') then
    Exit;
  LData := Trim(System.Copy(ALine, 6, MaxInt)); // after 'data:'
  if (LData = '') or (LData = '[DONE]') then
    Exit;

  try
    LRoot := TJSONObject.ParseJSONValue(LData) as TJSONObject;
  except
    LRoot := nil; // ignore a malformed fragment rather than fail the whole reply
  end;
  if LRoot = nil then
    Exit;
  try
    LType := LRoot.GetValue<string>('type', '');
    if LType = 'content_block_delta' then
    begin
      LDelta := LRoot.GetValue('delta') as TJSONObject;
      if (LDelta <> nil) and (LDelta.GetValue<string>('type', '') = 'text_delta') then
      begin
        LToken := LDelta.GetValue<string>('text', '');
        if LToken <> '' then
        begin
          FText.Append(LToken);
          if Assigned(FOnToken) then
            FOnToken(LToken);
        end;
      end;
    end
    else if LType = 'error' then
    begin
      LErr := LRoot.GetValue('error') as TJSONObject;
      if LErr <> nil then
        FError := LErr.GetValue<string>('message', _('The AI provider returned an error.'))
      else
        FError := _('The AI provider returned an error.');
    end;
  finally
    LRoot.Free;
  end;
end;

{ Helpers }

// The last user message is the current question (grounding + safety).
function LastUserMessage(const AHistory: TArray<TKXChatMessage>): string;
var
  I: Integer;
begin
  Result := '';
  for I := High(AHistory) downto Low(AHistory) do
    if AHistory[I].Role = crUser then
      Exit(AHistory[I].Content);
end;

// Builds the system prompt: base instruction (+ optional override), the current
// view context, and the RAG grounding block (best-matching doc pages).
function BuildSystemPrompt(const AHistory: TArray<TKXChatMessage>;
  const AContext: TKXChatContext; const ASystemPromptOverride: string;
  const AGroundingMaxPages: Integer): string;
var
  LBase, LQuestion, LScreen: string;
  LSb: TStringBuilder;
  LPages: TArray<TKXHelpPage>;
  I: Integer;
begin
  // Use the configured override if present, else the localized default. The
  // literal is kept here (not a constant) so dxgettext can extract it.
  LBase := ASystemPromptOverride;
  if LBase = '' then
    LBase := _('You are the in-app help assistant for a web application built with the KittoX framework. ' +
      'Answer the user concisely and practically, focusing on how to use the application. ' +
      'Prefer the documentation excerpts provided below when they are relevant, and cite the linked page. ' +
      'If you are not sure, say so and point to the documentation rather than inventing details. ' +
      'Reply in the same language as the user. You may use short Markdown (links, bold, inline code).');

  LSb := TStringBuilder.Create;
  try
    LSb.Append(LBase);

    // Context of the screen the chat was opened from, when available.
    if (AContext.ViewName <> '') or (AContext.ControllerType <> '') then
    begin
      if AContext.ViewLabel <> '' then
        LScreen := AContext.ViewLabel
      else
        LScreen := AContext.ViewName;
      LSb.Append(#10#10);
      LSb.Append(Format(_('The user is currently on the "%s" screen (controller type: %s).'),
        [LScreen, AContext.ControllerType]));
    end;

    // RAG grounding: inject the best-matching documentation pages.
    if AGroundingMaxPages <> 0 then
    begin
      LQuestion := LastUserMessage(AHistory);
      LPages := KXSearchHelpPages(LQuestion, AContext.ControllerType, AGroundingMaxPages);
      if Length(LPages) > 0 then
      begin
        LSb.Append(#10#10);
        LSb.Append(_('Relevant documentation excerpts:'));
        for I := Low(LPages) to High(LPages) do
        begin
          LSb.Append(#10#10);
          LSb.Append(Format('## %s'#10'%s'#10'%s: %s',
            [LPages[I].Title, LPages[I].Summary, _('Source'), LPages[I].Url]));
        end;
      end;
    end;

    Result := LSb.ToString;
  finally
    LSb.Free;
  end;
end;

// Extracts a human-readable message from a non-2xx Anthropic response body.
function ExtractApiError(const ARaw: string; const AStatus: Integer;
  const AStatusText: string): string;
var
  LRoot, LErr: TJSONObject;
begin
  Result := '';
  if Trim(ARaw) <> '' then
  begin
    try
      LRoot := TJSONObject.ParseJSONValue(Trim(ARaw)) as TJSONObject;
    except
      LRoot := nil;
    end;
    if LRoot <> nil then
      try
        LErr := LRoot.GetValue('error') as TJSONObject;
        if LErr <> nil then
          Result := LErr.GetValue<string>('message', '');
      finally
        LRoot.Free;
      end;
  end;
  if Result = '' then
    Result := Format(_('Claude API error (HTTP %d %s).'), [AStatus, AStatusText]);
end;

{ TKXClaudeProvider }

constructor TKXClaudeProvider.Create;
begin
  inherited Create;
  FConfig := TKClaudeProviderConfig.Create(TKConfig.Instance.Config);
end;

destructor TKXClaudeProvider.Destroy;
begin
  FConfig.Free;
  inherited;
end;

function TKXClaudeProvider.GetName: string;
begin
  Result := KX_CHAT_PROVIDER_CLAUDE;
end;

function TKXClaudeProvider.SupportsStreaming: Boolean;
begin
  Result := True;
end;

function TKXClaudeProvider.Generate(const AHistory: TArray<TKXChatMessage>;
  const AContext: TKXChatContext; const AOnToken: TKXChatTokenProc): string;
var
  LSystem, LBody: string;
  LClient: THTTPClient;
  LSource: TStringStream;
  LStream: TKXAnthropicStream;
  LHeaders: TNetHeaders;
  LResponse: IHTTPResponse;
  LRoot, LMsg: TJSONObject;
  LMessages: TJSONArray;
  I: Integer;
begin
  // FConfig was read once at construction (see Create); no per-request tree lookups.
  if FConfig.ApiKey = '' then
    raise Exception.Create(_('The Claude help provider is not configured: set ' +
      'HelpChat/Claude/ApiKey in Config.yaml (or the ANTHROPIC_API_KEY environment variable).'));

  LSystem := BuildSystemPrompt(AHistory, AContext, FConfig.SystemPrompt, FConfig.GroundingMaxPages);

  // Build the request body with System.JSON so all content is correctly escaped.
  LRoot := TJSONObject.Create;
  try
    LRoot.AddPair('model', FConfig.Model);
    LRoot.AddPair('max_tokens', TJSONNumber.Create(FConfig.MaxTokens));
    LRoot.AddPair('stream', TJSONBool.Create(True));
    if LSystem <> '' then
      LRoot.AddPair('system', LSystem);

    LMessages := TJSONArray.Create;
    for I := Low(AHistory) to High(AHistory) do
    begin
      // Fold system messages into the top-level system field; skip empties.
      if (AHistory[I].Role = crSystem) or (Trim(AHistory[I].Content) = '') then
        Continue;
      LMsg := TJSONObject.Create;
      if AHistory[I].Role = crUser then
        LMsg.AddPair('role', 'user')
      else
        LMsg.AddPair('role', 'assistant');
      LMsg.AddPair('content', AHistory[I].Content);
      LMessages.AddElement(LMsg);
    end;
    // The API requires a non-empty messages array starting with a user turn; our
    // history always ends with the current user question, but guard anyway.
    if LMessages.Count = 0 then
    begin
      LMsg := TJSONObject.Create;
      LMsg.AddPair('role', 'user');
      LMsg.AddPair('content', LastUserMessage(AHistory));
      LMessages.AddElement(LMsg);
    end;
    LRoot.AddPair('messages', LMessages);

    LBody := LRoot.ToJSON;
  finally
    LRoot.Free; // frees the whole tree (messages + message objects)
  end;

  LClient := THTTPClient.Create;
  LSource := TStringStream.Create(LBody, TEncoding.UTF8);
  LStream := TKXAnthropicStream.Create(AOnToken);
  try
    LClient.ConnectionTimeout := FConfig.ConnectTimeoutMs;
    LClient.ResponseTimeout := FConfig.ResponseTimeoutMs;

    LHeaders := [
      TNetHeader.Create('x-api-key', FConfig.ApiKey),
      TNetHeader.Create('anthropic-version', FConfig.Version),
      TNetHeader.Create('content-type', 'application/json'),
      TNetHeader.Create('accept', 'text/event-stream')
    ];

    // The response body is streamed into LStream, which parses the SSE tokens
    // and forwards them via AOnToken as they arrive.
    LResponse := LClient.Post(FConfig.BaseUrl + '/v1/messages', LSource, LStream, LHeaders);
    LStream.Finish;

    if LResponse.StatusCode >= 400 then
      raise Exception.Create(ExtractApiError(LStream.Raw, LResponse.StatusCode, LResponse.StatusText));
    if LStream.Error <> '' then
      raise Exception.Create(LStream.Error);

    Result := LStream.Text;
    if Trim(Result) = '' then
      Result := _('The assistant did not return any content.');
  finally
    LStream.Free;
    LSource.Free;
    LClient.Free;
  end;
end;

initialization
  TKXChatProviderRegistry.RegisterProvider(KX_CHAT_PROVIDER_CLAUDE, TKXClaudeProvider);

finalization
  if TKXChatProviderRegistry.IsRegistered(KX_CHAT_PROVIDER_CLAUDE) then
    TKXChatProviderRegistry.UnregisterProvider(KX_CHAT_PROVIDER_CLAUDE);

end.
