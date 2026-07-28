/* =========================================================
   AskEva — Contacts module · part 2
   UI-Contacts (inbound-first message senders, fed to Leads)
   and Opt-out (Unsubscribed / Blocked) tabs.
   Plugs into the shell exposed by contacts.js (window.__contacts).
   ========================================================= */
(function () {
  "use strict";
  var M = window.__contacts;
  if (!M) return;
  var I = M.I, esc = M.esc, digits = M.digits, toast = M.toast, initials = M.initials;

  var ICX = {
    cal: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="5" width="18" height="16" rx="2.5"/><path d="M3 10h18M8 3v4M16 3v4"/></svg>',
    cart: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="9" cy="20" r="1.4"/><circle cx="17" cy="20" r="1.4"/><path d="M2 3h3l2.4 12.4a1.5 1.5 0 0 0 1.5 1.2h8.2a1.5 1.5 0 0 0 1.5-1.2L22 7H6"/></svg>',
    msg: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 12a8 8 0 0 1-11.6 7.1L3 21l1.9-6.4A8 8 0 1 1 21 12Z"/></svg>',
    block: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="M5.6 5.6l12.8 12.8"/></svg>'
  };

  /* =========================================================
     UI-CONTACTS  (people who messaged first → also become Leads)
     ========================================================= */
  var uiState = { q: "", start: "", end: "" };
  function uiSource() {
    var list = (window.__chat && window.__chat.contacts) || [];
    return list.filter(function (c) {
      if (c.group || c.broadcast) return false;
      var fm = (c.thread || []).filter(function (m) { return m.dir; })[0];
      var inboundFirst = fm ? fm.dir === "in" : true;   // unknown → treat as inbound enquiry
      return inboundFirst;
    }).map(function (c) {
      return { id: c.id, name: c.name || "", phone: digits(c.phone || ""), preview: c.preview || "", time: c.time || "",
        ts: c.lastTs || 0, tags: (c.tags || []).slice(), _c: c };
    });
  }
  function fmtTs(r) {
    if (r.ts) { var d = new Date(r.ts), p = function (n) { return (n < 10 ? "0" : "") + n; };
      return p(d.getDate()) + "/" + p(d.getMonth() + 1) + "/" + d.getFullYear() + " " + p(d.getHours()) + ":" + p(d.getMinutes()) + ":" + p(d.getSeconds()); }
    return r.time || "—";
  }
  function uiFiltered() {
    var q = uiState.q.trim().toLowerCase();
    var s = uiState.start ? new Date(uiState.start + "T00:00:00").getTime() : null;
    var e = uiState.end ? new Date(uiState.end + "T23:59:59").getTime() : null;
    return uiSource().filter(function (r) {
      if (s && r.ts && r.ts < s) return false;
      if (e && r.ts && r.ts > e) return false;
      if (!q) return true;
      return (r.name + " " + r.phone + " " + r.tags.join(" ")).toLowerCase().indexOf(q) > -1;
    });
  }
  function renderUIContacts(body) {
    var list = uiFiltered();
    body.innerHTML =
      '<div class="ct-search" style="margin-bottom:12px">' + I.search + '<input id="uicQ" type="text" placeholder="Search tag / name / number" value="' + esc(uiState.q) + '"></div>' +
      '<div class="ct-daterow">' +
        '<button class="dp-pill" id="uicRange" type="button" style="flex:0 1 auto;margin-right:auto"></button>' +
        '<button class="ct-actchip primary" id="uicExport" style="flex:0 0 auto">' + I.up + 'Export</button>' +
      '</div>' +
      '<div class="ct-count"><b>' + list.length + '</b> ' + (list.length === 1 ? "contact" : "contacts") + ' · user-initiated' +
        '<span style="color:var(--eva-green-deep,#177a36)"> · auto-synced to Leads</span></div>' +
      '<div class="ct-list" id="uicList">' + (list.length ? list.map(uiCard).join("") : '<div class="ct-empty">' + ICX.msg + '<div class="t">No inbound contacts</div><div class="s">People who message you first appear here and are added to Leads automatically.</div></div>') + '</div>';
    var qi = body.querySelector("#uicQ"); if (qi) qi.addEventListener("input", function () { uiState.q = qi.value; var l = body.querySelector("#uicList"); var arr = uiFiltered(); l.innerHTML = arr.length ? arr.map(uiCard).join("") : '<div class="ct-empty">' + ICX.msg + '<div class="t">No matches</div></div>'; bindUI(body); });
    var rp = body.querySelector("#uicRange"); if (rp && window.AskEvaPicker) window.AskEvaPicker.rangePill(rp, { start: uiState.start, end: uiState.end, onChange: function (r) { uiState.start = r.start; uiState.end = r.end; M.rerender(); } });
    var ex = body.querySelector("#uicExport"); if (ex) ex.addEventListener("click", function () { exportUI(uiFiltered()); });
    bindUI(body);
  }
  function uiCard(r) {
    var media = /order|item/i.test(r.preview) ? '<span class="ic">' + ICX.cart + '</span>' : "";
    var tags = r.tags.map(function (t) { return '<span class="ct-tag">' + esc(t) + '</span>'; }).join("");
    return '<div class="ct-uicard" data-id="' + r.id + '">' +
      '<span class="ct-av">' + esc(initials(r.name || r.phone).toUpperCase()) + '</span>' +
      '<div class="ct-info">' +
        '<div class="ct-nm">' + (esc(r.name) || '<span style="color:var(--ink-3,#8a978d)">' + esc(r.phone) + '</span>') + '</div>' +
        '<div class="lm">' + media + '<span style="overflow:hidden;text-overflow:ellipsis;white-space:nowrap">' + esc(r.preview || "—") + '</span></div>' +
        '<div class="when">' + esc(fmtTs(r)) + ' · ' + esc(r.phone) + '</div>' +
        '<div class="ct-chips">' + tags + '<button class="ct-addtag" data-addtag>+ Add Tag</button></div>' +
      '</div>' +
    '</div>';
  }
  function bindUI(body) {
    body.querySelectorAll(".ct-uicard").forEach(function (card) {
      var id = card.getAttribute("data-id");
      var at = card.querySelector("[data-addtag]");
      if (at) at.addEventListener("click", function (e) { e.stopPropagation(); addUITag(id); });
      card.addEventListener("click", function () { if (window.__openChatFrom) window.__openChatFrom("contacts", id, "Contacts"); });
    });
  }
  function addUITag(id) {
    var src = uiSource().filter(function (r) { return r.id === id; })[0]; if (!src) return;
    M.promptTag ? M.promptTag() : promptTag(function (v) {
      var c = src._c; c.tags = c.tags || []; if (c.tags.indexOf(v) < 0) c.tags.push(v);
      // sync the tag onto the saved Contact (same number), if any
      if (window.AskEvaContactsAPI) { var saved = (window.AskEvaContactsAPI.list() || []).filter(function (x) { return digits(x.mobile).slice(-10) === digits(src.phone).slice(-10); })[0]; if (saved) { saved.tags = saved.tags || []; if (saved.tags.indexOf(v) < 0) saved.tags.push(v); M.saveAll(); } }
      if (window.__chat && window.__chat.refresh) window.__chat.refresh();
      M.rerender(); toast("Tag added");
    });
  }
  // small tag prompt reusing the module's modal
  var tagScrim;
  function promptTag(onOk) {
    var host = M.host;
    if (!tagScrim) { tagScrim = document.createElement("div"); tagScrim.className = "ct-modal-scrim"; host.appendChild(tagScrim); tagScrim.addEventListener("click", function (e) { if (e.target === tagScrim) tagScrim.classList.remove("show"); }); }
    tagScrim.innerHTML = '<div class="ct-modal"><div class="mt">Add tag</div><input class="ct-input" id="ctTagI" maxlength="24" placeholder="Tag name"><div class="mb"><button class="ct-btn ghost" id="ctTagC">Cancel</button><button class="ct-btn primary" id="ctTagO" style="flex:0 0 auto;padding:12px 22px">Add</button></div></div>';
    tagScrim.classList.add("show");
    var inp = tagScrim.querySelector("#ctTagI"); setTimeout(function () { inp.focus(); }, 80);
    tagScrim.querySelector("#ctTagC").addEventListener("click", function () { tagScrim.classList.remove("show"); });
    tagScrim.querySelector("#ctTagO").addEventListener("click", function () { var v = inp.value.trim(); if (!v) return; tagScrim.classList.remove("show"); onOk(v); });
  }
  function exportUI(rows) {
    var lines = ["Name,Mobile,LastMessageTime,LastMessage,Tags"];
    rows.forEach(function (r) { lines.push([r.name, r.phone, fmtTs(r), r.preview, r.tags.join("|")].map(function (v) { v = String(v == null ? "" : v); return /[",\n]/.test(v) ? '"' + v.replace(/"/g, '""') + '"' : v; }).join(",")); });
    try { var b = new Blob([lines.join("\n")], { type: "text/csv" }); var u = URL.createObjectURL(b); var a = document.createElement("a"); a.href = u; a.download = "ui-contacts.csv"; document.body.appendChild(a); a.click(); setTimeout(function () { a.remove(); URL.revokeObjectURL(u); }, 200); } catch (e) {}
    toast("Exported " + rows.length + " contact" + (rows.length === 1 ? "" : "s"));
  }

  /* =========================================================
     OPT-OUT  (Unsubscribed / Blocked)
     ========================================================= */
  var ooTab = "unsubscribed";
  var ooSelMode = false;   // Blocked tab: Contacts-style Select / Select all toggle
  var ooSel = {};   // last-10 mobile -> selected
  function ooKey(e) { return digits(e.mobile).slice(-10); }
  function renderOptOut(body) {
    var OO = M.OPTOUT();
    var rows = (OO[ooTab] || []);
    // drop selections no longer in this tab
    var present = {}; rows.forEach(function (e) { present[ooKey(e)] = 1; });
    Object.keys(ooSel).forEach(function (k) { if (!present[k]) delete ooSel[k]; });
    var selN = Object.keys(ooSel).filter(function (k) { return ooSel[k]; }).length;
    var isBlocked = ooTab === "blocked";
    if (!isBlocked) ooSelMode = false;
    var toolsHTML = (isBlocked && ooSelMode)
      ? '<div class="ct-ootools">' +
          '<button class="ct-actchip" id="ooUnblock"' + (selN ? '' : ' disabled style="opacity:.5;cursor:default"') + '>Bulk Unblock (' + selN + ')</button>' +
        '</div>'
      : '';
    body.innerHTML =
      '<div class="ct-subtabs">' +
        '<button class="ct-subtab' + (ooTab === "unsubscribed" ? " on" : "") + '" data-oo="unsubscribed">Unsubscribed</button>' +
        '<button class="ct-subtab' + (isBlocked ? " on" : "") + '" data-oo="blocked">Blocked</button>' +
        (isBlocked ? '<button class="oo-uploadbtn" id="ooUploadBlock" type="button">' + I.up + 'Upload CSV</button>' : '') +
      '</div>' +
      toolsHTML +
      '<div class="ct-count"><span class="ct-countn"><b>' + rows.length + '</b> ' + (ooTab === "blocked" ? "blocked" : "unsubscribed") + '</span>' +
        (selN ? '<span class="ct-selnote">' + selN + ' selected</span>' : '') +
        (isBlocked && rows.length ? '<span style="display:flex;gap:8px;flex:0 0 auto;margin-left:auto">' +
          (ooSelMode ? '<button class="ct-selecttog on" data-oo-a="selall"><span>' + (selN === rows.length ? "Deselect all" : "Select all") + '</span></button>' : '') +
          '<button class="ct-selecttog' + (ooSelMode ? " on" : "") + '" data-oo-a="select">' + (ooSelMode ? I.x : I.check) + '<span>' + (ooSelMode ? "Cancel" : "Select") + '</span></button>' +
        '</span>' : '') + '</div>' +
      (rows.length ? rows.map(ooRow).join("") :
        '<div class="ct-empty">' + (ooTab === "blocked" ? ICX.block : ICX.msg) + '<div class="t">No ' + ooTab + ' contacts</div>' +
        '<div class="s">' + (ooTab === "blocked" ? "Contacts you block from a chat appear here and are excluded from Compose." : "Contacts who opt out of messages appear here and are skipped by Compose.") + '</div></div>');
    body.querySelectorAll(".ct-subtab").forEach(function (b) { b.addEventListener("click", function () { ooTab = b.getAttribute("data-oo"); ooSel = {}; ooSelMode = false; M.rerender(); }); });
    body.querySelectorAll("[data-oo-a]").forEach(function (b) { b.addEventListener("click", function () {
      var a = b.getAttribute("data-oo-a");
      if (a === "select") { ooSelMode = !ooSelMode; if (!ooSelMode) ooSel = {}; M.rerender(); }
      else if (a === "selall") { var all = rows.length && Object.keys(ooSel).filter(function (k) { return ooSel[k]; }).length === rows.length; ooSel = {}; if (!all) rows.forEach(function (e) { ooSel[ooKey(e)] = true; }); M.rerender(); }
    }); });
    body.querySelectorAll("[data-sel]").forEach(function (b) { b.addEventListener("click", function (e) { e.stopPropagation(); var k = b.getAttribute("data-sel"); ooSel[k] = !ooSel[k]; b.classList.toggle("on", !!ooSel[k]); var row = b.closest(".ct-oorow"); if (row) row.classList.toggle("sel", !!ooSel[k]); var note = body.querySelector(".ct-selnote"); var n = Object.keys(ooSel).filter(function (x) { return ooSel[x]; }).length; if (note) note.textContent = n ? n + " selected" : ""; else if (n) { var c = body.querySelector(".ct-count"); if (c) c.insertAdjacentHTML("afterbegin", '<span class="ct-selnote">' + n + ' selected</span>'); } var ub = body.querySelector("#ooUnblock"); if (ub) { ub.disabled = !n; ub.style.opacity = n ? "" : ".5"; ub.style.cursor = n ? "pointer" : "default"; ub.textContent = "Bulk Unblock (" + n + ")"; } }); });
    var ex = body.querySelector("#ooExport"); if (ex) ex.addEventListener("click", function () { if (rows.length) ooExport(rows); });
    var unb = body.querySelector("#ooUnblock"); if (unb) unb.addEventListener("click", function () { if (Object.keys(ooSel).filter(function (k) { return ooSel[k]; }).length) ooBulk("unblock"); });
    var upb = body.querySelector("#ooUploadBlock"); if (upb) upb.addEventListener("click", ooUploadBlockCSV);
    body.querySelectorAll("[data-restore]").forEach(function (b) { b.addEventListener("click", function () {
      var m = b.getAttribute("data-restore"); var arr = OO[ooTab]; var idx = arr.findIndex(function (e) { return digits(e.mobile).slice(-10) === m; }); if (idx > -1) arr.splice(idx, 1); delete ooSel[m]; M.saveOptOut(); M.rerender(); toast(ooTab === "blocked" ? "Unblocked" : "Re-subscribed");
    }); });
  }
  function ooBulk(action) {
    if (!action) return;
    var keys = Object.keys(ooSel).filter(function (k) { return ooSel[k]; });
    if (!keys.length) { toast("Select contacts first"); return; }
    var OO = M.OPTOUT(), arr = OO[ooTab];
    keys.forEach(function (k) {
      var idx = arr.findIndex(function (e) { return ooKey(e) === k; }); if (idx < 0) return;
      var rec = arr[idx];
      if (action === "subscribe" || action === "unblock") { arr.splice(idx, 1); }
      else if (action === "unsubscribe") { arr.splice(idx, 1); if (!OO.unsubscribed.some(function (e) { return ooKey(e) === k; })) OO.unsubscribed.unshift(rec); }
      else if (action === "block") { arr.splice(idx, 1); if (!OO.blocked.some(function (e) { return ooKey(e) === k; })) OO.blocked.unshift(rec); }
    });
    var n = keys.length; ooSel = {}; M.saveOptOut(); M.rerender();
    var verb = action === "subscribe" || action === "unblock" ? "subscribed" : (action === "block" ? "blocked" : "unsubscribed");
    toast(n + " contact" + (n > 1 ? "s" : "") + " " + verb);
  }
  function ooExport(rows) {
    function cell(v) { v = String(v == null ? "" : v); return /[",\n]/.test(v) ? '"' + v.replace(/"/g, '""') + '"' : v; }
    var lines = ["Name,Mobile,Status,Date"];
    rows.forEach(function (e) {
      var d = new Date(e.ts || Date.now()), p = function (n) { return (n < 10 ? "0" : "") + n; };
      lines.push([e.name || "", e.mobile, ooTab, p(d.getDate()) + "/" + p(d.getMonth() + 1) + "/" + d.getFullYear()].map(cell).join(","));
    });
    try { var b = new Blob([lines.join("\n")], { type: "text/csv" }); var u = URL.createObjectURL(b); var a = document.createElement("a"); a.href = u; a.download = ooTab + "-contacts.csv"; document.body.appendChild(a); a.click(); setTimeout(function () { a.remove(); URL.revokeObjectURL(u); }, 200); } catch (e) {}
    toast("Exported " + rows.length + " contact" + (rows.length === 1 ? "" : "s"));
  }
  /* ---- Upload CSV to Block: pick a file, parse mobiles, add to blocked list ---- */
  function ooUploadBlockCSV() {
    var inp = document.createElement("input"); inp.type = "file"; inp.accept = ".csv,text/csv"; inp.style.display = "none"; document.body.appendChild(inp);
    inp.addEventListener("change", function () {
      var f = inp.files && inp.files[0]; if (!f) { inp.remove(); return; }
      if (!(/\.csv$/i.test(f.name) || /csv/i.test(f.type || ""))) { toast("Only CSV files can be uploaded"); inp.remove(); return; }
      var rd = new FileReader();
      rd.onload = function () {
        var added = parseBlockCSV(String(rd.result || "")); inp.remove();
        ooTab = "blocked"; M.saveOptOut(); M.rerender();
        toast(added ? added + " contact" + (added === 1 ? "" : "s") + " blocked" : "No new mobile numbers found");
      };
      rd.readAsText(f);
    });
    inp.click();
  }
  function parseBlockCSV(text) {
    var OO = M.OPTOUT(), blocked = OO.blocked, added = 0;
    var lines = text.split(/\r?\n/).filter(function (l) { return l.trim(); });
    if (!lines.length) return 0;
    function split(l) { return l.split(",").map(function (s) { return s.trim().replace(/^"|"$/g, ""); }); }
    var first = lines[0].toLowerCase(), hasHeader = /name|mobile|phone|number/.test(first);
    var mobCol = -1, nameCol = -1;
    if (hasHeader) { split(lines[0]).forEach(function (c, i) { c = c.toLowerCase(); if (mobCol < 0 && /mobile|phone|number/.test(c)) mobCol = i; if (nameCol < 0 && /name/.test(c)) nameCol = i; }); }
    for (var i = hasHeader ? 1 : 0; i < lines.length; i++) {
      var parts = split(lines[i]), mob = "", nm = "";
      if (mobCol > -1) { mob = parts[mobCol] || ""; nm = nameCol > -1 ? (parts[nameCol] || "") : ""; }
      else { var bestN = 0; parts.forEach(function (p) { var dn = digits(p).length; if (dn > bestN) { bestN = dn; mob = p; } }); nm = parts.filter(function (p) { return p !== mob && /[a-z]/i.test(p); })[0] || ""; }
      var dd = digits(mob); if (dd.length < 7) continue;
      var key = dd.slice(-10);
      if (blocked.some(function (e) { return digits(e.mobile).slice(-10) === key; })) continue;
      blocked.unshift({ name: nm, mobile: dd, ts: Date.now() });
      added++;
    }
    return added;
  }
  function ooRow(e) {
    var d = new Date(e.ts || Date.now()), p = function (n) { return (n < 10 ? "0" : "") + n; };
    var h = d.getHours(), ap = h < 12 ? "AM" : "PM", h12 = (h % 12) || 12;
    var when = p(d.getDate()) + "/" + p(d.getMonth() + 1) + "/" + d.getFullYear() + " " + p(h12) + ":" + p(d.getMinutes()) + " " + ap;
    var k = ooKey(e);
    return '<div class="ct-oorow' + (ooSel[k] ? " sel" : "") + '">' +
      (ooTab === "blocked" && ooSelMode ? '<button class="oo-check' + (ooSel[k] ? " on" : "") + '" data-sel="' + k + '" aria-label="Select">' + I.check + '</button>' : '') +
      '<span class="ct-av">' + esc(initials(e.name || e.mobile).toUpperCase()) + '</span>' +
      '<div class="oo-info"><div class="nm">' + (esc(e.name) || esc(e.mobile)) + '</div><div class="mb">' + esc(e.mobile) + '</div>' +
        '<div class="dt">' + when + '</div></div>' +
      '<button class="restore" data-restore="' + k + '">' + (ooTab === "blocked" ? "Unblock" : "Restore") + '</button>' +
    '</div>';
  }

  /* register the two tabs with the shell */
  M.registerTab("uicontacts", renderUIContacts);
  M.registerTab("optout", renderOptOut);
})();
