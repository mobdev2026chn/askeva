/* =========================================================
   AskEva — Appointment BOOKINGS (full rebuild)
   Mobile translation of the web "Appointment Bookings":
     · view toggle  →  Calendar View  /  Appointments
     · Calendar View : month grid + legend + Total/Closed/
       Current tiles + day schedule ("Appointments for …")
     · Appointments  : search + week strip + status sub-tabs
       (Current / Rescheduled / Completed / Feedbacks) + list
   Overrides AX.renderBookings from appointments.js.
   ========================================================= */
(function (AX) {
  "use strict";
  if (!AX || !AX.pane) return;
  var $ = AX.$, $$ = AX.$$, I = AX.I, esc = AX.esc;
  var iso = AX.iso, fromISO = AX.fromISO, addDays = AX.addDays, pad = AX.pad;
  var TODAY = AX.TODAY, TODAY_ISO = AX.TODAY_ISO, MON = AX.MON, MONF = AX.MONF, DOW = AX.DOW, DOWF = AX.DOWF;

  /* one-time: give completed appts a feedback rating so the
     Feedbacks tab has content */
  if (!AX.appts.some(function (a) { return a.rating; })) {
    var fb = {
      p1: { rating: 5, note: "Very helpful, cleared all my doubts." },
      p2: { rating: 4, note: "Good demo, slightly rushed at the end." },
      p3: { rating: 5, note: "Detailed diagnostics, very thorough." },
      p4: { rating: 4, note: "Quick and on time." },
      p6: { rating: 5, note: "Great consultation." },
      p7: { rating: 3, note: "Onboarding was okay, needed more depth." }
    };
    AX.appts.forEach(function (a) { if (fb[a.id]) { a.rating = fb[a.id].rating; a.feedback = fb[a.id].note; } });
    AX.save();
  }

  if (!AX.state.bookView) AX.state.bookView = "calendar";  // calendar | list
  if (!AX.state.bookTab)  AX.state.bookTab  = "current";   // current | resched | completed | feedback
  if (AX.state.stripOpen == null) AX.state.stripOpen = true; // calendar (week strip) visibility — toggle hides it
  if (!AX.state.bookMonth) AX.state.bookMonth = new Date(fromISO(AX.state.day).getFullYear(), fromISO(AX.state.day).getMonth(), 1);
  if (AX.state.bookQ == null) AX.state.bookQ = "";

  var icSearch = I.search, icFilter = I.filter, icStar = '<svg viewBox="0 0 24 24" fill="currentColor"><path d="m12 3 2.7 5.4 6 .9-4.3 4.2 1 6L12 16.9 6.6 19.5l1-6L3.3 9.3l6-.9z"/></svg>';
  var icX = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M18 6 6 18M6 6l12 12"/></svg>';
  var icInbox = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="M3 13h4l2 3h6l2-3h4"/><path d="M5 19h14a2 2 0 0 0 2-2V8.5a2 2 0 0 0-.3-1L17 2H7L3.3 7.5a2 2 0 0 0-.3 1V17a2 2 0 0 0 2 2Z"/></svg>';

  function dayAppts(di) { return AX.appts.filter(function (x) { return x.date === di; }).sort(function (a, b) { return a.time - b.time; }); }
  function liveCount(di) { return AX.appts.filter(function (x) { return x.date === di && x.status !== "cancelled"; }).length; }

  /* compact day-schedule card — name + consultancy + status only.
     Tapping opens the detail sheet which carries the full info. */
  function compactCard(a) {
    var dep = AX.deptById(a.department);
    var st = a.status, pillCls = st === "completed" ? "completed" : st === "cancelled" ? "cancelled" : st === "pending" ? "pending" : "confirmed";
    var pillTxt = st.charAt(0).toUpperCase() + st.slice(1);
    return '<div class="ap-tlcard ap-mini" data-id="' + a.id + '" style="border-left:3px solid ' + AX.statusDot(st) + '">' +
      '<div class="ap-mini-main">' +
        '<div class="ap-mini-nm">' + esc(a.name) + '</div>' +
        '<div class="ap-mini-dep" style="color:' + dep.color + '">' + esc(dep.name) + '</div>' +
      '</div>' +
      '<span class="appt-pill ' + pillCls + '">' + pillTxt + '</span>' +
      '<span class="chev">' + I.chevR + '</span>' +
    '</div>';
  }

  /* =========================================================
     VIEW TOGGLE
     ========================================================= */
  function viewToggle() {
    return '<div class="ap-viewtog">' +
      '<button class="vt' + (AX.state.bookView === "calendar" ? " on" : "") + '" data-v="calendar">' + I.cal + 'Calendar View</button>' +
      '<button class="vt' + (AX.state.bookView === "list" ? " on" : "") + '" data-v="list">' + I.note + 'Appointments</button>' +
      '</div>';
  }

  /* =========================================================
     MONTH CALENDAR (selectable, with appointment dots)
     ========================================================= */
  function monthGrid() {
    var view = AX.state.bookMonth, y = view.getFullYear(), mo = view.getMonth();
    var first = new Date(y, mo, 1).getDay(), dim = new Date(y, mo + 1, 0).getDate(), prevDim = new Date(y, mo, 0).getDate();
    var sel = AX.state.day, cells = "";
    for (var i = 0; i < first; i++) cells += '<div class="ap-mcell out">' + (prevDim - first + 1 + i) + "</div>";
    for (var dd = 1; dd <= dim; dd++) {
      var di = y + "-" + pad(mo + 1) + "-" + pad(dd);
      var n = liveCount(di), isToday = di === TODAY_ISO, isSel = di === sel;
      cells += '<button class="ap-mcell' + (isToday ? " today" : "") + (isSel ? " sel" : "") + (n ? " has" : "") + '" data-d="' + di + '">' +
        '<span class="dn">' + dd + "</span>" + (n ? '<span class="dots">' + (n > 3 ? "•••" : Array(n + 1).join("•")) + "</span>" : "") + "</button>";
    }
    var trail = (first + dim) % 7; if (trail) for (var k = 1; k <= 7 - trail; k++) cells += '<div class="ap-mcell out">' + k + "</div>";
    return '<div class="ap-card" id="apBookCal"><div class="ch-hd"><div class="ap-calnav2"><button class="nb" data-mv="-1">' + I.chevL + "</button>" +
      '<span class="m">' + MONF[mo] + " " + y + '</span><button class="nb" data-mv="1">' + I.chevR + "</button></div></div>" +
      '<div class="ap-mdow">' + DOW.map(function (x) { return "<span>" + x.charAt(0) + "</span>"; }).join("") + "</div>" +
      '<div class="ap-mgrid">' + cells + "</div>" +
      '<div class="ap-calleg2"><span class="t">Calendar Legend</span>' +
        '<span class="li"><span class="dot sel"></span>Selected date</span>' +
        '<span class="li"><span class="dot has">•</span>Has appointments</span></div>' +
      "</div>";
  }

  /* =========================================================
     CALENDAR VIEW
     ========================================================= */
  function calendarView(host) {
    var day = AX.state.day, list = dayAppts(day);
    var total = list.filter(function (x) { return x.status !== "cancelled"; }).length;
    var closed = list.filter(function (x) { return x.status === "completed"; }).length;
    var current = list.filter(function (x) { return x.status === "confirmed" || x.status === "pending"; }).length;
    var rel = AX.relWord(day), dObj = fromISO(day);
    var dayTitle = (rel ? rel + ", " : "") + DOWF[dObj.getDay()] + " " + dObj.getDate() + " " + MON[dObj.getMonth()];

    var schedule;
    if (!list.length) {
      schedule = '<div class="ax-empty"><div class="ic">' + I.cal + '</div><div class="t">No appointments</div>' +
        '<div class="s">Nothing booked for this day.</div></div>';
    } else {
      schedule = '<div class="ap-daytl">' + list.map(function (a) {
        var tm = AX.fmtTime(a.time);
        return '<div class="ap-hour has"><div class="t">' + tm.hh + "<br>" + tm.ap + '</div><div class="lane">' + compactCard(a) + "</div></div>";
      }).join("") + "</div>";
    }

    host.innerHTML =
      viewToggle() +
      monthGrid() +
      '<div class="ap-counttiles">' +
        '<div class="ct blue"><div class="v">' + total + '</div><div class="l">Total</div></div>' +
        '<div class="ct green"><div class="v">' + closed + '</div><div class="l">Closed</div></div>' +
        '<div class="ct amber"><div class="v">' + current + '</div><div class="l">Current</div></div>' +
      '</div>' +
      '<div class="ap-card" style="padding:16px"><div class="ch-hd" style="margin-bottom:14px"><div class="ch-ttl">' + I.clock + 'Appointments for ' + esc(dayTitle) + '</div></div>' +
        schedule + "</div>";

    wireToggle(host); wireMonth(host);
    $$(".ap-tlcard", host).forEach(function (el) { el.addEventListener("click", function () { AX.openDetail(el.getAttribute("data-id")); }); });
  }

  /* =========================================================
     APPOINTMENTS (LIST) VIEW
     ========================================================= */
  var TABS = [["current", "Current"], ["resched", "Rescheduled"], ["completed", "Completed"], ["feedback", "Feedbacks"]];
  /* When the calendar (week strip) is OFF, an extra "Upcoming" tab appears that
     lists every future appointment (from tomorrow onward, across all days). */
  function tabsList() { return AX.state.stripOpen ? TABS : [TABS[0], TABS[1], ["upcoming", "Upcoming"], TABS[2], TABS[3]]; }
  function upcomingBase() {
    return AX.appts.filter(function (a) { return a.date > TODAY_ISO && a.status !== "cancelled"; })
      .sort(function (a, b) { return a.date < b.date ? -1 : a.date > b.date ? 1 : a.time - b.time; });
  }

  function filterTab(list, tab) {
    if (tab === "current") return list.filter(function (a) { return (a.status === "confirmed" || a.status === "pending") && !a.rescheduled; });
    if (tab === "resched") return list.filter(function (a) { return a.rescheduled; });
    if (tab === "completed") return list.filter(function (a) { return a.status === "completed"; });
    if (tab === "upcoming") return list.filter(function (a) { return a.date > TODAY_ISO && a.status !== "cancelled"; });
    return list.filter(function (a) { return a.rating; }); // feedback
  }

  function listView(host) {
    var day = AX.state.day, sel = fromISO(day), span = 21;
    // horizontal day-chip strip (same as the New/Edit Appointment form), windowed so the
    // selected day is always visible; trailing calendar button opens the full month picker.
    var start = sel < AX.TODAY ? new Date(sel.getFullYear(), sel.getMonth(), sel.getDate()) : new Date(AX.TODAY);
    var diff = Math.round((sel - start) / 86400000);
    if (diff >= span) start = addDays(sel, -(span - 1));
    var week = "";
    for (var i = 0; i < span; i++) {
      var wd = addDays(start, i), wi = iso(wd);
      var isToday = wi === TODAY_ISO;
      var dn = DOW[wd.getDay()].toUpperCase();
      var wcnt = AX.appts.filter(function (a) { return a.date === wi && a.status !== "cancelled"; }).length;
      week += '<button class="ax-wday' + (wi === day ? " on" : "") + (isToday ? " today" : "") + '" data-d="' + wi + '">' +
        (wcnt ? '<span class="ax-wct">' + wcnt + '</span>' : '') +
        '<span class="dn">' + dn + '</span>' +
        '<span class="dd">' + wd.getDate() + '</span>' +
        '<span class="dm">' + MON[wd.getMonth()] + '</span>' +
        (isToday ? '<span class="ax-wtoday" aria-label="Today"></span>' : '') +
        '</button>';
    }
    week += '<button class="ax-wday more" id="apWkMore" aria-label="Pick date">' + I.cal + '</button>';

    var tab = AX.state.bookTab, q = AX.state.bookQ.trim().toLowerCase();
    // the Upcoming tab only exists while the calendar strip is hidden
    if (tab === "upcoming" && AX.state.stripOpen) { tab = AX.state.bookTab = "current"; }
    var tabBase = dayAppts(day);
    var base = tab === "upcoming" ? upcomingBase() : dayAppts(day);
    if (q) base = base.filter(function (a) { return a.name.toLowerCase().indexOf(q) > -1 || (a.mobile || "").indexOf(q) > -1; });
    var rows = tab === "upcoming" ? base.slice() : filterTab(base, tab);
    if (tab !== "upcoming") rows.sort(function (a, b) { return AX.appts.indexOf(a) - AX.appts.indexOf(b); });  // newest-created first (AX.appts is unshift-ordered)

    var body = bodyHTML(rows, tab);

    host.innerHTML =
      viewToggle() +
      '<div class="ap-srow"><div class="ap-search">' + icSearch + '<input id="apSearch" type="text" placeholder="Search name or number" value="' + esc(AX.state.bookQ) + '"></div>' +
        '<button class="ap-caltoggle' + (AX.state.stripOpen ? " on" : "") + '" id="apStripToggle" title="Calendar view" aria-label="Toggle calendar">' + I.cal + '</button>' +
        '<button class="ap-filterbtn" id="apFilter">' + icFilter + 'Filter</button></div>' +
      (AX.state.stripOpen ?
        '<div class="ap-wkrow"><button class="ap-wknav" id="apWkPrev">' + I.chevL + '</button>' +
          '<div class="ax-week" id="apWkStrip" style="flex:1;min-width:0">' + week + '</div>' +
          '<button class="ap-wknav" id="apWkNext">' + I.chevR + '</button></div>' : "") +
      '<div class="ap-ltabs">' + tabsList().map(function (t) {
        var cnt = t[0] === "upcoming" ? upcomingBase().length : filterTab(tabBase, t[0]).length;
        return '<button class="lt' + (tab === t[0] ? " on" : "") + '" data-t="' + t[0] + '">' + t[1] + (cnt ? '<span class="c">' + cnt + "</span>" : "") + "</button>";
      }).join("") + "</div>" +
      '<div class="ap-lwrap">' + body + "</div>";

    wireToggle(host);
    $("#apSearch", host).addEventListener("input", function (e) { AX.state.bookQ = e.target.value; refreshList(host); });
    $("#apStripToggle", host).addEventListener("click", function () { AX.state.stripOpen = !AX.state.stripOpen; render(host); });
    $("#apFilter", host).addEventListener("click", function () { AX.openAgentFilter ? AX.openAgentFilter() : AX.toast("Filter"); });
    var wkPrev = $("#apWkPrev", host); if (wkPrev) wkPrev.addEventListener("click", function () { AX.state.day = iso(addDays(fromISO(AX.state.day), -1)); render(host); });
    var wkNext = $("#apWkNext", host); if (wkNext) wkNext.addEventListener("click", function () { AX.state.day = iso(addDays(fromISO(AX.state.day), 1)); render(host); });
    var wkMore = $("#apWkMore", host); if (wkMore) wkMore.addEventListener("click", function () {
      AX.calendar({ sel: AX.state.day, dots: true, title: "Appointment date", onPick: function (di) { AX.state.day = di; render(host); } }); });
    $$("#apWkStrip .ax-wday[data-d]", host).forEach(function (b) { b.addEventListener("click", function () { AX.state.day = b.getAttribute("data-d"); render(host); }); });
    var strip = $("#apWkStrip", host), selChip = strip && strip.querySelector(".ax-wday.on");
    if (strip && selChip) strip.scrollLeft = Math.max(0, selChip.offsetLeft - 40);
    $$(".ap-ltabs .lt", host).forEach(function (b) { b.addEventListener("click", function () { AX.state.bookTab = b.getAttribute("data-t"); render(host); }); });
    $$(".ap-lrow", host).forEach(function (el) { el.addEventListener("click", function () { AX.openDetail(el.getAttribute("data-id")); }); });
  }

  /* card rows for current/rescheduled/completed; feedback keeps its own cards */
  function bodyHTML(rows, tab) {
    if (!rows.length) return '<div class="ap-nodata"><div class="ic">' + icInbox + '</div><div class="t">No data</div></div>';
    if (tab === "feedback") return rows.map(feedbackRow).join("");
    return rows.map(listRow).join("");
  }

  function refreshList(host) {
    // re-render only rows + tab counts without losing search focus
    var day = AX.state.day, tab = AX.state.bookTab, q = AX.state.bookQ.trim().toLowerCase();
    var base = tab === "upcoming" ? upcomingBase() : dayAppts(day);
    if (q) base = base.filter(function (a) { return a.name.toLowerCase().indexOf(q) > -1 || (a.mobile || "").indexOf(q) > -1; });
    var rows = tab === "upcoming" ? base.slice() : filterTab(base, tab), wrap = $(".ap-lwrap", host);
    if (tab !== "upcoming") rows.sort(function (a, b) { return AX.appts.indexOf(a) - AX.appts.indexOf(b); });  // newest-created first
    if (!wrap) return;
    wrap.innerHTML = bodyHTML(rows, tab);
    $$(".ap-lrow", wrap).forEach(function (el) { el.addEventListener("click", function () { AX.openDetail(el.getAttribute("data-id")); }); });
    $$(".ap-trow", wrap).forEach(function (el) { el.addEventListener("click", function () { AX.openDetail(el.getAttribute("data-id")); }); });
  }

  function listRow(a) {
    var dep = AX.deptById(a.department), u = AX.userById(a.user) || { name: "—", initials: "?", color: "#999" };
    var tm = AX.fmtTime(a.time);
    var st = a.status, pillTxt = st.charAt(0).toUpperCase() + st.slice(1);
    var pillCls = st === "completed" ? "completed" : st === "cancelled" ? "cancelled" : st === "pending" ? "pending" : "confirmed";
    return '<div class="ap-lrow" data-id="' + a.id + '">' +
      '<span class="av" style="background:' + u.color + '">' + esc((a.name || "?").trim().charAt(0).toUpperCase()) + "</span>" +
      '<div class="mid"><div class="r1"><span class="nm">' + esc(a.name) + '</span><span class="appt-pill ' + pillCls + '">' + pillTxt + "</span></div>" +
        '<div class="r2"><span class="dept" style="color:' + dep.color + '">' + esc(dep.name) + '</span><span class="sep">·</span>' + esc(AX.apptCode ? AX.apptCode(a) : a.id.toUpperCase()) + "</div>" +
        '<div class="r3">' + I.clock + AX.fmtDayShort(a.date) + " · " + tm.full + '<span class="sep">·</span>' + esc(u.name) + "</div>" +
        (a.amount ? '<div class="r4">' + AX.inr(a.amount) + ' · ' + (a.paymentType === "prepaid" ? "Prepaid" : "Postpaid") +
          '<span class="paypill ' + (a.payStatus === "paid" ? "paid" : a.payStatus === "pending" ? "pending" : "fail") + '">' + AX.payLabel(a.payStatus) + "</span></div>" : "") +
      "</div><span class=\"chev\">" + I.chevR + "</span></div>";
  }

  function feedbackRow(a) {
    var u = AX.userById(a.user) || { name: "—", initials: "?", color: "#999" };
    var stars = "";
    for (var i = 1; i <= 5; i++) stars += '<span class="st' + (i <= a.rating ? " on" : "") + '">' + icStar + "</span>";
    return '<div class="ap-lrow fb" data-id="' + a.id + '">' +
      '<span class="av" style="background:' + u.color + '">' + esc((a.name || "?").trim().charAt(0).toUpperCase()) + "</span>" +
      '<div class="mid"><div class="r1"><span class="nm">' + esc(a.name) + '</span><span class="stars">' + stars + "</span></div>" +
        '<div class="r3" style="color:var(--ink-4)">' + AX.fmtDayShort(a.date) + " · " + esc(u.name) + "</div>" +
        (a.feedback ? '<div class="fbnote">"' + esc(a.feedback) + '"</div>' : "") +
      "</div></div>";
  }

  /* =========================================================
     wiring helpers
     ========================================================= */
  function wireToggle(host) {
    $$(".ap-viewtog .vt", host).forEach(function (b) {
      b.addEventListener("click", function () { AX.state.bookView = b.getAttribute("data-v"); render(host); });
    });
  }
  function wireMonth(host) {
    $$("#apBookCal .nb", host).forEach(function (b) {
      b.addEventListener("click", function () {
        var mv = +b.getAttribute("data-mv");
        AX.state.bookMonth = new Date(AX.state.bookMonth.getFullYear(), AX.state.bookMonth.getMonth() + mv, 1);
        render(host);
      });
    });
    $$("#apBookCal .ap-mcell[data-d]", host).forEach(function (b) {
      b.addEventListener("click", function () { AX.state.day = b.getAttribute("data-d"); render(host); });
    });
  }

  function render(host) {
    host = host || $("#axView"); if (!host) return;
    if (AX.state.bookView === "calendar") calendarView(host);
    else listView(host);
  }

  AX.renderBookings = function (host) {
    // sync calendar month to the selected day only when (re)entering the tab,
    // so manual month navigation isn't reset on every internal re-render
    var d = fromISO(AX.state.day);
    AX.state.bookMonth = new Date(d.getFullYear(), d.getMonth(), 1);
    render(host);
  };

  setTimeout(function () {
    if (AX.state.tab === "bookings") { var h = $("#axView"); if (h && !h.querySelector(".ap-viewtog")) render(h); }
  }, 0);

})(window.AX);
