/* =========================================================
   AskEva — Appointments (working module · v2)
   Redrawn to match the real AskEva product IA:
     Dashboard · Bookings · Payments · Booking Settings
   This CORE file owns: shared data model, helpers, UI
   primitives (sheet / confirm / calendar), the sub-tab
   router, and the Dashboard + Bookings views.
   The companion file appointments-detail.js attaches the
   Detail view, the New/Edit form, Payments and Settings
   onto the shared AX namespace.
   ========================================================= */
window.AX = (function () {
  "use strict";
  var pane = document.getElementById("app-appointments");
  var AX = { pane: pane };
  if (!pane) return AX;

  var $  = AX.$  = function (s, r) { return (r || document).querySelector(s); };
  var $$ = AX.$$ = function (s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); };

  /* ---------- toast ---------- */
  var toastT;
  AX.toast = function (msg) {
    var t = document.getElementById("toast"); if (!t) return;
    t.textContent = msg;
    t.style.opacity = "1"; t.style.transform = "translateX(-50%) translateY(0)";
    clearTimeout(toastT);
    toastT = setTimeout(function () { t.style.opacity = "0"; t.style.transform = "translateX(-50%) translateY(20px)"; }, 1900);
  };
  var esc = AX.esc = function (s) { return String(s == null ? "" : s).replace(/[&<>"]/g, function (c) {
    return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]; }); };

  /* ---------- icons ---------- */
  var I = AX.I = {
    back:   '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M15 19l-7-7 7-7"/></svg>',
    x:      '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"><path d="M6 6l12 12M18 6 6 18"/></svg>',
    plus:   '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"><path d="M12 5v14M5 12h14"/></svg>',
    check:  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="m5 12 4 4 10-11"/></svg>',
    chevR:  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m9 6 6 6-6 6"/></svg>',
    chevL:  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m15 6-6 6 6 6"/></svg>',
    cal:    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="5" width="18" height="16" rx="2.5"/><path d="M3 10h18M8 3v4M16 3v4"/></svg>',
    calPlus:'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="5" width="18" height="16" rx="2.5"/><path d="M3 10h18M8 3v4M16 3v4M12 14v4M10 16h4"/></svg>',
    users:  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="9" cy="8" r="3.2"/><path d="M3 20c0-3.2 2.7-5 6-5s6 1.8 6 5"/><path d="M16 4.5a3.2 3.2 0 0 1 0 6.3M21 20c0-2.6-1.6-4.3-4-4.8"/></svg>',
    clock:  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3.5 2"/></svg>',
    check2: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="m8.5 12 2.5 2.5 4.5-5"/></svg>',
    trend:  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><polyline points="22 7 13.5 15.5 8.5 10.5 2 17"/><polyline points="16 7 22 7 22 13"/></svg>',
    rupee:  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M7 5h10M7 9h10M16 5c0 4-3.5 5-6 5l6 9"/></svg>',
    star:   '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m12 3 2.7 5.4 6 .9-4.3 4.2 1 6L12 16.9 6.6 19.5l1-6L3.3 9.3l6-.9z"/></svg>',
    starF:  '<svg viewBox="0 0 24 24" fill="currentColor"><path d="m12 3 2.7 5.4 6 .9-4.3 4.2 1 6L12 16.9 6.6 19.5l1-6L3.3 9.3l6-.9z"/></svg>',
    dots:   '<svg viewBox="0 0 24 24" fill="currentColor"><circle cx="5" cy="12" r="2"/><circle cx="12" cy="12" r="2"/><circle cx="19" cy="12" r="2"/></svg>',
    phone:  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linejoin="round"><path d="M5 4h3l1.5 4-2 1.5a12 12 0 0 0 5 5L14 12l4 1.5V17a2 2 0 0 1-2 2A14 14 0 0 1 5 6Z"/></svg>',
    msg:    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14 9a2 2 0 0 1-2 2H6l-4 4V4c0-1.1.9-2 2-2h8a2 2 0 0 1 2 2v5Z"/><path d="M18 9h2a2 2 0 0 1 2 2v11l-4-4h-6a2 2 0 0 1-2-2v-1"/><circle cx="5.2" cy="6.4" r=".7" fill="currentColor" stroke="none"/><circle cx="8" cy="6.4" r=".7" fill="currentColor" stroke="none"/><circle cx="10.8" cy="6.4" r=".7" fill="currentColor" stroke="none"/></svg>',
    repeat: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M17 3l3 3-3 3M20 6H8a4 4 0 0 0-4 4v1M7 21l-3-3 3-3M4 18h12a4 4 0 0 0 4-4v-1"/></svg>',
    edit:   '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M11 4H5a2 2 0 0 0-2 2v13a2 2 0 0 0 2 2h13a2 2 0 0 0 2-2v-6"/><path d="M18.5 2.5a2.12 2.12 0 0 1 3 3L12 15l-4 1 1-4Z"/></svg>',
    trash:  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 7h16M9 7V5a2 2 0 0 1 2-2h2a2 2 0 0 1 2 2v2M6 7l1 13a2 2 0 0 0 2 2h6a2 2 0 0 0 2-2l1-13"/></svg>',
    user:   '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="8" r="4"/><path d="M4 21c0-4 3.6-6 8-6s8 2 8 6"/></svg>',
    dept:   '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linejoin="round"><path d="M4 21V8l8-5 8 5v13"/><path d="M9 21v-6h6v6" stroke-linecap="round"/></svg>',
    cake:   '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 21h16v-7a2 2 0 0 0-2-2H6a2 2 0 0 0-2 2v7Z"/><path d="M4 16c2 0 2 1.4 4 1.4S10 16 12 16s2 1.4 4 1.4S18 16 20 16M12 8V5M9 6V4M15 6V4"/></svg>',
    note:   '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 5h16M4 10h16M4 15h10"/></svg>',
    card:   '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="2" y="5" width="20" height="14" rx="2.5"/><path d="M2 10h20"/></svg>',
    search: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><circle cx="11" cy="11" r="7"/><path d="M21 21l-4.3-4.3"/></svg>',
    filter: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M4 6h16M7 12h10M10 18h4"/></svg>',
    grip:   '<svg viewBox="0 0 24 24" fill="currentColor"><circle cx="9" cy="6" r="1.6"/><circle cx="15" cy="6" r="1.6"/><circle cx="9" cy="12" r="1.6"/><circle cx="15" cy="12" r="1.6"/><circle cx="9" cy="18" r="1.6"/><circle cx="15" cy="18" r="1.6"/></svg>',
    warn:   '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 9v4M12 17h.01"/><path d="M10.3 3.9 2 19a2 2 0 0 0 1.7 3h16.6a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0Z"/></svg>',
    upi:    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M7 3 4 12l3 9M13 3l-3 9 3 9M21 7l-3 5 3 5"/></svg>',
    cash:   '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="2" y="6" width="20" height="12" rx="2"/><circle cx="12" cy="12" r="2.4"/></svg>'
  };

  /* ---------- config: departments (SHARED STORE) ----------
     Single source of truth for appointment departments. Edited from
     Appointment Settings → Departments and seeded with the real booking
     departments. Drives the booking-form department picker, appointment
     detail, and the per-agent appointment-department assignment. */
  var DEPT_KEY = "askeva.appt.depts.v2";
  var DEPT_PALETTE = ["#2BA84A", "#2563EB", "#7C5CFF", "#E5499A", "#FF9416", "#1E7FB0", "#0E9F6E", "#D9480F", "#9333EA", "#0891B2", "#F2542D", "#15803D"];
  var SEED_DEPTS = [
    { id: "consult", name: "General Consultation", color: "#2BA84A" },
    { id: "demo",    name: "Product Demo",         color: "#2563EB" },
    { id: "onboard", name: "Onboarding",           color: "#7C5CFF" },
    { id: "diag",    name: "Diagnostics",          color: "#E5499A" },
    { id: "followup",name: "Follow-up",            color: "#FF9416" }
  ];
  var _depts; try { _depts = JSON.parse(localStorage.getItem(DEPT_KEY)) || null; } catch (e) { _depts = null; }
  if (!_depts || !_depts.length) _depts = SEED_DEPTS.map(function (d) { return Object.assign({}, d); });
  AX.DEPTS = _depts;
  AX.saveDepts = function () {
    try { localStorage.setItem(DEPT_KEY, JSON.stringify(AX.DEPTS)); } catch (e) {}
    try { document.dispatchEvent(new CustomEvent("apptdepts:changed")); } catch (e) {}
  };
  AX.deptById = function (id) { for (var i = 0; i < AX.DEPTS.length; i++) if (AX.DEPTS[i].id === id) return AX.DEPTS[i]; return AX.DEPTS[0] || { id: "", name: "\u2014", color: "#8A978D" }; };
  AX.deptInUse = function (id) { return (AX.appts || []).some(function (a) { return a.department === id; }); };
  AX.addDept = function (name) {
    name = (name || "").trim(); if (!name) return null;
    if (AX.DEPTS.some(function (d) { return d.name.toLowerCase() === name.toLowerCase(); })) return null;
    var dep = { id: "dp" + Date.now().toString(36), name: name, color: DEPT_PALETTE[AX.DEPTS.length % DEPT_PALETTE.length] };
    AX.DEPTS.push(dep); AX.saveDepts(); return dep;
  };
  AX.removeDept = function (id) { AX.DEPTS = AX.DEPTS.filter(function (d) { return d.id !== id; }); AX.saveDepts(); };
  AX.renameDept = function (id, name) { var d = AX.deptById(id); if (d && (name || "").trim()) { d.name = name.trim(); AX.saveDepts(); } };

  /* users (consultants) come from the shared people store (Settings → Agents) so
     anyone created/edited/deactivated there is instantly bookable here. */
  var FALLBACK_USERS = [
    { id: "eshan", name: "Eshan Rao", role: "Senior Consultant", color: "#2BA84A", initials: "ER", you: true },
    { id: "kavya", name: "Kavya S",   role: "Consultant",        color: "#7C5CFF", initials: "KS" },
    { id: "dev",   name: "Dev Patel", role: "Specialist",        color: "#FF9416", initials: "DP" },
    { id: "priya", name: "Priya M",   role: "Associate",         color: "#1E7FB0", initials: "PM" }
  ];
  function usersList() { return (window.AskEvaPeople && AskEvaPeople.roster) ? AskEvaPeople.roster("appt") : FALLBACK_USERS; }
  Object.defineProperty(AX, "USERS", { configurable: true, get: usersList });
  AX.userById = function (id) { var L = usersList(); for (var i = 0; i < L.length; i++) if (L[i].id === id) return L[i]; var p = (window.AskEvaPeople && AskEvaPeople.byId) ? AskEvaPeople.byId(id) : null; return p || null; };
  AX.METHODS = ["Card", "Netbanking", "Wallet", "Cash"];

  /* ---------- date helpers (anchor: REAL current date in IST / GMT+5:30) ---------- */
  var nowIST = AX.nowIST = function () { var d = new Date(); return new Date(d.getTime() + (d.getTimezoneOffset() + 330) * 60000); };
  var _ist = nowIST();
  var TODAY = AX.TODAY = new Date(_ist.getFullYear(), _ist.getMonth(), _ist.getDate());
  var MON  = AX.MON  = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
  var MONF = AX.MONF = ["January","February","March","April","May","June","July","August","September","October","November","December"];
  var DOW  = AX.DOW  = ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"];
  var DOWF = AX.DOWF = ["Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"];

  function pad(n) { return n < 10 ? "0" + n : "" + n; }
  AX.pad = pad;
  var iso = AX.iso = function (d) { return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate()); };
  var fromISO = AX.fromISO = function (s) { var p = s.split("-"); return new Date(+p[0], +p[1] - 1, +p[2]); };
  var addDays = AX.addDays = function (d, n) { var x = new Date(d); x.setDate(x.getDate() + n); return x; };
  AX.dayDiff = function (a, b) { return Math.round((fromISO(a) - fromISO(b)) / 86400000); };
  var TODAY_ISO = AX.TODAY_ISO = iso(TODAY);
  var TMRW_ISO  = AX.TMRW_ISO  = iso(addDays(TODAY, 1));

  AX.fmtTime = function (mins) {
    var h = Math.floor(mins / 60), m = mins % 60, ap = h >= 12 ? "PM" : "AM", hh = h % 12; if (hh === 0) hh = 12;
    return { hh: hh + (m ? ":" + pad(m) : ""), ap: ap, full: hh + ":" + pad(m) + " " + ap };
  };
  AX.fmtDayLong  = function (s) { var d = fromISO(s); return DOWF[d.getDay()] + ", " + d.getDate() + " " + MONF[d.getMonth()]; };
  AX.fmtDayShort = function (s) { var d = fromISO(s); return DOW[d.getDay()] + " " + d.getDate() + " " + MON[d.getMonth()]; };
  AX.relWord = function (s) {
    if (s === TODAY_ISO) return "Today";
    if (s === TMRW_ISO) return "Tomorrow";
    if (s === iso(addDays(TODAY, -1))) return "Yesterday";
    return null;
  };
  AX.durLabel = function (m) { if (m < 60) return m + " min"; var h = Math.floor(m / 60), mm = m % 60; return h + "h" + (mm ? " " + mm + "m" : ""); };
  AX.inr = function (n) { return "\u20b9" + Math.round(n || 0).toLocaleString("en-IN"); };
  /* payment status — only ever Success / Pending / Failed everywhere */
  AX.payLabel = function (s) { return s === "paid" ? "Success" : s === "pending" ? "Pending" : "Failed"; };
  AX.payCls = function (s) { return s === "paid" ? "completed" : s === "pending" ? "pending" : "cancelled"; };
  AX.ageFromDob = function (dob) { if (!dob) return ""; var d = fromISO(dob), y = TODAY.getFullYear() - d.getFullYear();
    if (TODAY.getMonth() < d.getMonth() || (TODAY.getMonth() === d.getMonth() && TODAY.getDate() < d.getDate())) y--; return y; };

  /* ---------- seed data ---------- */
  function mk(o) {
    o.created = o.created == null ? 1440 : o.created;
    if (o.payStatus == null) o.payStatus = o.paymentType === "prepaid" ? "paid" : (o.status === "completed" ? "paid" : "pending");
    o.orderId = o.orderId || ("ORD-" + (10240 + (mk._n = (mk._n || 0) + 1)));
    o.method = o.method || AX.METHODS[(mk._n) % AX.METHODS.length];
    return o;
  }
  function d(off) { return iso(addDays(TODAY, off)); }
  var SEED = [
    mk({ id: "a1", name: "Aarav Mehta",  age: 34, mobile: "9876543210", dob: "1991-08-12", department: "consult", user: "eshan", date: d(0), time: 630, dur: 30, description: "First consultation about the WhatsApp catalog rollout.", paymentType: "prepaid", amount: 1500, status: "confirmed" }),
    mk({ id: "a2", name: "Priya Nair",   age: 29, mobile: "9123456780", dob: "1996-02-04", department: "demo",    user: "kavya", date: d(0), time: 720, dur: 45, description: "Live demo of broadcast campaigns and analytics.", paymentType: "prepaid", amount: 0, status: "confirmed" }),
    mk({ id: "a3", name: "Rohan Das",    age: 41, mobile: "9988776655", dob: "1984-11-23", department: "onboard", user: "dev",   date: d(0), time: 900, dur: 60, description: "Onboarding walkthrough for the new store account.", paymentType: "postpaid", amount: 2000, status: "pending" }),
    mk({ id: "a4", name: "Sneha Iyer",   age: 36, mobile: "9090909090", dob: "1989-05-19", department: "followup",user: "eshan", date: d(0), time: 1020, dur: 30, description: "Follow-up on the refund escalation #4471.", paymentType: "prepaid", amount: 800, status: "confirmed" }),
    mk({ id: "a5", name: "Vikram Joshi", age: 47, mobile: "9871230456", dob: "1978-09-30", department: "consult", user: "priya", date: d(1), time: 660, dur: 30, description: "Quarterly account review.", paymentType: "prepaid", amount: 1500, status: "confirmed" }),
    mk({ id: "a6", name: "Meera Kapoor", age: 31, mobile: "9012345678", dob: "1994-12-08", department: "diag",    user: "kavya", date: d(1), time: 930, dur: 45, description: "Diagnostics review of campaign performance.", paymentType: "postpaid", amount: 2500, status: "pending" }),
    mk({ id: "a7", name: "Arjun Reddy",  age: 38, mobile: "9876012345", dob: "1987-07-14", department: "demo",    user: "dev",   date: d(2), time: 540, dur: 30, description: "Demo for the new chatbot flows.", paymentType: "prepaid", amount: 1200, status: "confirmed" }),
    mk({ id: "a8", name: "Ananya Gupta", age: 27, mobile: "9765432108", dob: "1998-03-21", department: "onboard", user: "eshan", date: d(3), time: 795, dur: 60, description: "Full onboarding for the Pro plan.", paymentType: "postpaid", amount: 3000, status: "pending" }),
    mk({ id: "p1", name: "Karan Shah",   age: 33, mobile: "9654321098", dob: "1992-10-02", department: "consult", user: "eshan", date: d(-1), time: 600, dur: 30, description: "Intro consultation.", paymentType: "prepaid", amount: 1500, status: "completed", created: 2880 }),
    mk({ id: "p2", name: "Divya Rao",    age: 45, mobile: "9543210987", dob: "1980-06-17", department: "demo",    user: "kavya", date: d(-1), time: 960, dur: 45, description: "Product demo.", paymentType: "prepaid", amount: 1200, status: "completed", created: 2880 }),
    mk({ id: "p3", name: "Rahul Verma",  age: 39, mobile: "9432109876", dob: "1986-01-29", department: "diag",    user: "dev",   date: d(-2), time: 690, dur: 30, description: "Diagnostics session.", paymentType: "postpaid", amount: 2500, status: "completed", created: 4320 }),
    mk({ id: "p4", name: "Nisha Pillai", age: 30, mobile: "9321098765", dob: "1995-04-11", department: "followup",user: "priya", date: d(-2), time: 1080, dur: 30, description: "Follow-up call.", paymentType: "prepaid", amount: 800, status: "completed", created: 4320 }),
    mk({ id: "p5", name: "Sahil Khan",   age: 28, mobile: "9210987654", dob: "1997-08-23", department: "demo",    user: "eshan", date: d(-3), time: 840, dur: 45, description: "Demo — did not show up.", paymentType: "postpaid", amount: 1200, status: "cancelled", payStatus: "failed", created: 5760 }),
    mk({ id: "p6", name: "Ishaan Roy",   age: 35, mobile: "9109876543", dob: "1990-11-05", department: "consult", user: "kavya", date: d(-4), time: 720, dur: 30, description: "Consultation.", paymentType: "prepaid", amount: 1500, status: "completed", created: 7200 }),
    mk({ id: "p7", name: "Tara Menon",   age: 42, mobile: "9098765432", dob: "1983-02-28", department: "onboard", user: "dev",   date: d(-5), time: 600, dur: 60, description: "Onboarding.", paymentType: "postpaid", amount: 3000, status: "completed", created: 8640 }),
    mk({ id: "p8", name: "Yusuf Ali",    age: 37, mobile: "9087654321", dob: "1988-09-09", department: "followup",user: "priya", date: d(-6), time: 990, dur: 30, description: "Follow-up — refunded after reschedule.", paymentType: "prepaid", amount: 800, status: "cancelled", payStatus: "refunded", created: 10080 })
  ];

  /* ---------- store ---------- */
  var KEY = "askeva.appointments.v3";
  var appts;
  try { appts = JSON.parse(localStorage.getItem(KEY)) || null; } catch (e) { appts = null; }
  if (!appts || !appts.length) appts = SEED.slice();
  AX.appts = appts;
  AX.save = function () { try { localStorage.setItem(KEY, JSON.stringify(AX.appts)); } catch (e) {} };
  AX.getAppt = function (id) { for (var i = 0; i < AX.appts.length; i++) if (AX.appts[i].id === id) return AX.appts[i]; return null; };
  AX.uid = function () { return "x" + Date.now().toString(36) + Math.floor(Math.random() * 1e4).toString(36); };
  AX.delAppt = function (id) { AX.appts = AX.appts.filter(function (a) { return a.id !== id; }); AX.save(); };

  /* ============================================================
     UI PRIMITIVES — bottom sheet + confirm modal + calendar
     ============================================================ */
  var scrim, sheet;
  function ensureSheet() {
    if (scrim) return;
    scrim = document.createElement("div"); scrim.className = "ax-scrim";
    sheet = document.createElement("div"); sheet.className = "ax-sheet";
    scrim.addEventListener("click", AX.closeSheet);
    pane.appendChild(scrim); pane.appendChild(sheet);
  }
  AX.openSheet = function (html) {
    ensureSheet(); sheet.innerHTML = html; sheet.scrollTop = 0;
    requestAnimationFrame(function () { scrim.classList.add("show"); sheet.classList.add("show"); });
    return sheet;
  };
  AX.closeSheet = function () { if (sheet) { scrim.classList.remove("show"); sheet.classList.remove("show"); } };

  var cScrim, onGo;
  AX.confirm = function (o) {
    if (!cScrim) {
      cScrim = document.createElement("div"); cScrim.className = "ax-modal-scrim";
      pane.appendChild(cScrim);
      cScrim.addEventListener("click", function (e) { if (e.target === cScrim) cScrim.classList.remove("show"); });
    }
    cScrim.innerHTML = '<div class="ax-modal"><div class="mic">' + I.warn + '</div><div class="mt">' + esc(o.title) +
      '</div><div class="ms">' + esc(o.sub) + '</div><div class="mb"><button class="keep" id="axCKeep">Keep</button>' +
      '<button class="go" id="axCGo">' + esc(o.go) + '</button></div></div>';
    onGo = o.onGo;
    $("#axCKeep", cScrim).addEventListener("click", function () { cScrim.classList.remove("show"); });
    $("#axCGo", cScrim).addEventListener("click", function () { cScrim.classList.remove("show"); if (onGo) onGo(); });
    requestAnimationFrame(function () { cScrim.classList.add("show"); });
  };

  /* radio sheet helper */
  AX.radioSheet = function (title, items, onPick) {
    var html = '<div class="ax-grip"></div><div class="ax-sheet-head"><div class="ax-sheet-ttl">' + esc(title) + '</div></div>' +
      '<div class="ax-reasons">' + items.map(function (it) {
        return '<button class="ax-reason' + (it.on ? " on" : "") + '" data-v="' + esc(it.v) + '">' + (it.dot || "") + esc(it.label) + '</button>';
      }).join("") + '</div>';
    var s = AX.openSheet(html);
    $$(".ax-reason", s).forEach(function (b) {
      b.addEventListener("click", function () { AX.closeSheet(); onPick(b.getAttribute("data-v")); });
    });
  };

  /* full month calendar; opts: {sel, min, dots, onPick} */
  AX.calendar = function (opts) {
    opts = opts || {};
    var view = fromISO(opts.sel || TODAY_ISO); view.setDate(1);
    var picked = opts.sel || null;
    var minPast = opts.allowPast === false;
    var mode = "days"; // days | months | years
    var s = AX.openSheet('<div class="ax-grip"></div><div id="axCalWrap"></div>');
    function paintDays() {
      var y = view.getFullYear(), mo = view.getMonth();
      var first = new Date(y, mo, 1).getDay(), dim = new Date(y, mo + 1, 0).getDate(), prevDim = new Date(y, mo, 0).getDate();
      var cells = "";
      for (var i = 0; i < first; i++) cells += '<button class="ax-cell muted" disabled>' + (prevDim - first + 1 + i) + '</button>';
      for (var dd = 1; dd <= dim; dd++) {
        var di = y + "-" + pad(mo + 1) + "-" + pad(dd);
        var has = opts.dots !== false && AX.appts.some(function (a) { return a.date === di && a.status !== "cancelled"; });
        var isPast = minPast && AX.dayDiff(di, TODAY_ISO) < 0;
        cells += '<button class="ax-cell' + (di === TODAY_ISO ? " today" : "") + (di === picked ? " on" : "") + (has ? " has" : "") + '"' +
          (isPast ? " disabled" : "") + ' data-d="' + di + '">' + dd + '</button>';
      }
      $("#axCalWrap", s).innerHTML =
        '<div class="ax-sheet-head"><div class="ax-sheet-ttl">' + esc(opts.title || "Pick a date") + '</div></div>' +
        '<div class="ax-calnav"><button id="axCalPrev">' + I.chevL + '</button><button class="m mbtn" id="axCalTitle">' + MONF[mo] + " " + y + '</button><button id="axCalNext">' + I.chevR + '</button></div>' +
        '<div class="ax-caldow">' + DOW.map(function (x) { return '<span>' + x.charAt(0) + '</span>'; }).join("") + '</div>' +
        '<div class="ax-calgrid">' + cells + '</div>';
      $("#axCalPrev", s).addEventListener("click", function () { view.setMonth(view.getMonth() - 1); paint(); });
      $("#axCalNext", s).addEventListener("click", function () { view.setMonth(view.getMonth() + 1); paint(); });
      $("#axCalTitle", s).addEventListener("click", function () { mode = "months"; paint(); });
      $$(".ax-cell[data-d]:not([disabled])", s).forEach(function (b) {
        b.addEventListener("click", function () { picked = b.getAttribute("data-d"); AX.closeSheet(); opts.onPick(picked); });
      });
    }
    function paintMonths() {
      var y = view.getFullYear(), curMo = view.getMonth();
      var grid = MONF.map(function (nm, i) { return '<button class="ax-mcell' + (i === curMo ? " on" : "") + '" data-m="' + i + '">' + nm.slice(0, 3) + '</button>'; }).join("");
      $("#axCalWrap", s).innerHTML =
        '<div class="ax-sheet-head"><div class="ax-sheet-ttl">' + esc(opts.title || "Pick a date") + '</div></div>' +
        '<div class="ax-calnav"><button id="axCalPrevY">' + I.chevL + '</button><button class="m mbtn" id="axCalYear">' + y + '</button><button id="axCalNextY">' + I.chevR + '</button></div>' +
        '<div class="ax-monthgrid">' + grid + '</div>';
      $("#axCalPrevY", s).addEventListener("click", function () { view.setFullYear(y - 1); paint(); });
      $("#axCalNextY", s).addEventListener("click", function () { view.setFullYear(y + 1); paint(); });
      $("#axCalYear", s).addEventListener("click", function () { mode = "years"; paint(); });
      $$(".ax-mcell", s).forEach(function (b) { b.addEventListener("click", function () { view.setMonth(+b.getAttribute("data-m")); mode = "days"; paint(); }); });
    }
    function paintYears() {
      var y = view.getFullYear(), curY = (new Date()).getFullYear();
      var start = curY + 5, end = curY - 100, cells = "";
      for (var yy = start; yy >= end; yy--) cells += '<button class="ax-ycell' + (yy === y ? " on" : "") + '" data-y="' + yy + '">' + yy + '</button>';
      $("#axCalWrap", s).innerHTML =
        '<div class="ax-sheet-head"><div class="ax-sheet-ttl">' + esc(opts.title || "Pick a date") + '</div></div>' +
        '<div class="ax-calnav"><span></span><button class="m mbtn" id="axCalBackM">Select year</button><span></span></div>' +
        '<div class="ax-yeargrid">' + cells + '</div>';
      $("#axCalBackM", s).addEventListener("click", function () { mode = "months"; paint(); });
      var sel = $(".ax-ycell.on", s); if (sel && sel.scrollIntoView) try { sel.scrollIntoView({ block: "center" }); } catch (e) {}
      $$(".ax-ycell", s).forEach(function (b) { b.addEventListener("click", function () { view.setFullYear(+b.getAttribute("data-y")); mode = "months"; paint(); }); });
    }
    function paint() { if (mode === "months") paintMonths(); else if (mode === "years") paintYears(); else paintDays(); }
    paint();
  };

  /* ============================================================
     ROUTER — sub-tabs
     ============================================================ */
  var TAB_META = {
    dashboard: { big: "Dashboard", sub: "Appointment overview" },
    bookings:  { big: "Bookings",  sub: "Calendar & schedule" },
    payments:  { big: "Payments",  sub: "Transaction history" },
    settings:  { big: "Settings",  sub: "Booking form fields" }
  };
  AX.state = { tab: "dashboard", agent: "all", day: TODAY_ISO, payStatus: "all", payQ: "" };

  AX.setTab = function (tab) {
    AX.state.tab = tab;
    $$("#axTabs button").forEach(function (b) { b.classList.toggle("active", b.getAttribute("data-tab") === tab); });
    var m = TAB_META[tab];
    var big = $("#axBig"), sub = $("#axSub");
    if (big) big.textContent = m.big;
    if (sub) sub.textContent = m.sub;
    var pill = $("#axPill"), fab = $("#axFab");
    // header pill adapts per tab (pill may be hidden/absent — null-safe)
    if (pill) {
      if (tab === "dashboard") { pill.style.display = ""; pill.innerHTML = agentLabel() + " \u25be"; }
      else { pill.style.display = "none"; }
    }
    fab.style.display = (tab === "settings" || tab === "payments") ? "none" : "";
    render();
  };
  function agentLabel() { return AX.state.agent === "all" ? "All Agents" : (AX.userById(AX.state.agent) || {}).name; }
  AX.agentLabel = agentLabel;

  function render() {
    var host = $("#axView"); if (!host) return;
    host.style.animation = "none"; host.offsetHeight; host.style.animation = "";
    if (AX.state.tab === "dashboard") AX.renderDashboard(host);
    else if (AX.state.tab === "bookings") AX.renderBookings(host);
    else if (AX.state.tab === "payments") AX.renderPayments ? AX.renderPayments(host) : (host.innerHTML = "");
    else AX.renderSettings ? AX.renderSettings(host) : (host.innerHTML = "");
  }
  AX.render = render;

  /* live-sync with the people store: agent changes in Settings re-render appointments */
  if (window.AskEvaPeople && AskEvaPeople.on) {
    AskEvaPeople.on(function () { try { if (AX.pane) render(); } catch (e) {} });
  }
  /* live-sync when departments are added/renamed/deleted in Settings → Departments */
  document.addEventListener("apptdepts:changed", function () { try { if (AX.pane) render(); } catch (e) {} });

  /* ============================================================
     DASHBOARD
     ============================================================ */
  function scope() {
    var a = AX.appts;
    if (AX.state.agent !== "all") a = a.filter(function (x) { return x.user === AX.state.agent; });
    return a;
  }
  AX.renderDashboard = function (host) {
    var a = scope();
    var todayCount = a.filter(function (x) { return x.date === TODAY_ISO && x.status !== "cancelled"; }).length;
    var total = a.length;
    var pending = a.filter(function (x) { return x.status === "pending" || x.status === "confirmed"; }).length;
    var completed = a.filter(function (x) { return x.status === "completed"; }).length;
    var cancelled = a.filter(function (x) { return x.status === "cancelled"; }).length;
    var earned = a.filter(function (x) { return x.payStatus === "paid"; }).reduce(function (s, x) { return s + (x.amount || 0); }, 0);
    var totalRev = a.filter(function (x) { return x.status !== "cancelled"; }).reduce(function (s, x) { return s + (x.amount || 0); }, 0);
    var compRev = a.filter(function (x) { return x.status === "completed"; }).reduce(function (s, x) { return s + (x.amount || 0); }, 0);
    var successDen = completed + cancelled;
    var successRate = successDen ? Math.round((completed / successDen) * 100) : 0;
    var avgRev = completed ? Math.round(compRev / completed) : 0;

    host.innerHTML =
      '<div class="ap-secrow"><span class="h">Overview</span><span class="a" data-go="bookings">View bookings ' + I.chevR + '</span></div>' +
      '<div class="ap-statgrid">' +
        stat(I.cal, "today", todayCount, "Today's Appointments") +
        stat(I.users, "blue", total, "Total Appointments") +
        stat(I.clock, "amber", pending, "Pending") +
        stat(I.check2, "", completed, "Completed") +
      '</div>' +
      '<div class="ap-revrow">' +
        '<div class="ap-rev"><div class="l">Earned Revenue</div><div class="v">' + AX.inr(earned) + '</div><div class="d">' + I.trend + ' realised</div></div>' +
        '<div class="ap-rev alt"><div class="l">Total Revenue</div><div class="v">' + AX.inr(totalRev) + '</div><div class="d">' + I.trend + ' booked</div></div>' +
      '</div>' +
      '<div class="ap-secrow"><span class="h">Performance</span></div>' +
      '<div class="ap-kpis">' +
        '<div class="ap-kpi"><div class="v">' + successRate + '%</div><div class="l">Success Rate</div><div class="track"><i style="width:' + successRate + '%"></i></div></div>' +
        '<div class="ap-kpi"><div class="v">' + AX.inr(avgRev) + '</div><div class="l">Avg Revenue</div></div>' +
        '<div class="ap-kpi"><div class="v">' + AX.inr(compRev) + '</div><div class="l">Completed Rev.</div></div>' +
      '</div>' +
      '<div class="ap-secrow"><span class="h">Trend</span></div>' +
      trendCard(a);

    $$("[data-go]", host).forEach(function (el) { el.addEventListener("click", function () { AX.setTab(el.getAttribute("data-go")); }); });
    // animate bars
    requestAnimationFrame(function () { $$(".ap-bar", host).forEach(function (b) { b.style.height = b.getAttribute("data-h") + "px"; }); });
  };
  function stat(ic, cls, num, lbl) {
    return '<div class="ap-stat"><div class="ic ' + cls + '">' + ic + '</div>' +
      '<div><div class="num">' + num + '</div><div class="lbl">' + lbl + '</div></div></div>';
  }
  function trendCard(a) {
    // last 7 days; per-day counts for up to top-3 agents (by total in scope)
    var agents = AX.state.agent === "all" ? AX.USERS.slice(0, 3) : [AX.userById(AX.state.agent)];
    var days = [];
    for (var i = 6; i >= 0; i--) days.push(iso(addDays(TODAY, -i)));
    var max = 1;
    var data = days.map(function (di) {
      var per = agents.map(function (ag) {
        var c = a.filter(function (x) { return x.date === di && x.user === ag.id && x.status !== "cancelled"; }).length;
        if (c > max) max = c; return c;
      });
      return { di: di, per: per };
    });
    var any = data.some(function (dd) { return dd.per.some(function (c) { return c > 0; }); });
    var H = 104;
    var cols = data.map(function (dd) {
      var dy = fromISO(dd.di);
      var bars = dd.per.map(function (c, idx) {
        var h = Math.max(c ? Math.round((c / max) * H) : 0, c ? 6 : 0);
        return '<span class="ap-bar c' + (idx + 1) + '" data-h="' + h + '" style="height:0px"></span>';
      }).join("");
      return '<div class="ap-col' + (dd.di === TODAY_ISO ? " on" : "") + '"><div class="ap-bars">' + bars + '</div>' +
        '<span class="dl">' + DOW[dy.getDay()].charAt(0) + '</span></div>';
    }).join("");
    var legend = '<div class="ap-legend">' + agents.map(function (ag, idx) {
      var sw = idx === 0 ? "var(--accent)" : idx === 1 ? "#8FD63B" : "#1E7FB0";
      return '<span class="li"><span class="sw" style="background:' + sw + '"></span>' + esc(ag.name) + '</span>';
    }).join("") + '</div>';
    return '<div class="ap-card"><div class="ch-hd"><div><div class="ch-ttl">' + I.trend + 'Appointment Trend by Agent</div>' +
      '<div class="ch-sub">Last 7 days report</div></div><span class="ch-menu">' + I.dots + '</span></div>' +
      (any ? '<div class="ap-chart">' + cols + '</div>' + legend
           : '<div class="ap-chart-empty">No appointment data available</div>') + '</div>';
  }

  /* agent filter sheet (dashboard pill) */
  AX.openAgentFilter = function () {
    var opts = [{ v: "all", label: "All Agents", on: AX.state.agent === "all" }];
    AX.USERS.forEach(function (u) { opts.push({ v: u.id, label: u.name + (u.you ? " (You)" : ""), on: AX.state.agent === u.id }); });
    AX.radioSheet("Filter by agent", opts, function (v) { AX.state.agent = v; $("#axPill").innerHTML = agentLabel() + " \u25be"; render(); });
  };

  /* ============================================================
     BOOKINGS — week strip + day timeline
     ============================================================ */
  AX.renderBookings = function (host) {
    var day = AX.state.day;
    var dObj = fromISO(day);
    // week strip centred so selected day visible; show the Sun..Sat of selected week
    var startOfWeek = addDays(dObj, -dObj.getDay());
    var week = "";
    for (var i = 0; i < 7; i++) {
      var wd = addDays(startOfWeek, i), wi = iso(wd);
      var n = AX.appts.filter(function (x) { return x.date === wi && x.status !== "cancelled"; }).length;
      week += '<button class="ax-wday' + (wi === day ? " on" : "") + '" data-d="' + wi + '">' +
        '<span class="dn">' + DOW[wd.getDay()].toUpperCase() + '</span><span class="dd">' + wd.getDate() + '</span>' +
        (n ? '<span class="wn' + (wi === day ? " on" : "") + '"></span>' : '') + '</button>';
    }

    var rel = AX.relWord(day);
    var dayList = AX.appts.filter(function (x) { return x.date === day; }).sort(function (x, y) { return x.time - y.time; });

    var timeline;
    if (!dayList.length) {
      timeline = '<div class="ax-empty"><div class="ic">' + I.cal + '</div><div class="t">No appointments</div>' +
        '<div class="s">Nothing booked for this day. Tap + to add one.</div></div>';
    } else {
      timeline = '<div class="ap-daytl">' + dayList.map(function (a, idx) {
        var tm = AX.fmtTime(a.time);
        return '<div class="ap-hour has"><div class="t">' + tm.hh + '<br>' + tm.ap + '</div>' +
          '<div class="lane">' + AX.bookingCard(a) + '</div></div>';
      }).join("") + '</div>';
    }

    host.innerHTML =
      '<div class="ap-toolbar"><button class="ap-today" id="apToday">Today</button>' +
        '<button class="ap-navbtn" id="apPrev">' + I.chevL + '</button>' +
        '<button class="ap-navbtn" id="apNext">' + I.chevR + '</button>' +
        '<span class="ap-daylbl">' + (rel ? rel + ", " : "") + DOWF[dObj.getDay()] + " " + dObj.getDate() + '</span></div>' +
      '<div class="ax-week" id="apWeek">' + week + '</div>' +
      '<div class="ap-secrow"><span class="h">' + (rel || AX.fmtDayShort(day)) + '</span><span class="ap-daysum">' +
        dayList.length + (dayList.length === 1 ? " appointment" : " appointments") + '</span></div>' +
      timeline +
      '<div class="ap-callegend" style="margin-top:14px"><span class="li"><span class="dot" style="background:var(--accent)"></span>Confirmed</span>' +
        '<span class="li"><span class="dot" style="background:#9A6B05"></span>Pending</span>' +
        '<span class="li"><span class="dot" style="background:var(--ink-4)"></span>Completed</span>' +
        '<span class="li"><span class="dot" style="background:#C23A18"></span>Cancelled</span></div>';

    $("#apToday", host).addEventListener("click", function () { AX.state.day = TODAY_ISO; render(); });
    $("#apPrev", host).addEventListener("click", function () { AX.state.day = iso(addDays(fromISO(AX.state.day), -1)); render(); });
    $("#apNext", host).addEventListener("click", function () { AX.state.day = iso(addDays(fromISO(AX.state.day), 1)); render(); });
    $$(".ax-wday", host).forEach(function (b) { b.addEventListener("click", function () { AX.state.day = b.getAttribute("data-d"); render(); }); });
    $$(".ap-tlcard", host).forEach(function (el) { el.addEventListener("click", function () { AX.openDetail(el.getAttribute("data-id")); }); });
  };

  AX.statusDot = function (s) { return s === "confirmed" ? "var(--accent)" : s === "pending" ? "#9A6B05" : s === "completed" ? "var(--ink-4)" : "#C23A18"; };
  AX.bookingCard = function (a) {
    var dep = AX.deptById(a.department), u = AX.userById(a.user) || { name: "" };
    var tm = AX.fmtTime(a.time), end = AX.fmtTime(a.time + a.dur);
    var pillCls = a.status === "completed" ? "completed" : a.status === "cancelled" ? "cancelled" : a.status === "pending" ? "pending" : "confirmed";
    var pillTxt = a.status.charAt(0).toUpperCase() + a.status.slice(1);
    return '<div class="ap-tlcard tk-card" data-id="' + a.id + '" style="margin-bottom:0;border-left:3px solid ' + AX.statusDot(a.status) + '">' +
      '<div class="tk-top"><span class="tk-left" style="gap:7px"><span class="tk-cat" style="border-color:' + dep.color + '33;color:' + dep.color + ';background:' + dep.color + '12">' + esc(dep.name) + '</span></span>' +
        '<span class="appt-pill ' + pillCls + '">' + pillTxt + '</span></div>' +
      '<div class="tk-subj-row"><div style="flex:1;min-width:0"><div class="tk-subj">' + esc(a.name) + '</div>' +
        '<div class="tk-snip">' + tm.full + ' \u2013 ' + end.full + ' \u00b7 ' + esc(u.name) + '</div></div>' +
        '<span class="chev">' + I.chevR + '</span></div>' +
      (a.amount ? '<div class="tk-foot"><span class="tk-cust" style="font-weight:700;color:var(--ink-2)">' + AX.inr(a.amount) + ' \u00b7 ' + (a.paymentType === "prepaid" ? "Prepaid" : "Postpaid") + '</span>' +
        '<span class="appt-pill ' + AX.payCls(a.payStatus) + '">' + AX.payLabel(a.payStatus) + '</span></div>' : '') +
    '</div>';
  };

  /* ============================================================
     STATIC WIRING
     ============================================================ */
  function wire() {
    $$("#axTabs button").forEach(function (b) { b.addEventListener("click", function () { AX.setTab(b.getAttribute("data-tab")); }); });
    $("#axPill").addEventListener("click", function () { if (AX.state.tab === "dashboard") AX.openAgentFilter(); });
    $("#axFab").addEventListener("click", function () { AX.openForm(); });
    AX.setTab("dashboard");
  }
  // defer so companion file can register its renderers first
  setTimeout(wire, 0);

  return AX;
})();
