/* AskEva — global Notifications: quick popup + full "View all" screen + live count badges */
(function () {
  "use strict";
  var screen = document.getElementById("screen");
  if (!screen) return;

  var toastT;
  function toast(msg) {
    var t = document.getElementById("toast"); if (!t) return;
    t.textContent = msg; t.style.opacity = "1"; t.style.transform = "translateX(-50%) translateY(0)";
    clearTimeout(toastT); toastT = setTimeout(function () { t.style.opacity = "0"; t.style.transform = "translateX(-50%) translateY(20px)"; }, 1800);
  }
  function $$(s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); }
  function iso(d) { return d.getFullYear() + "-" + ("0" + (d.getMonth() + 1)).slice(-2) + "-" + ("0" + d.getDate()).slice(-2); }
  function esc(s) { return String(s == null ? "" : s).replace(/[&<>"]/g, function (c) { return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]; }); }
  var PRD_MON = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
  function prettyD(s) { var p = (s || "").split("-"); if (p.length < 3) return s; return (+p[2]) + " " + (PRD_MON[+p[1] - 1] || "") + " " + p[0]; }

  var I = {
    lead: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="8" r="3.5"/><path d="M5 20c0-3.3 3-5.5 7-5.5s7 2.2 7 5.5"/></svg>',
    hot: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 22a6 6 0 0 0 6-6c0-2.2-1-3.9-2.6-5.4-.4 1.1-1 1.6-1.7 1.7.6-2.6-.4-4.9-3-6.8.3 2.6-.9 3.9-2.2 5.2C6.8 12.4 6 13.9 6 16a6 6 0 0 0 6 6Z"/></svg>',
    conv: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9" stroke-width="1.8"/><path d="m8 12 2.6 2.6L16 9.5"/></svg>',
    msg: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14 9a2 2 0 0 1-2 2H6l-4 4V4c0-1.1.9-2 2-2h8a2 2 0 0 1 2 2v5Z"/><path d="M18 9h2a2 2 0 0 1 2 2v11l-4-4h-6a2 2 0 0 1-2-2v-1"/></svg>',
    fund: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="6" width="18" height="13" rx="2.5"/><path d="M3 10h18M16 15h2"/></svg>',
    appt: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="5" width="18" height="16" rx="2.5"/><path d="M3 10h18M8 3v4M16 3v4"/></svg>',
    ticket: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 7a2 2 0 0 1 2-2h12a2 2 0 0 1 2 2v2a2 2 0 0 0 0 6v2a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2v-2a2 2 0 0 0 0-6z"/></svg>',
    bell: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M6 9a6 6 0 0 1 12 0c0 4 1.5 5 2 6H4c.5-1 2-2 2-6Z"/><path d="M10 19a2 2 0 0 0 4 0"/></svg>',
    x: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M18 6 6 18M6 6l12 12"/></svg>',
    back: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="m15 18-6-6 6-6"/></svg>',
    cal: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="5" width="18" height="16" rx="2.5"/><path d="M3 10h18M8 3v4M16 3v4"/></svg>',
    chevD: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m6 9 6 6 6-6"/></svg>'
  };

  /* =========================================================
     LIVE notification feed — built from the real app stores
     (Leads, Tickets, Appointments) plus any runtime push events.
     No dummy data: every row maps to an actual record. Read state
     is persisted so dismissed items stay read across refreshes.
     ========================================================= */
  var READK = "askeva.notifs.read.v1";
  var readSet = {}; try { (JSON.parse(localStorage.getItem(READK)) || []).forEach(function (id) { readSet[id] = 1; }); } catch (e) {}
  function saveRead() { try { localStorage.setItem(READK, JSON.stringify(Object.keys(readSet))); } catch (e) {} }
  function markRead(id) { if (id && !readSet[id]) { readSet[id] = 1; saveRead(); } }

  /* runtime push() events (in-memory, newest first) + current merged feed */
  var pushed = [];
  var NOTIFS = [];

  function n(cat, type, t, d, unread) { return { id: "push:" + (n._i = (n._i || 0) + 1) + ":" + Date.now(), cat: cat, type: type, t: t, d: d, ts: Date.now(), unread: unread !== false }; }
  function cap(s) { s = String(s == null ? "" : s); return s ? s.charAt(0).toUpperCase() + s.slice(1) : s; }
  function parseDMY(s) { var m = /(\d{1,2})-(\d{1,2})-(\d{4})(?:\s+(\d{1,2}):(\d{1,2}))?/.exec(s || ""); if (!m) return Date.now(); return new Date(+m[3], +m[2] - 1, +m[1], +(m[4] || 0), +(m[5] || 0)).getTime(); }
  function minsAgo(m) { return Date.now() - (+m || 0) * 60000; }
  function timeStr(t) { t = +t || 0; var h = Math.floor(t / 60), mm = t % 60, ap = h >= 12 ? "PM" : "AM", hh = h % 12 || 12; return hh + ":" + ("0" + mm).slice(-2) + " " + ap; }

  function buildLeads() {
    var out = [], L = window.AskEvaLeads || [];
    L.forEach(function (l) {
      if (!l || !l.name) return;
      var st = (l.status || "").toLowerCase();
      var type = st === "converted" ? "conv" : st === "hot" ? "hot" : "lead";
      out.push({ id: "lead:" + l.id + ":" + (l.updated || l.created || ""), cat: "leads", type: type,
        t: st === "converted" ? "Lead converted" : st === "hot" ? "Lead marked Hot" : "Lead Notification",
        d: "Lead " + l.name + (l.mobile ? " (" + l.mobile + ")" : "") + " \u2014 status: " + (cap(l.status) || "New") + ".",
        ts: parseDMY(l.updated || l.created), to: l.assigned || "" });
    });
    return out;
  }
  function buildAppts() {
    var out = [], A = (window.AX && window.AX.appts) || [];
    A.forEach(function (a) {
      if (!a) return;
      var when = (window.AX && AX.relWord && AX.relWord(a.date)) || (window.AX && AX.fmtDayLong && AX.fmtDayLong(a.date)) || a.date;
      out.push({ id: "appt:" + a.id + ":" + a.status, cat: "appointments", type: "appt",
        t: "Appointment Notification",
        d: "Appointment with " + (a.name || "client") + " on " + when + " at " + timeStr(a.time) + ". Status: " + (a.status || "scheduled") + ".",
        ts: minsAgo(a.created), to: a.user || "" });
    });
    return out;
  }
  function buildTickets() {
    var out = [], T = (window.TK && TK.tickets) || [];
    T.forEach(function (t) {
      if (!t) return;
      var resolved = (t.status || "") === "resolved";
      out.push({ id: "tk:" + t.id + ":" + t.status + ":" + t.updated, cat: "tickets", type: "ticket",
        t: "Ticket Notification",
        d: resolved
          ? "Ticket #" + t.num + " \u201C" + t.subject + "\u201D was resolved."
          : "Ticket #" + t.num + " \u201C" + t.subject + "\u201D \u00b7 " + cap(t.priority) + " priority.",
        ts: minsAgo(t.updated != null ? t.updated : t.created), to: (t.assignee && t.assignee !== "unassigned") ? t.assignee : "" });
    });
    return out;
  }

  function rebuild() {
    var live = buildLeads().concat(buildAppts(), buildTickets());
    var all = pushed.concat(live);
    all.sort(function (a, b) { return b.ts - a.ts; });
    all = all.slice(0, 50);
    all.forEach(function (it) { it.unread = !readSet[it.id]; });
    NOTIFS = all;
    return NOTIFS;
  }

  function unreadCount() { rebuild(); return NOTIFS.filter(function (x) { return x.unread; }).length; }
  function ago(ts) {
    var m = Math.round((Date.now() - ts) / 60000);
    if (m < 1) return "just now";
    if (m < 60) return m + " min" + (m === 1 ? "" : "s") + " ago";
    var h = Math.round(m / 60); if (h < 24) return h + " hr" + (h === 1 ? "" : "s") + " ago";
    var d = Math.round(h / 24); return d + " day" + (d === 1 ? "" : "s") + " ago";
  }
  function dayLabel(ts) {
    var d = new Date(ts), t = new Date();
    if (iso(d) === iso(t)) return "Today";
    t.setDate(t.getDate() - 1); if (iso(d) === iso(t)) return "Yesterday";
    return new Date(ts).toLocaleDateString("en-GB", { day: "numeric", month: "short" });
  }

  /* =========================================================
     LIVE COUNT BADGES on every notification bell
     ========================================================= */
  function syncBadges() {
    var c = unreadCount();
    $$('[aria-label="Notifications"]').forEach(function (bell) {
      var b = bell.querySelector(".nt-badge");
      if (c > 0) {
        if (!b) { b = document.createElement("span"); b.className = "nt-badge"; bell.appendChild(b); }
        b.textContent = c > 99 ? "99+" : c;
        b.hidden = false;
      } else if (b) { b.hidden = true; }
    });
  }

  /* =========================================================
     QUICK POPUP
     ========================================================= */
  var scrim = document.createElement("div"); scrim.className = "nt-scrim";
  var panel = document.createElement("div"); panel.className = "nt-panel";
  screen.appendChild(scrim); screen.appendChild(panel);

  function render() {
    var c = unreadCount();
    /* quick popup shows UNREAD only — "Mark all read" / tapping items empties it to the all-caught-up state */
    var vis = NOTIFS.filter(function (x) { return x.unread; });
    var groups = {}, order = [];
    vis.forEach(function (it) { var L = dayLabel(it.ts); if (!groups[L]) { groups[L] = []; order.push(L); } groups[L].push(it); });
    var rows = "";
    order.forEach(function (L) {
      rows += '<div class="nt-daylbl">' + L + '</div>';
      groups[L].forEach(function (it) {
        rows += '<div class="nt-item' + (it.unread ? " unread" : "") + '" data-id="' + it.id + '">' +
          '<span class="nt-ic ' + it.type + '">' + (I[it.type] || I.bell) + '</span>' +
          '<div class="nt-body"><div class="t">' + esc(it.t) + '</div><div class="d">' + esc(it.d) + '</div>' + (it.to ? '<div class="d" style="color:var(--eva-green-deep,#177a36);font-weight:700">For ' + esc((it.to + "").split("@")[0]) + '</div>' : '') + '<div class="ago">' + ago(it.ts) + '</div></div>' +
          '<span class="nt-dot"></span></div>';
      });
    });
    var body = vis.length ? rows : '<div class="nt-empty"><div class="ei">' + I.bell + '</div><p>You\u2019re all caught up</p></div>';
    panel.innerHTML =
      '<div class="nt-head"><span class="tt">Notifications</span>' + (c ? '<span class="cnt">' + c + '</span>' : '') +
        '<button class="read" data-read>Mark all read</button>' +
        '<button class="x" data-x>' + I.x + '</button></div>' +
      '<div class="nt-list">' + body + '</div>' +
      '<div class="nt-foot"><button data-all>View all notifications</button></div>';

    panel.querySelector("[data-x]").addEventListener("click", close);
    panel.querySelector("[data-read]").addEventListener("click", function () { NOTIFS.forEach(function (i) { markRead(i.id); }); render(); syncBadges(); toast("All notifications marked read"); });
    panel.querySelector("[data-all]").addEventListener("click", function () { close(); openFull(); });
    $$(".nt-item", panel).forEach(function (el) {
      el.addEventListener("click", function () {
        var it = byId(el.getAttribute("data-id")); if (it && it.unread) { markRead(it.id); render(); syncBadges(); }
      });
    });
  }
  function byId(id) { for (var i = 0; i < NOTIFS.length; i++) if (NOTIFS[i].id === id) return NOTIFS[i]; return null; }

  var open = false;
  function openPanel() { render(); requestAnimationFrame(function () { scrim.classList.add("show"); panel.classList.add("show"); }); open = true; }
  function close() { scrim.classList.remove("show"); panel.classList.remove("show"); open = false; }
  scrim.addEventListener("click", close);

  /* =========================================================
     FULL "VIEW ALL" SCREEN  (tabs + unread + date range)
     ========================================================= */
  var fxScrim = document.createElement("div"); fxScrim.className = "ntx-scrim";
  var fx = document.createElement("div"); fx.className = "ntx-screen";
  screen.appendChild(fxScrim); screen.appendChild(fx);
  fxScrim.addEventListener("click", closeFull);

  var TABS = [["all", "All Notifications"], ["tickets", "Tickets"], ["leads", "Leads"], ["appointments", "Appointments"]];
  var flt = { tab: "all", unread: false, start: "", end: "" };

  function matches(it) {
    if (flt.tab !== "all" && it.cat !== flt.tab) return false;
    if (flt.unread && !it.unread) return false;
    var di = iso(new Date(it.ts));
    if (flt.start && di < flt.start) return false;
    if (flt.end && di > flt.end) return false;
    return true;
  }
  function tabCount(tab) { return NOTIFS.filter(function (it) { return (tab === "all" || it.cat === tab) && (!flt.unread || it.unread); }).length; }

  function renderFull() {
    rebuild();
    var list = NOTIFS.filter(matches);
    var rows = list.length ? list.map(function (it) {
      return '<div class="ntx-item' + (it.unread ? " unread" : "") + '" data-id="' + it.id + '">' +
        '<span class="ntx-ic ' + it.type + '">' + (I[it.type] || I.bell) + '</span>' +
        '<div class="ntx-body"><div class="t">' + esc(it.t) + ': <span class="dd">' + esc(it.d) + '</span>' + (it.to ? ' <span class="dd" style="color:var(--eva-green-deep,#177a36)">\u2192 ' + esc((it.to + "").split("@")[0]) + '</span>' : '') + '</div></div>' +
        '<div class="ntx-meta"><span class="ago">' + ago(it.ts) + '</span>' + (it.unread ? '<span class="udot"></span>' : '') + '</div></div>';
    }).join("") : '<div class="ntx-empty"><div class="ei">' + I.bell + '</div><p>No notifications match these filters.</p></div>';

    fx.innerHTML =
      '<div class="ntx-top">' +
        '<button class="ntx-back" data-x>' + I.back + '</button>' +
        '<span class="ntx-hic">' + I.bell + '</span>' +
        '<div class="ntx-htxt"><div class="h">Notifications</div><div class="s">See all updates at a glance</div></div>' +
        '<div class="ntx-statuswrap">' +
          '<button class="ntx-statusbtn' + (flt.unread ? " on" : "") + '" data-statusbtn>' + (flt.unread ? "Unread" : "All status") +
            '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="m6 9 6 6 6-6"/></svg></button>' +
          '<div class="ntx-statusmenu" id="ntxStatusMenu" hidden>' +
            '<button data-st="all" class="' + (!flt.unread ? "on" : "") + '">All status</button>' +
            '<button data-st="unread" class="' + (flt.unread ? "on" : "") + '">Unread</button>' +
          '</div>' +
        '</div>' +
      '</div>' +
      '<div class="ntx-daterow"><div class="ntx-rangeholder" id="ntxRange"></div></div>' +
      '<div class="ntx-tabs">' + TABS.map(function (t) {
        return '<button class="ntx-tab' + (flt.tab === t[0] ? " on" : "") + '" data-tab="' + t[0] + '">' + esc(t[1]) + '<span class="c">' + tabCount(t[0]) + '</span></button>';
      }).join("") + '</div>' +
      '<div class="ntx-list">' + rows + '</div>';

    fx.querySelector("[data-x]").addEventListener("click", closeFull);
    // status dropdown (All status / Unread)
    var sBtn = fx.querySelector("[data-statusbtn]"), sMenu = fx.querySelector("#ntxStatusMenu");
    if (sBtn && sMenu) {
      sBtn.addEventListener("click", function (e) { e.stopPropagation(); sMenu.hidden = !sMenu.hidden; });
      fx.querySelectorAll("#ntxStatusMenu [data-st]").forEach(function (b) {
        b.addEventListener("click", function () { flt.unread = b.getAttribute("data-st") === "unread"; renderFull(); });
      });
    }
    // universal date-range picker (calendar→X reset, modal, no future)
    var holder = fx.querySelector("#ntxRange");
    if (holder && window.AskEvaPicker && window.AskEvaPicker.rangePill) {
      window.AskEvaPicker.rangePill(holder, {
        start: flt.start, end: flt.end, maxToday: true,
        onChange: function (r) { flt.start = r.start || ""; flt.end = r.end || ""; renderFull(); }
      });
    }
    $$(".ntx-tab", fx).forEach(function (b) { b.addEventListener("click", function () { flt.tab = b.getAttribute("data-tab"); renderFull(); }); });
    $$(".ntx-item", fx).forEach(function (el) { el.addEventListener("click", function () { var it = byId(el.getAttribute("data-id")); if (it && it.unread) { markRead(it.id); renderFull(); syncBadges(); } }); });
  }
  function openFull() { renderFull(); requestAnimationFrame(function () { fxScrim.classList.add("show"); fx.classList.add("show"); }); }
  function closeFull() { fxScrim.classList.remove("show"); fx.classList.remove("show"); }

  /* bell click → popup */
  document.addEventListener("click", function (e) {
    var bell = e.target.closest('[aria-label="Notifications"]');
    if (!bell) return;
    e.preventDefault(); e.stopPropagation();
    if (open) { close(); } else { openPanel(); }
  }, true);

  syncBadges();
  var _badgeInt = setInterval(syncBadges, 1500);   // keep badges live as bells mount/unmount across panes
  document.addEventListener("visibilitychange", function () {
    if (document.hidden) { clearInterval(_badgeInt); _badgeInt = null; }   // pause polling when tab is hidden
    else if (!_badgeInt) { syncBadges(); _badgeInt = setInterval(syncBadges, 1500); }
  });
  document.addEventListener("leads:changed", function () { syncBadges(); if (open) render(); });
  document.addEventListener("lead:viewed", function (e) {
    if (e && e.detail && e.detail.id) markLeadRead(e.detail.id);
  });
  function markLeadRead(id) {
    if (!id) return;
    rebuild();
    NOTIFS.forEach(function (n) {
      if (n.cat === "leads" && (n.id.indexOf("lead:" + id) === 0 || (n.d && n.d.indexOf(id) !== -1))) {
        markRead(n.id);
      }
    });
    if (open) render();
    syncBadges();
  }
  function pushNotif(o) {
    o = o || {};
    var it = n(o.cat || "system", o.type || "lead", o.t || "Notification", o.d || "", true);
    it.to = o.to || "";
    pushed.unshift(it);
    rebuild();
    if (open) render();
    syncBadges();
    return it;
  }
  window.__notifs = { open: openPanel, openFull: openFull, sync: syncBadges, count: unreadCount, push: pushNotif, markRead: markRead, markLeadRead: markLeadRead };
})();
