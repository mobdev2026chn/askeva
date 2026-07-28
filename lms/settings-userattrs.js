/* =========================================================
   AskEva — Settings · Manage User Attributes (part 3)
   Template variables ($name) with Name + Value:
     · searchable table (S.No / Name / Value / Actions)
     · Create / Edit modal (Name required, Value optional)
     · Delete with confirm
     · pagination + per-page selector
   Renders into #uaView. Self-contained.
   ========================================================= */
(function () {
  "use strict";
  var view = document.getElementById("uaView"); if (!view) return;
  var $ = function (s, r) { return (r || document).querySelector(s); };
  var $$ = function (s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); };
  function esc(s) { return String(s == null ? "" : s).replace(/[&<>"]/g, function (c) { return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]; }); }
  var toastT;
  function toast(m) { var t = document.getElementById("toast"); if (!t) return; t.textContent = m; t.style.opacity = "1"; t.style.transform = "translateX(-50%) translateY(0)"; clearTimeout(toastT); toastT = setTimeout(function () { t.style.opacity = "0"; t.style.transform = "translateX(-50%) translateY(20px)"; }, 1900); }

  var UK = "askeva.set.userattrs.v1";
  /* attribute names & values must read as template tokens: $something$ */
  function dollar(s) { s = String(s == null ? "" : s).trim().replace(/^\$+/, "").replace(/\$+$/, ""); return s ? "$" + s + "$" : ""; }
  function mk(n, v) { return { id: "u" + (mk._i = (mk._i || 0) + 1), name: n, value: v == null ? n : v }; }
  var SEED = [
    mk("$Description"), mk("$mailid", "$mail id"), mk("$agentname"), mk("$products"), mk("$orderid"),
    mk("$customername"), mk("$phone"), mk("$company"), mk("$appointmentdate"), mk("$appointmenttime"),
    mk("$department"), mk("$ticketid"), mk("$status"), mk("$priority"), mk("$amount"),
    mk("$invoiceno"), mk("$duedate"), mk("$address"), mk("$city"), mk("$pincode"),
    mk("$agentemail"), mk("$businessname"), mk("$website"), mk("$supportnumber"), mk("$greeting")
  ];
  var attrs; try { attrs = JSON.parse(localStorage.getItem(UK)) || null; } catch (e) { attrs = null; }
  if (!attrs || !attrs.length) attrs = SEED.slice();
  var _uaListeners = [];
  function _uaNotify() { _uaListeners.forEach(function (f) { try { f(attrs.slice()); } catch (e) {} }); try { document.dispatchEvent(new CustomEvent("userattrs:changed")); } catch (e) {} }
  function save() { try { localStorage.setItem(UK, JSON.stringify(attrs)); } catch (e) {} _uaNotify(); }

  var state = { q: "", page: 1, pp: 10 };

  function filtered() {
    var q = state.q.trim().toLowerCase();
    return attrs.filter(function (a) { return !q || (a.name + " " + a.value).toLowerCase().indexOf(q) > -1; });
  }

  function render() {
    var badge = document.getElementById("uaCountBadge"); if (badge) badge.textContent = attrs.length;
    var list = filtered();
    var pages = Math.max(1, Math.ceil(list.length / state.pp)); if (state.page > pages) state.page = pages;
    var start = (state.page - 1) * state.pp, slice = list.slice(start, start + state.pp);

    view.innerHTML =
      '<div class="ua-card">' +
        '<div class="ua-top"><div class="ua-search">' + IC.search + '<input id="uaQ" type="text" placeholder="Search by name or value…" value="' + esc(state.q) + '" autocomplete="off">' +
          (state.q ? '<button class="clr" id="uaClr">' + IC.x + '</button>' : '') + '</div>' +
          '<button class="ua-create" id="uaCreate">' + IC.plus + 'Create</button></div>' +
        '<div class="ua-colhd"><span class="c-sn">S.No</span><span class="c-nm">Name</span><span class="c-vl">Value</span><span class="c-ac">Actions</span></div>' +
        '<div class="ua-list">' + (slice.length ? slice.map(function (a, i) { return row(a, start + i + 1); }).join("") : '<div class="ua-empty">No attributes found.</div>') + '</div>' +
        foot(list.length, start, slice.length, pages) +
      '</div>';

    var qi = $("#uaQ", view); qi.addEventListener("input", function (e) { state.q = e.target.value; state.page = 1; var c = e.target.selectionStart; render(); var n = $("#uaQ", view); if (n) { n.focus(); try { n.setSelectionRange(c, c); } catch (x) {} } });
    var clr = $("#uaClr", view); if (clr) clr.addEventListener("click", function () { state.q = ""; state.page = 1; render(); });
    $("#uaCreate", view).addEventListener("click", function () { openForm(); });
    $$(".ua-edit", view).forEach(function (b) { b.addEventListener("click", function () { openForm(attrs.filter(function (x) { return x.id === b.getAttribute("data-id"); })[0]); }); });
    $$(".ua-del", view).forEach(function (b) { b.addEventListener("click", function () { var id = b.getAttribute("data-id"), a = attrs.filter(function (x) { return x.id === id; })[0]; confirmModal("Delete attribute?", "“" + a.name + "” will be permanently removed.", "Delete", function () { attrs = attrs.filter(function (x) { return x.id !== id; }); save(); render(); toast("Attribute deleted"); }); }); });
    $$(".ua-pg[data-pg]", view).forEach(function (b) { b.addEventListener("click", function () { var p = +b.getAttribute("data-pg"); if (p < 1 || p > pages || p === state.page) return; state.page = p; render(); }); });
    var ppb = $("#uaPP", view); if (ppb) ppb.addEventListener("click", function () { radioSheet("Rows per page", [[10, "10 / page"], [20, "20 / page"], [50, "50 / page"]], state.pp, function (v) { state.pp = +v; state.page = 1; render(); }); });
  }

  function row(a, sn) {
    return '<div class="ua-row"><span class="sn">' + sn + '</span>' +
      '<span class="nm">' + esc(dollar(a.name)) + '</span>' +
      '<span class="vl">' + esc(dollar(a.value || a.name) || "—") + '</span>' +
      '<span class="ac"><button class="ua-edit" data-id="' + a.id + '" aria-label="Edit">' + IC.edit + '</button>' +
        '<button class="ua-del" data-id="' + a.id + '" aria-label="Delete">' + IC.trash + '</button></span></div>';
  }
  function foot(total, start, count, pages) {
    if (!total) return "";
    var nums = ""; for (var p = 1; p <= pages; p++) nums += '<button class="ua-pg num' + (p === state.page ? " on" : "") + '" data-pg="' + p + '">' + p + '</button>';
    return '<div class="ua-foot"><div class="ua-pager"><button class="ua-pg arr" data-pg="' + (state.page - 1) + '"' + (state.page <= 1 ? " disabled" : "") + '>' + IC.chevL + '</button>' + nums +
      '<button class="ua-pg arr" data-pg="' + (state.page + 1) + '"' + (state.page >= pages ? " disabled" : "") + '>' + IC.chevR + '</button></div>' +
      '<button class="ua-pp" id="uaPP">' + state.pp + ' / page' + IC.chevD + '</button></div>';
  }

  function openForm(existing) {
    var edit = existing && existing.id;
    var html = '<div class="ax-grip"></div><div class="ax-sheet-head"><div class="ax-sheet-ttl">' + (edit ? "Edit User Attribute" : "Create User Attribute") + '</div></div>' +
      '<div class="ax-field"><label class="ax-label">Name<span class="nf-req">*</span>' + (edit ? '<span style="color:var(--ink-4);font-weight:600"> (fixed)</span>' : '') + '</label><div class="ax-control' + (edit ? ' locked' : '') + '">' + IC.tag + '<input id="uaName" type="text" placeholder="Name" value="' + esc(edit ? existing.name : "") + '"' + (edit ? ' readonly' : '') + '></div></div>' +
      '<div class="ax-field"><label class="ax-label">Value <span style="color:var(--ink-4);font-weight:600">(Optional)</span></label><div class="ax-control">' + IC.edit + '<input id="uaValue" type="text" placeholder="Value" value="' + esc(edit ? existing.value : "") + '"></div></div>' +
      '<div class="af-foot"><button class="cfg-btn ghost" id="uaCancel">Cancel</button><button class="cfg-btn primary" id="uaOk">OK</button></div>';
    var s = openSheet(html);
    var ni = $("#uaName", s); var vi = $("#uaValue", s);
    setTimeout(function () { try { (edit ? vi : ni).focus(); } catch (e) {} }, 80);
    $("#uaCancel", s).addEventListener("click", closeSheet);
    $("#uaOk", s).addEventListener("click", function () {
      var vl = (vi.value || "").trim();
      if (edit) { existing.value = dollar(vl || existing.name); save(); closeSheet(); render(); toast("Attribute updated"); return; }
      var nm = (ni.value || "").trim(); if (!nm) { toast("Enter a name"); return; }
      attrs.unshift({ id: "u" + Date.now().toString(36), name: dollar(nm), value: dollar(vl || nm) }); state.page = 1;
      save(); closeSheet(); render(); toast("Attribute created");
    });
  }

  /* sheet + modal primitives */
  var scrim, sheet, host = document.getElementById("app-settings");
  function ensureSheet() { if (scrim) return; scrim = document.createElement("div"); scrim.className = "ax-scrim ua-scrim"; sheet = document.createElement("div"); sheet.className = "ax-sheet ua-sheet"; scrim.addEventListener("click", closeSheet); host.appendChild(scrim); host.appendChild(sheet); }
  function openSheet(html) { ensureSheet(); sheet.innerHTML = html; sheet.scrollTop = 0; requestAnimationFrame(function () { scrim.classList.add("show"); sheet.classList.add("show"); }); return sheet; }
  function closeSheet() { if (sheet) { scrim.classList.remove("show"); sheet.classList.remove("show"); } }
  function radioSheet(title, opts, cur, onPick) {
    var html = '<div class="ax-grip"></div><div class="ax-sheet-head"><div class="ax-sheet-ttl">' + esc(title) + '</div></div><div class="ax-reasons">' +
      opts.map(function (o) { return '<button class="ax-reason' + (cur == o[0] ? " on" : "") + '" data-v="' + o[0] + '">' + esc(o[1]) + '</button>'; }).join("") + '</div>';
    var s = openSheet(html);
    $$(".ax-reason", s).forEach(function (b) { b.addEventListener("click", function () { closeSheet(); onPick(b.getAttribute("data-v")); }); });
  }
  var cScrim, onGo;
  function confirmModal(title, sub, go, cb) {
    if (!cScrim) { cScrim = document.createElement("div"); cScrim.className = "ax-modal-scrim ua-modal"; host.appendChild(cScrim); cScrim.addEventListener("click", function (e) { if (e.target === cScrim) cScrim.classList.remove("show"); }); }
    cScrim.innerHTML = '<div class="ax-modal"><div class="mic">' + WARN + '</div><div class="mt">' + esc(title) + '</div><div class="ms">' + esc(sub) + '</div><div class="mb"><button class="keep" id="uaKeep">Keep</button><button class="go" id="uaGo">' + esc(go) + '</button></div></div>';
    onGo = cb;
    $("#uaKeep", cScrim).addEventListener("click", function () { cScrim.classList.remove("show"); });
    $("#uaGo", cScrim).addEventListener("click", function () { cScrim.classList.remove("show"); if (onGo) onGo(); });
    requestAnimationFrame(function () { cScrim.classList.add("show"); });
  }

  var IC = {
    search: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><circle cx="11" cy="11" r="7"/><path d="M21 21l-4.3-4.3"/></svg>',
    x: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"><path d="M6 6l12 12M18 6 6 18"/></svg>',
    plus: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"><path d="M12 5v14M5 12h14"/></svg>',
    chevL: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m15 6-6 6 6 6"/></svg>',
    chevR: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m9 6 6 6-6 6"/></svg>',
    chevD: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m6 9 6 6 6-6"/></svg>',
    edit: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M11 4H5a2 2 0 0 0-2 2v13a2 2 0 0 0 2 2h13a2 2 0 0 0 2-2v-6"/><path d="M18.5 2.5a2.12 2.12 0 0 1 3 3L12 15l-4 1 1-4Z"/></svg>',
    trash: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 7h16M9 7V5a2 2 0 0 1 2-2h2a2 2 0 0 1 2 2v2M6 7l1 13a2 2 0 0 0 2 2h6a2 2 0 0 0 2-2l1-13"/></svg>',
    tag: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 12V5a2 2 0 0 1 2-2h7l9 9-9 9-9-9Z"/><circle cx="8" cy="8" r="1.3" fill="currentColor"/></svg>'
  };
  var WARN = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 9v4M12 17h.01"/><path d="M10.3 3.9 2 19a2 2 0 0 0 1.7 3h16.6a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0Z"/></svg>';

  render();
  window.__userattrs = { render: render };
  /* public API — Contacts custom-attribute fields read from here; edits reflect live.
     `key` is the attribute name without the leading $ (used as the display label). */
  window.AskEvaUserAttrs = {
    list: function () { return attrs.map(function (a) { return { id: a.id, name: a.name, key: String(a.name || "").replace(/^\$+/, "").replace(/\$+$/, ""), value: a.value }; }); },
    on: function (cb) { if (typeof cb === "function") _uaListeners.push(cb); }
  };
})();
