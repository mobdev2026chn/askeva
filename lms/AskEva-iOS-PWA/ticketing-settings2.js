/* =========================================================
   AskEva — Ticket Settings (part 2)
   Registers: Notification (Alerts) Configuration, Ticket Form
   (Ticketing Flow / Customer Response Flow), Webhook.
   Adds to window.TKSettings. Uses window.TK.
   ========================================================= */
(function () {
  "use strict";
  var TK = window.TK, S = window.TKSettings; if (!TK || !S) return;
  var $ = TK.$, $$ = TK.$$, esc = TK.esc, toast = TK.toast, IC = S.IC;
  IC.bell = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 9a6 6 0 0 1 12 0c0 5 2 6 2 6H4s2-1 2-6Z"/><path d="M10 19a2 2 0 0 0 4 0"/></svg>';
  IC.globe = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3a14 14 0 0 1 0 18M12 3a14 14 0 0 0 0 18"/></svg>';
  IC.link = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M10 13a5 5 0 0 0 7 0l3-3a5 5 0 0 0-7-7l-1.5 1.5"/><path d="M14 11a5 5 0 0 0-7 0l-3 3a5 5 0 0 0 7 7l1.5-1.5"/></svg>';

  function load(k, d) { try { var v = JSON.parse(localStorage.getItem(k)); return v == null ? d : v; } catch (e) { return d; } }
  function store(k, v) { try { localStorage.setItem(k, JSON.stringify(v)); } catch (e) {} }

  /* =========================================================
     NOTIFICATION (ALERTS) CONFIGURATION
     ========================================================= */
  var EVENTS = [
    ["assigned", "Ticket Assigned"], ["awaiting", "Ticket Awaiting for Customer"], ["pending", "Ticket Pending"],
    ["inprogress", "Ticket In Progress"], ["completed", "Ticket Completed"], ["reopened", "Ticket Reopened"],
    ["delay", "Agent Response Delay"], ["resolve", "Ticket Resolve Time"]
  ];
  /* per-event template + variables (UI only — backend wires the real send) */
  var FIELDS = ["Customer Name", "Ticket ID", "Assignee Name", "Mobile Number", "Department", "Subject", "Status", "Priority", "Company Name"];
  var EVCFG = {
    assigned:   { tpl: "ulity_test", type: "UTILITY", header: "text", msg: "Your service update is completed successfully. For any queries, please contact support", vars: [], user: true, dmap: {} },
    awaiting:   { tpl: "awaiting_customer_response_form_copy_copy", type: "MARKETING", header: "text", msg: "Hi this is from Askeva.\nPlease find the answers for {{questions}}\n\nThank you!", vars: ["questions"], actions: "flow: fill", user: true, dmap: { questions: "Ticket ID" } },
    pending:    { tpl: "ticket_pending", type: "UTILITY", header: "text", msg: "Hi {{Name}}, Your {{ticketid}} is now moved to pending.", vars: ["Name", "ticketid"], user: true, dmap: { Name: "Customer Name", ticketid: "Ticket ID" } },
    inprogress: { tpl: "ticket_inprogress_copy", type: "UTILITY", header: "text", msg: "Hello {{1}},\n\nWe wanted to let you know that your support ticket {{2}} is now in progress.\nOur team member *{{3}}* has started working on your request and will keep you updated on the status.\n\nThank you for your patience and cooperation.", vars: ["1", "2", "3"], user: true, dmap: { "1": "Customer Name", "2": "Ticket ID", "3": "Assignee Name" } },
    completed:  { tpl: "ticket_completed", type: "MARKETING", header: "text", msg: "Hi {{1}},\n\nYour ticket has been resolved. Please review the update and let us know if everything is working as expected.\n\nIf the issue persists or you need further assistance, feel free to reopen the ticket.\n\nThank you for your patience and cooperation!", vars: ["1"], user: true, dmap: { "1": "Customer Name" } },
    reopened:   { tpl: "test0001", type: "MARKETING", header: "text", msg: "\u0643\u064a\u0641 \u062d\u0627\u0644\u0643", vars: [], user: true, dmap: {} },
    delay:      { tpl: "agent_response_delay", type: "MARKETING", header: "text", msg: "Hi {{Name}},\nyour response is delay , kindly response the ticket before the time limit.", vars: ["Name"], user: false, dmap: { Name: "Assignee Name" } },
    resolve:    { tpl: "resolve_time_exceed", type: "UTILITY", header: "text", msg: "Hi {{Name}},\nticket resolve time is exceed kindly look into this and close asap.", vars: ["Name"], user: false, dmap: { Name: "Assignee Name" } }
  };
  var ALK = "askeva.tset.alerts.v1";
  var alerts = load(ALK, {});
  function alertOf(ev) {
    var cfg = EVCFG[ev] || { tpl: "utility_test", vars: [], user: true, dmap: {} };
    if (!alerts[ev]) {
      alerts[ev] = { biz: { on: true, tpl: cfg.tpl, map: Object.assign({}, cfg.dmap || {}) }, user: { on: true, tpl: cfg.tpl, map: Object.assign({}, cfg.dmap || {}) } };
    }
    ["biz", "user"].forEach(function (k) { if (alerts[ev][k] && !alerts[ev][k].map) alerts[ev][k].map = Object.assign({}, cfg.dmap || {}); });
    return alerts[ev];
  }
  function saveAlerts() { store(ALK, alerts); }
  /* expose USER notification config so the ticket lifecycle can deliver the
     configured template into the customer's chat */
  window.TKNotify = {
    enabled: function (ev) { var a = alertOf(ev); return !!(a.user && a.user.on); },
    tpl: function (ev) { var a = alertOf(ev); return a.user ? a.user.tpl : null; }
  };
  var TPL_MSG = "Your service update is completed successfully. For any queries, please contact support";
  var curEv = "assigned";

  S.register({
    id: "alerts", title: "Notification Configuration", sub: "Configure automated notifications for ticket events", icon: IC.bell || S.IC.gear,
    render: function (host) {
      var ev = curEv, def = alertOf(ev), cfg = EVCFG[ev] || { tpl: "utility_test", vars: [], user: true, dmap: {} }, evLabel = EVENTS.filter(function (e) { return e[0] === ev; })[0][1];
      host.innerHTML =
        '<div class="na-events" id="naEvents">' + EVENTS.map(function (e) {
          return '<button class="na-ev' + (ev === e[0] ? " on" : "") + '" data-e="' + e[0] + '">' + esc(e[1]) + '</button>';
        }).join("") + '</div>' +
        alertCard(evLabel + " - Business Alert", "biz", def.biz, cfg) +
        (cfg.user ? alertCard(evLabel + " - User Alert", "user", def.user, cfg) : "");
      $$("#naEvents .na-ev", host).forEach(function (b) { b.addEventListener("click", function () { curEv = b.getAttribute("data-e"); S.render(); }); });
      $$(".na-card", host).forEach(function (card) {
        var kind = card.getAttribute("data-k");
        var tg = $(".na-toggle", card); if (tg) tg.addEventListener("click", function () { def[kind].on = !def[kind].on; saveAlerts(); S.render(); });
        var sel = $(".na-tpl", card); if (sel) sel.addEventListener("click", function () {
          TK.radioSheet("Select template", ["utility_test", "welcome_v2", "resolution_note", "followup_msg"].map(function (t) { return { v: t, label: t, on: def[kind].tpl === t }; }), function (v) { def[kind].tpl = v; saveAlerts(); S.render(); });
        });
        var sv = $(".na-save", card); if (sv) sv.addEventListener("click", function () { saveAlerts(); toast("Configuration saved"); });
        var rs = $(".na-reset", card); if (rs) rs.addEventListener("click", function () { def[kind] = { on: true, tpl: cfg.tpl, map: Object.assign({}, cfg.dmap || {}) }; saveAlerts(); S.render(); toast("Reset"); });
        $$(".na-mapsel", card).forEach(function (ms) { ms.addEventListener("click", function () {
          var vn = ms.getAttribute("data-var");
          TK.radioSheet("Map " + vn.toUpperCase(), FIELDS.map(function (f) { return { v: f, label: f, on: (def[kind].map && def[kind].map[vn]) === f }; }), function (val) { def[kind].map = def[kind].map || {}; def[kind].map[vn] = val; saveAlerts(); S.render(); });
        }); });
      });
    }
  });
  function alertCard(title, kind, d, cfg) {
    cfg = cfg || { tpl: d.tpl, type: "UTILITY", header: "text", msg: TPL_MSG, vars: [] };
    var vars = cfg.vars || [];
    var preview = '<div class="na-preview"><div class="pv-hd"><span class="t">Type: <b>' + esc(cfg.type || "UTILITY") + '</b></span><span class="h">Header: <b>' + esc(cfg.header || "text") + '</b></span></div>' +
      '<div class="pv-msg-l">Message:</div><div class="pv-msg">' + esc(cfg.msg || "").replace(/\n/g, "<br>") + '</div>' +
      (vars.length ? '<div class="pv-meta">Variables: <b>' + vars.map(esc).join(", ") + '</b></div>' : '') +
      (cfg.actions ? '<div class="pv-meta">Actions: <b>' + esc(cfg.actions) + '</b></div>' : '') +
    '</div>';
    var maps = vars.map(function (v) {
      var val = (d.map && d.map[v]) || "";
      return '<div class="na-mapfield"><label>Map ' + esc(v.toUpperCase()) + ' <span class="req">*</span></label>' +
        '<button class="na-mapsel' + (val ? "" : " ph") + '" data-var="' + esc(v) + '"><span class="v">' + esc(val || "Select field") + '</span><span class="cv">' + (IC.chevD || "") + '</span></button></div>';
    }).join("");
    return '<div class="na-card" data-k="' + kind + '"><div class="na-hd"><div class="na-ttl">' + esc(title) + '</div>' +
      '<button class="na-toggle' + (d.on ? " on" : "") + '" role="switch" aria-checked="' + d.on + '"><span class="kn"></span><span class="tx">' + (d.on ? "ON" : "OFF") + '</span></button></div>' +
      '<div class="na-tplrow"><span class="lbl">Select Template <span class="req">*</span></span>' +
        '<button class="na-tpl">Template: <b>' + esc(d.tpl || cfg.tpl) + '</b>' + (IC.upload || "") + '</button></div>' +
      preview + maps +
      '<div class="na-foot"><button class="na-save cfg-btn primary sm">' + IC.save + 'Save Configuration</button>' +
        '<button class="na-reset cfg-btn danger-solid sm">Reset</button></div></div>';
  }

  /* =========================================================
     TICKET FORM (Ticketing Flow / Customer Response Flow)
     ========================================================= */
  var TFK = "askeva.tset.ticketform.v2";
  var DEF_TF = {
    ticketing: [
      { id: "subject", name: "Subject", type: "textinput", req: true, static: true, ph: "" },
      { id: "desc", name: "Description", type: "textarea", req: true, static: true, ph: "" },
      { id: "doc", name: "Document", type: "document", req: false, static: true, ph: "Document Upload", meta: "File Types: pdf, doc, docx, jpg, jpeg, png · Max File Size: 100MB" },
      { id: "dept", name: "Department", type: "select", req: true, static: true, ph: "Select department" },
      { id: "cf", name: "Reference ID", type: "text", req: true, static: false, ph: "e.g. REF-2041" }
    ],
    customer: [
      { id: "cdesc", name: "Description", type: "textarea", req: true, static: true, ph: "Enter description" },
      { id: "cdoc", name: "Documents", type: "document", req: false, static: true, ph: "Upload supporting documents", meta: "File Types: pdf, doc, docx, jpg, jpeg, png, xls, xlsx · Max File Size: 10MB" }
    ]
  };
  var tf = load(TFK, DEF_TF);
  if (!tf.ticketing || !tf.customer) tf = JSON.parse(JSON.stringify(DEF_TF));
  function saveTf() { store(TFK, tf); }
  /* expose configured ticket-form fields so the live create-ticket form reflects them */
  TK.ticketForm = function (flow) { return (tf[flow || "ticketing"] || []).slice(); };
  var tfFlow = "ticketing";

  S.register({
    id: "ticketForm", title: "Ticket Form", sub: "Customize Flows and properties", icon: IC.tag,
    render: function (host) {
      var fields = tf[tfFlow];
      var totals = { total: fields.length, static: fields.filter(function (f) { return f.static; }).length, custom: fields.filter(function (f) { return !f.static; }).length, req: fields.filter(function (f) { return f.req; }).length };
      var isT = tfFlow === "ticketing";
      host.innerHTML =
        '<div class="tf-flowtabs"><button class="tf-flow' + (isT ? " on" : "") + '" data-f="ticketing">Ticketing Flow</button>' +
          '<button class="tf-flow' + (!isT ? " on" : "") + '" data-f="customer">Customer Response Flow</button></div>' +
        '<div class="cfg-card"><div class="bf-hd"><div><div class="bf-ttl">' + (isT ? "Ticketing Form Configuration" : "Customer Response Flow Configuration") + '</div>' +
          '<div class="bf-sub">' + (isT ? "Configure the fields for your ticket creation form" : "Configure the fields for your customer response form") + '</div></div></div>' +
          '<div class="bf-actions"><button class="cfg-btn primary sm" id="tfPublish">' + IC.upload + 'Publish Flow</button><button class="cfg-btn primary sm" id="tfAdd">' + IC.plus + 'Add Field</button></div>' +
          '<div class="bf-hint"><b>Drag and drop to reorder fields.</b> Changes are saved automatically.</div>' +
          '<div class="bf-list" id="tfList">' + fields.map(tfRow).join("") + '</div>' +
          '<div class="tf-totals"><span><b>Total Fields:</b> ' + totals.total + '</span><span><b>Static Fields:</b> ' + totals.static + '</span>' +
            '<span><b>Custom Fields:</b> ' + totals.custom + '</span><span><b>Required Fields:</b> ' + totals.req + '</span></div></div>';
      $$(".tf-flow", host).forEach(function (b) { b.addEventListener("click", function () { tfFlow = b.getAttribute("data-f"); S.render(); }); });
      $("#tfPublish", host).addEventListener("click", function () { saveTf(); toast("Flow published successfully"); });
      $("#tfAdd", host).addEventListener("click", function () { tfAddField(); });
      $$(".bf-row .edit", host).forEach(function (b) { b.addEventListener("click", function () { tfEdit(b.getAttribute("data-id")); }); });
      $$(".bf-row .del", host).forEach(function (b) { b.addEventListener("click", function () { var id = b.getAttribute("data-id"); TK.showConfirm({ title: "Delete field?", sub: "This custom field will be removed.", go: "Delete", onGo: function () { tf[tfFlow] = tf[tfFlow].filter(function (x) { return x.id !== id; }); saveTf(); S.render(); toast("Field deleted"); } }); }); });
      tfDrag(host);
    }
  });
  function tfRow(f) {
    return '<div class="bf-row" data-id="' + f.id + '" draggable="true"><span class="bf-drag">' + IC.plus + '<span>Drag</span></span>' +
      '<div class="bf-mid"><div class="bf-name">' + esc(f.name) + (f.req ? '<span class="rq">*</span>' : '') +
        '<span class="bf-badge type">' + esc(f.type) + '</span>' + (f.static ? '<span class="bf-badge stat">Static Field</span>' : '<span class="bf-badge custom">Custom</span>') + '</div>' +
        (f.ph ? '<div class="bf-ph">Placeholder: ' + esc(f.ph) + '</div>' : '') +
        (f.meta ? '<div class="bf-meta2">' + esc(f.meta) + '</div>' : '') + '</div>' +
      '<div class="bf-rowacts"><button class="edit" data-id="' + f.id + '" aria-label="Edit">' + IC.edit + '</button>' +
        (!f.static ? '<button class="del" data-id="' + f.id + '" aria-label="Delete">' + IC.trash + '</button>' : '') + '</div></div>';
  }
  function tfDrag(host) {
    var list = $("#tfList", host); if (!list) return; var dragEl = null;
    $$(".bf-row", list).forEach(function (row) {
      row.addEventListener("dragstart", function () { dragEl = row; row.classList.add("dragging"); });
      row.addEventListener("dragend", function () { row.classList.remove("dragging"); dragEl = null;
        var ids = $$(".bf-row", list).map(function (r) { return r.getAttribute("data-id"); });
        tf[tfFlow].sort(function (a, b) { return ids.indexOf(a.id) - ids.indexOf(b.id); }); saveTf();
      });
    });
    list.addEventListener("dragover", function (e) { e.preventDefault(); if (!dragEl) return; var after = afterEl(list, e.clientY); if (after == null) list.appendChild(dragEl); else list.insertBefore(dragEl, after); });
  }
  function afterEl(list, y) { var els = $$(".bf-row:not(.dragging)", list), c = null, off = -Infinity; els.forEach(function (el) { var b = el.getBoundingClientRect(), d = y - b.top - b.height / 2; if (d < 0 && d > off) { off = d; c = el; } }); return c; }
  function tfEdit(id) {
    var f = tf[tfFlow].filter(function (x) { return x.id === id; })[0];
    var html = '<div class="ax-grip"></div><div class="ax-sheet-head"><div class="ax-sheet-ttl">Edit field</div><div class="ax-sheet-sub">' + esc(f.name) + '</div></div>' +
      '<div class="ax-field"><label class="ax-label">Label</label><div class="ax-control">' + IC.tag + '<input id="tfL" type="text" value="' + esc(f.name) + '"></div></div>' +
      '<div class="ax-field"><label class="ax-label">Placeholder</label><div class="ax-control">' + IC.tag + '<input id="tfP" type="text" value="' + esc(f.ph || "") + '"></div></div>' +
      '<button class="ax-reason' + (f.req ? " on" : "") + '" id="tfR" style="width:100%;margin-bottom:10px"><span class="rd"></span>Required field</button>' +
      (f.static ? '<div class="ef-locknote">' + IC.info + 'This is a static field and cannot be deleted.</div>' : '') +
      '<button class="ax-sheetbtn" id="tfSave">Save field</button>';
    var s = TK.openSheet(html); var req = f.req;
    $("#tfR", s).addEventListener("click", function () { req = !req; this.classList.toggle("on", req); });
    $("#tfSave", s).addEventListener("click", function () { f.name = ($("#tfL", s).value || f.name).trim(); f.ph = $("#tfP", s).value; f.req = req; saveTf(); TK.closeSheet(); S.render(); toast("Field saved"); });
  }
  function tfAddField() {
    var type = "text", req = true;
    var TYPES = [["text", "Text"], ["textinput", "Text Input"], ["textarea", "Text Area"], ["select", "Dropdown"], ["document", "Document"], ["number", "Number"], ["date", "Date"]];
    var html = '<div class="ax-grip"></div><div class="ax-sheet-head"><div class="ax-sheet-ttl">Add field</div></div>' +
      '<div class="ax-field"><label class="ax-label">Label</label><div class="ax-control">' + IC.tag + '<input id="afL" type="text" placeholder="e.g. Order ID"></div></div>' +
      '<div class="ax-field"><label class="ax-label">Placeholder</label><div class="ax-control">' + IC.tag + '<input id="afP" type="text" placeholder="Enter value"></div></div>' +
      '<div class="ax-field"><label class="ax-label">Type</label><div class="ax-chiprow" id="afT">' + TYPES.map(function (t, i) { return '<button class="ax-pillchip' + (i === 0 ? " on" : "") + '" data-t="' + t[0] + '">' + t[1] + '</button>'; }).join("") + '</div></div>' +
      '<button class="ax-reason on" id="afR" style="width:100%;margin-bottom:10px"><span class="rd"></span>Required field</button>' +
      '<button class="ax-sheetbtn" id="afSave">Add field</button>';
    var s = TK.openSheet(html);
    $$("#afT .ax-pillchip", s).forEach(function (b) { b.addEventListener("click", function () { type = b.getAttribute("data-t"); $$("#afT .ax-pillchip", s).forEach(function (x) { x.classList.remove("on"); }); b.classList.add("on"); }); });
    $("#afR", s).addEventListener("click", function () { req = !req; this.classList.toggle("on", req); });
    $("#afSave", s).addEventListener("click", function () { var nm = ($("#afL", s).value || "").trim(); if (!nm) { toast("Enter a label"); return; } tf[tfFlow].push({ id: "f" + Date.now().toString(36), name: nm, type: type, req: req, static: false, ph: $("#afP", s).value || "" }); saveTf(); TK.closeSheet(); S.render(); toast("Field added"); });
  }

  /* =========================================================
     WEBHOOK (reuses .wh-* styles)
     ========================================================= */
  var WHK = "askeva.tset.webhook.v1";
  var wh = load(WHK, { enabled: true, url: "", event: "all", hkey: "askeva", hval: "vkylff", editing: false });
  function saveWh() { store(WHK, wh); }
  var WEVENTS = [["all", "All Events"], ["created", "Ticket Created"], ["updated", "Ticket Updated"], ["assigned", "Ticket Assigned"], ["resolved", "Ticket Resolved"]];
  var WSAMPLE = '{\n  "event": "ticket_created",\n  "timestamp": "2025-10-06T09:41:22.594Z",\n  "userId": "user_123",\n  "data": {\n    "ticket_id": "TKT_67890",\n    "ticketId": "TK001",\n    "subject": "Unable to login to my account",\n    "description": "I\'m getting an error message when trying to login with my credentials.",\n    "priority": "high",\n    "status": "open",\n    "customer": {\n      "name": "John Doe",\n      "email": "john.doe@example.com",\n      "phone": "+1234567890"\n    },\n    "department": "Technical Support",\n    "assignedTo": "agent@example.com",\n    "source": "web",\n    "dueDate": "2025-10-08T09:41:22.594Z",\n    "created_at": "2025-10-06T09:41:22.594Z",\n    "updated_at": "2025-10-06T09:41:22.594Z"\n  }\n}';

  S.register({
    id: "webhook", title: "Webhook Configuration", sub: "Configure webhook endpoints for real-time events", icon: IC.link || S.IC.gear,
    render: function (host) {
      var ed = wh.editing, ev = (WEVENTS.filter(function (e) { return e[0] === wh.event; })[0] || WEVENTS[0])[1];
      host.innerHTML = '<div class="cfg-card">' +
        '<div class="wh-hd"><div class="wh-ttl"><span class="ic">' + (IC.link || "") + '</span>Webhook Configuration</div>' +
          '<button class="wh-enable' + (wh.enabled ? " on" : "") + '" id="whEn"><span class="lbl">Enabled</span><span class="sw"><span class="kn">' + (wh.enabled ? IC.check : "") + '</span></span></button></div>' +
        '<label class="wh-label">Webhook URL <i>*</i></label>' +
        '<div class="wh-input' + (ed ? "" : " ro") + '">' + (ed ? '<input id="whUrl" type="url" placeholder="https://webhook.site/…" value="' + esc(wh.url) + '">' : '<span class="val' + (wh.url ? "" : " ph") + '">' + esc(wh.url || "https://webhook.site/618300e7-3ede-4210-aed5-49042c49db8c") + '</span>') + '</div>' +
        '<label class="wh-label">Event Type <i>*</i></label>' + (ed ? '<button class="wh-input as-btn" id="whEv"><span class="val">' + esc(ev) + '</span><span class="cv">' + IC.chevR + '</span></button>' : '<div class="wh-input ro"><span class="val">' + esc(ev) + '</span></div>') +
        '<label class="wh-label mt">Header Parameters <span class="opt">(Optional)</span></label>' +
        '<div class="wh-hrow">' + (ed ? '<input id="whK" class="wh-input edit" type="text" placeholder="Header Key" value="' + esc(wh.hkey) + '"><input id="whV" class="wh-input edit" type="text" placeholder="Header Value" value="' + esc(wh.hval) + '">' :
          '<div class="wh-input ro"><span class="val' + (wh.hkey ? "" : " ph") + '">' + esc(wh.hkey || "Header Key") + '</span></div><div class="wh-input ro"><span class="val' + (wh.hval ? "" : " ph") + '">' + esc(wh.hval || "Header Value") + '</span></div>') + '</div>' +
        '<label class="wh-label mt">Sample Payload Structure</label><pre class="wh-code">' + payload(WSAMPLE) + '</pre>' +
        '<div class="wh-note2">Your webhook endpoint should accept POST requests with JSON payloads</div>' +
        '<div class="wh-actions"><button class="cfg-btn primary" id="whEdit">' + (ed ? IC.check + 'Save Configuration' : IC.edit + 'Edit Configuration') + '</button>' +
          '<button class="cfg-btn ghost" id="whTest"' + (wh.url ? "" : " disabled") + '>' + (IC.play || "") + 'Test Webhook</button>' +
          '<button class="cfg-btn danger-o" id="whReset">Reset</button></div></div>';
      $("#whEn", host).addEventListener("click", function () { wh.enabled = !wh.enabled; saveWh(); S.render(); });
      var u = $("#whUrl", host); if (u) u.addEventListener("input", function (e) { wh.url = e.target.value; });
      var k = $("#whK", host); if (k) k.addEventListener("input", function (e) { wh.hkey = e.target.value; });
      var v = $("#whV", host); if (v) v.addEventListener("input", function (e) { wh.hval = e.target.value; });
      var evb = $("#whEv", host); if (evb) evb.addEventListener("click", function () { TK.radioSheet("Event Type", WEVENTS.map(function (e) { return { v: e[0], label: e[1], on: wh.event === e[0] }; }), function (vv) { wh.event = vv; saveWh(); S.render(); }); });
      $("#whEdit", host).addEventListener("click", function () { if (wh.editing) { saveWh(); wh.editing = false; toast("Webhook saved"); } else wh.editing = true; S.render(); });
      var tb = $("#whTest", host); if (tb && !tb.disabled) tb.addEventListener("click", function () { toast("Test event sent"); });
      $("#whReset", host).addEventListener("click", function () { TK.showConfirm({ title: "Reset webhook?", sub: "Clears URL, event and headers.", go: "Reset", onGo: function () { wh = { enabled: wh.enabled, url: "", event: "all", hkey: "", hval: "", editing: false }; saveWh(); S.render(); toast("Webhook reset"); } }); });
    }
  });
  function payload(src) { return esc(src).replace(/(&quot;[^&]*?&quot;)(\s*:)/g, '<span class="k">$1</span>$2').replace(/(:\s*)(&quot;[^&]*?&quot;)/g, '$1<span class="s">$2</span>'); }
})();
