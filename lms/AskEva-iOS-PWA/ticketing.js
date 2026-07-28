/* =========================================================
   AskEva — Ticketing (working module)
   Owns #app-ticketing: list, ticket thread (detail + reply),
   status / priority / assignee changes, resolve / reopen,
   create, delete + localStorage. Reuses shared ax- primitives.
   ========================================================= */
(function () {
  "use strict";
  var $  = function (s, r) { return (r || document).querySelector(s); };
  var $$ = function (s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); };
  var pane = document.getElementById("app-ticketing");
  if (!pane) return;

  var toastT;
  function toast(msg) {
    var t = document.getElementById("toast"); if (!t) return;
    t.textContent = msg;
    t.style.opacity = "1"; t.style.transform = "translateX(-50%) translateY(0)";
    clearTimeout(toastT);
    toastT = setTimeout(function () { t.style.opacity = "0"; t.style.transform = "translateX(-50%) translateY(20px)"; }, 1900);
  }
  function esc(s) { return String(s == null ? "" : s).replace(/[&<>"]/g, function (c) {
    return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]; }); }

  /* ---------- icons ---------- */
  var I = {
    back:  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M15 19l-7-7 7-7"/></svg>',
    more:  '<svg viewBox="0 0 24 24" fill="currentColor"><circle cx="12" cy="5" r="2"/><circle cx="12" cy="12" r="2"/><circle cx="12" cy="19" r="2"/></svg>',
    plus:  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"><path d="M12 5v14M5 12h14"/></svg>',
    check: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="m5 12 4 4 10-11"/></svg>',
    x:     '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"><path d="M6 6l12 12M18 6 6 18"/></svg>',
    chevR: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m9 6 6 6-6 6"/></svg>',
    send:  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 12l16-8-6 16-3-7-7-1Z"/></svg>',
    phone: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linejoin="round"><path d="M5 4h3l1.5 4-2 1.5a12 12 0 0 0 5 5L14 12l4 1.5V17a2 2 0 0 1-2 2A14 14 0 0 1 5 6Z"/></svg>',
    msg:   '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linejoin="round"><path d="M21 12a8 8 0 0 1-11.6 7.1L4 20l1-5.2A8 8 0 1 1 21 12Z"/></svg>',
    flag:  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M5 21V4M5 4h11l-2 4 2 4H5"/></svg>',
    user:  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="8" r="4"/><path d="M4 21c0-4 3.6-6 8-6s8 2 8 6"/></svg>',
    bldg:  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linejoin="round"><path d="M4 21V5a2 2 0 0 1 2-2h7a2 2 0 0 1 2 2v16M15 21V9h3a2 2 0 0 1 2 2v10"/><path d="M8 7h3M8 11h3M8 15h3" stroke-linecap="round"/></svg>',
    tag:   '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 12V5a2 2 0 0 1 2-2h7l9 9-9 9-9-9Z"/><circle cx="8" cy="8" r="1.4" fill="currentColor"/></svg>',
    clock: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3.5 2"/></svg>',
    chan:  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 5h16v11H7l-3 3V5Z"/></svg>',
    assign:'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="9" cy="8" r="3.4"/><path d="M3.5 19c0-3 2.5-4.6 5.5-4.6 1.2 0 2.3.25 3.2.7"/><path d="M17 14v6M14 17h6"/></svg>',
    note:  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 5h16M4 10h16M4 15h10"/></svg>',
    trash: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 7h16M9 7V5a2 2 0 0 1 2-2h2a2 2 0 0 1 2 2v2M6 7l1 13a2 2 0 0 0 2 2h6a2 2 0 0 0 2-2l1-13"/></svg>',
    search:'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><circle cx="11" cy="11" r="7"/><path d="M21 21l-4.3-4.3"/></svg>',
    reopen:'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 12a9 9 0 1 0 3-6.7L3 8M3 4v4h4"/></svg>',
    warn:  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 9v4M12 17h.01"/><path d="M10.3 3.9 2 19a2 2 0 0 0 1.7 3h16.6a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0Z"/></svg>',
    cart:  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="9" cy="20" r="1.4"/><circle cx="18" cy="20" r="1.4"/><path d="M2 3h3l2.5 13h11l2-9H6"/></svg>',
    card:  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="2" y="5" width="20" height="14" rx="2.5"/><path d="M2 10h20"/></svg>',
    book:  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 5a2 2 0 0 1 2-2h13v16H6a2 2 0 0 0-2 2V5Z"/><path d="M6 17h13"/></svg>',
    gear:  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="3.2"/><path d="M19.4 13.5a7.7 7.7 0 0 0 0-3l1.8-1.3-2-3.4-2.1.9a7.5 7.5 0 0 0-2.6-1.5L12 2h-4l-.5 2.2A7.5 7.5 0 0 0 4.9 5.7L2.8 4.8l-2 3.4 1.8 1.3a7.7 7.7 0 0 0 0 3l-1.8 1.3 2 3.4 2.1-.9a7.5 7.5 0 0 0 2.6 1.5L8 22h4l.5-2.2a7.5 7.5 0 0 0 2.6-1.5l2.1.9 2-3.4-1.8-1.3Z"/></svg>',
    bot:   '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="4" y="8" width="16" height="11" rx="3"/><path d="M12 8V4M9 13h.01M15 13h.01M2 12v3M22 12v3"/></svg>',
    dots:  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12h.01M12 12h.01M19 12h.01"/></svg>'
  };

  /* ---------- config ---------- */
  var CATS = {
    Delivery: I.cart, Billing: I.card, Catalog: I.book, Account: I.gear, Chatbot: I.bot, Other: I.dots
  };
  var CAT_ORDER = ["Delivery", "Billing", "Catalog", "Account", "Chatbot", "Other"];
  var CHANNELS = ["WhatsApp", "Email", "Phone", "Web"];
  var PRIO = { high: "High", med: "Medium", low: "Low" };
  var STATUS = { open: "Open", pending: "Pending", resolved: "Resolved" };

  var CUSTOMERS = [
    { id: "aarav",  name: "Aarav Mehta",  company: "Burger Street", color: "#22B0E8", initials: "AM", mobile: "98765 43210" },
    { id: "priya",  name: "Priya Nair",   company: "Catalog Co",    color: "#7C5CFF", initials: "PN", mobile: "98220 11233" },
    { id: "rohan",  name: "Rohan Das",    company: "Das Retail",    color: "#FF9416", initials: "RD", mobile: "99004 55678" },
    { id: "sneha",  name: "Sneha Iyer",   company: "Iyer & Co",     color: "#E5499A", initials: "SI", mobile: "90080 12345" },
    { id: "vikram", name: "Vikram Joshi", company: "Joshi Foods",   color: "#2BA84A", initials: "VJ", mobile: "97411 22008" },
    { id: "meera",  name: "Meera Kapoor", company: "Kapoor Mart",   color: "#1E7FB0", initials: "MK", mobile: "96320 78451" }
  ];
  function custById(id) { for (var i = 0; i < CUSTOMERS.length; i++) if (CUSTOMERS[i].id === id) return CUSTOMERS[i]; return null; }

  /* agents come from the shared people store (Settings → Agents) so anyone
     created/edited/deactivated there is instantly assignable here. Falls back to
     a minimal cast only if the store hasn't loaded yet. */
  var FALLBACK_AGENTS = [
    { id: "eshan", name: "Eshan Rao", role: "Super Admin", color: "#2BA84A", initials: "ER", you: true },
    { id: "kavya", name: "Kavya S",   role: "Support Lead", color: "#7C5CFF", initials: "KS" },
    { id: "dev",   name: "Dev Patel", role: "Agent",        color: "#FF9416", initials: "DP" }
  ];
  function agentsList() { return (window.AskEvaPeople && AskEvaPeople.roster) ? AskEvaPeople.roster("ticket") : FALLBACK_AGENTS; }
  function agentById(id) { if (!id || id === "unassigned") return null; var L = agentsList(); for (var i = 0; i < L.length; i++) if (L[i].id === id) return L[i]; var p = window.AskEvaPeople && AskEvaPeople.byId ? AskEvaPeople.byId(id) : null; return p || null; }

  /* ---------- time/age ---------- */
  function ago(mins) {
    if (mins <= 0) return "just now";
    if (mins < 60) return mins + "m";
    if (mins < 1440) return Math.floor(mins / 60) + "h";
    return Math.floor(mins / 1440) + "d";
  }
  function agoLong(mins) {
    if (mins <= 0) return "Just now";
    if (mins < 60) return mins + " min ago";
    if (mins < 1440) { var h = Math.floor(mins / 60); return h + (h === 1 ? " hour" : " hours") + " ago"; }
    var d = Math.floor(mins / 1440); return d + (d === 1 ? " day" : " days") + " ago";
  }
  function updLabel(mins) { return mins <= 0 ? "Updated just now" : "Updated " + ago(mins) + " ago"; }

  /* ---------- seed ---------- */
  var SEED = [
    { id: "t1", num: "TK-4471", subject: "Order not delivered on time", customer: "aarav", priority: "high", status: "open",
      category: "Delivery", channel: "WhatsApp", assignee: "eshan", created: 95, updated: 22, unread: true,
      thread: [
        { from: "customer", text: "My order #4471 was supposed to arrive yesterday by 6 PM but it's still not here. This is for a customer event today.", mins: 95 },
        { from: "agent", who: "eshan", text: "Hi Aarav, really sorry about the delay. Let me pull up the courier status right now and get back to you in a few minutes.", mins: 70 },
        { from: "note", who: "eshan", text: "Courier shows \"out for delivery\" since 9 AM. Flagging the delivery partner.", mins: 60 },
        { from: "customer", text: "Please hurry, the event starts at 2 PM.", mins: 22 }
      ] },
    { id: "t2", num: "TK-4468", subject: "Catalog price mismatch on 3 items", customer: "priya", priority: "med", status: "pending",
      category: "Catalog", channel: "Email", assignee: "kavya", created: 320, updated: 180, unread: false,
      thread: [
        { from: "customer", text: "Three items in our catalog show old prices on WhatsApp but new prices on the dashboard. Customers are confused.", mins: 320 },
        { from: "agent", who: "kavya", text: "Thanks for flagging Priya. This looks like a sync delay. I've escalated to the catalog team — should refresh within 24h.", mins: 180 }
      ] },
    { id: "t3", num: "TK-4465", subject: "Request to update business hours", customer: "rohan", priority: "low", status: "open",
      category: "Account", channel: "WhatsApp", assignee: "unassigned", created: 480, updated: 480, unread: true,
      thread: [ { from: "customer", text: "Can you update our store hours to 10 AM – 11 PM on the auto-reply?", mins: 480 } ] },
    { id: "t4", num: "TK-4460", subject: "Payment link expired before checkout", customer: "sneha", priority: "high", status: "open",
      category: "Billing", channel: "Web", assignee: "dev", created: 1500, updated: 200, unread: false,
      thread: [
        { from: "customer", text: "The payment link you sent expired and now I can't complete my purchase.", mins: 1500 },
        { from: "agent", who: "dev", text: "Apologies Sneha — I've generated a fresh link with a 24h validity. Sending it on WhatsApp now.", mins: 200 }
      ] },
    { id: "t5", num: "TK-4455", subject: "Refund requested for duplicate order", customer: "vikram", priority: "med", status: "pending",
      category: "Billing", channel: "Phone", assignee: "eshan", created: 2880, updated: 1300, unread: false,
      thread: [
        { from: "customer", text: "I was charged twice for the same order. Need a refund for one.", mins: 2880 },
        { from: "agent", who: "eshan", text: "Confirmed the duplicate charge. Refund initiated — it'll reflect in 5–7 business days.", mins: 1300 }
      ] },
    { id: "t6", num: "TK-4452", subject: "How to add a new team member", customer: "priya", priority: "low", status: "resolved",
      category: "Account", channel: "Email", assignee: "kavya", created: 4320, updated: 4000, unread: false,
      thread: [
        { from: "customer", text: "How do I invite a teammate to our AskEva workspace?", mins: 4320 },
        { from: "agent", who: "kavya", text: "Go to Settings → Team Members → Invite. You can set their role and modules there. Let me know if you get stuck!", mins: 4100 },
        { from: "system", text: "Marked resolved", mins: 4000 }
      ] },
    { id: "t7", num: "TK-4448", subject: "Chatbot not replying to keywords", customer: "aarav", priority: "high", status: "resolved",
      category: "Chatbot", channel: "WhatsApp", assignee: "dev", created: 7200, updated: 6800, unread: false,
      thread: [
        { from: "customer", text: "The bot stopped replying to \"menu\" and \"hours\".", mins: 7200 },
        { from: "agent", who: "dev", text: "Found it — a keyword rule was disabled after the last update. Re-enabled and tested. Working now.", mins: 6900 },
        { from: "system", text: "Marked resolved", mins: 6800 }
      ] }
  ];

  /* ---------- store ---------- */
  var KEY = "askeva.tickets.v1";
  var tickets;
  try { tickets = JSON.parse(localStorage.getItem(KEY)) || null; } catch (e) { tickets = null; }
  if (!tickets || !tickets.length) tickets = SEED.slice();
  function save() { try { localStorage.setItem(KEY, JSON.stringify(tickets)); } catch (e) {} }
  function getT(id) { for (var i = 0; i < tickets.length; i++) if (tickets[i].id === id) return tickets[i]; return null; }
  function uid() { return "t" + Date.now().toString(36) + Math.floor(Math.random() * 1e4).toString(36); }
  var seq = 4472;
  function nextNum() {
    var max = 4471;
    tickets.forEach(function (t) { var n = parseInt((t.num || "").replace("TK-", ""), 10); if (n > max) max = n; });
    return "TK-" + (max + 1);
  }

  /* ============================================================
     LIST
     ============================================================ */
  var state = { status: "open", priority: "all", q: "" };

  function counts() {
    var c = { open: 0, pending: 0, resolved: 0, all: tickets.length };
    tickets.forEach(function (t) { if (c[t.status] != null) c[t.status]++; });
    return c;
  }
  function matchFilter(t) {
    var okS = (state.status === "all") || (t.status === state.status);
    var okP = (state.priority === "all") || (t.priority === state.priority);
    var q = state.q.toLowerCase();
    var cust = custById(t.customer) || {};
    var okQ = !q || (t.subject + " " + t.num + " " + (cust.name || "") + " " + (cust.company || "") + " " + t.category).toLowerCase().indexOf(q) > -1;
    return okS && okP && okQ;
  }

  function renderList() {
    var c = counts();
    $$(".tx-chip", pane).forEach(function (ch) {
      var f = ch.getAttribute("data-f");
      ch.classList.toggle("on", f === state.status);
      var n = ch.querySelector(".n"); if (n && c[f] != null) n.textContent = c[f];
    });
    var pill = $("#txPrioPill");
    if (pill) pill.innerHTML = (state.priority === "all" ? "All" : PRIO[state.priority]) + " \u25be";

    var list = tickets.filter(matchFilter).sort(function (a, b) {
      var pr = { high: 0, med: 1, low: 2 };
      if (a.status !== b.status) return 0;
      if (pr[a.priority] !== pr[b.priority]) return pr[a.priority] - pr[b.priority];
      return a.updated - b.updated;
    });

    var head = $("#txHead"), cnt = $("#txCount"), sub = $("#txHeadSub");
    var base = state.status === "all" ? "All tickets" : STATUS[state.status] + " tickets";
    if (head) head.textContent = (state.priority === "all" ? base : PRIO[state.priority] + " \u00b7 " + base);
    if (cnt) cnt.textContent = list.length + (state.status === "resolved" ? " resolved" : state.status === "all" ? " total" : " active");
    if (sub) sub.textContent = c.open + " open \u00b7 " + c.all + " total";

    var host = $("#txList");
    if (!list.length) {
      host.innerHTML = '<div class="tx-empty"><div class="ic">' + I.tag + '</div><div class="t">No tickets here</div>' +
        '<div class="s">' + (state.q ? "Try a different search." : "Tap + to raise a new ticket.") + '</div></div>';
      return;
    }
    host.innerHTML = list.map(cardHTML).join("");
    $$(".tx-card", host).forEach(function (el) {
      el.addEventListener("click", function () { openTicket(el.getAttribute("data-id")); });
    });
  }

  function cardHTML(t) {
    var cust = custById(t.customer) || { name: "Unknown", initials: "?", color: "#999" };
    var last = t.thread[t.thread.length - 1] || { text: "" };
    var ageCls = (t.status !== "resolved" && t.updated > 1440) ? " late" : (t.status !== "resolved" && t.updated > 240) ? " warn" : "";
    return '<div class="tk-card tx-card" data-id="' + t.id + '" data-status="' + t.status + '" data-priority="' + t.priority + '">' +
      '<div class="tk-top"><span class="tk-left"><span class="tk-id">#' + esc(t.num) + '</span>' +
        '<span class="tk-cat">' + esc(t.category) + '</span></span>' +
        '<span class="tk-prio ' + t.priority + '">' + PRIO[t.priority] + '</span></div>' +
      '<div class="tk-subj-row"><div style="flex:1;min-width:0"><div class="tk-subj">' + esc(t.subject) + '</div>' +
        '<div class="tk-snip">' + esc(last.text) + '</div></div>' +
        (t.unread && t.status !== "resolved" ? '<span class="tk-unread" title="Unread"></span>' : '') +
        '<span class="chev">' + I.chevR + '</span></div>' +
      '<div class="tk-foot"><span class="tk-cust"><span class="av" style="background:' + cust.color + '">' + esc(cust.initials) + '</span>' + esc(cust.name) + '</span>' +
        '<span class="tk-meta"><span class="tk-age' + ageCls + '">' + ago(t.updated) + '</span>' +
        '<span class="tk-status ' + t.status + '">' + STATUS[t.status] + '</span></span></div>' +
    '</div>';
  }

  /* ============================================================
     OVERLAYS
     ============================================================ */
  var detailEl = $("#txDetail"), formEl = $("#txForm");
  function showOverlay(el) { el.classList.add("show"); }
  function hideOverlay(el) { el.classList.remove("show"); }

  /* ============================================================
     TICKET DETAIL (thread + reply)
     ============================================================ */
  var curId = null, noteMode = false;
  function openTicket(id) {
    var t = getT(id); if (!t) return;
    curId = id; noteMode = false;
    t.unread = false; save();
    renderTicket(t);
    showOverlay(detailEl);
  }

  function renderTicket(t) {
    var cust = custById(t.customer) || { name: "Unknown", company: "", initials: "?", color: "#999" };
    var ag = t.assignee && t.assignee !== "unassigned" ? agentById(t.assignee) : null;
    var resolved = t.status === "resolved";

    var quick = '<div class="tx-quickbar">' +
      (resolved
        ? qbtn(I.reopen, "Reopen", "reopen")
        : qbtn(I.check, "Resolve", "resolve")) +
      qbtn(I.flag, "Priority", "priority") +
      qbtn(I.assign, "Assign", "assign") +
      qbtn(I.phone, "Call", "call") +
    '</div>';

    var info = '<div class="ax-info">' +
      infoRow(I.user, "Requester", esc(cust.name)) +
      (cust.company ? infoRow(I.bldg, "Company", esc(cust.company)) : "") +
      infoRow(I.chan, "Channel", esc(t.channel)) +
      infoRow(CATS[t.category] || I.tag, "Category", esc(t.category)) +
      infoRow(I.assign, "Assigned to", ag ? esc(ag.name) + (ag.you ? " (You)" : "") : '<span class="v" style="color:var(--ink-4)">Unassigned</span>', !ag) +
      infoRow(I.flag, "Priority", '<span class="tx-prio ' + t.priority + '" style="margin-top:2px">' + PRIO[t.priority] + '</span>', true) +
      infoRow(I.clock, "Opened", agoLong(t.created)) +
    '</div>';

    var thread = '<div class="tx-threadlbl">Conversation</div><div class="tx-thread" id="txThread">' +
      t.thread.map(function (m) { return msgHTML(m, cust); }).join("") + '</div>';

    detailEl.innerHTML =
      '<div class="ax-bar">' +
        '<button class="ax-iconbtn" data-x="back" aria-label="Back">' + I.back + '</button>' +
        '<div class="ttl">#' + esc(t.num) + '</div>' +
        '<button class="ax-iconbtn" data-act="menu" aria-label="More">' + I.more + '</button>' +
      '</div>' +
      '<div class="ax-scroll" id="txScroll">' +
        '<div class="tx-subjbig">' + esc(t.subject) + '</div>' +
        '<div class="tx-idline"><span>#' + esc(t.num) + '</span><span class="dot"></span><span>' + esc(t.channel) +
          '</span><span class="dot"></span><span>' + updLabel(t.updated) + '</span></div>' +
        '<div class="tx-badges"><span class="ax-status ' + statusCls(t.status) + '">' + STATUS[t.status] + '</span>' +
          '<span class="tx-prio ' + t.priority + '">' + PRIO[t.priority] + ' priority</span></div>' +
        quick + info + thread +
      '</div>' +
      composerHTML(t);

    bindTicket(t);
    var sc = $("#txScroll"); if (sc) sc.scrollTop = sc.scrollHeight;
  }

  function statusCls(s) { return s === "open" ? "confirmed" : s === "pending" ? "pending" : "completed"; }
  function qbtn(ic, l, act) { return '<button class="tx-qbtn" data-act="' + act + '"><span class="ic">' + ic + '</span><span class="l">' + l + '</span></button>'; }
  function infoRow(ic, k, v, raw) {
    return '<div class="r"><div class="ic">' + ic + '</div><div class="b"><div class="k">' + k + '</div>' +
      (raw ? v : '<div class="v">' + v + '</div>') + '</div></div>';
  }

  function msgHTML(m, cust) {
    if (m.from === "system") return '<div class="tx-sysline"><span>' + esc(m.text) + ' · ' + msgTime(m.mins) + '</span></div>';
    if (m.from === "note") {
      var na = agentById(m.who) || { name: "Agent", color: "#999", initials: "A" };
      return '<div class="tx-msg note out"><span class="av" style="background:' + na.color + '">' + esc(na.initials) + '</span>' +
        '<div class="bub"><div class="who"><span class="tag">Internal note</span>' + esc(na.name) + '</div>' +
        '<div class="tx-txt">' + esc(m.text) + '</div><div class="tm">' + msgTime(m.mins) + '</div></div></div>';
    }
    if (m.from === "agent") {
      var a = agentById(m.who) || { name: "Agent", color: "#2BA84A", initials: "A" };
      return '<div class="tx-msg out"><span class="av" style="background:' + a.color + '">' + esc(a.initials) + '</span>' +
        '<div class="bub"><div class="who">' + esc(a.name) + '<span class="tag">Agent</span></div>' +
        '<div class="tx-txt">' + esc(m.text) + '</div><div class="tm">' + msgTime(m.mins) + '</div></div></div>';
    }
    // customer
    return '<div class="tx-msg"><span class="av" style="background:' + cust.color + '">' + esc(cust.initials) + '</span>' +
      '<div class="bub"><div class="who">' + esc(cust.name) + '</div>' +
      '<div class="tx-txt">' + esc(m.text) + '</div><div class="tm">' + msgTime(m.mins) + '</div></div></div>';
  }
  function msgTime(mins) { return mins <= 0 ? "Just now" : ago(mins) + " ago"; }

  function composerHTML(t) {
    if (t.status === "resolved") {
      return '<div class="tx-composer"><button class="ax-btn ghost" data-act="reopen" style="width:100%">' + I.reopen + 'Reopen ticket</button></div>';
    }
    return '<div class="tx-composer">' +
      '<div class="tx-comptools">' +
        '<button class="tx-tool" id="txNoteToggle">' + I.note + 'Internal note</button>' +
        '<button class="tx-tool resolve" data-act="resolve">' + I.check + 'Resolve</button>' +
      '</div>' +
      '<div class="tx-comprow"><div class="tx-compbox"><textarea id="txReply" rows="1" placeholder="Reply to customer…"></textarea></div>' +
        '<button class="tx-send" id="txSend" disabled>' + I.send + '</button></div>' +
    '</div>';
  }

  function bindTicket(t) {
    detailEl.querySelector('[data-x="back"]').addEventListener("click", function () { hideOverlay(detailEl); renderList(); });
    $$("[data-act]", detailEl).forEach(function (b) {
      b.addEventListener("click", function () { ticketAction(b.getAttribute("data-act"), t); });
    });
    var ta = $("#txReply", detailEl), send = $("#txSend", detailEl), noteBtn = $("#txNoteToggle", detailEl);
    if (ta) {
      ta.addEventListener("input", function () {
        ta.style.height = "auto"; ta.style.height = Math.min(ta.scrollHeight, 96) + "px";
        if (send) send.disabled = !ta.value.trim();
      });
      ta.addEventListener("keydown", function (e) {
        if (e.key === "Enter" && (e.metaKey || e.ctrlKey)) { e.preventDefault(); sendReply(t); }
      });
    }
    if (send) send.addEventListener("click", function () { sendReply(t); });
    if (noteBtn) noteBtn.addEventListener("click", function () {
      noteMode = !noteMode;
      noteBtn.classList.toggle("on", noteMode);
      if (ta) ta.placeholder = noteMode ? "Add a private internal note…" : "Reply to customer…";
    });
  }

  function sendReply(t) {
    var ta = $("#txReply", detailEl); if (!ta) return;
    var txt = ta.value.trim(); if (!txt) return;
    t.thread.push({ from: noteMode ? "note" : "agent", who: "eshan", text: txt, mins: 0 });
    t.updated = 0;
    if (!noteMode && t.status === "open") t.status = "pending";   // replied → awaiting customer
    save();
    var wasNote = noteMode;
    renderTicket(t);
    renderList();
    toast(wasNote ? "Internal note added" : "Reply sent");
  }

  function ticketAction(act, t) {
    switch (act) {
      case "menu":     openActionSheet(t); break;
      case "resolve":  setStatus(t, "resolved"); break;
      case "reopen":   setStatus(t, "open"); break;
      case "priority": openPriority(t); break;
      case "assign":   openAssign(t); break;
      case "call":     var cu = custById(t.customer) || { name: "Customer" }; if (window.__callScreen) window.__callScreen({ name: cu.name, mobile: cu.mobile ? "91 " + cu.mobile : "" }); else toast("Calling " + cu.name + "…"); break;
      case "status":   openStatus(t); break;
      case "delete":   confirmDelete(t); break;
    }
  }

  function setStatus(t, s) {
    if (t.status === s) return;
    t.status = s;
    t.thread.push({ from: "system", text: "Marked " + STATUS[s].toLowerCase(), mins: 0 });
    t.updated = 0; save();
    renderTicket(t); renderList();
    toast("Ticket " + STATUS[s].toLowerCase());
  }

  /* ---------- action sheet (more) ---------- */
  function openActionSheet(t) {
    var html = '<div class="ax-grip"></div><div class="ax-sheet-head"><div class="ax-sheet-ttl">Ticket actions</div></div>' +
      '<div class="ax-optlist">' +
        actOpt("status", I.tag, "Change status", STATUS[t.status]) +
        actOpt("priority", I.flag, "Change priority", PRIO[t.priority]) +
        actOpt("assign", I.assign, "Assign to", assigneeName(t)) +
        '<button class="ax-opt" data-a="delete" style="margin-top:4px"><span class="av" style="background:#FDEAE3;color:#C23A18">' + I.trash + '</span>' +
          '<span class="t"><span class="nm" style="color:#C23A18">Delete ticket</span></span></button>' +
      '</div>';
    var s = openSheet(html);
    $$("[data-a]", s).forEach(function (b) {
      b.addEventListener("click", function () { closeSheet(); ticketAction(b.getAttribute("data-a"), t); });
    });
  }
  function actOpt(a, ic, label, val) {
    return '<button class="ax-opt" data-a="' + a + '"><span class="av empty" style="background:var(--accent-soft);color:var(--accent-deep)">' + ic + '</span>' +
      '<span class="t"><span class="nm">' + label + '</span><span class="co">' + esc(val) + '</span></span><span class="chev" style="opacity:1;color:var(--ink-4)">' + I.chevR + '</span></button>';
  }
  function assigneeName(t) { var a = t.assignee && t.assignee !== "unassigned" ? agentById(t.assignee) : null; return a ? a.name : "Unassigned"; }

  /* ---------- status sheet ---------- */
  function openStatus(t) {
    var opts = [["open", "Open"], ["pending", "Pending"], ["resolved", "Resolved"]];
    radioSheet("Change status", opts.map(function (o) {
      return { v: o[0], label: o[1], dot: '<span class="sdot ' + o[0] + '"></span>', on: t.status === o[0] };
    }), function (v) { setStatus(t, v); });
  }
  function openPriority(t) {
    var opts = [["high", "High"], ["med", "Medium"], ["low", "Low"]];
    radioSheet("Set priority", opts.map(function (o) {
      return { v: o[0], label: o[1], dot: '<span class="pdot ' + o[0] + '"></span>', on: t.priority === o[0] };
    }), function (v) {
      t.priority = v; t.updated = 0; save(); renderTicket(t); renderList(); toast("Priority set to " + PRIO[v]);
    });
  }
  function openAssign(t) {
    var html = '<div class="ax-grip"></div><div class="ax-sheet-head"><div class="ax-sheet-ttl">Assign ticket</div></div><div class="ax-optlist">' +
      agentsList().map(function (a) {
        return '<button class="ax-opt' + (t.assignee === a.id ? " on" : "") + '" data-id="' + a.id + '"><span class="av" style="background:' + a.color + '">' + esc(a.initials) + '</span>' +
          '<span class="t"><span class="nm">' + esc(a.name) + (a.you ? " (You)" : "") + '</span><span class="co">' + esc(a.role) + '</span></span><span class="tick">' + I.check + '</span></button>';
      }).join("") +
      '<button class="ax-opt' + (t.assignee === "unassigned" || !t.assignee ? " on" : "") + '" data-id="unassigned"><span class="av empty" style="background:var(--surface-3);color:var(--ink-4)">' + I.user + '</span>' +
        '<span class="t"><span class="nm">Unassigned</span></span><span class="tick">' + I.check + '</span></button>' +
      '</div>';
    var s = openSheet(html);
    $$(".ax-opt", s).forEach(function (b) {
      b.addEventListener("click", function () {
        t.assignee = b.getAttribute("data-id"); t.updated = 0; save();
        closeSheet(); renderTicket(t); renderList();
        toast(t.assignee === "unassigned" ? "Ticket unassigned" : "Assigned to " + agentById(t.assignee).name);
      });
    });
  }

  function radioSheet(title, items, onPick) {
    var html = '<div class="ax-grip"></div><div class="ax-sheet-head"><div class="ax-sheet-ttl">' + esc(title) + '</div></div><div class="ax-reasons">' +
      items.map(function (it) {
        return '<button class="ax-reason' + (it.on ? " on" : "") + '" data-v="' + it.v + '">' + (it.dot || "") + esc(it.label) + '</button>';
      }).join("") + '</div>';
    var s = openSheet(html);
    $$(".ax-reason", s).forEach(function (b) {
      b.addEventListener("click", function () { closeSheet(); onPick(b.getAttribute("data-v")); });
    });
  }

  function confirmDelete(t) {
    showConfirm({
      title: "Delete ticket?",
      sub: "Ticket #" + t.num + " and its full conversation will be permanently removed.",
      go: "Delete",
      onGo: function () {
        tickets = tickets.filter(function (x) { return x.id !== t.id; });
        save(); hideOverlay(detailEl); renderList(); toast("Ticket deleted");
      }
    });
  }

  /* ============================================================
     CREATE
     ============================================================ */
  var draft = null;
  /* ---- configured-from-Settings helpers (Departments + Ticket Form fields) ---- */
  function catList() { var d = window.TK && window.TK.tsetDepts && window.TK.tsetDepts(); return (d && d.length) ? d.map(function (x) { return x.name; }) : CAT_ORDER; }
  function catIcon(n) { return CATS[n] || I.tag; }
  function tfFields() { return (window.TK && window.TK.ticketForm) ? window.TK.ticketForm("ticketing") : null; }
  function tfGet(id) { var f = tfFields(); if (!f) return null; for (var i = 0; i < f.length; i++) if (f[i].id === id) return f[i]; return null; }
  function reqStar(on) { return on ? ' <span style="color:#EF5350">*</span>' : ''; }
  function tfExtraHTML() {
    var f = tfFields(); if (!f) return '';
    return f.filter(function (x) { return x.id !== 'subject' && x.id !== 'desc' && x.id !== 'dept'; }).map(function (x) {
      var val = esc(draft.cf[x.id] || '');
      var lbl = '<label class="ax-label">' + esc(x.name) + reqStar(x.req) + '</label>';
      if (x.type === 'document') {
        var has = !!draft.cf[x.id];
        return '<div class="ax-field">' + lbl + '<button class="ax-pick" data-doc="' + x.id + '"><span class="av empty">' + I.tag + '</span><span class="t"><span class="a' + (has ? '' : ' ph') + '">' + (has ? esc(draft.cf[x.id]) : esc(x.ph || 'Upload document')) + '</span></span><span class="chev">' + I.chevR + '</span></button></div>';
      }
      if (x.type === 'textarea') return '<div class="ax-field">' + lbl + '<div class="ax-control"><textarea data-cf="' + x.id + '" rows="3" placeholder="' + esc(x.ph || '') + '">' + val + '</textarea></div></div>';
      var itype = x.type === 'number' ? 'number' : (x.type === 'date' ? 'date' : 'text');
      return '<div class="ax-field">' + lbl + '<div class="ax-control">' + I.tag + '<input data-cf="' + x.id + '" type="' + itype + '" placeholder="' + esc(x.ph || '') + '" value="' + val + '"></div></div>';
    }).join('');
  }

  function openForm() {
    var cats = catList();
    draft = { customer: null, subject: "", desc: "", priority: "med", category: (cats[0] || "Delivery"), channel: "WhatsApp", assignee: "eshan", cf: {} };
    renderForm();
    showOverlay(formEl);
  }

  function renderForm() {
    var cust = draft.customer ? custById(draft.customer) : null;
    var ag = agentById(draft.assignee);
    formEl.innerHTML =
      '<div class="ax-bar"><button class="ax-iconbtn" data-x="close" aria-label="Close">' + I.x + '</button>' +
        '<div class="ttl">New ticket</div><span class="spacer"></span></div>' +
      '<div class="ax-scroll" id="txFormScroll">' +
        '<div class="ax-field"><label class="ax-label">Customer</label>' +
          '<button class="ax-pick" id="txPickCust">' +
          (cust ? '<span class="av" style="background:' + cust.color + '">' + esc(cust.initials) + '</span><span class="t"><span class="a">' + esc(cust.name) + '</span><span class="b">' + esc(cust.company) + '</span></span>'
                : '<span class="av empty">' + I.user + '</span><span class="t"><span class="a ph">Select a customer</span><span class="b">Who raised this issue?</span></span>') +
          '<span class="chev">' + I.chevR + '</span></button></div>' +
        '<div class="ax-field"><label class="ax-label">' + esc((tfGet('subject') || {}).name || 'Subject') + reqStar(true) + '</label>' +
          '<div class="ax-control">' + I.tag + '<input id="txSubj" type="text" placeholder="' + esc((tfGet('subject') || {}).ph || 'Short summary of the issue') + '" value="' + esc(draft.subject) + '"></div></div>' +
        '<div class="ax-field"><label class="ax-label">' + esc((tfGet('desc') || {}).name || 'Description') + reqStar(true) + '</label>' +
          '<div class="ax-control"><textarea id="txDesc" rows="3" placeholder="' + esc((tfGet('desc') || {}).ph || 'What is the customer reporting?') + '">' + esc(draft.desc) + '</textarea></div></div>' +
        '<div class="ax-field"><label class="ax-label">Priority</label>' +
          '<div class="ax-chiprow" id="txPrio">' + [["high", "High"], ["med", "Medium"], ["low", "Low"]].map(function (o) {
            return '<button class="ax-pillchip' + (draft.priority === o[0] ? " on" : "") + '" data-p="' + o[0] + '">' + o[1] + '</button>';
          }).join("") + '</div></div>' +
        '<div class="ax-field"><label class="ax-label">' + esc((tfGet('dept') || {}).name || 'Category') + reqStar(true) + '</label>' +
          '<div class="ax-types" id="txCats">' + catList().map(function (k) {
            return '<button class="ax-type' + (draft.category === k ? " on" : "") + '" data-c="' + esc(k) + '"><span class="ic">' + catIcon(k) + '</span><span class="l">' + esc(k) + '</span></button>';
          }).join("") + '</div></div>' +
        tfExtraHTML() +
        '<div class="ax-field"><label class="ax-label">Channel</label>' +
          '<div class="ax-chiprow" id="txChan">' + CHANNELS.map(function (ch) {
            return '<button class="ax-pillchip' + (draft.channel === ch ? " on" : "") + '" data-ch="' + ch + '">' + ch + '</button>';
          }).join("") + '</div></div>' +
        '<div class="ax-field"><label class="ax-label">Assign to</label>' +
          '<button class="ax-pick" id="txPickAg"><span class="av" style="background:' + ag.color + '">' + esc(ag.initials) + '</span>' +
          '<span class="t"><span class="a">' + esc(ag.name) + (ag.you ? " (You)" : "") + '</span><span class="b">' + esc(ag.role) + '</span></span><span class="chev">' + I.chevR + '</span></button></div>' +
      '</div>' +
      '<div class="ax-savebar"><button class="ax-btn primary" id="txCreate">' + I.check + 'Create ticket</button></div>';
    bindForm();
  }

  function bindForm() {
    formEl.querySelector('[data-x="close"]').addEventListener("click", function () { hideOverlay(formEl); });
    $("#txPickCust").addEventListener("click", openCustPicker);
    $("#txSubj").addEventListener("input", function (e) { draft.subject = e.target.value; });
    $("#txDesc").addEventListener("input", function (e) { draft.desc = e.target.value; });
    pillGroup("#txPrio", "data-p", function (v) { draft.priority = v; });
    pillGroup("#txChan", "data-ch", function (v) { draft.channel = v; });
    $$("#txCats .ax-type").forEach(function (b) {
      b.addEventListener("click", function () {
        draft.category = b.getAttribute("data-c");
        $$("#txCats .ax-type").forEach(function (x) { x.classList.remove("on"); });
        b.classList.add("on");
      });
    });
    $("#txPickAg").addEventListener("click", openAgPicker);
    $$("[data-cf]", formEl).forEach(function (el) { el.addEventListener("input", function () { draft.cf[el.getAttribute("data-cf")] = el.value; }); });
    $$("[data-doc]", formEl).forEach(function (b) { b.addEventListener("click", function () {
      var inp = document.createElement("input"); inp.type = "file"; inp.style.display = "none"; document.body.appendChild(inp);
      inp.addEventListener("change", function () { if (inp.files && inp.files[0]) { draft.cf[b.getAttribute("data-doc")] = inp.files[0].name; } inp.remove(); renderForm(); });
      inp.click();
    }); });
    $("#txCreate").addEventListener("click", create);
  }
  function pillGroup(sel, attr, cb) {
    $$(sel + " .ax-pillchip").forEach(function (b) {
      b.addEventListener("click", function () {
        cb(b.getAttribute(attr));
        $$(sel + " .ax-pillchip").forEach(function (x) { x.classList.remove("on"); });
        b.classList.add("on");
      });
    });
  }

  function openCustPicker() {
    var html = '<div class="ax-grip"></div><div class="ax-sheet-head"><div class="ax-sheet-ttl">Choose customer</div></div>' +
      '<div class="ax-optsearch">' + I.search + '<input id="txCustSearch" type="text" placeholder="Search customers"></div>' +
      '<div class="ax-optlist" id="txCustList"></div>';
    var s = openSheet(html);
    function paint(q) {
      q = (q || "").toLowerCase();
      $("#txCustList", s).innerHTML = CUSTOMERS.filter(function (c) {
        return !q || (c.name + " " + c.company).toLowerCase().indexOf(q) > -1;
      }).map(function (c) {
        return '<button class="ax-opt' + (draft.customer === c.id ? " on" : "") + '" data-id="' + c.id + '"><span class="av" style="background:' + c.color + '">' + esc(c.initials) + '</span>' +
          '<span class="t"><span class="nm">' + esc(c.name) + '</span><span class="co">' + esc(c.company) + '</span></span><span class="tick">' + I.check + '</span></button>';
      }).join("");
      $$(".ax-opt", $("#txCustList", s)).forEach(function (b) {
        b.addEventListener("click", function () { draft.customer = b.getAttribute("data-id"); closeSheet(); renderForm(); });
      });
    }
    paint(""); $("#txCustSearch", s).addEventListener("input", function (e) { paint(e.target.value); });
  }

  function openAgPicker() {
    var html = '<div class="ax-grip"></div><div class="ax-sheet-head"><div class="ax-sheet-ttl">Assign to</div></div><div class="ax-optlist">' +
      agentsList().map(function (a) {
        return '<button class="ax-opt' + (draft.assignee === a.id ? " on" : "") + '" data-id="' + a.id + '"><span class="av" style="background:' + a.color + '">' + esc(a.initials) + '</span>' +
          '<span class="t"><span class="nm">' + esc(a.name) + (a.you ? " (You)" : "") + '</span><span class="co">' + esc(a.role) + '</span></span><span class="tick">' + I.check + '</span></button>';
      }).join("") + '</div>';
    var s = openSheet(html);
    $$(".ax-opt", s).forEach(function (b) {
      b.addEventListener("click", function () { draft.assignee = b.getAttribute("data-id"); closeSheet(); renderForm(); });
    });
  }

  function create() {
    if (!draft.customer) { toast("Pick a customer first"); openCustPicker(); return; }
    if (!draft.subject.trim()) { toast("Add a subject"); var i = $("#txSubj"); if (i) i.focus(); return; }
    var ff = tfFields();
    if (ff) { for (var fi = 0; fi < ff.length; fi++) { var f = ff[fi]; if (f.req && f.id !== 'subject' && f.id !== 'desc' && f.id !== 'dept') { if (!String(draft.cf[f.id] || "").trim()) { toast("Please fill " + f.name); return; } } } }
    var nt = { id: uid(), num: nextNum(), subject: draft.subject.trim(), customer: draft.customer,
      priority: draft.priority, status: "open", category: draft.category, channel: draft.channel,
      assignee: draft.assignee, created: 0, updated: 0, unread: false, fields: draft.cf, thread: [] };
    if (draft.desc.trim()) nt.thread.push({ from: "customer", text: draft.desc.trim(), mins: 0 });
    tickets.unshift(nt); save();
    hideOverlay(formEl);
    state.status = "open"; state.priority = "all";
    renderList();
    toast("Ticket " + nt.num + " created");
    setTimeout(function () { openTicket(nt.id); }, 280);
  }

  /* ============================================================
     SHEET + CONFIRM primitives (own instances in this pane)
     ============================================================ */
  var scrim, sheet;
  function ensureSheet() {
    if (scrim) return;
    scrim = document.createElement("div"); scrim.className = "ax-scrim";
    sheet = document.createElement("div"); sheet.className = "ax-sheet";
    scrim.addEventListener("click", closeSheet);
    pane.appendChild(scrim); pane.appendChild(sheet);
  }
  function openSheet(html) {
    ensureSheet(); sheet.innerHTML = html; sheet.scrollTop = 0;
    requestAnimationFrame(function () { scrim.classList.add("show"); sheet.classList.add("show"); });
    return sheet;
  }
  function closeSheet() { if (sheet) { scrim.classList.remove("show"); sheet.classList.remove("show"); } }

  var cScrim, onGo;
  function showConfirm(o) {
    if (!cScrim) {
      cScrim = document.createElement("div"); cScrim.className = "ax-modal-scrim";
      pane.appendChild(cScrim);
      cScrim.addEventListener("click", function (e) { if (e.target === cScrim) cScrim.classList.remove("show"); });
    }
    cScrim.innerHTML = '<div class="ax-modal"><div class="mic">' + I.warn + '</div><div class="mt">' + esc(o.title) + '</div>' +
      '<div class="ms">' + esc(o.sub) + '</div><div class="mb"><button class="keep" id="txCKeep">Keep</button><button class="go" id="txCGo">' + esc(o.go) + '</button></div></div>';
    onGo = o.onGo;
    $("#txCKeep", cScrim).addEventListener("click", function () { cScrim.classList.remove("show"); });
    $("#txCGo", cScrim).addEventListener("click", function () { cScrim.classList.remove("show"); if (onGo) onGo(); });
    requestAnimationFrame(function () { cScrim.classList.add("show"); });
  }

  /* ============================================================
     SECTION ROUTER (Dashboard / Tickets)
     ============================================================ */
  var section = "dashboard";
  function setSection(sec) {
    section = sec;
    $$("#txTabs button", pane).forEach(function (b) { b.classList.toggle("active", b.getAttribute("data-sec") === sec); });
    var dash = $("#txDashView"), tw = $("#txTicketsWrap"), sv = $("#txSettingsView"), fab = $("#txFab"), pill = $("#txPrioPill"), big = $("#txBig"), sub = $("#txHeadSub");
    var onTickets = sec === "tickets", onSettings = sec === "settings";
    if (dash) dash.style.display = (sec === "dashboard") ? "" : "none";
    if (tw) tw.style.display = onTickets ? "" : "none";
    if (sv) sv.style.display = onSettings ? "" : "none";
    if (fab) fab.style.display = onTickets ? "" : "none";
    if (pill) pill.style.display = "none";
    if (big) big.textContent = onTickets ? "Tickets" : onSettings ? "Settings" : "Dashboard";
    if (onTickets) {
      if (window.TKTickets) { if (sub) sub.textContent = "Manage all tickets"; window.TKTickets.render(); }
      else { renderList(); }
    } else if (onSettings) {
      if (sub) sub.textContent = "Ticket configuration"; if (window.TKSettings) window.TKSettings.render();
    } else { if (sub) sub.textContent = "Ticketing overview"; if (window.TKDash) window.TKDash.render(); }
    var sheet = $(".lp-sheet", pane); if (sheet) sheet.scrollTop = 0;
  }

  /* ---------- expose live data + helpers for the dashboard module ---------- */
  window.TK = {
    pane: pane, $: $, $$: $$, esc: esc, toast: toast, I: I,
    get tickets() { return tickets; },
    get AGENTS() { return agentsList(); },
    PRIO: PRIO, STATUS: STATUS, CHANNELS: CHANNELS,
    CUSTOMERS: CUSTOMERS, CATS: CATS, CAT_ORDER: CAT_ORDER,
    agentById: agentById, custById: custById, getT: getT, save: save,
    openSheet: openSheet, closeSheet: closeSheet, radioSheet: radioSheet,
    openTicket: openTicket, setSection: setSection,
    nextNum: nextNum, uid: uid,
    addTicket: function (t) { tickets.unshift(t); save(); },
    delTicket: function (id) { tickets = tickets.filter(function (x) { return x.id !== id; }); save(); },
    showConfirm: showConfirm
  };

  /* ============================================================
     wire static controls
     ============================================================ */
  $$(".tx-chip", pane).forEach(function (ch) {
    ch.addEventListener("click", function () { state.status = ch.getAttribute("data-f"); renderList(); });
  });
  $$("#txTabs button", pane).forEach(function (b) {
    b.addEventListener("click", function () { setSection(b.getAttribute("data-sec")); });
  });
  var fab = $("#txFab"); if (fab) fab.addEventListener("click", openForm);
  var prioPill = $("#txPrioPill"); if (prioPill) prioPill.addEventListener("click", openPrioFilter);

  /* live-sync with the people store: any agent change in Settings re-renders here */
  if (window.AskEvaPeople && AskEvaPeople.on) {
    AskEvaPeople.on(function () {
      try { renderList(); } catch (e) {}
      if (window.TKDash && document.getElementById("txDashView")) { try { TKDash.render(); } catch (e) {} }
    });
  }

  function openPrioFilter() {
    var opts = [["all", "All priorities"], ["high", "High"], ["med", "Medium"], ["low", "Low"]];
    radioSheet("Filter by priority", opts.map(function (o) {
      return { v: o[0], label: o[1], dot: o[0] === "all" ? "" : '<span class="pdot ' + o[0] + '"></span>', on: state.priority === o[0] };
    }), function (v) { state.priority = v; renderList(); });
  }

  setSection("dashboard");
  window.__tickets = {
    renderList: renderList, openTicket: openTicket, openForm: openForm,
    /* tickets for a given customer (matched by name or last-10 mobile digits) */
    byCustomer: function (name, mobile) {
      var d10 = String(mobile || "").replace(/\D/g, "").slice(-10);
      var nm = String(name || "").trim().toLowerCase();
      var ids = CUSTOMERS.filter(function (c) {
        var cm = String(c.mobile || "").replace(/\D/g, "").slice(-10);
        return (nm && (c.name || "").toLowerCase() === nm) || (d10 && cm === d10);
      }).map(function (c) { return c.id; });
      return tickets.filter(function (t) { return ids.indexOf(t.customer) > -1; }).map(function (t) {
        var c = custById(t.customer) || {}, ag = (t.assignee && t.assignee !== "unassigned") ? agentById(t.assignee) : null;
        return { num: t.num, subject: t.subject, custName: c.name || "", dept: t.category, status: t.status, priority: t.priority, createdMins: t.created, assignee: ag ? ag.name : "Unassigned" };
      });
    }
  };
})();
