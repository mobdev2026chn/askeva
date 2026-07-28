/* =========================================================
   AskEva — Web-app design-language refinement (app-wide)
   ---------------------------------------------------------
   The mobile app's house style leans heavy: font-weight:800
   everywhere, UPPERCASE letter-spaced micro-labels, and tight
   16–18px card radii. The AskEva web app (my.askeva.io) reads
   lighter and airier: medium/semibold weights, sentence-case
   labels, larger radii. Rather than hand-edit ~30 stylesheets,
   we walk every same-origin CSS rule once at load (and again
   whenever a screen lazily injects its <style>) and nudge it
   toward the web look:
       • font-weight 800/900           -> 700  (semibold, not black)
       • UPPERCASE eyebrow labels        -> sentence case, weight 600,
                                            letter-spacing reset
       • card surfaces radius 16–18px    -> +4px (rounder, premium)
       • card surfaces uniform pad 13–17 -> +4px (airier)
   It is idempotent (safe to re-run) and only touches rules that
   clearly match these patterns, leaving buttons, chips, avatars,
   inputs and intentional all-caps data (e.g. plan names) alone.
   ========================================================= */
(function () {
  "use strict";

  function isCardLike(s) {
    // a real surface: has a soft shadow OR a 1px hairline border
    return !!(s.boxShadow && s.boxShadow !== "none") ||
           (!!s.border && s.border !== "none") ||
           (!!s.borderColor && /line|eef1ec|EEF1EC/.test(s.borderColor));
  }

  function refineRule(rule) {
    var s = rule.style;
    if (!s) return;

    /* ---- weights: black/extra-bold -> semibold ---- */
    var fw = s.fontWeight;
    if (fw === "800" || fw === "900") s.fontWeight = "700";

    /* ---- de-capitalize small eyebrow / key labels ---- */
    if (s.textTransform === "uppercase") {
      var fs = parseFloat(s.fontSize);          // px value set in same rule
      var lsRaw = s.letterSpacing;
      var spaced = lsRaw && lsRaw !== "normal" && parseFloat(lsRaw) > 0.3; // >~0.02em
      // treat as a micro-label when it's small text and/or tracked out
      if ((!isNaN(fs) && fs <= 13) || spaced) {
        s.textTransform = "none";
        if (spaced) s.letterSpacing = "0";
        s.fontWeight = "600";                   // labels read medium, not black
      }
    }

    /* ---- airier card surfaces: bump radius & uniform padding ---- */
    var br = s.borderRadius;
    if (br && br.indexOf(" ") === -1 && br.indexOf("%") === -1) {
      var r = parseFloat(br);
      // 16–18px hardcoded radii are this app's card surfaces (buttons/chips/inputs sit at 10–14)
      if (!isNaN(r) && r >= 16 && r <= 18 && isCardLike(s)) {
        s.borderRadius = (r + 4) + "px";
        var pad = s.padding;
        if (pad && pad.indexOf(" ") === -1 && pad.indexOf("var") === -1) {
          var p = parseFloat(pad);
          if (!isNaN(p) && p >= 13 && p <= 18) s.padding = (p + 4) + "px";
        }
      }
    }
  }

  function refineRules(rules) {
    if (!rules) return;
    for (var i = 0; i < rules.length; i++) {
      var rule = rules[i];
      try {
        // NOTE: some engines expose a truthy (empty) `cssRules` on plain style
        // rules, so we must route by selectorText, not by cssRules existence.
        if (rule.style && rule.selectorText) refineRule(rule);               // style rule
        if (rule.cssRules && rule.cssRules.length) refineRules(rule.cssRules); // @media / @supports
      } catch (e) { /* keyframe/font-face/read-only descriptor — skip */ }
    }
  }

  function refineAll() {
    var sheets = document.styleSheets;
    for (var i = 0; i < sheets.length; i++) {
      var rules;
      try { rules = sheets[i].cssRules; } catch (e) { continue; } // foreign/locked
      refineRules(rules);
    }
  }

  // run as soon as we can, and again on a few staggered passes — external
  // <link> sheets parse asynchronously and this app fires `load` late.
  function boot() { try { refineAll(); } catch (e) {} }
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", boot);
  } else {
    boot();
  }
  window.addEventListener("load", boot);
  [60, 250, 600, 1200, 2500].forEach(function (ms) { setTimeout(boot, ms); });

  // screens inject their <style> lazily on first open — refine those too
  var pending = null;
  var mo = new MutationObserver(function (muts) {
    for (var i = 0; i < muts.length; i++) {
      var added = muts[i].addedNodes;
      for (var j = 0; j < added.length; j++) {
        var t = added[j].tagName;
        if (t === "STYLE" || t === "LINK") {
          if (pending) cancelAnimationFrame(pending);
          pending = requestAnimationFrame(function () { pending = null; boot(); });
          return;
        }
      }
    }
  });
  mo.observe(document.documentElement, { childList: true, subtree: true });
})();
