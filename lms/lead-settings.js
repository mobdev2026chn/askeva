/* =========================================================
   AskEva — Lead Settings (Lead Configuration)
   Tabs: Reminders · Settings · Webhook · Quick Reply.
   Owns #app-leadsettings.
   ========================================================= */
(function () {
  "use strict";
  var $ = function (s, r) { return (r || document).querySelector(s); };
  var $$ = function (s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); };
  function esc(s) { return String(s == null ? "" : s).replace(/[&<>"]/g, function (c) { return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]; }); }
  var pane = document.getElementById("app-leadsettings");
  if (!pane) return;

  var toastT;
  function toast(msg) {
    var t = document.getElementById("toast"); if (!t) return;
    t.textContent = msg; t.style.opacity = "1"; t.style.transform = "translateX(-50%) translateY(0)";
    clearTimeout(toastT); toastT = setTimeout(function () { t.style.opacity = "0"; t.style.transform = "translateX(-50%) translateY(20px)"; }, 1800);
  }

  var I = {
    bell: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 9a6 6 0 0 1 12 0c0 4 1.5 5 2 6H4c.5-1 2-2 2-6Z"/><path d="M10 19a2 2 0 0 0 4 0"/></svg>',
    gear: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.6 1.6 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.6 1.6 0 0 0-2.7 1.1V21a2 2 0 0 1-4 0v-.2A1.6 1.6 0 0 0 7 19.4l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1A1.6 1.6 0 0 0 4.6 15H4a2 2 0 0 1 0-4h.2A1.6 1.6 0 0 0 5.6 8L5.5 8a2 2 0 1 1 2.8-2.9l.1.1A1.6 1.6 0 0 0 11 4.6V4a2 2 0 0 1 4 0v.2a1.6 1.6 0 0 0 2.7 1.1l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.6 1.6 0 0 0-.3 1.8v.1a1.6 1.6 0 0 0 1.5 1H21a2 2 0 0 1 0 4h-.2a1.6 1.6 0 0 0-1.4 1Z"/></svg>',
    link: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M10 13a5 5 0 0 0 7 0l3-3a5 5 0 0 0-7-7l-1.5 1.5"/><path d="M14 11a5 5 0 0 0-7 0l-3 3a5 5 0 0 0 7 7l1.5-1.5"/></svg>',
    chat: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14 9a2 2 0 0 1-2 2H6l-4 4V4c0-1.1.9-2 2-2h8a2 2 0 0 1 2 2v5Z"/><path d="M18 9h2a2 2 0 0 1 2 2v11l-4-4h-6a2 2 0 0 1-2-2v-1"/><circle cx="5.2" cy="6.4" r=".7" fill="currentColor" stroke="none"/><circle cx="8" cy="6.4" r=".7" fill="currentColor" stroke="none"/><circle cx="10.8" cy="6.4" r=".7" fill="currentColor" stroke="none"/></svg>',
    cal: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="5" width="18" height="16" rx="2.5"/><path d="M3 10h18M8 3v4M16 3v4"/></svg>',
    calclock: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 11V7a2 2 0 0 0-2-2H5a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h7M3 10h18M8 3v4M16 3v4"/><circle cx="18" cy="17" r="4"/><path d="M18 15.5V17l1 1"/></svg>',
    cloud: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M7 18a4 4 0 0 1 0-8 6 6 0 0 1 11.3 2A3.5 3.5 0 0 1 18 18Z"/><path d="M12 13v6m0-6 2.5 2.5M12 13l-2.5 2.5"/></svg>',
    trash: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 7h16M9 7V5h6v2M6 7l1 13h10l1-13"/></svg>',
    edit: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M11 4H5a2 2 0 0 0-2 2v13a2 2 0 0 0 2 2h13a2 2 0 0 0 2-2v-6"/><path d="M18.5 2.5a2.12 2.12 0 0 1 3 3L12 15l-4 1 1-4Z"/></svg>',
    x: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M18 6 6 18M6 6l12 12"/></svg>',
    plus: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round"><path d="M12 5v14M5 12h14"/></svg>',
    refresh: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 12a9 9 0 0 1-15 6.7L3 16M3 12a9 9 0 0 1 15-6.7L21 8"/><path d="M21 3v5h-5M3 21v-5h5"/></svg>',
    menu: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"><path d="M4 7h16M4 12h16M4 17h16"/></svg>'
  };

  /* ---------- state ---------- */
  var reminders = { business: true, newlead: true };
  var settingsSub = "fields";
  var FIELDS = (window.AskEvaLeadFields && window.AskEvaLeadFields.list()) || [
    { n: "Name", t: "Input", disp: true, mand: true, lock: true },
    { n: "Company", t: "Input", disp: true, mand: false, lock: true },
    { n: "Email", t: "Input", disp: true, mand: false, lock: true },
    { n: "Status", t: "Select", disp: true, mand: true, lock: true },
    { n: "Source", t: "Select", disp: true, mand: true, lock: true },
    { n: "Assigned", t: "Select", disp: true, mand: true, lock: true },
    { n: "Position", t: "Input", disp: true, mand: false },
    { n: "Country Code", t: "Input", disp: true, mand: true },
    { n: "Mobile", t: "Input", disp: true, mand: true, lock: true },
    { n: "Product", t: "Select", disp: false, mand: false },
    { n: "Address", t: "Textarea", disp: true, mand: false },
    { n: "City", t: "Input", disp: true, mand: false },
    { n: "Country", t: "Input", disp: true, mand: false },
    { n: "Website", t: "Input", disp: true, mand: false },
    { n: "Lead Value", t: "Input", disp: true, mand: false },
    { n: "Tags", t: "Input", disp: true, mand: false },
    { n: "Description", t: "Textarea", disp: true, mand: false }
  ];
  /* core (system) fields can never be deleted; the mandatory-core ones can't be
     toggled off either. Anything the user adds is "custom" and fully removable. */
  var CORE_FIELDS = ["Name", "Company", "Email", "Status", "Source", "Assigned", "Position", "Country Code", "Mobile", "Product", "Address", "City", "Country", "Website", "Lead Value", "Tags", "Description"];
  var MAND_LOCK = ["Name", "Status", "Source", "Assigned", "Mobile", "Country Code"];
  function isCore(f) { return !f.custom && (f.lock || CORE_FIELDS.indexOf(f.n) > -1); }
  function reqLocked(f) { return MAND_LOCK.indexOf(f.n) > -1; }
  /* field-type helpers — "Dropdown" and the legacy "Select" are the same thing */
  function isDropdownType(t) { return t === "Dropdown" || t === "Select"; }
  function typeLabel(t) { return isDropdownType(t) ? "Dropdown" : (t === "Textarea" ? "Text Area" : "Input"); }
  var DROPDOWNS = [
    { n: "Status", opts: ["New", "Hot", "Warm", "Cold", "Customer"] },
    { n: "Source", opts: ["Import", "Chat-Sync", "User Initiated - Whatsapp", "Website", "Referral", "Manual"] },
    { n: "Assigned", opts: ["testerr@gmail.com", "eshan@tunepath.com"] },
    { n: "Product", opts: [] }
  ];
  var QR = (window.AskEvaQuickReplies && window.AskEvaQuickReplies.list()) || [
    { t: "test", m: "testingggghhh" },
    { t: "TESTING", m: "Testingghhhhhh" },
    { t: "askeva", m: "testing" },
    { t: "Exam", m: "Questions" }
  ];
  function qrPersist() { if (window.AskEvaQuickReplies) window.AskEvaQuickReplies.save(); }
  var webhook = { editing: false };
  var fieldSearch = "";

  /* ---------- scaffold ---------- */
  var TABS = [
    { k: "reminders", l: "Reminders", i: I.bell },
    { k: "settings", l: "Configuration", i: I.gear },
    { k: "webhook", l: "Webhook", i: I.link },
    { k: "quick", l: "Quick Reply", i: I.chat }
  ];
  pane.innerHTML =
    '<div class="lx-head">' +
      '<div class="lx-topbar">' +
        '<button class="lx-iconbtn" aria-label="Menu">' + I.menu + '</button>' +
        '<div class="lx-title">Lead Configuration</div>' +
        '<span class="lx-iconbtn" aria-hidden="true" style="visibility:hidden"></span>' +
      '</div>' +
      '<div class="lx-tabs">' + TABS.map(function (t, i) {
        return '<button class="lx-tab' + (i === 0 ? " active" : "") + '" data-lst="' + t.k + '">' + t.i + t.l + '</button>';
      }).join("") + '</div>' +
    '</div>' +
    '<div class="lx-sheet" id="lsBody"></div>';
  var body = $("#lsBody", pane);
  var active = "reminders";

  /* ---------- bottom sheet (quick reply form) ---------- */
  var scrim = document.createElement("div"); scrim.className = "lx-scrim";
  var sheet = document.createElement("div"); sheet.className = "lx-sheetpop";
  pane.appendChild(scrim); pane.appendChild(sheet);
  scrim.addEventListener("click", closeSheet);
  function openSheet(html) { sheet.innerHTML = '<div class="lx-grip"></div>' + html; requestAnimationFrame(function () { scrim.classList.add("show"); sheet.classList.add("show"); }); }
  function closeSheet() { scrim.classList.remove("show"); sheet.classList.remove("show"); }

  /* ---------- confirm-before-delete modal (shared by every Lead-settings delete) ---------- */
  var cScrim, cOnGo;
  function confirmModal(title, sub, go, cb) {
    if (!cScrim) {
      cScrim = document.createElement("div"); cScrim.className = "ax-modal-scrim";
      (pane || document.body).appendChild(cScrim);
      cScrim.addEventListener("click", function (e) { if (e.target === cScrim) cScrim.classList.remove("show"); });
    }
    cScrim.innerHTML = '<div class="ax-modal"><div class="mic">' + I.trash + '</div><div class="mt">' + esc(title) +
      '</div><div class="ms">' + esc(sub) + '</div><div class="mb"><button class="keep" id="lsCKeep">Keep</button>' +
      '<button class="go" id="lsCGo">' + esc(go) + '</button></div></div>';
    cOnGo = cb;
    $("#lsCKeep", cScrim).addEventListener("click", function () { cScrim.classList.remove("show"); });
    $("#lsCGo", cScrim).addEventListener("click", function () { cScrim.classList.remove("show"); if (cOnGo) cOnGo(); });
    requestAnimationFrame(function () { cScrim.classList.add("show"); });
  }

  /* ===================== RENDER ===================== */
  function render() {
    if (active === "reminders") renderReminders();
    else if (active === "settings") renderSettings();
    else if (active === "webhook") renderWebhook();
    else renderQuick();
  }

  function renderReminders() {
    var DEF = {
      business: { on: true, recipient: "Agent Contact Number", template: "lead_remainder_copy" },
      newlead: { on: true, recipient: "Primary Contact", template: "test_variables" }
    };
    var cfg = (window.AskEvaLeadConfig && window.AskEvaLeadConfig.alerts()) || JSON.parse(JSON.stringify(DEF));
    function tpl(name) { var list = (window.AskEvaTemplates && window.AskEvaTemplates.list()) || []; for (var i = 0; i < list.length; i++) if (list[i].n === name) return list[i]; return null; }
    function preview(name) {
      var t = tpl(name);
      if (!t) return '<div class="ra-prev empty">No template selected — tap “Template Name” to choose one.</div>';
      return '<div class="ra-prev">' +
        '<div class="ra-prow"><span class="k">Type:</span><b>' + esc((t.cat || "").toUpperCase()) + '</b><span class="hdr">Header: ' + esc(t.header || "text") + '</span></div>' +
        '<div class="ra-prow body"><span class="k">Body:</span><span class="bd">' + esc(t.p) + '</span></div>' +
      '</div>';
    }
    function card(title, sub, ic, key, c) {
      return '<div class="ra-card" data-alert="' + key + '">' +
        '<div class="ra-hd"><span class="ra-ic">' + ic + '</span><div class="ra-tt">' + title + '</div>' +
          '<button class="ls-switch' + (c.on ? " on" : "") + '" data-toggle aria-label="Toggle"></button></div>' +
        '<div class="ra-sub">' + sub + '</div>' +
        '<button class="ra-config" data-config aria-expanded="false">Configure templates &amp; follow-ups' +
          '<svg class="ra-chev" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="M9 6l6 6-6 6"/></svg></button>' +
        '<div class="ra-body" data-body hidden>' +
          '<div class="ra-recip">Recipient Number : <b>' + esc(c.recipient) + '</b></div>' +
          '<div class="ra-tplrow"><span class="lbl">Select Template <span class="req">*</span></span>' +
            '<button class="ra-tplname" data-pick>Template Name: <b class="tn">' + esc(c.template || "—") + '</b><span class="rf">' + I.refresh + '</span></button></div>' +
          '<div data-prevhost>' + preview(c.template) + '</div>' +
          '<div class="ra-btns"><button class="ra-save" data-save>Save</button><button class="ra-reset" data-reset>Reset</button></div>' +
        '</div>' +
      '</div>';
    }
    body.innerHTML =
      card("Business Alert", "Track and manage all new leads in your system with real-time updates.", I.cal, "business", cfg.business) +
      card("New Lead Creation Alert", "Monitor lead progression and send automated updates.", I.calclock, "newlead", cfg.newlead);

    $$("[data-alert]", body).forEach(function (cardEl) {
      var key = cardEl.getAttribute("data-alert"), c = cfg[key];
      var label = key === "business" ? "Business Alert" : "New Lead Creation Alert";
      var tg = $("[data-toggle]", cardEl);
      tg.addEventListener("click", function () {
        c.on = !c.on; tg.classList.toggle("on", c.on);
        if (window.AskEvaLeadConfig) window.AskEvaLeadConfig.saveAlerts();
        toast(label + " " + (c.on ? "enabled" : "disabled"));
      });
      var cfgBtn = $("[data-config]", cardEl), bodyEl = $("[data-body]", cardEl);
      cfgBtn.addEventListener("click", function () {
        var open = cardEl.classList.toggle("open");
        bodyEl.hidden = !open;
        cfgBtn.setAttribute("aria-expanded", open ? "true" : "false");
      });
      $("[data-pick]", cardEl).addEventListener("click", function () {
        if (!window.AskEvaTemplates) return;
        window.AskEvaTemplates.open({
          title: "Select Template",
          fields: function () { return window.AskEvaLeadFields && AskEvaLeadFields.mapFields(); },
          onSend: function (t) {
            c.template = t.n;
            $(".tn", cardEl).textContent = t.n;
            $("[data-prevhost]", cardEl).innerHTML = preview(t.n);
          }
        });
      });
      $("[data-save]", cardEl).addEventListener("click", function () {
        if (window.AskEvaLeadConfig) window.AskEvaLeadConfig.saveAlerts();
        toast(label + " saved");
      });
      $("[data-reset]", cardEl).addEventListener("click", function () {
        cfg[key] = JSON.parse(JSON.stringify(DEF[key]));
        if (window.AskEvaLeadConfig) { var a = window.AskEvaLeadConfig.alerts(); a[key] = cfg[key]; window.AskEvaLeadConfig.saveAlerts(); }
        renderReminders(); toast(label + " reset");
      });
    });
  }

  function renderSettings() {
    body.innerHTML =
      '<div class="ls-cardtitle">' + I.gear + '<h3>Field Configuration</h3></div>' +
      '<div class="ls-subtabs">' +
        '<button class="' + (settingsSub === "fields" ? "active" : "") + '" data-sub="fields">Lead Fields</button>' +
        '<button class="' + (settingsSub === "dd" ? "active" : "") + '" data-sub="dd">Dropdown Fields</button>' +
      '</div><div id="lsSubBody"></div>';
    $$("[data-sub]", body).forEach(function (b) {
      b.addEventListener("click", function () { settingsSub = b.getAttribute("data-sub"); renderSettings(); });
    });
    if (settingsSub === "fields") renderFields(); else renderDropdowns();
  }

  function renderFields() {
    var sb = $("#lsSubBody", body);
    var typeOpts = ["Input", "Textarea", "Dropdown"];
    var rows = FIELDS.filter(function (f) { return !fieldSearch || f.n.toLowerCase().indexOf(fieldSearch) >= 0; });
    sb.innerHTML =
      '<div class="lx-search" style="margin-bottom:12px"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><circle cx="11" cy="11" r="7"/><path d="M21 21l-4.3-4.3"/></svg><input id="lsFieldSearch" placeholder="Search fields…" value="' + fieldSearch + '"></div>' +
      '<div class="ls-addbar"><input class="lx-input" id="lsNewField" placeholder="Custom field name"><select class="lx-select" id="lsNewType">' +
        typeOpts.map(function (o) { return '<option>' + o + '</option>'; }).join("") + '</select><button class="add" id="lsAddField"><span class="pl">+</span> Add</button></div>' +
      '<div class="ls-typehint" id="lsTypeHint"></div>' +
      rows.map(function (f) {
        var idx = FIELDS.indexOf(f);
        var reqL = reqLocked(f); if (reqL) f.mand = true;
        var core = isCore(f);
        return '<div class="ls-field" data-fi="' + idx + '">' +
          '<span class="sn">' + (idx + 1) + '</span>' +
          '<div class="fmain"><div class="fn">' + f.n + '</div><span class="ft ft-' + (isDropdownType(f.t) ? 'dd' : (f.t === 'Textarea' ? 'ta' : 'in')) + '">' + typeLabel(f.t) + '</span></div>' +
          '<div class="ftoggles">' +
            '<div class="ls-tg"><span class="k">Display</span><button class="ls-tgsw' + (f.disp ? " on" : "") + '" data-tg="disp"></button></div>' +
            '<div class="ls-tg"><span class="k">Required</span><button class="ls-tgsw' + (f.mand ? " on" : "") + (reqL ? " locked" : "") + '" data-tg="mand"' + (reqL ? " disabled" : "") + '></button></div>' +
          '</div>' +
          '<button class="ls-del" data-del="' + idx + '"' + (core ? " disabled" : "") + '>' + I.trash + '</button>' +
        '</div>';
      }).join("") +
      (rows.length ? "" : '<div class="lx-empty"><div class="t">No fields match</div></div>');
    var srch = $("#lsFieldSearch", sb);
    var TYPE_HINTS = {
      "Input": "Single-line text — e.g. Name, Email, Phone Number.",
      "Textarea": "Multi-line text — e.g. Address, Comments, Description.",
      "Dropdown": "Pick-list — set its options in the Dropdown Fields tab."
    };
    var typeSel = $("#lsNewType", sb), typeHint = $("#lsTypeHint", sb);
    function showTypeHint() { if (typeHint) typeHint.textContent = TYPE_HINTS[typeSel.value] || ""; }
    if (typeSel) { typeSel.addEventListener("change", showTypeHint); showTypeHint(); }
    srch.addEventListener("input", function () { fieldSearch = this.value.toLowerCase(); var pos = this.selectionStart; renderFields(); var ns = $("#lsFieldSearch", body); ns.focus(); try { ns.setSelectionRange(pos, pos); } catch (e) {} });
    $("#lsAddField", sb).addEventListener("click", function () {
      var name = $("#lsNewField", sb).value.trim(); if (!name) { toast("Enter a field name"); return; }
      if (FIELDS.some(function (f) { return f.n.toLowerCase() === name.toLowerCase(); })) { toast('"' + name + '" already exists'); return; }
      var t = $("#lsNewType", sb).value;
      FIELDS.push({ n: name, t: t, disp: true, mand: false, custom: true });
      if (window.AskEvaLeadFields) window.AskEvaLeadFields.save();
      // a Dropdown field needs an (initially empty) option list in the shared store
      if (isDropdownType(t) && window.AskEvaLeadDropdowns) window.AskEvaLeadDropdowns.ensure(name);
      fieldSearch = ""; renderFields();
      toast(name + " field added" + (isDropdownType(t) ? " · add its options in Dropdown Fields" : ""));
    });
    $$("[data-fi]", sb).forEach(function (row) {
      var f = FIELDS[+row.getAttribute("data-fi")];
      $$(".ls-tgsw", row).forEach(function (sw) {
        sw.addEventListener("click", function () {
          var key = sw.getAttribute("data-tg");
          if (key === "mand" && reqLocked(f)) { toast(f.n + " is always required"); return; }
          f[key] = !f[key]; sw.classList.toggle("on", f[key]);
          if (window.AskEvaLeadFields) window.AskEvaLeadFields.save();
          if (key === "disp") toast(f.n + (f.disp ? " shown in" : " hidden from") + " lead form");
          else toast(f.n + (f.mand ? " is now required" : " is now optional"));
        });
      });
    });
    $$("[data-del]", sb).forEach(function (b) {
      if (b.disabled) return;
      b.addEventListener("click", function () {
        var f = FIELDS[+b.getAttribute("data-del")];
        confirmModal("Remove field?", "\u201C" + f.n + "\u201D will be removed from the lead form.", "Remove", function () {
          FIELDS.splice(FIELDS.indexOf(f), 1);
          if (isDropdownType(f.t) && window.AskEvaLeadDropdowns) window.AskEvaLeadDropdowns.drop(f.n);
          if (window.AskEvaLeadFields) window.AskEvaLeadFields.save(); renderFields(); toast(f.n + " removed");
        });
      });
    });
  }

  function renderDropdowns() {
    var sb = $("#lsSubBody", body);
    var DD = window.AskEvaLeadDropdowns;
    /* Dropdown Fields are DERIVED from Lead Fields: every field whose type is
       Dropdown (incl. the legacy "Select" built-ins Status/Source/Assigned)
       shows here automatically. Add a Dropdown field in Lead Fields → it appears
       here; remove it there → it disappears. Options live in the shared store so
       edits propagate to the lead form, filters and board. */
    var ddFields = FIELDS.filter(function (f) { return isDropdownType(f.t); });
    var ddList = ddFields.map(function (f) {
      return { n: f.n, opts: (DD ? DD.options(f.n) : []) };
    });
    if (!ddList.length) {
      sb.innerHTML = '<div class="lx-empty"><div class="t">No dropdown fields yet</div>' +
        '<div class="s">Add a field of type <b>Dropdown</b> in the Lead Fields tab — it will appear here so you can set its options.</div></div>';
      return;
    }
    sb.innerHTML = ddList.map(function (d, di) {
      return '<div class="ls-dd" data-dd="' + di + '">' +
        '<div class="ls-ddhd"><span class="nm">' + d.n + '</span><span class="ty">Dropdown</span></div>' +
        '<div class="ls-opts">' + (d.opts.length ? d.opts.map(function (o, oi) {
          return '<span class="ls-opt">' + o + '<button data-rmopt="' + oi + '">' + I.x + '</button></span>';
        }).join("") : '<span style="font-size:12px;font-weight:600;color:var(--ink-4)">No options yet</span>') + '</div>' +
        '<div class="ls-optadd"><input class="lx-input" placeholder="Add option…"><button class="add">Add</button></div>' +
      '</div>';
    }).join("");
    $$("[data-dd]", sb).forEach(function (cardEl) {
      var d = ddList[+cardEl.getAttribute("data-dd")];
      $$("[data-rmopt]", cardEl).forEach(function (b) {
        b.addEventListener("click", function () {
          var oi = +b.getAttribute("data-rmopt"), optName = d.opts[oi];
          confirmModal("Remove option?", "\u201C" + optName + "\u201D will be removed from " + d.n + ".", "Remove", function () {
            if (DD) DD.remove(d.n, oi); else d.opts.splice(oi, 1);
            renderDropdowns(); toast("Option removed from " + d.n);
          });
        });
      });
      var inp = $(".ls-optadd .lx-input", cardEl), add = $(".ls-optadd .add", cardEl);
      function addOpt() {
        var v = inp.value.trim(); if (!v) return;
        var ok = DD ? DD.add(d.n, v) : (d.opts.push(v), true);
        if (ok === false) { toast('"' + v + '" already exists in ' + d.n); return; }
        renderDropdowns(); toast("Option added to " + d.n);
      }
      add.addEventListener("click", addOpt);
      inp.addEventListener("keydown", function (e) { if (e.key === "Enter") { e.preventDefault(); addOpt(); } });
    });
  }

  function renderWebhook() {
    var ed = webhook.editing, dis = ed ? "" : " disabled";
    var payload =
      '<span class="k">{</span>\n' +
      '  <span class="k">"event"</span>: <span class="s">"lead_created"</span>,\n' +
      '  <span class="k">"timestamp"</span>: <span class="s">"2026-06-05T12:34:56Z"</span>,\n' +
      '  <span class="k">"data"</span>: {\n' +
      '    <span class="k">"leadId"</span>: <span class="s">"507f1f77bcf86cd799439011"</span>,\n' +
      '    <span class="k">"name"</span>: <span class="s">"John Doe"</span>,\n' +
      '    <span class="k">"email"</span>: <span class="s">"john@example.com"</span>,\n' +
      '    <span class="k">"mobile"</span>: <span class="s">"1234567890"</span>,\n' +
      '    <span class="k">"company"</span>: <span class="s">"Example Corp"</span>,\n' +
      '    <span class="k">"status"</span>: <span class="s">"New Lead"</span>\n' +
      '  }\n<span class="k">}</span>';
    body.innerHTML =
      '<div class="ls-cardtitle">' + I.link + '<h3>Webhook Configuration</h3></div>' +
      '<div class="ls-wh">' +
        '<div class="lx-field" style="margin-bottom:14px"><label class="ls-whlabel">Webhook URL <span class="req">*</span></label>' +
          '<input class="lx-input" id="whUrl"' + dis + ' placeholder="https://webhook.site/fb7e5fcc-71cc-4eb0-a56f-235ec3de6379"></div>' +
        '<div class="lx-field"><label class="ls-whlabel">Events <span class="req">*</span></label>' +
          '<select class="lx-select" id="whEvents"' + dis + '><option>All</option><option>lead_created</option><option>lead_updated</option><option>lead_converted</option></select></div>' +
        '<label class="ls-whlabel">Header Parameters (Optional)</label>' +
        '<div class="lx-twocol" style="margin-bottom:16px"><input class="lx-input" id="whHk"' + dis + ' placeholder="Header Key"><input class="lx-input" id="whHv"' + dis + ' placeholder="Header Value"></div>' +
        '<label class="ls-whlabel">Sample Payload</label>' +
        '<div class="ls-payload">' + payload + '</div>' +
        '<div class="ls-whbtns">' +
          '<button class="edit" id="whEdit">' + (ed ? "Save" : "Edit") + '</button>' +
          '<button class="test" id="whTest">Test Webhook</button>' +
          '<button class="reset" id="whReset">Reset</button>' +
        '</div>' +
      '</div>';
    $("#whEdit", body).addEventListener("click", function () {
      if (webhook.editing) toast("Webhook saved");
      webhook.editing = !webhook.editing; renderWebhook();
    });
    $("#whTest", body).addEventListener("click", function () { toast("Test event sent ✓"); });
    $("#whReset", body).addEventListener("click", function () { webhook.editing = false; renderWebhook(); toast("Webhook reset"); });
  }

  function renderQuick() {
    body.innerHTML =
      '<div class="ls-cardtitle">' + I.chat + '<h3>Quick Reply</h3><span class="sp"></span>' +
        '<button class="lx-filterbtn" id="qrAdd">' + I.plus + 'Add</button></div>' +
      (QR.length ? QR.map(function (q, i) {
        var qrClock = '<span class="qr-ic"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></svg></span>';
        return '<div class="ls-qr" data-qr="' + i + '">' + qrClock + '<div class="qrmain"><div class="qrt">' + q.t + '</div><div class="qrm">' + q.m + '</div></div>' +
          '<div class="qracts"><button class="qract" data-qedit="' + i + '">' + I.edit + '</button><button class="qract del" data-qdel="' + i + '">' + I.trash + '</button></div></div>';
      }).join("") : '<div class="lx-empty"><div class="t">No quick replies yet</div><div class="s">Tap Add to create one</div></div>');
    $("#qrAdd", body).addEventListener("click", function () { qrForm(null); });
    $$("[data-qedit]", body).forEach(function (b) { b.addEventListener("click", function () { qrForm(+b.getAttribute("data-qedit")); }); });
    $$("[data-qdel]", body).forEach(function (b) { b.addEventListener("click", function () { var i = +b.getAttribute("data-qdel"); var t = QR[i].t; confirmModal("Delete quick reply?", "\u201C" + t + "\u201D will be permanently removed.", "Delete", function () { QR.splice(i, 1); qrPersist(); renderQuick(); toast('"' + t + '" deleted'); }); }); });
  }
  function qrForm(idx) {
    var q = idx == null ? { t: "", m: "" } : QR[idx];
    openSheet(
      '<div class="lx-shead"><span class="tt">' + (idx == null ? "Add Quick Reply" : "Edit Quick Reply") + '</span><button class="x" data-x>' + I.x + '</button></div>' +
      '<div class="lx-sbody">' +
        '<div class="lx-field"><label>Title</label><input class="lx-input" id="qrT" value="' + q.t.replace(/"/g, "&quot;") + '" placeholder="Short title"></div>' +
        '<div class="lx-field"><label>Message</label><textarea class="lx-textarea" id="qrM" placeholder="Reply message…">' + q.m + '</textarea></div>' +
      '</div>' +
      '<div class="lx-sfoot"><button class="lx-btn ghost" data-x2>Cancel</button><button class="lx-btn primary" data-save>' + (idx == null ? "Add reply" : "Save") + '</button></div>'
    );
    $("[data-x]", sheet).addEventListener("click", closeSheet);
    $("[data-x2]", sheet).addEventListener("click", closeSheet);
    $("[data-save]", sheet).addEventListener("click", function () {
      var t = $("#qrT", sheet).value.trim(), m = $("#qrM", sheet).value.trim();
      if (!t) { toast("Enter a title"); return; }
      if (idx == null) QR.unshift({ t: t, m: m }); else { QR[idx].t = t; QR[idx].m = m; }
      qrPersist();
      closeSheet(); renderQuick(); toast(idx == null ? "Quick reply added" : "Quick reply updated");
    });
  }

  /* ---------- tabs ---------- */
  $$(".lx-tab", pane).forEach(function (t) {
    t.addEventListener("click", function () {
      active = t.getAttribute("data-lst");
      $$(".lx-tab", pane).forEach(function (x) { x.classList.toggle("active", x === t); });
      body.scrollTop = 0; render();
    });
  });

  render();
})();
