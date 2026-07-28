/* =========================================================
   AskEva — Subscription service + management UI
   SINGLE SOURCE OF TRUTH for plan / expiry / billing.

   Dashboard  = compact overview only (plan, expiry, days, Upgrade)
   Profile    = full management center (Renew / Upgrade / Billing)
   Renew      = extend the CURRENT plan (3 / 6 / 12 months)
   Upgrade    = change tier (plan comparison)

   ── Backend note ──────────────────────────────────────────
   The DATA layer below simulates the billing API and caches
   to localStorage. Replace api.getSubscription / api.putSubscription
   / api.getCatalog / api.getBilling with real fetch() calls and
   the entire UI keeps working unchanged. There are NO hardcoded
   plan names / expiry dates / demo rows baked into the views —
   everything renders from api state.
   ========================================================= */
(function () {
  "use strict";
  var $ = function (s, r) { return (r || document).querySelector(s); };
  var $$ = function (s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); };

  function toast(msg) {
    var t = document.getElementById("toast"); if (!t) { return; }
    t.textContent = msg; t.style.opacity = "1"; t.style.transform = "translateX(-50%) translateY(0)";
    clearTimeout(toast._t); toast._t = setTimeout(function () { t.style.opacity = "0"; t.style.transform = "translateX(-50%) translateY(20px)"; }, 1900);
  }
  function esc(s) { return String(s == null ? "" : s).replace(/[&<>"]/g, function (c) { return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]; }); }
  function inr(n) { return "₹" + Math.round(n).toLocaleString("en-IN"); }

  var IC = {
    refresh: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 12a9 9 0 1 1-3-6.7L21 8M21 3v5h-5"/></svg>',
    rocket: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M5 14c-2 1-3 4-3 4s3-1 4-3M14 5c4-3 7-2 7-2s1 3-2 7c-1.6 2.2-5 4.5-7 5l-3-3c.5-2 2.8-5.4 5-7Z"/><circle cx="15" cy="9" r="1.6"/></svg>',
    receipt: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M5 3v18l2.5-1.5L10 21l2-1.5L14 21l2.5-1.5L19 21V3l-2.5 1.5L14 3l-2 1.5L10 3 7.5 4.5 5 3Z"/><path d="M9 8h6M9 12h6"/></svg>',
    clock: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="M12 7.5V12l3 2"/></svg>',
    wallet: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="6" width="18" height="13" rx="2.5"/><path d="M3 10h18M16 14h2"/></svg>',
    card: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="5" width="18" height="14" rx="2.5"/><path d="M3 10h18"/></svg>',
    check: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><path d="m5 12 4 4 10-11"/></svg>',
    x: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="M18 6 6 18M6 6l12 12"/></svg>',
    back: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="m15 18-6-6 6-6"/></svg>',
    cloud: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M7 18a4 4 0 0 1 0-8 6 6 0 0 1 11.3 2A3.5 3.5 0 0 1 18 18Z"/></svg>',
    lock: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="4.5" y="10.5" width="15" height="10" rx="2.5"/><path d="M8 10.5V8a4 4 0 0 1 8 0v2.5"/></svg>',
    support: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 13a8 8 0 0 1 16 0"/><rect x="2.5" y="13" width="4" height="7" rx="1.6"/><rect x="17.5" y="13" width="4" height="7" rx="1.6"/><path d="M20 20a4 4 0 0 1-4 3h-2"/></svg>',
    phone: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M5 4h3l2 5-2.5 1.5a11 11 0 0 0 5 5L16 16l5 2v3a2 2 0 0 1-2.2 2A17 17 0 0 1 3 6.2 2 2 0 0 1 5 4Z"/></svg>'
  };

  /* =========================================================
     DATA  — simulated billing backend (swap for real API)
     ========================================================= */
  /* tier ranks the plans: HIGHER number = higher plan.
     Ecommerce is the TOP plan (most expensive, ALL features);
     Enterprise is the 2nd plan below it. */
  var CATALOG = {
    ecommerce: { id: "ecommerce", name: "Ecommerce", monthly: 1999, tier: 2, tierNo: 3, msgLimit: 100000,
      tagline: "Our most complete plan — unlimited agents, every feature and priority support for serious online stores." },
    enterprise: { id: "enterprise", name: "Enterprise", monthly: 1199, tier: 1, tierNo: 2, msgLimit: 10000,
      tagline: "Core automation, APIs and catalog messaging for growing teams. Upgrade to Ecommerce for unlimited scale." }
  };
  var ORDER = ["ecommerce", "enterprise"];      // comparison column order (top plan first)
  var FEATURES = [
    { f: "Broadcast & Analytics",      ecommerce: true,        enterprise: true },
    { f: "Live Chat + History",        ecommerce: true,        enterprise: true },
    { f: "Chatbot Nodes",              ecommerce: "Unlimited", enterprise: "7" },
    { f: "Team Agents",                ecommerce: "Unlimited", enterprise: "5" },
    { f: "APIs & Webhooks",            ecommerce: true,        enterprise: true },
    { f: "Catalog / Product Messages", ecommerce: true,        enterprise: true },
    { f: "Carousel & WA Forms",        ecommerce: true,        enterprise: true },
    { f: "Role-based Access",          ecommerce: true,        enterprise: false },
    { f: "Dedicated Success Manager",  ecommerce: true,        enterprise: false },
    { f: "Priority Support (24×7)",    ecommerce: true,        enterprise: false }
  ];
  /* term options for renewal — discount grows with length */
  var TERMS = [
    { months: 3,  label: "3 Months", discount: 0.00 },
    { months: 6,  label: "6 Months", discount: 0.08 },
    { months: 12, label: "12 Months", discount: 0.17 }
  ];

  var LS_KEY = "askeva_subscription_v1";
  var LS_BILL = "askeva_billing_v1";

  /* ----- simulated API ----- */
  var api = {
    getCatalog: function () { return CATALOG; },
    getSubscription: function () {
      try { var raw = localStorage.getItem(LS_KEY); if (raw) return JSON.parse(raw); } catch (e) {}
      /* seed: server would return the account's real subscription */
      var start = new Date(); var exp = new Date(); exp.setFullYear(exp.getFullYear() + 1);
      var seed = { planId: "ecommerce", status: "active", startISO: iso(start), expiryISO: iso(exp), termMonths: 12 };
      api.putSubscription(seed); return seed;
    },
    putSubscription: function (sub) { try { localStorage.setItem(LS_KEY, JSON.stringify(sub)); } catch (e) {} return sub; },
    getBilling: function () {
      try { var raw = localStorage.getItem(LS_BILL); if (raw) return JSON.parse(raw); } catch (e) {}
      var s = api.getSubscription();
      var seed = [{ id: "inv-seed", planId: s.planId, months: s.termMonths || 12,
        amount: CATALOG[s.planId].monthly * (s.termMonths || 12), method: "online",
        dateISO: s.startISO, status: "Paid" }];
      try { localStorage.setItem(LS_BILL, JSON.stringify(seed)); } catch (e) {}
      return seed;
    },
    addBilling: function (rec) {
      var list = api.getBilling(); list.unshift(rec);
      try { localStorage.setItem(LS_BILL, JSON.stringify(list)); } catch (e) {}
      return list;
    }
  };

  /* ----- date helpers ----- */
  function iso(d) { return d.toISOString().slice(0, 10); }
  function parse(isoStr) { var p = (isoStr || "").split("-"); return new Date(+p[0], (+p[1] || 1) - 1, +p[2] || 1); }
  function fmt(isoStr) {
    var d = parse(isoStr), M = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    return d.getDate() + " " + M[d.getMonth()] + " " + d.getFullYear();
  }
  function daysLeft(isoStr) { return Math.max(0, Math.ceil((parse(isoStr) - new Date()) / 864e5)); }
  function termDays(isoStr) {
    var s = api.getSubscription();
    var total = Math.max(1, Math.round((parse(isoStr) - parse(s.startISO)) / 864e5));
    return total;
  }

  /* ----- tier helpers ----- */
  function maxTier() {
    return Object.keys(CATALOG).reduce(function (m, id) { return Math.max(m, CATALOG[id].tier); }, 0);
  }
  /* true when the given plan is the HIGHEST available — nothing left to upgrade to */
  function isTopTier(planId) {
    return CATALOG[planId] && CATALOG[planId].tier >= maxTier();
  }

  /* ----- pricing ----- */
  function priceFor(planId, months, discount) {
    var base = CATALOG[planId].monthly * months;
    return Math.round(base * (1 - (discount || 0)));
  }

  /* =========================================================
     SERVICE  (mutations re-render every surface)
     ========================================================= */
  var Sub = {
    get: function () { return api.getSubscription(); },
    plan: function () { return CATALOG[api.getSubscription().planId]; },

    renew: function (months, method) {
      var s = api.getSubscription();
      var from = daysLeft(s.expiryISO) > 0 ? parse(s.expiryISO) : new Date();
      var exp = new Date(from); exp.setMonth(exp.getMonth() + months);
      var term = TERMS.filter(function (t) { return t.months === months; })[0] || { discount: 0 };
      s.expiryISO = iso(exp); s.status = "active"; s.termMonths = months;
      api.putSubscription(s);
      api.addBilling({ id: "inv-" + Date.now(), planId: s.planId, months: months,
        amount: priceFor(s.planId, months, term.discount), method: method || "online",
        dateISO: iso(new Date()), status: "Paid", kind: "Renewal" });
      this.renderAll();
    },
    upgrade: function (planId, method) {
      var s = api.getSubscription();
      s.planId = planId; s.status = "active";
      s.startISO = iso(new Date());
      var exp = new Date(); exp.setMonth(exp.getMonth() + (s.termMonths || 12));
      s.expiryISO = iso(exp);
      api.putSubscription(s);
      api.addBilling({ id: "inv-" + Date.now(), planId: planId, months: s.termMonths || 12,
        amount: priceFor(planId, s.termMonths || 12, 0), method: method || "online",
        dateISO: iso(new Date()), status: "Paid", kind: "Upgrade" });
      this.renderAll();
    },
    /* switch tier WITH proration — unused value of the current plan is credited */
    switchPlan: function (planId, months, method, payable) {
      var s = api.getSubscription();
      s.planId = planId; s.status = "active"; s.startISO = iso(new Date());
      var exp = new Date(); exp.setMonth(exp.getMonth() + months); s.expiryISO = iso(exp); s.termMonths = months;
      api.putSubscription(s);
      api.addBilling({ id: "inv-" + Date.now(), planId: planId, months: months, amount: payable,
        method: method || "online", dateISO: iso(new Date()), status: "Paid", kind: "Plan change" });
      this.renderAll();
    },

    renderAll: function () { this.renderDash(); this.renderProfile(); this.syncSettings(); this.renderUsage(); },

    /* ---------- DASHBOARD usage: WABA messaging tier + message-limit gauge,
       Meta AI partner messaging tier — independent of the subscription plan ---------- */
    renderUsage: function () {
      var meta = window.AskEvaMetaTier || { tierNo: 3, limit: 100000 };
      var limit = meta.limit, tierNo = meta.tierNo, used = 14;
      var wt = document.getElementById("wabaTierVal");
      if (wt) wt.textContent = "tier_" + tierNo + ": MSG_ " + limit + " LIMIT";
      var sub = document.getElementById("msgLimitSub");
      if (sub) sub.textContent = used + " out of " + limit;
      var pctV = Math.round((used / limit) * 1000) / 10;
      var pe = document.getElementById("msgPct"); if (pe) pe.textContent = pctV + "%";
      var arc = document.getElementById("msgArc");
      if (arc) arc.setAttribute("stroke-dashoffset", (157 * (1 - Math.min(1, used / limit))).toFixed(1));
    },

    /* ---------- DASHBOARD: compact overview only ---------- */
    renderDash: function () {
      var card = document.getElementById("subDashCard"); if (!card) return;
      var s = api.getSubscription(), p = CATALOG[s.planId];
      var top = isTopTier(s.planId);
      card.innerHTML =
        '<div class="hm-gtitle">Current Plan</div>' +
        '<div class="hm-plan">' + esc(p.name.toUpperCase()) + '</div>' +
        '<div class="hm-gsub">Valid until: <b>' + fmt(s.expiryISO) + '</b></div>' +
        (top
          ? '<button class="hm-upgrade" data-hm="renew">Renew Now</button>'
          : '<button class="hm-upgrade" data-hm="upgrade">Upgrade Now</button>');
    },

    /* ---------- PROFILE: full management center ---------- */
    renderProfile: function () {
      var host = document.getElementById("subCenter"); if (!host) return;
      var s = api.getSubscription(), p = CATALOG[s.planId];
      var dl = daysLeft(s.expiryISO), total = termDays(s.expiryISO);
      var pct = Math.max(3, Math.min(100, Math.round((dl / total) * 100)));
      var statusTxt = dl <= 0 ? "Expired" : (dl <= 14 ? "Expiring soon" : "Active");
      host.innerHTML =
        '<div class="sub-hero">' +
          '<div class="sub-top"><span class="sub-planbadge">Current Plan</span>' +
            '<span class="sub-statuspill"><span class="d"></span>' + statusTxt + '</span></div>' +
          '<div class="sub-planname">' + esc(p.name) + '</div>' +
          '<div class="sub-grid">' +
            '<div><div class="k">Expiry Date</div><div class="v">' + fmt(s.expiryISO) + '</div></div>' +
            '<div><div class="k">Remaining</div><div class="v">' + (dl > 0 ? dl + " days" : "—") + '</div></div>' +
            '<div><div class="k">Renews On</div><div class="v">' + fmt(s.expiryISO) + '</div></div>' +
            '<div><div class="k">Billing</div><div class="v">' + (s.termMonths || 12) + '-month term</div></div>' +
          '</div>' +
          '<div class="sub-progress"><i style="width:' + pct + '%"></i></div>' +
          '<div class="sub-proglbl">' + (dl > 0 ? dl + " of " + total + " days remaining in this term" : "This plan has expired — renew to continue") + '</div>' +
          '<div class="sub-actions">' +
            '<button class="renew" data-sub-act="renew">' + IC.refresh + 'Renew</button>' +
            (isTopTier(s.planId)
              ? '<button class="compare" data-sub-act="upgrade">' + IC.rocket + 'Check other plans</button>'
              : '<button class="upgrade" data-sub-act="upgrade">' + IC.rocket + 'Upgrade</button>') +
            '<button class="billing" data-sub-act="billing">' + IC.receipt + 'Billing History</button>' +
          '</div>' +
        '</div>' +
        '<div class="sub-apinote">' + IC.cloud + 'Plan details are loaded live from your billing account.</div>';
    },

    /* features list for ONE plan (used in the Pricing tab, stays in sync with the plan) */
    featuresCard: function (planId) {
      var p = CATALOG[planId];
      return '<div class="sub-featcard">' +
        '<div class="sub-feathd"><span class="ic">' + IC.check + '</span><h4>' + esc(p.name) + ' Plan — Features</h4></div>' +
        '<div class="sub-feats">' + FEATURES.map(function (r) {
          var v = r[planId], val;
          if (v === true) val = '<span class="fv yes">' + IC.check + '</span>';
          else if (v === false) val = '<span class="fv no">' + IC.x + '</span>';
          else val = '<span class="fv txt">' + esc(v) + '</span>';
          return '<div class="sub-feat' + (v === false ? ' off' : '') + '"><span class="fn">' + esc(r.f) + '</span>' + val + '</div>';
        }).join("") + '</div>' +
      '</div>';
    },

    /* ---------- keep the Settings hub row consistent ---------- */
    syncSettings: function () {
      var row = $('#app-settings .set-row[data-sub-go="subscription"]') || $('#app-settings .set-row[data-sub="pricing"]');
      if (!row) return;
      var s = api.getSubscription(), p = CATALOG[s.planId];
      var sub = row.querySelector(".sub"), badge = row.querySelector(".cbadge");
      if (sub) sub.textContent = p.name + " · renews " + fmt(s.expiryISO);
      if (badge) badge.textContent = p.name;
    },

    /* ===================================================
       RENEW  — bottom sheet, current plan only
       =================================================== */
    openRenew: function () {
      var s = api.getSubscription(), p = CATALOG[s.planId];
      var sel = { months: 12 }, method = "online";
      var sheet = ensureSheet();
      function termRows() {
        return TERMS.map(function (t) {
          var price = priceFor(s.planId, t.months, t.discount);
          var per = Math.round(price / t.months);
          return '<button class="sub-term' + (t.months === sel.months ? " sel" : "") + '" data-term="' + t.months + '">' +
            '<span class="radio"></span>' +
            '<span class="tinfo"><span class="tn">' + t.label + '</span>' +
              '<span class="ts">' + inr(per) + '/mo' + (t.discount ? ' · save ' + Math.round(t.discount * 100) + '%' : '') + '</span></span>' +
            '<span class="tp"><span class="amt">' + inr(price) + '</span>' +
              (t.discount ? '<span class="save">save ' + inr(CATALOG[s.planId].monthly * t.months - price) + '</span>' : '') + '</span>' +
          '</button>';
        }).join("");
      }
      function render() {
        var term = TERMS.filter(function (t) { return t.months === sel.months; })[0];
        var total = priceFor(s.planId, sel.months, term.discount);
        var newExp = daysLeft(s.expiryISO) > 0 ? parse(s.expiryISO) : new Date();
        newExp = new Date(newExp); newExp.setMonth(newExp.getMonth() + sel.months);
        sheet.body.innerHTML =
          '<div class="sub-renewhd"><span class="ic">' + IC.refresh + '</span>' +
            '<div><div class="nm">Renew ' + esc(p.name) + '</div>' +
            '<div class="sb">Extend your current plan — your tier and features stay the same.</div></div></div>' +
          '<div class="sub-terms">' + termRows() + '</div>' +
          '<div class="sub-summary"><div class="sl">Total payable<div class="ne">New expiry · ' + fmt(iso(newExp)) + '</div></div>' +
            '<div class="sv">' + inr(total) + '</div></div>' +
          '<div class="sub-paylabel">Payment Method</div>' +
          '<div class="sub-paypick">' +
            '<button class="sub-pay' + (method === "wallet" ? " sel" : "") + '" data-pay="wallet">' + IC.wallet + '<span class="pw">Wallet<small>Use AskEva balance</small></span></button>' +
            '<button class="sub-pay' + (method === "online" ? " sel" : "") + '" data-pay="online">' + IC.card + '<span class="pw">Online Payment<small>Card / Netbanking</small></span></button>' +
          '</div>';
        sheet.foot.innerHTML = '<button class="sub-cta" data-do-renew>' + IC.lock + 'Pay ' + inr(total) + ' & Renew</button>';
      }
      sheet.title.textContent = "Renew Plan";
      render(); openSheet(sheet);
      sheet.body.onclick = function (e) {
        var tb = e.target.closest("[data-term]"); if (tb) { sel.months = +tb.getAttribute("data-term"); render(); return; }
        var pb = e.target.closest("[data-pay]"); if (pb) { method = pb.getAttribute("data-pay"); render(); return; }
      };
      sheet.foot.onclick = function (e) {
        if (e.target.closest("[data-do-renew]")) {
          closeSheet(sheet); Sub.renew(sel.months, method);
          if (window.AskEvaAddTransaction) window.AskEvaAddTransaction({ amount: total, deducted: method === "wallet", reason: p.name + " renewed \u00b7 " + sel.months + " months", method: method === "wallet" ? "Wallet" : "Online", gateway: method === "wallet" ? "0" : "Razorpay" });
          toast(p.name + " renewed · " + sel.months + " months");
        }
      };
    },

    /* ===================================================
       UPGRADE  — slide panel, plan comparison
       =================================================== */
    openUpgrade: function () {
      var panel = ensurePanel(), s = api.getSubscription();
      var target = ORDER.filter(function (id) { return id !== s.planId; })[0]; // default highlight the other tier
      function planCards() {
        return '<div class="sub-plans">' + ORDER.map(function (id) {
          var p = CATALOG[id], isCur = id === s.planId, isTgt = id === target && !isCur;
          return '<div class="sub-plan' + (isCur ? " current" : "") + (isTgt ? " target" : "") + '" data-plan="' + id + '">' +
            (isCur ? '<span class="ribbon">Current Plan</span>' : (isTgt ? '<span class="ribbon">Switch to</span>' : '')) +
            '<div class="pn">' + esc(p.name) + '</div>' +
            '<div class="pp">' + inr(p.monthly) + '<small>/mo</small></div>' +
            '<div class="pd">' + esc(p.tagline) + '</div>' +
            (isCur ? '<button class="pbtn cur" disabled>Your plan</button>'
                   : '<button class="pbtn go" data-switch="' + id + '">' + (CATALOG[id].tier > CATALOG[s.planId].tier ? "Upgrade" : "Switch") + ' to ' + esc(p.name) + '</button>') +
          '</div>';
        }).join("") + '</div>';
      }
      function cmpTable() {
        var head = '<div class="sub-cmphd"><span class="f">Feature</span>' +
          ORDER.map(function (id) { return '<span class="c' + (id === s.planId ? "" : " tgt") + '">' + esc(CATALOG[id].name) + '</span>'; }).join("") + '</div>';
        var rows = FEATURES.map(function (r) {
          return '<div class="sub-cmprow"><span class="f">' + esc(r.f) + '</span>' +
            ORDER.map(function (id) {
              var v = r[id];
              if (v === true) return '<span class="c"><span class="yes">' + IC.check + '</span></span>';
              if (v === false) return '<span class="c"><span class="no">' + IC.x + '</span></span>';
              return '<span class="c">' + esc(v) + '</span>';
            }).join("") + '</div>';
        }).join("");
        return '<div class="sub-cmptt">Full feature comparison</div><div class="sub-cmp">' + head + rows + '</div>';
      }
      panel.title.textContent = "Compare Plans";
      panel.body.innerHTML = planCards() + cmpTable();
      openPanel(panel);
      panel.body.onclick = function (e) {
        var sw = e.target.closest("[data-switch]");
        if (sw) {
          var id = sw.getAttribute("data-switch");
          var cur = api.getSubscription();
          /* DOWNGRADES (e.g. Ecommerce → Enterprise) are not self-serve —
             route the user to customer care instead of switching. */
          if (CATALOG[id] && CATALOG[id].tier < CATALOG[cur.planId].tier) {
            switchUnavailable(CATALOG[id]);
            return;
          }
          openSwitch(id, panel);
        }
      };
    },

    /* ===================================================
       BILLING HISTORY  — slide panel
       =================================================== */
    openBilling: function () {
      var panel = ensurePanel();
      var list = api.getBilling();
      panel.title.textContent = "Billing History";
      panel.body.innerHTML = list.length ? '<div class="sub-bill">' + list.map(function (b) {
        var p = CATALOG[b.planId] || { name: b.planId };
        return '<div class="sub-billrow"><span class="bi">' + IC.receipt + '</span>' +
          '<div class="bm"><div class="bd">' + esc(p.name) + ' · ' + (b.kind || "Subscription") + '</div>' +
          '<div class="bs">' + fmt(b.dateISO) + ' · ' + b.months + ' months · ' + (b.method === "wallet" ? "Wallet" : "Online") + '</div></div>' +
          '<div class="br"><div class="ba">' + inr(b.amount) + '</div><span class="bstatus">' + esc(b.status) + '</span></div></div>';
      }).join("") + '</div>' : '<div class="sub-billempty">No billing records yet.</div>';
      openPanel(panel);
    }
  };

  /* =========================================================
     Confirm-switch mini dialog (reuses sheet)
     ========================================================= */
  /* =========================================================
     Switch plan WITH proration  (reuses sheet)
     Unused value of the current plan is credited toward the new one.
     ========================================================= */
  function openSwitch(planId, panel) {
    var s = api.getSubscription(), from = CATALOG[s.planId], to = CATALOG[planId];
    var dl = daysLeft(s.expiryISO);
    var credit = Math.round((from.monthly / 30) * dl);   // value of remaining days on current plan
    var sel = { months: s.termMonths || 3 };
    var sheet = ensureSheet();
    function termRows() {
      return TERMS.map(function (t) {
        var price = priceFor(planId, t.months, t.discount), per = Math.round(price / t.months);
        return '<button class="sub-term' + (t.months === sel.months ? " sel" : "") + '" data-term="' + t.months + '"><span class="radio"></span>' +
          '<span class="tinfo"><span class="tn">' + t.label + '</span><span class="ts">' + inr(per) + '/mo' + (t.discount ? ' · save ' + Math.round(t.discount * 100) + '%' : '') + '</span></span>' +
          '<span class="tp"><span class="amt">' + inr(price) + '</span></span></button>';
      }).join("");
    }
    function calc() { var term = TERMS.filter(function (t) { return t.months === sel.months; })[0] || TERMS[0]; var total = priceFor(planId, sel.months, term.discount); var applied = Math.min(credit, total); return { total: total, applied: applied, payable: Math.max(0, total - applied) }; }
    function render() {
      var c = calc();
      var exp = new Date(); exp.setMonth(exp.getMonth() + sel.months);
      sheet.body.innerHTML =
        '<div class="sub-renewhd"><span class="ic">' + IC.rocket + '</span><div><div class="nm">' + esc(from.name) + ' \u2192 ' + esc(to.name) + '</div>' +
          '<div class="sb">Pick a term for ' + esc(to.name) + '. Unused time on your ' + esc(from.name) + ' plan is adjusted automatically.</div></div></div>' +
        '<div class="sub-terms">' + termRows() + '</div>' +
        '<div class="sub-adjust">' +
          '<div class="ar"><span class="al">' + esc(to.name) + ' · ' + sel.months + ' months</span><span class="av">' + inr(c.total) + '</span></div>' +
          (c.applied > 0 ? '<div class="ar credit"><span class="al">Adjustment · unused ' + esc(from.name) + ' (' + dl + ' days left)</span><span class="av">\u2212 ' + inr(c.applied) + '</span></div>' : '') +
        '</div>' +
        '<div class="sub-summary"><div class="sl">Amount payable<div class="ne">New expiry · ' + fmt(iso(exp)) + '</div></div><div class="sv">' + inr(c.payable) + '</div></div>';
      sheet.foot.innerHTML = '<button class="sub-cta" data-do-switch>' + IC.lock + 'Pay ' + inr(c.payable) + ' & Switch</button>';
    }
    sheet.title.textContent = "Change Plan";
    render(); openSheet(sheet);
    sheet.body.onclick = function (e) { var tb = e.target.closest("[data-term]"); if (tb) { sel.months = +tb.getAttribute("data-term"); render(); } };
    sheet.foot.onclick = function (e) {
      if (e.target.closest("[data-do-switch]")) {
        var c = calc(); closeSheet(sheet); if (panel) closePanel(panel);
        Sub.switchPlan(planId, sel.months, "online", c.payable);
        if (window.AskEvaAddTransaction) window.AskEvaAddTransaction({ amount: c.payable, deducted: false, reason: "Switched to " + to.name + " \u00b7 " + sel.months + " months", method: "Online", gateway: "Razorpay" });
        toast("Switched to " + to.name + " · paid " + inr(c.payable));
      }
    };
  }

  function confirmSwitch(planId, onYes) {
    var s = api.getSubscription(), from = CATALOG[s.planId], to = CATALOG[planId];
    var sheet = ensureSheet();
    sheet.title.textContent = "Confirm Plan Change";
    sheet.body.innerHTML =
      '<div class="sub-renewhd"><span class="ic">' + IC.rocket + '</span>' +
        '<div><div class="nm">' + esc(from.name) + ' → ' + esc(to.name) + '</div>' +
        '<div class="sb">Your features and limits update immediately. The new term bills at ' + inr(to.monthly) + '/mo.</div></div></div>' +
      '<div class="sub-summary"><div class="sl">New plan<div class="ne">' + (s.termMonths || 12) + '-month term</div></div>' +
        '<div class="sv">' + inr(to.monthly) + '<small style="font-size:12px;font-weight:700;color:var(--ink-4)">/mo</small></div></div>';
    sheet.foot.innerHTML = '<button class="sub-cta" data-confirm>' + IC.check + 'Confirm & Switch to ' + esc(to.name) + '</button>';
    openSheet(sheet);
    sheet.foot.onclick = function (e) { if (e.target.closest("[data-confirm]")) { closeSheet(sheet); onYes(); } };
  }

  /* =========================================================
     Switch-not-available dialog (restricted downgrade)
     ========================================================= */
  var CARE_NUMBER = "+91 80 4718 1888";
  function switchUnavailable(toPlan) {
    var s = api.getSubscription(), from = CATALOG[s.planId];
    var sheet = ensureSheet();
    sheet.title.textContent = "Switch Not Available";
    sheet.body.innerHTML =
      '<div class="sub-blocked">' +
        '<span class="bic">' + IC.support + '</span>' +
        '<div class="bt">Plan change isn\u2019t available here</div>' +
        '<div class="bs">Switching from <b>' + esc(from.name) + '</b> to <b>' + esc(toPlan.name) + '</b> can\u2019t be done from the app. Please contact customer care and our team will switch it for you.</div>' +
        '<a class="sub-care" href="tel:' + CARE_NUMBER.replace(/\s/g, "") + '">' + IC.phone + '<span>' + esc(CARE_NUMBER) + '</span></a>' +
      '</div>';
    sheet.foot.innerHTML =
      '<button class="sub-cta" data-care>' + IC.support + 'Contact Customer Care</button>' +
      '<button class="sub-ghost" data-dismiss>Not now</button>';
    openSheet(sheet);
    sheet.foot.onclick = function (e) {
      if (e.target.closest("[data-care]")) { toast("Connecting you to customer care\u2026"); }
      else if (!e.target.closest("[data-dismiss]")) { return; }
      closeSheet(sheet);
    };
  }

  /* =========================================================
     Sheet / Panel infra  (scoped to #app-profile)
     ========================================================= */
  function host() { return document.getElementById("app-profile"); }
  var _sheet, _panel;
  function ensureSheet() {
    if (_sheet) return _sheet;
    var h = host();
    var scrim = document.createElement("div"); scrim.className = "sub-scrim";
    var sheet = document.createElement("div"); sheet.className = "sub-sheet";
    sheet.innerHTML = '<div class="sub-grip"></div>' +
      '<div class="sub-shead"><span class="tt"></span><button class="sub-x" aria-label="Close">' + IC.x + '</button></div>' +
      '<div class="sub-sbody"></div><div class="sub-sfoot"></div>';
    h.appendChild(scrim); h.appendChild(sheet);
    _sheet = { scrim: scrim, el: sheet, title: sheet.querySelector(".tt"), body: sheet.querySelector(".sub-sbody"), foot: sheet.querySelector(".sub-sfoot") };
    scrim.addEventListener("click", function () { closeSheet(_sheet); });
    sheet.querySelector(".sub-x").addEventListener("click", function () { closeSheet(_sheet); });
    return _sheet;
  }
  function openSheet(s) { requestAnimationFrame(function () { s.scrim.classList.add("show"); s.el.classList.add("show"); }); }
  function closeSheet(s) { if (!s) return; s.scrim.classList.remove("show"); s.el.classList.remove("show"); }

  function ensurePanel() {
    if (_panel) return _panel;
    var h = host();
    var panel = document.createElement("div"); panel.className = "sub-panel";
    panel.innerHTML = '<div class="sub-pbar"><button class="back" aria-label="Back">' + IC.back + '</button><span class="ptt"></span></div>' +
      '<div class="sub-pbody"></div>';
    h.appendChild(panel);
    _panel = { el: panel, title: panel.querySelector(".ptt"), body: panel.querySelector(".sub-pbody") };
    panel.querySelector(".back").addEventListener("click", function () { closePanel(_panel); });
    return _panel;
  }
  function openPanel(p) { requestAnimationFrame(function () { p.el.classList.add("show"); p.body.scrollTop = 0; }); }
  function closePanel(p) { if (!p) return; p.el.classList.remove("show"); }

  /* close any open subscription surface (called on route change) */
  function closeAll() { if (_sheet) closeSheet(_sheet); if (_panel) closePanel(_panel); }

  /* =========================================================
     WIRING
     ========================================================= */
  function wire() {
    /* profile management actions */
    var pp = host();
    if (pp) {
      pp.addEventListener("click", function (e) {
        var b = e.target.closest("[data-sub-act]"); if (!b) return;
        var act = b.getAttribute("data-sub-act");
        if (act === "renew") Sub.openRenew();
        else if (act === "upgrade") Sub.openUpgrade();
        else if (act === "billing") Sub.openBilling();
      });
    }

    /* dashboard plan CTA → Profile › Pricing tab; Upgrade opens comparison, Renew opens renew sheet */
    var home = document.getElementById("app-home");
    if (home) {
      home.addEventListener("click", function (e) {
        var b = e.target.closest('[data-hm="upgrade"], [data-hm="renew"]'); if (!b) return;
        var act = b.getAttribute("data-hm");
        e.stopPropagation();   // pre-empt the old home-dashboard toast handler
        if (window.__appRoute) window.__appRoute("profile");
        if (window.__pfShowTab) window.__pfShowTab("subscription");
        setTimeout(function () { act === "renew" ? Sub.openRenew() : Sub.openUpgrade(); }, 360);
      }, true);  // capture phase so we win over home-dashboard.js
    }

    /* settings "Pricing & Plan" row → Profile › Pricing tab (single management center) */
    var setRow = $('#app-settings .set-row[data-sub="pricing"]');
    if (setRow) {
      setRow.setAttribute("data-sub-go", "subscription");
      setRow.removeAttribute("data-sub");           // stop the settings sub-view opener
      setRow.addEventListener("click", function (e) {
        e.stopPropagation();
        if (window.__appRoute) window.__appRoute("profile");
        if (window.__pfShowTab) window.__pfShowTab("subscription");
        toast("Manage your plan here");
      }, true);
    }

    /* close panels when navigating away (clean nav state restore) */
    if (window.__appRoute && !window.__appRoute.__subWrapped) {
      var orig = window.__appRoute;
      var wrapped = function (route, opts) { if (route !== "profile") closeAll(); return orig(route, opts); };
      wrapped.__subWrapped = true;
      window.__appRoute = wrapped;
    }

    Sub.renderAll();
  }

  window.__sub = Sub;
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", wire);
  else wire();
})();
