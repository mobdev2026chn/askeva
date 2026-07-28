/* =========================================================
   AskEva — Appointment DASHBOARD (full rebuild)
   Faithful mobile translation of the web "Appointment
   Dashboard": 6 stat tiles · Appointment Trend by Agent
   (Today / 7 Days / Last Month) · Success/Avg/Completed
   KPIs · Appointment Calendar · Monthly Appointment Trends
   · Appointment Status donut · Agent Performance.
   Overrides AX.renderDashboard from appointments.js.
   Loaded AFTER appointments-detail.js, BEFORE wire().
   ========================================================= */
(function (AX) {
  "use strict";
  if (!AX || !AX.pane) return;
  var $ = AX.$, $$ = AX.$$, I = AX.I, esc = AX.esc;
  var iso = AX.iso, fromISO = AX.fromISO, addDays = AX.addDays, pad = AX.pad;
  var TODAY = AX.TODAY, TODAY_ISO = AX.TODAY_ISO, MON = AX.MON, MONF = AX.MONF, DOW = AX.DOW;

  /* ---- one-time migration: tag a few appts as rescheduled so the
          status donut + monthly trends have a 3rd dimension ---- */
  if (!AX.appts.some(function (a) { return a.rescheduled; })) {
    ["p5", "p8", "a3"].forEach(function (id) { var a = AX.getAppt(id); if (a) a.rescheduled = true; });
    AX.save();
  }

  /* dashboard sub-state lives on AX.state so it survives re-renders */
  if (!AX.state.trendRange) AX.state.trendRange = "7d";          // today | 7d | month
  if (!AX.state.dashMonth)  AX.state.dashMonth  = new Date(TODAY.getFullYear(), TODAY.getMonth(), 1);

  var chartSeq = 0;

  /* ---------- extra icons ---------- */
  var GR = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 19V5M4 19h16M8 16l3-4 3 2 4-6"/></svg>';
  var DONUT = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3a9 9 0 1 0 9 9h-9V3Z"/></svg>';

  /* =========================================================
     scope (honours the All-Agents header pill)
     ========================================================= */
  function scope() {
    var a = AX.appts;
    if (AX.state.agent !== "all") a = a.filter(function (x) { return x.user === AX.state.agent; });
    return a;
  }

  /* =========================================================
     SVG helpers
     ========================================================= */
  function linePath(pts) {
    if (!pts.length) return "";
    if (pts.length < 2) return "M" + pts[0].x + " " + pts[0].y;
    var d = "M" + r1(pts[0].x) + " " + r1(pts[0].y);
    for (var i = 0; i < pts.length - 1; i++) {
      var p0 = pts[i - 1] || pts[i], p1 = pts[i], p2 = pts[i + 1], p3 = pts[i + 2] || p2;
      var c1x = p1.x + (p2.x - p0.x) / 6, c1y = p1.y + (p2.y - p0.y) / 6;
      var c2x = p2.x - (p3.x - p1.x) / 6, c2y = p2.y - (p3.y - p1.y) / 6;
      d += " C" + r1(c1x) + " " + r1(c1y) + " " + r1(c2x) + " " + r1(c2y) + " " + r1(p2.x) + " " + r1(p2.y);
    }
    return d;
  }
  function r1(n) { return Math.round(n * 10) / 10; }
  function niceMax(m) { m = Math.max(m, 1); return m <= 5 ? m : Math.ceil(m / 5) * 5; }

  /* single-series area chart -------------------------------------------- */
  function areaChart(labels, values, accent) {
    var W = 326, H = 168, padL = 22, padR = 8, padT = 10, padB = 26;
    var plotW = W - padL - padR, plotH = H - padT - padB, n = values.length;
    var max = niceMax(Math.max.apply(null, values));
    var X = function (i) { return padL + (n <= 1 ? plotW / 2 : plotW * i / (n - 1)); };
    var Y = function (v) { return padT + plotH * (1 - v / max); };
    var pts = values.map(function (v, i) { return { x: X(i), y: Y(v) }; });
    var lp = linePath(pts);
    var base = padT + plotH;
    var area = lp + " L" + r1(X(n - 1)) + " " + base + " L" + r1(X(0)) + " " + base + " Z";

    var step = max <= 5 ? 1 : max / 5, ticks = [];
    for (var t = 0; t <= max + 0.001; t += step) ticks.push(Math.round(t));
    var grid = ticks.map(function (tv) {
      var yy = Y(tv);
      return '<line x1="' + padL + '" y1="' + r1(yy) + '" x2="' + (W - padR) + '" y2="' + r1(yy) + '" class="axc-grid"/>' +
        '<text x="' + (padL - 5) + '" y="' + r1(yy + 3) + '" class="axc-ylab">' + tv + "</text>";
    }).join("");

    var lstep = n <= 8 ? 1 : Math.ceil(n / 7);
    var xl = labels.map(function (l, i) {
      if (i % lstep !== 0 && i !== n - 1) return "";
      return '<text x="' + r1(X(i)) + '" y="' + (H - 8) + '" class="axc-xlab">' + esc(l) + "</text>";
    }).join("");

    var gid = "axarea" + (chartSeq++);
    var dots = "";
    if (n <= 8) dots = pts.map(function (p, i) {
      return values[i] ? '<circle cx="' + r1(p.x) + '" cy="' + r1(p.y) + '" r="3" fill="#fff" stroke="' + accent + '" stroke-width="2"/>' : "";
    }).join("");

    return '<svg class="axc" viewBox="0 0 ' + W + " " + H + '" preserveAspectRatio="none" role="img">' +
      '<defs><linearGradient id="' + gid + '" x1="0" y1="0" x2="0" y2="1">' +
      '<stop offset="0" stop-color="' + accent + '" stop-opacity="0.30"/>' +
      '<stop offset="1" stop-color="' + accent + '" stop-opacity="0.02"/></linearGradient></defs>' +
      grid +
      '<path d="' + area + '" fill="url(#' + gid + ')"/>' +
      '<path d="' + lp + '" fill="none" stroke="' + accent + '" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/>' +
      dots + xl + "</svg>";
  }

  /* multi-line chart ---------------------------------------------------- */
  function lineChart(labels, seriesList) {
    var W = 326, H = 178, padL = 20, padR = 8, padT = 10, padB = 26;
    var plotW = W - padL - padR, plotH = H - padT - padB, n = labels.length;
    var allMax = 1;
    seriesList.forEach(function (s) { s.values.forEach(function (v) { if (v > allMax) allMax = v; }); });
    var max = niceMax(allMax);
    var X = function (i) { return padL + (n <= 1 ? plotW / 2 : plotW * i / (n - 1)); };
    var Y = function (v) { return padT + plotH * (1 - v / max); };

    var step = max <= 5 ? 1 : max / 5, ticks = [];
    for (var t = 0; t <= max + 0.001; t += step) ticks.push(Math.round(t));
    var grid = ticks.map(function (tv) {
      var yy = Y(tv);
      return '<line x1="' + padL + '" y1="' + r1(yy) + '" x2="' + (W - padR) + '" y2="' + r1(yy) + '" class="axc-grid"/>' +
        '<text x="' + (padL - 4) + '" y="' + r1(yy + 3) + '" class="axc-ylab">' + tv + "</text>";
    }).join("");

    var lstep = Math.ceil(n / 12);
    var xl = labels.map(function (l, i) {
      if (i % lstep !== 0 && i !== n - 1 && n > 12) return "";
      return '<text x="' + r1(X(i)) + '" y="' + (H - 8) + '" class="axc-xlab">' + esc(l) + "</text>";
    }).join("");

    var lines = seriesList.map(function (s) {
      var pts = s.values.map(function (v, i) { return { x: X(i), y: Y(v) }; });
      return '<path d="' + linePath(pts) + '" fill="none" stroke="' + s.color + '" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/>';
    }).join("");

    return '<svg class="axc" viewBox="0 0 ' + W + " " + H + '" preserveAspectRatio="none" role="img">' +
      grid + lines + xl + "</svg>";
  }

  /* donut --------------------------------------------------------------- */
  function donut(segs, total) {
    var R = 54, C = 2 * Math.PI * R, sw = 18, cx = 70, cy = 70, start = 0;
    var rings = segs.map(function (s) {
      var frac = total ? s.value / total : 0, len = frac * C;
      var ring = '<circle cx="' + cx + '" cy="' + cy + '" r="' + R + '" fill="none" stroke="' + s.color +
        '" stroke-width="' + sw + '" stroke-linecap="butt" stroke-dasharray="' + r1(len) + " " + r1(C - len) +
        '" stroke-dashoffset="' + r1(-start * C) + '"/>';
      start += frac;
      return ring;
    }).join("");
    return '<svg viewBox="0 0 140 140" class="ap-donut">' +
      '<circle cx="' + cx + '" cy="' + cy + '" r="' + R + '" fill="none" stroke="var(--surface-3)" stroke-width="' + sw + '"/>' +
      '<g transform="rotate(-90 ' + cx + " " + cy + ')">' + rings + "</g>" +
      '<text x="70" y="64" class="ap-donut-cap">Total</text>' +
      '<text x="70" y="88" class="ap-donut-num">' + total + "</text></svg>";
  }

  /* =========================================================
     TREND data builders
     ========================================================= */
  function trendData(a, range) {
    var labels = [], values = [], sub = "";
    if (range === "today") {
      sub = "Today, hourly";
      for (var h = 9; h <= 18; h++) {
        labels.push(((h % 12) || 12) + (h < 12 ? "a" : "p"));
        values.push(a.filter(function (x) {
          return x.date === TODAY_ISO && x.status !== "cancelled" && Math.floor(x.time / 60) === h;
        }).length);
      }
    } else if (range === "month") {
      sub = "Last 30 days report";
      for (var i = 29; i >= 0; i--) {
        var di = iso(addDays(TODAY, -i)), d = fromISO(di);
        labels.push(d.getDate() + " " + MON[d.getMonth()]);
        values.push(a.filter(function (x) { return x.date === di && x.status !== "cancelled"; }).length);
      }
    } else {
      sub = "Last 7 days report";
      for (var j = 6; j >= 0; j--) {
        var dj = iso(addDays(TODAY, -j)), dd = fromISO(dj);
        labels.push(dd.getDate() + " " + MON[dd.getMonth()]);
        values.push(a.filter(function (x) { return x.date === dj && x.status !== "cancelled"; }).length);
      }
    }
    return { labels: labels, values: values, sub: sub };
  }

  function trendCardHTML(a) {
    var range = AX.state.trendRange;
    var td = trendData(a, range);
    var any = td.values.some(function (v) { return v > 0; });
    var seg = [["today", "Today"], ["7d", "7 Days"], ["month", "Last Month"]].map(function (o) {
      return '<button class="ap-segb' + (range === o[0] ? " on" : "") + '" data-range="' + o[0] + '">' + o[1] + "</button>";
    }).join("");
    return '<div class="ap-card" id="apTrendCard">' +
      '<div class="ch-hd"><div><div class="ch-ttl">' + GR + 'Appointment Trend by Agent</div>' +
      '<div class="ch-sub">' + td.sub + '</div></div><span class="ch-menu">' + I.dots + '</span></div>' +
      '<div class="ap-segmini">' + seg + "</div>" +
      (any ? '<div class="ap-chartbox">' + areaChart(td.labels, td.values, "#2BA84A") + "</div>"
           : '<div class="ap-chart-empty">No appointment data for this range</div>') +
      "</div>";
  }

  function wireTrend(host) {
    $$("#apTrendCard .ap-segb", host).forEach(function (b) {
      b.addEventListener("click", function () {
        AX.state.trendRange = b.getAttribute("data-range");
        var card = $("#apTrendCard", host);
        var fresh = document.createElement("div");
        fresh.innerHTML = trendCardHTML(scope());
        card.replaceWith(fresh.firstChild);
        wireTrend(host);
      });
    });
  }

  /* =========================================================
     CALENDAR (inline mini-month)
     ========================================================= */
  function calCardHTML(a) {
    var view = AX.state.dashMonth, y = view.getFullYear(), mo = view.getMonth();
    var first = new Date(y, mo, 1).getDay(), dim = new Date(y, mo + 1, 0).getDate(), prevDim = new Date(y, mo, 0).getDate();
    var cells = "";
    for (var i = 0; i < first; i++) cells += '<div class="ap-mcell out">' + (prevDim - first + 1 + i) + "</div>";
    for (var dd = 1; dd <= dim; dd++) {
      var di = y + "-" + pad(mo + 1) + "-" + pad(dd);
      var n = a.filter(function (x) { return x.date === di && x.status !== "cancelled"; }).length;
      var isToday = di === TODAY_ISO;
      cells += '<button class="ap-mcell' + (isToday ? " today" : "") + (n ? " has" : "") + '" data-d="' + di + '">' +
        '<span class="dn">' + dd + "</span>" + (n ? '<span class="apt">' + n + " Apt</span>" : "") + "</button>";
    }
    var trail = (first + dim) % 7; if (trail) for (var k = 1; k <= 7 - trail; k++) cells += '<div class="ap-mcell out">' + k + "</div>";
    return '<div class="ap-card" id="apCalCard"><div class="ch-hd">' +
      '<div class="ch-ttl">' + I.cal + 'Appointment Calendar</div>' +
      '<div class="ap-calnav2"><button class="nb" data-mv="-1">' + I.chevL + '</button>' +
      '<span class="m">' + MONF[mo] + " " + y + '</span><button class="nb" data-mv="1">' + I.chevR + "</button></div></div>" +
      '<div class="ap-mdow">' + DOW.map(function (x) { return "<span>" + x.toUpperCase() + "</span>"; }).join("") + "</div>" +
      '<div class="ap-mgrid">' + cells + "</div></div>";
  }
  function wireCal(host) {
    $$("#apCalCard .nb", host).forEach(function (b) {
      b.addEventListener("click", function () {
        var mv = +b.getAttribute("data-mv");
        AX.state.dashMonth = new Date(AX.state.dashMonth.getFullYear(), AX.state.dashMonth.getMonth() + mv, 1);
        var card = $("#apCalCard", host), fresh = document.createElement("div");
        fresh.innerHTML = calCardHTML(scope());
        card.replaceWith(fresh.firstChild); wireCal(host);
      });
    });
    $$("#apCalCard .ap-mcell[data-d]", host).forEach(function (b) {
      b.addEventListener("click", function () { AX.state.day = b.getAttribute("data-d"); AX.setTab("bookings"); });
    });
  }

  /* =========================================================
     MONTHLY TRENDS (illustrative yearly distribution)
     scaled by how many of each kind exist in the live data
     ========================================================= */
  function monthlyCardHTML(a) {
    var completed = a.filter(function (x) { return x.status === "completed"; }).length;
    var resched = a.filter(function (x) { return x.rescheduled; }).length;
    var current = a.filter(function (x) { return x.status === "confirmed" || x.status === "pending"; }).length;
    // seasonal shape (peaks late-spring) — normalised weights summing ~1
    var shape = [0, 0, 0.04, 0.20, 0.40, 0.22, 0.08, 0.03, 0.01, 0.01, 0.005, 0.005];
    function series(total, peak) {
      return shape.map(function (w, i) { return Math.round(w * total * peak * 10) / 10; });
    }
    var s = [
      { name: "Current", color: "#2BA84A", values: series(current, 1.0) },
      { name: "Rescheduled", color: "#F5A623", values: series(resched, 1.25) },
      { name: "Completed", color: "#85D653", values: series(completed, 1.0) }
    ];
    var legend = '<div class="ap-legend">' + s.map(function (x) {
      return '<span class="li"><span class="dotc" style="background:' + x.color + '"></span>' + x.name + "</span>";
    }).join("") + "</div>";
    return '<div class="ap-card"><div class="ch-hd"><div class="ch-ttl">' + GR + 'Monthly Appointment Trends</div></div>' +
      '<div class="ap-chartbox">' + lineChart(MON, s) + "</div>" + legend + "</div>";
  }

  /* =========================================================
     STATUS DONUT
     ========================================================= */
  function statusCardHTML(a) {
    var completed = a.filter(function (x) { return x.status === "completed"; }).length;
    var resched = a.filter(function (x) { return x.rescheduled; }).length;
    var current = a.filter(function (x) { return (x.status === "confirmed" || x.status === "pending") && !x.rescheduled; }).length;
    var total = current + completed + resched;
    var pct = function (v) { return total ? Math.round((v / total) * 1000) / 10 : 0; };
    var segs = [
      { color: "#2BA84A", value: current },
      { color: "#85D653", value: completed },
      { color: "#F5A623", value: resched }
    ];
    return '<div class="ap-card"><div class="ch-hd"><div class="ch-ttl">' + AX.I.users + 'Appointment Status</div></div>' +
      '<div class="ap-statuswrap">' +
        '<div class="ap-donutcol">' + donut(segs, total) +
          '<div class="ap-dlegend">' +
            '<span class="li"><span class="dotc" style="background:#2BA84A"></span>Current</span>' +
            '<span class="li"><span class="dotc" style="background:#85D653"></span>Completed</span>' +
            '<span class="li"><span class="dotc" style="background:#F5A623"></span>Rescheduled</span>' +
          '</div></div>' +
        '<div class="ap-statbreak">' +
          breakRow("Current Appointments", current, pct(current) + "% of total", "info", I.clock) +
          breakRow("Completed Appointments", completed, pct(completed) + "% success rate", "ok", AX.I.trend) +
          breakRow("Rescheduled Appointments", resched, pct(resched) + "% of total", "warn", I.repeat) +
        '</div></div></div>';
  }
  function breakRow(label, num, sub, tone, ic) {
    return '<div class="ap-brk"><div class="k">' + esc(label) + '</div><div class="v">' + num + "</div>" +
      '<div class="s ' + tone + '">' + ic + esc(sub) + "</div></div>";
  }

  /* =========================================================
     AGENT PERFORMANCE
     ========================================================= */
  function agentCardHTML() {
    var rows = AX.USERS.map(function (u) {
      var list = AX.appts.filter(function (x) { return x.user === u.id; });
      if (!list.length) return null;
      var appts = list.length;
      var completed = list.filter(function (x) { return x.status === "completed"; }).length;
      var revenue = list.filter(function (x) { return x.status !== "cancelled"; }).reduce(function (s, x) { return s + (x.amount || 0); }, 0);
      var earned = list.filter(function (x) { return x.payStatus === "paid"; }).reduce(function (s, x) { return s + (x.amount || 0); }, 0);
      return { u: u, appts: appts, completed: completed, revenue: revenue, earned: earned };
    }).filter(Boolean).sort(function (a, b) { return b.appts - a.appts; });

    var body = rows.map(function (r) {
      return '<div class="ap-agrow"><div class="who"><span class="av" style="background:' + r.u.color + '">' +
        esc(r.u.initials) + '</span><div class="nm">' + esc(r.u.name) + '<span class="role">' + esc(r.u.role) + "</span></div></div>" +
        '<div class="mtx"><span class="m"><b>' + r.appts + '</b>Appts</span>' +
          '<span class="m"><b class="g">' + r.completed + '</b>Done</span>' +
          '<span class="m"><b>' + AX.inr(r.revenue) + '</b>Revenue</span>' +
          '<span class="m"><b class="g">' + AX.inr(r.earned) + '</b>Earned</span></div></div>';
    }).join("");
    return '<div class="ap-card"><div class="ch-hd"><div class="ch-ttl">' + AX.I.users + 'Agent Performance</div></div>' +
      '<div class="ap-agents">' + (body || '<div class="ap-chart-empty">No agent activity yet</div>') + "</div></div>";
  }

  /* =========================================================
     STAT TILE
     ========================================================= */
  function stat(ic, cls, num, lbl, sub, wide) {
    return '<div class="ap-stat' + (wide ? " wide" : "") + '"><div class="ic ' + cls + '">' + ic + "</div>" +
      '<div class="meta"><div class="num">' + num + '</div><div class="lbl">' + lbl + "</div>" +
      (sub ? '<div class="ap-stat-sub">' + sub + "</div>" : "") + "</div></div>";
  }

  /* =========================================================
     MAIN RENDER (override)
     ========================================================= */
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
    var successRate = total ? Math.round((completed / total) * 1000) / 10 : 0;
    var avgRev = completed ? Math.round(compRev / completed) : 0;

    // status breakdown (was the donut) — now folded into the stat cards
    var resched = a.filter(function (x) { return x.rescheduled; }).length;
    var current = a.filter(function (x) { return (x.status === "confirmed" || x.status === "pending") && !x.rescheduled; }).length;
    var statusTotal = current + completed + resched;
    var spct = function (v) { return statusTotal ? Math.round((v / statusTotal) * 1000) / 10 : 0; };

    host.innerHTML =
      '<div class="ap-statgrid six">' +
        stat(I.cal, "today", todayCount, "Today's Appointments") +
        stat(I.users, "blue", total, "Total Appointments") +
        stat(I.clock, "amber", pending, "Pending", spct(current) + "% of total") +
        stat(I.check2, "", completed, "Completed", spct(completed) + "% success rate") +
        stat(I.repeat, "amber", resched, "Rescheduled", spct(resched) + "% of total") +
        stat(I.trend, "", AX.inr(earned), "Earned Revenue") +
        stat(I.trend, "blue", AX.inr(totalRev), "Total Revenue", "", true) +
      '</div>' +
      '<div class="ap-kpis">' +
        '<div class="ap-kpi"><div class="v">' + successRate + '%</div><div class="l">Success Rate</div><div class="track"><i style="width:' + successRate + '%"></i></div></div>' +
        '<div class="ap-kpi"><div class="v">' + AX.inr(avgRev) + '</div><div class="l">Avg Revenue</div></div>' +
        '<div class="ap-kpi"><div class="v">' + AX.inr(compRev) + '</div><div class="l">Completed Rev.</div></div>' +
      '</div>' +
      (AX.state.agent !== "all" ? trendCardHTML(a) : "") +
      (AX.state.agent === "all" ? agentCardHTML() : "");

    wireTrend(host);
  };

  /* guarantee the override paints even if wire() ran its first render
     before this file executed (script load-order race) */
  setTimeout(function () {
    if (AX.state.tab === "dashboard") {
      var h = document.getElementById("axView");
      if (h && !h.querySelector(".ap-statgrid.six")) AX.renderDashboard(h);
    }
  }, 0);

})(window.AX);
