/* =========================================================
   AskEva — Appointments DETAIL / FORM / PAYMENTS / SETTINGS
   Companion to appointments.js — attaches the remaining views
   onto the shared AX namespace. Loaded AFTER appointments.js
   and BEFORE its deferred wire().
   ========================================================= */
(function (AX) {
  "use strict";
  if (!AX || !AX.pane) return;
  var $ = AX.$, $$ = AX.$$, I = AX.I, esc = AX.esc, pane = AX.pane;
  var detailEl = $("#axDetail"), formEl = $("#axForm");
  function show(el) { el.classList.add("show"); }
  function hide(el) { el.classList.remove("show"); }
  function initials(name) {
    var p = (name || "").trim().split(/\s+/);
    return ((p[0] || "")[0] || "") + ((p[1] || "")[0] || (p[0] || "")[1] || "");
  }
  function avColor(name) {
    var pal = ["#22B0E8", "#7C5CFF", "#FF9416", "#E5499A", "#2BA84A", "#1E7FB0", "#9A6B05"];
    var s = 0; for (var i = 0; i < (name || "").length; i++) s += name.charCodeAt(i);
    return pal[s % pal.length];
  }

  /* ============================================================
     DETAIL
     ============================================================ */
  AX.openDetail = function (id) {
    var a = AX.getAppt(id); if (!a) return;
    renderDetail(a); show(detailEl);
  };
  function renderDetail(a) {
    var dep = AX.deptById(a.department), u = AX.userById(a.user) || { name: "Unassigned", role: "", color: "#999", initials: "?" };
    var tm = AX.fmtTime(a.time), end = AX.fmtTime(a.time + a.dur);
    var rel = AX.relWord(a.date);
    var dayTxt = (rel ? rel + ", " : "") + AX.fmtDayLong(a.date);
    var upcoming = a.status === "confirmed" || a.status === "pending";
    var ic = initials(a.name).toUpperCase(), col = avColor(a.name);

    var statusTag = '<span class="ax-status ' + a.status + '">' + a.status.charAt(0).toUpperCase() + a.status.slice(1) + '</span>';
    var deptTag = '<span class="ax-typetag" style="color:' + dep.color + '">' + I.dept + dep.name + '</span>';
    var payTag = a.amount ? '<span class="ax-typetag">' + I.card + AX.inr(a.amount) + ' · ' + (a.paymentType === "prepaid" ? "Prepaid" : "Postpaid") + '</span>' : '';

    var actsHTML = upcoming ? '<div class="ax-actions">' +
      act("primary", I.phone, "Call", "call") + act("", I.msg, "Message", "message") + act("", I.repeat, "Reschedule", "reschedule") + '</div>' : '';

    var rows = '<div class="ax-info">' +
      row(I.clock, "When", dayTxt + " · " + tm.full + " – " + end.full) +
      row(I.calPlus, "Duration", AX.durLabel(a.dur)) +
      row(I.user, "Customer", esc(a.name) + (a.age ? " · " + a.age + " yrs" : "")) +
      row(I.phone, "Mobile", esc((a.cc || "+91") + " " + a.mobile)) +
      (a.dob ? row(I.cake, "Date of Birth", AX.fmtDayLong(a.dob).replace(/^\w+, /, "")) : "") +
      row(I.dept, "Department", esc(dep.name)) +
      row(I.users, "Assigned user", esc(u.name) + (u.role ? " · " + esc(u.role) : "")) +
    '</div>';

    var payRows = '<div class="ax-info" style="margin-top:14px">' +
      row(I.card, "Payment type", a.paymentType === "prepaid" ? "Prepaid" : "Postpaid") +
      row(I.rupee, "Amount", a.amount ? AX.inr(a.amount) : "—") +
      row(I.check2, "Payment status", '<span class="appt-pill ' + payCls(a.payStatus) + '" style="margin-top:2px">' + cap(a.payStatus) + '</span>', true) +
      (a.amount ? row(I.note, "Order ID", esc(a.orderId) + " · " + esc(a.method)) : "") +
      (a.feedback && a.feedback.rating ? row(I.star, "Feedback", fbSummary(a.feedback), true) : "") +
    '</div>';

    var note = '<div class="ax-note"><div class="hd"><div class="ic">' + I.note + '</div><div class="lbl">Description</div></div>' +
      '<div class="bd' + (a.description ? "" : " muted") + '">' + esc(a.description || "No description added.") + '</div></div>';

    var foot = "";
    if (a.status === "pending") foot = btn("primary", I.check, "Confirm appointment", "confirm") + btn2(btn("ghost", I.repeat, "Reschedule", "reschedule") + btn("danger", I.x, "Cancel", "cancel"));
    else if (a.status === "confirmed") foot = btn("primary", I.check, "Mark as complete", "complete") + btn2(btn("ghost", I.repeat, "Reschedule", "reschedule") + btn("danger", I.x, "Cancel", "cancel"));
    else if (a.status === "completed") {
      var hasFb = !!(a.feedback && a.feedback.rating);
      var needPay = a.amount > 0 && a.payStatus !== "paid";
      if (needPay) foot = btn("primary", I.card, "Request payment", "reqpay") + btn("ghost", I.calPlus, "Book follow-up", "rebook");
      else if (!hasFb) foot = btn("primary", I.star, "Request feedback", "reqfb") + btn("ghost", I.calPlus, "Book follow-up", "rebook");
      else foot = btn("ghost", I.calPlus, "Book follow-up", "rebook");
    }
    else foot = btn("primary", I.repeat, "Reschedule", "rebook") + btn("danger", I.trash, "Delete appointment", "delete");

    var topRight = (a.status === "cancelled" || a.status === "completed")
      ? '<button class="ax-iconbtn" data-act="delete" aria-label="Delete">' + I.trash + '</button>'
      : '<button class="ax-iconbtn" data-act="edit" aria-label="Edit">' + I.edit + '</button>';

    detailEl.innerHTML =
      '<div class="ax-bar"><button class="ax-iconbtn" data-x="back" aria-label="Back">' + I.back + '</button>' +
        '<div class="ttl">Appointment</div>' + topRight + '</div>' +
      '<div class="ax-scroll">' +
        '<div class="ax-hero"><div class="av" style="background:' + col + '">' + esc(ic) + '</div>' +
          '<div class="who"><div class="nm">' + esc(a.name) + '</div><div class="co">' + esc(dep.name) + ' · ' + esc(u.name) + '</div></div></div>' +
        '<div class="ax-statusrow">' + statusTag + deptTag + payTag + '</div>' +
        '<div class="ax-whenbig' + (upcoming ? "" : " flat") + '"><div><div class="day">' + esc(dayTxt) + '</div>' +
          '<div class="time">' + tm.full + '</div><div class="sub">Ends ' + end.full + ' · ' + AX.durLabel(a.dur) + '</div></div>' +
          '<button class="calbtn" data-act="addcal" aria-label="Add to calendar">' + I.calPlus + '</button></div>' +
        actsHTML + rows + payRows + note +
        '<div class="ax-foot">' + foot + '</div>' +
      '</div>';

    detailEl.querySelector('[data-x="back"]').addEventListener("click", function () { hide(detailEl); AX.render(); });
    $$("[data-act]", detailEl).forEach(function (b) { b.addEventListener("click", function () { detailAction(b.getAttribute("data-act"), a); }); });
    var sc = detailEl.querySelector(".ax-scroll"); if (sc) sc.scrollTop = 0;
  }
  function row(ic, k, v, raw) { return '<div class="r"><div class="ic">' + ic + '</div><div class="b"><div class="k">' + k + '</div>' + (raw ? v : '<div class="v">' + v + '</div>') + '</div></div>'; }
  function act(cls, ic, l, a) { return '<button class="ax-act ' + cls + '" data-act="' + a + '"><span class="ic">' + ic + '</span><span class="l">' + l + '</span></button>'; }
  function btn(cls, ic, l, a) { return '<button class="ax-btn ' + cls + '" data-act="' + a + '">' + ic + l + '</button>'; }
  function btn2(inner) { return '<div class="ax-btn2">' + inner + '</div>'; }
  function payCls(s) { return s === "paid" ? "completed" : s === "pending" ? "pending" : s === "refunded" ? "cancelled" : "cancelled"; }
  function cap(s) { return (s || "").charAt(0).toUpperCase() + (s || "").slice(1); }
  function fbSummary(fb) {
    if (!fb || !fb.rating) return "—";
    var stars = "";
    for (var i = 1; i <= 5; i++) stars += '<span class="ax-fbstar' + (i <= fb.rating ? " on" : "") + '">' + (i <= fb.rating ? I.starF : I.star) + '</span>';
    var tags = (fb.tags && fb.tags.length) ? '<div class="ax-fbtags">' + fb.tags.map(function (t) { return '<span class="ax-fbtag">' + esc(t) + '</span>'; }).join("") + '</div>' : "";
    var cm = fb.comment ? '<div class="ax-fbcomment">"' + esc(fb.comment) + '"</div>' : "";
    return '<div class="ax-fbwrap"><div class="ax-fbstars">' + stars + '<span class="ax-fbnum">' + fb.rating + '/5</span></div>' + tags + cm + '</div>';
  }

  function detailAction(act, a) {
    switch (act) {
      case "call":      AX.openCall(a); break;
      case "message":   AX.openChatWith(a); break;
      case "addcal":    AX.toast("Added to your calendar"); break;
      case "edit":      hide(detailEl); AX.openForm(a.id); break;
      case "reschedule":openReschedule(a); break;
      case "rebook":    hide(detailEl); AX.openForm(null, a); break;
      case "confirm":   a.status = "confirmed"; AX.save(); logApptActivity(a, "status", 'Appointment for "' + a.name + '" was confirmed', { prevStatus: "Pending", newStatus: "Confirmed" }); refresh(a, "Appointment confirmed"); break;
      case "complete":  a.status = "completed"; if (a.paymentType === "prepaid") a.payStatus = "paid"; AX.save(); logApptActivity(a, "completed", "Appointment completed"); refresh(a, "Marked as complete"); break;
      case "collect":
        if (window.__payGateway && a.amount > 0) {
          window.__payGateway(a.amount, {
            headNm: a.name || "Customer", headSub: "Appointment payment", totalLabel: "Amount due",
            success: function () {
              return {
                procT: "Processing payment\u2026", procS: "Securely charging\u2026",
                okT: "Payment Received", okS: AX.inr(a.amount) + " collected",
                toast: "Payment collected",
                onDone: function () { a.payStatus = "paid"; AX.save(); renderDetail(a); AX.render(); }
              };
            }
          });
        } else { a.payStatus = "paid"; AX.save(); refresh(a, "Payment collected"); }
        break;
      case "reqpay":    sendApptToChat(a, "pay"); break;
      case "reqfb":     sendApptToChat(a, "feedback"); break;
      case "cancel":    openCancel(a); break;
      case "delete":    AX.confirm({ title: "Delete appointment?", sub: "This permanently removes " + a.name + "'s appointment.", go: "Delete",
                          onGo: function () { logApptActivity(a, "deleted", "Appointment deleted \u00b7 " + AX.fmtDayShort(a.date) + ", " + AX.fmtTime(a.time).full); AX.delAppt(a.id); hide(detailEl); AX.render(); AX.toast("Appointment deleted"); } }); break;
    }
  }
  function refresh(a, msg) { renderDetail(a); AX.render(); AX.toast(msg); }

  /* PASS 4: write appointment events onto the appointment's OWN activity log
     AND cross-post onto the matching lead's timeline (keep both in sync). */
  function logApptActivity(a, kind, text, meta) {
    if (!a) return;
    try {
      if (!a.activity) a.activity = [{ kind: "created", text: 'Appointment for "' + a.name + '" was created', ts: a.createdTs || Date.now() }];
      a.activity.unshift({ kind: kind, text: text, ts: Date.now(), meta: meta || null });
      if (AX && AX.save) AX.save();
    } catch (e) {}
    try { if (window.AskEvaActivity) window.AskEvaActivity.log({ mobile: a.mobile, name: a.name }, { type: "appointment", text: text, module: "Appointments" }); } catch (e) {}
  }

  /* AUTOMATION: a booking/reschedule auto-schedules a reminder; a no-show
     auto-creates a follow-up task. Reminders land on the matching lead's
     Reminders list + timeline (no chat navigation). */
  function apptReminder(a, kind) {
    try {
      if (!a || !window.AskEvaAddReminder) return;
      var consultant = (AX.userById(a.user) || {}).name || a.user || "";
      var dept = (AX.deptById(a.department) || {}).name || "appointment";
      var hh = Math.floor(a.time / 60), mm = a.time % 60, p = function (n) { return (n < 10 ? "0" : "") + n; };
      var when = a.date + "T" + p(hh) + ":" + p(mm);
      var whenLabel = AX.fmtDayShort(a.date) + " \u00b7 " + AX.fmtTime(a.time).full;
      var desc = (kind === "noshow")
        ? "No-show follow-up \u2014 reschedule " + a.name + "'s " + dept
        : "Appointment reminder \u2014 " + dept + " on " + whenLabel;
      window.AskEvaAddReminder({ mobile: a.mobile, name: a.name },
        { desc: desc, when: when, whenLabel: whenLabel, agent: consultant, module: "Appointments" });
    } catch (e) {}
  }

  /* ---- Message: jump to the Chats tab and open the matching conversation ---- */
  AX.openChatWith = function (a) {
    hide(detailEl);
    var contacts = (window.__chat && window.__chat.contacts) || [];
    var nm = (a.name || "").trim().toLowerCase();
    var match = contacts.filter(function (c) { return (c.name || "").trim().toLowerCase() === nm; })[0];
    if (window.__openChatFrom) {
      window.__openChatFrom("appointments", match ? match.id : null, "Appointment", { name: a.name, phone: a.mobile });
    } else if (window.__appRoute) {
      window.__appRoute("chats", { keepChat: true });
      if (window.__chat) { if (match) window.__chat.openById(match.id); else if (window.__chat.openWith) window.__chat.openWith(a.name, a.mobile); else window.__chat.showList(); }
    }
  };

  /* ---- Appointment → Chat: send payment request, then feedback request ----
     Routes to the patient's chat and posts the request bubble. Payment success
     and feedback submission call back into AX (below) to update the appointment. */
  function sendApptToChat(a, kind) {
    var dept = (AX.deptById(a.department) || {}).name || "appointment";
    var consultant = (AX.userById(a.user) || {}).name || "";
    hide(detailEl);
    var fire = function () {
      if (!window.__chat) { AX.toast("Chat is unavailable"); return; }
      if (kind === "pay") {
        window.__chat.requestAppointmentPayment(
          { name: a.name, phone: a.mobile },
          { amount: a.amount, note: dept + (consultant ? " · " + consultant : ""), apptId: a.id, deptName: dept });
        AX.toast("Payment request sent in Chat");
      } else {
        window.__chat.requestAppointmentFeedback(
          { name: a.name, phone: a.mobile },
          { apptId: a.id, deptName: dept });
        AX.toast("Feedback request sent in Chat");
      }
    };
    if (window.__appRoute) { window.__appRoute("chats", { keepChat: true }); setTimeout(fire, 90); }
    else fire();
  }

  /* ---- bridges the Chat module calls back into when the patient acts ---- */
  AX.markApptPaid = function (id) {
    var a = AX.getAppt(id); if (!a) return;
    if (a.payStatus !== "paid") {
      a.payStatus = "paid";
      if (!a.orderId) { a.orderId = "ORD-" + (10500 + AX.appts.length); a.method = AX.METHODS[AX.appts.length % AX.METHODS.length]; }
      AX.save(); logApptActivity(a, "paid", "Payment received \u00b7 " + AX.inr(a.amount));
      AX.render(); if (detailEl.classList.contains("show")) AX.openDetail(a.id);
    }
  };
  /* ---- Appointment USER-ALERT: deliver the configured template into the
     customer's chat when a booking/reschedule/completion happens, IF that
     user alert is enabled in Appointment Settings. Silent (no navigation). ---- */
  function fillApptVars(s, a) {
    var dep = (AX.deptById(a.department) || {}).name || "";
    var u = (AX.userById(a.user) || {}).name || "";
    var map = {
      "Name": a.name || "", "Mobile Number": a.mobile || "", "Department": dep, "Select User": u,
      "Appointment Date": AX.fmtDayShort ? AX.fmtDayShort(a.date) : a.date,
      "Appointment Timing": AX.fmtTime ? AX.fmtTime(a.time).full : "",
      "Age": a.age || "", "Date of Birth": a.dob || ""
    };
    s = String(s || "");
    s = s.replace(/\{\{\s*Name\s*\}\}/gi, a.name || "there").replace(/\{\{\s*1\s*\}\}/g, a.name || "");
    Object.keys(map).forEach(function (k) { s = s.split("{{" + k + "}}").join(map[k]); s = s.split("{{ " + k + " }}").join(map[k]); });
    return s;
  }
  AX.notifyCustomer = function (a, key) {
    try {
      if (!a || !window.AskEvaApptAlerts || !window.__chat || !window.__chat.postApptAlert) return;
      if (!AskEvaApptAlerts.enabled("user", key)) return;
      var tpl = AskEvaApptAlerts.template("user", key);
      if (tpl) {
        window.__chat.postApptAlert({ name: a.name, phone: a.mobile },
          { n: tpl.n, text: fillApptVars(tpl.p, a), cat: tpl.cat });
      }
      // configured follow-ups — delivered after their delay (compressed for the
      // prototype: staggered a few seconds apart instead of the real hours/days)
      var fus = (AskEvaApptAlerts.followups("user", key)) || [];
      fus.forEach(function (f, i) {
        setTimeout(function () {
          try {
            window.__chat.postApptAlert({ name: a.name, phone: a.mobile },
              { n: f.n, text: fillApptVars(f.p, a), cat: f.cat });
          } catch (e) {}
        }, 3500 + i * 3000);
      });
    } catch (e) {}
  };

  AX.saveApptFeedback = function (id, data) {
    var a = AX.getAppt(id); if (!a || !data) return;
    a.rating = data.rating || 0;
    a.feedback = data.comment || "";
    a.feedbackTags = (data.tags || []).slice();
    a.feedbackAt = Date.now();
    AX.save(); logApptActivity(a, "feedback", "Feedback received \u00b7 " + a.rating + "\u2605");
    AX.render(); if (detailEl.classList.contains("show")) AX.openDetail(a.id);
  };

  /* ---- Call: route to the shared full-screen call UI (same screen used in Leads) ---- */
  AX.openCall = function (a) {
    if (window.__callScreen) window.__callScreen({ name: a.name, mobile: (a.cc || "+91").replace("+", "") + " " + a.mobile });
    else AX.toast("Calling " + (a.cc || "+91") + " " + a.mobile + "\u2026");
  };

  var CANCEL_REASONS = ["Customer requested", "Rescheduling needed", "No-show", "Duplicate booking", "Other"];
  function openCancel(a) {
    var chosen = CANCEL_REASONS[0];
    var html = '<div class="ax-grip"></div><div class="ax-sheet-head"><div><div class="ax-sheet-ttl">Cancel appointment</div>' +
      '<div class="ax-sheet-sub">' + esc(a.name) + ' · ' + AX.fmtDayShort(a.date) + '</div></div></div>' +
      '<div class="ax-reasons">' + CANCEL_REASONS.map(function (r, i) {
        return '<button class="ax-reason' + (i === 0 ? " on" : "") + '" data-r="' + esc(r) + '"><span class="rd"></span>' + esc(r) + '</button>'; }).join("") + '</div>' +
      '<button class="ax-sheetbtn" style="background:#E5484D;box-shadow:0 12px 28px -12px rgba(229,72,77,.7)" id="axCancelGo">Cancel this appointment</button>';
    var s = AX.openSheet(html);
    $$(".ax-reason", s).forEach(function (b) { b.addEventListener("click", function () {
      $$(".ax-reason", s).forEach(function (x) { x.classList.remove("on"); }); b.classList.add("on"); chosen = b.getAttribute("data-r"); }); });
    $("#axCancelGo", s).addEventListener("click", function () {
      a.status = "cancelled"; a.cancelReason = chosen;
      if (a.payStatus === "paid") a.payStatus = "refunded"; else a.payStatus = "failed";
      AX.save(); logApptActivity(a, "cancelled", "Appointment cancelled");
      if (chosen === "No-show") { logApptActivity(a, "noshow", "Marked no-show \u00b7 follow-up created"); apptReminder(a, "noshow"); }
      AX.closeSheet(); renderDetail(a); AX.render(); AX.toast(chosen === "No-show" ? "No-show \u00b7 follow-up task created" : "Appointment cancelled");
    });
  }

  function openReschedule(a) {
    var temp = { date: a.date, time: a.time };
    var s = AX.openSheet(body());
    function body() {
      return '<div class="ax-grip"></div><div class="ax-sheet-head"><div><div class="ax-sheet-ttl">Reschedule</div>' +
        '<div class="ax-sheet-sub">' + esc(a.name) + ' · ' + esc(AX.deptById(a.department).name) + '</div></div></div>' +
        '<label class="ax-label">Date</label><div class="ax-week" id="rsWeek" style="margin-bottom:16px"></div>' +
        '<label class="ax-label">Time</label><div class="ax-times" id="rsTimes"></div>' +
        '<button class="ax-sheetbtn" id="rsGo">Confirm new time</button>';
    }
    function week() {
      var host = $("#rsWeek", s), h = "", ap = apptCfg(a.user);
      if (ap && temp.date && !dateAvail(ap, temp.date)) temp.date = null;
      for (var i = 0; i < 21; i++) { var dd = AX.addDays(AX.TODAY, i), di = AX.iso(dd), lbl = AX.relWord(di);
        var dn = lbl === "Today" ? "TODAY" : lbl === "Tomorrow" ? "TMRW" : AX.DOW[dd.getDay()].toUpperCase();
        var avail = dateAvail(ap, di);
        h += '<button class="ax-wday' + (temp.date === di ? " on" : "") + (avail ? "" : " off") + '"' + (avail ? "" : " disabled") + ' data-d="' + di + '"><span class="dn">' + dn + '</span><span class="dd">' + dd.getDate() + '</span></button>'; }
      host.innerHTML = h;
      $$(".ax-wday[data-d]:not(.off)", host).forEach(function (b) { b.addEventListener("click", function () { temp.date = b.getAttribute("data-d"); week(); times(); }); });
    }
    function times() {
      var host = $("#rsTimes", s), ap = apptCfg(a.user), step = slotStep(ap), win = workWindow(ap);
      var occ = (ap && parseInt(ap.occupancy, 10) > 0) ? parseInt(ap.occupancy, 10) : 1;
      var counts = {};
      AX.appts.forEach(function (x) { if (x.date === temp.date && x.id !== a.id && x.status !== "cancelled" && x.user === a.user) counts[x.time] = (counts[x.time] || 0) + 1; });
      if (temp.time != null && (temp.time < win.start || temp.time + step > win.end || hourBlocked(ap, temp.time, step) || (counts[temp.time] || 0) >= occ)) temp.time = null;
      var h = "", any = false;
      for (var m = win.start; m + step <= win.end; m += step) {
        if (hourBlocked(ap, m, step)) continue;
        var full = (counts[m] || 0) >= occ; any = true;
        h += '<button class="ax-slot' + (temp.time === m ? " on" : "") + (full ? " taken" : "") + '" ' + (full ? "disabled" : "") + ' data-m="' + m + '">' + AX.fmtTime(m).full.replace(":00", "") + '</button>'; }
      host.innerHTML = any ? h : '<div class="ax-noslots">' + (!temp.date ? "Select a date." : (ap && !dateAvail(ap, temp.date) ? "Not available on this day." : "No available time slots.")) + '</div>';
      $$(".ax-slot:not(.taken)", host).forEach(function (b) { b.addEventListener("click", function () { temp.time = parseInt(b.getAttribute("data-m"), 10); times(); }); });
    }
    week(); times();
    $("#rsGo", s).addEventListener("click", function () {
      a.date = temp.date; a.time = temp.time; a.rescheduled = true;
      if (a.status === "cancelled" || a.status === "completed") { a.status = "pending"; if (a.payStatus !== "paid") a.payStatus = "pending"; }
      AX.save(); logApptActivity(a, "rescheduled", "Appointment rescheduled to " + AX.fmtDayShort(temp.date) + ", " + AX.fmtTime(temp.time).full); apptReminder(a); AX.closeSheet(); renderDetail(a); AX.render(); AX.toast("Rescheduled to " + AX.fmtDayShort(temp.date) + ", " + AX.fmtTime(temp.time).full);
    });
  }

  /* ============================================================
     CREATE / EDIT FORM
     ============================================================ */
  var draft = null, editingId = null;
  AX.openForm = function (id, cloneFrom) {
    editingId = id || null;
    if (id) { var a = AX.getAppt(id);
      draft = { name: a.name, age: a.age, mobile: a.mobile, cc: a.cc || "+91", dob: a.dob, department: a.department, user: a.user,
        date: a.date, time: a.time, dur: a.dur, description: a.description, bio: a.bio || "", mode: a.mode || "Online", paymentType: a.paymentType, amount: a.amount }; }
    else if (cloneFrom) { var c = cloneFrom;
      draft = { name: c.name, age: c.age, mobile: c.mobile, cc: c.cc || "+91", dob: c.dob, department: c.department, user: c.user,
        date: AX.TODAY_ISO, time: null, dur: c.dur, description: "", bio: c.bio || "", mode: c.mode || "Online", paymentType: c.paymentType, amount: c.amount }; }
    else draft = { name: "", age: "", mobile: "", cc: "+91", dob: "", department: "consult", user: "eshan",
        date: AX.TODAY_ISO, time: null, dur: 30, description: "", bio: "", mode: "Online", paymentType: "prepaid", amount: "" };
    // amount + duration come from the selected agent's master configuration
    if (!draft.cf) { var _ed = editingId && AX.getAppt(editingId); draft.cf = (_ed && _ed.cf) ? Object.assign({}, _ed.cf) : (cloneFrom && cloneFrom.cf ? Object.assign({}, cloneFrom.cf) : {}); }
    if (!editingId) { var _c = apptCfg(draft.user); if (_c && _c.amount) draft.amount = _c.amount; }
    renderForm(); show(formEl);
  };

  /* custom booking-form fields configured in Settings → Booking Form */
  function bfList() { return (AX.bookingFields && AX.bookingFields()) || null; }
  function bfReq(on) { return on ? ' <span style="color:#EF5350">*</span>' : ''; }
  function bfCustomHTML() {
    var l = bfList(); if (!l) return '';
    return l.filter(function (f) { return f.custom; }).map(function (f) {
      var val = esc(draft.cf[f.id] || '');
      var lbl = '<label class="ax-label">' + esc(f.name) + bfReq(f.req) + '</label>';
      if (f.type === 'textarea') return '<div class="ax-field">' + lbl + '<div class="ax-control area"><textarea data-cf="' + f.id + '" rows="3" placeholder="' + esc(f.ph || '') + '">' + val + '</textarea></div></div>';
      var itype = f.type === 'number' ? 'number' : (f.type === 'date' ? 'date' : (f.type === 'time' ? 'time' : 'text'));
      return '<div class="ax-field">' + lbl + '<div class="ax-control">' + I.note + '<input data-cf="' + f.id + '" type="' + itype + '" placeholder="' + esc(f.ph || '') + '" value="' + val + '"></div></div>';
    }).join('');
  }

  function renderForm() {
    var dep = AX.deptById(draft.department), u = AX.userById(draft.user);
    if (draft.mode !== "Virtual" && draft.mode !== "Manual") draft.mode = "Virtual";
    formEl.innerHTML =
      '<div class="ax-bar"><button class="ax-iconbtn" data-x="close" aria-label="Close">' + I.x + '</button>' +
        '<div class="ttl">' + (editingId ? "Edit appointment" : "New appointment") + '</div><span class="spacer"></span></div>' +
      '<div class="ax-scroll" id="axFormScroll">' +
        '<div class="ax-field"><label class="ax-label">Name</label><div class="nf-custwrap"><div class="ax-control">' + I.user +
          '<input id="fName" type="text" autocomplete="off" placeholder="Search existing customer or enter name" value="' + esc(draft.name) + '"></div><div class="nf-sugg" id="fNameSugg" hidden></div></div></div>' +
        '<div class="ax-field" style="display:grid;grid-template-columns:1fr 1fr;gap:11px">' +
          '<div><label class="ax-label">Age</label><div class="ax-control"><input id="fAge" type="number" inputmode="numeric" placeholder="Age" value="' + esc(draft.age) + '"></div></div>' +
          '<div><label class="ax-label">Date of Birth</label><button class="ax-pick" id="fDob" style="padding:11px 13px"><span class="ic" style="width:32px;height:32px;flex:0 0 32px">' + I.cake + '</span>' +
            '<span class="t"><span class="a' + (draft.dob ? "" : " ph") + '" style="font-size:13.5px">' + (draft.dob ? AX.fmtDayShort(draft.dob).replace(/^\w+ /, "") : "Select") + '</span></span></button></div></div>' +
        '<div class="ax-field"><label class="ax-label">Mobile Number</label>' +
          '<div class="ap-mobrow"><select id="fCC" data-uxdd-codeonly>' + (window.AskEvaCCOptions ? window.AskEvaCCOptions(draft.cc || "+91", { format: function (n, c) { return c + "  " + n; } }) : '<option value="+91">+91  India</option>') + '</select>' +
          '<input id="fMobile" type="tel" inputmode="numeric" placeholder="Enter mobile number" value="' + esc(draft.mobile) + '"></div></div>' +
        '<div class="ax-field"><label class="ax-label">Department</label>' + pick("fDept", I.dept, dep ? dep.name : "Select Department", dep ? "" : "ph") + '</div>' +
        '<div class="ax-field"><label class="ax-label">Select User</label>' +
          '<button class="ax-pick" id="fUser">' + (u ? '<span class="av" style="background:' + u.color + '">' + esc(u.initials) + '</span><span class="t"><span class="a">' + esc(u.name) + '</span><span class="b">' + esc(u.role) + '</span></span>'
            : '<span class="av empty">' + I.users + '</span><span class="t"><span class="a ph">Select User</span></span>') + '<span class="chev">' + I.chevR + '</span></button></div>' +
        '<div class="ax-field"><label class="ax-label">Appointment Date</label><div class="ax-week" id="fWeek"></div></div>' +
        '<div class="ax-field"><label class="ax-label">Appointment Timing</label><div class="ax-times" id="fTimes"></div></div>' +
        '<div class="ax-field"><label class="ax-label">Description</label><div class="ax-control area"><textarea id="fDesc" rows="3" maxlength="300" placeholder="Enter description">' + esc(draft.description) + '</textarea><span class="ap-count" id="fCount">' + (draft.description || "").length + ' / 300</span></div></div>' +
        bfCustomHTML() +
        '<div class="ax-field"><label class="ax-label">Bio</label><div class="ax-control">' + I.note +
          '<input id="fBio" type="text" placeholder="Enter bio" value="' + esc(draft.bio) + '"></div></div>' +
        '<div class="ax-field"><label class="ax-label">Appointment mode</label><div class="ax-chiprow" id="fMode">' +
          ["Virtual", "Manual"].map(function (m) { return '<button class="ax-pillchip' + (draft.mode === m ? " on" : "") + '" data-m="' + m + '">' + m + '</button>'; }).join("") + '</div></div>' +
        '<div class="ax-field"><label class="ax-label">Payment Type</label><div class="ap-paytype" id="fPay">' +
          ptype("prepaid", I.card, "Prepaid") + ptype("postpaid", I.clock, "Postpaid") + '</div></div>' +
      '</div>' +
      '<div class="ax-savebar"><button class="ax-btn primary" id="fSave">' + I.check + (editingId ? "Save changes" : "Create Appointment") + '</button></div>';
    renderWeek(); renderTimes(); bindForm();
  }
  function pick(id, ic, label, ph) {
    return '<button class="ax-pick" id="' + id + '"><span class="ic">' + ic + '</span><span class="t"><span class="a ' + (ph || "") + '">' + esc(label) + '</span></span><span class="chev">' + I.chevR + '</span></button>';
  }
  function ptype(v, ic, label) {
    return '<button class="ax-type' + (draft.paymentType === v ? " on" : "") + '" data-p="' + v + '"><span class="ic">' + ic + '</span><span class="l">' + label + '</span></button>';
  }
  /* ---- agent availability helpers (synced from Settings → Agents → Appointment) ---- */
  var DAY_NAMES = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];
  function apptCfg(userId) { if (!userId || !window.AskEvaAgentCfg || !AskEvaAgentCfg.get) return null; var c = AskEvaAgentCfg.get(userId); return (c && c.appointment) ? c.appointment : null; }
  function hhmm(s) { var p = (s || "").split(":"); return p.length === 2 ? (+p[0]) * 60 + (+p[1]) : null; }
  function dateAvail(ap, iso) {
    if (!ap) return true;
    var d = new Date(iso + "T00:00:00");
    if (ap.days && ap.days.length && ap.days.indexOf(DAY_NAMES[d.getDay()]) < 0) return false;
    if (ap.ranges && ap.ranges.length && !ap.ranges.some(function (r) { return iso >= r.start && iso <= r.end; })) return false;
    if (ap.unavailDates && ap.unavailDates.indexOf(iso) > -1) return false;
    return true;
  }
  function slotStep(ap) {
    if (!ap || !ap.slotDur) return 30;
    var n = parseFloat(ap.slotDur); if (isNaN(n)) return 30;
    return (ap.slotType === "Minutes") ? Math.max(5, Math.round(n)) : Math.max(15, Math.round(n * 60));
  }
  function workWindow(ap) {
    var s = 540, e = 1140;
    if (ap && ap.workStart && ap.workEnd) { var ws = hhmm(ap.workStart), we = hhmm(ap.workEnd); if (ws != null && we != null && we > ws) { s = ws; e = we; } }
    return { start: s, end: e };
  }
  function hourBlocked(ap, m, step) {
    if (!ap || !ap.unavailHours || !ap.unavailHours.length) return false;
    return ap.unavailHours.some(function (u) { var s = hhmm(u.start), e = hhmm(u.end); return s != null && e != null && m < e && (m + step) > s; });
  }

  function renderWeek() {
    var host = $("#fWeek"); if (!host) return; var h = "", ap = apptCfg(draft.user);
    if (ap && draft.date && !dateAvail(ap, draft.date)) draft.date = null;
    for (var i = 0; i < 21; i++) {
      var dd = AX.addDays(AX.TODAY, i), di = AX.iso(dd), lbl = AX.relWord(di);
      var dn = lbl === "Today" ? "TODAY" : lbl === "Tomorrow" ? "TMRW" : AX.DOW[dd.getDay()].toUpperCase();
      var avail = dateAvail(ap, di);
      h += '<button class="ax-wday' + (draft.date === di ? " on" : "") + (avail ? "" : " off") + '"' + (avail ? "" : " disabled") + ' data-d="' + di + '"><span class="dn">' + dn + '</span><span class="dd">' + dd.getDate() + '</span></button>';
    }
    h += '<button class="ax-wday more" id="fMoreDate" aria-label="Pick date">' + I.cal + '</button>';
    host.innerHTML = h;
    // if the agent's availability greys out the leading dates, auto-select the first
    // available one and scroll it into view so the user always has a valid, visible pick
    if (!draft.date) {
      var fa = host.querySelector('.ax-wday[data-d]:not(.off)');
      if (fa) { draft.date = fa.getAttribute("data-d"); fa.classList.add("on"); host.scrollLeft = Math.max(0, fa.offsetLeft - 40); }
    } else {
      var sel = host.querySelector('.ax-wday.on'); if (sel) host.scrollLeft = Math.max(0, sel.offsetLeft - 40);
    }
    $$(".ax-wday[data-d]:not(.off)", host).forEach(function (b) { b.addEventListener("click", function () {
      draft.date = b.getAttribute("data-d"); $$(".ax-wday", host).forEach(function (x) { x.classList.remove("on"); }); b.classList.add("on");
      // keep the tapped date fully in view (it was getting half-clipped at the strip edges)
      host.scrollLeft = Math.max(0, b.offsetLeft - (host.clientWidth - b.offsetWidth) / 2);
      renderTimes(); }); });
    $("#fMoreDate", host).addEventListener("click", function () { AX.calendar({ sel: draft.date, allowPast: false, title: "Appointment date", onPick: function (di) {
      var ap2 = apptCfg(draft.user); if (ap2 && !dateAvail(ap2, di)) { AX.toast("This agent isn't available on that date"); return; }
      draft.date = di; renderWeek(); renderTimes(); } }); });
  }
  function renderTimes() {
    var host = $("#fTimes"); if (!host) return;
    var ap = apptCfg(draft.user), step = slotStep(ap), win = workWindow(ap);
    draft.dur = step; // duration is dictated by the agent's slot configuration
    var occ = (ap && parseInt(ap.occupancy, 10) > 0) ? parseInt(ap.occupancy, 10) : 1;
    var counts = {};
    AX.appts.forEach(function (a) { if (a.date === draft.date && a.id !== editingId && a.status !== "cancelled" && (!draft.user || a.user === draft.user)) counts[a.time] = (counts[a.time] || 0) + 1; });
    if (draft.time != null && (draft.time < win.start || draft.time + step > win.end || hourBlocked(ap, draft.time, step) || (counts[draft.time] || 0) >= occ)) draft.time = null;
    var h = "", any = false;
    for (var m = win.start; m + step <= win.end; m += step) {
      if (hourBlocked(ap, m, step)) continue;
      var full = (counts[m] || 0) >= occ; any = true;
      h += '<button class="ax-slot' + (draft.time === m ? " on" : "") + (full ? " taken" : "") + '" ' + (full ? "disabled" : "") + ' data-m="' + m + '">' + AX.fmtTime(m).full.replace(":00", "") + '</button>';
    }
    host.innerHTML = any ? h : '<div class="ax-noslots">' + (!draft.date ? "Select a date to see available times." : (ap && !dateAvail(ap, draft.date) ? "Agent is not available on this day." : "No available time slots for this day.")) + '</div>';
    $$(".ax-slot:not(.taken)", host).forEach(function (b) { b.addEventListener("click", function () {
      draft.time = parseInt(b.getAttribute("data-m"), 10); $$(".ax-slot", host).forEach(function (x) { x.classList.remove("on"); }); b.classList.add("on"); }); });
  }
  function bindForm() {
    formEl.querySelector('[data-x="close"]').addEventListener("click", function () { hide(formEl); });
    (function () {
      var inp = $("#fName"), sugg = $("#fNameSugg");
      if (!inp) return;
      function closeS() { if (sugg) { sugg.hidden = true; sugg.innerHTML = ""; } }
      function apptCustomers() {
        var out = [], seen = {};
        try { (window.AskEvaLeads || []).forEach(function (L) { if (L.status !== "converted") return; var k = (L.name || "").trim().toLowerCase() + "|" + (L.mobile || "").replace(/\D/g, ""); if (seen[k]) return; seen[k] = 1; out.push({ name: L.name || "", mobile: (L.mobile || "").replace(/\D/g, "") }); }); } catch (e) {}
        return out;
      }
      function fill(c) { draft.name = c.name; inp.value = c.name; if (c.mobile) { draft.mobile = c.mobile; var mb = $("#fMobile"); if (mb) mb.value = c.mobile; } closeS(); }
      function renderS() {
        if (!sugg) return;
        var q = inp.value.trim().toLowerCase();
        var list = (q ? apptCustomers().filter(function (c) { return c.name.toLowerCase().indexOf(q) > -1 || (c.mobile || "").indexOf(q) > -1; }) : apptCustomers()).slice(0, 6);
        if (!list.length) { closeS(); return; }
        sugg.innerHTML = list.map(function (c, i) { return '<button type="button" class="nf-suggopt" data-i="' + i + '"><span class="nm">' + esc(c.name) + '</span>' + (c.mobile ? '<span class="mb">' + esc(c.mobile) + '</span>' : "") + '</button>'; }).join("");
        sugg.hidden = false;
        sugg.querySelectorAll(".nf-suggopt").forEach(function (b) { b.addEventListener("mousedown", function (e) { e.preventDefault(); fill(list[+b.getAttribute("data-i")]); }); });
      }
      inp.addEventListener("input", function () { draft.name = inp.value; renderS(); });
      inp.addEventListener("focus", renderS);
      inp.addEventListener("blur", function () { setTimeout(closeS, 160); });
    }());
    $("#fAge").addEventListener("input", function (e) { draft.age = e.target.value; });
    $("#fMobile").addEventListener("input", function (e) { var mx = (window.AskEvaPhoneLen ? window.AskEvaPhoneLen(draft.cc || "+91").max : 15); draft.mobile = e.target.value.replace(/\D/g, "").slice(0, mx); e.target.value = draft.mobile; });
    (function () { var cc = $("#fCC"); if (cc) cc.addEventListener("change", function (e) { draft.cc = e.target.value; var mx = (window.AskEvaPhoneLen ? window.AskEvaPhoneLen(draft.cc).max : 15); draft.mobile = (draft.mobile || "").slice(0, mx); var mob = $("#fMobile"); if (mob) mob.value = draft.mobile; }); })();
    $("#fDob").addEventListener("click", function () { AX.calendar({ sel: draft.dob || "1995-01-01", dots: false, title: "Date of birth", onPick: function (di) { draft.dob = di; draft.age = AX.ageFromDob(di); renderForm(); } }); });
    $("#fDept").addEventListener("click", openDeptPick);
    $("#fUser").addEventListener("click", openUserPick);
    var desc = $("#fDesc"); desc.addEventListener("input", function () { draft.description = desc.value; $("#fCount").textContent = desc.value.length + " / 300"; });
    $("#fBio").addEventListener("input", function (e) { draft.bio = e.target.value; });
    $$("#fMode .ax-pillchip").forEach(function (b) { b.addEventListener("click", function () {
      draft.mode = b.getAttribute("data-m"); $$("#fMode .ax-pillchip").forEach(function (x) { x.classList.remove("on"); }); b.classList.add("on"); }); });
    $$("#fPay .ax-type").forEach(function (b) { b.addEventListener("click", function () {
      draft.paymentType = b.getAttribute("data-p"); $$("#fPay .ax-type").forEach(function (x) { x.classList.remove("on"); }); b.classList.add("on"); }); });
    $$("[data-cf]", formEl).forEach(function (el) { el.addEventListener("input", function () { draft.cf[el.getAttribute("data-cf")] = el.value; }); });
    $("#fSave").addEventListener("click", saveForm);
  }
  function openDeptPick() {
    var html = '<div class="ax-grip"></div><div class="ax-sheet-head"><div class="ax-sheet-ttl">Select Department</div></div><div class="ax-optlist clean">' +
      AX.DEPTS.map(function (d) { return '<button class="ax-opt clean' + (draft.department === d.id ? " on" : "") + '" data-id="' + d.id + '">' +
        '<span class="t"><span class="nm">' + esc(d.name) + '</span></span><span class="tick">' + I.check + '</span></button>'; }).join("") + '</div>';
    var s = AX.openSheet(html);
    $$(".ax-opt", s).forEach(function (b) { b.addEventListener("click", function () {
      draft.department = b.getAttribute("data-id");
      if (draft.user && window.AskEvaAgentCfg && AskEvaAgentCfg.usersForApptDept) {
        var ok = AskEvaAgentCfg.usersForApptDept(draft.department).some(function (u) { return u.id === draft.user; });
        if (!ok) draft.user = null;
      }
      AX.closeSheet(); renderForm();
    }); });
  }
  function openUserPick() {
    if (!draft.department) { AX.toast("Select a department first"); return; }
    var list = (window.AskEvaAgentCfg && AskEvaAgentCfg.usersForApptDept) ? AskEvaAgentCfg.usersForApptDept(draft.department) : AX.USERS;
    var rows = list.length ? list.map(function (u) { return '<button class="ax-opt' + (draft.user === u.id ? " on" : "") + '" data-id="' + u.id + '">' +
      '<span class="av" style="background:' + u.color + '">' + esc(u.initials) + '</span><span class="t"><span class="nm">' + esc(u.name) + (u.you ? " (You)" : "") + '</span><span class="co">' + esc(u.role) + '</span></span><span class="tick">' + I.check + '</span></button>'; }).join("")
      : '<div class="ax-empty" style="padding:26px 16px;text-align:center;color:var(--ink-4)"><div class="t" style="font-weight:800;color:var(--ink-2)">No users in this department</div><div class="s" style="font-size:12.5px;margin-top:5px;line-height:1.5">Assign agents to this department in Settings \u2192 Agents \u2192 Appointment.</div></div>';
    var html = '<div class="ax-grip"></div><div class="ax-sheet-head"><div class="ax-sheet-ttl">Select User</div></div><div class="ax-optlist">' + rows + '</div>';
    var s = AX.openSheet(html);
    $$(".ax-opt", s).forEach(function (b) { b.addEventListener("click", function () {
      draft.user = b.getAttribute("data-id");
      var cfg = apptCfg(draft.user);
      if (cfg && cfg.amount) draft.amount = cfg.amount; // amount is set by the agent's master config
      AX.closeSheet(); renderForm();
    }); });
  }
  /* Age ↔ DOB consistency: accept either the completed age OR the calendar-year
     age (currentYear − birthYear). e.g. today Jun 15 2026, DOB Jul 31 2004 →
     completed age 21 but turns 22 this year, so BOTH 21 and 22 are valid; 23 errors. */
  function ageMatchesDob(age, dob) {
    if (!dob || age === "" || age == null) return true;
    var n = parseInt(age, 10); if (isNaN(n)) return true;
    var curYear = parseInt(String(AX.TODAY_ISO || "").slice(0, 4), 10);
    var birthYear = parseInt(String(dob).slice(0, 4), 10);
    if (!curYear || !birthYear) return true;
    var calYearAge = curYear - birthYear;
    var completed = parseInt(AX.ageFromDob(dob), 10);
    if (isNaN(completed)) completed = calYearAge;
    return n === calYearAge || n === completed;
  }
  function saveForm() {
    if (!draft.name.trim()) { AX.toast("Enter the customer's name"); var n = $("#fName"); if (n) n.focus(); return; }
    var _pl = (window.AskEvaPhoneLen ? window.AskEvaPhoneLen(draft.cc || "+91") : { min: 10, max: 10 });
    if (!draft.mobile || draft.mobile.length < _pl.min || draft.mobile.length > _pl.max) {
      AX.toast(_pl.min === _pl.max ? "Enter a valid " + _pl.min + "-digit mobile number" : "Enter a valid mobile number");
      var mo = $("#fMobile"); if (mo) mo.focus(); return;
    }
    if (draft.dob && draft.age !== "" && draft.age != null && !ageMatchesDob(draft.age, draft.dob)) {
      AX.toast("Age doesn't match the date of birth"); var ai = $("#fAge"); if (ai) { ai.focus(); ai.select && ai.select(); } return;
    }
    if (draft.time == null) { AX.toast("Choose an appointment time"); var sc = $("#axFormScroll"); if (sc) sc.scrollTop = sc.scrollHeight * 0.5; return; }
    var _bf = bfList();
    if (_bf) { for (var bi = 0; bi < _bf.length; bi++) { var bff = _bf[bi]; if (bff.custom && bff.req && !String(draft.cf[bff.id] || "").trim()) { AX.toast("Please fill " + bff.name); return; } } }
    var amt = parseInt(draft.amount, 10) || 0;
    if (editingId) {
      var a = AX.getAppt(editingId);
      var _prevUser = a.user, _prevDept = a.department;
      ["name", "department", "user", "date", "time", "dur", "description", "bio", "mode", "paymentType"].forEach(function (k) { a[k] = draft[k]; });
      a.name = draft.name.trim(); a.age = parseInt(draft.age, 10) || a.age; a.mobile = draft.mobile; a.cc = draft.cc || "+91"; a.dob = draft.dob; a.amount = amt; a.cf = draft.cf;
      if (a.payStatus !== "paid") a.payStatus = a.paymentType === "prepaid" ? "paid" : "pending";
      // log agent (and department) reassignment on the appointment's own timeline
      if (_prevUser !== a.user) {
        var _ou = (AX.userById(_prevUser) || {}).name || "\u2014", _nu = (AX.userById(a.user) || {}).name || "\u2014";
        logApptActivity(a, "agent", 'Agent changed for "' + a.name + '"', { Field: "Agent", prevStatus: _ou, newStatus: _nu });
      } else if (_prevDept !== a.department) {
        logApptActivity(a, "updated", 'Appointment details updated');
      }
      AX.save(); hide(formEl); AX.render(); if (detailEl.classList.contains("show")) renderDetail(a); AX.toast("Appointment updated");
    } else {
      var na = { id: AX.uid(), name: draft.name.trim(), age: parseInt(draft.age, 10) || AX.ageFromDob(draft.dob) || "", mobile: draft.mobile, cc: draft.cc || "+91", dob: draft.dob,
        department: draft.department, user: draft.user, date: draft.date, time: draft.time, dur: draft.dur, description: draft.description,
        bio: draft.bio, mode: draft.mode, paymentType: draft.paymentType, amount: amt, status: "pending", created: 0, createdTs: Date.now(), cf: draft.cf,
        payStatus: draft.paymentType === "prepaid" ? "paid" : "pending", orderId: "ORD-" + (10500 + AX.appts.length), method: AX.METHODS[AX.appts.length % AX.METHODS.length] };
      AX.appts.unshift(na); AX.save(); logApptActivity(na, "created", "Appointment created \u00b7 " + AX.fmtDayShort(na.date) + ", " + AX.fmtTime(na.time).full); apptReminder(na); hide(formEl);
      if (AX.notifyCustomer) AX.notifyCustomer(na, "newBooking");
      AX.state.tab = "bookings"; AX.state.day = na.date; AX.setTab("bookings");
      AX.toast("Appointment created \u00b7 reminder scheduled");
      setTimeout(function () { AX.openDetail(na.id); }, 260);
    }
  }

  /* ============================================================
     PAYMENTS
     ============================================================ */
  AX.openPayFilter = function () {
    var opts = [["all", "All Status"], ["paid", "Paid"], ["pending", "Pending"], ["failed", "Failed"], ["refunded", "Refunded"]];
    AX.radioSheet("Filter by status", opts.map(function (o) { return { v: o[0], label: o[1], on: AX.state.payStatus === o[0] }; }), function (v) { AX.state.payStatus = v; AX.render(); });
  };
  AX.renderPayments = function (host) {
    var txns = AX.appts.filter(function (a) { return a.amount > 0; }).slice().sort(function (a, b) { return a.created - b.created; });
    var paidSum = txns.filter(function (t) { return t.payStatus === "paid"; }).reduce(function (s, t) { return s + t.amount; }, 0);
    var pendSum = txns.filter(function (t) { return t.payStatus === "pending"; }).reduce(function (s, t) { return s + t.amount; }, 0);
    var totalSum = txns.reduce(function (s, t) { return s + t.amount; }, 0);
    var q = AX.state.payQ.toLowerCase();
    var list = txns.filter(function (t) {
      var okS = AX.state.payStatus === "all" || t.payStatus === AX.state.payStatus;
      var okQ = !q || (t.name + " " + t.orderId + " " + t.mobile + " " + t.method).toLowerCase().indexOf(q) > -1;
      return okS && okQ;
    });
    host.innerHTML =
      '<div class="ap-paysum"><div class="c"><div class="v">' + AX.inr(totalSum) + '</div><div class="l">Total</div></div>' +
        '<div class="c"><div class="v" style="color:var(--accent-deep)">' + AX.inr(paidSum) + '</div><div class="l">Received</div></div>' +
        '<div class="c"><div class="v" style="color:#9A6B05">' + AX.inr(pendSum) + '</div><div class="l">Pending</div></div></div>' +
      '<div class="ap-payfilter"><div class="lp-search">' + I.search + '<input id="payQ" type="text" placeholder="Search by Order ID, name…" value="' + esc(AX.state.payQ) + '" style="border:none;outline:none;background:transparent;font-family:inherit;font-size:14.5px;font-weight:600;color:var(--ink);width:100%"></div>' +
        '<button class="ap-statuspill" id="payStatusBtn">' + (AX.state.payStatus === "all" ? "All Status" : cap(AX.state.payStatus)) + ' \u25be</button></div>' +
      '<div class="ap-secrow"><span class="h">Transactions</span><span class="ap-daysum">' + list.length + (list.length === 1 ? " record" : " records") + '</span></div>' +
      (list.length ? list.map(payCard).join("") :
        '<div class="ax-empty"><div class="ic">' + I.card + '</div><div class="t">No transactions found</div><div class="s">' + (q || AX.state.payStatus !== "all" ? "Try a different filter." : "Payments will appear here.") + '</div></div>');

    var qi = $("#payQ", host); if (qi) qi.addEventListener("input", function (e) { AX.state.payQ = e.target.value; var c = e.target.selectionStart; AX.render(); var n = $("#payQ"); if (n) { n.focus(); try { n.setSelectionRange(c, c); } catch (x) {} } });
    var sb = $("#payStatusBtn", host); if (sb) sb.addEventListener("click", AX.openPayFilter);
    $$(".ap-pay", host).forEach(function (el) { el.addEventListener("click", function () { AX.openDetail(el.getAttribute("data-id")); }); });
  };
  function payCard(t) {
    var ic = t.method === "Cash" ? I.cash : t.method === "UPI" ? I.upi : I.card;
    var when = t.created <= 0 ? "Just now" : t.created < 60 ? t.created + "m ago" : t.created < 1440 ? Math.floor(t.created / 60) + "h ago" : Math.floor(t.created / 1440) + "d ago";
    return '<button class="ap-pay" data-id="' + t.id + '"><span class="mic">' + ic + '</span><div class="mid">' +
      '<div class="r1"><span class="who">' + esc(t.name) + '</span><span class="amt">' + AX.inr(t.amount) + '</span></div>' +
      '<div class="r2"><span class="ord">' + esc(t.orderId) + ' · ' + esc(t.method) + ' · ' + when + '</span>' +
        '<span class="pst ' + t.payStatus + '">' + cap(t.payStatus) + '</span></div></div></button>';
  }

  /* ============================================================
     BOOKING SETTINGS — form field config
     ============================================================ */
  var FKEY = "askeva.bookingfields.v1";
  var DEF_FIELDS = [
    { id: "name",   name: "Name",              ph: "Enter customer name",  type: "text",     req: true, lock: true,  on: true },
    { id: "age",    name: "Age",               ph: "Enter age",            type: "number",   req: true, lock: false, on: true },
    { id: "mobile", name: "Mobile Number",     ph: "Enter 10 digit number",type: "phone",    req: true, lock: true,  on: true },
    { id: "dob",    name: "Date of Birth",     ph: "Select date of birth", type: "date",     req: true, lock: true,  on: true },
    { id: "dept",   name: "Department",        ph: "Select Department",    type: "select",   req: true, step: true,  on: true },
    { id: "user",   name: "Select User",       ph: "Select User",          type: "select",   req: true, step: true,  on: true },
    { id: "adate",  name: "Appointment Date",  ph: "Select Date",          type: "date",     req: true, step: true,  on: true },
    { id: "atime",  name: "Appointment Timing",ph: "Select Time Slot",     type: "time",     req: true, step: true,  on: true },
    { id: "desc",   name: "Description",       ph: "Enter description",     type: "textarea", req: true, lock: true,  on: true },
    { id: "ptype",  name: "Payment Type",      ph: "Select payment type",  type: "select",   req: true, lock: true,  on: true }
  ];
  var fields;
  try { fields = JSON.parse(localStorage.getItem(FKEY)) || null; } catch (e) { fields = null; }
  if (!fields || !fields.length) fields = DEF_FIELDS.map(function (f) { return Object.assign({}, f); });
  function saveFields() { try { localStorage.setItem(FKEY, JSON.stringify(fields)); } catch (e) {} }

  AX.renderSettings = function (host) {
    var total = fields.length;
    var req = fields.filter(function (f) { return f.req; }).length;
    var custom = fields.filter(function (f) { return f.custom; }).length;
    host.innerHTML =
      '<div class="ap-secrow"><span class="h">Booking Form Fields</span><span class="ap-daysum">Drag to reorder</span></div>' +
      fields.map(fieldRow).join("") +
      '<button class="ap-addfield" id="apAddField">' + I.plus + 'Add custom field</button>' +
      '<div class="ap-totals"><div class="c"><div class="v">' + total + '</div><div class="l">Total Fields</div></div>' +
        '<div class="c"><div class="v">' + req + '</div><div class="l">Required</div></div>' +
        '<div class="c"><div class="v">' + custom + '</div><div class="l">Custom</div></div></div>';
    $$(".ap-switch", host).forEach(function (sw) { sw.addEventListener("click", function () {
      var f = fieldById(sw.getAttribute("data-id")); if (f.lock && f.on) { AX.toast("This field can't be turned off"); return; }
      f.on = !f.on; saveFields(); AX.render(); AX.toast(f.name + (f.on ? " enabled" : " disabled")); }); });
    $$(".ap-setcard .edit", host).forEach(function (b) { b.addEventListener("click", function () { editField(b.getAttribute("data-id")); }); });
    $("#apAddField", host).addEventListener("click", AX.addField);
  };
  function fieldById(id) { for (var i = 0; i < fields.length; i++) if (fields[i].id === id) return fields[i]; return null; }
  function fieldRow(f) {
    var tags = '<span class="ap-tag type">' + f.type + '</span>';
    if (f.step) tags += '<span class="ap-tag step">Step field</span>';
    if (f.lock) tags += '<span class="ap-tag lock">Non-deletable</span>';
    if (f.custom) tags += '<span class="ap-tag on">Custom</span>';
    if (f.on) tags += '<span class="ap-tag on">Activated</span>';
    return '<div class="ap-setcard"><span class="grip">' + I.grip + '</span>' +
      '<div class="fb"><div class="fn">' + esc(f.name) + (f.req ? '<span class="req">*</span>' : '') + '</div>' +
        '<div class="ph">Placeholder: ' + esc(f.ph) + '</div><div class="ap-tags">' + tags + '</div></div>' +
      '<button class="ap-switch' + (f.on ? " on" : "") + '" data-id="' + f.id + '" aria-label="Toggle"></button>' +
      '<button class="edit" data-id="' + f.id + '" aria-label="Edit field">' + I.edit + '</button></div>';
  }
  function editField(id) {
    var f = fieldById(id);
    var html = '<div class="ax-grip"></div><div class="ax-sheet-head"><div><div class="ax-sheet-ttl">Edit field</div>' +
      '<div class="ax-sheet-sub">' + esc(f.name) + '</div></div></div>' +
      '<div class="ax-field"><label class="ax-label">Label</label><div class="ax-control">' + I.note + '<input id="efName" type="text" value="' + esc(f.name) + '"></div></div>' +
      '<div class="ax-field"><label class="ax-label">Placeholder</label><div class="ax-control">' + I.note + '<input id="efPh" type="text" value="' + esc(f.ph) + '"></div></div>' +
      '<button class="ax-reason' + (f.req ? " on" : "") + '" id="efReq" style="width:100%;margin-bottom:10px"><span class="rd"></span>Required field</button>' +
      (f.custom ? '<button class="ax-btn danger" id="efDel" style="margin-bottom:10px">' + I.trash + 'Delete field</button>' : '') +
      '<button class="ax-sheetbtn" id="efSave">Save field</button>';
    var s = AX.openSheet(html);
    var req = f.req;
    $("#efReq", s).addEventListener("click", function () { req = !req; this.classList.toggle("on", req); });
    if (f.custom) $("#efDel", s).addEventListener("click", function () { fields = fields.filter(function (x) { return x.id !== id; }); saveFields(); AX.closeSheet(); AX.render(); AX.toast("Field deleted"); });
    $("#efSave", s).addEventListener("click", function () {
      f.name = ($("#efName", s).value || f.name).trim(); f.ph = $("#efPh", s).value; f.req = req;
      saveFields(); AX.closeSheet(); AX.render(); AX.toast("Field saved");
    });
  }
  AX.addField = function () {
    var types = ["text", "number", "select", "date", "time", "textarea"];
    var html = '<div class="ax-grip"></div><div class="ax-sheet-head"><div class="ax-sheet-ttl">Add custom field</div></div>' +
      '<div class="ax-field"><label class="ax-label">Label</label><div class="ax-control">' + I.note + '<input id="afName" type="text" placeholder="e.g. GST Number"></div></div>' +
      '<div class="ax-field"><label class="ax-label">Placeholder</label><div class="ax-control">' + I.note + '<input id="afPh" type="text" placeholder="Enter value"></div></div>' +
      '<div class="ax-field"><label class="ax-label">Type</label><div class="ax-chiprow" id="afType">' +
        types.map(function (t, i) { return '<button class="ax-pillchip' + (i === 0 ? " on" : "") + '" data-t="' + t + '">' + t + '</button>'; }).join("") + '</div></div>' +
      '<button class="ax-reason" id="afReq" style="width:100%;margin-bottom:10px"><span class="rd"></span>Required field</button>' +
      '<button class="ax-sheetbtn" id="afSave">Add field</button>';
    var s = AX.openSheet(html);
    var type = "text", req = false;
    $$("#afType .ax-pillchip", s).forEach(function (b) { b.addEventListener("click", function () { type = b.getAttribute("data-t"); $$("#afType .ax-pillchip", s).forEach(function (x) { x.classList.remove("on"); }); b.classList.add("on"); }); });
    $("#afReq", s).addEventListener("click", function () { req = !req; this.classList.toggle("on", req); });
    $("#afSave", s).addEventListener("click", function () {
      var nm = ($("#afName", s).value || "").trim(); if (!nm) { AX.toast("Enter a field label"); return; }
      fields.push({ id: "c" + Date.now().toString(36), name: nm, ph: $("#afPh", s).value || "Enter value", type: type, req: req, custom: true, on: true });
      saveFields(); AX.closeSheet();
      if (AX.state.tab !== "settings") AX.setTab("settings"); else AX.render();
      AX.toast("Custom field added");
    });
  };

})(window.AX);
