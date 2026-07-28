/* =========================================================
   AskEva — Shared country dial-code list (A→Z)
   One canonical list used by every country-code <select> in the
   app (Add/Edit Contact, Add/Edit Lead, Sign-up). Exposes:
     window.AskEvaCC            -> [[name, code], ...] sorted A→Z
     window.AskEvaCCOptions(sel, opts) -> <option> HTML string
       opts.blank  : label for a leading empty option (optional)
       opts.format : fn(name, code) -> option text (default "name (code)")
   Auto-fills the static sign-up #suCC select on load.
   ========================================================= */
(function () {
  "use strict";
  var RAW =
    "Afghanistan|+93,Albania|+355,Algeria|+213,Andorra|+376,Angola|+244,Argentina|+54," +
    "Armenia|+374,Aruba|+297,Australia|+61,Austria|+43,Azerbaijan|+994,Bahamas|+1,Bahrain|+973," +
    "Bangladesh|+880,Barbados|+1,Belarus|+375,Belgium|+32,Belize|+501,Benin|+229,Bhutan|+975," +
    "Bolivia|+591,Bosnia & Herzegovina|+387,Botswana|+267,Brazil|+55,Brunei|+673,Bulgaria|+359," +
    "Burkina Faso|+226,Burundi|+257,Cambodia|+855,Cameroon|+237,Canada|+1,Cape Verde|+238," +
    "Chad|+235,Chile|+56,China|+86,Colombia|+57,Comoros|+269,Congo|+242,Costa Rica|+506," +
    "Croatia|+385,Cuba|+53,Cyprus|+357,Czechia|+420,Denmark|+45,Djibouti|+253,Dominica|+1," +
    "Dominican Republic|+1,Ecuador|+593,Egypt|+20,El Salvador|+503,Estonia|+372,Eswatini|+268," +
    "Ethiopia|+251,Fiji|+679,Finland|+358,France|+33,Gabon|+241,Gambia|+220,Georgia|+995," +
    "Germany|+49,Ghana|+233,Greece|+30,Grenada|+1,Guatemala|+502,Guinea|+224,Guyana|+592," +
    "Haiti|+509,Honduras|+504,Hong Kong|+852,Hungary|+36,Iceland|+354,India|+91,Indonesia|+62," +
    "Iran|+98,Iraq|+964,Ireland|+353,Israel|+972,Italy|+39,Jamaica|+1,Japan|+81,Jordan|+962," +
    "Kazakhstan|+7,Kenya|+254,Kuwait|+965,Kyrgyzstan|+996,Laos|+856,Latvia|+371,Lebanon|+961," +
    "Lesotho|+266,Liberia|+231,Libya|+218,Liechtenstein|+423,Lithuania|+370,Luxembourg|+352," +
    "Macau|+853,Madagascar|+261,Malawi|+265,Malaysia|+60,Maldives|+960,Mali|+223,Malta|+356," +
    "Mauritania|+222,Mauritius|+230,Mexico|+52,Moldova|+373,Monaco|+377,Mongolia|+976," +
    "Montenegro|+382,Morocco|+212,Mozambique|+258,Myanmar|+95,Namibia|+264,Nepal|+977," +
    "Netherlands|+31,New Zealand|+64,Nicaragua|+505,Niger|+227,Nigeria|+234,North Korea|+850," +
    "North Macedonia|+389,Norway|+47,Oman|+968,Pakistan|+92,Palestine|+970,Panama|+507," +
    "Papua New Guinea|+675,Paraguay|+595,Peru|+51,Philippines|+63,Poland|+48,Portugal|+351," +
    "Qatar|+974,Romania|+40,Russia|+7,Rwanda|+250,Samoa|+685,San Marino|+378,Saudi Arabia|+966," +
    "Senegal|+221,Serbia|+381,Seychelles|+248,Sierra Leone|+232,Singapore|+65,Slovakia|+421," +
    "Slovenia|+386,Somalia|+252,South Africa|+27,South Korea|+82,South Sudan|+211,Spain|+34," +
    "Sri Lanka|+94,Sudan|+249,Suriname|+597,Sweden|+46,Switzerland|+41,Syria|+963,Taiwan|+886," +
    "Tajikistan|+992,Tanzania|+255,Thailand|+66,Togo|+228,Tonga|+676,Trinidad & Tobago|+1," +
    "Tunisia|+216,Turkey|+90,Turkmenistan|+993,Uganda|+256,Ukraine|+380,United Arab Emirates|+971," +
    "United Kingdom|+44,United States|+1,Uruguay|+598,Uzbekistan|+998,Vanuatu|+678,Venezuela|+58," +
    "Vietnam|+84,Yemen|+967,Zambia|+260,Zimbabwe|+263";

  var CC = RAW.split(",").map(function (s) { var p = s.split("|"); return [p[0], p[1]]; });
  window.AskEvaCC = CC;

  function escAttr(s) { return String(s).replace(/"/g, "&quot;"); }
  window.AskEvaCCOptions = function (selected, opts) {
    opts = opts || {};
    var fmt = opts.format || function (name, code) { return name + " (" + code + ")"; };
    var html = opts.blank ? '<option value="">' + opts.blank + "</option>" : "";
    var sawSel = false;
    for (var i = 0; i < CC.length; i++) {
      var name = CC[i][0], code = CC[i][1];
      var sel = (!sawSel && selected && code === selected) ? " selected" : "";
      if (sel) sawSel = true;
      html += '<option value="' + escAttr(code) + '"' + sel + ">" + fmt(name, code) + "</option>";
    }
    return html;
  };

  // populate the static sign-up country-code <select> with the full list
  function fillSignup() {
    var s = document.getElementById("suCC");
    if (!s || s.dataset.ccFilled) return;
    var cur = s.value || "+91";
    s.innerHTML = window.AskEvaCCOptions(cur, { format: function (n, c) { return c + "  " + n; } });
    s.value = cur;
    s.dataset.ccFilled = "1";
  }
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", fillSignup);
  else fillSignup();
})();

/* =========================================================
   AskEva — Universal searchable dropdown (AskEvaSelect)
   Upgrades a native <select> into the approved lf-codd panel
   design (trigger + searchable, scrollable, contained list).
   • Auto-applies to every country-code <select> (values like +91)
     so they all get a search bar — like Compose Message.
   • Opt-in for any other <select> via class "js-uxdd".
   • Keeps the original <select> in the DOM (hidden) as the value
     store, and dispatches "change" on pick, so existing listeners
     and value reads keep working unchanged.
   Exposes window.AskEvaSelect.enhance(sel, opts) / .enhanceAll(root)
   ========================================================= */
(function () {
  "use strict";
  var SRCH = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><circle cx="11" cy="11" r="7"/><path d="M21 21l-4.3-4.3"/></svg>';
  var CHEV = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 9l6 6 6-6"/></svg>';
  /* shared bottom-sheet country picker — used by every country-code <select> */
  var ccScrim, ccSheet;
  function ccHost() { return document.getElementById("screen") || document.body; }
  function closeCCSheet() { if (ccScrim) ccScrim.classList.remove("show"); }
  function openCCSheet(curVal, onPick) {
    if (!ccScrim) {
      ccScrim = document.createElement("div"); ccScrim.className = "ccx-scrim";
      ccSheet = document.createElement("div"); ccSheet.className = "ccx-sheet";
      ccScrim.appendChild(ccSheet);
      ccScrim.addEventListener("click", function (e) { if (e.target === ccScrim) closeCCSheet(); });
    }
    if (ccScrim.parentNode !== ccHost()) ccHost().appendChild(ccScrim);
    var list = window.AskEvaCC || [];
    ccSheet.innerHTML =
      '<div class="ccx-grip"></div><div class="ccx-hd">Select country code</div>' +
      '<div class="ccx-srch">' + SRCH + '<input type="text" class="ccx-search" placeholder="Search country or code" autocomplete="off"></div>' +
      '<div class="ccx-list"></div>';
    var listEl = ccSheet.querySelector(".ccx-list"), srch = ccSheet.querySelector(".ccx-search");
    function render() {
      var q = (srch.value || "").trim().toLowerCase();
      var rows = list.filter(function (c) { return !q || c[0].toLowerCase().indexOf(q) >= 0 || c[1].toLowerCase().indexOf(q) >= 0; });
      listEl.innerHTML = rows.length
        ? rows.map(function (c) { return '<button type="button" class="ccx-opt' + (c[1] === curVal ? " on" : "") + '" data-v="' + c[1] + '">' + c[0] + " (" + c[1] + ")</button>"; }).join("")
        : '<div class="ccx-none">No match</div>';
      [].slice.call(listEl.querySelectorAll(".ccx-opt")).forEach(function (b) {
        b.addEventListener("click", function () { if (onPick) onPick(b.getAttribute("data-v")); closeCCSheet(); });
      });
    }
    srch.addEventListener("input", render);
    render();
    requestAnimationFrame(function () { ccScrim.classList.add("show"); setTimeout(function () { try { srch.focus(); } catch (e) {} }, 40); });
  }
  function isCC(sel) {
    var o = sel.options; if (!o || !o.length) return false;
    var n = 0;
    for (var i = 0; i < o.length; i++) {
      var v = o[i].value; if (v === "") continue;
      if (!/^\+\d/.test(v)) return false; n++;
    }
    return n > 0;
  }
  /* National (subscriber) number length per dial code. Exact number or [min,max].
     Unlisted codes fall back to the E.164 generic range. Exposed globally. */
  var PHONE_LEN = {
    "+91": 10, "+1": 10, "+44": 10, "+971": 9, "+61": 9, "+65": 8, "+49": [10, 11],
    "+33": 9, "+86": 11, "+81": [10, 11], "+7": 10, "+39": [9, 10], "+34": 9, "+55": [10, 11],
    "+27": 9, "+92": 10, "+880": 10, "+94": 9, "+977": 10, "+60": [9, 10], "+62": [9, 12],
    "+63": 10, "+66": 9, "+84": 9, "+82": [9, 10], "+852": 8, "+853": 8, "+886": 9,
    "+966": 9, "+974": 8, "+965": 8, "+973": 8, "+968": 8, "+962": 9, "+961": [7, 8],
    "+20": 10, "+234": 10, "+254": 9, "+233": 9, "+263": 9, "+212": 9, "+213": 9, "+216": 8,
    "+90": 10, "+98": 10, "+64": [8, 9], "+353": 9, "+41": 9, "+43": [10, 11], "+31": 9,
    "+32": [8, 9], "+46": [7, 9], "+47": 8, "+45": 8, "+358": [9, 10], "+48": 9, "+351": 9,
    "+30": 10, "+52": 10, "+54": 10, "+57": 10, "+56": 9, "+51": 9, "+58": 10, "+593": 9,
    "+591": 8, "+595": 9, "+598": 8, "+506": 8, "+507": 8, "+509": 8, "+972": 9, "+420": 9,
    "+421": 9, "+36": 9, "+40": 9, "+380": 9, "+375": 9, "+994": 9, "+995": 9, "+998": 9,
    "+93": 9, "+960": 7, "+975": 8, "+855": [8, 9], "+95": [8, 10], "+673": 7, "+856": 9,
    "+976": 8, "+251": 9, "+255": 9, "+256": 9, "+260": 9, "+265": 9, "+970": 9
  };
  function lenFor(code) {
    var v = PHONE_LEN[code];
    if (v == null) return { min: 6, max: 15 };
    return typeof v === "number" ? { min: v, max: v } : { min: v[0], max: v[1] };
  }
  window.AskEvaPhoneLen = lenFor;
  /* find the mobile-number <input> paired with a country-code <select> */
  function findMobileInput(ccSel) {
    var scope = ccSel.closest(".lx-twocol,.ct-two,.cm-two,.st-recline,.ap-mobrow,.ax-field,.lx-field") || ccSel.parentElement;
    for (var hop = 0; hop < 3 && scope; hop++) {
      var inp = [].slice.call(scope.querySelectorAll("input")).filter(function (i) {
        if (i === ccSel || i.type === "hidden") return false;
        return i.inputMode === "numeric" || /mob|phone|number/i.test((i.id || "") + " " + (i.placeholder || "") + " " + (i.getAttribute("name") || ""));
      })[0];
      if (inp) return inp;
      scope = scope.parentElement;
    }
    return null;
  }
  /* enforce the per-country digit limit on the paired mobile input */
  function bindPhoneLimit(ccSel) {
    if (!ccSel || ccSel.dataset.phoneBound) return;
    var inp = findMobileInput(ccSel); if (!inp) return;
    ccSel.dataset.phoneBound = "1";
    function clamp() {
      var L = lenFor(ccSel.value);
      inp.setAttribute("maxlength", L.max);
      var v = (inp.value || "").replace(/\D/g, "").slice(0, L.max);
      if (inp.value !== v) inp.value = v;
    }
    inp.addEventListener("input", clamp);
    ccSel.addEventListener("change", clamp);
    clamp();
  }
  function enhance(sel, opts) {
    if (!sel || sel.dataset.uxdd || sel.multiple) return;
    opts = opts || {};
    sel.dataset.uxdd = "1";
    var searchable = opts.search != null ? opts.search : (sel.options.length > 6);
    var wrap = document.createElement("div");
    wrap.className = "lf-codd uxdd";
    sel.parentNode.insertBefore(wrap, sel);
    wrap.appendChild(sel);
    sel.style.display = "none";
    var trig = document.createElement("button");
    trig.type = "button"; trig.className = "lx-input lf-codd-trig uxdd-trig";
    trig.innerHTML = '<span class="val"></span>' + CHEV;
    var panel = document.createElement("div");
    panel.className = "lf-codd-panel"; panel.hidden = true;
    panel.innerHTML =
      (searchable ? '<div class="lf-codd-srch">' + SRCH + '<input type="text" class="uxdd-srch" placeholder="' + (opts.placeholder || "Search") + '" autocomplete="off"></div>' : "") +
      '<div class="lf-codd-list"></div>';
    wrap.appendChild(trig); wrap.appendChild(panel);
    var listEl = panel.querySelector(".lf-codd-list");
    var srch = panel.querySelector(".uxdd-srch");
    var codeOnly = sel.hasAttribute("data-uxdd-codeonly");
    function selOpt() { return sel.options[sel.selectedIndex] || null; }
    function isPlaceholder() { var o = selOpt(); return !o || o.value === "" || o.disabled; }
    function syncTrig() { var o = selOpt(); var t = o ? o.textContent : ""; if (codeOnly && t) t = t.trim().split(/\s+/)[0]; trig.querySelector(".val").textContent = t; trig.classList.toggle("ph", isPlaceholder()); }
    function renderList() {
      var q = (srch && srch.value || "").trim().toLowerCase(), rows = [];
      for (var i = 0; i < sel.options.length; i++) {
        var o = sel.options[i];
        if (o.value === "" || o.disabled) continue;
        if (q && o.textContent.toLowerCase().indexOf(q) < 0) continue;
        rows.push(o);
      }
      if (!rows.length) { listEl.innerHTML = '<div class="lf-codd-none">No match</div>'; return; }
      listEl.innerHTML = rows.map(function (o) {
        return '<button type="button" class="lf-codd-opt' + (o.value === sel.value ? " on" : "") + '" data-v="' + String(o.value).replace(/"/g, "&quot;") + '">' + o.textContent + "</button>";
      }).join("");
      [].slice.call(listEl.querySelectorAll(".lf-codd-opt")).forEach(function (b) {
        b.addEventListener("click", function () { pick(b.getAttribute("data-v")); });
      });
    }
    function pick(v) { sel.value = v; sel.dispatchEvent(new Event("change", { bubbles: true })); syncTrig(); close(); }
    function syncDisabled() { var d = !!sel.disabled; trig.classList.toggle("uxdd-dis", d); trig.disabled = d; if (d) close(); }
    function open() { if (sel.disabled) return; panel.hidden = false; trig.classList.add("open"); renderList(); if (srch) setTimeout(function () { srch.focus(); }, 30); }
    function close() { panel.hidden = true; trig.classList.remove("open"); if (srch) srch.value = ""; }
    trig.addEventListener("click", function (e) {
      e.stopPropagation(); if (sel.disabled) return;
      if (opts.sheet && window.AskEvaCC) { openCCSheet(sel.value, function (v) { pick(v); }); return; }
      panel.hidden ? open() : close();
    });
    if (srch) {
      srch.addEventListener("input", renderList);
      srch.addEventListener("keydown", function (e) { if (e.key === "Enter") { e.preventDefault(); var f = listEl.querySelector(".lf-codd-opt"); if (f) f.click(); } });
    }
    wrap.addEventListener("click", function (e) { e.stopPropagation(); });
    document.addEventListener("click", function () { if (!panel.hidden) close(); });
    sel.addEventListener("change", syncTrig);
    try { new MutationObserver(syncDisabled).observe(sel, { attributes: true, attributeFilter: ["disabled"] }); } catch (e) {}
    syncTrig(); syncDisabled();
  }
  function enhanceAll(root) {
    root = root || document;
    var nodes = [];
    if (root.tagName === "SELECT") nodes = [root];
    else if (root.querySelectorAll) nodes = [].slice.call(root.querySelectorAll("select:not([data-uxdd])"));
    nodes.forEach(function (sel) {
      if (sel.dataset.uxdd || sel.multiple) return;
      if (sel.classList.contains("js-uxdd-skip")) return;        // explicit opt-out
      if (isCC(sel)) { enhance(sel, { sheet: true, search: true, placeholder: "Search country or code" }); bindPhoneLimit(sel); return; }
      // universal: every other <select> gets the same design (search shows when the list is long)
      enhance(sel, { placeholder: "Search" });
    });
  }
  window.AskEvaSelect = { enhance: enhance, enhanceAll: enhanceAll, openCCSheet: openCCSheet };
  function boot() {
    enhanceAll(document);
    var host = document.body || document.documentElement;
    var pending = false;
    var mo = new MutationObserver(function () {
      if (pending) return; pending = true;
      setTimeout(function () { pending = false; enhanceAll(document); }, 0);
    });
    mo.observe(host, { childList: true, subtree: true });
  }
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", boot);
  else boot();
})();
