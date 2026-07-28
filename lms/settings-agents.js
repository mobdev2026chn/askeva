/* =========================================================
   AskEva — Settings · Agents (part 1)
   Mobile translation of the web "Agents" settings page:
     tabs: Agents / Role Configuration
     · agents table (name, email, mobile, role, type modules,
       status toggle, actions) + Create Agent + pagination
     · row actions: User Credentials / Edit / Change Password
       / Delete
     · agent detail (Agent Information + Type Configuration)
     · Create New Agent modal
   Renders into #agentsView. Self-contained.
   ========================================================= */
(function () {
  "use strict";
  var pane = document.getElementById("sub-agents"); if (!pane) return;
  var $ = function (s, r) { return (r || document).querySelector(s); };
  var $$ = function (s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); };
  function esc(s) { return String(s == null ? "" : s).replace(/[&<>"]/g, function (c) { return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]; }); }
  var toastT;
  function toast(m) { var t = document.getElementById("toast"); if (!t) return; t.textContent = m; t.style.opacity = "1"; t.style.transform = "translateX(-50%) translateY(0)"; clearTimeout(toastT); toastT = setTimeout(function () { t.style.opacity = "0"; t.style.transform = "translateX(-50%) translateY(20px)"; }, 1900); }

  /* modules */
  var MODS = [["chat", "Chat Agent", "chat"], ["leads", "Leads", "leads"], ["appt", "Appointment", "appt"], ["ticket", "Ticketing", "ticket"]];
  var MOD_LBL = {}; MODS.forEach(function (m) { MOD_LBL[m[0]] = m[1]; });
  var ALL = ["chat", "leads", "appt", "ticket"];

  /* store */
  var AK = "askeva.set.agents.v1";
  var SEED = [
    { id: "a1", name: "ananthu", email: "ananthu@gmail.com", mobile: "919495204766", role: "Yeah Test", mods: ["chat"], on: false },
    { id: "a2", name: "dj", email: "testbytest@gmail.com", mobile: "919042498027", role: "admin", mods: ALL.slice(), on: true },
    { id: "a3", name: "Madhan", email: "testerr@gmail.com", mobile: "917904532349", role: "agent", mods: ALL.slice(), on: true },
    { id: "a4", name: "Navitha", email: "navitha@gmail.com", mobile: "919360474181", role: "admin", mods: ALL.slice(), on: true },
    { id: "a5", name: "payer", email: "pay@01gmail.com", mobile: "919889098098", role: "payer", mods: [], on: true },
    { id: "a6", name: "saranya velusamy", email: "saranya.tester.askeva@gmail.com", mobile: "911234500000", role: "admin", mods: ALL.slice(), on: true },
    { id: "a7", name: "t1", email: "t1@gmail.com", mobile: "917904530349", role: "admin", mods: ALL.slice(), on: true },
    { id: "a8", name: "Test", email: "teswwt@gmail.com", mobile: "912435345454", role: "admin", mods: ALL.slice(), on: true },
    { id: "a9", name: "Testing Check 1", email: "teshj@gmail.com", mobile: "919089088908", role: "Testing Check 1", mods: [], on: true },
    { id: "a10", name: "vicky", email: "vickyvicky@gmail.com", mobile: "919786742563", role: "agent", mods: ["chat"], on: true }
  ];
  var agents; try { agents = JSON.parse(localStorage.getItem(AK)) || null; } catch (e) { agents = null; }
  if (!agents || !agents.length) agents = SEED.map(function (a) { return Object.assign({}, a, { mods: a.mods.slice() }); });

  /* core operational team members referenced by Ticketing / Appointments / Leads /
     Analytics seed data — ensure they exist in the people store so assignments
     resolve and stay in sync. One-time & idempotent (respects later deletes). */
  var CORE = [
    { id: "eshan", name: "Eshan Rao", email: "eshan@tunepath.com", mobile: "919000000001", role: "admin", mods: ALL.slice(), on: true, color: "#2BA84A" },
    { id: "kavya", name: "Kavya S",   email: "kavya@askeva.io",    mobile: "919000000002", role: "agent", mods: ALL.slice(), on: true, color: "#7C5CFF" },
    { id: "dev",   name: "Dev Patel", email: "dev@askeva.io",      mobile: "919000000003", role: "agent", mods: ALL.slice(), on: true, color: "#FF9416" },
    { id: "priya", name: "Priya M",   email: "priya@askeva.io",    mobile: "919000000004", role: "agent", mods: ALL.slice(), on: true, color: "#1E7FB0" }
  ];
  (function ensureCore() {
    var FLAG = "askeva.set.agents.core.v1";
    try { if (localStorage.getItem(FLAG)) return; } catch (e) {}
    var added = false;
    CORE.forEach(function (c) { if (!getA(c.id)) { agents.push(Object.assign({}, c, { mods: c.mods.slice() })); added = true; } });
    try { localStorage.setItem(FLAG, "1"); } catch (e) {}
    if (added) { try { localStorage.setItem(AK, JSON.stringify(agents)); } catch (e) {} }
  })();
  function emit() { try { document.dispatchEvent(new CustomEvent("people:changed")); } catch (e) {} }
  function save() { try { localStorage.setItem(AK, JSON.stringify(agents)); } catch (e) {} emit(); }
  function getA(id) { for (var i = 0; i < agents.length; i++) if (agents[i].id === id) return agents[i]; return null; }
  function roles() { var s = {}; agents.forEach(function (a) { if (a.role) s[a.role] = 1; }); return Object.keys(s); }

  /* ---------- departments (shared with Team) ---------- */
  var DK = "askeva.set.depts.v1";
  var depts; try { depts = JSON.parse(localStorage.getItem(DK)) || null; } catch (e) { depts = null; }
  if (!depts || !depts.length) depts = ["Sales", "Support", "Management"];
  function saveDepts() { try { localStorage.setItem(DK, JSON.stringify(depts)); } catch (e) {} emit(); }

  /* ---------- per-agent configs: Ticketing / Leads / Appointment ---------- */
  var ACFGK = "askeva.set.agentcfg.v1";
  var agentCfg; try { agentCfg = JSON.parse(localStorage.getItem(ACFGK)) || {}; } catch (e) { agentCfg = {}; }
  function saveCfgStore() { try { localStorage.setItem(ACFGK, JSON.stringify(agentCfg)); } catch (e) {} emit(); }
  function cfgOf(id) {
    if (!agentCfg[id]) agentCfg[id] = {};
    var c = agentCfg[id];
    if (!c.ticketing) c.ticketing = { depts: [] };
    if (!c.leads) c.leads = { target: "", perDay: "", profession: "" };
    if (!c.appointment) c.appointment = { dept: "", days: [], ranges: [], unavailDates: [], workStart: "", workEnd: "", unavailHours: [], slotType: "Hours", slotDur: "", occupancy: "1", amount: "", editing: false };
    return c;
  }

  /* one-time seed: give the core appointment staff a department + working hours
     so the New/Edit-appointment "Select User" list (scoped to the chosen
     department) actually has people to show. Dept ids match AX.DEPTS. */
  (function ensureApptDepts() {
    var FLAG = "askeva.apptdept.seed.v1";
    try { if (localStorage.getItem(FLAG)) return; } catch (e) {}
    var DEF = { workStart: "09:00", workEnd: "19:00", slotType: "Minutes", slotDur: "15 minutes", occupancy: "1" };
    var map = { eshan: "consult", kavya: "demo", dev: "onboard", priya: "diag", a3: "followup", a4: "consult", a10: "demo" };
    var changed = false;
    Object.keys(map).forEach(function (id) {
      if (!getA(id)) return;
      var p = cfgOf(id).appointment;
      if (!p.dept) { p.dept = map[id]; changed = true; }
      if (!p.workStart) p.workStart = DEF.workStart;
      if (!p.workEnd) p.workEnd = DEF.workEnd;
      if (!p.slotDur) { p.slotType = DEF.slotType; p.slotDur = DEF.slotDur; }
      if (!p.occupancy) p.occupancy = DEF.occupancy;
    });
    if (changed) saveCfgStore();
    try { localStorage.setItem(FLAG, "1"); } catch (e) {}
  })();

  /* one-time seed: map ticketing staff to ticketing departments so the
     New-Ticket "Assign To" list (scoped to the chosen department) has people.
     Department names match TK.tsetDepts(). Fully editable later in each
     agent's Ticketing config. Idempotent + respects later manual edits. */
  (function ensureTicketDepts() {
    var FLAG = "askeva.tkdept.seed.v1";
    try { if (localStorage.getItem(FLAG)) return; } catch (e) {}
    var map = {
      eshan: ["Support L1", "Operations"],
      kavya: ["Support L1", "Support L2"],
      dev:   ["Development Team", "Quality Assurance"],
      priya: ["Billing", "Finance"],
      a2:    ["Support L2", "Sales"],
      a3:    ["Support L1", "Onboarding"],
      a4:    ["Sales", "Marketing"],
      a6:    ["Quality Assurance", "Support L2"],
      a7:    ["Operations", "Accounts"],
      a8:    ["Billing", "Catalog"]
    };
    var changed = false;
    Object.keys(map).forEach(function (id) {
      if (!getA(id)) return;
      var tk = cfgOf(id).ticketing;
      if (!tk.depts || !tk.depts.length) { tk.depts = map[id].slice(); changed = true; }
    });
    if (changed) saveCfgStore();
    try { localStorage.setItem(FLAG, "1"); } catch (e) {}
  })();

  var tab = "agents", page = 1, PP = 8;
  var view = $("#agentsView");

  /* =========================================================
     RENDER
     ========================================================= */
  function render() {
    var badge = document.getElementById("agentsCountBadge"); if (badge) badge.textContent = agents.length + " agents";
    view.innerHTML =
      '<div class="ag-tabs"><button class="ag-tab' + (tab === "agents" ? " on" : "") + '" data-t="agents">Agents</button>' +
        '<button class="ag-tab' + (tab === "roles" ? " on" : "") + '" data-t="roles">Role Configuration</button></div>' +
      (tab === "agents" ? agentsTab() : rolesTab());
    $$(".ag-tab", view).forEach(function (b) { b.addEventListener("click", function () { tab = b.getAttribute("data-t"); render(); }); });
    if (tab === "agents") wireAgents(); else wireRoles();
  }

  function agentsTab() {
    var pages = Math.max(1, Math.ceil(agents.length / PP)); if (page > pages) page = pages;
    var start = (page - 1) * PP, slice = agents.slice(start, start + PP);
    var rows = slice.map(function (a, i) { return agentCard(a, start + i + 1); }).join("");
    return '<div class="ag-toolbar"><button class="ag-create" id="agCreate">' + IC.userPlus + 'Create Agent</button></div>' +
      '<div class="ag-list">' + rows + '</div>' +
      (pages > 1 ? pager(pages) : "");
  }

  function agentCard(a, sn) {
    var mods = a.mods.length ? '<div class="ag-mods">' + a.mods.map(function (m) { return '<span class="ag-mod ' + m + '">' + MOD_LBL[m] + '</span>'; }).join("") + '</div>' : '<span class="ag-nomod">—</span>';
    return '<div class="ag-card" data-id="' + a.id + '">' +
      '<div class="r1"><span class="sn">' + sn + '</span><span class="nm">' + esc(a.name) + '</span>' +
        '<button class="ag-status' + (a.on ? " on" : "") + '" data-id="' + a.id + '" aria-label="Toggle status"><span class="kn"></span></button>' +
        '<button class="ag-act" data-id="' + a.id + '" aria-label="Actions">' + IC.dots + '</button></div>' +
      '<div class="ag-meta"><span class="m"><span class="k">Email</span>' + esc(a.email) + '</span>' +
        '<span class="m"><span class="k">Mobile</span>' + esc(a.mobile) + '</span>' +
        '<span class="m"><span class="k">Role</span>' + esc(a.role || "—") + '</span></div>' +
      '<div class="ag-typerow"><span class="k">Type</span>' + mods + '</div></div>';
  }
  function pager(pages) {
    var nums = ""; for (var p = 1; p <= pages; p++) nums += '<button class="ag-pg num' + (p === page ? " on" : "") + '" data-pg="' + p + '">' + p + '</button>';
    return '<div class="ag-foot"><button class="ag-pg arr" data-pg="' + (page - 1) + '"' + (page <= 1 ? " disabled" : "") + '>' + IC.chevL + '</button>' + nums +
      '<button class="ag-pg arr" data-pg="' + (page + 1) + '"' + (page >= pages ? " disabled" : "") + '>' + IC.chevR + '</button></div>';
  }

  function wireAgents() {
    $("#agCreate", view).addEventListener("click", openForm);
    $$(".ag-card", view).forEach(function (c) { c.addEventListener("click", function (e) {
      if (e.target.closest(".ag-act") || e.target.closest(".ag-status")) return; openDetail(c.getAttribute("data-id"));
    }); });
    $$(".ag-status", view).forEach(function (b) { b.addEventListener("click", function (e) {
      e.stopPropagation(); var a = getA(b.getAttribute("data-id")); a.on = !a.on; save(); render(); toast(a.name + (a.on ? " activated" : " deactivated"));
    }); });
    $$(".ag-act", view).forEach(function (b) { b.addEventListener("click", function (e) { e.stopPropagation(); openActions(b.getAttribute("data-id")); }); });
    $$(".ag-pg[data-pg]", view).forEach(function (b) { b.addEventListener("click", function () { var p = +b.getAttribute("data-pg"); var pages = Math.ceil(agents.length / PP); if (p < 1 || p > pages || p === page) return; page = p; render(); }); });
  }

  /* =========================================================
     ROW ACTIONS
     ========================================================= */
  function openActions(id) {
    var a = getA(id);
    var html = '<div class="ax-grip"></div><div class="ax-sheet-head"><div class="ax-sheet-ttl">' + esc(a.name) + '</div>' +
      '<div class="ax-sheet-sub">' + esc(a.email) + '</div></div><div class="ag-actlist">' +
      actRow("creds", IC.id, "User Credentials") +
      actRow("edit", IC.edit, "Edit") +
      actRow("password", IC.lock, "Change Password") +
      actRow("delete", IC.trash, "Delete", "danger") + '</div>';
    var s = openSheet(html);
    $$("[data-a]", s).forEach(function (b) { b.addEventListener("click", function () { closeSheet(); rowAction(b.getAttribute("data-a"), a); }); });
  }
  function actRow(a, ic, label, cls) { return '<button class="ag-actrow ' + (cls || "") + '" data-a="' + a + '"><span class="ic">' + ic + '</span><span class="t">' + label + '</span></button>'; }
  function rowAction(act, a) {
    if (act === "creds") {
      openSheet('<div class="ax-grip"></div><div class="ax-sheet-head"><div class="ax-sheet-ttl">User Credentials</div></div>' +
        '<div class="ag-creds"><div class="cr"><span class="k">Email</span><span class="v">' + esc(a.email) + '</span></div>' +
        '<div class="cr"><span class="k">Password</span><span class="v mono">••••••••</span></div>' +
        '<div class="cr"><span class="k">Mobile</span><span class="v">' + esc(a.mobile) + '</span></div>' +
        '<div class="cr"><span class="k">Role</span><span class="v">' + esc(a.role || "—") + '</span></div></div>' +
        '<button class="cfg-btn primary" style="width:100%;margin-top:6px" id="crCopy">Copy login link</button>');
      var cb = $("#crCopy"); if (cb) cb.addEventListener("click", function () { closeSheet(); toast("Login link copied"); });
    }
    else if (act === "edit") openForm(a);
    else if (act === "password") {
      openSheet('<div class="ax-grip"></div><div class="ax-sheet-head"><div class="ax-sheet-ttl">Change Password</div><div class="ax-sheet-sub">' + esc(a.name) + '</div></div>' +
        '<div class="ax-field"><label class="ax-label">New Password</label><div class="ax-control">' + IC.lock + '<input id="cpNew" type="password" placeholder="Enter new password"></div></div>' +
        '<div class="ax-field"><label class="ax-label">Confirm Password</label><div class="ax-control">' + IC.lock + '<input id="cpCon" type="password" placeholder="Re-enter password"></div></div>' +
        '<button class="ax-sheetbtn" id="cpSave">Update password</button>');
      $("#cpSave").addEventListener("click", function () {
        var n = $("#cpNew").value, c = $("#cpCon").value;
        if (n.length < 4) { toast("Min 4 characters"); return; } if (n !== c) { toast("Passwords don't match"); return; }
        closeSheet(); toast("Password updated");
      });
    }
    else if (act === "delete") {
      var resp = agentResponsibilities(a);
      var others = agents.filter(function (x) { return x.id !== a.id; });
      if (others.length) openTransfer(a, resp);
      else confirmModal("Delete agent?", "“" + a.name + "” will be permanently removed.", "Delete", function () {
        doDeleteAgent(a); toast("Agent deleted");
      });
    }
  }

  /* ---------- responsibilities + transfer-on-delete ---------- */
  function agentResponsibilities(a) {
    var r = { leads: 0, tickets: 0, appts: 0 };
    function owns(rec, fields) {
      for (var i = 0; i < fields.length; i++) {
        var v = rec[fields[i]];
        if (v != null && v !== "" && (v === a.id || v === a.email || (a.name && v === a.name))) return true;
      }
      return false;
    }
    try { if (window.AskEvaLeads) r.leads = window.AskEvaLeads.filter(function (L) { return owns(L, ["assigned", "assignedTo", "agent", "owner", "agentId"]); }).length; } catch (e) {}
    try { if (window.TK && window.TK.tickets) r.tickets = window.TK.tickets.filter(function (t) { return owns(t, ["assignee", "assigned", "agent", "agentId"]); }).length; } catch (e) {}
    try { if (window.AX && window.AX.appts) r.appts = window.AX.appts.filter(function (x) { return x.status !== "cancelled" && owns(x, ["user", "agent", "assignee", "agentId"]); }).length; } catch (e) {}
    return r;
  }
  function respTotal(r) { return r.leads + r.tickets + r.appts; }
  function doDeleteAgent(a) {
    agents = agents.filter(function (x) { return x.id !== a.id; });
    if (agentCfg[a.id]) { delete agentCfg[a.id]; saveCfgStore(); }
    save(); render();
  }
  function transferResponsibilitiesTo(from, toId) {
    var to = getA(toId); if (!to) return;
    function reassign(rec, fields, newId, newEmail) {
      for (var i = 0; i < fields.length; i++) {
        var f = fields[i], v = rec[f];
        if (v == null || v === "") continue;
        if (v === from.id) { rec[f] = newId; return true; }
        if (v === from.email) { rec[f] = newEmail; return true; }
        if (from.name && v === from.name) { rec[f] = to.name; return true; }
      }
      return false;
    }
    try {
      if (window.AskEvaLeads) {
        var lc = false;
        window.AskEvaLeads.forEach(function (L) { if (reassign(L, ["assigned", "assignedTo", "agent", "owner", "agentId"], to.id, to.email)) lc = true; });
        if (lc && window.AskEvaSaveLeads) window.AskEvaSaveLeads();
        if (lc && window.AskEvaLeadsChanged) window.AskEvaLeadsChanged("update");
      }
    } catch (e) {}
    try {
      if (window.TK && window.TK.tickets) {
        var tc = false;
        window.TK.tickets.forEach(function (t) { if (reassign(t, ["assignee", "assigned", "agent", "agentId"], to.id, to.email)) tc = true; });
        if (tc && window.TK.save) window.TK.save();
      }
    } catch (e) {}
    try {
      if (window.AX && window.AX.appts) {
        var ac = false;
        window.AX.appts.forEach(function (x) { if (reassign(x, ["user", "agent", "assignee", "agentId"], to.id, to.email)) ac = true; });
        if (ac && window.AX.save) window.AX.save();
        if (ac && window.AX.render) try { window.AX.render(); } catch (e) {}
      }
    } catch (e) {}
  }
  function openTransfer(a, resp) {
    if (!cScrim) { cScrim = document.createElement("div"); cScrim.className = "ax-modal-scrim"; host.appendChild(cScrim); cScrim.addEventListener("click", function (e) { if (e.target === cScrim) cScrim.classList.remove("show"); }); }
    var others = agents.filter(function (x) { return x.id !== a.id && x.on !== false; });
    if (!others.length) others = agents.filter(function (x) { return x.id !== a.id; });
    var bits = [];
    if (resp.leads) bits.push(resp.leads + " lead" + (resp.leads > 1 ? "s" : ""));
    if (resp.tickets) bits.push(resp.tickets + " ticket" + (resp.tickets > 1 ? "s" : ""));
    if (resp.appts) bits.push(resp.appts + " appointment" + (resp.appts > 1 ? "s" : ""));
    var has = respTotal(resp) > 0;
    var subTxt = has
      ? "“" + esc(a.name) + "” still has work assigned. Choose another agent to take it over before removing them."
      : "Before removing “" + esc(a.name) + "”, transfer any of their responsibilities to another agent.";
    var goTxt = has ? "Transfer &amp; Delete" : "Transfer &amp; Delete";
    var opts = '<option value="">Select an agent…</option>' + others.map(function (o) { return '<option value="' + o.id + '">' + esc(o.name) + (o.role ? " — " + esc(o.role) : "") + '</option>'; }).join("");
    cScrim.innerHTML = '<div class="ax-modal tr-modal"><div class="mic">' + IC.transfer + '</div>' +
      '<div class="mt">Transfer Responsibilities</div>' +
      '<div class="ms">' + subTxt + '</div>' +
      '<div class="tr-sumrow">' + bits.map(function (b) { return '<span class="tr-chip">' + esc(b) + '</span>'; }).join("") + '</div>' +
      '<label class="tr-lbl">Transfer to</label>' +
      '<div class="tr-dd" id="trDD"><button type="button" class="tr-ddbtn" id="trDDBtn"><span id="trDDLbl">Select an agent…</span>' + IC.chevD + '</button>' +
        '<div class="tr-ddlist" id="trDDList" hidden>' +
          others.map(function (o) { return '<button type="button" class="tr-ddopt" data-id="' + o.id + '"><span class="nm">' + esc(o.name) + '</span>' + (o.role ? '<span class="rl">' + esc(o.role) + '</span>' : "") + '</button>'; }).join("") +
        '</div></div>' +
      '<div class="mb"><button class="keep" id="trKeep">Cancel</button><button class="go" id="trGo">' + goTxt + '</button></div></div>';
    var picked = "";
    var ddBtn = $("#trDDBtn", cScrim), ddList = $("#trDDList", cScrim), ddLbl = $("#trDDLbl", cScrim);
    ddBtn.addEventListener("click", function () { ddList.hidden = !ddList.hidden; ddBtn.classList.toggle("open", !ddList.hidden); });
    $$(".tr-ddopt", cScrim).forEach(function (b) { b.addEventListener("click", function () {
      picked = b.getAttribute("data-id");
      ddLbl.textContent = b.querySelector(".nm").textContent;
      ddLbl.style.color = "var(--ink)";
      $$(".tr-ddopt", cScrim).forEach(function (x) { x.classList.remove("on"); });
      b.classList.add("on");
      ddList.hidden = true; ddBtn.classList.remove("open");
    }); });
    $("#trKeep", cScrim).addEventListener("click", function () { cScrim.classList.remove("show"); });
    $("#trGo", cScrim).addEventListener("click", function () {
      var toId = picked;
      if (!toId) { toast("Select an agent to transfer to"); return; }
      var to = getA(toId);
      transferResponsibilitiesTo(a, toId);
      cScrim.classList.remove("show");
      doDeleteAgent(a);
      toast("Transferred to " + (to ? to.name : "agent") + " · agent deleted");
    });
    requestAnimationFrame(function () { cScrim.classList.add("show"); });
  }

  /* =========================================================
     DETAIL
     ========================================================= */
  var detail = $("#agentDetail");
  var detailId = null, detailTab = "ticketing";
  var DAYS = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"];
  var CALIC = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="5" width="18" height="16" rx="2.5"/><path d="M3 10h18M8 3v4M16 3v4"/></svg>';
  var CLKIC = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></svg>';
  var apptDraft = { uhs: "", uhe: "" };
  function tkDeptNames() { try { if (window.TK && TK.tsetDepts) return TK.tsetDepts().map(function (d) { return d.name; }); } catch (e) {} return depts.slice(); }
  function apptDepts() { try { return (window.AX && AX.DEPTS) ? AX.DEPTS.slice() : []; } catch (e) { return []; } }
  function durOptions(type) { return type === "Minutes" ? ["15 minutes", "30 minutes", "45 minutes"] : ["1 hour", "1.5 hours", "2 hours", "3 hours"]; }

  function openDetail(id) {
    var a = getA(id); if (!a) return;
    detailId = id; detailTab = "ticketing";
    renderDetail();
    detail.classList.add("show");
  }
  function renderDetail() {
    var a = getA(detailId); if (!a) return;
    var c = cfgOf(a.id);
    var T = [["ticketing", "Ticketing", IC.ticketTab], ["leads", "Leads", IC.usersTab], ["appointment", "Appointment", IC.calTab]];
    var body = detailTab === "ticketing" ? ticketingBody(c) : detailTab === "leads" ? leadsBody(c) : appointmentBody(c);
    detail.innerHTML =
      '<div class="set-bar"><button class="iconbtn" data-x="back" aria-label="Back">' + IC.back + '<span>Agents</span></button></div>' +
      '<div class="ax-scroll" style="padding:16px;">' +
        '<div class="adt-tabs">' + T.map(function (t) { return '<button class="adt-tab' + (detailTab === t[0] ? " on" : "") + '" data-t="' + t[0] + '"><span class="ic">' + t[2] + '</span>' + t[1] + '</button>'; }).join("") + '</div>' +
        '<div class="ad-card info"><div class="ad-ttl">Agent Information</div><div class="ad-info">' +
          adKv("Name", a.name) + adKv("Email", a.email) + adKv("Mobile", a.mobile) + adKv("Role", a.role || "—") + '</div></div>' +
        body +
      '</div>';
    $('[data-x="back"]', detail).addEventListener("click", function () { detail.classList.remove("show"); });
    $$(".adt-tab", detail).forEach(function (b) { b.addEventListener("click", function () { detailTab = b.getAttribute("data-t"); renderDetail(); }); });
    if (detailTab === "ticketing") wireTicketing(a, c);
    else if (detailTab === "leads") wireLeads(a, c);
    else wireAppointment(a, c);
  }
  function adField(label, control) { return '<div class="ad-fld"><div class="alc-maplbl"><i>*</i> ' + esc(label) + '</div>' + control + '</div>'; }

  /* ---- Ticketing ---- */
  function ticketingBody(c) {
    var d = c.ticketing.depts;
    return '<div class="ad-card"><div class="adc-hd"><span class="adc-ttl">Ticketing Configuration</span>' +
      '<button class="cfg-btn primary sm" id="tkSave">' + IC.save + 'Save Ticketing Config</button></div>' +
      '<div class="adc-body"><div class="alc-maplbl"><i>*</i> Departments</div>' +
        '<button class="alc-select" id="tkDepts"><span' + (d.length ? "" : ' class="ph"') + '>' + (d.length ? esc(d.join(", ")) : "Select departments") + '</span><span class="cv">' + IC.chevD + '</span></button>' +
        (d.length ? '<div class="adc-chips">' + d.map(function (n) { return '<span class="adc-chip">' + esc(n) + '</span>'; }).join("") + '</div>' : '') +
      '</div></div>';
  }
  function wireTicketing(a, c) {
    $("#tkDepts", detail).addEventListener("click", function () {
      openDeptMulti(c.ticketing.depts, function (sel) { c.ticketing.depts = sel; saveCfgStore(); renderDetail(); });
    });
    $("#tkSave", detail).addEventListener("click", function () { saveCfgStore(); toast("Ticketing config saved"); });
  }

  /* ---- Leads ---- */
  function leadsBody(c) {
    var l = c.leads;
    return '<div class="ad-card"><div class="adc-hd"><span class="adc-ttl">Leads Configuration</span>' +
      '<button class="cfg-btn primary sm" id="ldSave">' + IC.save + 'Save Leads Config</button></div>' +
      '<div class="adc-grid">' +
        adField("Monthly Target", '<input id="ldTarget" class="ad-input" type="number" inputmode="numeric" placeholder="Enter monthly target" value="' + esc(l.target) + '">') +
        adField("New Leads Per Day", '<input id="ldPerDay" class="ad-input" type="number" inputmode="numeric" placeholder="Enter leads per day" value="' + esc(l.perDay) + '">') +
        adField("Work Profession", '<input id="ldProf" class="ad-input" type="text" placeholder="Enter work profession" value="' + esc(l.profession) + '">') +
      '</div></div>';
  }
  function wireLeads(a, c) {
    var t = $("#ldTarget", detail), p = $("#ldPerDay", detail), pr = $("#ldProf", detail);
    if (t) t.addEventListener("input", function () { c.leads.target = t.value; });
    if (p) p.addEventListener("input", function () { c.leads.perDay = p.value; });
    if (pr) pr.addEventListener("input", function () { c.leads.profession = pr.value; });
    $("#ldSave", detail).addEventListener("click", function () { saveCfgStore(); toast("Leads config saved"); });
  }

  /* ---- Appointment (syncs with the Appointments module via AskEvaAgentCfg) ---- */
  function appointmentBody(c) {
    var p = c.appointment, ed = !!p.editing, dis = ed ? "" : " disabled";
    var depName = (apptDepts().filter(function (d) { return d.id === p.dept; })[0] || {}).name || "";
    var udReady = ed && p.ranges.length;
    var uhReady = ed && p.unavailHours.length < 4;
    return '<div class="ad-card"><div class="adc-hd"><span class="adc-ttl">Appointment Configuration</span><div class="adc-hdbtns">' +
        '<button class="cfg-btn primary sm" id="apEdit">' + IC.edit + 'Edit Configuration</button>' +
        '<button class="cfg-btn primary sm" id="apSave"' + (ed ? "" : " disabled") + '>' + IC.save + 'Save Configuration</button></div></div>' +
      '<div class="adc-body">' +
        '<div class="alc-maplbl"><i>*</i> Department</div>' +
        '<button class="alc-select" id="apDept"' + dis + '><span' + (depName ? "" : ' class="ph"') + '>' + (depName ? esc(depName) : "Select department") + '</span><span class="cv">' + IC.chevD + '</span></button>' +

        '<div class="ad-fieldlbl">Available Days</div>' +
        '<div class="ap-days">' + DAYS.map(function (d) { var on = p.days.indexOf(d) > -1; return '<button class="ap-day' + (on ? " on" : "") + '" data-day="' + d + '"' + dis + '><span class="cb">' + (on ? IC.check : "") + '</span>' + d.slice(0, 3) + '</button>'; }).join("") + '</div>' +

        '<div class="ad-fieldlbl">Available Date Ranges</div>' +
        '<button type="button" class="alc-select ap-pick" id="apRangePick"' + dis + '><span class="ph">' + CALIC + 'Select a date range to add</span><span class="cv">' + IC.chevR + '</span></button>' +
        '<div class="ap-current"><b>Current Available Ranges:</b> ' + (p.ranges.length ? p.ranges.map(function (r, i) { return '<span class="ap-chip">' + esc(r.start) + ' \u2192 ' + esc(r.end) + (ed ? ' <button data-rngdel="' + i + '">\u00d7</button>' : "") + '</span>'; }).join("") : '<span class="ph">No date ranges set</span>') + '</div>' +

        '<div class="ad-fieldlbl">Unavailable Dates</div>' +
        '<button type="button" class="alc-select ap-pick" id="apUDPick"' + (udReady ? "" : " disabled") + '><span class="ph">' + CALIC + 'Select an unavailable date to add</span><span class="cv">' + IC.chevR + '</span></button>' +
        '<div class="ap-current">' + (p.ranges.length ? (p.unavailDates.length ? '<b>Unavailable Dates:</b> ' + p.unavailDates.map(function (x, i) { return '<span class="ap-chip">' + esc(x) + (ed ? ' <button data-uddel="' + i + '">\u00d7</button>' : "") + '</span>'; }).join("") : '<span class="ph">No unavailable dates set</span>') : '<span class="ph">Set available date ranges first</span>') + '</div>' +

        '<div class="ad-fieldlbl req">Working Hours</div>' +
        '<div class="ap-row"><button type="button" class="alc-select ap-pick" id="apWS"' + dis + '><span' + (p.workStart ? "" : ' class="ph"') + '>' + CLKIC + (p.workStart ? esc(p.workStart) : 'Start time') + '</span></button><span class="ar">\u2192</span><button type="button" class="alc-select ap-pick" id="apWE"' + dis + '><span' + (p.workEnd ? "" : ' class="ph"') + '>' + CLKIC + (p.workEnd ? esc(p.workEnd) : 'End time') + '</span></button></div>' +
        '<div class="ap-current"><b>Current Working Hours:</b> ' + (p.workStart && p.workEnd ? esc(p.workStart) + ' - ' + esc(p.workEnd) : '<span class="ph">No working hours set</span>') + '</div>' +

        '<div class="ad-fieldlbl">Unavailable Hours <span class="mx">Maximum 4 slots allowed (' + p.unavailHours.length + '/4)</span></div>' +
        '<div class="ap-row"><button type="button" class="alc-select ap-pick" id="apUHS"' + (uhReady ? "" : " disabled") + '><span' + (apptDraft.uhs ? "" : ' class="ph"') + '>' + CLKIC + (apptDraft.uhs ? esc(apptDraft.uhs) : 'Start time') + '</span></button><span class="ar">\u2192</span><button type="button" class="alc-select ap-pick" id="apUHE"' + (uhReady ? "" : " disabled") + '><span' + (apptDraft.uhe ? "" : ' class="ph"') + '>' + CLKIC + (apptDraft.uhe ? esc(apptDraft.uhe) : 'End time') + '</span></button><button class="ap-add" id="apUHAdd"' + (uhReady ? "" : " disabled") + '>+ Add</button></div>' +
        '<div class="ap-current">' + (p.unavailHours.length ? '<b>Unavailable Hours:</b> ' + p.unavailHours.map(function (x, i) { return '<span class="ap-chip">' + esc(x.start) + ' - ' + esc(x.end) + (ed ? ' <button data-uhdel="' + i + '">\u00d7</button>' : "") + '</span>'; }).join("") : '<span class="ph">No unavailable hours set</span>') + '</div>' +

        '<div class="ap-two">' +
          '<div><div class="alc-maplbl"><i>*</i> Slot Duration Type</div><button class="alc-select" id="apSlotType"' + dis + '><span>' + esc(p.slotType || "Hours") + '</span><span class="cv">' + IC.chevD + '</span></button></div>' +
          '<div><div class="alc-maplbl"><i>*</i> Slot Duration</div><button class="alc-select" id="apSlotDur"' + dis + '><span' + (p.slotDur ? "" : ' class="ph"') + '>' + (p.slotDur ? esc(p.slotDur) : "Select duration") + '</span><span class="cv">' + IC.chevD + '</span></button></div>' +
        '</div>' +
        '<div class="ap-two">' +
          '<div><div class="alc-maplbl"><i>*</i> Occupancy per Slot</div><input type="number" id="apOcc" class="ad-input" value="' + esc(p.occupancy || "1") + '"' + dis + '></div>' +
          '<div><div class="alc-maplbl"><i>*</i> Amount per Booking</div><input type="number" id="apAmt" class="ad-input" placeholder="\u20b9 0" value="' + esc(p.amount) + '"' + dis + '></div>' +
        '</div>' +
      '</div></div>';
  }
  function wireAppointment(a, c) {
    var p = c.appointment;
    $("#apEdit", detail).addEventListener("click", function () { p.editing = true; saveCfgStore(); renderDetail(); });
    var sv = $("#apSave", detail); if (sv && !sv.disabled) sv.addEventListener("click", function () { p.editing = false; saveCfgStore(); renderDetail(); toast("Appointment config saved"); });
    var dp = $("#apDept", detail); if (dp && !dp.disabled) dp.addEventListener("click", function () {
      var ds = apptDepts();
      var ADD = "\u002B Add new department";
      radioSheet("Select department", [ADD].concat(ds.map(function (d) { return d.name; })), (ds.filter(function (d) { return d.id === p.dept; })[0] || {}).name || "", function (v) {
        if (v === ADD) {
          promptText("New department", "Department name", function (name) {
            if (!(window.AX && AX.addDept)) { toast("Unavailable"); return; }
            var nd = AX.addDept(name); if (!nd) { toast("Enter a valid name"); return; }
            p.dept = nd.id; saveCfgStore(); renderDetail(); toast("Department added");
          });
          return;
        }
        var hit = apptDepts().filter(function (d) { return d.name === v; })[0]; p.dept = hit ? hit.id : ""; saveCfgStore(); renderDetail();
      });
    });
    $$(".ap-day:not([disabled])", detail).forEach(function (b) { b.addEventListener("click", function () { var d = b.getAttribute("data-day"), i = p.days.indexOf(d); if (i > -1) p.days.splice(i, 1); else p.days.push(d); saveCfgStore(); renderDetail(); }); });
    var rp = $("#apRangePick", detail); if (rp && !rp.disabled) rp.addEventListener("click", function () {
      if (!(window.AskEvaPicker && AskEvaPicker.dateRange)) { toast("Picker unavailable"); return; }
      AskEvaPicker.dateRange({ start: "", end: "", onApply: function (r) { if (!r.start) return; p.ranges.push({ start: r.start, end: r.end || r.start }); saveCfgStore(); renderDetail(); } });
    });
    $$("[data-rngdel]", detail).forEach(function (b) { b.addEventListener("click", function () { p.ranges.splice(+b.getAttribute("data-rngdel"), 1); saveCfgStore(); renderDetail(); }); });
    var up = $("#apUDPick", detail); if (up && !up.disabled) up.addEventListener("click", function () {
      if (!(window.AskEvaPicker && AskEvaPicker.singleDate)) { toast("Picker unavailable"); return; }
      AskEvaPicker.singleDate({ title: "Unavailable date", onPick: function (o) { p.unavailDates.push(o.date); saveCfgStore(); renderDetail(); } });
    });
    $$("[data-uddel]", detail).forEach(function (b) { b.addEventListener("click", function () { p.unavailDates.splice(+b.getAttribute("data-uddel"), 1); saveCfgStore(); renderDetail(); }); });
    var ws = $("#apWS", detail), we = $("#apWE", detail);
    if (ws && !ws.disabled) ws.addEventListener("click", function () { AskEvaPicker.timeOnly({ title: "Start time", value: p.workStart || "09:00", onPick: function (o) { p.workStart = o.time; saveCfgStore(); renderDetail(); } }); });
    if (we && !we.disabled) we.addEventListener("click", function () { AskEvaPicker.timeOnly({ title: "End time", value: p.workEnd || "18:00", onPick: function (o) { p.workEnd = o.time; saveCfgStore(); renderDetail(); } }); });
    var uhs = $("#apUHS", detail); if (uhs && !uhs.disabled) uhs.addEventListener("click", function () { AskEvaPicker.timeOnly({ title: "Start time", value: apptDraft.uhs || "09:00", onPick: function (o) { apptDraft.uhs = o.time; renderDetail(); } }); });
    var uhe = $("#apUHE", detail); if (uhe && !uhe.disabled) uhe.addEventListener("click", function () { AskEvaPicker.timeOnly({ title: "End time", value: apptDraft.uhe || "10:00", onPick: function (o) { apptDraft.uhe = o.time; renderDetail(); } }); });
    var uha = $("#apUHAdd", detail); if (uha && !uha.disabled) uha.addEventListener("click", function () { if (!apptDraft.uhs || !apptDraft.uhe) { toast("Pick start and end times"); return; } if (p.unavailHours.length >= 4) { toast("Maximum 4 slots"); return; } p.unavailHours.push({ start: apptDraft.uhs, end: apptDraft.uhe }); apptDraft.uhs = ""; apptDraft.uhe = ""; saveCfgStore(); renderDetail(); });
    $$("[data-uhdel]", detail).forEach(function (b) { b.addEventListener("click", function () { p.unavailHours.splice(+b.getAttribute("data-uhdel"), 1); saveCfgStore(); renderDetail(); }); });
    var st = $("#apSlotType", detail); if (st && !st.disabled) st.addEventListener("click", function () { radioSheet("Slot Duration Type", ["Hours", "Minutes"], p.slotType || "Hours", function (v) { p.slotType = v; p.slotDur = ""; saveCfgStore(); renderDetail(); }); });
    var sd = $("#apSlotDur", detail); if (sd && !sd.disabled) sd.addEventListener("click", function () { radioSheet("Slot Duration", durOptions(p.slotType || "Hours"), p.slotDur, function (v) { p.slotDur = v; saveCfgStore(); renderDetail(); }); });
    var oc = $("#apOcc", detail); if (oc && !oc.disabled) oc.addEventListener("input", function () { p.occupancy = oc.value; });
    var am = $("#apAmt", detail); if (am && !am.disabled) am.addEventListener("input", function () { p.amount = am.value; });
  }

  function openDeptMulti(sel, onDone) {
    var names = tkDeptNames(), chosen = sel.slice();
    var html = '<div class="ax-grip"></div><div class="ax-sheet-head"><div class="ax-sheet-ttl">Select departments</div></div>' +
      '<button class="ad-chk ad-adddept" id="dmAdd"><span class="cb">' + IC.userPlus + '</span>Add new department</button>' +
      '<div class="ax-reasons">' +
      names.map(function (n) { return '<button class="ad-chk' + (chosen.indexOf(n) > -1 ? " on" : "") + '" data-n="' + esc(n) + '"><span class="cb">' + (chosen.indexOf(n) > -1 ? IC.check : "") + '</span>' + esc(n) + '</button>'; }).join("") +
      '</div>' +
      '<button class="ax-sheetbtn" id="dmDone">Done</button>';
    var s = openSheet(html);
    $$(".ad-chk:not(.ad-adddept)", s).forEach(function (b) { b.addEventListener("click", function () { var n = b.getAttribute("data-n"), i = chosen.indexOf(n); if (i > -1) chosen.splice(i, 1); else chosen.push(n); b.classList.toggle("on"); b.querySelector(".cb").innerHTML = chosen.indexOf(n) > -1 ? IC.check : ""; }); });
    $("#dmAdd", s).addEventListener("click", function () {
      promptText("New department", "Department name", function (name) {
        var ok = false;
        try { if (window.TK && window.TK.tsetAddDept) ok = window.TK.tsetAddDept(name); } catch (e) {}
        if (!ok) { toast("Couldn't add (maybe a duplicate)"); return; }
        if (chosen.indexOf(name) < 0) chosen.push(name);
        onDone(chosen); toast("Department added");
      });
    });
    $("#dmDone", s).addEventListener("click", function () { closeSheet(); onDone(chosen); });
  }
  function adKv(k, v) { return '<div class="kv"><span class="k">' + k + ':</span><span class="v">' + esc(v) + '</span></div>'; }
  /* role permission summary (reflects the master Role Configuration) */
  function rolePermCard(a) {
    if (!window.AskEvaRoles) return "";
    var sum = window.AskEvaRoles.summary(a.role), total = window.AskEvaRoles.permCount(a.role), active = window.AskEvaRoles.isActive(a.role);
    var chips = sum.length ? '<div class="ad-permgrid">' + sum.map(function (s) {
      return '<span class="ad-permchip"><span class="ic">' + s.icon + '</span>' + esc(s.name) + '<b>' + s.sel + '/' + s.total + '</b></span>';
    }).join("") + '</div>' : '<div class="ad-empty">No permissions granted to this role.</div>';
    return '<div class="ad-card"><div class="ad-ttl">Role Permissions</div>' +
      '<div class="ad-permhd"><span class="rc2-perm">' + total + ' permission' + (total === 1 ? "" : "s") + '</span>' +
      (active ? '' : '<span class="rc2-inactive">Role inactive</span>') + '</div>' + chips + '</div>';
  }

  /* =========================================================
     CREATE / EDIT FORM
     ========================================================= */
  var formEl = $("#agentForm");
  function openForm(existing) {
    var edit = existing && existing.id;
    var d = edit ? { name: existing.name, email: existing.email, pw: "", mobile: existing.mobile.replace(/^91/, ""), role: existing.role, partial: existing.mods.length > 0 && existing.mods.length < 4, mods: existing.mods.slice() }
      : { name: "", email: "", pw: "", mobile: "", role: "", partial: false, mods: [] };
    function body() {
      return '<div class="ax-bar"><button class="ax-iconbtn" data-x="close">' + IC.x + '</button><div class="ttl">' + (edit ? "Edit Agent" : "Create New Agent") + '</div><span class="spacer"></span></div>' +
        '<div class="ax-scroll">' +
          field("Name", true, '<div class="ax-control">' + IC.user + '<input id="afName" type="text" placeholder="Enter name" value="' + esc(d.name) + '"></div>') +
          field("Email", true, '<div class="ax-control">' + IC.mail + '<input id="afEmail" type="email" placeholder="Enter email" value="' + esc(d.email) + '"></div>') +
          field("Password", !edit, '<div class="ax-control"><span class="ag-lockic">' + IC.lock + '</span><input id="afPw" type="password" placeholder="' + (edit ? "Leave blank to keep" : "Enter password") + '"><button class="ag-eye" id="afEye" type="button">' + IC.eye + '</button></div>') +
          field("Mobile Number", true, '<div class="ax-control"><span class="nf-cc">+91</span><input id="afMob" type="tel" placeholder="Enter 10 digit number" value="' + esc(d.mobile) + '"></div>') +
          field("Role", true, '<button class="nf-select' + (d.role ? "" : " ph") + '" id="afRole"><span class="v">' + esc(d.role || "Select role") + '</span><span class="cv">' + IC.chevD + '</span></button>') +
          '<label class="ag-partial" id="afPartialRow"><span class="cb' + (d.partial ? " on" : "") + '" id="afPartial">' + (d.partial ? IC.check : "") + '</span>Partial Access<span class="help" title="Grant access to specific modules only">' + IC.help + '</span></label>' +
          (d.partial ? '<div class="ag-modpick" id="afMods">' + MODS.map(function (m) { return '<button class="ag-modchk' + (d.mods.indexOf(m[0]) > -1 ? " on" : "") + '" data-m="' + m[0] + '"><span class="cb">' + (d.mods.indexOf(m[0]) > -1 ? IC.check : "") + '</span>' + m[1] + '</button>'; }).join("") + '</div>' : '') +
        '</div>' +
        '<div class="ax-savebar two"><button class="ax-btn ghost" data-x="close">Cancel</button><button class="ax-btn primary" id="afCreate">' + IC.check + (edit ? "Save" : "Create") + '</button></div>';
    }
    function bind() {
      $$('[data-x="close"]', formEl).forEach(function (b) { b.addEventListener("click", function () { formEl.classList.remove("show"); }); });
      bindIn("afName", function (v) { d.name = v; }); bindIn("afEmail", function (v) { d.email = v; });
      bindIn("afPw", function (v) { d.pw = v; }); bindIn("afMob", function (v) { d.mobile = v.replace(/\D/g, "").slice(0, 10); });
      var eye = $("#afEye", formEl); if (eye) eye.addEventListener("click", function () { var i = $("#afPw", formEl); i.type = i.type === "password" ? "text" : "password"; });
      $("#afRole", formEl).addEventListener("click", function () {
        var rs = (window.AskEvaRoles && window.AskEvaRoles.activeNames().length) ? window.AskEvaRoles.activeNames() : roles();
        if (rs.indexOf("admin") < 0) rs.unshift("admin"); if (rs.indexOf("agent") < 0) rs.push("agent");
        radioSheet("Select role", rs, d.role, function (v) { d.role = v; formEl.innerHTML = body(); bind(); });
      });
      $("#afPartial", formEl).addEventListener("click", function () { d.partial = !d.partial; if (!d.partial) d.mods = []; formEl.innerHTML = body(); bind(); });
      $$("#afMods .ag-modchk", formEl).forEach(function (b) { b.addEventListener("click", function () {
        var m = b.getAttribute("data-m"), i = d.mods.indexOf(m); if (i > -1) d.mods.splice(i, 1); else d.mods.push(m); formEl.innerHTML = body(); bind();
      }); });
      $("#afCreate", formEl).addEventListener("click", function () {
        if (!d.name.trim()) { toast("Enter a name"); return; }
        if (!/\S+@\S+\.\S+/.test(d.email)) { toast("Enter a valid email"); return; }
        if (!edit && d.pw.length < 4) { toast("Password min 4 chars"); return; }
        if (d.mobile.length < 10) { toast("Enter 10-digit number"); return; }
        if (!d.role) { toast("Select a role"); return; }
        // reject duplicates — email or mobile already in use by another agent
        var emailLc = d.email.trim().toLowerCase();
        var mob91 = "91" + d.mobile;
        var dupEmail = agents.some(function (a) { return a.id !== (edit ? existing.id : null) && (a.email || "").trim().toLowerCase() === emailLc; });
        if (dupEmail) { toast("This email is already in use"); var ef = $("#afEmail", formEl); if (ef) { ef.focus(); } return; }
        var dupMob = agents.some(function (a) { return a.id !== (edit ? existing.id : null) && (a.mobile || "") === mob91; });
        if (dupMob) { toast("This mobile number is already in use"); var mf = $("#afMob", formEl); if (mf) { mf.focus(); } return; }
        var mods = d.partial ? d.mods.slice() : roleMods(d.role);
        if (edit) { existing.name = d.name.trim(); existing.email = d.email.trim(); existing.mobile = "91" + d.mobile; existing.role = d.role; existing.mods = mods; }
        else { agents.unshift({ id: "a" + Date.now().toString(36), name: d.name.trim(), email: d.email.trim(), mobile: "91" + d.mobile, role: d.role, mods: mods, on: true }); page = 1; }
        save(); formEl.classList.remove("show"); render(); toast(edit ? "Agent updated" : "Agent created");
      });
    }
    formEl.innerHTML = body(); bind(); formEl.classList.add("show");
  }
  function field(label, req, control) { return '<div class="ax-field"><label class="ax-label">' + esc(label) + (req ? '<span class="nf-req">*</span>' : '') + '</label>' + control + '</div>'; }
  function bindIn(id, cb) { var el = $("#" + id, formEl); if (el) el.addEventListener("input", function (e) { cb(e.target.value); }); }

  /* =========================================================
     ROLE CONFIGURATION TAB  → delegated to AskEvaRoles (settings-roles.js)
     ========================================================= */
  function rolesTab() {
    return '<div id="rcRoot"></div>' + (window.AskEvaRoles ? "" : '<div class="ad-empty">Role configuration unavailable.</div>');
  }
  function wireRoles() {
    if (window.AskEvaRoles) window.AskEvaRoles.renderTab($("#rcRoot", view));
  }
  /* module access (chat|leads|appt|ticket) derived from the role's permissions */
  function roleMods(role) {
    if (window.AskEvaRoles) { var m = window.AskEvaRoles.modsFor(role); if (m && m.length) return m; }
    var r = (role || "").toLowerCase();
    return (r === "admin" || r.indexOf("super") > -1) ? ALL.slice() : (r === "agent" ? ["chat", "leads", "ticket"] : ["chat"]);
  }

  /* =========================================================
     sheet + modal primitives (scoped to settings pane)
     ========================================================= */
  var scrim, sheet, host = document.getElementById("app-settings");
  function ensureSheet() { if (scrim) return; scrim = document.createElement("div"); scrim.className = "ax-scrim"; sheet = document.createElement("div"); sheet.className = "ax-sheet"; scrim.addEventListener("click", closeSheet); host.appendChild(scrim); host.appendChild(sheet); }
  function openSheet(html) { ensureSheet(); sheet.innerHTML = html; sheet.scrollTop = 0; requestAnimationFrame(function () { scrim.classList.add("show"); sheet.classList.add("show"); }); return sheet; }
  function closeSheet() { if (sheet) { scrim.classList.remove("show"); sheet.classList.remove("show"); } }
  function radioSheet(title, opts, cur, onPick) {
    var html = '<div class="ax-grip"></div><div class="ax-sheet-head"><div class="ax-sheet-ttl">' + esc(title) + '</div></div><div class="ax-reasons">' +
      opts.map(function (o) { return '<button class="ax-reason' + (cur === o ? " on" : "") + '" data-v="' + esc(o) + '">' + esc(o) + '</button>'; }).join("") + '</div>';
    var s = openSheet(html);
    $$(".ax-reason", s).forEach(function (b) { b.addEventListener("click", function () { closeSheet(); onPick(b.getAttribute("data-v")); }); });
  }
  function promptText(title, ph, onDone) {
    var html = '<div class="ax-grip"></div><div class="ax-sheet-head"><div class="ax-sheet-ttl">' + esc(title) + '</div></div>' +
      '<div class="ax-field"><div class="ax-control">' + IC.edit + '<input id="ptIn" type="text" placeholder="' + esc(ph || "") + '" autocomplete="off"></div></div>' +
      '<button class="ax-sheetbtn" id="ptDone">Add</button>';
    var s = openSheet(html);
    var inp = $("#ptIn", s); if (inp) setTimeout(function () { inp.focus(); }, 80);
    $("#ptDone", s).addEventListener("click", function () { var v = (inp && inp.value || "").trim(); if (!v) { toast("Enter a name"); return; } closeSheet(); onDone(v); });
  }
  var cScrim, onGo;
  function confirmModal(title, sub, go, cb) {
    if (!cScrim) { cScrim = document.createElement("div"); cScrim.className = "ax-modal-scrim"; host.appendChild(cScrim); cScrim.addEventListener("click", function (e) { if (e.target === cScrim) cScrim.classList.remove("show"); }); }
    cScrim.innerHTML = '<div class="ax-modal"><div class="mic">' + IC.warn + '</div><div class="mt">' + esc(title) + '</div><div class="ms">' + esc(sub) + '</div><div class="mb"><button class="keep" id="agKeep">Keep</button><button class="go" id="agGo">' + esc(go) + '</button></div></div>';
    onGo = cb;
    $("#agKeep", cScrim).addEventListener("click", function () { cScrim.classList.remove("show"); });
    $("#agGo", cScrim).addEventListener("click", function () { cScrim.classList.remove("show"); if (onGo) onGo(); });
    requestAnimationFrame(function () { cScrim.classList.add("show"); });
  }

  /* icons */
  var IC = {
    back: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M15 18l-6-6 6-6"/></svg>',
    x: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"><path d="M6 6l12 12M18 6 6 18"/></svg>',
    dots: '<svg viewBox="0 0 24 24" fill="currentColor"><circle cx="12" cy="5" r="2"/><circle cx="12" cy="12" r="2"/><circle cx="12" cy="19" r="2"/></svg>',
    chevL: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m15 6-6 6 6 6"/></svg>',
    chevR: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m9 6 6 6-6 6"/></svg>',
    chevD: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m6 9 6 6 6-6"/></svg>',
    userPlus: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="9" cy="8" r="3.4"/><path d="M3 20c0-3.2 2.7-5 6-5 1 0 1.9.15 2.7.43"/><path d="M17 14v6M14 17h6"/></svg>',
    user: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="8" r="4"/><path d="M4 21c0-4 3.6-6 8-6s8 2 8 6"/></svg>',
    mail: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="5" width="18" height="14" rx="2.5"/><path d="m3 7 9 6 9-6"/></svg>',
    lock: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="5" y="10" width="14" height="10" rx="2.5"/><path d="M8 10V7a4 4 0 0 1 8 0v3"/></svg>',
    eye: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7-10-7-10-7Z"/><circle cx="12" cy="12" r="3"/></svg>',
    edit: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M11 4H5a2 2 0 0 0-2 2v13a2 2 0 0 0 2 2h13a2 2 0 0 0 2-2v-6"/><path d="M18.5 2.5a2.12 2.12 0 0 1 3 3L12 15l-4 1 1-4Z"/></svg>',
    trash: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 7h16M9 7V5a2 2 0 0 1 2-2h2a2 2 0 0 1 2 2v2M6 7l1 13a2 2 0 0 0 2 2h6a2 2 0 0 0 2-2l1-13"/></svg>',
    id: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="5" width="18" height="14" rx="2.5"/><circle cx="8.5" cy="11" r="2"/><path d="M5.5 16c.4-1.4 1.6-2 3-2s2.6.6 3 2M14 9h4M14 13h3"/></svg>',
    check: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="m5 12 4 4 10-11"/></svg>',
    help: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="M9.5 9a2.5 2.5 0 1 1 3.5 2.3c-.7.4-1 .8-1 1.7M12 17h.01"/></svg>',
    warn: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 9v4M12 17h.01"/><path d="M10.3 3.9 2 19a2 2 0 0 0 1.7 3h16.6a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0Z"/></svg>',
    save: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M5 4h11l3 3v13H5z"/><path d="M8 4v5h6V4M8 20v-6h8v6"/></svg>',
    transfer: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M16 3l4 4-4 4"/><path d="M20 7H8a4 4 0 0 0-4 4v0"/><path d="M8 21l-4-4 4-4"/><path d="M4 17h12a4 4 0 0 0 4-4v0"/></svg>',
    ticketTab: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 9a2 2 0 0 1 2-2h12a2 2 0 0 1 2 2v1.5a1.5 1.5 0 0 0 0 3V15a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2v-1.5a1.5 1.5 0 0 0 0-3Z"/><path d="M14 7v10"/></svg>',
    usersTab: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="9" cy="8" r="3.2"/><path d="M3 20c0-3.2 2.7-5 6-5s6 1.8 6 5"/><path d="M16 5.5a3 3 0 0 1 0 5M21 20c0-2.5-1.5-4-3.5-4.6"/></svg>',
    calTab: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="5" width="18" height="16" rx="2.5"/><path d="M3 10h18M8 3v4M16 3v4"/></svg>'
  };

  render();
  window.__agents = { render: render };

  /* master control: when a role's permissions change, propagate the derived
     module access to every agent holding that role (keeps rosters in sync). */
  if (window.AskEvaRoles && window.AskEvaRoles.on) window.AskEvaRoles.on(function () {
    var changed = false;
    agents.forEach(function (a) {
      if (window.AskEvaRoles.get(a.role)) { var m = roleMods(a.role); if (m.join(",") !== (a.mods || []).join(",")) { a.mods = m; changed = true; } }
    });
    if (changed) { try { localStorage.setItem(AK, JSON.stringify(agents)); } catch (e) {} emit(); if (tab === "agents") render(); }
  });

  /* ---------- PUBLIC PEOPLE API — single source of truth for Team + Agents ---------- */
  function deriveMods(role) { return roleMods(role); }
  /* enrich a stored agent with display fields (color/initials/you) for module pickers */
  var PALETTE = ["#2BA84A", "#7C5CFF", "#FF9416", "#1E7FB0", "#E5499A", "#E0541F", "#3BA4DD", "#2563EB", "#16A34A", "#DB4324"];
  function colorOf(a) { if (a.color) return a.color; var s = a.id || a.name || "", h = 0; for (var i = 0; i < s.length; i++) h = (h * 31 + s.charCodeAt(i)) >>> 0; return PALETTE[h % PALETTE.length]; }
  function initialsOf(name) { var p = (name || "").trim().split(/\s+/); var s = ((p[0] || "")[0] || "") + ((p[1] || "")[0] || ""); return (s || (name || "?").charAt(0) || "?").toUpperCase(); }
  function enrich(a) { return { id: a.id, name: a.name, email: a.email, role: a.role, mods: a.mods, on: a.on, color: colorOf(a), initials: initialsOf(a.name), you: a.id === "eshan" }; }
  window.AskEvaPeople = {
    list: function () { return agents; },
    get: getA,
    /* enriched, active people for module pickers/filters — optionally gated to a
       module key (chat|leads|appt|ticket). Always returns plain display objects. */
    roster: function (moduleKey) {
      return agents.filter(function (a) {
        return a.on !== false && (!moduleKey || !Array.isArray(a.mods) || a.mods.indexOf(moduleKey) > -1);
      }).map(enrich);
    },
    byId: function (id) { var a = getA(id); return a ? enrich(a) : null; },
    emails: function (moduleKey) { return this.roster(moduleKey).map(function (a) { return a.email; }).filter(Boolean); },
    departments: function () { return depts; },
    roleList: function () {
      if (window.AskEvaRoles && window.AskEvaRoles.names().length) return window.AskEvaRoles.names();
      var rs = roles(); ["admin", "agent"].forEach(function (r) { if (rs.indexOf(r) < 0) rs.push(r); }); return rs;
    },
    add: function (p) {
      var a = { id: "a" + Date.now().toString(36), name: (p.name || "").trim(), email: (p.email || "").trim(),
        mobile: p.mobile || "", role: p.role || "agent", dept: p.dept || "", mods: (p.mods && p.mods.length) ? p.mods.slice() : deriveMods(p.role), on: p.on !== false };
      agents.unshift(a); page = 1; save(); render(); return a;
    },
    update: function (id, patch) { var a = getA(id); if (!a) return null; Object.keys(patch || {}).forEach(function (k) { a[k] = patch[k]; }); save(); render(); return a; },
    remove: function (id) { agents = agents.filter(function (x) { return x.id !== id; }); save(); render(); },
    setActive: function (id, on) { var a = getA(id); if (!a) return; a.on = (on === undefined ? !a.on : !!on); save(); render(); return a.on; },
    addDept: function (name) { name = (name || "").trim(); if (!name) return false; if (depts.some(function (d) { return d.toLowerCase() === name.toLowerCase(); })) return false; depts.push(name); saveDepts(); return true; },
    on: function (cb) { document.addEventListener("people:changed", cb); }
  };

  /* ---------- agent config bridge — Appointments reads this to scope users to a department ---------- */
  window.AskEvaAgentCfg = {
    get: function (id) { return agentCfg[id] || null; },
    apptDeptOf: function (id) { var c = agentCfg[id]; return (c && c.appointment) ? c.appointment.dept : ""; },
    usersForApptDept: function (deptId) {
      return agents.filter(function (a) { var c = agentCfg[a.id]; return a.on !== false && c && c.appointment && c.appointment.dept === deptId; }).map(enrich);
    },
    ticketDeptsOf: function (id) { var c = agentCfg[id]; return (c && c.ticketing && c.ticketing.depts) ? c.ticketing.depts.slice() : []; },
    usersForTicketDept: function (deptName) {
      return agents.filter(function (a) {
        var c = agentCfg[a.id];
        return a.on !== false && (a.mods || []).indexOf("ticket") > -1 &&
          c && c.ticketing && c.ticketing.depts && c.ticketing.depts.indexOf(deptName) > -1;
      }).map(enrich);
    }
  };
})();
