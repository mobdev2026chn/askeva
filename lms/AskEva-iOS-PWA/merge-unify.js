/* =========================================================
   MERGE: make Leads behave like Appointments —
   ONE "Leads" sidebar item opening a page with header tabs
   [ Dashboard · Leads · Settings ]. The three existing panes
   (#app-dashboard = lead dashboard, #app-leads = list,
   #app-leadsettings = settings) each get the SAME primary tab
   bar in their green header (wired to the app router), and each
   pane's own sub-controls drop into the white content sheet as a
   secondary segmented control. Idempotent + safe to re-run.
   ========================================================= */
(function () {
  "use strict";
  var $  = function (s, r) { return (r || document).querySelector(s); };
  var $$ = function (s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); };

  var PRIMARY = [
    { route: "dashboard",    label: "Dashboard" },
    { route: "leads",        label: "Leads" },
    { route: "leadsettings", label: "Settings" }
  ];

  function makePrimary(active) {
    var seg = document.createElement("div");
    seg.className = "lp-seg leads-primary";
    PRIMARY.forEach(function (t) {
      var b = document.createElement("button");
      b.type = "button";
      b.setAttribute("data-go", t.route);
      b.textContent = t.label;
      if (t.route === active) b.className = "active";
      seg.appendChild(b);
    });
    seg.addEventListener("click", function (e) {
      var b = e.target.closest("button[data-go]"); if (!b) return;
      if (window.__appRoute) window.__appRoute(b.getAttribute("data-go"));
    });
    return seg;
  }

  // paneSel, header selector, sheet selector, secondary selector, which-route
  function build(paneSel, headSel, sheetSel, secSel, which) {
    var pane = $(paneSel); if (!pane) return;
    var head = $(headSel, pane), sheet = $(sheetSel, pane);
    if (!head || !sheet) return;

    // normalise the section title to "Leads" (like Appointments shows one name)
    var ttl = head.querySelector(".lx-title, .d2-title");
    if (ttl && ttl.textContent.trim() !== "Leads") ttl.textContent = "Leads";

    // 1) primary tab bar in the green header (right after the topbar)
    var topbar = head.querySelector(".lx-topbar, .d2-topbar");
    var prim = head.querySelector(".leads-primary");
    if (!prim && topbar) { prim = makePrimary(which); topbar.insertAdjacentElement("afterend", prim); }
    else if (prim) { $$("button[data-go]", prim).forEach(function (b) { b.classList.toggle("active", b.getAttribute("data-go") === which); }); }

    // 2) keep this pane's own sub-control in the HEADER, right below the primary bar,
    //    as a secondary chip row. (Modules rewrite the sheet, so the sheet is unsafe.)
    var sec = pane.querySelector(secSel);
    if (sec && prim) {
      sec.classList.add("leads-secondary");
      if (sec.parentElement !== head || sec.previousElementSibling !== prim) prim.insertAdjacentElement("afterend", sec);
    }

    // remove any leftover hero from an earlier iteration
    var oldHero = head.querySelector(".lp-hero");
    if (oldHero) oldHero.remove();
  }

  function unify() {
    build("#app-dashboard",    ".d2-head", ".d2-sheet",  ".d2-segtoggle", "dashboard");
    build("#app-leads",        ".lx-head", ".lx-sheet",  ".lx-tabs",      "leads");
    build("#app-leadsettings", ".lx-head", ".lx-sheet",  ".lx-tabs",      "leadsettings");
  }

  if (document.readyState !== "loading") unify();
  else document.addEventListener("DOMContentLoaded", unify);

  // poll while modules finish building
  var n = 0, iv = setInterval(function () { unify(); if (++n > 24) clearInterval(iv); }, 300);

  // re-assert after navigation
  document.addEventListener("click", function (e) {
    if (e.target.closest && e.target.closest(".side-item, .leads-primary button")) {
      [60, 250, 600].forEach(function (d) { setTimeout(unify, d); });
    }
  });
  try {
    var obs = new MutationObserver(function () { unify(); });
    ["#app-dashboard", "#app-leads", "#app-leadsettings"].forEach(function (id) {
      var el = document.querySelector(id);
      if (el) obs.observe(el, { childList: true, subtree: true });
    });
  } catch (e) {}
})();
