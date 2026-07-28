/* =========================================================================
   AskEva · Sync & Real-Time UX layer  (sync-layer.js)
   Drives every sync indicator: status chip, offline banner, queue + retry,
   pull-to-refresh, background sync, message states, conflict + collision.
   Real where it can be (connectivity, gestures, chat ticks); simulated where
   it would need a server (conflict, collision, multi-device).
   ========================================================================= */
(function () {
  "use strict";

  /* ---------- tiny helpers ---------- */
  function elFrom(html) { var t = document.createElement("template"); t.innerHTML = html.trim(); return t.content.firstElementChild; }
  function $(s, r) { return (r || document).querySelector(s); }
  function $$(s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); }

  var IC = {
    check:   '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><path d="M20 6 9 17l-5-5"/></svg>',
    spin:    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" class="sy-spin"><path d="M21 12a9 9 0 0 1-15 6.7L3 16M3 12a9 9 0 0 1 15-6.7L21 8"/></svg>',
    sync:    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 12a9 9 0 0 1-15 6.7L3 16M3 12a9 9 0 0 1 15-6.7L21 8"/><path d="M3 4v4h4M21 20v-4h-4"/></svg>',
    offline: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.1" stroke-linecap="round" stroke-linejoin="round"><path d="M1 1l22 22M16.7 11.7a6 6 0 0 0-7.4-1M5 8a10 10 0 0 1 4-2.3M2 5a14 14 0 0 1 3-2.1M19.6 8.1A14 14 0 0 0 16 5.6M8.5 16.5a4 4 0 0 1 7 0M12 20h.01"/></svg>',
    wifi:    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.1" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12.5a10 10 0 0 1 14 0M2 8.8a15 15 0 0 1 20 0M8.5 16.2a5 5 0 0 1 7 0M12 20h.01"/></svg>',
    clock:   '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.1" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="M12 8v4l2.5 2"/></svg>',
    bang:    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="M12 7v6M12 16.5v.4"/></svg>',
    msg:     '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 11.5a8.4 8.4 0 0 1-11.9 7.6L3 21l1.9-6.1A8.4 8.4 0 1 1 21 11.5Z"/></svg>',
    lead:    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="9" cy="8" r="3.2"/><path d="M3.5 19c0-2.7 2.5-4.2 5.5-4.2M15 13l2 2 4-4"/></svg>',
    cal:     '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="5" width="18" height="16" rx="2.5"/><path d="M3 10h18M8 3v4M16 3v4"/></svg>',
    ticket:  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 7a2 2 0 0 1 2-2h12a2 2 0 0 1 2 2v2a2 2 0 0 0 0 6v2a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2v-2a2 2 0 0 0 0-6Z"/></svg>',
    x:       '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"><path d="M6 6l12 12M18 6 6 18"/></svg>',
    retry:   '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 12a9 9 0 1 1-3-6.7L21 8M21 4v4h-4"/></svg>',
    bolt:    '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M13 2 4 14h6l-1 8 9-12h-6z"/></svg>',
    flask:   '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M9 3h6M10 3v6L5 19a1.5 1.5 0 0 0 1.4 2h11.2A1.5 1.5 0 0 0 19 19l-5-10V3"/></svg>',
    people:  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="9" cy="8" r="3.2"/><path d="M2.5 20a6.5 6.5 0 0 1 13 0M17 5.2a3.2 3.2 0 0 1 0 6M19.5 20a6.4 6.4 0 0 0-3-5.4"/></svg>',
    branch:  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="6" cy="6" r="2.5"/><circle cx="6" cy="18" r="2.5"/><circle cx="18" cy="9" r="2.5"/><path d="M6 8.5v7M8.4 7.4A6 6 0 0 1 15.5 9"/></svg>'
  };

  /* ---------- state ---------- */
  var S = {
    forcedOffline: false,
    syncing: false,
    lastSynced: Date.now(),
    queue: [],        // {id, kind, label, sub, icon, state, el}
    failNext: false,  // demo: next flush fails
    demoOpen: false,  // demo controls disclosure
    seq: 0
  };
  function isOffline() { return S.forcedOffline || navigator.onLine === false; }

  /* ---------- DOM refs (built on init) ---------- */
  var screen, statusBar, chip, banner, ptr, scrim, sheet, fab, toastEl, collide, chipHideTimer = null;

  function build() {
    screen = document.getElementById("screen");
    if (!screen) return false;
    statusBar = $(".status-bar", screen);
    if (!statusBar) return false;

    /* chip in status bar */
    chip = elFrom('<button class="sy-chip is-synced" type="button" aria-label="Sync status" aria-live="polite">' +
      '<span class="sy-dot"></span><span class="sy-ring">' + IC.spin + '</span>' +
      '<span class="sy-txt">Synced</span><span class="sy-count">0</span></button>');
    statusBar.appendChild(chip);
    chip.addEventListener("click", openSheet);

    /* offline / reconnect banner */
    banner = elFrom('<div class="sy-banner"><span class="sy-bic"></span>' +
      '<div class="sy-btext"></div><button class="sy-bbtn" type="button">View</button></div>');
    screen.appendChild(banner);
    $(".sy-bbtn", banner).addEventListener("click", openSheet);

    /* pull-to-refresh */
    ptr = elFrom('<div class="sy-ptr"><span class="sy-ptr-ring">' + IC.sync + '</span></div>');
    screen.appendChild(ptr);

    /* collision banner */
    collide = elFrom('<div class="sy-collide"><span class="ca">KS</span>' +
      '<span class="ct">Kavya S is also viewing this chat</span>' +
      '<span class="cx" role="button" aria-label="Dismiss">' + IC.x + '</span></div>');
    screen.appendChild(collide);
    $(".cx", collide).addEventListener("click", function () { collide.classList.remove("show"); });

    /* sheet + scrim */
    scrim = elFrom('<div class="sy-scrim"></div>');
    sheet = elFrom('<div class="sy-sheet"></div>');
    screen.appendChild(scrim); screen.appendChild(sheet);
    scrim.addEventListener("click", closeSheet);

    /* toast */
    toastEl = elFrom('<div class="sy-toast"></div>');
    screen.appendChild(toastEl);

    return true;
  }

  /* ---------- relative time ---------- */
  function rel(ts) {
    var s = Math.round((Date.now() - ts) / 1000);
    if (s < 8) return "just now";
    if (s < 60) return s + "s ago";
    var m = Math.round(s / 60);
    if (m < 60) return m + "m ago";
    var h = Math.round(m / 60);
    if (h < 24) return h + "h ago";
    return Math.round(h / 24) + "d ago";
  }

  /* ---------- chip ---------- */
  function pendingCount() { return S.queue.filter(function (q) { return q.state === "queued" || q.state === "failed"; }).length; }
  function hasFailed() { return S.queue.some(function (q) { return q.state === "failed"; }); }

  function renderChip() {
    if (!chip) return;
    chip.classList.remove("is-synced", "is-syncing", "is-offline", "is-failed", "has-queue");
    var txt = $(".sy-txt", chip), cnt = $(".sy-count", chip);
    var n = pendingCount();
    if (n > 0) { chip.classList.add("has-queue"); cnt.textContent = n; }
    if (S.syncing) { chip.classList.add("is-syncing"); txt.textContent = "Syncing"; }
    else if (hasFailed()) { chip.classList.add("is-failed"); txt.textContent = "Failed"; }
    else if (isOffline()) { chip.classList.add("is-offline"); txt.textContent = n > 0 ? "Offline \u00b7 " + n : "Offline"; }
    else if (n > 0) { chip.classList.add("is-syncing"); txt.textContent = "Pending"; }
    else { chip.classList.add("is-synced"); txt.textContent = "Synced"; }
    chip.setAttribute("aria-label", "Sync status: " + txt.textContent + (n > 0 ? ", " + n + " pending" : ""));

    /* visibility: the chip is NOT a permanent badge. It stays hidden while idle
       and only appears when sync needs attention (syncing/pending/failed/offline)
       or transiently after a pull-to-refresh, then auto-hides. */
    var meaningful = S.syncing || hasFailed() || isOffline() || n > 0;
    if (meaningful) {
      if (chipHideTimer) { clearTimeout(chipHideTimer); chipHideTimer = null; }
      chip.classList.add("sy-chip-show");
    } else {
      var wasShown = chip.classList.contains("sy-chip-show") || S._revealChip;
      S._revealChip = false;
      if (wasShown) {
        chip.classList.add("sy-chip-show");
        if (chipHideTimer) clearTimeout(chipHideTimer);
        chipHideTimer = setTimeout(function () { if (chip) chip.classList.remove("sy-chip-show"); chipHideTimer = null; }, 1500);
      } else {
        chip.classList.remove("sy-chip-show");
      }
    }
  }

  /* ---------- banner ---------- */
  var bannerTimer = null;
  function showBanner(kind) {
    if (!banner) return;
    clearTimeout(bannerTimer);
    banner.classList.toggle("online", kind === "online");
    $(".sy-bic", banner).innerHTML = kind === "online" ? IC.wifi : IC.offline;
    var t = $(".sy-btext", banner), btn = $(".sy-bbtn", banner);
    if (kind === "online") {
      t.innerHTML = "<b>Back online</b><small>Syncing your changes\u2026</small>";
      btn.style.display = "none";
      screen.classList.remove("sy-banner-on");   // transient: don't reflow content
      banner.classList.add("show");
      bannerTimer = setTimeout(hideBanner, 2600);
    } else {
      var n = pendingCount();
      t.innerHTML = "<b>You\u2019re offline</b><small>" + (n > 0 ? n + " change" + (n === 1 ? "" : "s") + " will sync when you reconnect" : "Changes will sync when you reconnect") + "</small>";
      btn.style.display = n > 0 ? "" : "none";
      screen.classList.add("sy-banner-on");      // persistent: push panes below it
      banner.classList.add("show");
    }
  }
  function hideBanner() { if (banner) banner.classList.remove("show"); if (screen) screen.classList.remove("sy-banner-on"); }

  /* ---------- toast ---------- */
  var toastTimer = null;
  function toast(msg, icon) {
    if (!toastEl) return;
    toastEl.innerHTML = (icon || IC.check) + "<span>" + msg + "</span>";
    toastEl.classList.add("show");
    clearTimeout(toastTimer);
    toastTimer = setTimeout(function () { toastEl.classList.remove("show"); }, 2200);
  }

  /* ---------- queue ops ---------- */
  function enqueue(item) {
    item.id = "q" + (++S.seq);
    item.state = item.state || "queued";
    S.queue.push(item);
    renderChip(); renderSheet();
    return item;
  }

  // chat.js calls this for messages composed while offline
  function queueMessage(bubbleEl, name) {
    enqueue({ kind: "msg", icon: IC.msg, label: "Message to " + (name || "contact"), sub: "Chat \u00b7 WhatsApp", el: bubbleEl });
  }

  function flush(opts) {
    opts = opts || {};
    if (S._flushing) return;                // re-entrancy guard: don't interleave overlapping flush passes
    var items = S.queue.filter(function (q) { return q.state === "queued" || (opts.includeFailed && q.state === "failed"); });
    if (!items.length) { S.syncing = false; renderChip(); return; }
    S._flushing = true;
    var failMode = S.failNext; S.failNext = false; // capture one-shot up front
    S.syncing = true; renderChip(); renderSheet();
    var i = 0;
    (function step() {
      if (i >= items.length) {
        // settle
        var anyFail = hasFailed();
        S.syncing = false; S._flushing = false;
        if (!anyFail) { S.lastSynced = Date.now(); }
        renderChip(); renderSheet();
        // clear out the completed rows after a beat
        setTimeout(function () {
          S.queue = S.queue.filter(function (q) { return q.state !== "done"; });
          renderChip(); renderSheet();
        }, 900);
        return;
      }
      var it = items[i++];
      it.state = "syncing"; renderSheet();
      setTimeout(function () {
        var fail = failMode;
        if (fail) {
          it.state = "failed";
          if (it.kind === "msg" && it.el && window.__chatTicks) {
            window.__chatTicks.set(it.el, "failed");
            attachFailNote(it.el, it);
          }
        } else {
          it.state = "done";
          if (it.kind === "msg" && it.el && window.__chatTicks) {
            window.__chatTicks.play(it.el);
          }
        }
        renderChip(); renderSheet();
        setTimeout(step, 280);
      }, 620);
    })();
  }

  function retryItem(id) {
    var it = S.queue.find(function (q) { return q.id === id; });
    if (!it) return;
    if (isOffline()) { toast("Still offline \u2014 can\u2019t sync yet", IC.offline); return; }
    it.state = "syncing"; renderSheet(); renderChip();
    setTimeout(function () {
      it.state = "done";
      if (it.kind === "msg" && it.el && window.__chatTicks) window.__chatTicks.play(it.el);
      S.lastSynced = Date.now();
      renderSheet(); renderChip();
      setTimeout(function () { S.queue = S.queue.filter(function (q) { return q.state !== "done"; }); renderSheet(); renderChip(); }, 800);
    }, 700);
  }
  function retryAll() {
    if (isOffline()) { toast("Still offline \u2014 can\u2019t sync yet", IC.offline); return; }
    S.queue.forEach(function (q) { if (q.state === "failed") q.state = "queued"; });
    flush({ includeFailed: true });
  }

  function attachFailNote(bubble, it) {
    if (!bubble || $(".sy-failnote", bubble)) return;
    var note = elFrom('<div class="sy-failnote">' + IC.retry + 'Not delivered \u00b7 Tap to retry</div>');
    note.addEventListener("click", function (e) {
      e.stopPropagation();
      if (isOffline()) { toast("Still offline \u2014 can\u2019t sync yet", IC.offline); return; }
      note.remove();
      it.state = "syncing"; renderSheet(); renderChip();
      window.__chatTicks.set(bubble, "sending");
      setTimeout(function () {
        it.state = "done"; window.__chatTicks.play(bubble); S.lastSynced = Date.now();
        renderSheet(); renderChip();
        setTimeout(function () { S.queue = S.queue.filter(function (q) { return q.state !== "done"; }); renderSheet(); renderChip(); }, 800);
      }, 700);
    });
    var meta = $(".meta", bubble);
    if (meta) meta.parentNode.insertBefore(note, meta.nextSibling); else bubble.appendChild(note);
  }

  /* ---------- sheet rendering ---------- */
  function heroState() {
    if (S.syncing) return { c: "is-syncing", ic: IC.spin, t: "Syncing\u2026", s: pendingCount() + " item" + (pendingCount() === 1 ? "" : "s") + " in progress" };
    if (hasFailed()) return { c: "is-failed", ic: IC.bang, t: "Sync failed", s: "Some changes didn\u2019t go through" };
    if (isOffline()) return { c: "is-offline", ic: IC.offline, t: "You\u2019re offline", s: pendingCount() + " change" + (pendingCount() === 1 ? "" : "s") + " waiting to sync" };
    if (pendingCount() > 0) return { c: "is-syncing", ic: IC.clock, t: "Pending", s: pendingCount() + " change" + (pendingCount() === 1 ? "" : "s") + " queued" };
    return { c: "is-synced", ic: IC.check, t: "All synced", s: "Last synced \u00b7 " + rel(S.lastSynced) };
  }

  function qStateHTML(q) {
    if (q.state === "syncing") return '<span class="sy-qstate syncing">' + IC.spin + 'Syncing</span>';
    if (q.state === "done") return '<span class="sy-qstate done"><span class="d"></span>Synced</span>';
    if (q.state === "failed") return '<button class="sy-qretry" data-retry="' + q.id + '">' + IC.retry + ' Retry</button>';
    return '<span class="sy-qstate queued"><span class="d"></span>Queued</span>';
  }

  function renderSheet() {
    if (!sheet) return;
    var h = heroState();
    var rows = S.queue.length
      ? '<div class="sy-qlist">' + S.queue.map(function (q) {
          return '<div class="sy-qrow ' + (q.state === "failed" ? "is-failed" : "") + '">' +
            '<span class="sy-qic">' + (q.icon || IC.sync) + '</span>' +
            '<div class="sy-qtx"><b>' + esc(q.label) + '</b><small>' + esc(q.sub || "") + '</small></div>' +
            qStateHTML(q) + '</div>';
        }).join("") + '</div>'
      : '<div class="sy-qempty"><div class="sy-eic">' + IC.check + '</div><b>You\u2019re all caught up</b><span>Every change is synced across your devices.</span></div>';

    sheet.innerHTML =
      '<div class="sy-grab"></div>' +
      '<div class="sy-shero ' + h.c + '"><span class="sy-ic">' + h.ic + '</span>' +
        '<div class="sy-htx"><b>' + h.t + '</b><span>' + h.s + '</span></div>' +
        '<button class="sy-x" type="button">' + IC.x + '</button></div>' +
      '<div class="sy-qsec"><div class="sy-qhd"><span class="sy-qt">Sync queue</span>' +
        '<button class="sy-retryall ' + (hasFailed() ? "show" : "") + '">' + IC.retry + ' Retry all</button></div>' +
        rows + '</div>' +
      demoHTML();

    $(".sy-x", sheet).addEventListener("click", closeSheet);
    var ra = $(".sy-retryall", sheet); if (ra) ra.addEventListener("click", retryAll);
    $$(".sy-qretry", sheet).forEach(function (b) { b.addEventListener("click", function () { retryItem(b.getAttribute("data-retry")); }); });
    wireDemo();
  }

  function esc(s) { return String(s == null ? "" : s).replace(/[&<>"]/g, function (c) { return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]; }); }

  /* ---------- demo controls (tucked behind a quiet disclosure) ---------- */
  function demoHTML() {
    var caret = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="M6 9l6 6 6-6"/></svg>';
    return '<div class="sy-demo">' +
      '<button class="sy-dtoggle" type="button" aria-expanded="' + (S.demoOpen ? "true" : "false") + '">' + IC.flask +
        '<span>Prototype tools</span><i class="sy-dcaret">' + caret + '</i></button>' +
      '<div class="sy-dwrap"' + (S.demoOpen ? "" : " hidden") + '>' +
        '<div class="sy-dgrid">' +
          '<button class="sy-dbtn ' + (isOffline() ? "on" : "") + '" data-demo="offline"><span class="di">' + IC.offline + '</span><b>' + (isOffline() ? "Go online" : "Go offline") + '</b></button>' +
          '<button class="sy-dbtn" data-demo="queue"><span class="di">' + IC.lead + '</span><b>Queue a change</b></button>' +
          '<button class="sy-dbtn" data-demo="fail"><span class="di">' + IC.bang + '</span><b>Make sync fail</b></button>' +
          '<button class="sy-dbtn" data-demo="conflict"><span class="di">' + IC.branch + '</span><b>Edit conflict</b></button>' +
          '<button class="sy-dbtn" data-demo="collision"><span class="di">' + IC.people + '</span><b>Agent collision</b></button>' +
          '<button class="sy-dbtn" data-demo="bg"><span class="di">' + IC.sync + '</span><b>Background sync</b></button>' +
        '</div></div></div>';
  }
  function wireDemo() {
    var tg = $(".sy-dtoggle", sheet);
    if (tg) tg.addEventListener("click", function () { S.demoOpen = !S.demoOpen; renderSheet(); });
    $$(".sy-dbtn", sheet).forEach(function (b) {
      b.addEventListener("click", function () { demoAction(b.getAttribute("data-demo")); });
    });
  }
  var demoQueuePool = [
    { kind: "lead", icon: IC.lead, label: "Lead status \u2192 Converted", sub: "Leads \u00b7 Aarav Mehta" },
    { kind: "appt", icon: IC.cal, label: "Reschedule \u00b7 4:30 PM", sub: "Appointments \u00b7 Priya Nair" },
    { kind: "ticket", icon: IC.ticket, label: "Assign TK-4471 \u2192 Kavya", sub: "Ticketing" },
    { kind: "lead", icon: IC.lead, label: "New note added", sub: "Leads \u00b7 Rohan Das" }
  ];
  var demoQIdx = 0;
  function demoAction(a) {
    if (a === "offline") {
      S.forcedOffline = !S.forcedOffline;
      if (S.forcedOffline) { showBanner("offline"); toast("Offline mode on", IC.offline); }
      else { onReconnect(); }
      renderChip(); renderSheet();
    } else if (a === "queue") {
      var p = demoQueuePool[demoQIdx % demoQueuePool.length]; demoQIdx++;
      enqueue({ kind: p.kind, icon: p.icon, label: p.label, sub: p.sub });
      if (isOffline()) { showBanner("offline"); toast("Queued \u2014 will sync when online", IC.clock); }
      else { toast("Syncing change\u2026", IC.spin); flush(); }
    } else if (a === "fail") {
      S.failNext = true;
      if (pendingCount() === 0) { var p2 = demoQueuePool[demoQIdx % demoQueuePool.length]; demoQIdx++; enqueue({ kind: p2.kind, icon: p2.icon, label: p2.label, sub: p2.sub }); }
      if (isOffline()) { S.forcedOffline = false; }
      toast("Forcing a failed sync\u2026", IC.bang);
      flush({ includeFailed: true });
    } else if (a === "conflict") {
      closeSheet(); setTimeout(openConflict, 280);
    } else if (a === "collision") {
      closeSheet();
      if (window.__appRoute) window.__appRoute("chats", { keepChat: true });
      setTimeout(function () { showCollision(); }, 360);
    } else if (a === "bg") {
      closeSheet(); setTimeout(backgroundSync, 200);
    }
  }

  /* ---------- conflict sheet ---------- */
  var cfChoice = "latest";
  function openConflict() {
    cfChoice = "latest";
    sheet.classList.add("sy-conflict");
    sheet.innerHTML =
      '<div class="sy-grab"></div>' +
      '<div class="sy-shero is-syncing"><span class="sy-ic">' + IC.branch + '</span>' +
        '<div class="sy-htx"><b>This lead changed elsewhere</b><span>Aarav Mehta \u00b7 edited on another device</span></div>' +
        '<button class="sy-x" type="button">' + IC.x + '</button></div>' +
      '<div style="padding:14px 0 2px"><div class="sy-cfields">' +
        cfField("Status", "Warm", "Converted") +
        cfField("Owner", "You (Eshan)", "Kavya S") +
      '</div></div>' +
      '<div class="sy-cf-actions">' +
        '<button data-cf="mine">Keep mine</button>' +
        '<button class="sy-cf-go" data-cf="go">Use latest</button>' +
      '</div>';
    $(".sy-x", sheet).addEventListener("click", closeSheet);
    $$(".sy-cf-opt", sheet).forEach(function (o) {
      o.addEventListener("click", function () {
        var grp = o.getAttribute("data-grp");
        $$('.sy-cf-opt[data-grp="' + grp + '"]', sheet).forEach(function (x) { x.classList.remove("sel"); });
        o.classList.add("sel");
      });
    });
    $$("[data-cf]", sheet).forEach(function (b) {
      b.addEventListener("click", function () {
        var k = b.getAttribute("data-cf");
        closeSheet();
        setTimeout(function () {
          S.lastSynced = Date.now(); renderChip();
          toast(k === "mine" ? "Kept your version \u00b7 synced" : "Updated to the latest \u00b7 synced");
          sheet.classList.remove("sy-conflict");
          renderSheet();
        }, 300);
      });
    });
    openSheetRaw();
  }
  function cfField(k, mine, theirs) {
    var g = k.toLowerCase();
    return '<div class="sy-cfield"><div class="sy-cf-k">' + k + '</div><div class="sy-cf-opts">' +
      '<div class="sy-cf-opt" data-grp="' + g + '"><small>Yours</small><b>' + mine + '</b></div>' +
      '<div class="sy-cf-opt sel" data-grp="' + g + '"><small>Latest</small><b>' + theirs + '</b></div>' +
    '</div></div>';
  }

  /* ---------- collision banner ---------- */
  var collideTimer = null;
  function showCollision() {
    if (!collide) return;
    collide.classList.add("show");
    clearTimeout(collideTimer);
    collideTimer = setTimeout(function () { collide.classList.remove("show"); }, 5200);
  }

  /* ---------- background sync ---------- */
  function backgroundSync() {
    if (S.syncing || isOffline() || pendingCount() > 0) { return; }
    S.syncing = true; renderChip();
    setTimeout(function () {
      S.syncing = false; S.lastSynced = Date.now(); renderChip();
    }, 1200);
  }

  /* ---------- connectivity ---------- */
  function onReconnect() {
    showBanner("online");
    renderChip();
    setTimeout(function () { flush(); }, 700);
  }
  function bindConnectivity() {
    window.addEventListener("offline", function () { if (!S.forcedOffline) { showBanner("offline"); renderChip(); renderSheet(); } });
    window.addEventListener("online", function () { if (!S.forcedOffline) { onReconnect(); renderSheet(); } });
  }

  /* ---------- sheet open/close ---------- */
  function openSheetRaw() { scrim.classList.add("show"); sheet.classList.add("show"); }
  function openSheet() { if (sheet.classList.contains("sy-conflict")) { sheet.classList.remove("sy-conflict"); } renderSheet(); openSheetRaw(); }
  function closeSheet() { scrim.classList.remove("show"); sheet.classList.remove("show"); }

  /* ---------- pull to refresh ---------- */
  function scrollableFrom(node) {
    var n = node;
    while (n && n !== screen && n.nodeType === 1) {
      var st = getComputedStyle(n);
      if ((st.overflowY === "auto" || st.overflowY === "scroll") && n.scrollHeight - n.clientHeight > 6) return n;
      n = n.parentNode;
    }
    return null;
  }
  function bindPTR() {
    var startY = 0, dragging = false, scroller = null, dist = 0, active = false;
    var TH = 66, MAX = 92;
    screen.addEventListener("pointerdown", function (e) {
      if (sheet.classList.contains("show") || isInteractive(e.target)) return;
      scroller = scrollableFrom(e.target);
      if (!scroller || scroller.scrollTop > 2) { scroller = null; return; }
      startY = e.clientY; dragging = true; active = false; dist = 0;
    }, true);
    screen.addEventListener("pointermove", function (e) {
      if (!dragging || !scroller) return;
      if (scroller.scrollTop > 2) { reset(); return; }
      var dy = e.clientY - startY;
      if (dy <= 0) { if (active) { ptr.style.opacity = "0"; } dist = 0; return; }
      active = true;
      dist = Math.min(dy * 0.6, MAX);
      ptr.style.opacity = String(Math.min(dist / TH, 1));
      ptr.style.transform = "translate(-50%," + (dist - 6) + "px)";
      var ring = $(".sy-ptr-ring", ptr); if (ring) ring.style.transform = "rotate(" + (dist * 3.4) + "deg)";
      if (e.cancelable) e.preventDefault();
    }, { capture: true, passive: false });
    function end() {
      if (!dragging) return;
      var fire = active && dist >= TH;
      dragging = false;
      if (fire) doRefresh(); else reset();
    }
    screen.addEventListener("pointerup", end, true);
    screen.addEventListener("pointercancel", reset, true);
    function reset() { dragging = false; active = false; dist = 0; ptr.classList.remove("run"); ptr.style.opacity = "0"; ptr.style.transform = "translate(-50%,0)"; }
    function doRefresh() {
      S._revealChip = true;
      ptr.classList.add("run"); ptr.style.opacity = "1"; ptr.style.transform = "translate(-50%,46px)";
      S.syncing = true; renderChip();
      setTimeout(function () {
        S.syncing = false; S.lastSynced = Date.now(); renderChip();
        if (!isOffline() && pendingCount() > 0) flush();
        reset();
        toast(isOffline() ? "Offline \u2014 showing saved data" : "Synced \u00b7 just now", isOffline() ? IC.offline : IC.check);
      }, 1050);
    }
  }
  function isInteractive(t) {
    return !!(t.closest && t.closest("button, a, input, textarea, select, .sy-sheet, [role=button], .lx-tab, .pf-tab, .seg, [data-seg]"));
  }

  /* ---------- route awareness ---------- */
  function bindRoutes() {
    var ds = screen;
    var obs = new MutationObserver(function () {
      // dismiss collision when leaving chat conversation
      if (!ds.classList.contains("route-chats") || !ds.classList.contains("chat-conv")) {
        if (collide) collide.classList.remove("show");
      }
      renderChip();
    });
    obs.observe(ds, { attributes: true, attributeFilter: ["class"] });
  }

  /* ---------- real edits → queue (observe the shared #toast) ----------
     Every module reports success through one shared #toast element. We watch
     it: a syncable edit made OFFLINE becomes a pending queue item; made ONLINE
     it triggers a brief "Syncing→Synced" pulse so the chip reflects real work. */
  function cap(s) { s = String(s || "").trim(); return s.length > 42 ? s.slice(0, 40) + "\u2026" : s; }
  function classifyToast(msg) {
    var m = (msg || "").toLowerCase();
    if (!m) return null;
    // ignore noise + confirmations that aren't data writes
    if (/refreshed|copied|synced|sync complete|caught up|all synced|downloaded|exported|logged out|link copied|test event|coming soon|enter |select |required|invalid|please /.test(m)) return null;
    if (/appointment|booking|reschedul|no-show|no show|marked as complete|payment collected|slot|confirmed/.test(m)) return { icon: IC.cal, sub: "Appointments" };
    if (/ticket|tk-|escalat|resolved|reopened|priority|reply sent|internal note/.test(m)) return { icon: IC.ticket, sub: "Ticketing" };
    if (/lead|converted|prospect|customer|status|owner|stage|assigned|pipeline/.test(m)) return { icon: IC.lead, sub: "Leads" };
    if (/message|broadcast|campaign/.test(m)) return { icon: IC.msg, sub: "Chat" };
    if (/saved|updated|added|created|changed|deleted|removed|set |applied|moved/.test(m)) return { icon: IC.sync, sub: "AskEva" };
    return null;
  }
  function onRealEdit(msg) {
    if (!screen || screen.classList.contains("logged-out")) return;
    var c = classifyToast(msg);
    if (!c) return;
    if (isOffline()) {
      enqueue({ kind: "edit", icon: c.icon, label: cap(msg), sub: c.sub + " \u00b7 pending" });
    } else {
      pulseSync();
    }
  }
  function pulseSync() {
    if (S.syncing) { S.lastSynced = Date.now(); return; }
    S.syncing = true; renderChip();
    setTimeout(function () { S.syncing = false; S.lastSynced = Date.now(); renderChip(); renderSheet(); }, 850);
  }
  function bindRealEdits() {
    var t = document.getElementById("toast");
    if (!t) return;
    var last = "", lastAt = 0;
    var obs = new MutationObserver(function () {
      // modules set inline opacity '1' to SHOW and '0' to HIDE — only react to shows.
      // (computed opacity is unreliable here: the toast fades in via transition.)
      if (t.style.opacity !== "1") return;
      var msg = (t.textContent || "").trim();
      if (!msg) return;
      var now = Date.now();
      if (msg === last && now - lastAt < 1600) return;
      last = msg; lastAt = now;
      onRealEdit(msg);
    });
    obs.observe(t, { childList: true, characterData: true, subtree: true, attributes: true, attributeFilter: ["style", "class"] });
  }

  /* ---------- init ---------- */
  function init() {
    if (!build()) return;
    window.__sync = {
      isOffline: isOffline,
      queueMessage: queueMessage,
      enqueue: enqueue,
      toast: toast,
      openSheet: openSheet,
      showCollision: showCollision,
      backgroundSync: backgroundSync,
      state: S
    };
    bindConnectivity();
    bindPTR();
    bindRoutes();
    bindRealEdits();
    renderChip();
    if (isOffline()) showBanner("offline");
    // gentle background sync heartbeat
    setInterval(backgroundSync, 52000);
    // keep the "last synced" label fresh while the sheet is open
    setInterval(function () { if (sheet && sheet.classList.contains("show") && !sheet.classList.contains("sy-conflict")) { var hero = $(".sy-shero .sy-htx span", sheet); if (hero && !S.syncing && !isOffline() && pendingCount() === 0) hero.textContent = "Last synced \u00b7 " + rel(S.lastSynced); } }, 15000);
  }

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", init);
  else init();
})();
