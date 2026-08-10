/*!
 * kxchat.js — KittoX in-app help chat (assistant bubble, polling v1)
 * Copyright 2012-2026 Ethea S.r.l. — Apache License 2.0
 *
 * Renders a floating assistant button in the bottom-right corner. Clicking it
 * opens a chat drawer: the user asks questions, the message is sent to
 * `kx/chat/send`, and the assistant reply — produced asynchronously on a server
 * worker — is retrieved by polling `kx/chat/poll/{id}`. Active only on the
 * authenticated home (body.kx-authenticated) and when HelpChat is enabled
 * (KX_CFG.helpChat). Uses fetch (not htmx) so transient poll errors never
 * surface the global htmx error dialog. SSE streaming can later replace polling.
 */
(function () {
  'use strict';

  var POLL_MS = 1200;
  var ui = null;
  var isOpen = false;
  var loaded = false;

  function el(tag, cls, html) {
    var e = document.createElement(tag);
    if (cls) { e.className = cls; }
    if (html != null) { e.innerHTML = html; }
    return e;
  }

  // Localized label from KX_STRINGS (injected server-side from gettext _()),
  // with an English fallback.
  function t(key, fallback) {
    return (window.KX_STRINGS && window.KX_STRINGS[key]) || fallback;
  }

  // Themed Material SVG icon (CSS mask, currentColor) as an HTML string.
  function iconHtml(name, sizeCls) {
    var cfg = window.KX_CFG || { resPath: '', iconStyle: 'filled' };
    var url = (cfg.resPath || '') + '/icons/' + (cfg.iconStyle || 'filled') + '/' + name + '.svg';
    return '<span class="kx-icon ' + (sizeCls || 'kx-icon-sm') +
      '" style="-webkit-mask-image:url(\'' + url + '\');mask-image:url(\'' + url + '\')"></span>';
  }

  // Best-effort: the view the user is currently on (used as help context by a
  // DocuWiki/AI provider). Empty when it cannot be determined.
  function currentViewName() {
    var active = document.querySelector('.kx-tab-active[data-view-name], .kx-tab-active[data-viewname]');
    if (active) {
      return active.getAttribute('data-view-name') || active.getAttribute('data-viewname') || '';
    }
    return '';
  }

  function build() {
    var cfg = window.KX_CFG || { resPath: '', iconStyle: 'filled' };
    var wrap = el('div', 'kx-chat');
    wrap.id = 'kx-chat';

    // Floating assistant button (themed Material SVG via CSS mask).
    var fab = el('button', 'kx-chat-fab');
    fab.type = 'button';
    fab.title = t('helpAssistant', 'Help assistant');
    fab.setAttribute('aria-label', t('helpAssistant', 'Help assistant'));
    var iconUrl = (cfg.resPath || '') + '/icons/' + (cfg.iconStyle || 'filled') + '/support_agent.svg';
    var icon = el('span', 'kx-icon kx-icon-md');
    icon.style.webkitMaskImage = "url('" + iconUrl + "')";
    icon.style.maskImage = "url('" + iconUrl + "')";
    fab.appendChild(icon);

    // Drawer.
    var panel = el('div', 'kx-chat-panel');
    panel.innerHTML =
      '<div class="kx-chat-header">' +
        '<span class="kx-chat-title">' + t('help', 'Help') + '</span>' +
        '<span class="kx-chat-actions">' +
          '<button type="button" class="kx-chat-hbtn" data-action="clear" title="' + t('clear', 'Clear') + '">' + iconHtml('delete_sweep') + '</button>' +
          '<button type="button" class="kx-chat-hbtn" data-action="close" title="' + t('close', 'Close') + '">' + iconHtml('close') + '</button>' +
        '</span>' +
      '</div>' +
      '<div class="kx-chat-body"></div>' +
      '<div class="kx-chat-footer">' +
        '<textarea class="kx-chat-input" rows="1" placeholder="' + t('chatPlaceholder', 'Ask about the application...') + '"></textarea>' +
        '<button type="button" class="kx-chat-send" title="' + t('send', 'Send') + '">' + iconHtml('send') + '</button>' +
      '</div>';

    wrap.appendChild(fab);
    wrap.appendChild(panel);
    document.body.appendChild(wrap);

    var u = {
      wrap: wrap, fab: fab, panel: panel,
      body: panel.querySelector('.kx-chat-body'),
      input: panel.querySelector('.kx-chat-input'),
      send: panel.querySelector('.kx-chat-send')
    };

    fab.addEventListener('click', function () { toggle(); });

    panel.querySelector('.kx-chat-header').addEventListener('click', function (ev) {
      var btn = ev.target.closest('.kx-chat-hbtn');
      if (!btn) { return; }
      if (btn.getAttribute('data-action') === 'close') { close(); }
      else if (btn.getAttribute('data-action') === 'clear') { clearConversation(); }
    });

    u.send.addEventListener('click', function () { sendMessage(); });

    u.input.addEventListener('keydown', function (ev) {
      if (ev.key === 'Enter' && !ev.shiftKey) {
        ev.preventDefault();
        sendMessage();
      } else if (ev.key === 'Escape') {
        close();
      }
    });
    // Auto-grow the textarea up to a few rows.
    u.input.addEventListener('input', function () {
      u.input.style.height = 'auto';
      u.input.style.height = Math.min(u.input.scrollHeight, 120) + 'px';
    });

    return u;
  }

  function toggle() { if (isOpen) { close(); } else { open(); } }

  function open() {
    isOpen = true;
    ui.wrap.classList.add('kx-chat-open');
    if (!loaded) { loadHistory(); }
    setTimeout(function () { ui.input.focus(); }, 50);
  }

  function close() {
    isOpen = false;
    ui.wrap.classList.remove('kx-chat-open');
  }

  function scrollToEnd() { ui.body.scrollTop = ui.body.scrollHeight; }

  function loadHistory() {
    fetch('kx/chat/panel', { headers: { 'X-KittoX': 'true' }, credentials: 'same-origin' })
      .then(function (r) { return r.ok ? r.text() : null; })
      .then(function (t) { if (t != null) { ui.body.innerHTML = t; loaded = true; scrollToEnd(); } })
      .catch(function () { /* ignore */ });
  }

  function clearConversation() {
    fetch('kx/chat/clear', { method: 'POST', headers: { 'X-KittoX': 'true' }, credentials: 'same-origin' })
      .then(function (r) { if (!r.ok) { kxReportRequestError(r, clearConversation); return null; } return r.text(); })
      .then(function (t) { if (t != null) { ui.body.innerHTML = t; scrollToEnd(); } })
      .catch(function () { kxReportRequestError(undefined, clearConversation); });
  }

  function postSend(text, viewName, ctype) {
    var params = new URLSearchParams();
    params.set('message', text);
    params.set('viewName', viewName || '');
    params.set('controllerType', ctype || '');

    fetch('kx/chat/send', {
      method: 'POST',
      headers: { 'X-KittoX': 'true', 'Content-Type': 'application/x-www-form-urlencoded' },
      credentials: 'same-origin',
      body: params.toString()
    })
      .then(function (r) {
        if (!r.ok) { kxReportRequestError(r, function () { postSend(text, viewName, ctype); }); return null; }
        return r.text();
      })
      .then(function (t) {
        if (t == null) { return; }
        loaded = true;
        ui.body.insertAdjacentHTML('beforeend', t);
        scrollToEnd();
        var pending = ui.body.querySelector('.kx-chat-msg[data-pending="1"]');
        if (pending) { pollReply(pending.getAttribute('data-msgid')); }
      })
      .catch(function () { kxReportRequestError(undefined, function () { postSend(text, viewName, ctype); }); });
  }

  function sendMessage() {
    var text = (ui.input.value || '').trim();
    if (!text) { return; }
    ui.input.value = '';
    ui.input.style.height = 'auto';
    postSend(text, currentViewName(), '');
  }

  // Contextual trigger: a view's "?" help button opens the chat and asks a
  // contextual question, passing the controller type so the answer is anchored
  // to the right documentation page.
  function openForView(viewName, label, ctype, question) {
    if (!ui) { return; }
    open();
    postSend(question || label || 'Help', viewName, ctype);
  }

  function pollReply(msgId) {
    if (!msgId) { return; }
    fetch('kx/chat/poll/' + encodeURIComponent(msgId), {
      headers: { 'X-KittoX': 'true' }, credentials: 'same-origin'
    })
      .then(function (r) { return r.ok ? r.text() : null; })
      .then(function (html) {
        if (html == null || html === '') { setTimeout(function () { pollReply(msgId); }, POLL_MS); return; }
        var current = ui.body.querySelector('.kx-chat-msg[data-msgid="' + msgId + '"]');
        if (current) { current.outerHTML = html; }
        scrollToEnd();
        // Keep polling while the (replaced) bubble is still pending.
        var refreshed = ui.body.querySelector('.kx-chat-msg[data-msgid="' + msgId + '"]');
        if (refreshed && refreshed.getAttribute('data-pending') === '1') {
          setTimeout(function () { pollReply(msgId); }, POLL_MS);
        }
      })
      .catch(function () { setTimeout(function () { pollReply(msgId); }, POLL_MS); });
  }

  function start() {
    if (!document.body.classList.contains('kx-authenticated')) { return; }
    if (!window.KX_CFG || window.KX_CFG.helpChat !== true) { return; }
    ui = build();
    // Delegated handler for the per-view "?" help buttons (rendered by List/Form
    // when HelpChat is enabled). Works for toolbars added later via AJAX.
    document.addEventListener('click', function (ev) {
      var b = ev.target.closest('.kx-help-chat-btn');
      if (!b) { return; }
      ev.preventDefault();
      openForView(b.getAttribute('data-view') || '', b.getAttribute('data-label') || '',
        b.getAttribute('data-ctype') || '', b.getAttribute('data-question') || '');
    });
    // Allow server-rendered markup to trigger it directly too.
    window.kxChat = { openForView: openForView };
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', start);
  } else {
    start();
  }
})();
