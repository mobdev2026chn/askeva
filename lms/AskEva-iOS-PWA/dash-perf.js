/* AskEva — Leads Dashboard: Overview/Performance toggle + FUNCTIONAL filters
   (filters recompute the KPIs, status, company & performance stats from the
    live leads dataset exposed by leads-module.js as window.AskEvaLeads) */
(function () {
  "use strict";
  var $ = function (s, r) { return (r || document).querySelector(s); };
  var $$ = function (s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); };
  var pane = document.getElementById("app-dashboard");
  if (!pane) return;

  var toastT;
  function toast(msg) {
    var t = document.getElementById("toast"); if (!t) return;
    t.textContent = msg; t.style.opacity = "1"; t.style.transform = "translateX(-50%) translateY(0)";
    clearTimeout(toastT); toastT = setTimeout(function () { t.style.opacity = "0"; t.style.transform = "translateX(-50%) translateY(20px)"; }, 1800);
  }

  var CAL = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="5" width="18" height="16" rx="2.5"/><path d="M3 10h18M8 3v4M16 3v4"/></svg>';
  var FUN = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 6h16M7 12h10M10 18h4"/></svg>';
  var FUN2 = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 5h18l-7 8v5l-4 2v-7z"/></svg>';
  var X = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M18 6 6 18M6 6l12 12"/></svg>';
  var ARROW = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12h14m0 0-5-5m5 5-5 5"/></svg>';
  var CASH = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="6" width="18" height="12" rx="2.5"/><circle cx="12" cy="12" r="2.4"/><path d="M6 9.5v5M18 9.5v5"/></svg>';
  var EYE = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7-10-7-10-7Z"/><circle cx="12" cy="12" r="3"/></svg>';
  var CHEVL = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m15 18-6-6 6-6"/></svg>';
  var CHEVR = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m9 18 6-6-6-6"/></svg>';
  var BARS = '<svg viewBox="0 0 24 24" fill="none" stroke="#2BA84A" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 20V10M10 20V4M16 20v-7M20 20H3"/></svg>';
  function esch(s){ return String(s==null?"":s).replace(/[&<>"]/g,function(c){return {"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;"}[c];}); }
  var coPage = 1, coPageSize = 5;
  function ensureCoStyle(){
    if (document.getElementById("d2-cptable-style")) return;
    var s = document.createElement("style"); s.id = "d2-cptable-style";
    s.textContent =
      ".cp-card{overflow:hidden;}" +
      ".cp-scroll{overflow-x:auto;-webkit-overflow-scrolling:touch;scrollbar-width:none;}.cp-scroll::-webkit-scrollbar{display:none;}" +
      ".cp-table{width:max-content;min-width:100%;border-collapse:collapse;}" +
      ".cp-table th{text-align:left;font-size:11px;font-weight:600;color:var(--ink-3,#8a978d);padding:4px 16px 12px;white-space:nowrap;}" +
      ".cp-table td{padding:14px 16px;border-top:1px solid var(--line,#eef1ec);white-space:nowrap;vertical-align:middle;}" +
      ".cp-co{display:flex;align-items:center;gap:10px;}" +
      ".cp-av{width:34px;height:34px;border-radius:50%;display:grid;place-items:center;color:#fff;font-weight:700;font-size:13px;flex:0 0 34px;}" +
      ".cp-coname{font-size:13.5px;font-weight:600;color:var(--ink,#15231a);white-space:normal;max-width:130px;line-height:1.25;}" +
      ".cp-badge{display:inline-grid;place-items:center;min-width:26px;height:26px;padding:0 8px;border-radius:999px;background:var(--eva-green,#3cc23f);color:#fff;font-size:12.5px;font-weight:700;}" +
      ".cp-rate{display:flex;align-items:center;gap:10px;min-width:160px;}" +
      ".cp-track{flex:1;height:7px;border-radius:999px;background:var(--surface-3,#ecf0e8);overflow:hidden;}.cp-track i{display:block;height:100%;border-radius:999px;}" +
      ".cp-rpct{font-size:12px;font-weight:700;min-width:40px;text-align:right;}" +
      ".cp-val{font-size:13.5px;font-weight:700;color:var(--ink,#15231a);}" +
      ".cp-pager{display:flex;align-items:center;justify-content:flex-end;gap:8px;padding:14px 16px 6px;}" +
      ".cp-pager button{width:32px;height:32px;border:1px solid var(--line,#eef1ec);background:#fff;border-radius:9px;display:grid;place-items:center;cursor:pointer;color:var(--ink-2,#4d5d52);}" +
      ".cp-pager button svg{width:16px;height:16px;}.cp-pager button:disabled{opacity:.4;cursor:default;}" +
      ".cp-pager .pg{min-width:32px;height:32px;border:1.5px solid var(--eva-green,#3cc23f);border-radius:9px;display:grid;place-items:center;font-size:13px;font-weight:700;color:var(--eva-green-deep,#177a36);}";
    document.head.appendChild(s);
  }
  function renderCoTable(list){
    var ct = document.getElementById("d2CoTable"); if (!ct) return;
    ensureCoStyle();
    var co = {};
    list.forEach(function (L) { var n = companyOf(L); (co[n] = co[n] || []).push(L); });
    var arr = Object.keys(co).map(function (n) {
      var g = co[n], cv = g.filter(function (L){ return L.status==="converted"; }).length;
      var val = g.filter(function (L){ return L.status==="converted"; }).reduce(function (s,L){ return s + leadVal(L); }, 0);
      var ags = {}; g.forEach(function (L){ ags[agentOf(L)] = 1; });
      return { name:n, leads:g.length, conv:cv, rate:pct(cv,g.length), value:val, agents:Object.keys(ags).length };
    }).sort(function (a,b){ return (b.leads-a.leads) || (b.conv-a.conv); });
    if (!arr.length) { ct.innerHTML = '<div class="d2-empty" style="padding:24px 16px">No companies match these filters</div>'; return; }
    var pages = Math.max(1, Math.ceil(arr.length/coPageSize));
    if (coPage>pages) coPage=pages; if (coPage<1) coPage=1;
    var slice = arr.slice((coPage-1)*coPageSize, coPage*coPageSize);
    function barColor(r){ return r>=67?"var(--eva-green,#3cc23f)":r>=34?"#F5B829":"#EF5350"; }
    function rateColor(r){ return r>=67?"#1F8A3B":r>=34?"#9A6B00":"#C1352F"; }
    var rowsHTML = slice.map(function (g){
      var known = g.name!=="Unknown Company";
      return '<tr>' +
        '<td><div class="cp-co"><span class="cp-av" style="background:'+(known?"var(--eva-gradient)":"#9AA39C")+'">'+esch(g.name.charAt(0).toUpperCase())+'</span><span class="cp-coname">'+esch(g.name)+'</span></div></td>' +
        '<td><span class="cp-badge">'+g.leads+'</span></td>' +
        '<td><span class="cp-badge">'+g.conv+'</span></td>' +
        '<td><div class="cp-rate"><div class="cp-track"><i style="width:'+Math.max(g.rate,3)+'%;background:'+barColor(g.rate)+'"></i></div><span class="cp-rpct" style="color:'+rateColor(g.rate)+'">'+g.rate+'%</span></div></td>' +
        '<td><span class="cp-val">'+inrk(g.value)+'</span></td>' +
        '<td><span class="cp-badge">'+g.agents+'</span></td>' +
      '</tr>';
    }).join("");
    var pager = '<div class="cp-pager"><button data-pg="prev"'+(coPage<=1?' disabled':'')+'>'+CHEVL+'</button><span class="pg">'+coPage+'</span><button data-pg="next"'+(coPage>=pages?' disabled':'')+'>'+CHEVR+'</button></div>';
    ct.innerHTML = '<div class="cp-scroll"><table class="cp-table">' +
      '<thead><tr><th>Company</th><th>Leads</th><th>Converted</th><th>Conversion Rate</th><th>Total Value</th><th>Agents</th></tr></thead>' +
      '<tbody>'+rowsHTML+'</tbody></table></div>' + (pages>1 ? pager : '');
    var pv = ct.querySelector('[data-pg="prev"]'), nx = ct.querySelector('[data-pg="next"]');
    if (pv) pv.addEventListener("click", function (){ if (coPage>1){ coPage--; renderCoTable(list); } });
    if (nx) nx.addEventListener("click", function (){ if (coPage<pages){ coPage++; renderCoTable(list); } });
  }

  var PERIODS = ["Last 7 days", "Last 30 days", "Last 90 days", "This year", "All time"];
  /* agent filter options come from the shared people store (Settings → Agents) */
  function agentOptions() {
    var emails = (window.AskEvaPeople && AskEvaPeople.emails) ? AskEvaPeople.emails("leads") : ["eshan@tunepath.com", "testerr@gmail.com"];
    return ["All Agents"].concat(emails).concat(["Unassigned"]);
  }
  /* Sources, statuses + status donut meta are sourced from the shared dropdown
     store (Lead Settings → Configuration) so this dashboard stays in lock-step
     with the Leads list — add/remove a status or source there and it shows here. */
  var ST_BUILTIN = { "new": ["New", "#2563EB"], hot: ["Hot", "#DB4324"], warm: ["Warm", "#B5790A"], cold: ["Cold", "#2E90C4"], converted: ["Customer", "#1F8A3B"] };
  var ST_ALIAS = { "new": "new", hot: "hot", warm: "warm", cold: "cold", customer: "converted", converted: "converted" };
  var ST_CUSTOM_COLORS = ["#1E7FB0", "#6D45D6", "#B5790A", "#4254C5", "#D7402A", "#5C6358"];
  function stKey(label) { var l = String(label).trim().toLowerCase(); return ST_ALIAS[l] || ("st_" + l.replace(/[^a-z0-9]+/g, "_").replace(/^_|_$/g, "")); }
  var SOURCES, STATUSES, ST, STATUS_LABEL_TO_KEY;
  function rebuildDD() {
    SOURCES = ["All Sources"].concat((window.AskEvaLeadDropdowns && AskEvaLeadDropdowns.options("Source")) || ["Import", "Chat-Sync", "Chat-Initiated", "Website", "Referral", "Manual"]);
    var labels = (window.AskEvaLeadDropdowns && AskEvaLeadDropdowns.options("Status")) || ["New", "Hot", "Warm", "Cold", "Customer"];
    STATUSES = ["All Status"].concat(labels);
    ST = []; STATUS_LABEL_TO_KEY = {}; var ci = 0;
    labels.forEach(function (label) {
      var key = stKey(label);
      var color = ST_BUILTIN[key] ? ST_BUILTIN[key][1] : ST_CUSTOM_COLORS[ci++ % ST_CUSTOM_COLORS.length];
      ST.push([key, label, color]);
      STATUS_LABEL_TO_KEY[label] = key;
    });
  }
  rebuildDD();
  if (window.AskEvaLeadDropdowns && AskEvaLeadDropdowns.onChange) AskEvaLeadDropdowns.onChange(function () { rebuildDD(); try { rerenderAll(); } catch (e) {} });

  /* ---------- data ---------- */
  var LEADS = (window.AskEvaLeads || []).slice();
  function parseDate(s) {
    // "DD-MM-YYYY HH:MM"
    var m = /(\d{2})-(\d{2})-(\d{4})(?:\s+(\d{2}):(\d{2}))?/.exec(s || "");
    if (!m) return null;
    return new Date(+m[3], +m[2] - 1, +m[1], +(m[4] || 0), +(m[5] || 0));
  }
  function computeNow() {
    var max = 0;
    LEADS.forEach(function (L) { var d = parseDate(L.created); if (d && d.getTime() > max) max = d.getTime(); });
    return new Date((max || Date.now()) + 864e5);
  }
  // anchor "today" to the most recent lead so the default range stays populated
  var NOW = computeNow();
  function companyOf(L) { return (L.company && L.company.trim()) ? L.company.trim() : "Unknown Company"; }
  function agentOf(L) { return L.assigned ? L.assigned : "Unassigned"; }

  function filterList(f) {
    var startD = f.start ? new Date(f.start + "T00:00:00") : null;
    var endD = f.end ? new Date(f.end + "T23:59:59") : null;
    var periodMs = { "Last 7 days": 7, "Last 30 days": 30, "Last 90 days": 90 }[f.period];
    var minP = periodMs ? NOW.getTime() - periodMs * 864e5 : null;
    return LEADS.filter(function (L) {
      var d = parseDate(L.created);
      if (minP != null && d && d.getTime() < minP) return false;
      if (f.period === "This year" && d && d.getFullYear() !== NOW.getFullYear()) return false;
      if (startD && d && d < startD) return false;
      if (endD && d && d > endD) return false;
      if (f.assigned !== "All Agents") {
        if (f.assigned === "Unassigned" && L.assigned) return false;
        if (f.assigned !== "Unassigned" && L.assigned !== f.assigned) return false;
      }
      if (f.source !== "All Sources" && L.source !== f.source) return false;
      if (f.status !== "All Status") {
        if (L.status !== STATUS_LABEL_TO_KEY[f.status]) return false;
      }
      return true;
    });
  }

  function countBy(list, fn) { var m = {}; list.forEach(function (x) { var k = fn(x); m[k] = (m[k] || 0) + 1; }); return m; }
  function leadVal(L) { var n = parseFloat((L.value || "").toString().replace(/[^\d.]/g, "")); return isNaN(n) ? 0 : n; }
  function inrk(n) { return "&#8377;" + (n >= 1000 ? (n / 1000).toFixed(1) + "k" : (n ? n.toFixed(0) : "0.0k")); }
  function pct(part, whole) { return whole ? Math.round(part / whole * 100) : 0; }

  /* ===================== OVERVIEW RENDER ===================== */
  function renderOverview(list) {
    var total = list.length;
    var byStatus = countBy(list, function (L) { return L.status; });
    var converted = byStatus.converted || 0;
    var hot = byStatus.hot || 0;
    var achieved = list.filter(function (L) { return L.status === "converted"; }).reduce(function (s, L) { return s + leadVal(L); }, 0);
    var totalValue = list.reduce(function (s, L) { return s + leadVal(L); }, 0);

    /* KPI grid */
    var kpis = [hot, converted, (total ? (converted / total * 100).toFixed(1) : "0") + "%", "&#8377;" + achieved, "&#8377;" + totalValue, total];
    $$("#d2KpiGrid .d2-kpi .v", pane).forEach(function (el, i) { if (i < kpis.length) el.innerHTML = kpis[i]; });

    /* lead status donut + legend — SVG ring donut, same interactive style as the
       ticketing Priority Distribution donut (tap a ring or count-pill to focus it) */
    var card = $("#d2StatusCard", pane);
    if (card) {
      var segs = ST.map(function (s) { return { key: s[0], label: s[1], color: s[2], v: byStatus[s[0]] || 0 }; });
      var R = 52, CIRC = 2 * Math.PI * R, sw = 20, cx = 70, cy = 70, acc2 = 0;
      var rings = segs.map(function (s, idx) {
        if (!(s.v > 0)) return "";
        var frac = total ? s.v / total : 0, len = frac * CIRC;
        var ring = '<circle class="tx-dring tap" data-i="' + idx + '" cx="' + cx + '" cy="' + cy + '" r="' + R + '" fill="none" stroke="' + s.color + '" stroke-width="' + sw +
          '" stroke-dasharray="' + (Math.round(len * 10) / 10) + ' ' + (Math.round((CIRC - len) * 10) / 10) + '" stroke-dashoffset="' + (Math.round(-acc2 * CIRC * 10) / 10) + '"/>';
        acc2 += frac; return ring;
      }).join("");
      var donutSVG = '<svg viewBox="0 0 140 140" class="tx-donut tap">' +
        '<circle cx="' + cx + '" cy="' + cy + '" r="' + R + '" fill="none" stroke="var(--surface-3)" stroke-width="' + sw + '"/>' +
        '<g transform="rotate(-90 ' + cx + ' ' + cy + ')">' + rings + '</g>' +
        '<text x="70" y="64" class="tx-donut-cap">Leads</text><text x="70" y="90" class="tx-donut-num">' + total + '</text></svg>';
      var legend = segs.map(function (s, i) {
        return '<button class="li tx-prleg" data-i="' + i + '"><span class="dotc" style="background:' + s.color + '"></span>' + s.label + '<b class="lv">' + s.v + '</b></button>';
      }).join("");
      card.innerHTML = '<div class="tx-donutwrap">' + donutSVG + '<div class="tx-dlegend">' + legend + '</div></div>';

      var don = card.querySelector(".tx-donut.tap");
      var cap = don.querySelector(".tx-donut-cap"), num = don.querySelector(".tx-donut-num");
      var legs = card.querySelectorAll(".tx-prleg");
      function resetStatus() {
        don.classList.remove("has-sel");
        don.querySelectorAll(".tx-dring").forEach(function (r) { r.classList.remove("sel"); });
        legs.forEach(function (b) { b.classList.remove("on"); });
        cap.textContent = "Leads"; num.textContent = total;
      }
      function selectStatus(i) {
        var s = segs[i]; if (!s || !(s.v > 0)) return;
        don.classList.add("has-sel");
        don.querySelectorAll(".tx-dring").forEach(function (r) { r.classList.toggle("sel", +r.getAttribute("data-i") === i); });
        legs.forEach(function (b) { b.classList.toggle("on", +b.getAttribute("data-i") === i); });
        cap.textContent = s.label; num.textContent = s.v;
      }
      function toggleStatus(i) {
        var isSel = don.classList.contains("has-sel") && don.querySelector('.tx-dring.sel[data-i="' + i + '"]');
        if (isSel) resetStatus(); else selectStatus(i);
      }
      don.addEventListener("click", function (e) { var r = e.target.closest(".tx-dring"); if (r) toggleStatus(+r.getAttribute("data-i")); });
      legs.forEach(function (b) { b.addEventListener("click", function () { toggleStatus(+b.getAttribute("data-i")); }); });
    }

    /* company analytics */
    var co = $("#d2CompanyCard", pane);
    if (co) {
      var groups = {};
      list.forEach(function (L) { var n = companyOf(L); (groups[n] = groups[n] || []).push(L); });
      var arr = Object.keys(groups).map(function (n) {
        var g = groups[n], cv = g.filter(function (L) { return L.status === "converted"; }).length;
        var srcs = {}; g.forEach(function (L) { if (L.source) srcs[L.source] = 1; });
        return { name: n, leads: g.length, conv: cv, sources: Object.keys(srcs).length };
      }).sort(function (a, b) { return b.leads - a.leads; });
      co.innerHTML = arr.length ? arr.map(function (g) {
        var p = pct(g.conv, g.leads), known = g.name !== "Unknown Company";
        return '<div class="d2-perf"><span class="d2-pav" style="background:' + (known ? "var(--eva-gradient)" : "#9AA39C") + '">' + g.name.charAt(0).toUpperCase() + '</span>' +
          '<div class="d2-pinfo"><div class="toprow"><span class="d2-pname">' + g.name + '</span><span class="d2-pval">&#8377;0.0k</span></div>' +
          '<div class="d2-psub">' + g.leads + ' lead' + (g.leads === 1 ? "" : "s") + ' &middot; ' + g.conv + ' converted &middot; ' + g.sources + ' source' + (g.sources === 1 ? "" : "s") + '</div>' +
          '<div class="d2-trackrow"><div class="d2-ptrack"><i style="width:' + Math.max(p, 3) + '%"></i></div><span class="d2-ppct' + (p === 100 ? " done" : p === 0 ? " muted" : "") + '">' + p + '%</span></div></div></div>';
      }).join("") : '<div class="d2-empty">No companies match these filters</div>';
    }

    /* top performers — agent leaderboard (leads, converted, conversion %) */
    var tp = $("#d2TopPerf", pane);
    if (tp) {
      var ag = {};
      list.forEach(function (L) { var a = agentOf(L); (ag[a] = ag[a] || []).push(L); });
      var rows = Object.keys(ag).map(function (a) {
        var g = ag[a], cv = g.filter(function (L) { return L.status === "converted"; }).length;
        var val = g.filter(function (L) { return L.status === "converted"; }).reduce(function (s, L) { return s + leadVal(L); }, 0);
        return { name: a, leads: g.length, conv: cv, value: val };
      }).sort(function (a, b) { return (b.conv - a.conv) || (b.leads - a.leads); });
      tp.innerHTML = rows.length ? rows.map(function (g) {
        var p = pct(g.conv, g.leads), known = g.name !== "Unassigned";
        return '<div class="d2-perf"><span class="d2-pav" style="background:' + (known ? "var(--eva-gradient)" : "#9AA39C") + '">' + g.name.charAt(0).toUpperCase() + '</span>' +
          '<div class="d2-pinfo"><div class="toprow"><span class="d2-pname">' + g.name + '</span><span class="d2-pval">' + inrk(g.value) + '</span></div>' +
          '<div class="d2-psub">' + g.leads + ' lead' + (g.leads === 1 ? "" : "s") + ' &middot; ' + g.conv + ' converted</div>' +
          '<div class="d2-trackrow"><div class="d2-ptrack"><i style="width:' + Math.max(p, 3) + '%"></i></div><span class="d2-ppct' + (p === 100 ? " done" : p === 0 ? " muted" : "") + '">' + p + '%</span></div></div></div>';
      }).join("") : '<div class="d2-empty">No agents match these filters</div>';
    }
  }

  /* ===================== 30-DAY TREND (bar chart) ===================== */
  var DOW = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
  var MON = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
  var trendGran = "daily";

  function midnight(d) { return new Date(d.getFullYear(), d.getMonth(), d.getDate()); }
  /* leads passing the current non-date overview filters (the 30-day window is fixed) */
  function trendBase() {
    var f = FS.overview;
    return LEADS.filter(function (L) {
      if (f.assigned !== "All Agents") {
        if (f.assigned === "Unassigned" && L.assigned) return false;
        if (f.assigned !== "Unassigned" && L.assigned !== f.assigned) return false;
      }
      if (f.source !== "All Sources" && L.source !== f.source) return false;
      if (f.status !== "All Status" && L.status !== STATUS_LABEL_TO_KEY[f.status]) return false;
      return true;
    });
  }
  /* count leads created on each of `n` days ending at `end` (a midnight Date) */
  function dailySeries(list, end, n) {
    var days = [];
    for (var i = n - 1; i >= 0; i--) days.push(new Date(end.getTime() - i * 864e5));
    var counts = days.map(function () { return 0; });
    list.forEach(function (L) {
      var d = parseDate(L.created); if (!d) return;
      var dm = midnight(d).getTime();
      for (var i = 0; i < days.length; i++) { if (days[i].getTime() === dm) { counts[i]++; break; } }
    });
    return { days: days, counts: counts };
  }

  function renderTrend() {
    var card = $("#d2TrendCard", pane); if (!card) return;
    var base = trendBase();
    var end = midnight(NOW);
    var cur = dailySeries(base, end, 30);
    var prev = dailySeries(base, new Date(end.getTime() - 30 * 864e5), 30);
    var curTotal = cur.counts.reduce(function (a, b) { return a + b; }, 0);
    var prevTotal = prev.counts.reduce(function (a, b) { return a + b; }, 0);

    /* delta vs previous 30 days */
    var deltaPct, deltaCls, deltaTxt;
    if (prevTotal === 0) { deltaTxt = curTotal ? "New" : "—"; deltaCls = curTotal ? "up" : "flat"; }
    else { deltaPct = Math.round((curTotal - prevTotal) / prevTotal * 100); deltaCls = deltaPct > 0 ? "up" : deltaPct < 0 ? "down" : "flat"; deltaTxt = (deltaPct > 0 ? "+" : "") + deltaPct + "%"; }
    /* zigzag trending-up / trending-down icons (Lucide style) for any directional trend */
    var trendIc = deltaCls === "up"
      ? '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><polyline points="22 7 13.5 15.5 8.5 10.5 2 17"/><polyline points="16 7 22 7 22 13"/></svg>'
      : deltaCls === "down"
      ? '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><polyline points="22 17 13.5 8.5 8.5 13.5 2 7"/><polyline points="16 17 22 17 22 11"/></svg>'
      : '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12h14"/></svg>';

    /* build bars for the active granularity */
    var bars, labels, peakDay;
    if (trendGran === "weekly") {
      var W = []; /* 5 buckets of 6 days */
      for (var b = 0; b < 5; b++) {
        var c = 0; for (var k = 0; k < 6; k++) c += cur.counts[b * 6 + k];
        W.push({ c: c, start: cur.days[b * 6], end: cur.days[b * 6 + 5] });
      }
      var wmax = Math.max.apply(null, W.map(function (x) { return x.c; }).concat([4]));
      bars = W.map(function (w, i) {
        var pk = w.c === Math.max.apply(null, W.map(function (x) { return x.c; })) && w.c > 0;
        return '<button class="d2-tbar wk' + (pk ? " peak" : "") + '" data-i="' + i + '" style="--h:' + (w.c / wmax * 100) + '%" aria-label="' + tipText(w, true) + '"><span class="cap">' + (w.c || "") + '</span><i></i></button>';
      }).join("");
      labels = W.map(function (w) { return '<span>' + MON[w.start.getMonth()] + " " + w.start.getDate() + '</span>'; }).join("");
      window.__trendTips = W.map(function (w) { return tipText(w, true); });
    } else {
      var dmax = Math.max.apply(null, cur.counts.concat([3]));
      var maxIdx = cur.counts.indexOf(Math.max.apply(null, cur.counts));
      bars = cur.counts.map(function (c, i) {
        var pk = i === maxIdx && c > 0;
        return '<button class="d2-tbar' + (pk ? " peak" : "") + (c === 0 ? " zero" : "") + '" data-i="' + i + '" style="--h:' + (c / dmax * 100) + '%" aria-label="' + tipText({ c: c, start: cur.days[i] }, false) + '"><i></i></button>';
      }).join("");
      var li = [0, 7, 14, 21, 29];
      labels = li.map(function (ix) { var d = cur.days[ix]; return '<span>' + MON[d.getMonth()] + " " + d.getDate() + '</span>'; }).join("");
      window.__trendTips = cur.counts.map(function (c, i) { return tipText({ c: c, start: cur.days[i] }, false); });
    }
    var avg = (curTotal / 30).toFixed(curTotal >= 30 ? 0 : 1);

    card.innerHTML =
      '<div class="d2-trend-top">' +
        '<div class="d2-trend-stat"><div class="big">' + curTotal + '</div>' +
          '<div class="lbl">new leads · avg ' + avg + '/day</div></div>' +
        '<div class="d2-trend-right">' +
          '<span class="d2-trend-delta ' + deltaCls + '">' + trendIc + deltaTxt + '</span>' +
          '<div class="d2-gran"><button data-gran="daily"' + (trendGran === "daily" ? ' class="on"' : "") + '>Daily</button><button data-gran="weekly"' + (trendGran === "weekly" ? ' class="on"' : "") + '>Weekly</button></div>' +
        '</div>' +
      '</div>' +
      '<div class="d2-trend-plot"><div class="d2-trend-grid"><i></i><i></i><i></i></div>' +
        '<div class="d2-trend-bars' + (trendGran === "weekly" ? " weekly" : "") + '">' + bars + '</div>' +
        '<div class="d2-trend-tip" hidden></div>' +
      '</div>' +
      '<div class="d2-trend-x">' + labels + '</div>' +
      '<div class="d2-trend-foot">vs ' + prevTotal + ' in the prior 30 days</div>';

    /* granularity toggle */
    $$("[data-gran]", card).forEach(function (g) {
      g.addEventListener("click", function () { trendGran = g.getAttribute("data-gran"); renderTrend(); });
    });
    /* bar tooltip (tap / hover) */
    var barsEl = $(".d2-trend-bars", card), tip = $(".d2-trend-tip", card);
    function showTip(barEl) {
      var i = +barEl.getAttribute("data-i");
      tip.innerHTML = (window.__trendTips[i] || "").replace(" · ", "<b> · ");
      tip.hidden = false;
      var plotW = barsEl.offsetWidth, x = barEl.offsetLeft + barEl.offsetWidth / 2;
      tip.style.left = Math.min(Math.max(x, 34), plotW - 34) + "px";
      barsEl.querySelectorAll(".d2-tbar").forEach(function (b) { b.classList.toggle("act", b === barEl); });
    }
    function hideTip() { tip.hidden = true; barsEl.querySelectorAll(".d2-tbar.act").forEach(function (b) { b.classList.remove("act"); }); }
    barsEl.addEventListener("click", function (e) { var b = e.target.closest(".d2-tbar"); if (b) showTip(b); });
    barsEl.addEventListener("mouseover", function (e) { var b = e.target.closest(".d2-tbar"); if (b) showTip(b); });
    barsEl.addEventListener("mouseleave", hideTip);
  }
  function tipText(w, weekly) {
    var d = w.start, lead = w.c === 1 ? "lead" : "leads";
    if (weekly) { var e = w.end; return MON[d.getMonth()] + " " + d.getDate() + "–" + (e.getMonth() !== d.getMonth() ? MON[e.getMonth()] + " " : "") + e.getDate() + " · " + w.c + " " + lead; }
    return DOW[d.getDay()] + ", " + MON[d.getMonth()] + " " + d.getDate() + " · " + w.c + " " + lead;
  }

  /* ===================== PERFORMANCE RENDER ===================== */
  function renderPerformance(list) {
    function escx(s){return String(s==null?"":s).replace(/[&<>"]/g,function(ch){return {"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;"}[ch];});}
    /* per-agent leads config (Monthly Target / Per Day / Profession) from Settings → Agents */
    function leadsCfgFor(email) {
      if (!window.AskEvaPeople || !window.AskEvaAgentCfg || !AskEvaAgentCfg.get) return null;
      var roster = AskEvaPeople.roster ? AskEvaPeople.roster("leads") : [];
      var a = roster.filter(function (x) { return x.email === email; })[0];
      if (!a) return null;
      var c = AskEvaAgentCfg.get(a.id);
      return (c && c.leads) ? c.leads : null;
    }
    /* agents */
    var wrap = $("#d2AgentsWrap", pane);
    if (wrap) {
      var ag = {};
      list.forEach(function (L) { var a = agentOf(L); (ag[a] = ag[a] || []).push(L); });
      var arr = Object.keys(ag).map(function (a) { return { email: a, leads: ag[a] }; }).sort(function (x, y) { return y.leads.length - x.leads.length; });
      wrap.innerHTML = arr.length ? arr.map(function (a) {
        var n = a.leads.length, cv = a.leads.filter(function (L) { return L.status === "converted"; }).length, p = pct(cv, n);
        var aval = a.leads.reduce(function (s, L) { return s + leadVal(L); }, 0);
        var vstr = "&#8377;" + (aval >= 1e7 ? (aval / 1e7).toFixed(1) + "Cr" : aval >= 1e5 ? (aval / 1e5).toFixed(1) + "L" : aval >= 1000 ? (aval / 1000).toFixed(1) + "k" : aval);
        var statsRow = '<div class="lxp-stats">' +
          '<div class="s"><span class="k">Total Leads</span><span class="v">' + n + '</span></div>' +
          '<div class="s"><span class="k">Converted</span><span class="v g">' + cv + '</span></div>' +
          '<div class="s"><span class="k">Conversion Rate</span><span class="v">' + p + '%</span></div>' +
          '<div class="s"><span class="k">Total Value</span><span class="v g">' + vstr + '</span></div>' +
        '</div>';
        var c = countBy(a.leads, function (L) { return L.status; });
        var label = a.email === "Unassigned" ? "Unassigned" : a.email;
        var cfg = a.email === "Unassigned" ? null : leadsCfgFor(a.email);
        var tgt = cfg && parseInt(cfg.target, 10) > 0 ? parseInt(cfg.target, 10) : 0;
        var tprog = tgt ? Math.min(100, Math.round((n / tgt) * 100)) : 0;
        var sub = cfg && cfg.profession ? '<span class="lxp-prof">' + escx(cfg.profession) + '</span>' : '';
        var targetRow = tgt ? '<div class="lxp-target"><span class="tl">Monthly target</span><div class="lxp-track sm"><i style="width:' + Math.max(tprog, 1) + '%"></i></div><span class="tv">' + n + ' / ' + tgt + '</span></div>'
          + (cfg && cfg.perDay ? '<div class="lxp-perday">Goal: ' + escx(cfg.perDay) + ' new leads / day</div>' : '') : '';
        var chips = '<span class="lxp-stchip new">' + (c.new || 0) + ' New</span><span class="lxp-stchip warm">' + (c.warm || 0) + ' Warm</span>' +
          '<span class="lxp-stchip negotiation">' + (c.hot || 0) + ' Hot</span><span class="lxp-stchip won">' + (c.converted || 0) + ' Customer</span>' +
          '<span class="lxp-stchip lost">' + (c.cold || 0) + ' Cold</span>';
        return '<div class="d2-card lxp-agent"><div class="lxp-ahd"><span class="av" style="background:#9AA39C">' + label.charAt(0).toLowerCase() + '</span><span class="em">' + label + sub + '</span><span class="lxp-leads">' + n + '</span></div>' +
          '<div class="lxp-conv"><div class="lxp-track"><i style="width:' + Math.max(p, 1) + '%"></i></div><span class="lxp-pct">' + p + '%</span></div>' +
          targetRow +
          '<div class="lxp-row2"><span class="lxp-val">' + CASH + vstr + '</span><button class="lxp-view" type="button">' + EYE + 'View Details</button></div>' +
          '<div class="lxp-details collapsed">' + statsRow +
          '<div class="lxp-stchips"><div class="lxp-stchips-lbl">New · Hot · Warm · Cold · Converted</div>' + chips + '</div></div></div>';
      }).join("") : '<div class="d2-card"><div class="d2-empty">No agents match these filters</div></div>';
    }

    /* source performance — conversion rate per source */
    var sc = $("#d2SourceCard", pane);
    if (sc) {
      var src = {};
      list.forEach(function (L) { var s = L.source || "Unknown"; (src[s] = src[s] || []).push(L); });
      var sarr = Object.keys(src).map(function (s) {
        var g = src[s], cv = g.filter(function (L) { return L.status === "converted"; }).length;
        return { name: s, rate: pct(cv, g.length) };
      }).sort(function (a, b) { return b.rate - a.rate; });
      sc.innerHTML = (sarr.length ? '<div class="lxp-bars">' + sarr.map(function (b) {
        var cls = b.rate === 0 ? "zero" : b.rate < 100 ? "lite" : "";
        return '<div class="lxp-bar"><div class="top"><span class="nm">' + b.name + '</span><span class="vv">' + b.rate + '%</span></div>' +
          '<div class="track"><i class="' + cls + '" style="width:' + b.rate + '%"></i></div></div>';
      }).join("") + '</div>' : '<div class="d2-empty">No sources match these filters</div>') +
        '<div class="lxp-legend"><span><span class="d" style="background:var(--eva-green)"></span>Conversion Rate</span></div>';
    }

    /* company analysis — leads per company */
    var cc = $("#d2CoAnalysisCard", pane);
    if (cc) {
      var co = {};
      list.forEach(function (L) { var n = (L.company && L.company.trim()) ? L.company.trim() : "Unknown"; (co[n] = co[n] || []).push(L); });
      var carr = Object.keys(co).map(function (n) { return { name: n, leads: co[n].length }; }).sort(function (a, b) { return b.leads - a.leads; });
      var max = carr.reduce(function (m, c) { return Math.max(m, c.leads); }, 0) || 1;
      cc.innerHTML = (carr.length ? '<div class="lxp-bars">' + carr.map(function (c) {
        return '<div class="lxp-bar"><div class="top"><span class="nm">' + c.name + '</span><span class="vv">' + c.leads + ' &middot; &#8377;0</span></div>' +
          '<div class="track"><i style="width:' + Math.round(c.leads / max * 100) + '%;background:var(--eva-green-700)"></i></div></div>';
      }).join("") + '</div>' : '<div class="d2-empty">No companies match these filters</div>') +
        '<div class="lxp-legend"><span><span class="d" style="background:var(--eva-green-700)"></span>Leads</span><span><span class="d" style="background:var(--eva-green)"></span>Total Value</span></div>';
    }

    renderCoTable(list);
  }

  /* ---------- filter state ---------- */
  var FS = {
    overview: { period: "Last 30 days", assigned: "All Agents", source: "All Sources", status: "All Status", start: "", end: "" },
    performance: { period: "Last 30 days", assigned: "All Agents", source: "All Sources", status: "All Status" }
  };

  /* ---------- toggle ---------- */
  var btns = $$(".d2-segtoggle button", pane);
  var bodies = $$("[data-dash-body]", pane);
  var scan = $(".d2-scan", pane);

  /* inject filter row atop Performance body */
  var perfBody = $('[data-dash-body="performance"]', pane);
  if (perfBody && !$(".d2-filterrow", perfBody)) {
    var row = document.createElement("div");
    row.className = "d2-filterrow";
    row.innerHTML = '<span class="lbl">' + CAL + '<span class="ptxt">Last 30 days</span></span>' +
      '<button class="d2-filterbtn" data-pf>' + FUN + 'Filters</button>';
    perfBody.insertBefore(row, perfBody.firstChild);
  }
  if (perfBody && !document.getElementById("d2CoTable")) {
    ensureCoStyle();
    var coSec = document.createElement("div"); coSec.className = "d2-sec";
    coSec.innerHTML = '<span class="si">' + BARS + '</span><h3>Detailed Company Performance</h3>';
    var coCard = document.createElement("div"); coCard.className = "d2-card cp-card"; coCard.id = "d2CoTable"; coCard.style.padding = "6px 0 4px";
    perfBody.appendChild(coSec); perfBody.appendChild(coCard);
  }
  var ovBody = $('[data-dash-body="overview"]', pane);
  var ovLbl = ovBody ? $(".d2-filterrow .lbl", ovBody) : null;
  if (ovLbl && !$(".ptxt", ovLbl)) ovLbl.innerHTML = CAL + '<span class="ptxt">Last 30 days</span>';

  function show(which) {
    btns.forEach(function (b) { b.classList.toggle("active", b.getAttribute("data-dash") === which); });
    bodies.forEach(function (b) { b.hidden = b.getAttribute("data-dash-body") !== which; });
    if (scan) scan.style.display = which === "overview" ? "" : "none";
    var sheet = $(".d2-sheet", pane); if (sheet) sheet.scrollTop = 0;
  }
  btns.forEach(function (b) { b.addEventListener("click", function () { show(b.getAttribute("data-dash")); }); });

  /* ---------- filter panel ---------- */
  var panel = document.createElement("div"); panel.className = "lx-panel"; pane.appendChild(panel);
  function openPanel() { requestAnimationFrame(function () { panel.classList.add("show"); }); }
  function closePanel() { panel.classList.remove("show"); }

  function selField(label, id, opts, val) {
    return '<div class="lx-ffield"><label>' + label + '</label><select class="lx-select" id="' + id + '">' +
      opts.map(function (o) { return '<option' + (o === val ? " selected" : "") + '>' + o + '</option>'; }).join("") + '</select></div>';
  }

  function applyFilters(kind) {
    var f = FS[kind];
    var list = filterList(f);
    if (kind === "overview") renderOverview(list); else renderPerformance(list);
    if (kind === "overview") renderTrend();
    var lbl = kind === "overview" ? (ovLbl && $(".ptxt", ovLbl)) : $('[data-dash-body="performance"] .d2-filterrow .ptxt', pane);
    if (lbl) lbl.textContent = f.period;
    return list;
  }

  function build(kind) {
    var f = FS[kind];
    var title = kind === "overview" ? "Global Filters" : "Performance Filters";
    var dateField = kind === "overview"
      ? '<div class="lx-ffield"><label>Created Date Range</label><div id="dGlobalDatePill"></div></div>'
      : "";
    panel.innerHTML =
      '<div class="lx-pbar"><button class="x" data-x>' + X + '</button><span class="ptt">' + FUN2 + title + '</span></div>' +
      '<div class="lx-pbody">' + dateField +
        selField("Time Period", "fPeriod", PERIODS, f.period) +
        selField("Assigned To", "fAssigned", agentOptions(), f.assigned) +
        selField("Lead Source", "fSource", SOURCES, f.source) +
        selField("Lead Status", "fStatus", STATUSES, f.status) +
      '</div>' +
      '<div class="lx-pfoot"><button class="lx-btn clear" data-clear>Clear All</button><button class="lx-btn primary" data-apply>Apply Filters</button></div>';
    $("[data-x]", panel).addEventListener("click", closePanel);
    if (kind === "overview") {
      var gpill = $("#dGlobalDatePill", panel);
      if (gpill && window.AskEvaPicker && AskEvaPicker.rangePill) {
        AskEvaPicker.rangePill(gpill, { start: f.start || "", end: f.end || "", onChange: function (r) { f.start = r.start || ""; f.end = r.end || ""; } });
      }
    }
    $("[data-clear]", panel).addEventListener("click", function () {
      FS[kind] = kind === "overview"
        ? { period: "Last 30 days", assigned: "All Agents", source: "All Sources", status: "All Status", start: "", end: "" }
        : { period: "Last 30 days", assigned: "All Agents", source: "All Sources", status: "All Status" };
      build(kind); applyFilters(kind); toast("Filters cleared");
    });
    $("[data-apply]", panel).addEventListener("click", function () {
      f.period = $("#fPeriod", panel).value; f.assigned = $("#fAssigned", panel).value;
      f.source = $("#fSource", panel).value; f.status = $("#fStatus", panel).value;
      if (kind === "overview") { /* start/end synced live by the date pill */ }
      var list = applyFilters(kind);
      var act = [f.assigned !== "All Agents", f.source !== "All Sources", f.status !== "All Status", !!(f.start || f.end)].filter(Boolean).length;
      closePanel();
      toast(list.length + " lead" + (list.length === 1 ? "" : "s") + " · " + (act ? act + " filter" + (act > 1 ? "s" : "") + " · " : "") + f.period);
    });
  }

  if (ovBody) { var ob = $(".d2-filterbtn", ovBody); if (ob) ob.addEventListener("click", function () { build("overview"); openPanel(); }); }
  pane.addEventListener("click", function (e) { if (e.target.closest("[data-pf]")) { build("performance"); openPanel(); } });

  /* initial render from defaults */
  function rerenderAll() {
    renderOverview(filterList(FS.overview));
    renderTrend();
    renderPerformance(filterList(FS.performance));
  }
  /* PASS 3: live sync — recompute KPIs, donut, companies, trend & performance
     from the leads store whenever anything changes, with no page refresh */
  document.addEventListener("leads:changed", function () {
    LEADS = (window.AskEvaLeads || []).slice();
    NOW = computeNow();
    rerenderAll();
  });
  /* also re-render when agents / their per-module config change (Settings → Agents),
     so a saved Leads config (target / per-day / profession) reflects live here */
  document.addEventListener("people:changed", function () { rerenderAll(); });
  rerenderAll();
})();
