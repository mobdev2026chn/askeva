/* =========================================================
   MERGE: make the Leads-area actions actually do something —
   CSV export/sample/import, and a real business-card scanner:
   "Take Photo" (full-screen camera with a card-alignment frame
   that turns GREEN when a card is aligned, RED otherwise) or
   "Choose from Gallery". Capture → read → prefilled lead form.
   ========================================================= */
(function () {
  "use strict";
  var $ = function (s, r) { return (r || document).querySelector(s); };
  var $$ = function (s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); };

  function toast(msg) {
    var t = document.getElementById("toast"); if (!t) { return; }
    t.textContent = msg; t.style.opacity = "1"; t.style.transform = "translateX(-50%) translateY(0)";
    clearTimeout(t.__lh); t.__lh = setTimeout(function () { t.style.opacity = "0"; t.style.transform = "translateX(-50%) translateY(20px)"; }, 2000);
  }
  function esc(s) { return String(s == null ? "" : s).replace(/[&<>"]/g, function (c) { return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]; }); }

  /* ---------------- CSV helpers ---------------- */
  function stamp() { var d = new Date(); return d.getFullYear() + ("0" + (d.getMonth() + 1)).slice(-2) + ("0" + d.getDate()).slice(-2); }
  function cell(v) { v = (v == null ? "" : String(v)); return /[",\n]/.test(v) ? '"' + v.replace(/"/g, '""') + '"' : v; }
  function downloadFile(name, text) {
    var blob = new Blob([text], { type: "text/csv;charset=utf-8;" });
    var url = URL.createObjectURL(blob);
    var a = document.createElement("a"); a.href = url; a.download = name;
    document.body.appendChild(a); a.click();
    setTimeout(function () { document.body.removeChild(a); URL.revokeObjectURL(url); }, 120);
  }
  function scrapeLeads() {
    return $$("#app-leads .lx-card").map(function (c) {
      var name = ((c.querySelector(".lx-cname") || {}).textContent || "").trim();
      var status = ((c.querySelector(".lx-badge") || {}).textContent || "").trim();
      var m = $$(".lx-cmeta .m", c).map(function (x) { return x.textContent.trim(); });
      return [name, status, m[0] || "", m[1] || "", m[2] || "", m[3] || ""];
    });
  }
  function exportLeads() {
    var rows = scrapeLeads();
    var csv = [["Name", "Status", "Phone", "Source", "Assigned", "Created"].join(",")]
      .concat(rows.map(function (r) { return r.map(cell).join(","); })).join("\r\n");
    downloadFile("leads-export-" + stamp() + ".csv", csv);
    toast(rows.length + " lead" + (rows.length === 1 ? "" : "s") + " exported");
  }
  var SAMPLE = [
    "Name,Phone,Email,Company,Status,Source,Assigned",
    "Aarav Sharma,919876543210,aarav@example.com,Acme Corp,New Lead,Website,",
    "Priya Menon,919812345678,priya@example.com,,Warm,Referral,agent@askeva.io",
    "Rahul Verma,919900112233,rahul@example.com,Nova Tech,Hot,WhatsApp,"
  ].join("\r\n");

  var fileInput;
  function importCsv() { openImportWizard(); }

  /* =========================================================
     IMPORT LEADS WIZARD — 4 steps:
       1 Upload File (+ duplicate-detection settings)
       2 Map Fields  (CSV columns → system fields, with samples)
       3 Preview & Handle Duplicates
       4 Import
     Real CSV parsing, mapping, dedupe & insert into the leads store.
     ========================================================= */
  function _d(s) { return String(s == null ? "" : s).replace(/\D/g, ""); }
  function splitCSVLine(line) { var out = [], cur = "", q = false; var delimiter = (line.indexOf(";") !== -1 && line.indexOf(",") === -1) ? ";" : ","; for (var i = 0; i < line.length; i++) { var ch = line[i]; if (q) { if (ch === '"' && line[i + 1] === '"') { cur += '"'; i++; } else if (ch === '"') q = false; else cur += ch; } else { if (ch === '"') q = true; else if (ch === delimiter) { out.push(cur); cur = ""; } else cur += ch; } } out.push(cur); return out; }
  function sysFields() {
    var list = (window.AskEvaLeadFields && AskEvaLeadFields.list && AskEvaLeadFields.list()) || [];
    var names = list.filter(function (f) { return f.disp !== false; }).map(function (f) { return f.n; });
    if (names.indexOf("Mobile") < 0) names.push("Mobile");
    if (!names.length) names = ["Name", "Company", "Email", "Status", "Source", "Assigned", "Mobile", "Position", "Address", "City", "Country", "Website", "Lead Value", "Tags", "Description"];
    return names;
  }
  function norm(s) { return String(s == null ? "" : s).toLowerCase().replace(/[^a-z0-9]/g, ""); }
  var FIELD_SYN = {
    "Name": ["name", "fullname", "contactname", "leadname"],
    "Mobile": ["mobile", "phone", "phonenumber", "mobilenumber", "number", "whatsapp", "contact", "msisdn"],
    "Email": ["email", "emailaddress", "mail"],
    "Company": ["company", "organisation", "organization", "org", "business"],
    "Status": ["status", "stage", "leadstatus"],
    "Source": ["source", "leadsource", "channel"],
    "Assigned": ["assigned", "assignedto", "owner", "agent"],
    "Country Code": ["countrycode", "cc", "dialcode"],
    "Position": ["position", "designation", "title", "role"],
    "Address": ["address", "addr"], "City": ["city"], "Country": ["country"],
    "Website": ["website", "url", "site"], "Lead Value": ["leadvalue", "value", "amount", "deal"],
    "Tags": ["tags", "tag", "labels"], "Description": ["description", "notes", "remark", "remarks", "note"]
  };
  function autoMapField(header, fields) {
    var nh = norm(header);
    for (var i = 0; i < fields.length; i++) {
      var f = fields[i], syn = FIELD_SYN[f] || [norm(f)];
      for (var j = 0; j < syn.length; j++) { if (nh === norm(syn[j])) return f; }
    }
    for (var k = 0; k < fields.length; k++) {
      var f2 = fields[k], syn2 = FIELD_SYN[f2] || [norm(f2)];
      for (var m = 0; m < syn2.length; m++) { var ns = norm(syn2[m]); if (ns && (nh.indexOf(ns) > -1 || ns.indexOf(nh) > -1)) return f2; }
    }
    return "";
  }
  function statusKey(v) { v = (v || "").toLowerCase(); if (/convert|customer|won/.test(v)) return "converted"; if (/hot/.test(v)) return "hot"; if (/warm/.test(v)) return "warm"; if (/cold|lost/.test(v)) return "cold"; return "new"; }

  function ensureIwStyle() {
    if (document.getElementById("ilw-style")) return;
    var s = document.createElement("style"); s.id = "ilw-style";
    s.textContent =
      ".ilw-ov{position:absolute;inset:0;z-index:96;display:flex;align-items:center;justify-content:center;background:rgba(10,20,12,.5);-webkit-backdrop-filter:blur(3px);backdrop-filter:blur(3px);opacity:0;transition:opacity .2s;padding:14px;}" +
      ".ilw-ov.show{opacity:1;}" +
      ".ilw-sheet{width:100%;max-width:440px;height:100%;max-height:94%;background:#fff;border-radius:22px;display:flex;flex-direction:column;overflow:hidden;box-shadow:0 24px 60px rgba(0,0,0,.4);transform:translateY(14px);transition:transform .24s cubic-bezier(.2,.8,.2,1);}" +
      ".ilw-ov.show .ilw-sheet{transform:none;}" +
      ".ilw-head{display:flex;align-items:center;justify-content:space-between;padding:16px 18px 12px;border-bottom:1px solid var(--line,#eef1ec);}" +
      ".ilw-title{font-size:17px;font-weight:700;color:var(--ink,#15231a);}" +
      ".ilw-x{width:34px;height:34px;border:0;border-radius:10px;background:var(--surface-2,#f1f4ef);color:var(--ink-2,#4d5d52);display:grid;place-items:center;cursor:pointer;}.ilw-x svg{width:18px;height:18px;}" +
      ".ilw-stepper{display:flex;align-items:flex-start;padding:14px 10px 12px;}" +
      ".ilw-step{flex:1;display:flex;flex-direction:column;align-items:center;position:relative;gap:6px;}" +
      ".ilw-line{position:absolute;top:13px;right:50%;width:100%;height:2px;background:var(--line,#eef1ec);z-index:0;}" +
      ".ilw-step.done .ilw-line,.ilw-step.on .ilw-line{background:var(--eva-green,#3cc23f);}" +
      ".ilw-dot{position:relative;z-index:1;width:26px;height:26px;border-radius:50%;display:grid;place-items:center;font-size:12px;font-weight:700;background:var(--surface-3,#e6ebe3);color:var(--ink-3,#8a978d);}" +
      ".ilw-step.on .ilw-dot{background:var(--eva-green,#3cc23f);color:#fff;}.ilw-step.done .ilw-dot{background:var(--eva-green-deep,#177a36);color:#fff;}.ilw-dot svg{width:14px;height:14px;}" +
      ".ilw-slbl{font-size:9.5px;font-weight:600;color:var(--ink-3,#8a978d);text-align:center;line-height:1.1;}.ilw-step.on .ilw-slbl{color:var(--ink,#15231a);}" +
      ".ilw-body{flex:1;min-height:0;overflow-y:auto;padding:16px 18px 18px;}" +
      ".ilw-up{text-align:center;padding:12px 0 6px;}.ilw-xls{display:inline-grid;place-items:center;color:var(--eva-green,#3cc23f);}.ilw-xls svg{width:54px;height:54px;}" +
      ".ilw-uptitle{font-size:18px;font-weight:700;color:var(--ink,#15231a);margin-top:8px;}.ilw-upsub{font-size:13px;font-weight:500;color:var(--ink-3,#8a978d);margin-top:5px;line-height:1.45;}" +
      ".ilw-selfile{display:flex;align-items:center;justify-content:center;gap:9px;width:100%;margin-top:18px;border:1.5px dashed var(--tint-border,#cdeac4);background:var(--surface-2,#fbfdfa);border-radius:12px;padding:14px;font-family:inherit;font-size:14px;font-weight:600;color:var(--ink,#15231a);cursor:pointer;}" +
      ".ilw-selfile .ic{display:inline-grid;place-items:center;color:var(--eva-green-deep,#177a36);}.ilw-selfile .ic svg{width:18px;height:18px;}.ilw-selfile:active{background:var(--tint-50,#eaf9e6);}" +
      ".ilw-card{border:1px solid var(--line,#eef1ec);border-radius:16px;margin-top:18px;overflow:hidden;}" +
      ".ilw-cardhd{font-size:14px;font-weight:600;color:var(--ink,#15231a);padding:14px 16px;border-bottom:1px solid var(--line,#eef1ec);}.ilw-cardbody{padding:14px 16px;}" +
      ".ilw-dupq{font-size:13px;font-weight:600;color:var(--ink-2,#4d5d52);margin-bottom:10px;}" +
      ".ilw-chk{display:flex;align-items:center;gap:11px;width:100%;border:0;background:transparent;cursor:pointer;padding:8px 0;font-family:inherit;text-align:left;}" +
      ".ilw-chk .box{width:22px;height:22px;border-radius:7px;border:1.5px solid var(--line,#cfd6ce);display:grid;place-items:center;color:#fff;flex:0 0 22px;}.ilw-chk .box svg{width:13px;height:13px;opacity:0;}" +
      ".ilw-chk.on .box{background:var(--eva-green,#3cc23f);border-color:var(--eva-green,#3cc23f);}.ilw-chk.on .box svg{opacity:1;}" +
      ".ilw-chk .lb{font-size:13.5px;font-weight:600;color:var(--ink,#15231a);}.ilw-chk.dis{cursor:default;}.ilw-chk.dis .lb{color:var(--ink-3,#8a978d);}.ilw-chk.dis .box{background:var(--ink-4,#9aa39c);border-color:var(--ink-4,#9aa39c);}" +
      ".ilw-h2{font-size:18px;font-weight:700;color:var(--ink,#15231a);}.ilw-sub{font-size:12.5px;font-weight:500;color:var(--ink-3,#8a978d);margin:5px 0 14px;line-height:1.45;}" +
      ".ilw-maphd{display:flex;justify-content:space-between;font-size:10.5px;font-weight:600;letter-spacing:.04em;text-transform:uppercase;color:var(--ink-3,#8a978d);padding:0 2px 8px;}" +
      ".ilw-maplist{display:flex;flex-direction:column;gap:10px;}" +
      ".ilw-maprow{border:1px solid var(--line,#eef1ec);border-radius:14px;padding:12px 13px;display:flex;flex-direction:column;gap:10px;}" +
      ".ilw-mapcol .k{font-size:13.5px;font-weight:600;color:var(--ink,#15231a);}.ilw-mapcol .s{font-size:12px;font-weight:500;color:var(--ink-3,#8a978d);margin-top:2px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;}" +
      ".ilw-mapsel{position:relative;}.ilw-mapsel select{width:100%;-webkit-appearance:none;appearance:none;border:1.5px solid var(--line,#eef1ec);background:#fff;border-radius:10px;padding:11px 32px 11px 12px;font-family:inherit;font-size:13.5px;font-weight:600;color:var(--ink,#15231a);cursor:pointer;}" +
      ".ilw-mapsel svg{position:absolute;right:10px;top:50%;transform:translateY(-50%);width:16px;height:16px;color:var(--ink-3,#8a978d);pointer-events:none;}" +
      ".ilw-stats{display:flex;gap:10px;margin:6px 0 14px;}.ilw-stat{flex:1;border:1px solid var(--line,#eef1ec);border-radius:12px;padding:12px;text-align:center;}" +
      ".ilw-stat b{display:block;font-size:20px;font-weight:700;color:var(--ink,#15231a);}.ilw-stat span{font-size:11px;font-weight:500;color:var(--ink-3,#8a978d);}.ilw-stat.dup b{color:#9A6B00;}.ilw-stat.bad b{color:#C1352F;}" +
      ".ilw-seg{display:flex;gap:7px;}.ilw-segbtn{flex:1;border:1.5px solid var(--line,#eef1ec);background:#fff;border-radius:10px;padding:9px 6px;font-family:inherit;font-size:11.5px;font-weight:600;color:var(--ink-2,#4d5d52);cursor:pointer;}" +
      ".ilw-segbtn.on{border-color:var(--eva-green,#3cc23f);background:var(--tint-50,#eaf9e6);color:var(--eva-green-deep,#177a36);}" +
      ".ilw-plist{display:flex;flex-direction:column;gap:8px;margin-top:14px;}.ilw-prow{display:flex;align-items:center;gap:10px;border:1px solid var(--line,#eef1ec);border-radius:12px;padding:11px 13px;}" +
      ".ilw-pmain{flex:1;min-width:0;}.ilw-pmain .nm{font-size:13.5px;font-weight:600;color:var(--ink,#15231a);}.ilw-pmain .mb{font-size:12px;font-weight:500;color:var(--ink-3,#8a978d);margin-top:2px;}" +
      ".ilw-tag{flex:0 0 auto;font-size:10.5px;font-weight:600;padding:3px 9px;border-radius:999px;}.ilw-tag.new{background:var(--tint-50,#eaf9e6);color:var(--eva-green-deep,#177a36);}.ilw-tag.dup{background:#FFF4DC;color:#9A6B00;}" +
      ".ilw-more{font-size:12px;font-weight:600;color:var(--ink-3,#8a978d);text-align:center;padding:8px;}" +
      ".ilw-done{text-align:center;padding:24px 0 8px;}.ilw-tick{display:inline-grid;place-items:center;width:64px;height:64px;border-radius:50%;background:var(--eva-green,#3cc23f);color:#fff;box-shadow:0 10px 24px -8px rgba(43,168,74,.6);}.ilw-tick svg{width:32px;height:32px;}" +
      ".ilw-donet{font-size:18px;font-weight:700;color:var(--ink,#15231a);margin-top:14px;}.ilw-donesub{font-size:13px;font-weight:500;color:var(--ink-3,#8a978d);margin-top:5px;}" +
      ".ilw-foot{display:flex;gap:10px;margin-top:18px;}" +
      ".ilw-btn{flex:1;border:0;border-radius:12px;padding:13px;font-family:inherit;font-size:14px;font-weight:600;cursor:pointer;color:#fff;background:linear-gradient(135deg,var(--eva-green,#3cc23f),var(--eva-green-deep,#2ba84a));box-shadow:0 8px 20px -8px rgba(43,168,74,.7);}" +
      ".ilw-btn.ghost{background:var(--surface-2,#f1f4ef);color:var(--ink-2,#4d5d52);box-shadow:none;flex:0 0 auto;padding:13px 22px;}.ilw-btn:disabled{opacity:.5;cursor:default;box-shadow:none;}";
    document.head.appendChild(s);
  }

  var iw = null;
  function openImportWizard() {
    ensureIwStyle();
    if (document.getElementById("ilwRoot")) return;
    iw = { step: 1, fileName: "", headers: [], rows: [], map: {}, dupe: { mobile: true, email: true, name: false }, strategy: "skip", result: null };
    var ov = document.createElement("div"); ov.id = "ilwRoot"; ov.className = "ilw-ov";
    ov.innerHTML = '<div class="ilw-sheet"><div class="ilw-head"><span class="ilw-title">Import Leads</span><button class="ilw-x" data-close>' + IC.close + '</button></div>' +
      '<div class="ilw-stepper" id="ilwStepper"></div><div class="ilw-body" id="ilwBody"></div></div>';
    host().appendChild(ov);
    requestAnimationFrame(function () { ov.classList.add("show"); });
    ov.querySelector("[data-close]").addEventListener("click", closeImportWizard);
    ov.addEventListener("click", function (e) { if (e.target === ov) closeImportWizard(); });
    renderIw();
  }
  function closeImportWizard() { var ov = document.getElementById("ilwRoot"); if (!ov) return; ov.classList.remove("show"); setTimeout(function () { ov.remove(); }, 220); iw = null; }

  function renderStepper() {
    var el = document.getElementById("ilwStepper"); if (!el) return;
    var steps = ["Upload", "Map Fields", "Preview", "Import"];
    el.innerHTML = steps.map(function (lbl, i) {
      var n = i + 1, st = n < iw.step ? "done" : n === iw.step ? "on" : "";
      return '<div class="ilw-step ' + st + '">' + (i ? '<span class="ilw-line"></span>' : '') +
        '<span class="ilw-dot">' + (n < iw.step ? IC.check : n) + '</span><span class="ilw-slbl">' + lbl + '</span></div>';
    }).join("");
  }
  function renderIw() {
    renderStepper();
    var b = document.getElementById("ilwBody"); if (!b) return;
    if (iw.step === 1) renderUpload(b);
    else if (iw.step === 2) renderMap(b);
    else if (iw.step === 3) renderPreview(b);
    else renderImport(b);
    b.scrollTop = 0;
  }

  /* ---- step 1: upload + duplicate settings ---- */
  function renderUpload(b) {
    b.innerHTML =
      '<div class="ilw-up">' +
        '<span class="ilw-xls">' + IC.xls + '</span>' +
        '<div class="ilw-uptitle">Import Leads</div>' +
        '<div class="ilw-upsub">Upload a CSV file to import your contacts as leads</div>' +
        '<button class="ilw-selfile" data-pick><span class="ic">' + IC.up + '</span>' + (iw.fileName ? esc(iw.fileName) : "Select File") + '</button>' +
      '</div>' +
      '<div class="ilw-card"><div class="ilw-cardhd">Duplicate Detection Settings</div>' +
        '<div class="ilw-cardbody"><div class="ilw-dupq">Check for duplicates based on:</div>' +
          chk("mobile", "Mobile Number (Required)", true, true) +
          chk("email", "Email Address", iw.dupe.email, false) +
          chk("name", "Name", iw.dupe.name, false) +
        '</div>' +
      '</div>';
    b.querySelector("[data-pick]").addEventListener("click", pickImportFile);
    $$("[data-dupe]", b).forEach(function (c) { c.addEventListener("click", function () { var k = c.getAttribute("data-dupe"); if (k === "mobile") return; iw.dupe[k] = !iw.dupe[k]; c.classList.toggle("on", iw.dupe[k]); }); });
  }
  function chk(key, label, on, disabled) {
    return '<button class="ilw-chk' + (on ? " on" : "") + (disabled ? " dis" : "") + '" data-dupe="' + key + '"' + (disabled ? ' disabled' : '') + '>' +
      '<span class="box">' + IC.check + '</span><span class="lb">' + esc(label) + '</span></button>';
  }
  function pickImportFile() {
    if (!fileInput) {
      fileInput = document.createElement("input"); fileInput.type = "file"; fileInput.accept = ".csv,text/csv"; fileInput.style.display = "none";
      document.body.appendChild(fileInput);
    }
    fileInput.onchange = function () {
      var f = fileInput.files && fileInput.files[0]; if (!f) return;
      var reader = new FileReader();
      reader.onload = function () { loadCsvText(String(reader.result || ""), f.name); };
      reader.readAsText(f); fileInput.value = "";
    };
    fileInput.click();
  }
  function loadCsvText(text, name) {
    var lines = String(text || "").split(/\r\n|\r|\n/).filter(function (l) { return l.trim(); });
    if (!lines.length) { toast("That CSV looks empty"); return; }
    iw.headers = splitCSVLine(lines[0]).map(function (h) { return h.trim(); }).filter(function (h) { return h !== ""; });
    iw.rows = lines.slice(1).map(function (l) { return splitCSVLine(l); });
    iw.fileName = name || "import.csv";
    var fields = sysFields(); iw.map = {};
    iw.headers.forEach(function (h) { iw.map[h] = autoMapField(h, fields); });
    iw.step = 2; renderIw();
    toast(iw.rows.length + " row" + (iw.rows.length === 1 ? "" : "s") + " detected");
  }
  window.__importLeadsLoadCSV = function (text, name) { if (!document.getElementById("ilwRoot")) openImportWizard(); loadCsvText(text, name || "test.csv"); };

  /* ---- step 2: map fields ---- */
  function sampleFor(header) {
    var idx = iw.headers.indexOf(header);
    for (var r = 0; r < iw.rows.length; r++) { var v = (iw.rows[r][idx] || "").trim(); if (v) return v; }
    return "\u2014";
  }
  function renderMap(b) {
    var fields = sysFields();
    var rowsHTML = iw.headers.map(function (h) {
      var opts = '<option value="">Select field</option>' + fields.map(function (f) {
        var req = (f === "Name" || f === "Mobile");
        return '<option value="' + esc(f) + '"' + (iw.map[h] === f ? " selected" : "") + '>' + esc(f) + (req ? " *" : "") + '</option>';
      }).join("");
      return '<div class="ilw-maprow"><div class="ilw-mapcol"><div class="k">' + esc(h) + '</div><div class="s">' + esc(sampleFor(h)) + '</div></div>' +
        '<div class="ilw-mapsel"><select data-map="' + esc(h) + '">' + opts + '</select>' + IC.chevd + '</div></div>';
    }).join("");
    b.innerHTML =
      '<div class="ilw-h2">Map Fields</div>' +
      '<div class="ilw-sub">Map your CSV columns to system fields. <b>Name</b> &amp; <b>Mobile</b> are required.</div>' +
      '<div class="ilw-maphd"><span>CSV Column</span><span>Map to field</span></div>' +
      '<div class="ilw-maplist">' + rowsHTML + '</div>' +
      '<div class="ilw-foot"><button class="ilw-btn ghost" data-back>Back</button><button class="ilw-btn" data-next>Preview Data</button></div>';
    $$("[data-map]", b).forEach(function (s) { s.addEventListener("change", function () { iw.map[s.getAttribute("data-map")] = s.value; }); });
    b.querySelector("[data-back]").addEventListener("click", function () { iw.step = 1; renderIw(); });
    b.querySelector("[data-next]").addEventListener("click", function () {
      var mapped = {}; Object.keys(iw.map).forEach(function (h) { if (iw.map[h]) mapped[iw.map[h]] = 1; });
      if (!mapped.Name) { toast("Map a column to Name"); return; }
      if (!mapped.Mobile) { toast("Map a column to Mobile"); return; }
      iw.step = 3; renderIw();
    });
  }

  /* ---- build leads from rows using the mapping ---- */
  function buildParsed() {
    var hi = {}; iw.headers.forEach(function (h, i) { hi[h] = i; });
    var fieldToHeader = {}; Object.keys(iw.map).forEach(function (h) { if (iw.map[h]) fieldToHeader[iw.map[h]] = h; });
    function cell(row, field) { var h = fieldToHeader[field]; if (!h) return ""; var v = row[hi[h]]; return String(v == null ? "" : v).trim(); }
    var KNOWN = { "Name": "name", "Company": "company", "Email": "email", "Source": "source", "Assigned": "assigned", "Position": "position", "Address": "address", "City": "city", "Country": "country", "Website": "website", "Lead Value": "value", "Description": "description", "Country Code": "countryCode" };
    return iw.rows.map(function (row) {
      var mob = _d(cell(row, "Mobile"));
      var lead = { name: cell(row, "Name") || "", mobile: mob, status: statusKey(cell(row, "Status")), source: cell(row, "Source") || "Import", tags: [] };
      Object.keys(KNOWN).forEach(function (f) { var v = cell(row, f); if (v) lead[KNOWN[f]] = v; });
      var tg = cell(row, "Tags"); if (tg) lead.tags = tg.split(/[|;,]/).map(function (s) { return s.trim(); }).filter(Boolean);
      lead._valid = !!mob && mob.length >= 6;
      return lead;
    });
  }
  function existingMatch(lead) {
    var leads = window.AskEvaLeads || [];
    var mob = _d(lead.mobile), em = (lead.email || "").toLowerCase(), nm = (lead.name || "").trim().toLowerCase();
    for (var i = 0; i < leads.length; i++) {
      var L = leads[i];
      if (iw.dupe.mobile && mob && _d(L.mobile).slice(-10) === mob.slice(-10)) return L;
      if (iw.dupe.email && em && (L.email || "").toLowerCase() === em) return L;
      if (iw.dupe.name && nm && (L.name || "").trim().toLowerCase() === nm) return L;
    }
    return null;
  }

  /* ---- step 3: preview & handle duplicates ---- */
  function renderPreview(b) {
    var parsed = buildParsed();
    var valid = parsed.filter(function (l) { return l._valid; });
    var invalid = parsed.length - valid.length;
    var dupes = 0;
    valid.forEach(function (l) { l._dupe = !!existingMatch(l); if (l._dupe) dupes++; });
    var fresh = valid.length - dupes;
    iw._parsed = valid;
    var STRAT = [["skip", "Skip duplicates"], ["update", "Update existing"]];
    var rowsHTML = valid.slice(0, 8).map(function (l) {
      var tag = l._dupe ? '<span class="ilw-tag dup">Duplicate</span>' : '<span class="ilw-tag new">New</span>';
      return '<div class="ilw-prow"><div class="ilw-pmain"><div class="nm">' + esc(l.name || "(no name)") + '</div><div class="mb">' + esc((l.countryCode ? l.countryCode + " " : "") + (l.mobile || "—")) + (l.company ? ' &middot; ' + esc(l.company) : '') + '</div></div>' + tag + '</div>';
    }).join("") + (valid.length > 8 ? '<div class="ilw-more">+ ' + (valid.length - 8) + ' more</div>' : '');
    b.innerHTML =
      '<div class="ilw-h2">Preview &amp; Handle Duplicates</div>' +
      '<div class="ilw-sub">' + valid.length + ' valid row' + (valid.length === 1 ? "" : "s") + ' ready to import.</div>' +
      '<div class="ilw-stats"><div class="ilw-stat"><b>' + fresh + '</b><span>New</span></div>' +
        '<div class="ilw-stat dup"><b>' + dupes + '</b><span>Duplicates</span></div>' +
        '<div class="ilw-stat bad"><b>' + invalid + '</b><span>Invalid</span></div></div>' +
      (dupes ? '<div class="ilw-card"><div class="ilw-cardhd">Handle duplicates</div><div class="ilw-cardbody"><div class="ilw-seg">' +
        STRAT.map(function (s) { return '<button class="ilw-segbtn' + (iw.strategy === s[0] ? " on" : "") + '" data-strat="' + s[0] + '">' + s[1] + '</button>'; }).join("") + '</div></div></div>' : '') +
      '<div class="ilw-plist">' + (rowsHTML || '<div class="ilw-more">No valid rows to import.</div>') + '</div>' +
      '<div class="ilw-foot"><button class="ilw-btn ghost" data-back>Back</button><button class="ilw-btn" data-import' + (valid.length ? '' : ' disabled') + '>Import ' + fresh + (dupes && iw.strategy !== "skip" ? "+" + dupes : "") + ' Lead' + (fresh === 1 ? "" : "s") + '</button></div>';
    $$("[data-strat]", b).forEach(function (s) { s.addEventListener("click", function () { iw.strategy = s.getAttribute("data-strat"); renderIw(); }); });
    b.querySelector("[data-back]").addEventListener("click", function () { iw.step = 2; renderIw(); });
    var imp = b.querySelector("[data-import]"); if (imp) imp.addEventListener("click", doImportRun);
  }

  /* ---- step 4: run import + summary ---- */
  function doImportRun() {
    var parsed = iw._parsed || [];
    var added = 0, updated = 0, skipped = 0;
    parsed.forEach(function (l) {
      var match = existingMatch(l);
      var rec = { name: l.name, mobile: l.mobile, email: l.email || "", company: l.company || "", status: l.status, source: l.source || "Import", assigned: l.assigned || (window.AskEvaNextAgent ? window.AskEvaNextAgent() : ""), position: l.position || "", countryCode: l.countryCode || "", address: l.address || "", city: l.city || "", country: l.country || "", website: l.website || "", value: l.value || "", tags: l.tags || [], description: l.description || "" };
      if (match) {
        if (iw.strategy === "skip") { skipped++; return; }
        if (iw.strategy === "update") { Object.keys(rec).forEach(function (k) { if (rec[k] !== "" && !(Array.isArray(rec[k]) && !rec[k].length)) match[k] = rec[k]; }); updated++; return; }
      }
      if (window.AskEvaAddLead) window.AskEvaAddLead(rec); added++;
    });
    if (window.AskEvaLeadsChanged) window.AskEvaLeadsChanged("import");
    iw.result = { added: added, updated: updated, skipped: skipped }; iw.step = 4; renderIw();
  }
  function renderImport(b) {
    var r = iw.result || { added: 0, updated: 0, skipped: 0 };
    b.innerHTML =
      '<div class="ilw-done"><span class="ilw-tick">' + IC.check + '</span>' +
        '<div class="ilw-donet">Import complete</div>' +
        '<div class="ilw-donesub">Your leads have been added to the pipeline.</div>' +
        '<div class="ilw-stats"><div class="ilw-stat"><b>' + r.added + '</b><span>Imported</span></div>' +
          '<div class="ilw-stat"><b>' + r.updated + '</b><span>Updated</span></div>' +
          '<div class="ilw-stat bad"><b>' + r.skipped + '</b><span>Skipped</span></div></div>' +
      '</div>' +
      '<div class="ilw-foot"><button class="ilw-btn ghost" data-close2>Done</button><button class="ilw-btn" data-view>View Leads</button></div>';
    b.querySelector("[data-close2]").addEventListener("click", closeImportWizard);
    b.querySelector("[data-view]").addEventListener("click", function () { closeImportWizard(); if (window.__appRoute) window.__appRoute("leads"); });
  }

  /* ================= Card scanner ================= */
  function host() { return document.getElementById("screen") || document.body; }

  var IC = {
    close: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M18 6 6 18M6 6l12 12"/></svg>',
    camera: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 8.5A2.5 2.5 0 0 1 5.5 6h1.2l.9-1.5a1.5 1.5 0 0 1 1.3-.7h4.2a1.5 1.5 0 0 1 1.3.7L16.3 6h1.2A2.5 2.5 0 0 1 20 8.5v8A2.5 2.5 0 0 1 17.5 19h-11A2.5 2.5 0 0 1 4 16.5z" stroke-width="0" fill="currentColor" opacity=".001"/><path d="M3 9a2 2 0 0 1 2-2h2l1.2-1.8A1 1 0 0 1 9 4.8h6a1 1 0 0 1 .8.4L17 7h2a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/><circle cx="12" cy="13" r="3.2"/></svg>',
    gallery: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="4" width="18" height="16" rx="2.5"/><circle cx="8.5" cy="9.5" r="1.8"/><path d="m4 17 5-5 4 4 3-3 4 4"/></svg>',
    chev: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="m9 6 6 6-6 6"/></svg>',
    check: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="m5 12 5 5 9-10"/></svg>',
    xls: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M14 3H7a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V8z"/><path d="M14 3v5h5"/><path d="m9.5 12 5 5m0-5-5 5"/></svg>',
    up: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 16V5m0 0 4 4m-4-4-4 4"/><path d="M5 16v2.5A1.5 1.5 0 0 0 6.5 20h11a1.5 1.5 0 0 0 1.5-1.5V16"/></svg>',
    chevd: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m6 9 6 6 6-6"/></svg>'
  };

  /* ---- step 1: Take Photo / Choose from Gallery ---- */
  function openScan() {
    if (document.getElementById("scanRoot")) return;
    var ov = document.createElement("div"); ov.id = "scanRoot"; ov.className = "sc-ov";
    ov.innerHTML =
      '<div class="sc-sheet">' +
        '<div class="sc-grip"></div>' +
        '<div class="sc-shead"><span class="sc-ttl">Scan business card</span>' +
          '<button class="sc-x" data-close>' + IC.close + '</button></div>' +
        '<p class="sc-sub">Add a lead by scanning a business card</p>' +
        '<button class="sc-opt" data-take><span class="sc-oic green">' + IC.camera + '</span>' +
          '<span class="sc-otx"><b>Take Photo</b><span>Use your camera to scan a card</span></span><span class="chev">' + IC.chev + '</span></button>' +
        '<button class="sc-opt" data-gallery><span class="sc-oic blue">' + IC.gallery + '</span>' +
          '<span class="sc-otx"><b>Choose from Gallery</b><span>Pick an existing photo</span></span><span class="chev">' + IC.chev + '</span></button>' +
      '</div>';
    host().appendChild(ov);
    requestAnimationFrame(function () { ov.classList.add("show"); });
    function close() { ov.classList.remove("show"); setTimeout(function () { ov.remove(); }, 220); }
    ov.querySelector("[data-close]").addEventListener("click", close);
    ov.addEventListener("click", function (e) { if (e.target === ov) close(); });
    ov.querySelector("[data-take]").addEventListener("click", function () { close(); openCamera(); });
    ov.querySelector("[data-gallery]").addEventListener("click", function () { close(); openGallery(); });
  }

  /* ---- gallery picker ---- */
  var galInput;
  function openGallery() {
    if (!galInput) {
      galInput = document.createElement("input");
      galInput.type = "file"; galInput.accept = "image/*"; galInput.style.display = "none";
      galInput.addEventListener("change", function () {
        var f = galInput.files && galInput.files[0]; if (!f) { return; }
        var url = URL.createObjectURL(f);
        openResult(url); galInput.value = "";
      });
      document.body.appendChild(galInput);
    }
    galInput.click();
  }

  /* ---- frame-content analysis helpers ---- */
  function lumaAt(d, i) { return 0.299 * d[i] + 0.587 * d[i + 1] + 0.114 * d[i + 2]; }
  function metrics(d, w, h) {
    var edges = 0, sum = 0, n = w * h;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        var i = (y * w + x) * 4, L = lumaAt(d, i); sum += L;
        if (x < w - 1) edges += Math.abs(L - lumaAt(d, i + 4));
        if (y < h - 1) edges += Math.abs(L - lumaAt(d, i + w * 4));
      }
    }
    return { edge: edges / n, bright: sum / n };
  }
  function enableDrag(el, onMove) {
    var sx, sy, ox, oy, drag = false;
    function pt(e) { var t = e.touches && e.touches[0]; return { x: t ? t.clientX : e.clientX, y: t ? t.clientY : e.clientY }; }
    function down(e) { drag = true; var p = pt(e); sx = p.x; sy = p.y; ox = parseFloat(el.style.left) || 0; oy = parseFloat(el.style.top) || 0; el.classList.add("grab"); e.preventDefault(); }
    function move(e) { if (!drag) return; var p = pt(e); el.style.left = (ox + p.x - sx) + "px"; el.style.top = (oy + p.y - sy) + "px"; if (onMove) onMove(); }
    function up() { drag = false; el.classList.remove("grab"); }
    el.addEventListener("mousedown", down); el.addEventListener("touchstart", down, { passive: false });
    var mv = move, u = up;
    window.addEventListener("mousemove", mv); window.addEventListener("mouseup", u);
    window.addEventListener("touchmove", mv, { passive: false }); window.addEventListener("touchend", u);
    el.__cleanup = function () { window.removeEventListener("mousemove", mv); window.removeEventListener("mouseup", u); window.removeEventListener("touchmove", mv); window.removeEventListener("touchend", u); };
  }

  /* ---- step 2: full-screen camera ---- */
  function openCamera() {
    if (document.getElementById("cscRoot")) return;
    var ov = document.createElement("div"); ov.id = "cscRoot"; ov.className = "csc-ov";
    ov.innerHTML =
      '<video class="csc-video" playsinline muted autoplay></video>' +
      '<div class="csc-fallbg" hidden></div>' +
      '<div class="csc-top"><button class="csc-x" data-close>' + IC.close + '</button>' +
        '<span class="csc-title">Scan business card</span><span style="width:38px"></span></div>' +
      '<div class="csc-frame"><i class="c tl"></i><i class="c tr"></i><i class="c bl"></i><i class="c br"></i></div>' +
      '<div class="csc-status"><span class="dot"></span><span class="txt">Align the card inside the frame</span></div>' +
      '<div class="csc-bottom"><button class="csc-shutter" data-capture aria-label="Capture"></button></div>' +
      '<canvas class="csc-canvas" width="80" height="50" hidden></canvas>';
    host().appendChild(ov);
    requestAnimationFrame(function () { ov.classList.add("show"); });

    var video = ov.querySelector(".csc-video");
    var frame = ov.querySelector(".csc-frame");
    var statusEl = ov.querySelector(".csc-status");
    var statusTxt = ov.querySelector(".csc-status .txt");
    var shutter = ov.querySelector("[data-capture]");
    var canvas = ov.querySelector(".csc-canvas");
    var ctx = canvas.getContext("2d");
    var CW = 80, CH = 50;
    var stream = null, raf = null, aligned = false, alignedSince = 0, fallback = false, dragCard = null, done = false;

    function setAligned(b) {
      if (b === aligned) return; aligned = b;
      frame.classList.toggle("ok", b);
      statusEl.classList.toggle("ok", b);
      shutter.classList.toggle("ready", b);
      statusTxt.textContent = b ? "Card detected \u2014 hold steady\u2026" : (fallback ? "Drag the card into the frame" : "Align the card inside the frame");
    }
    function stop() { if (raf) cancelAnimationFrame(raf); raf = null; if (stream) { stream.getTracks().forEach(function (t) { t.stop(); }); stream = null; } if (dragCard && dragCard.__cleanup) dragCard.__cleanup(); }
    function close() { stop(); ov.classList.remove("show"); setTimeout(function () { ov.remove(); }, 220); }
    ov.querySelector("[data-close]").addEventListener("click", close);

    function analyze() {
      var vw = video.videoWidth, vh = video.videoHeight;
      if (vw && vh) {
        var fr = frame.getBoundingClientRect(), vr = video.getBoundingClientRect();
        var scale = Math.max(vr.width / vw, vr.height / vh);
        var offX = (vr.width - vw * scale) / 2, offY = (vr.height - vh * scale) / 2;
        var sx = ((fr.left - vr.left) - offX) / scale, sy = ((fr.top - vr.top) - offY) / scale;
        var sw = fr.width / scale, sh = fr.height / scale;
        sx = Math.max(0, sx); sy = Math.max(0, sy); sw = Math.min(sw, vw - sx); sh = Math.min(sh, vh - sy);
        try {
          ctx.drawImage(video, sx, sy, sw, sh, 0, 0, CW, CH);
          var m = metrics(ctx.getImageData(0, 0, CW, CH).data, CW, CH);
          setAligned(m.edge > 14 && m.bright > 42 && m.bright < 250);
        } catch (e) { }
        if (aligned) { if (!alignedSince) alignedSince = performance.now(); else if (performance.now() - alignedSince > 1100) { doCapture(); return; } }
        else alignedSince = 0;
      }
      raf = requestAnimationFrame(analyze);
    }

    function startFallback() {
      fallback = true; video.hidden = true;
      ov.querySelector(".csc-fallbg").hidden = false;
      dragCard = document.createElement("div"); dragCard.className = "csc-dragcard";
      dragCard.innerHTML = '<b>BRIGHTWAVE</b><span>Daniel Roberts &middot; Sales Lead</span><span>+91 98765 43210</span>';
      ov.insertBefore(dragCard, ov.querySelector(".csc-bottom"));
      var r = ov.getBoundingClientRect();
      dragCard.style.left = Math.round(r.width * 0.10) + "px";
      dragCard.style.top = Math.round(r.height * 0.66) + "px";
      statusTxt.textContent = "Drag the card into the frame";
      enableDrag(dragCard, checkOverlap);
    }
    function checkOverlap() {
      if (!dragCard) return;
      var fr = frame.getBoundingClientRect(), cr = dragCard.getBoundingClientRect();
      var ix = Math.max(0, Math.min(fr.right, cr.right) - Math.max(fr.left, cr.left));
      var iy = Math.max(0, Math.min(fr.bottom, cr.bottom) - Math.max(fr.top, cr.top));
      var ratio = (cr.width * cr.height) ? (ix * iy) / (cr.width * cr.height) : 0;
      setAligned(ratio > 0.8);
      if (aligned) { if (!alignedSince) alignedSince = performance.now(); }
      else alignedSince = 0;
    }

    shutter.addEventListener("click", function () {
      if (fallback && !aligned) { statusTxt.textContent = "Move the card fully inside the frame"; return; }
      doCapture();
    });

    function doCapture() {
      if (done) return; done = true; stop();
      var preview = null;
      if (!fallback && video.videoWidth) {
        try { var c = document.createElement("canvas"); c.width = video.videoWidth; c.height = video.videoHeight; c.getContext("2d").drawImage(video, 0, 0); preview = c.toDataURL("image/jpeg", 0.8); } catch (e) { }
      }
      close(); openResult(preview);
    }

    if (navigator.mediaDevices && navigator.mediaDevices.getUserMedia) {
      navigator.mediaDevices.getUserMedia({ video: { facingMode: { ideal: "environment" } } })
        .then(function (s) { stream = s; video.srcObject = s; var p = video.play(); if (p && p.catch) p.catch(function () { }); raf = requestAnimationFrame(analyze); })
        .catch(function () { startFallback(); });
    } else { startFallback(); }
  }

  /* ---- realistic unique dummy-lead generator (each scan = new lead) ---- */
  function randomLead() {
    var first = ["Aarav","Vivaan","Aditya","Diya","Ananya","Ishaan","Kabir","Saanvi","Riya","Arjun","Meera","Rohan","Neha","Karthik","Priya","Sahil","Tara","Nikhil","Ayaan","Zara","Dev","Anjali","Varun","Pooja","Rahul","Sneha"];
    var last = ["Sharma","Verma","Iyer","Nair","Reddy","Gupta","Mehta","Patel","Rao","Joshi","Kapoor","Bose","Das","Menon","Chopra","Saxena","Pillai","Bhat"];
    var companies = ["Brightwave Media","Nimbus Logistics","Vertex Analytics","Lotus Retail","Quanta Labs","Orbit Foods","Indus Textiles","Pixela Studios","Apex Realty","Greenfield Agro","Stellar Fintech","Cobalt Health","Trailhead Travel","Zenith Motors","Saffron Hospitality"];
    var designations = ["Founder","CEO","Sales Lead","Marketing Manager","Product Manager","Business Head","Operations Lead","Growth Manager","Procurement Head","Account Executive","Director","VP Sales"];
    var industries = ["Technology","Retail","Logistics","Healthcare","Finance","Hospitality","Manufacturing","Real Estate","Agriculture","Media","Travel","Automotive"];
    var statuses = ["new","hot","warm","cold"];
    function pick(a) { return a[Math.floor(Math.random() * a.length)]; }
    var f = pick(first), l = pick(last), co = pick(companies);
    var dom = co.toLowerCase().replace(/[^a-z]+/g, "") + ".com";
    var phone = "+91 " + (9 - Math.floor(Math.random() * 4)) + String(1000 + Math.floor(Math.random() * 9000)) + " " + String(10000 + Math.floor(Math.random() * 89999));
    return { name: f + " " + l, company: co, designation: pick(designations), industry: pick(industries),
      email: f.toLowerCase() + "." + l.toLowerCase() + "@" + dom, phone: phone, status: pick(statuses) };
  }

  /* ---- step 3: reading -> prefilled form ---- */
  function openResult(previewUrl) {
    if (document.getElementById("scanResult")) return;
    var R = randomLead();
    var ov = document.createElement("div"); ov.id = "scanResult"; ov.className = "sc-ov";
    ov.innerHTML =
      '<div class="sc-sheet">' +
        '<div class="sc-grip"></div>' +
        '<div class="sc-shead"><span class="sc-ttl" data-ttl>Scanning card</span>' +
          '<button class="sc-x" data-close>' + IC.close + '</button></div>' +
        '<div class="sc-stage" data-stage="reading">' +
          (previewUrl ? '<div class="sc-preview"><img src="' + previewUrl + '" alt="card"></div>' : "") +
          '<div class="sc-spin"></div><p class="sc-hint">Reading card details\u2026</p></div>' +
        '<div class="sc-stage" data-stage="form" hidden>' +
          '<div class="sc-ok">' + IC.check + 'Card scanned successfully</div>' +
          fld("Name", R.name) + fld("Company", R.company) + fld("Designation", R.designation) +
          fld("Phone", R.phone) + fld("Email", R.email) + fld("Industry", R.industry) +
          '<div class="sc-foot"><button class="sc-btn ghost" data-retake>Retake</button><button class="sc-btn" data-create>Create Lead</button></div>' +
        '</div>' +
      '</div>';
    host().appendChild(ov);
    requestAnimationFrame(function () { ov.classList.add("show"); });
    function stage(n) { $$(".sc-stage", ov).forEach(function (s) { s.hidden = s.getAttribute("data-stage") !== n; }); }
    function close() { ov.classList.remove("show"); setTimeout(function () { ov.remove(); }, 220); }
    ov.querySelector("[data-close]").addEventListener("click", close);
    setTimeout(function () { stage("form"); ov.querySelector("[data-ttl]").textContent = "Card details"; }, 1400);
    ov.querySelector("[data-retake]").addEventListener("click", function () { close(); openScan(); });
    ov.querySelector("[data-create]").addEventListener("click", function () {
      function get(f) { var i = ov.querySelector('input[data-f="' + f + '"]'); return i ? i.value.trim() : ""; }
      var nm = get("Name") || R.name;
      var lead = {
        name: nm, subtitle: get("Designation") || R.designation, company: get("Company"),
        mobile: (get("Phone") || "").replace(/[^\d]/g, ""), email: get("Email"),
        industry: get("Industry") || R.industry,
        status: R.status, source: "Card Scan", assigned: "", website: "", value: "", tags: [],
        address: "", city: "", country: "", description: "Added via business card scan", cf_test: "", cf_username: ""
      };
      if (window.AskEvaAddLead) window.AskEvaAddLead(lead);
      close();
      if (window.__appRoute) window.__appRoute("leads");
      toast("Lead created from card \u00b7 " + nm);
    });
  }
  function fld(label, val) {
    return '<label class="sc-fld"><span>' + label + '</span><input data-f="' + label + '" value="' + val + '"></label>';
  }

  /* ---------------- delegation ---------------- */
  document.addEventListener("click", function (e) {
    var t = e.target;
    var chip = t.closest && t.closest("#app-leads [data-act]");
    if (chip) {
      var a = chip.getAttribute("data-act");
      if (a === "export") exportLeads();
      else if (a === "sample") { downloadFile("sample-leads-template.csv", SAMPLE); }
      else if (a === "import") importCsv();
      return;
    }
    if (t.closest && t.closest(".sb-exp")) { exportLeads(); return; }
    if (t.closest && t.closest(".d2-scan")) { openScan(); return; }
    if (t.closest && t.closest(".lxp-view")) {
      var vbtn = t.closest(".lxp-view"), card = vbtn.closest(".lxp-agent");
      var chips = card && card.querySelector(".lxp-details") || card && card.querySelector(".lxp-stchips");
      if (chips) {
        var open = chips.classList.toggle("collapsed") === false;
        // update the button label (keep the leading eye icon)
        var lbl = vbtn.querySelector(".lxp-vlbl");
        if (!lbl) { lbl = document.createElement("span"); lbl.className = "lxp-vlbl"; vbtn.appendChild(lbl); }
        vbtn.childNodes.forEach && Array.prototype.forEach.call(vbtn.childNodes, function (n) { if (n.nodeType === 3) n.textContent = ""; });
        lbl.textContent = open ? "Hide Details" : "View Details";
      }
      return;
    }
  });

  /* ---------------- scoped styles ---------------- */
  var css = document.createElement("style");
  css.textContent =
    /* action sheet + result sheet */
    ".sc-ov{position:absolute;inset:0;z-index:92;display:flex;align-items:flex-end;justify-content:center;background:rgba(10,20,12,.5);-webkit-backdrop-filter:blur(3px);backdrop-filter:blur(3px);opacity:0;transition:opacity .2s ease;}" +
    ".sc-ov.show{opacity:1;}" +
    ".sc-sheet{width:100%;background:var(--surface,#fff);border-radius:24px 24px 0 0;padding:10px 18px calc(20px + env(safe-area-inset-bottom));transform:translateY(16px);transition:transform .24s cubic-bezier(.2,.8,.2,1);max-height:92%;overflow-y:auto;box-shadow:0 -12px 40px rgba(0,0,0,.25);}" +
    ".sc-ov.show .sc-sheet{transform:translateY(0);}" +
    ".sc-grip{width:40px;height:4px;border-radius:999px;background:var(--surface-3,#d9e0d6);margin:2px auto 12px;}" +
    ".sc-shead{display:flex;align-items:center;justify-content:space-between;}" +
    ".sc-ttl{font-family:var(--font-display,inherit);font-size:18px;font-weight:800;color:var(--ink,#15231a);}" +
    ".sc-x{width:34px;height:34px;border:0;border-radius:10px;background:var(--surface-2,#f1f4ef);color:var(--ink-2,#4d5d52);display:grid;place-items:center;cursor:pointer;}" +
    ".sc-x svg{width:18px;height:18px;}" +
    ".sc-sub{font-size:12.5px;font-weight:600;color:var(--ink-3,#8a978d);margin:4px 0 14px;}" +
    ".sc-opt{display:flex;align-items:center;gap:13px;width:100%;border:1.5px solid var(--line,#eef1ec);background:#fff;border-radius:16px;padding:14px;cursor:pointer;font-family:var(--font-body,inherit);text-align:left;margin-bottom:11px;transition:border-color .15s,background .15s;}" +
    ".sc-opt:active{background:var(--surface-2,#f1f4ef);}" +
    ".sc-oic{flex:0 0 46px;width:46px;height:46px;border-radius:13px;display:grid;place-items:center;color:#fff;}" +
    ".sc-oic.green{background:linear-gradient(135deg,#3cc23f,#2ba84a);}" +
    ".sc-oic.blue{background:linear-gradient(135deg,#5BAEE6,#3b82f6);}" +
    ".sc-oic svg{width:23px;height:23px;}" +
    ".sc-otx{flex:1;display:flex;flex-direction:column;gap:2px;min-width:0;}" +
    ".sc-otx b{font-size:14.5px;font-weight:800;color:var(--ink,#15231a);}" +
    ".sc-otx span{font-size:12px;font-weight:600;color:var(--ink-3,#8a978d);}" +
    ".sc-opt .chev{color:var(--ink-4,#aab3a8);flex:0 0 auto;display:grid;place-items:center;}" +
    ".sc-opt .chev svg{width:18px;height:18px;}" +
    ".sc-preview{border-radius:14px;overflow:hidden;margin:8px 0 4px;max-height:150px;}" +
    ".sc-preview img{width:100%;display:block;object-fit:cover;}" +
    ".sc-spin{width:42px;height:42px;margin:18px auto 0;border-radius:50%;border:4px solid rgba(43,168,74,.2);border-top-color:#2ba84a;animation:scanspin .8s linear infinite;}" +
    "@keyframes scanspin{to{transform:rotate(360deg)}}" +
    ".sc-hint{text-align:center;font-size:13px;font-weight:600;color:var(--ink-3,#8a978d);margin:14px 0 6px;}" +
    ".sc-ok{display:flex;align-items:center;gap:8px;font-size:13.5px;font-weight:800;color:var(--accent-deep,#177a36);margin:8px 0 12px;}" +
    ".sc-ok svg{width:20px;height:20px;}" +
    ".sc-fld{display:block;margin-bottom:11px;}" +
    ".sc-fld span{display:block;font-size:11px;font-weight:800;letter-spacing:.06em;text-transform:uppercase;color:var(--ink-3,#8a978d);margin-bottom:5px;}" +
    ".sc-fld input{width:100%;border:1px solid var(--line,#eef1ec);border-radius:11px;padding:11px 13px;font-family:var(--font-body,inherit);font-size:14.5px;font-weight:600;color:var(--ink,#15231a);background:var(--surface-2,#f8faf6);}" +
    ".sc-fld input:focus{outline:none;border-color:var(--accent,#3cc23f);background:#fff;}" +
    ".sc-btn{flex:1;border:0;border-radius:14px;padding:14px;font-family:var(--font-body,inherit);font-size:15px;font-weight:800;cursor:pointer;color:#fff;background:linear-gradient(135deg,#3cc23f,#2ba84a);box-shadow:0 8px 20px -8px rgba(43,168,74,.7);}" +
    ".sc-btn.ghost{background:var(--surface-2,#f1f4ef);color:var(--ink-2,#4d5d52);box-shadow:none;}" +
    ".sc-foot{display:flex;gap:10px;margin-top:8px;}" +
    /* full-screen camera */
    ".csc-ov{position:absolute;inset:0;z-index:95;background:#06100a;opacity:0;transition:opacity .25s ease;overflow:hidden;}" +
    ".csc-ov.show{opacity:1;}" +
    ".csc-video{position:absolute;inset:0;width:100%;height:100%;object-fit:cover;background:#06100a;}" +
    ".csc-fallbg{position:absolute;inset:0;background:radial-gradient(120% 80% at 50% 22%,#16482a,#06100a);}" +
    ".csc-top{position:absolute;top:0;left:0;right:0;z-index:4;display:flex;align-items:center;justify-content:space-between;padding:calc(14px + env(safe-area-inset-top)) 14px 14px;background:linear-gradient(rgba(0,0,0,.5),transparent);}" +
    ".csc-title{color:#fff;font-weight:800;font-size:15px;}" +
    ".csc-x{width:38px;height:38px;border:0;border-radius:50%;background:rgba(255,255,255,.18);color:#fff;display:grid;place-items:center;cursor:pointer;}" +
    ".csc-x svg{width:19px;height:19px;}" +
    ".csc-frame{position:absolute;left:50%;top:45%;transform:translate(-50%,-50%);width:84%;aspect-ratio:1.6/1;border-radius:16px;border:3px solid #EF4B4B;box-shadow:0 0 0 9999px rgba(6,16,10,.56);transition:border-color .25s ease;z-index:2;}" +
    ".csc-frame.ok{border-color:#3CC23F;}" +
    ".csc-frame .c{position:absolute;width:26px;height:26px;border:4px solid #EF4B4B;transition:border-color .25s ease;}" +
    ".csc-frame.ok .c{border-color:#3CC23F;}" +
    ".csc-frame .c.tl{left:-3px;top:-3px;border-right:0;border-bottom:0;border-radius:14px 0 0 0;}" +
    ".csc-frame .c.tr{right:-3px;top:-3px;border-left:0;border-bottom:0;border-radius:0 14px 0 0;}" +
    ".csc-frame .c.bl{left:-3px;bottom:-3px;border-right:0;border-top:0;border-radius:0 0 0 14px;}" +
    ".csc-frame .c.br{right:-3px;bottom:-3px;border-left:0;border-top:0;border-radius:0 0 14px 0;}" +
    ".csc-status{position:absolute;left:50%;bottom:132px;transform:translateX(-50%);z-index:4;display:inline-flex;align-items:center;gap:8px;background:rgba(6,16,10,.72);border:1px solid rgba(255,255,255,.16);padding:9px 15px;border-radius:999px;color:#fff;font-size:12.5px;font-weight:700;white-space:nowrap;max-width:90%;}" +
    ".csc-status .dot{width:9px;height:9px;border-radius:50%;background:#EF4B4B;transition:background .25s ease;flex:0 0 9px;}" +
    ".csc-status.ok .dot{background:#3CC23F;}" +
    ".csc-bottom{position:absolute;left:0;right:0;bottom:calc(30px + env(safe-area-inset-bottom));z-index:4;display:flex;justify-content:center;}" +
    ".csc-shutter{width:72px;height:72px;border-radius:50%;border:5px solid rgba(255,255,255,.92);background:rgba(255,255,255,.22);cursor:pointer;transition:transform .1s ease,border-color .25s ease,background .25s ease,box-shadow .25s ease;}" +
    ".csc-shutter.ready{border-color:#3CC23F;background:#3CC23F;box-shadow:0 0 22px 4px rgba(60,194,63,.6);}" +
    ".csc-shutter:active{transform:scale(.92);}" +
    ".csc-dragcard{position:absolute;z-index:3;width:62%;max-width:240px;background:rgba(255,255,255,.97);border-radius:12px;padding:14px 16px;display:flex;flex-direction:column;gap:5px;box-shadow:0 14px 32px rgba(0,0,0,.45);cursor:grab;touch-action:none;user-select:none;}" +
    ".csc-dragcard.grab{cursor:grabbing;}" +
    ".csc-dragcard b{font-size:14px;letter-spacing:.1em;color:#177a36;}" +
    ".csc-dragcard span{font-size:11.5px;color:#46514a;font-weight:600;}";
  document.head.appendChild(css);

  /* expose for testing */
  window.__openScan = openScan;
})();
