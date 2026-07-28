/* =========================================================
   AskEva — Contacts module (core)
   Owns #app-contacts: shell + sub-tabs + the Contacts (address
   book) tab — list, add/edit, groups, tags, custom attributes
   (from Settings → User Attributes), bulk ops, import/export.
   UI-Contacts + Opt-out tabs live in contacts2.js.
   ========================================================= */
(function () {
  "use strict";
  var pane = document.getElementById("app-contacts");
  if (!pane) return;
  var host = document.getElementById("screen") || pane;
  var $ = function (s, r) { return (r || document).querySelector(s); };
  var $$ = function (s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); };
  function esc(s) { return String(s == null ? "" : s).replace(/[&<>"]/g, function (c) { return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]; }); }
  function digits(s) { return String(s == null ? "" : s).replace(/\D/g, ""); }
  var toastT;
  function toast(m) { var t = document.getElementById("toast"); if (!t) return; t.textContent = m; t.style.opacity = "1"; t.style.transform = "translateX(-50%) translateY(0)"; clearTimeout(toastT); toastT = setTimeout(function () { t.style.opacity = "0"; t.style.transform = "translateX(-50%) translateY(20px)"; }, 2000); }
  function initials(n) { var p = String(n || "").trim().replace(/[^\p{L}\p{N} ]/gu, "").split(/\s+/).filter(Boolean); return ((p[0] || "")[0] || "") + ((p[1] || "")[0] || "") || (String(n || "?")[0] || "?"); }

  var I = {
    book: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 4h13a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2H4z"/><path d="M4 4v16"/><circle cx="11" cy="10" r="2.3"/><path d="M7.5 16c0-1.8 1.6-2.7 3.5-2.7s3.5.9 3.5 2.7"/></svg>',
    search: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><circle cx="11" cy="11" r="7"/><path d="M21 21l-4.3-4.3"/></svg>',
    chevD: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m6 9 6 6 6-6"/></svg>',
    plus: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.3" stroke-linecap="round"><path d="M12 5v14M5 12h14"/></svg>',
    trash: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 7h16M9 7V5a2 2 0 0 1 2-2h2a2 2 0 0 1 2 2v2M6 7l1 13a2 2 0 0 0 2 2h6a2 2 0 0 0 2-2l1-13"/></svg>',
    dl: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3v12M7 11l5 5 5-5M5 21h14"/></svg>',
    up: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 21V9M7 13l5-5 5 5M5 3h14"/></svg>',
    users: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="9" cy="8" r="3.2"/><path d="M3 20c0-3.2 2.7-5 6-5s6 1.8 6 5"/><path d="M16 5.2a3 3 0 0 1 0 5.6M17.5 15c2 .6 3.5 1.7 3.5 4"/></svg>',
    csv: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14 3v5h5"/><path d="M14 3H6a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><path d="M8 13h8M8 17h5"/></svg>',
    fileDown: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14 3v5h5"/><path d="M14 3H6a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><path d="M11.5 12v4.5"/><path d="m9.5 14.7 2 2 2-2"/></svg>',
    check: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><path d="M20 6 9 17l-5-5"/></svg>',
    x: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"><path d="M6 6l12 12M18 6 6 18"/></svg>',
    edit: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M11 4H5a2 2 0 0 0-2 2v13a2 2 0 0 0 2 2h13a2 2 0 0 0 2-2v-6"/><path d="M18.5 2.5a2.12 2.12 0 0 1 3 3L12 15l-4 1 1-4Z"/></svg>',
    pen: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M11 4H5a2 2 0 0 0-2 2v13a2 2 0 0 0 2 2h13a2 2 0 0 0 2-2v-6"/><path d="M18.5 2.5a2.12 2.12 0 0 1 3 3L12 15l-4 1 1-4Z"/></svg>',
    move: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M5 9 2 12l3 3M9 5l3-3 3 3M15 19l-3 3-3-3M19 9l3 3-3 3M2 12h20M12 2v20"/></svg>',
    copy: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="9" y="9" width="11" height="11" rx="2"/><path d="M5 15V5a2 2 0 0 1 2-2h10"/></svg>',
    dots: '<svg viewBox="0 0 24 24" fill="currentColor"><circle cx="5" cy="12" r="2"/><circle cx="12" cy="12" r="2"/><circle cx="19" cy="12" r="2"/></svg>',
    menu: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M4 7h16M4 12h16M4 17h16"/></svg>'
  };

  /* ---------- persisted stores ---------- */
  var GK = "askeva.contactgroups.v1", CK2 = "askeva.contacts.v1", OK = "askeva.optout.v1";
  function load(k, fb) { try { var v = JSON.parse(localStorage.getItem(k)); return v == null ? fb : v; } catch (e) { return fb; } }
  var SEED_GROUPS = ["Test", "test", "test5", "utility", "vk"].map(function (n, i) { return { id: "g" + i, name: n }; });
  function gByName(n) { for (var i = 0; i < GROUPS.length; i++) if (GROUPS[i].name.toLowerCase() === String(n).toLowerCase()) return GROUPS[i]; return null; }
  function gid(n) { var g = gByName(n); return g ? g.id : null; }
  var GROUPS = load(GK, null) || SEED_GROUPS.slice();
  function seedC(name, mobile, groups, tags, attrs) {
    return { id: "c" + Math.random().toString(36).slice(2, 8), name: name, cc: "+91", mobile: mobile,
      groups: (groups || []).map(gid).filter(Boolean), tags: tags || [], attrs: attrs || {}, createdAt: Date.now() };
  }
  var SEED_CONTACTS = [
    seedC("Muks", "917338855669", ["utility"], [], {}),
    seedC("Rizwan", "918129978459", ["test5"], [], {}),
    seedC("Madhan", "917904532349", ["Test"], ["premium"], { company: "Brightline Retail" }),
    seedC("Muhammed Shuraif", "918113801548", ["test", "utility"], ["Vbc"], { company: "Catalog Co" }),
    seedC("Call Me Vicky", "919786742563", ["test"], ["test"], {}),
    seedC("AMERIN", "918971264355", ["vk"], [], {}),
    seedC("BHAVANI", "919751811176", ["test"], [], { doctor: "Dr. Mehta" }),
    seedC("Priya Nair", "919812345670", ["utility"], ["premium"], { company: "Catalog Co", doctor: "Dr. Rao" })
  ];
  SEED_CONTACTS.forEach(function (c, i) { c.createdAt = 1000000 + (SEED_CONTACTS.length - i); }); // stable seed order, all below real timestamps
  var CONTACTS = load(CK2, null) || SEED_CONTACTS.slice();
  function byNewest(a, b) { return (b.createdAt || 0) - (a.createdAt || 0); }
  var OPTOUT = load(OK, null) || { unsubscribed: [], blocked: [{ name: "Mukhil Lawrence", mobile: "917338855669", ts: Date.now() - 3600000 }] };

  function saveGroups() { try { localStorage.setItem(GK, JSON.stringify(GROUPS)); } catch (e) {} }
  function saveContacts() { try { localStorage.setItem(CK2, JSON.stringify(CONTACTS)); } catch (e) {} }
  function saveOptOut() { try { localStorage.setItem(OK, JSON.stringify(OPTOUT)); } catch (e) {} }
  function saveAll() { saveGroups(); saveContacts(); saveOptOut(); }

  window.AskEvaContactGroups = GROUPS;
  window.AskEvaContacts = CONTACTS;
  window.AskEvaOptOut = OPTOUT;

  function groupName(id) { var g = GROUPS.filter(function (x) { return x.id === id; })[0]; return g ? g.name : ""; }
  function groupCount(id) { return CONTACTS.filter(function (c) { return (c.groups || []).indexOf(id) > -1; }).length; }
  function contactByMobile(m) { m = digits(m); if (m.length < 6) return null; for (var i = 0; i < CONTACTS.length; i++) if (digits(CONTACTS[i].mobile).slice(-10) === m.slice(-10)) return CONTACTS[i]; return null; }
  function allTags() { var s = {}, out = []; CONTACTS.forEach(function (c) { (c.tags || []).forEach(function (t) { if (!s[t.toLowerCase()]) { s[t.toLowerCase()] = 1; out.push(t); } }); }); ["premium", "test", "Vbc", "vip"].forEach(function (t) { if (!s[t.toLowerCase()]) { s[t.toLowerCase()] = 1; out.push(t); } }); return out; }
  function userAttrKeys() {
    if (window.AskEvaUserAttrs && window.AskEvaUserAttrs.list) {
      return window.AskEvaUserAttrs.list().map(function (a) { return a.key; }).filter(function (k, i, a) { return k && a.indexOf(k) === i; });
    }
    return ["company", "doctor", "department", "Name", "ticketid"];
  }

  /* ---------- state ---------- */
  var state = { tab: "contacts", filter: "all", q: "", selMode: false, selected: {} };
  var TAB = {};   // tab renderers registered by contacts2.js (uicontacts, optout)

  /* ---------- shell ---------- */
  function render() {
    pane.innerHTML =
      '<div class="lp-head" style="padding-bottom:24px;">' +
        '<div class="lp-topbar">' +
          '<button class="lp-iconbtn" aria-label="Menu" id="ctMenuBtn">' + I.menu + '</button>' +
          '<div class="lp-title" style="flex:1;text-align:center;">Contacts</div>' +
          '<span class="lp-iconbtn" style="background:transparent;border:none;"></span>' +
        '</div>' +
      '</div>' +
      '<div class="lp-sheet">' +
        '<div class="ct-tabs">' +
          tabBtn("contacts", "Contacts") + tabBtn("uicontacts", "UI-Contacts") + tabBtn("optout", "Opt-out") +
        '</div>' +
        '<div class="ct-body" id="ctBody"></div>' +
      '</div>';
    var mb = $("#ctMenuBtn", pane); if (mb) mb.addEventListener("click", function () { var t = document.getElementById("sideHamb") || document.querySelector('[aria-label="Open menu"]'); if (window.__openSideNav) window.__openSideNav(); else { var sb = document.getElementById("sidebar"), sc = document.getElementById("sideScrim"); if (sb) sb.classList.add("open"); if (sc) sc.classList.add("show"); } });
    $$(".ct-tab", pane).forEach(function (b) { b.addEventListener("click", function () { state.tab = b.getAttribute("data-t"); exitSel(); render(); }); });
    var body = $("#ctBody", pane);
    if (state.tab === "contacts") renderContactsTab(body);
    else if (TAB[state.tab]) TAB[state.tab](body);
    else body.innerHTML = '<div class="ct-empty">' + I.book + '<div class="t">Coming up…</div></div>';
  }
  function tabBtn(id, label) { return '<button class="ct-tab' + (state.tab === id ? " on" : "") + '" data-t="' + id + '">' + label + '</button>'; }

  /* ---------- overlays (scrim + sheet + menu) ---------- */
  var scrim = document.createElement("div"); scrim.className = "ct-scrim";
  var sheet = document.createElement("div"); sheet.className = "ct-sheet";
  host.appendChild(scrim); host.appendChild(sheet);
  scrim.addEventListener("click", closeSheet);
  function openSheet(html) { sheet.innerHTML = '<div class="ct-grip"></div>' + html; sheet.scrollTop = 0; requestAnimationFrame(function () { scrim.classList.add("show"); sheet.classList.add("show"); }); return sheet; }
  function closeSheet() { scrim.classList.remove("show"); sheet.classList.remove("show"); }

  var menuScrim = document.createElement("div"); menuScrim.className = "ct-menuscrim"; menuScrim.style.display = "none";
  var menu = document.createElement("div"); menu.className = "ct-menu";
  host.appendChild(menuScrim); host.appendChild(menu);
  menuScrim.addEventListener("click", hideMenu);
  function hideMenu() { menu.classList.remove("show"); menuScrim.style.display = "none"; }
  function showMenuAt(btn, html) {
    menu.innerHTML = html;
    menuScrim.style.display = "block";
    var hr = host.getBoundingClientRect(), br = btn.getBoundingClientRect();
    // #screen is CSS-scaled (device frame). getBoundingClientRect returns scaled
    // VIEWPORT px, but menu.style.left/top are LOCAL (unscaled) px — so convert
    // every viewport delta by the scale factor or the menu lands in random spots.
    var sc = host.offsetWidth ? (hr.width / host.offsetWidth) : 1; if (!sc) sc = 1;
    menu.style.visibility = "hidden"; menu.classList.add("show");
    var mw = menu.offsetWidth, mh = menu.offsetHeight;
    var hLocal = hr.height / sc;
    var left = (br.right - hr.left) / sc - mw; if (left < 8) left = 8;
    var top = (br.bottom - hr.top) / sc + 6; if (top + mh > hLocal - 8) top = (br.top - hr.top) / sc - mh - 6;
    menu.style.left = left + "px"; menu.style.top = Math.max(8, top) + "px"; menu.style.visibility = "";
  }

  var modalScrim = document.createElement("div"); modalScrim.className = "ct-modal-scrim"; host.appendChild(modalScrim);
  modalScrim.addEventListener("click", function (e) { if (e.target === modalScrim) modalScrim.classList.remove("show"); });
  function promptModal(title, value, max, onOk) {
    modalScrim.innerHTML = '<div class="ct-modal"><div class="mt">' + esc(title) + '</div>' +
      '<input class="ct-input" id="ctPInput" maxlength="' + (max || 30) + '" value="' + esc(value || "") + '">' +
      '<div class="cc"><span id="ctPCnt">' + (value || "").length + '</span> / ' + (max || 30) + '</div>' +
      '<div class="mb"><button class="ct-btn ghost" id="ctPCancel">Cancel</button><button class="ct-btn primary" id="ctPOk" style="flex:0 0 auto;padding:12px 22px">OK</button></div></div>';
    modalScrim.classList.add("show");
    var inp = $("#ctPInput", modalScrim), cnt = $("#ctPCnt", modalScrim);
    setTimeout(function () { inp.focus(); }, 80);
    inp.addEventListener("input", function () { cnt.textContent = inp.value.length; });
    $("#ctPCancel", modalScrim).addEventListener("click", function () { modalScrim.classList.remove("show"); });
    $("#ctPOk", modalScrim).addEventListener("click", function () { var v = inp.value.trim(); if (!v) { toast("Enter a name"); return; } modalScrim.classList.remove("show"); onOk(v); });
  }
  function confirmModal(title, sub, go, onOk) {
    modalScrim.innerHTML = '<div class="ct-modal"><div class="mt">' + esc(title) + '</div>' +
      '<div style="margin:2px 0 16px;font-size:13px;font-weight:600;color:var(--ink-2,#4d5d52);line-height:1.5">' + esc(sub || "") + '</div>' +
      '<div class="mb"><button class="ct-btn ghost" id="ctCCancel">Cancel</button><button class="ct-btn primary" id="ctCOk" style="flex:0 0 auto;padding:12px 22px;background:#ef5350;box-shadow:none">' + esc(go || "Delete") + '</button></div></div>';
    modalScrim.classList.add("show");
    $("#ctCCancel", modalScrim).addEventListener("click", function () { modalScrim.classList.remove("show"); });
    $("#ctCOk", modalScrim).addEventListener("click", function () { modalScrim.classList.remove("show"); onOk(); });
  }

  /* =========================================================
     CONTACTS TAB
     ========================================================= */
  function matchContact(c) {
    var q = state.q.trim().toLowerCase();
    if (state.filter === "groups" && !(c.groups || []).length) return false;
    if (state.filter === "tags" && !(c.tags || []).length) return false;
    if (!q) return true;
    if (state.filter === "number") return digits(c.mobile).indexOf(digits(q)) > -1;
    if (state.filter === "groups") return (c.groups || []).map(groupName).join(" ").toLowerCase().indexOf(q) > -1;
    if (state.filter === "tags") return (c.tags || []).join(" ").toLowerCase().indexOf(q) > -1;
    var hay = (c.name + " " + c.mobile + " " + (c.groups || []).map(groupName).join(" ") + " " + (c.tags || []).join(" ")).toLowerCase();
    return hay.indexOf(q) > -1;
  }
  function selCount() { return Object.keys(state.selected).filter(function (k) { return state.selected[k]; }).length; }
  function exitSel() { state.selMode = false; state.selected = {}; }

  function renderContactsTab(body) {
    var list = CONTACTS.filter(matchContact).slice().sort(byNewest);
    body.innerHTML =
      '<div class="ct-toolbar">' +
        '<div class="ct-filter" id="ctFilterWrap">' +
          '<select id="ctFilter" class="js-uxdd-skip" hidden>' +
            ["all|All", "groups|Groups", "tags|Tags", "number|Number"].map(function (o) { var p = o.split("|"); return '<option value="' + p[0] + '"' + (state.filter === p[0] ? " selected" : "") + '>' + p[1] + '</option>'; }).join("") +
          '</select>' +
          '<button type="button" class="ct-filterbtn" id="ctFilterBtn"><span class="lbl">' +
            (({ all: "All", groups: "Groups", tags: "Tags", number: "Number" })[state.filter] || "All") + '</span>' + I.chevD + '</button>' +
          '<div class="ct-filtermenu" id="ctFilterMenu" hidden>' +
            ["all|All", "groups|Groups", "tags|Tags", "number|Number"].map(function (o) { var p = o.split("|"); return '<button type="button" class="ct-filteropt' + (state.filter === p[0] ? " on" : "") + '" data-v="' + p[0] + '">' + p[1] + '</button>'; }).join("") +
          '</div>' +
        '</div>' +
        '<div class="ct-search">' + I.search + '<input id="ctSearch" type="text" placeholder="Search…" value="' + esc(state.q) + '"></div>' +
      '</div>' +
      '<div class="ct-actions">' +
        '<button class="ct-actchip primary" data-a="add"><span class="ic">' + I.plus + '</span>Add Contact</button>' +
        '<button class="ct-actchip" data-a="groups"><span class="ic">' + I.users + '</span>Manage Groups</button>' +
        '<button class="ct-actchip" data-a="import"><span class="ic">' + I.dl + '</span>Import</button>' +
        '<button class="ct-actchip" data-a="export"><span class="ic">' + I.up + '</span>Export</button>' +
        '<button class="ct-actchip" data-a="sample"><span class="ic">' + I.fileDown + '</span>Sample CSV</button>' +
      '</div>' +
      '<div class="ct-count"><span class="ct-countn"><b>' + list.length + '</b> ' + (list.length === 1 ? "contact" : "contacts") + (CONTACTS.length !== list.length ? " · " + CONTACTS.length + " total" : "") + '</span>' +
        '<span style="display:flex;gap:8px;flex:0 0 auto">' +
          (state.selMode ? '<button class="ct-selecttog on" data-a="selall"><span>' + (list.length && list.every(function (c) { return state.selected[c.id]; }) ? "Deselect all" : "Select all") + '</span></button>' : '') +
          '<button class="ct-selecttog' + (state.selMode ? " on" : "") + '" data-a="select">' + (state.selMode ? I.x : I.check) + '<span>' + (state.selMode ? "Cancel" : "Select") + '</span></button>' +
        '</span>' +
      '</div>' +
      '<div class="ct-list" id="ctList">' + (list.length ? list.map(cardHTML).join("") : emptyHTML()) + '</div>' +
      '<div class="ct-selbar" id="ctSelbar"><span class="n" id="ctSelN">0 selected</span>' +
        '<button class="ct-selbtn green" data-s="group">' + I.users + 'Add to Group</button>' +
        '<button class="ct-selbtn" data-s="export">' + I.up + '</button>' +
        '<button class="ct-selbtn red" data-s="delete">' + I.trash + '</button>' +
        '<button class="ct-selbtn icon" data-s="cancel">' + I.x + '</button>' +
      '</div>';
    wireContactsTab(body);
    syncSelbar();
  }
  function emptyHTML() {
    return '<div class="ct-empty">' + I.book + '<div class="t">' + (state.q || state.filter !== "all" ? "No matches" : "No contacts yet") + '</div>' +
      '<div class="s">' + (state.q || state.filter !== "all" ? "Try a different search or filter." : "Add a contact or import a CSV to build your address book. Compose pulls its audience from here.") + '</div></div>';
  }
  function cardHTML(c) {
    var sel = !!state.selected[c.id];
    var groups = (c.groups || []).map(function (id) { return '<span class="ct-chip">' + esc(groupName(id)) + '</span>'; }).join("");
    var tags = (c.tags || []).map(function (t) { return '<span class="ct-tag">' + esc(t) + '</span>'; }).join("");
    var attrs = Object.keys(c.attrs || {}).filter(function (k) { return c.attrs[k]; }).slice(0, 3)
      .map(function (k) { return '<span class="ct-attr"><b>' + esc(k) + ':</b> ' + esc(c.attrs[k]) + '</span>'; }).join("");
    return '<div class="ct-card' + (sel ? " sel" : "") + '" data-id="' + c.id + '">' +
      (state.selMode ? '<button class="ct-check" data-check aria-label="Select"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><path d="m5 12 4 4 10-11"/></svg></button>' : '') +
      '<span class="ct-av">' + esc(initials(c.name).toUpperCase()) + '</span>' +
      '<div class="ct-info">' +
        '<div class="ct-nm">' + esc(c.name) + '</div>' +
        '<div class="ct-mob">' + esc((c.cc ? c.cc + " " : "") + c.mobile) + '</div>' +
        (groups || tags ? '<div class="ct-chips">' + groups + tags + '</div>' : '') +
        (attrs ? '<div class="ct-attrs">' + attrs + '</div>' : '') +
      '</div>' +
      '<button class="ct-rowmenu" data-menu aria-label="Actions">' + I.pen + '</button>' +
    '</div>';
  }

  function wireContactsTab(body) {
    var fl = $("#ctFilter", body); if (fl) fl.addEventListener("change", function () { state.filter = fl.value; render(); });
    var fbtn = $("#ctFilterBtn", body), fmenu = $("#ctFilterMenu", body);
    if (fbtn && fmenu) {
      fbtn.addEventListener("click", function (e) {
        e.stopPropagation();
        if (fmenu.hidden) {
          fmenu.hidden = false; fbtn.classList.add("open");
          var off = function () { fmenu.hidden = true; fbtn.classList.remove("open"); document.removeEventListener("click", off); };
          setTimeout(function () { document.addEventListener("click", off); }, 0);
        } else { fmenu.hidden = true; fbtn.classList.remove("open"); }
      });
      $$(".ct-filteropt", fmenu).forEach(function (b) { b.addEventListener("click", function () { state.filter = b.getAttribute("data-v"); render(); }); });
    }
    var se = $("#ctSearch", body); if (se) se.addEventListener("input", function () { state.q = se.value; var l = $("#ctList", body); var arr = CONTACTS.filter(matchContact).slice().sort(byNewest); l.innerHTML = arr.length ? arr.map(cardHTML).join("") : emptyHTML(); var cn = $(".ct-countn", body); if (cn) cn.innerHTML = '<b>' + arr.length + '</b> ' + (arr.length === 1 ? "contact" : "contacts") + (CONTACTS.length !== arr.length ? " · " + CONTACTS.length + " total" : ""); bindCards(body); });
    $$(".ct-actchip", body).forEach(function (b) { b.addEventListener("click", function () { actAction(b.getAttribute("data-a")); }); });
    $$(".ct-selecttog", body).forEach(function (b) { b.addEventListener("click", function () { actAction(b.getAttribute("data-a")); }); });
    $$(".ct-selbtn", body).forEach(function (b) { b.addEventListener("click", function () { selAction(b.getAttribute("data-s")); }); });
    bindCards(body);
    // Pin the bulk-select bar to the non-scrolling pane so it stays at the
    // bottom of the screen instead of scrolling away with the list.
    if (pane) {
      var oldBar = pane.querySelector(":scope > .ct-selbar"); if (oldBar) oldBar.remove();
      var newBar = $("#ctSelbar", body); if (newBar) pane.appendChild(newBar);
    }
  }
  function bindCards(body) {
    $$(".ct-card", body).forEach(function (card) {
      var id = card.getAttribute("data-id");
      var chk = $("[data-check]", card); if (chk) chk.addEventListener("click", function (e) { e.stopPropagation(); toggleSel(id, card); });
      var mn = $("[data-menu]", card); if (mn) mn.addEventListener("click", function (e) { e.stopPropagation(); openRowMenu(mn, id); });
      card.addEventListener("click", function () { if (state.selMode) toggleSel(id, card); else openContactForm(byId(id)); });
    });
  }
  function byId(id) { return CONTACTS.filter(function (c) { return c.id === id; })[0]; }
  function toggleSel(id, card) { state.selected[id] = !state.selected[id]; if (card) card.classList.toggle("sel", !!state.selected[id]); syncSelbar(); }
  function syncSelbar() {
    var bar = $("#ctSelbar", pane); if (!bar) return;
    var n = selCount();
    bar.classList.toggle("show", state.selMode && n > 0 || state.selMode);
    var nn = $("#ctSelN", pane); if (nn) nn.textContent = n + " selected";
  }

  function actAction(a) {
    if (a === "add") return openContactForm(null);
    if (a === "groups") return openManageGroups();
    if (a === "import") return openImportModal();
    if (a === "export") return exportCSV(CONTACTS, "contacts");
    if (a === "sample") return sampleCSV();
    if (a === "select") { state.selMode = !state.selMode; if (!state.selMode) state.selected = {}; render(); }
    if (a === "selall") { var l = CONTACTS.filter(matchContact); var all = l.length && l.every(function (c) { return state.selected[c.id]; }); l.forEach(function (c) { state.selected[c.id] = !all; }); render(); }
  }
  function selAction(s) {
    var ids = Object.keys(state.selected).filter(function (k) { return state.selected[k]; });
    if (s === "cancel") { exitSel(); render(); return; }
    if (!ids.length) { toast("Select contacts first"); return; }
    if (s === "delete") { confirmModal("Delete " + ids.length + " contact" + (ids.length > 1 ? "s" : "") + "?", "The selected contact" + (ids.length > 1 ? "s" : "") + " will be permanently removed.", "Delete", function () { CONTACTS = CONTACTS.filter(function (c) { return ids.indexOf(c.id) < 0; }); window.AskEvaContacts = CONTACTS; saveContacts(); toast(ids.length + " contact" + (ids.length > 1 ? "s" : "") + " deleted"); exitSel(); render(); }); return; }
    if (s === "export") { exportCSV(CONTACTS.filter(function (c) { return ids.indexOf(c.id) > -1; }), "contacts-selected"); return; }
    if (s === "group") { openAddToGroups(ids); return; }
  }

  /* ---------- row action menu ---------- */
  function openRowMenu(btn, id) {
    var c = byId(id); if (!c) return;
    showMenuAt(btn,
      '<button class="ct-mitem" data-m="edit">' + I.edit + 'Edit</button>' +
      '<button class="ct-mitem" data-m="move">' + I.move + 'Move</button>' +
      '<button class="ct-mitem" data-m="copy">' + I.copy + 'Copy</button>' +
      '<button class="ct-mitem" data-m="export">' + I.up + 'Export</button>' +
      '<div class="ct-mdiv"></div>' +
      '<button class="ct-mitem del" data-m="delete">' + I.trash + 'Delete</button>');
    $$(".ct-mitem", menu).forEach(function (b) { b.addEventListener("click", function () {
      var m = b.getAttribute("data-m"); hideMenu();
      if (m === "edit") openContactForm(c);
      else if (m === "move") openAddToGroups([id], true);
      else if (m === "copy") openAddToGroups([id], false);
      else if (m === "export") exportCSV([c], "contact-" + digits(c.mobile));
      else if (m === "delete") { confirmModal("Delete contact?", "\u201C" + (c.name || "This contact") + "\u201D will be permanently removed.", "Delete", function () { CONTACTS = CONTACTS.filter(function (x) { return x.id !== id; }); window.AskEvaContacts = CONTACTS; saveContacts(); toast(c.name + " deleted"); render(); }); }
    }); });
  }

  /* ---------- Add / Edit contact ---------- */
  var formCtx = null;   // {existing, draft}
  function openContactForm(existing) {
    var c = existing || {};
    formCtx = { existing: existing, draft: {
      name: c.name || "", cc: c.cc || "+91", mobile: c.mobile || "",
      groups: (c.groups || []).slice(), tags: (c.tags || []).slice(), attrs: Object.assign({}, c.attrs || {})
    } };
    renderForm();
  }
  function renderForm() {
    var ex = formCtx.existing, d = formCtx.draft;
    var groupChips = GROUPS.map(function (g) { return '<button class="ct-pickchip' + (d.groups.indexOf(g.id) > -1 ? " on" : "") + '" data-g="' + g.id + '"><span class="dot"></span>' + esc(g.name) + '</button>'; }).join("");
    var tagChips = allTags().map(function (t) { return '<button class="ct-pickchip' + (d.tags.indexOf(t) > -1 ? " on" : "") + '" data-tag="' + esc(t) + '"><span class="dot"></span>' + esc(t) + '</button>'; }).join("") +
      '<button class="ct-pickchip ct-pickadd" data-newtag>' + I.plus + 'New tag</button>';
    var attrFields = userAttrKeys().map(function (k) {
      return '<div class="ct-field"><label>' + esc(k) + '</label><input class="ct-input" data-attr="' + esc(k) + '" value="' + esc(d.attrs[k] || "") + '" placeholder="' + esc(k) + '"></div>';
    }).join("");
    var ccOpts = (window.AskEvaCCOptions ? window.AskEvaCCOptions(d.cc, { format: function (n, c) { return c + "  " + n; } }) : ["+91", "+1", "+44", "+971", "+61", "+65"].map(function (x) { return '<option' + (d.cc === x ? " selected" : "") + '>' + x + '</option>'; }).join(""));
    openSheet(
      '<div class="ct-shead"><span class="si">' + I.book + '</span><span class="tt">' + (ex ? "Edit Contact" : "Add Contact") + '</span><button class="x" data-x>' + I.x + '</button></div>' +
      '<div class="ct-field"><label>Group</label><div class="ct-pick" id="ctFGroups">' + groupChips + '<button class="ct-pickchip ct-pickadd" data-newgroup>' + I.plus + 'New group</button></div></div>' +
      '<div class="ct-two">' +
        '<div class="ct-field"><label>Country Code <span class="req">*</span></label><select class="ct-select" id="ctFcc">' + ccOpts + '</select></div>' +
        '<div class="ct-field"><label>Mobile Number <span class="req">*</span></label><input class="ct-input" id="ctFmob" inputmode="numeric" placeholder="Mobile number" value="' + esc(d.mobile) + '"></div>' +
      '</div>' +
      '<div class="ct-field"><label>Contact Name <span class="req">*</span></label><input class="ct-input" id="ctFname" placeholder="Contact Name" value="' + esc(d.name) + '"></div>' +
      '<div class="ct-field"><label>Tags</label><div class="ct-pick" id="ctFTags">' + tagChips + '</div></div>' +
      '<div class="ct-sublbl">Custom Attributes</div>' + (attrFields || '<div class="ct-attr" style="margin-bottom:14px">No attributes yet — add them in Settings → User Attributes.</div>') +
      '<div class="ct-foot"><button class="ct-btn ghost" data-x>Cancel</button><button class="ct-btn primary" data-save>' + (ex ? "Save changes" : "Submit") + '</button></div>'
    );
    $$("[data-x]", sheet).forEach(function (b) { b.addEventListener("click", function () { formCtx = null; closeSheet(); }); });
    syncDraftFromForm.bind = sheet;
    var ccSel = $("#ctFcc", sheet); if (ccSel) { ccSel.value = d.cc; ccSel.addEventListener("change", function () { d.cc = this.value; }); }
    $("#ctFmob", sheet).addEventListener("input", function () { d.mobile = digits(this.value); });
    $("#ctFname", sheet).addEventListener("input", function () { d.name = this.value; });
    $$("[data-attr]", sheet).forEach(function (inp) { inp.addEventListener("input", function () { d.attrs[inp.getAttribute("data-attr")] = inp.value; }); });
    $$("#ctFGroups [data-g]", sheet).forEach(function (b) { b.addEventListener("click", function () { var id = b.getAttribute("data-g"); var i = d.groups.indexOf(id); if (i > -1) d.groups.splice(i, 1); else d.groups.push(id); b.classList.toggle("on"); }); });
    $("[data-newgroup]", sheet).addEventListener("click", function () { promptModal("New group", "", 30, function (v) { var g = createGroup(v); if (g) { d.groups.push(g.id); renderForm(); } }); });
    $$("#ctFTags [data-tag]", sheet).forEach(function (b) { b.addEventListener("click", function () { var t = b.getAttribute("data-tag"); var i = d.tags.indexOf(t); if (i > -1) d.tags.splice(i, 1); else d.tags.push(t); b.classList.toggle("on"); }); });
    $("[data-newtag]", sheet).addEventListener("click", function () { promptModal("New tag", "", 24, function (v) { if (d.tags.indexOf(v) < 0) d.tags.push(v); renderForm(); }); });
    $("[data-save]", sheet).addEventListener("click", saveForm);
  }
  function syncDraftFromForm() {}
  function saveForm() {
    var ex = formCtx.existing, d = formCtx.draft;
    if (!digits(d.mobile) || digits(d.mobile).length < 8) { toast("Enter a valid mobile number"); return; }
    if (!d.name.trim()) { toast("Enter a contact name"); return; }
    var clean = { name: d.name.trim(), cc: d.cc, mobile: digits(d.mobile), groups: d.groups.slice(), tags: d.tags.slice(), attrs: d.attrs };
    if (ex) { Object.assign(ex, clean); toast("Contact updated"); }
    else {
      var dupe = contactByMobile(clean.mobile);
      if (dupe) { Object.assign(dupe, clean); toast("Updated existing contact"); }
      else { CONTACTS.unshift(Object.assign({ id: "c" + Date.now().toString(36), createdAt: Date.now() }, clean)); toast("Contact added"); }
    }
    window.AskEvaContacts = CONTACTS; saveContacts(); formCtx = null; closeSheet(); render();
  }

  /* ---------- groups: create / manage / add-to ---------- */
  function createGroup(name) {
    name = (name || "").trim(); if (!name) return null;
    if (gByName(name)) { toast("Group already exists"); return gByName(name); }
    var g = { id: "g" + Date.now().toString(36), name: name }; GROUPS.push(g); window.AskEvaContactGroups = GROUPS; saveGroups(); return g;
  }
  function openManageGroups() {
    function rows() {
      return GROUPS.length ? GROUPS.map(function (g) {
        return '<div class="ct-grouprow" data-gid="' + g.id + '"><div style="flex:1;min-width:0"><div class="gn">' + esc(g.name) + '</div><div class="gc">' + groupCount(g.id) + ' contact' + (groupCount(g.id) === 1 ? "" : "s") + '</div></div>' +
          '<button class="ct-gact" data-ed aria-label="Rename">' + I.pen + '</button>' +
          '<button class="ct-gact del" data-del aria-label="Delete">' + I.trash + '</button></div>';
      }).join("") : '<div class="ct-attr" style="padding:14px 0">No groups yet.</div>';
    }
    openSheet('<div class="ct-shead"><span class="si">' + I.users + '</span><span class="tt">Manage Groups</span><button class="x" data-x>' + I.x + '</button></div>' +
      '<button class="ct-btn primary" id="ctNewGroup" style="margin-bottom:14px">' + I.plus + ' Create group</button>' +
      '<div id="ctGroupList">' + rows() + '</div>');
    function refresh() { $("#ctGroupList", sheet).innerHTML = rows(); wire(); }
    function wire() {
      $$(".ct-grouprow", sheet).forEach(function (r) {
        var id = r.getAttribute("data-gid"), g = GROUPS.filter(function (x) { return x.id === id; })[0];
        $("[data-ed]", r).addEventListener("click", function () { promptModal("Edit Group", g.name, 30, function (v) { g.name = v; saveGroups(); refresh(); toast("Group updated"); }); });
        $("[data-del]", r).addEventListener("click", function () { confirmModal("Delete group?", "\u201C" + (g ? g.name : "This group") + "\u201D will be removed. Contacts stay, but lose this group tag.", "Delete", function () { GROUPS = GROUPS.filter(function (x) { return x.id !== id; }); window.AskEvaContactGroups = GROUPS; CONTACTS.forEach(function (c) { c.groups = (c.groups || []).filter(function (x) { return x !== id; }); }); saveGroups(); saveContacts(); refresh(); toast("Group deleted"); }); });
      });
    }
    $("[data-x]", sheet).addEventListener("click", function () { closeSheet(); render(); });
    $("#ctNewGroup", sheet).addEventListener("click", function () { promptModal("New group", "", 30, function (v) { createGroup(v); refresh(); }); });
    wire();
  }
  function openAddToGroups(ids, isMove) {
    var chosen = {};
    openSheet('<div class="ct-shead"><span class="si">' + I.users + '</span><span class="tt">' + (isMove ? "Move to group" : "Add to group") + '</span><button class="x" data-x>' + I.x + '</button></div>' +
      '<div class="ct-attr" style="margin-bottom:12px">' + ids.length + ' contact' + (ids.length > 1 ? "s" : "") + ' selected</div>' +
      '<div class="ct-pick" id="ctATG">' + GROUPS.map(function (g) { return '<button class="ct-pickchip" data-g="' + g.id + '"><span class="dot"></span>' + esc(g.name) + '</button>'; }).join("") +
        '<button class="ct-pickchip ct-pickadd" data-newgroup>' + I.plus + 'New group</button></div>' +
      '<div class="ct-foot"><button class="ct-btn ghost" data-x>Cancel</button><button class="ct-btn primary" data-apply>' + (isMove ? "Move" : "Add") + '</button></div>');
    $$("[data-x]", sheet).forEach(function (b) { b.addEventListener("click", closeSheet); });
    function bindChips() { $$("#ctATG [data-g]", sheet).forEach(function (b) { b.addEventListener("click", function () { var id = b.getAttribute("data-g"); chosen[id] = !chosen[id]; b.classList.toggle("on"); }); }); }
    $("[data-newgroup]", sheet).addEventListener("click", function () { promptModal("New group", "", 30, function (v) { var g = createGroup(v); if (g) { $("#ctATG", sheet).insertAdjacentHTML("beforeend", '<button class="ct-pickchip on" data-g="' + g.id + '"><span class="dot"></span>' + esc(g.name) + '</button>'); chosen[g.id] = true; bindChips(); } }); });
    bindChips();
    $("[data-apply]", sheet).addEventListener("click", function () {
      var gids = Object.keys(chosen).filter(function (k) { return chosen[k]; });
      if (!gids.length) { toast("Pick a group"); return; }
      ids.forEach(function (cid) { var c = byId(cid); if (!c) return; if (isMove) c.groups = gids.slice(); else gids.forEach(function (g) { if ((c.groups || []).indexOf(g) < 0) c.groups.push(g); }); });
      saveContacts(); closeSheet(); exitSel(); render();
      toast((isMove ? "Moved " : "Added ") + ids.length + " contact" + (ids.length > 1 ? "s" : ""));
    });
  }

  /* ---------- CSV import / export / sample ---------- */
  function exportCSV(rows, fname) {
    var keys = userAttrKeys();
    var head = ["Name", "CountryCode", "Mobile", "Groups", "Tags"].concat(keys);
    var lines = [head.join(",")];
    rows.forEach(function (c) {
      var row = [c.name, c.cc || "", c.mobile, (c.groups || []).map(groupName).join("|"), (c.tags || []).join("|")]
        .concat(keys.map(function (k) { return (c.attrs && c.attrs[k]) || ""; }));
      lines.push(row.map(csvCell).join(","));
    });
    download((fname || "contacts") + ".csv", lines.join("\n"));
    toast("Exported " + rows.length + " contact" + (rows.length === 1 ? "" : "s"));
  }
  function csvCell(v) { v = String(v == null ? "" : v); return /[",\n]/.test(v) ? '"' + v.replace(/"/g, '""') + '"' : v; }
  function sampleCSV() {
    var keys = userAttrKeys();
    download("contacts-sample.csv", ["Name,CountryCode,Mobile,Groups,Tags" + (keys.length ? "," + keys.join(",") : ""),
      "Asha Verma,+91,919000000001,utility|Test,premium" + (keys.length ? "," + keys.map(function () { return ""; }).join(",") : ""),
      "Ravi Kumar,+91,919000000002,test,," + (keys.length ? keys.map(function () { return ""; }).join(",") : "")].join("\n"));
    toast("Sample CSV downloaded");
  }
  function download(name, text) {
    try { var blob = new Blob([text], { type: "text/csv" }); var url = URL.createObjectURL(blob); var a = document.createElement("a"); a.href = url; a.download = name; document.body.appendChild(a); a.click(); setTimeout(function () { a.remove(); URL.revokeObjectURL(url); }, 200); } catch (e) { toast("Download not supported here"); }
  }
  function importCSV() {
    var inp = document.createElement("input"); inp.type = "file"; inp.accept = ".csv,text/csv"; inp.style.display = "none"; document.body.appendChild(inp);
    inp.addEventListener("change", function () {
      var f = inp.files && inp.files[0]; if (!f) { inp.remove(); return; }
      var rd = new FileReader();
      rd.onload = function () { var added = parseCSV(String(rd.result || "")); inp.remove(); saveContacts(); render(); toast(added + " contact" + (added === 1 ? "" : "s") + " imported"); };
      rd.readAsText(f);
    });
    inp.click();
  }

  /* ---------- Import contact (CSV column mapping) ---------- */
  var imp = null;   // { headers, rows, fileName, group, map }
  function impNorm(s) { return String(s == null ? "" : s).toLowerCase().replace(/[^a-z0-9]/g, ""); }
  function impFields() {
    var core = [
      { k: "name", label: "Contact Name", req: true, syn: ["name", "contact name", "contactname", "full name", "fullname", "display name", "displayname"] },
      { k: "cc", label: "Country Code", req: true, syn: ["country code", "countrycode", "cc", "dial code", "dialcode", "country"] },
      { k: "mobile", label: "Mobile Number", req: true, syn: ["mobile number", "mobile", "phone number", "phone", "number", "whatsapp", "waba number", "wabanumber", "msisdn"] }
    ];
    return core.concat(userAttrKeys().map(function (k) { return { k: "attr:" + k, label: k, req: false, syn: [k] }; }));
  }
  function impAutoMap() {
    imp.map = {};
    var used = {};
    impFields().forEach(function (f) {
      var best = "";
      // pass 1: exact normalized match
      imp.headers.forEach(function (h) { if (best || used[h]) return; var nh = impNorm(h); for (var i = 0; i < f.syn.length; i++) { if (nh === impNorm(f.syn[i])) { best = h; break; } } });
      // pass 2: loose contains
      if (!best) imp.headers.forEach(function (h) { if (best || used[h]) return; var nh = impNorm(h); if (!nh) return; for (var i = 0; i < f.syn.length; i++) { var ns = impNorm(f.syn[i]); if (ns && (nh.indexOf(ns) > -1 || ns.indexOf(nh) > -1)) { best = h; break; } } });
      if (best) used[best] = 1;
      imp.map[f.k] = best;
    });
  }
  function impPickFile() {
    var input = document.createElement("input"); input.type = "file"; input.accept = ".csv,text/csv"; input.style.display = "none"; document.body.appendChild(input);
    input.addEventListener("change", function () {
      var f = input.files && input.files[0]; if (!f) { input.remove(); return; }
      var rd = new FileReader();
      rd.onload = function () { impLoadText(String(rd.result || ""), f.name); input.remove(); };
      rd.readAsText(f);
    });
    input.click();
  }
  function impLoadText(text, name) {
    var lines = text.split(/\r\n|\r|\n/).filter(function (l) { return l.trim(); });
    if (!lines.length) { toast("That CSV looks empty"); return; }
    imp.headers = splitCSVLine(lines[0]).map(function (h) { return h.trim(); }).filter(function (h) { return h !== ""; });
    imp.rows = lines.slice(1).map(function (l) { return splitCSVLine(l); });
    imp.fileName = name || "contacts.csv";
    impAutoMap();
    renderImport();
    toast(imp.rows.length + " row" + (imp.rows.length === 1 ? "" : "s") + " detected");
  }
  function openImportModal() {
    imp = { headers: [], rows: [], fileName: "", group: "", map: {} };
    renderImport();
  }
  function impMapSelect(f) {
    if (!imp.headers.length) return '<select class="ct-select" data-map="' + f.k + '" disabled><option>Upload a CSV first</option></select>';
    var cur = imp.map[f.k] || "";
    return '<select class="ct-select" data-map="' + f.k + '">' +
      '<option value="">\u2014 Not mapped \u2014</option>' +
      imp.headers.map(function (h) { return '<option value="' + esc(h) + '"' + (cur === h ? " selected" : "") + '>' + esc(h) + '</option>'; }).join("") +
      '</select>';
  }
  function renderImport() {
    var has = imp.headers.length > 0;
    var groupOpts = GROUPS.map(function (g) { return '<option value="' + g.id + '"' + (imp.group === g.id ? " selected" : "") + '>' + esc(g.name) + '</option>'; }).join("");
    var fieldsHTML = impFields().map(function (f) {
      return '<div class="ct-field"><label>' + esc(f.label) + (f.req ? ' <span class="req">*</span>' : "") + '</label>' + impMapSelect(f) + '</div>';
    }).join("");
    var uploadHTML = has
      ? '<div class="imp-file"><span class="ic">' + I.csv + '</span><div class="meta"><b>' + esc(imp.fileName) + '</b><span>' + imp.rows.length + ' row' + (imp.rows.length === 1 ? "" : "s") + ' \u00b7 ' + imp.headers.length + ' column' + (imp.headers.length === 1 ? "" : "s") + '</span></div><button class="imp-replace" data-upload>Replace</button></div>'
      : '<button class="imp-upload" data-upload><span class="ic">' + I.up + '</span>Upload</button>';
    var hintHTML = has
      ? '<div class="imp-hint">Columns were matched to fields automatically. Review the mapping below \u2014 set anything wrong to <b>Not mapped</b> or pick the right column.</div>'
      : '<div class="imp-hint">Upload a CSV file, then map its columns to your contact fields. <b>Mobile Number</b> is required to import a row.</div>';
    openSheet(
      '<div class="ct-shead"><span class="si">' + I.dl + '</span><span class="tt">Import contact</span><button class="x" data-x>' + I.x + '</button></div>' +
      '<div class="ct-field"><label>Group <span class="req">*</span></label><select class="ct-select" id="impGroup"><option value="">Select</option>' + groupOpts + '</select></div>' +
      '<div class="ct-field"><label>Choose CSV File</label>' + uploadHTML + '</div>' +
      hintHTML +
      '<div class="imp-sub">Map columns to fields</div>' +
      fieldsHTML +
      '<div class="ct-foot"><button class="ct-btn ghost" data-x>Cancel</button><button class="ct-btn primary" data-import>Import to Contacts</button></div>'
    );
    $$("[data-x]", sheet).forEach(function (b) { b.addEventListener("click", function () { imp = null; closeSheet(); }); });
    $$("[data-upload]", sheet).forEach(function (b) { b.addEventListener("click", impPickFile); });
    var gsel = $("#impGroup", sheet); if (gsel) gsel.addEventListener("change", function () { imp.group = this.value; });
    $$("[data-map]", sheet).forEach(function (s) { s.addEventListener("change", function () { imp.map[s.getAttribute("data-map")] = this.value; }); });
    $("[data-import]", sheet).addEventListener("click", doImport);
  }
  function doImport() {
    if (!imp.headers.length) { toast("Upload a CSV file first"); return; }
    if (!imp.group) { toast("Select a group"); return; }
    if (!imp.map.mobile) { toast("Map the Mobile Number column"); return; }
    var hi = {}; imp.headers.forEach(function (h, i) { hi[h] = i; });
    function cell(row, fk) { var h = imp.map[fk]; if (!h) return ""; var i = hi[h]; return i == null ? "" : String(row[i] == null ? "" : row[i]).trim(); }
    var keys = userAttrKeys(), added = 0, dup = 0;
    imp.rows.forEach(function (row, r) {
      var mob = digits(cell(row, "mobile")); if (!mob || mob.length < 6) return;
      var attrs = {}; keys.forEach(function (k) { var v = cell(row, "attr:" + k); if (v) attrs[k] = v; });
      var cc = cell(row, "cc"); if (cc && cc.charAt(0) !== "+" && /^\d+$/.test(cc)) cc = "+" + cc;
      var rec = { name: cell(row, "name") || ("Contact " + mob.slice(-4)), cc: cc || "+91", mobile: mob, groups: [imp.group], tags: [], attrs: attrs };
      var dupe = contactByMobile(mob);
      if (dupe) {
        dupe.attrs = Object.assign(dupe.attrs || {}, attrs);
        if (cell(row, "name")) dupe.name = rec.name;
        dupe.groups = dupe.groups || []; if (dupe.groups.indexOf(imp.group) < 0) dupe.groups.push(imp.group);
        dup++;
      } else {
        CONTACTS.unshift(Object.assign({ id: "c" + Date.now().toString(36) + r.toString(36), createdAt: Date.now() }, rec));
        added++;
      }
    });
    window.AskEvaContacts = CONTACTS; saveContacts(); imp = null; closeSheet(); render();
    if (!added && !dup) { toast("No valid rows found \u2014 check the Mobile mapping"); return; }
    toast(added + " imported" + (dup ? " \u00b7 " + dup + " updated" : ""));
  }
  function parseCSV(text) {
    var lines = text.split(/\r\n|\r|\n/).filter(function (l) { return l.trim(); }); if (!lines.length) return 0;
    var head = splitCSVLine(lines[0]).map(function (h) { return h.trim().toLowerCase(); });
    function col(names) { for (var i = 0; i < head.length; i++) if (names.indexOf(head[i]) > -1) return i; return -1; }
    var ni = col(["name", "contact name", "contactname"]), mi = col(["mobile", "phone", "number", "mobile number"]), ci = col(["countrycode", "country code", "cc"]), gi = col(["groups", "group", "group name"]), ti = col(["tags", "tag"]);
    var keys = userAttrKeys(), added = 0;
    for (var r = 1; r < lines.length; r++) {
      var cells = splitCSVLine(lines[r]); var mob = digits(cells[mi] || ""); if (!mob) continue;
      var groups = (gi > -1 ? (cells[gi] || "") : "").split(/[|;]/).map(function (s) { return s.trim(); }).filter(Boolean).map(function (n) { var g = createGroup(n); return g.id; });
      var tags = (ti > -1 ? (cells[ti] || "") : "").split(/[|;]/).map(function (s) { return s.trim(); }).filter(Boolean);
      var attrs = {}; keys.forEach(function (k) { var idx = col([k.toLowerCase()]); if (idx > -1 && cells[idx]) attrs[k] = cells[idx].trim(); });
      var rec = { name: (ni > -1 ? cells[ni] : "") || ("Contact " + mob.slice(-4)), cc: (ci > -1 && cells[ci]) ? cells[ci].trim() : "+91", mobile: mob, groups: groups, tags: tags, attrs: attrs };
      var dupe = contactByMobile(mob); if (dupe) Object.assign(dupe, rec); else { CONTACTS.unshift(Object.assign({ id: "c" + Date.now().toString(36) + r, createdAt: Date.now() }, rec)); }
      added++;
    }
    window.AskEvaContacts = CONTACTS; return added;
  }
  function splitCSVLine(line) { var out = [], cur = "", q = false; var delimiter = (line.indexOf(";") !== -1 && line.indexOf(",") === -1) ? ";" : ","; for (var i = 0; i < line.length; i++) { var ch = line[i]; if (q) { if (ch === '"' && line[i + 1] === '"') { cur += '"'; i++; } else if (ch === '"') q = false; else cur += ch; } else { if (ch === '"') q = true; else if (ch === delimiter) { out.push(cur); cur = ""; } else cur += ch; } } out.push(cur); return out; }

  /* ---------- public API (used by Chat profile + Compose + contacts2) ---------- */
  function addContactRecord(rec) {
    rec = rec || {}; var mob = digits(rec.mobile); if (!mob) return null;
    var c = contactByMobile(mob);
    if (!c) { c = { id: "c" + Date.now().toString(36), name: rec.name || ("Contact " + mob.slice(-4)), cc: rec.cc || "+91", mobile: mob, groups: [], tags: [], attrs: {}, createdAt: Date.now() }; CONTACTS.unshift(c); }
    if (rec.name && !c.name) c.name = rec.name;
    if (rec.group) { var g = createGroup(rec.group); if (g && c.groups.indexOf(g.id) < 0) c.groups.push(g.id); }
    if (rec.tag && c.tags.indexOf(rec.tag) < 0) c.tags.push(rec.tag);
    window.AskEvaContacts = CONTACTS; saveContacts();
    if (state.tab === "contacts" && pane.querySelector("#ctList")) render();
    return c;
  }
  window.AskEvaContactsAPI = {
    list: function () { return CONTACTS.slice(); },
    groups: function () { return GROUPS.map(function (g) { return { id: g.id, name: g.name, count: groupCount(g.id) }; }); },
    contactsInGroup: function (gid) { return CONTACTS.filter(function (c) { return (c.groups || []).indexOf(gid) > -1; }); },
    addToGroup: function (mobile, groupName) { return addContactRecord({ mobile: mobile, group: groupName }); },
    add: addContactRecord,
    isOptedOut: function (mobile) { var m = digits(mobile).slice(-10); return [].concat(OPTOUT.unsubscribed, OPTOUT.blocked).some(function (e) { return digits(e.mobile).slice(-10) === m; }); },
    optOut: function (rec, kind) { kind = kind === "blocked" ? "blocked" : "unsubscribed"; var m = digits(rec.mobile).slice(-10); var arr = OPTOUT[kind]; if (!arr.some(function (e) { return digits(e.mobile).slice(-10) === m; })) { arr.unshift({ name: rec.name || "", mobile: digits(rec.mobile), ts: Date.now() }); saveOptOut(); if (state.tab === "optout") render(); } }
  };

  /* shared interface for contacts2.js */
  window.__contacts = {
    pane: pane, host: host, I: I, esc: esc, digits: digits, toast: toast, initials: initials,
    GROUPS: function () { return GROUPS; }, CONTACTS: function () { return CONTACTS; }, OPTOUT: function () { return OPTOUT; },
    groupName: groupName, saveAll: saveAll, saveOptOut: saveOptOut, state: state,
    openSheet: openSheet, closeSheet: closeSheet, sheet: function () { return sheet; },
    rerender: render, registerTab: function (name, fn) { TAB[name] = fn; if (state.tab === name) render(); }
  };

  /* re-render columns/attrs live when User Attributes change in Settings */
  if (window.AskEvaUserAttrs && window.AskEvaUserAttrs.on) window.AskEvaUserAttrs.on(function () { if (formCtx) renderForm(); });
  document.addEventListener("userattrs:changed", function () { if (formCtx) renderForm(); });

  render();
})();
