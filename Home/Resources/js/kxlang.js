/*!
 * kxlang.js — KittoX interface-language switcher
 * Copyright 2012-2026 Ethea S.r.l. — Apache License 2.0
 *
 * Companion of the LanguageSwitcher controller (Kitto.Html.LanguageSwitcher).
 * The flag dropdown's options call kxLang.set('<code>'), which posts to the
 * anonymous endpoint kx/setlang/<code> and, on success, reloads the current
 * page so the whole UI (login or home) re-renders in the chosen language via
 * the per-session gettext instance.
 *
 * Language is a SERVER-side per-session setting (unlike the theme, which is a
 * client-side localStorage preference), hence the round-trip + reload.
 */
(function (g) {
  'use strict';

  function reportError(onRetry) {
    // Surface the same [Retry]/[Reset] dialog other user-initiated actions use
    // when it is available; otherwise fall back to a plain reload attempt.
    if (typeof g.kxReportRequestError === 'function') {
      g.kxReportRequestError(undefined, onRetry);
    }
  }

  g.kxLang = {
    // code: a language id offered by the switcher ('it','en','de','es','pt',...)
    set: function (code) {
      if (!code) { return; }
      fetch('kx/setlang/' + encodeURIComponent(code), {
        method: 'POST',
        headers: { 'X-KittoX': 'true' },
        credentials: 'same-origin'
      })
        .then(function (r) {
          if (!r.ok) { reportError(function () { g.kxLang.set(code); }); return; }
          // Re-render everything in the new language.
          g.location.reload();
        })
        .catch(function () { reportError(function () { g.kxLang.set(code); }); });
    }
  };
})(window);
