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
///  Deterministic help-chat provider (<c>docsearch</c>) that answers by
///  searching the bundled KittoX documentation index and pointing to the
///  matching published page. No API key, no network: it loads
///  <c>Resources/help/kittox-help.json</c> (generated from the VitePress corpus
///  by <c>Tools/build_help_index.py</c>) once, scores the user's terms against
///  each page (title weighted higher than body) and returns the best page's
///  summary plus a "read more" link to <c>HelpChat/DocBaseUrl</c>
///  (default https://ethea.it/docs/kittox/). It is the base example engine for
///  the help chat; a Claude/RAG provider can later reuse the same index.
/// </summary>
unit Kitto.Chat.DocSearch;

{$I Kitto.Defines.inc}

interface

uses
  Kitto.Chat.Provider;

type
  /// <summary>Answers from the local KittoX documentation index (name <c>docsearch</c>).</summary>
  TKXDocSearchProvider = class(TKXChatProviderBase)
  public
    function GetName: string; override;
    function Generate(const AHistory: TArray<TKXChatMessage>;
      const AContext: TKXChatContext; const AOnToken: TKXChatTokenProc): string; override;
  end;

  /// <summary>A documentation page returned by the shared search: title, absolute
  /// URL (base URL already joined) and one-line summary. Used both by the
  /// docsearch provider and by the Claude provider for RAG grounding.</summary>
  TKXHelpPage = record
    Title: string;
    Url: string;
    Summary: string;
  end;

const
  /// <summary>Name of the deterministic documentation-search provider.</summary>
  KX_CHAT_PROVIDER_DOCSEARCH = 'docsearch';

/// <summary>
///  Searches the bundled documentation index for the pages best matching
///  <c>AQuery</c> (optionally biased by <c>AControllerType</c>, so a chat opened
///  from a List/Form view surfaces the matching framework page), most relevant
///  first, up to <c>AMaxPages</c> (&lt;= 0 defaults to 3). Returns <c>[]</c> when
///  the index is unavailable or nothing scores. Shared entry point for RAG
///  grounding: the Claude provider injects these pages into the system prompt.
/// </summary>
function KXSearchHelpPages(const AQuery, AControllerType: string;
  const AMaxPages: Integer): TArray<TKXHelpPage>;

implementation

uses
  System.SysUtils,
  System.StrUtils,
  System.Classes,
  System.IOUtils,
  System.JSON,
  System.SyncObjs,
  System.Character,
  System.Generics.Collections,
  EF.Localization,
  Kitto.Config;

type
  TKXDocEntry = record
    Title: string;
    Url: string;
    Summary: string;
    LTitle: string; // lowercased title (for scoring)
    LText: string;  // lowercased body (for scoring)
  end;

var
  FIndex: TArray<TKXDocEntry>;
  FLoaded: Boolean;
  FLoadLock: TCriticalSection;

const
  STOPWORDS: array[0..39] of string = (
    'the', 'and', 'for', 'with', 'that', 'this', 'from', 'how', 'can', 'you',
    'are', 'what', 'when', 'where', 'which', 'your', 'not', 'use', 'does',
    'come', 'che', 'per', 'con', 'non', 'una', 'uno', 'gli', 'dei', 'del',
    'nel', 'sul', 'come', 'cosa', 'quando', 'dove', 'posso', 'devo', 'mio',
    'the', 'and');

function IsStopWord(const AWord: string): Boolean;
var
  S: string;
begin
  for S in STOPWORDS do
    if S = AWord then
      Exit(True);
  Result := False;
end;

// Resolves the help index file: HelpChat/DocIndex if set, else
// Resources/help/kittox-help.json under the app home, then the system home.
function ResolveIndexPath: string;
var
  LConfigured: string;
begin
  LConfigured := TKConfig.Instance.Config.GetExpandedString('HelpChat/DocIndex');
  if (LConfigured <> '') and TFile.Exists(LConfigured) then
    Exit(LConfigured);
  Result := TPath.Combine(TKConfig.AppHomePath, 'Resources\help\kittox-help.json');
  if TFile.Exists(Result) then
    Exit;
  Result := TPath.Combine(TKConfig.SystemHomePath, 'Resources\help\kittox-help.json');
end;

procedure EnsureLoaded;
var
  LPath, LJson: string;
  LArray: TJSONArray;
  LValue: TJSONValue;
  LObj: TJSONObject;
  LList: TList<TKXDocEntry>;
  LEntry: TKXDocEntry;
  I: Integer;
begin
  if FLoaded then
    Exit;
  FLoadLock.Enter;
  try
    if FLoaded then
      Exit;
    FIndex := nil;
    try
      LPath := ResolveIndexPath;
      if TFile.Exists(LPath) then
      begin
        LJson := TFile.ReadAllText(LPath, TEncoding.UTF8);
        LArray := TJSONObject.ParseJSONValue(LJson) as TJSONArray;
        if LArray <> nil then
          try
            LList := TList<TKXDocEntry>.Create;
            try
              for I := 0 to LArray.Count - 1 do
              begin
                LValue := LArray.Items[I];
                if LValue is TJSONObject then
                begin
                  LObj := TJSONObject(LValue);
                  LEntry := Default(TKXDocEntry);
                  LEntry.Title := LObj.GetValue<string>('title', '');
                  LEntry.Url := LObj.GetValue<string>('url', '');
                  LEntry.Summary := LObj.GetValue<string>('summary', '');
                  LEntry.LTitle := LEntry.Title.ToLower;
                  LEntry.LText := LObj.GetValue<string>('text', '').ToLower;
                  if LEntry.Title <> '' then
                    LList.Add(LEntry);
                end;
              end;
              FIndex := LList.ToArray;
            finally
              LList.Free;
            end;
          finally
            LArray.Free;
          end;
      end;
    except
      // A missing/corrupt index must not break the chat: leave FIndex empty and
      // let Generate return a graceful fallback.
      FIndex := nil;
    end;
    FLoaded := True;
  finally
    FLoadLock.Leave;
  end;
end;

function Tokenize(const AText: string): TArray<string>;
var
  LList: TList<string>;
  LCur: string;
  C: Char;

  procedure Flush;
  begin
    if (LCur.Length >= 3) and not IsStopWord(LCur) then
      LList.Add(LCur);
    LCur := '';
  end;

begin
  LList := TList<string>.Create;
  try
    LCur := '';
    for C in AText.ToLower do
      if C.IsLetterOrDigit then
        LCur := LCur + C
      else
        Flush;
    Flush;
    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

function CountOccurrences(const AHaystack, ANeedle: string): Integer;
var
  P: Integer;
begin
  Result := 0;
  if ANeedle = '' then
    Exit;
  P := PosEx(ANeedle, AHaystack, 1);
  while P > 0 do
  begin
    Inc(Result);
    P := PosEx(ANeedle, AHaystack, P + ANeedle.Length);
  end;
end;

function ScoreEntry(const AEntry: TKXDocEntry; const ATokens: TArray<string>): Integer;
var
  LToken: string;
begin
  Result := 0;
  for LToken in ATokens do
    Inc(Result, CountOccurrences(AEntry.LTitle, LToken) * 6 +
                CountOccurrences(AEntry.LText, LToken));
end;

function DocBaseUrl: string;
begin
  Result := TKConfig.Instance.Config.GetExpandedString('HelpChat/DocBaseUrl',
    'https://ethea.it/docs/kittox/');
  if (Result <> '') and not Result.EndsWith('/') then
    Result := Result + '/';
end;

function KXSearchHelpPages(const AQuery, AControllerType: string;
  const AMaxPages: Integer): TArray<TKXHelpPage>;
var
  LTokens: TArray<string>;
  LScores: TArray<Integer>;
  LUsed: TArray<Boolean>;
  LBase: string;
  LMax, LBestIdx, LBestScore, I, J: Integer;
  LPages: TList<TKXHelpPage>;
  LPage: TKXHelpPage;
begin
  Result := [];
  EnsureLoaded;
  if Length(FIndex) = 0 then
    Exit;

  LTokens := Tokenize(AQuery);
  if AControllerType <> '' then
    LTokens := LTokens + Tokenize(AControllerType);
  if Length(LTokens) = 0 then
    Exit;

  SetLength(LScores, Length(FIndex));
  for I := 0 to High(FIndex) do
    LScores[I] := ScoreEntry(FIndex[I], LTokens);

  LBase := DocBaseUrl;
  LMax := AMaxPages;
  if LMax <= 0 then
    LMax := 3;
  SetLength(LUsed, Length(FIndex));

  LPages := TList<TKXHelpPage>.Create;
  try
    // Greedy top-N by score (score must be > 0 to be relevant at all).
    for J := 1 to LMax do
    begin
      LBestIdx := -1;
      LBestScore := 0;
      for I := 0 to High(FIndex) do
        if (not LUsed[I]) and (LScores[I] > LBestScore) then
        begin
          LBestScore := LScores[I];
          LBestIdx := I;
        end;
      if LBestIdx < 0 then
        Break;
      LUsed[LBestIdx] := True;
      LPage.Title := FIndex[LBestIdx].Title;
      LPage.Url := LBase + FIndex[LBestIdx].Url;
      LPage.Summary := FIndex[LBestIdx].Summary;
      LPages.Add(LPage);
    end;
    Result := LPages.ToArray;
  finally
    LPages.Free;
  end;
end;

{ TKXDocSearchProvider }

function TKXDocSearchProvider.GetName: string;
begin
  Result := KX_CHAT_PROVIDER_DOCSEARCH;
end;

function TKXDocSearchProvider.Generate(const AHistory: TArray<TKXChatMessage>;
  const AContext: TKXChatContext; const AOnToken: TKXChatTokenProc): string;
var
  LQuestion: string;
  LTokens: TArray<string>;
  LScore, LBest, LSecond: Integer;
  LBestIdx, LSecondIdx, I: Integer;
  LBase: string;
begin
  EnsureLoaded;

  // The last user message is the question.
  LQuestion := '';
  for I := High(AHistory) downto Low(AHistory) do
    if AHistory[I].Role = crUser then
    begin
      LQuestion := AHistory[I].Content;
      Break;
    end;

  LBase := DocBaseUrl;

  if (Length(FIndex) = 0) then
    Exit(Format(_('The help index is not available. See the [documentation](%s).'),
      [LBase]));

  LTokens := Tokenize(LQuestion);
  // When the chat was opened contextually from a view, anchor the search to the
  // view's controller type (List, Form, ...) so the matching framework page wins.
  if AContext.ControllerType <> '' then
    LTokens := LTokens + Tokenize(AContext.ControllerType);
  LBest := 0; LSecond := 0; LBestIdx := -1; LSecondIdx := -1;
  for I := 0 to High(FIndex) do
  begin
    LScore := ScoreEntry(FIndex[I], LTokens);
    if LScore > LBest then
    begin
      LSecond := LBest; LSecondIdx := LBestIdx;
      LBest := LScore; LBestIdx := I;
    end
    else if LScore > LSecond then
    begin
      LSecond := LScore; LSecondIdx := I;
    end;
  end;

  if LBestIdx < 0 then
    Exit(Format(_('I could not find a specific page for your question. Browse the [documentation](%s).'), [LBase]));

  // Best match: title + summary + a "read more" link (markdown; the chat
  // renderer turns links/bold into safe HTML).
  Result := Format('**%s**'#10#10'%s'#10#10'[%s](%s%s)',
    [FIndex[LBestIdx].Title, FIndex[LBestIdx].Summary,
     _('Read more'), LBase, FIndex[LBestIdx].Url]);

  // Offer a second related page when it is a meaningful match.
  if (LSecondIdx >= 0) and (LSecond >= 2) then
    Result := Result + Format(#10#10'%s [%s](%s%s)',
      [_('See also:'), FIndex[LSecondIdx].Title, LBase, FIndex[LSecondIdx].Url]);
end;

initialization
  FLoadLock := TCriticalSection.Create;
  TKXChatProviderRegistry.RegisterProvider(KX_CHAT_PROVIDER_DOCSEARCH, TKXDocSearchProvider);

finalization
  if TKXChatProviderRegistry.IsRegistered(KX_CHAT_PROVIDER_DOCSEARCH) then
    TKXChatProviderRegistry.UnregisterProvider(KX_CHAT_PROVIDER_DOCSEARCH);
  FLoadLock.Free;

end.
