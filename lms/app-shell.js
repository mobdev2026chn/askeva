/* =========================================================
   AskEva — App Shell
   Global sidebar navigation (replaces bottom nav), route
   switching, settings drill-in, and new-screen interactions.
   ========================================================= */
(function () {
  "use strict";
  var $  = function (s, r) { return (r || document).querySelector(s); };
  var $$ = function (s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); };

  var ds       = document.getElementById("screen");
  var sidebar  = document.getElementById("sidebar");
  var scrim    = document.getElementById("sideScrim");

  var ROUTES = ["dashboard", "leads", "chats", "appointments", "ticketing", "profile", "settings"];

  /* ---------- toast (reuse shared #toast) ---------- */
  var toastT;
  function toast(msg) {
    var t = document.getElementById("toast"); if (!t) return;
    t.textContent = msg;
    t.style.opacity = "1"; t.style.transform = "translateX(-50%) translateY(0)";
    clearTimeout(toastT);
    toastT = setTimeout(function () {
      t.style.opacity = "0"; t.style.transform = "translateX(-50%) translateY(20px)";
    }, 1800);
  }

  /* ---------- sidebar open/close ---------- */
  function openNav()  { sidebar.classList.add("show"); scrim.classList.add("show"); }
  function closeNav() { sidebar.classList.remove("show"); scrim.classList.remove("show"); }

  // any top-left hamburger (aria-label="Menu") opens the sidebar
  document.addEventListener("click", function (e) {
    var menu = e.target.closest ? e.target.closest('[aria-label="Menu"]') : null;
    if (menu) { e.preventDefault(); openNav(); }
  });
  scrim.addEventListener("click", closeNav);

  /* ---------- routing ---------- */
  function syncActive(route) {
    $$(".side-item").forEach(function (b) {
      b.classList.toggle("active", b.getAttribute("data-route") === route);
    });
  }
  function routeTo(route, opts) {
    opts = opts || {};
    ROUTES.forEach(function (r) { ds.classList.remove("route-" + r); });
    ds.classList.add("route-" + route);
    syncActive(route);
    closeSubs();               // leaving settings closes any open sub-view
    if (route === "chats" && window.__chat && !opts.keepChat) window.__chat.showList();
  }

  $$(".side-item").forEach(function (b) {
    b.addEventListener("click", function () {
      routeTo(b.getAttribute("data-route"));
      closeNav();
    });
  });

  /* ---------- lead card -> open its chat ---------- */
  $$("#app-leads [data-chat]").forEach(function (el) {
    el.addEventListener("click", function () {
      var id = el.getAttribute("data-chat");
      routeTo("chats", { keepChat: true });
      if (window.__chat) window.__chat.openById(id);
    });
  });

  /* ---------- leads <-> companies segmented control ---------- */
  var segBtns = $$("#app-leads .lp-seg button");
  function setSeg(seg) {
    segBtns.forEach(function (b) { b.classList.toggle("active", b.getAttribute("data-seg") === seg); });
    $$("#app-leads [data-seg-body]").forEach(function (b) {
      b.hidden = (b.getAttribute("data-seg-body") !== seg);
    });
    var big = $("#lpBig"), sub = $("#lpSub");
    if (seg === "companies") { big.textContent = "Companies"; sub.textContent = "2 organisations · 69 leads"; }
    else { big.textContent = "All Leads"; sub.textContent = "6 leads · 3 active"; }
  }
  segBtns.forEach(function (b) { b.addEventListener("click", function () { setSeg(b.getAttribute("data-seg")); }); });
  $$("#app-leads [data-seg-to]").forEach(function (el) {
    el.addEventListener("click", function () { setSeg(el.getAttribute("data-seg-to")); });
  });

  /* ---------- Settings: drill-in sub-views ---------- */
  function closeSubs() { $$(".set-sub.show").forEach(function (e) { e.classList.remove("show"); }); }
  $$("#app-settings .set-row[data-sub]").forEach(function (row) {
    row.addEventListener("click", function () {
      var el = document.getElementById("sub-" + row.getAttribute("data-sub"));
      if (el) { el.classList.add("show"); var sc = $(".set-scroll", el); if (sc) sc.scrollTop = 0; }
    });
  });
  $$("#app-settings .set-back").forEach(function (b) {
    b.addEventListener("click", function () { closeSubs(); });
  });
  var sl = document.getElementById("setLogout");
  if (sl) sl.addEventListener("click", function () { askLogout(); });

  /* ---------- toggles (settings switches) ---------- */
  $$("[data-tgl]").forEach(function (sw) {
    sw.addEventListener("click", function (e) {
      e.stopPropagation();
      sw.classList.toggle("on");
      var wrap = sw.closest(".swrap");
      if (wrap) { var l = $(".l", wrap); if (l) l.textContent = sw.classList.contains("on") ? "Active" : "Inactive"; }
      if (sw.closest("#memList")) updateMemCount();
    });
  });

  /* ---------- password eye + strength ---------- */
  $$("[data-eye]").forEach(function (eye) {
    eye.addEventListener("click", function () {
      var inp = eye.parentElement.querySelector("input");
      inp.type = inp.type === "password" ? "text" : "password";
      eye.style.color = inp.type === "text" ? "var(--accent-deep)" : "var(--ink-4)";
    });
  });
  var newPw = document.getElementById("newPw");
  if (newPw) {
    var bars = $$("#pwStrength .bar"), stxt = document.getElementById("pwStxt");
    var labels = ["Too weak", "Weak", "Good", "Strong"];
    var colors = ["#E5484D", "#F6A609", "#5BCF37", "#1F7A1B"];
    newPw.addEventListener("input", function () {
      var v = newPw.value, s = 0;
      if (v.length >= 8) s++;
      if (/[A-Z]/.test(v) && /[a-z]/.test(v)) s++;
      if (/[0-9]/.test(v)) s++;
      if (/[^A-Za-z0-9]/.test(v)) s++;
      if (v.length === 0) s = 0;
      bars.forEach(function (b, i) { b.style.background = i < s ? colors[Math.max(0, s - 1)] : "#e2e8e2"; });
      stxt.textContent = v.length === 0 ? "Use 8+ characters with a mix of letters & numbers" : labels[Math.max(0, s - 1)];
      stxt.style.color = v.length === 0 ? "var(--ink-4)" : colors[Math.max(0, s - 1)];
    });
  }

  /* ---------- team search ---------- */
  var ts = document.getElementById("teamSearch");
  if (ts) ts.addEventListener("input", function () { applyTeam(); });

  /* ---------- filter chip rows (appointments / ticketing) ---------- */
  var tkStatus = "open", tkPriority = "all";
  var PRIO_LABEL = { all: "All", high: "High", med: "Medium", low: "Low" };
  function filterAppts(group) {
    $$("#app-appointments [data-appt-group]").forEach(function (g) {
      g.hidden = (g.getAttribute("data-appt-group") !== group);
    });
  }
  function filterTickets(status) {
    if (status) tkStatus = status;
    var n = 0;
    $$("#app-ticketing .tk-card").forEach(function (c) {
      var okS = (tkStatus === "all") || (c.getAttribute("data-status") === tkStatus);
      var prioEl = c.querySelector(".tk-prio");
      var pcls = prioEl ? (prioEl.classList.contains("high") ? "high" : prioEl.classList.contains("med") ? "med" : "low") : "";
      var okP = (tkPriority === "all") || (pcls === tkPriority);
      var show = okS && okP;
      c.style.display = show ? "" : "none";
      if (show) n++;
    });
    var head = document.getElementById("tkHead"), cnt = document.getElementById("tkCount");
    var base = (tkStatus === "all" ? "All tickets" : tkStatus.charAt(0).toUpperCase() + tkStatus.slice(1) + " tickets");
    if (head) head.textContent = (tkPriority === "all" ? base : PRIO_LABEL[tkPriority] + " \u00b7 " + base);
    if (cnt) cnt.textContent = n + (tkStatus === "resolved" ? " resolved" : " active");
  }
  $$(".chip-row").forEach(function (row) {
    var pane = row.closest(".app-pane");
    $$(".f-chip", row).forEach(function (c) {
      c.addEventListener("click", function () {
        $$(".f-chip", row).forEach(function (x) { x.classList.remove("on"); });
        c.classList.add("on");
        if (pane && pane.id === "app-appointments") filterAppts(c.getAttribute("data-appt"));
        else if (pane && pane.id === "app-ticketing") filterTickets(c.getAttribute("data-status"));
      });
    });
  });
  // apply the default-selected chip on load
  filterTickets("open");

  /* ---------- floating add buttons + logout ---------- */
  $$(".fab-add").forEach(function (b) {
    b.addEventListener("click", function () { toast(b.getAttribute("aria-label") || "Create"); });
  });
  var slo = $(".side-logout");
  if (slo) slo.addEventListener("click", function () { closeNav(); askLogout(); });

  /* ---------- bottom-sheet popover helper ---------- */
  var sheetScrim, sheetPop;
  function ensureSheet() {
    if (sheetScrim) return;
    sheetScrim = document.createElement("div"); sheetScrim.className = "sheet-scrim";
    sheetPop = document.createElement("div"); sheetPop.className = "sheet-pop";
    sheetScrim.addEventListener("click", closeSheet);
    ds.appendChild(sheetScrim); ds.appendChild(sheetPop);
  }
  function openSheet(html) {
    ensureSheet();
    sheetPop.innerHTML = html;
    requestAnimationFrame(function () { sheetScrim.classList.add("show"); sheetPop.classList.add("show"); });
    return sheetPop;
  }
  function closeSheet() { if (sheetPop) { sheetScrim.classList.remove("show"); sheetPop.classList.remove("show"); } }

  /* ---------- appointments: month picker (pill + calendar icon) ---------- */
  var MONTHS = ["January","February","March","April","May","June","July","August","September","October","November","December"];
  var apptMonth = 5, apptYear = 2026, tmpYear = apptYear;
  function renderMonthGrid() {
    return MONTHS.map(function (m, i) {
      var on = (i === apptMonth && tmpYear === apptYear) ? " on" : "";
      return '<button class="mcell' + on + '" data-m="' + i + '">' + m.slice(0, 3) + '</button>';
    }).join("");
  }
  function bindMonthCells(pop) {
    pop.querySelectorAll(".mcell").forEach(function (c) {
      c.addEventListener("click", function () {
        apptMonth = parseInt(c.getAttribute("data-m"), 10);
        apptYear = tmpYear;
        var pill = document.getElementById("apptPill");
        if (pill) pill.innerHTML = MONTHS[apptMonth].slice(0, 3) + " \u25be";
        closeSheet();
        toast("Showing " + MONTHS[apptMonth] + " " + apptYear);
      });
    });
  }
  function openMonthPicker() {
    tmpYear = apptYear;
    var pop = openSheet(
      '<div class="pop-grip"></div>' +
      '<div class="pop-head"><span class="pop-ttl">Select month</span></div>' +
      '<div class="year-nav"><button data-y="-1">\u2039</button><span class="y" id="popYear">' + tmpYear + '</span><button data-y="1">\u203a</button></div>' +
      '<div class="month-grid" id="monthGrid">' + renderMonthGrid() + '</div>'
    );
    pop.querySelectorAll("[data-y]").forEach(function (b) {
      b.addEventListener("click", function () {
        tmpYear += parseInt(b.getAttribute("data-y"), 10);
        document.getElementById("popYear").textContent = tmpYear;
        document.getElementById("monthGrid").innerHTML = renderMonthGrid();
        bindMonthCells(pop);
      });
    });
    bindMonthCells(pop);
  }
  var apptPill = document.getElementById("apptPill");
  if (apptPill) apptPill.addEventListener("click", openMonthPicker);
  var calIcon = $('#app-appointments [aria-label="Calendar"]');
  if (calIcon) calIcon.addEventListener("click", openMonthPicker);

  /* ---------- ticketing: priority filter (pill + filter icon) ---------- */
  function openTicketFilter() {
    var opts = [["all", "All priorities", ""], ["high", "High", "high"], ["med", "Medium", "med"], ["low", "Low", "low"]];
    var html = '<div class="pop-grip"></div><div class="pop-head"><span class="pop-ttl">Filter by priority</span></div><div class="pop-list">' +
      opts.map(function (o) {
        return '<button class="pop-opt' + (o[0] === tkPriority ? " on" : "") + '" data-p="' + o[0] + '">' +
          '<span class="pdot"><span class="d ' + o[2] + '"></span>' + o[1] + '</span>' +
          '<span class="tick"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="m5 12 4 4 10-11"/></svg></span></button>';
      }).join("") + '</div>';
    var pop = openSheet(html);
    pop.querySelectorAll("[data-p]").forEach(function (b) {
      b.addEventListener("click", function () {
        tkPriority = b.getAttribute("data-p");
        var pill = document.getElementById("tkPill");
        if (pill) pill.innerHTML = PRIO_LABEL[tkPriority] + " \u25be";
        filterTickets();
        closeSheet();
      });
    });
  }
  var tkPill = document.getElementById("tkPill");
  if (tkPill) tkPill.addEventListener("click", openTicketFilter);
  var filterIcon = $('#app-ticketing [aria-label="Filter"]');
  if (filterIcon) filterIcon.addEventListener("click", openTicketFilter);

  /* ---------- team: department filter + create ---------- */
  var deptFilter = "all";
  function applyTeam() {
    var q = (ts && ts.value ? ts.value.trim().toLowerCase() : "");
    $$("#sub-team .mem").forEach(function (m) {
      var okQ = !q || (m.getAttribute("data-q") || "").toLowerCase().indexOf(q) > -1;
      var okD = (deptFilter === "all") || (m.getAttribute("data-dept") === deptFilter);
      m.classList.toggle("hidden", !(okQ && okD));
    });
    updateMemCount();
  }
  function updateMemCount() {
    var all = $$("#memList .mem");
    var active = all.filter(function (m) { var sw = m.querySelector(".swrap .set-switch"); return sw && sw.classList.contains("on"); });
    var c = document.getElementById("memCount");
    if (c) c.textContent = all.length + " total \u00b7 " + active.length + " active";
  }
  var deptRow = document.getElementById("deptRow");
  if (deptRow) {
    deptRow.addEventListener("click", function (e) {
      var chip = e.target.closest(".f-chip"); if (!chip) return;
      $$(".f-chip", deptRow).forEach(function (x) { x.classList.remove("on"); });
      chip.classList.add("on");
      deptFilter = chip.getAttribute("data-dept");
      applyTeam();
    });
  }
  var deptForm = document.getElementById("deptForm");
  var deptInput = document.getElementById("deptInput");
  var deptNewBtn = document.getElementById("deptNewBtn");
  if (deptNewBtn) deptNewBtn.addEventListener("click", function () {
    deptForm.hidden = !deptForm.hidden;
    if (!deptForm.hidden && deptInput) deptInput.focus();
  });
  function addDept() {
    var name = (deptInput.value || "").trim();
    if (!name) { deptInput.focus(); return; }
    var exists = $$(".f-chip", deptRow).some(function (c) { return c.getAttribute("data-dept").toLowerCase() === name.toLowerCase(); });
    if (!exists) {
      var chip = document.createElement("button");
      chip.className = "f-chip"; chip.setAttribute("data-dept", name); chip.textContent = name;
      deptRow.insertBefore(chip, deptNewBtn);
      var sel = document.getElementById("invDept");
      if (sel) { var o = document.createElement("option"); o.textContent = name; sel.appendChild(o); }
      toast('Department \u201c' + name + '\u201d created');
    }
    deptInput.value = ""; deptForm.hidden = true;
  }
  var deptAdd = document.getElementById("deptAdd");
  if (deptAdd) deptAdd.addEventListener("click", addDept);
  if (deptInput) deptInput.addEventListener("keydown", function (e) { if (e.key === "Enter") addDept(); });

  /* ---------- team: invite member ---------- */
  var inviteForm = document.getElementById("inviteForm");
  function toggleInvite(show) {
    if (!inviteForm) return;
    inviteForm.hidden = (show === undefined) ? !inviteForm.hidden : !show;
    if (!inviteForm.hidden) { var n = document.getElementById("invName"); if (n) n.focus(); }
  }
  ["inviteBtn", "teamInviteIcon"].forEach(function (id) {
    var b = document.getElementById(id); if (b) b.addEventListener("click", function () { toggleInvite(); });
  });
  var invCancel = document.getElementById("invCancel");
  if (invCancel) invCancel.addEventListener("click", function () { toggleInvite(false); });

  var AV_COLORS = ["#22B0E8", "#7C5CFF", "#FF9416", "#E5499A", "#2BA84A", "#1E7FB0"];
  var MODS_BY_ROLE = { "Super Admin": ["all"], "Admin": ["Chat", "Leads", "Tickets"], "Agent": ["Chat", "Leads"] };
  var invSave = document.getElementById("invSave");
  if (invSave) invSave.addEventListener("click", function () {
    var nameEl = document.getElementById("invName"), emailEl = document.getElementById("invEmail");
    var name = (nameEl.value || "").trim(), email = (emailEl.value || "").trim();
    var role = document.getElementById("invRole").value, dept = document.getElementById("invDept").value;
    if (!name) { nameEl.focus(); return; }
    if (!email) { emailEl.focus(); return; }

    var roleCls = role === "Super Admin" ? "super" : role === "Admin" ? "admin" : "agent";
    var mods = MODS_BY_ROLE[role] || ["Chat"];
    var modsHtml = (mods[0] === "all")
      ? '<span class="mem-mod all">All modules</span>'
      : mods.map(function (m) { return '<span class="mem-mod">' + m + '</span>'; }).join("");
    var color = AV_COLORS[$$("#memList .mem").length % AV_COLORS.length];

    var el = document.createElement("div");
    el.className = "mem justadded";
    el.setAttribute("data-q", (name + " " + email + " " + role + " " + dept).toLowerCase());
    el.setAttribute("data-dept", dept);
    el.innerHTML =
      '<div class="mem-top"><div class="mem-av" style="background:' + color + '">' + name.charAt(0).toUpperCase() + '</div>' +
      '<div class="mem-id"><div class="row1"><span class="nm">' + name + '</span><span class="mem-role ' + roleCls + '">' + role + '</span></div><div class="mem-you">' + dept + '</div></div></div>' +
      '<div class="mem-contact"><div class="ln"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="5" width="18" height="14" rx="2"/><path d="m4 7 8 5 8-5"/></svg>' + email + '</div></div>' +
      '<div class="mem-foot"><div class="mem-mods">' + modsHtml + '</div><div class="swrap"><span class="l">Active</span><button class="set-switch on" data-tgl></button></div></div>';
    document.getElementById("memList").appendChild(el);

    var sw = el.querySelector("[data-tgl]");
    sw.addEventListener("click", function (e) {
      e.stopPropagation(); sw.classList.toggle("on");
      var l = el.querySelector(".swrap .l"); if (l) l.textContent = sw.classList.contains("on") ? "Active" : "Inactive";
      updateMemCount();
    });

    nameEl.value = ""; emailEl.value = "";
    toggleInvite(false);
    applyTeam();
    toast(name + " added to " + dept);
  });

  /* =========================================================
     AUTH — login screen + logout confirm
     ========================================================= */
  var loginScreen = document.getElementById("loginScreen");
  var logoutModal = document.getElementById("logoutModal");
  var pwForm  = document.getElementById("loginPwForm");
  var otpForm = document.getElementById("loginOtpForm");
  var loginSubtitle = document.getElementById("loginSubtitle");

  function showErr(el, msg) { if (el) { el.textContent = msg; el.classList.add("show"); } }
  function hideErr(el) { if (el) { el.classList.remove("show"); el.textContent = ""; } }

  function askLogout()  { if (logoutModal) logoutModal.classList.add("show"); }
  function hideLogout() { if (logoutModal) logoutModal.classList.remove("show"); }

  function showPwForm() {
    if (pwForm) pwForm.hidden = false;
    if (otpForm) otpForm.hidden = true;
    if (loginSubtitle) loginSubtitle.textContent = "Sign in to continue";
    hideErr(document.getElementById("loginErr"));
  }
  function showOtpForm() {
    if (pwForm) pwForm.hidden = true;
    if (otpForm) otpForm.hidden = false;
    if (loginSubtitle) loginSubtitle.textContent = "Verify it's you";
    var em = document.getElementById("loginEmail"), oe = document.getElementById("otpEmail");
    if (em && oe) oe.textContent = em.value.trim() || "your email";
    $$("#otpRow input").forEach(function (i) { i.value = ""; i.classList.remove("filled"); });
    hideErr(document.getElementById("otpErr"));
    var first = $("#otpRow input"); if (first) setTimeout(function () { first.focus(); }, 90);
    toast("Verification code sent");
  }

  function doLogout() {
    hideLogout();
    routeTo("dashboard");                 // reset so re-login lands fresh
    closeNav();
    showPwForm();
    ds.classList.add("logged-out");
    if (loginScreen) { loginScreen.classList.remove("anim"); void loginScreen.offsetWidth; loginScreen.classList.add("anim"); }
  }
  function doLogin() {
    ds.classList.remove("logged-out");
    toast("Welcome back, Eshan");
  }

  if (logoutModal) {
    var lcCancel = document.getElementById("logoutCancel"), lcOk = document.getElementById("logoutConfirm");
    if (lcCancel) lcCancel.addEventListener("click", hideLogout);
    if (lcOk) lcOk.addEventListener("click", doLogout);
    logoutModal.addEventListener("click", function (e) { if (e.target === logoutModal) hideLogout(); });
  }

  // password eye toggle
  var loginEye = document.getElementById("loginEye");
  if (loginEye) loginEye.addEventListener("click", function () {
    var inp = document.getElementById("loginPw");
    var reveal = inp.type === "password";
    inp.type = reveal ? "text" : "password";
    loginEye.classList.toggle("revealed", reveal);
  });

  // password sign-in
  if (pwForm) pwForm.addEventListener("submit", function (e) {
    e.preventDefault();
    var em = document.getElementById("loginEmail"), pw = document.getElementById("loginPw");
    var err = document.getElementById("loginErr");
    var okEmail = /\S+@\S+\.\S+/.test(em.value.trim());
    var okPw = pw.value.trim().length >= 4;
    document.getElementById("lfEmail").classList.toggle("invalid", !okEmail);
    document.getElementById("lfPw").classList.toggle("invalid", !okPw);
    if (!okEmail) { showErr(err, "Enter a valid email address"); em.focus(); return; }
    if (!okPw) { showErr(err, "Password must be at least 4 characters"); pw.focus(); return; }
    hideErr(err); doLogin();
  });

  // OTP toggles
  var toOtp = document.getElementById("loginToOtp"), toPw = document.getElementById("otpToPw");
  if (toOtp) toOtp.addEventListener("click", showOtpForm);
  if (toPw) toPw.addEventListener("click", showPwForm);

  // forgot password / sign up (demo affordances)
  var forgotBtn = document.getElementById("forgotPw");
  if (forgotBtn) forgotBtn.addEventListener("click", function () { toast("Password reset link sent to your email"); });
  var signUpBtn = document.getElementById("signUp");
  if (signUpBtn) signUpBtn.addEventListener("click", function () { toast("Ask your workspace admin for an invite"); });

  // OTP inputs: auto-advance, backspace, paste
  var otpInputs = $$("#otpRow input");
  otpInputs.forEach(function (inp, idx) {
    inp.addEventListener("input", function () {
      inp.value = inp.value.replace(/[^0-9]/g, "").slice(0, 1);
      inp.classList.toggle("filled", !!inp.value);
      if (inp.value && idx < otpInputs.length - 1) otpInputs[idx + 1].focus();
    });
    inp.addEventListener("keydown", function (e) {
      if (e.key === "Backspace" && !inp.value && idx > 0) otpInputs[idx - 1].focus();
    });
    inp.addEventListener("paste", function (e) {
      e.preventDefault();
      var d = ((e.clipboardData || window.clipboardData).getData("text") || "").replace(/[^0-9]/g, "").slice(0, 6).split("");
      d.forEach(function (ch, i) { if (otpInputs[i]) { otpInputs[i].value = ch; otpInputs[i].classList.add("filled"); } });
      var next = Math.min(d.length, otpInputs.length - 1); if (otpInputs[next]) otpInputs[next].focus();
    });
  });
  if (otpForm) otpForm.addEventListener("submit", function (e) {
    e.preventDefault();
    var err = document.getElementById("otpErr");
    var code = otpInputs.map(function (i) { return i.value; }).join("");
    if (code.length < 6) { showErr(err, "Enter all 6 digits"); return; }
    hideErr(err); doLogin();
  });

  /* ---------- init: boot splash -> login ---------- */
  routeTo("dashboard");
  bootSplash();

  function bootSplash() {
    var sp = document.getElementById("splashScreen");
    ds.classList.add("logged-out");
    if (!sp) return;
    ds.classList.add("booting");
    var travelLogo = sp.querySelector(".splash-logo");
    var heroLogo = document.querySelector("#loginScreen .brand-logo");
    if (travelLogo) travelLogo.classList.add("float");
    if (heroLogo) heroLogo.style.opacity = "0";   // hidden until the flying logo lands

    setTimeout(startLeave, 4300);

    function startLeave() {
      sp.classList.add("leaving");                 // robot push + bg fade (CSS)
      if (travelLogo && heroLogo) {
        // FLIP: fly the splash logo into the login hero logo's slot
        var s = travelLogo.getBoundingClientRect();
        var t = heroLogo.getBoundingClientRect();
        var dx = (t.left + t.width / 2) - (s.left + s.width / 2);
        var dy = (t.top + t.height / 2) - (s.top + s.height / 2);
        var scale = t.width / s.width;
        travelLogo.classList.remove("float");      // stop idle float so transform sticks
        travelLogo.style.transform = "none";       // settle at base before launch
        // wind-up, then Eva "pushes" the logo across
        setTimeout(function () {
          travelLogo.style.transition = "transform .72s cubic-bezier(.5,0,.15,1)";
          travelLogo.style.transform = "translate(" + dx + "px," + dy + "px) scale(" + scale + ")";
        }, 300);
      }
      // hand off to the real hero logo, then drop the splash
      setTimeout(function () {
        if (heroLogo) heroLogo.style.opacity = "";
        ds.classList.remove("booting");
        sp.classList.remove("leaving");
        if (travelLogo) { travelLogo.style.transition = ""; travelLogo.style.transform = ""; }
      }, 1120);
    }
  }
})();
