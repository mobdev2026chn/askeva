/* AskEva — app-open push alerts (low wallet balance) ===================
   On every app open / reload, if the wallet balance is below the
   threshold, slide in a system-style push card for ~4s. Reads the live
   balance from the dashboard so it always reflects the real amount. */
(function () {
  "use strict";
  var screen = document.getElementById("screen");
  if (!screen) return;

  var THRESHOLD = 500;

  var WALLET = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="6" width="18" height="13" rx="2.5"/><path d="M3 10h18M16 14h2"/></svg>';
  var X = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M18 6 6 18M6 6l12 12"/></svg>';

  function balance() {
    var el = document.querySelector(".hm-balance .amt");
    if (!el) return null;
    var v = parseFloat((el.textContent || "").replace(/[^\d.]/g, ""));
    return isNaN(v) ? null : v;
  }

  var active = null, hideT = null, killT = null;
  function dismiss(card) {
    if (!card) return;
    clearTimeout(hideT); clearTimeout(killT);
    card.classList.add("hide");
    killT = setTimeout(function () {
      if (card.parentNode) card.parentNode.removeChild(card);
      if (active === card) active = null;
    }, 320);
  }

  function showLowBalance() {
    if (active) return;
    try {
      if (localStorage.getItem("askeva.push.low_balance_read") === "true") return;
    } catch (e) {}
    window.__pushShownCount = (window.__pushShownCount || 0) + 1;
    var card = document.createElement("div");
    card.className = "pushn";
    card.innerHTML =
      '<span class="pushn-ic">' + WALLET + '</span>' +
      '<div class="pushn-tx">Wallet balance is low. Recharge the wallet ASAP.</div>' +
      '<button class="pushn-x" aria-label="Dismiss">' + X + '</button>';
    screen.appendChild(card);
    active = card;
    hideT = setTimeout(function () { dismiss(card); }, 4200);
    card.querySelector(".pushn-x").addEventListener("click", function () {
      try { localStorage.setItem("askeva.push.low_balance_read", "true"); } catch (e) {}
      dismiss(card);
    });
  }

  function check() {
    var b = balance();
    if (b != null && b < THRESHOLD) { showLowBalance(); return true; }
    return false;
  }

  /* Run after the user is LOGGED IN (not during the splash/login screens,
     where the card would slide in behind them and auto-dismiss unseen).
     We wait for #screen to lose the `logged-out` class, then poll for the
     balance (the dashboard markup may still be (re)building during init). */
  function runCheckSoon() {
    var tries = 0;
    (function attempt() {
      tries++;
      var b = balance();
      if (b != null) { if (b < THRESHOLD) showLowBalance(); return; }
      if (tries < 24) setTimeout(attempt, 250);   // keep trying up to ~6s
    })();
  }
  function boot() {
    // already logged in? (defensive) run straight away
    if (!screen.classList.contains("logged-out")) { runCheckSoon(); return; }
    // otherwise wait until login completes (logged-out removed)
    var obs = new MutationObserver(function () {
      if (!screen.classList.contains("logged-out")) {
        obs.disconnect();
        setTimeout(runCheckSoon, 900);   // let the login screen finish dismissing
      }
    });
    obs.observe(screen, { attributes: true, attributeFilter: ["class"] });
  }
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", boot);
  else boot();

  /* expose for manual re-trigger (e.g. after a deduction elsewhere) */
  window.__lowBalanceCheck = check;

  /* generic push banner — used to alert whoever a reminder/event concerns */
  var BELL = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M18 8a6 6 0 1 0-12 0c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.7 21a2 2 0 0 1-3.4 0"/></svg>';
  function showCard(iconSvg, text) {
    if (active) dismiss(active);
    var card = document.createElement("div"); card.className = "pushn";
    var ic = document.createElement("span"); ic.className = "pushn-ic"; ic.innerHTML = iconSvg;
    var tx = document.createElement("div"); tx.className = "pushn-tx"; tx.textContent = text;
    var bx = document.createElement("button"); bx.className = "pushn-x"; bx.setAttribute("aria-label", "Dismiss"); bx.innerHTML = X;
    card.appendChild(ic); card.appendChild(tx); card.appendChild(bx);
    screen.appendChild(card); active = card;
    hideT = setTimeout(function () { dismiss(card); }, 4600);
    bx.addEventListener("click", function () { dismiss(card); });
  }
  window.__pushAlert = function (o) { o = o || {}; showCard(o.icon || BELL, o.text || ""); };
})();
