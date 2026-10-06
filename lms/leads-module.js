/* =========================================================
   AskEva — Leads module (mobile)
   Owns #app-leads: list, search, slide-in filters, quick-
   action popup, full-field detail page, new-lead form,
   companies → customers. Replaces lead-profile.js + leads-tools.js.
   ========================================================= */
(function () {
  "use strict";
  var $ = function (s, r) { return (r || document).querySelector(s); };
  var $$ = function (s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); };
  var pane = document.getElementById("app-leads");
  if (!pane) return;

  /* ---------- toast ---------- */
  var toastT;
  function toast(msg, dur) {
    var t = document.getElementById("toast"); if (!t) return;
    t.textContent = msg; t.style.opacity = "1"; t.style.transform = "translateX(-50%) translateY(0)";
    clearTimeout(toastT); toastT = setTimeout(function () {
      t.style.opacity = "0"; t.style.transform = "translateX(-50%) translateY(20px)";
    }, dur || 1800);
  }

  /* ---------- confirm-before-delete modal (shared .ax-modal style) ---------- */
  var cScrim, cOnGo;
  function confirmModal(title, sub, go, cb) {
    if (!cScrim) {
      cScrim = document.createElement("div"); cScrim.className = "ax-modal-scrim";
      (pane || document.body).appendChild(cScrim);
      cScrim.addEventListener("click", function (e) { if (e.target === cScrim) cScrim.classList.remove("show"); });
    }
    var TRASH = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 6h18M8 6V4a1 1 0 0 1 1-1h6a1 1 0 0 1 1 1v2m2 0v14a1 1 0 0 1-1 1H6a1 1 0 0 1-1-1V6"/></svg>';
    cScrim.innerHTML = '<div class="ax-modal"><div class="mic">' + TRASH + '</div><div class="mt">' + esc(title) +
      '</div><div class="ms">' + esc(sub) + '</div><div class="mb"><button class="keep" id="lxCKeep">Keep</button>' +
      '<button class="go" id="lxCGo">' + esc(go) + '</button></div></div>';
    cOnGo = cb;
    $("#lxCKeep", cScrim).addEventListener("click", function () { cScrim.classList.remove("show"); });
    $("#lxCGo", cScrim).addEventListener("click", function () { cScrim.classList.remove("show"); if (cOnGo) cOnGo(); });
    requestAnimationFrame(function () { cScrim.classList.add("show"); });
  }

  /* ---------- delete + Undo (restore deleted leads) ----------
     Captures each removed lead with its original index so Undo can splice it
     back into the same spot. Stash is cleared when the snackbar times out. */
  var undoBar, undoT, deletedStash = null;
  function captureRemoved(predicate) {
    var removed = [];
    LEADS.forEach(function (L, i) { if (predicate(L)) removed.push({ lead: L, idx: i }); });
    return removed;
  }
  function restoreDeleted() {
    if (!deletedStash || !deletedStash.length) return;
    deletedStash.slice().sort(function (a, b) { return a.idx - b.idx; }).forEach(function (e) {
      LEADS.splice(Math.min(e.idx, LEADS.length), 0, e.lead);
    });
    clearTombstones(deletedStash);
    var n = deletedStash.length; deletedStash = null;
    emitLeadsChanged("restore"); updateLeadBadges(); renderLeads();
    if (undoBar) undoBar.classList.remove("show"); clearTimeout(undoT);
    toast(n + " lead" + (n > 1 ? "s" : "") + " restored");
  }
  function showUndo(msg) {
    if (!undoBar) {
      undoBar = document.createElement("div"); undoBar.className = "lx-undobar";
      (pane || document.body).appendChild(undoBar);
    }
    undoBar.innerHTML = '<span class="m">' + esc(msg) + '</span><button class="u" type="button">Undo</button>';
    undoBar.querySelector(".u").onclick = restoreDeleted;
    requestAnimationFrame(function () { undoBar.classList.add("show"); });
    clearTimeout(undoT);
    undoT = setTimeout(function () { if (undoBar) undoBar.classList.remove("show"); deletedStash = null; }, 5000);
  }
  (function injectUndoCss() {
    if (document.getElementById("lx-undo-css")) return;
    var s = document.createElement("style"); s.id = "lx-undo-css";
    s.textContent =
      ".lx-undobar{ position:absolute; left:14px; right:14px; bottom:78px; z-index:120; display:flex; align-items:center;" +
      "justify-content:space-between; gap:12px; background:#15231A; color:#fff; border-radius:13px; padding:13px 16px;" +
      "box-shadow:0 14px 34px rgba(0,0,0,.28); font-family:var(--font-body); font-size:13.5px; font-weight:600;" +
      "opacity:0; transform:translateY(12px); pointer-events:none; transition:opacity .2s ease, transform .2s ease; }" +
      ".lx-undobar.show{ opacity:1; transform:none; pointer-events:auto; }" +
      ".lx-undobar .m{ min-width:0; overflow:hidden; text-overflow:ellipsis; white-space:nowrap; }" +
      ".lx-undobar .u{ flex:0 0 auto; border:none; background:transparent; color:var(--brand-300,#85D653);" +
      "font-family:inherit; font-size:13.5px; font-weight:800; cursor:pointer; padding:4px 6px; }";
    document.head.appendChild(s);
  })();

  /* ---------- escape + activity-timeline css (PASS 4) ---------- */
  function esc(s) { return String(s == null ? "" : s).replace(/[&<>"']/g, function (c) { return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]; }); }
  (function injectTlCss() {
    if (document.getElementById("askeva-tl-css")) return;
    var s = document.createElement("style"); s.id = "askeva-tl-css";
    s.textContent =
      ".lx-tl{padding:2px 0}" +
      ".lx-tlitem{display:flex;gap:12px;padding:11px 14px;position:relative}" +
      ".lx-tlitem:not(:last-child)::before{content:'';position:absolute;left:27px;top:36px;bottom:-3px;width:2px;background:var(--line,#EEF1EC)}" +
      ".lx-tlic{flex:0 0 28px;width:28px;height:28px;border-radius:9px;display:grid;place-items:center;background:var(--tint-50,#EAF9E6);color:var(--brand-700,#177A36);z-index:1}" +
      ".lx-tlic svg{width:15px;height:15px}" +
      ".lx-tlitem.chat .lx-tlic{background:#E6F4FB;color:#1E7FB0}" +
      ".lx-tlitem.appt .lx-tlic{background:#FFF1DC;color:#9A6B05}" +
      ".lx-tlitem.ticket .lx-tlic{background:#EFEAFB;color:#6D45D6}" +
      ".lx-tlt{font-size:13.5px;font-weight:700;color:var(--ink,#15231A);letter-spacing:-.01em;line-height:1.3}" +
      ".lx-tlm{font-size:11.5px;font-weight:600;color:var(--ink-3,#8A978D);margin-top:2px}" +
      ".lx-tlempty{padding:16px 14px;font-size:12.5px;font-weight:600;color:var(--ink-3,#8A978D)}";
    document.head.appendChild(s);
  })();
  function actMeta(t) {
    switch (t) {
      case "created": return { ic: I.user, cls: "created" };
      case "updated": return { ic: I.tag, cls: "updated" };
      case "status": return { ic: I.activity, cls: "status" };
      case "note": return { ic: I.note, cls: "note" };
      case "followup": return { ic: I.remind, cls: "followup" };
      case "chat": case "message": return { ic: I.chat, cls: "chat" };
      case "appointment": return { ic: I.clock, cls: "appt" };
      case "ticket": return { ic: I.template, cls: "ticket" };
      default: return { ic: I.activity, cls: "event" };
    }
  }
  function updateLeadBadges() {
    try { var b = document.querySelector('.side-item[data-route="leads"] .badge'); if (b) b.textContent = LEADS.length; } catch (e) {}
  }

  /* ---------- icons ---------- */
  var I = {
    phone: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M22 16.9v3a2 2 0 0 1-2.2 2 19.8 19.8 0 0 1-8.6-3 19.5 19.5 0 0 1-6-6 19.8 19.8 0 0 1-3-8.6A2 2 0 0 1 4.1 2h3a2 2 0 0 1 2 1.7c.1.9.4 1.8.7 2.7a2 2 0 0 1-.5 2.1L8.1 9.7a16 16 0 0 0 6 6l1.2-1.2a2 2 0 0 1 2.1-.5c.9.3 1.8.6 2.7.7a2 2 0 0 1 1.8 2.1z"/></svg>',
    mail: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="5" width="18" height="14" rx="2.5"/><path d="m4 7 8 6 8-6"/></svg>',
    globe: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3c2.5 2.4 2.5 15.6 0 18M12 3c-2.5 2.4-2.5 15.6 0 18"/></svg>',
    building: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 21V7l7-4 7 4v14M3 21h18M8.5 21v-3.5h3V21M8 9h.5M13 9h.5M8 13h.5M13 13h.5"/></svg>',
    pin: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 21s7-5.2 7-11a7 7 0 1 0-14 0c0 5.8 7 11 7 11Z"/><circle cx="12" cy="10" r="2.4"/></svg>',
    user: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="8" r="4"/><path d="M4 21a8 8 0 0 1 16 0"/></svg>',
    tag: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 12V5a2 2 0 0 1 2-2h7l9 9-9 9z"/><circle cx="8" cy="8" r="1.5"/></svg>',
    source: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9.2"/><path d="M12 2.8v18.4M2.8 12h18.4"/><path d="M12 2.8c3.6 2.7 3.6 15.7 0 18.4M12 2.8c-3.6 2.7-3.6 15.7 0 18.4"/><path d="M4 7.6c5 1.9 11 1.9 16 0M4 16.4c5-1.9 11-1.9 16 0"/><circle cx="8.4" cy="6.6" r="1.15" fill="currentColor" stroke="none"/><circle cx="16.6" cy="12" r="1.15" fill="currentColor" stroke="none"/><circle cx="12" cy="16.4" r="1.15" fill="currentColor" stroke="none"/></svg>',
    dot: '<svg viewBox="0 0 24 24" fill="currentColor"><circle cx="12" cy="12" r="4"/></svg>',
    cash: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="6" width="18" height="12" rx="2.5"/><circle cx="12" cy="12" r="2.6"/><path d="M6 9.5v5M18 9.5v5"/></svg>',
    clock: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></svg>',
    doc: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 3h8l4 4v14H6Z"/><path d="M14 3v4h4M9 13h6M9 17h5"/></svg>',
    chev: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="m9 6 6 6-6 6"/></svg>',
    back: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="m15 18-6-6 6-6"/></svg>',
    x: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M18 6 6 18M6 6l12 12"/></svg>',
    check: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><path d="m5 12 4 4 10-11"/></svg>',
    funnel: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 5h18l-7 8v5l-4 2v-7z"/></svg>',
    sync: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 12a9 9 0 0 1-15 6.7L3 16M3 12a9 9 0 0 1 15-6.7L21 8"/><path d="M3 21v-5h5M21 3v5h-5"/></svg>',
    dl: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3v12m0 0 4-4m-4 4-4-4M5 21h14"/></svg>',
    up: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 21V9m0 0 4 4m-4-4-4 4M5 3h14"/></svg>',
    csv: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 3h8l4 4v14H6Z"/><path d="M14 3v4h4M8 14h2M8 17h2M14 14h2M14 17h2"/></svg>',
    trash: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 7h16M9 7V5h6v2M6 7l1 13h10l1-13"/></svg>',
    check2: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m9 11 3 3L22 4"/><path d="M21 12v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11"/></svg>',
    dots: '<svg viewBox="0 0 24 24" fill="currentColor"><circle cx="12" cy="5" r="2"/><circle cx="12" cy="12" r="2"/><circle cx="12" cy="19" r="2"/></svg>',
    bell: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 9a6 6 0 0 1 12 0c0 4 1.5 5 2 6H4c.5-1 2-2 2-6Z"/><path d="M10 19a2 2 0 0 0 4 0"/></svg>',
    wa: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 2a10 10 0 0 0-8.6 15l-1.3 4.7 4.8-1.3A10 10 0 1 0 12 2Zm5.3 14.1c-.2.6-1.3 1.2-1.8 1.2-.5.1-1 .1-1.7-.1-.4-.1-.9-.3-1.6-.6-2.8-1.2-4.6-4-4.7-4.2-.1-.2-1.1-1.5-1.1-2.8 0-1.3.7-2 .9-2.2.2-.3.5-.3.7-.3h.5c.2 0 .4 0 .6.5l.8 1.9c.1.2.1.4 0 .5l-.4.5c-.2.2-.3.4-.1.6.1.3.7 1.1 1.4 1.7.9.8 1.6 1 1.9 1.2.2.1.4.1.5-.1l.6-.7c.2-.2.3-.2.6-.1l1.8.9c.3.1.4.2.5.3.1.2.1.7-.1 1.3Z"/></svg>',
    chat: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14 9a2 2 0 0 1-2 2H6l-4 4V4c0-1.1.9-2 2-2h8a2 2 0 0 1 2 2v5Z"/><path d="M18 9h2a2 2 0 0 1 2 2v11l-4-4h-6a2 2 0 0 1-2-2v-1"/><circle cx="5.2" cy="6.4" r=".7" fill="currentColor" stroke="none"/><circle cx="8" cy="6.4" r=".7" fill="currentColor" stroke="none"/><circle cx="10.8" cy="6.4" r=".7" fill="currentColor" stroke="none"/></svg>',
    template: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M16 16l-4-4-4 4"/><path d="M12 12v9"/><path d="M20.39 18.39A5 5 0 0 0 18 9h-1.26A8 8 0 1 0 3 16.3"/></svg>',
    note: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M5 3h11l3 3v15H5z"/><path d="M9 9h6M9 13h6M9 17h3"/></svg>',
    activity: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 12h4l2 6 4-14 2 8h6"/></svg>',
    remind: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="13" r="8"/><path d="M12 9v4l2.5 2M9 2 6 4M15 2l3 2"/></svg>',
    calllog: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M15 4h5v5M20 4l-7 7M20 16.9v3a2 2 0 0 1-2.2 2 19.8 19.8 0 0 1-8.6-3 19.5 19.5 0 0 1-6-6 19.8 19.8 0 0 1-3-8.6A2 2 0 0 1 4.1 2h3a2 2 0 0 1 2 1.7c.1.9.4 1.8.7 2.7a2 2 0 0 1-.5 2.1L8.1 9.7a16 16 0 0 0 6 6"/></svg>',
    edit: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M11 4H5a2 2 0 0 0-2 2v13a2 2 0 0 0 2 2h13a2 2 0 0 0 2-2v-6"/><path d="M18.5 2.5a2.12 2.12 0 0 1 3 3L12 15l-4 1 1-4Z"/></svg>',
    listIc: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M8 6h13M8 12h13M8 18h13M3 6h.01M3 12h.01M3 18h.01"/></svg>',
    boardIc: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="4" width="5" height="16" rx="1.5"/><rect x="10" y="4" width="5" height="11" rx="1.5"/><rect x="17" y="4" width="4" height="14" rx="1.5"/></svg>'
  };

  /* ---------- status meta (marketing funnel) ----------
     Statuses are sourced from Lead Settings → Configuration → Dropdown Fields
     (the shared AskEvaLeadDropdowns store) so any status added/removed there
     shows up here in the list, filters, add/edit form and kanban board. */
  var BUILTIN_STATUS = {
    "new":     { label: "New",      cls: "new" },
    hot:       { label: "Hot",      cls: "hot" },
    warm:      { label: "Warm",     cls: "warm" },
    cold:      { label: "Cold",     cls: "cold" },
    converted: { label: "Customer", cls: "converted" }
  };
  var STATUS_ALIAS = { "new": "new", hot: "hot", warm: "warm", cold: "cold", customer: "converted", converted: "converted" };
  var CUSTOM_CLS = ["contacted", "qualified", "meeting", "proposal", "negotiation", "followup"];
  function statusKey(label) { var l = String(label).trim().toLowerCase(); return STATUS_ALIAS[l] || ("st_" + l.replace(/[^a-z0-9]+/g, "_").replace(/^_|_$/g, "")); }
  var STATUS = {}, STATUS_ORDER = [];
  function rebuildStatuses() {
    var keep = STATUS; STATUS = {}; STATUS_ORDER = [];
    var opts = (window.AskEvaLeadDropdowns && AskEvaLeadDropdowns.options("Status")) || ["New", "Hot", "Warm", "Cold", "Customer"];
    var ci = 0;
    opts.forEach(function (label) {
      var key = statusKey(label);
      if (BUILTIN_STATUS[key]) STATUS[key] = { label: BUILTIN_STATUS[key].label, cls: BUILTIN_STATUS[key].cls };
      else STATUS[key] = { label: label, cls: CUSTOM_CLS[ci++ % CUSTOM_CLS.length] };
      if (STATUS_ORDER.indexOf(key) < 0) STATUS_ORDER.push(key);
    });
    if (!STATUS["new"]) STATUS["new"] = { label: "New", cls: "new" };
    // conversion logic depends on a 'converted' status existing
    if (!STATUS.converted) { STATUS.converted = { label: "Customer", cls: "converted" }; STATUS_ORDER.push("converted"); }
    return keep;
  }
  rebuildStatuses();
  var AV = ["#2BA84A", "#22B0E8", "#7C5CFF", "#E5499A", "#FF9416", "#1E7FB0", "#E0541F", "#3BA4DD"];
  var MONTHS = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];

  /* ---------- data (from the supplied screens) ---------- */
  var LEADS = [
    { id:"madhan", name:"Madhan", subtitle:"", mobile:"917904532349", company:"Brightline Retail", status:"converted",
      source:"Import", assigned:"testerr@gmail.com", email:"test@gmail.com",
      created:"02-06-2026 12:36", updated:"04-06-2026 12:49", address:"", city:"", country:"",
      website:"mmu", value:"", tags:[], description:"Hello testing", cf_test:"", cf_username:"Madhan" },
    { id:"l917200076059", name:"917200076059", subtitle:"", mobile:"917200076059", company:"", status:"new",
      source:"Chat-Sync", assigned:"", email:"", created:"01-06-2026 16:20", updated:"01-06-2026 16:20",
      address:"", city:"", country:"", website:"", value:"", tags:[],
      description:"Created from WhatsApp contact: 917200076059", cf_test:"", cf_username:"" },
    { id:"louis", name:"Łôūīš Můťhūśâmÿ", subtitle:"", mobile:"916374537701", company:"Lumen Academy", status:"new",
      source:"User Initiated - Whatsapp", assigned:"", email:"", created:"01-06-2026 13:26", updated:"01-06-2026 13:26",
      address:"", city:"", country:"", website:"", value:"", tags:[],
      description:"Synced from WhatsApp contact: Łôūīš Můťhūśâmÿ", cf_test:"", cf_username:"" },
    { id:"jashim", name:"Jashim", subtitle:"", mobile:"916383895962", company:"Meridian Health", status:"new",
      source:"User Initiated - Whatsapp", assigned:"", email:"", created:"01-06-2026 13:25", updated:"01-06-2026 13:25",
      address:"", city:"", country:"", website:"", value:"", tags:[],
      description:"Synced from WhatsApp contact: Jashim", cf_test:"", cf_username:"" },
    { id:"shuraif", name:"Muhammed Shuraif", subtitle:"test", mobile:"918113801548", company:"Cedar Grove Realty", status:"hot",
      source:"User Initiated - Whatsapp", assigned:"testerr@gmail.com", email:"", created:"18-05-2026 17:12", updated:"25-05-2026 12:18",
      address:"", city:"", country:"", website:"yjuuj", value:"", tags:["Vbc"],
      description:"Synced from WhatsApp contact: Muhammed Shuraif", cf_test:"", cf_username:"" },
    { id:"nagaraj", name:"Nagaraj", subtitle:"Bulletu Stack Marketer", mobile:"919159651706", company:"ASK EVA", status:"converted",
      source:"Website", assigned:"eshan@tunepath.com", email:"eshan@tunepath.com", created:"16-05-2026 16:42", updated:"22-05-2026 13:14",
      address:"", city:"", country:"", website:"https://askeva.io", value:"", tags:[],
      description:"", cf_test:"", cf_username:"" },
    { id:"unknown7", name:"Unknown", subtitle:"", mobile:"917012458890", company:"", status:"new",
      source:"Chat-Sync", assigned:"", email:"", created:"08-05-2026 18:37", updated:"20-05-2026 12:56",
      address:"", city:"", country:"", website:"", value:"", tags:[],
      description:"Synced from WhatsApp contact: Unknown", cf_test:"", cf_username:"" }
  ];
  window.AskEvaLeads = LEADS;
  var SEED_LEADS = LEADS.map(function (L) { return JSON.parse(JSON.stringify(L)); });

  /* ---------- persistence: Leads are the single source of truth (survive refresh) ---------- */
  var LEADS_KEY = "askeva.leads.v1";
  /* tombstones: ids the user explicitly deleted. Deletes always win over reseed. */
  var TOMB_KEY = "askeva.leads.tombstones.v1";
  function loadTombstones() { try { return JSON.parse(localStorage.getItem(TOMB_KEY)) || {}; } catch (e) { return {}; } }
  function recordTombstones(removed) {
    if (!removed || !removed.length) return;
    var t = loadTombstones();
    removed.forEach(function (e) { if (e.lead && e.lead.id) t[e.lead.id] = 1; });
    try { localStorage.setItem(TOMB_KEY, JSON.stringify(t)); } catch (e) {}
  }
  function clearTombstones(removed) {
    if (!removed || !removed.length) return;
    var t = loadTombstones();
    removed.forEach(function (e) { if (e.lead && e.lead.id) delete t[e.lead.id]; });
    try { localStorage.setItem(TOMB_KEY, JSON.stringify(t)); } catch (e) {}
  }
  /* default lead shape — saved records are merged over this so a new release's
     added fields get sane defaults instead of reading undefined downstream. */
  var LEAD_DEFAULTS = { id:"", name:"", subtitle:"", mobile:"", company:"", status:"new",
    source:"", assigned:"", email:"", created:"", updated:"", address:"", city:"",
    country:"", website:"", value:"", tags:[], description:"", cf_test:"", cf_username:"" };
  (function loadLeads() {
    try {
      var raw = localStorage.getItem(LEADS_KEY);
      if (raw) {
        var saved = JSON.parse(raw);
        if (saved && saved.length) {
          LEADS.length = 0;
          saved.forEach(function (s) {
            var lead = Object.assign({}, LEAD_DEFAULTS, s);
            lead.tags = Array.isArray(s && s.tags) ? s.tags.slice() : [];
            LEADS.push(lead);
          });
        }
      }
    } catch (e) {}
  })();
  /* ---------- one-time restore: re-insert any original seed leads that were
     deleted during testing, back at their original positions. Runs once
     (guarded by a flag); future deletes stick normally. ---------- */
  (function reseedDeletedOnce() {
    try {
      if (localStorage.getItem("askeva.leads.reseed.v1")) return;
      var have = {}; LEADS.forEach(function (L) { have[L.id] = 1; });
      var tomb = loadTombstones();
      SEED_LEADS.forEach(function (s, i) {
        if (!have[s.id] && !tomb[s.id]) LEADS.splice(Math.min(i, LEADS.length), 0, JSON.parse(JSON.stringify(s)));
      });
      localStorage.setItem("askeva.leads.reseed.v1", "1");
      localStorage.setItem(LEADS_KEY, JSON.stringify(LEADS));
    } catch (e) {}
  })();
  function saveLeads() { try { localStorage.setItem(LEADS_KEY, JSON.stringify(LEADS)); } catch (e) {} }
  window.AskEvaSaveLeads = saveLeads;
  window.addEventListener("pagehide", saveLeads);
  document.addEventListener("visibilitychange", function () { if (document.visibilityState === "hidden") saveLeads(); });

  /* ===== PASS 3: live event bus — one signal every subscriber listens to ===== */
  var _lcT;
  function emitLeadsChanged(type, detail) {
    saveLeads();
    clearTimeout(_lcT);
    _lcT = setTimeout(function () {
      try { document.dispatchEvent(new CustomEvent("leads:changed", { detail: Object.assign({ type: type || "update" }, detail || {}) })); } catch (e) {}
    }, 0);
  }
  window.AskEvaLeadsChanged = emitLeadsChanged;

  /* ===== PASS 4: unified per-lead activity timeline (shared write surface) ===== */
  function _digits(s) { return String(s == null ? "" : s).replace(/\D/g, ""); }
  function _stamp() { var d = new Date(), p = function (n) { return (n < 10 ? "0" : "") + n; }; return p(d.getDate()) + "-" + p(d.getMonth() + 1) + "-" + d.getFullYear() + " " + p(d.getHours()) + ":" + p(d.getMinutes()); }
  function findLeadByContact(m) {
    m = m || {};
    if (m.id) { var byId = leadById(m.id); if (byId) return byId; }
    var mob = _digits(m.mobile), nm = (m.name || "").trim().toLowerCase();
    if (mob.length >= 6) { for (var i = 0; i < LEADS.length; i++) { var lm = _digits(LEADS[i].mobile); if (lm && lm.slice(-10) === mob.slice(-10)) return LEADS[i]; } }
    if (nm) { for (var j = 0; j < LEADS.length; j++) { if ((LEADS[j].name || "").trim().toLowerCase() === nm) return LEADS[j]; } }
    return null;
  }
  function logActivity(L, ev) {
    if (!L || !ev) return null;
    if (!L.activity) L.activity = [];
    var e = { type: ev.type || "event", text: ev.text || "", module: ev.module || "Leads", ts: ev.ts || _stamp(), at: Date.now() };
    L.activity.unshift(e);
    if (ev.touch !== false) L.updated = e.ts;
    emitLeadsChanged("activity", { id: L.id, kind: e.type });
    return e;
  }
  /* public: any module (Chat, Appointments, Tickets, future) appends here */
  window.AskEvaActivity = {
    log: function (match, ev) { var L = findLeadByContact(match); return L ? logActivity(L, ev) : null; },
    logById: function (id, ev) { return logActivity(leadById(id), ev); },
    forLead: function (id) { var L = leadById(id); return (L && L.activity) || []; },
    find: findLeadByContact
  };

  /* ===== Customer entity — created ON conversion, distinct from the Lead =====
     Resolves audit C-01: "Convert" no longer just relabels a lead; it mints a
     real Customer record (own id, owner, onboarding state) linked by leadId. */
  var CUSTOMERS_KEY = "askeva.customers.v1";
  window.AskEvaCustomers = (function () { try { return JSON.parse(localStorage.getItem(CUSTOMERS_KEY)) || []; } catch (e) { return []; } })();
  function saveCustomers() { try { localStorage.setItem(CUSTOMERS_KEY, JSON.stringify(window.AskEvaCustomers)); } catch (e) {} }
  function createCustomerRecord(L) {
    if (!L) return null;
    for (var i = 0; i < window.AskEvaCustomers.length; i++) if (window.AskEvaCustomers[i].leadId === L.id) return window.AskEvaCustomers[i];
    var cust = { id: "cust_" + Date.now().toString(36), leadId: L.id, name: L.name, mobile: L.mobile,
      company: L.company || "", owner: L.assigned || "Unassigned", since: _stamp(), state: "active", onboarded: false };
    window.AskEvaCustomers.unshift(cust); saveCustomers();
    logActivity(L, { type: "created", text: "Customer record created \u00b7 onboarding started", module: "Customers" });
    cust.onboarded = true; saveCustomers();
    onboardCustomer(L);
    return cust;
  }
  /* post-conversion onboarding: welcome the customer, schedule a check-in, alert the owner */
  function onboardCustomer(L) {
    if (!L) return;
    var owner = L.assigned || "Unassigned";
    if (window.__chat && window.__chat.deliverToThread) {
      window.__chat.deliverToThread({ name: L.name, phone: L.mobile },
        { type: "text", text: "\uD83C\uDF89 Welcome aboard, " + (L.name || "there") + "! Thanks for choosing us. Your account is active \u2014 reach out anytime." });
    }
    if (window.AskEvaAddReminder) {
      var d = new Date(Date.now() + 24 * 3600000), p = function (n) { return (n < 10 ? "0" : "") + n; };
      var when = d.getFullYear() + "-" + p(d.getMonth() + 1) + "-" + p(d.getDate()) + "T" + p(d.getHours()) + ":" + p(d.getMinutes());
      window.AskEvaAddReminder({ name: L.name, mobile: L.mobile },
        { desc: "Onboarding check-in with " + L.name, when: when, whenLabel: "Tomorrow", agent: owner, module: "Customers" });
    }
    if (window.__notifs && window.__notifs.push) {
      window.__notifs.push({ cat: "leads", type: "conv", t: "New customer onboarded", d: (L.name || "A lead") + " is now a customer \u2014 welcome sent.", to: owner });
    }
    logActivity(L, { type: "message", text: "Welcome message sent \u00b7 onboarding check-in scheduled", module: "Customers" });
  }
  window.AskEvaCreateCustomer = createCustomerRecord;
  /* reconcileCustomers: keep the Customers book in lock-step with Leads.
     - backfill: every converted lead gets a real Customer record
     - prune: drop any Customer whose lead no longer exists OR is no longer
       converted, so the Customers tab never shows a card that can't resolve.
     Also refreshes name/company/mobile/owner from the lead so edits sync. */
  function reconcileCustomers() {
    var changed = false;
    var byId = {}; LEADS.forEach(function (L) { byId[L.id] = L; });
    // prune orphaned / un-converted
    var kept = (window.AskEvaCustomers || []).filter(function (c) {
      var L = byId[c.leadId];
      if (!L || L.status !== "converted") { changed = true; return false; }
      // keep lead-sourced fields in sync
      if (c.name !== L.name || c.company !== (L.company || "") || c.mobile !== L.mobile) {
        c.name = L.name; c.company = L.company || ""; c.mobile = L.mobile; changed = true;
      }
      return true;
    });
    if (kept.length !== (window.AskEvaCustomers || []).length) window.AskEvaCustomers = kept;
    // backfill missing
    LEADS.forEach(function (L) {
      if (L.status === "converted" && !window.AskEvaCustomers.some(function (c) { return c.leadId === L.id; })) {
        window.AskEvaCustomers.unshift({ id: "cust_" + L.id, leadId: L.id, name: L.name, mobile: L.mobile,
          company: L.company || "", owner: L.assigned || "Unassigned", since: L.updated || L.created || _stamp(), state: "active", onboarded: true });
        changed = true;
      }
    });
    if (changed) saveCustomers();
    return changed;
  }
  reconcileCustomers();
  /* convert by contact match — used by Chat's "convert to customer" so both sides
     mint the same real Customer record */
  window.AskEvaConvertLead = function (match) {
    var L = findLeadByContact(match);
    if (!L) return null;
    if (L.status !== "converted") { L.status = "converted"; logActivity(L, { type: "status", text: "Status changed to Customer", module: "Leads" }); }
    var cust = createCustomerRecord(L);
    try { saveLeads(); } catch (e) {}
    try { emitLeadsChanged("convert"); } catch (e) {}
    try { renderLeads(); } catch (e) {}
    return cust;
  };
  /* shared reminder write surface — any module (Appointments, Tickets, future)
     can drop a reminder onto the matching lead's timeline + Reminders list.
     Resolves audit gap: reminders are no longer manual-only. */
  window.AskEvaAddReminder = function (match, info) {
    info = info || {};
    var L = findLeadByContact(match);
    var rec = { desc: info.desc || "", when: info.when || "", whenLabel: info.whenLabel || "", agent: info.agent || "", status: "pending", source: info.source || (info.module || "") };
    if (L) {
      L._reminders = L._reminders || [];
      L._reminders.unshift(rec);
      logActivity(L, { type: "followup", text: "Reminder set: " + (rec.desc.length > 50 ? rec.desc.slice(0, 50) + "\u2026" : rec.desc), module: info.module || "Reminders" });
      try { saveLeads(); } catch (e) {}
    }
    if (info.notifyChat && window.__chat && window.__chat.postReminderTo) {
      window.__chat.postReminderTo({ name: (L && L.name) || match.name, phone: (L && L.mobile) || match.mobile },
        { desc: rec.desc, whenLabel: rec.whenLabel, agent: rec.agent, customer: (L && L.name) || match.name });
    }
    return rec;
  };

  /* ===== reminder SCHEDULER — every reminder fires at its due time and is
     routed to whoever it concerns: the assigned agent (notification + push
     banner) AND the customer (a reminder delivered into their chat), then
     logged on the timeline and marked done. ===== */
  function reminderDueMs(r) { if (!r || !r.when) return null; var d = new Date(r.when); return isNaN(d.getTime()) ? null : d.getTime(); }
  function fireReminder(L, r) {
    if (!L || !r || r.status !== "pending") return;
    r.status = "done"; r.firedAt = Date.now();
    var mod = r.source || "Reminders";
    var recipient = r.agent || L.assigned || "Unassigned";
    var recName = (recipient || "Unassigned").split("@")[0] || "team";
    /* 1 — timeline */
    logActivity(L, { type: "followup", text: "Reminder fired \u2192 " + recName + ": " + r.desc, module: mod });
    /* 2 — alert the assigned agent it concerns */
    if (window.__notifs && window.__notifs.push) {
      window.__notifs.push({ cat: (mod === "Appointments" ? "appointments" : "leads"), type: (mod === "Appointments" ? "appt" : "lead"),
        t: "Reminder due", d: r.desc + " \u00b7 " + (L.name || ""), to: recipient });
    }
    if (window.__pushAlert) window.__pushAlert({ text: "Reminder for " + recName + ": " + r.desc });
    /* 3 — reach the customer it concerns, in their own chat (no navigation) */
    if (window.__chat && window.__chat.deliverToThread) {
      window.__chat.deliverToThread({ name: L.name, phone: L.mobile },
        { type: "reminder", text: r.desc, whenLabel: r.whenLabel || "", agent: recName, customer: L.name });
    }
  }
  function checkReminders() {
    var now = Date.now(), fired = 0;
    LEADS.forEach(function (L) {
      (L._reminders || []).forEach(function (r) {
        if (r.status === "pending") { var t = reminderDueMs(r); if (t != null && t <= now) { fireReminder(L, r); fired++; } }
      });
    });
    if (fired) { saveLeads(); }
    return fired;
  }
  window.AskEvaFireDueReminders = checkReminders;
  setTimeout(checkReminders, 2600);          // catch any already-due reminders after boot
  setInterval(checkReminders, 15000);        // then poll so each one fires on time

  /* migrate legacy statuses/sources to the new pipeline + internal Chat vocab */
  (function migrate() {
    /* normalise any legacy pipeline statuses back to the marketing funnel */
    var SMAP = { negotiation: "hot", proposal: "hot", meeting: "warm", contacted: "warm", qualified: "warm", followup: "cold", invalid: "cold", lost: "cold", won: "converted" };
    var changed = false;
    LEADS.forEach(function (L) {
      if (SMAP[L.status]) { L.status = SMAP[L.status]; changed = true; }
      if (L.source) L.source = L.source.replace(/whatsapp/ig, "Chat").replace(/User Initiated - Chat/i, "Chat-Initiated");
      if (L.description) L.description = L.description.replace(/WhatsApp/ig, "Chat");
    });
    if (changed) { try { localStorage.setItem(LEADS_KEY, JSON.stringify(LEADS)); } catch (e) {} }
  })();

  var SOURCES = [];
  function rebuildSources() {
    SOURCES = (window.AskEvaLeadDropdowns && AskEvaLeadDropdowns.options("Source")) || ["Import", "Chat-Sync", "Chat-Initiated", "Website", "Referral", "Manual"];
  }
  rebuildSources();
  if (window.AskEvaLeadDropdowns && AskEvaLeadDropdowns.onChange) {
    AskEvaLeadDropdowns.onChange(function () { rebuildStatuses(); rebuildSources(); try { renderLeads(); updateLeadBadges(); } catch (e) {} });
  }
  /* lead owners come from the shared people store (Settings → Agents) so anyone
     created/edited/deactivated there shows up in the Assigned-To filter here. */
  function leadAgents() { return (window.AskEvaPeople && AskEvaPeople.roster) ? AskEvaPeople.roster("leads") : [{ email: "testerr@gmail.com", name: "Madhan" }, { email: "eshan@tunepath.com", name: "Eshan Rao" }]; }
  if (window.AskEvaPeople && AskEvaPeople.on) AskEvaPeople.on(function () { try { if (typeof renderLeads === "function") renderLeads(); } catch (e) {} });
  var AGENTS = ["testerr@gmail.com", "eshan@tunepath.com"];

  /* company → industry mapping; drives the Industry & Company filters */
  var COMPANY_META = {
    "ASK EVA":            "SaaS & Technology",
    "Brightline Retail":  "Retail & E-commerce",
    "Cedar Grove Realty": "Real Estate",
    "Meridian Health":    "Healthcare",
    "Lumen Academy":      "Education"
  };
  var INDUSTRIES = ["SaaS & Technology", "Retail & E-commerce", "Real Estate", "Healthcare", "Education", "Finance", "Manufacturing"];
  function industryOf(L) { return COMPANY_META[(L.company || "").trim()] || ""; }
  /* distinct companies present in the data (named only) */
  function companyList() {
    var seen = {}, out = [];
    LEADS.forEach(function (L) { var c = (L.company || "").trim(); if (c && !seen[c]) { seen[c] = 1; out.push(c); } });
    return out.sort();
  }

  var state = {
    tab: "leads", query: "",
    f: { status: "all", source: "all", assigned: "all", industry: "all", company: "all", period: "Last 30 days", start: "", end: "" },
    selMode: false, selected: {}, view: "list"
  };
  var FDEFAULT = { status: "all", source: "all", assigned: "all", industry: "all", company: "all", period: "Last 30 days", start: "", end: "" };

  /* ===== PASS 3: persist active filters across refresh ===== */
  var FILTERS_KEY = "askeva.leads.filters.v1";
  function saveFilters() { try { localStorage.setItem(FILTERS_KEY, JSON.stringify(state.f)); } catch (e) {} }
  (function loadFilters() { try { var r = localStorage.getItem(FILTERS_KEY); if (r) { var f = JSON.parse(r); if (f && typeof f === "object") state.f = Object.assign({}, FDEFAULT, f); } } catch (e) {} })();
  /* PASS 5 perf: debounce render-time persistence (search/filter keystrokes no
     longer hammer localStorage). Real data mutations still persist immediately
     through emitLeadsChanged(). */
  var _persistT;
  function schedulePersist() { clearTimeout(_persistT); _persistT = setTimeout(function () { saveLeads(); saveFilters(); }, 400); }

  /* ---------- helpers ---------- */
  function isAlpha(s) { return /[A-Za-z\u00C0-\u024F]/.test(s); }
  function firstGlyph(s) { return s ? (Array.from(String(s))[0] || "") : ""; }   // surrogate-safe (emoji/initials)
  function initials(name) {
    var p = (name || "").trim().split(/\s+/);
    return (firstGlyph(p[0]) + (p[1] ? firstGlyph(p[1]) : "")).toUpperCase();
  }
  function avHTML(lead) {
    var color = AV[hashIdx(lead.id)];
    var inner = isAlpha(lead.name) ? initials(lead.name) : I.wa;
    return '<span class="lx-av" style="background:' + color + '">' + inner + '</span>';
  }
  function hashIdx(s) { var h = 0; for (var i = 0; i < s.length; i++) h = (h + s.charCodeAt(i)) % AV.length; return h; }
  function fmtDate(s) {
    if (!s) return "—";
    var m = s.match(/(\d{2})-(\d{2})-(\d{4})(?:\s+(\d{2}:\d{2}))?/);
    if (!m) return s;
    return parseInt(m[1], 10) + " " + MONTHS[parseInt(m[2], 10) - 1] + " " + m[3] + (m[4] ? " · " + m[4] : "");
  }
  function dash(v) { return v && String(v).trim() ? v : "—"; }
  function badge(status) {
    var s = STATUS[status] || STATUS["new"];
    return '<span class="lx-badge ' + s.cls + '"><span class="d"></span>' + s.label + '</span>';
  }
  function companyName(c) { return c && c.trim() ? c : "No Company"; }

  /* ---------- markup scaffold ---------- */
  pane.innerHTML =
    '<div class="lx-head">' +
      '<div class="lx-topbar">' +
        '<button class="lx-iconbtn" aria-label="Menu"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"><path d="M4 7h16M4 12h16M4 17h16"/></svg></button>' +
        '<div class="lx-title">Leads Management</div>' +
        '<button class="lx-iconbtn" aria-label="Notifications">' + I.bell + '</button>' +
      '</div>' +
      '<div class="lx-tabs"><button class="lx-tab active" data-tab="leads">Leads</button><button class="lx-tab" data-tab="companies">Companies</button><button class="lx-tab" data-tab="customers">Customers</button></div>' +
    '</div>' +
    '<div class="lx-sheet">' +
      '<div data-tab-body="leads">' +
        '<div class="lx-toolbar">' +
          '<div class="lx-search"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><circle cx="11" cy="11" r="7"/><path d="M21 21l-4.3-4.3"/></svg><input id="lxSearch" type="text" placeholder="Search leads"></div>' +
          '<button class="lx-filterbtn" id="lxFilterBtn">' + I.funnel + 'Filters<span class="lx-fcount" hidden>0</span></button>' +
        '</div>' +
        '<div class="lx-actions">' +
          '<button class="lx-actchip" data-act="sync">' + I.sync + 'Sync</button>' +
          '<button class="lx-actchip" data-act="sample">' + I.csv + 'Sample CSV</button>' +
          '<button class="lx-actchip" data-act="import">' + I.dl + 'Import</button>' +
          '<button class="lx-actchip" data-act="export">' + I.up + 'Export</button>' +
        '</div>' +
        '<div class="lx-countrow"><span class="c" id="lxCount"></span><span class="chips" id="lxFilterChips"></span>' +
          '<div class="lx-selgroup">' +
            '<button class="lx-selbtn lx-selall" data-act="selall"><span class="lx-sallbl">Select all</span></button>' +
            '<button class="lx-selbtn" data-act="select"><span class="lx-selic">' + I.check2 + '</span><span class="lx-sellbl">Select</span></button>' +
          '</div>' +
          '<div class="lx-viewseg" id="lxViewSeg">' +
            '<button class="on" data-view="list" aria-label="List view">' + I.listIc + '</button>' +
            '<button data-view="kanban" aria-label="Kanban view">' + I.boardIc + '</button>' +
          '</div>' +
        '</div>' +
        '<div id="lxList"></div>' +
        '<div id="lxBoard" class="lx-board" hidden></div>' +
      '</div>' +
      '<div data-tab-body="companies" hidden>' +
        '<div class="lx-toolbar">' +
          '<div class="lx-search"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><circle cx="11" cy="11" r="7"/><path d="M21 21l-4.3-4.3"/></svg><input id="lxCoSearch" type="text" placeholder="Search companies"></div>' +
          '<button class="lx-filterbtn ghost" data-act="refreshco" aria-label="Refresh">' + I.sync + '</button>' +
        '</div>' +
        '<div class="lx-countrow"><span class="c" id="lxCoCount"></span></div>' +
        '<div id="lxCoList"></div>' +
      '</div>' +
      '<div data-tab-body="customers" hidden>' +
        '<div class="lx-toolbar">' +
          '<div class="lx-search"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><circle cx="11" cy="11" r="7"/><path d="M21 21l-4.3-4.3"/></svg><input id="lxCustSearch" type="text" placeholder="Search customers"></div>' +
          '<button class="lx-filterbtn ghost" data-act="import" aria-label="Import customers"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 15V3m0 12 4-4m-4 4-4-4M4 17v2a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-2"/></svg></button>' +
          '<button class="lx-filterbtn ghost" data-act="refreshcust" aria-label="Refresh">' + I.sync + '</button>' +
        '</div>' +
        '<div class="lx-custdates"><div id="lxCustDatePill"></div></div>' +
        '<div class="lx-countrow"><span class="c" id="lxCustCount"></span></div>' +
        '<div id="lxCustList"></div>' +
      '</div>' +
    '</div>' +
    '<button class="lx-fab" id="lxFab" aria-label="New lead"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round"><path d="M12 5v14M5 12h14"/></svg>New Lead</button>' +
    '<div class="lx-selbar" id="lxSelbar">' +
      '<span class="n" id="lxSelN">0 selected</span>' +
      '<button class="sb-up" data-sel="update">' + I.edit + 'Update</button>' +
      '<button class="sb-del" data-sel="delete">' + I.trash + '</button>' +
      '<button class="sb-x" data-sel="cancel">' + I.x + '</button></div>';

  var listEl = $("#lxList", pane), coListEl = $("#lxCoList", pane), custListEl = $("#lxCustList", pane);

  /* ===================== LEADS LIST ===================== */
  function filtered() {
    var q = state.query.trim().toLowerCase(), f = state.f;
    // anchor "now" to the most recent lead so date ranges stay meaningful
    var nowMs = 0;
    LEADS.forEach(function (L) { var d = parseLeadDate(L.created); if (d && d.getTime() > nowMs) nowMs = d.getTime(); });
    if (!nowMs) nowMs = Date.now();
    var periodDays = { "Last 7 days": 7, "Last 30 days": 30, "Last 90 days": 90 }[f.period];
    var minMs = periodDays ? nowMs - periodDays * 864e5 : null;
    var startD = f.start ? new Date(f.start + "T00:00:00") : null;
    var endD = f.end ? new Date(f.end + "T23:59:59") : null;
    return LEADS.filter(function (L) {
      if (f.status !== "all" && L.status !== f.status) return false;
      if (f.source !== "all" && L.source !== f.source) return false;
      if (f.industry !== "all" && industryOf(L) !== f.industry) return false;
      if (f.company !== "all" && (L.company || "").trim() !== f.company) return false;
      if (f.assigned !== "all") {
        if (f.assigned === "Unassigned" && L.assigned) return false;
        if (f.assigned !== "Unassigned" && L.assigned !== f.assigned) return false;
      }
      var d = parseLeadDate(L.created);
      if (minMs != null && d && d.getTime() < minMs) return false;
      if (f.period === "This year" && d && d.getFullYear() !== new Date(nowMs).getFullYear()) return false;
      if (startD && d && d < startD) return false;
      if (endD && d && d > endD) return false;
      if (q) {
        var hay = (L.name + " " + L.mobile + " " + L.email + " " + L.company + " " + L.source + " " + L.assigned).toLowerCase();
        if (hay.indexOf(q) < 0) return false;
      }
      return true;
    });
  }
  function parseLeadDate(s) {
    var m = /(\d{2})-(\d{2})-(\d{4})(?:\s+(\d{2}):(\d{2}))?/.exec(s || "");
    if (!m) return null;
    return new Date(+m[3], +m[2] - 1, +m[1], +(m[4] || 0), +(m[5] || 0));
  }
  function cardHTML(L) {
    var sub = L.subtitle ? '<div class="lx-csub">' + L.subtitle + '</div>' : "";
    var assigned = L.assigned ? L.assigned.split("@")[0] : "Unassigned";
    var meta =
      '<span class="m">' + I.phone + dash(L.mobile) + '</span>' +
      '<span class="m">' + I.source + '<b>' + dash(L.source) + '</b></span>' +
      '<span class="m">' + I.user + assigned + '</span>' +
      '<span class="m">' + I.clock + fmtDate(L.created).split(" · ")[0] + '</span>';
    return '<div class="lx-card" data-id="' + L.id + '">' +
      '<span class="chk">' + I.check + '</span>' +
      avHTML(L) +
      '<div class="lx-cmain">' +
        '<div class="lx-crow1"><span class="lx-cname">' + L.name + '</span>' + badge(L.status) + '</div>' +
        sub +
        '<div class="lx-cmeta">' + meta + '</div>' +
      '</div>' +
    '</div>';
  }
  function renderLeads() {
    var rows = filtered();
    $("#lxCount", pane).textContent = rows.length + (rows.length === 1 ? " lead" : " leads");
    var board = $("#lxBoard", pane);
    if (state.view === "kanban") {
      pane.classList.remove("selmode");
      listEl.hidden = true; if (board) { board.hidden = false; renderBoard(rows); }
      renderFilterChips();
      schedulePersist(); updateLeadBadges();
      return;
    }
    if (board) board.hidden = true;
    listEl.hidden = false;
    listEl.innerHTML = rows.length ? rows.map(cardHTML).join("") :
      '<div class="lx-empty">' + I.user + '<div class="t">No leads found</div><div class="s">Try adjusting your search or filters</div></div>';
    // re-apply selection visual
    if (state.selMode) pane.classList.add("selmode"); else pane.classList.remove("selmode");
    $$(".lx-card", listEl).forEach(function (c) {
      if (state.selected[c.getAttribute("data-id")]) c.classList.add("sel");
    });
    renderFilterChips();
    schedulePersist(); updateLeadBadges();
  }

  /* ===================== KANBAN BOARD ===================== */
  var dragId = null;
  function kcardHTML(L) {
    var assigned = L.assigned ? L.assigned.split("@")[0] : "Unassigned";
    var locked = L.status === "converted";   // Customers can't be dragged in Kanban
    return '<div class="lx-kcard' + (locked ? " locked" : "") + '" data-id="' + L.id + '" draggable="false">' +
      '<div class="kc-top">' + avHTML(L) + '<span class="kc-name">' + L.name + '</span></div>' +
      '<div class="kc-meta"><span class="m">' + I.phone + dash(L.mobile) + '</span>' +
        '<span class="m">' + I.user + assigned + '</span></div>' +
    '</div>';
  }
  function renderBoard(rows) {
    var board = $("#lxBoard", pane); if (!board) return;
    var byStatus = {};
    STATUS_ORDER.forEach(function (s) { byStatus[s] = []; });
    rows.forEach(function (L) { (byStatus[L.status] || (byStatus[L.status] = [])).push(L); });
    board.innerHTML = STATUS_ORDER.map(function (s) {
      var st = STATUS[s] || { label: s, cls: s };
      var items = byStatus[s] || [];
      return '<div class="lx-kcol" data-st="' + s + '">' +
        '<div class="lx-khd ' + st.cls + '"><span class="dot"></span><span class="kt">' + st.label + '</span><span class="kn">' + items.length + '</span></div>' +
        '<div class="lx-kbody">' +
          (items.length ? items.map(kcardHTML).join("") : '<div class="lx-kempty">No leads</div>') +
        '</div>' +
      '</div>';
    }).join("");
  }
  function leadById(id) { for (var i = 0; i < LEADS.length; i++) if (LEADS[i].id === id) return LEADS[i]; return null; }

  /* active-filter chips + count */
  function activeFilters() {
    var f = state.f, list = [];
    if (f.status !== "all") list.push({ k: "status", g: "Status", t: (STATUS[f.status] || {}).label || f.status });
    if (f.source !== "all") list.push({ k: "source", g: "Source", t: f.source });
    if (f.assigned !== "all") list.push({ k: "assigned", g: "Agent", t: f.assigned === "Unassigned" ? "Unassigned" : f.assigned.split("@")[0] });
    if (f.industry !== "all") list.push({ k: "industry", g: "Industry", t: f.industry });
    if (f.company !== "all") list.push({ k: "company", g: "Company", t: f.company });
    if (f.start || f.end) list.push({ k: "date", g: "Created", t: (f.start || "…") + " → " + (f.end || "…") });
    return list;
  }
  function renderFilterChips() {
    var fc = activeFilters();
    var badgeEl = $(".lx-fcount", pane);
    if (fc.length) { badgeEl.hidden = false; badgeEl.textContent = fc.length; } else badgeEl.hidden = true;
    var chipsEl = $("#lxFilterChips", pane);
    chipsEl.innerHTML = fc.map(function (c) {
      return '<span class="lx-fchip"><span class="k">' + c.g + '</span>' + c.t + '<button data-clear="' + c.k + '" aria-label="Remove">' + I.x + '</button></span>';
    }).join("") + (fc.length > 1 ? '<button class="lx-fchip-clear" data-clearall>Clear all</button>' : "");
    $$("[data-clear]", chipsEl).forEach(function (b) {
      b.addEventListener("click", function () {
        var k = b.getAttribute("data-clear");
        if (k === "date") { state.f.start = ""; state.f.end = ""; } else state.f[k] = "all";
        renderLeads();
      });
    });
    var ca = $("[data-clearall]", chipsEl);
    if (ca) ca.addEventListener("click", function () { state.f = Object.assign({}, FDEFAULT); renderLeads(); toast("Filters cleared"); });
  }

  /* ===================== COMPANIES ===================== */
  function companyGroups() {
    var map = {};
    LEADS.forEach(function (L) {
      var n = companyName(L.company);
      (map[n] = map[n] || []).push(L);
    });
    return Object.keys(map).map(function (n) { return { name: n, leads: map[n] }; })
      .sort(function (a, b) { return b.leads.length - a.leads.length; });
  }
  function renderCompanies(q) {
    q = (q || "").trim().toLowerCase();
    var groups = companyGroups().filter(function (g) { return !q || g.name.toLowerCase().indexOf(q) >= 0; });
    $("#lxCoCount", pane).textContent = groups.length + (groups.length === 1 ? " company" : " companies");
    coListEl.innerHTML = groups.map(function (g) {
      return '<div class="lx-cocard" data-co="' + g.name + '">' +
        '<span class="ic">' + I.building + '</span>' +
        '<div class="info"><div class="lx-coname">' + g.name + '</div><div class="lx-cocount">' + g.leads.length + (g.leads.length === 1 ? " customer" : " customers") + '</div></div>' +
        '<span class="lx-coview">View' + I.chev + '</span>' +
      '</div>';
    }).join("") +
      '<div class="lx-copage"><span class="pg">' + "‹" + '</span><span class="pg on">1</span><span class="pg">' + "›" + '</span></div>';
    $$(".lx-cocard", coListEl).forEach(function (c) {
      c.addEventListener("click", function () { openCustomers(c.getAttribute("data-co")); });
    });
  }

  /* ===================== CUSTOMERS (converted leads → real Customer records) ===================== */
  function custStateMeta(s) {
    if (s === "churned") return { label: "Churned", cls: "churned" };
    if (s === "at_risk" || s === "at-risk") return { label: "At risk", cls: "atrisk" };
    if (s === "reactivated") return { label: "Reactivated", cls: "active" };
    return { label: "Active", cls: "active" };
  }
  function custInitials(n) { var p = (n || "").trim().split(/\s+/); return (firstGlyph(p[0]) + firstGlyph(p[1])).toUpperCase() || "?"; }
  /* lifecycle: change a customer's state (active ↔ at-risk → churned → reactivated) */
  function setCustomerState(cust, state, note) {
    if (!cust) return;
    cust.state = state; saveCustomers();
    var L = leadById(cust.leadId);
    if (L) logActivity(L, { type: "status", text: note || ("Customer status \u2192 " + custStateMeta(state).label), module: "Customers" });
    renderCustomers((($("#lxCustSearch", pane) || {}).value) || "");
  }
  window.AskEvaSetCustomerState = function (custId, state) { var c = (window.AskEvaCustomers || []).filter(function (x) { return x.id === custId; })[0]; if (c) setCustomerState(c, state); return c; };
  var custDates = { start: "", end: "" };
  var custPillInit = false;
  function renderCustomers(q) {
    if (!custListEl) return;
    if (!custPillInit) {
      var _pill = $("#lxCustDatePill", pane);
      if (_pill && window.AskEvaPicker && AskEvaPicker.rangePill) {
        AskEvaPicker.rangePill(_pill, { start: custDates.start, end: custDates.end, onChange: function (r) {
          custDates.start = r.start || ""; custDates.end = r.end || "";
          renderCustomers(($("#lxCustSearch", pane) || {}).value || "");
        } });
        custPillInit = true;
      }
    }
    q = (q || "").trim().toLowerCase();
    var all = (window.AskEvaCustomers || []).slice();
    var sD = custDates.start ? new Date(custDates.start + "T00:00:00") : null;
    var eD = custDates.end ? new Date(custDates.end + "T23:59:59") : null;
    var list = all.filter(function (c) {
      if (q && (c.name + " " + (c.company || "") + " " + (c.mobile || "") + " " + (c.owner || "")).toLowerCase().indexOf(q) < 0) return false;
      if (sD || eD) { var d = parseLeadDate(c.since); if (!d) return false; if (sD && d < sD) return false; if (eD && d > eD) return false; }
      return true;
    });
    var cnt = $("#lxCustCount", pane); if (cnt) cnt.textContent = list.length + (list.length === 1 ? " customer" : " customers");
    if (!list.length) {
      custListEl.innerHTML = '<div class="lx-custempty">' + I.user + '<div class="t">' + (all.length ? "No matches" : "No customers yet") + '</div><div class="s">' + (all.length ? "Try a different search." : "Convert a lead to create a customer record \u2014 it appears here with its owner, status and full timeline.") + '</div></div>';
      return;
    }
    custListEl.innerHTML = list.map(function (c) {
      var sm = custStateMeta(c.state);
      var owner = (c.owner || "Unassigned").split("@")[0];
      var since = (c.since || "").split(" ")[0] || "\u2014";
      return '<div class="lx-custcard" data-lead="' + esc(c.leadId || "") + '">' +
        '<span class="av">' + esc(custInitials(c.name)) + '</span>' +
        '<div class="info">' +
          '<div class="top"><span class="nm">' + esc(c.name) + '</span><button class="lx-custstate ' + sm.cls + '" type="button" data-cyclestate title="Tap to change status"><span class="d"></span>' + sm.label + '</button></div>' +
          (c.company ? '<div class="sub">' + esc(c.company) + '</div>' : '') +
          '<div class="meta"><span>' + I.user + esc(owner) + '</span><span>' + I.clock + 'Since ' + esc(since) + '</span></div>' +
        '</div>' +
        '<span class="lx-coview">View' + I.chev + '</span>' +
      '</div>';
    }).join("");
    $$(".lx-custcard", custListEl).forEach(function (el) {
      el.addEventListener("click", function () {
        var lid = el.getAttribute("data-lead");
        var L = lid && leadById(lid);
        var cust = (window.AskEvaCustomers || []).filter(function (x) { return x.leadId === lid; })[0];
        if (L) openCustomerDetail(L, cust); else toast("Customer profile");
      });
    });
    $$(".lx-custcard [data-cyclestate]", custListEl).forEach(function (btn) {
      btn.addEventListener("click", function (e) {
        e.stopPropagation();
        var lid = btn.closest(".lx-custcard").getAttribute("data-lead");
        var cust = (window.AskEvaCustomers || []).filter(function (x) { return x.leadId === lid; })[0]; if (!cust) return;
        var order = ["active", "at_risk", "churned"]; var idx = order.indexOf(cust.state); if (idx < 0) idx = 0;
        var next = order[(idx + 1) % order.length];
        if (cust.state === "churned" && next === "active") { setCustomerState(cust, "reactivated", "Customer reactivated \u00b7 new opportunity opened"); toast(cust.name + " reactivated"); }
        else { setCustomerState(cust, next); toast(cust.name + " \u2192 " + custStateMeta(next).label); }
      });
    });
  }

  /* ===================== OVERLAYS: scrim + sheet ===================== */
  var scrim = document.createElement("div"); scrim.className = "lx-scrim";
  var sheet = document.createElement("div"); sheet.className = "lx-sheetpop";
  pane.appendChild(scrim); pane.appendChild(sheet);
  scrim.addEventListener("click", closeSheet);
  function openSheet(html) {
    sheet.innerHTML = '<div class="lx-grip"></div>' + html;
    requestAnimationFrame(function () { scrim.classList.add("show"); sheet.classList.add("show"); });
  }
  function closeSheet() { scrim.classList.remove("show"); sheet.classList.remove("show"); }

  /* slide panels */
  function makePanel() { var p = document.createElement("div"); p.className = "lx-panel"; pane.appendChild(p); return p; }
  var filterPanel = makePanel(), detailPanel = makePanel(), custPanel = makePanel();
  var customerPanel = makePanel(); customerPanel.style.zIndex = "47";
  var tplPanel = makePanel(); tplPanel.style.zIndex = "47";
  detailPanel.style.zIndex = "46"; // sit above the customers panel when opened from a company
  function openPanel(p) { requestAnimationFrame(function () { p.classList.add("show"); }); }
  function closePanel(p) { p.classList.remove("show"); }

  /* ===================== CUSTOMER DETAIL (info + Appointments / Ticketing tabs) ===================== */
  function _digits10(s) { return String(s || "").replace(/\D/g, "").slice(-10); }
  function apptsForCustomer(L) {
    var AX = window.AX; if (!AX || !AX.appts) return [];
    var d = _digits10(L.mobile); if (!d) return [];
    return AX.appts.filter(function (a) { return _digits10(a.mobile) === d; })
      .sort(function (a, b) { return a.date < b.date ? 1 : -1; });
  }
  function ticketsForCustomer(L) {
    return (window.__tickets && window.__tickets.byCustomer) ? window.__tickets.byCustomer(L.name, L.mobile) : [];
  }
  function cdKV(k, v) { return '<div class="cd-cell"><div class="k">' + k + '</div><div class="v">' + v + '</div></div>'; }
  function customerApptRows(L) {
    var AX = window.AX, list = apptsForCustomer(L);
    if (!list.length) return '<div class="cd-empty">No appointments for this customer.</div>';
    return list.map(function (a) {
      var dep = AX.deptById ? AX.deptById(a.department) : { name: a.department };
      var u = AX.userById ? AX.userById(a.user) : null;
      var st = a.status === "completed" ? { t: "completed", c: "done" } : a.status === "cancelled" ? { t: "cancelled", c: "cancel" } : { t: "current", c: "cur" };
      var tm = AX.fmtTime ? (AX.fmtTime(a.time).full + " - " + AX.fmtTime(a.time + a.dur).full) : "";
      var code = AX.apptCode ? AX.apptCode(a) : (a.id || "");
      var pay = a.paymentType === "prepaid" ? "prepaid" : "postpaid";
      return '<div class="cd-row">' +
        '<div class="cd-r1"><span class="id">' + esc(code) + '</span><span class="cd-pill ' + pay + '">' + pay + '</span></div>' +
        '<div class="cd-r2">' + esc((dep && dep.name) || "") + ' \u00b7 <span class="cd-st ' + st.c + '">' + st.t + '</span></div>' +
        '<div class="cd-r3">' + esc(a.date) + ' \u00b7 ' + esc(tm) + '</div>' +
        '<div class="cd-r3">Manager: ' + esc((u && u.name) || "\u2014") + '</div>' +
      '</div>';
    }).join("");
  }
  function customerTicketRows(L) {
    var list = ticketsForCustomer(L);
    if (!list.length) return '<div class="cd-empty">No tickets for this customer.</div>';
    return list.map(function (t) {
      var pc = t.priority === "high" ? "hi" : t.priority === "med" ? "md" : "lo";
      var sc = t.status === "resolved" ? "done" : t.status === "pending" ? "pend" : "open";
      return '<div class="cd-row">' +
        '<div class="cd-r1"><span class="id">' + esc(t.num) + '</span><span class="cd-st ' + sc + '">' + esc(t.status) + '</span></div>' +
        '<div class="cd-r2">' + esc(t.dept || "\u2014") + ' \u00b7 <span class="cd-prio ' + pc + '">' + esc(t.priority) + '</span></div>' +
        '<div class="cd-r3">' + esc(t.subject || "") + '</div>' +
        '<div class="cd-r3">Assigned: ' + esc(t.assignee || "\u2014") + '</div>' +
      '</div>';
    }).join("");
  }
  function openCustomerDetail(L, cust) {
    if (!L) return;
    var since = (cust && cust.since) || L.updated || L.created || "\u2014";
    var closedBy = (cust && cust.owner) ? cust.owner.split("@")[0] : (L.assigned ? L.assigned.split("@")[0] : "\u2014");
    var appts = apptsForCustomer(L), tks = ticketsForCustomer(L);
    function body(tab) { return tab === "tk" ? customerTicketRows(L) : customerApptRows(L); }
    customerPanel.innerHTML =
      '<div class="lx-pbar"><button class="back" data-back>' + I.back + '</button><span class="ptt">Customer Details</span></div>' +
      '<div class="lx-pbody" style="padding:14px 14px 60px">' +
        '<div class="cd-grid">' +
          cdKV("Name", esc(L.name)) + cdKV("Company", esc(L.company || "N/A")) +
          cdKV("Email", esc(L.email || "N/A")) + cdKV("Mobile", "+91 " + esc(_digits10(L.mobile))) +
          cdKV("Conversion Date", esc(since)) + cdKV("Lead Closed By", esc(closedBy)) +
          cdKV("Source", esc(L.source || "\u2014")) + cdKV("Status", '<span class="cd-conv">' + I.check + 'Converted</span>') +
        '</div>' +
        '<div class="cd-tabs">' +
          '<button class="on" data-ct="appts">Appointments (' + appts.length + ')</button>' +
          '<button data-ct="tk">Ticketing (' + tks.length + ')</button>' +
        '</div>' +
        '<div id="cdBody">' + body("appts") + '</div>' +
      '</div>';
    $("[data-back]", customerPanel).addEventListener("click", function () { closePanel(customerPanel); });
    $$(".cd-tabs button", customerPanel).forEach(function (b) {
      b.addEventListener("click", function () {
        $$(".cd-tabs button", customerPanel).forEach(function (x) { x.classList.remove("on"); }); b.classList.add("on");
        $("#cdBody", customerPanel).innerHTML = body(b.getAttribute("data-ct"));
      });
    });
    openPanel(customerPanel);
  }

  /* ===================== QUICK-ACTION POPUP ===================== */
  function openQuick(id) {
    var L = leadById(id); if (!L) return;
    var converted = L.status === "converted";
    var actions = [
      { q: "call", l: "Call", i: I.phone },
      { q: "remind", l: "Reminders", i: I.remind },
      { q: "profile", l: "Profile", i: I.user },
      { q: "template", l: "Send Template", i: I.template },
      { q: "notes", l: "Notes", i: I.note },
      { q: "activity", l: "Activity Logs", i: I.activity },
      { q: "calls", l: "Call Logs", i: I.calllog }
    ];
    openSheet(
      '<div class="lx-shead"><span class="tt">Lead actions</span><button class="x" data-x>' + I.x + '</button></div>' +
      '<div class="lx-sbody">' +
        '<div class="lx-qhead">' + avHTML(L) +
          '<div><div class="qn">' + L.name + '</div><div class="qm">' + I.phone.replace("currentColor","currentColor") + dash(L.mobile) + '</div></div>' +
          '<div style="margin-left:auto">' + badge(L.status) + '</div>' +
        '</div>' +
        '<div class="lx-qgrid">' + actions.map(function (a) {
          return '<button class="lx-qaction" data-q="' + a.q + '"><span class="qi">' + a.i + '</span><span class="ql">' + a.l + '</span></button>';
        }).join("") + '</div>' +
      '</div>' +
      '<div class="lx-sfoot lx-sfoot-stack">' +
        '<button class="lx-convert' + (converted ? " done" : "") + '" data-convert>' + (converted ? I.check + "Already a customer" : I.check + "Convert as customer") + '</button>' +
        '<button class="lx-deletelead" data-deletelead>' + I.trash + 'Delete lead</button>' +
      '</div>'
    );
    $("[data-x]", sheet).addEventListener("click", closeSheet);
    $$(".lx-qaction", sheet).forEach(function (b) {
      b.addEventListener("click", function () { quickAction(b.getAttribute("data-q"), L); });
    });
    var cv = $("[data-convert]", sheet);
    if (!converted) cv.addEventListener("click", function () { convertLead(L); });
    var dlb = $("[data-deletelead]", sheet);
    if (dlb) dlb.addEventListener("click", function () {
      if (dlb.classList.contains("confirm")) { deleteLead(L); return; }
      dlb.classList.add("confirm"); dlb.innerHTML = I.trash + "Tap again to delete";
      setTimeout(function () { if (dlb) { dlb.classList.remove("confirm"); dlb.innerHTML = I.trash + "Delete lead"; } }, 2600);
    });
  }
  function quickAction(q, L) {
    if (q === "profile") { closeSheet(); setTimeout(function () { openDetail(L.id); }, 200); return; }
    if (q === "call") { closeSheet(); setTimeout(function () { openCallScreen(L); }, 180); return; }
    if (q === "remind") { openReminders(L); return; }
    if (q === "template") { closeSheet(); setTimeout(function () { openSendTemplate(L); }, 200); return; }
    if (q === "notes") { openNotes(L); return; }
    if (q === "activity") { openActivity(L); return; }
    if (q === "calls") { openCalls(L); return; }
  }
  function convertLead(L) {
    L.status = "converted";
    logActivity(L, { type: "status", text: "Status changed to Customer", module: "Leads" });
    createCustomerRecord(L);
    closeSheet(); renderLeads();
    toast(L.name + " marked as customer");
  }

  /* ----- secondary sheets ----- */
  function sheetShell(title, bodyHTML, footHTML) {
    openSheet('<div class="lx-shead"><span class="tt">' + title + '</span><button class="x" data-x>' + I.x + '</button></div>' +
      '<div class="lx-sbody">' + bodyHTML + '</div>' + (footHTML ? '<div class="lx-sfoot">' + footHTML + '</div>' : ""));
    $("[data-x]", sheet).addEventListener("click", closeSheet);
  }
  function openReminders(L) {
    L._reminders = L._reminders || [];
    var agents = leadAgents().filter(function (a) { return a.email; });
    var qrs = (window.AskEvaQuickReplies && window.AskEvaQuickReplies.list()) || [];
    function listHTML() {
      if (!L._reminders.length) return '<div class="rm-empty">No reminders found</div>';
      return L._reminders.map(function (r, i) {
        var who = r.agent ? '<span class="dot">&middot;</span>' + I.user + '<span>' + esc(r.agent.split("@")[0]) + '</span>' : "";
        return '<div class="rm-item">' +
          '<div class="rm-main"><div class="rm-desc">' + esc(r.desc) + '</div>' +
            '<div class="rm-meta">' + I.remind + '<span>' + esc(r.whenLabel) + '</span>' + who + '</div></div>' +
          '<span class="rm-status pending">Pending</span>' +
          '<button class="rm-del" data-rmdel="' + i + '" aria-label="Delete">' + I.trash + '</button></div>';
      }).join("");
    }
    sheetShell("Set New Reminder",
      '<div class="lx-field"><label>Description <span class="req">*</span></label>' +
        '<textarea class="lx-textarea" id="rmDesc" placeholder="Enter reminder description or select from quick replies below"></textarea></div>' +
      '<div class="lx-field"><label>Quick Replies</label>' +
        '<select class="lx-select" id="rmQR"><option value="" selected>Select a quick reply to insert in description</option>' +
          qrs.map(function (q, i) { return '<option value="' + i + '">' + esc(q.t) + '</option>'; }).join("") + '</select></div>' +
      '<div class="lx-twocol">' +
        '<div class="lx-field"><label>Date &amp; Time <span class="req">*</span></label><input class="lx-input" type="datetime-local" id="rmWhen" min="' + (function () { var d = new Date(), p = function (n) { return (n < 10 ? "0" : "") + n; }; return d.getFullYear() + "-" + p(d.getMonth() + 1) + "-" + p(d.getDate()) + "T" + p(d.getHours()) + ":" + p(d.getMinutes()); })() + '"></div>' +
        '<div class="lx-field"><label>Set reminder to</label><select class="lx-select" id="rmAgent"><option value="" selected disabled>Select an agent</option>' +
          agents.map(function (a) { return '<option value="' + esc(a.email) + '">' + esc(a.name) + '</option>'; }).join("") + '</select></div>' +
      '</div>' +
      '<div class="rm-sec">Reminders</div>' +
      '<div id="rmList" class="rm-list">' + listHTML() + '</div>',
      '<button class="lx-btn primary" data-add>Add Reminder</button>');
    var desc = $("#rmDesc", sheet);
    $("#rmQR", sheet).addEventListener("change", function () {
      if (this.value === "") return;
      var q = qrs[+this.value];
      if (q) {
        var cur = desc.value.replace(/\s*$/, "");
        // first quick reply fills the description; each further one is appended
        // under an "-- Additional points --" separator so they stack up.
        desc.value = cur ? (cur + "\n\n-- Additional points --\n" + q.m) : q.m;
      }
      this.value = ""; desc.focus();
    });
    function bindDel() {
      $$("[data-rmdel]", sheet).forEach(function (b) {
        b.addEventListener("click", function () {
          L._reminders.splice(+b.getAttribute("data-rmdel"), 1); saveLeads();
          $("#rmList", sheet).innerHTML = listHTML(); bindDel();
        });
      });
    }
    bindDel();
    $("[data-add]", sheet).addEventListener("click", function () {
      var d = desc.value.trim(), w = $("#rmWhen", sheet).value, ag = $("#rmAgent", sheet).value || L.assigned || "Unassigned";
      if (!d) { toast("Enter a reminder description"); desc.focus(); return; }
      if (!w) { toast("Pick a date & time"); return; }
      if (new Date(w).getTime() < Date.now() - 60000) { toast("Pick a present or future date & time"); return; }
      L._reminders.unshift({ desc: d, when: w, whenLabel: fmtCustom(w), agent: ag, status: "pending" });
      logActivity(L, { type: "followup", text: "Reminder set: " + (d.length > 50 ? d.slice(0, 50) + "\u2026" : d), module: "Leads" });
      // reflect the reminder live in the lead's chat (for both agent + customer)
      if (window.__chat && window.__chat.postReminderTo) {
        window.__chat.postReminderTo({ name: L.name, phone: L.mobile },
          { desc: d, whenLabel: fmtCustom(w), agent: ag ? ag.split("@")[0] : "", customer: L.name });
      }
      saveLeads();
      desc.value = ""; $("#rmWhen", sheet).value = ""; $("#rmAgent", sheet).value = "";
      $("#rmList", sheet).innerHTML = listHTML(); bindDel();
      toast("Reminder added");
    });
  }
  function openTemplates(L) {
    // single shared source of truth + UI (see shared-library.js)
    if (window.AskEvaTemplates && window.AskEvaTemplates.open) {
      window.AskEvaTemplates.open({
        title: "Send a template",
        fields: function () { return window.AskEvaLeadFields && AskEvaLeadFields.mapFields(); },
        onSend: function (t) {
          logActivity(L, { type: "message", text: "Template sent: " + (t && t.n ? t.n : ""), module: "Leads" });
          var target = { name: L.name, phone: L.mobile };
          if (window.__openChatFrom) window.__openChatFrom("leads", null, "Lead", target);
          if (window.__chat && window.__chat.sendTemplateTo) window.__chat.sendTemplateTo(target, t);
          else { toast('"' + (t && t.n ? t.n : "Template") + '" sent to ' + L.name); }
        }
      });
    }
  }

  /* ---- Send Template panel: primary lead + up to 3 extra recipients ---- */
  function ensureStStyle() {
    if (document.getElementById("lx-sendtpl-style")) return;
    var s = document.createElement("style"); s.id = "lx-sendtpl-style";
    s.textContent =
      ".lx-select{padding-right:36px;text-overflow:ellipsis;}" +
      ".st-toprow{display:flex;align-items:center;gap:10px;flex-wrap:wrap;margin-bottom:12px;}" +
      ".st-pick{display:inline-flex;align-items:center;gap:8px;border:0;border-radius:11px;padding:11px 16px;font-family:inherit;font-size:14px;font-weight:600;color:#fff;background:#3DC838;cursor:pointer;}.st-pick svg{width:17px;height:17px;}" +
      ".st-status{font-size:12px;font-weight:600;color:var(--ink-2,#4d5d52);border:1px solid var(--line,#eef1ec);border-radius:8px;padding:6px 10px;}" +
      ".st-tplprev{font-size:12.5px;font-weight:500;color:var(--ink-2,#4d5d52);background:var(--tint-50,#eaf9e6);border:1px solid var(--tint-border,#cdeac4);border-radius:10px;padding:10px 12px;margin-bottom:12px;line-height:1.45;white-space:pre-wrap;}" +
      ".st-lbl{display:block;font-size:12.5px;font-weight:600;color:var(--ink,#15231a);margin:6px 0 7px;}" +
      ".st-rechd{margin-top:16px;}" +
      ".st-addrec{display:inline-flex;align-items:center;gap:7px;border:1.5px dashed var(--tint-border,#cdeac4);background:var(--surface-2,#fbfdfa);color:var(--eva-green-deep,#177a36);border-radius:11px;padding:10px 14px;font-family:inherit;font-size:13px;font-weight:600;cursor:pointer;margin:8px 0 12px;}.st-addrec svg{width:15px;height:15px;}.st-addrec:disabled{opacity:.5;cursor:default;}" +
      ".st-rec{border:1px solid var(--line,#eef1ec);border-radius:14px;padding:12px;margin-bottom:10px;display:flex;flex-direction:column;gap:9px;}" +
      ".st-recline{display:flex;gap:8px;align-items:center;}.st-ccwrap{flex:0 0 42%;min-width:0;}.st-recline select{width:100%;}.st-rmob{flex:1;min-width:0;}" +
      ".st-recdel{flex:0 0 auto;width:40px;height:40px;border:1px solid var(--line,#eef1ec);background:#fff;border-radius:10px;color:#EF5350;display:grid;place-items:center;cursor:pointer;}.st-recdel svg{width:17px;height:17px;}" +
      ".st-recchk{display:flex;align-items:center;gap:8px;font-size:13px;font-weight:600;color:var(--ink-2,#4d5d52);cursor:pointer;}.st-recchk input{width:18px;height:18px;accent-color:var(--eva-green,#3cc23f);}" +
      ".st-foot{display:flex;gap:10px;justify-content:flex-end;margin-top:16px;}.st-foot .lx-btn{flex:0 0 auto;display:inline-flex;align-items:center;justify-content:center;gap:8px;padding:13px 20px;font-size:14px;line-height:1;}.st-foot .lx-btn svg{width:17px;height:17px;flex:0 0 auto;}";
    document.head.appendChild(s);
  }
  ensureStStyle();
  function openSendTemplate(L) {
    ensureStStyle();
    var PLUSI = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round"><path d="M12 5v14M5 12h14"/></svg>';
    var SENDI = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 12h14m0 0-5-5m5 5-5 5"/></svg>';
    var stTpl = null, recips = [];
    function ccOpts(sel) { return window.AskEvaCCOptions ? window.AskEvaCCOptions(sel || "+91", { format: function (n, c) { return c + "  " + n; } }) : '<option>+91</option>'; }
    function validRecips() { return recips.filter(function (r) { return _digits(r.mobile).length >= 6; }); }
    function sendCount() { return 1 + recips.length; }
    function sendLabel() { return SENDI + 'Send to (' + sendCount() + ')'; }
    function recHTML(r, i) {
      return '<div class="st-rec">' +
        '<input class="lx-input st-rname" data-i="' + i + '" placeholder="Name" value="' + esc(r.name || "") + '">' +
        '<div class="st-recline"><div class="st-ccwrap"><select class="lx-select st-rcc" data-i="' + i + '">' + ccOpts(r.cc) + '</select></div>' +
          '<input class="lx-input st-rmob" data-i="' + i + '" inputmode="numeric" placeholder="Mobile Number" value="' + esc(r.mobile || "") + '">' +
          '<button class="st-recdel" data-del="' + i + '" aria-label="Remove">' + I.trash + '</button></div>' +
        '<label class="st-recchk"><input type="checkbox" data-lead="' + i + '"' + (r.lead ? " checked" : "") + '><span>Create as Lead</span></label>' +
      '</div>';
    }
    function render() {
      var st = (STATUS[L.status] || {}).label || L.status || "—";
      tplPanel.innerHTML =
        '<div class="lx-pbar"><button class="back" data-x>' + I.back + '</button><span class="ptt">Send Template</span></div>' +
        '<div class="lx-pbody" style="padding:16px 16px 110px">' +
          '<div class="st-toprow"><button class="st-pick" data-pick>' + I.template + (stTpl ? esc(stTpl.n || "Template") : "Select Template") + '</button>' +
            '<span class="st-status">Status: ' + esc(st) + '</span></div>' +
          (stTpl ? '<div class="st-tplprev">' + esc(stTpl.p || "") + '</div>' : '') +
          '<label class="st-lbl">Primary Mobile Number</label>' +
          '<input class="lx-input" disabled value="' + esc((L.countryCode || "+91") + " " + (L.mobile || "")) + '">' +
          '<div class="st-rechd"><span class="st-lbl" style="margin:0">Additional Recipients</span></div>' +
          '<button class="st-addrec" data-add' + (recips.length >= 3 ? ' disabled' : '') + '>' + PLUSI + 'Add Recipient</button>' +
          '<div id="stList">' + recips.map(recHTML).join("") + '</div>' +
          '<div class="st-foot"><button class="lx-btn ghost" data-reset>Reset</button>' +
            '<button class="lx-btn primary" data-send>' + sendLabel() + '</button></div>' +
        '</div>';
      wire();
    }
    function wire() {
      $("[data-x]", tplPanel).addEventListener("click", function () { closePanel(tplPanel); });
      $("[data-pick]", tplPanel).addEventListener("click", function () {
        if (window.AskEvaTemplates && window.AskEvaTemplates.open) window.AskEvaTemplates.open({ title: "Select template", fields: function () { return window.AskEvaLeadFields && AskEvaLeadFields.mapFields(); }, onSend: function (t) { stTpl = t; render(); } });
      });
      var add = $("[data-add]", tplPanel); if (add) add.addEventListener("click", function () { if (recips.length < 3) { recips.push({ name: "", cc: "+91", mobile: "", lead: false }); render(); } });
      $$("[data-del]", tplPanel).forEach(function (b) { b.addEventListener("click", function () { recips.splice(+b.getAttribute("data-del"), 1); render(); }); });
      $$(".st-rname", tplPanel).forEach(function (inp) { inp.addEventListener("input", function () { recips[+inp.getAttribute("data-i")].name = inp.value; }); });
      $$(".st-rcc", tplPanel).forEach(function (sel) { sel.value = recips[+sel.getAttribute("data-i")].cc || "+91"; sel.addEventListener("change", function () { recips[+sel.getAttribute("data-i")].cc = sel.value; }); });
      $$(".st-rmob", tplPanel).forEach(function (inp) { inp.addEventListener("input", function () { recips[+inp.getAttribute("data-i")].mobile = _digits(inp.value); var c = $("[data-send]", tplPanel); if (c) c.innerHTML = sendLabel(); }); });
      $$("[data-lead]", tplPanel).forEach(function (c) { c.addEventListener("change", function () { recips[+c.getAttribute("data-lead")].lead = c.checked; }); });
      $("[data-reset]", tplPanel).addEventListener("click", function () { stTpl = null; recips = []; render(); });
      $("[data-send]", tplPanel).addEventListener("click", doSend);
    }
    function doSend() {
      if (!stTpl) { toast("Select a template first"); return; }
      var targets = [{ name: L.name, phone: L.mobile }];
      validRecips().forEach(function (r) { targets.push({ name: r.name || "Recipient", phone: _digits(r.cc) + _digits(r.mobile) }); });
      validRecips().forEach(function (r) {
        if (r.lead && window.AskEvaAddLead) window.AskEvaAddLead({ name: r.name || "New contact", countryCode: r.cc || "+91", mobile: _digits(r.mobile), status: "new", source: "Template", assigned: (window.AskEvaNextAgent ? window.AskEvaNextAgent() : ""), description: "Created from Send Template" });
      });
      targets.forEach(function (tg) { if (window.__chat && window.__chat.sendTemplateTo) window.__chat.sendTemplateTo(tg, stTpl); });
      logActivity(L, { type: "message", text: "Template sent: " + (stTpl.n || "") + " · " + targets.length + " recipient" + (targets.length > 1 ? "s" : ""), module: "Leads" });
      if (window.AskEvaLeadsChanged) window.AskEvaLeadsChanged("update");
      closePanel(tplPanel);
      toast("Template sent to " + targets.length + " recipient" + (targets.length > 1 ? "s" : ""));
    }
    render();
    openPanel(tplPanel);
  }
  function openNotes(L) {
    L._notes = L._notes || [];
    var NTI = {
      Text: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="M8 13s1.5 2 4 2 4-2 4-2M9 9h.01M15 9h.01"/></svg>',
      Audio: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="9" y="3" width="6" height="11" rx="3"/><path d="M5 11a7 7 0 0 0 14 0M12 18v3"/></svg>',
      Image: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="4" width="18" height="16" rx="2.5"/><circle cx="8.5" cy="9.5" r="1.6"/><path d="m4 17 5-5 4 4 3-3 4 4"/></svg>',
      Video: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="6" width="13" height="12" rx="2.5"/><path d="m16 10 5-3v10l-5-3z"/></svg>',
      Document: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14 3H7a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V8z"/><path d="M14 3v5h5M9 13h6M9 17h4"/></svg>'
    };
    var UPLOAD = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 16V5m0 0 4 4m-4-4-4 4"/><path d="M5 16v2.5A1.5 1.5 0 0 0 6.5 20h11a1.5 1.5 0 0 0 1.5-1.5V16"/></svg>';
    // accepted upload formats per note type (drives the OS file picker filter)
    var ACCEPT = {
      Audio: ".mp3,.ogg,audio/mpeg,audio/ogg",
      Image: "image/*",
      Video: ".mp4,video/mp4",
      Document: ".csv,.doc,.docx,.xls,.xlsx,.ppt,.pptx,.pdf,.txt,text/csv,text/plain,application/pdf,application/msword,application/vnd.openxmlformats-officedocument.wordprocessingml.document,application/vnd.ms-excel,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet,application/vnd.ms-powerpoint,application/vnd.openxmlformats-officedocument.presentationml.presentation"
    };
    // hard validation (accept= is only a hint; this actually rejects e.g. .exe)
    var VALID = {
      Audio: /\.(mp3|ogg)$/i,
      Image: /\.(jpe?g|png|gif|webp|bmp|svg|heic|heif|tiff?|avif)$/i,
      Video: /\.(mp4)$/i,
      Document: /\.(csv|docx?|xlsx?|pptx?|pdf|txt)$/i
    };
    var ACCEPT_HINT = {
      Audio: "MP3 or OGG",
      Image: "JPG, PNG, GIF, WebP, SVG…",
      Video: "MP4",
      Document: "CSV, Word, Excel, PPT, PDF or TXT"
    };
    var TYPES = ["Text", "Audio", "Image", "Video", "Document"];
    var curType = "Text";
    function listHTML() {
      if (!L._notes.length) return '<div class="rm-empty">No notes found</div>';
      return L._notes.map(function (n, i) {
        return '<div class="nt-item"><span class="nt-ic ' + n.type.toLowerCase() + '">' + (NTI[n.type] || NTI.Text) + '</span>' +
          '<div class="nt-main"><div class="nt-content">' + esc(n.content) + '</div><div class="nt-meta">' + n.type + ' &middot; ' + esc(n.when) + '</div></div>' +
          '<button class="rm-del" data-ntdel="' + i + '" aria-label="Delete">' + I.trash + '</button></div>';
      }).join("");
    }
    sheetShell("Add New Note",
      '<div class="lx-field"><label>Select Note Type</label>' +
        '<div class="nt-types" id="ntTypes">' + TYPES.map(function (t) {
          return '<button class="nt-type' + (t === curType ? " on" : "") + '" data-nt="' + t + '">' + NTI[t] + '<span>' + t + '</span>' +
            (t === curType && t !== "Text" ? '<i class="nt-x" data-ntx title="Clear selection"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="M18 6 6 18M6 6l12 12"/></svg></i>' : '') + '</button>';
        }).join("") + '</div></div>' +
      '<div id="ntInput"></div>' +
      '<div class="nt-allhd">' + I.note + 'All Notes <span id="ntCount">(' + L._notes.length + ')</span></div>' +
      '<div id="ntList" class="rm-list">' + listHTML() + '</div>',
      '<button class="lx-btn primary" data-add>Add Note</button>');
    function renderInput() {
      var box = $("#ntInput", sheet);
      if (curType === "Text") {
        box.innerHTML = '<div class="lx-field"><textarea class="lx-textarea" id="ntText" placeholder="Enter your note here…"></textarea></div>';
      } else if (curType === "Audio" && window.AskEvaAudioNote) {
        box.innerHTML = '<div class="lx-field">' + window.AskEvaAudioNote.blockHTML() + '</div>';
        window.AskEvaAudioNote.wire(box, { toast: toast });
      } else {
        box.innerHTML = '<div class="lx-field"><label class="nt-upload" id="ntUpWrap">' +
          '<input type="file" id="ntFile" accept="' + (ACCEPT[curType] || "") + '" hidden>' +
          '<span class="nt-uptext" id="ntUpText">' + UPLOAD + 'Choose ' + curType.toLowerCase() + ' file</span></label>' +
          '<div class="af-uphint">Accepted: ' + (ACCEPT_HINT[curType] || "") + '</div></div>';
        $("#ntFile", sheet).addEventListener("change", function () {
          var f = this.files && this.files[0];
          if (!f) return;
          var rule = VALID[curType];
          if (rule && !rule.test(f.name)) {
            this.value = "";
            $("#ntUpText", sheet).innerHTML = UPLOAD + 'Choose ' + curType.toLowerCase() + ' file';
            $("#ntUpWrap", sheet).classList.remove("has");
            toast("Unsupported file \u2014 accepted: " + (ACCEPT_HINT[curType] || ""));
            return;
          }
          $("#ntUpText", sheet).innerHTML = (NTI[curType] || "") + '<span class="fn">' + esc(f.name) + '</span>';
          $("#ntUpWrap", sheet).classList.add("has");
        });
      }
    }
    function bindDel() {
      $$("[data-ntdel]", sheet).forEach(function (b) {
        b.addEventListener("click", function () {
          L._notes.splice(+b.getAttribute("data-ntdel"), 1); saveLeads();
          $("#ntList", sheet).innerHTML = listHTML(); $("#ntCount", sheet).textContent = "(" + L._notes.length + ")"; bindDel();
        });
      });
    }
    function renderTypes() {
      var box = $("#ntTypes", sheet); if (!box) return;
      box.innerHTML = TYPES.map(function (t) {
        return '<button class="nt-type' + (t === curType ? " on" : "") + '" data-nt="' + t + '">' + NTI[t] + '<span>' + t + '</span>' +
          (t === curType && t !== "Text" ? '<i class="nt-x" data-ntx title="Clear selection"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="M18 6 6 18M6 6l12 12"/></svg></i>' : '') + '</button>';
      }).join("");
      bindTypes();
    }
    function bindTypes() {
      $$("[data-nt]", sheet).forEach(function (b) {
        b.addEventListener("click", function (e) {
          if (e.target.closest("[data-ntx]")) {
            curType = "Text"; if (window.AskEvaAudioNote) window.AskEvaAudioNote.clear(); renderTypes(); renderInput(); return;
          }
          curType = b.getAttribute("data-nt"); if (window.AskEvaAudioNote) window.AskEvaAudioNote.clear(); renderTypes(); renderInput();
        });
      });
    }
    bindTypes();
    renderInput(); bindDel();
    $("[data-add]", sheet).addEventListener("click", function () {
      var content = "";
      if (curType === "Text") {
        content = $("#ntText", sheet).value.trim();
        if (!content) { toast("Write a note first"); return; }
      } else if (curType === "Audio") {
        var r = window.AskEvaAudioNote && window.AskEvaAudioNote.result();
        if (!r) { toast("Record or choose an audio file"); return; }
        content = r.name;
      } else {
        var f = $("#ntFile", sheet);
        if (!f || !f.files || !f.files.length) { toast("Choose a " + curType.toLowerCase() + " file"); return; }
        content = f.files[0].name;
      }
      L._notes.unshift({ type: curType, content: content, when: fmtDate(fmtNow()) });
      logActivity(L, { type: "note", text: curType + " note added" + (curType === "Text" ? ": " + (content.length > 50 ? content.slice(0, 50) + "\u2026" : content) : " (" + content + ")"), module: "Leads" });
      saveLeads();
      $("#ntList", sheet).innerHTML = listHTML(); $("#ntCount", sheet).textContent = "(" + L._notes.length + ")"; bindDel();
      curType = "Text";
      if (window.AskEvaAudioNote) window.AskEvaAudioNote.clear();
      renderTypes();
      renderInput();
      toast("Note added");
    });
  }
  function openActivity(L) {
    // render the REAL per-lead activity feed (status/agent changes, notes,
    // follow-ups + cross-module chat/appointment/ticket events), newest first.
    var acts = (L.activity || []).map(function (e) {
      var m = actMeta(e.type);
      return { t: e.text || "Activity", s: e.module || "Leads", time: (e.ts || "").split(" ")[0] || (e.ts || ""), i: m.ic };
    });
    if (!acts.length) {
      // fall back to the lead's origin so the sheet is never empty
      acts = [{ t: L.description || "Lead created", s: "via " + L.source, time: fmtDate(L.created).split(" · ")[0], i: I.activity }];
    }
    sheetShell("Activity logs · " + L.name,
      acts.map(function (a) { return '<div class="lx-row"><span class="ri">' + a.i + '</span><div><div class="rt">' + esc(a.t) + '</div><div class="rs">' + esc(a.s) + '</div></div><span class="rtime">' + esc(a.time) + '</span></div>'; }).join(""));
  }
  function openCalls(L) {
    var calls = [
      { t: "Outgoing call", s: "2 min 14 sec", time: "Yesterday", i: I.calllog },
      { t: "Missed call", s: L.mobile, time: "3 days ago", i: I.phone },
      { t: "Incoming call", s: "5 min 02 sec", time: "Last week", i: I.phone }
    ];
    sheetShell("Call logs · " + L.name,
      calls.map(function (a) { return '<div class="lx-row"><span class="ri">' + a.i + '</span><div><div class="rt">' + a.t + '</div><div class="rs">' + a.s + '</div></div><span class="rtime">' + a.time + '</span></div>'; }).join(""));
  }

  /* ===================== DETAIL PAGE ===================== */
  function field(ic, k, v, cls) {
    return '<div class="lx-dfield"><span class="fi">' + ic + '</span><div class="fc"><div class="fk">' + k + '</div><div class="fv ' + (cls || "") + '">' + v + '</div></div></div>';
  }
  function openDetail(id) {
    var L = leadById(id); if (!L) return;
    var assigned = L.assigned || "Unassigned";
    var tags = L.tags && L.tags.length ? '<div class="lx-dtags">' + L.tags.map(function (t) { return '<span>' + t + '</span>'; }).join("") + '</div>' : '<span class="muted">—</span>';
    var converted = L.status === "converted";
    var fups = L._followups || [];
    var fupsHTML = fups.length ? '<div class="lx-dsec">Follow-ups</div><div class="lx-dcard">' +
      fups.map(function (f) { return field(I.remind, f.t, f.w + (f.note ? ' \u00b7 ' + f.note : '')); }).join("") + '</div>' : '';
    var acts = L.activity || [];
    var actSection = '<div class="lx-dsec">Activity timeline</div><div class="lx-dcard lx-tl">' +
      (acts.length ? acts.map(function (a) { var m = actMeta(a.type); return '<div class="lx-tlitem ' + m.cls + '"><span class="lx-tlic">' + m.ic + '</span><div class="lx-tlc"><div class="lx-tlt">' + esc(a.text) + '</div><div class="lx-tlm">' + esc(a.module || "") + ' \u00b7 ' + fmtDate(a.ts) + '</div></div></div>'; }).join("")
        : '<div class="lx-tlempty">No activity yet. Chats, appointments, tickets, notes and follow-ups will appear here.</div>') +
      '</div>';
    detailPanel.innerHTML =
      '<div class="lx-pbar"><button class="back" data-back>' + I.back + '</button><span class="ptt">Lead Details</span></div>' +
      '<div class="lx-pbody" style="padding:0 0 100px">' +
        '<div class="lx-dhero">' + avHTML(L).replace("lx-av", "lx-av") +
          '<div style="flex:1;min-width:0"><div class="dn">' + L.name + '</div>' +
            (L.subtitle ? '<div class="dsub">' + L.subtitle + '</div>' : '') +
            '<div class="dbadge">' + badge(L.status) + (converted ? '<span class="lx-custtag"><span class="dot"></span>Customer</span>' : '') + '</div></div></div>' +
        '<div class="lx-dquick">' +
          '<button data-dq="call">' + I.phone + 'Call</button>' +
          '<button data-dq="wa">' + I.chat + 'Chat</button>' +
          '<button data-dq="template">' + I.template + 'Template</button>' +
          '<button data-dq="notes">' + I.note + 'Notes</button>' +
        '</div>' +
        '<div style="padding:0 16px">' +
          '<div class="lx-dsec">Lead info</div><div class="lx-dcard">' +
            field(I.tag, "Status", badge(L.status)) +
            field(I.source, "Source", dash(L.source)) +
            field(I.user, "Assigned to", dash(assigned), L.assigned ? "" : "muted") +
            field(I.cash, "Lead value", L.value ? "₹" + L.value : "—", L.value ? "" : "muted") +
            field(I.tag, "Tags", tags) +
          '</div>' +
          fupsHTML +
          actSection +
          '<div class="lx-dsec">Contact</div><div class="lx-dcard">' +
            field(I.phone, "Mobile", dash(L.mobile)) +
            field(I.mail, "Email", dash(L.email), L.email ? "link" : "muted") +
            field(I.globe, "Website", L.website ? L.website : "—", L.website ? "link" : "muted") +
          '</div>' +
          '<div class="lx-dsec">Company</div><div class="lx-dcard">' +
            field(I.building, "Company", companyName(L.company), L.company ? "" : "muted") +
          '</div>' +
          '<div class="lx-dsec">Location</div><div class="lx-dcard">' +
            field(I.pin, "Address", dash(L.address), L.address ? "" : "muted") +
            field(I.pin, "City", dash(L.city), L.city ? "" : "muted") +
            field(I.globe, "Country", dash(L.country), L.country ? "" : "muted") +
          '</div>' +
          '<div class="lx-dsec">Description</div><div class="lx-dcard"><div class="lx-dbody">' + (L.description || "—") + '</div></div>' +
          '<div class="lx-dsec">Custom fields</div><div class="lx-dcard">' +
            field(I.doc, "test", dash(L.cf_test), L.cf_test ? "" : "muted") +
            field(I.doc, "username", dash(L.cf_username), L.cf_username ? "" : "muted") +
          '</div>' +
          '<div class="lx-dsec">Timeline</div><div class="lx-dcard">' +
            field(I.clock, "Created at", fmtDate(L.created)) +
            field(I.clock, "Updated at", fmtDate(L.updated)) +
          '</div>' +
        '</div>' +
      '</div>' +
      '<div class="lx-pfoot">' +
        (converted ? '' : '<button class="lx-btn primary" data-convert2>Convert as customer</button>') +
        '<button class="lx-btn ghost" data-edit2>Edit lead</button>' +
      '</div>';
    $("[data-back]", detailPanel).addEventListener("click", function () { closePanel(detailPanel); });
    $$("[data-edit],[data-edit2]", detailPanel).forEach(function (b) { b.addEventListener("click", function () { openForm(L); }); });
    $$("[data-dq]", detailPanel).forEach(function (b) {
      b.addEventListener("click", function () {
        var q = b.getAttribute("data-dq");
        if (q === "call") openCallScreen(L);
        else if (q === "wa") { closePanel(detailPanel); if (window.__openChatFrom) window.__openChatFrom("leads", null, "Lead", { name: L.name, phone: L.mobile }); else if (window.__appRoute) { window.__appRoute("chats"); if (window.__chat && window.__chat.openWith) window.__chat.openWith(L.name, L.mobile); } }
        else if (q === "template") openSendTemplate(L);
        else if (q === "notes") openNotes(L);
      });
    });
    var cv2 = $("[data-convert2]", detailPanel);
    if (cv2) cv2.addEventListener("click", function () { L.status = "converted"; logActivity(L, { type: "status", text: "Status changed to Customer", module: "Leads" }); createCustomerRecord(L); renderLeads(); closePanel(detailPanel); toast(L.name + " marked as Won"); });
    $(".lx-pbody", detailPanel).scrollTop = 0;
    openPanel(detailPanel);
  }

  /* ===================== CUSTOMERS PANEL (per company) ===================== */
  function openCustomers(coName) {
    var leads = companyGroups().filter(function (g) { return g.name === coName; })[0];
    leads = leads ? leads.leads : [];
    custPanel.innerHTML =
      '<div class="lx-pbar"><button class="back" data-back>' + I.back + '</button><span class="ptt">' + I.building + coName + '</span></div>' +
      '<div class="lx-pbody"><div class="lx-countrow"><span class="c">' + leads.length + (leads.length === 1 ? " customer" : " customers") + '</span></div>' +
        leads.map(cardHTML).join("") + '</div>';
    $("[data-back]", custPanel).addEventListener("click", function () { closePanel(custPanel); });
    $$(".lx-card", custPanel).forEach(function (c) {
      c.addEventListener("click", function (e) {
        if (e.target.closest("[data-dots]")) { openQuick(c.getAttribute("data-id")); return; }
        openFollowup(c.getAttribute("data-id"));
      });
    });
    openPanel(custPanel);
  }

  /* ===================== CUSTOMER FOLLOW-UP POPUP ===================== */
  var TKT = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 7a2 2 0 0 1 2-2h12a2 2 0 0 1 2 2v2a2 2 0 0 0 0 6v2a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2v-2a2 2 0 0 0 0-6z"/><path d="M14 5v14" stroke-dasharray="2 2"/></svg>';
  var CAL = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="5" width="18" height="16" rx="2.5"/><path d="M3 10h18M8 3v4M16 3v4"/></svg>';
  function openFollowup(id) {
    var L = leadById(id); if (!L) return;
    var conv = L.status === "converted" ? fmtDate(L.updated) : "—";
    var closedBy = L.assigned || "—";
    function item(ic, k, v, cls, wide) {
      return '<div class="lx-fuitem' + (wide ? " wide" : "") + '"><span class="fi">' + ic + '</span><div style="min-width:0"><div class="k">' + k + '</div><div class="v ' + (cls || "") + '">' + v + '</div></div></div>';
    }
    var AXref = window.AX;
    var tickets = ticketsForCustomer(L);
    var realAppts = apptsForCustomer(L);
    var followups = (L._followups || []);
    var openCount = tickets.filter(function (t) { return t.status !== "resolved"; }).length;
    var resolvedCount = tickets.filter(function (t) { return t.status === "resolved"; }).length;
    function tRow(t) {
      var open = t.status !== "resolved";
      return '<div class="lx-row"><span class="ri">' + TKT + '</span><div style="min-width:0"><div class="rt">' + esc(t.num || "") + '</div><div class="rs">' + esc(t.subject || "") + '</div></div>' +
        '<span class="lx-badge ' + (open ? "negotiation" : "won") + '"><span class="d"></span>' + esc(t.status || (open ? "open" : "resolved")) + '</span></div>';
    }
    function aRow(a) {
      var dep = AXref && AXref.deptById ? AXref.deptById(a.department) : { name: a.department };
      var tm = AXref && AXref.fmtTime ? AXref.fmtTime(a.time).full : "";
      var done = a.status === "completed", cancel = a.status === "cancelled";
      return '<div class="lx-row"><span class="ri">' + CAL + '</span><div style="min-width:0"><div class="rt">' + esc((dep && dep.name) || "Appointment") + '</div><div class="rs">' + esc(a.date + (tm ? " \u00b7 " + tm : "")) + '</div></div>' +
        '<span class="lx-badge ' + (done ? "won" : cancel ? "lost" : "meeting") + '"><span class="d"></span>' + (done ? "Completed" : cancel ? "Cancelled" : "Upcoming") + '</span></div>';
    }
    function fuRow(a) {
      return '<div class="lx-row"><span class="ri">' + CAL + '</span><div style="min-width:0"><div class="rt">' + esc(a.t) + '</div><div class="rs">' + esc(a.w) + '</div></div>' +
        '<span class="lx-badge ' + (a.ok ? "won" : "meeting") + '"><span class="d"></span>' + (a.ok ? "Confirmed" : "Pending") + '</span></div>';
    }
    var tkEmpty = '<div style="padding:13px 4px;font-size:12.5px;font-weight:600;color:var(--ink-3,#8A978D)">No tickets for this customer.</div>';
    var apEmpty = '<div style="padding:13px 4px;font-size:12.5px;font-weight:600;color:var(--ink-3,#8A978D)">No appointments for this customer.</div>';
    openSheet(
      '<div class="lx-shead"><span class="tt">Follow-up</span><button class="x" data-x>' + I.x + '</button></div>' +
      '<div class="lx-sbody">' +
        '<div class="lx-qhead">' + avHTML(L) +
          '<div style="min-width:0"><div class="qn">' + L.name + '</div>' + (L.subtitle ? '<div class="qm">' + L.subtitle + '</div>' : '') + '</div>' +
          '<div style="margin-left:auto">' + badge(L.status) + '</div></div>' +
        '<div class="lx-fugrid">' +
          item(I.mail, "Email", dash(L.email), L.email ? "" : "muted", true) +
          item(I.clock, "Conversion date", conv, conv === "—" ? "muted" : "") +
          item(I.source, "Source", dash(L.source)) +
          item(I.building, "Company", companyName(L.company), L.company ? "" : "muted") +
          item(I.phone, "Mobile", dash(L.mobile)) +
          item(I.user, "Lead closed by", closedBy, L.assigned ? "" : "muted") +
          item(I.tag, "Status", (STATUS[L.status] || STATUS["new"]).label) +
        '</div>' +
        '<div class="lx-fusec">' + TKT + 'Tickets</div>' +
        '<div class="lx-fucard">' + (tickets.length ? '<div class="lx-fustat"><span><b>' + openCount + '</b>Open</span><span><b>' + resolvedCount + '</b>Resolved</span></div>' + tickets.map(tRow).join("") : tkEmpty) + '</div>' +
        '<div class="lx-fusec">' + CAL + 'Appointments</div>' +
        '<div class="lx-fucard">' + ((realAppts.length || followups.length) ? (realAppts.map(aRow).join("") + followups.map(fuRow).join("")) : apEmpty) + '</div>' +
      '</div>' +
      '<div class="lx-sfoot"><button class="lx-btn ghost" data-prof>Full profile</button><button class="lx-btn primary" data-fu>Add follow-up</button></div>'
    );
    $("[data-x]", sheet).addEventListener("click", closeSheet);
    $("[data-prof]", sheet).addEventListener("click", function () { closeSheet(); setTimeout(function () { openDetail(L.id); }, 200); });
    $("[data-fu]", sheet).addEventListener("click", function () { openAddFollowup(L); });
  }

  function openAddFollowup(L) {
    var types = ["Call", "Meeting", "WhatsApp", "Email"];
    sheetShell("Add follow-up",
      '<div style="font-size:13px;font-weight:600;color:var(--ink-3);margin-bottom:16px">Schedule a follow-up with <b style="color:var(--ink)">' + L.name + '</b></div>' +
      '<label class="lx-clabel">Type</label>' +
      '<div class="lx-chiprow" style="margin-bottom:16px">' + types.map(function (t, i) { return '<button class="lx-pick' + (i === 0 ? " on" : "") + '" data-ft="' + t + '">' + t + '</button>'; }).join("") + '</div>' +
      '<label class="lx-clabel">Date &amp; time</label>' +
      '<input class="lx-input" type="datetime-local" id="fuTime" style="margin-bottom:16px">' +
      '<label class="lx-clabel">Note <span style="font-weight:600;text-transform:none;letter-spacing:0;color:var(--ink-4)">(optional)</span></label>' +
      '<textarea class="lx-textarea" id="fuNote" placeholder="What\u2019s this follow-up about?"></textarea>',
      '<button class="lx-btn primary" data-save>Schedule follow-up</button>');
    var type = "Call";
    var inp = $("#fuTime", sheet);
    var d = new Date(Date.now() + 864e5); d.setSeconds(0, 0);
    inp.value = new Date(d.getTime() - d.getTimezoneOffset() * 60000).toISOString().slice(0, 16);
    $$(".lx-pick", sheet).forEach(function (b) {
      b.addEventListener("click", function () {
        $$(".lx-pick", sheet).forEach(function (x) { x.classList.remove("on"); });
        b.classList.add("on"); type = b.getAttribute("data-ft");
      });
    });
    $("[data-save]", sheet).addEventListener("click", function () {
      var v = $("#fuTime", sheet).value;
      if (!v) { toast("Pick a date & time first"); return; }
      var note = ($("#fuNote", sheet).value || "").trim();
      L._followups = L._followups || [];
      L._followups.unshift({ t: type + " follow-up", w: fmtCustom(v), ok: false, note: note });
      logActivity(L, { type: "followup", text: type + " follow-up scheduled \u00b7 " + fmtCustom(v), module: "Leads" });
      closeSheet();
      setTimeout(function () { openFollowup(L.id); toast(type + " follow-up scheduled \u00b7 " + fmtCustom(v), 3000); }, 220);
    });
  }

  /* ===================== FILTER PANEL ===================== */
  function readPanel() {
    return {
      status: $("#lxStatus", filterPanel).value,
      source: $("#lxSource", filterPanel).value,
      assigned: $("#lxAssigned", filterPanel).value,
      industry: $("#lxIndustry", filterPanel).value,
      company: $("#lxCompany", filterPanel).value,
      period: $("#lxPeriod", filterPanel).value,
      start: state.f.start || "",
      end: state.f.end || ""
    };
  }
  function buildFilterPanel() {
    function sel(id, label, opts, val) {
      return '<div class="lx-ffield"><label>' + label + '</label><select class="lx-select" id="' + id + '">' +
        opts.map(function (o) { return '<option value="' + o.v + '"' + (o.v === val ? " selected" : "") + '>' + o.t + '</option>'; }).join("") + '</select></div>';
    }
    var statusOpts = [{ v: "all", t: "All Status" }].concat(Object.keys(STATUS).map(function (k) { return { v: k, t: STATUS[k].label }; }));
    var srcOpts = [{ v: "all", t: "All Sources" }].concat(SOURCES.map(function (s) { return { v: s, t: s }; }));
    var agentOpts = [{ v: "all", t: "All Agents" }].concat(leadAgents().filter(function (a) { return a.email; }).map(function (a) { return { v: a.email, t: a.name }; })).concat([{ v: "Unassigned", t: "Unassigned" }]);
    var indOpts = [{ v: "all", t: "All Industries" }].concat(INDUSTRIES.map(function (s) { return { v: s, t: s }; }));
    var coOpts = [{ v: "all", t: "All Companies" }].concat(companyList().map(function (s) { return { v: s, t: s }; }));
    var periodOpts = ["Last 7 days", "Last 30 days", "Last 90 days", "This year", "All time"].map(function (p) { return { v: p, t: p }; });

    filterPanel.innerHTML =
      '<div class="lx-pbar"><button class="x" data-x>' + I.x + '</button><span class="ptt">' + I.funnel + 'Filters</span></div>' +
      '<div class="lx-pbody">' +
        '<div class="lx-ffield"><label>Created Date Range</label><div id="lxFilterDatePill"></div></div>' +
        sel("lxPeriod", "Time Period", periodOpts, state.f.period) +
        '<div class="lx-twocol">' + sel("lxIndustry", "Industry", indOpts, state.f.industry) + sel("lxCompany", "Company", coOpts, state.f.company) + '</div>' +
        sel("lxAssigned", "Assigned To", agentOpts, state.f.assigned) +
        sel("lxSource", "Lead Source", srcOpts, state.f.source) +
        sel("lxStatus", "Lead Status", statusOpts, state.f.status) +
      '</div>' +
      '<div class="lx-pfoot"><button class="lx-btn ghost" data-clearall>Clear All</button><button class="lx-btn primary" data-apply>Apply Filters</button></div>';

    $("[data-x]", filterPanel).addEventListener("click", function () { closePanel(filterPanel); });
    (function () {
      var pill = $("#lxFilterDatePill", filterPanel);
      if (pill && window.AskEvaPicker && AskEvaPicker.rangePill) {
        AskEvaPicker.rangePill(pill, { start: state.f.start || "", end: state.f.end || "", onChange: function (r) {
          state.f.start = r.start || ""; state.f.end = r.end || "";
        } });
      }
    })();
    $("[data-clearall]", filterPanel).addEventListener("click", function () {
      state.f = Object.assign({}, FDEFAULT);
      buildFilterPanel(); renderLeads(); toast("Filters cleared");
    });
    $("[data-apply]", filterPanel).addEventListener("click", function () {
      state.f = Object.assign(state.f, readPanel());
      closePanel(filterPanel); renderLeads();
      var n = activeFilters().length;
      toast(n ? n + " filter" + (n > 1 ? "s" : "") + " applied" : "Showing all leads");
    });
  }

  /* ===================== NEW / EDIT LEAD FORM ===================== */
  function openForm(edit) {
    var L = edit || {};
    var isEdit = !!edit;
    var agents = leadAgents().filter(function (a) { return a.email; });
    var companies = (function () { var seen = {}, out = []; LEADS.forEach(function (x) { var c = (x.company || "").trim(); if (c && !seen[c]) { seen[c] = 1; out.push(c); } }); return out; })();
    var CODES = (window.AskEvaCC && window.AskEvaCC.length) ? window.AskEvaCC.map(function (p) { return [p[1], p[1] + "  " + p[0]]; }) : [["+91", "+91  India"], ["+1", "+1  USA"], ["+44", "+44  UK"], ["+971", "+971  UAE"], ["+61", "+61  Australia"], ["+65", "+65  Singapore"]];
    var PLUS = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round"><path d="M12 5v14M5 12h14"/></svg>';
    var tags = (L.tags || []).slice();
    var defCode = L.countryCode || (isEdit ? "" : "+91");
    var LF = window.AskEvaLeadFields;
    function shown(n) { return !LF || LF.shown(n); }
    function rq(n) { return !!(LF && LF.required(n)); }
    function star(n) { return rq(n) ? ' <span class="req">*</span>' : ""; }
    var nlAlert = (window.AskEvaLeadConfig && window.AskEvaLeadConfig.alerts().newlead) || { on: true, template: "" };

    function fld(id, label, val, ph, type, req) {
      return '<div class="lx-field"><label>' + label + (req ? ' <span class="req">*</span>' : "") + '</label>' +
        '<input class="lx-input" id="' + id + '" type="' + (type || "text") + '" value="' + esc(val || "") + '" placeholder="' + esc(ph || "") + '"></div>';
    }
    function opt(v, t, sel, dis) { return '<option value="' + esc(v) + '"' + (sel ? " selected" : "") + (dis ? " disabled" : "") + '>' + esc(t) + '</option>'; }

    /* custom fields are driven by Settings → Lead Fields (anything not a built-in).
       Honor Display/Mandatory toggles, additions and deletions, live. */
    var BUILTIN_FIELDS = ["Name", "Company", "Email", "Status", "Source", "Assigned", "Position", "Country Code", "Mobile", "Product", "Address", "City", "Country", "Website", "Lead Value", "Tags", "Description"];
    function cfKey(n) { return "cf_" + String(n).toLowerCase().replace(/[^a-z0-9]+/g, "_").replace(/^_|_$/g, ""); }
    function customFields() { return (LF ? LF.list() : []).filter(function (f) { return BUILTIN_FIELDS.indexOf(f.n) < 0; }); }
    function customFieldsHTML() {
      return customFields().filter(function (f) { return f.disp !== false; }).map(function (f) {
        var key = cfKey(f.n), id = "lf_" + key, val = L[key], req = !!f.mand, st = req ? ' <span class="req">*</span>' : "";
        var ph = "Enter " + f.n.toLowerCase();
        if (f.t === "Textarea") return '<div class="lx-field"><label>' + esc(f.n) + st + '</label><textarea class="lx-textarea" id="' + id + '" placeholder="' + esc(ph) + '">' + esc(val || "") + '</textarea></div>';
        if (f.t === "Dropdown" || f.t === "Select") {
          var dopts = (window.AskEvaLeadDropdowns && AskEvaLeadDropdowns.options(f.n)) || [];
          var oh = '<option value="">' + esc("Select " + f.n.toLowerCase()) + '</option>' +
            dopts.map(function (o) { return '<option value="' + esc(o) + '"' + (val === o ? " selected" : "") + '>' + esc(o) + '</option>'; }).join("");
          return '<div class="lx-field"><label>' + esc(f.n) + st + '</label><select class="lx-select" id="' + id + '">' + oh + '</select></div>';
        }
        var type = f.t === "Number" ? "number" : (f.t === "Date" ? "date" : "text");
        return '<div class="lx-field"><label>' + esc(f.n) + st + '</label><input class="lx-input" id="' + id + '" type="' + type + '" value="' + esc(val || "") + '" placeholder="' + esc(ph) + '"></div>';
      }).join("");
    }

    var hasAssignee = !!L.assigned;
    var statusOpts = opt("", hasAssignee ? "Select status" : "Select status (assign lead first)", !L.status, true) +
      Object.keys(STATUS).map(function (k) { return opt(k, STATUS[k].label, L.status === k); }).join("");
    var sourceOpts = opt("", "Select source", !L.source, true) + SOURCES.map(function (s) { return opt(s, s, L.source === s); }).join("");
    var assignOpts = opt("", "Select assigned person", !L.assigned, true) + agents.map(function (a) { return opt(a.email, a.name, L.assigned === a.email); }).join("");
    var asLabel = (agents.filter(function (a) { return a.email === L.assigned; })[0] || {}).name || "Select assigned person";
    var codeOpts = opt("", "Select code", !defCode, true) + CODES.map(function (c) { return opt(c[0], c[1], defCode === c[0]); }).join("");

    var CHEV = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="m6 9 6 6 6-6"/></svg>';
    var SRCH = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><circle cx="11" cy="11" r="7"/><path d="M21 21l-4.3-4.3"/></svg>';
    var companyHTML = '<div class="lx-field"><label>Company' + star("Company") + '</label>' +
      '<div class="lf-codd" id="lfCoDD">' +
        '<input type="hidden" id="lfCompany" value="' + esc(L.company || "") + '">' +
        '<button type="button" class="lx-input lf-codd-trig' + (L.company ? '' : ' ph') + '" id="lfCoTrig">' +
          '<span class="val">' + esc(L.company || "Select or search company") + '</span>' + CHEV +
        '</button>' +
        '<div class="lf-codd-panel" id="lfCoPanel" hidden>' +
          '<div class="lf-codd-srch">' + SRCH + '<input type="text" id="lfCoSearch" placeholder="Search company" autocomplete="off"></div>' +
          '<div class="lf-codd-list" id="lfCoList"></div>' +
          '<div class="lf-codd-add"><input type="text" id="lfCoNew" placeholder="Enter Company Name" autocomplete="off"><button type="button" id="lfCoAdd">' + PLUS + 'Add</button></div>' +
        '</div>' +
      '</div></div>';

    sheetShell((isEdit ? "Edit Lead" : "Add New Lead"),
      '<div class="lx-field"><label>Status <span class="req">*</span></label>' +
        '<select class="lx-select" id="lfStatus"' + (hasAssignee ? "" : " disabled") + '>' + statusOpts + '</select>' +
        '<div class="lx-hint bad" id="lfStatusHint"' + (hasAssignee ? ' style="display:none"' : "") + '>Please assign a person before selecting status</div></div>' +
      '<div class="lx-twocol">' +
        '<div class="lx-field"><label>Source <span class="req">*</span></label><select class="lx-select" id="lfSource">' + sourceOpts + '</select></div>' +
        '<div class="lx-field"><label>Assigned <span class="req">*</span></label>' +
          '<div class="lf-codd" id="lfAsDD">' +
            '<input type="hidden" id="lfAssigned" value="' + esc(L.assigned || "") + '">' +
            '<button type="button" class="lx-input lf-codd-trig' + (L.assigned ? '' : ' ph') + '" id="lfAsTrig">' +
              '<span class="val">' + esc(asLabel) + '</span>' + CHEV +
            '</button>' +
            '<div class="lf-codd-panel" id="lfAsPanel" hidden>' +
              '<div class="lf-codd-srch">' + SRCH + '<input type="text" id="lfAsSearch" placeholder="Search person" autocomplete="off"></div>' +
              '<div class="lf-codd-list" id="lfAsList"></div>' +
            '</div>' +
          '</div></div>' +
      '</div>' +
      (shown("Tags") ? '<div class="lx-field"><label>Tags' + star("Tags") + '</label>' +
        '<div class="lf-tagadd"><input class="lx-input" id="lfTagInput" placeholder="Add tag"><button type="button" class="lf-tagbtn" id="lfTagAdd" aria-label="Add tag">' + PLUS + '</button></div>' +
        '<div class="lf-tags" id="lfTags"></div></div>' : "") +
      fld("lfName", "Name", L.name, "Enter name", "text", true) +
      (shown("Company") ? companyHTML : "") +
      (shown("Position") ? fld("lfPosition", "Position", L.position, "Enter position", "text", rq("Position")) : "") +
      '<div class="lx-twocol">' +
        '<div class="lx-field"><label>Country Code <span class="req">*</span></label><select class="lx-select" id="lfCode">' + codeOpts + '</select></div>' +
        '<div class="lx-field"><label>Mobile Number <span class="req">*</span></label><input class="lx-input" id="lfMobile" inputmode="numeric" value="' + esc(L.mobile || "") + '" placeholder="Enter mobile number (digits only)"></div>' +
      '</div>' +
      (shown("Email") ? fld("lfEmail", "Email Address", L.email, "Enter email address", "email", rq("Email")) : "") +
      (shown("Address") ? '<div class="lx-field"><label>Address' + star("Address") + '</label><textarea class="lx-textarea" id="lfAddress" placeholder="Enter address">' + esc(L.address || "") + '</textarea></div>' : "") +
      (shown("Website") ? fld("lfWebsite", "Website", L.website, "Enter website URL", "text", rq("Website")) : "") +
      (shown("City") ? fld("lfCity", "City", L.city, "Enter city", "text", rq("City")) : "") +
      (shown("Lead Value") ? fld("lfValue", "Lead Value", L.value, "Enter lead value", "text", rq("Lead Value")) : "") +
      (shown("Country") ? fld("lfCountry", "Country", L.country, "Enter country", "text", rq("Country")) : "") +
      (shown("Description") ? '<div class="lx-field"><label>Description' + star("Description") + '</label><textarea class="lx-textarea" id="lfDesc" maxlength="200" placeholder="Enter description">' + esc(L.description || "") + '</textarea><div class="lf-counter"><span id="lfDescCount">' + (L.description || "").length + '</span>/200</div></div>' : "") +
      customFieldsHTML() +
      ((isEdit || !nlAlert.on) ? "" : '<label class="lf-alert"><input type="checkbox" id="lfAlert"><span class="lf-alertbody"><span class="t">Send new lead alert message to this lead</span><span class="s">This will send the \u201c' + esc(nlAlert.template || "welcome") + '\u201d template to the new lead.</span></span></label>'),
      '<button class="lx-btn ghost" data-x2>Cancel</button><button class="lx-btn primary" data-save>' + (isEdit ? "Save changes" : "Add Lead") + '</button>');

    // --- Status gating on Assigned ---
    var statusSel = $("#lfStatus", sheet), hint = $("#lfStatusHint", sheet);
    $("#lfAssigned", sheet).addEventListener("change", function () {
      var has = !!this.value;
      statusSel.disabled = !has;
      hint.style.display = has ? "none" : "";
      if (!has) statusSel.value = "";
    });
    // --- mobile digits only ---
    $("#lfMobile", sheet).addEventListener("input", function () { this.value = this.value.replace(/\D/g, ""); });
    // --- description counter (Description may be hidden by settings) ---
    var desc = $("#lfDesc", sheet), dc = $("#lfDescCount", sheet);
    if (desc && dc) desc.addEventListener("input", function () { dc.textContent = this.value.length; });
    // --- tags (Tags may be hidden by settings) ---
    function renderTags() {
      var host = $("#lfTags", sheet); if (!host) return;
      host.innerHTML = tags.map(function (t, i) {
        return '<span class="lf-tag">' + esc(t) + '<button type="button" data-tagrm="' + i + '" aria-label="Remove">' + I.x + '</button></span>';
      }).join("");
      $$("[data-tagrm]", sheet).forEach(function (b) { b.addEventListener("click", function () { tags.splice(+b.getAttribute("data-tagrm"), 1); renderTags(); }); });
    }
    function addTag() {
      var inp = $("#lfTagInput", sheet); if (!inp) return; var v = inp.value.trim();
      if (!v) return; if (tags.indexOf(v) < 0) tags.push(v); inp.value = ""; renderTags(); inp.focus();
    }
    if ($("#lfTagAdd", sheet)) {
      $("#lfTagAdd", sheet).addEventListener("click", addTag);
      $("#lfTagInput", sheet).addEventListener("keydown", function (e) { if (e.key === "Enter") { e.preventDefault(); addTag(); } });
      renderTags();
    }

    // --- Company custom dropdown (search + pick + add; empty-state when none) ---
    (function () {
      var dd = $("#lfCoDD", sheet); if (!dd) return;
      var trig = $("#lfCoTrig", sheet), panel = $("#lfCoPanel", sheet), hid = $("#lfCompany", sheet);
      var listEl = $("#lfCoList", sheet), srch = $("#lfCoSearch", sheet), newInp = $("#lfCoNew", sheet), addBtn = $("#lfCoAdd", sheet);
      var coList = companies.slice();
      function setVal(v) {
        hid.value = v;
        $(".val", trig).textContent = v || "Select or search company";
        trig.classList.toggle("ph", !v);
      }
      function renderList() {
        var q = (srch.value || "").trim().toLowerCase();
        var rows = coList.filter(function (c) { return !q || c.toLowerCase().indexOf(q) >= 0; });
        if (!coList.length) {
          listEl.innerHTML = '<div class="lf-codd-empty">' + SRCH + '<div class="t">No companies registered yet</div><div class="s">Add your first company below — it’ll be saved with this lead.</div></div>';
          return;
        }
        if (!rows.length) { listEl.innerHTML = '<div class="lf-codd-none">No match for “' + esc(srch.value) + '”</div>'; return; }
        listEl.innerHTML = rows.map(function (c) {
          return '<button type="button" class="lf-codd-opt' + (hid.value === c ? ' on' : '') + '" data-co="' + esc(c) + '">' + esc(c) + '</button>';
        }).join("");
        $$(".lf-codd-opt", listEl).forEach(function (b) {
          b.addEventListener("click", function () { setVal(b.getAttribute("data-co")); close(); });
        });
      }
      function open() { panel.hidden = false; trig.classList.add("open"); renderList(); setTimeout(function () { srch.focus(); }, 30); }
      function close() { panel.hidden = true; trig.classList.remove("open"); }
      function addNew() {
        var v = (newInp.value || "").trim(); if (!v) { newInp.focus(); return; }
        if (!coList.some(function (c) { return c.toLowerCase() === v.toLowerCase(); })) coList.unshift(v);
        setVal(v); newInp.value = ""; close();
      }
      trig.addEventListener("click", function (e) { e.stopPropagation(); panel.hidden ? open() : close(); });
      srch.addEventListener("input", renderList);
      srch.addEventListener("keydown", function (e) { if (e.key === "Enter") { e.preventDefault(); var first = $(".lf-codd-opt", listEl); if (first) first.click(); } });
      addBtn.addEventListener("click", addNew);
      newInp.addEventListener("keydown", function (e) { if (e.key === "Enter") { e.preventDefault(); addNew(); } });
      dd.addEventListener("click", function (e) { e.stopPropagation(); });
      sheet.addEventListener("click", function () { if (!panel.hidden) close(); });
    })();

    // --- Assigned custom dropdown (search + pick; contained + scrollable) ---
    (function () {
      var dd = $("#lfAsDD", sheet); if (!dd) return;
      var trig = $("#lfAsTrig", sheet), panel = $("#lfAsPanel", sheet), hid = $("#lfAssigned", sheet);
      var listEl = $("#lfAsList", sheet), srch = $("#lfAsSearch", sheet);
      function setVal(email, name) {
        hid.value = email;
        $(".val", trig).textContent = name || "Select assigned person";
        trig.classList.toggle("ph", !email);
        hid.dispatchEvent(new Event("change", { bubbles: true }));
      }
      function renderList() {
        var q = (srch.value || "").trim().toLowerCase();
        var rows = agents.filter(function (a) { return !q || a.name.toLowerCase().indexOf(q) >= 0; });
        if (!rows.length) { listEl.innerHTML = '<div class="lf-codd-none">No match for “' + esc(srch.value) + '”</div>'; return; }
        listEl.innerHTML = rows.map(function (a) {
          return '<button type="button" class="lf-codd-opt' + (hid.value === a.email ? ' on' : '') + '" data-email="' + esc(a.email) + '" data-name="' + esc(a.name) + '">' + esc(a.name) + '</button>';
        }).join("");
        $$(".lf-codd-opt", listEl).forEach(function (b) {
          b.addEventListener("click", function () { setVal(b.getAttribute("data-email"), b.getAttribute("data-name")); close(); });
        });
      }
      function open() { panel.hidden = false; trig.classList.add("open"); renderList(); setTimeout(function () { srch.focus(); }, 30); }
      function close() { panel.hidden = true; trig.classList.remove("open"); }
      trig.addEventListener("click", function (e) { e.stopPropagation(); panel.hidden ? open() : close(); });
      srch.addEventListener("input", renderList);
      srch.addEventListener("keydown", function (e) { if (e.key === "Enter") { e.preventDefault(); var first = $(".lf-codd-opt", listEl); if (first) first.click(); } });
      dd.addEventListener("click", function (e) { e.stopPropagation(); });
      sheet.addEventListener("click", function () { if (!panel.hidden) close(); });
    })();

    $("[data-x2]", sheet).addEventListener("click", closeSheet);
    $("[data-save]", sheet).addEventListener("click", function () {
      function v(id) { var e = $("#" + id, sheet); return e ? e.value.trim() : ""; }
      // hidden fields keep their previous value instead of being wiped
      function g(name, id, prev) { return shown(name) ? v(id) : (prev || ""); }
      var assigned = v("lfAssigned"), status = statusSel.value, source = v("lfSource"),
          name = v("lfName"), code = v("lfCode"), mobile = v("lfMobile");
      if (!assigned) { toast("Select an assigned person"); return; }
      if (!status) { toast("Select a status"); statusSel.focus(); return; }
      if (!source) { toast("Select a source"); return; }
      if (!name) { toast("Enter a name"); $("#lfName", sheet).focus(); return; }
      if (!code) { toast("Select a country code"); return; }
      if (!mobile) { toast("Enter a mobile number"); $("#lfMobile", sheet).focus(); return; }
      // optional fields that Settings marked Required must be filled (reflects config)
      var optReq = [["Website", "lfWebsite", "website"], ["Email", "lfEmail", "email address"], ["Company", "lfCompany", "company"],
        ["Position", "lfPosition", "position"], ["Address", "lfAddress", "address"], ["City", "lfCity", "city"],
        ["Lead Value", "lfValue", "lead value"], ["Country", "lfCountry", "country"], ["Description", "lfDesc", "description"]];
      for (var r = 0; r < optReq.length; r++) {
        var nm = optReq[r][0], id = optReq[r][1];
        if (shown(nm) && rq(nm) && !v(id)) { toast("Enter " + optReq[r][2]); var el = $("#" + id, sheet); if (el) el.focus(); return; }
      }
      // custom fields that Settings marked Required must be filled
      var _cfs = customFields();
      for (var cr = 0; cr < _cfs.length; cr++) {
        var cf = _cfs[cr]; if (cf.disp !== false && cf.mand) { var cel = $("#lf_" + cfKey(cf.n), sheet); if (cel && !cel.value.trim()) { toast("Enter " + cf.n); cel.focus(); return; } }
      }
      var data = {
        name: name, assigned: assigned, status: status, source: source, countryCode: code, mobile: mobile,
        company: g("Company", "lfCompany", L.company), position: g("Position", "lfPosition", L.position),
        email: g("Email", "lfEmail", L.email), address: g("Address", "lfAddress", L.address),
        website: g("Website", "lfWebsite", L.website), city: g("City", "lfCity", L.city),
        value: g("Lead Value", "lfValue", L.value), country: g("Country", "lfCountry", L.country),
        description: g("Description", "lfDesc", L.description),
        tags: shown("Tags") ? tags.slice() : (L.tags || [])
      };
      // dynamic custom field values (reflect Settings → Lead Fields; hidden ones keep prior value)
      customFields().forEach(function (f) {
        var key = cfKey(f.n);
        if (f.disp === false) { data[key] = L[key] || ""; return; }
        var el = $("#lf_" + key, sheet); data[key] = el ? el.value.trim() : (L[key] || "");
      });
      if (isEdit) {
        var _old = L.status;
        for (var k in data) L[k] = data[k];
        if (_old !== L.status) logActivity(L, { type: "status", text: "Status changed to " + ((STATUS[L.status] || {}).label || L.status), module: "Leads" });
        else logActivity(L, { type: "updated", text: "Lead details updated", module: "Leads" });
        closeSheet(); emitLeadsChanged("update"); renderLeads(); if (detailPanel.classList.contains("show")) openDetail(L.id); toast("Lead updated");
      } else {
        var now = new Date(), pad = function (n) { return (n < 10 ? "0" : "") + n; };
        var ds = pad(now.getDate()) + "-" + pad(now.getMonth() + 1) + "-" + now.getFullYear() + " " + pad(now.getHours()) + ":" + pad(now.getMinutes());
        var _nl = Object.assign({ id: "lead" + Date.now(), subtitle: "", created: ds, updated: ds }, data);
        LEADS.unshift(_nl);
        logActivity(_nl, { type: "created", text: "Lead created manually", module: "Leads" });
        var alertOn = $("#lfAlert", sheet) && $("#lfAlert", sheet).checked;
        if (alertOn) {
          logActivity(_nl, { type: "message", text: "Alert sent: " + (nlAlert.template || "welcome"), module: "Leads" });
          // deliver the configured New-Lead template into the lead's chat (as a template)
          if (window.__chat && window.__chat.postApptAlert) {
            var _tn = nlAlert.template || "Welcome message";
            var _tl = ((window.AskEvaTemplates && AskEvaTemplates.list()) || []).filter(function (x) { return x.n === _tn; })[0];
            var _body = String((_tl ? _tl.p : "Hi! Thanks for connecting with us."))
              .replace(/\{\{\s*Name\s*\}\}/gi, _nl.name || "there").replace(/\{\{\s*1\s*\}\}/g, _nl.name || "");
            window.__chat.postApptAlert({ name: _nl.name, phone: _nl.mobile }, { n: _tn, text: _body, cat: (_tl && _tl.cat) || "Marketing" });
          }
        }
        closeSheet(); state.tab = "leads"; emitLeadsChanged("create"); renderLeads();
        toast(name + " added" + (alertOn ? ' \u00b7 "' + (nlAlert.template || "welcome") + '" sent' : ""));
      }
    });
  }

  /* ===================== SELECTION MODE ===================== */
  var selbar = $("#lxSelbar", pane);
  function updateSel() {
    var ids = Object.keys(state.selected).filter(function (k) { return state.selected[k]; });
    $("#lxSelN", pane).textContent = ids.length + " selected";
    selbar.classList.toggle("show", state.selMode);
    var up = $('[data-sel="update"]', selbar), del = $('[data-sel="delete"]', selbar), all = $('[data-sel="all"]', selbar);
    if (up) up.disabled = ids.length === 0;
    if (del) del.disabled = ids.length === 0;
    var total = filtered().length;
    if (all) all.classList.toggle("on", total > 0 && ids.length === total);
    var selall = $('[data-act="selall"] .lx-sallbl', pane);
    if (selall) selall.textContent = (total > 0 && ids.length === total) ? "Deselect all" : "Select all";
  }
  function toggleSelMode(on) {
    state.selMode = on; if (!on) state.selected = {};
    if (on && state.view !== "list") {
      state.view = "list";
      $$("#lxViewSeg [data-view]", pane).forEach(function (x) { x.classList.toggle("on", x.getAttribute("data-view") === "list"); });
    }
    pane.classList.toggle("selmode", on);
    var chip = $('[data-act="select"]', pane);
    if (chip) {
      chip.classList.toggle("on", on);
      var lbl = $(".lx-sellbl", chip), ic = $(".lx-selic", chip);
      if (lbl) lbl.textContent = on ? "Cancel" : "Select";
      if (ic) ic.innerHTML = on ? I.x : I.check2;
    }
    renderLeads(); updateSel();
  }
  // Select all / Deselect all (top toolbar, Contacts-style)
  function selectAllToggle() {
    if (!state.selMode) { toggleSelMode(true); }
    var rows = filtered();
    var allSel = rows.length > 0 && rows.every(function (L) { return state.selected[L.id]; });
    state.selected = {};
    if (!allSel) rows.forEach(function (L) { state.selected[L.id] = true; });
    renderLeads(); updateSel();
  }
  $$("[data-sel]", selbar).forEach(function (b) {
    b.addEventListener("click", function () {
      var a = b.getAttribute("data-sel");
      var ids = Object.keys(state.selected).filter(function (k) { return state.selected[k]; });
      if (a === "cancel") { toggleSelMode(false); return; }
      if (a === "all") {
        var rows = filtered();
        var allSel = rows.length > 0 && rows.every(function (L) { return state.selected[L.id]; });
        state.selected = {};
        if (!allSel) rows.forEach(function (L) { state.selected[L.id] = true; });
        renderLeads(); updateSel(); return;
      }
      if (a === "update") { if (ids.length) openBulkUpdate(ids); return; }
      if (a === "delete") {
        if (!ids.length) return;
        confirmModal(
          "Delete " + ids.length + " lead" + (ids.length > 1 ? "s" : "") + "?",
          "This permanently removes " + (ids.length > 1 ? "these leads" : "this lead") + " and their activity. This can't be undone.",
          "Delete",
          function () {
            var removed = captureRemoved(function (L) { return state.selected[L.id]; });
            var keep = LEADS.filter(function (L) { return !state.selected[L.id]; });
            LEADS.length = 0; Array.prototype.push.apply(LEADS, keep);   // mutate in place so window.AskEvaLeads stays the single source of truth
            emitLeadsChanged("delete"); updateLeadBadges();
            deletedStash = removed; recordTombstones(removed);
            showUndo(ids.length + " lead" + (ids.length > 1 ? "s" : "") + " deleted");
            toggleSelMode(false);
          }
        );
      }
    });
  });

  /* ===================== BULK UPDATE ===================== */
  function openBulkUpdate(ids) {
    var agents = leadAgents().filter(function (a) { return a.email; });
    var statusOpts = Object.keys(STATUS).map(function (k) { return '<option value="' + k + '">' + STATUS[k].label + '</option>'; }).join("");
    var agentOpts = agents.map(function (a) { return '<option value="' + a.email + '">' + a.name + '</option>'; }).join("");
    openSheet(
      '<div class="lx-shead"><span class="bu-hicon">' + I.edit + '</span><span class="tt">Bulk Update \u00b7 ' + ids.length + ' selected</span><button class="x" data-x>' + I.x + '</button></div>' +
      '<div class="lx-sbody">' +
        '<div class="lx-field"><label>Update Status</label>' +
          '<select class="lx-select" id="buStatus" disabled><option value="" selected disabled>First select an assignee</option>' + statusOpts + '</select>' +
          '<div class="lx-hint bad" id="buHint">Please select an assignee first to enable status update</div></div>' +
        '<div class="lx-field"><label>Change Assigned To</label>' +
          '<select class="lx-select" id="buAssign"><option value="" selected disabled>Select assigned person (required)</option>' + agentOpts + '</select></div>' +
        '<div class="bu-summary"><div class="t">Update Summary</div><div class="s" id="buSum">No updates selected. Choose an assignee or status above.</div></div>' +
      '</div>' +
      '<div class="lx-sfoot two">' +
        '<button class="lx-btn ghost" data-x>Cancel</button>' +
        '<button class="lx-btn primary" id="buApply" disabled>Apply Changes</button>' +
      '</div>'
    );
    $$("[data-x]", sheet).forEach(function (b) { b.addEventListener("click", closeSheet); });
    var as = $("#buAssign", sheet), stt = $("#buStatus", sheet), hint = $("#buHint", sheet), apply = $("#buApply", sheet), sum = $("#buSum", sheet);
    function refresh() {
      var hasA = !!as.value;
      stt.disabled = !hasA;
      if (hasA) { hint.style.display = "none"; } else { hint.style.display = ""; stt.value = ""; }
      var hasS = !!stt.value;
      var parts = [];
      if (hasA) { var nm = (agents.filter(function (a) { return a.email === as.value; })[0] || {}).name || as.value; parts.push("Assign to <b>" + nm + "</b>"); }
      if (hasS) { parts.push("Set status to <b>" + STATUS[stt.value].label + "</b>"); }
      sum.innerHTML = parts.length ? parts.map(function (p) { return "\u2022 " + p; }).join("<br>") : "No updates selected. Choose an assignee or status above.";
      apply.disabled = parts.length === 0;
    }
    as.addEventListener("change", refresh);
    stt.addEventListener("change", refresh);
    apply.addEventListener("click", function () {
      var asg = as.value, stv = stt.value;
      ids.forEach(function (id) {
        var L = leadById(id); if (!L) return;
        if (stv && L.status !== stv) { L.status = stv; logActivity(L, { type: "status", text: "Status changed to " + STATUS[stv].label, module: "Leads" }); }
        if (asg) { L.assigned = asg; logActivity(L, { type: "updated", text: "Assigned to " + asg.split("@")[0], module: "Leads" }); }
      });
      emitLeadsChanged("bulk"); updateLeadBadges();
      closeSheet(); toggleSelMode(false);
      toast(ids.length + " lead" + (ids.length > 1 ? "s" : "") + " updated");
    });
    refresh();
  }
  function deleteLead(L) {
    var removed = captureRemoved(function (x) { return x.id === L.id; });
    var keep = LEADS.filter(function (x) { return x.id !== L.id; });
    LEADS.length = 0; Array.prototype.push.apply(LEADS, keep);
    emitLeadsChanged("delete"); updateLeadBadges();
    closeSheet(); renderLeads();
    deletedStash = removed; recordTombstones(removed);
    showUndo((L.name || "Lead") + " deleted");
  }

  /* ===================== EVENT WIRING ===================== */
  // tabs
  $$(".lx-tab", pane).forEach(function (t) {
    t.addEventListener("click", function () {
      var tab = t.getAttribute("data-tab");
      state.tab = tab;
      $$(".lx-tab", pane).forEach(function (x) { x.classList.toggle("active", x === t); });
      $$("[data-tab-body]", pane).forEach(function (b) { b.hidden = b.getAttribute("data-tab-body") !== tab; });
      $("#lxFab", pane).style.display = "";
      if (tab === "companies") renderCompanies($("#lxCoSearch", pane).value);
      if (tab === "customers") renderCustomers($("#lxCustSearch", pane).value);
      if (state.selMode) toggleSelMode(false);
    });
  });
  // search
  $("#lxSearch", pane).addEventListener("input", function () { state.query = this.value; renderLeads(); });
  $("#lxCoSearch", pane).addEventListener("input", function () { renderCompanies(this.value); });
  (function () { var cs = $("#lxCustSearch", pane); if (cs) cs.addEventListener("input", function () { renderCustomers(this.value); }); })();
  // filter button
  $("#lxFilterBtn", pane).addEventListener("click", function () { buildFilterPanel(); openPanel(filterPanel); });
  // list interactions (delegated)
  listEl.addEventListener("click", function (e) {
    var card = e.target.closest(".lx-card"); if (!card) return;
    var id = card.getAttribute("data-id");
    if (state.selMode) {
      state.selected[id] = !state.selected[id];
      card.classList.toggle("sel", !!state.selected[id]); updateSel(); return;
    }
    if (e.target.closest("[data-dots]")) { openQuick(id); return; }
    openQuick(id);
  });
  // action chips
  $$('[data-act]', pane).forEach(function (b) {
    b.addEventListener("click", function () {
      var a = b.getAttribute("data-act");
      if (a === "select") { toggleSelMode(!state.selMode); return; }
      if (a === "selall") { selectAllToggle(); return; }
      if (a === "sync") { openSync(); return; }
      // export / sample / import are handled for real by leads-interactions.js (CSV download + file import)
      if (a === "refreshco") { renderCompanies($("#lxCoSearch", pane).value); toast("Companies refreshed"); return; }
      if (a === "refreshcust") { renderCustomers($("#lxCustSearch", pane).value); toast("Customers refreshed"); return; }
    });
  });
  // view toggle (List / Kanban)
  $$("#lxViewSeg [data-view]", pane).forEach(function (b) {
    b.addEventListener("click", function () {
      var v = b.getAttribute("data-view");
      if (v === state.view) return;
      state.view = v;
      $$("#lxViewSeg [data-view]", pane).forEach(function (x) { x.classList.toggle("on", x === b); });
      if (v === "kanban" && state.selMode) { toggleSelMode(false); return; }
      renderLeads();
    });
  });
  // kanban board interactions (delegated)
  var boardEl = $("#lxBoard", pane);
  if (boardEl) {
    /* Pointer-based drag — native HTML5 DnD breaks inside the CSS-scaled device
       frame (the drag ghost escapes the phone screen and drop hit-testing fails)
       and doesn't work on touch. This maps the pointer into the scaled screen
       and uses elementFromPoint for the drop target, so it works on mouse + touch
       and the lifted card stays clipped inside the phone. */
    var kdrag = null, suppressClick = false;
    function scaleHost() {
      var h = document.getElementById("screen") || document.querySelector(".device-screen") || boardEl;
      var rect = h.getBoundingClientRect();
      var sc = h.offsetWidth ? (rect.width / h.offsetWidth) : 1;
      return { el: h, rect: rect, scale: sc || 1 };
    }
    function colUnder(x, y) {
      var g = kdrag && kdrag.ghost, prev = g ? g.style.visibility : "";
      if (g) g.style.visibility = "hidden";
      var el = document.elementFromPoint(x, y);
      if (g) g.style.visibility = prev;
      return el && el.closest ? el.closest(".lx-kcol") : null;
    }
    boardEl.addEventListener("pointerdown", function (e) {
      if (e.pointerType === "mouse" && e.button !== 0) return;
      var c = e.target.closest(".lx-kcard"); if (!c || c.classList.contains("locked")) return;
      var rect = c.getBoundingClientRect();
      kdrag = { id: c.getAttribute("data-id"), card: c, started: false, pid: e.pointerId,
        sx: e.clientX, sy: e.clientY, offX: e.clientX - rect.left, offY: e.clientY - rect.top,
        ghost: null, overCol: null };
    });
    window.addEventListener("pointermove", function (e) {
      if (!kdrag) return;
      if (!kdrag.started) {
        if (Math.abs(e.clientX - kdrag.sx) < 6 && Math.abs(e.clientY - kdrag.sy) < 6) return;
        kdrag.started = true; dragId = kdrag.id; kdrag.card.classList.add("dragging");
        var host = scaleHost(); kdrag.host = host.el; kdrag.rect = host.rect; kdrag.scale = host.scale;
        var g = kdrag.card.cloneNode(true);
        g.className = kdrag.card.className.replace("dragging", "").trim() + " kc-ghost";
        g.style.cssText = "position:absolute;margin:0;z-index:9999;pointer-events:none;width:" + kdrag.card.offsetWidth + "px;left:0;top:0;";
        kdrag.host.appendChild(g); kdrag.ghost = g;
        try { kdrag.card.setPointerCapture(e.pointerId); } catch (_) {}
      }
      e.preventDefault();
      var lx = (e.clientX - kdrag.rect.left) / kdrag.scale - kdrag.offX;
      var ly = (e.clientY - kdrag.rect.top) / kdrag.scale - kdrag.offY;
      kdrag.ghost.style.left = lx + "px"; kdrag.ghost.style.top = ly + "px";
      var col = colUnder(e.clientX, e.clientY), L0 = leadById(dragId);
      var blocked = col && L0 && L0.status === "converted" && col.getAttribute("data-st") !== "converted";
      kdrag.overCol = blocked ? null : col;
      $$(".lx-kcol", boardEl).forEach(function (x) { x.classList.toggle("over", x === kdrag.overCol); });
    }, { passive: false });
    function endDrag(commit) {
      if (!kdrag) return;
      var d = kdrag; kdrag = null;
      if (!d.started) return;                       // a tap → let click open the card
      if (d.ghost) d.ghost.remove();
      d.card.classList.remove("dragging");
      $$(".lx-kcol", boardEl).forEach(function (x) { x.classList.remove("over"); });
      suppressClick = true; setTimeout(function () { suppressClick = false; }, 60);
      if (commit && d.overCol) {
        var L = leadById(d.id), ns = d.overCol.getAttribute("data-st");
        if (L && ns && L.status !== ns) {
          if (L.status === "converted") { toast("Customers can\u2019t be moved to another status"); dragId = null; return; }
          L.status = ns;
          logActivity(L, { type: "status", text: "Status changed to " + ((STATUS[ns] || {}).label || ns), module: "Leads" });
          if (ns === "converted") createCustomerRecord(L);
          emitLeadsChanged("status"); updateLeadBadges();
          toast(L.name + " \u2192 " + ((STATUS[ns] || {}).label || ns));
        }
      }
      dragId = null;
    }
    window.addEventListener("pointerup", function () { endDrag(true); });
    window.addEventListener("pointercancel", function () { endDrag(false); });
    boardEl.addEventListener("click", function (e) {
      if (suppressClick) { suppressClick = false; return; }
      var c = e.target.closest(".lx-kcard"); if (!c) return;
      openQuick(c.getAttribute("data-id"));
    });
  }
  // FAB
  $("#lxFab", pane).addEventListener("click", function () { openForm(null); });

  /* ===================== SYNC + CALL SCREEN (added) ===================== */
  function fmtNow() { var d = new Date(); function p(n) { return (n < 10 ? "0" : "") + n; } return p(d.getDate()) + "-" + p(d.getMonth() + 1) + "-" + d.getFullYear() + " " + p(d.getHours()) + ":" + p(d.getMinutes()); }
  function fmtCustom(v) {
    var d = new Date(v); if (isNaN(d)) return v;
    var mo = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    var h = d.getHours(), ap = h < 12 ? "AM" : "PM", h12 = h % 12 || 12, mm = (d.getMinutes() < 10 ? "0" : "") + d.getMinutes();
    return d.getDate() + " " + mo[d.getMonth()] + " " + d.getFullYear() + " \u00b7 " + h12 + ":" + mm + " " + ap;
  }

  /* Manual sync pulls ONLY "UI contacts" (inbound-first WhatsApp senders — the
     UI-Contacts list). Every other source already auto-syncs into Leads. */
  var SYNC_POOL = [
    { name: "Arjun Pillai", mobile: "919840012233", source: "User Initiated - Whatsapp", channel: "WhatsApp (UI Contact)" },
    { name: "Sneha Rao", mobile: "918765012345", source: "User Initiated - Whatsapp", channel: "WhatsApp (UI Contact)" },
    { name: "Vikram Sethi", mobile: "917012998877", source: "User Initiated - Whatsapp", channel: "WhatsApp (UI Contact)" }
  ];
  var syncRun = 0;
  function _syncDigits(s) { return String(s == null ? "" : s).replace(/\D/g, ""); }
  // Inbound-first chat contacts = the UI-Contacts list. Manual sync imports only these.
  function uiContactsForSync() {
    var list = (window.__chat && window.__chat.contacts) || [];
    return list.filter(function (c) {
      if (!c || c.group || c.broadcast || c.blocked) return false;
      var fm = (c.thread || []).filter(function (m) { return m && m.dir; })[0];
      return fm ? fm.dir === "in" : true;   // inbound-first
    }).map(function (c) {
      return { name: c.name || _syncDigits(c.phone), mobile: _syncDigits(c.phone), source: "User Initiated - Whatsapp", channel: "WhatsApp (UI Contact)" };
    }).filter(function (c) { return c.mobile; });
  }
  function srcRow(name, desc) {
    return '<div class="lx-srcrow"><span class="ic">' + I.sync + '</span><div class="tx"><div class="n">' + name + '</div><div class="d">' + desc + '</div></div><span class="ck">' + I.check + '</span></div>';
  }
  function openSync() {
    openSheet(
      '<div class="lx-shead"><span class="tt">Sync UI contacts</span><button class="x" data-x>' + I.x + '</button></div>' +
      '<div class="lx-sbody"><div class="lx-syncwrap" id="lxSync">' +
        '<div class="lx-syncspin"></div>' +
        '<div class="lx-synctitle">Syncing UI contacts\u2026</div>' +
        '<div class="lx-syncsub">Pulling people who messaged you first. Other sources sync automatically.</div>' +
        '<div class="lx-syncsrc">' + srcRow("UI Contacts", "Reading inbound-first WhatsApp senders") + srcRow("Matching", "Skipping contacts already in Leads") + '</div>' +
      '</div></div>'
    );
    $("[data-x]", sheet).addEventListener("click", closeSheet);
    var rows = $$(".lx-srcrow", sheet);
    rows.forEach(function (r, i) { setTimeout(function () { r.classList.add("done"); }, 480 + i * 560); });
    setTimeout(finishSync, 480 + rows.length * 560 + 420);
  }
  function finishSync() {
    var existing = {}; LEADS.forEach(function (L) { existing[_syncDigits(L.mobile)] = 1; });
    // UI contacts: chats the user started in the Chat screen (queued) + every
    // inbound-first contact. Other sources are excluded — they auto-sync.
    var queued = (window.__pendingChatLeads || []).map(function (c) {
      return { name: c.name, mobile: _syncDigits(c.mobile), source: "User Initiated - Whatsapp", channel: "WhatsApp (UI Contact)" };
    });
    window.__pendingChatLeads = [];
    var found = queued.concat(uiContactsForSync()).filter(function (c) { return c.mobile && !existing[c.mobile]; });
    if (!found.length) found = SYNC_POOL.filter(function (c) { return !existing[_syncDigits(c.mobile)]; }).slice(0, 2);
    found = found.filter(function (c, i, a) { return a.findIndex(function (x) { return x.mobile === c.mobile; }) === i; });
    var now = fmtNow();
    found.forEach(function (c) {
      var _sl = { id: "sync" + (++syncRun) + "_" + Date.now(), name: c.name, subtitle: "", mobile: c.mobile, company: "", status: "new",
        source: c.source, assigned: "", email: "", created: now, updated: now, address: "", city: "", country: "",
        website: "", value: "", tags: [], description: "Synced from " + c.channel + " contact: " + c.name, cf_test: "", cf_username: "" };
      LEADS.unshift(_sl);
      logActivity(_sl, { type: "created", text: "Lead synced from " + c.source, module: "Leads" });
    });
    renderLeads(); updateLeadBadges();
    var wrap = $("#lxSync", sheet); if (!wrap) return;
    wrap.innerHTML =
      '<div class="lx-syncok">' + I.check + '</div>' +
      '<div class="lx-synctitle">' + (found.length ? "Sync complete" : "You\u2019re all caught up") + '</div>' +
      '<div class="lx-syncsub">' + (found.length ? found.length + " new lead" + (found.length === 1 ? "" : "s") + " added from UI Contacts" : "No new UI contacts to import right now") + '</div>' +
      (found.length ? '<div class="lx-syncfound">' + found.map(function (c) {
        return '<div class="lx-srcrow found"><span class="ic green">' + I.user + '</span><div class="tx"><div class="n">' + c.name + '</div><div class="d">' + c.mobile + ' \u00b7 ' + c.source + '</div></div></div>';
      }).join("") + '</div>' : "") +
      '<button class="lx-btn primary" data-syncdone style="margin-top:18px">' + (found.length ? "View leads" : "Done") + '</button>';
    $("[data-syncdone]", sheet).addEventListener("click", closeSheet);
  }

  /* ----- full-screen call ----- */
  var CIC = {
    mic: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="9" y="3" width="6" height="11" rx="3"/><path d="M5 11a7 7 0 0 0 14 0M12 18v3"/></svg>',
    speaker: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 9v6h4l5 4V5L8 9H4z"/><path d="M17 9a4 4 0 0 1 0 6M19.5 7a7 7 0 0 1 0 10"/></svg>',
    pad: '<svg viewBox="0 0 24 24" fill="currentColor"><circle cx="6" cy="6" r="1.7"/><circle cx="12" cy="6" r="1.7"/><circle cx="18" cy="6" r="1.7"/><circle cx="6" cy="12" r="1.7"/><circle cx="12" cy="12" r="1.7"/><circle cx="18" cy="12" r="1.7"/><circle cx="6" cy="18" r="1.7"/><circle cx="12" cy="18" r="1.7"/><circle cx="18" cy="18" r="1.7"/></svg>',
    add: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 5v14M5 12h14"/></svg>',
    hold: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M8 5v14M16 5v14"/></svg>',
    end: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 9c-2 0-3.9.3-5.6.9-.6.2-1 .8-1 1.4v2.1c0 .5.3.9.8 1l2.4.5c.5.1 1-.2 1.1-.7l.3-1.7c1.3-.4 2.7-.4 4 0l.3 1.7c.1.5.6.8 1.1.7l2.4-.5c.5-.1.8-.5.8-1v-2.1c0-.6-.4-1.2-1-1.4C15.9 9.3 14 9 12 9Z" transform="rotate(135 12 12)"/></svg>',
    back: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="m15 6-6 6 6 6"/></svg>'
  };
  function callBtn(k, label, ic) { return '<button class="cs-act" data-ca="' + k + '"><span class="ci">' + ic + '</span><span class="cl">' + label + '</span></button>'; }
  function host() { return document.getElementById("screen") || document.body; }
  function openCallScreen(L) {
    if (document.getElementById("callScreen")) return;
    var ov = document.createElement("div"); ov.id = "callScreen"; ov.className = "callscr";
    var face = isAlpha(L.name) ? initials(L.name) : I.wa;
    ov.innerHTML =
      '<div class="cs-grad"></div>' +
      '<div class="cs-head">' +
        '<button class="cs-min" data-end-min>' + CIC.back + '</button>' +
        '<div class="cs-status" id="csStatus">Calling\u2026</div>' +
        '<div class="cs-name">' + L.name + '</div>' +
        '<div class="cs-num">' + (L.mobile ? "+" + L.mobile : "Unknown number") + '</div>' +
      '</div>' +
      '<div class="cs-avatar">' + face + '<span class="cs-pulse"></span></div>' +
      '<div class="cs-dialed" id="csDialed"></div>' +
      '<div class="cs-grid">' +
        callBtn("mute", "Mute", CIC.mic) + callBtn("keypad", "Keypad", CIC.pad) + callBtn("speaker", "Speaker", CIC.speaker) +
        callBtn("add", "Add call", CIC.add) + callBtn("hold", "Hold", CIC.hold) + callBtn("wa", "WhatsApp", I.wa) +
      '</div>' +
      '<div class="cs-endrow"><button class="cs-end" data-end aria-label="End call">' + CIC.end + '</button></div>' +
      '<div class="cs-keypad" id="csKeypad" hidden><div class="cs-keys">' +
        ["1", "2", "3", "4", "5", "6", "7", "8", "9", "*", "0", "#"].map(function (d) { return '<button class="cs-key" data-key="' + d + '">' + d + '</button>'; }).join("") +
        '</div><button class="cs-hidepad" data-hidepad>Hide</button></div>';
    host().appendChild(ov);
    requestAnimationFrame(function () { ov.classList.add("show"); });

    var statusEl = $("#csStatus", ov), dialedEl = $("#csDialed", ov);
    var secs = 0, timer = null, dialed = "";
    var ring = setTimeout(function () {
      statusEl.textContent = "00:00";
      timer = setInterval(function () { secs++; var m = Math.floor(secs / 60), s = secs % 60; statusEl.textContent = (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s; }, 1000);
    }, 2200);

    function end() {
      clearTimeout(ring); if (timer) clearInterval(timer);
      ov.classList.remove("show");
      setTimeout(function () { ov.remove(); }, 260);
      toast(secs > 0 ? "Call ended \u00b7 " + Math.floor(secs / 60) + "m " + (secs % 60) + "s" : "Call ended");
    }
    $$("[data-end],[data-end-min]", ov).forEach(function (b) { b.addEventListener("click", end); });
    $$(".cs-act", ov).forEach(function (b) {
      b.addEventListener("click", function () {
        var k = b.getAttribute("data-ca");
        if (k === "keypad") { $("#csKeypad", ov).hidden = false; return; }
        if (k === "wa") { toast("Opening WhatsApp\u2026"); return; }
        if (k === "add") { toast("Add call"); return; }
        b.classList.toggle("on");
        toast(b.querySelector(".cl").textContent + (b.classList.contains("on") ? " on" : " off"));
      });
    });
    $("[data-hidepad]", ov).addEventListener("click", function () { $("#csKeypad", ov).hidden = true; });
    $$(".cs-key", ov).forEach(function (k) {
      k.addEventListener("click", function () { dialed += k.getAttribute("data-key"); dialedEl.textContent = dialed; });
    });
  }
  /* expose the full-screen call screen so Chat / Profile can reuse it */
  window.__callScreen = openCallScreen;

  /* ----- injected styles for the Customers tab ----- */
  (function () {
    var s = document.createElement("style");
    s.textContent =
      ".lx-custcard{display:flex;align-items:center;gap:13px;background:var(--surface,#fff);border:1px solid var(--line,#eef1ec);border-radius:18px;padding:14px 15px;cursor:pointer;box-shadow:0 1px 2px rgba(21,35,26,.04);margin-bottom:11px;transition:border-color .15s,box-shadow .15s;}" +
      ".lx-custcard:active{transform:translateY(1px);}" +
      ".lx-custcard .av{width:46px;height:46px;flex:0 0 46px;border-radius:50%;display:grid;place-items:center;color:#fff;font-weight:800;font-size:15px;background:linear-gradient(135deg,#3cc23f,#2ba84a);}" +
      ".lx-custcard .info{flex:1;min-width:0;}" +
      ".lx-custcard .top{display:flex;align-items:center;gap:8px;}" +
      ".lx-custcard .nm{font-size:15px;font-weight:800;color:var(--ink,#15231a);letter-spacing:-.01em;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;}" +
      ".lx-custcard .sub{font-size:12.5px;font-weight:600;color:var(--ink-3,#8a978d);margin-top:2px;}" +
      ".lx-custcard .meta{display:flex;flex-wrap:wrap;gap:13px;margin-top:7px;}" +
      ".lx-custcard .meta span{display:inline-flex;align-items:center;gap:5px;font-size:12px;font-weight:700;color:var(--ink-3,#8a978d);}" +
      ".lx-custcard .meta svg{width:14px;height:14px;flex:0 0 auto;color:var(--ink-3,#8a978d);}" +
      ".lx-custstate{display:inline-flex;align-items:center;gap:5px;font-size:10.5px;font-weight:800;padding:3px 9px;border-radius:999px;letter-spacing:.02em;white-space:nowrap;border:0;cursor:pointer;font-family:inherit;}" +
      ".lx-custstate .d{width:6px;height:6px;border-radius:50%;background:currentColor;}" +
      ".lx-custstate.active{background:#eaf9e6;color:#177a36;}" +
      ".lx-custstate.atrisk{background:#fff4dc;color:#9a6b00;}" +
      ".lx-custstate.churned{background:#fdecec;color:#c1352f;}" +
      ".lx-custcard .lx-coview{flex:0 0 auto;display:inline-flex;align-items:center;gap:2px;font-size:12px;font-weight:800;color:var(--eva-green-deep,#177a36);}" +
      ".lx-custcard .lx-coview svg{width:15px;height:15px;}" +
      ".lx-custempty{text-align:center;padding:48px 26px;color:var(--ink-3,#8a978d);}" +
      ".lx-custempty>svg{width:40px;height:40px;color:var(--ink-4,#b9c2bb);margin-bottom:10px;}" +
      ".lx-custempty .t{font-size:15px;font-weight:800;color:var(--ink-2,#4d5d52);margin-bottom:5px;}" +
      ".lx-custempty .s{font-size:12.5px;font-weight:600;line-height:1.5;max-width:34ch;margin:0 auto;}";
    document.head.appendChild(s);
  })();

  /* ----- injected styles for sync / call / customer tag / custom reminder ----- */
  (function () {
    var s = document.createElement("style");
    s.textContent =
      ".lx-custtag{display:inline-flex;align-items:center;gap:6px;margin-left:9px;font-size:12px;font-weight:800;color:var(--eva-green-deep,#177a36);vertical-align:middle;}" +
      ".lx-qhead .qm svg{width:14px;height:14px;flex:0 0 auto;}" +
      ".lt-tabs{display:flex;gap:20px;border-bottom:1px solid var(--line,#eef1ec);margin:-2px 0 14px;}" +
      ".lt-tab{background:none;border:0;padding:8px 1px 11px;font-family:var(--font-body,inherit);font-size:13.5px;font-weight:700;color:var(--ink-3,#8a978d);cursor:pointer;position:relative;}" +
      ".lt-tab.on{color:var(--eva-green-deep,#177a36);}" +
      ".lt-tab.on::after{content:'';position:absolute;left:0;right:0;bottom:-1px;height:2.5px;border-radius:2px;background:var(--eva-green,#3cc23f);}" +
      ".lt-search{margin-bottom:14px;}" +
      ".lt-list{display:flex;flex-direction:column;gap:11px;}" +
      ".lt-card{display:flex;align-items:center;gap:13px;width:100%;text-align:left;cursor:pointer;background:#fff;border:1px solid var(--line,#eef1ec);border-radius:16px;padding:12px 13px;font-family:var(--font-body,inherit);box-shadow:var(--shadow-xs,0 1px 2px rgba(16,30,18,.05));transition:border-color .15s,box-shadow .15s;}" +
      ".lt-card:active{border-color:var(--eva-green,#3cc23f);box-shadow:0 0 0 3px var(--accent-soft,#eaf9e6);}" +
      ".lt-ic{flex:0 0 44px;width:44px;height:44px;border-radius:12px;display:grid;place-items:center;background:var(--accent-soft,#eaf9e6);color:var(--eva-green-deep,#177a36);}" +
      ".lt-ic svg{width:21px;height:21px;}" +
      ".lt-body{flex:1;min-width:0;display:flex;flex-direction:column;gap:2px;}" +
      ".lt-name{font-size:14.5px;font-weight:800;color:var(--ink,#15231a);letter-spacing:-.01em;}" +
      ".lt-prev{font-size:12.5px;font-weight:600;color:var(--ink-3,#8a978d);white-space:nowrap;overflow:hidden;text-overflow:ellipsis;}" +
      ".lt-cat{align-self:flex-start;margin-top:4px;font-size:9.5px;font-weight:800;text-transform:uppercase;letter-spacing:.07em;color:var(--eva-green-deep,#177a36);background:var(--accent-soft,#eaf9e6);border-radius:6px;padding:2px 7px;}" +
      ".lt-send{flex:0 0 auto;width:34px;height:34px;border-radius:50%;display:grid;place-items:center;background:#3DC838;color:#fff;box-shadow:0 4px 10px -4px rgba(43,168,74,.6);}" +
      ".lt-send svg{width:16px;height:16px;}" +
      ".lt-empty{padding:34px 8px;text-align:center;font-size:13px;font-weight:600;color:var(--ink-3,#8a978d);}" +
      ".lx-custtag .dot{width:7px;height:7px;border-radius:50%;background:var(--eva-green,#3CC23F);box-shadow:0 0 0 3px rgba(60,194,63,.18);}" +
      ".lx-customr{margin-top:14px;}" +
      ".lx-clabel{display:block;font-size:11px;font-weight:800;letter-spacing:.04em;text-transform:uppercase;color:var(--ink-3,#8a978d);margin-bottom:7px;}" +
      /* sync */
      ".lx-syncwrap{display:flex;flex-direction:column;align-items:center;text-align:center;padding:10px 0 6px;}" +
      ".lx-syncspin{width:46px;height:46px;border-radius:50%;border:4px solid var(--accent-soft,#eaf9e6);border-top-color:var(--eva-green,#3cc23f);animation:lxspin .8s linear infinite;margin-bottom:14px;}" +
      "@keyframes lxspin{to{transform:rotate(360deg)}}" +
      ".lx-syncok{width:54px;height:54px;border-radius:50%;background:var(--eva-green,#3cc23f);color:#fff;display:grid;place-items:center;margin-bottom:12px;animation:lxpop .3s cubic-bezier(.2,1.4,.5,1);}" +
      ".lx-syncok svg{width:30px;height:30px;}@keyframes lxpop{from{transform:scale(.3);opacity:0}to{transform:scale(1);opacity:1}}" +
      ".lx-synctitle{font-size:16px;font-weight:800;color:var(--ink,#15231a);}" +
      ".lx-syncsub{font-size:12.5px;font-weight:600;color:var(--ink-3,#8a978d);margin-top:4px;}" +
      ".lx-syncsrc,.lx-syncfound{width:100%;margin-top:18px;display:flex;flex-direction:column;gap:9px;}" +
      ".lx-srcrow{display:flex;align-items:center;gap:11px;padding:11px 13px;border:1px solid var(--line,#eef1ec);border-radius:13px;text-align:left;opacity:.5;transition:opacity .3s,border-color .3s;}" +
      ".lx-srcrow.done,.lx-srcrow.found{opacity:1;border-color:var(--tint-border,#cdeac4);}" +
      ".lx-srcrow .ic{flex:0 0 32px;width:32px;height:32px;border-radius:9px;background:var(--surface-2,#f1f4ef);color:var(--ink-3,#8a978d);display:grid;place-items:center;}" +
      ".lx-srcrow .ic.green{background:var(--accent-soft,#eaf9e6);color:var(--eva-green-deep,#177a36);}" +
      ".lx-srcrow .ic svg{width:17px;height:17px;}" +
      ".lx-srcrow .tx{flex:1;min-width:0;}.lx-srcrow .tx .n{font-size:13.5px;font-weight:800;color:var(--ink,#15231a);}.lx-srcrow .tx .d{font-size:11.5px;font-weight:600;color:var(--ink-3,#8a978d);margin-top:1px;}" +
      ".lx-srcrow .ck{flex:0 0 auto;color:var(--eva-green,#3cc23f);opacity:0;transform:scale(.5);transition:opacity .25s,transform .25s;}" +
      ".lx-srcrow.done .ck{opacity:1;transform:scale(1);}.lx-srcrow .ck svg{width:18px;height:18px;}" +
      /* call screen */
      ".callscr{position:absolute;inset:0;z-index:120;display:flex;flex-direction:column;align-items:center;color:#fff;opacity:0;transition:opacity .26s ease;overflow:hidden;}" +
      ".callscr.show{opacity:1;}" +
      ".cs-grad{position:absolute;inset:0;z-index:-1;background:radial-gradient(120% 70% at 50% 0%,#2BA84A,#0f3d20 70%,#06160d);}" +
      ".cs-head{margin-top:calc(40px + env(safe-area-inset-top));text-align:center;padding:0 20px;position:relative;width:100%;}" +
      ".cs-min{position:absolute;left:14px;top:-4px;width:38px;height:38px;border:0;border-radius:50%;background:rgba(255,255,255,.16);color:#fff;display:grid;place-items:center;cursor:pointer;}" +
      ".cs-min svg{width:20px;height:20px;}" +
      ".cs-status{font-size:13px;font-weight:700;color:rgba(255,255,255,.82);letter-spacing:.02em;min-height:16px;}" +
      ".cs-name{font-size:27px;font-weight:800;letter-spacing:-.01em;margin-top:8px;}" +
      ".cs-num{font-size:13.5px;font-weight:600;color:rgba(255,255,255,.7);margin-top:4px;}" +
      ".cs-avatar{position:relative;margin:34px 0 8px;width:118px;height:118px;border-radius:50%;background:rgba(255,255,255,.16);display:grid;place-items:center;font-size:42px;font-weight:800;}" +
      ".cs-avatar svg{width:48px;height:48px;}" +
      ".cs-pulse{position:absolute;inset:-10px;border-radius:50%;border:2px solid rgba(255,255,255,.28);animation:cspulse 1.8s ease-out infinite;}" +
      "@keyframes cspulse{0%{transform:scale(.9);opacity:.7}100%{transform:scale(1.25);opacity:0}}" +
      ".cs-dialed{min-height:22px;font-size:18px;font-weight:700;letter-spacing:.12em;color:#fff;}" +
      ".cs-grid{margin-top:auto;display:grid;grid-template-columns:repeat(3,1fr);gap:20px 26px;padding:0 34px;width:100%;max-width:340px;}" +
      ".cs-act{display:flex;flex-direction:column;align-items:center;gap:8px;background:none;border:0;cursor:pointer;font-family:var(--font-body,inherit);color:#fff;}" +
      ".cs-act .ci{width:62px;height:62px;border-radius:50%;background:rgba(255,255,255,.16);display:grid;place-items:center;transition:background .15s,color .15s;}" +
      ".cs-act .ci svg{width:25px;height:25px;}" +
      ".cs-act.on .ci{background:#fff;color:#177a36;}" +
      ".cs-act .cl{font-size:12px;font-weight:700;color:rgba(255,255,255,.9);}" +
      ".cs-endrow{margin:30px 0 calc(30px + env(safe-area-inset-bottom));}" +
      ".cs-end{width:70px;height:70px;border-radius:50%;border:0;background:#EF4444;color:#fff;cursor:pointer;display:grid;place-items:center;box-shadow:0 12px 28px -8px rgba(239,68,68,.7);transition:transform .1s;}" +
      ".cs-end:active{transform:scale(.93);}.cs-end svg{width:30px;height:30px;}" +
      ".cs-keypad{position:absolute;left:0;right:0;bottom:0;z-index:2;background:rgba(8,22,13,.96);-webkit-backdrop-filter:blur(8px);backdrop-filter:blur(8px);border-radius:24px 24px 0 0;padding:20px 26px calc(20px + env(safe-area-inset-bottom));}" +
      ".cs-keys{display:grid;grid-template-columns:repeat(3,1fr);gap:14px;}" +
      ".cs-key{height:62px;border-radius:50%;border:0;background:rgba(255,255,255,.12);color:#fff;font-size:24px;font-weight:700;font-family:var(--font-body,inherit);cursor:pointer;transition:background .12s;}" +
      ".cs-key:active{background:rgba(255,255,255,.28);}" +
      ".cs-hidepad{margin:16px auto 0;display:block;background:none;border:0;color:rgba(255,255,255,.8);font-family:var(--font-body,inherit);font-size:14px;font-weight:700;cursor:pointer;}";
    document.head.appendChild(s);
  })();

  /* ---------- init ---------- */
  var _rrIdx = 0;
  window.AskEvaNextAgent = function () { var ags = leadAgents().filter(function (a) { return a.email; }).map(function (a) { return a.email; }); if (!ags.length) return ""; return ags[_rrIdx++ % ags.length]; };
  window.AskEvaAddLead = function (lead) {
    lead = lead || {};
    lead.id = lead.id || ("scan_" + Date.now());
    lead.status = lead.status || "new";
    lead.created = lead.created || fmtNow();
    lead.updated = lead.updated || lead.created;
    if (!("tags" in lead)) lead.tags = [];
    LEADS.unshift(lead);
    logActivity(lead, { type: "created", text: "Lead created" + (lead.source ? " from " + lead.source : ""), module: "Leads" });
    state.tab = "leads";
    $$(".lx-tab", pane).forEach(function (x) { x.classList.toggle("active", x.getAttribute("data-tab") === "leads"); });
    $$("[data-tab-body]", pane).forEach(function (b) { b.hidden = b.getAttribute("data-tab-body") !== "leads"; });
    var fab = $("#lxFab", pane); if (fab) fab.style.display = "";
    renderLeads();
    return lead;
  };
  /* PASS 3: external store changes re-render the active leads/companies view + badges */
  document.addEventListener("leads:changed", function () {
    reconcileCustomers();
    if (state.tab === "companies") renderCompanies($("#lxCoSearch", pane).value);
    else if (state.tab === "customers") renderCustomers($("#lxCustSearch", pane).value);
    else renderLeads();
    updateLeadBadges();
  });
  updateLeadBadges();
  renderLeads();
})();
