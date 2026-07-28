/* =========================================================
   AskEva — Appointments Configuration (full rebuild)
   Mobile translation of the web "Appointments Configuration"
   settings, 4 tabs:
     · Alerts    → User Alerts / Business Alerts toggle cards
     · Webhook   → Webhook Configuration (URL, event, headers,
                   sample payload, Edit/Test/Reset)
     · Booking Form → drag-reorder field list, type badges,
                   Step Field / Non Deletable, Add Field, Publish
     · Department Configuration → Manage Departments table,
                   In Use / Not Used, delete, Create Department
   Overrides AX.renderSettings + AX.addField.
   ========================================================= */
(function (AX) {
  "use strict";
  if (!AX || !AX.pane) return;
  var $ = AX.$, $$ = AX.$$, I = AX.I, esc = AX.esc;

  /* ---------- extra icons ---------- */
  var icBell = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 9a6 6 0 0 1 12 0c0 5 2 6 2 6H4s2-1 2-6Z"/><path d="M10 19a2 2 0 0 0 4 0"/></svg>';
  var icLink = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M10 13a5 5 0 0 0 7 0l2-2a5 5 0 0 0-7-7l-1 1"/><path d="M14 11a5 5 0 0 0-7 0l-2 2a5 5 0 0 0 7 7l1-1"/></svg>';
  var icCalChk = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="5" width="18" height="16" rx="2.5"/><path d="M3 10h18M8 3v4M16 3v4"/><path d="m9 15 2 2 4-4"/></svg>';
  var icCalClock = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="5" width="18" height="16" rx="2.5"/><path d="M3 10h18M8 3v4M16 3v4"/><circle cx="15" cy="15" r="3.2"/><path d="M15 14v1.3l1 .7"/></svg>';
  var icUpload = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 15v3a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-3"/><path d="m8 9 4-4 4 4"/><path d="M12 5v11"/></svg>';
  var icPlay = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m6 4 14 8-14 8V4Z"/></svg>';
  var icCheck = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="m5 12 4 4 10-11"/></svg>';
  var icEye = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7-10-7-10-7Z"/><circle cx="12" cy="12" r="3"/></svg>';

  /* =========================================================
     PERSISTED STORES
     ========================================================= */
  function load(key, def) { try { var v = JSON.parse(localStorage.getItem(key)); return v == null ? def : v; } catch (e) { return def; } }
  function store(key, v) { try { localStorage.setItem(key, JSON.stringify(v)); } catch (e) {} }

  /* alerts */
  var AK = "askeva.cfg.alerts.v1";
  var alerts = load(AK, {
    user: { newBooking: true, reschedule: true, completion: true },
    business: { newBooking: true, reschedule: true }
  });
  function saveAlerts() { store(AK, alerts); }

  /* alert template-flow configs (preliminary + follow-ups), per scope+key */
  var ACK = "askeva.cfg.alertcfg.v2";
  function fu() { return { on: false, template: null, type: null, mapField: "Name", delayType: "Hours", delayValue: "1 hour" }; }
  function defCfg(key) {
    return { prelim: { template: null, type: null, chatbot: key === "newBooking" }, mapField: "Name", followups: [fu(), fu()] };
  }
  var alertCfg = load(ACK, {
    user_newBooking: { prelim: { template: "askeva_user", type: "MARKETING", chatbot: true }, mapField: "Name",
      followups: [{ on: true, template: "Follow-up", type: "UTILITY", mapField: "Name", delayType: "Hours", delayValue: "1 hour" }, fu()] },
    user_reschedule: { prelim: { template: "demo_sample", type: "MARKETING", chatbot: false }, mapField: "Name",
      followups: [{ on: true, template: "Follow-up", type: "UTILITY", mapField: "Name", delayType: "Hours", delayValue: "1 hour" }, fu()] },
    user_completion: { prelim: { template: "Pricing & plans", type: "UTILITY", chatbot: false }, mapField: "Name", followups: [fu(), fu()] },
    business_newBooking: { prelim: { template: "summer_glasses", type: "MARKETING", chatbot: true }, mapField: "Name",
      followups: [{ on: true, template: "Follow-up", type: "UTILITY", mapField: "Name", delayType: "Hours", delayValue: "1 hour" }, fu()] },
    business_reschedule: { prelim: { template: "demo_sample", type: "MARKETING", chatbot: false }, mapField: "Name",
      followups: [{ on: true, template: "Follow-up", type: "UTILITY", mapField: "Name", delayType: "Hours", delayValue: "1 hour" }, fu()] }
  });
  function saveCfg() { store(ACK, alertCfg); }
  function cfgFor(scope, key) {
    var id = scope + "_" + key;
    if (!alertCfg[id]) { alertCfg[id] = defCfg(key); }
    var c = alertCfg[id];
    if (!c.prelim) c.prelim = defCfg(key).prelim;
    if (!c.followups) c.followups = [fu(), fu()];
    if (!c.mapField) c.mapField = "Name";
    return c;
  }
  /* per-alert layout rules */
  var ALERT_SCHEMA = {
    newBooking: { chatbot: true,  followups: 2, prelimMap: false },
    reschedule: { chatbot: false, followups: 2, prelimMap: false },
    completion: { chatbot: false, followups: 0, prelimMap: true }
  };
  var MAP_FIELDS = ["Name", "Mobile Number", "Department", "Select User", "Appointment Date", "Appointment Timing", "Age", "Date of Birth"];
  // Live Map-to-field list for Appointment templates: the configured booking-form
  // fields (incl. custom) + the system columns the appointment table carries.
  function apptMapFields() {
    var out = ["ID"];
    var bf = (AX.bookingFields && AX.bookingFields()) || [];
    bf.forEach(function (f) { if (f && f.name) out.push(f.name); });
    out.push("Payment", "Status");
    return out.filter(function (x, i, a) { return x && a.indexOf(x) === i; });
  }
  var DELAY_TYPES = ["Minutes", "Hours", "Days"];
  function delayValues(type) {
    if (type === "Minutes") return ["5 minutes", "10 minutes", "15 minutes", "30 minutes", "45 minutes"];
    if (type === "Days") return ["1 day", "2 days", "3 days", "5 days", "7 days"];
    return ["1 hour", "2 hours", "3 hours", "6 hours", "12 hours", "24 hours"];
  }
  function tplByName(n) { var L = (window.AskEvaTemplates && AskEvaTemplates.list && AskEvaTemplates.list()) || []; for (var i = 0; i < L.length; i++) if (L[i].n === n) return L[i]; return null; }
  function tplType(n) { var t = tplByName(n); return t ? (t.cat || "").toUpperCase() : ""; }

  /* webhook */
  var WK = "askeva.cfg.webhook.v1";
  var webhook = load(WK, { enabled: true, url: "", event: "all", hkey: "", hval: "", editing: false });
  function saveWebhook() { store(WK, webhook); }
  var EVENTS = [["all", "All Events"], ["create", "Appointment Creation"], ["reschedule", "Appointment Reschedule"], ["complete", "Appointment Completion"], ["cancel", "Appointment Cancellation"]];
  var SAMPLE = '{\n  "event": "appointmentCreation",\n  "timestamp": "2024-01-15T10:30:00Z",\n  "userId": "user_123",\n  "data": {\n    "appointmentId": "appt_456",\n    "appointmentNo": "A000001",\n    "name": "John Doe",\n    "mobile": "+1234567890",\n    "appointmentDate": "2024-01-20T14:00:00Z",\n    "timing": "2:00 PM - 2:30 PM",\n    "status": "current",\n    "department": "Consultation",\n    "manager": "Dr. Smith",\n    "managerId": "mgr_789",\n    "description": "Regular checkup appointment",\n    "createdAt": "2024-01-15T10:30:00Z",\n    "updatedAt": "2024-01-15T10:30:00Z"\n  }\n}';

  /* booking-form fields */
  var FK = "askeva.cfg.bookfields.v2";
  var DEF_FIELDS = [
    { id: "name",  name: "Patient Name",       ph: "Enter test name",        type: "input",    req: true, lock: true },
    { id: "age",   name: "Age",                ph: "Enter age",              type: "number",   req: true, lock: true },
    { id: "mob",   name: "Mobile Number",      ph: "Enter 10 digit number",  type: "input",    req: true, lock: true },
    { id: "dob",   name: "Date of Birth",      ph: "Select date of birth",   type: "date",     req: true, lock: true },
    { id: "dept",  name: "Department",         ph: "Select Department",      type: "select",   req: true, step: true },
    { id: "user",  name: "Select User",        ph: "Select User",            type: "select",   req: true, step: true },
    { id: "adate", name: "Appointment Date",   ph: "Select Date",            type: "date",     req: true, step: true },
    { id: "atime", name: "Appointment Timing", ph: "Select Time",            type: "time",     req: true, step: true },
    { id: "desc",  name: "Description",        ph: "Enter description",      type: "textarea", req: true, lock: true }
  ];
  var fields = load(FK, null);
  if (!fields || !fields.length) fields = DEF_FIELDS.map(function (f) { return Object.assign({}, f); });
  function saveFields() { store(FK, fields); }
  function fieldById(id) { for (var i = 0; i < fields.length; i++) if (fields[i].id === id) return fields[i]; return null; }
  /* expose the configured booking-form fields so the live New-appointment form reflects them */
  AX.bookingFields = function () { return fields.slice(); };
  AX.bookingFieldBy = function (id) { return fieldById(id); };

  /* departments — SHARED store lives in appointments.js (AX.DEPTS).
     This Settings tab is the edit home; the same list drives the booking
     form, appointment detail, and per-agent appointment-dept assignment. */

  /* =========================================================
     SUB-TAB STATE
     ========================================================= */
  if (!AX.state.cfgTab) AX.state.cfgTab = "alerts";        // alerts|webhook|bookingform|departments
  if (!AX.state.alertScope) AX.state.alertScope = "user";  // user|business
  if (AX.state.alertOpen === undefined) AX.state.alertOpen = null; // {scope,key} when a config screen is open
  if (AX.state.deptPage == null) AX.state.deptPage = 1;

  var CFG_TABS = [
    ["alerts", "Alerts", icBell],
    ["webhook", "Webhook", icLink],
    ["bookingform", "Booking Form", I.edit],
    ["departments", "Departments", I.users]
  ];

  function tabBar() {
    return '<div class="cfg-tabs" id="cfgTabs">' + CFG_TABS.map(function (t) {
      return '<button class="cfg-tab' + (AX.state.cfgTab === t[0] ? " on" : "") + '" data-t="' + t[0] + '">' +
        '<span class="ic">' + t[2] + '</span>' + t[1] + '</button>';
    }).join("") + '</div>';
  }

  /* =========================================================
     ALERTS
     ========================================================= */
  var ALERT_CARDS = {
    user: [
      { k: "newBooking", ic: I.cal, title: "New Booking", desc: "Track and manage all new appointment bookings in your system with real-time updates." },
      { k: "reschedule", ic: icCalClock, title: "Reschedule Booking", desc: "Handle rescheduling requests and send automated alerts to customers about their new slots." },
      { k: "completion", ic: icCalChk, title: "Appointment Completion", desc: "Monitor completed appointments and gather feedback to improve service quality." }
    ],
    business: [
      { k: "newBooking", ic: I.cal, title: "New Booking", desc: "Send notifications to your business team whenever a new appointment is booked." },
      { k: "reschedule", ic: icCalClock, title: "Reschedule Booking", desc: "Notify your team automatically when a customer reschedules an appointment." }
    ]
  };

  function scopeSeg(scope) {
    return '<div class="cfg-seg" id="alScope">' +
      '<button class="sg' + (scope === "user" ? " on" : "") + '" data-s="user">User Alerts</button>' +
      '<button class="sg' + (scope === "business" ? " on" : "") + '" data-s="business">Business Alerts</button>' +
    '</div>';
  }

  function alertsView(host) {
    var scope = AX.state.alertScope, cards = ALERT_CARDS[scope], data = alerts[scope];
    host.innerHTML = tabBar() + scopeSeg(scope) +
      '<div class="cfg-alerts">' + cards.map(function (c) {
        var on = data[c.k];
        return '<div class="al-card" data-open="' + c.k + '"><div class="al-top">' +
          '<span class="al-ic">' + c.ic + '</span>' +
          '<span class="al-title">' + esc(c.title) + '</span>' +
          '<button class="al-toggle' + (on ? " on" : "") + '" data-k="' + c.k + '" role="switch" aria-checked="' + on + '"><span class="kn"></span><span class="tx">' + (on ? "ON" : "OFF") + '</span></button>' +
          '</div><div class="al-desc">' + esc(c.desc) + '</div>' +
          '<div class="al-cfgrow">Configure templates &amp; follow-ups <span class="cv">' + I.chevR + '</span></div></div>';
      }).join("") + '</div>';

    wireTabs(host);
    $$("#alScope .sg", host).forEach(function (b) { b.addEventListener("click", function () { AX.state.alertScope = b.getAttribute("data-s"); render(host); }); });
    $$(".al-toggle", host).forEach(function (b) {
      b.addEventListener("click", function (e) {
        e.stopPropagation();
        var k = b.getAttribute("data-k");
        alerts[scope][k] = !alerts[scope][k]; saveAlerts();
        AX.toast((ALERT_CARDS[scope].filter(function (c) { return c.k === k; })[0].title) + (alerts[scope][k] ? " alerts ON" : " alerts OFF"));
        render(host);
      });
    });
    $$(".al-card", host).forEach(function (card) {
      card.addEventListener("click", function (e) {
        if (e.target.closest(".al-toggle")) return;
        AX.state.alertOpen = { scope: scope, key: card.getAttribute("data-open") };
        render(host);
      });
    });
  }

  /* =========================================================
     ALERT · TEMPLATE-FLOW CONFIG SCREEN
     ========================================================= */
  function tplChip(o) {
    if (!o || !o.template) return '<div class="alc-chip empty">No template selected</div>';
    return '<div class="alc-chip"><span class="nm">Template: <b>' + esc(o.template) + '</b></span>' +
      '<span class="ty">Type: ' + esc(o.type || tplType(o.template)) + '</span></div>';
  }
  function mapRow(val, who) {
    return '<div class="alc-maplbl"><i>*</i> Map Name to appointment field</div>' +
      '<button class="alc-select" data-map="' + who + '"><span>' + esc(val || "Name") + '</span><span class="cv">' + I.chevR + '</span></button>';
  }
  function sw(on, attrs) {
    return '<button class="alc-sw' + (on ? " on" : "") + '" ' + (attrs || "") + ' role="switch" aria-checked="' + on + '"><span class="kn"></span></button>';
  }
  function pill(on, attrs) {
    return '<button class="al-toggle' + (on ? " on" : "") + '" ' + (attrs || "") + ' role="switch" aria-checked="' + on + '"><span class="kn"></span><span class="tx">' + (on ? "ON" : "OFF") + '</span></button>';
  }
  function prelimCard(cfg, sch) {
    var p = cfg.prelim;
    return '<div class="alc-card">' +
      '<div class="alc-cardhd"><span class="h">Preliminary Message</span>' +
        '<span class="alc-acts"><button class="alc-link" data-prev="prelim">' + icEye + 'Preview</button>' +
          '<button class="alc-link" data-tpl="prelim">' + icUpload + 'Select Template</button></span></div>' +
      tplChip(p) +
      (sch.chatbot ? '<div class="alc-trigger">' + sw(p.chatbot, 'data-chatbot="1"') + '<span>Trigger for chatbot booking</span></div>' : '') +
      (sch.prelimMap ? mapRow(cfg.mapField, "prelim") : '') +
    '</div>';
  }
  function fuCard(f, i) {
    return '<div class="alc-card">' +
      '<div class="alc-cardhd"><span class="h">Follow-up ' + (i + 1) + '</span>' + pill(f.on, 'data-futoggle="' + i + '"') +
        '<span class="alc-acts"><button class="alc-link" data-prev="fu' + i + '">' + icEye + 'Preview</button>' +
          '<button class="alc-link" data-tpl="fu' + i + '">' + icUpload + 'Select Template</button></span></div>' +
      tplChip(f) +
      (f.on ? mapRow(f.mapField, "fu" + i) +
        '<div class="alc-two"><div><div class="alc-lbl">Delay Type</div>' +
          '<button class="alc-select" data-dtype="' + i + '"><span>' + esc(f.delayType) + '</span><span class="cv">' + I.chevR + '</span></button></div>' +
        '<div><div class="alc-lbl">Delay Value</div>' +
          '<button class="alc-select" data-dval="' + i + '"><span>' + esc(f.delayValue) + '</span><span class="cv">' + I.chevR + '</span></button></div></div>' : '') +
    '</div>';
  }
  function previewBlock(cfg) {
    var p = cfg.prelim, t = tplByName(p.template);
    var body = t ? (t.p || "") : "Select a template to preview the message.";
    return '<div class="alc-prevwrap"><div class="alc-prevttl">Preliminary Message</div>' +
      '<div class="alc-phone"><div class="alc-bubble' + (p.template ? "" : " empty") + '">' +
        (p.template ? '<div class="hd">' + esc(t ? t.n : p.template) + '</div>' : '') +
        '<div class="bd">' + esc(body) + '</div></div></div></div>';
  }

  function alertConfigView(host) {
    var scope = AX.state.alertOpen.scope, key = AX.state.alertOpen.key;
    var meta = (ALERT_CARDS[scope] || []).filter(function (c) { return c.k === key; })[0] || { title: "Alert" };
    var sch = ALERT_SCHEMA[key] || { chatbot: false, followups: 0, prelimMap: false };
    var cfg = cfgFor(scope, key);
    var fus = "";
    for (var i = 0; i < sch.followups; i++) fus += fuCard(cfg.followups[i], i);

    host.innerHTML = tabBar() + scopeSeg(scope) +
      '<button class="alc-back" id="alcBack"><span class="cv">' + I.chevL + '</span>Back</button>' +
      '<div class="alc-title">' + esc(meta.title) + ' Configuration</div>' +
      '<div class="alc-wrap">' +
        prelimCard(cfg, sch) + fus + previewBlock(cfg) +
        '<div class="alc-foot"><button class="cfg-btn primary" id="alcSave">Save Configuration</button>' +
          '<button class="cfg-btn red" id="alcReset">Reset</button></div>' +
      '</div>';

    wireTabs(host);
    $$("#alScope .sg", host).forEach(function (b) { b.addEventListener("click", function () { AX.state.alertScope = b.getAttribute("data-s"); AX.state.alertOpen = null; render(host); }); });
    $("#alcBack", host).addEventListener("click", function () { AX.state.alertOpen = null; render(host); });

    var cb = $(".alc-sw[data-chatbot]", host);
    if (cb) cb.addEventListener("click", function () { cfg.prelim.chatbot = !cfg.prelim.chatbot; saveCfg(); render(host); });

    $$(".al-toggle[data-futoggle]", host).forEach(function (b) {
      b.addEventListener("click", function () { var i = +b.getAttribute("data-futoggle"); cfg.followups[i].on = !cfg.followups[i].on; saveCfg(); render(host); });
    });

    $$(".alc-link[data-tpl]", host).forEach(function (b) {
      b.addEventListener("click", function () { pickTemplate(b.getAttribute("data-tpl"), host); });
    });
    $$(".alc-link[data-prev]", host).forEach(function (b) {
      b.addEventListener("click", function () { previewTemplate(b.getAttribute("data-prev")); });
    });

    $$(".alc-select[data-map]", host).forEach(function (b) {
      b.addEventListener("click", function () {
        var who = b.getAttribute("data-map"), cur = who === "prelim" ? cfg.mapField : cfg.followups[+who.slice(2)].mapField;
        AX.radioSheet("Map to appointment field", MAP_FIELDS.map(function (m) { return { v: m, label: m, on: cur === m }; }), function (v) {
          if (who === "prelim") cfg.mapField = v; else cfg.followups[+who.slice(2)].mapField = v;
          saveCfg(); render(host);
        });
      });
    });
    $$(".alc-select[data-dtype]", host).forEach(function (b) {
      b.addEventListener("click", function () {
        var i = +b.getAttribute("data-dtype"), f = cfg.followups[i];
        AX.radioSheet("Delay Type", DELAY_TYPES.map(function (d) { return { v: d, label: d, on: f.delayType === d }; }), function (v) {
          f.delayType = v; f.delayValue = delayValues(v)[0]; saveCfg(); render(host);
        });
      });
    });
    $$(".alc-select[data-dval]", host).forEach(function (b) {
      b.addEventListener("click", function () {
        var i = +b.getAttribute("data-dval"), f = cfg.followups[i];
        AX.radioSheet("Delay Value", delayValues(f.delayType).map(function (d) { return { v: d, label: d, on: f.delayValue === d }; }), function (v) {
          f.delayValue = v; saveCfg(); render(host);
        });
      });
    });

    $("#alcSave", host).addEventListener("click", function () { saveCfg(); AX.toast("Configuration saved"); });
    $("#alcReset", host).addEventListener("click", function () {
      AX.confirm({ title: "Reset configuration?", sub: "This clears the templates and follow-ups for this alert.", go: "Reset", onGo: function () {
        alertCfg[scope + "_" + key] = defCfg(key); saveCfg(); render(host); AX.toast("Configuration reset");
      } });
    });
  }

  function pickTemplate(target, host) {
    if (!(window.AskEvaTemplates && AskEvaTemplates.open)) { AX.toast("Templates unavailable"); return; }
    AskEvaTemplates.open({ title: "Select Template", fields: apptMapFields, onSend: function (t) {
      var scope = AX.state.alertOpen.scope, key = AX.state.alertOpen.key, cfg = cfgFor(scope, key);
      var name = (t && (t.n || t.name)) || "", type = ((t && t.cat) || "").toUpperCase() || tplType(name);
      if (target === "prelim") { cfg.prelim.template = name; cfg.prelim.type = type; }
      else { var i = +target.slice(2); cfg.followups[i].template = name; cfg.followups[i].type = type; cfg.followups[i].on = true; }
      saveCfg(); render(host);
    } });
  }
  function previewTemplate(target) {
    var scope = AX.state.alertOpen.scope, key = AX.state.alertOpen.key, cfg = cfgFor(scope, key);
    var o = target === "prelim" ? cfg.prelim : cfg.followups[+target.slice(2)];
    if (!o.template) { AX.toast("Select a template first"); return; }
    var t = tplByName(o.template);
    AX.openSheet('<div class="ax-grip"></div><div class="ax-sheet-head"><div class="ax-sheet-ttl">Preview</div>' +
      '<div class="ax-sheet-sub">' + esc(o.template) + ' \u00b7 ' + esc(o.type || tplType(o.template)) + '</div></div>' +
      '<div class="alc-phone big"><div class="alc-bubble"><div class="hd">' + esc(t ? t.n : o.template) + '</div>' +
        '<div class="bd">' + esc(t ? (t.p || "") : "") + '</div></div></div>');
  }

  /* =========================================================
     WEBHOOK
     ========================================================= */
  function webhookView(host) {
    var ed = webhook.editing, ev = (EVENTS.filter(function (e) { return e[0] === webhook.event; })[0] || EVENTS[0])[1];
    host.innerHTML = tabBar() +
      '<div class="cfg-card">' +
        '<div class="wh-hd"><div class="wh-ttl"><span class="ic">' + icLink + '</span>Webhook Configuration</div>' +
          '<button class="wh-enable' + (webhook.enabled ? " on" : "") + '" id="whEnable" role="switch" aria-checked="' + webhook.enabled + '">' +
            '<span class="lbl">Enabled</span><span class="sw"><span class="kn"></span></span></button></div>' +

        '<label class="wh-label">Webhook URL <i>*</i></label>' +
        '<div class="wh-input' + (ed ? "" : " ro") + '">' + (ed
          ? '<input id="whUrl" type="url" placeholder="Enter webhook URL (e.g., https://api.example.com/webhook)" value="' + esc(webhook.url) + '">'
          : '<span class="val' + (webhook.url ? "" : " ph") + '">' + esc(webhook.url || "Enter webhook URL (e.g., https://api.example.com/webhook)") + '</span>') + '</div>' +

        '<label class="wh-label">Event Type <i>*</i></label>' +
        (ed
          ? '<button class="wh-input as-btn" id="whEvent"><span class="val">' + esc(ev) + '</span><span class="cv">' + I.chevR + '</span></button>'
          : '<div class="wh-input ro"><span class="val">' + esc(ev) + '</span></div>') +

        '<label class="wh-label mt">Header Parameters <span class="opt">(Optional)</span></label>' +
        '<div class="wh-hrow">' +
          (ed
            ? '<input id="whHKey" class="wh-input edit" type="text" placeholder="Header Key (e.g., Authorizatio…)" value="' + esc(webhook.hkey) + '">' +
              '<input id="whHVal" class="wh-input edit" type="text" placeholder="Header Value (e.g., Bearer token123)" value="' + esc(webhook.hval) + '">'
            : '<div class="wh-input ro"><span class="val' + (webhook.hkey ? "" : " ph") + '">' + esc(webhook.hkey || "Header Key (e.g., Authorizatio…)") + '</span></div>' +
              '<div class="wh-input ro"><span class="val' + (webhook.hval ? "" : " ph") + '">' + esc(webhook.hval || "Header Value (e.g., Bearer token123)") + '</span></div>') +
        '</div>' +

        '<label class="wh-label mt">Sample Payload Structure</label>' +
        '<pre class="wh-code">' + payloadHTML(SAMPLE) + '</pre>' +

        '<div class="wh-actions">' +
          '<button class="cfg-btn primary" id="whEdit">' + (ed ? icCheck + 'Save Configuration' : I.edit + 'Edit Configuration') + '</button>' +
          '<button class="cfg-btn ghost" id="whTest"' + (webhook.url ? "" : " disabled") + '>' + icPlay + 'Test Webhook</button>' +
          '<button class="cfg-btn danger-o" id="whReset">Reset</button>' +
        '</div>' +
      '</div>';

    wireTabs(host);
    $("#whEnable", host).addEventListener("click", function () { webhook.enabled = !webhook.enabled; saveWebhook(); render(host); AX.toast("Webhook " + (webhook.enabled ? "enabled" : "disabled")); });
    var ue = $("#whUrl", host); if (ue) ue.addEventListener("input", function (e) { webhook.url = e.target.value; });
    var hk = $("#whHKey", host); if (hk) hk.addEventListener("input", function (e) { webhook.hkey = e.target.value; });
    var hv = $("#whHVal", host); if (hv) hv.addEventListener("input", function (e) { webhook.hval = e.target.value; });
    var evb = $("#whEvent", host); if (evb) evb.addEventListener("click", function () {
      AX.radioSheet("Event Type", EVENTS.map(function (e) { return { v: e[0], label: e[1], on: webhook.event === e[0] }; }), function (v) { webhook.event = v; saveWebhook(); render(host); });
    });
    $("#whEdit", host).addEventListener("click", function () {
      if (ed) { saveWebhook(); webhook.editing = false; AX.toast("Webhook configuration saved"); }
      else { webhook.editing = true; }
      render(host);
    });
    var tb = $("#whTest", host); if (tb && !tb.disabled) tb.addEventListener("click", function () { AX.toast("Test event sent to webhook"); });
    $("#whReset", host).addEventListener("click", function () {
      AX.confirm({ title: "Reset webhook?", sub: "This clears the URL, event type and headers.", go: "Reset", onGo: function () {
        webhook = { enabled: webhook.enabled, url: "", event: "all", hkey: "", hval: "", editing: false }; saveWebhook(); render(host); AX.toast("Webhook reset");
      } });
    });
  }
  function payloadHTML(src) {
    return esc(src)
      .replace(/(&quot;[^&]*?&quot;)(\s*:)/g, '<span class="k">$1</span>$2')
      .replace(/(:\s*)(&quot;[^&]*?&quot;)/g, '$1<span class="s">$2</span>');
  }

  /* =========================================================
     BOOKING FORM
     ========================================================= */
  function bookingFormView(host) {
    host.innerHTML = tabBar() +
      '<div class="cfg-card bf">' +
        '<div class="bf-hd"><div><div class="bf-ttl">Booking Form Configuration</div>' +
          '<div class="bf-sub">Configure the fields for your appointment booking form</div></div></div>' +
        '<div class="bf-actions"><button class="cfg-btn primary sm" id="bfPublish">' + icUpload + 'Publish</button>' +
          '<button class="cfg-btn primary sm" id="bfAdd">' + I.plus + 'Add Field</button></div>' +
        '<div class="bf-hint"><b>Drag and drop to reorder fields.</b> Changes are saved automatically.' +
          '<span class="note">Note: Core step fields (Department, User, Date, Time) move together as a group.</span></div>' +
        '<div class="bf-list" id="bfList">' + fields.map(fieldRow).join("") + '</div>' +
      '</div>';

    wireTabs(host);
    $("#bfPublish", host).addEventListener("click", function () { saveFields(); AX.toast("Flow published successfully"); });
    $("#bfAdd", host).addEventListener("click", openAddField);
    $$(".bf-row .edit", host).forEach(function (b) { b.addEventListener("click", function () { editField(b.getAttribute("data-id")); }); });
    initDrag(host);
  }

  function fieldRow(f) {
    var typeBadge = '<span class="bf-badge type">' + esc(f.type) + '</span>';
    var lockBadge = f.step ? '<span class="bf-badge step">Step Field</span>'
      : (f.lock ? '<span class="bf-badge lock">Non Deletable</span>'
      : (f.custom ? '<span class="bf-badge custom">Custom</span>' : ''));
    return '<div class="bf-row" data-id="' + f.id + '"' + (f.step ? ' data-step="1"' : '') + ' draggable="true">' +
      '<span class="bf-drag">' + I.plus + '<span>Drag</span></span>' +
      '<div class="bf-mid"><div class="bf-name">' + esc(f.name) + (f.req ? '<span class="rq">*</span>' : '') +
        typeBadge + lockBadge + '</div>' +
        (f.ph ? '<div class="bf-ph">Placeholder: ' + esc(f.ph) + '</div>' : '') + '</div>' +
      '<button class="edit" data-id="' + f.id + '" aria-label="Edit field">' + I.edit + '</button></div>';
  }

  /* drag-reorder (step fields move as a group) */
  function initDrag(host) {
    var list = $("#bfList", host); if (!list) return;
    var dragEl = null;
    $$(".bf-row", list).forEach(function (row) {
      row.addEventListener("dragstart", function (e) { dragEl = row; row.classList.add("dragging"); e.dataTransfer.effectAllowed = "move"; });
      row.addEventListener("dragend", function () { row.classList.remove("dragging"); dragEl = null; commitOrder(list); });
    });
    list.addEventListener("dragover", function (e) {
      e.preventDefault();
      var after = afterEl(list, e.clientY);
      if (!dragEl) return;
      if (after == null) list.appendChild(dragEl); else list.insertBefore(dragEl, after);
    });
  }
  function afterEl(list, y) {
    var els = $$(".bf-row:not(.dragging)", list), closest = null, off = -Infinity;
    els.forEach(function (el) { var b = el.getBoundingClientRect(), d = y - b.top - b.height / 2; if (d < 0 && d > off) { off = d; closest = el; } });
    return closest;
  }
  function commitOrder(list) {
    var ids = $$(".bf-row", list).map(function (r) { return r.getAttribute("data-id"); });
    fields.sort(function (a, b) { return ids.indexOf(a.id) - ids.indexOf(b.id); });
    saveFields();
  }

  function editField(id) {
    var f = fieldById(id);
    var html = '<div class="ax-grip"></div><div class="ax-sheet-head"><div><div class="ax-sheet-ttl">Edit field</div>' +
      '<div class="ax-sheet-sub">' + esc(f.name) + '</div></div></div>' +
      '<div class="ax-field"><label class="ax-label">Label</label><div class="ax-control">' + I.note + '<input id="efName" type="text" value="' + esc(f.name) + '"></div></div>' +
      '<div class="ax-field"><label class="ax-label">Placeholder</label><div class="ax-control">' + I.note + '<input id="efPh" type="text" value="' + esc(f.ph || "") + '"></div></div>' +
      '<button class="ax-reason' + (f.req ? " on" : "") + '" id="efReq" style="width:100%;margin-bottom:10px"><span class="rd"></span>Required field</button>' +
      (f.lock || f.step ? '<div class="ef-locknote">' + I.warn + 'This is a core field and cannot be deleted.</div>'
        : '<button class="ax-btn danger" id="efDel" style="margin-bottom:10px">' + I.trash + 'Delete field</button>') +
      '<button class="ax-sheetbtn" id="efSave">Save field</button>';
    var s = AX.openSheet(html);
    var req = f.req;
    $("#efReq", s).addEventListener("click", function () { req = !req; this.classList.toggle("on", req); });
    var del = $("#efDel", s); if (del) del.addEventListener("click", function () {
      AX.confirm({ title: "Delete field?", sub: "This permanently removes \u201C" + (f.name || "this field") + "\u201D from the booking form.", go: "Delete", onGo: function () {
        fields = fields.filter(function (x) { return x.id !== id; }); saveFields(); AX.closeSheet(); render(); AX.toast("Field deleted");
      } });
    });
    $("#efSave", s).addEventListener("click", function () {
      f.name = ($("#efName", s).value || f.name).trim(); f.ph = $("#efPh", s).value; f.req = req;
      saveFields(); AX.closeSheet(); render(); AX.toast("Field saved");
    });
  }

  /* Field taxonomy — mirrors the web "Add Field" wizard:
       Category → Field Type → (Input Type, for ShortAnswer only) → Show in Booking Form
     Each field type maps to a stored `type` token used for the row badge / live form. */
  var FIELD_CATS = {
    "Text Answer": [
      ["ShortAnswer", "Short Answer", "input"],
      ["Paragraph", "Paragraph", "textarea"],
      ["DatePicker", "Date Picker", "date"]
    ],
    "Selections": [
      ["SingleChoice", "Single Choice", "radio"],
      ["MultipleChoice", "Multiple Choice", "checkbox"],
      ["Dropdown", "Dropdown", "select"]
    ]
  };
  var INPUT_TYPES = [["Text", "text"], ["Password", "password"], ["Email", "email"], ["Number", "number"]];
  function ftypeDef(cat, ft) { return (FIELD_CATS[cat] || []).filter(function (t) { return t[0] === ft; })[0] || null; }
  function ftypeLabel(cat, ft) { var d = ftypeDef(cat, ft); return d ? d[1] : ""; }

  /* select-style dropdown button (opens a radioSheet picker — the mobile dropdown) */
  function afSelect(id, val, ph) {
    return '<button class="af-select' + (val ? "" : " ph") + '" id="' + id + '" type="button">' +
      '<span class="val">' + esc(val || ph) + '</span>' +
      '<svg class="cv" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 9l6 6 6-6"/></svg></button>';
  }
  function afCheck(id, label, sub, on) {
    return '<label class="af-check' + (on ? " on" : "") + '" id="' + id + '"><span class="bx">' + icCheck + '</span>' +
      '<span class="tx"><span class="t">' + esc(label) + '</span>' + (sub ? '<span class="s">' + esc(sub) + '</span>' : '') + '</span></label>';
  }

  function openAddField() {
    var step = 1, cat = "", ft = "", inputType = "Text", showInForm = true, req = false, options = ["", ""];
    function isChoice() { return cat === "Selections"; }
    function isShort() { return cat === "Text Answer" && ft === "ShortAnswer"; }
    function stepHdr() {
      return '<div class="af-steps"><span class="af-step' + (step === 1 ? " on" : " done") + '"><span class="n">1</span>Select Type</span>' +
        '<span class="af-stepline"></span>' +
        '<span class="af-step' + (step === 2 ? " on" : "") + '"><span class="n">2</span>Configure</span></div>';
    }
    function captureOptions() {
      var inps = $$(".af-optrow input", sheetRef); if (inps.length) options = inps.map(function (i) { return i.value; });
    }
    var sheetRef = null;
    function body() {
      if (step === 1) {
        return '<div class="ax-grip"></div>' + stepHdr() +
          '<div class="af-intro">Select a field category and type to add to your form</div>' +
          '<div class="ax-field"><label class="ax-label">Category</label>' + afSelect("afCat", cat, "Select a category") + '</div>' +
          (cat ? '<div class="ax-field"><label class="ax-label">Field Type</label>' + afSelect("afFt", ftypeLabel(cat, ft), "Select a field type") + '</div>' : '') +
          '<div class="af-foot"><button class="cfg-btn ghost" id="afCancel" type="button">Cancel</button>' +
            '<button class="cfg-btn primary" id="afNext" type="button"' + (cat && ft ? "" : " disabled") + '>Next: Configure Field ' + I.chevR + '</button></div>';
      }
      var optsHTML = isChoice() ? (
        '<div class="ax-field"><div class="af-optshd"><label class="ax-label" style="margin:0">Options</label>' +
          '<button class="af-addopt" id="afAddOpt" type="button">' + I.plus + 'Add Option</button></div>' +
          '<div class="af-opts">' + options.map(function (o, i) {
            return '<div class="af-optrow"><input type="text" value="' + esc(o) + '" placeholder="Option ' + (i + 1) + '">' +
              '<button class="af-optdel" type="button" data-i="' + i + '" aria-label="Remove option">' + I.trash + '</button></div>';
          }).join("") + '</div></div>'
      ) : "";
      return '<div class="ax-grip"></div>' + stepHdr() +
        '<div class="af-intro">Configure the “' + esc(ftypeLabel(cat, ft)) + '” field for your booking form</div>' +
        '<div class="ax-field"><label class="ax-label">Field Label <span class="req">*</span></label><div class="ax-control">' + I.note + '<input id="afName" type="text" placeholder="Enter field label" value="' + esc(afName_v) + '"></div></div>' +
        '<div class="ax-field"><label class="ax-label">Placeholder Text</label><div class="ax-control">' + I.note + '<input id="afPh" type="text" placeholder="Enter placeholder text" value="' + esc(afPh_v) + '"></div></div>' +
        (isShort() ? '<div class="ax-field"><label class="ax-label">Input Type</label>' + afSelect("afInput", inputType, "Text") + '</div>' : '') +
        optsHTML +
        afCheck("afReq", "Mandatory Field", "", req) +
        afCheck("afShow", "Show in Booking Form", "When unchecked, this field is hidden from the booking form but still available in the database.", showInForm) +
        '<div class="af-foot"><button class="cfg-btn ghost" id="afBack" type="button">' + I.chevL + ' Back</button>' +
          '<button class="cfg-btn ghost" id="afCancel2" type="button">Cancel</button>' +
          '<button class="cfg-btn primary" id="afSave" type="button">Add Field</button></div>';
    }
    var afName_v = "", afPh_v = "";
    function paint() { sheetRef = AX.openSheet(body()); rewire(); }
    function rewire() {
      var s = sheetRef;
      if (step === 1) {
        $("#afCat", s).addEventListener("click", function () {
          AX.radioSheet("Category", Object.keys(FIELD_CATS).map(function (c) { return { v: c, label: c, on: cat === c }; }), function (v) {
            cat = v; ft = ""; paint();
          });
        });
        var ftb = $("#afFt", s); if (ftb) ftb.addEventListener("click", function () {
          AX.radioSheet("Field Type", FIELD_CATS[cat].map(function (t) { return { v: t[0], label: t[1], on: ft === t[0] }; }), function (v) {
            ft = v; paint();
          });
        });
        $("#afCancel", s).addEventListener("click", AX.closeSheet);
        var nx = $("#afNext", s); if (nx && !nx.disabled) nx.addEventListener("click", function () { step = 2; paint(); });
      } else {
        var nmEl = $("#afName", s), phEl = $("#afPh", s);
        if (nmEl) nmEl.addEventListener("input", function () { afName_v = nmEl.value; });
        if (phEl) phEl.addEventListener("input", function () { afPh_v = phEl.value; });
        var inb = $("#afInput", s); if (inb) inb.addEventListener("click", function () {
          AX.radioSheet("Input Type", INPUT_TYPES.map(function (t) { return { v: t[0], label: t[0], on: inputType === t[0] }; }), function (v) { inputType = v; paint(); });
        });
        var addOpt = $("#afAddOpt", s); if (addOpt) addOpt.addEventListener("click", function () { captureOptions(); options.push(""); paint(); });
        $$(".af-optdel", s).forEach(function (b) { b.addEventListener("click", function () {
          captureOptions(); var i = +b.getAttribute("data-i"); if (options.length > 1) options.splice(i, 1); paint();
        }); });
        $("#afReq", s).addEventListener("click", function (e) { e.preventDefault(); captureOptions(); req = !req; this.classList.toggle("on", req); });
        $("#afShow", s).addEventListener("click", function (e) { e.preventDefault(); captureOptions(); showInForm = !showInForm; this.classList.toggle("on", showInForm); });
        $("#afBack", s).addEventListener("click", function () { captureOptions(); step = 1; paint(); });
        $("#afCancel2", s).addEventListener("click", AX.closeSheet);
        $("#afSave", s).addEventListener("click", function () {
          var nm = ($("#afName", s).value || "").trim(); if (!nm) { AX.toast("Enter a field label"); return; }
          captureOptions();
          var def = ftypeDef(cat, ft) || ["", "", "input"];
          var storeType = isShort() ? (INPUT_TYPES.filter(function (t) { return t[0] === inputType; })[0] || ["", "text"])[1] : def[2];
          var opts = isChoice() ? options.map(function (o) { return (o || "").trim(); }).filter(Boolean) : null;
          if (isChoice() && opts.length < 1) { AX.toast("Add at least one option"); return; }
          fields.push({
            id: "c" + Date.now().toString(36), name: nm, ph: $("#afPh", s).value || "Enter value",
            type: storeType, fieldType: ft, category: cat, inputType: isShort() ? inputType : null,
            options: opts, req: req, showInForm: showInForm, on: showInForm, custom: true
          });
          saveFields(); AX.closeSheet(); render(); AX.toast("Field added");
        });
      }
    }
    paint();
  }

  /* =========================================================
     DEPARTMENT CONFIGURATION
     ========================================================= */
  var DEPT_PAGE = 9;
  function departmentsView(host) {
    var depts = AX.DEPTS;
    var pages = Math.max(1, Math.ceil(depts.length / DEPT_PAGE));
    if (AX.state.deptPage > pages) AX.state.deptPage = pages;
    var page = AX.state.deptPage, start = (page - 1) * DEPT_PAGE, slice = depts.slice(start, start + DEPT_PAGE);

    var rows = slice.map(function (d, i) {
      var sn = start + i + 1, used = AX.deptInUse(d.id);
      return '<div class="dp-row"><span class="sn">' + sn + '</span>' +
        '<span class="nm"><span class="dp-dot" style="background:' + (d.color || "#8A978D") + '"></span>' + esc(d.name) + '</span>' +
        '<span class="st ' + (used ? "in" : "not") + '">' + (used ? "In Use" : "Not Used") + '</span>' +
        '<button class="dp-del' + (used ? " off" : "") + '" data-id="' + d.id + '"' + (used ? " disabled" : "") + ' aria-label="Delete">' + I.trash + '</button></div>';
    }).join("");

    var pager = pages > 1 ? '<div class="dp-pager"><button class="dp-pg arr" data-pg="' + (page - 1) + '"' + (page <= 1 ? " disabled" : "") + '>' + I.chevL + '</button>' +
      Array.apply(null, { length: pages }).map(function (_, i) { return '<button class="dp-pg num' + (i + 1 === page ? " on" : "") + '" data-pg="' + (i + 1) + '">' + (i + 1) + '</button>'; }).join("") +
      '<button class="dp-pg arr" data-pg="' + (page + 1) + '"' + (page >= pages ? " disabled" : "") + '>' + I.chevR + '</button></div>' : '';

    host.innerHTML = tabBar() +
      '<div class="cfg-card">' +
        '<div class="dp-hd"><div class="dp-ttl"><span class="ic">' + I.users + '</span>Manage Departments</div>' +
          '<button class="cfg-btn primary sm" id="dpCreate">' + I.plus + 'Create</button></div>' +
        '<div class="dp-note2">' + I.warn + 'These departments power the appointment booking form, detail and agent assignment. In-use departments can\u2019t be deleted.</div>' +
        '<div class="dp-colhd"><span class="c-sn">S.No</span><span class="c-nm">Department Name</span><span class="c-st">Status</span><span class="c-ac"></span></div>' +
        '<div class="dp-list">' + rows + '</div>' +
        pager +
      '</div>';

    wireTabs(host);
    $("#dpCreate", host).addEventListener("click", openCreateDept);
    $$(".dp-del:not(.off)", host).forEach(function (b) {
      b.addEventListener("click", function () {
        var id = b.getAttribute("data-id"), d = AX.deptById(id);
        AX.confirm({ title: "Delete department?", sub: "This permanently removes \u201C" + (d ? d.name : "") + "\u201D.", go: "Delete", onGo: function () {
          AX.removeDept(id); render(host); AX.toast("Department deleted");
        } });
      });
    });
    $$(".dp-pg[data-pg]", host).forEach(function (b) { b.addEventListener("click", function () {
      var p = +b.getAttribute("data-pg"); if (p < 1 || p > pages || p === page) return; AX.state.deptPage = p; render(host);
    }); });
  }
  function openCreateDept() {
    var html = '<div class="ax-grip"></div><div class="ax-sheet-head"><div class="ax-sheet-ttl"><span style="display:inline-flex;vertical-align:-3px;width:18px;height:18px;margin-right:7px">' + I.users + '</span>Create Department</div></div>' +
      '<div class="ax-field"><label class="ax-label">Department Name</label><div class="ax-control">' + I.dept + '<input id="cdName" type="text" placeholder="Enter department name" autocomplete="off"></div></div>' +
      '<div class="af-foot"><button class="cfg-btn ghost" id="cdCancel">Cancel</button>' +
        '<button class="cfg-btn primary" id="cdCreate">Create</button></div>';
    var s = AX.openSheet(html);
    var inp = $("#cdName", s); setTimeout(function () { try { inp.focus(); } catch (e) {} }, 80);
    $("#cdCancel", s).addEventListener("click", AX.closeSheet);
    function create() {
      var nm = (inp.value || "").trim(); if (!nm) { AX.toast("Enter a department name"); return; }
      var dep = AX.addDept(nm);
      if (!dep) { AX.toast("That department already exists"); return; }
      AX.closeSheet(); AX.state.deptPage = Math.ceil(AX.DEPTS.length / DEPT_PAGE); render(); AX.toast("Department created");
    }
    $("#cdCreate", s).addEventListener("click", create);
    inp.addEventListener("keydown", function (e) { if (e.key === "Enter") create(); });
  }

  /* =========================================================
     ROUTER
     ========================================================= */
  function wireTabs(host) {
    $$("#cfgTabs .cfg-tab", host).forEach(function (b) {
      b.addEventListener("click", function () { AX.state.alertOpen = null; AX.state.cfgTab = b.getAttribute("data-t"); render(host); });
    });
  }
  function render(host) {
    host = host || $("#axView"); if (!host) return;
    var t = AX.state.cfgTab;
    if (t === "webhook") webhookView(host);
    else if (t === "bookingform") bookingFormView(host);
    else if (t === "departments") departmentsView(host);
    else if (AX.state.alertOpen) alertConfigView(host);
    else alertsView(host);
  }

  AX.renderSettings = function (host) { render(host); };
  /* header "+" / context action repurposed per config sub-tab */
  AX.addField = function () {
    if (AX.state.cfgTab === "bookingform") openAddField();
    else if (AX.state.cfgTab === "departments") openCreateDept();
    else AX.toast("Open Booking Form to add fields");
  };

  /* ---- expose user/business alert config so the appointment lifecycle can
     deliver the configured WhatsApp template into the customer's chat ---- */
  window.AskEvaApptAlerts = {
    enabled: function (scope, key) { return !!(alerts[scope] && alerts[scope][key]); },
    config: function (scope, key) { return cfgFor(scope, key); },
    template: function (scope, key) {
      var c = cfgFor(scope, key);
      var name = c && c.prelim && c.prelim.template;
      if (!name) return null;
      var t = tplByName(name) || { n: name, p: "", cat: (c.prelim.type || "Template") };
      return { n: t.n, p: t.p || "", cat: t.cat || (c.prelim.type || "Template"), mapField: c.mapField || "Name" };
    },
    followups: function (scope, key) {
      var c = cfgFor(scope, key);
      return (c.followups || []).filter(function (f) { return f && f.on && f.template; }).map(function (f) {
        var t = tplByName(f.template) || { n: f.template, p: "", cat: (f.type || "Utility") };
        return { n: t.n, p: t.p || "", cat: t.cat || (f.type || "Utility"), delayType: f.delayType, delayValue: f.delayValue };
      });
    }
  };

  setTimeout(function () {
    if (AX.state.tab === "settings") { var h = $("#axView"); if (h && !h.querySelector(".cfg-tabs")) render(h); }
  }, 0);

})(window.AX);
