/* =========================================================
   AskEva — Shared Library
   Single source of truth for:
     • Templates  → window.AskEvaTemplates  (list + shared picker UI)
     • Quick Replies → window.AskEvaQuickReplies (persisted list, edited in Settings)
   Any screen that sends a template or inserts a quick reply pulls from here,
   so the UI + data stay identical everywhere.
   ========================================================= */
(function () {
  "use strict";
  var $ = function (s, r) { return (r || document).querySelector(s); };
  var $$ = function (s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); };
  function host() { return document.getElementById("screen") || document.body; }
  var _tT;
  function toast(msg) {
    var t = document.getElementById("toast"); if (!t) return;
    t.textContent = msg; t.style.opacity = "1"; t.style.transform = "translateX(-50%) translateY(0)";
    clearTimeout(_tT); _tT = setTimeout(function () { t.style.opacity = "0"; t.style.transform = "translateX(-50%) translateY(20px)"; }, 1800);
  }
  function esc(s) { return String(s == null ? "" : s).replace(/[&<>"]/g, function (c) { return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]; }); }

  var ICX = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M18 6 6 18M6 6l12 12"/></svg>';
  var ICSEARCH = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><circle cx="11" cy="11" r="7"/><path d="M21 21l-4.3-4.3"/></svg>';
  var ICSEND = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 12h14m0 0-5-5m5 5-5 5"/></svg>';

  /* ============================================================
     QUICK REPLIES — persisted single source (edited in Lead Settings)
     ============================================================ */
  var QR_KEY = "askeva.quickreplies.v1";
  var QR_SEED = [
    { t: "test", m: "testingggghhh" },
    { t: "TESTING", m: "Testingghhhhhh" },
    { t: "askeva", m: "testing" },
    { t: "Exam", m: "Questions" }
  ];
  var qr;
  try { var raw = localStorage.getItem(QR_KEY); qr = raw ? JSON.parse(raw) : null; } catch (e) { qr = null; }
  if (!qr || !qr.length) qr = QR_SEED.slice();
  var qrSubs = [];
  function qrSave() {
    try { localStorage.setItem(QR_KEY, JSON.stringify(qr)); } catch (e) {}
    qrSubs.forEach(function (f) { try { f(qr); } catch (_) {} });
  }
  window.AskEvaQuickReplies = {
    list: function () { return qr; },
    add: function (o) { qr.unshift(o); qrSave(); },
    update: function (i, o) { qr[i] = o; qrSave(); },
    remove: function (i) { qr.splice(i, 1); qrSave(); },
    save: qrSave,
    subscribe: function (f) { if (typeof f === "function") qrSubs.push(f); }
  };

  /* ============================================================
     TEMPLATES — single source + shared picker UI
     ============================================================ */
  var TI = {
    Text: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M5 7V5h14v2M9 19h6M12 5v14"/></svg>',
    Image: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="4" width="18" height="16" rx="2.5"/><circle cx="8.5" cy="9.5" r="1.6"/><path d="m4 17 5-5 4 4 3-3 4 4"/></svg>',
    File: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14 3H7a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V8z"/><path d="M14 3v5h5M9 13h6M9 17h4"/></svg>',
    Video: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="6" width="13" height="12" rx="2.5"/><path d="m16 10 5-3v10l-5-3z"/></svg>'
  };
  var TPL = [
    { n: "Welcome message", p: "Hi! Thanks for reaching out to AskEva.", type: "Text", cat: "Marketing" },
    { n: "askeva_user", p: "Welcome to our Company. Thank You!", type: "Text", cat: "Marketing" },
    { n: "summer_glasses", p: "Hot Glasses for Hot Summer Trips", type: "Image", cat: "Marketing" },
    { n: "demo_sample", p: "Welcome to Askeva!", type: "Text", cat: "Marketing" },
    { n: "call_to_action", p: "Welcome to India — explore our offers", type: "Video", cat: "Marketing" },
    { n: "Pricing & plans", p: "Here are our plans and pricing details…", type: "File", cat: "Utility" },
    { n: "Follow-up", p: "Just checking in — any questions for us?", type: "Text", cat: "Utility" },
    { n: "Payment link", p: "Complete your purchase via this secure link.", type: "File", cat: "Utility" },
    { n: "OTP verification", p: "Your AskEva code is {{1}}. Valid 10 minutes.", type: "Text", cat: "Authentication" },
    { n: "Login alert", p: "New sign-in detected on your account.", type: "Text", cat: "Authentication" },
    { n: "lead_remainder_copy", p: "Hi {{Name}} the lead of mail id {{mailid}} you have setup remainder for this {{description}}.Thank you", type: "Text", cat: "Utility", header: "text" },
    { n: "test_variables", p: "Hellow {{Name}} ! Welcome to Askeva. We are having the best summer offers that shines your business days.", type: "Text", cat: "Marketing", header: "text" }
  ];
  var CATS = ["Marketing", "Utility", "Authentication"];

  var CHEVD = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m6 9 6 6 6-6"/></svg>';
  var BACKI = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="m15 18-6-6 6-6"/></svg>';

  /* ---- variable helpers (shared everywhere a template is used) ---- */
  function reEsc(s) { return String(s).replace(/[.*+?^${}()|[\]\\]/g, "\\$&"); }
  function extractVars(str) {
    var re = /\{\{\s*([^{}]+?)\s*\}\}/g, m, seen = {}, out = [];
    while ((m = re.exec(String(str || "")))) { var tok = m[1].trim(); if (tok && !seen[tok.toLowerCase()]) { seen[tok.toLowerCase()] = 1; out.push(tok); } }
    return out;
  }
  function fieldOptions() {
    var core = ["Name", "Mobile", "Email", "Company", "City", "Country", "Date"];
    var attrs = [];
    try { if (window.AskEvaUserAttrs && window.AskEvaUserAttrs.list) attrs = window.AskEvaUserAttrs.list().map(function (a) { return a.key || a.name || a; }); } catch (e) {}
    return core.concat(attrs).filter(function (x, i, a) { return x && a.indexOf(x) === i; });
  }
  // Resolve the per-module Map-to-field list passed by the caller (opts.fields).
  // Accepts an array OR a function returning an array (function = stays live,
  // re-read each time the picker opens). Falls back to the generic fieldOptions().
  function resolveFieldOptions(f) {
    try { if (typeof f === "function") f = f(); } catch (e) { f = null; }
    if (Array.isArray(f)) {
      var clean = f.map(function (x) { return (x && (x.name || x.n)) || x; })
                   .filter(function (x) { return x != null && String(x).trim() !== ""; })
                   .map(function (x) { return String(x).trim(); })
                   .filter(function (x, i, a) { return a.indexOf(x) === i; });
      if (clean.length) return clean;
    }
    return fieldOptions();
  }
  // Replace every {{token}} occurrence in raw with whatever repFn(token) returns.
  function fillVarsRaw(raw, valueFor) {
    var out = String(raw || "");
    extractVars(raw).forEach(function (tok) {
      out = out.replace(new RegExp("\\{\\{\\s*" + reEsc(tok) + "\\s*\\}\\}", "gi"), function () { return valueFor(tok); });
    });
    return out;
  }

  var tScrim, tSheet;
  function ensureOverlay() {
    if (tSheet && tSheet.parentNode) { ensureVarStyle(); return; }
    tScrim = document.createElement("div"); tScrim.className = "lx-scrim";
    tSheet = document.createElement("div"); tSheet.className = "lx-sheetpop";
    host().appendChild(tScrim); host().appendChild(tSheet);
    tScrim.addEventListener("click", closeTpl);
    ensureVarStyle();
  }
  function ensureVarStyle() {
    if (document.getElementById("askeva-varfill-style")) return;
    var s = document.createElement("style"); s.id = "askeva-varfill-style";
    s.textContent =
      ".vf-back{border:none;background:transparent;cursor:pointer;color:var(--ink-2,#4d5d52);width:34px;height:34px;border-radius:10px;display:grid;place-items:center;margin-right:4px;flex:0 0 34px;}" +
      ".vf-back svg{width:20px;height:20px;}.vf-back:active{background:var(--surface-2,#f4f6f3);}" +
      ".vf-tplname{display:flex;align-items:center;gap:11px;background:var(--tint-50,#eaf9e6);border:1px solid var(--tint-border,#cdeac4);border-radius:14px;padding:11px 13px;margin-bottom:16px;}" +
      ".vf-ic{width:34px;height:34px;border-radius:10px;background:#fff;display:grid;place-items:center;color:var(--eva-green-deep,#177a36);flex:0 0 34px;}.vf-ic svg{width:18px;height:18px;}" +
      ".vf-n{font-size:14px;font-weight:600;color:var(--ink,#15231a);}.vf-c{font-size:11.5px;font-weight:500;color:var(--ink-3,#8a978d);margin-top:1px;}" +
      ".vf-rows{display:flex;flex-direction:column;gap:13px;}" +
      ".vf-tok{display:inline-block;font-family:var(--font-mono,monospace);font-size:12px;font-weight:600;color:var(--eva-green-deep,#177a36);background:var(--tint-50,#eaf9e6);border:1px solid var(--tint-border,#cdeac4);border-radius:7px;padding:2px 8px;margin-bottom:7px;}" +
      ".vf-controls{display:flex;gap:8px;}" +
      ".vf-mapwrap{position:relative;flex:0 0 43%;}" +
      ".vf-map{width:100%;-webkit-appearance:none;appearance:none;border:1.5px solid var(--line,#eef1ec);background:#fff;border-radius:11px;padding:11px 30px 11px 12px;font-family:inherit;font-size:13px;font-weight:600;color:var(--ink,#15231a);cursor:pointer;}" +
      ".vf-mapwrap svg{position:absolute;right:9px;top:50%;transform:translateY(-50%);width:16px;height:16px;color:var(--ink-3,#8a978d);pointer-events:none;}" +
      ".vf-val{flex:1;min-width:0;border:1.5px solid var(--line,#eef1ec);background:#fbfdfa;border-radius:11px;padding:11px 12px;font-family:inherit;font-size:13.5px;color:var(--ink,#15231a);outline:none;}" +
      ".vf-val:focus{border-color:var(--eva-green,#3cc23f);background:#fff;}.vf-val:disabled{display:none;}" +
      ".vf-prevlbl{font-size:11px;font-weight:600;letter-spacing:.04em;text-transform:uppercase;color:var(--ink-3,#8a978d);margin:18px 0 8px;}" +
      ".vf-preview{background:var(--wa-bubble-out,#d9fdd3);border:1px solid #cdeac4;border-radius:14px;padding:12px 13px;font-size:13.5px;line-height:1.5;color:var(--ink,#15231a);white-space:pre-wrap;word-break:break-word;}" +
      ".vf-tag{background:#fff;border:1px solid var(--tint-border,#cdeac4);color:var(--eva-green-deep,#177a36);border-radius:6px;padding:0 5px;font-weight:600;font-size:12.5px;}" +
      ".vf-fill{font-weight:700;}.vf-ph{color:var(--ink-4,#9aa39c);}" +
      ".vf-use{width:100%;margin-top:18px;border:none;cursor:pointer;border-radius:13px;padding:14px;font-family:inherit;font-size:14.5px;font-weight:600;color:#fff;background:linear-gradient(135deg,var(--eva-green,#3cc23f),var(--eva-green-deep,#2ba84a));box-shadow:0 8px 20px -8px rgba(43,168,74,.7);}" +
      ".vf-use:active{transform:translateY(1px);}";
    document.head.appendChild(s);
  }
  function closeTpl() { if (tScrim) tScrim.classList.remove("show"); if (tSheet) tSheet.classList.remove("show"); }

  function openTemplates(opts) {
    opts = opts || {};
    ensureOverlay();
    var cat = "Marketing", q = "";
    requestAnimationFrame(function () { tScrim.classList.add("show"); tSheet.classList.add("show"); });

    function renderPicker() {
      tSheet.innerHTML = '<div class="lx-grip"></div>' +
        '<div class="lx-shead"><span class="tt">' + esc(opts.title || "Send a template") + '</span><button class="x" data-x>' + ICX + '</button></div>' +
        '<div class="lx-sbody">' +
          '<div class="lt-tabs">' + CATS.map(function (c) { return '<button class="lt-tab' + (c === cat ? " on" : "") + '" data-cat="' + c + '">' + c + '</button>'; }).join("") + '</div>' +
          '<div class="lx-search lt-search">' + ICSEARCH + '<input id="tplSearch" placeholder="Search templates…"></div>' +
          '<div id="tplList" class="lt-list"></div>' +
        '</div>';
      function renderList() {
        var ql = q.trim().toLowerCase();
        var rows = TPL.filter(function (t) { return t.cat === cat && (!ql || (t.n + " " + t.p).toLowerCase().indexOf(ql) >= 0); });
        $("#tplList", tSheet).innerHTML = rows.length ? rows.map(function (t) {
          var vc = extractVars(t.p).length;
          return '<button class="lt-card" data-send="' + esc(t.n) + '">' +
            '<span class="lt-ic">' + (TI[t.type] || TI.Text) + '</span>' +
            '<span class="lt-body"><span class="lt-name">' + esc(t.n) + '</span><span class="lt-prev">' + esc(t.p) + '</span>' +
              '<span class="lt-cat">' + t.type + (vc ? ' · ' + vc + ' variable' + (vc > 1 ? 's' : '') : '') + '</span></span>' +
            '<span class="lt-send">' + ICSEND + '</span></button>';
        }).join("") : '<div class="lt-empty">No templates in ' + cat + (ql ? ' match "' + esc(q) + '"' : '') + '</div>';
        $$("[data-send]", tSheet).forEach(function (b) {
          b.addEventListener("click", function () {
            var nm = b.getAttribute("data-send");
            var t = TPL.filter(function (x) { return x.n === nm; })[0] || { n: nm };
            var vars = (opts.fillVars === false) ? [] : extractVars(t.p);
            if (vars.length) { renderVarFill(t, vars); return; }
            closeTpl();
            if (typeof opts.onSend === "function") opts.onSend(t);
            else toast('"' + nm + '" sent');
          });
        });
      }
      $$(".lt-tab", tSheet).forEach(function (b) {
        b.addEventListener("click", function () { cat = b.getAttribute("data-cat"); $$(".lt-tab", tSheet).forEach(function (x) { x.classList.toggle("on", x === b); }); renderList(); });
      });
      $("#tplSearch", tSheet).addEventListener("input", function () { q = this.value; renderList(); });
      $("[data-x]", tSheet).addEventListener("click", closeTpl);
      renderList();
    }

    function renderVarFill(t, vars) {
      var valueOnly = !!opts.valueOnly;
      var state = vars.map(function (tok) { return { token: tok, map: "", value: "" }; });
      var fopts = resolveFieldOptions(opts.fields);
      tSheet.innerHTML = '<div class="lx-grip"></div>' +
        '<div class="lx-shead" style="display:flex;align-items:center;gap:2px"><button class="vf-back" data-back aria-label="Back">' + BACKI + '</button>' +
          '<span class="tt" style="flex:1">Fill variables</span><button class="x" data-x>' + ICX + '</button></div>' +
        '<div class="lx-sbody">' +
          '<div class="vf-tplname"><span class="vf-ic">' + (TI[t.type] || TI.Text) + '</span><div><div class="vf-n">' + esc(t.n) + '</div>' +
            '<div class="vf-c">' + esc(t.cat || "") + ' · ' + vars.length + ' variable' + (vars.length > 1 ? 's' : '') + '</div></div></div>' +
          '<div class="vf-rows">' + state.map(function (v, i) {
            return '<div class="vf-row">' +
              '<div class="vf-tok">{{' + esc(v.token) + '}}</div>' +
              '<div class="vf-controls">' +
                (valueOnly ? '' : '<div class="vf-mapwrap"><select class="vf-map" data-i="' + i + '">' +
                  '<option value="">✏️ Enter value</option>' +
                  '<optgroup label="Map to field">' + fopts.map(function (f) { return '<option value="field:' + esc(f) + '">' + esc(f) + '</option>'; }).join("") + '</optgroup>' +
                '</select>' + CHEVD + '</div>') +
                '<input class="vf-val" data-i="' + i + '" placeholder="Value for {{' + esc(v.token) + '}}">' +
              '</div>' +
            '</div>';
          }).join("") + '</div>' +
          '<div class="vf-prevlbl">Preview</div>' +
          '<div class="vf-preview" id="vfPreview"></div>' +
          '<button class="vf-use" data-use>Use template</button>' +
        '</div>';

      function refreshPreview() {
        var html = fillVarsRaw(t.p, function (tok) {
          var v = state.filter(function (x) { return x.token.toLowerCase() === tok.toLowerCase(); })[0];
          if (!v) return "{{" + tok + "}}";
          if (v.map) return '\u0002TAG:' + v.map + '\u0002';
          if (v.value !== "") return '\u0002FILL:' + v.value + '\u0002';
          return '\u0002PH:' + tok + '\u0002';
        });
        // escape, then swap sentinels for styled spans
        html = esc(html)
          .replace(/\u0002TAG:([^\u0002]*)\u0002/g, function (_, f) { return '<span class="vf-tag">[' + esc(f) + ']</span>'; })
          .replace(/\u0002FILL:([^\u0002]*)\u0002/g, function (_, val) { return '<b class="vf-fill">' + esc(val) + '</b>'; })
          .replace(/\u0002PH:([^\u0002]*)\u0002/g, function (_, tok) { return '<span class="vf-ph">{{' + esc(tok) + '}}</span>'; });
        $("#vfPreview", tSheet).innerHTML = html;
      }
      $$(".vf-map", tSheet).forEach(function (sel) {
        sel.addEventListener("change", function () {
          var i = +sel.getAttribute("data-i"), inp = $$('.vf-val[data-i="' + i + '"]', tSheet)[0];
          if (sel.value.indexOf("field:") === 0) { state[i].map = sel.value.slice(6); state[i].value = ""; if (inp) { inp.disabled = true; inp.value = ""; } }
          else { state[i].map = ""; if (inp) { inp.disabled = false; } }
          refreshPreview();
        });
      });
      $$(".vf-val", tSheet).forEach(function (inp) {
        inp.addEventListener("input", function () { var i = +inp.getAttribute("data-i"); state[i].value = inp.value; refreshPreview(); });
      });
      $("[data-back]", tSheet).addEventListener("click", renderPicker);
      $("[data-x]", tSheet).addEventListener("click", closeTpl);
      $("[data-use]", tSheet).addEventListener("click", function () {
        var resolved = fillVarsRaw(t.p, function (tok) {
          var v = state.filter(function (x) { return x.token.toLowerCase() === tok.toLowerCase(); })[0];
          if (!v) return "{{" + tok + "}}";
          if (v.map) return "[" + v.map + "]";
          return v.value !== "" ? v.value : "{{" + tok + "}}";
        });
        var out = {}; for (var k in t) if (Object.prototype.hasOwnProperty.call(t, k)) out[k] = t[k];
        out.p = resolved; out._resolved = resolved;
        out._vars = state.map(function (v) { return { token: v.token, field: v.map || null, value: v.map ? null : v.value }; });
        closeTpl();
        if (typeof opts.onSend === "function") opts.onSend(out);
        else toast('"' + (t.n || "Template") + '" ready');
      });
      refreshPreview();
    }

    renderPicker();
  }
  window.AskEvaTemplates = { list: function () { return TPL; }, icons: TI, open: openTemplates, close: closeTpl, extractVars: extractVars };

  /* ============================================================
     LEAD CONFIG — alerts (Reminders tab) + field display/required.
     Persisted so Settings choices reflect everywhere they're assigned.
     ============================================================ */
  function persisted(key, def) {
    var v; try { var r = localStorage.getItem(key); v = r ? JSON.parse(r) : null; } catch (e) { v = null; }
    return v == null ? def : v;
  }
  // -- alerts (Business Alert + New Lead Creation Alert) --
  var ALERT_KEY = "askeva.leadcfg.alerts.v1";
  var alerts = persisted(ALERT_KEY, {
    business: { on: true, recipient: "Agent Contact Number", template: "lead_remainder_copy" },
    newlead: { on: true, recipient: "Primary Contact", template: "test_variables" }
  });
  var alertSubs = [];
  function alertsSave() { try { localStorage.setItem(ALERT_KEY, JSON.stringify(alerts)); } catch (e) {} alertSubs.forEach(function (f) { try { f(alerts); } catch (_) {} }); }

  // -- lead fields (display / required) --
  var FIELDS_KEY = "askeva.leadcfg.fields.v1";
  var FIELDS_DEFAULT = [
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
  var fields = persisted(FIELDS_KEY, FIELDS_DEFAULT);
  var fieldSubs = [];
  function fieldsSave() { try { localStorage.setItem(FIELDS_KEY, JSON.stringify(fields)); } catch (e) {} fieldSubs.forEach(function (f) { try { f(fields); } catch (_) {} }); }

  window.AskEvaLeadConfig = {
    alerts: function () { return alerts; },
    saveAlerts: alertsSave,
    onAlerts: function (f) { if (typeof f === "function") alertSubs.push(f); }
  };
  window.AskEvaLeadFields = {
    list: function () { return fields; },
    get: function (name) { for (var i = 0; i < fields.length; i++) if (fields[i].n === name) return fields[i]; return null; },
    shown: function (name) { var f = this.get(name); return !f || f.disp !== false; },
    required: function (name) { var f = this.get(name); return !!(f && f.mand); },
    // Live Map-to-field list for Leads templates: the configured fields (incl.
    // custom) + the system columns the Leads table carries. Locked/core identity
    // fields (Name, Mobile, Email, Status, Source, Assigned, …) are always
    // included; the display toggle only governs the optional fields. If no field
    // is display-on, fall back to the full field list so the list is never empty.
    mapFields: function () {
      var anyShown = fields.some(function (f) { return f && f.n && f.disp !== false; });
      var out = ["S.No"];
      fields.forEach(function (f) {
        if (!f || !f.n) return;
        if (f.lock || f.disp !== false || !anyShown) out.push(f.n);
      });
      out.push("Created At", "Updated At");
      return out.filter(function (x, i, a) { return x && a.indexOf(x) === i; });
    },
    save: fieldsSave,
    reset: function () { fields.length = 0; Array.prototype.push.apply(fields, JSON.parse(JSON.stringify(FIELDS_DEFAULT))); fieldsSave(); },
    onChange: function (f) { if (typeof f === "function") fieldSubs.push(f); }
  };

  // -- lead dropdown options (Status / Source / Assigned) — shared so Settings
  //    edits flow straight into the Leads list, filters, forms and board --
  var DD_KEY = "askeva.leadcfg.dropdowns.v1";
  var DD_DEFAULT = {
    Status: ["New", "Hot", "Warm", "Cold", "Customer"],
    Source: ["Import", "Chat-Sync", "User Initiated - Whatsapp", "Website", "Referral", "Manual"],
    Assigned: ["testerr@gmail.com", "eshan@tunepath.com"]
  };
  var dropdowns = persisted(DD_KEY, DD_DEFAULT);
  ["Status", "Source", "Assigned"].forEach(function (k) { if (!Array.isArray(dropdowns[k])) dropdowns[k] = DD_DEFAULT[k].slice(); });
  var ddSubs = [];
  function ddSave() { try { localStorage.setItem(DD_KEY, JSON.stringify(dropdowns)); } catch (e) {} ddSubs.forEach(function (f) { try { f(dropdowns); } catch (_) {} }); }
  window.AskEvaLeadDropdowns = {
    all: function () { return dropdowns; },
    options: function (name) { return (dropdowns[name] || []).slice(); },
    add: function (name, val) { val = String(val || "").trim(); if (!val) return false; dropdowns[name] = dropdowns[name] || []; if (dropdowns[name].some(function (o) { return o.toLowerCase() === val.toLowerCase(); })) return false; dropdowns[name].push(val); ddSave(); return true; },
    remove: function (name, idx) { if (dropdowns[name] && idx >= 0 && idx < dropdowns[name].length) { dropdowns[name].splice(idx, 1); ddSave(); } },
    ensure: function (name) { if (!Array.isArray(dropdowns[name])) { dropdowns[name] = []; ddSave(); } },
    drop: function (name) { if (dropdowns[name] != null) { delete dropdowns[name]; ddSave(); } },
    save: ddSave,
    onChange: function (f) { if (typeof f === "function") ddSubs.push(f); }
  };
})();
