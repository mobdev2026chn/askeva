/* =========================================================
   AskEva — Ticket Settings (hub + core screens)
   Mobile translation of the web "Ticket Settings":
     hub (Recent / General / Notification / Communication /
     Ticket Management cards) → sub-screens. This file owns
     the hub + router + Business Hours, SLA Policies,
     Department Configuration, Quick Reply, Video Note.
     (Alerts, Ticket Form, Webhook live in -settings2.js)
   Renders into #txSettingsView. Uses window.TK.
   ========================================================= */
(function () {
  "use strict";
  var TK = window.TK; if (!TK) return;
  var $ = TK.$, $$ = TK.$$, esc = TK.esc, toast = TK.toast;

  function load(k, d) { try { var v = JSON.parse(localStorage.getItem(k)); return v == null ? d : v; } catch (e) { return d; } }
  function store(k, v) { try { localStorage.setItem(k, JSON.stringify(v)); } catch (e) {} }

  /* recently-accessed settings (most-recent first, capped at 3) */
  var RECENT_KEY = "askeva.tset.recent.v1";
  function getRecent() { var r = load(RECENT_KEY, []); return Array.isArray(r) ? r : []; }
  function pushRecent(id) {
    if (id === "__hub") return;
    var r = getRecent().filter(function (x) { return x !== id; });
    r.unshift(id); store(RECENT_KEY, r.slice(0, 3));
  }

  /* =========================================================
     REGISTRY + ROUTER
     ========================================================= */
  var S = {
    screens: {},
    route: null,
    register: function (def) { this.screens[def.id] = def; },
    open: function (id) { this.route = id; pushRecent(id); this.render(); },
    back: function () { this.route = null; this.render(); },
    render: function () {
      var host = $("#txSettingsView"); if (!host) return;
      if (!this.route || !this.screens[this.route]) { renderHub(host); return; }
      var def = this.screens[this.route];
      host.innerHTML = '<div class="ts-screenbar"><button class="ts-back" id="tsBack">' + IC.back + 'Back</button></div>' +
        '<h2 class="ts-screentitle">' + esc(def.title) + '</h2>' +
        '<div id="tsScreenBody"></div>';
      $("#tsBack", host).addEventListener("click", function () { S.back(); });
      def.render($("#tsScreenBody", host));
      var sh = $(".lp-sheet", TK.pane); if (sh) sh.scrollTop = 0;
    }
  };
  window.TKSettings = S;

  var IC = {
    back: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M15 19l-7-7 7-7"/></svg>',
    search: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><circle cx="11" cy="11" r="7"/><path d="M21 21l-4.3-4.3"/></svg>',
    plus: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"><path d="M12 5v14M5 12h14"/></svg>',
    chevD: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m6 9 6 6 6-6"/></svg>',
    chevL: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m15 6-6 6 6 6"/></svg>',
    chevR: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m9 6 6 6-6 6"/></svg>',
    clock: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3.5 2"/></svg>',
    alarm: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="13" r="8"/><path d="M12 9v4l2.5 2M5 3 2 6M19 3l3 3"/></svg>',
    dept: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linejoin="round"><path d="M3 7 12 3l9 4-9 4-9-4Z"/><path d="M3 7v6l9 4 9-4V7"/></svg>',
    chat: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14 9a2 2 0 0 1-2 2H6l-4 4V4c0-1.1.9-2 2-2h8a2 2 0 0 1 2 2v5Z"/><path d="M18 9h2a2 2 0 0 1 2 2v11l-4-4h-6a2 2 0 0 1-2-2v-1"/><circle cx="5.2" cy="6.4" r=".7" fill="currentColor" stroke="none"/><circle cx="8" cy="6.4" r=".7" fill="currentColor" stroke="none"/><circle cx="10.8" cy="6.4" r=".7" fill="currentColor" stroke="none"/></svg>',
    video: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linejoin="round"><rect x="3" y="6" width="13" height="12" rx="2"/><path d="m16 10 5-3v10l-5-3"/></svg>',
    gear: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="3.2"/><path d="M19.4 13.5a7.7 7.7 0 0 0 0-3l1.8-1.3-2-3.4-2.1.9a7.5 7.5 0 0 0-2.6-1.5L12 2H8l-.5 2.2A7.5 7.5 0 0 0 4.9 5.7L2.8 4.8l-2 3.4 1.8 1.3a7.7 7.7 0 0 0 0 3L.8 13.8l2 3.4 2.1-.9a7.5 7.5 0 0 0 2.6 1.5L8 22h4l.5-2.2a7.5 7.5 0 0 0 2.6-1.5l2.1.9 2-3.4-1.8-1.3Z"/></svg>',
    edit: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M11 4H5a2 2 0 0 0-2 2v13a2 2 0 0 0 2 2h13a2 2 0 0 0 2-2v-6"/><path d="M18.5 2.5a2.12 2.12 0 0 1 3 3L12 15l-4 1 1-4Z"/></svg>',
    trash: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 7h16M9 7V5a2 2 0 0 1 2-2h2a2 2 0 0 1 2 2v2M6 7l1 13a2 2 0 0 0 2 2h6a2 2 0 0 0 2-2l1-13"/></svg>',
    dots: '<svg viewBox="0 0 24 24" fill="currentColor"><circle cx="12" cy="5" r="2"/><circle cx="12" cy="12" r="2"/><circle cx="12" cy="19" r="2"/></svg>',
    refresh: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 12a9 9 0 1 0 3-6.7L3 8M3 4v4h4"/></svg>',
    save: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M5 3h11l4 4v14H5z"/><path d="M8 3v6h8M8 21v-7h8v7"/></svg>',
    info: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="M12 11v5M12 8h.01"/></svg>',
    tag: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 12V5a2 2 0 0 1 2-2h7l9 9-9 9-9-9Z"/><circle cx="8" cy="8" r="1.3" fill="currentColor"/></svg>',
    play: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="m10 9 5 3-5 3V9Z"/></svg>',
    upload: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 16V4m0 0 4 4m-4-4L8 8M4 18v1a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-1"/></svg>',
    x: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"><path d="M6 6l12 12M18 6 6 18"/></svg>',
    check: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="m5 12 4 4 10-11"/></svg>'
  };
  S.IC = IC;

  /* =========================================================
     HUB
     ========================================================= */
  var HUB = [
    ["General", [["department"], ["ticketForm"], ["businessHours"]]],
    ["Notification", [["alerts"], ["webhook"]]],
    ["Communication", [["quickReply"], ["videoNote"]]],
    ["Ticket Management", [["sla"]]]
  ];
  function cardHTML(def, q) {
    if (!def) return "";
    if (q && (def.title + " " + def.sub).toLowerCase().indexOf(q) < 0) return "";
    return '<button class="ts-card" data-id="' + def.id + '"><span class="ic">' + (def.icon || IC.gear) + '</span>' +
      '<span class="ttl">' + esc(def.title) + '</span><span class="sub">' + esc(def.sub) + '</span></button>';
  }
  function renderHub(host) {
    var q = (S.hubQ || "").trim().toLowerCase();
    /* dynamic Recent group — the 3 most recently opened settings */
    var recentIds = getRecent();
    var recentCards = recentIds.map(function (id) { return cardHTML(S.screens[id], q); }).join("");
    var recentGroup = recentCards.replace(/\s/g, "")
      ? '<div class="ts-group"><div class="ts-grouplbl">Recent</div><div class="ts-cards">' + recentCards + '</div></div>' : "";
    var groups = recentGroup + HUB.map(function (g) {
      var cards = g[1].map(function (c) { return cardHTML(S.screens[c[0]], q); }).join("");
      if (!cards.replace(/\s/g, "")) return "";
      return '<div class="ts-group"><div class="ts-grouplbl">' + esc(g[0]) + '</div><div class="ts-cards">' + cards + '</div></div>';
    }).join("");
    host.innerHTML =
      '<div class="ts-search">' + IC.search + '<input id="tsHubQ" type="text" placeholder="Search settings" value="' + esc(S.hubQ || "") + '" autocomplete="off"></div>' +
      (groups || '<div class="ts-empty">No settings match your search.</div>');
    var qi = $("#tsHubQ", host); if (qi) qi.addEventListener("input", function (e) {
      S.hubQ = e.target.value; var c = e.target.selectionStart; renderHub(host);
      var n = $("#tsHubQ", host); if (n) { n.focus(); try { n.setSelectionRange(c, c); } catch (x) {} }
    });
    $$(".ts-card", host).forEach(function (b) { b.addEventListener("click", function () { S.open(b.getAttribute("data-id")); }); });
  }

  /* =========================================================
     BUSINESS HOURS
     ========================================================= */
  var BHK = "askeva.tset.bh.v1";
  var DAYS = [["mon", "Monday"], ["tue", "Tuesday"], ["wed", "Wednesday"], ["thu", "Thursday"], ["fri", "Friday"], ["sat", "Saturday"], ["sun", "Sunday"]];
  var bh = load(BHK, {
    tz: "America/New_York",
    days: { mon: o(1), tue: o(1), wed: o(1), thu: o(1), fri: o(1), sat: o(0), sun: o(0) }
  });
  function o(open) { return { open: !!open, start: "09:00", end: "18:00", breaks: [] }; }
  var TZS = ["America/New_York", "America/Los_Angeles", "Europe/London", "Asia/Kolkata", "Asia/Dubai", "Australia/Sydney"];
  function hrs(d) { if (!d.open) return "Closed"; var s = +d.start.split(":")[0] + (+d.start.split(":")[1]) / 60, e = +d.end.split(":")[0] + (+d.end.split(":")[1]) / 60; var h = Math.round((e - s) * 10) / 10; return (h % 1 ? h : h | 0) + "h"; }

  S.register({
    id: "businessHours", title: "Business Hours", sub: "Set your business hours and working days", icon: IC.clock,
    render: function (host) {
      host.innerHTML =
        '<div class="cfg-card"><div class="bh-hd"><div class="bh-ttl">Working Hours</div>' +
          '<button class="bh-tz" id="bhTz"><span class="lab">' + esc(bh.tz) + '</span>' + IC.chevD + '</button></div>' +
          '<div class="bh-days">' + DAYS.map(dayCard).join("") + '</div></div>' +
        '<div class="ts-savebar"><button class="cfg-btn primary" id="bhSave">' + IC.save + 'Save All</button></div>';
      $("#bhTz", host).addEventListener("click", function () {
        TK.radioSheet("Timezone", TZS.map(function (t) { return { v: t, label: t, on: bh.tz === t }; }), function (v) { bh.tz = v; store(BHK, bh); S.render(); });
      });
      $$(".bh-day", host).forEach(function (card) {
        var k = card.getAttribute("data-d");
        var tg = $(".bh-toggle", card); if (tg) tg.addEventListener("click", function () { bh.days[k].open = !bh.days[k].open; store(BHK, bh); S.render(); });
        $$("input[type=time]", card).forEach(function (inp) {
          inp.addEventListener("change", function () { bh.days[k][inp.getAttribute("data-f")] = inp.value; store(BHK, bh); var b = $(".bh-h", card); if (b) b.textContent = hrs(bh.days[k]); });
        });
        var cb = $(".bh-breaks", card); if (cb) cb.addEventListener("click", function () { openBreaks(k); });
      });
      $("#bhSave", host).addEventListener("click", function () { store(BHK, bh); toast("Business hours saved"); });
    }
  });
  function dayCard(o2) {
    var k = o2[0], d = bh.days[k];
    return '<div class="bh-day" data-d="' + k + '"><div class="bh-dhd"><span class="nm">' + o2[1] + '</span><span class="bh-h">' + hrs(d) + '</span></div>' +
      '<button class="bh-toggle' + (d.open ? " on" : "") + '"><span class="kn"></span><span class="tx">' + (d.open ? "Open" : "Closed") + '</span></button>' +
      (d.open ? '<div class="bh-times"><label>Start Time</label><div class="bh-timein">' + IC.clock + '<input type="time" data-f="start" value="' + d.start + '"></div>' +
        '<label>End Time</label><div class="bh-timein">' + IC.clock + '<input type="time" data-f="end" value="' + d.end + '"></div>' +
        '<div class="bh-brk"><span class="k">Breaks:</span><span class="v">' + (d.breaks.length ? d.breaks.length + " configured" : "No breaks configured") + '</span></div>' +
        '<button class="bh-breaks">' + IC.edit + 'Configure Breaks</button></div>' : '') +
      '</div>';
  }
  /* break editor — add / remove break windows for a working day */
  function openBreaks(k) {
    var dayLabel = (DAYS.filter(function (x) { return x[0] === k; })[0] || ["", k])[1];
    var draft = JSON.parse(JSON.stringify(bh.days[k].breaks || []));
    function body() {
      var rows = draft.length ? draft.map(function (b, i) {
        return '<div class="bh-brkrow" data-i="' + i + '">' +
          '<div class="bh-timein sm">' + IC.clock + '<input type="time" data-f="start" data-i="' + i + '" value="' + (b.start || "13:00") + '"></div>' +
          '<span class="bh-brkdash">to</span>' +
          '<div class="bh-timein sm">' + IC.clock + '<input type="time" data-f="end" data-i="' + i + '" value="' + (b.end || "14:00") + '"></div>' +
          '<button class="bh-brkdel" data-i="' + i + '" aria-label="Remove">' + IC.trash + '</button></div>';
      }).join("") : '<div class="ts-empty" style="padding:18px 8px">No breaks added yet.</div>';
      return '<div class="ax-grip"></div><div class="ax-sheet-head"><div><div class="ax-sheet-ttl">Configure Breaks</div>' +
        '<div class="ax-sheet-sub">' + esc(dayLabel) + '</div></div></div>' +
        '<div class="bh-brklist">' + rows + '</div>' +
        '<button class="cfg-btn ghost" id="bhBrkAdd" style="width:100%;margin:6px 0 12px">' + IC.plus + 'Add Break</button>' +
        '<button class="ax-sheetbtn" id="bhBrkSave">Save breaks</button>';
    }
    var s = TK.openSheet(body());
    function rebind() {
      $$(".bh-brkrow input[type=time]", s).forEach(function (inp) {
        inp.addEventListener("change", function () { draft[+inp.getAttribute("data-i")][inp.getAttribute("data-f")] = inp.value; });
      });
      $$(".bh-brkdel", s).forEach(function (b) { b.addEventListener("click", function () { draft.splice(+b.getAttribute("data-i"), 1); refresh(); }); });
    }
    function refresh() { s.innerHTML = body(); wire(); }
    function wire() {
      rebind();
      $("#bhBrkAdd", s).addEventListener("click", function () { draft.push({ start: "13:00", end: "14:00" }); refresh(); });
      $("#bhBrkSave", s).addEventListener("click", function () { bh.days[k].breaks = draft; store(BHK, bh); TK.closeSheet(); S.render(); toast("Breaks saved"); });
    }
    wire();
  }

  /* =========================================================
     SLA POLICIES
     ========================================================= */
  var SLAK = "askeva.tset.sla.v2";
  var slas = load(SLAK, [
    { id: "s1", name: "Priority Support", dept: "Support L2", desc: "Premium customers — fast response", created: "06/02/2026", updated: "12/02/2026", active: true },
    { id: "s2", name: "Standard Resolution", dept: "Support L1", desc: "Default policy for all tickets", created: "16/02/2026", updated: "17/02/2026", active: true },
    { id: "s3", name: "Billing Escalation", dept: "Billing", desc: "Finance-related issues", created: "01/05/2026", updated: "01/05/2026", active: true }
  ]);
  function saveSla() { store(SLAK, slas); }
  /* single source of truth for the SLA fallback times (used when no policy matches).
     Was a literal "3 / 1" sprinkled across ticket creation, detail and escalation. */
  var SLADEFK = "askeva.tset.sladefault.v1";
  var slaDefault = load(SLADEFK, { res: 3, first: 1 });
  TK.slaDefaults = function () { return { res: +slaDefault.res || 3, first: +slaDefault.first || 1 }; };
  TK.setSlaDefaults = function (res, first) { slaDefault = { res: +res || 3, first: +first || 1 }; store(SLADEFK, slaDefault); };
  /* expose the configured SLA times so ticket timers run live off the policy
     (matched by department + ticket priority). Returns minutes or null. */
  TK.slaPolicies = function () { return slas.slice(); };
  TK.slaForTicket = function (t) {
    if (!t) return null;
    var dept = (t.department || "").toLowerCase();
    var prio = t.wpriority || (t.priority === "high" ? "high" : t.priority === "med" ? "medium" : "low");
    // strictly department-scoped: a policy only applies to its own department's
    // tickets. Among that department's active policies, use the one that has
    // times configured for this priority. No cross-department borrowing.
    var pol = slas.filter(function (s) {
      return s.active !== false && s.times && (s.dept || "").toLowerCase() === dept && s.times[prio] &&
        (s.times[prio].fr || s.times[prio].res);
    })[0];
    if (!pol) return null;
    var tm = pol.times[prio];
    function toMin(v, u) { v = parseFloat(v); if (isNaN(v)) return null; u = u || "Minutes"; return u === "Hours" ? v * 60 : u === "Days" ? v * 1440 : v; }
    var fr = toMin(tm.fr, tm.frU), res = toMin(tm.res, tm.resU);
    if (fr == null && res == null) return null;
    return { policy: pol.name, slaFirst: fr, slaRes: res };
  };
  var PR_SLA = [["critical", "Critical Priority", "#C2261A"], ["high", "High Priority", "#D6492B"], ["medium", "Medium Priority", "#C8881A"], ["low", "Low Priority", "#2BA84A"]];
  var SLA_UNITS = ["Minutes", "Hours", "Days"];

  S.register({
    id: "sla", title: "SLA Policies", sub: "Set response and resolution time policies", icon: IC.alarm,
    render: function (host) {
      host.innerHTML = '<div class="ts-actionrow"><button class="cfg-btn primary" id="slaAdd">' + IC.plus + 'Add Policy</button></div>' +
        '<div class="sla-list">' + (slas.length ? slas.map(slaCard).join("") : '<div class="ts-empty">No SLA policies yet.</div>') + '</div>';
      $("#slaAdd", host).addEventListener("click", function () { openSlaForm(); });
      $$(".sla-card", host).forEach(function (card) {
        var id = card.getAttribute("data-id");
        var tg = $(".sla-toggle", card); if (tg) tg.addEventListener("click", function () { var s = slas.filter(function (x) { return x.id === id; })[0]; s.active = !s.active; saveSla(); S.render(); });
        var menu = $(".sla-menu", card); if (menu) menu.addEventListener("click", function () { slaMenu(id); });
      });
    }
  });
  function slaCard(s, i) {
    return '<div class="sla-card" data-id="' + s.id + '"><div class="r1"><span class="sn">' + (i + 1) + '</span><span class="nm">' + esc(s.name) + '</span>' +
      '<button class="sla-menu" aria-label="Actions">' + IC.dots + '</button></div>' +
      '<div class="r2"><span class="dept">' + esc(s.dept) + '</span><span class="desc">' + esc(s.desc) + '</span></div>' +
      '<div class="r3"><span class="dt"><span class="k">Created</span>' + esc(s.created) + '</span><span class="dt"><span class="k">Updated</span>' + esc(s.updated) + '</span>' +
        '<button class="sla-toggle' + (s.active ? " on" : "") + '"><span class="kn"></span></button><span class="stlbl' + (s.active ? " on" : "") + '">' + (s.active ? "Active" : "Inactive") + '</span></div></div>';
  }
  function slaMenu(id) {
    var s = slas.filter(function (x) { return x.id === id; })[0];
    var html = '<div class="ax-grip"></div><div class="ax-sheet-head"><div class="ax-sheet-ttl">' + esc(s.name) + '</div></div><div class="ax-optlist">' +
      '<button class="ax-opt" data-a="edit"><span class="av empty" style="background:var(--accent-soft);color:var(--accent-deep)">' + IC.edit + '</span><span class="t"><span class="nm">Edit policy</span></span></button>' +
      '<button class="ax-opt" data-a="del"><span class="av" style="background:#FDEAE3;color:#C23A18">' + IC.trash + '</span><span class="t"><span class="nm" style="color:#C23A18">Delete policy</span></span></button></div>';
    var sh = TK.openSheet(html);
    $$("[data-a]", sh).forEach(function (b) { b.addEventListener("click", function () {
      var a = b.getAttribute("data-a"); TK.closeSheet();
      if (a === "edit") openSlaForm(s);
      else TK.showConfirm({ title: "Delete policy?", sub: "“" + s.name + "” will be permanently removed.", go: "Delete", onGo: function () { slas = slas.filter(function (x) { return x.id !== id; }); saveSla(); S.render(); toast("Policy deleted"); } });
    }); });
  }
  function openSlaForm(existing) {
    var d = existing || { name: "", desc: "", dept: "", times: {} };
    var draft = { name: d.name, desc: d.desc, dept: d.dept, times: JSON.parse(JSON.stringify(d.times || {})) };
    var fe = document.getElementById("txForm");
    function body() {
      return '<div class="ax-bar"><button class="ax-iconbtn" data-x="close">' + IC.x + '</button><div class="ttl">' + (existing ? "Edit SLA Policy" : "Create New SLA Policy") + '</div><span class="spacer"></span></div>' +
        '<div class="ax-scroll">' +
          '<div class="ax-field"><label class="ax-label">Policy Name<span class="nf-req">*</span></label><div class="ax-control">' + IC.tag + '<input id="slN" type="text" placeholder="Enter policy name" value="' + esc(draft.name) + '"></div></div>' +
          '<div class="ax-field"><label class="ax-label">Description</label><div class="ax-control area"><textarea id="slD" rows="2" placeholder="Enter policy description (optional)">' + esc(draft.desc) + '</textarea></div></div>' +
          '<div class="ax-field"><label class="ax-label">Department<span class="nf-req">*</span></label><button class="nf-select' + (draft.dept ? "" : " ph") + '" id="slDept"><span class="v">' + esc(draft.dept || "Select department") + '</span><span class="cv">' + IC.chevD + '</span></button></div>' +
          '<div class="ts-divlbl">Time Configuration</div><div class="sl-priottl">Priority Resolution Times</div>' +
          PR_SLA.map(slaPrioBlock).join("") +
        '</div>' +
        '<div class="ax-savebar two"><button class="ax-btn ghost" data-x="close">Cancel</button><button class="ax-btn primary" id="slSave">' + IC.check + (existing ? "Save" : "Create") + '</button></div>';
    }
    function slaPrioBlock(p) {
      var t = draft.times[p[0]] || {};
      return '<div class="sl-prio" style="--pc:' + p[2] + '"><div class="hd">' + esc(p[1]) + '</div>' +
        '<label class="sl-l">First Response Time<span class="nf-req">*</span></label><div class="sl-row"><input class="sl-num" data-p="' + p[0] + '" data-f="fr" type="number" placeholder="First Response Time" value="' + (t.fr || "") + '"><button class="sl-unit" data-p="' + p[0] + '" data-f="frU"><span>' + (t.frU || "Unit") + '</span>' + IC.chevD + '</button></div>' +
        '<label class="sl-l">Resolution Time<span class="nf-req">*</span></label><div class="sl-row"><input class="sl-num" data-p="' + p[0] + '" data-f="res" type="number" placeholder="Resolution Time" value="' + (t.res || "") + '"><button class="sl-unit" data-p="' + p[0] + '" data-f="resU"><span>' + (t.resU || "Unit") + '</span>' + IC.chevD + '</button></div></div>';
    }
    function bind() {
      $$('[data-x="close"]', fe).forEach(function (b) { b.addEventListener("click", function () { fe.classList.remove("show"); }); });
      $("#slN", fe).addEventListener("input", function (e) { draft.name = e.target.value; });
      $("#slD", fe).addEventListener("input", function (e) { draft.desc = e.target.value; });
      $("#slDept", fe).addEventListener("click", function () {
        var deps = TKdepts().map(function (x) { return x.name; });
        TK.radioSheet("Department", deps.map(function (x) { return { v: x, label: x, on: draft.dept === x }; }), function (v) { draft.dept = v; fe.innerHTML = body(); bind(); });
      });
      $$(".sl-num", fe).forEach(function (inp) { inp.addEventListener("input", function () { var p = inp.getAttribute("data-p"), f = inp.getAttribute("data-f"); (draft.times[p] = draft.times[p] || {})[f] = inp.value; }); });
      $$(".sl-unit", fe).forEach(function (b) { b.addEventListener("click", function () {
        var p = b.getAttribute("data-p"), f = b.getAttribute("data-f");
        TK.radioSheet("Unit", SLA_UNITS.map(function (u) { return { v: u, label: u, on: false }; }), function (v) { (draft.times[p] = draft.times[p] || {})[f] = v; fe.innerHTML = body(); bind(); });
      }); });
      $("#slSave", fe).addEventListener("click", function () {
        if (!draft.name.trim()) { toast("Enter a policy name"); return; }
        if (!draft.dept) { toast("Select a department"); return; }
        var today = fmtToday();
        if (existing) { existing.name = draft.name.trim(); existing.desc = draft.desc.trim() || "No description"; existing.dept = draft.dept; existing.times = draft.times; existing.updated = today; }
        else { slas.unshift({ id: "s" + Date.now().toString(36), name: draft.name.trim(), desc: draft.desc.trim() || "No description", dept: draft.dept, created: today, updated: today, active: true, times: draft.times }); }
        saveSla(); fe.classList.remove("show"); S.render(); toast(existing ? "Policy updated" : "Policy created");
      });
    }
    fe.innerHTML = body(); bind(); fe.classList.add("show");
  }

  /* =========================================================
     DEPARTMENT CONFIGURATION
     ========================================================= */
  var DEPK = "askeva.tset.depts.v2";
  var depts = load(DEPK, [
    { id: "d1", name: "Support L1", agents: 2, created: "Oct 22, 2025" },
    { id: "d2", name: "Support L2", agents: 1, created: "Oct 22, 2025" },
    { id: "d3", name: "Development Team", agents: 0, created: "Oct 27, 2025" },
    { id: "d4", name: "Billing", agents: 1, created: "Oct 28, 2025" },
    { id: "d5", name: "Sales", agents: 0, created: "Oct 28, 2025" },
    { id: "d6", name: "Operations", agents: 1, created: "Nov 10, 2025" },
    { id: "d7", name: "Onboarding", agents: 0, created: "Nov 20, 2025" },
    { id: "d8", name: "Quality Assurance", agents: 0, created: "Dec 23, 2025" },
    { id: "d9", name: "Marketing", agents: 0, created: "Dec 25, 2025" },
    { id: "d10", name: "Finance", agents: 0, created: "Jan 2, 2026" },
    { id: "d11", name: "Accounts", agents: 0, created: "Jan 8, 2026" },
    { id: "d12", name: "Catalog", agents: 0, created: "Jan 15, 2026" }
  ]);
  function saveDepts() { store(DEPK, depts); }
  function TKdepts() { return depts; }
  var depPage = 1, DEP_PP = 10;

  S.register({
    id: "department", title: "Department Configuration", sub: "Customize Departments and properties", icon: IC.dept,
    render: function (host) {
      var totalAgents = depts.reduce(function (s, d) { return s + d.agents; }, 0);
      var pages = Math.max(1, Math.ceil(depts.length / DEP_PP)); if (depPage > pages) depPage = pages;
      var start = (depPage - 1) * DEP_PP, slice = depts.slice(start, start + DEP_PP);
      host.innerHTML = '<div class="cfg-card"><div class="dm-hd"><div class="dm-ttl">Department Management ' +
          '<span class="dm-badge blue">' + depts.length + ' departments</span><span class="dm-badge green">' + totalAgents + ' total agents</span></div></div>' +
        '<div class="dm-actions"><button class="cfg-btn ghost sm" id="dmRefresh">' + IC.refresh + 'Refresh</button>' +
          '<button class="cfg-btn primary sm" id="dmAdd">' + IC.plus + 'Add Department</button></div>' +
        '<div class="dm-colhd"><span class="c-nm">Department</span><span class="c-ag">Agents</span><span class="c-ac"></span></div>' +
        '<div class="dm-list">' + slice.map(deptRow).join("") + '</div>' +
        (pages > 1 ? dmPager(pages, start, slice.length) : '') +
        '<div class="dm-note">' + IC.info + 'Departments are used to categorize and assign tickets. Departments with agents assigned cannot be deleted.</div></div>';
      $("#dmRefresh", host).addEventListener("click", function () { S.render(); toast("Refreshed"); });
      $("#dmAdd", host).addEventListener("click", openDeptForm);
      $$(".dm-del:not(.off)", host).forEach(function (b) { b.addEventListener("click", function () {
        var id = b.getAttribute("data-id"), d = depts.filter(function (x) { return x.id === id; })[0];
        TK.showConfirm({ title: "Delete department?", sub: "“" + d.name + "” will be permanently removed.", go: "Delete", onGo: function () { depts = depts.filter(function (x) { return x.id !== id; }); saveDepts(); S.render(); toast("Department deleted"); } });
      }); });
      $$(".dm-pg[data-pg]", host).forEach(function (b) { b.addEventListener("click", function () { var p = +b.getAttribute("data-pg"); if (p < 1 || p > pages || p === depPage) return; depPage = p; S.render(); }); });
    }
  });
  function deptRow(d, i) {
    var locked = d.agents > 0;
    return '<div class="dm-row"><div class="nm">' + esc(d.name) + '<span class="cr">' + esc(d.created) + '</span></div>' +
      '<span class="ag' + (d.agents ? " has" : "") + '">' + d.agents + '</span>' +
      '<button class="dm-del' + (locked ? " off" : "") + '" data-id="' + d.id + '"' + (locked ? " disabled" : "") + '>' + IC.trash + 'Delete</button></div>';
  }
  function dmPager(pages, start, count) {
    var nums = ""; for (var p = 1; p <= pages; p++) nums += '<button class="dm-pg num' + (p === depPage ? " on" : "") + '" data-pg="' + p + '">' + p + '</button>';
    return '<div class="dm-foot"><span class="rng">' + (start + 1) + '-' + (start + count) + ' of ' + depts.length + '</span>' +
      '<div class="dm-pgr"><button class="dm-pg arr" data-pg="' + (depPage - 1) + '"' + (depPage <= 1 ? " disabled" : "") + '>' + IC.chevL + '</button>' + nums +
      '<button class="dm-pg arr" data-pg="' + (depPage + 1) + '"' + (depPage >= pages ? " disabled" : "") + '>' + IC.chevR + '</button></div></div>';
  }
  function openDeptForm() {
    var html = '<div class="ax-grip"></div><div class="ax-sheet-head"><div class="ax-sheet-ttl">Add New Department</div></div>' +
      '<div class="ax-field"><label class="ax-label">Department Name</label><div class="ax-control">' + IC.dept + '<input id="dmName" type="text" maxlength="50" placeholder="e.g., Sales, Support, Tech…"><span class="nf-count" id="dmCount">0 / 50</span></div></div>' +
      '<div class="af-foot"><button class="cfg-btn ghost" id="dmCancel">Cancel</button><button class="cfg-btn primary" id="dmCreate">Add Department</button></div>';
    var s = TK.openSheet(html);
    var inp = $("#dmName", s); setTimeout(function () { try { inp.focus(); } catch (e) {} }, 80);
    inp.addEventListener("input", function () { $("#dmCount", s).textContent = inp.value.length + " / 50"; });
    $("#dmCancel", s).addEventListener("click", TK.closeSheet);
    $("#dmCreate", s).addEventListener("click", function () {
      var nm = (inp.value || "").trim(); if (!nm) { toast("Enter a name"); return; }
      depts.push({ id: "d" + Date.now().toString(36), name: nm, agents: 0, created: fmtToday2() }); saveDepts();
      depPage = Math.ceil(depts.length / DEP_PP); TK.closeSheet(); S.render(); toast("Department added");
    });
  }

  /* =========================================================
     QUICK REPLY
     ========================================================= */
  var QRK = "askeva.tset.qr.v2";
  var qrs = load(QRK, [
    { id: "q1", title: "Greeting", msg: "Hi! Thanks for reaching out to AskEva support. How can we help you today?" },
    { id: "q2", title: "Working on it", msg: "Thanks for your patience \u2014 our team is looking into this and will update you shortly." },
    { id: "q3", title: "Resolved", msg: "Your issue has been resolved. Feel free to reply here if you need anything else!" }
  ]);
  function saveQr() { store(QRK, qrs); }
  /* expose ticketing's OWN quick replies so the ticket reply composer uses these
     (NOT the shared/Leads AskEvaQuickReplies). Shape: {id, title, msg}. */
  TK.quickReplies = function () { return qrs.slice(); };
  S.register({
    id: "quickReply", title: "Quick Reply Configuration", sub: "Set up quick reply templates for faster responses", icon: IC.chat,
    render: function (host) {
      host.innerHTML = '<div class="cfg-card"><div class="qr-hd"><div class="qr-ttl">Quick Reply Configuration <span class="dm-badge blue">' + qrs.length + ' quick replies</span></div>' +
        '<button class="cfg-btn primary sm" id="qrAdd">' + IC.plus + 'Add Quick Reply</button></div>' +
        '<div class="qr-list">' + (qrs.length ? qrs.map(qrRow).join("") : '<div class="ts-empty">No quick replies yet.</div>') + '</div></div>';
      $("#qrAdd", host).addEventListener("click", function () { openQrForm(); });
      $$(".qr-edit", host).forEach(function (b) { b.addEventListener("click", function () { openQrForm(qrs.filter(function (x) { return x.id === b.getAttribute("data-id"); })[0]); }); });
      $$(".qr-del", host).forEach(function (b) { b.addEventListener("click", function () { var id = b.getAttribute("data-id"); TK.showConfirm({ title: "Delete quick reply?", sub: "This template will be removed.", go: "Delete", onGo: function () { qrs = qrs.filter(function (x) { return x.id !== id; }); saveQr(); S.render(); toast("Deleted"); } }); }); });
    }
  });
  function qrRow(q) {
    var clock = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></svg>';
    return '<div class="qr-row"><span class="qr-ic">' + clock + '</span>' +
      '<span class="qr-main"><span class="t">' + esc(q.title) + '</span><span class="m">' + esc(q.msg) + '</span></span>' +
      '<span class="a"><button class="qr-edit" data-id="' + q.id + '" aria-label="Edit">' + IC.edit + '</button><button class="qr-del" data-id="' + q.id + '" aria-label="Delete">' + IC.trash + '</button></span></div>';
  }
  function openQrForm(existing) {
    var html = '<div class="ax-grip"></div><div class="ax-sheet-head"><div class="ax-sheet-ttl">' + (existing ? "Edit Quick Reply" : "Add New Quick Reply") + '</div></div>' +
      '<div class="ax-field"><label class="ax-label">Title<span class="nf-req">*</span></label><div class="ax-control">' + IC.tag + '<input id="qrT" type="text" placeholder="Enter quick reply title" value="' + esc(existing ? existing.title : "") + '"></div></div>' +
      '<div class="ax-field"><label class="ax-label">Message<span class="nf-req">*</span></label><div class="ax-control area"><textarea id="qrM" rows="3" maxlength="1000" placeholder="Enter quick reply message">' + esc(existing ? existing.msg : "") + '</textarea><span class="nf-count" id="qrC">' + (existing ? existing.msg.length : 0) + ' / 1000</span></div></div>' +
      '<div class="af-foot"><button class="cfg-btn ghost" id="qrCancel">Cancel</button><button class="cfg-btn primary" id="qrOk">OK</button></div>';
    var s = TK.openSheet(html);
    var m = $("#qrM", s); m.addEventListener("input", function () { $("#qrC", s).textContent = m.value.length + " / 1000"; });
    $("#qrCancel", s).addEventListener("click", TK.closeSheet);
    $("#qrOk", s).addEventListener("click", function () {
      var t = ($("#qrT", s).value || "").trim(), msg = (m.value || "").trim();
      if (!t) { toast("Enter a title"); return; } if (!msg) { toast("Enter a message"); return; }
      if (existing) { existing.title = t; existing.msg = msg; } else { qrs.push({ id: "q" + Date.now().toString(36), title: t, msg: msg }); }
      saveQr(); TK.closeSheet(); S.render(); toast(existing ? "Updated" : "Quick reply added");
    });
  }

  /* =========================================================
     VIDEO NOTE
     ========================================================= */
  var VNK = "askeva.tset.vn.v2";
  var vns = load(VNK, [
    { id: "v1", title: "Account Setup Walkthrough", desc: "Step-by-step guide to setting up a new account", created: "04/03/2026 1:16 PM" },
    { id: "v2", title: "How to Reset Password", desc: "Quick demo of the password reset flow", created: "09/01/2026 6:55 PM" },
    { id: "v3", title: "Billing & Invoices", desc: "Where to find invoices and manage billing", created: "09/01/2026 6:54 PM" },
    { id: "v4", title: "Connecting WhatsApp", desc: "How to link your WhatsApp Business number", created: "05/01/2026 4:21 PM" }
  ]);
  function saveVn() { store(VNK, vns); }
  /* expose configured video notes so the ticket reply composer can send them */
  TK.videoNotes = function () { return vns.slice(); };
  TK.videoNoteURL = function (id) { return vnURLs[id] || null; };
  S.register({
    id: "videoNote", title: "Video Note Configuration", sub: "Configure video note templates and settings", icon: IC.video,
    render: function (host) {
      host.innerHTML = '<div class="cfg-card"><div class="qr-hd"><div class="qr-ttl">Video Note Configuration <span class="dm-badge blue">' + vns.length + ' video notes</span></div>' +
        '<button class="cfg-btn primary sm" id="vnAdd">' + IC.plus + 'Add Video Note</button></div>' +
        '<div class="vn-list">' + (vns.length ? vns.map(vnRow).join("") : '<div class="ts-empty">No video notes yet.</div>') + '</div></div>';
      $("#vnAdd", host).addEventListener("click", function () { openVnForm(); });
      $$(".vn-play", host).forEach(function (b) { b.addEventListener("click", function () { playVn(vns.filter(function (x) { return x.id === b.getAttribute("data-id"); })[0]); }); });
      $$(".vn-edit", host).forEach(function (b) { b.addEventListener("click", function () { openVnForm(vns.filter(function (x) { return x.id === b.getAttribute("data-id"); })[0]); }); });
      $$(".vn-del", host).forEach(function (b) { b.addEventListener("click", function () { var id = b.getAttribute("data-id"); TK.showConfirm({ title: "Delete video note?", sub: "This note will be removed.", go: "Delete", onGo: function () { vns = vns.filter(function (x) { return x.id !== id; }); saveVn(); S.render(); toast("Deleted"); } }); }); });
    }
  });
  function vnRow(v) {
    return '<div class="vn-row"><div class="m"><div class="t">' + esc(v.title) + '</div><div class="d">' + esc(v.desc) + '</div><div class="c">' + esc(v.created) + '</div></div>' +
      '<span class="a"><button class="vn-play" data-id="' + v.id + '" aria-label="Play">' + IC.play + '</button><button class="vn-edit" data-id="' + v.id + '" aria-label="Edit">' + IC.edit + '</button><button class="vn-del" data-id="' + v.id + '" aria-label="Delete">' + IC.trash + '</button></span></div>';
  }
  var vnURLs = {};            // in-session blob URLs for uploaded videos
  function playVn(v) {
    if (!v) return;
    var url = vnURLs[v.id];
    var head = '<div class="ax-grip"></div><div class="ax-sheet-head"><div><div class="ax-sheet-ttl">' + esc(v.title) + '</div>' +
      (v.desc ? '<div class="ax-sheet-sub">' + esc(v.desc) + '</div>' : '') + '</div></div>';
    var media = url
      ? '<video class="vn-player" controls autoplay playsinline src="' + url + '"></video>'
      : '<div class="vn-placeholder"><span class="ic">' + IC.play + '</span><span class="t">Preview not available</span>' +
        '<span class="s">' + esc(v.fileName || "Original recording") + ' \u00b7 ' + esc(v.created) + '</span></div>';
    TK.openSheet(head + '<div class="vn-playwrap">' + media + '</div>');
  }
  function openVnForm(existing) {
    var html = '<div class="ax-grip"></div><div class="ax-sheet-head"><div class="ax-sheet-ttl">' + (existing ? "Edit Video Note" : "Add New Video Note") + '</div></div>' +
      '<div class="ax-field"><label class="ax-label">Title<span class="nf-req">*</span></label><div class="ax-control">' + IC.tag + '<input id="vnT" type="text" placeholder="Enter video note title" value="' + esc(existing ? existing.title : "") + '"></div></div>' +
      '<div class="ax-field"><label class="ax-label">Description</label><div class="ax-control area"><textarea id="vnD" rows="2" maxlength="500" placeholder="Enter description (optional)">' + esc(existing ? existing.desc : "") + '</textarea><span class="nf-count" id="vnC">' + (existing ? existing.desc.length : 0) + ' / 500</span></div></div>' +
      '<div class="ax-field"><label class="ax-label">Upload Video<span class="nf-req">*</span></label><button class="nf-upload" id="vnUp">' + IC.upload + 'Click to Upload Video</button>' +
        '<div class="vn-formats">Supported formats: MP4, MOV, AVI, WMV, FLV, WebM, MKV (Max 100MB)</div></div>' +
      '<div class="af-foot"><button class="cfg-btn ghost" id="vnCancel">Cancel</button><button class="cfg-btn primary" id="vnOk">OK</button></div>';
    var s = TK.openSheet(html);
    var d = $("#vnD", s); d.addEventListener("input", function () { $("#vnC", s).textContent = d.value.length + " / 500"; });
    var pending = { url: null, name: existing ? existing.fileName : "" };
    var upBtn = $("#vnUp", s);
    if (existing && existing.fileName) upBtn.innerHTML = IC.check + esc(existing.fileName);
    upBtn.addEventListener("click", function () {
      var inp = document.createElement("input"); inp.type = "file";
      inp.accept = "video/mp4,video/quicktime,video/x-msvideo,video/webm,video/*"; inp.style.display = "none";
      document.body.appendChild(inp);
      inp.addEventListener("change", function () {
        var f = inp.files && inp.files[0];
        if (f) {
          if (pending.url) { try { URL.revokeObjectURL(pending.url); } catch (e) {} }
          pending.url = URL.createObjectURL(f); pending.name = f.name;
          upBtn.classList.add("has"); upBtn.innerHTML = IC.check + esc(f.name);
          toast("Selected " + f.name);
        }
        document.body.removeChild(inp);
      });
      inp.click();
    });
    $("#vnCancel", s).addEventListener("click", TK.closeSheet);
    $("#vnOk", s).addEventListener("click", function () {
      var t = ($("#vnT", s).value || "").trim(); if (!t) { toast("Enter a title"); return; }
      if (existing) {
        existing.title = t; existing.desc = d.value.trim();
        if (pending.url) { vnURLs[existing.id] = pending.url; existing.fileName = pending.name; }
      } else {
        var nid = "v" + Date.now().toString(36);
        if (pending.url) vnURLs[nid] = pending.url;
        vns.unshift({ id: nid, title: t, desc: d.value.trim(), created: fmtNow(), fileName: pending.name || "" });
      }
      saveVn(); TK.closeSheet(); S.render(); toast(existing ? "Updated" : "Video note added");
    });
  }
  TK.tsetDepts = TKdepts;
  TK.tsetAddDept = function (name) {
    name = (name || "").trim(); if (!name) return false;
    if (depts.some(function (d) { return (d.name || "").toLowerCase() === name.toLowerCase(); })) return false;
    depts.push({ id: "d" + Date.now().toString(36), name: name, agents: 0, created: fmtToday2() });
    saveDepts(); try { S.render(); } catch (e) {} return true;
  };

  /* =========================================================
     date helpers + icons
     ========================================================= */
  function fmtToday() { var d = new Date(2026, 5, 5); return pad(d.getDate()) + "/" + pad(d.getMonth() + 1) + "/" + d.getFullYear(); }
  function fmtToday2() { var M = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]; var d = new Date(2026, 5, 5); return M[d.getMonth()] + " " + d.getDate() + ", " + d.getFullYear(); }
  function fmtNow() { var d = new Date(2026, 5, 5, 13, 12); var h = d.getHours(), ap = h < 12 ? "AM" : "PM"; h = h % 12 || 12; return pad(d.getDate()) + "/" + pad(d.getMonth() + 1) + "/" + d.getFullYear() + " " + h + ":" + pad(d.getMinutes()) + " " + ap; }
  function pad(n) { return n < 10 ? "0" + n : "" + n; }
})();
