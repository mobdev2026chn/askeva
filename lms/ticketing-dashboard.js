/* =========================================================
   AskEva — Ticketing DASHBOARD
   Mobile translation of the web "Ticketing Dashboard":
     · Overview          → 7 stat tiles, date range, Ticket
       Status Distribution by Agent, Performance Metrics,
       Ticket Trends Over Time, Priority Distribution donut,
       Department Breakdown
     · Agent Performance → summary chart, completion rates,
       performance summary table
   Renders into #txDashView. Reads live data from window.TK.
   ========================================================= */
(function () {
  "use strict";
  var TK = window.TK; if (!TK) return;
  var $ = TK.$, $$ = TK.$$, esc = TK.esc;
  var host = document.getElementById("txDashView"); if (!host) return;

  /* fixed "now" anchor — matches the appointments world (early Jun 2026) */
  var NOW = new Date(2026, 5, 5, 12, 0, 0);
  var DAY = 86400000, MIN = 60000;

  /* dashboard status / priority vocab */
  var WST = [
    ["assigned",   "Assigned",                   "#16A34A"],
    ["inprogress", "In Progress",                "#F59E0B"],
    ["awaiting",   "Awaiting Customer Response", "#F87171"],
    ["pending",    "Pending",                    "#EAB308"],
    ["completed",  "Completed",                  "#86EFAC"],
    ["reopened",   "Reopened",                   "#8B5CF6"]
  ];
  var WST_MAP = {}; WST.forEach(function (s) { WST_MAP[s[0]] = { label: s[1], color: s[2] }; });
  var WPRIO = [
    ["critical", "Critical", "#DC2626"],
    ["high",     "High",     "#F87171"],
    ["medium",   "Medium",   "#3B82F6"],
    ["low",      "Low",      "#4ADE80"]
  ];
  var WPRIO_MAP = {}; WPRIO.forEach(function (p) { WPRIO_MAP[p[0]] = { label: p[1], color: p[2] }; });
  var DEPT_OF = { Delivery: "Operations", Billing: "Finance", Catalog: "Catalog", Account: "Accounts", Chatbot: "Automation", Other: "Support" };

  /* explicit dashboard mapping for the seed tickets */
  var SEED_MAP = {
    t1: { wstatus: "inprogress", wpriority: "critical", rating: 0 },
    t2: { wstatus: "awaiting",   wpriority: "medium",   rating: 0 },
    t3: { wstatus: "assigned",   wpriority: "low",      rating: 0 },
    t4: { wstatus: "assigned",   wpriority: "high",     rating: 0 },
    t5: { wstatus: "pending",    wpriority: "high",     rating: 0 },
    t6: { wstatus: "completed",  wpriority: "low",      rating: 5 },
    t7: { wstatus: "completed",  wpriority: "high",     rating: 4 }
  };
  function deriveStatus(t) {
    if (t.status === "resolved") return "completed";
    if (t.status === "pending") return "pending";
    return "assigned";
  }
  function derivePrio(t) { return t.priority === "high" ? "high" : t.priority === "med" ? "medium" : "low"; }

  /* one-time migration: enrich each ticket with dashboard fields */
  function migrate() {
    var changed = false;
    TK.tickets.forEach(function (t) {
      if (!t.wstatus) {
        var m = SEED_MAP[t.id];
        t.wstatus = m ? m.wstatus : deriveStatus(t);
        t.wpriority = m ? m.wpriority : derivePrio(t);
        if (t.rating == null) t.rating = m ? m.rating : (t.wstatus === "completed" ? 4 : 0);
        t.department = DEPT_OF[t.category] || "Support";
        t.createdMs = NOW.getTime() - (t.created || 0) * MIN;
        t.assignedMs = t.assignee && t.assignee !== "unassigned" ? t.createdMs + 30 * MIN : null;
        t.dueMs = t.createdMs + 2 * DAY;
        t.completedMs = t.wstatus === "completed" ? NOW.getTime() - (t.updated || 0) * MIN : null;
        changed = true;
      }
    });
    if (changed) TK.save();
  }

  /* =========================================================
     STATE
     ========================================================= */
  var state = { tab: "overview", range: "all", trendIdx: null, trendKey: "total", agent: "all" };
  var RANGES = [["all", "All time"], ["7d", "Last 7 days"], ["30d", "Last 30 days"], ["month", "This month"]];

  function inRange(t) {
    if (state.range === "all") return true;
    var ms = t.createdMs, lo;
    if (state.range === "7d") lo = NOW.getTime() - 7 * DAY;
    else if (state.range === "30d") lo = NOW.getTime() - 30 * DAY;
    else { var d = new Date(NOW.getFullYear(), NOW.getMonth(), 1); lo = d.getTime(); }
    return ms >= lo;
  }
  function scope() { return TK.tickets.filter(inRange); }

  /* =========================================================
     SVG HELPERS
     ========================================================= */
  function r1(n) { return Math.round(n * 10) / 10; }
  function niceMax(m) { m = Math.max(m, 1); return m <= 5 ? 5 : Math.ceil(m / 5) * 5; }
  function smooth(pts) {
    if (pts.length < 2) return pts.length ? "M" + pts[0].x + " " + pts[0].y : "";
    var d = "M" + r1(pts[0].x) + " " + r1(pts[0].y);
    for (var i = 0; i < pts.length - 1; i++) {
      var p0 = pts[i - 1] || pts[i], p1 = pts[i], p2 = pts[i + 1], p3 = pts[i + 2] || p2;
      d += " C" + r1(p1.x + (p2.x - p0.x) / 6) + " " + r1(p1.y + (p2.y - p0.y) / 6) + " " +
        r1(p2.x - (p3.x - p1.x) / 6) + " " + r1(p2.y - (p3.y - p1.y) / 6) + " " + r1(p2.x) + " " + r1(p2.y);
    }
    return d;
  }

  /* grouped vertical bars */
  function groupBars(cats, series, opts) {
    opts = opts || {};
    var W = 326, H = 196, padL = 24, padR = 8, padT = 16, padB = 34;
    var plotW = W - padL - padR, plotH = H - padT - padB;
    var max = niceMax(Math.max.apply(null, [].concat.apply([], series.map(function (s) { return s.values; }))));
    var groupW = plotW / cats.length, barGap = 5, bw = (groupW - 14 - barGap * (series.length - 1)) / series.length;
    var Y = function (v) { return padT + plotH * (1 - v / max); };
    var grid = "", step = max / 4;
    for (var g = 0; g <= 4; g++) { var yy = padT + plotH * g / 4, val = Math.round(max - step * g);
      grid += '<line x1="' + padL + '" y1="' + r1(yy) + '" x2="' + (W - padR) + '" y2="' + r1(yy) + '" class="txc-grid"/>' +
        '<text x="' + (padL - 5) + '" y="' + r1(yy + 3) + '" class="txc-yl">' + val + '</text>'; }
    var bars = "", labels = "";
    cats.forEach(function (c, ci) {
      var gx = padL + groupW * ci + 7;
      series.forEach(function (s, si) {
        var v = s.values[ci], x = gx + si * (bw + barGap), h = plotH * v / max, y = Y(v);
        bars += '<rect x="' + r1(x) + '" y="' + r1(y) + '" width="' + r1(bw) + '" height="' + r1(Math.max(h, v ? 2 : 0)) + '" rx="3" fill="' + s.color + '"/>';
        if (v) bars += '<text x="' + r1(x + bw / 2) + '" y="' + r1(y - 4) + '" class="txc-vl">' + v + '</text>';
      });
      labels += '<text x="' + r1(gx + (groupW - 14) / 2) + '" y="' + (H - 14) + '" class="txc-xl">' + esc(c) + '</text>';
    });
    return '<svg class="txc" viewBox="0 0 ' + W + ' ' + H + '" preserveAspectRatio="none">' + grid + bars + labels + '</svg>';
  }

  /* interactive single-series bars (ticket trends) */
  function trendBars(cats, values, color) {
    var W = 326, H = 196, padL = 24, padR = 8, padT = 18, padB = 34;
    var plotW = W - padL - padR, plotH = H - padT - padB;
    var max = niceMax(Math.max.apply(null, values.concat([1])));
    var n = cats.length, slot = plotW / n, bw = Math.min(28, slot - 10);
    var Y = function (v) { return padT + plotH * (1 - v / max); };
    var grid = "", step = max / 4;
    for (var g = 0; g <= 4; g++) { var yy = padT + plotH * g / 4, val = Math.round(max - step * g);
      grid += '<line x1="' + padL + '" y1="' + r1(yy) + '" x2="' + (W - padR) + '" y2="' + r1(yy) + '" class="txc-grid"/>' +
        '<text x="' + (padL - 5) + '" y="' + r1(yy + 3) + '" class="txc-yl">' + val + '</text>'; }
    var bars = "", labels = "";
    cats.forEach(function (c, ci) {
      var v = values[ci], cx = padL + slot * ci + slot / 2, x = cx - bw / 2, h = plotH * v / max, y = Y(v);
      bars += '<rect class="txb-hit" x="' + r1(padL + slot * ci) + '" y="' + padT + '" width="' + r1(slot) + '" height="' + plotH + '" data-i="' + ci + '" fill="transparent"/>';
      bars += '<rect class="txb-bar" data-i="' + ci + '" x="' + r1(x) + '" y="' + r1(y) + '" width="' + r1(bw) + '" height="' + r1(Math.max(h, v ? 2 : 0)) + '" rx="4" fill="' + color + '"/>';
      if (v) bars += '<text class="txc-vl txb-vl" data-i="' + ci + '" x="' + r1(cx) + '" y="' + r1(y - 5) + '">' + v + '</text>';
      labels += '<text class="txc-xl" x="' + r1(cx) + '" y="' + (H - 14) + '">' + esc(c) + '</text>';
    });
    return '<svg class="txc txb-svg" viewBox="0 0 ' + W + ' ' + H + '" preserveAspectRatio="none">' + grid + bars + labels + '</svg>';
  }

  /* stacked daily bars — each day's bar is segmented by status (distinct green
     shades) so you can see how many were completed / pending / etc. that day */
  function trendStackBars(cats, stacks, totals) {
    var W = 326, H = 196, padL = 24, padR = 8, padT = 18, padB = 34;
    var plotW = W - padL - padR, plotH = H - padT - padB;
    var max = niceMax(Math.max.apply(null, totals.concat([1])));
    var n = cats.length, slot = plotW / n, bw = Math.min(28, slot - 10);
    var grid = "", step = max / 4;
    for (var g = 0; g <= 4; g++) { var yy = padT + plotH * g / 4, val = Math.round(max - step * g);
      grid += '<line x1="' + padL + '" y1="' + r1(yy) + '" x2="' + (W - padR) + '" y2="' + r1(yy) + '" class="txc-grid"/>' +
        '<text x="' + (padL - 5) + '" y="' + r1(yy + 3) + '" class="txc-yl">' + val + '</text>'; }
    var bars = "", labels = "", defs = "";
    cats.forEach(function (c, ci) {
      var segs = stacks[ci], tot = totals[ci], cx = padL + slot * ci + slot / 2, x = cx - bw / 2;
      bars += '<rect class="txb-hit" x="' + r1(padL + slot * ci) + '" y="' + padT + '" width="' + r1(slot) + '" height="' + plotH + '" data-i="' + ci + '" fill="transparent"/>';
      var drawn = segs.filter(function (s) { return s.v > 0; });
      if (drawn.length) {
        // one continuous bar: rounded-rect clip around the whole stack, segments
        // drawn flush inside it so the green shades themselves divide the bar
        var hTot = plotH * tot / max, yTop0 = padT + plotH - hTot, clipId = "txbclip" + ci;
        defs += '<clipPath id="' + clipId + '"><rect x="' + r1(x) + '" y="' + r1(yTop0) + '" width="' + r1(bw) + '" height="' + r1(Math.max(hTot, 2)) + '" rx="4"/></clipPath>';
        var grp = '<g clip-path="url(#' + clipId + ')">';
        var yCursor = padT + plotH;
        drawn.forEach(function (s) {
          var hSeg = plotH * s.v / max, yTop = yCursor - hSeg;
          grp += '<rect class="txb-seg" data-i="' + ci + '" x="' + r1(x) + '" y="' + r1(yTop) + '" width="' + r1(bw) +
            '" height="' + r1(Math.max(hSeg, 1)) + '" fill="' + s.color + '"/>';
          yCursor = yTop;
        });
        bars += grp + '</g>';
      }
      if (tot) bars += '<text class="txc-vl txb-vl" x="' + r1(cx) + '" y="' + r1(padT + plotH - plotH * tot / max - 5) + '">' + tot + '</text>';
      labels += '<text class="txc-xl" x="' + r1(cx) + '" y="' + (H - 14) + '">' + esc(c) + '</text>';
    });
    return '<svg class="txc txb-svg" viewBox="0 0 ' + W + ' ' + H + '" preserveAspectRatio="none"><defs>' + defs + '</defs>' + grid + bars + labels + '</svg>';
  }

  /* stacked horizontal bars (status distribution by agent) */
  function stackedBars(rows) {
    var W = 326, rowH = 34, gap = 14, padL = 4, padT = 6, labelH = 16;
    var H = padT + rows.length * (rowH + labelH + gap);
    var maxTotal = Math.max.apply(null, rows.map(function (r) { return r.total; }).concat([1]));
    var barW = W - padL * 2;
    var out = "";
    rows.forEach(function (r, ri) {
      var y = padT + ri * (rowH + labelH + gap);
      out += '<text x="' + padL + '" y="' + (y + 12) + '" class="txc-rowl">' + esc(r.name) + '</text>';
      var x = padL, by = y + labelH, scale = r.total ? (barW * (r.total / maxTotal)) / r.total : 0;
      r.segs.forEach(function (s) {
        if (!s.v) return; var w = s.v * scale;
        out += '<rect x="' + r1(x) + '" y="' + by + '" width="' + r1(w) + '" height="' + rowH + '" fill="' + s.color + '"' +
          (x === padL ? ' rx="4"' : '') + '/>';
        if (w > 16) out += '<text x="' + r1(x + w / 2) + '" y="' + (by + rowH / 2 + 4) + '" class="txc-segv">' + s.v + '</text>';
        x += w;
      });
      if (!r.total) out += '<rect x="' + padL + '" y="' + by + '" width="' + barW + '" height="' + rowH + '" rx="4" fill="var(--surface-3)"/>';
    });
    return '<svg class="txc" viewBox="0 0 ' + W + ' ' + H + '" preserveAspectRatio="none" style="height:' + H + 'px">' + out + '</svg>';
  }

  /* multi-line trends */
  function lineChart(labels, series) {
    var W = 326, H = 188, padL = 20, padR = 8, padT = 12, padB = 28;
    var plotW = W - padL - padR, plotH = H - padT - padB, n = labels.length;
    var max = niceMax(Math.max.apply(null, [].concat.apply([], series.map(function (s) { return s.values; }))));
    var X = function (i) { return padL + (n <= 1 ? plotW / 2 : plotW * i / (n - 1)); };
    var Y = function (v) { return padT + plotH * (1 - v / max); };
    var grid = "";
    for (var g = 0; g <= max; g++) { var yy = Y(g);
      grid += '<line x1="' + padL + '" y1="' + r1(yy) + '" x2="' + (W - padR) + '" y2="' + r1(yy) + '" class="txc-grid"/>' +
        '<text x="' + (padL - 4) + '" y="' + r1(yy + 3) + '" class="txc-yl">' + g + '</text>'; }
    var lines = series.map(function (s) {
      var pts = s.values.map(function (v, i) { return { x: X(i), y: Y(v) }; });
      return '<path d="' + smooth(pts) + '" fill="none" stroke="' + s.color + '" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" opacity="' + (s.faint ? .55 : 1) + '"/>';
    }).join("");
    var xl = labels.map(function (l, i) { return '<text x="' + r1(X(i)) + '" y="' + (H - 8) + '" class="txc-xl">' + esc(l) + '</text>'; }).join("");
    return '<svg class="txc" viewBox="0 0 ' + W + ' ' + H + '" preserveAspectRatio="none">' + grid + lines + xl + '</svg>';
  }

  /* donut (segments tappable when interactive) */
  function donut(segs, total, interactive) {
    var R = 52, C = 2 * Math.PI * R, sw = 20, cx = 70, cy = 70, start = 0;
    var rings = segs.map(function (s, idx) {
      if (!(s.v > 0)) return "";
      var frac = total ? s.v / total : 0, len = frac * C;
      var ring = '<circle class="tx-dring' + (interactive ? ' tap' : '') + '" data-i="' + idx + '" cx="' + cx + '" cy="' + cy + '" r="' + R + '" fill="none" stroke="' + s.color + '" stroke-width="' + sw +
        '" stroke-dasharray="' + r1(len) + ' ' + r1(C - len) + '" stroke-dashoffset="' + r1(-start * C) + '"/>';
      start += frac; return ring;
    }).join("");
    return '<svg viewBox="0 0 140 140" class="tx-donut' + (interactive ? ' tap' : '') + '">' +
      '<circle cx="' + cx + '" cy="' + cy + '" r="' + R + '" fill="none" stroke="var(--surface-3)" stroke-width="' + sw + '"/>' +
      '<g transform="rotate(-90 ' + cx + ' ' + cy + ')">' + rings + '</g>' +
      '<text x="70" y="64" class="tx-donut-cap">Tickets</text><text x="70" y="90" class="tx-donut-num">' + total + '</text></svg>';
  }

  /* =========================================================
     formatting
     ========================================================= */
  function pad(n) { return n < 10 ? "0" + n : "" + n; }
  function fmtDate(ms) { if (!ms) return "N/A"; var d = new Date(ms); return pad(d.getDate()) + "/" + pad(d.getMonth() + 1) + "/" + d.getFullYear() + " " + pad(d.getHours()) + ":" + pad(d.getMinutes()); }
  function fmtDur(ms) { if (ms == null) return "N/A"; var m = Math.round(ms / MIN); if (m < 60) return m + "m"; if (m < 1440) return Math.round(m / 60) + "h"; return Math.round(m / 1440) + "d"; }

  /* =========================================================
     OVERVIEW
     ========================================================= */
  function statCounts(list) {
    var c = { assigned: 0, inprogress: 0, awaiting: 0, pending: 0, completed: 0, reopened: 0 };
    list.forEach(function (t) { if (c[t.wstatus] != null) c[t.wstatus]++; });
    return c;
  }

  var BAR_COLOR = { assigned: "#16A34A", inprogress: "#F59E0B", awaiting: "#F87171", pending: "#EAB308", completed: "#2BA84A", reopened: "#8B5CF6", total: "#2563EB" };
  function tile(cls, label, ic, val, total) {
    var pct = total ? Math.round((val / total) * 100) : 0;
    return '<div class="tx-stat"><div class="ic ' + cls + '">' + ic + '</div>' +
      '<div class="num">' + val + '</div><div class="lbl">' + label + '</div>' +
      (cls === "total"
        ? '<div class="tx-stat-foot"><span class="tx-stat-pct">All ticket activity</span></div>'
        : '<div class="tx-stat-bar"><i style="width:' + pct + '%;background:' + BAR_COLOR[cls] + '"></i></div>' +
          '<div class="tx-stat-foot"><span class="tx-stat-pct">' + pct + '% of total</span></div>') +
      '</div>';
  }

  function overview() {
    var list = scope(), c = statCounts(list), total = list.length;
    var rangeLabel = (RANGES.filter(function (r) { return r[0] === state.range; })[0] || RANGES[0])[1];

    /* stat tiles */
    var tiles = [
      ["assigned", "Assigned Tickets", icAssigned, c.assigned],
      ["inprogress", "In Progress", icProgress, c.inprogress],
      ["awaiting", "Awaiting Response", icAwait, c.awaiting],
      ["pending", "Pending Tickets", icPending, c.pending],
      ["completed", "Completed Tickets", icDone, c.completed],
      ["reopened", "Reopened Tickets", icReopen, c.reopened],
      ["total", "Total Tickets", icTotal, total]
    ].map(function (s) { return tile(s[0], s[1], s[2], s[3], total); }).join("");

    /* status distribution + performance metrics removed per request */

    /* trends over last 7 days */
    var days = [], trendSeries = {};
    var BARC = (window.CHART && CHART.bar) || "#2BA84A";
    /* each status gets a distinct on-brand shade of green (single source of
       truth in chart-theme.js) so the chart + legend read as differentiated
       greens rather than one flat green. */
    var GS = (window.CHART && CHART.statusScale) || {};
    function gs(k) { return GS[k] || BARC; }
    var trendKeys = [["total", "Total Tickets", gs("total")], ["assigned", "Assigned", gs("assigned")], ["inprogress", "In Progress", gs("inprogress")],
      ["awaiting", "Awaiting Customer", gs("awaiting")], ["reopened", "Reopened", gs("reopened")], ["pending", "Pending", gs("pending")], ["completed", "Completed", gs("completed")]];
    trendKeys.forEach(function (k) { trendSeries[k[0]] = []; });
    for (var i = 6; i >= 0; i--) {
      var d0 = new Date(NOW.getFullYear(), NOW.getMonth(), NOW.getDate() - i), d1 = d0.getTime() + DAY;
      days.push(pad(d0.getDate()) + "/" + pad(d0.getMonth() + 1));
      var dayT = list.filter(function (t) { return t.createdMs >= d0.getTime() && t.createdMs < d1; });
      trendSeries.total.push(dayT.length);
      ["assigned", "inprogress", "awaiting", "reopened", "pending", "completed"].forEach(function (st) {
        trendSeries[st].push(dayT.filter(function (t) { return t.wstatus === st; }).length);
      });
    }
    var activeKey = state.trendKey || "total";
    var activeMeta = trendKeys.filter(function (k) { return k[0] === activeKey; })[0] || trendKeys[0];
    var activeTotal = (trendSeries.total || []).reduce(function (a, b) { return a + b; }, 0);
    /* per-day stacked breakdown by status, each a distinct on-brand green shade */
    var stackStatuses = [["assigned", "Assigned"], ["inprogress", "In Progress"], ["awaiting", "Awaiting Customer"], ["pending", "Pending"], ["reopened", "Reopened"], ["completed", "Completed"]];
    var dayStacks = days.map(function (_d, di) {
      return stackStatuses.map(function (s) { return { key: s[0], label: s[1], color: gs(s[0]), v: trendSeries[s[0]][di] || 0 }; });
    });
    var dayTotals = trendSeries.total;
    var trendLegend = stackStatuses.map(function (s) {
      return '<span class="li"><span class="dotc" style="background:' + gs(s[0]) + '"></span>' + s[1] + '</span>';
    }).join("");

    /* priority donut */
    var prioSegs = WPRIO.map(function (p) { return { key: p[0], label: p[1], color: p[2], v: list.filter(function (t) { return t.wpriority === p[0]; }).length }; });
    var prioLegend = WPRIO.map(function (p, i) { return '<button class="li tx-prleg" data-i="' + i + '"><span class="dotc" style="background:' + p[2] + '"></span>' + p[1] + '<b class="lv">' + prioSegs[i].v + '</b></button>'; }).join("");

    /* department breakdown */
    var deptMap = {};
    list.forEach(function (t) { var d = t.department || "Support"; (deptMap[d] = deptMap[d] || { total: 0, completed: 0 }); deptMap[d].total++; if (t.wstatus === "completed") deptMap[d].completed++; });
    var deptRows = Object.keys(deptMap).sort(function (a, b) { return deptMap[b].total - deptMap[a].total; }).map(function (d) {
      var o = deptMap[d], opened = o.total - o.completed, rate = o.total ? Math.round((o.completed / o.total) * 100) : 0;
      return '<div class="dpb-row"><span class="nm">' + esc(d) + '</span><span class="v">' + o.total + '</span><span class="v">' + opened + '</span><span class="v">' + o.completed + '</span>' +
        '<span class="rate"><span class="track"><i style="width:' + rate + '%' + (rate === 0 ? '' : ';background:' + (rate < 30 ? '#F87171' : 'var(--accent)')) + '"></i></span><b>' + rate + '%</b></span></div>';
    }).join("");

    host.innerHTML = subTabs() +
      '<button class="tx-range" id="txRange"><span class="ic">' + icCal + '</span><span class="lab">' + esc(rangeLabel) + '</span><span class="cv">' + icChevD + '</span></button>' +
      '<div class="tx-statgrid">' + tiles + '</div>' +

      card("Ticket Trends Over Time", icBar, null,
        '<div class="txb-readout" id="txbReadout"><b>' + activeTotal + ' tickets</b><span class="muted"> \u00b7 last 7 days \u00b7 tap a bar for the day\u2019s breakdown</span></div>' +
        '<div class="tx-chartbox">' + trendStackBars(days, dayStacks, dayTotals) + '</div>' +
        '<div class="tx-legend sm txb-legend">' + trendLegend + '</div>') +

      card("Priority Distribution", icAlert2, null,
        '<div class="tx-donutwrap">' + donut(prioSegs, list.length, true) + '<div class="tx-dlegend">' + prioLegend + '</div></div>') +

      '<div class="tx-card"><div class="ch-hd"><div class="ch-ttl">' + icUsers + 'Department Breakdown</div></div>' +
        '<div class="dpb"><div class="dpb-hd"><span class="nm">Department</span><span class="v">Total</span><span class="v">Opened</span><span class="v">Completed</span><span class="rate">Rate %</span></div>' +
        (deptRows || '<div class="tx-empty">No departments in range</div>') + '</div></div>';

    wireSub();
    $("#txRange", host).addEventListener("click", function () {
      TK.radioSheet("Date range", RANGES.map(function (r) { return { v: r[0], label: r[1], on: state.range === r[0] }; }), function (v) { state.range = v; render(); });
    });
    host.querySelectorAll(".txb-leg").forEach(function (b) {
      b.addEventListener("click", function () { state.trendKey = b.getAttribute("data-tk"); render(); });
    });
    (function () {
      var svg = host.querySelector(".txb-svg"); if (!svg) return;
      var readout = host.querySelector("#txbReadout");
      svg.addEventListener("click", function (e) {
        var hit = e.target.closest("[data-i]"); if (!hit) return;
        var i = +hit.getAttribute("data-i");
        svg.querySelectorAll(".txb-seg").forEach(function (r) { r.style.opacity = (+r.getAttribute("data-i") === i) ? "1" : "0.3"; });
        svg.classList.add("has-sel");
        var segs = dayStacks[i].filter(function (s) { return s.v > 0; });
        var tot = dayTotals[i] || 0;
        var parts = segs.map(function (s) { return '<span class="txb-bd"><span class="dotc" style="background:' + s.color + '"></span>' + s.v + ' ' + s.label + '</span>'; }).join("");
        if (readout) readout.innerHTML = '<b>' + days[i] + ' \u00b7 ' + tot + ' ticket' + (tot === 1 ? "" : "s") + '</b>' + (parts ? '<div class="txb-bdrow">' + parts + '</div>' : ' <span class="muted">\u00b7 no tickets</span>');
      });
    })();

    /* interactive Priority Distribution donut: tap a slice or legend pill to focus it */
    (function () {
      var don = host.querySelector(".tx-donut.tap"); if (!don) return;
      var cap = don.querySelector(".tx-donut-cap"), num = don.querySelector(".tx-donut-num");
      var legs = host.querySelectorAll(".tx-prleg");
      function reset() {
        don.classList.remove("has-sel");
        don.querySelectorAll(".tx-dring").forEach(function (r) { r.classList.remove("sel"); });
        legs.forEach(function (b) { b.classList.remove("on"); });
        cap.textContent = "Tickets"; num.textContent = list.length;
      }
      function select(i) {
        var p = prioSegs[i]; if (!p || !(p.v > 0)) return;
        don.classList.add("has-sel");
        don.querySelectorAll(".tx-dring").forEach(function (r) { r.classList.toggle("sel", +r.getAttribute("data-i") === i); });
        legs.forEach(function (b) { b.classList.toggle("on", +b.getAttribute("data-i") === i); });
        cap.textContent = p.label; num.textContent = p.v;
      }
      function toggle(i) {
        var isSel = don.classList.contains("has-sel") && don.querySelector('.tx-dring.sel[data-i="' + i + '"]');
        if (isSel) reset(); else select(i);
      }
      don.addEventListener("click", function (e) { var r = e.target.closest(".tx-dring"); if (r) toggle(+r.getAttribute("data-i")); });
      legs.forEach(function (b) { b.addEventListener("click", function () { toggle(+b.getAttribute("data-i")); }); });
    })();
  }

  function metric(ic, label, val) {
    return '<div class="tx-metric"><div class="ml">' + label + '</div><div class="mv">' + ic + '<b>' + val + '</b></div></div>';
  }

  /* =========================================================
     AGENT PERFORMANCE
     ========================================================= */
  function agentStats(a, list) {
    var mine = list.filter(function (t) { return t.assignee === a.id; });
    var completed = mine.filter(function (t) { return t.wstatus === "completed"; });
    var open = mine.length - completed.length;
    var rate = mine.length ? Math.round((completed.length / mine.length) * 1000) / 10 : 0;
    var createdMax = mine.length ? Math.max.apply(null, mine.map(function (t) { return t.createdMs; })) : null;
    var dueMin = mine.length ? Math.min.apply(null, mine.map(function (t) { return t.dueMs; })) : null;
    var assignedArr = mine.filter(function (t) { return t.assignedMs; });
    var assignedMax = assignedArr.length ? Math.max.apply(null, assignedArr.map(function (t) { return t.assignedMs; })) : null;
    var compDone = completed.filter(function (t) { return t.completedMs; });
    var compMax = compDone.length ? Math.max.apply(null, compDone.map(function (t) { return t.completedMs; })) : null;
    var avgDur = compDone.length ? compDone.reduce(function (s, t) { return s + (t.completedMs - t.createdMs); }, 0) / compDone.length : null;
    return { a: a, total: mine.length, completed: completed.length, open: open, rate: rate,
      createdMax: createdMax, dueMin: dueMin, assignedMax: assignedMax, compMax: compMax, avgDur: avgDur };
  }

  /* clean, readable horizontal bars: each agent's tickets split into Completed + Open */
  function agentBars(rows) {
    var series = [["total", "Total Tickets", "#2BA84A"], ["completed", "Completed Tickets", "#BCE8B0"], ["open", "Open Tickets", "#16A34A"]];
    var W = 326, H = 214, padL = 26, padR = 10, padT = 22, padB = 48;
    var plotW = W - padL - padR, plotH = H - padT - padB;
    var allv = []; rows.forEach(function (r) { series.forEach(function (s) { allv.push(r[s[0]]); }); });
    var max = niceMax(Math.max.apply(null, allv.concat([1])));
    var Y = function (v) { return padT + plotH * (1 - v / max); };
    var grid = "", step = max / 4;
    for (var g = 0; g <= 4; g++) { var val = Math.round(step * g), yy = Y(val);
      grid += '<line x1="' + padL + '" y1="' + r1(yy) + '" x2="' + (W - padR) + '" y2="' + r1(yy) + '" class="txc-grid"/>' +
        '<text x="' + (padL - 6) + '" y="' + r1(yy + 3) + '" class="txc-yl">' + val + '</text>'; }
    var groupW = plotW / rows.length, inner = Math.min(groupW - 14, 92), barGap = 7, bw = (inner - barGap * (series.length - 1)) / series.length;
    var bars = "", labels = "", hits = "";
    rows.forEach(function (r, ci) {
      var gx = padL + groupW * ci + (groupW - inner) / 2;
      hits += '<rect class="txg-hit" x="' + r1(padL + groupW * ci) + '" y="' + padT + '" width="' + r1(groupW) + '" height="' + plotH + '" data-ci="' + ci + '" data-nm="' + esc(r.a.name) + '" data-t="' + r.total + '" data-c="' + r.completed + '" data-o="' + r.open + '" fill="transparent"/>';
      series.forEach(function (s, si) {
        var v = r[s[0]], x = gx + si * (bw + barGap), h = plotH * v / max, y = Y(v);
        bars += '<rect class="txg-bar" data-ci="' + ci + '" x="' + r1(x) + '" y="' + r1(y) + '" width="' + r1(bw) + '" height="' + r1(Math.max(h, v ? 2 : 0)) + '" rx="4" fill="' + s[2] + '"/>';
        if (v) labels += '<text class="txc-vl" x="' + r1(x + bw / 2) + '" y="' + r1(y - 5) + '">' + v + '</text>';
      });
      labels += '<text class="txc-xl" data-ci="' + ci + '" x="' + r1(padL + groupW * ci + groupW / 2) + '" y="' + (H - 26) + '">' + esc(r.a.name) + '</text>';
    });
    var svg = '<svg class="txc txg-svg" viewBox="0 0 ' + W + ' ' + H + '" preserveAspectRatio="none">' + grid + hits + bars + labels + '</svg>';
    var legend = '<div class="tx-legend">' + series.map(function (s) { return '<span class="li"><span class="dotc" style="background:' + s[2] + '"></span>' + s[1] + '</span>'; }).join("") + '</div>';
    return '<div class="tx-abreadout" id="txAbReadout"><span class="muted">Tap an agent\u2019s bars for details</span></div>' +
      '<div class="tx-chartbox">' + svg + '</div>' + legend;
  }

  /* full detail row for one agent (Agent Performance Summary) */
  function summaryDetail(r) {
    return '<div class="aps-row">' +
      '<div class="c who"><span class="av" style="background:' + r.a.color + '">' + esc(r.a.initials) + '</span>' + esc(r.a.name) + '</div>' +
      kv("Total Tickets", r.total) + kv("Completed", r.completed) +
      kv("Latest Created", fmtDate(r.createdMax)) + kv("Nearest Due", fmtDate(r.dueMin)) +
      kv("Latest Assigned", fmtDate(r.assignedMax)) + kv("Avg Duration", fmtDur(r.avgDur)) +
      kv("Latest Completed", fmtDate(r.compMax)) +
    '</div>';
  }

  function summaryCard(r) {
    return '<div class="aps-card">' +
      '<span class="av" style="background:' + r.a.color + '">' + esc(r.a.initials) + '</span>' +
      '<div class="info">' +
        '<div class="top"><span class="nm">' + esc(r.a.name) + '</span><span class="rate">' + r.rate + '%</span></div>' +
        '<div class="meta"><span>Total ' + r.total + '</span><span class="dot">\u00b7</span><span>Done ' + r.completed + '</span>' +
          '<span class="dot">\u00b7</span><span>Avg ' + fmtDur(r.avgDur) + '</span></div>' +
      '</div></div>';
  }

  function agentFilterBar() {
    var label = state.agent === "all" ? "All Agents" : ((TK.agentById(state.agent) || {}).name || "All Agents");
    return '<div class="tx-agentbar"><button class="tx-agentpill" id="txAgentPill">' + icUser +
      '<span>' + esc(label) + '</span>' + icChevD + '</button></div>';
  }

  function agentPerf() {
    var list = scope();
    var allRows = TK.AGENTS.map(function (a) { return agentStats(a, list); });

    var body, apsRows = null;
    if (state.agent === "all") {
      var rows = allRows.filter(function (r) { return r.total > 0; });
      var chart = rows.length ? agentBars(rows) : '<div class="tx-empty">No agent data in range</div>';
      var rateCards = rows.map(function (r) {
        return '<div class="tx-ratecard"><div class="nm">' + esc(r.a.name) + '</div><div class="pct">' + r.rate + '%</div>' +
          '<div class="cap">Completion Rate</div></div>';
      }).join("") || '<div class="tx-empty">No agents</div>';
      var tableRows = rows.map(summaryCard).join("") || '<div class="tx-empty">No agent activity</div>';
      apsRows = rows;
      var detail0 = rows.length ? summaryDetail(rows[0]) : '<div class="tx-empty">No agent activity</div>';
      body =
        card("Agent Performance Summary Chart", icBar, "Total · Completed · Open per agent · tap a bar", chart) +
        '<div class="tx-card"><div class="ch-hd"><div class="ch-ttl">' + icTrophy + 'Agent Completion Rates</div></div>' +
          '<div class="tx-ratewrap">' + rateCards + '</div></div>' +
        '<div class="tx-card"><div class="ch-hd"><div class="ch-ttl">' + icCal + 'Agent Performance Summary</div></div>' +
          '<div class="aps" id="apsDetail">' + detail0 + '</div></div>';
    } else {
      var r = allRows.filter(function (x) { return x.a.id === state.agent; })[0];
      if (!r || !r.total) {
        body = '<div class="tx-card"><div class="tx-empty">No tickets for ' + esc((TK.agentById(state.agent) || {}).name || "this agent") + ' in range</div></div>';
      } else {
        var ringPct = r.rate;
        body =
          '<div class="tx-card tx-agenthead"><span class="av" style="background:' + r.a.color + '">' + esc(r.a.initials) + '</span>' +
            '<div class="meta"><div class="nm">' + esc(r.a.name) + '</div><div class="ro">' + esc(r.a.role || "Agent") + '</div></div></div>' +
          '<div class="tx-card"><div class="ch-hd"><div class="ch-ttl">' + icTrophy + 'Completion Rate</div></div>' +
            '<div class="tx-ratebig"><div class="ring" style="--pct:' + ringPct + '"><div class="inner"><b>' + r.rate + '%</b><span>' + r.completed + '/' + r.total + '</span></div></div>' +
              '<div class="tx-ratebrk"><div class="b"><span class="k">Completed</span><span class="v" style="color:var(--accent-deep)">' + r.completed + '</span></div>' +
                '<div class="b"><span class="k">Open</span><span class="v">' + r.open + '</span></div>' +
                '<div class="b"><span class="k">Avg Duration</span><span class="v">' + fmtDur(r.avgDur) + '</span></div></div></div></div>' +
          card("Agent Performance Summary Chart", icBar, esc(r.a.name) + " · Total · Completed · Open", agentBars([r])) +
          '<div class="tx-card"><div class="ch-hd"><div class="ch-ttl">' + icCal + 'Performance Summary</div></div>' +
            '<div class="aps">' + summaryDetail(r) + '</div></div>';
      }
    }

    host.innerHTML = subTabs() + agentFilterBar() + body;

    wireSub();
    var _chartSvg = host.querySelector(".txg-svg");
    if (_chartSvg) {
      var _ro = $("#txAbReadout", host), _det = $("#apsDetail", host);
      _chartSvg.addEventListener("click", function (e) {
        var hit = e.target.closest("[data-ci]"); if (!hit) return;
        var ci = hit.getAttribute("data-ci");
        _chartSvg.querySelectorAll(".txg-bar").forEach(function (b) { b.classList.toggle("sel", b.getAttribute("data-ci") === ci); });
        _chartSvg.querySelectorAll(".txc-xl").forEach(function (l) { l.classList.toggle("sel", l.getAttribute("data-ci") === ci); });
        _chartSvg.classList.add("has-sel");
        if (_ro) _ro.innerHTML = '<b>' + esc(hit.getAttribute("data-nm")) + '</b><span class="muted"> \u00b7 Total ' + hit.getAttribute("data-t") + ' \u00b7 Completed ' + hit.getAttribute("data-c") + ' \u00b7 Open ' + hit.getAttribute("data-o") + '</span>';
        if (_det && apsRows && apsRows[+ci]) _det.innerHTML = summaryDetail(apsRows[+ci]);
      });
    }
    var pill = $("#txAgentPill", host);
    if (pill) pill.addEventListener("click", function () {
      var opts = [{ v: "all", label: "All Agents", on: state.agent === "all" }];
      TK.AGENTS.forEach(function (a) { opts.push({ v: a.id, label: a.name + (a.you ? " (You)" : ""), on: state.agent === a.id }); });
      TK.radioSheet("Filter by agent", opts, function (v) { state.agent = v; render(); });
    });
  }
  function kv(k, v) { return '<div class="c"><span class="k">' + k + '</span><span class="vv">' + v + '</span></div>'; }

  /* =========================================================
     shared shell
     ========================================================= */
  function subTabs() {
    return '<div class="tx-subtabs" id="txSubTabs">' +
      '<button class="st' + (state.tab === "overview" ? " on" : "") + '" data-t="overview">' + icGrid + 'Overview</button>' +
      '<button class="st' + (state.tab === "agents" ? " on" : "") + '" data-t="agents">' + icUser + 'Agent Performance</button>' +
      '</div>';
  }
  function wireSub() {
    $$("#txSubTabs .st", host).forEach(function (b) {
      b.addEventListener("click", function () { state.tab = b.getAttribute("data-t"); render(); });
    });
  }
  function card(title, ic, sub, body) {
    return '<div class="tx-card"><div class="ch-hd"><div><div class="ch-ttl">' + ic + esc(title) + '</div>' +
      (sub ? '<div class="ch-sub">' + esc(sub) + '</div>' : '') + '</div></div>' + body + '</div>';
  }

  function render() {
    migrate();
    if (state.tab === "agents") agentPerf(); else overview();
    var sh = $(".lp-sheet", TK.pane); if (sh) sh.scrollTop = 0;
  }

  /* =========================================================
     icons
     ========================================================= */
  var icGrid = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="3" width="7" height="7" rx="1.5"/><rect x="14" y="3" width="7" height="7" rx="1.5"/><rect x="3" y="14" width="7" height="7" rx="1.5"/><rect x="14" y="14" width="7" height="7" rx="1.5"/></svg>';
  var icUser = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="8" r="4"/><path d="M4 21c0-4 3.6-6 8-6s8 2 8 6"/></svg>';
  var icUsers = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="9" cy="8" r="3.2"/><path d="M3 20c0-3.2 2.7-5 6-5s6 1.8 6 5"/><path d="M16 5.2a3 3 0 0 1 0 5.6M17.5 15c2 .6 3.5 1.7 3.5 4"/></svg>';
  var icBar = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 20V10M10 20V4M16 20v-7M22 20H2"/></svg>';
  var icGauge = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 18a8 8 0 1 1 16 0"/><path d="M12 14l3-3"/></svg>';
  var icTrophy = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M7 4h10v4a5 5 0 0 1-10 0V4Z"/><path d="M7 6H4v1a3 3 0 0 0 3 3M17 6h3v1a3 3 0 0 1-3 3M9 21h6M12 13v4"/></svg>';
  var icCal = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="5" width="18" height="16" rx="2.5"/><path d="M3 10h18M8 3v4M16 3v4"/></svg>';
  var icChevD = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m6 9 6 6 6-6"/></svg>';
  var icClock2 = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3.5 2"/></svg>';
  var icStar = '<svg viewBox="0 0 24 24" fill="currentColor"><path d="m12 3 2.7 5.4 6 .9-4.3 4.2 1 6L12 16.9 6.6 19.5l1-6L3.3 9.3l6-.9z"/></svg>';
  var icAlert = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 9v4M12 17h.01"/><path d="M10.3 3.9 2 19a2 2 0 0 0 1.7 3h16.6a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0Z"/></svg>';
  var icAlert2 = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="M12 8v4M12 16h.01"/></svg>';
  /* stat-tile icons */
  var icAssigned = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="5" width="18" height="16" rx="2.5"/><path d="M3 10h18M8 3v4M16 3v4"/><path d="m9 15 2 2 4-4"/></svg>';
  var icProgress = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m6 6 6 6-6 6M13 6l6 6-6 6"/></svg>';
  var icAwait = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="M8 12h.01M12 12h.01M16 12h.01"/></svg>';
  var icPending = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="M12 8v4M12 15h.01"/></svg>';
  var icDone = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="m8.5 12 2.5 2.5 4.5-5"/></svg>';
  var icReopen = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 12a9 9 0 1 0 3-6.7L3 8M3 4v4h4"/></svg>';
  var icTotal = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="4" width="18" height="16" rx="2.5"/><path d="m8 11 2.5 2.5L16 8"/></svg>';

  window.TKDash = { render: render };

  /* initial paint (ticketing.js already defaulted to the dashboard section) */
  render();
})();
