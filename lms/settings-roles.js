/* =========================================================
   AskEva — Settings · Agents · Role Configuration (master control)
   Owns the full Role Access Management table + granular
   Module-Permissions editor. Single source of truth for roles;
   exposed as window.AskEvaRoles and consumed by the Agents tab.
   Renders the Role Configuration tab into #agentsView and the
   editor into the #roleEditor overlay.
   ========================================================= */
(function () {
  "use strict";
  var $ = function (s, r) { return (r || document).querySelector(s); };
  var $$ = function (s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); };
  function esc(s) { return String(s == null ? "" : s).replace(/[&<>"]/g, function (c) { return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]; }); }
  function slug(s) { return String(s).toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, ""); }
  var toastT;
  function toast(m) { var t = document.getElementById("toast"); if (!t) return; t.textContent = m; t.style.opacity = "1"; t.style.transform = "translateX(-50%) translateY(0)"; clearTimeout(toastT); toastT = setTimeout(function () { t.style.opacity = "0"; t.style.transform = "translateX(-50%) translateY(20px)"; }, 1900); }

  /* ----- icons ----- */
  var I = {
    dash: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="3" width="7" height="7" rx="1.5"/><rect x="14" y="3" width="7" height="7" rx="1.5"/><rect x="3" y="14" width="7" height="7" rx="1.5"/><rect x="14" y="14" width="7" height="7" rx="1.5"/></svg>',
    send: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M22 2 11 13M22 2l-7 20-4-9-9-4 20-7z"/></svg>',
    chat: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/></svg>',
    contact: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.9"/></svg>',
    tmpl: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="4" y="3" width="16" height="18" rx="2"/><path d="M8 8h8M8 12h8M8 16h5"/></svg>',
    report: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 3v18h18"/><path d="M7 14l3-3 3 3 5-6"/></svg>',
    bot: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="4" y="8" width="16" height="11" rx="3"/><path d="M12 8V4M9 4h6M8.5 13h.01M15.5 13h.01"/></svg>',
    ai: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3l1.9 4.7L19 9.3l-3.6 3.1 1 5.1L12 14.9 7.6 17.5l1-5.1L5 9.3l5.1-1.6z"/></svg>',
    catalog: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="5" y="3" width="14" height="18" rx="2"/><path d="M9 7h6M9 11h6M9 15h3"/></svg>',
    pay: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="2" y="5" width="20" height="14" rx="2.5"/><path d="M2 10h20"/></svg>',
    plug: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M10 13a5 5 0 0 0 7 0l3-3a5 5 0 0 0-7-7l-1 1"/><path d="M14 11a5 5 0 0 0-7 0l-3 3a5 5 0 0 0 7 7l1-1"/></svg>',
    leads: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="8"/><circle cx="12" cy="12" r="3"/><path d="M12 2v2M12 20v2M2 12h2M20 12h2"/></svg>',
    customer: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="8" r="4"/><path d="M4 21c0-4 3.6-6 8-6s8 2 8 6"/></svg>',
    appt: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="4" width="18" height="17" rx="2"/><path d="M3 9h18M8 2v4M16 2v4"/></svg>',
    ticket: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 8a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2v2a2 2 0 0 0 0 4v2a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-2a2 2 0 0 0 0-4z"/><path d="M13 6v12"/></svg>',
    billing: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 2h12v20l-3-2-3 2-3-2-3 2z"/><path d="M9 7h6M9 11h6"/></svg>',
    flow: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="6" cy="6" r="2.5"/><circle cx="6" cy="18" r="2.5"/><circle cx="18" cy="12" r="2.5"/><path d="M8.5 6H14a2 2 0 0 1 2 2v2M8.5 18H14a2 2 0 0 0 2-2v-2"/></svg>',
    gear: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.6 1.6 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.6 1.6 0 0 0-2.7 1.1V21a2 2 0 0 1-4 0v-.1A1.6 1.6 0 0 0 7 19.4l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1A1.6 1.6 0 0 0 5 13.6H4.9a2 2 0 0 1 0-4H5a1.6 1.6 0 0 0 1.1-2.7L6 6.8a2 2 0 1 1 2.8-2.8l.1.1A1.6 1.6 0 0 0 11 4.6V4.5a2 2 0 0 1 4 0v.1A1.6 1.6 0 0 0 17 6.1l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.6 1.6 0 0 0-.3 1.8z"/></svg>',
    cart: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="9" cy="20" r="1.5"/><circle cx="18" cy="20" r="1.5"/><path d="M2 3h2l2.5 13h12L21 7H6"/></svg>',
    tag: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M20.6 13.4 12 22 2 12V2h10z"/><circle cx="7" cy="7" r="1.5" fill="currentColor"/></svg>',
    bell: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 8a6 6 0 0 1 12 0c0 7 3 7 3 9H3c0-2 3-2 3-9z"/><path d="M10.5 21a2 2 0 0 0 3 0"/></svg>',
    cfg: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 6h10M4 12h7M4 18h13"/><circle cx="18" cy="6" r="2"/><circle cx="15" cy="12" r="2"/><circle cx="21" cy="18" r="2"/></svg>',
    book: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="4" width="18" height="17" rx="2"/><path d="M3 9h18M8 2v4M16 2v4M8 14h4"/></svg>',
    coin: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="M12 7v10M9.5 9.5a2.5 2.5 0 0 1 5 0c0 1.4-1.1 2-2.5 2.5s-2.5 1.1-2.5 2.5a2.5 2.5 0 0 0 5 0"/></svg>',
    code: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m9 18-6-6 6-6M15 6l6 6-6 6"/></svg>',
    qr: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="3" width="7" height="7" rx="1"/><rect x="14" y="3" width="7" height="7" rx="1"/><rect x="3" y="14" width="7" height="7" rx="1"/><path d="M14 14h3v3M21 14v.01M17 21h4v-4M14 21h.01"/></svg>',
    layers: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m12 3 9 5-9 5-9-5z"/><path d="m3 13 9 5 9-5M3 18l9 5 9-5" opacity=".55"/></svg>',
    agent: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="8" r="3.5"/><path d="M5 20c0-3.3 3.1-5 7-5s7 1.7 7 5"/><path d="M18 8l1.5-1.5"/></svg>',
    back: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M15 18l-6-6 6-6"/></svg>',
    chevD: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="m6 9 6 6 6-6"/></svg>',
    chevL: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m15 6-6 6 6 6"/></svg>',
    chevR: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m9 6 6 6-6 6"/></svg>',
    plus: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 5v14M5 12h14"/></svg>',
    edit: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M11 4H5a2 2 0 0 0-2 2v13a2 2 0 0 0 2 2h13a2 2 0 0 0 2-2v-6"/><path d="M18.5 2.5a2.12 2.12 0 0 1 3 3L12 15l-4 1 1-4Z"/></svg>',
    trash: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 7h16M9 7V5a2 2 0 0 1 2-2h2a2 2 0 0 1 2 2v2M6 7l1 13a2 2 0 0 0 2 2h6a2 2 0 0 0 2-2l1-13"/></svg>',
    save: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M5 3h11l3 3v15H5z"/><path d="M8 3v6h7M8 21v-7h8v7"/></svg>',
    check: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="m5 12 4 4 10-11"/></svg>',
    warn: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 9v4M12 17h.01"/><path d="M10.3 3.9 2 19a2 2 0 0 0 1.7 3h16.6a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0Z"/></svg>'
  };

  /* =========================================================
     MODULE / PERMISSION CATALOG  (mirrors the web Role editor)
     `flat` modules render permissions directly (no sub-group).
     Permission id = moduleKey "." groupKey "." permKey
     ========================================================= */
  var FA = "Full Access", VO = "View Only Access", CV = "Create and View";
  function g(name, icon, perms) { return { key: slug(name), name: name, icon: icon, perms: perms.map(function (p) { return { key: slug(p), label: p }; }) }; }
  var MODULES = [
    { key: "dashboard", name: "Dashboard", icon: I.dash, flat: true, groups: [g("Dashboard", I.dash, [FA])] },
    { key: "compose", name: "Compose Message", icon: I.send, flat: true, groups: [g("Compose Message", I.send, [FA, VO])] },
    { key: "chat", name: "Chat", icon: I.chat, flat: true, groups: [g("Chat", I.chat, ["Live chat - Global Access", "History - Global Access"])] },
    { key: "contact", name: "Contact", icon: I.contact, groups: [
      g("Contacts", I.contact, [FA, VO, CV]),
      g("Contact Groups", I.contact, [FA, VO, CV])
    ] },
    { key: "template", name: "Manage Template", icon: I.tmpl, flat: true, groups: [g("Manage Template", I.tmpl, [FA, "Creation and View Access", "View Only Access"])] },
    { key: "report", name: "Report", icon: I.report, groups: [
      g("Chat Reports", I.report, [FA, VO]),
      g("Lead Reports", I.report, [FA, VO]),
      g("Agent Reports", I.report, [FA, VO])
    ] },
    { key: "chatbot", name: "Chatbot Builder", icon: I.bot, flat: true, groups: [g("Chatbot Builder", I.bot, [FA, VO])] },
    { key: "aiagent", name: "AI Agent", icon: I.ai, flat: true, groups: [g("AI Agent", I.ai, [FA, VO])] },
    { key: "catalog", name: "Catalog", icon: I.catalog, groups: [
      g("Catalogs", I.catalog, [FA]),
      g("Orders", I.cart, [FA, VO]),
      g("Coupons", I.tag, [FA, VO, CV])
    ] },
    { key: "payment", name: "Payment", icon: I.pay, groups: [
      g("Transactions", I.pay, [FA]),
      g("Configuration", I.gear, [FA, VO]),
      g("Payment Notification", I.bell, [FA])
    ] },
    { key: "integration", name: "Integration", icon: I.plug, flat: true, groups: [g("Integration", I.plug, [FA, VO])] },
    { key: "leads", name: "Leads", icon: I.leads, groups: [
      g("Dashboard", I.dash, [FA]),
      g("Leads", I.leads, [FA, VO]),
      g("Configurations", I.cfg, [FA, VO])
    ] },
    { key: "customer", name: "Customer", icon: I.customer, flat: true, groups: [g("Customer", I.customer, [FA])] },
    { key: "appointments", name: "Appointments", icon: I.appt, groups: [
      g("Dashboard", I.dash, [FA]),
      g("Bookings", I.book, [FA, VO]),
      g("Configuration", I.gear, [FA, VO]),
      g("Payments", I.coin, [FA])
    ] },
    { key: "tickets", name: "Tickets", icon: I.ticket, groups: [
      g("Dashboard", I.dash, [FA]),
      g("Tickets", I.ticket, [FA, VO]),
      g("Ticket Settings", I.gear, [FA, VO])
    ] },
    { key: "billing", name: "Billing", icon: I.billing, flat: true, groups: [g("Billing", I.billing, [FA])] },
    { key: "flows", name: "Whatsapp Flows", icon: I.flow, flat: true, groups: [g("Whatsapp Flows", I.flow, [FA, "Creation and View Access", "View Only Access"])] },
    { key: "settings", name: "Settings", icon: I.gear, groups: [
      g("Agent Settings", I.agent, [FA, VO]),
      g("API Settings", I.code, [FA, VO]),
      g("QR Code", I.qr, [FA, VO]),
      g("User Attributes", I.layers, [FA, VO])
    ] }
  ];

  /* legacy module key -> Agents "type" module (chat|leads|appt|ticket) */
  var MOD2TYPE = { chat: "chat", leads: "leads", appointments: "appt", tickets: "ticket" };

  /* flat ordered list of every permission id + index helpers */
  var ALL_PERMS = [];
  var MOD_PERMS = {};   // moduleKey -> [permId]
  MODULES.forEach(function (m) {
    MOD_PERMS[m.key] = [];
    m.groups.forEach(function (grp) {
      grp.perms.forEach(function (p) {
        var id = m.key + "." + grp.key + "." + p.key;
        ALL_PERMS.push(id); MOD_PERMS[m.key].push(id);
      });
    });
  });
  function modPermIds(keys) { var out = []; keys.forEach(function (k) { out = out.concat(MOD_PERMS[k] || []); }); return out; }
  var TOTAL = ALL_PERMS.length;

  /* =========================================================
     STORE
     ========================================================= */
  var RK = "askeva.set.roles.v2";
  function firstN(n) { return ALL_PERMS.slice(0, Math.max(0, Math.min(n, TOTAL))); }
  function seed() {
    var agentPerms = modPermIds(["dashboard", "compose", "chat", "contact", "template", "leads", "tickets", "appointments"]);
    var chatPerms = modPermIds(["dashboard", "compose", "chat", "contact", "template"]);
    return [
      { id: "admin", name: "Admin", desc: "Full access to all modules", on: true, core: true, perms: ALL_PERMS.slice() },
      { id: "agent", name: "Agent", desc: "Handle chats, leads & tickets", on: true, core: true, perms: agentPerms },
      { id: "chatagent", name: "Chat Agent", desc: "Chat support only", on: true, core: true, perms: chatPerms },
      { id: "payer", name: "payer", desc: "payment check", on: true, perms: modPermIds(["payment"]).slice(0, 1) },
      { id: "testcheck1", name: "Testing Check 1", desc: "test", on: true, perms: firstN(25) },
      { id: "yeahtest", name: "Yeah Test", desc: "chumma", on: true, perms: firstN(63) },
      { id: "finaltest", name: "final test", desc: "testing", on: true, perms: firstN(2) },
      { id: "test", name: "test", desc: "check", on: true, perms: firstN(19) },
      { id: "intern", name: "Intern", desc: "Testing", on: true, perms: firstN(1) },
      { id: "rockers", name: "rockers", desc: "rk", on: true, perms: firstN(18) },
      { id: "ddv", name: "DDV", desc: "hm", on: true, perms: firstN(3) },
      { id: "developer", name: "Developer", desc: "Test", on: true, perms: firstN(7) },
      { id: "junior", name: "Junior", desc: "test", on: true, perms: firstN(22) }
    ];
  }
  var roles;
  try { roles = JSON.parse(localStorage.getItem(RK)) || null; } catch (e) { roles = null; }
  if (!roles || !roles.length) roles = seed();
  // normalise (perms always array, drop stale ids)
  roles.forEach(function (r) {
    if (!Array.isArray(r.perms)) r.perms = [];
    r.perms = r.perms.filter(function (p) { return ALL_PERMS.indexOf(p) > -1; });
    if (r.on === undefined) r.on = true;
  });
  function save() { try { localStorage.setItem(RK, JSON.stringify(roles)); } catch (e) {} emit(); }
  function emit() { try { document.dispatchEvent(new CustomEvent("roles:changed")); } catch (e) {} }
  function getRole(id) { for (var i = 0; i < roles.length; i++) if (roles[i].id === id) return roles[i]; return null; }
  /* agents currently holding this role (case-insensitive, matches name or id) */
  function roleHolders(r) {
    if (!r) return [];
    try {
      if (window.AskEvaPeople && window.AskEvaPeople.list) {
        var rn = (r.name || "").trim().toLowerCase(), rid = (r.id || "").toLowerCase();
        return window.AskEvaPeople.list().filter(function (a) {
          var ar = (a.role || "").trim().toLowerCase();
          return ar && (ar === rn || ar === rid);
        });
      }
    } catch (e) {}
    return [];
  }
  function getByName(n) { n = (n || "").toLowerCase(); for (var i = 0; i < roles.length; i++) if ((roles[i].name || "").toLowerCase() === n || roles[i].id === n) return roles[i]; return null; }
  function permSet(r) { var s = {}; (r.perms || []).forEach(function (p) { s[p] = 1; }); return s; }
  function modsForRole(r) {
    if (!r) return [];
    var out = [], set = permSet(r);
    Object.keys(MOD2TYPE).forEach(function (mk) {
      if ((MOD_PERMS[mk] || []).some(function (p) { return set[p]; })) out.push(MOD2TYPE[mk]);
    });
    return out;
  }

  /* =========================================================
     ROLE ACCESS MANAGEMENT  (tab list)
     ========================================================= */
  var view = null, page = 1, PP = 10, onChangeCb = null;
  function renderTab(viewEl, onChange) {
    view = viewEl; onChangeCb = onChange || null;
    var pages = Math.max(1, Math.ceil(roles.length / PP)); if (page > pages) page = pages;
    var start = (page - 1) * PP, slice = roles.slice(start, start + PP);
    view.innerHTML =
      '<div class="rc2-head"><div class="rc2-htxt"><h3>Role Access Management</h3>' +
        '<p>' + roles.length + ' roles \u00b7 ' + TOTAL + ' permissions available</p></div>' +
        '<button class="rc2-new" id="rcNew">' + I.plus + 'Create New Role</button></div>' +
      '<div class="rc2-list">' + slice.map(function (r, i) { return roleRow(r, start + i + 1); }).join("") + '</div>' +
      (pages > 1 ? pager(pages) : "");
    bindTab();
  }
  function roleRow(r, sn) {
    var n = (r.perms || []).length;
    var assigned = !r.core && roleHolders(r).length > 0;
    var locked = r.core || assigned;
    return '<div class="rc2-card" data-id="' + r.id + '">' +
      '<div class="rc2-top"><span class="rc2-sn">' + sn + '</span>' +
        '<div class="rc2-id"><div class="rc2-name">' + esc(r.name) + (r.core ? '<span class="rc2-core">core</span>' : '') + '</div>' +
        '<div class="rc2-desc">' + esc(r.desc || "\u2014") + '</div></div>' +
        '<button class="rc2-toggle' + (r.on ? " on" : "") + '" data-id="' + r.id + '" aria-label="Status"><span class="kn"></span></button></div>' +
      '<div class="rc2-bottom"><span class="rc2-perm">' + n + ' permission' + (n === 1 ? "" : "s") + '</span>' +
        (r.on ? "" : '<span class="rc2-inactive">Inactive</span>') +
        '<span class="rc2-actions"><button class="rc2-edit" data-id="' + r.id + '" aria-label="Edit">' + I.edit + '</button>' +
        '<button class="rc2-trash' + (locked ? " off" : "") + (assigned ? " lk" : "") + '" data-id="' + r.id + '" aria-label="Delete"' + (r.core ? " disabled" : "") + '>' + I.trash + '</button></span></div>' +
      '</div>';
  }
  function pager(pages) {
    var nums = ""; for (var p = 1; p <= pages; p++) nums += '<button class="rc2-pg num' + (p === page ? " on" : "") + '" data-pg="' + p + '">' + p + '</button>';
    return '<div class="rc2-foot"><button class="rc2-pg arr" data-pg="' + (page - 1) + '"' + (page <= 1 ? " disabled" : "") + '>' + I.chevL + '</button>' + nums +
      '<button class="rc2-pg arr" data-pg="' + (page + 1) + '"' + (page >= pages ? " disabled" : "") + '>' + I.chevR + '</button></div>';
  }
  function bindTab() {
    var nb = $("#rcNew", view); if (nb) nb.addEventListener("click", function () { openEditor(null); });
    $$(".rc2-toggle", view).forEach(function (b) { b.addEventListener("click", function (e) {
      e.stopPropagation(); var r = getRole(b.getAttribute("data-id")); r.on = !r.on; save(); renderTab(view, onChangeCb); notify(); toast(r.name + (r.on ? " activated" : " deactivated"));
    }); });
    $$(".rc2-edit", view).forEach(function (b) { b.addEventListener("click", function (e) { e.stopPropagation(); openEditor(b.getAttribute("data-id")); }); });
    $$(".rc2-card", view).forEach(function (c) { c.addEventListener("click", function (e) {
      if (e.target.closest("button")) return; openEditor(c.getAttribute("data-id"));
    }); });
    $$(".rc2-trash.lk", view).forEach(function (b) { b.addEventListener("click", function (e) {
      e.stopPropagation(); var r = getRole(b.getAttribute("data-id"));
      var holders = roleHolders(r);
      var who = holders.slice(0, 3).map(function (a) { return a.name; }).join(", ") + (holders.length > 3 ? " +" + (holders.length - 3) + " more" : "");
      confirmModal("Can't delete this role", "\u201C" + r.name + "\u201D is assigned to " + holders.length + " agent" + (holders.length > 1 ? "s" : "") + " (" + who + "). Reassign them to another role first, then delete it.", "Got it", null);
    }); });
    $$(".rc2-trash:not(.off)", view).forEach(function (b) { b.addEventListener("click", function (e) {
      e.stopPropagation(); var r = getRole(b.getAttribute("data-id"));
      var holders = roleHolders(r);
      if (holders.length) {
        var who = holders.slice(0, 3).map(function (a) { return a.name; }).join(", ") + (holders.length > 3 ? " +" + (holders.length - 3) + " more" : "");
        confirmModal("Can't delete this role", "\u201C" + r.name + "\u201D is assigned to " + holders.length + " agent" + (holders.length > 1 ? "s" : "") + " (" + who + "). Reassign them to another role first, then delete it.", "Got it", null);
        return;
      }
      confirmModal("Delete role?", "\u201C" + r.name + "\u201D will be permanently removed.", "Delete", function () {
        roles = roles.filter(function (x) { return x.id !== r.id; }); save(); renderTab(view, onChangeCb); notify(); toast("Role deleted");
      });
    }); });
    $$(".rc2-pg[data-pg]", view).forEach(function (b) { b.addEventListener("click", function () {
      var p = +b.getAttribute("data-pg"), pages = Math.ceil(roles.length / PP);
      if (b.disabled || p < 1 || p > pages || p === page) return; page = p; renderTab(view, onChangeCb);
    }); });
  }
  function notify() { if (onChangeCb) try { onChangeCb(); } catch (e) {} }

  /* =========================================================
     EDITOR  (#roleEditor overlay) — module accordion
     ========================================================= */
  var editor = null, draft = null, expanded = {}, editId = null;
  function openEditor(id) {
    editor = document.getElementById("roleEditor"); if (!editor) return;
    editId = id;
    var r = id ? getRole(id) : null;
    draft = { name: r ? r.name : "", desc: r ? r.desc : "", on: r ? r.on : true, sel: {} };
    if (r) (r.perms || []).forEach(function (p) { draft.sel[p] = 1; });
    expanded = {};
    renderEditor(); editor.classList.add("show");
  }
  function closeEditor() { if (editor) editor.classList.remove("show"); }
  function selCount() { return Object.keys(draft.sel).filter(function (k) { return draft.sel[k]; }).length; }
  function modCount(m) { var c = 0; MOD_PERMS[m.key].forEach(function (p) { if (draft.sel[p]) c++; }); return c; }
  function grpCount(mKey, grp) { var c = 0; grp.perms.forEach(function (p) { if (draft.sel[mKey + "." + grp.key + "." + p.key]) c++; }); return c; }

  function renderEditor() {
    var sc = editor.querySelector(".rcx-scroll"); var prevTop = sc ? sc.scrollTop : 0;
    editor.innerHTML =
      '<div class="rcx-bar"><button class="rcx-x" data-x="close" aria-label="Cancel">' + I.back + '</button>' +
        '<div class="rcx-ttl">' + (editId ? "Edit Role" : "Create New Role") + '</div><span class="rcx-spacer"></span></div>' +
      '<div class="rcx-scroll">' +
        '<div class="rcx-meta">' +
          '<div class="rcx-field"><label>Role Name<span>*</span></label><input id="rxName" type="text" placeholder="e.g. Supervisor" value="' + esc(draft.name) + '"></div>' +
          '<div class="rcx-field"><label>Description</label><input id="rxDesc" type="text" placeholder="Short description" value="' + esc(draft.desc) + '"></div>' +
          '<label class="rcx-statusrow"><span>Status <small>' + (draft.on ? "Active" : "Inactive") + '</small></span>' +
            '<button class="rc2-toggle' + (draft.on ? " on" : "") + '" id="rxStatus"><span class="kn"></span></button></label>' +
        '</div>' +
        '<div class="rcx-permhead"><h4>Module Permissions</h4><p>Configure access levels for each system module \u00b7 <b>' + selCount() + '</b> of ' + TOTAL + ' selected</p></div>' +
        '<div class="rcx-allperms"><span class="rcx-apic"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 2 4 6v6c0 5 3.4 8.4 8 10 4.6-1.6 8-5 8-10V6z"/><path d="M9 12l2 2 4-4"/></svg></span>' +
          '<span class="rcx-aptx"><span class="nm">All permissions</span><span class="ct">' + (selCount() === TOTAL ? "Every permission enabled" : "Enable or disable every permission at once") + '</span></span>' +
          toggleHtml(selCount() === TOTAL, "all-perms", 'id="rxAllPerms"') + '</div>' +
        '<div class="rcx-mods">' + MODULES.map(moduleBlock).join("") + '</div>' +
      '</div>' +
      '<div class="rcx-savebar"><button class="rcx-btn ghost" data-x="close">Cancel</button>' +
        '<button class="rcx-btn primary" id="rxSave">' + I.save + (editId ? "Update Role" : "Create Role") + '</button></div>';
    bindEditor();
    var sc2 = editor.querySelector(".rcx-scroll"); if (sc2) sc2.scrollTop = prevTop;
  }
  function toggleHtml(on, cls, attrs) { return '<button class="rcx-sw' + (on ? " on" : "") + (cls ? " " + cls : "") + '" ' + (attrs || "") + '><span class="kn"></span></button>'; }
  function moduleBlock(m) {
    var open = !!expanded[m.key], total = MOD_PERMS[m.key].length, sel = modCount(m), all = sel === total;
    var head =
      '<div class="rcx-modhead' + (open ? " open" : "") + '" data-mod="' + m.key + '">' +
        '<span class="rcx-modic">' + m.icon + '</span>' +
        '<span class="rcx-modtx"><span class="nm">' + esc(m.name) + '</span><span class="ct">' + sel + ' of ' + total + ' permissions selected</span></span>' +
        '<span class="rcx-selall"><span class="lbl">Select All</span>' + toggleHtml(all, "mod-all", 'data-modall="' + m.key + '"') + '</span>' +
        '<span class="rcx-chev">' + I.chevD + '</span>' +
      '</div>';
    if (!open) return '<div class="rcx-mod">' + head + '</div>';
    var body = m.groups.map(function (grp) {
      if (m.flat) {
        return grp.perms.map(function (p) {
          var id = m.key + "." + grp.key + "." + p.key;
          return permRow(p.label, !!draft.sel[id], id);
        }).join("");
      }
      var gsel = grpCount(m.key, grp), gtot = grp.perms.length, gall = gsel === gtot;
      return '<div class="rcx-grp">' +
        '<div class="rcx-grphead"><span class="rcx-grpic">' + grp.icon + '</span>' +
          '<span class="rcx-grptx"><span class="nm">' + esc(grp.name) + '</span><span class="ct">' + gsel + ' of ' + gtot + ' permissions selected</span></span>' +
          '<span class="rcx-selall sm"><span class="lbl">Select All</span>' + toggleHtml(gall, "grp-all", 'data-grpall="' + m.key + '|' + grp.key + '"') + '</span></div>' +
        grp.perms.map(function (p) { var id = m.key + "." + grp.key + "." + p.key; return permRow(p.label, !!draft.sel[id], id); }).join("") +
      '</div>';
    }).join("");
    return '<div class="rcx-mod open">' + head + '<div class="rcx-modbody">' + body + '</div></div>';
  }
  function permRow(label, on, id) {
    return '<div class="rcx-perm"><span class="rcx-permlbl">' + esc(label) + '</span>' + toggleHtml(on, "perm", 'data-perm="' + id + '"') + '</div>';
  }
  function bindEditor() {
    $$('[data-x="close"]', editor).forEach(function (b) { b.addEventListener("click", closeEditor); });
    var nm = $("#rxName", editor); if (nm) nm.addEventListener("input", function (e) { draft.name = e.target.value; });
    var ds = $("#rxDesc", editor); if (ds) ds.addEventListener("input", function (e) { draft.desc = e.target.value; });
    var st = $("#rxStatus", editor); if (st) st.addEventListener("click", function () { draft.on = !draft.on; renderEditor(); });
    var ap = $("#rxAllPerms", editor); if (ap) ap.addEventListener("click", function () {
      var on = !ap.classList.contains("on");
      if (on) { ALL_PERMS.forEach(function (p) { draft.sel[p] = 1; }); }
      else { draft.sel = {}; }
      renderEditor();
    });
    $$(".rcx-modhead", editor).forEach(function (h) { h.addEventListener("click", function (e) {
      if (e.target.closest(".rcx-selall")) return; var k = h.getAttribute("data-mod"); expanded[k] = !expanded[k]; renderEditor();
    }); });
    $$("[data-modall]", editor).forEach(function (b) { b.addEventListener("click", function (e) {
      e.stopPropagation(); var k = b.getAttribute("data-modall"), on = !b.classList.contains("on");
      MOD_PERMS[k].forEach(function (p) { if (on) draft.sel[p] = 1; else delete draft.sel[p]; }); renderEditor();
    }); });
    $$("[data-grpall]", editor).forEach(function (b) { b.addEventListener("click", function (e) {
      e.stopPropagation(); var parts = b.getAttribute("data-grpall").split("|"), mKey = parts[0], gKey = parts[1];
      var m = MODULES.filter(function (x) { return x.key === mKey; })[0], grp = m.groups.filter(function (x) { return x.key === gKey; })[0];
      var on = !b.classList.contains("on");
      grp.perms.forEach(function (p) { var id = mKey + "." + gKey + "." + p.key; if (on) draft.sel[id] = 1; else delete draft.sel[id]; }); renderEditor();
    }); });
    $$("[data-perm]", editor).forEach(function (b) { b.addEventListener("click", function () {
      var id = b.getAttribute("data-perm"); if (draft.sel[id]) delete draft.sel[id]; else draft.sel[id] = 1; renderEditor();
    }); });
    var sv = $("#rxSave", editor); if (sv) sv.addEventListener("click", saveDraft);
  }
  function saveDraft() {
    var name = (draft.name || "").trim();
    if (!name) { toast("Enter a role name"); return; }
    var perms = Object.keys(draft.sel).filter(function (k) { return draft.sel[k]; });
    if (editId) {
      var r = getRole(editId); if (r) { r.name = name; r.desc = (draft.desc || "").trim(); r.on = draft.on; r.perms = perms; }
    } else {
      roles.push({ id: "r" + Date.now().toString(36), name: name, desc: (draft.desc || "").trim() || "Custom role", on: draft.on, perms: perms });
      page = Math.ceil(roles.length / PP);
    }
    save(); closeEditor(); if (view) renderTab(view, onChangeCb); notify();
    toast(editId ? "Role updated" : "Role created");
  }

  /* ----- confirm modal (scoped to settings pane) ----- */
  var cScrim, host = document.getElementById("app-settings");
  function confirmModal(title, sub, go, cb) {
    if (!host) host = document.body;
    if (!cScrim) { cScrim = document.createElement("div"); cScrim.className = "ax-modal-scrim"; host.appendChild(cScrim); cScrim.addEventListener("click", function (e) { if (e.target === cScrim) cScrim.classList.remove("show"); }); }
    cScrim.innerHTML = '<div class="ax-modal"><div class="mic">' + I.warn + '</div><div class="mt">' + esc(title) + '</div><div class="ms">' + esc(sub) + '</div><div class="mb"><button class="keep" id="rcKeep">Keep</button><button class="go" id="rcGo">' + esc(go) + '</button></div></div>';
    $("#rcKeep", cScrim).addEventListener("click", function () { cScrim.classList.remove("show"); });
    $("#rcGo", cScrim).addEventListener("click", function () { cScrim.classList.remove("show"); if (cb) cb(); });
    requestAnimationFrame(function () { cScrim.classList.add("show"); });
  }

  /* =========================================================
     PUBLIC API
     ========================================================= */
  window.AskEvaRoles = {
    modules: MODULES,
    total: function () { return TOTAL; },
    list: function () { return roles.slice(); },
    active: function () { return roles.filter(function (r) { return r.on !== false; }); },
    names: function () { return roles.map(function (r) { return r.name; }); },
    activeNames: function () { return roles.filter(function (r) { return r.on !== false; }).map(function (r) { return r.name; }); },
    get: getByName,
    permCount: function (name) { var r = getByName(name); return r ? (r.perms || []).length : 0; },
    isActive: function (name) { var r = getByName(name); return r ? r.on !== false : true; },
    modsFor: function (name) { return modsForRole(getByName(name)); },
    /* short module breakdown for an agent's role card */
    summary: function (name) {
      var r = getByName(name); if (!r) return [];
      return MODULES.map(function (m) { var c = 0; MOD_PERMS[m.key].forEach(function (p) { if ((r.perms || []).indexOf(p) > -1) c++; }); return { key: m.key, name: m.name, icon: m.icon, sel: c, total: MOD_PERMS[m.key].length }; })
        .filter(function (x) { return x.sel > 0; });
    },
    renderTab: renderTab,
    openEditor: openEditor,
    on: function (cb) { document.addEventListener("roles:changed", cb); }
  };
})();
