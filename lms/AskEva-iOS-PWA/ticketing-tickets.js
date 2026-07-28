/* =========================================================
   AskEva — Tickets Management (list)
   Mobile translation of the web "Tickets Management":
     · tabs: Open / All / Starred / Spam / Feedbacks
     · search + Export + New Ticket toolbar
     · ticket rows (ID, priority, assignee, customer, mobile,
       status, due date, subject, department, custom field)
     · per-row actions: Update Status / Priority / Star /
       Print / Mark as Spam
     · pagination
   Renders into #txTicketsWrap. Uses window.TK.
   ========================================================= */
(function () {
  "use strict";
  var TK = window.TK; if (!TK) return;
  var $ = TK.$, $$ = TK.$$, esc = TK.esc, toast = TK.toast;
  var wrap = document.getElementById("txTicketsWrap"); if (!wrap) return;

  /* ---- bulk-update styles (selection bar, checkboxes, panel) ---- */
  if (!document.getElementById("tmBulkCss")) {
    var _bst = document.createElement("style"); _bst.id = "tmBulkCss";
    _bst.textContent = [
      ".tm-actchip.on{ background:var(--accent-soft,#EAF9E6); border-color:var(--accent-soft-2,#CDEAC4); color:var(--accent-deep,#177A36); }",
      ".tm-selbar{ display:flex; align-items:center; gap:10px; background:var(--surface,#fff); border:1px solid var(--line,#EEF1EC); border-radius:12px; padding:8px 10px; margin:0 0 12px; box-shadow:var(--shadow-xs,0 1px 2px rgba(0,0,0,.05)); }",
      ".tm-sb-all{ flex:0 0 auto; width:26px; height:26px; border-radius:8px; border:1.5px solid var(--line,#CDEAC4); background:#fff; color:transparent; cursor:pointer; display:grid; place-items:center; padding:0; }",
      ".tm-sb-all svg{ width:15px; height:15px; }",
      ".tm-sb-all.on{ background:linear-gradient(135deg,#3CC23F,#2BA84A); border-color:#2BA84A; color:#fff; }",
      ".tm-selbar .n{ font-size:13px; font-weight:800; color:var(--ink,#15231A); }",
      ".tm-selbar .sp{ flex:1; }",
      ".tm-sb-up{ display:inline-flex; align-items:center; gap:6px; border:none; cursor:pointer; font-family:var(--font-body); font-size:13px; font-weight:800; color:#fff; background:linear-gradient(135deg,#3CC23F,#2BA84A); border-radius:10px; padding:9px 14px; }",
      ".tm-sb-up svg{ width:15px; height:15px; }",
      ".tm-sb-up:disabled{ opacity:.5; cursor:not-allowed; }",
      ".tm-sb-cancel{ border:1px solid var(--line,#EEF1EC); background:#fff; cursor:pointer; font-family:var(--font-body); font-size:13px; font-weight:700; color:var(--ink-2,#4D5D52); border-radius:10px; padding:9px 12px; }",
      ".tm-row.selectable{ cursor:pointer; }",
      ".tm-row.sel{ border-color:#2BA84A; box-shadow:0 0 0 2px rgba(61,200,56,.18); }",
      ".tm-cb{ flex:0 0 auto; width:22px; height:22px; border-radius:7px; border:1.5px solid var(--line,#CDEAC4); background:#fff; color:transparent; display:grid; place-items:center; margin-right:8px; }",
      ".tm-cb svg{ width:13px; height:13px; }",
      ".tm-cb.on{ background:linear-gradient(135deg,#3CC23F,#2BA84A); border-color:#2BA84A; color:#fff; }",
      ".tm-bulkinfo{ background:#E8F2FE; border:1px solid #BBDEFB; border-radius:14px; padding:14px 15px; margin-bottom:16px; }",
      ".tm-bulkinfo .bi-ttl{ font-size:15px; font-weight:800; color:var(--ink,#15231A); letter-spacing:-.01em; }",
      ".tm-bulkinfo .bi-lbl{ font-size:12.5px; font-weight:800; color:var(--ink,#15231A); margin-top:9px; }",
      ".tm-bulkinfo .bi-mobs{ font-size:13px; font-weight:600; color:var(--ink-2,#4D5D52); margin-top:3px; word-break:break-word; line-height:1.5; }",
      ".tm-bulkgrp{ margin-bottom:16px; }",
      ".tm-bulkgrp .bg-hd{ display:flex; align-items:center; gap:7px; font-size:14.5px; font-weight:800; color:var(--ink,#15231A); margin-bottom:10px; letter-spacing:-.01em; }",
      ".tm-bulkgrp .bg-hd svg{ width:16px; height:16px; flex:0 0 auto; color:var(--accent-deep,#177A36); }",
      ".tm-bulkinfo svg{ width:15px; height:15px; }",
      "#txBulk .ax-savebar .ax-btn svg{ width:16px; height:16px; }",
      ".ax-label.sub{ text-transform:none; letter-spacing:0; font-size:12.5px; font-weight:700; color:var(--ink-2,#4D5D52); margin:0 2px 7px; }",
      ".nf-select.disabled{ opacity:.55; pointer-events:none; background:var(--surface-2,#F6F8F5); }"
    ].join("");
    document.head.appendChild(_bst);
  }

  var PAGE = 6;
  var NOW = new Date(2026, 5, 5, 12, 0, 0), MIN = 60000, DAY = 86400000;

  /* dashboard-status vocab (mirrors ticketing-dashboard) */
  var WST = [
    ["assigned", "Assigned", "ok"], ["inprogress", "In Progress", "warn"],
    ["awaiting", "Awaiting Customer Response", "rose"], ["pending", "Pending", "amber"],
    ["completed", "Completed", "ok"], ["reopened", "Reopened", "violet"]
  ];
  var WST_LBL = {}, WST_CLS = {}; WST.forEach(function (s) { WST_LBL[s[0]] = s[1]; WST_CLS[s[0]] = s[2]; });
  /* statuses an agent can SET from the Update Ticket dropdown (only these 3) */
  var WST_SET = [["awaiting", "Awaiting Customer Response"], ["inprogress", "In Progress"], ["completed", "Complete"]];
  var WPRIO = [["critical", "Critical"], ["high", "High"], ["medium", "Medium"], ["low", "Low"]];
  var WPRIO_LBL = {}; WPRIO.forEach(function (p) { WPRIO_LBL[p[0]] = p[1]; });
  /* ---------- static feedback responses (fixed dummy — never changes) ---------- */
  var FEEDBACK = [
    ["25/02/2026, 06:35 PM", "TK008", "919360512179", "dasd", "Good", 5],
    ["18/02/2026, 04:20 PM", "TK005", "917904532349", "madhan", "Good", 5],
    ["08/01/2026, 04:23 PM", "TK390", "917904532349", "Teta", "Good", 5],
    ["08/01/2026, 12:59 PM", "TK383", "919786742563", "Vky", "Good", 5],
    ["06/01/2026, 06:42 PM", "TK373", "919495204766", "Ananthu", "Good", 5],
    ["22/12/2025, 06:55 PM", "TK266", "917904532349", "Test", "Good", 5],
    ["20/12/2025, 12:18 PM", "TK258", "916374095193", "Rajiiiii", "Good", 3],
    ["20/12/2025, 11:52 AM", "TK257", "916374095193", "Saranya", "Good", 5],
    ["16/12/2025, 03:34 PM", "TK239", "919495204766", "Lolll", "Bad", 3],
    ["16/12/2025, 03:30 PM", "TK239", "919495204766", "Thanks", "Bad", 5]
  ];
  function fbStars(n) {
    var s = "";
    for (var i = 1; i <= 5; i++) s += '<svg viewBox="0 0 24 24" class="' + (i <= n ? "on" : "off") + '"><path d="m12 3 2.7 5.4 6 .9-4.3 4.2 1 6L12 16.9 6.6 19.5l1-6L3.3 9.3l6-.9z"/></svg>';
    return '<span class="fb-stars">' + s + '</span><span class="fb-starlbl">(' + n + ' STAR)</span>';
  }
  function feedbackTableHTML() {
    var rows = FEEDBACK.map(function (r, i) {
      return '<tr><td>' + (i + 1) + '</td><td>' + esc(r[0]) + '</td><td class="tid">' + esc(r[1]) + '</td><td>' + esc(r[2]) + '</td><td>' + esc(r[3]) + '</td><td>' + esc(r[4]) + '</td><td class="rt">' + fbStars(r[5]) + '</td><td class="na">N/A</td><td class="na">N/A</td></tr>';
    }).join("");
    return '<div class="fb-card">' +
      '<div class="fb-hd"><div class="fb-ttl">All Feedback Responses</div>' +
        '<div class="fb-tools"><div class="fb-search">' + ICON.search + '<input type="text" placeholder="Search\u2026" readonly></div>' +
          '<button class="fb-daterange" type="button"><span class="ph">Start date</span><span class="ar">\u2192</span><span class="ph">End date</span>' + ICON.clock + '</button></div></div>' +
      '<div class="fb-scroll"><table class="fb-table"><thead><tr><th>S.No</th><th>Responded Date</th><th>Ticket ID</th><th>User Number</th><th>Name</th><th>Service</th><th>Ratings</th><th>Customer_description</th><th>Customer_rating</th></tr></thead><tbody>' + rows + '</tbody></table></div>' +
      '<div class="fb-foot"><span class="fb-total">Total 20 feedback responses</span><span class="fb-pages"><button class="nav" disabled>\u2039</button><button class="on">1</button><button>2</button><button class="nav">\u203a</button><span class="fb-pp">10 / page</span></span></div>' +
    '</div>';
  }
  /* kanban grouping options */
  var KAN_GROUPS = [["status", "Group by Status"], ["priority", "Group by Priority"], ["department", "Group by Department"], ["assignee", "Group by Assignee"]];

  var CF_LABEL = "Reference ID";
  var CF_POOL = ["REF-2041", "REF-3382", "REF-1175", "REF-4490", "REF-2208", "REF-7731", "REF-5560", "REF-9912", "REF-6043", "REF-8124"];
  var MAXDOCS = 3;
  /* custom (non-static) fields configured in Settings → Ticket Form — drive the form live */
  function cfgCustom() { var f = (window.TK && TK.ticketForm) ? TK.ticketForm("ticketing") : []; return (f || []).filter(function (x) { return x && !x.static && x.type !== "document"; }); }
  function firstCf(d) { var cs = cfgCustom(); for (var i = 0; i < cs.length; i++) { var v = d.cfx && d.cfx[cs[i].id]; if (v) return String(v); } return d.cf || ""; }

  /* ---- file helpers ---- */
  function downloadFile(name, content, mime) {
    try {
      var blob = new Blob([content], { type: mime || "text/plain;charset=utf-8" });
      var url = URL.createObjectURL(blob);
      var a = document.createElement("a");
      a.href = url; a.download = name; a.style.display = "none";
      document.body.appendChild(a); a.click();
      setTimeout(function () { document.body.removeChild(a); URL.revokeObjectURL(url); }, 120);
      return true;
    } catch (e) { return false; }
  }
  function csvCell(v) { v = String(v == null ? "" : v); return /[",\n]/.test(v) ? '"' + v.replace(/"/g, '""') + '"' : v; }

  /* one-time migration: add Tickets-Management fields */
  function migrate() {
    var changed = false, i = 0;
    TK.tickets.forEach(function (t) {
      if (t.starred == null) { t.starred = false; changed = true; }
      if (t.spam == null) { t.spam = false; changed = true; }
      if (t.cf == null) { t.cf = CF_POOL[i % CF_POOL.length]; changed = true; }
      if (t.company == null) { var c = TK.custById(t.customer); t.company = c ? c.company : ""; changed = true; }
      if (t.source == null) { t.source = (t.channel || "form").toLowerCase() === "web" ? "form" : (t.channel || "form").toLowerCase(); changed = true; }
      if (t.slaRes == null) { t.slaRes = 3; changed = true; }      // resolution target (min)
      if (t.slaFirst == null) { t.slaFirst = 1; changed = true; }  // first-response target (min)
      // Anchor the SLA clock ONCE, at first load, against the real wall clock.
      // Without this, older/seed tickets had no real start time and only got one
      // stamped the moment you first opened them — so their countdown appeared to
      // "reset" on first view. Stamping here (and persisting) makes every ticket's
      // SLA stable from load onward.
      if (t.slaStartMs == null) { t.slaStartMs = Date.now(); changed = true; }
      // ensure dashboard fields exist (in case dashboard not visited yet)
      if (t.wstatus == null) { t.wstatus = t.status === "resolved" ? "completed" : t.status === "pending" ? "pending" : "assigned"; changed = true; }
      if (t.wpriority == null) { t.wpriority = t.priority === "high" ? "high" : t.priority === "med" ? "medium" : "low"; changed = true; }
      if (t.createdMs == null) { t.createdMs = NOW.getTime() - (t.created || 0) * MIN; changed = true; }
      if (t.dueMs == null) { t.dueMs = t.createdMs + 2 * DAY; changed = true; }
      i++;
    });
    if (changed) TK.save();
  }

  var state = { tab: "open", q: "", page: 1, view: "card", selMode: false, selected: {}, kanGroup: "status" };
  TK.tmState = state;
  var VIEW_LABEL = { table: "Table View", card: "Card View", kanban: "Kanban View" };

  function inTab(t) {
    if (state.tab === "spam") return t.spam;
    if (t.spam) return false;
    if (state.tab === "starred") return t.starred;
    if (state.tab === "feedback") return t.rating > 0;
    if (state.tab === "completed") return t.wstatus === "completed";
    if (state.tab === "open") return t.wstatus !== "completed";
    return true; // all
  }
  function tabCount(tab) {
    var s = state.tab; state.tab = tab;
    var n = TK.tickets.filter(inTab).length; state.tab = s; return n;
  }

  /* =========================================================
     RENDER
     ========================================================= */
  function render() {
    migrate();
    // SLA breach sweep — breached, still-open tickets auto-go Pending and escalate
    // to their department head (no toast here; the detail view announces per-ticket)
    var escChanged = false;
    TK.tickets.forEach(function (t) { if (escalateBreached(t)) escChanged = true; });
    if (escChanged) TK.save();
    if (state.selMode) state.view = "card";
    var q = state.q.trim().toLowerCase();
    var isKanban = state.view === "kanban";
    // The kanban groups by status, so the open/completed status TABS must not
    // filter statuses out (otherwise a card moved to Complete vanishes while on
    // the "Open" tab). Spam/starred/feedback stay as orthogonal scoping.
    function kanbanScope(t) {
      if (state.tab === "spam") return t.spam;
      if (t.spam) return false;
      if (state.tab === "starred") return t.starred;
      if (state.tab === "feedback") return t.rating > 0;
      return true;
    }
    var list = TK.tickets.filter(isKanban ? kanbanScope : inTab).filter(function (t) {
      if (!q) return true;
      var c = TK.custById(t.customer) || {};
      return (t.num + " " + t.subject + " " + (c.name || "") + " " + (t.mobile || "") + " " + t.department + " " + t.cf).toLowerCase().indexOf(q) > -1;
    }).sort(function (a, b) { return b.createdMs - a.createdMs; });

    var pages = Math.max(1, Math.ceil(list.length / PAGE));
    if (state.page > pages) state.page = pages;
    var start = (state.page - 1) * PAGE, slice = list.slice(start, start + PAGE);

    var TABS = [["open", "Open Tickets"], ["all", "All Tickets"], ["completed", "Completed"], ["starred", "Starred"], ["spam", "Spam"], ["feedback", "Feedbacks"]];
    var tabsHTML = TABS.map(function (o) {
      var cnt = o[0] === "feedback" ? null : tabCount(o[0]);
      return '<button class="tm-tab' + (state.tab === o[0] ? " on" : "") + '" data-t="' + o[0] + '">' + o[1] +
        (cnt != null ? ' <span class="c">(' + cnt + ')</span>' : '') + '</button>';
    }).join("");

    if (state.tab === "feedback") {
      wrap.innerHTML = '<div class="tm-tabs" id="tmTabs">' + tabsHTML + '</div>' + feedbackTableHTML();
      $$("#tmTabs .tm-tab", wrap).forEach(function (b) { b.addEventListener("click", function () { state.tab = b.getAttribute("data-t"); state.page = 1; render(); }); });
      (function () { var strip = $("#tmTabs", wrap), on = strip && strip.querySelector(".tm-tab.on"); if (strip && on) { strip.scrollLeft = Math.max(0, on.offsetLeft - 24); } })();
      return;
    }

    var rowsHTML;
    // preserve the kanban's horizontal scroll so a re-render (e.g. after a drop)
    // doesn't snap the board back to the first column
    var _kanSL = (function () { var k = wrap.querySelector(".tm-kanwrap"); return k ? k.scrollLeft : 0; })();
    if (!list.length) rowsHTML = emptyHTML(q);
    else if (state.view === "table") rowsHTML = renderTable(slice, start);
    else if (isKanban) rowsHTML = renderKanban(list);
    else rowsHTML = '<div class="tm-rows">' + slice.map(function (t, i) { return rowCard(t, start + i + 1); }).join("") + '</div>';

    var viewMenu = ["table", "card", "kanban"].map(function (v) {
      return '<button class="tm-viewopt' + (state.view === v ? " on" : "") + '" data-v="' + v + '">' + (state.view === v ? ICON.check : '<span class="sp"></span>') + VIEW_LABEL[v] + '</button>';
    }).join("");

    wrap.innerHTML =
      '<div class="tm-tabs" id="tmTabs">' + tabsHTML + '</div>' +
      '<div class="tm-toolbar">' +
        '<div class="tm-search">' + ICON.search + '<input id="tmQ" type="text" placeholder="Search…" value="' + esc(state.q) + '" autocomplete="off">' +
          (q ? '<button class="clr" id="tmClr">' + ICON.x + '</button>' : '') + '</div>' +
        '<button class="tm-new" id="tmNew">' + ICON.plus + 'New</button>' +
      '</div>' +
      '<div class="tm-actions">' +
        '<div class="tm-viewdd"><button class="tm-actchip view" id="tmView">' + ICON.view + '<span>' + VIEW_LABEL[state.view] + '</span>' + ICON.chevD + '</button>' +
          '<div class="tm-viewmenu" id="tmViewMenu" hidden>' + viewMenu + '</div></div>' +
        '<button class="tm-actchip" id="tmExport">' + ICON.export + 'Export</button>' +
        '<button class="tm-actchip' + (state.selMode ? ' on' : '') + '" id="tmBulk">' + ICON.edit + 'Select</button>' +
      '</div>' +
      (state.selMode ? selbar(list) : '') +
      rowsHTML +
      (isKanban ? "" : foot(list.length, start, slice.length, pages));

    /* wire */
    $$("#tmTabs .tm-tab", wrap).forEach(function (b) { b.addEventListener("click", function () { state.tab = b.getAttribute("data-t"); state.page = 1; render(); }); });
    // keep the active tab visible — re-rendering rebuilds the strip and would
    // otherwise snap its horizontal scroll back to the start (looking like it
    // reverted to "Open Tickets" whenever a tab further right is selected)
    (function () {
      var strip = $("#tmTabs", wrap), on = strip && strip.querySelector(".tm-tab.on");
      if (strip && on) { var pad = 24; strip.scrollLeft = Math.max(0, on.offsetLeft - pad); }
    })();
    var qi = $("#tmQ", wrap); if (qi) qi.addEventListener("input", function (e) {
      state.q = e.target.value; state.page = 1; var c = e.target.selectionStart; render();
      var n = $("#tmQ", wrap); if (n) { n.focus(); try { n.setSelectionRange(c, c); } catch (x) {} }
    });
    var clr = $("#tmClr", wrap); if (clr) clr.addEventListener("click", function () { state.q = ""; state.page = 1; render(); });
    $("#tmExport", wrap).addEventListener("click", function () { exportTickets(list); });
    $("#tmNew", wrap).addEventListener("click", openForm);
    var vbtn = $("#tmView", wrap), vmenu = $("#tmViewMenu", wrap);
    if (vbtn) vbtn.addEventListener("click", function (e) { e.stopPropagation(); if (vmenu) vmenu.hidden = !vmenu.hidden; });
    $$(".tm-viewopt", wrap).forEach(function (b) { b.addEventListener("click", function () { state.view = b.getAttribute("data-v"); state.page = 1; render(); }); });
    var bulkBtn = $("#tmBulk", wrap); if (bulkBtn) bulkBtn.addEventListener("click", function () { toggleSel(!state.selMode); });
    if (state.selMode) {
      var sAll = $("#tmSelAll", wrap); if (sAll) sAll.addEventListener("click", function () { toggleAll(list); });
      var bOpen = $("#tmBulkOpen", wrap); if (bOpen) bOpen.addEventListener("click", function () { var ids = selectedIds(); if (ids.length) openBulk(ids); });
      var sCancel = $("#tmSelCancel", wrap); if (sCancel) sCancel.addEventListener("click", function () { toggleSel(false); });
    }
    $$(".tm-row", wrap).forEach(function (el) {
      el.addEventListener("click", function (e) {
        if (wrap.__kanSuppress) { wrap.__kanSuppress = false; return; }
        if (e.target.closest(".tm-act")) return;
        if (e.target.closest(".tm-docview")) return;
        // tapping the footer checkbox selects the card directly — no need to enter
        // bulk-update mode first, and it must not open the ticket detail
        if (e.target.closest(".tm-cb")) {
          var cid = el.getAttribute("data-id");
          if (!state.selMode) { state.selMode = true; state.selected = {}; }
          state.selected[cid] = !state.selected[cid];
          render();
          return;
        }
        if (state.selMode) {
          var id = el.getAttribute("data-id");
          state.selected[id] = !state.selected[id];
          el.classList.toggle("sel", !!state.selected[id]);
          var cb = el.querySelector(".tm-cb"); if (cb) cb.classList.toggle("on", !!state.selected[id]);
          updateSelbar(list); return;
        }
        if (window.TKDetail) window.TKDetail.open(el.getAttribute("data-id")); else TK.openTicket(el.getAttribute("data-id"));
      });
    });
    $$(".tm-act", wrap).forEach(function (b) { b.addEventListener("click", function (e) { e.stopPropagation(); openActions(b.getAttribute("data-id")); }); });
    $$(".tm-docview", wrap).forEach(function (b) { b.addEventListener("click", function (e) { e.stopPropagation(); openDocViewer(TK.getT(b.getAttribute("data-docview"))); }); });
    $$(".tm-pg[data-pg]", wrap).forEach(function (b) { b.addEventListener("click", function () {
      var p = +b.getAttribute("data-pg"); if (p < 1 || p > pages || p === state.page) return; state.page = p; render();
    }); });
    if (state.view === "table") wireTableDnd(wrap);
    if (isKanban) {
      wireKanbanDnd(wrap);
      var kg = $("#tmKanGroup", wrap);
      if (kg) kg.addEventListener("change", function () { state.kanGroup = this.value; render(); });
      var _nkw = wrap.querySelector(".tm-kanwrap"); if (_nkw && _kanSL) _nkw.scrollLeft = _kanSL;
    }
  }

  /* ---- KANBAN drag-and-drop with status-movement rules ----
     • Any non-completed status can move to any status (incl. Complete).
     • A Completed ticket can ONLY move to Reopened — never to any other status. */
  function canKanMove(src, tgt) {
    if (!src || !tgt || src === tgt) return false;
    if (src === "completed") return tgt === "reopened";
    return true;
  }
  function applyKanStatus(t, v) {
    if (!t || t.wstatus === v) return;
    var _prev = WST_LBL[t.wstatus] || t.wstatus;
    t.wstatus = v;
    t.status = v === "completed" ? "resolved" : (v === "pending" || v === "awaiting") ? "pending" : "open";
    if (v === "completed" && !t.completedMs) t.completedMs = NOW.getTime();
    if (v === "reopened") { t.reopenedMs = NOW.getTime(); t.completedMs = null; t.escalated = false; t.slaStartMs = Date.now(); }
    TK.save(); render();
    logTicketActivity(t, v === "completed" ? "Ticket closed \u00b7 " + displayId(t) : "Ticket status changed", { Field: "Status", oldVal: _prev, newVal: WST_LBL[v] || v });
    toast("Moved to " + WST_LBL[v]);
    if (TK.notifyCustomer) TK.notifyCustomer(t, v);
  }
  function applyKanMove(t, g, v) {
    if (g === "status") { applyKanStatus(t, v); return; }
    if (kanGroupVal(t, g) === v) return;
    var meta = null;
    if (g === "priority") { var _op = WPRIO_LBL[t.wpriority] || t.wpriority; t.wpriority = v; t.priority = (v === "critical" || v === "high") ? "high" : v === "medium" ? "med" : "low"; meta = { Field: "Priority", oldVal: _op, newVal: WPRIO_LBL[v] || v }; toast("Priority: " + (WPRIO_LBL[v] || v)); }
    else if (g === "department") { var _od = t.department || "\u2014"; t.department = v; meta = { Field: "Department", oldVal: _od, newVal: v || "\u2014" }; toast("Department: " + (v || "\u2014")); }
    else if (g === "assignee") { var _oa = TK.agentById(t.assignee); t.assignee = v; var ag = TK.agentById(v); meta = { Field: "Agent", oldVal: (_oa ? _oa.name : (t.assignee === "unassigned" ? "Unassigned" : t.assignee || "\u2014")), newVal: (ag ? ag.name : (v === "unassigned" ? "Unassigned" : v)) }; toast("Assigned to " + (ag ? ag.name : (v === "unassigned" ? "Unassigned" : v))); }
    TK.save(); render();
    logTicketActivity(t, "Ticket " + g + " changed", meta);
  }
  function wireKanbanDnd(wrap) {
    var g = state.kanGroup || "status";
    function clearHints() { $$(".tm-kcol", wrap).forEach(function (c) { c.classList.remove("kdrop-ok", "kdrop-no", "kdrop-over"); }); }
    function canMove(srcId, srcVal, tgtV) {
      if (tgtV === srcVal) return false;
      if (g === "status") { var t = TK.getT(srcId); return canKanMove(t ? t.wstatus : srcVal, tgtV); }
      return true;
    }
    function scaleHost() {
      var h = document.getElementById("screen") || document.querySelector(".device-screen") || wrap;
      var rect = h.getBoundingClientRect();
      var sc = h.offsetWidth ? (rect.width / h.offsetWidth) : 1;
      return { el: h, rect: rect, scale: sc || 1 };
    }
    /* Pointer-based drag — native HTML5 DnD breaks inside the CSS-scaled device
       frame (ghost renders full-size, drops don't register) and has no touch
       support. Includes edge auto-scroll so off-screen columns (e.g. Complete)
       are reachable, since the column row scrolls horizontally. */
    var drag = null, rafId = 0;
    function colUnder(x, y) {
      var gh = drag && drag.ghost, prev = gh ? gh.style.visibility : "";
      if (gh) gh.style.visibility = "hidden";
      var el = document.elementFromPoint(x, y);
      if (gh) gh.style.visibility = prev;
      return el && el.closest ? el.closest(".tm-kcol") : null;
    }
    function evaluate() {
      if (!drag || !drag.started) return;
      drag.ghost.style.left = ((drag.lastX - drag.rect.left) / drag.scale - drag.offX) + "px";
      drag.ghost.style.top = ((drag.lastY - drag.rect.top) / drag.scale - drag.offY) + "px";
      var col = colUnder(drag.lastX, drag.lastY), v = col && col.getAttribute("data-gv");
      var ok = !!col && canMove(drag.id, drag.srcVal, v);
      $$(".tm-kcol", wrap).forEach(function (c) { c.classList.toggle("kdrop-over", c === col && ok); });
      drag.overCol = ok ? col : null;
    }
    function autoScroll() {
      if (drag && drag.started) {
        var kw = wrap.querySelector(".tm-kanwrap");
        if (kw) {
          var kr = kw.getBoundingClientRect(), edge = 54, sp = 0;
          if (drag.lastX > kr.right - edge) sp = 16;
          else if (drag.lastX < kr.left + edge) sp = -16;
          if (sp) {
            var before = kw.scrollLeft; kw.scrollLeft += sp;
            if (kw.scrollLeft !== before) evaluate();
          }
        }
        rafId = requestAnimationFrame(autoScroll);
      }
    }
    function teardown() {
      window.removeEventListener("pointermove", onMove);
      window.removeEventListener("pointerup", onUp);
      window.removeEventListener("pointercancel", onCancel);
      if (rafId) { cancelAnimationFrame(rafId); rafId = 0; }
    }
    function onMove(e) {
      if (!drag) return;
      if (!drag.started) {
        if (Math.abs(e.clientX - drag.sx) < 6 && Math.abs(e.clientY - drag.sy) < 6) return;
        drag.started = true;
        var t = TK.getT(drag.id); drag.srcVal = t ? kanGroupVal(t, g) : null;
        drag.card.classList.add("kdragging");
        var host = scaleHost(); drag.host = host.el; drag.rect = host.rect; drag.scale = host.scale;
        var gh = drag.card.cloneNode(true);
        gh.className = drag.card.className.replace("kdragging", "").trim() + " kc-ghost";
        gh.style.cssText = "position:absolute;margin:0;z-index:9999;pointer-events:none;width:" + drag.card.offsetWidth + "px;left:0;top:0;";
        drag.host.appendChild(gh); drag.ghost = gh;
        $$(".tm-kcol", wrap).forEach(function (col) {
          var v = col.getAttribute("data-gv");
          if (v === drag.srcVal) return;
          col.classList.add(canMove(drag.id, drag.srcVal, v) ? "kdrop-ok" : "kdrop-no");
        });
        try { drag.card.setPointerCapture(e.pointerId); } catch (_) {}
        rafId = requestAnimationFrame(autoScroll);
      }
      e.preventDefault();
      drag.lastX = e.clientX; drag.lastY = e.clientY;
      evaluate();
    }
    function onUp() {
      if (!drag) return; var d = drag; drag = null; teardown();
      if (!d.started) return;
      if (d.ghost) d.ghost.remove();
      d.card.classList.remove("kdragging"); clearHints();
      wrap.__kanSuppress = true; setTimeout(function () { wrap.__kanSuppress = false; }, 60);
      if (d.overCol) {
        var t = TK.getT(d.id); if (!t) return;
        var v = d.overCol.getAttribute("data-gv"), cur = kanGroupVal(t, g);
        if (cur !== v) {
          if (g === "status" && !canKanMove(t.wstatus, v)) {
            toast(t.wstatus === "completed" ? "Completed tickets can only move to Reopened" : "That move isn't allowed");
            return;
          }
          applyKanMove(t, g, v);   // calls render() → re-wires the board
        }
      }
    }
    function onCancel() {
      if (!drag) return; var d = drag; drag = null; teardown();
      if (d.ghost) d.ghost.remove();
      d.card.classList.remove("kdragging"); clearHints();
    }
    $$(".tm-kcard", wrap).forEach(function (card) {
      card.addEventListener("pointerdown", function (e) {
        if (e.pointerType === "mouse" && e.button !== 0) return;
        if (e.target.closest(".tm-act") || e.target.closest(".tm-cb")) return;
        var rect = card.getBoundingClientRect();
        drag = { id: card.getAttribute("data-id"), card: card, started: false, pid: e.pointerId,
          sx: e.clientX, sy: e.clientY, lastX: e.clientX, lastY: e.clientY,
          offX: e.clientX - rect.left, offY: e.clientY - rect.top, ghost: null, overCol: null, srcVal: null };
        window.addEventListener("pointermove", onMove, { passive: false });
        window.addEventListener("pointerup", onUp);
        window.addEventListener("pointercancel", onCancel);
      });
    });
  }

  function emptyHTML(q) {
    return '<div class="tm-empty"><div class="ic">' + ICON.inbox + '</div><div class="t">No tickets here</div>' +
      '<div class="s">' + (q ? "Try a different search." : state.tab === "spam" ? "No spam tickets." : "Tap New Ticket to create one.") + '</div></div>';
  }

  /* ---- TABLE view (horizontal scroll) ---- */
  function docList(t) { return (t.docs && t.docs.length) ? t.docs : (t.doc ? [{ name: t.doc, data: t.docData, type: t.docType, size: t.docSize }] : []); }
  function docCell(t) {
    var n = docList(t).length;
    if (!n) return '<span class="tm-nodoc">\u2014</span>';
    return '<button class="tm-docview" type="button" data-docview="' + t.id + '">' + ICON.eye + 'Preview (' + n + ')</button>';
  }
  function openDocViewer(t) {
    if (!t) return;
    var docs = docList(t); if (!docs.length) return;
    function isImg(d) { return /^image\//.test(d.type || "") || /\.(png|jpe?g|gif|webp|bmp|svg)$/i.test(d.name || ""); }
    var imgs = docs.filter(isImg);
    var preview = imgs.length
      ? '<div class="dv-preview">' + imgs.map(function (d) {
          return '<div class="dv-img"><img src="' + (d.data || "") + '" alt="' + esc(d.name) + '">' +
            (d.data ? '<a class="dv-dl" href="' + d.data + '" download="' + esc(d.name) + '" aria-label="Download">' + ICON.download + '</a>' : '') + '</div>';
        }).join("") + '</div>'
      : '<div class="dv-noimg">' + ICON.file + '<span>No image preview available</span></div>';
    var files = docs.map(function (d) {
      var pdf = /pdf/i.test(d.type || "") || /\.pdf$/i.test(d.name || "");
      return '<div class="dv-file"><span class="ic ' + (pdf ? "pdf" : "img") + '">' + ICON.file + '</span>' +
        '<div class="meta"><div class="nm">' + esc(d.name) + '</div><div class="ty">' + (pdf ? "PDF Document" : "Image") + '</div></div>' +
        '<div class="acts">' +
          (d.data ? '<a class="b" href="' + d.data + '" target="_blank" rel="noopener" aria-label="Open">' + ICON.link + '</a>' +
                    '<a class="b" href="' + d.data + '" download="' + esc(d.name) + '" aria-label="Download">' + ICON.download + '</a>' : '') +
        '</div></div>';
    }).join("");
    var ov = document.createElement("div"); ov.className = "dv-ov";
    ov.innerHTML = '<div class="dv-modal"><div class="dv-head"><span class="t">Attached Documents</span>' +
      '<button class="dv-x" type="button" aria-label="Close">' + ICON.x + '</button></div>' +
      '<div class="dv-body">' + preview + '<div class="dv-flbl">FILES</div>' + files + '</div></div>';
    var host = (formEl && formEl.parentNode) || (wrap && wrap.parentNode) || document.body;
    host.appendChild(ov);
    requestAnimationFrame(function () { ov.classList.add("show"); });
    function close() { ov.classList.remove("show"); setTimeout(function () { if (ov.parentNode) ov.remove(); }, 200); }
    ov.addEventListener("click", function (e) { if (e.target === ov) close(); });
    ov.querySelector(".dv-x").addEventListener("click", close);
  }
  /* ---- TABLE columns (drag-reorderable, order persisted) ---- */
  var TCOLS = {
    id:        { label: "Ticket ID", td: "", cell: function (t) { return '<div class="tt-id">' + esc(displayId(t)) + '</div><span class="tm-prio ' + (t.wpriority || "low") + '">' + (WPRIO_LBL[t.wpriority || "low"] || "Low") + '</span>'; } },
    assigned:  { label: "Assigned", td: "", cell: function (t) { var ag = t.assignee && t.assignee !== "unassigned" ? TK.agentById(t.assignee) : null; return esc(ag ? ag.name : "Unassigned"); } },
    customer:  { label: "Customer", td: "", cell: function (t) { return esc((TK.custById(t.customer) || { name: "." }).name); } },
    mobile:    { label: "Mobile", td: "", cell: function (t) { return esc((t.cc || "+91") + " " + (t.mobile || "").replace(/\D/g, "")); } },
    status:    { label: "Status", td: "", cell: function (t) { return '<span class="tm-status ' + (WST_CLS[t.wstatus] || "amber") + '">' + esc(WST_LBL[t.wstatus] || "Pending") + '</span>'; } },
    due:       { label: "Due Date", td: "nowrap", cell: function (t) { return fmtDue(t.dueMs); } },
    subject:   { label: "Subject", td: "", cell: function (t) { return esc(t.subject); } },
    department:{ label: "Department", td: "", cell: function (t) { return esc(t.department); } },
    document:  { label: "Document", td: "", cell: function (t) { return docCell(t); } }
  };
  var DEFAULT_COLS = ["id", "assigned", "customer", "mobile", "status", "due", "subject", "department", "document"];
  var COLORD_KEY = "askeva.tk.colorder.v2";
  var colOrder = (function () {
    try { var s = JSON.parse(localStorage.getItem(COLORD_KEY)); if (s && s.length) {
      var clean = s.filter(function (k) { return TCOLS[k]; });
      DEFAULT_COLS.forEach(function (k) { if (clean.indexOf(k) < 0) clean.push(k); });   // append any new cols
      return clean;
    } } catch (e) {}
    return DEFAULT_COLS.slice();
  })();
  function saveColOrder() { try { localStorage.setItem(COLORD_KEY, JSON.stringify(colOrder)); } catch (e) {} }

  function renderTable(slice, start) {
    var rows = slice.map(function (t, i) {
      var tds = colOrder.map(function (k) { var col = TCOLS[k]; return '<td' + (col.td ? ' class="' + col.td + '"' : '') + '>' + col.cell(t) + '</td>'; }).join("");
      return '<tr class="tm-row" data-id="' + t.id + '">' +
        '<td>' + (start + i + 1) + '</td>' + tds +
        '<td><button class="tm-act" data-id="' + t.id + '" aria-label="Actions">' + ICON.dots + '</button></td>' +
      '</tr>';
    }).join("");
    var ths = colOrder.map(function (k) {
      return '<th class="tm-colh" draggable="true" data-col="' + k + '"><span class="tm-colgrip">' + ICON.drag + '</span>' + esc(TCOLS[k].label) + '</th>';
    }).join("");
    return '<div class="tm-colhint">Drag a column header to reorder</div>' +
      '<div class="tm-tablewrap"><table class="tm-table"><thead><tr>' +
      '<th>S.No</th>' + ths + '<th></th>' +
      '</tr></thead><tbody>' + rows + '</tbody></table></div>';
  }
  function wireTableDnd(wrap) {
    var ths = $$(".tm-colh", wrap); if (!ths.length) return;
    var dragKey = null;
    ths.forEach(function (th) {
      th.addEventListener("dragstart", function (e) { dragKey = th.getAttribute("data-col"); th.classList.add("dragging"); try { e.dataTransfer.effectAllowed = "move"; e.dataTransfer.setData("text/plain", dragKey); } catch (x) {} });
      th.addEventListener("dragend", function () { th.classList.remove("dragging"); dragKey = null; $$(".tm-colh", wrap).forEach(function (x) { x.classList.remove("dragover"); }); });
      th.addEventListener("dragover", function (e) { e.preventDefault(); if (dragKey && th.getAttribute("data-col") !== dragKey) th.classList.add("dragover"); });
      th.addEventListener("dragleave", function () { th.classList.remove("dragover"); });
      th.addEventListener("drop", function (e) {
        e.preventDefault(); th.classList.remove("dragover");
        var from = dragKey || (e.dataTransfer && e.dataTransfer.getData("text/plain"));
        var to = th.getAttribute("data-col");
        if (!from || from === to) return;
        var fi = colOrder.indexOf(from), ti = colOrder.indexOf(to);
        if (fi < 0 || ti < 0) return;
        colOrder.splice(fi, 1); colOrder.splice(colOrder.indexOf(to) + (ti > fi ? 1 : 0), 0, from);
        saveColOrder();
        // preserve horizontal scroll so reordering a right-side column doesn't
        // snap the table back to the leftmost columns on re-render
        var tw = wrap.querySelector(".tm-tablewrap"); var sl = tw ? tw.scrollLeft : 0;
        render();
        var tw2 = wrap.querySelector(".tm-tablewrap"); if (tw2) tw2.scrollLeft = sl;
      });
    });
  }

  /* ---- KANBAN view (grouped by status / priority / department / assignee) ---- */
  function kanGroupVal(t, g) {
    if (g === "priority") return t.wpriority || "low";
    if (g === "department") return t.department || "";
    if (g === "assignee") return t.assignee || "unassigned";
    return t.wstatus || "pending";
  }
  function kanColumns(list, g) {
    var PAL = ["ok", "warn", "amber", "rose", "violet", "teal"];
    if (g === "status") return WST.map(function (s) { return { key: s[0], label: s[1], cls: s[2] }; });
    if (g === "priority") {
      var PCLS = { critical: "rose", high: "amber", medium: "warn", low: "ok" };
      return WPRIO.map(function (s) { return { key: s[0], label: s[1], cls: PCLS[s[0]] || "" }; });
    }
    var seen = {}, cols = [], ci = 0;
    function add(key, label) { if (key in seen) return; seen[key] = 1; cols.push({ key: key, label: label, cls: PAL[ci++ % PAL.length] }); }
    if (g === "department") {
      // columns come from the configured ticket departments (Settings → Department Config)
      deptNames().forEach(function (d) { add(d, d); });
      // include any department present on tickets but not (or no longer) configured
      list.forEach(function (t) { var k = kanGroupVal(t, g); if (k) add(k, k); });
      if (!cols.length) add("", "\u2014");
      return cols;
    }
    // assignee → columns from the agents present in the data
    list.forEach(function (t) {
      var k = kanGroupVal(t, g);
      var label = (!k || k === "unassigned") ? "Unassigned" : ((TK.agentById(k) || {}).name || k);
      add(k, label);
    });
    if (!cols.length) add("unassigned", "Unassigned");
    return cols;
  }
  function renderKanban(list) {
    var g = state.kanGroup || "status";
    var cols = kanColumns(list, g);
    var byKey = {}, order = [];
    cols.forEach(function (c) { byKey[c.key] = { key: c.key, label: c.label, cls: c.cls, items: [] }; order.push(c.key); });
    list.forEach(function (t) { var k = kanGroupVal(t, g); (byKey[k] || byKey[order[0]]).items.push(t); });
    var dd = '<div class="tm-kgroup"><select id="tmKanGroup">' +
      KAN_GROUPS.map(function (gp) { return '<option value="' + gp[0] + '"' + (gp[0] === g ? " selected" : "") + '>' + gp[1] + '</option>'; }).join("") + '</select></div>';
    return dd + '<div class="tm-kanwrap">' + order.map(function (k) {
      var col = byKey[k];
      return '<div class="tm-kcol" data-gv="' + esc(String(k)) + '"><div class="tm-khd ' + (col.cls || "") + '"><span class="kt">' + esc(col.label) + '</span><span class="kc">' + col.items.length + '</span></div>' +
        '<div class="tm-kbody">' + (col.items.length ? col.items.map(function (t) { return kanCard(t, g); }).join("") : '<div class="tm-kempty">No tickets</div>') + '</div></div>';
    }).join("") + '</div>';
  }
  function kanCard(t, g) {
    var c = TK.custById(t.customer) || { name: ".", initials: "?", color: "#999" };
    var stLbl = WST_LBL[t.wstatus] || "Pending", stCls = WST_CLS[t.wstatus] || "amber", prio = t.wpriority || "low";
    var init = (c.initials || (c.name || "?").charAt(0) || "?").toUpperCase();
    return '<div class="tm-kcard tm-row" data-id="' + t.id + '" draggable="false">' +
      '<div class="kc-top"><span class="kc-id">' + esc(displayId(t)) + '</span>' +
        '<button class="tm-act" data-id="' + t.id + '" aria-label="Actions">' + ICON.dots + '</button></div>' +
      '<div class="kc-cust"><span class="av" style="background:' + (c.color || "#999") + '">' + esc(init) + '</span><span class="nm">' + esc(c.name) + '</span></div>' +
      '<div class="kc-tags"><span class="tm-status ' + stCls + '">' + esc(stLbl) + '</span><span class="tm-prio ' + prio + '">' + (WPRIO_LBL[prio] || "Low") + '</span></div>' +
      '<div class="kc-date">' + ICON.clock + '<span>' + fmtDue(t.dueMs).split(" ")[0] + '</span></div>' +
    '</div>';
  }

  function rowCard(t, sn) {
    var c = TK.custById(t.customer) || { name: ".", initials: "?", color: "#999" };
    var ag = t.assignee && t.assignee !== "unassigned" ? TK.agentById(t.assignee) : null;
    var stCls = WST_CLS[t.wstatus] || "amber", stLbl = WST_LBL[t.wstatus] || "Pending";
    var prio = t.wpriority || "low";
    var seld = state.selMode && !!state.selected[t.id];
    var mobile = (t.mobile || "").replace(/\D/g, "");
    function kv(k, v) { return '<div class="tc-kv"><span class="k">' + k + '</span><span class="v">' + v + '</span></div>'; }
    return '<div class="tm-row tm-card2' + (state.selMode ? ' selectable' : '') + (seld ? ' sel' : '') + '" data-id="' + t.id + '">' +
      '<div class="tc-hd"><span class="tc-id"><span class="lbl">Ticket ID:</span> ' + esc(displayId(t)) + '</span>' +
        (t.starred ? '<span class="tm-star">' + ICON.starF + '</span>' : '') +
        '<button class="tm-act" data-id="' + t.id + '" aria-label="Actions">' + ICON.dots + '</button></div>' +
      '<div class="tc-body">' +
        kv("Customer Name", esc(c.name)) +
        (mobile ? kv("Mobile", esc((t.cc || "+91") + " " + mobile)) : "") +
        kv("Agent", esc(ag ? ag.name : "Unassigned")) +
        kv("Department", esc(t.department)) +
        kv("Subject", '<span class="subjv">' + esc(t.subject) + '</span>') +
        '<div class="tc-kv"><span class="k">Priority</span><span class="tm-prio ' + prio + '">' + (WPRIO_LBL[prio] || "Low") + '</span></div>' +
        '<div class="tc-kv"><span class="k">Status</span><span class="tm-status ' + stCls + '">' + esc(stLbl) + '</span></div>' +
        kv("Created", esc(fmtDue(t.createdMs))) +
      '</div>' +
      '<div class="tc-foot">' +
        '<span class="tm-cb' + (seld ? ' on' : '') + '" aria-hidden="true">' + (seld ? ICON.check : "") + '</span>' +
        '<span class="tc-due' + (t.dueMs < NOW.getTime() && t.wstatus !== "completed" ? " over" : "") + '">' + ICON.clock + 'Due ' + fmtDue(t.dueMs) + '</span>' +
      '</div>' +
    '</div>';
  }
  function displayId(t) { return (t.num || "").replace(/^TK-?/, "TK"); }

  function foot(total, start, count, pages) {
    if (!total) return "";
    var nums = "";
    for (var p = 1; p <= pages; p++) nums += '<button class="tm-pg num' + (p === state.page ? " on" : "") + '" data-pg="' + p + '">' + p + '</button>';
    return '<div class="tm-foot"><span class="rng">Showing ' + (start + 1) + '–' + (start + count) + ' of ' + total + ' tickets</span>' +
      '<div class="tm-pager"><button class="tm-pg arr" data-pg="' + (state.page - 1) + '"' + (state.page <= 1 ? " disabled" : "") + '>' + ICON.chevL + '</button>' +
      nums + '<button class="tm-pg arr" data-pg="' + (state.page + 1) + '"' + (state.page >= pages ? " disabled" : "") + '>' + ICON.chevR + '</button></div></div>';
  }

  function fmtDue(ms) { var d = new Date(ms); return pad(d.getDate()) + "/" + pad(d.getMonth() + 1) + "/" + d.getFullYear() + " " + pad(d.getHours()) + ":" + pad(d.getMinutes()); }
  function pad(n) { return n < 10 ? "0" + n : "" + n; }

  /* =========================================================
     ROW ACTIONS
     ========================================================= */
  function openActions(id) {
    var t = TK.getT(id); if (!t) return;
    var html = '<div class="ax-grip"></div><div class="ax-sheet-head"><div class="ax-sheet-ttl">Ticket actions</div>' +
      '<div class="ax-sheet-sub">' + esc(displayId(t)) + ' · ' + esc(t.subject) + '</div></div>' +
      '<div class="tm-actlist">' +
        actBtn("edit", ICON.edit, "Edit Ticket", "") +
        actBtn("status", ICON.check, "Update Status", WST_LBL[t.wstatus]) +
        actBtn("priority", ICON.flag, "Update Priority", WPRIO_LBL[t.wpriority]) +
        actBtn("star", t.starred ? ICON.starF : ICON.star, t.starred ? "Unstar Ticket" : "Star Ticket", "") +
        actBtn("print", ICON.print, "Print Ticket", "") +
        actBtn("spam", ICON.alert, t.spam ? "Not Spam" : "Mark as Spam", "", "danger") +
      '</div>';
    var s = TK.openSheet(html);
    $$("[data-a]", s).forEach(function (b) {
      b.addEventListener("click", function () { TK.closeSheet(); doAction(b.getAttribute("data-a"), t); });
    });
  }
  function actBtn(a, ic, label, val, cls) {
    return '<button class="tm-actrow ' + (cls || "") + '" data-a="' + a + '"><span class="ic">' + ic + '</span>' +
      '<span class="t">' + label + '</span>' + (val ? '<span class="v">' + esc(val) + '</span>' : '') + '</button>';
  }
  function doAction(a, t) {
    if (a === "edit") { openForm(t); }
    else if (a === "status") {
      TK.radioSheet("Update Status", WST_SET.map(function (s) { return { v: s[0], label: s[1], on: t.wstatus === s[0] }; }), function (v) {
        if (t.wstatus === v) return;
        var _prev = WST_LBL[t.wstatus] || t.wstatus;
        t.wstatus = v; t.status = v === "completed" ? "resolved" : v === "pending" || v === "awaiting" ? "pending" : "open";
        if (v === "completed" && !t.completedMs) t.completedMs = NOW.getTime();
        if (v === "reopened") { t.reopenedMs = NOW.getTime(); t.completedMs = null; t.escalated = false; t.slaStartMs = Date.now(); }
        TK.save(); render(); logTicketActivity(t, v === "completed" ? "Ticket closed \u00b7 " + displayId(t) : "Ticket status changed", { Field: "Status", oldVal: _prev, newVal: WST_LBL[v] || v }); toast("Status updated to " + WST_LBL[v]);
        if (TK.notifyCustomer) TK.notifyCustomer(t, v);
      });
    } else if (a === "priority") {
      TK.radioSheet("Update Priority", WPRIO.map(function (p) { return { v: p[0], label: p[1], on: t.wpriority === p[0] }; }), function (v) {
        if (t.wpriority === v) return;
        var _op = WPRIO_LBL[t.wpriority] || t.wpriority;
        t.wpriority = v; t.priority = v === "high" || v === "critical" ? "high" : v === "medium" ? "med" : "low";
        TK.save(); render(); logTicketActivity(t, "Ticket priority changed", { Field: "Priority", oldVal: _op, newVal: WPRIO_LBL[v] || v }); toast("Priority set to " + WPRIO_LBL[v]);
      });
    } else if (a === "star") { t.starred = !t.starred; TK.save(); render(); toast(t.starred ? "Ticket starred" : "Star removed"); }
    else if (a === "print") { printTicket(t); }
    else if (a === "spam") { t.spam = !t.spam; TK.save(); render(); toast(t.spam ? "Marked as spam" : "Removed from spam"); }
  }

  /* =========================================================
     EXPORT · IMPORT · PRINT
     ========================================================= */
  function exportTickets(list) {
    if (!list || !list.length) { toast("No tickets to export"); return; }
    var cols = ["Ticket ID", "Subject", "Customer", "Mobile", "Company", "Department", "Assignee", "Status", "Priority", CF_LABEL, "Due Date"];
    var lines = [cols.map(csvCell).join(",")];
    list.forEach(function (t) {
      var c = TK.custById(t.customer) || {}, ag = TK.agentById(t.assignee) || {};
      lines.push([
        displayId(t), t.subject, c.name || t.custName || "", "91" + (t.mobile || "").replace(/\D/g, ""),
        t.company || "", t.department || "", ag.name || "Unassigned",
        WST_LBL[t.wstatus] || "", WPRIO_LBL[t.wpriority] || "", t.cf || "", fmtDue(t.dueMs)
      ].map(csvCell).join(","));
    });
    var ok = downloadFile("tickets-" + state.tab + "-" + ymd() + ".csv", lines.join("\n"), "text/csv;charset=utf-8");
    toast(ok ? "Exported " + list.length + " tickets to CSV" : "Export blocked by browser");
  }

  function importTickets() {
    var inp = document.createElement("input");
    inp.type = "file"; inp.accept = ".csv,text/csv"; inp.style.display = "none";
    document.body.appendChild(inp);
    inp.addEventListener("change", function () {
      var f = inp.files && inp.files[0];
      if (!f) { document.body.removeChild(inp); return; }
      var reader = new FileReader();
      reader.onload = function () {
        var added = parseImport(String(reader.result || ""));
        document.body.removeChild(inp);
        if (added > 0) { state.tab = "all"; state.page = 1; render(); toast("Imported " + added + (added === 1 ? " ticket" : " tickets")); }
        else toast("No valid rows found in file");
      };
      reader.onerror = function () { document.body.removeChild(inp); toast("Could not read file"); };
      reader.readAsText(f);
    });
    inp.click();
  }
  function parseImport(text) {
    var rows = parseCSV(text);
    if (rows.length < 2) return 0;
    var head = rows[0].map(function (h) { return h.trim().toLowerCase(); });
    function col(names) { for (var i = 0; i < names.length; i++) { var x = head.indexOf(names[i]); if (x > -1) return x; } return -1; }
    var ix = {
      subject: col(["subject"]), customer: col(["customer", "customer name"]), mobile: col(["mobile", "phone"]),
      company: col(["company"]), dept: col(["department", "dept"]), assignee: col(["assignee", "agent"]),
      status: col(["status"]), prio: col(["priority"]), cf: col([CF_LABEL.toLowerCase(), "reference id", "reference"])
    };
    var added = 0;
    var prioMap = { critical: "critical", high: "high", medium: "medium", low: "low" };
    var statusMap = { assigned: "assigned", "in progress": "inprogress", "awaiting customer response": "awaiting", pending: "pending", completed: "completed", reopened: "reopened" };
    for (var r = 1; r < rows.length; r++) {
      var row = rows[r]; if (!row || !row.join("").trim()) continue;
      var subj = ix.subject > -1 ? (row[ix.subject] || "").trim() : "";
      if (!subj) continue;
      var wp = ix.prio > -1 ? (prioMap[(row[ix.prio] || "").trim().toLowerCase()] || "low") : "low";
      var ws = ix.status > -1 ? (statusMap[(row[ix.status] || "").trim().toLowerCase()] || "assigned") : "assigned";
      var agName = ix.assignee > -1 ? (row[ix.assignee] || "").trim() : "";
      var agObj = TK.AGENTS.filter(function (a) { return a.name.toLowerCase() === agName.toLowerCase(); })[0];
      var nt = {
        id: TK.uid(), num: TK.nextNum(), subject: subj,
        customer: "aarav", custName: ix.customer > -1 ? (row[ix.customer] || "").trim() : "Imported",
        company: ix.company > -1 ? (row[ix.company] || "").trim() : "",
        mobile: ix.mobile > -1 ? (row[ix.mobile] || "").replace(/\D/g, "").slice(-10) : "",
        priority: wp === "critical" || wp === "high" ? "high" : wp === "medium" ? "med" : "low",
        wpriority: wp, status: ws === "completed" ? "resolved" : ws === "pending" || ws === "awaiting" ? "pending" : "open", wstatus: ws,
        category: "Other", department: ix.dept > -1 ? (row[ix.dept] || "Imported").trim() : "Imported", channel: "Import", source: "import",
        assignee: agObj ? agObj.id : "unassigned", cf: ix.cf > -1 ? (row[ix.cf] || "").trim() : "",
        starred: false, spam: false, rating: 0, created: 0, updated: 0, unread: false,
        createdMs: NOW.getTime(), assignedMs: agObj ? NOW.getTime() : null, dueMs: NOW.getTime() + 2 * DAY,
        completedMs: ws === "completed" ? NOW.getTime() : null, slaStartMs: Date.now(), slaRes: (TK.slaDefaults ? TK.slaDefaults().res : 3), slaFirst: (TK.slaDefaults ? TK.slaDefaults().first : 1), thread: []
      };
      TK.addTicket(nt); added++;
    }
    return added;
  }
  function parseCSV(text) {
    var rows = [], row = [], cur = "", i = 0, inQ = false, ch;
    text = text.replace(/\r\n/g, "\n").replace(/\r/g, "\n");
    while (i < text.length) {
      ch = text[i];
      if (inQ) {
        if (ch === '"') { if (text[i + 1] === '"') { cur += '"'; i++; } else inQ = false; }
        else cur += ch;
      } else {
        if (ch === '"') inQ = true;
        else if (ch === ",") { row.push(cur); cur = ""; }
        else if (ch === "\n") { row.push(cur); rows.push(row); row = []; cur = ""; }
        else cur += ch;
      }
      i++;
    }
    if (cur.length || row.length) { row.push(cur); rows.push(row); }
    return rows;
  }

  function printTicket(t) {
    var c = TK.custById(t.customer) || {}, ag = TK.agentById(t.assignee) || {};
    function r(k, v) { return '<tr><td class="k">' + esc(k) + '</td><td>' + esc(v) + '</td></tr>'; }
    var html = '<!doctype html><html><head><meta charset="utf-8"><title>' + esc(displayId(t)) + '</title>' +
      '<style>body{font-family:-apple-system,Segoe UI,Roboto,sans-serif;color:#15231a;padding:32px;max-width:680px;margin:auto;}' +
      'h1{font-size:22px;margin:0 0 4px;}h2{font-size:13px;font-weight:600;color:#4d5d52;margin:0 0 24px;}' +
      'table{width:100%;border-collapse:collapse;}td{padding:9px 10px;border-bottom:1px solid #eef1ec;font-size:14px;vertical-align:top;}' +
      'td.k{width:160px;color:#8a978d;font-weight:700;}.sub{margin-top:24px;font-size:13px;color:#4d5d52;}</style></head><body>' +
      '<h1>' + esc(t.subject) + '</h1><h2>' + esc(displayId(t)) + ' · AskEva Ticketing</h2><table>' +
      r("Customer", c.name || t.custName || "—") + r("Mobile", "91" + (t.mobile || "").replace(/\D/g, "")) +
      r("Company", t.company || "N/A") + r("Department", t.department || "—") +
      r("Assignee", ag.name || "Unassigned") + r("Status", WST_LBL[t.wstatus] || "—") +
      r("Priority", WPRIO_LBL[t.wpriority] || "—") + r("Source", t.source || "form") +
      r(CF_LABEL, t.cf || "—") + r("Due Date", fmtDue(t.dueMs)) + '</table>' +
      (t.thread && t.thread[0] ? '<div class="sub"><b>Description:</b><br>' + esc(t.thread[0].text) + '</div>' : '') +
      '</body></html>';
    var ifr = document.createElement("iframe");
    ifr.setAttribute("aria-hidden", "true");
    ifr.style.cssText = "position:fixed;right:0;bottom:0;width:0;height:0;border:0;opacity:0;";
    document.body.appendChild(ifr);
    var d = ifr.contentWindow.document; d.open(); d.write(html); d.close();
    setTimeout(function () {
      try { ifr.contentWindow.focus(); ifr.contentWindow.print(); } catch (e) {}
      setTimeout(function () { if (ifr.parentNode) ifr.parentNode.removeChild(ifr); }, 1500);
    }, 350);
    toast("Opening print dialog for " + displayId(t) + "…");
  }
  function ymd() { var d = new Date(); return d.getFullYear() + pad(d.getMonth() + 1) + pad(d.getDate()); }

  /* =========================================================
     NEW TICKET (full-screen form)
     ========================================================= */
  /* PASS 4: write ticket events onto the ticket's OWN activity log AND
     cross-post onto the matching lead's timeline (keep both in sync). */
  function logTicketActivity(t, text, meta) {
    if (!t) return;
    try {
      if (!t.activity) t.activity = [];
      t.activity.unshift({ text: text, ms: Date.now(), who: "eshan@tunepath.com", meta: meta || null });
      if (TK && TK.save) TK.save();
    } catch (e) {}
    try { if (window.AskEvaActivity) window.AskEvaActivity.log({ mobile: t.mobile, name: t.custName }, { type: "ticket", text: text, module: "Tickets" }); } catch (e) {}
  }
  var formEl = document.getElementById("txForm");
  /* converted-lead customers feed the customer-name dropdown */
  function convertedCustomers() {
    var out = [], seen = {};
    try {
      (window.AskEvaLeads || []).forEach(function (L) {
        if (L.status !== "converted") return;
        var key = (L.name || "").trim().toLowerCase() + "|" + (L.mobile || "").replace(/\D/g, "");
        if (seen[key]) return; seen[key] = 1;
        out.push({ name: L.name || "", mobile: (L.mobile || "").replace(/\D/g, ""), company: L.company || "", cc: "+91" });
      });
    } catch (e) {}
    return out;
  }
  /* new ticket for an unlisted customer → create a Converted lead in Leads */
  function ensureCustomerLead(name, cc, mobile, company) {
    if (!name || !window.AskEvaLeads) return;
    var digits = (mobile || "").replace(/\D/g, ""), nm = name.trim().toLowerCase();
    var leads = window.AskEvaLeads, match = null;
    for (var i = 0; i < leads.length; i++) {
      var L = leads[i], ld = (L.mobile || "").replace(/\D/g, "");
      if ((digits && ld.slice(-10) === digits.slice(-10)) || (L.name || "").trim().toLowerCase() === nm) { match = L; break; }
    }
    if (match) {
      // back-fill company from the ticket if the existing lead has none yet,
      // so the lead + its Customer record reflect the company entered here.
      var co = (company || "").trim(), didFill = false;
      if (co && !(match.company || "").trim()) { match.company = co; didFill = true; }
      if (match.status !== "converted" && window.AskEvaConvertLead) {
        try { window.AskEvaConvertLead({ name: match.name, phone: match.mobile || "" }); } catch (e) {}
      } else if (didFill) {
        if (window.AskEvaSaveLeads) { try { window.AskEvaSaveLeads(); } catch (e) {} }
        if (window.AskEvaLeadsChanged) { try { window.AskEvaLeadsChanged("update"); } catch (e) {} }
        else document.dispatchEvent(new CustomEvent("leads:changed"));
      }
      return;
    }
    if (window.AskEvaAddLead) {
      try {
        window.AskEvaAddLead({ name: name, countryCode: cc || "+91", mobile: digits, company: company || "", status: "converted", source: "Ticket", assigned: "" });
        if (window.AskEvaConvertLead) window.AskEvaConvertLead({ name: name, phone: digits });
        else document.dispatchEvent(new CustomEvent("leads:changed"));
      } catch (e) {}
    }
  }
  var draft = null, editingId = null;
  function openForm(existing) {
    editingId = (existing && existing.id) || null;
    if (editingId) {
      var c = TK.custById(existing.customer) || {};
      draft = {
        department: existing.department || "", assignee: existing.assignee || "", priority: existing.wpriority || "",
        customer: existing.customer || "", custName: existing.custName || c.name || "", cc: existing.cc || "+91", mobile: (existing.mobile || "").replace(/\D/g, ""),
        company: existing.company || "", subject: existing.subject || "",
        desc: (existing.thread && existing.thread[0] && existing.thread[0].text) || "", cf: existing.cf || "",
        docs: (existing.docs && existing.docs.slice()) || (existing.doc ? [{ name: existing.doc, data: existing.docData || "", type: existing.docType || "", size: existing.docSize || 0 }] : []),
        cfx: Object.assign({}, existing.cfx || {})
      };
    } else {
      draft = { department: "", assignee: "", priority: "", customer: "", custName: "", cc: "+91", mobile: "", company: "", subject: "", desc: "", cf: "", docs: [], cfx: {} };
    }
    renderForm(); formEl.classList.add("show");
  }
  function renderForm() {
    var DEPTS = deptNames();
    var ASSIGNEES = agentsForDept(draft.department);
    // if the picked agent isn't in the (re-scoped) department, clear it
    if (draft.assignee && !ASSIGNEES.some(function (a) { return a.id === draft.assignee; })) draft.assignee = "";
    formEl.innerHTML =
      '<div class="ax-bar"><button class="ax-iconbtn" data-x="close" aria-label="Close">' + ICON.x + '</button>' +
        '<div class="ttl">' + (editingId ? "Edit Ticket" : "Create New Ticket") + '</div><span class="spacer"></span></div>' +
      '<div class="ax-scroll">' +
        sel("Department", "nfDept", draft.department, "Select department", DEPTS.map(function (d) { return [d, d]; }), true) +
        sel("Assign To", "nfAssign", draft.assignee, draft.department ? (ASSIGNEES.length ? "Select agent" : "No agents in this department") : "Select department first", ASSIGNEES.map(function (a) { return [a.id, a.name]; }), true) +
        sel("Priority", "nfPrio", draft.priority, "Select priority", WPRIO.map(function (p) { return [p[0], p[1]]; }), true) +
        field("Customer Name", '<div class="nf-custwrap"><div class="ax-control">' + ICON.user + '<input id="nfName" type="text" autocomplete="off" placeholder="Search or enter customer name" value="' + esc(draft.custName) + '"></div><div class="nf-sugg" id="nfNameSugg" hidden></div></div>', true) +
        field("Mobile Number", '<div class="ap-mobrow"><select id="nfCC" data-uxdd-codeonly>' + (window.AskEvaCCOptions ? window.AskEvaCCOptions(draft.cc || "+91", { format: function (n, c) { return c + "  " + n; } }) : '<option value="+91">+91  India</option>') + '</select><input id="nfMob" type="tel" inputmode="numeric" placeholder="Enter mobile number" value="' + esc(draft.mobile) + '"></div>', true) +
        field("Company Name", '<div class="ax-control">' + ICON.bldg + '<input id="nfCo" type="text" placeholder="Enter company name" value="' + esc(draft.company) + '"></div>', false) +
        field("Subject", '<div class="ax-control">' + ICON.tag + '<input id="nfSubj" type="text" maxlength="75" placeholder="Enter Subject" value="' + esc(draft.subject) + '"><span class="nf-count" id="nfSubjN">' + draft.subject.length + ' / 75</span></div>', true) +
        field("Description", '<div class="ax-control area"><textarea id="nfDesc" rows="3" placeholder="Enter Description">' + esc(draft.desc) + '</textarea></div>', true) +
        docField() +
        cfgCustom().map(customField).join("") +
      '</div>' +
      '<div class="ax-savebar two"><button class="ax-btn ghost" data-x="close">Cancel</button>' +
        '<button class="ax-btn primary" id="nfCreate">' + ICON.check + (editingId ? "Save Changes" : "Create Ticket") + '</button></div>';
    bindForm();
  }
  function field(label, control, req) {
    return '<div class="ax-field"><label class="ax-label">' + esc(label) + (req ? '<span class="nf-req">*</span>' : '') + '</label>' + control + '</div>';
  }
  function sel(label, id, val, ph, opts, req) {
    var cur = opts.filter(function (o) { return o[0] === val; })[0];
    return '<div class="ax-field"><label class="ax-label">' + esc(label) + (req ? '<span class="nf-req">*</span>' : '') + '</label>' +
      '<button class="nf-select' + (cur ? "" : " ph") + '" id="' + id + '" data-opts=\'' + esc(JSON.stringify(opts)) + '\'><span class="v">' + esc(cur ? cur[1] : ph) + '</span><span class="cv">' + ICON.chevD + '</span></button></div>';
  }
  function docField() {
    var items = draft.docs.map(function (d, i) {
      return '<div class="nf-docitem"><span class="ic">' + ICON.file + '</span><span class="nm">' + esc(d.name) + '</span>' +
        '<button class="rm" type="button" data-docrm="' + i + '" aria-label="Remove">' + ICON.x + '</button></div>';
    }).join("");
    var canAdd = draft.docs.length < MAXDOCS;
    var ctrl = '<div class="nf-doclist">' + items +
      (canAdd ? '<button class="nf-upload" type="button" id="nfDoc">' + ICON.upload + 'Upload File (' + draft.docs.length + '/' + MAXDOCS + ')</button>' : '') +
      '<div class="nf-dochint">PDF and image files \u00b7 up to ' + MAXDOCS + ' files</div></div>';
    return field("Documents", ctrl, false);
  }
  function customField(f) {
    var val = esc(draft.cfx[f.id] != null ? draft.cfx[f.id] : "");
    if (f.type === "textarea") return field(f.name, '<div class="ax-control area"><textarea data-cfx="' + f.id + '" rows="3" placeholder="' + esc(f.ph || "") + '">' + val + '</textarea></div>', !!f.req);
    var itype = f.type === "number" ? "number" : (f.type === "date" ? "date" : "text");
    return field(f.name, '<div class="ax-control">' + ICON.note + '<input data-cfx="' + f.id + '" type="' + itype + '" placeholder="' + esc(f.ph || "") + '" value="' + val + '"></div>', !!f.req);
  }
  function bindForm() {
    $$('[data-x="close"]', formEl).forEach(function (b) { b.addEventListener("click", function () { formEl.classList.remove("show"); }); });
    pickSel("nfDept", "Select department", function (v) { draft.department = v; });
    pickSel("nfAssign", "Assign to", function (v) { draft.assignee = v; });
    pickSel("nfPrio", "Select priority", function (v) { draft.priority = v; });
    (function () {
      var inp = $("#nfName", formEl), sugg = $("#nfNameSugg", formEl);
      if (!inp) return;
      function closeSugg() { if (sugg) { sugg.hidden = true; sugg.innerHTML = ""; } }
      function fill(c) {
        draft.custName = c.name; inp.value = c.name;
        if (c.mobile) { draft.mobile = c.mobile; var mb = $("#nfMob", formEl); if (mb) mb.value = c.mobile; }
        if (c.company) { draft.company = c.company; var co = $("#nfCo", formEl); if (co) co.value = c.company; }
        closeSugg();
      }
      function renderSugg() {
        if (!sugg) return;
        var q = inp.value.trim().toLowerCase();
        var all = convertedCustomers();
        var list = (q ? all.filter(function (c) { return c.name.toLowerCase().indexOf(q) > -1 || (c.mobile || "").indexOf(q) > -1; }) : all).slice(0, 6);
        if (!list.length) { closeSugg(); return; }
        sugg.innerHTML = list.map(function (c, i) { return '<button type="button" class="nf-suggopt" data-i="' + i + '"><span class="nm">' + esc(c.name) + '</span>' + (c.mobile ? '<span class="mb">' + esc(c.mobile) + '</span>' : "") + '</button>'; }).join("");
        sugg.hidden = false;
        $$(".nf-suggopt", sugg).forEach(function (b) { b.addEventListener("mousedown", function (e) { e.preventDefault(); fill(list[+b.getAttribute("data-i")]); }); });
      }
      inp.addEventListener("input", function () { draft.custName = inp.value; renderSugg(); });
      inp.addEventListener("focus", renderSugg);
      inp.addEventListener("blur", function () { setTimeout(closeSugg, 160); });
    }());
    bindInput("nfMob", function (v) { var mx = (window.AskEvaPhoneLen ? window.AskEvaPhoneLen(draft.cc || "+91").max : 15); draft.mobile = v.replace(/\D/g, "").slice(0, mx); });
    (function () { var cc = $("#nfCC", formEl); if (cc) cc.addEventListener("change", function (e) { draft.cc = e.target.value; var mx = (window.AskEvaPhoneLen ? window.AskEvaPhoneLen(draft.cc).max : 15); draft.mobile = (draft.mobile || "").slice(0, mx); var mb = $("#nfMob", formEl); if (mb) mb.value = draft.mobile; }); })();
    bindInput("nfCo", function (v) { draft.company = v; });
    var subj = $("#nfSubj", formEl); if (subj) subj.addEventListener("input", function (e) { draft.subject = e.target.value; var n = $("#nfSubjN", formEl); if (n) n.textContent = e.target.value.length + " / 75"; });
    bindInput("nfDesc", function (v) { draft.desc = v; });
    $$("[data-cfx]", formEl).forEach(function (el) { el.addEventListener("input", function () { draft.cfx[el.getAttribute("data-cfx")] = el.value; }); });
    var doc = $("#nfDoc", formEl); if (doc) doc.addEventListener("click", pickDocs);
    $$("[data-docrm]", formEl).forEach(function (b) { b.addEventListener("click", function () { draft.docs.splice(+b.getAttribute("data-docrm"), 1); renderForm(); }); });
    $("#nfCreate", formEl).addEventListener("click", create);
  }
  function pickDocs() {
    if (draft.docs.length >= MAXDOCS) { toast("Up to " + MAXDOCS + " files"); return; }
    var inp = document.createElement("input");
    inp.type = "file"; inp.accept = "image/*,application/pdf,.pdf"; inp.multiple = true; inp.style.display = "none";
    document.body.appendChild(inp);
    inp.addEventListener("change", function () {
      var files = inp.files ? Array.prototype.slice.call(inp.files) : [];
      files.forEach(function (f) {
        if (draft.docs.length >= MAXDOCS) return;
        var isImg = /^image\//.test(f.type), isPdf = f.type === "application/pdf" || /\.pdf$/i.test(f.name);
        if (!isImg && !isPdf) { toast("Only PDF and image files"); return; }
        var rec = { name: f.name, type: f.type || (isPdf ? "application/pdf" : ""), size: f.size || 0, data: "" };
        draft.docs.push(rec);
        var rd = new FileReader(); rd.onload = function () { rec.data = String(rd.result || ""); }; rd.readAsDataURL(f);
      });
      inp.remove(); renderForm();
    });
    inp.click();
  }
  function bindInput(id, cb) { var el = $("#" + id, formEl); if (el) el.addEventListener("input", function (e) { cb(e.target.value); }); }
  function pickSel(id, title, cb) {
    var btn = $("#" + id, formEl); if (!btn) return;
    btn.addEventListener("click", function () {
      var opts = JSON.parse(btn.getAttribute("data-opts"));
      TK.radioSheet(title, opts.map(function (o) { return { v: o[0], label: o[1], on: false }; }), function (v) {
        cb(v); renderForm();
      });
    });
  }
  function create() {
    if (!draft.department) { toast("Select a department"); return; }
    if (!draft.assignee) { toast("Assign to an agent"); return; }
    if (!draft.priority) { toast("Select a priority"); return; }
    if (!draft.custName.trim()) { toast("Enter customer name"); return; }
    var _pl = (window.AskEvaPhoneLen ? window.AskEvaPhoneLen(draft.cc || "+91") : { min: 10, max: 10 });
    if (!draft.mobile || draft.mobile.length < _pl.min || draft.mobile.length > _pl.max) { toast(_pl.min === _pl.max ? "Enter a " + _pl.min + "-digit number" : "Enter a valid mobile number"); return; }
    if (!draft.subject.trim()) { toast("Enter a subject"); return; }
    var _cfs = cfgCustom();
    for (var _ci = 0; _ci < _cfs.length; _ci++) { var _cf = _cfs[_ci]; if (_cf.req && !String(draft.cfx[_cf.id] || "").trim()) { toast("Please fill " + _cf.name); return; } }
    var pr = draft.priority;
    var derivedPrio = pr === "critical" || pr === "high" ? "high" : pr === "medium" ? "med" : "low";

    if (editingId) {
      var t = TK.getT(editingId);
      if (t) {
        t.subject = draft.subject.trim();
        t.department = draft.department;
        t.assignee = draft.assignee;
        t.wpriority = pr; t.priority = derivedPrio;
        t.custName = draft.custName.trim();
        t.mobile = draft.mobile; t.cc = draft.cc || "+91";
        t.company = draft.company.trim();
        t.cfx = Object.assign({}, draft.cfx); t.cf = firstCf(draft);
        t.docs = draft.docs.slice();
        var _d0 = draft.docs[0];
        if (_d0) { t.doc = _d0.name; t.docData = _d0.data || ""; t.docType = _d0.type || ""; t.docSize = _d0.size || 0; }
        else { t.doc = ""; t.docData = ""; t.docType = ""; t.docSize = 0; }
        var desc = draft.desc.trim();
        if (desc) {
          if (t.thread && t.thread[0]) t.thread[0].text = desc;
          else t.thread = [{ from: "customer", text: desc, mins: 0 }];
        }
        TK.save();
      }
      formEl.classList.remove("show");
      render();
      logTicketActivity(t, "Ticket updated \u00b7 " + displayId(t));
      toast("Ticket " + displayId(t) + " updated");
      if (window.TKDetail && window.TKDetail.open) setTimeout(function () { window.TKDetail.open(editingId); }, 60);
      editingId = null;
      return;
    }

    var nt = {
      id: TK.uid(), num: TK.nextNum(), subject: draft.subject.trim(),
      customer: draft.customer || "aarav", custName: draft.custName.trim(), company: draft.company.trim(),
      mobile: draft.mobile, cc: draft.cc || "+91", priority: derivedPrio,
      wpriority: pr, status: "open", wstatus: "assigned",
      category: "Other", department: draft.department, channel: "Web", source: "form",
      assignee: draft.assignee, cf: firstCf(draft), cfx: Object.assign({}, draft.cfx), starred: false, spam: false, rating: 0,
      docs: draft.docs.slice(),
      doc: (draft.docs[0] && draft.docs[0].name) || "", docData: (draft.docs[0] && draft.docs[0].data) || "", docType: (draft.docs[0] && draft.docs[0].type) || "", docSize: (draft.docs[0] && draft.docs[0].size) || 0,
      created: 0, updated: 0, unread: false,
      createdMs: NOW.getTime(), assignedMs: NOW.getTime(), dueMs: NOW.getTime() + 2 * DAY, completedMs: null,
      slaStartMs: Date.now(),
      slaRes: (TK.slaDefaults ? TK.slaDefaults().res : 3), slaFirst: (TK.slaDefaults ? TK.slaDefaults().first : 1),
      thread: draft.desc.trim() ? [{ from: "customer", text: draft.desc.trim(), mins: 0 }] : []
    };
    // store a friendlier custom name on customer-less ticket: keep custName for display
    TK.addTicket(nt);
    ensureCustomerLead(nt.custName, nt.cc, nt.mobile, nt.company);
    logTicketActivity(nt, "Ticket created \u00b7 " + displayId(nt));
    if (TK.notifyCustomer) TK.notifyCustomer(nt, "assigned");
    formEl.classList.remove("show");
    state.tab = "open"; state.page = 1; render();
    toast("Ticket " + displayId(nt) + " created");
    setTimeout(function () { if (window.TKDetail) window.TKDetail.open(nt.id); }, 260);
  }

  /* ---- Ticketing USER notification: deliver the configured template into the
     customer's chat when a ticket event fires, IF that user alert is on
     (Settings → Ticketing → Notification Configuration). Silent, no nav. ---- */
  var TICKET_MSG = {
    assigned: "Hi {name}, your ticket {id} has been received and assigned to our team. We'll be in touch shortly.",
    awaiting: "Hi {name}, we're awaiting your response on ticket {id}. Please reply when you can.",
    pending: "Hi {name}, your ticket {id} is currently pending. We'll update you soon.",
    inprogress: "Hi {name}, good news \u2014 work on your ticket {id} is now in progress.",
    completed: "Hi {name}, your ticket {id} has been completed. Thank you for your patience!",
    reopened: "Hi {name}, your ticket {id} has been reopened and is being looked into again."
  };
  TK.notifyCustomer = function (t, ev) {
    try {
      if (!t || !window.TKNotify || !window.__chat || !window.__chat.postApptAlert) return;
      if (!TKNotify.enabled(ev)) return;
      var base = TICKET_MSG[ev]; if (!base) return;                 // only customer-facing lifecycle events
      var c = TK.custById(t.customer) || {};
      var name = c.name || t.custName || "there";
      var body = base.split("{name}").join(name).split("{id}").join(displayId(t));
      window.__chat.postApptAlert({ name: c.name || t.custName, phone: t.mobile },
        { n: TKNotify.tpl(ev) || "Notification", text: body, cat: "Utility" });
    } catch (e) {}
  };

  function deptList() {
    var set = {};
    TK.tickets.forEach(function (t) { if (t.department) set[t.department] = 1; });
    var arr = Object.keys(set); if (!arr.length) arr = ["Test dep", "OH"];
    if (arr.indexOf("Test dep") < 0) arr.unshift("Test dep");
    return arr;
  }

  /* =========================================================
     BULK UPDATE (select tickets → update status / priority /
     department + agent / send a bulk response)
     ========================================================= */
  function selectedIds() { return Object.keys(state.selected).filter(function (k) { return state.selected[k]; }); }
  function selbar(list) {
    var ids = selectedIds();
    var allSel = list.length > 0 && list.every(function (t) { return state.selected[t.id]; });
    return '<div class="tm-selbar">' +
      '<button class="tm-sb-all' + (allSel ? ' on' : '') + '" id="tmSelAll" aria-label="Select all">' + ICON.check + '</button>' +
      '<span class="n">' + ids.length + ' selected</span><span class="sp"></span>' +
      '<button class="tm-sb-up" id="tmBulkOpen"' + (ids.length ? '' : ' disabled') + '>' + ICON.edit + 'Update (' + ids.length + ')</button>' +
      '<button class="tm-sb-cancel" id="tmSelCancel">Cancel</button>' +
    '</div>';
  }
  function updateSelbar(list) {
    var ids = selectedIds();
    var n = wrap.querySelector('.tm-selbar .n'); if (n) n.textContent = ids.length + ' selected';
    var up = $("#tmBulkOpen", wrap); if (up) { up.disabled = !ids.length; up.innerHTML = ICON.edit + 'Update (' + ids.length + ')'; }
    var sa = $("#tmSelAll", wrap); if (sa) { var allSel = list.length > 0 && list.every(function (t) { return state.selected[t.id]; }); sa.classList.toggle('on', allSel); }
  }
  function toggleSel(on) { state.selMode = on; state.selected = {}; if (on) state.view = "card"; render(); }
  function toggleAll(list) {
    var allSel = list.length > 0 && list.every(function (t) { return state.selected[t.id]; });
    state.selected = {};
    if (!allSel) list.forEach(function (t) { state.selected[t.id] = true; });
    render();
  }
  function deptNames() {
    try { if (window.TK && TK.tsetDepts) { var d = TK.tsetDepts().map(function (x) { return x.name; }); if (d.length) return d; } } catch (e) {}
    return deptList();
  }
  function agentsForDept(dept) {
    if (!dept) return [];
    // Source of truth: each agent's Ticketing config (Settings → Agents).
    // Show ONLY agents scoped to the selected department — no fallback to all.
    if (window.AskEvaAgentCfg && AskEvaAgentCfg.usersForTicketDept) {
      var scoped = AskEvaAgentCfg.usersForTicketDept(dept) || [];
      // keep only agents the ticketing store actually knows about
      var ids = {}; TK.AGENTS.forEach(function (a) { ids[a.id] = a; });
      var mapped = scoped.filter(function (a) { return ids[a.id]; }).map(function (a) { return ids[a.id]; });
      return mapped.length ? mapped : scoped;
    }
    return [];
  }
  /* department head = highest-ranked agent scoped to that department */
  function deptHeadFor(dept) {
    var scoped = agentsForDept(dept) || [];
    function rank(a) { return /super|admin|head|lead|manager/i.test(a.role || "") ? 0 : 1; }
    var sorted = scoped.slice().sort(function (a, b) { return rank(a) - rank(b); });
    return sorted[0] || null;
  }
  /* SLA breach handler: a still-open ticket past its resolution target becomes
     Pending and is escalated (reassigned) to its department head. Idempotent. */
  function escalateBreached(t) {
    if (!t || t.spam || t.wstatus === "completed" || t.escalated) return false;
    // only sweep tickets that have a real-time SLA start (created/opened under the
    // live clock); seed tickets without one are left alone
    if (t.slaStartMs == null) return false;
    var _dres = (window.TK && TK.slaDefaults) ? TK.slaDefaults().res : 3;
    var resMin = (window.TK && TK.slaForTicket) ? (function () { var p = TK.slaForTicket(t); return p && p.slaRes != null ? p.slaRes : (t.slaRes || _dres); })() : (t.slaRes || _dres);
    var mins = (Date.now() - t.slaStartMs) / MIN;
    if (mins <= resMin) return false;
    t.wstatus = "pending"; t.status = "pending";
    t.escalated = true; t.escalatedMs = NOW.getTime();
    var head = deptHeadFor(t.department);
    if (head) { t.assignee = head.id; t.assignedMs = NOW.getTime(); t.escalatedTo = head.id; t.escalatedToName = head.name; }
    logTicketActivity(t, "SLA breached \u00b7 escalated to " + (head ? head.name : "department head") + " \u00b7 " + displayId(t));
    return true;
  }
  TK.escalateBreached = escalateBreached;
  TK.deptHeadFor = deptHeadFor;
  function closeBulk() { var o = document.getElementById("txBulk"); if (o) o.classList.remove("show"); }
  function openBulk(ids) {
    var overlay = document.getElementById("txBulk"); if (!overlay) return;
    var upd = { desc: "", status: "", priority: "", department: "", assignee: "" };
    function mobiles() {
      return ids.map(function (id) {
        var t = TK.getT(id); if (!t) return null;
        var raw = (t.mobile || "").replace(/\D/g, "");
        if (!raw) { var c = TK.custById(t.customer) || {}; raw = (c.mobile || "").replace(/\D/g, ""); }
        return raw ? ("91" + raw) : displayId(t);
      }).filter(Boolean);
    }
    function paint() {
      var ms = mobiles();
      var shown = ms.slice(0, 3).join(", ") + (ms.length > 3 ? " +" + (ms.length - 3) + " more" : "");
      var statusLbl = upd.status ? WST_LBL[upd.status] : "Select status";
      var prioLbl = upd.priority ? WPRIO_LBL[upd.priority] : "Select priority";
      var deptLbl = upd.department || "Select department";
      var agObj = upd.assignee ? TK.agentById(upd.assignee) : null;
      var agLbl = !upd.department ? "Select department first" : (agObj ? agObj.name : "Select agent");
      overlay.innerHTML =
        '<div class="ax-bar"><button class="ax-iconbtn" data-x="close" aria-label="Close">' + ICON.x + '</button>' +
          '<div class="ttl">Bulk Update Tickets</div><span class="spacer"></span></div>' +
        '<div class="ax-scroll">' +
          '<div class="tm-bulkinfo"><div class="bi-ttl">Updating ' + ids.length + ' ticket' + (ids.length > 1 ? 's' : '') + '</div>' +
            '<div class="bi-lbl">Mobile Numbers:</div><div class="bi-mobs">' + esc(shown || "\u2014") + '</div></div>' +
          '<div class="ax-field"><label class="ax-label">Bulk description</label>' +
            '<div class="ax-control area"><textarea id="buDesc" rows="4" placeholder="Type your response to all selected tickets\u2026">' + esc(upd.desc) + '</textarea></div></div>' +
          '<div class="tm-bulkgrp"><div class="bg-hd">' + ICON.check + 'Status</div>' +
            '<button class="nf-select' + (upd.status ? '' : ' ph') + '" id="buStatus"><span class="v">' + esc(statusLbl) + '</span><span class="cv">' + ICON.chevD + '</span></button></div>' +
          '<div class="tm-bulkgrp"><div class="bg-hd">' + ICON.flag + 'Priority</div>' +
            '<button class="nf-select' + (upd.priority ? '' : ' ph') + '" id="buPrio"><span class="v">' + esc(prioLbl) + '</span><span class="cv">' + ICON.chevD + '</span></button></div>' +
          '<div class="tm-bulkgrp"><div class="bg-hd">' + ICON.user + 'Agent Change</div>' +
            '<label class="ax-label sub">Department</label>' +
            '<button class="nf-select' + (upd.department ? '' : ' ph') + '" id="buDept"><span class="v">' + esc(deptLbl) + '</span><span class="cv">' + ICON.chevD + '</span></button>' +
            '<label class="ax-label sub" style="margin-top:13px">Agent</label>' +
            '<button class="nf-select' + (upd.assignee ? '' : ' ph') + (upd.department ? '' : ' disabled') + '" id="buAgent"><span class="v">' + esc(agLbl) + '</span><span class="cv">' + ICON.chevD + '</span></button></div>' +
        '</div>' +
        '<div class="ax-savebar two"><button class="ax-btn ghost" data-x="close">Cancel</button>' +
          '<button class="ax-btn primary" id="buApply">' + ICON.check + 'Apply Updates</button></div>';

      $$('[data-x="close"]', overlay).forEach(function (b) { b.addEventListener("click", closeBulk); });
      $("#buDesc", overlay).addEventListener("input", function (e) { upd.desc = e.target.value; });
      $("#buStatus", overlay).addEventListener("click", function () {
        TK.radioSheet("Select status", WST_SET.map(function (s) { return { v: s[0], label: s[1], on: upd.status === s[0] }; }), function (v) { upd.status = v; paint(); });
      });
      $("#buPrio", overlay).addEventListener("click", function () {
        TK.radioSheet("Select priority", WPRIO.map(function (p) { return { v: p[0], label: p[1], on: upd.priority === p[0] }; }), function (v) { upd.priority = v; paint(); });
      });
      $("#buDept", overlay).addEventListener("click", function () {
        var ds = deptNames();
        TK.radioSheet("Select department", ds.map(function (d) { return { v: d, label: d, on: upd.department === d }; }), function (v) { if (v !== upd.department) { upd.department = v; upd.assignee = ""; } paint(); });
      });
      var agBtn = $("#buAgent", overlay);
      if (agBtn && upd.department) agBtn.addEventListener("click", function () {
        var ags = agentsForDept(upd.department);
        if (!ags.length) { TK.toast("No agents in this department"); return; }
        TK.radioSheet("Select agent", ags.map(function (a) { return { v: a.id, label: a.name, on: upd.assignee === a.id }; }), function (v) { upd.assignee = v; paint(); });
      });
      $("#buApply", overlay).addEventListener("click", function () {
        if (!upd.desc.trim() && !upd.status && !upd.priority && !upd.department && !upd.assignee) { TK.toast("Choose at least one update"); return; }
        applyBulk(ids, upd); closeBulk(); toggleSel(false);
        TK.toast(ids.length + " ticket" + (ids.length > 1 ? "s" : "") + " updated");
      });
    }
    paint();
    overlay.classList.add("show");
  }
  function applyBulk(ids, upd) {
    var meId = (TK.AGENTS.filter(function (a) { return a.you; })[0] || {}).id || "eshan";
    ids.forEach(function (id) {
      var t = TK.getT(id); if (!t) return;
      if (upd.status) {
        t.wstatus = upd.status;
        t.status = upd.status === "completed" ? "resolved" : (upd.status === "pending" || upd.status === "awaiting") ? "pending" : "open";
        if (upd.status === "completed" && !t.completedMs) t.completedMs = NOW.getTime();
      }
      if (upd.priority) {
        t.wpriority = upd.priority;
        t.priority = (upd.priority === "critical" || upd.priority === "high") ? "high" : upd.priority === "medium" ? "med" : "low";
      }
      if (upd.department) t.department = upd.department;
      if (upd.assignee) { t.assignee = upd.assignee; t.assignedMs = NOW.getTime(); }
      if (upd.desc.trim()) { t.thread = t.thread || []; t.thread.push({ from: "agent", who: meId, text: upd.desc.trim(), mins: 0 }); }
      var parts = [];
      if (upd.status) parts.push("status \u2192 " + WST_LBL[upd.status]);
      if (upd.priority) parts.push("priority \u2192 " + WPRIO_LBL[upd.priority]);
      if (upd.department) parts.push("dept \u2192 " + upd.department);
      if (upd.assignee) { var a = TK.agentById(upd.assignee); parts.push("assigned \u2192 " + (a ? a.name : upd.assignee)); }
      if (upd.desc.trim()) parts.push("response sent");
      logTicketActivity(t, "Bulk update \u00b7 " + (parts.join(", ") || "updated"));
    });
    TK.save(); render();
  }

  /* =========================================================
     icons
     ========================================================= */
  var ICON = {
    search: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><circle cx="11" cy="11" r="7"/><path d="M21 21l-4.3-4.3"/></svg>',
    x: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"><path d="M6 6l12 12M18 6 6 18"/></svg>',
    plus: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"><path d="M12 5v14M5 12h14"/></svg>',
    dots: '<svg viewBox="0 0 24 24" fill="currentColor"><circle cx="12" cy="5" r="2"/><circle cx="12" cy="12" r="2"/><circle cx="12" cy="19" r="2"/></svg>',
    chevL: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m15 6-6 6 6 6"/></svg>',
    chevR: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m9 6 6 6-6 6"/></svg>',
    chevD: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m6 9 6 6 6-6"/></svg>',
    clock: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3.5 2"/></svg>',
    tag: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 12V5a2 2 0 0 1 2-2h7l9 9-9 9-9-9Z"/><circle cx="8" cy="8" r="1.3" fill="currentColor"/></svg>',
    check: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="m5 12 4 4 10-11"/></svg>',
    flag: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M5 21V4M5 4h11l-2 4 2 4H5"/></svg>',
    star: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m12 3 2.7 5.4 6 .9-4.3 4.2 1 6L12 16.9 6.6 19.5l1-6L3.3 9.3l6-.9z"/></svg>',
    starF: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="m12 3 2.7 5.4 6 .9-4.3 4.2 1 6L12 16.9 6.6 19.5l1-6L3.3 9.3l6-.9z"/></svg>',
    print: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 9V3h12v6M6 18H4v-5a2 2 0 0 1 2-2h12a2 2 0 0 1 2 2v5h-2M6 14h12v7H6z"/></svg>',
    alert: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 9v4M12 17h.01"/><path d="M10.3 3.9 2 19a2 2 0 0 0 1.7 3h16.6a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0Z"/></svg>',
    export: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 15v3a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-3"/><path d="m8 9 4-4 4 4"/><path d="M12 5v11"/></svg>',
    import: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 15v3a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-3"/><path d="m8 11 4 4 4-4"/><path d="M12 15V4"/></svg>',
    upload: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 15v3a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-3"/><path d="m8 9 4-4 4 4"/><path d="M12 5v11"/></svg>',
    user: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="8" r="4"/><path d="M4 21c0-4 3.6-6 8-6s8 2 8 6"/></svg>',
    bldg: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linejoin="round"><path d="M4 21V5a2 2 0 0 1 2-2h7a2 2 0 0 1 2 2v16M15 21V9h3a2 2 0 0 1 2 2v10"/><path d="M8 7h3M8 11h3M8 15h3" stroke-linecap="round"/></svg>',
    note: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 5h16M4 10h16M4 15h10"/></svg>',
    inbox: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="M3 13h4l2 3h6l2-3h4"/><path d="M5 19h14a2 2 0 0 0 2-2V8.5a2 2 0 0 0-.3-1L17 2H7L3.3 7.5a2 2 0 0 0-.3 1V17a2 2 0 0 0 2 2Z"/></svg>',
    view: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="4" width="18" height="16" rx="2"/><path d="M3 9h18M9 9v11"/></svg>',
    edit: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M11 4H5a2 2 0 0 0-2 2v13a2 2 0 0 0 2 2h13a2 2 0 0 0 2-2v-6"/><path d="M18.5 2.5a2.12 2.12 0 0 1 3 3L12 15l-4 1 1-4Z"/></svg>',
    drag: '<svg viewBox="0 0 24 24" fill="currentColor"><circle cx="9" cy="6" r="1.6"/><circle cx="15" cy="6" r="1.6"/><circle cx="9" cy="12" r="1.6"/><circle cx="15" cy="12" r="1.6"/><circle cx="9" cy="18" r="1.6"/><circle cx="15" cy="18" r="1.6"/></svg>',
    eye: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7-10-7-10-7Z"/><circle cx="12" cy="12" r="3"/></svg>',
    download: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 4v11m0 0 4-4m-4 4-4-4M5 19h14"/></svg>',
    link: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M10 13a5 5 0 0 0 7 0l3-3a5 5 0 0 0-7-7l-1.5 1.5"/><path d="M14 11a5 5 0 0 0-7 0l-3 3a5 5 0 0 0 7 7l1.5-1.5"/></svg>',
    file: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14 3H7a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V8Z"/><path d="M14 3v5h5"/></svg>'
  };

  window.TKTickets = { render: render, openForm: openForm, displayId: displayId, CF_LABEL: CF_LABEL, WST: WST, WST_SET: WST_SET, WST_LBL: WST_LBL, WST_CLS: WST_CLS, WPRIO: WPRIO, WPRIO_LBL: WPRIO_LBL, NOW: NOW };

  /* close the view dropdown on any outside click */
  document.addEventListener("click", function (e) {
    var menu = document.getElementById("tmViewMenu");
    if (menu && !menu.hidden && (!e.target.closest || !e.target.closest(".tm-viewdd"))) menu.hidden = true;
  });
})();
