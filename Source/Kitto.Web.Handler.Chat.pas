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
///  Attribute-routed endpoints for the in-app help chat: the drawer history
///  partial, message send (enqueues the provider call on the chat runner and
///  returns the user bubble plus a pending assistant bubble), the poll endpoint
///  the client uses to fetch the assistant reply once the worker has produced it,
///  and a conversation reset. Requires an authenticated user; all responses are
///  HTML fragments requested by htmx/fetch (with the X-KittoX header), so the
///  navigation guard leaves them alone and no [TKXNavigable] is needed.
/// </summary>
unit Kitto.Web.Handler.Chat;

{$I Kitto.Defines.inc}
{$RTTI EXPLICIT METHODS([vcPublic, vcPublished]) PROPERTIES([vcPublic, vcPublished])}

interface

uses
  Kitto.Web.Routing.Attributes;

type
  /// <summary>Serves the help-chat drawer history, message send, reply polling
  /// and conversation reset.</summary>
  [TKXPath('/kx/chat')]
  TKXChatHandler = class
  public
    /// <summary>Returns the HTML of the current user's conversation (all bubbles),
    /// or a greeting when empty. Requested when the drawer opens.</summary>
    [TKXPath('/panel')]
    [TKXGET]
    procedure HandlePanel;

    /// <summary>Accepts a user message (form fields <c>message</c> and optional
    /// <c>viewName</c>), appends it plus a pending assistant bubble, submits the
    /// provider call to the chat runner, and returns both bubbles for immediate
    /// display. The assistant bubble carries its id for polling.</summary>
    [TKXPath('/send')]
    [TKXPOST]
    procedure HandleSend;

    /// <summary>Returns the assistant bubble for the given message id. While the
    /// worker is still producing the reply the bubble is marked pending (typing
    /// indicator); once ready it carries the final text (or the error).</summary>
    [TKXPath('/poll/{MsgId}')]
    [TKXGET]
    procedure HandlePoll([TKXPathParam('MsgId')] const AMsgId: string);

    /// <summary>Clears the current user's conversation and returns the greeting.</summary>
    [TKXPath('/clear')]
    [TKXPOST]
    procedure HandleClear;
  end;

implementation

uses
  System.SysUtils,
  System.StrUtils,
  System.RegularExpressions,
  System.NetEncoding,
  EF.Tree,
  EF.Localization,
  Kitto.Auth,
  Kitto.Config,
  Kitto.Web.Request,
  Kitto.Web.Response,
  Kitto.Chat.Provider,
  Kitto.Chat.Runner,
  Kitto.Web.Routing.Registry;

function RoleToClass(const ARole: TKXChatRole): string;
begin
  case ARole of
    crUser:      Result := 'user';
    crAssistant: Result := 'assistant';
  else
    Result := 'system';
  end;
end;

// Plain-text -> safe HTML: encode, then turn newlines into <br>.
function TextToHtml(const AText: string): string;
begin
  Result := TNetEncoding.HTML.Encode(AText);
  Result := StringReplace(Result, #13#10, '<br>', [rfReplaceAll]);
  Result := StringReplace(Result, #10, '<br>', [rfReplaceAll]);
  Result := StringReplace(Result, #13, '<br>', [rfReplaceAll]);
end;

// Minimal, XSS-safe markdown for assistant replies: the text is HTML-encoded
// first, then a restricted set of markdown is turned into tags — links
// [text](http(s)://url), **bold**, `code` and newlines. Because everything is
// encoded before the tags are injected, no raw HTML from the provider (or an AI)
// can reach the DOM; only http/https links are produced.
function MarkdownToSafeHtml(const AText: string): string;
begin
  Result := TNetEncoding.HTML.Encode(AText);
  Result := TRegEx.Replace(Result, '\[([^\]]+)\]\((https?://[^)\s]+)\)',
    '<a href="$2" target="_blank" rel="noopener">$1</a>');
  Result := TRegEx.Replace(Result, '\*\*(.+?)\*\*', '<b>$1</b>');
  Result := TRegEx.Replace(Result, '`([^`]+)`', '<code>$1</code>');
  Result := StringReplace(Result, #13#10, '<br>', [rfReplaceAll]);
  Result := StringReplace(Result, #10, '<br>', [rfReplaceAll]);
  Result := StringReplace(Result, #13, '<br>', [rfReplaceAll]);
end;

// Renders one message as a chat bubble. A pending assistant message shows a
// typing indicator instead of text; an error message gets the error class.
function RenderBubble(const AMessage: TKXChatMessage): string;
var
  LExtra, LBody: string;
begin
  LExtra := '';
  if AMessage.Pending then
  begin
    LExtra := ' data-pending="1"';
    LBody := '<span class="kx-chat-typing"><span></span><span></span><span></span></span>';
  end
  else if AMessage.IsError then
  begin
    LExtra := ' data-error="1"';
    LBody := TextToHtml(AMessage.Content);
  end
  else if AMessage.Role = crAssistant then
    // Completed assistant reply: render the restricted markdown (links, bold, code).
    LBody := MarkdownToSafeHtml(AMessage.Content)
  else
    LBody := TextToHtml(AMessage.Content);

  Result :=
    '<div class="kx-chat-msg kx-chat-' + RoleToClass(AMessage.Role) +
      IfThen(AMessage.IsError, ' kx-chat-msg-error', '') + '"' +
      ' data-msgid="' + AMessage.Id + '"' + LExtra + '>' +
      '<div class="kx-chat-bubble">' + LBody + '</div>' +
    '</div>';
end;

function GreetingHtml: string;
var
  LGreeting: string;
begin
  LGreeting := TKConfig.Instance.Config.GetExpandedString('HelpChat/Greeting',
    _('Hi! Ask me anything about how to use the application.'));
  Result :=
    '<div class="kx-chat-msg kx-chat-assistant kx-chat-greeting">' +
      '<div class="kx-chat-bubble">' + TextToHtml(LGreeting) + '</div>' +
    '</div>';
end;

function RenderHistory(const AUser: string): string;
var
  LMessages: TArray<TKXChatMessage>;
  LMessage: TKXChatMessage;
begin
  LMessages := TKXChatStore.Instance.GetMessages(AUser);
  if Length(LMessages) = 0 then
    Exit(GreetingHtml);
  Result := '';
  for LMessage in LMessages do
    Result := Result + RenderBubble(LMessage);
end;

procedure WritePartial(const AHtml: string);
begin
  TKWebResponse.Current.Items.Clear;
  TKWebResponse.Current.Items.AddHTML(AHtml);
  TKWebResponse.Current.ContentType := 'text/html; charset=utf-8';
end;

{ TKXChatHandler }

procedure TKXChatHandler.HandlePanel;
begin
  WritePartial(RenderHistory(TKAuthenticator.Current.UserName));
end;

procedure TKXChatHandler.HandleSend;
var
  LUser, LText, LViewName, LControllerType: string;
  LConfig: TEFTree;
  LMaxLen: Integer;
  LUserMessage, LAssistantMessage: TKXChatMessage;
  LAssistantId: string;
  LContext: TKXChatContext;
begin
  LUser := TKAuthenticator.Current.UserName;
  LText := Trim(TKWebRequest.Current.GetContentFields.Values['message']);
  LViewName := Trim(TKWebRequest.Current.GetContentFields.Values['viewName']);
  LControllerType := Trim(TKWebRequest.Current.GetContentFields.Values['controllerType']);

  LConfig := TKConfig.Instance.Config;
  LMaxLen := LConfig.GetInteger('HelpChat/MessageMaxLength', 4000);
  if (LText = '') then
  begin
    WritePartial('');
    Exit;
  end;
  if (LMaxLen > 0) and (Length(LText) > LMaxLen) then
    LText := Copy(LText, 1, LMaxLen);

  // Record the user message and a pending assistant placeholder, then hand the
  // provider call to the runner (off the request thread).
  LUserMessage := TKXChatStore.Instance.AddUserMessage(LUser, LText);
  LAssistantId := TKXChatStore.Instance.AddPendingAssistant(LUser);

  LContext := Default(TKXChatContext);
  LContext.UserName := LUser;
  LContext.ViewName := LViewName;
  LContext.ControllerType := LControllerType;

  TKXChatRunner.Instance.Submit(LUser, LAssistantId,
    LConfig.GetString('HelpChat/Provider', KX_CHAT_PROVIDER_STUB),
    LContext, LConfig.GetInteger('HelpChat/HistoryMaxMessages', 50));

  // Return both bubbles: the user message and the pending assistant placeholder
  // (the client starts polling the latter by its id).
  TKXChatStore.Instance.TryGetMessage(LUser, LAssistantId, LAssistantMessage);
  WritePartial(RenderBubble(LUserMessage) + RenderBubble(LAssistantMessage));
end;

procedure TKXChatHandler.HandlePoll(const AMsgId: string);
var
  LMessage: TKXChatMessage;
begin
  if TKXChatStore.Instance.TryGetMessage(TKAuthenticator.Current.UserName, AMsgId, LMessage) then
    WritePartial(RenderBubble(LMessage))
  else
    WritePartial('');
end;

procedure TKXChatHandler.HandleClear;
begin
  TKXChatStore.Instance.Clear(TKAuthenticator.Current.UserName);
  WritePartial(GreetingHtml);
end;

initialization
  TKXResourceRegistry.Instance.RegisterResource(TKXChatHandler);

finalization
  TKXResourceRegistry.Instance.UnregisterResource(TKXChatHandler);

end.
