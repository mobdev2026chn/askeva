/* =========================================================
   AskEva — Payment Transactions (full rebuild)
   Faithful mobile translation of the web "Payment
   Transactions" table:
     · Search by Order ID / Recipient Number
     · All Status dropdown filter
     · Records (S.No · Recipient Number · Order ID · Method
       · Amount · Timestamp · Status)
     · Pagination (Page N · ‹ · numbered · ›)
   Overrides AX.renderPayments from appointments-detail.js.
   ========================================================= */
(function (AX) {
  "use strict";
  if (!AX || !AX.pane) return;
  var $ = AX.$, $$ = AX.$$, I = AX.I, esc = AX.esc, fromISO = AX.fromISO, pad = AX.pad, MON = AX.MON;

  var PAGE_SIZE = 6;

  /* ---- one-time migration: give every paid/unpaid appt a web-style
          orderId (APMT_<ms>_<nnn>) + a real epoch timestamp ---- */
  if (!AX.appts.some(function (a) { return /^APMT_/.test(a.orderId || ""); })) {
    var seq = 0;
    AX.appts.slice().sort(function (a, b) { return b.created - a.created; }).forEach(function (a) {
      if (!(a.amount > 0)) return;
      var d = fromISO(a.date);
      var ms = new Date(d.getFullYear(), d.getMonth(), d.getDate(), Math.floor(a.time / 60), a.time % 60).getTime();
      a.orderId = "APMT_" + ms + "_" + (100 + (seq = (seq + 137) % 900));
      a.payTs = ms;
    });
    AX.save();
  }

  if (AX.state.payPage == null) AX.state.payPage = 1;

  /* status → display label + pill class (paid → Success) */
  function statusOf(t) {
    if (t.payStatus === "paid") return { label: "Success", cls: "ok" };
    if (t.payStatus === "pending") return { label: "Pending", cls: "pend" };
    return { label: "Failed", cls: "fail" };
  }
  var STATUS_OPTS = [["all", "All Status"], ["paid", "Success"], ["pending", "Pending"], ["failed", "Failed"]];

  function recipient(t) { return "91" + (t.mobile || "").replace(/\D/g, ""); }

  function fmtTs(t) {
    var d = t.payTs ? new Date(t.payTs) : fromISO(t.date);
    var dd = pad(d.getDate()), mm = pad(d.getMonth() + 1), yy = String(d.getFullYear()).slice(-2);
    var hh = pad(d.getHours()), mi = pad(d.getMinutes());
    return dd + "/" + mm + "/" + yy + ", " + hh + ":" + mi;
  }

  var icCheck = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="m8.5 12 2.5 2.5 4.5-5"/></svg>';
  var icDot   = '<svg viewBox="0 0 24 24" fill="currentColor"><circle cx="12" cy="12" r="5"/></svg>';
  var icUpi = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="m6 3 4 9-4 9 13-9z"/></svg>';
  var icChevD = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m6 9 6 6 6-6"/></svg>';

  AX.openPayFilter = function () {
    AX.radioSheet("Filter by status",
      STATUS_OPTS.map(function (o) { return { v: o[0], label: o[1], on: AX.state.payStatus === o[0] }; }),
      function (v) { AX.state.payStatus = v; AX.state.payPage = 1; AX.render(); });
  };

  AX.renderPayments = function (host) {
    var txns = AX.appts.filter(function (a) { return a.amount > 0; }).slice()
      .sort(function (a, b) { return (b.payTs || 0) - (a.payTs || 0); });

    var q = (AX.state.payQ || "").trim().toLowerCase();
    var filtered = txns.filter(function (t) {
      var okS = AX.state.payStatus === "all" || t.payStatus === AX.state.payStatus ||
        (AX.state.payStatus === "failed" && t.payStatus !== "paid" && t.payStatus !== "pending");
      var okQ = !q || (t.orderId + " " + recipient(t) + " " + t.name + " " + t.method).toLowerCase().indexOf(q) > -1;
      return okS && okQ;
    });

    var pages = Math.max(1, Math.ceil(filtered.length / PAGE_SIZE));
    if (AX.state.payPage > pages) AX.state.payPage = pages;
    var page = AX.state.payPage, start = (page - 1) * PAGE_SIZE;
    var slice = filtered.slice(start, start + PAGE_SIZE);

    var curLabel = (STATUS_OPTS.filter(function (o) { return o[0] === AX.state.payStatus; })[0] || STATUS_OPTS[0])[1];

    var rowsHTML = slice.length ? slice.map(function (t, i) { return payRow(t, start + i + 1); }).join("")
      : '<div class="pt-empty"><div class="ic">' + I.card + '</div><div class="t">No transactions found</div>' +
        '<div class="s">' + (q || AX.state.payStatus !== "all" ? "Try a different search or filter." : "Payments will appear here.") + '</div></div>';

    host.innerHTML =
      '<div class="pt-card">' +
        '<div class="pt-tools">' +
          '<div class="pt-search">' + I.search +
            '<input id="ptQ" type="text" placeholder="Search by Order ID, Recipient…" value="' + esc(AX.state.payQ || "") + '" autocomplete="off">' +
            (q ? '<button class="pt-clear" id="ptClear" aria-label="Clear">' + I.x + '</button>' : '') +
          '</div>' +
          '<button class="pt-statusdd" id="ptStatus">' + esc(curLabel) + ' <span class="cv">' + icChevD + '</span></button>' +
        '</div>' +
        '<div class="pt-colhd"><span class="c-sn">S.No</span><span class="c-main">Recipient / Order</span><span class="c-amt">Amount</span></div>' +
        '<div class="pt-rows" id="ptRows">' + rowsHTML + '</div>' +
        paginator(page, pages, filtered.length, start, slice.length) +
      '</div>';

    var qi = $("#ptQ", host);
    if (qi) qi.addEventListener("input", function (e) {
      AX.state.payQ = e.target.value; AX.state.payPage = 1;
      var c = e.target.selectionStart; AX.render();
      var n = $("#ptQ"); if (n) { n.focus(); try { n.setSelectionRange(c, c); } catch (x) {} }
    });
    var cl = $("#ptClear", host); if (cl) cl.addEventListener("click", function () { AX.state.payQ = ""; AX.state.payPage = 1; AX.render(); });
    var sb = $("#ptStatus", host); if (sb) sb.addEventListener("click", AX.openPayFilter);
    $$(".pt-row", host).forEach(function (el) { el.addEventListener("click", function () { AX.openDetail(el.getAttribute("data-id")); }); });
    $$(".pt-pg[data-pg]", host).forEach(function (b) {
      b.addEventListener("click", function () {
        var p = +b.getAttribute("data-pg");
        if (p < 1 || p > pages || p === page) return;
        AX.state.payPage = p; AX.render();
        var sc = $("#app-appointments .lp-sheet"); if (sc) sc.scrollTop = 0;
      });
    });
  };

  function payRow(t, sn) {
    var s = statusOf(t);
    var methodIc = t.method === "UPI" ? icUpi : t.method === "Cash" ? I.cash : I.card;
    return '<div class="pt-row" data-id="' + t.id + '">' +
      '<span class="sn">' + sn + '</span>' +
      '<div class="body">' +
        '<div class="r1"><span class="rcpt">' + esc(recipient(t)) + '</span>' +
          '<span class="amt">' + AX.inr(t.amount) + '</span></div>' +
        '<div class="ordid">' + esc(t.orderId) + '</div>' +
        '<div class="meta"><span class="mth">' + methodIc + esc(t.method) + '</span>' +
          '<span class="dot">·</span><span class="ts">' + fmtTs(t) + '</span></div>' +
        '<div class="r3"><span class="pt-pill ' + s.cls + '">' + (s.cls === "ok" ? icCheck : icDot) + s.label + '</span></div>' +
      '</div></div>';
  }

  function paginator(page, pages, total, start, count) {
    if (!total) return "";
    var from = start + 1, to = start + count;
    var nums = "";
    var lo = Math.max(1, page - 1), hi = Math.min(pages, lo + 2); lo = Math.max(1, hi - 2);
    if (lo > 1) nums += '<button class="pt-pg num" data-pg="1">1</button>' + (lo > 2 ? '<span class="pt-ell">…</span>' : "");
    for (var p = lo; p <= hi; p++) nums += '<button class="pt-pg num' + (p === page ? " on" : "") + '" data-pg="' + p + '">' + p + '</button>';
    if (hi < pages) nums += (hi < pages - 1 ? '<span class="pt-ell">…</span>' : "") + '<button class="pt-pg num" data-pg="' + pages + '">' + pages + '</button>';
    return '<div class="pt-foot">' +
      '<span class="pt-range">Showing ' + from + '–' + to + ' of ' + total + '</span>' +
      '<div class="pt-pager">' +
        '<button class="pt-pg arr" data-pg="' + (page - 1) + '"' + (page <= 1 ? " disabled" : "") + '>' + I.chevL + '</button>' +
        nums +
        '<button class="pt-pg arr" data-pg="' + (page + 1) + '"' + (page >= pages ? " disabled" : "") + '>' + I.chevR + '</button>' +
      '</div></div>';
  }

  setTimeout(function () {
    if (AX.state.tab === "payments") { var h = $("#axView"); if (h && !h.querySelector(".pt-card")) AX.renderPayments(h); }
  }, 0);

})(window.AX);
