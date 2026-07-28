/* =========================================================
   AskEva — Compose Message module
   Mobile translation of the web "Compose Message" page:
     tabs → Single MSG · Group · CSV
   Single source for one-off / group / CSV message campaigns.
   Sends route through the shared chat (window.__chat) so a
   single or group send is reflected live, exactly like the
   rest of the app. Templates come from the shared library
   (window.AskEvaTemplates). Renders into #cmView.
   ========================================================= */
(function () {
  "use strict";
  var pane = document.getElementById("app-compose"); if (!pane) return;
  var view = document.getElementById("cmView"); if (!view) return;
  var $ = function (s, r) { return (r || document).querySelector(s); };
  var $$ = function (s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); };
  function esc(s) { return String(s == null ? "" : s).replace(/[&<>"]/g, function (c) { return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]; }); }
  var toastT;
  function toast(msg, dur) {
    var t = document.getElementById("toast"); if (!t) return;
    t.textContent = msg; t.style.opacity = "1"; t.style.transform = "translateX(-50%) translateY(0)";
    clearTimeout(toastT); toastT = setTimeout(function () { t.style.opacity = "0"; t.style.transform = "translateX(-50%) translateY(20px)"; }, dur || 1800);
  }

  /* ---------- persisted campaign log ---------- */
  var CK = "askeva.campaigns.v1";
  var campaigns; try { campaigns = JSON.parse(localStorage.getItem(CK)) || []; } catch (e) { campaigns = []; }
  function saveCampaigns() { try { localStorage.setItem(CK, JSON.stringify(campaigns)); } catch (e) {} }
  function logCampaign(rec) { rec.ts = Date.now(); campaigns.unshift(rec); saveCampaigns(); }
  window.AskEvaCampaigns = { list: function () { return campaigns.slice(); } };

  /* ---------- reference data ---------- */
  var COUNTRY_CODES = (window.AskEvaCC && window.AskEvaCC.length)
    ? window.AskEvaCC.map(function (x) { return [x[1], x[0] + " (" + x[1] + ")"]; })
    : [
    ["+91", "India (+91)"], ["+1", "United States (+1)"], ["+44", "United Kingdom (+44)"],
    ["+971", "UAE (+971)"], ["+61", "Australia (+61)"], ["+65", "Singapore (+65)"], ["+49", "Germany (+49)"]
  ];
  function newCampaignName() { return "CAMP-" + Math.floor(10000 + Math.random() * 89999); }
  /* National (subscriber) number length per dial code — used to bound + validate
     the Mobile Number field. Value is exact length (number) or [min,max].
     Unlisted codes fall back to the E.164 generic range. */
  var PHONE_LEN = {
    "+91": 10, "+1": 10, "+44": 10, "+971": 9, "+61": 9, "+65": 8, "+49": [10, 11],
    "+33": 9, "+86": 11, "+81": [10, 11], "+7": 10, "+39": [9, 10], "+34": 9, "+55": [10, 11],
    "+27": 9, "+92": 10, "+880": 10, "+94": 9, "+977": 10, "+60": [9, 10], "+62": [9, 12],
    "+63": 10, "+66": 9, "+84": 9, "+82": [9, 10], "+852": 8, "+853": 8, "+886": 9,
    "+966": 9, "+974": 8, "+965": 8, "+973": 8, "+968": 8, "+962": 9, "+961": [7, 8],
    "+20": 10, "+234": 10, "+254": 9, "+233": 9, "+263": 9, "+212": 9, "+213": 9, "+216": 8,
    "+90": 10, "+98": 10, "+64": [8, 9], "+353": 9, "+41": 9, "+43": [10, 11], "+31": 9,
    "+32": [8, 9], "+46": [7, 9], "+47": 8, "+45": 8, "+358": [9, 10], "+48": 9, "+351": 9,
    "+30": 10, "+52": 10, "+54": 10, "+57": 10, "+56": 9, "+51": 9, "+58": 10, "+593": 9,
    "+591": 8, "+595": 9, "+598": 8, "+506": 8, "+507": 8, "+509": 8, "+972": 9, "+420": 9,
    "+421": 9, "+36": 9, "+40": 9, "+380": 9, "+375": 9, "+994": 9, "+995": 9, "+998": 9,
    "+93": 9, "+960": 7, "+975": 8, "+856": [8, 9], "+855": [8, 9], "+95": [8, 10],
    "+673": 7, "+856": 9, "+976": 8, "+251": 9, "+255": 9, "+256": 9, "+260": 9, "+265": 9,
    "+44": 10, "+353": 9, "+966": 9, "+970": 9
  };
  function phoneLenFor(cc) {
    var v = PHONE_LEN[cc];
    if (v == null) return { min: 6, max: 15 };
    return typeof v === "number" ? { min: v, max: v } : { min: v[0], max: v[1] };
  }
  function phoneLenHint(cc) {
    if (!cc) return "";
    var p = phoneLenFor(cc);
    if (p.max === 15 && p.min === 6) return "";
    return p.min === p.max ? (p.min + " digits") : (p.min + "\u2013" + p.max + " digits");
  }
  /* Group-template Map-to-field columns (the group campaign column set) */
  var GROUP_VARS = ["S.No", "Contact Name", "Mobile Number", "Group Name", "Tags", "company", "doctor", "department", "Name", "ticketid", "companyname", "wabanumber", "amount", "mode", "method", "id", "status", "number", "date", "timing", "DisplayName", "questions", "plan", "validity", "1", "flat", "patient", "course", "code", "orderid", "products", "agentname", "mail id", "Description", "Actions"];
  function chatGroups() {
    var api = window.AskEvaContactsAPI;
    if (api && api.groups) {
      var g2 = api.groups().map(function (g) { return { id: g.id, name: g.name, count: g.count, synthetic: false }; })
        .filter(function (g) { return g.count > 0; });   // only groups that actually have members; no "All Contacts"
      return g2;
    }
    var list = (window.__chat && window.__chat.contacts) || [];
    var real = list.filter(function (c) { return c.group; }).map(function (c) {
      var n = parseInt((c.status || "").replace(/\D/g, ""), 10);
      return { id: c.id, name: c.name, count: isNaN(n) ? null : n, synthetic: false };
    });
    var groups = real.filter(function (g) { return g.count == null || g.count > 0; });   // hide empty groups; no "All Contacts"
    return groups;
  }

  /* ---------- per-tab draft state ---------- */
  var tab = "single";
  var draft = {
    single: { cc: "", mobile: "", content: "", tpl: null, campaign: newCampaignName() },
    group:  { groupId: "", content: "", tpl: null, campaign: newCampaignName() },
    csv:    { content: "", tpl: null, campaign: newCampaignName(), fileName: "", rows: [], headers: [], cc: "", ccCol: "", mobileCol: "" }
  };

  /* =========================================================
     RENDER
     ========================================================= */
  function render() {
    if (tab === "single") view.innerHTML = singleView();
    else if (tab === "group") view.innerHTML = groupView();
    else view.innerHTML = csvView();
    syncTabs();
    bind();
  }
  function syncTabs() { $$("#cmTabs button").forEach(function (b) { b.classList.toggle("active", b.getAttribute("data-tab") === tab); }); }

  /* shared message-content box */
  function contentBox(d) {
    if (d.content) {
      return '<div class="cm-field"><label class="cm-label">Message Content</label>' +
        '<div class="cm-content filled"><textarea class="cm-contentta" id="cmContent" rows="6" placeholder="Type your message…">' + esc(d.content) + '</textarea>' +
          '<button class="cm-tplchip" id="cmTplChange">' + IC.tpl + (d.tpl ? esc(d.tpl) : "Select template") + '</button></div></div>';
    }
    return '<div class="cm-field"><label class="cm-label">Message Content</label>' +
      '<button class="cm-content empty" id="cmContentPick"><span class="ic">' + IC.tplBig + '</span>' +
        '<span class="t">Click here to select template</span></button></div>';
  }
  function campaignField(d) {
    return '<div class="cm-field"><label class="cm-label">Campaign Name</label>' +
      '<input class="cm-input" id="cmCampaign" type="text" value="' + esc(d.campaign) + '" autocomplete="off"></div>';
  }
  function footerBtns() {
    return '<div class="cm-foot"><button class="cm-btn clear" id="cmClear">Clear</button>' +
      '<div class="cm-split"><button class="cm-btn send" id="cmSend">' + IC.send + 'Send Now</button>' +
        '<button class="cm-btn caret" id="cmCaret" aria-label="Send options">' + IC.chevD + '</button>' +
        '<div class="cm-menu" id="cmMenu" hidden>' +
          '<button data-s="now">' + IC.send + 'Send Now</button>' +
          '<button data-s="later">' + IC.clock + 'Schedule for later</button>' +
        '</div></div></div>';
  }

  function singleView() {
    var d = draft.single;
    var ccLabel = d.cc ? (COUNTRY_CODES.filter(function (x) { return x[0] === d.cc; })[0] || ["", d.cc])[1] : "";
    var pl = phoneLenFor(d.cc);
    return '<div class="cm-card">' +
      '<div class="cm-two">' +
        '<div class="cm-field"><label class="cm-label">Country Code</label>' +
          '<button class="cm-select' + (d.cc ? "" : " ph") + '" id="cmCC"><span>' + esc(d.cc ? ccLabel : "Select") + '</span>' + IC.chevD + '</button></div>' +
        '<div class="cm-field"><label class="cm-label">Mobile Number</label>' +
          '<input class="cm-input" id="cmMobile" type="tel" inputmode="numeric" maxlength="' + pl.max + '" placeholder="Enter the Mobile Number" value="' + esc(d.mobile) + '"></div>' +
      '</div>' +
      contentBox(d) + campaignField(d) + footerBtns() +
    '</div>';
  }

  function groupView() {
    var d = draft.group, groups = chatGroups();
    var opts = '<option value="">Please select</option>' + groups.map(function (g) {
      return '<option value="' + esc(g.id) + '"' + (d.groupId === g.id ? " selected" : "") + '>' + esc(g.name) + (g.count != null ? " (" + g.count + ")" : "") + '</option>';
    }).join("");
    return '<div class="cm-card">' +
      '<div class="cm-field"><label class="cm-label big">Select from Contact Groups:</label>' +
        '<div class="cm-selectwrap"><select class="cm-nativesel" id="cmGroup">' + opts + '</select>' + IC.chevD + '</div>' +
        (groups.length ? '' : '<div class="cm-hint">No contact groups yet — create one in Contacts → Manage Groups.</div>') + '</div>' +
      contentBox(d) + campaignField(d) + footerBtns() +
    '</div>';
  }

  function csvView() {
    var d = draft.csv;
    var ccOpts = '<option value="">Select</option>' + d.headers.map(function (h) { return '<option value="' + esc(h) + '"' + (d.ccCol === h ? " selected" : "") + '>' + esc(h) + '</option>'; }).join("");
    var colOpts = '<option value="">Select</option>' + d.headers.map(function (h) { return '<option value="' + esc(h) + '"' + (d.mobileCol === h ? " selected" : "") + '>' + esc(h) + '</option>'; }).join("");
    return '<div class="cm-csvwrap">' +
      '<div class="cm-card">' + contentBox(d) + campaignField(d) + footerBtns() + '</div>' +
      '<div class="cm-card cm-uploadcard">' +
        '<div class="cm-uploadnote">Upload CSV only, Max file size : 32 MB</div>' +
        '<div class="cm-field"><label class="cm-label">Choose File</label>' +
          '<button class="cm-upload' + (d.fileName ? " has" : "") + '" id="cmUpload">' + IC.upload + (d.fileName ? esc(d.fileName) : "Upload") + '</button></div>' +
        '<div class="cm-field"><label class="cm-label">Country Code:</label>' +
          '<div class="cm-selectwrap"><select class="cm-nativesel" id="cmCsvCC"' + (d.headers.length ? "" : " disabled") + '>' + ccOpts + '</select>' + IC.chevD + '</div>' +
          (d.headers.length ? '' : '<div class="cm-hint">Upload a CSV to map the country-code column.</div>') + '</div>' +
        '<div class="cm-field"><label class="cm-label">Mobile Number:</label>' +
          '<div class="cm-selectwrap"><select class="cm-nativesel" id="cmCsvCol"' + (d.headers.length ? "" : " disabled") + '>' + colOpts + '</select>' + IC.chevD + '</div>' +
          (d.headers.length ? '<div class="cm-hint ok">' + d.rows.length + ' row' + (d.rows.length === 1 ? "" : "s") + ' loaded</div>' : '<div class="cm-hint">Upload a CSV to choose the number column.</div>') + '</div>' +
      '</div>' +
    '</div>';
  }

  /* =========================================================
     BIND
     ========================================================= */
  function curDraft() { return draft[tab]; }
  function bind() {
    // tab switches (header segmented control)
    $$("#cmTabs button").forEach(function (b) { b.onclick = function () { tab = b.getAttribute("data-tab"); render(); }; });

    var d = curDraft();

    // message content
    var pick = $("#cmContentPick", view); if (pick) pick.onclick = openTemplatePicker;
    var chg = $("#cmTplChange", view); if (chg) chg.onclick = openTemplatePicker;
    var cta = $("#cmContent", view); if (cta) cta.oninput = function () { d.content = cta.value; };

    // campaign
    var camp = $("#cmCampaign", view); if (camp) camp.oninput = function () { d.campaign = camp.value; };

    // clear
    var clr = $("#cmClear", view); if (clr) clr.onclick = clearForm;

    // send split button
    var send = $("#cmSend", view); if (send) send.onclick = function () { doSend("now"); };
    var caret = $("#cmCaret", view), menu = $("#cmMenu", view);
    if (caret && menu) {
      caret.onclick = function (e) { e.stopPropagation(); menu.hidden = !menu.hidden; };
      $$("button[data-s]", menu).forEach(function (b) { b.onclick = function () { menu.hidden = true; var s = b.getAttribute("data-s"); if (s === "later" && window.AskEvaPicker) { var cd = curDraft(); if (!(cd.content || "").trim()) { toast("Select a template or enter a message"); return; } window.AskEvaPicker.dateTime({ minToday: true, timezone: true, onPick: function (p) { doSend("later", p); } }); } else doSend(s); }; });
    }

    if (tab === "single") {
      var cc = $("#cmCC", view); if (cc) cc.onclick = function () { openCountryPick(function (v) { d.cc = v; render(); }); };
      var mob = $("#cmMobile", view); if (mob) mob.oninput = function () { var mx = phoneLenFor(d.cc).max; d.mobile = mob.value.replace(/[^\d]/g, "").slice(0, mx); if (mob.value !== d.mobile) mob.value = d.mobile; };
    } else if (tab === "group") {
      var gsel = $("#cmGroup", view); if (gsel) gsel.onchange = function () { d.groupId = gsel.value; };
    } else if (tab === "csv") {
      var up = $("#cmUpload", view); if (up) up.onclick = pickCSV;
      var ccs = $("#cmCsvCC", view); if (ccs) ccs.onchange = function () { d.ccCol = ccs.value; };
      var col = $("#cmCsvCol", view); if (col) col.onchange = function () { d.mobileCol = col.value; };
    }
  }

  /* close the send menu on outside click */
  document.addEventListener("click", function (e) {
    var m = $("#cmMenu", view); if (m && !m.hidden && (!e.target.closest || !e.target.closest(".cm-split"))) m.hidden = true;
  });

  function openTemplatePicker() {
    var d = curDraft();
    if (window.AskEvaTemplates && window.AskEvaTemplates.open) {
      window.AskEvaTemplates.open({ title: "Select template", valueOnly: tab === "single", fields: tab === "group" ? GROUP_VARS : null, onSend: function (t) {
        d.tpl = (t && (t.n || t.name)) || "Template";
        d.content = (t && (t.p || t.text)) || "";
        render();
      } });
    } else { toast("Templates unavailable"); }
  }

  function openCountryPick(cb) {
    // lightweight bottom sheet built locally (compose has no shared sheet)
    var scrim = document.createElement("div"); scrim.className = "cm-scrim";
    var sheet = document.createElement("div"); sheet.className = "cm-sheet";
    sheet.innerHTML = '<div class="cm-sheethd">Select country code</div>' +
      '<div class="cm-ccsrch"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><circle cx="11" cy="11" r="7"/><path d="M21 21l-4.3-4.3"/></svg>' +
        '<input type="text" id="cmCCSearch" placeholder="Search country or code" autocomplete="off"></div>' +
      '<div class="cm-cclist" id="cmCCList">' +
      COUNTRY_CODES.map(function (x) { return '<button class="cm-sheetopt" data-v="' + x[0] + '">' + esc(x[1]) + '</button>'; }).join("") + '</div>';
    function close() { scrim.classList.remove("show"); sheet.classList.remove("show"); setTimeout(function () { scrim.remove(); sheet.remove(); }, 220); }
    scrim.onclick = close;
    pane.appendChild(scrim); pane.appendChild(sheet);
    var listEl = sheet.querySelector("#cmCCList"), srch = sheet.querySelector("#cmCCSearch");
    function renderOpts() {
      var q = (srch.value || "").trim().toLowerCase();
      var rows = COUNTRY_CODES.filter(function (x) { return !q || x[1].toLowerCase().indexOf(q) >= 0 || String(x[0]).toLowerCase().indexOf(q) >= 0; });
      listEl.innerHTML = rows.length
        ? rows.map(function (x) { return '<button class="cm-sheetopt" data-v="' + x[0] + '">' + esc(x[1]) + '</button>'; }).join("")
        : '<div class="cm-ccnone">No match</div>';
      bindOpts();
    }
    function bindOpts() {
      sheet.querySelectorAll(".cm-sheetopt").forEach(function (b) { b.onclick = function () { if (cb) cb(b.getAttribute("data-v")); close(); }; });
    }
    srch.addEventListener("input", renderOpts);
    bindOpts();
    requestAnimationFrame(function () { scrim.classList.add("show"); sheet.classList.add("show"); setTimeout(function () { srch.focus(); }, 60); });
  }

  function pickCSV() {
    var d = draft.csv;
    var inp = document.createElement("input"); inp.type = "file"; inp.accept = ".csv,text/csv"; inp.style.display = "none";
    document.body.appendChild(inp);
    inp.onchange = function () {
      var f = inp.files && inp.files[0];
      if (!f) { inp.remove(); return; }
      var isCsv = /\.csv$/i.test(f.name) || /csv/i.test(f.type || "");
      if (!isCsv) { toast("Only CSV files can be uploaded"); inp.remove(); return; }
      if (f.size > 32 * 1024 * 1024) { toast("File exceeds 32 MB"); inp.remove(); return; }
      var rd = new FileReader();
      rd.onload = function () {
        var parsed = parseCSV(String(rd.result || ""));
        if (parsed.length < 1) { toast("Empty CSV"); inp.remove(); return; }
        d.headers = parsed[0].map(function (h) { return (h || "").trim(); });
        d.rows = parsed.slice(1).filter(function (r) { return r.join("").trim(); });
        d.fileName = f.name;
        // auto-pick a likely mobile column
        var guess = d.headers.filter(function (h) { return /mobile|phone|number|contact/i.test(h); })[0];
        if (guess) d.mobileCol = guess;
        inp.remove(); render(); toast("Loaded " + d.rows.length + " rows from " + f.name);
      };
      rd.onerror = function () { inp.remove(); toast("Could not read file"); };
      rd.readAsText(f);
    };
    inp.click();
  }
  function parseCSV(text) {
    var rows = [], row = [], cur = "", i = 0, inQ = false, ch;
    text = text.replace(/\r\n/g, "\n").replace(/\r/g, "\n");
    while (i < text.length) {
      ch = text[i];
      if (inQ) { if (ch === '"') { if (text[i + 1] === '"') { cur += '"'; i++; } else inQ = false; } else cur += ch; }
      else { if (ch === '"') inQ = true; else if (ch === ",") { row.push(cur); cur = ""; } else if (ch === "\n") { row.push(cur); rows.push(row); row = []; cur = ""; } else cur += ch; }
      i++;
    }
    if (cur.length || row.length) { row.push(cur); rows.push(row); }
    return rows;
  }

  function clearForm() {
    var name = newCampaignName();
    if (tab === "single") draft.single = { cc: "", mobile: "", content: "", tpl: null, campaign: name };
    else if (tab === "group") draft.group = { groupId: "", content: "", tpl: null, campaign: name };
    else draft.csv = { content: "", tpl: null, campaign: name, fileName: "", rows: [], headers: [], cc: "", ccCol: "", mobileCol: "" };
    render(); toast("Cleared");
  }

  function doSend(when, sched) {
    var d = curDraft();
    var content = (d.content || "").trim();
    if (!content) { toast("Select a template or enter a message"); return; }

    if (tab === "single") {
      if (!d.cc) { toast("Select a country code"); return; }
      var pl = phoneLenFor(d.cc);
      if (!d.mobile || d.mobile.length < pl.min || d.mobile.length > pl.max) {
        toast(pl.min === pl.max
          ? d.cc + " numbers must be " + pl.min + " digits"
          : d.cc + " numbers must be " + pl.min + "\u2013" + pl.max + " digits");
        return;
      }
      var phone = d.cc.replace("+", "") + d.mobile;
      logCampaign({ name: d.campaign, type: "single", to: 1, when: when, content: content });
      if (when === "later") { schedule(d.campaign, 1, sched); resetAfterSend(); return; }
      deliverToChat({ name: d.cc + " " + d.mobile, phone: phone }, content);
      toast("Sent to " + d.cc + " " + d.mobile);
      resetAfterSend();
    } else if (tab === "group") {
      if (!d.groupId) { toast("Select a contact group"); return; }
      var g = chatGroups().filter(function (x) { return x.id === d.groupId; })[0] || { name: "Group", count: 0, synthetic: true };
      logCampaign({ name: d.campaign, type: "group", group: g.name, to: g.count || 0, when: when, content: content });
      if (when === "later") { schedule(d.campaign, g.count || 0, sched); resetAfterSend(); return; }
      if (g.synthetic) {
        // broadcast segment — no single conversation to open; record + confirm
        toast("Sent to " + g.name + (g.count ? " (" + g.count + " contact" + (g.count === 1 ? "" : "s") + ")" : ""));
      } else {
        var capi = window.AskEvaContactsAPI;
        var members = capi ? (d.groupId === "all" ? capi.list() : capi.contactsInGroup(d.groupId)) : [];
        members = members.filter(function (c) { return !capi || !capi.isOptedOut(c.mobile); });
        var delivered = 0;
        members.forEach(function (c) { if (window.__chat && window.__chat.deliverToThread) { window.__chat.deliverToThread({ name: c.name, phone: c.mobile }, { type: "text", text: content }); delivered++; } });
        if (!delivered && window.deliverToChat) deliverToChat({ id: d.groupId }, content);
        toast("Sent to " + g.name + " (" + (delivered || g.count || 0) + " contact" + ((delivered || g.count || 0) === 1 ? "" : "s") + ")");
      }
      resetAfterSend();
    } else {
      if (!d.rows.length) { toast("Upload a CSV file first"); return; }
      if (!d.mobileCol) { toast("Choose the mobile number column"); return; }
      var midx = d.headers.indexOf(d.mobileCol);
      var cidx = d.ccCol ? d.headers.indexOf(d.ccCol) : -1;
      var nidx = d.headers.indexOf((d.headers.filter(function (h) { return /name/i.test(h); })[0]) || "");
      var recips = d.rows.map(function (r) {
        var num = (r[midx] || "").replace(/[^\d]/g, ""); if (num.length < 6) return null;
        var cc = cidx > -1 ? (r[cidx] || "").replace(/[^\d]/g, "") : "";
        return { phone: cc ? cc + num : num, name: (nidx > -1 ? (r[nidx] || "") : "") || ("+" + cc + " " + num) };
      }).filter(Boolean);
      if (!recips.length) { toast("No valid numbers in that column"); return; }
      logCampaign({ name: d.campaign, type: "csv", file: d.fileName, to: recips.length, when: when, content: content });
      if (when === "later") { schedule(d.campaign, recips.length, sched); resetAfterSend(); return; }
      var capi = window.AskEvaContactsAPI, sent = 0;
      recips.forEach(function (rc) { if (capi && capi.isOptedOut(rc.phone)) return; if (window.__chat && window.__chat.deliverToThread) { window.__chat.deliverToThread({ name: rc.name, phone: rc.phone }, { type: "text", text: content }); sent++; } });
      toast("Sent " + (sent || recips.length) + " message" + ((sent || recips.length) === 1 ? "" : "s") + " \u00b7 " + d.campaign);
      resetAfterSend();
    }
  }
  function schedule(name, n, sched) { toast("Message scheduled successfully", 3000); }
  function resetAfterSend() {
    var name = newCampaignName();
    if (tab === "single") draft.single = { cc: "", mobile: "", content: "", tpl: null, campaign: name };
    else if (tab === "group") draft.group = { groupId: "", content: "", tpl: null, campaign: name };
    else { draft.csv.content = ""; draft.csv.tpl = null; draft.csv.campaign = name; }
    render();
  }

  /* deliver live through the shared chat (single source of truth) */
  function deliverToChat(target, text) {
    if (window.__chat && window.__chat.sendQuickReplyTo) { window.__chat.sendQuickReplyTo(target, text); return true; }
    if (window.__openChatFrom) { window.__openChatFrom("compose", target.id || null, "Compose", target); return true; }
    return false;
  }

  /* icons */
  var IC = {
    chevD: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m6 9 6 6 6-6"/></svg>',
    tplBig: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M16 16l-4-4-4 4"/><path d="M12 12v9"/><path d="M20.39 18.39A5 5 0 0 0 18 9h-1.26A8 8 0 1 0 3 16.3"/></svg>',
    tpl: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M16 16l-4-4-4 4"/><path d="M12 12v9"/><path d="M20.39 18.39A5 5 0 0 0 18 9h-1.26A8 8 0 1 0 3 16.3"/></svg>',
    x: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 6l12 12M18 6L6 18"/></svg>',
    send: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 12l16-8-6 16-3-7-7-1Z"/></svg>',
    clock: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3.5 2"/></svg>',
    upload: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 15v3a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-3"/><path d="m8 9 4-4 4 4"/><path d="M12 5v11"/></svg>'
  };

  render();
  window.AskEvaCompose = { render: render, setTab: function (t) { tab = t; render(); } };
})();
