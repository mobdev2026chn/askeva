/* AskEva — Overall (home) dashboard interactions + Add Fund sheet */
(function () {
  "use strict";
  var $ = function (s, r) { return (r || document).querySelector(s); };
  var pane = document.getElementById("app-home");
  if (!pane) return;

  var toastT;
  function toast(msg) {
    var t = document.getElementById("toast"); if (!t) return;
    t.textContent = msg; t.style.opacity = "1"; t.style.transform = "translateX(-50%) translateY(0)";
    clearTimeout(toastT); toastT = setTimeout(function () { t.style.opacity = "0"; t.style.transform = "translateX(-50%) translateY(20px)"; }, 1800);
  }

  var X = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M18 6 6 18M6 6l12 12"/></svg>';
  var CARD = '<svg viewBox="0 0 24 24" fill="none" stroke="#2BA84A" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="5" width="18" height="14" rx="2.5"/><path d="M3 10h18M7 15h4"/></svg>';
  var UPI_IC = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="6" y="2.5" width="12" height="19" rx="2.5"/><path d="M10.5 6.5h3M12 17.5h.01"/></svg>';
  var BANK_IC = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 9.5 12 4l9 5.5M4.5 9.5V19M19.5 9.5V19M8.5 9.5V19M15.5 9.5V19M3 19h18"/></svg>';
  var LOCK = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="4.5" y="10.5" width="15" height="10" rx="2.5"/><path d="M8 10.5V7a4 4 0 0 1 8 0v3.5"/></svg>';
  var BACK = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M15 5l-7 7 7 7"/></svg>';
  var CHEVD = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="m6 9 6 6 6-6"/></svg>';
  var BIGTICK = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><path d="m5 12 5 5 9-11"/></svg>';
  var UPLOAD_IC = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 16V4M7 9l5-5 5 5"/><path d="M5 16v2.5A1.5 1.5 0 0 0 6.5 20h11a1.5 1.5 0 0 0 1.5-1.5V16"/></svg>';
  var FILE_IC = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14 3H7a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V8z"/><path d="M14 3v5h5"/></svg>';

  /* ---------- sheet ---------- */
  var scrim = document.createElement("div"); scrim.className = "lx-scrim";
  var sheet = document.createElement("div"); sheet.className = "lx-sheetpop";
  pane.appendChild(scrim); pane.appendChild(sheet);
  scrim.addEventListener("click", closeSheet);
  function closeSheet() { scrim.classList.remove("show"); sheet.classList.remove("show"); }

  var MIN = 3000;
  function inr(v, dec) { return "&#8377; " + (dec ? v.toFixed(2) : Math.round(v).toLocaleString("en-IN")); }

  function bumpWallet(by) {
    var el = $(".hm-balance .amt", pane); if (!el) return;
    var cur = parseFloat((el.textContent || "").replace(/[^\d.]/g, "")) || 0;
    el.textContent = "INR " + (cur + by).toFixed(2);
  }

  /* shared processing -> success overlay used by gateway, bank transfer & UPI */
  function runSuccess(opts) {
    var host = opts.sheetEl || sheet;
    var close = opts.close || closeSheet;
    var ov = host.querySelector("#pgOv");
    if (!ov) { ov = document.createElement("div"); ov.className = "pg-overlay"; ov.id = "pgOv"; host.appendChild(ov); }
    ov.innerHTML = '<div class="pg-spin"></div><div class="pg-ovt">' + opts.procT + '</div><div class="pg-ovs">' + opts.procS + '</div>';
    ov.classList.add("show");
    setTimeout(function () {
      ov.innerHTML = '<div class="pg-tick">' + BIGTICK + '</div><div class="pg-ovt">' + opts.okT + '</div><div class="pg-ovs">' + opts.okS + '</div>';
      if (opts.bump !== false) bumpWallet(opts.amount);
      if (window.AskEvaAddTransaction && opts.amount) window.AskEvaAddTransaction({ amount: opts.amount, deducted: false, reason: opts.txReason || "Wallet recharge", method: opts.txMethod || "Online", gateway: opts.txGateway || "Razorpay" });
      if (typeof opts.onDone === "function") opts.onDone();
    }, 1900);
    setTimeout(function () { close(); toast(opts.toast); }, 3300);
  }

  /* build a fresh sheet/scrim overlay on any host (for reusing the gateway outside #app-home) */
  function makeOverlay(hostEl) {
    var sc = document.createElement("div"); sc.className = "lx-scrim";
    var sh = document.createElement("div"); sh.className = "lx-sheetpop";
    (hostEl || pane).appendChild(sc); (hostEl || pane).appendChild(sh);
    function close() { sc.classList.remove("show"); sh.classList.remove("show"); setTimeout(function () { if (sc.parentNode) sc.remove(); if (sh.parentNode) sh.remove(); }, 300); }
    sc.addEventListener("click", close);
    return { sheet: sh, scrim: sc, close: close };
  }

  /* AskEva collection account / UPI (demo data) */
  var BANK = {
    name: "AskEva Technologies Pvt Ltd",
    acc: "50200082341197",
    ifsc: "HDFC0000123",
    bank: "HDFC Bank",
    branch: "Koramangala, Bengaluru",
    type: "Current"
  };
  var UPI_VPA = "askeva.payments@hdfcbank";

  var INFO = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="M12 11v5M12 7.5h.01"/></svg>';
  var COPY = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="9" y="9" width="11" height="11" rx="2.2"/><path d="M5 15V5a2 2 0 0 1 2-2h10"/></svg>';
  var TICK = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><path d="m5 12 4 4 10-11"/></svg>';

  function fallbackCopy(t) {
    var ta = document.createElement("textarea"); ta.value = t; ta.style.position = "fixed"; ta.style.opacity = "0";
    document.body.appendChild(ta); ta.select();
    try { document.execCommand("copy"); } catch (e) {}
    document.body.removeChild(ta);
  }
  function copyText(t) {
    if (navigator.clipboard && navigator.clipboard.writeText) {
      return navigator.clipboard.writeText(t).catch(function () { fallbackCopy(t); });
    }
    fallbackCopy(t); return Promise.resolve();
  }
  function copyRow(k, v) {
    return '<div class="af-brow"><span class="k">' + k + '</span><span class="v">' + v + '</span>' +
      '<button class="af-copy" type="button" data-copy="' + v + '" aria-label="Copy ' + k + '">' + COPY + '</button></div>';
  }

  /* per-method body html */
  function methodBody(m) {
    if (m === "bank") {
      return '<div class="lx-field"><label>Challan Date</label>' +
            '<input class="lx-input" id="afChDate" type="date"></div>' +
        '<div class="lx-field"><label>Payment Mode</label>' +
            '<select class="lx-select" id="afPayMode">' +
              '<option value="" disabled selected>Select Payment Mode</option>' +
              '<option>NEFT</option><option>RTGS</option><option>IMPS</option>' +
              '<option>Cheque</option><option>Cash Deposit</option><option>Demand Draft</option>' +
            '</select></div>' +
        '<div class="lx-field"><label>Reference Number</label>' +
            '<input class="lx-input" id="afRef" type="text" placeholder="Reference number"></div>' +
        '<div class="lx-field"><label>Account Number</label>' +
            '<select class="lx-select" id="afAccNum">' +
              '<option value="" disabled selected>Select Account</option>' +
              '<option>' + BANK.acc + ' \u00b7 HDFC Bank</option>' +
              '<option>10923456789012 \u00b7 ICICI Bank</option>' +
            '</select></div>' +
        '<div class="lx-field"><label>Upload Challan</label>' +
          '<label class="af-upload" id="afUpWrap">' +
            '<input type="file" id="afChallan" accept=".jpg,.jpeg,.png,.pdf" hidden>' +
            '<span class="af-uptext" id="afUpText">' + UPLOAD_IC + 'Upload</span>' +
          '</label>' +
          '<div class="af-uphint">Allowed jpg, png and pdf. Max size of 2 MB</div>' +
        '</div>' +
        '<div class="hm-fundgroup">' +
          '<div class="hm-fundrow"><span>GST (18% on Charges)</span><b id="afGst">' + inr(0, true) + '</b></div>' +
          '<div class="hm-fundrow"><span>Total Deduction</span><b id="afTd">' + inr(0, true) + '</b></div>' +
          '<div class="hm-fundrow total"><span class="lbl">Wallet Amount</span><b id="afWal">' + inr(0, true) + '</b></div>' +
        '</div>';
    }
    if (m === "upi") {
      var qr = "https://api.qrserver.com/v1/create-qr-code/?size=220x220&qzone=1&data=" +
        encodeURIComponent("upi://pay?pa=" + UPI_VPA + "&pn=AskEva&cu=INR");
      return '<div class="af-note">' + INFO + '<span>Scan the QR or pay to the UPI ID below from any UPI app, then enter the UPI reference number to confirm. No gateway charges apply.</span></div>' +
        '<div class="af-qr">' +
          '<img src="' + qr + '" alt="UPI QR code" loading="lazy">' +
          '<div class="vpa">' + UPI_VPA + '<button class="af-copy" type="button" data-copy="' + UPI_VPA + '" aria-label="Copy UPI ID">' + COPY + '</button></div>' +
          '<div class="cap">Payee: ' + BANK.name + '</div>' +
        '</div>' +
        '<div class="lx-field" style="margin-top:16px"><label>UPI Transaction / Reference ID</label>' +
          '<input class="lx-input" id="afRef" type="text" placeholder="12-digit UPI reference no."></div>' +
        '<div class="hm-fundgroup">' +
          '<div class="hm-fundrow"><span>Paid amount</span><b id="afAmt2">' + inr(0) + '</b></div>' +
          '<div class="hm-fundrow"><span>Gateway charges</span><b>' + inr(0, true) + '</b></div>' +
          '<div class="hm-fundrow total"><span class="lbl">Total amount to pay</span><b id="afPay">' + inr(0) + '</b></div>' +
        '</div>';
    }
    /* online (default) */
    return '<div class="hm-fundgroup">' +
        '<div class="hm-fundrow"><span>Gateway Charges (2.5%)</span><b id="afGw">' + inr(0, true) + '</b></div>' +
        '<div class="hm-fundrow"><span>GST (18% on Charges)</span><b id="afGst">' + inr(0, true) + '</b></div>' +
        '<div class="hm-fundrow"><span>Total charges</span><b id="afTc">' + inr(0, true) + '</b></div>' +
        '<div class="hm-fundrow"><span>Wallet amount</span><b id="afWal">' + inr(0) + '</b></div>' +
        '<div class="hm-fundrow total"><span class="lbl">Total amount to pay</span><b id="afPay">' + inr(0) + '</b></div>' +
      '</div>';
  }

  function btnLabel(m) {
    if (m === "bank") return "Upload Challan";
    if (m === "upi") return "I\u2019ve Paid via UPI";
    return "Proceed To Pay";
  }

  function openAddFund() {
    var method = "online";
    sheet.innerHTML = '<div class="lx-grip"></div>' +
      '<div class="lx-shead"><span class="lx-fundicon">' + CARD + '</span><span class="tt">Add Fund</span><button class="x" data-x>' + X + '</button></div>' +
      '<div class="lx-sbody">' +
        '<div class="lx-field"><label>Type of payment</label><select class="lx-select" id="afType">' +
          '<option value="online">Online Payment - UPI, Cards, NetBanking</option>' +
          '<option value="bank">Bank Transaction</option>' +
        '</select></div>' +
        '<div class="lx-field"><label>Amount</label><input class="lx-input" id="afAmount" type="number" inputmode="numeric" placeholder="Minimum Recharge value is 3000"></div>' +
        '<div id="afDyn">' + methodBody(method) + '</div>' +
      '</div>' +
      '<div class="lx-sfoot"><button class="lx-btn primary" data-pay>' + btnLabel(method) + '</button></div>';
    requestAnimationFrame(function () { scrim.classList.add("show"); sheet.classList.add("show"); });

    var typeSel = $("#afType", sheet);
    var amt = $("#afAmount", sheet);
    var payBtn = $("[data-pay]", sheet);

    function recompute() {
      var a = parseFloat(amt.value) || 0;
      if (method === "online") {
        var gw = a * 0.025, gst = gw * 0.18, tc = gw + gst, pay = a + tc;
        $("#afGw", sheet).innerHTML = inr(gw, true);
        $("#afGst", sheet).innerHTML = inr(gst, true);
        $("#afTc", sheet).innerHTML = inr(tc, true);
        $("#afWal", sheet).innerHTML = inr(a);
        $("#afPay", sheet).innerHTML = inr(pay, true);
      } else if (method === "bank") {
        var ch = a * 0.025, g = ch * 0.18, td = ch + g, wal = Math.max(0, a - td);
        var gEl = $("#afGst", sheet); if (gEl) gEl.innerHTML = inr(g, true);
        var tdEl = $("#afTd", sheet); if (tdEl) tdEl.innerHTML = inr(td, true);
        var wEl = $("#afWal", sheet); if (wEl) wEl.innerHTML = inr(wal, true);
      } else {
        var amt2 = $("#afAmt2", sheet); if (amt2) amt2.innerHTML = inr(a);
        var p = $("#afPay", sheet); if (p) p.innerHTML = inr(a);
      }
    }

    function rebuild() {
      $("#afDyn", sheet).innerHTML = methodBody(method);
      payBtn.textContent = btnLabel(method);
      recompute();
    }

    typeSel.addEventListener("change", function () { method = typeSel.value; rebuild(); });
    amt.addEventListener("input", recompute);

    // copy buttons (delegated)
    $("#afDyn", sheet).addEventListener("click", function (e) {
      var b = e.target.closest("[data-copy]"); if (!b) return;
      copyText(b.getAttribute("data-copy")).then(function () {
        var old = b.innerHTML; b.classList.add("ok"); b.innerHTML = TICK; toast("Copied to clipboard");
        setTimeout(function () { b.classList.remove("ok"); b.innerHTML = old; }, 1200);
      });
    });

    // challan upload (delegated change)
    $("#afDyn", sheet).addEventListener("change", function (e) {
      var f = e.target.closest("#afChallan"); if (!f) return;
      var wrap = $("#afUpWrap", sheet), txt = $("#afUpText", sheet);
      if (!f.files || !f.files.length) { return; }
      var file = f.files[0];
      var okType = /\.(jpe?g|png|pdf)$/i.test(file.name) || /^(image\/jpeg|image\/png|application\/pdf)$/.test(file.type);
      if (!okType) {
        toast("Only JPG, PNG or PDF files are allowed"); f.value = "";
        if (wrap) wrap.classList.remove("has");
        if (txt) txt.innerHTML = UPLOAD_IC + "Upload";
        return;
      }
      if (file.size > 2 * 1024 * 1024) {
        toast("File too large \u2014 max size is 2 MB"); f.value = "";
        if (wrap) wrap.classList.remove("has");
        if (txt) txt.innerHTML = UPLOAD_IC + "Upload";
        return;
      }
      if (wrap) wrap.classList.add("has");
      if (txt) txt.innerHTML = FILE_IC + '<span class="fn">' + file.name + '</span>';
    });

    $("[data-x]", sheet).addEventListener("click", closeSheet);
    payBtn.addEventListener("click", function () {
      var a = parseFloat(amt.value) || 0;
      if (a < MIN) { toast("Minimum recharge value is \u20B9" + MIN); amt.focus(); return; }
      if (method === "online") {
        closeSheet();
        setTimeout(function () { openGateway(a); }, 230);
        return;
      }
      if (method === "bank") {
        var pm = $("#afPayMode", sheet), acc = $("#afAccNum", sheet),
            file = $("#afChallan", sheet), bref = $("#afRef", sheet);
        if (!pm || !pm.value) { toast("Select the payment mode"); return; }
        if (!bref || bref.value.trim().length < 4) { toast("Enter the transaction reference number"); if (bref) bref.focus(); return; }
        if (!acc || !acc.value) { toast("Select the account number"); return; }
        if (!file || !file.files || !file.files.length) { toast("Upload the challan (jpg, png or pdf)"); return; }
        var chf = file.files[0];
        if (!(/\.(jpe?g|png|pdf)$/i.test(chf.name) || /^(image\/jpeg|image\/png|application\/pdf)$/.test(chf.type))) { toast("Only JPG, PNG or PDF files are allowed"); return; }
        var net = Math.max(0, a - a * 0.025 * 1.18);
        var netStr = "\u20B9 " + Math.round(net).toLocaleString("en-IN");
        runSuccess({ amount: net,
          procT: "Uploading challan\u2026", procS: "Submitting for verification",
          okT: "Challan Submitted", okS: netStr + " will be credited after verification",
          toast: "Challan uploaded successfully" });
        return;
      }
      // UPI
      var ref = $("#afRef", sheet);
      var refVal = ref ? ref.value.trim() : "";
      if (refVal.length < 6) {
        toast("Enter your UPI reference number");
        if (ref) ref.focus(); return;
      }
      var amtStr = "\u20B9 " + Math.round(a).toLocaleString("en-IN");
      runSuccess({ amount: a,
        procT: "Verifying payment\u2026", procS: "Confirming with your UPI app",
        okT: "Payment Successful", okS: amtStr + " added to your wallet",
        toast: amtStr + " added to wallet successfully" });
    });
  }

  /* ---------- payment gateway (stage 2) ---------- */
  var GPAY_ICON = '<svg viewBox="0 0 48 48" width="34" height="34"><rect width="48" height="48" rx="11" fill="#fff"/><path fill="#4285F4" d="M34.6 24.3c0-.8-.07-1.5-.2-2.3H24v4.5h6c-.26 1.4-1.05 2.6-2.25 3.4v2.8h3.6c2.1-1.95 3.25-4.8 3.25-8.4z"/><path fill="#34A853" d="M24 35c3.05 0 5.6-1 7.45-2.75l-3.6-2.8c-1 .67-2.3 1.07-3.85 1.07-2.95 0-5.45-2-6.35-4.68h-3.7v2.9C15.8 32.6 19.6 35 24 35z"/><path fill="#FBBC05" d="M17.65 25.84a6.6 6.6 0 0 1 0-3.68v-2.9h-3.7a11 11 0 0 0 0 9.48l3.7-2.9z"/><path fill="#EA4335" d="M24 17.46c1.66 0 3.15.57 4.32 1.69l3.2-3.2C29.6 14.1 27.05 13 24 13c-4.4 0-8.2 2.4-10.05 5.96l3.7 2.9c.9-2.68 3.4-4.4 6.35-4.4z"/></svg>';
  var PHONEPE_ICON = '<svg viewBox="0 0 48 48" width="34" height="34"><rect width="48" height="48" rx="11" fill="#5F259F"/><text x="24" y="30" text-anchor="middle" font-family="Arial,Helvetica,sans-serif" font-size="19" font-weight="700" fill="#fff">Pe</text></svg>';
  var PAYTM_ICON = '<svg viewBox="0 0 48 48" width="34" height="34"><rect x="1" y="1" width="46" height="46" rx="10" fill="#fff" stroke="#E4E8E1"/><text x="24" y="29" text-anchor="middle" font-family="Arial,Helvetica,sans-serif" font-size="13.5" font-weight="800"><tspan fill="#012E58">pay</tspan><tspan fill="#00B9F1">tm</tspan></text></svg>';
  var BHIM_ICON = '<svg viewBox="0 0 48 48" width="34" height="34"><rect width="48" height="48" rx="11" fill="#E2761B"/><text x="24" y="32" text-anchor="middle" font-family="Arial,Helvetica,sans-serif" font-size="23" font-weight="700" fill="#fff">\u20B9</text></svg>';
  var UPI_APPS = [
    { id: "gpay", n: "GPay", c: "#1A73E8", t: "G", svg: GPAY_ICON },
    { id: "phonepe", n: "PhonePe", c: "#5F259F", t: "Pe", svg: PHONEPE_ICON },
    { id: "paytm", n: "Paytm", c: "#012E58", t: "P", svg: PAYTM_ICON },
    { id: "bhim", n: "BHIM", c: "#E2761B", t: "B", svg: BHIM_ICON }
  ];
  var NETBANKS = [
    { id: "hdfc", n: "HDFC", c: "#004C8F", t: "H" },
    { id: "icici", n: "ICICI", c: "#AE282E", t: "I" },
    { id: "sbi", n: "SBI", c: "#22409A", t: "S" },
    { id: "axis", n: "Axis", c: "#97144D", t: "A" },
    { id: "kotak", n: "Kotak", c: "#ED1C24", t: "K" },
    { id: "yes", n: "Yes Bank", c: "#00518F", t: "Y" }
  ];

  function luhn(s) {
    var sum = 0, alt = false;
    for (var i = s.length - 1; i >= 0; i--) {
      var d = parseInt(s.charAt(i), 10);
      if (alt) { d *= 2; if (d > 9) d -= 9; }
      sum += d; alt = !alt;
    }
    return s.length >= 12 && sum % 10 === 0;
  }
  function cardBrand(n) {
    if (/^4/.test(n)) return "VISA";
    if (/^(5[1-5]|2[2-7])/.test(n)) return "Mastercard";
    if (/^3[47]/.test(n)) return "Amex";
    if (/^(60|65|81|82|508)/.test(n)) return "RuPay";
    return "";
  }

  function walletSuccess(amount) {
    var amtStr = "\u20B9 " + Math.round(amount).toLocaleString("en-IN");
    return { procT: "Processing payment\u2026", procS: "Please don\u2019t press back or close",
      okT: "Payment Successful", okS: amtStr + " added to your wallet",
      toast: amtStr + " added to wallet successfully" };
  }

  function defaultGwEnv() {
    return { sheet: sheet, scrim: scrim, close: closeSheet, back: function () { closeSheet(); setTimeout(openAddFund, 230); } };
  }

  function openGateway(amount, opts) {
    opts = opts || {};
    var env = opts.env || defaultGwEnv();
    var sheet = env.sheet, scrim = env.scrim, closeSheet = env.close;   // shadow module refs for all nested fns
    var charge = opts.charge !== false;                                  // default true (Add Fund wallet recharge)
    var total = charge ? amount + amount * 0.025 * 1.18 : amount;
    var headNm = opts.headNm || "AskEva Technologies";
    var headSub = opts.headSub || "Wallet recharge";
    var totalLabel = opts.totalLabel || "Total payable";
    var open = "upi";         // currently expanded method
    var upiApp = "";         // selected upi app
    var bankSel = "";        // selected netbank

    function methodCard(id, ic, title, sub, body) {
      return '<div class="pg-method' + (open === id ? " open" : "") + '" data-m="' + id + '">' +
        '<button class="pg-mhead" type="button" data-mhead="' + id + '">' +
          '<span class="mi">' + ic + '</span>' +
          '<span class="ml"><span class="t">' + title + '</span><span class="s">' + sub + '</span></span>' +
          '<span class="chev">' + CHEVD + '</span>' +
        '</button>' +
        (open === id ? '<div class="pg-mbody">' + body() + '</div>' : '') +
      '</div>';
    }
    function upiBody() {
      return '<div class="pg-apps">' + UPI_APPS.map(function (a) {
          return '<button class="pg-app' + (upiApp === a.id ? " sel" : "") + '" type="button" data-app="' + a.id + '">' +
            (a.svg ? '<span class="ai img">' + a.svg + '</span>' : '<span class="ai" style="background:' + a.c + '">' + a.t + '</span>') +
            '<span class="an">' + a.n + '</span></button>';
        }).join("") + '</div>' +
        '<div class="pg-or">OR PAY USING UPI ID</div>' +
        '<div class="lx-field" style="margin-bottom:2px"><input class="lx-input" id="pgVpa" type="text" placeholder="yourname@bank" autocomplete="off"></div>';
    }
    function cardBody() {
      return '<div class="pg-cardwrap">' +
          '<div class="lx-field"><label>Card Number</label><input class="lx-input" id="pgNum" type="text" inputmode="numeric" placeholder="1234 5678 9012 3456" maxlength="23" autocomplete="off"><span class="brand" id="pgBrand"></span></div>' +
          '<div class="pg-twocol">' +
            '<div class="lx-field"><label>Expiry</label><input class="lx-input" id="pgExp" type="text" inputmode="numeric" placeholder="MM / YY" maxlength="7" autocomplete="off"></div>' +
            '<div class="lx-field"><label>CVV</label><input class="lx-input" id="pgCvv" type="password" inputmode="numeric" placeholder="123" maxlength="4" autocomplete="off"></div>' +
          '</div>' +
          '<div class="lx-field" style="margin-bottom:2px"><label>Name on Card</label><input class="lx-input" id="pgName" type="text" placeholder="As printed on card" autocomplete="off"></div>' +
        '</div>';
    }
    function bankBody() {
      return '<div class="pg-banks">' + NETBANKS.map(function (b) {
          return '<button class="pg-bank' + (bankSel === b.id ? " sel" : "") + '" type="button" data-bank="' + b.id + '">' +
            '<span class="bi" style="background:' + b.c + '">' + b.t + '</span><span class="bn">' + b.n + '</span></button>';
        }).join("") + '</div>' +
        '<div class="lx-field" style="margin-bottom:2px"><label>All Banks</label><select class="lx-select" id="pgBankSel">' +
          '<option value="">Select another bank\u2026</option>' +
          '<option value="bob">Bank of Baroda</option><option value="pnb">Punjab National Bank</option>' +
          '<option value="idfc">IDFC First Bank</option><option value="indus">IndusInd Bank</option>' +
          '<option value="federal">Federal Bank</option><option value="rbl">RBL Bank</option>' +
        '</select></div>';
    }

    function renderMethods() {
      return methodCard("upi", UPI_IC, "UPI", "GPay, PhonePe, Paytm, BHIM", upiBody) +
        methodCard("card", CARD, "Credit / Debit Card", "Visa, Mastercard, RuPay, Amex", cardBody) +
        methodCard("bank", BANK_IC, "Net Banking", "All major banks supported", bankBody);
    }

    function shell() {
      sheet.innerHTML = '<div class="lx-grip"></div>' +
        '<div class="lx-shead"><button class="x" data-back aria-label="Back">' + BACK + '</button>' +
          '<span class="tt">Payment</span><button class="x" data-x>' + X + '</button></div>' +
        '<div class="lx-sbody">' +
          '<div class="pg-head"><div class="m"><span class="logo">' + CARD + '</span>' +
            '<span><span class="nm">' + headNm + '</span><span class="sub">' + headSub + '</span></span></div>' +
            '<div class="amt"><span class="v">&#8377; ' + total.toFixed(2) + '</span><span class="k">' + totalLabel + '</span></div></div>' +
          '<div class="pg-seclabel">Choose payment method</div>' +
          '<div id="pgMethods">' + renderMethods() + '</div>' +
          '<div class="pg-secure">' + LOCK + ' 256-bit secured payment</div>' +
        '</div>' +
        '<div class="lx-sfoot"><button class="lx-btn primary" data-pgpay>Pay &#8377; ' + total.toFixed(2) + '</button></div>' +
        '<div class="pg-overlay" id="pgOv"></div>';
      wire();
    }

    function refreshMethods() {
      $("#pgMethods", sheet).innerHTML = renderMethods();
      bindMethodInner();
    }

    function bindMethodInner() {
      var num = $("#pgNum", sheet);
      if (num) {
        num.addEventListener("input", function () {
          var raw = num.value.replace(/\D/g, "").slice(0, 19);
          num.value = raw.replace(/(.{4})/g, "$1 ").trim();
          $("#pgBrand", sheet).textContent = cardBrand(raw);
        });
      }
      var exp = $("#pgExp", sheet);
      if (exp) {
        exp.addEventListener("input", function () {
          var r = exp.value.replace(/\D/g, "").slice(0, 4);
          exp.value = r.length > 2 ? r.slice(0, 2) + " / " + r.slice(2) : r;
        });
      }
      var cvv = $("#pgCvv", sheet);
      if (cvv) cvv.addEventListener("input", function () { cvv.value = cvv.value.replace(/\D/g, "").slice(0, 4); });
      var bsel = $("#pgBankSel", sheet);
      if (bsel) bsel.addEventListener("change", function () {
        if (bsel.value) { bankSel = ""; [].forEach.call(sheet.querySelectorAll(".pg-bank"), function (e) { e.classList.remove("sel"); }); }
      });
    }

    function wire() {
      $("[data-x]", sheet).addEventListener("click", closeSheet);
      $("[data-back]", sheet).addEventListener("click", env.back || closeSheet);

      $("#pgMethods", sheet).addEventListener("click", function (e) {
        var head = e.target.closest("[data-mhead]");
        if (head) { open = head.getAttribute("data-mhead"); upiApp = ""; refreshMethods(); return; }
        var app = e.target.closest("[data-app]");
        if (app) { upiApp = app.getAttribute("data-app"); var v = $("#pgVpa", sheet); if (v) v.value = "";
          [].forEach.call(sheet.querySelectorAll(".pg-app"), function (el) { el.classList.toggle("sel", el === app); }); return; }
        var bk = e.target.closest("[data-bank]");
        if (bk) { bankSel = bk.getAttribute("data-bank"); var s = $("#pgBankSel", sheet); if (s) s.value = "";
          [].forEach.call(sheet.querySelectorAll(".pg-bank"), function (el) { el.classList.toggle("sel", el === bk); }); return; }
      });
      var vpa = $("#pgVpa", sheet);
      if (vpa) vpa.addEventListener("input", function () {
        if (vpa.value) { upiApp = ""; [].forEach.call(sheet.querySelectorAll(".pg-app"), function (el) { el.classList.remove("sel"); }); }
      });
      bindMethodInner();
      $("[data-pgpay]", sheet).addEventListener("click", pay);
    }

    function validate() {
      if (open === "upi") {
        var vpa = ($("#pgVpa", sheet) || {}).value || "";
        if (upiApp) return true;
        if (/^[\w.\-]{2,}@[a-zA-Z]{2,}$/.test(vpa.trim())) return true;
        toast("Select a UPI app or enter a valid UPI ID"); return false;
      }
      if (open === "card") {
        var num = ($("#pgNum", sheet).value || "").replace(/\s/g, "");
        var exp = ($("#pgExp", sheet).value || "").replace(/\s/g, "");
        var cvv = $("#pgCvv", sheet).value || "";
        var nm = ($("#pgName", sheet).value || "").trim();
        if (!luhn(num)) { toast("Enter a valid card number"); return false; }
        var mm = parseInt(exp.slice(0, 2), 10), yy = parseInt(exp.slice(3, 5), 10);
        if (!(mm >= 1 && mm <= 12) || exp.length < 5) { toast("Enter a valid expiry date"); return false; }
        var now = new Date(), curY = now.getFullYear() % 100, curM = now.getMonth() + 1;
        if (yy < curY || (yy === curY && mm < curM)) { toast("Card has expired"); return false; }
        if (cvv.length < 3) { toast("Enter a valid CVV"); return false; }
        if (nm.length < 2) { toast("Enter the name on card"); return false; }
        return true;
      }
      if (open === "bank") {
        if (bankSel || (($("#pgBankSel", sheet) || {}).value)) return true;
        toast("Select your bank to continue"); return false;
      }
      return false;
    }

    function pay() {
      if (!validate()) return;
      var cfg = opts.success ? opts.success(amount, total) : walletSuccess(amount);
      cfg.amount = amount; cfg.sheetEl = sheet; cfg.close = closeSheet;
      runSuccess(cfg);
    }

    shell();
    requestAnimationFrame(function () { scrim.classList.add("show"); sheet.classList.add("show"); });
  }

  /* reusable gateway for other screens (Chat profile invoice, etc.) — own overlay on the device host */
  window.__payGateway = function (amount, opts) {
    opts = opts || {};
    var host = document.getElementById("screen") || document.body;
    var ov = makeOverlay(host);
    openGateway(amount, { env: { sheet: ov.sheet, scrim: ov.scrim, close: ov.close, back: ov.close }, charge: false,
      headNm: opts.headNm || "AskEva Technologies", headSub: opts.headSub || "Payment", totalLabel: opts.totalLabel || "Amount payable",
      success: opts.success });
  };

  /* ---------- other actions ---------- */
  var ROCKET = '<svg viewBox="0 0 24 24" fill="none" stroke="#2BA84A" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M5 14c-2 1-3 4-3 4s3-1 4-3M14 5c4-3 7-2 7-2s1 3-2 7c-1.6 2.2-5 4.5-7 5l-3-3c.5-2 2.8-5.4 5-7Z"/><circle cx="15" cy="9" r="1.6"/></svg>';
  var FEAT = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="m5 12 4 4 10-11"/></svg>';

  var PLANS = [
    { id: "mmlite", name: "MMLite", desc: "A lightweight, marketing-focused version built for speed and efficiency. Perfect for quick campaigns and resource-friendly deployments.",
      feats: ["Faster setup &amp; improved performance", "Optimized for marketing campaigns", "Reduced system overhead"] },
    { id: "coexistence", name: "Coexistence", desc: "Run WhatsApp Business App and Cloud API together without conflicts. Keep your existing workflows while enjoying advanced automation.",
      feats: ["Dual access: Business App + Cloud API", "Better sync between devices and API", "Smooth migration path"] }
  ];

  function openUpgrade() {
    var chosen = "coexistence";
    function cards() {
      return PLANS.map(function (p) {
        return '<button class="hm-plan-card' + (p.id === chosen ? " sel" : "") + '" data-plan="' + p.id + '">' +
          '<div class="hm-plan-top"><span class="hm-radio"></span><span class="hm-plan-name">' + p.name + '</span></div>' +
          '<div class="hm-plan-desc">' + p.desc + '</div>' +
          '<div class="hm-plan-feats">' + p.feats.map(function (f) { return '<div class="hm-feat"><span class="fi">' + FEAT + '</span>' + f + '</div>'; }).join("") + '</div>' +
        '</button>';
      }).join("");
    }
    sheet.innerHTML = '<div class="lx-grip"></div>' +
      '<div class="lx-shead"><span class="lx-fundicon">' + ROCKET + '</span><span class="tt">Select Feature to Upgrade</span><button class="x" data-x>' + X + '</button></div>' +
      '<div class="lx-sbody"><div class="hm-plans" id="upPlans">' + cards() + '</div></div>' +
      '<div class="lx-sfoot two"><button class="lx-btn ghost" data-x>Cancel</button><button class="lx-btn primary" data-up>Upgrade</button></div>';
    requestAnimationFrame(function () { scrim.classList.add("show"); sheet.classList.add("show"); });

    $("#upPlans", sheet).addEventListener("click", function (e) {
      var c = e.target.closest("[data-plan]"); if (!c) return;
      chosen = c.getAttribute("data-plan");
      var all = sheet.querySelectorAll(".hm-plan-card");
      Array.prototype.forEach.call(all, function (n) { n.classList.toggle("sel", n.getAttribute("data-plan") === chosen); });
    });
    Array.prototype.forEach.call(sheet.querySelectorAll("[data-x]"), function (b) { b.addEventListener("click", closeSheet); });
    $("[data-up]", sheet).addEventListener("click", function () {
      var p = PLANS.filter(function (x) { return x.id === chosen; })[0];
      closeSheet(); toast("Upgrading to " + p.name + "\u2026");
    });
  }

  /* ---------- more-menu period popover ---------- */
  var FEAT = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><path d="m5 12 4 4 10-11"/></svg>';
  var PERIODS = ["Today", "Last 7 days", "Last 28 days"];
  var moreMenu = document.createElement("div"); moreMenu.className = "hm-menu";
  var menuOwner = null;
  function closeMenu() { moreMenu.classList.remove("show"); if (moreMenu.parentNode) moreMenu.parentNode.removeChild(moreMenu); menuOwner = null; }
  document.addEventListener("click", function (e) {
    if (menuOwner && !e.target.closest(".hm-menu") && !e.target.closest('[data-hm="more"]')) closeMenu();
  });

  var PERIOD_MULT = { "Today": 0.16, "Last 7 days": 1, "Last 28 days": 4 };

  /* ----- live chart redraw: regenerate the trend graph for the chosen period ----- */
  function hashStr(s) { var h = 2166136261; s = String(s || ""); for (var i = 0; i < s.length; i++) { h ^= s.charCodeAt(i); h = Math.imul(h, 16777619); } return h >>> 0; }
  function seedRand(seed) { seed = seed >>> 0 || 1; return function () { seed = (seed + 0x6D2B79F5) | 0; var t = Math.imul(seed ^ (seed >>> 15), 1 | seed); t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t; return ((t ^ (t >>> 14)) >>> 0) / 4294967296; }; }
  function chartSVGInner(card, n, seedKey) {
    n = Math.max(2, Math.min(n | 0, 32));
    var pills = card.querySelectorAll(".hm-pill .n");
    function num(el) { if (!el) return 0; var b = el.getAttribute("data-base"); return parseInt((b != null ? b : el.textContent).replace(/[^\d]/g, ""), 10) || 0; }
    var sent = num(pills[0]) || 1, del = num(pills[1]), read = num(pills[2]);
    var rDel = Math.min(1, del / sent || 0.62), rRead = Math.min(rDel, read / sent || 0.46);
    var rnd = seedRand(hashStr(seedKey));
    var shape = [], pk = Math.floor(rnd() * n);
    for (var i = 0; i < n; i++) shape.push(0.3 + rnd() * 0.68);
    shape[pk] = 1;                                  // one clear peak per period
    var xL = 8, xR = 312, yTop = 18, yBase = 122;
    function X(i) { return n === 1 ? xL : xL + i * (xR - xL) / (n - 1); }
    function Y(v) { return yBase - v * (yBase - yTop); }
    function pts(scale) { var a = []; for (var i = 0; i < n; i++) a.push(X(i).toFixed(1) + "," + Y(shape[i] * scale).toFixed(1)); return a; }
    function line(a, c) { return '<path d="M' + a.join(" L") + '" fill="none" stroke="' + c + '" stroke-width="2" stroke-linejoin="round"/>'; }
    function area(a, f) { return '<path d="M' + a.join(" L") + " L" + xR.toFixed(1) + "," + yBase + " L" + xL.toFixed(1) + "," + yBase + ' Z" fill="' + f + '"/>'; }
    var grid = "";
    [[122, "#E4E8E1"], [85.7, "#EEF1EC"], [49.4, "#EEF1EC"], [12, "#EEF1EC"]].forEach(function (g) {
      grid += '<line x1="8" y1="' + g[0] + '" x2="312" y2="' + g[0] + '" stroke="' + g[1] + '" stroke-width="1"/>';
    });
    var sP = pts(1), dP = pts(rDel), rP = pts(rRead);
    return grid +
      area(sP, "rgba(28,122,99,.32)") + line(sP, "#177A36") +
      area(dP, "rgba(67,190,142,.40)") + line(dP, "#3CC23F") +
      area(rP, "rgba(150,222,190,.55)") + line(rP, "#85D653");
  }
  function pointsForPeriod(p) { return p === "Today" ? 9 : p === "Last 28 days" ? 28 : 7; }
  function redrawChart(card, n, seedKey) {
    if (!card) return;
    var svg = card.querySelector("svg.hm-chart"); if (!svg) return;
    svg.innerHTML = chartSVGInner(card, n, seedKey);
    svg.classList.remove("hm-chart-anim"); void svg.offsetWidth; svg.classList.add("hm-chart-anim");
  }

  /* scale a card's stat numbers for the chosen period so the 3-dot menu has a
     visible effect (numbers are captured once into data-base, then scaled). */
  function applyMult(card, mult) {
    if (!card) return;
    if (mult == null) mult = 1;
    Array.prototype.forEach.call(card.querySelectorAll(".hm-pill .n, .hm-stat .n"), function (n) {
      if (n.getAttribute("data-base") == null) n.setAttribute("data-base", String(parseInt((n.textContent || "0").replace(/[^\d]/g, ""), 10) || 0));
      var base = parseInt(n.getAttribute("data-base"), 10) || 0;
      n.textContent = Math.round(base * mult).toLocaleString("en-IN");
    });
  }
  function applyPeriod(card, p) {
    var mult = PERIOD_MULT[p]; if (mult == null) mult = 1;
    applyMult(card, mult);
    redrawChart(card, pointsForPeriod(p), "period:" + p);
  }

  function openMore(btn) {
    if (menuOwner === btn) { closeMenu(); return; }
    menuOwner = btn;
    var card = btn.closest(".d2-card");
    var label = card ? card.querySelector(".hm-reportrow .rt") : null;
    var current = (card && card.getAttribute("data-period")) || (label && label.getAttribute("data-period")) || "Last 7 days";
    moreMenu.innerHTML = PERIODS.map(function (p) {
      return '<button data-period="' + p + '"' + (p === current ? ' class="sel"' : '') + '>' + p + '<span class="ck">' + FEAT + '</span></button>';
    }).join("");
    // anchor menu inside the card header so it scrolls with the card
    btn.parentNode.appendChild(moreMenu);
    moreMenu.style.top = "100%";
    moreMenu.style.right = "0";
    moreMenu.style.left = "auto";
    moreMenu.classList.add("show");
    moreMenu.querySelectorAll("button").forEach(function (b) {
      b.addEventListener("click", function () {
        var p = b.getAttribute("data-period");
        if (card) card.setAttribute("data-period", p);
        if (label) { label.textContent = p + " Report"; label.setAttribute("data-period", p); }
        applyPeriod(card, p);
        closeMenu(); toast("Showing " + p.toLowerCase());
      });
    });
  }

  /* ---------- date-range picker (per summary card) ---------- */
  var CAL = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="5" width="18" height="16" rx="2.5"/><path d="M3 10h18M8 3v4M16 3v4"/></svg>';
  var CAL_G = '<svg viewBox="0 0 24 24" fill="none" stroke="#2BA84A" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="5" width="18" height="16" rx="2.5"/><path d="M3 10h18M8 3v4M16 3v4"/></svg>';
  var DR_MON = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
  function drISO(d) { return d.getFullYear() + "-" + ("0" + (d.getMonth() + 1)).slice(-2) + "-" + ("0" + d.getDate()).slice(-2); }
  function drParse(v) { var p = (v || "").split("-"); return new Date(+p[0], (+p[1] || 1) - 1, +p[2] || 1); }
  function drFmt(d) { return d.getDate() + " " + DR_MON[d.getMonth()]; }
  function drPreset(p) {
    var e = new Date(); var s = new Date();
    if (p === "month") s = new Date(e.getFullYear(), e.getMonth(), 1);
    else if (p === "0") s = new Date(e);
    else { var n = parseInt(p, 10); s = new Date(e); s.setDate(s.getDate() - (n - 1)); }
    return { s: s, e: e };
  }

  function paintDR(card, sIso, eIso) {
    var db = card && card.querySelector(".hm-daterange");
    if (!db) return;
    if (sIso && eIso) {
      var s = drParse(sIso), e = drParse(eIso);
      db.classList.add("set");
      db.innerHTML = '<span class="hm-drtxt">' + drFmt(s) + ' \u2192 ' + drFmt(e) + '</span>' +
        '<button class="hm-drx" type="button" aria-label="Reset date">' + X + '</button>';
    } else {
      db.classList.remove("set");
      db.innerHTML = '<span class="hm-drtxt ph">Start date \u2192 End date</span>' + CAL;
    }
  }
  function resetDateRange(card) {
    if (!card) return;
    card.removeAttribute("data-rstart"); card.removeAttribute("data-rend"); card.setAttribute("data-period", "7");
    var label = card.querySelector(".hm-reportrow .rt");
    if (label) { label.textContent = "Last 7 days Report"; label.setAttribute("data-period", "7"); }
    paintDR(card, "", "");
    applyMult(card, 1);
    redrawChart(card, 7, "period:Last 7 days");
    toast("Date range cleared");
  }

  function openDateRange(btn) {
    var card = btn.closest(".d2-card");

    function applyRange(sIso, eIso) {
      var s = drParse(sIso), e = drParse(eIso);
      if (e < s) { var td = s; s = e; e = td; var ts = sIso; sIso = eIso; eIso = ts; }
      var days = Math.round((e - s) / 864e5) + 1;
      var rangeTxt = drFmt(s) + (days > 1 ? " \u2013 " + drFmt(e) : "");
      if (card) {
        card.setAttribute("data-rstart", sIso); card.setAttribute("data-rend", eIso); card.removeAttribute("data-period");
        var label = card.querySelector(".hm-reportrow .rt");
        if (label) { label.textContent = rangeTxt + " Report"; label.removeAttribute("data-period"); }
        paintDR(card, sIso, eIso);
        applyMult(card, days / 7);
        redrawChart(card, Math.max(2, Math.min(days, 30)), "range:" + sIso + ":" + eIso);
      }
      toast("Showing " + rangeTxt);
    }

    /* one universal modal — Start date → End date, no future dates */
    var P = window.AskEvaPicker;
    if (!P || !P.dateRange) { toast("Date picker unavailable"); return; }
    P.dateRange({
      start: (card && card.getAttribute("data-rstart")) || "",
      end: (card && card.getAttribute("data-rend")) || "",
      maxToday: true,
      onApply: function (r) { if (r && r.start) applyRange(r.start, r.end || r.start); }
    });
  }

  /* ---------- other actions ---------- */
  var MSG = {};
  pane.addEventListener("click", function (e) {
    var el = e.target.closest("[data-hm]"); if (!el) return;
    var k = el.getAttribute("data-hm");
    if (k === "addfund") { openAddFund(); return; }
    if (k === "daterange") {
      if (e.target.closest(".hm-drx")) { resetDateRange(el.closest(".d2-card")); return; }
      openDateRange(el); return;
    }
    if (k === "upgrade") { toast("You\u2019re already on the best plan"); return; }
    if (k === "more") { e.stopPropagation(); openMore(el); return; }
    toast(MSG[k] || "Coming soon");
  });
})();
