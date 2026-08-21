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
///  Anonymous endpoint backing the LanguageSwitcher controller. Sets the
///  interface language for the current session and returns an empty 200; the
///  client (kxlang.js) then reloads the page so the whole UI re-renders in the
///  new language via the per-session gettext instance.
///
///  It is [TKXAnonymous] because the switcher lives on the Login view too, so an
///  unauthenticated visitor must be able to change language before signing in.
///  The requested id is validated against TKXLanguageCatalog.IsAvailable, so a
///  crafted /kx/setlang/xx can only ever select a language the app actually
///  ships — it can never inject an arbitrary value into the session.
/// </summary>
unit Kitto.Web.Handler.SetLang;

{$I Kitto.Defines.inc}
{$RTTI EXPLICIT METHODS([vcPublic, vcPublished]) PROPERTIES([vcPublic, vcPublished])}

interface

uses
  Kitto.Web.Routing.Attributes;

type
  /// <summary>Sets the per-session interface language (validated) so the next
  /// page load renders in that language.</summary>
  [TKXPath('/kx/setlang')]
  TKXSetLangHandler = class
  public
    /// <summary>Sets the session language to <c>Lang</c> when it is one of the
    /// languages the application ships (else leaves it unchanged) and returns an
    /// empty 200 for the client to reload on.</summary>
    [TKXPath('/{Lang}')]
    [TKXPOST]
    [TKXAnonymous]
    procedure HandleSetLang([TKXPathParam('Lang')] const ALang: string);
  end;

implementation

uses
  Kitto.Web.Response,
  Kitto.Web.Session,
  Kitto.Html.LanguageSwitcher,
  Kitto.Web.Routing.Registry;

{ TKXSetLangHandler }

procedure TKXSetLangHandler.HandleSetLang(const ALang: string);
begin
  if TKXLanguageCatalog.IsAvailable(ALang) then
  begin
    TKWebSession.Current.Language := TKXLanguageCatalog.NormalizeCode(ALang);
    // kxlang.js reloads the current page right after this call, and on the Home
    // page that URL IS the application root. Reaching the root logs the user out
    // on purpose (a fresh page load must land on the login), so without this
    // flag switching language from inside Home would sign the user out. Same
    // guard used by the login success path and by the legacy login language
    // combo (Kitto.Web.Handler.Auth). It also stops ServeHomePage from
    // re-deriving the language from the query string / Config, which would undo
    // the choice just made. The flag is one-shot: ServeHomePage clears it.
    TKWebSession.Current.ReloadingHome := True;
  end;
  // Empty 200: the client only checks r.ok, then reloads the current page.
  TKWebResponse.Current.Items.Clear;
  TKWebResponse.Current.ContentType := 'text/plain; charset=utf-8';
  TKWebResponse.Current.Items.AddHTML('');
end;

initialization
  TKXResourceRegistry.Instance.RegisterResource(TKXSetLangHandler);

finalization
  TKXResourceRegistry.Instance.UnregisterResource(TKXSetLangHandler);

end.
