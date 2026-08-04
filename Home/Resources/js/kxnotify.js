/*!
 * kxnotify.js — KittoX notification center (polling, v1)
 * Copyright 2012-2026 Ethea S.r.l. — Apache License 2.0
 *
 * Renders a bell in the top-right corner with an unread badge, polls
 * `kx/notifications` and shows the current user's background jobs (running with
 * a percentage, completed with a Download link, failed) in a dropdown. Active
 * only on the authenticated home (body.kx-authenticated); on the login page it
 * does nothing. Uses fetch (not htmx) so transient poll errors never surface the
 * global htmx error dialog. SSE push can later replace the polling with no UI
 * change.
 */
(function () {
  'use strict';

  var POLL_MS = 3000;
  var ui = null;
  var isOpen = false;
  var prevStatus = {}; // jobid -> last seen status, to detect completion

  function el(tag, cls, html) {
    var e = document.createElement(tag);
    if (cls) { e.className = cls; }
    if (html != null) { e.innerHTML = html; }
    return e;
  }

  function build() {
    var wrap = el('div', 'kx-notif');
    wrap.id = 'kx-notif';

    var btn = el('button', 'kx-notif-bell');
    btn.type = 'button';
    btn.title = 'Notification center';
    btn.setAttribute('aria-label', 'Notification center');

    // Themed Material SVG icon via CSS mask — same mechanism (and same icon set /
    // IconStyle) as the framework's server-rendered icons, so it matches the theme.
    var cfg = window.KX_CFG || { resPath: '', iconStyle: 'filled' };
    var iconUrl = (cfg.resPath || '') + '/icons/' + (cfg.iconStyle || 'filled') + '/notifications.svg';
    var icon = el('span', 'kx-icon kx-icon-md');
    icon.style.webkitMaskImage = "url('" + iconUrl + "')";
    icon.style.maskImage = "url('" + iconUrl + "')";
    btn.appendChild(icon);

    var badge = el('span', 'kx-notif-badge');
    badge.style.display = 'none';
    btn.appendChild(badge);

    var panel = el('div', 'kx-notif-panel');
    panel.style.display = 'none';
    panel.innerHTML =
      '<div class="kx-notif-header">Notification center</div>' +
      '<div class="kx-notif-body"><div class="kx-notif-empty">…</div></div>';

    wrap.appendChild(btn);
    wrap.appendChild(panel);
    document.body.appendChild(wrap);

    btn.addEventListener('click', function (ev) {
      ev.stopPropagation();
      isOpen = !isOpen;
      panel.style.display = isOpen ? 'block' : 'none';
      if (isOpen) { poll(); }
    });
    document.addEventListener('click', function () {
      if (isOpen) { isOpen = false; panel.style.display = 'none'; }
    });
    panel.addEventListener('click', function (ev) {
      ev.stopPropagation(); // keep the panel open on inner clicks
      var rm = ev.target.closest('.kx-notif-btn[data-action="remove"]');
      if (rm) {
        ev.preventDefault();
        removeJob(rm.getAttribute('data-jobid'));
        return;
      }
      var dl = ev.target.closest('a.kx-notif-download');
      if (dl) {
        // Let the browser download the file; a downloaded job leaves the list,
        // so refresh shortly after so it disappears from the panel/badge.
        setTimeout(poll, 1500);
      }
    });

    return { wrap: wrap, btn: btn, badge: badge, panel: panel,
             body: panel.querySelector('.kx-notif-body') };
  }

  function removeJob(id) {
    fetch('kx/job/' + id + '/remove', {
      method: 'POST',
      headers: { 'X-KittoX': 'true' },
      credentials: 'same-origin'
    })
      .then(function (r) { return r.ok ? r.text() : null; })
      .then(function (t) { if (t != null) { render(t); } else { poll(); } })
      .catch(function () { poll(); });
  }

  function toast(msg) {
    var t = el('div', 'kx-notif-toast', msg);
    document.body.appendChild(t);
    // force reflow then show
    void t.offsetWidth;
    t.classList.add('kx-notif-toast-show');
    setTimeout(function () {
      t.classList.remove('kx-notif-toast-show');
      setTimeout(function () { if (t.parentNode) { t.parentNode.removeChild(t); } }, 400);
    }, 5000);
  }

  function detectCompletions(container) {
    var items = container.querySelectorAll('.kx-notif-item[data-jobid]');
    var seenNow = {};
    for (var i = 0; i < items.length; i++) {
      var id = items[i].getAttribute('data-jobid');
      var st = items[i].getAttribute('data-status');
      seenNow[id] = st;
      if (prevStatus[id] && prevStatus[id] !== 'completed' && st === 'completed') {
        var title = (items[i].querySelector('.kx-notif-title') || {}).textContent || '';
        toast(title ? (title + ' — ready') : 'Operation ready');
      }
    }
    prevStatus = seenNow;
  }

  function render(html) {
    if (!ui) { return; }
    ui.body.innerHTML = html;
    var list = ui.body.querySelector('#kx-notif-list');
    detectCompletions(ui.body);
    var count = list ? parseInt(list.getAttribute('data-count') || '0', 10) : 0;
    if (count > 0) {
      ui.badge.textContent = count > 99 ? '99+' : count;
      ui.badge.style.display = '';
    } else {
      ui.badge.style.display = 'none';
    }
  }

  function poll() {
    fetch('kx/notifications', {
      headers: { 'X-KittoX': 'true' },
      credentials: 'same-origin'
    })
      .then(function (r) { return r.ok ? r.text() : null; })
      .then(function (t) { if (t != null) { render(t); } })
      .catch(function () { /* ignore transient errors */ });
  }

  function start() {
    if (!document.body.classList.contains('kx-authenticated')) { return; }
    ui = build();
    poll();
    setInterval(poll, POLL_MS);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', start);
  } else {
    start();
  }
})();
