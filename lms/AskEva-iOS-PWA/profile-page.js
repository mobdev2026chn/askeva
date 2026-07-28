/* AskEva — Profile page (tabs, panels, interactions) */
(function () {
  "use strict";
  var pane = document.getElementById("app-profile");
  if (!pane) return;
  var $ = function (s, r) { return (r || pane).querySelector(s); };
  var $$ = function (s, r) { return Array.prototype.slice.call((r || pane).querySelectorAll(s)); };

  var toastT;
  function toast(msg) {
    var t = document.getElementById("toast"); if (!t) return;
    t.textContent = msg; t.style.opacity = "1"; t.style.transform = "translateX(-50%) translateY(0)";
    clearTimeout(toastT); toastT = setTimeout(function () { t.style.opacity = "0"; t.style.transform = "translateX(-50%) translateY(20px)"; }, 1800);
  }
  function esc(s) { return String(s).replace(/[&<>"]/g, function (c) { return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]; }); }

  /* ---------------- icons ---------------- */
  var I = {
    user: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="8" r="3.2"/><path d="M5 20c0-3.2 3-5 7-5s7 1.8 7 5"/></svg>',
    mail: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="5" width="18" height="14" rx="2"/><path d="m4 7 8 6 8-6"/></svg>',
    globe: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3c2.5 2.4 2.5 15.6 0 18M12 3c-2.5 2.4-2.5 15.6 0 18"/></svg>',
    vertical: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="4" y="3" width="16" height="18" rx="1.6"/><path d="M8 7h2M8 11h2M8 15h2M14 7h2M14 11h2M14 15h2"/></svg>',
    pin: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 21s7-5.2 7-11a7 7 0 1 0-14 0c0 5.8 7 11 7 11Z"/><circle cx="12" cy="10" r="2.4"/></svg>',
    info: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="M12 11v5"/><circle cx="12" cy="7.6" r="1" fill="currentColor"/></svg>',
    doc: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linejoin="round"><path d="M6 3h8l4 4v14H6V3Z"/><path d="M14 3v4h4M9 13h6M9 17h6" stroke-linecap="round"/></svg>',
    cal: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="5" width="18" height="16" rx="2"/><path d="M3 10h18M8 3v4M16 3v4"/></svg>',
    clock: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="M12 8v4l3 2"/></svg>',
    shield: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3 5 6v5c0 4.4 3 7.6 7 9 4-1.4 7-4.6 7-9V6l-7-3Z"/></svg>',
    phone: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 3 4 5c0 9 6 15 15 15l2-2-4-3-2 1c-2-1-4-3-5-5l1-2-3-4Z"/></svg>',
    mobile: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="7" y="3" width="10" height="18" rx="2"/><path d="M11 18h2"/></svg>',
    contact: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="8" r="3"/><path d="M6 20c0-3 2.7-4.6 6-4.6s6 1.6 6 4.6"/><path d="m17 6 2 1.5L17 9"/></svg>',
    building: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="4" y="3" width="16" height="18" rx="1.6"/><path d="M9 21v-4h6v4M8 7h2M14 7h2M8 11h2M14 11h2"/></svg>',
    legal: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3v18M5 7l7-3 7 3M5 7l-2 5a3 3 0 0 0 6 0L7 7M19 7l-2 5a3 3 0 0 0 6 0l-2-5"/></svg>',
    map: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m9 4 6 2 5-2v14l-5 2-6-2-5 2V4l5-2Zm0 0v14m6-12v14"/></svg>',
    home: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 11 12 4l8 7M6 10v10h12V10"/></svg>',
    flag: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M5 21V4h11l-1.5 4L16 12H5"/></svg>',
    gst: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="6" width="18" height="13" rx="2"/><path d="M3 10h18M7 15h4"/></svg>',
    check: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><path d="m5 12 4 4 10-11"/></svg>',
    eye: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7-10-7-10-7Z"/><circle cx="12" cy="12" r="3"/></svg>',
    eyeoff: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 3l18 18M10.6 6.2A9.7 9.7 0 0 1 12 6c6.5 0 10 6 10 6a17 17 0 0 1-3.3 3.9M6.5 7.6A16.6 16.6 0 0 0 2 12s3.5 6 10 6a9.8 9.8 0 0 0 3.4-.6"/><path d="M9.5 10.6a3 3 0 0 0 4 4"/></svg>',
    edit: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M11 4H5a2 2 0 0 0-2 2v13a2 2 0 0 0 2 2h13a2 2 0 0 0 2-2v-6"/><path d="M18.5 2.5a2.12 2.12 0 0 1 3 3L12 15l-4 1 1-4Z"/></svg>',
    trash: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 7h16M9 7V5a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v2M6 7l1 13h10l1-13"/></svg>',
    plus: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="M12 5v14M5 12h14"/></svg>',
    x: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M18 6 6 18M6 6l12 12"/></svg>',
    dl: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 4v11m0 0 4-4m-4 4-4-4M5 20h14"/></svg>',
    chev: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m6 9 6 6 6-6"/></svg>',
    login: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="4" width="18" height="13" rx="2"/><path d="M8 21h8M12 17v4"/></svg>',
    save: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M5 4h11l3 3v13H5V4Z"/><path d="M8 4v5h7M8 14h8"/></svg>'
  };

  /* ---------------- data ---------------- */
  var ACCOUNT = [
    { ic: "info", k: "Account Status", status: true, v: "Active" },
    { ic: "contact", k: "Primary Contact Name", v: "Eshan" },
    { ic: "cal", k: "Creation Date", v: "25 Feb 2025" },
    { ic: "phone", k: "WhatsApp API No", v: "917200440497" },
    { ic: "clock", k: "Activation Date", v: "25 Feb 2025" },
    { ic: "mobile", k: "Primary Contact Mobile", v: "919786742563" },
    { ic: "shield", k: "Reseller ID", v: "N/A", muted: true },
    { ic: "mail", k: "Primary Contact Email", v: "eshan@tunepath.com" }
  ];
  var COMPANY = [
    { ic: "building", k: "Company Name", v: "Askeva API" },
    { ic: "legal", k: "Legal Business Name", v: "Askeva" },
    { ic: "pin", k: "Address", v: "test" },
    { ic: "map", k: "State", v: "Tamil Nadu" },
    { ic: "home", k: "City", v: "Mdu" },
    { ic: "map", k: "Zip", v: "123654" },
    { ic: "globe", k: "Company Website", v: "https://www.google.com", link: true },
    { ic: "flag", k: "Country", v: "India" },
    { ic: "gst", k: "GST No", v: "6372" }
  ];
  var WA = {
    name: "Eshan",
    email: "eshan@tunepath.com",
    desc: "Chatbot is the best solution for everything — automating conversations, capturing leads, and supporting guests around the clock.",
    website: "https://app.askeva.io",
    vertical: "Hotel and Lodging",
    address: "Madurai · Hosur · Chennai, Tamil Nadu"
  };
  var VERTICALS = ["Hotel and Lodging", "E-commerce", "Education", "Healthcare", "Finance", "Travel", "Restaurant", "Real Estate", "Retail", "Other"];
  var TEAM = [
    { name: "Vicky Techy", phone: "919786742563", role: "Test" },
    { name: "Jo", phone: "919159651706", role: "Testt" }
  ];
  var LOGINS = [
    { time: "05 Jun 2026, 03:27:13 pm", ip: "49.204.136.46", device: "Desktop · Windows · Chrome" },
    { time: "05 Jun 2026, 03:00:47 pm", ip: "49.204.136.46", device: "Desktop · Windows · Chrome" },
    { time: "05 Jun 2026, 12:46:19 pm", ip: "106.51.21.253", device: "Desktop · Windows · Chrome" },
    { time: "05 Jun 2026, 11:41:34 am", ip: "49.204.136.46", device: "Desktop · Windows · Chrome" },
    { time: "05 Jun 2026, 11:36:54 am", ip: "::1", device: "Desktop · Windows · Chrome" }
  ];
  var COSTS = {
    India: { area: "India ( Home Town )", auth: "0.20", mkt: "0.96", util: "0.20", sess: "0.00" },
    Argentina: { area: "Argentina", auth: "0.34", mkt: "0.06", util: "0.03", sess: "0.00" },
    Australia: { area: "Australia", auth: "0.34", mkt: "0.52", util: "0.34", sess: "0.00" },
    Bangladesh: { area: "Bangladesh", auth: "0.20", mkt: "0.45", util: "0.20", sess: "0.00" },
    Brazil: { area: "Brazil", auth: "0.03", mkt: "0.06", util: "0.01", sess: "0.00" },
    Canada: { area: "Canada", auth: "0.30", mkt: "1.40", util: "0.30", sess: "0.00" },
    Chile: { area: "Chile", auth: "0.32", mkt: "0.89", util: "0.32", sess: "0.00" },
    China: { area: "China", auth: "0.28", mkt: "0.78", util: "0.28", sess: "0.00" },
    Colombia: { area: "Colombia", auth: "0.01", mkt: "0.03", util: "0.01", sess: "0.00" },
    Egypt: { area: "Egypt", auth: "0.10", mkt: "0.13", util: "0.10", sess: "0.00" },
    France: { area: "France", auth: "0.07", mkt: "0.14", util: "0.03", sess: "0.00" },
    Germany: { area: "Germany", auth: "0.08", mkt: "0.16", util: "0.04", sess: "0.00" },
    Indonesia: { area: "Indonesia", auth: "0.30", mkt: "0.42", util: "0.30", sess: "0.00" },
    Ireland: { area: "Ireland", auth: "0.10", mkt: "0.21", util: "0.05", sess: "0.00" },
    Israel: { area: "Israel", auth: "0.02", mkt: "0.04", util: "0.01", sess: "0.00" },
    Italy: { area: "Italy", auth: "0.06", mkt: "0.12", util: "0.03", sess: "0.00" },
    Japan: { area: "Japan", auth: "0.05", mkt: "0.10", util: "0.05", sess: "0.00" },
    Kenya: { area: "Kenya", auth: "0.21", mkt: "0.48", util: "0.21", sess: "0.00" },
    Malaysia: { area: "Malaysia", auth: "0.06", mkt: "0.09", util: "0.02", sess: "0.00" },
    Mexico: { area: "Mexico", auth: "0.02", mkt: "0.04", util: "0.01", sess: "0.00" },
    Netherlands: { area: "Netherlands", auth: "0.09", mkt: "0.17", util: "0.05", sess: "0.00" },
    "New Zealand": { area: "New Zealand", auth: "0.32", mkt: "0.61", util: "0.32", sess: "0.00" },
    Nigeria: { area: "Nigeria", auth: "0.20", mkt: "0.41", util: "0.20", sess: "0.00" },
    Pakistan: { area: "Pakistan", auth: "0.22", mkt: "0.50", util: "0.22", sess: "0.00" },
    Peru: { area: "Peru", auth: "0.27", mkt: "0.69", util: "0.27", sess: "0.00" },
    Philippines: { area: "Philippines", auth: "0.05", mkt: "0.08", util: "0.02", sess: "0.00" },
    Poland: { area: "Poland", auth: "0.04", mkt: "0.08", util: "0.02", sess: "0.00" },
    Russia: { area: "Russia", auth: "0.05", mkt: "0.11", util: "0.05", sess: "0.00" },
    "Saudi Arabia": { area: "Saudi Arabia", auth: "0.18", mkt: "0.34", util: "0.18", sess: "0.00" },
    Singapore: { area: "Singapore", auth: "0.30", mkt: "0.61", util: "0.30", sess: "0.00" },
    "South Africa": { area: "South Africa", auth: "0.13", mkt: "0.27", util: "0.13", sess: "0.00" },
    "South Korea": { area: "South Korea", auth: "0.16", mkt: "0.34", util: "0.16", sess: "0.00" },
    Spain: { area: "Spain", auth: "0.03", mkt: "0.06", util: "0.02", sess: "0.00" },
    "Sri Lanka": { area: "Sri Lanka", auth: "0.20", mkt: "0.43", util: "0.20", sess: "0.00" },
    Sweden: { area: "Sweden", auth: "0.10", mkt: "0.20", util: "0.05", sess: "0.00" },
    Switzerland: { area: "Switzerland", auth: "0.11", mkt: "0.22", util: "0.06", sess: "0.00" },
    Thailand: { area: "Thailand", auth: "0.04", mkt: "0.08", util: "0.02", sess: "0.00" },
    Turkey: { area: "Turkey", auth: "0.01", mkt: "0.03", util: "0.01", sess: "0.00" },
    "United Arab Emirates": { area: "United Arab Emirates", auth: "0.28", mkt: "1.18", util: "0.28", sess: "0.00" },
    "United Kingdom": { area: "United Kingdom", auth: "0.34", mkt: "1.52", util: "0.34", sess: "0.00" },
    "United States": { area: "United States", auth: "0.30", mkt: "1.40", util: "0.30", sess: "0.00" },
    Vietnam: { area: "Vietnam", auth: "0.04", mkt: "0.07", util: "0.02", sess: "0.00" },
    "Rest of Africa": { area: "Rest of Africa", auth: "0.22", mkt: "0.50", util: "0.22", sess: "0.00" },
    "Rest of Asia Pacific": { area: "Rest of Asia Pacific", auth: "0.25", mkt: "0.55", util: "0.25", sess: "0.00" },
    "Rest of Central & Eastern Europe": { area: "Rest of Central & Eastern Europe", auth: "0.12", mkt: "0.24", util: "0.06", sess: "0.00" },
    "Rest of Latin America": { area: "Rest of Latin America", auth: "0.28", mkt: "0.74", util: "0.28", sess: "0.00" },
    "Rest of Middle East": { area: "Rest of Middle East", auth: "0.20", mkt: "0.42", util: "0.20", sess: "0.00" },
    "Rest of Western Europe": { area: "Rest of Western Europe", auth: "0.10", mkt: "0.20", util: "0.05", sess: "0.00" },
    Other: { area: "Other", auth: "0.30", mkt: "0.85", util: "0.30", sess: "0.00" }
  };
  var FEATURES = [
    ["Broadcast & Analytics", true], ["Chat (Live, History & Intervene)", true], ["Nodes Chatbot", "7"],
    ["APIs Documentation", true], ["Notify Me", true], ["Agents & Attributes", true], ["APIs + Web hooks", true],
    ["Schedule Campaign", true], ["Carousel", true], ["Questionnaire Flow", true], ["WhatsApp Forms", true]
  ];
  var TX = [
    { sno: 1, amt: "+9558.00", inn: true, date: "26 May 2026, 13:54:59", reason: "Plan upgraded — Ecommerce", prev: "1900.00", cur: "0.00", status: "deducted", inv: null,
      d: { acc: "N/A", payer: "Askeva API", deducted: "8100", recharge: "—", gst: "1458", gateway: "0", method: "Wallet", grand: "9558" } },
    { sno: 2, amt: "+1.21", inn: true, date: "25 May 2026, 12:46:41", reason: "Success", prev: "41.69", cur: "42.69", status: "paid", inv: "AEPW2603242",
      d: { acc: "N/A", payer: "Askeva API", deducted: "—", recharge: "1.21", gst: "0.18", gateway: "Razorpay", method: "Wallet", grand: "1.21" } },
    { sno: 3, amt: "+1.21", inn: true, date: "25 May 2026, 12:36:43", reason: "Success", prev: "40.69", cur: "41.69", status: "paid", inv: "AEPW2603241",
      d: { acc: "N/A", payer: "Askeva API", deducted: "—", recharge: "1.21", gst: "0.18", gateway: "Razorpay", method: "Wallet", grand: "1.21" } },
    { sno: 4, amt: "+1.21", inn: true, date: "25 May 2026, 12:24:27", reason: "Success", prev: "39.69", cur: "40.69", status: "paid", inv: "AEPW2603240",
      d: { acc: "N/A", payer: "Askeva API", deducted: "—", recharge: "1.21", gst: "0.18", gateway: "Razorpay", method: "Wallet", grand: "1.21" } },
    { sno: 5, amt: "+1.21", inn: true, date: "25 May 2026, 12:23:23", reason: "Success", prev: "38.69", cur: "39.69", status: "paid", inv: "AEPW2603239",
      d: { acc: "N/A", payer: "Askeva API", deducted: "—", recharge: "1.21", gst: "0.18", gateway: "Razorpay", method: "Wallet", grand: "1.21" } },
    { sno: 6, amt: "+1.21", inn: true, date: "25 May 2026, 12:20:54", reason: "Success", prev: "37.69", cur: "38.69", status: "paid", inv: "AEPW2603238",
      d: { acc: "N/A", payer: "Askeva API", deducted: "—", recharge: "1.21", gst: "0.18", gateway: "Razorpay", method: "Wallet", grand: "1.21" } }
  ];

  /* ---------------- transactions: live logging + persistence ---------------- */
  var SEED_TX = TX.slice();
  var addedTx = [];
  try { addedTx = JSON.parse(localStorage.getItem("askeva_tx_added") || "[]") || []; } catch (e) {}
  if (addedTx.length) TX = addedTx.concat(SEED_TX);
  var walletBalance;
  try { var _wb = localStorage.getItem("askeva_wallet"); walletBalance = _wb != null ? parseFloat(_wb) : (parseFloat(SEED_TX[0] && SEED_TX[0].cur) || 0); }
  catch (e) { walletBalance = parseFloat(SEED_TX[0] && SEED_TX[0].cur) || 0; }
  function txStamp() {
    var d = new Date(), p = function (n) { return (n < 10 ? "0" : "") + n; };
    var mon = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    return p(d.getDate()) + " " + mon[d.getMonth()] + " " + d.getFullYear() + ", " + p(d.getHours()) + ":" + p(d.getMinutes()) + ":" + p(d.getSeconds());
  }
  function genInv() { return "AEPW" + String(Date.now()).slice(-7); }
  function logTx(o) {
    o = o || {};
    var amount = Math.abs(parseFloat(o.amount) || 0);
    var deducted = !!o.deducted;
    var prev = walletBalance;
    walletBalance = deducted ? prev - amount : prev + amount;
    var rec = {
      sno: TX.length + 1, amt: "+" + amount.toFixed(2), inn: !deducted, date: txStamp(),
      reason: o.reason || (deducted ? "Payment" : "Wallet recharge"),
      prev: prev.toFixed(2), cur: walletBalance.toFixed(2),
      status: deducted ? "deducted" : "paid", inv: o.inv || (deducted ? null : genInv()),
      d: { acc: "N/A", payer: o.payer || "Askeva API",
        deducted: deducted ? String(Math.round(amount)) : "\u2014",
        recharge: deducted ? "\u2014" : String(Math.round(amount)),
        gst: o.gst != null ? String(o.gst) : "0", gateway: o.gateway || (deducted ? "0" : "Razorpay"),
        method: o.method || (deducted ? "Wallet" : "Razorpay"), grand: String(Math.round(amount)) }
    };
    TX.unshift(rec); addedTx.unshift(rec);
    try { localStorage.setItem("askeva_tx_added", JSON.stringify(addedTx)); localStorage.setItem("askeva_wallet", String(walletBalance)); } catch (e) {}
    rendered.transactions = false;
    var panel = pane.querySelector('[data-tabpanel="transactions"]');
    if (panel && !panel.hidden) { renderTransactions(); rendered.transactions = true; }
    return rec;
  }
  window.AskEvaAddTransaction = logTx;
  function rupee() { return "\u20B9"; }
  /* Payment Method is shown as just Manual / Online:
     online = went through a payment gateway; everything else (wallet / admin / bank) = manual. */
  function payMethod(d) {
    var g = String((d && d.gateway) || "").toLowerCase();
    var m = String((d && d.method) || "").toLowerCase();
    var online = /razor|stripe|payu|paytm|cashfree|gateway|online|card|upi|netbank/.test(g + " " + m);
    return online ? "Online" : "Manual";
  }
  function kvRows(list) {
    return list.map(function (r) {
      var val = r.status
        ? '<span class="pf-statuspill"><span class="d"></span>' + esc(r.v) + '</span>'
        : '<div class="v' + (r.link ? " link" : "") + (r.muted ? " muted" : "") + '">' + esc(r.v) + '</div>';
      return '<div class="pf-kv"><span class="ic">' + (I[r.ic] || I.info) + '</span><div class="c"><div class="k">' + esc(r.k) + '</div>' + val + '</div></div>';
    }).join("");
  }
  function renderAccount() {
    $("#pfAccount").innerHTML =
      '<div class="pf-card">' +
        '<div class="pf-wa"><div class="av"><img class="lg" src="' + ((window.__resources && window.__resources.askevaLogo) || 'assets/askeva-logo.png') + '" alt="AskEva"></div><div class="who"><div class="n">' + esc(WA.name) + '</div><div class="e">' + esc(WA.email) + '</div></div>' +
          '<button class="pf-waedit" data-editprofile aria-label="Edit profile details">' + I.edit + '</button></div>' +
        '<div class="pf-kv"><span class="ic">' + I.doc + '</span><div class="c"><div class="k">Description</div><div class="v" style="font-weight:600;color:var(--ink-2)">' + esc(WA.desc) + '</div></div></div>' +
        '<div class="pf-kv"><span class="ic">' + I.globe + '</span><div class="c"><div class="k">Website</div><div class="v link">' + esc(WA.website) + '</div></div></div>' +
        '<div class="pf-kv"><span class="ic">' + I.vertical + '</span><div class="c"><div class="k">Business Vertical</div><div class="v">' + esc(WA.vertical) + '</div></div></div>' +
        '<div class="pf-kv"><span class="ic">' + I.pin + '</span><div class="c"><div class="k">Address</div><div class="v">' + esc(WA.address) + '</div></div></div>' +
      '</div>' +
      '<div class="pf-card"><div class="pf-cardhd"><span class="ic">' + I.user + '</span><h4>Account Details</h4></div>' + kvRows(ACCOUNT) + '</div>' +
      '<div class="pf-card"><div class="pf-cardhd"><span class="ic">' + I.building + '</span><h4>Company Details</h4></div>' + kvRows(COMPANY) + '</div>';
  }

  /* ---------------- render: Team ---------------- */
  function renderTeam() {
    var rows = TEAM.map(function (m, idx) {
      return '<div class="pf-member">' +
        '<div class="mav">' + esc(m.name.charAt(0).toUpperCase()) + '</div>' +
        '<div class="mi"><div class="n">' + esc(m.name) + '</div><div class="ph">' + I.phone + esc(m.phone) + '</div><span class="pf-rolepill">' + esc(m.role) + '</span></div>' +
        '<div class="pf-mact"><button data-view="' + idx + '" aria-label="View">' + I.eye + '</button><button data-edit="' + idx + '" aria-label="Edit">' + I.edit + '</button><button class="del" data-del="' + idx + '" aria-label="Delete">' + I.trash + '</button></div>' +
      '</div>';
    }).join("");
    $("#pfTeam").innerHTML =
      '<div class="pf-teamtop"><span class="ct">' + TEAM.length + ' member' + (TEAM.length !== 1 ? "s" : "") + '</span>' +
        '<button class="pf-add" data-addmember>' + I.plus + 'Add Member</button></div>' + rows;
  }

  /* ---------------- render: Password ---------------- */
  function pwField(id, label) {
    return '<div class="pf-field"><label><span class="req">*</span>' + label + '</label>' +
      '<div class="pf-inwrap"><input class="pf-input" id="' + id + '" type="password" placeholder="' + label + '">' +
      '<button class="pf-eye" data-eye="' + id + '" aria-label="Show">' + I.eye + '</button></div></div>';
  }
  function renderPassword() {
    $("#pfPassword").innerHTML =
      '<div class="pf-card">' +
        '<div class="pf-cardhd"><span class="ic">' + I.shield + '</span><h4>Change Password</h4></div>' +
        '<p class="pf-hint">Use at least 8 characters with a mix of letters, numbers &amp; symbols.</p>' +
        pwField("pwOld", "Old Password") + pwField("pwNew", "New Password") + pwField("pwRe", "Retype New Password") +
        '<button class="pf-btn primary" data-savepw>' + I.save + 'Save Changes</button>' +
      '</div>';
  }

  /* ---------------- render: Pricing ---------------- */
  function renderPricing() {
    var c = COSTS.India;
    $("#pfPricing").innerHTML =
      '<div class="pf-card">' +
        '<div class="pf-cardhd"><span class="ic">' + I.gst + '</span><h4>Conversation Pricing</h4></div>' +
        '<select class="pf-select" id="pfCountry">' + Object.keys(COSTS).map(function (k) { return '<option' + (k === "India" ? " selected" : "") + '>' + k + '</option>'; }).join("") + '</select>' +
        '<div class="pf-svc" id="pfArea">Service Area: ' + c.area + '</div>' +
        '<div class="pf-costs" id="pfCostGrid">' + costGrid(c) + '</div>' +
      '</div>';
  }
  function renderSubscription() {
    $("#pfSubscription").innerHTML = '<div class="sub-center" id="subCenter"></div>';
    if (window.__sub) window.__sub.renderProfile();
  }
  function costGrid(c) {
    return '<div class="pf-cost"><div class="k">Authentication</div><div class="v">' + c.auth + '</div></div>' +
      '<div class="pf-cost"><div class="k">Marketing</div><div class="v">' + c.mkt + '</div></div>' +
      '<div class="pf-cost"><div class="k">Utility</div><div class="v">' + c.util + '</div></div>' +
      '<div class="pf-cost"><div class="k">Session</div><div class="v">' + c.sess + '</div></div>';
  }

  /* ---------------- render: Transactions ---------------- */
  function renderTransactions() {
    var rows = TX.map(function (t, idx) {
      var inv = t.inv
        ? '<div class="pf-txinv"><button data-inv="' + esc(t.inv) + '">' + I.dl + 'Invoice ' + esc(t.inv) + '</button></div>'
        : '';
      var d = t.d;
      return '<div class="pf-tx" data-tx="' + idx + '">' +
        '<div class="pf-txhd" data-txtoggle="' + idx + '">' +
          '<span class="pf-txi ' + (t.inn ? "in" : "out") + '">' + (t.inn ? I.dl : I.trash) + '</span>' +
          '<div class="pf-txm"><div class="rs">' + esc(t.reason) + '</div><div class="dt">' + esc(t.date) + '</div></div>' +
          '<div class="pf-txr"><div class="amt ' + (t.status === "deducted" ? "out" : "in") + '">' + rupee() + esc(t.amt.replace("+", "")) + '</div>' +
            '<span class="pf-txstatus ' + t.status + '"><span class="d"></span>' + (t.status === "paid" ? "Paid" : "Deducted") + '</span></div>' +
          '<span class="pf-txchev">' + I.chev + '</span>' +
        '</div>' +
        '<div class="pf-txbody"><div class="in">' +
          '<div class="pf-txbal"><div class="b"><div class="k">Previous Balance</div><div class="v">' + rupee() + esc(t.prev) + '</div></div>' +
            '<div class="b"><div class="k">Current Balance</div><div class="v">' + rupee() + esc(t.cur) + '</div></div></div>' +
          '<div class="pf-txdetail"><div class="pf-txd2">' +
            kvCell("Account No", d.acc) + kvCell("Payer Name", d.payer) +
            kvCell("Amount Deducted", d.deducted) + kvCell("Recharge Amount", d.recharge) +
            kvCell("GST", d.gst) + kvCell("Payment Gateway", d.gateway) +
            kvCell("Payment Method", payMethod(d)) + kvCell("Grand Total", rupee() + d.grand) +
          '</div></div>' + inv +
        '</div></div></div>';
    }).join("");
    $("#pfTransactions").innerHTML = rows +
      '<div class="pf-pager"><button data-pg="prev" disabled>' + '\u2039' + '</button>' +
        '<button class="active">1</button><button data-pg="2">2</button><button data-pg="3">3</button><button data-pg="next">' + '\u203A' + '</button></div>';
  }
  function kvCell(k, v) { return '<div><div class="k">' + esc(k) + '</div><div class="v">' + esc(v) + '</div></div>'; }

  /* ---------------- member sheet ---------------- */
  var mScrim = $("#pfMScrim"), mSheet = $("#pfMSheet");
  mScrim.addEventListener("click", closeMember);
  function closeMember() { mScrim.classList.remove("show"); mSheet.classList.remove("show"); }
  function openMember(member, idx) {
    var editing = member != null;
    mSheet.innerHTML =
      '<div class="pf-mgrip"></div>' +
      '<div class="pf-mhd"><span class="tt">' + (editing ? "Edit Member" : "Add Member") + '</span><button class="x" data-mx>' + I.x + '</button></div>' +
      '<div class="pf-mbody">' +
        '<div class="pf-field"><label>Name</label><input class="pf-input" id="mName" style="padding-right:14px" placeholder="Full name" value="' + (editing ? esc(member.name) : "") + '"></div>' +
        '<div class="pf-field"><label>Mobile Number</label><input class="pf-input" id="mPhone" style="padding-right:14px" inputmode="numeric" placeholder="91XXXXXXXXXX" value="' + (editing ? esc(member.phone) : "") + '"></div>' +
        '<div class="pf-field"><label>Role</label><input class="pf-input" id="mRole" style="padding-right:14px" placeholder="e.g. Agent" value="' + (editing ? esc(member.role) : "") + '"></div>' +
      '</div>' +
      '<div class="pf-mfoot"><button class="pf-btn primary" data-msave>' + I.save + (editing ? "Save Changes" : "Add Member") + '</button></div>';
    $("[data-mx]", mSheet).addEventListener("click", closeMember);
    $("[data-msave]", mSheet).addEventListener("click", function () {
      var nm = $("#mName", mSheet).value.trim(), ph = $("#mPhone", mSheet).value.trim(), ro = $("#mRole", mSheet).value.trim();
      if (!nm || !ph) { toast("Name and mobile are required"); return; }
      if (editing) { TEAM[idx] = { name: nm, phone: ph, role: ro || "Member" }; toast("Member updated"); }
      else { TEAM.push({ name: nm, phone: ph, role: ro || "Member" }); toast("Member added"); }
      renderTeam(); closeMember();
    });
    requestAnimationFrame(function () { mScrim.classList.add("show"); mSheet.classList.add("show"); });
  }

  /* ---------------- member details (read-only view) ---------------- */
  function openMemberView(member, idx) {
    if (!member) return;
    var initial = esc(member.name.charAt(0).toUpperCase());
    function vrow(k, v) {
      return '<div style="display:flex;align-items:center;justify-content:space-between;gap:16px;padding:14px 2px;border-bottom:1px solid var(--line);">' +
        '<span style="font-size:12px;font-weight:700;letter-spacing:.04em;text-transform:uppercase;color:var(--ink-4);">' + k + '</span>' +
        '<span style="font-size:14.5px;font-weight:700;color:var(--ink);text-align:right;word-break:break-word;">' + v + '</span></div>';
    }
    mSheet.innerHTML =
      '<div class="pf-mgrip"></div>' +
      '<div class="pf-mhd"><span class="tt">Member Details</span><button class="x" data-mx>' + I.x + '</button></div>' +
      '<div class="pf-mbody">' +
        '<div style="display:flex;flex-direction:column;align-items:center;text-align:center;padding:4px 0 18px;border-bottom:1px solid var(--line);">' +
          '<div style="width:66px;height:66px;border-radius:19px;display:grid;place-items:center;background:var(--accent-soft);color:var(--eva-green-deep);font-size:26px;font-weight:800;">' + initial + '</div>' +
          '<div style="font-size:19px;font-weight:800;color:var(--ink);margin-top:11px;letter-spacing:-.01em;">' + esc(member.name) + '</div>' +
          '<span class="pf-rolepill" style="margin-top:9px;">' + esc(member.role) + '</span>' +
        '</div>' +
        vrow("Mobile Number", esc(member.phone)) +
        vrow("Role", esc(member.role)) +
      '</div>' +
      '<div class="pf-mfoot"><button class="pf-btn primary" data-medit>' + I.edit + 'Edit Member</button></div>';
    $("[data-mx]", mSheet).addEventListener("click", closeMember);
    $("[data-medit]", mSheet).addEventListener("click", function () { openMember(member, idx); });
    requestAnimationFrame(function () { mScrim.classList.add("show"); mSheet.classList.add("show"); });
  }

  /* ---------------- edit WhatsApp profile sheet ---------------- */
  function field(id, label, val, opts) {
    opts = opts || {};
    var input;
    if (opts.textarea) input = '<textarea class="pf-input" id="' + id + '" rows="3" style="padding-right:14px;resize:none;line-height:1.5" placeholder="' + esc(label) + '">' + esc(val) + '</textarea>';
    else if (opts.select) input = '<select class="pf-select" id="' + id + '">' + opts.select.map(function (o) { return '<option' + (o === val ? " selected" : "") + '>' + esc(o) + '</option>'; }).join("") + '</select>';
    else input = '<input class="pf-input" id="' + id + '" style="padding-right:14px" ' + (opts.type ? 'inputmode="' + opts.type + '" ' : '') + 'placeholder="' + esc(label) + '" value="' + esc(val) + '">';
    return '<div class="pf-field"><label>' + esc(label) + '</label>' + input + '</div>';
  }
  /* ---------------- Logo upload + crop (Profile only) ---------------- */
  var LOGO_MAX_MB = 5;
  function applyLogo(url) {
    window.__resources = window.__resources || {};
    window.__resources.askevaLogo = url;
    try { localStorage.setItem("askeva_logo", url); } catch (e) {}
    document.querySelectorAll("img.lg, .side-logo img.mark").forEach(function (im) { im.src = url; });
    toast("Logo updated");
  }
  (function restoreLogo() {
    var saved; try { saved = localStorage.getItem("askeva_logo"); } catch (e) {}
    if (saved) { window.__resources = window.__resources || {}; window.__resources.askevaLogo = saved;
      document.querySelectorAll("img.lg, .side-logo img.mark").forEach(function (im) { im.src = saved; }); }
  })();
  function openLogoPicker(applyFn) {
    var inp = document.createElement("input");
    inp.type = "file"; inp.accept = "image/png,image/jpeg,.png,.jpg,.jpeg"; inp.style.display = "none";
    document.body.appendChild(inp);
    inp.addEventListener("change", function () {
      var f = inp.files && inp.files[0]; inp.remove();
      if (!f) return;
      if (!(/image\/(png|jpe?g)/i.test(f.type) || /\.(png|jpe?g)$/i.test(f.name))) { toast("Choose a JPG, JPEG or PNG image"); return; }
      if (f.size > LOGO_MAX_MB * 1024 * 1024) { toast("Image too large \u2014 max " + LOGO_MAX_MB + "MB"); return; }
      var rd = new FileReader();
      rd.onload = function () { openCropper(String(rd.result), applyFn); };
      rd.readAsDataURL(f);
    });
    inp.click();
  }
  function ensureCropStyle() {
    if (document.getElementById("lc-style")) return;
    var s = document.createElement("style"); s.id = "lc-style";
    s.textContent =
      ".lc-ov{position:fixed;inset:0;z-index:9999;display:flex;align-items:center;justify-content:center;background:rgba(15,26,14,.55);-webkit-backdrop-filter:blur(3px);backdrop-filter:blur(3px);}" +
      ".lc-card{width:min(330px,92vw);background:#fff;border-radius:22px;padding:18px;box-shadow:0 24px 60px -16px rgba(0,0,0,.5);font-family:var(--font-body,inherit);}" +
      ".lc-hd{display:flex;align-items:center;justify-content:space-between;margin-bottom:14px;}" +
      ".lc-hd span{font-size:16px;font-weight:800;color:var(--ink,#15231a);letter-spacing:-.01em;}" +
      ".lc-x{width:32px;height:32px;border:none;background:var(--surface-2,#f6f8f5);border-radius:10px;display:grid;place-items:center;cursor:pointer;color:var(--ink-2,#4d5d52);}" +
      ".lc-x svg{width:18px;height:18px;}" +
      ".lc-stage{position:relative;margin:0 auto;border-radius:18px;overflow:hidden;background:#0d140c;cursor:grab;touch-action:none;}" +
      ".lc-stage:active{cursor:grabbing;}" +
      ".lc-img{position:absolute;top:0;left:0;max-width:none;-webkit-user-drag:none;user-select:none;pointer-events:none;}" +
      ".lc-mask{position:absolute;inset:0;border:2px solid rgba(255,255,255,.92);border-radius:18px;pointer-events:none;}" +
      ".lc-zoom{display:flex;align-items:center;gap:10px;margin:16px 2px 2px;color:var(--ink-3,#8a978d);font-weight:800;}" +
      ".lc-range{flex:1;accent-color:var(--eva-green,#3cc23f);}" +
      ".lc-foot{display:flex;gap:10px;margin-top:14px;}" +
      ".lc-btn{flex:1;border:none;border-radius:13px;padding:13px;font-family:inherit;font-size:14px;font-weight:800;cursor:pointer;}" +
      ".lc-btn.ghost{background:var(--surface-2,#f6f8f5);color:var(--ink-2,#4d5d52);}" +
      ".lc-btn.primary{background:linear-gradient(135deg,var(--eva-green,#3cc23f),var(--eva-green-deep,#2ba84a));color:#fff;box-shadow:0 8px 18px -8px rgba(43,168,74,.7);}";
    document.head.appendChild(s);
  }
  function openCropper(src, applyFn) {
    ensureCropStyle();
    var VIEW = 264, OUT = 320;
    var ov = document.createElement("div"); ov.className = "lc-ov";
    ov.innerHTML =
      '<div class="lc-card">' +
        '<div class="lc-hd"><span>Crop Logo</span><button class="lc-x" aria-label="Close">' + I.x + '</button></div>' +
        '<div class="lc-stage" style="width:' + VIEW + 'px;height:' + VIEW + 'px"><img class="lc-img" alt=""><div class="lc-mask"></div></div>' +
        '<div class="lc-zoom"><span>\u2212</span><input type="range" class="lc-range" min="1" max="3" step="0.01" value="1"><span>+</span></div>' +
        '<div class="lc-foot"><button class="lc-btn ghost" data-cancel>Cancel</button><button class="lc-btn primary" data-apply>Apply</button></div>' +
      '</div>';
    document.body.appendChild(ov);
    var img = ov.querySelector(".lc-img"), range = ov.querySelector(".lc-range"), stage = ov.querySelector(".lc-stage");
    var nat = new Image(), st = { baseW: 0, baseH: 0, scale: 1, x: 0, y: 0 };
    var drag = false, sx = 0, sy = 0, ox = 0, oy = 0;
    function draw() {
      var w = st.baseW * st.scale, h = st.baseH * st.scale;
      st.x = Math.min(0, Math.max(VIEW - w, st.x));
      st.y = Math.min(0, Math.max(VIEW - h, st.y));
      img.style.width = w + "px"; img.style.height = h + "px";
      img.style.transform = "translate(" + st.x + "px," + st.y + "px)";
    }
    nat.onload = function () {
      var cover = Math.max(VIEW / nat.naturalWidth, VIEW / nat.naturalHeight);
      st.baseW = nat.naturalWidth * cover; st.baseH = nat.naturalHeight * cover; st.scale = 1;
      st.x = (VIEW - st.baseW) / 2; st.y = (VIEW - st.baseH) / 2; draw();
    };
    nat.src = src; img.src = src;
    range.addEventListener("input", function () {
      var next = parseFloat(this.value), prev = st.scale, c = VIEW / 2;
      st.x = c - (c - st.x) * (next / prev); st.y = c - (c - st.y) * (next / prev);
      st.scale = next; draw();
    });
    function pt(e) { var t = e.touches ? e.touches[0] : e; return { x: t.clientX, y: t.clientY }; }
    function down(e) { drag = true; var p = pt(e); sx = p.x; sy = p.y; ox = st.x; oy = st.y; e.preventDefault(); }
    function move(e) { if (!drag) return; var p = pt(e); st.x = ox + (p.x - sx); st.y = oy + (p.y - sy); draw(); e.preventDefault(); }
    function up() { drag = false; }
    stage.addEventListener("mousedown", down); window.addEventListener("mousemove", move); window.addEventListener("mouseup", up);
    stage.addEventListener("touchstart", down, { passive: false }); window.addEventListener("touchmove", move, { passive: false }); window.addEventListener("touchend", up);
    function cleanup() {
      window.removeEventListener("mousemove", move); window.removeEventListener("mouseup", up);
      window.removeEventListener("touchmove", move); window.removeEventListener("touchend", up); ov.remove();
    }
    ov.querySelector(".lc-x").addEventListener("click", cleanup);
    ov.querySelector("[data-cancel]").addEventListener("click", cleanup);
    ov.addEventListener("click", function (e) { if (e.target === ov) cleanup(); });
    ov.querySelector("[data-apply]").addEventListener("click", function () {
      var cv = document.createElement("canvas"); cv.width = OUT; cv.height = OUT;
      var ctx = cv.getContext("2d");
      var w = st.baseW * st.scale, h = st.baseH * st.scale;
      var sX = (-st.x / w) * nat.naturalWidth, sY = (-st.y / h) * nat.naturalHeight;
      var sW = (VIEW / w) * nat.naturalWidth, sH = (VIEW / h) * nat.naturalHeight;
      ctx.drawImage(nat, sX, sY, sW, sH, 0, 0, OUT, OUT);
      var out = cv.toDataURL("image/png");
      cleanup(); applyFn(out);
    });
  }
  function openEditProfile() {
    mSheet.innerHTML =
      '<div class="pf-mgrip"></div>' +
      '<div class="pf-mhd"><span class="tt">Edit Profile Details</span><button class="x" data-mx>' + I.x + '</button></div>' +
      '<div class="pf-mbody">' +
        '<div class="pf-mavrow"><div class="av"><img class="lg" src="' + ((window.__resources && window.__resources.askevaLogo) || 'assets/askeva-logo.png') + '" alt="AskEva"></div>' +
          '<button class="pf-mavbtn" data-changelogo>' + I.edit + 'Change Logo</button></div>' +
        field("epName", "Display Name", WA.name) +
        field("epEmail", "Email", WA.email, { type: "email" }) +
        field("epDesc", "Description", WA.desc, { textarea: true }) +
        field("epWeb", "Website", WA.website, { type: "url" }) +
        field("epVert", "Business Vertical", WA.vertical, { select: VERTICALS }) +
        field("epAddr", "Address", WA.address, { textarea: true }) +
      '</div>' +
      '<div class="pf-mfoot"><button class="pf-btn primary" data-epsave>' + I.save + 'Save Changes</button></div>';
    $("[data-mx]", mSheet).addEventListener("click", closeMember);
    $("[data-changelogo]", mSheet).addEventListener("click", function () { openLogoPicker(applyLogo); });
    $("[data-epsave]", mSheet).addEventListener("click", function () {
      var nm = $("#epName", mSheet).value.trim();
      if (!nm) { toast("Display name is required"); return; }
      WA.name = nm;
      WA.email = $("#epEmail", mSheet).value.trim();
      WA.desc = $("#epDesc", mSheet).value.trim();
      WA.website = $("#epWeb", mSheet).value.trim();
      WA.vertical = $("#epVert", mSheet).value;
      WA.address = $("#epAddr", mSheet).value.trim();
      renderAccount();
      // sync the green header name/email too
      var hn = pane.querySelector(".pf-id .nm"), he = pane.querySelector(".pf-id .em");
      if (hn) hn.textContent = WA.name; if (he) he.textContent = WA.email;
      closeMember(); toast("Profile updated");
    });
    requestAnimationFrame(function () { mScrim.classList.add("show"); mSheet.classList.add("show"); });
  }

  /* ---------------- tab switching ---------------- */
  var rendered = { account: false, team: false, password: false, pricing: false, subscription: false, transactions: false };
  function ensure(tab) {
    if (rendered[tab]) return;
    if (tab === "account") renderAccount();
    else if (tab === "team") renderTeam();
    else if (tab === "password") renderPassword();
    else if (tab === "pricing") renderPricing();
    else if (tab === "subscription") renderSubscription();
    else if (tab === "transactions") renderTransactions();
    rendered[tab] = true;
  }
  function show(tab) {
    $$(".pf-tab").forEach(function (b) { b.classList.toggle("active", b.getAttribute("data-tab") === tab); });
    $$(".pf-panel").forEach(function (p) { p.hidden = p.getAttribute("data-tabpanel") !== tab; });
    ensure(tab);
    var sc = $(".pf-scroll"); if (sc) sc.scrollTop = 0;
  }
  $("#pfTabs").addEventListener("click", function (e) {
    var b = e.target.closest(".pf-tab"); if (b) show(b.getAttribute("data-tab"));
  });
  window.__pfShowTab = show;   // let other modules (e.g. dashboard Upgrade) open a profile tab

  /* ---------------- delegated interactions ---------------- */
  pane.addEventListener("click", function (e) {
    var t;
    if ((t = e.target.closest("[data-pf]"))) {
      var k = t.getAttribute("data-pf");
      if (k === "edit") openEditProfile();
      else if (k === "renew") { toast("Renewing ECOMMERCE plan\u2026"); logTx({ amount: 23988, deducted: true, reason: "Plan renewed \u2014 Ecommerce", method: "Wallet" }); }
      return;
    }
    if (e.target.closest("[data-editprofile]")) { openEditProfile(); return; }
    // password eye
    if ((t = e.target.closest("[data-eye]"))) {
      var inp = document.getElementById(t.getAttribute("data-eye"));
      if (inp) { var show = inp.type === "password"; inp.type = show ? "text" : "password"; t.innerHTML = show ? I.eyeoff : I.eye; }
      return;
    }
    if (e.target.closest("[data-savepw]")) {
      var o = $("#pwOld").value, n = $("#pwNew").value, r = $("#pwRe").value;
      if (!o || !n || !r) { toast("Please fill all password fields"); return; }
      if (n.length < 8) { toast("New password must be 8+ characters"); return; }
      if (n !== r) { toast("Passwords do not match"); return; }
      $("#pwOld").value = $("#pwNew").value = $("#pwRe").value = ""; toast("Password updated successfully");
      return;
    }
    // team
    if (e.target.closest("[data-addmember]")) { openMember(null); return; }
    if ((t = e.target.closest("[data-edit]"))) { var ei = +t.getAttribute("data-edit"); openMember(TEAM[ei], ei); return; }
    if ((t = e.target.closest("[data-view]"))) { var vi = +t.getAttribute("data-view"); openMemberView(TEAM[vi], vi); return; }
    if ((t = e.target.closest("[data-del]"))) {
      var di = +t.getAttribute("data-del"); var nm = TEAM[di].name;
      var sc = document.createElement("div");
      sc.style.cssText = "position:absolute;inset:0;z-index:130;background:rgba(15,26,14,.45);display:grid;place-items:center;padding:24px";
      sc.innerHTML = '<div style="width:100%;max-width:320px;background:#fff;border-radius:20px;padding:20px;box-shadow:0 24px 60px -16px rgba(0,0,0,.5)"><div style="font-size:17px;font-weight:800;color:var(--ink);margin-bottom:8px">Remove team member?</div><div style="font-size:13px;font-weight:600;color:var(--ink-2);line-height:1.5;margin-bottom:18px">\u201C' + esc(nm) + '\u201D will lose access to this workspace.</div><div style="display:flex;gap:10px"><button id="pfcCancel" style="flex:1;border:1.5px solid var(--line);background:#fff;color:var(--ink-2);border-radius:12px;padding:13px;font-family:var(--font-body);font-size:14px;font-weight:800;cursor:pointer">Cancel</button><button id="pfcOk" style="flex:1;border:none;background:#ef5350;color:#fff;border-radius:12px;padding:13px;font-family:var(--font-body);font-size:14px;font-weight:800;cursor:pointer">Remove</button></div></div>';
      pane.appendChild(sc);
      sc.addEventListener("click", function (ev) { if (ev.target === sc) sc.remove(); });
      sc.querySelector("#pfcCancel").addEventListener("click", function () { sc.remove(); });
      sc.querySelector("#pfcOk").addEventListener("click", function () { sc.remove(); TEAM.splice(di, 1); renderTeam(); toast("Removed " + nm); });
      return;
    }
    // pricing pay
    if ((t = e.target.closest("[data-pay]"))) {
      if (t.getAttribute("data-pay") === "wallet") {
        toast("Paying " + rupee() + "23,988 from wallet\u2026");
        logTx({ amount: 23988, deducted: true, reason: "Ecommerce plan \u00b7 yearly", method: "Wallet" });
      } else if (window.__payGateway) {
        window.__payGateway(23988, {
          headNm: "AskEva Technologies", headSub: "Ecommerce plan \u00b7 billed yearly", totalLabel: "Amount payable",
          success: function (amt) {
            logTx({ amount: amt, deducted: false, reason: "Ecommerce plan \u00b7 yearly", gateway: "Razorpay", method: "Razorpay", gst: Math.round(amt - amt / 1.18) });
            var a = rupee() + Math.round(amt).toLocaleString("en-IN");
            return { procT: "Processing payment\u2026", procS: "Please don\u2019t close this screen",
              okT: "Payment Successful", okS: a + " \u00b7 Ecommerce plan", toast: "Plan activated successfully" };
          }
        });
      } else { toast("Opening payment gateway\u2026"); }
      return;
    }
    // transactions
    if ((t = e.target.closest("[data-txtoggle]"))) { t.closest(".pf-tx").classList.toggle("open"); return; }
    if ((t = e.target.closest("[data-inv]"))) { e.stopPropagation(); toast("Downloading invoice " + t.getAttribute("data-inv")); return; }
    if ((t = e.target.closest("[data-pg]"))) {
      var pg = t.getAttribute("data-pg");
      if (pg === "next" || pg === "prev") toast("Page navigation");
      else toast("Loading page " + pg);
      return;
    }
  });

  // pricing country change
  pane.addEventListener("change", function (e) {
    if (e.target.id === "pfCountry") {
      var c = COSTS[e.target.value] || COSTS.India;
      $("#pfArea").textContent = "Service Area: " + c.area;
      $("#pfCostGrid").innerHTML = costGrid(c);
    }
  });

  // initial
  ensure("account");
})();
