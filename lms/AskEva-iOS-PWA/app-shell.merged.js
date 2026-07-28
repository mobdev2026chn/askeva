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

  var ROUTES = ["home", "dashboard", "leads", "leadsettings", "chats", "appointments", "ticketing", "compose", "contacts", "profile", "settings"];

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

  /* ---------- routing + navigation-state preservation ---------- */
  function syncActive(route) {
    var navRoute = (route === "dashboard" || route === "leadsettings") ? "leads" : route;
    $$(".side-item").forEach(function (b) {
      b.classList.toggle("active", b.getAttribute("data-route") === navRoute);
    });
    var grp = document.getElementById("leadsGroup");
    if (grp && (route === "dashboard" || route === "leads" || route === "leadsettings")) grp.classList.add("open");
  }
  var curRoute = "chats";
  var scrollMem = {};
  var chatReturn = null;
  var SCROLLERS = {
    leads: "#app-leads .lp-sheet", dashboard: "#app-dashboard .d2-sheet",
    contacts: "#app-contacts .lp-sheet",
    appointments: "#app-appointments .lp-sheet", ticketing: "#app-ticketing .lp-sheet",
    settings: "#app-settings .lp-sheet", profile: "#app-profile .lp-sheet"
  };
  function scrollerFor(route) {
    var sel = SCROLLERS[route]; if (!sel) return null;
    var list = $$(sel);
    for (var i = 0; i < list.length; i++) { if (list[i] && list[i].scrollHeight - list[i].clientHeight > 4) return list[i]; }
    return list[0] || null;
  }
  function routeTo(route, opts) {
    opts = opts || {};
    if (curRoute && curRoute !== route) { var sc = scrollerFor(curRoute); if (sc) scrollMem[curRoute] = sc.scrollTop; }
    ROUTES.forEach(function (r) { ds.classList.remove("route-" + r); });
    ds.classList.add("route-" + route);
    syncActive(route);
    closeSubs();               // leaving settings closes any open sub-view
    if (route === "chats" && window.__chat && !opts.keepChat) window.__chat.showList();
    if (route !== "chats") { hideReturnPill(); chatReturn = null; ds.classList.remove("chat-conv"); }   // navigating away cancels the return context + clears chat-conv state
    curRoute = route;
    if (scrollMem[route] != null) { var s2 = scrollerFor(route); if (s2) requestAnimationFrame(function () { s2.scrollTop = scrollMem[route]; }); }
  }
  window.__appRoute = routeTo;   // exposed so the unified Leads tabs can switch sub-routes

  /* open Chat from another screen while remembering where to return.
     No floating pill anymore — the chat's own back arrow returns to the origin. */
  function hideReturnPill() { var p = document.getElementById("chatReturnPill"); if (p && p.parentNode) p.parentNode.removeChild(p); }

  /* When a chat was opened from another screen, its back arrow (#reopenBtn)
     should jump straight back to that screen instead of the chat list. */
  document.addEventListener("click", function (e) {
    var back = e.target.closest && e.target.closest("#reopenBtn");
    if (!back || !chatReturn) return;
    e.stopImmediatePropagation(); e.preventDefault();
    var r = chatReturn.route; chatReturn = null;
    routeTo(r);
  }, true);

  window.__openChatFrom = function (origin, chatId, label, opts) {
    chatReturn = { route: origin || curRoute, label: label || "back" };
    routeTo("chats", { keepChat: true });
    if (window.__chat) {
      if (chatId) window.__chat.openById(chatId);
      else if (opts && opts.name && window.__chat.openWith) window.__chat.openWith(opts.name, opts.phone);
      else window.__chat.showList();
    }
  };

  $$(".side-item").forEach(function (b) {
    b.addEventListener("click", function () {
      routeTo(b.getAttribute("data-route"));
      closeNav();
    });
  });

  /* logo + name in the sidebar header routes to Profile (Profile item removed from the nav) */
  (function () {
    var sl = $(".side-logo[data-route]");
    if (!sl) return;
    function go() { routeTo("profile"); closeNav(); }
    sl.addEventListener("click", go);
    sl.addEventListener("keydown", function (e) { if (e.key === "Enter" || e.key === " ") { e.preventDefault(); go(); } });
  })();

  /* ---------- expandable sidebar groups (Leads) ---------- */
  $$(".side-grouphd").forEach(function (h) {
    h.addEventListener("click", function () {
      var g = h.closest(".side-group");
      var open = g.classList.toggle("open");
      h.setAttribute("aria-expanded", open ? "true" : "false");
    });
  });

  /* ---------- lead card -> open its chat (remembers return) ---------- */
  $$("#app-leads [data-chat]").forEach(function (el) {
    el.addEventListener("click", function () {
      var id = el.getAttribute("data-chat");
      if (window.__openChatFrom) window.__openChatFrom("leads", id, "Lead");
      else { routeTo("chats", { keepChat: true }); if (window.__chat) window.__chat.openById(id); }
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
    if (seg === "companies") { big.textContent = "Companies"; sub.textContent = "5 companies · 6 leads"; }
    else { big.textContent = "All Leads"; if (window.__leadsTools) window.__leadsTools.refresh(); else sub.textContent = "6 leads · 3 active"; }
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

  /* ---------- app version (bump on each release) ---------- */
  window.AskEvaVersion = window.AskEvaVersion || "2.4.0";
  (function () {
    var sv = document.getElementById("setVersion");
    if (sv) sv.textContent = "AskEva \u00b7 v" + window.AskEvaVersion;
    var av = document.getElementById("aboutVersion");
    if (av) av.textContent = "v" + window.AskEvaVersion;
  })();

  /* ---------- toggles (settings switches) + persisted preferences ---------- */
  function prefGet(k, d) { try { var v = localStorage.getItem("askeva.pref." + k); return v == null ? d : v === "1"; } catch (e) { return d; } }
  function prefSet(k, v) { try { localStorage.setItem("askeva.pref." + k, v ? "1" : "0"); } catch (e) {} }
  function deviceEl() { return document.querySelector(".device-screen") || document.body; }
  function applyDark(on) { deviceEl().classList.toggle("theme-dark", !!on); document.documentElement.classList.toggle("theme-dark", !!on); }
  function applyCompact(on) { deviceEl().classList.toggle("theme-compact", !!on); }
  /* restore persisted preference toggles on load */
  $$("[data-pref]").forEach(function (sw) {
    var k = sw.getAttribute("data-pref");
    var on = prefGet(k, sw.classList.contains("on"));
    sw.classList.toggle("on", on);
    if (k === "appearance.dark") applyDark(on);
    if (k === "appearance.compact") applyCompact(on);
  });
  $$("[data-tgl]").forEach(function (sw) {
    sw.addEventListener("click", function (e) {
      e.stopPropagation();
      sw.classList.toggle("on");
      var on = sw.classList.contains("on");
      var wrap = sw.closest(".swrap");
      if (wrap) { var l = $(".l", wrap); if (l) l.textContent = on ? "Active" : "Inactive"; }
      var pref = sw.getAttribute("data-pref");
      if (pref) {
        prefSet(pref, on);
        if (pref === "appearance.dark") { applyDark(on); toast(on ? "Dark mode on" : "Dark mode off"); }
        else if (pref === "appearance.compact") { applyCompact(on); toast(on ? "Compact density on" : "Compact density off"); }
        else if (pref === "notif.push") toast(on ? "Push notifications enabled" : "Push notifications off");
        else if (pref === "notif.email") toast(on ? "Email digests enabled" : "Email digests off");
        else if (pref === "notif.sound") toast(on ? "In-app sounds on" : "In-app sounds off");
      }
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
  /* ---------- update password (validate + clear) ---------- */
  var updatePwBtn = document.getElementById("updatePwBtn");
  if (updatePwBtn) updatePwBtn.addEventListener("click", function () {
    var cur = document.getElementById("curPw"), nw = document.getElementById("newPw"), cf = document.getElementById("confPw");
    var curV = cur ? cur.value : "", nwV = nw ? nw.value : "", cfV = cf ? cf.value : "";
    if (!curV) { toast("Enter your current password"); if (cur) cur.focus(); return; }
    if (nwV.length < 8) { toast("New password must be at least 8 characters"); if (nw) nw.focus(); return; }
    if (!(/[A-Za-z]/.test(nwV) && /[0-9]/.test(nwV))) { toast("Use a mix of letters and numbers"); if (nw) nw.focus(); return; }
    if (nwV !== cfV) { toast("New passwords don't match"); if (cf) cf.focus(); return; }
    if (curV === nwV) { toast("New password must differ from current"); if (nw) nw.focus(); return; }
    if (cur) cur.value = ""; if (nw) nw.value = ""; if (cf) cf.value = "";
    if (typeof bars !== "undefined" && bars) bars.forEach(function (b) { b.style.background = "#e2e8e2"; });
    if (typeof stxt !== "undefined" && stxt) { stxt.textContent = "Use 8+ characters with a mix of letters & numbers"; stxt.style.color = "var(--ink-4)"; }
    try { localStorage.setItem("askeva.pref.pwUpdatedAt", Date.now().toString()); } catch (e) {}
    toast("Password updated successfully");
  });

  /* Team (Settings → Team) is owned by team-people.js — a view over the
     Agents store (window.AskEvaPeople). Its search is wired there. */

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
      var pcls = c.getAttribute("data-priority") ||
        (function (p) { return p ? (p.classList.contains("high") ? "high" : p.classList.contains("med") ? "med" : "low") : ""; })(c.querySelector(".tk-prio"));
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

  /* ---------- scan label + logout ---------- */
  var scanBtn = document.querySelector(".d2-scan");
  if (scanBtn) scanBtn.setAttribute("aria-label", "Scan business card");
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

  /* ---------- team: department filter, invite & member toggles ----------
     REMOVED in Pass 5. This was duplicate, DOM-only people management that
     did not persist and was disconnected from the Agents store. It now lives
     entirely in team-people.js, which renders Settings → Team from the single
     source of truth (window.AskEvaPeople) and writes back through it. */

  /* =========================================================
     AUTH — login screen + logout confirm
     ========================================================= */
  var loginScreen = document.getElementById("loginScreen");
  var logoutModal = document.getElementById("logoutModal");
  var pwForm  = document.getElementById("loginPwForm");
  var otpForm = document.getElementById("loginOtpForm");
  var twofaForm = document.getElementById("login2faForm");
  var bkForm = document.getElementById("loginBkForm");
  var loginSubtitle = document.getElementById("loginSubtitle");

  function showErr(el, msg) { if (el) { el.textContent = msg; el.classList.add("show"); } }
  function hideErr(el) { if (el) { el.classList.remove("show"); el.textContent = ""; } }

  function askLogout()  { if (logoutModal) logoutModal.classList.add("show"); }
  function hideLogout() { if (logoutModal) logoutModal.classList.remove("show"); }

  var signupForm = document.getElementById("loginSignupForm");
  var forgotForm = document.getElementById("loginForgotForm");
  var signinTitle = document.getElementById("signinTitle");
  var signupLine = document.getElementById("signupLine");

  function hideAllAuthForms() {
    if (pwForm) pwForm.hidden = true;
    if (otpForm) otpForm.hidden = true;
    if (twofaForm) twofaForm.hidden = true;
    if (bkForm) bkForm.hidden = true;
    if (signupForm) signupForm.hidden = true;
    if (forgotForm) forgotForm.hidden = true;
  }
  function setTitle(t) {
    if (!signinTitle) return;
    var n = signinTitle.firstChild;
    if (n && n.nodeType === 3) n.nodeValue = t;                              // leading text node (keeps the .ul span)
    else signinTitle.insertBefore(document.createTextNode(t), signinTitle.firstChild);
  }

  function showPwForm() {
    hideAllAuthForms();
    if (pwForm) pwForm.hidden = false;
    if (loginSubtitle) loginSubtitle.textContent = "Sign in to continue";
    if (signupLine) signupLine.hidden = false;
    setTitle("Sign in");
    hideErr(document.getElementById("loginErr"));
  }
  function showSignupForm() {
    hideAllAuthForms();
    if (signupForm) signupForm.hidden = false;
    if (signupLine) signupLine.hidden = true;
    setTitle("Welcome");
    hideErr(document.getElementById("signupErr"));
  }
  function showForgotForm() {
    hideAllAuthForms();
    if (forgotForm) forgotForm.hidden = false;
    if (signupLine) signupLine.hidden = true;
    setTitle("Reset password");
    hideErr(document.getElementById("forgotErr"));
    var ok = document.getElementById("fpSuccess"); if (ok) ok.hidden = true;
    var sb = document.getElementById("forgotSubmit"); if (sb) sb.textContent = "Send";
    var fe = document.getElementById("fpEmail"); if (fe) { fe.value = ""; setTimeout(function () { fe.focus(); }, 80); }
  }
  function showOtpForm() {
    hideAllAuthForms();
    if (otpForm) otpForm.hidden = false;
    if (signupLine) signupLine.hidden = false;
    setTitle("Sign in");
    if (loginSubtitle) loginSubtitle.textContent = "Verify it's you";
    var es = document.getElementById("otpEmailStep"), cs = document.getElementById("otpCodeStep");
    if (es) es.hidden = false; if (cs) cs.hidden = true;
    hideVerifyModal();
    var ein = document.getElementById("otpEmailInput"), lem = document.getElementById("loginEmail");
    if (ein) { if (lem && lem.value.trim()) ein.value = lem.value.trim(); setTimeout(function () { ein.focus(); }, 90); }
    hideErr(document.getElementById("otpEmailErr"));
  }
  /* registered email → the mobile number on file. null = no account registered (validation gate). */
  var SIGNUPS_KEY = "askeva.signups.v1";
  function loadSignups() { try { return JSON.parse(localStorage.getItem(SIGNUPS_KEY)) || {}; } catch (e) { return {}; } }
  function rememberSignup(email, phone) {
    if (!email) return;
    var m = loadSignups(); m[email.toLowerCase()] = String(phone || "").replace(/\D/g, "");
    try { localStorage.setItem(SIGNUPS_KEY, JSON.stringify(m)); } catch (e) {}
  }
  function registeredPhone(email) {
    var map = { "eshan@tunepath.com": "9876544322" };
    var key = (email || "").toLowerCase();
    return map[key] || loadSignups()[key] || null;                          // accounts created in-session can OTP / reset too
  }
  function maskPhone(n) { n = String(n || ""); return n.length >= 4 ? "********" + n.slice(-4) : "********"; }
  var pendingOtpEmail = "", pendingOtpPhone = "", pendingOtpCode = "";
  function showVerifyModal() { var m = document.getElementById("otpVerifyModal"); if (m) m.classList.add("show"); }
  function hideVerifyModal() { var m = document.getElementById("otpVerifyModal"); if (m) m.classList.remove("show"); }
  /* email entry is the validation gate: only registered emails proceed */
  function sendOtp() {
    var ein = document.getElementById("otpEmailInput"), err = document.getElementById("otpEmailErr");
    var email = (ein && ein.value.trim()) || "";
    if (!/\S+@\S+\.\S+/.test(email)) { showErr(err, "Enter a valid registered email"); if (ein) ein.focus(); return; }
    var raw = registeredPhone(email);
    if (!raw) { showErr(err, "No account is registered with this email"); if (ein) ein.focus(); return; }
    hideErr(err);
    pendingOtpEmail = email;
    pendingOtpPhone = maskPhone(raw);
    var vp = document.getElementById("otpVerifyPhone"); if (vp) vp.textContent = pendingOtpPhone;
    showVerifyModal();
  }
  /* modal “Send OTP” → actually send the code, advance to the code-entry step */
  function proceedToOtpCode() {
    hideVerifyModal();
    hideAllAuthForms();
    if (otpForm) otpForm.hidden = false;
    if (signupLine) signupLine.hidden = false;
    setTitle("Sign in");
    if (loginSubtitle) loginSubtitle.textContent = "Verify it's you";
    var oe = document.getElementById("otpEmail"); if (oe) oe.textContent = pendingOtpEmail;
    var op = document.getElementById("otpPhone"); if (op) op.textContent = pendingOtpPhone;
    var es = document.getElementById("otpEmailStep"), cs = document.getElementById("otpCodeStep");
    if (es) es.hidden = true; if (cs) cs.hidden = false;
    $$("#otpRow input").forEach(function (i) { i.value = ""; i.classList.remove("filled"); });
    hideErr(document.getElementById("otpErr"));
    pendingOtpCode = String(Math.floor(100000 + Math.random() * 900000));   // demo: real code, actually verified on submit
    var first = $("#otpRow input"); if (first) setTimeout(function () { first.focus(); }, 90);
    toast("Demo OTP " + pendingOtpCode + " sent to " + pendingOtpPhone);
  }

  function clearSession() {
    // Don't leave one user's CRM data for the next person on a shared device.
    // Clear PII stores + the reseed guard so a fresh login starts from clean seed data.
    var keys = ["askeva.leads.v1", "askeva.customers.v1", "askeva.leads.reseed.v1",
                "askeva.leads.tombstones.v1", "askeva.leads.filters.v1"];
    try { keys.forEach(function (k) { localStorage.removeItem(k); }); } catch (e) {}
  }
  function doLogout() {
    hideLogout();
    clearSession();
    routeTo("home");                      // reset so re-login lands fresh
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
    hideErr(err); maybe2FA();
  });

  // OTP toggles
  var toOtp = document.getElementById("loginToOtp"), toPw = document.getElementById("otpToPw");
  if (toOtp) toOtp.addEventListener("click", showOtpForm);
  if (toPw) toPw.addEventListener("click", showPwForm);
  var otpSendBtn = document.getElementById("otpSendBtn");
  if (otpSendBtn) otpSendBtn.addEventListener("click", sendOtp);
  var otpVerifyModal = document.getElementById("otpVerifyModal");
  if (otpVerifyModal) {
    var vSend = document.getElementById("otpVerifySend"), vClose = document.getElementById("otpVerifyClose");
    if (vSend) vSend.addEventListener("click", proceedToOtpCode);
    if (vClose) vClose.addEventListener("click", hideVerifyModal);
    otpVerifyModal.addEventListener("click", function (e) { if (e.target === otpVerifyModal) hideVerifyModal(); });
  }

  // forgot password / sign up — full screens
  var forgotBtn = document.getElementById("forgotPw");
  if (forgotBtn) forgotBtn.addEventListener("click", showForgotForm);
  var signUpBtn = document.getElementById("signUp");
  if (signUpBtn) signUpBtn.addEventListener("click", showSignupForm);
  var toLoginFromSignup = document.getElementById("toLoginFromSignup");
  if (toLoginFromSignup) toLoginFromSignup.addEventListener("click", showPwForm);
  var toLoginFromForgot = document.getElementById("toLoginFromForgot");
  if (toLoginFromForgot) toLoginFromForgot.addEventListener("click", showPwForm);

  // show/hide password eyes on the sign-up form
  $$('#loginSignupForm .uf-eye[data-eye]').forEach(function (btn) {
    btn.addEventListener("click", function () {
      var inp = document.getElementById(btn.getAttribute("data-eye"));
      if (!inp) return;
      var reveal = inp.type === "password";
      inp.type = reveal ? "text" : "password";
      btn.classList.toggle("revealed", reveal);
    });
  });

  // forgot-password submit → same validation gate as Login-with-OTP: registered email → OTP to mobile
  if (forgotForm) forgotForm.addEventListener("submit", function (e) {
    e.preventDefault();
    var fe = document.getElementById("fpEmail"), err = document.getElementById("forgotErr");
    var email = (fe.value || "").trim();
    var wrap = document.getElementById("fpEmailWrap");
    if (!/\S+@\S+\.\S+/.test(email)) { wrap.classList.add("invalid"); showErr(err, "Enter a valid email address"); fe.focus(); return; }
    var raw = registeredPhone(email);
    if (!raw) { wrap.classList.add("invalid"); showErr(err, "No account is registered with this email"); fe.focus(); return; }
    wrap.classList.remove("invalid"); hideErr(err);
    pendingOtpEmail = email;
    pendingOtpPhone = maskPhone(raw);
    var vp = document.getElementById("otpVerifyPhone"); if (vp) vp.textContent = pendingOtpPhone;
    showVerifyModal();
  });

  // sign-up submit → validate, confirm, return to login
  if (signupForm) signupForm.addEventListener("submit", function (e) {
    e.preventDefault();
    var err = document.getElementById("signupErr");
    var company = document.getElementById("suCompany"), contact = document.getElementById("suContact"),
        phone = document.getElementById("suPhone"), email = document.getElementById("suEmail"),
        pw = document.getElementById("suPw"), pw2 = document.getElementById("suPw2");
    function mark(id, bad) { var w = document.getElementById(id); if (w) w.classList.toggle("invalid", bad); }
    var okCompany = company.value.trim().length > 1;
    var okContact = contact.value.trim().length > 1;
    var okPhone = phone.value.replace(/\D/g, "").length >= 6;
    var okEmail = /\S+@\S+\.\S+/.test(email.value.trim());
    var okPw = pw.value.length >= 8 && /[A-Za-z]/.test(pw.value) && /[0-9]/.test(pw.value);   // match the change-password policy
    var okMatch = pw.value === pw2.value && pw2.value.length >= 8;
    mark("suCompanyWrap", !okCompany); mark("suContactWrap", !okContact); mark("suPhoneWrap", !okPhone);
    mark("suEmailWrap", !okEmail); mark("suPwWrap", !okPw); mark("suPw2Wrap", !okMatch);
    if (!okCompany) { showErr(err, "Enter your company name"); company.focus(); return; }
    if (!okContact) { showErr(err, "Enter the primary contact name"); contact.focus(); return; }
    if (!okPhone) { showErr(err, "Enter a valid WhatsApp number"); phone.focus(); return; }
    if (!okEmail) { showErr(err, "Enter a valid email address"); email.focus(); return; }
    if (!okPw) { showErr(err, "Use 8+ characters with letters and numbers"); pw.focus(); return; }
    if (!okMatch) { showErr(err, "Passwords do not match"); pw2.focus(); return; }
    hideErr(err);
    rememberSignup(email.value.trim(), phone.value);                        // so OTP login / reset recognise this account
    var em = document.getElementById("loginEmail"); if (em) em.value = email.value.trim();
    showPwForm();
    toast("Account created — please log in");
  });

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
      if (!d.length) { showErr(document.getElementById("otpErr"), "That doesn\u2019t look like a numeric code"); return; }
      d.forEach(function (ch, i) { if (otpInputs[i]) { otpInputs[i].value = ch; otpInputs[i].classList.add("filled"); } });
      var next = Math.min(d.length, otpInputs.length - 1); if (otpInputs[next]) otpInputs[next].focus();
    });
  });
  if (otpForm) otpForm.addEventListener("submit", function (e) {
    e.preventDefault();
    var err = document.getElementById("otpErr");
    var code = otpInputs.map(function (i) { return i.value; }).join("");
    if (code.length < 6) { showErr(err, "Enter all 6 digits"); return; }
    if (pendingOtpCode && code !== pendingOtpCode) {
      showErr(err, "Incorrect code. Check the OTP sent to your phone.");
      otpInputs.forEach(function (i) { i.value = ""; i.classList.remove("filled"); });
      if (otpInputs[0]) otpInputs[0].focus();
      return;
    }
    hideErr(err); pendingOtpCode = ""; maybe2FA();
  });

  /* ---------- 2FA gate at login (real authenticator code / backup code) ---------- */
  function maybe2FA() {
    // 2FA is enforced at login — no bypass. If the account has enrolled an
    // authenticator (Settings → Securities), require the live code or a backup
    // code before signing in.
    if (window.__security && window.__security.enabled && window.__security.enabled()) show2fa();
    else doLogin();
  }
  var twofaInputs = $$("#twofaRow input");
  function show2fa() {
    if (pwForm) pwForm.hidden = true; if (otpForm) otpForm.hidden = true; if (bkForm) bkForm.hidden = true;
    if (twofaForm) twofaForm.hidden = false;
    if (loginSubtitle) loginSubtitle.textContent = "Verify it's you";
    twofaInputs.forEach(function (i) { i.value = ""; i.classList.remove("filled"); });
    hideErr(document.getElementById("twofaErr"));
    if (twofaInputs[0]) setTimeout(function () { twofaInputs[0].focus(); }, 90);
  }
  function showBackup() {
    if (pwForm) pwForm.hidden = true; if (otpForm) otpForm.hidden = true; if (twofaForm) twofaForm.hidden = true;
    if (bkForm) bkForm.hidden = false;
    var bi = document.getElementById("bkCodeInput"); if (bi) { bi.value = ""; setTimeout(function () { bi.focus(); }, 90); }
    hideErr(document.getElementById("bkErr"));
  }
  twofaInputs.forEach(function (inp, idx) {
    inp.addEventListener("input", function () {
      inp.value = inp.value.replace(/[^0-9]/g, "").slice(0, 1);
      inp.classList.toggle("filled", !!inp.value);
      if (inp.value && idx < twofaInputs.length - 1) twofaInputs[idx + 1].focus();
    });
    inp.addEventListener("keydown", function (e) { if (e.key === "Backspace" && !inp.value && idx > 0) twofaInputs[idx - 1].focus(); });
    inp.addEventListener("paste", function (e) {
      e.preventDefault();
      var d = ((e.clipboardData || window.clipboardData).getData("text") || "").replace(/[^0-9]/g, "").slice(0, 6).split("");
      d.forEach(function (ch, i) { if (twofaInputs[i]) { twofaInputs[i].value = ch; twofaInputs[i].classList.add("filled"); } });
      var next = Math.min(d.length, twofaInputs.length - 1); if (twofaInputs[next]) twofaInputs[next].focus();
    });
  });
  if (twofaForm) twofaForm.addEventListener("submit", function (e) {
    e.preventDefault();
    var err = document.getElementById("twofaErr");
    var code = twofaInputs.map(function (i) { return i.value; }).join("");
    if (code.length < 6) { showErr(err, "Enter all 6 digits"); return; }
    if (!window.__security || !window.__security.verifyCode) {
      showErr(err, "Can\u2019t verify right now \u2014 try again in a moment.");   // fail closed: never wave through when the verifier is missing
      return;
    }
    window.__security.verifyCode(code).then(function (ok) {
      if (ok) { hideErr(err); doLogin(); }
      else { showErr(err, "Incorrect code. Open your authenticator app and enter the current 6-digit code."); twofaInputs.forEach(function (i) { i.value = ""; i.classList.remove("filled"); }); if (twofaInputs[0]) twofaInputs[0].focus(); }
    });
  });
  var twofaBack = document.getElementById("twofaBack"); if (twofaBack) twofaBack.addEventListener("click", showPwForm);
  var twofaUseBackup = document.getElementById("twofaUseBackup"); if (twofaUseBackup) twofaUseBackup.addEventListener("click", showBackup);
  if (bkForm) bkForm.addEventListener("submit", function (e) {
    e.preventDefault();
    var err = document.getElementById("bkErr"), bi = document.getElementById("bkCodeInput");
    var code = (bi ? bi.value : "").trim();
    if (code.length < 4) { showErr(err, "Enter a backup code"); return; }
    if (window.__security && window.__security.verifyBackup(code)) { hideErr(err); doLogin(); toast("Signed in with a backup code"); }
    else { showErr(err, "Invalid or already-used backup code."); if (bi) bi.focus(); }
  });
  var bkBack = document.getElementById("bkBack"); if (bkBack) bkBack.addEventListener("click", showPwForm);
  var bkUseAuth = document.getElementById("bkUseAuth"); if (bkUseAuth) bkUseAuth.addEventListener("click", show2fa);

  /* ---------- init: boot splash -> login ---------- */
  routeTo("home");
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

    var seenSplash = false;
    try { seenSplash = !!sessionStorage.getItem("askeva.splash.seen"); } catch (e) {}
    var holdMs = seenSplash ? 700 : 4300;         // short replay once you've seen it this session
    var started = false;
    var leaveT = setTimeout(startLeave, holdMs);
    function skip() { if (started) return; clearTimeout(leaveT); startLeave(); }
    sp.addEventListener("click", skip);           // tap anywhere to skip
    try { sessionStorage.setItem("askeva.splash.seen", "1"); } catch (e) {}

    function startLeave() {
      if (started) return; started = true;
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
