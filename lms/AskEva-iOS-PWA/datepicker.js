/* =========================================================
   AskEva — Universal date picker
   window.AskEvaPicker.dateRange({start,end,onApply})
   window.AskEvaPicker.dateTime({value,onPick})
   window.AskEvaPicker.rangePill(el,{start,end,onChange})
   One calendar everywhere a date range / schedule time appears.
   ========================================================= */
(function () {
  "use strict";
  var host = document.getElementById("screen") || document.body;
  var scrim, sheet;
  var MON = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
  var DOW = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"];
  var CAL = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="5" width="18" height="16" rx="2.5"/><path d="M3 10h18M8 3v4M16 3v4"/></svg>';
  var pad = function (n) { return (n < 10 ? "0" : "") + n; };
  function iso(d) { return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate()); }
  function parse(s) { if (!s) return null; var m = /(\d{4})-(\d{2})-(\d{2})/.exec(s); return m ? new Date(+m[1], +m[2] - 1, +m[3]) : null; }
  function pretty(s) { var d = parse(s); if (!d) return ""; return pad(d.getDate()) + " " + MON[d.getMonth()].slice(0, 3) + " " + d.getFullYear(); }

  function ensure() {
    if (scrim) return;
    scrim = document.createElement("div"); scrim.className = "dp-scrim";
    sheet = document.createElement("div"); sheet.className = "dp-sheet";
    host.appendChild(scrim); host.appendChild(sheet);
    scrim.addEventListener("click", close);
  }
  function open(html) { ensure(); sheet.innerHTML = html; requestAnimationFrame(function () { scrim.classList.add("show"); sheet.classList.add("show"); }); }
  function close() { if (scrim) { scrim.classList.remove("show"); sheet.classList.remove("show"); } }

  function grid(view, sel, maxIso, minIso) {
    var first = new Date(view.y, view.m, 1), start = first.getDay(), dim = new Date(view.y, view.m + 1, 0).getDate();
    var cells = "";
    for (var i = 0; i < start; i++) cells += '<span class="dp-cell empty"></span>';
    for (var d = 1; d <= dim; d++) {
      var di = view.y + "-" + pad(view.m + 1) + "-" + pad(d);
      var cls = "dp-cell";
      var dis = (maxIso && di > maxIso) || (minIso && di < minIso);
      if (dis) cls += " disabled";
      else if (sel.start && sel.end) { if (di === sel.start) cls += " sel start"; else if (di === sel.end) cls += " sel end"; else if (di > sel.start && di < sel.end) cls += " inrange"; }
      else if (di === sel.start) cls += " sel start end";
      cells += '<button class="' + cls + '" data-d="' + di + '"' + (dis ? ' disabled' : '') + '>' + d + '</button>';
    }
    return '<div class="dp-cal">' +
      '<div class="dp-calhd"><button class="dp-nav" data-nav="-1" aria-label="Prev">' + chev("l") + '</button>' +
        '<span class="dp-mtitle">' + MON[view.m] + ' ' + view.y + '</span>' +
        '<button class="dp-nav" data-nav="1" aria-label="Next">' + chev("r") + '</button></div>' +
      '<div class="dp-dow">' + DOW.map(function (w) { return '<span>' + w + '</span>'; }).join("") + '</div>' +
      '<div class="dp-grid">' + cells + '</div></div>';
  }
  function chev(d) { return '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="' + (d === "l" ? "m15 6-6 6 6 6" : "m9 6 6 6-6 6") + '"/></svg>'; }

  /* ---------- range ---------- */
  function dateRange(o) {
    o = o || {};
    var sel = { start: o.start || "", end: o.end || "" };
    var maxIso = o.maxToday ? iso(new Date()) : "";
    var anchor = parse(sel.start) || new Date();
    var view = { y: anchor.getFullYear(), m: anchor.getMonth() };
    var picking = sel.start && sel.end ? "start" : (sel.start ? "end" : "start");
    function head() {
      return '<div class="dp-grip"></div><div class="dp-head"><span class="t">Select date range</span>' +
        '<button class="dp-x" data-x>' + xIcon() + '</button></div>' +
        '<div class="dp-rangebar"><span class="dp-rb' + (picking === "start" ? " on" : "") + '">' + (sel.start ? pretty(sel.start) : "Start date") + '</span>' +
          '<span class="dp-arrow">\u2192</span><span class="dp-rb' + (picking === "end" ? " on" : "") + '">' + (sel.end ? pretty(sel.end) : "End date") + '</span></div>';
    }
    function paint() {
      open(head() + grid(view, sel, maxIso) +
        '<div class="dp-foot"><button class="dp-btn ghost" data-clear>Clear</button><button class="dp-btn primary" data-apply>Apply</button></div>');
      sheet.querySelector("[data-x]").addEventListener("click", close);
      sheet.querySelectorAll("[data-nav]").forEach(function (b) { b.addEventListener("click", function () { view.m += +b.getAttribute("data-nav"); if (view.m < 0) { view.m = 11; view.y--; } if (view.m > 11) { view.m = 0; view.y++; } paint(); }); });
      sheet.querySelectorAll("[data-d]").forEach(function (b) { b.addEventListener("click", function () {
        var di = b.getAttribute("data-d");
        if (picking === "start" || (sel.start && di < sel.start)) { sel.start = di; sel.end = ""; picking = "end"; }
        else { sel.end = di; picking = "start"; }
        paint();
      }); });
      sheet.querySelector("[data-clear]").addEventListener("click", function () { sel.start = ""; sel.end = ""; picking = "start"; paint(); });
      sheet.querySelector("[data-apply]").addEventListener("click", function () { close(); if (o.onApply) o.onApply({ start: sel.start, end: sel.end || sel.start }); });
    }
    paint();
  }

  /* ---------- date + time ---------- */
  var TIMEZONES = [
    ["Asia/Kolkata", "(GMT+5:30) India Standard Time"],
    ["Asia/Dubai", "(GMT+4:00) Gulf Standard Time"],
    ["Asia/Singapore", "(GMT+8:00) Singapore Time"],
    ["UTC", "(GMT+0:00) Coordinated Universal Time"],
    ["Europe/London", "(GMT+0:00) London"],
    ["Europe/Berlin", "(GMT+1:00) Central European Time"],
    ["America/New_York", "(GMT-5:00) Eastern Time (US)"],
    ["America/Chicago", "(GMT-6:00) Central Time (US)"],
    ["America/Los_Angeles", "(GMT-8:00) Pacific Time (US)"],
    ["Australia/Sydney", "(GMT+11:00) Sydney"]
  ];
  function tzLabel(v) { var z = TIMEZONES.filter(function (x) { return x[0] === v; })[0]; return z ? z[1] : v; }
  function dateTime(o) {
    o = o || {};
    var init = o.value ? new Date(o.value) : null;
    var sel = { date: init ? iso(init) : "", time: init ? pad(init.getHours()) + ":" + pad(init.getMinutes()) : "" };
    var tz = o.tz || "Asia/Kolkata";
    var minIso = o.minToday ? iso(new Date()) : "";
    var anchor = parse(sel.date) || new Date();
    var view = { y: anchor.getFullYear(), m: anchor.getMonth() };
    function paint() {
      open('<div class="dp-grip"></div><div class="dp-head"><span class="t">Select date &amp; time</span><button class="dp-x" data-x>' + xIcon() + '</button></div>' +
        grid(view, { start: sel.date, end: "" }, "", minIso) +
        '<div class="dp-tsec"><div class="dp-tseclbl">Time</div>' + timeMarkup(sel.time || "09:00") + '</div>' +
        (o.timezone ? '<div class="dp-tsec"><div class="dp-tseclbl">Time zone</div>' +
          '<div class="dp-tzwrap"><select class="dp-tzsel" data-tz>' + TIMEZONES.map(function (z) { return '<option value="' + z[0] + '"' + (z[0] === tz ? " selected" : "") + '>' + z[1] + '</option>'; }).join("") + '</select></div></div>' : '') +
        '<div class="dp-foot"><button class="dp-btn ghost" data-x>Cancel</button><button class="dp-btn primary" data-apply>Set</button></div>');
      sheet.querySelectorAll("[data-x]").forEach(function (b) { b.addEventListener("click", close); });
      sheet.querySelectorAll("[data-nav]").forEach(function (b) { b.addEventListener("click", function () { view.m += +b.getAttribute("data-nav"); if (view.m < 0) { view.m = 11; view.y--; } if (view.m > 11) { view.m = 0; view.y++; } paint(); }); });
      sheet.querySelectorAll("[data-d]").forEach(function (b) { b.addEventListener("click", function () { sel.date = b.getAttribute("data-d"); paint(); }); });
      var tzs = sheet.querySelector("[data-tz]"); if (tzs) tzs.addEventListener("change", function () { tz = tzs.value; });
      wireTime(sheet, function (t) { sel.time = t; });
      if (!sel.time) sel.time = "09:00";
      sheet.querySelector("[data-apply]").addEventListener("click", function () {
        if (!sel.date) { toast("Pick a date"); return; }
        if (minIso && sel.date < minIso) { toast("Pick today or a future date"); return; }
        var box = sheet.querySelector(".dp-timepick"); if (box) sel.time = box.getAttribute("data-time") || sel.time || "09:00";
        if (!sel.time) sel.time = "09:00";
        var p = sel.time.split(":"); var dt = parse(sel.date); dt.setHours(+p[0] || 0, +p[1] || 0, 0, 0);
        close(); if (o.onPick) o.onPick({ date: sel.date, time: sel.time, ts: dt.getTime(), value: iso(dt) + "T" + sel.time, tz: tz, tzLabel: tzLabel(tz), label: pretty(sel.date) + " \u00b7 " + sel.time + (o.timezone ? " \u00b7 " + tzLabel(tz) : "") });
      });
    }
    paint();
  }

  /* ---------- modern time wheel (replaces native <input type=time>) ---------- */
  function to24(h12, ap) { h12 = (+h12) % 12; return ap === "PM" ? h12 + 12 : h12; }
  function timeMarkup(time) {
    var h24 = 9, mn = 0; if (time) { var p = String(time).split(":"); h24 = +p[0] || 0; mn = +p[1] || 0; }
    var ap = h24 >= 12 ? "PM" : "AM", h12 = h24 % 12 || 12;
    var hrs = "", mns = "", aps = "";
    for (var i = 1; i <= 12; i++) hrs += '<button class="dp-topt' + (i === h12 ? " on" : "") + '" data-h="' + i + '">' + i + "</button>";
    for (var j = 0; j < 60; j++) mns += '<button class="dp-topt' + (j === mn ? " on" : "") + '" data-m="' + j + '">' + pad(j) + "</button>";
    ["AM", "PM"].forEach(function (a) { aps += '<button class="dp-apbtn' + (a === ap ? " on" : "") + '" data-ap="' + a + '">' + a + "</button>"; });
    return '<div class="dp-timepick" data-time="' + (pad(h24) + ":" + pad(mn)) + '">' +
      '<div class="dp-tpreview"><span class="hh">' + h12 + '</span><span class="cl">:</span><span class="mm">' + pad(mn) + '</span><span class="ap">' + ap + '</span></div>' +
      '<div class="dp-trow">' +
        '<div class="dp-twheels">' +
          '<div class="dp-tcol" data-col="h">' + hrs + '</div>' +
          '<div class="dp-tcol" data-col="m">' + mns + '</div>' +
        '</div>' +
        '<div class="dp-tap" data-col="ap">' + aps + '</div>' +
      '</div></div>';
  }
  function wireTime(root, onChange) {
    var box = root.querySelector(".dp-timepick"); if (!box) return;
    function cur() { var p = (box.getAttribute("data-time") || "09:00").split(":"); return { h: +p[0] || 0, m: +p[1] || 0 }; }
    function setTime(h24, m) {
      box.setAttribute("data-time", pad(h24) + ":" + pad(m));
      var ap = h24 >= 12 ? "PM" : "AM", h12 = h24 % 12 || 12, pv = box.querySelector(".dp-tpreview");
      if (pv) { pv.querySelector(".hh").textContent = h12; pv.querySelector(".mm").textContent = pad(m); pv.querySelector(".ap").textContent = ap; }
      if (onChange) onChange(pad(h24) + ":" + pad(m));
    }
    function center(col) { var on = col.querySelector(".dp-topt.on"); if (on) col.scrollTop = on.offsetTop - col.clientHeight / 2 + on.offsetHeight / 2; }
    box.querySelectorAll("[data-h]").forEach(function (b) { b.onclick = function () { box.querySelectorAll("[data-h]").forEach(function (x) { x.classList.remove("on"); }); b.classList.add("on"); var c = cur(), ap = c.h >= 12 ? "PM" : "AM"; setTime(to24(+b.getAttribute("data-h"), ap), c.m); center(b.parentNode); }; });
    box.querySelectorAll("[data-m]").forEach(function (b) { b.onclick = function () { box.querySelectorAll("[data-m]").forEach(function (x) { x.classList.remove("on"); }); b.classList.add("on"); var c = cur(); setTime(c.h, +b.getAttribute("data-m")); center(b.parentNode); }; });
    box.querySelectorAll("[data-ap]").forEach(function (b) { b.onclick = function () { box.querySelectorAll("[data-ap]").forEach(function (x) { x.classList.remove("on"); }); b.classList.add("on"); var c = cur(), h12 = c.h % 12 || 12; setTime(to24(h12, b.getAttribute("data-ap")), c.m); }; });
    requestAnimationFrame(function () { box.querySelectorAll(".dp-tcol").forEach(center); });
  }

  function wireNav(view, paint) {
    sheet.querySelectorAll("[data-nav]").forEach(function (b) { b.addEventListener("click", function () { view.m += +b.getAttribute("data-nav"); if (view.m < 0) { view.m = 11; view.y--; } if (view.m > 11) { view.m = 0; view.y++; } paint(); }); });
  }

  /* ---------- single date (replaces native <input type=date>) ---------- */
  function singleDate(o) {
    o = o || {};
    var iv = o.value ? (/(\d{4})-(\d{2})-(\d{2})/.exec(o.value) || [])[0] || "" : "";
    var sel = { date: iv };
    var maxIso = o.maxToday ? iso(new Date()) : "";
    var anchor = parse(sel.date) || new Date();
    var view = { y: anchor.getFullYear(), m: anchor.getMonth() };
    function paint() {
      open('<div class="dp-grip"></div><div class="dp-head"><span class="t">' + (o.title || "Select date") + '</span><button class="dp-x" data-x>' + xIcon() + '</button></div>' +
        grid(view, { start: sel.date, end: "" }, maxIso) +
        '<div class="dp-foot"><button class="dp-btn ghost" data-x>Cancel</button><button class="dp-btn primary" data-apply>Set</button></div>');
      sheet.querySelectorAll("[data-x]").forEach(function (b) { b.addEventListener("click", close); });
      wireNav(view, paint);
      sheet.querySelectorAll("[data-d]").forEach(function (b) { b.addEventListener("click", function () { sel.date = b.getAttribute("data-d"); paint(); }); });
      sheet.querySelector("[data-apply]").addEventListener("click", function () { if (!sel.date) { toast("Pick a date"); return; } close(); if (o.onPick) o.onPick({ date: sel.date, value: sel.date, label: pretty(sel.date) }); });
    }
    paint();
  }

  /* ---------- time only (replaces native <input type=time>) ---------- */
  function timeOnly(o) {
    o = o || {};
    var sel = { time: o.value || "09:00" };
    open('<div class="dp-grip"></div><div class="dp-head"><span class="t">' + (o.title || "Select time") + '</span><button class="dp-x" data-x>' + xIcon() + '</button></div>' +
      timeMarkup(sel.time) +
      '<div class="dp-foot"><button class="dp-btn ghost" data-x>Cancel</button><button class="dp-btn primary" data-apply>Set</button></div>');
    sheet.querySelectorAll("[data-x]").forEach(function (b) { b.addEventListener("click", close); });
    wireTime(sheet, function (t) { sel.time = t; });
    sheet.querySelector("[data-apply]").addEventListener("click", function () { var box = sheet.querySelector(".dp-timepick"); var t = box ? box.getAttribute("data-time") : sel.time; close(); if (o.onPick) o.onPick({ time: t, value: t }); });
  }

  /* ---------- global enhancer: every native date/time field uses the modern picker ---------- */
  function setVal(inp, v) { inp.value = v; inp.dispatchEvent(new Event("input", { bubbles: true })); inp.dispatchEvent(new Event("change", { bubbles: true })); }
  document.addEventListener("mousedown", function (e) {
    var inp = e.target.closest && e.target.closest('input[type="date"],input[type="time"],input[type="datetime-local"]');
    if (!inp || inp.disabled || inp.readOnly || inp.hasAttribute("data-native")) return;
    e.preventDefault();                                  // block the bland native popup + focus
    if (inp.blur) inp.blur();
    var type = inp.getAttribute("type");
    if (type === "date") {
      singleDate({ value: inp.value, onPick: function (r) { setVal(inp, r.value); } });
    } else if (type === "time") {
      timeOnly({ value: inp.value || "09:00", onPick: function (r) { setVal(inp, r.value); } });
    } else {
      dateTime({ value: inp.value || undefined, onPick: function (r) { setVal(inp, r.value); } });
    }
  }, true);


  function xIcon() { return '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"><path d="M6 6l12 12M18 6 6 18"/></svg>'; }
  function toast(m) { var t = document.getElementById("toast"); if (!t) return; t.textContent = m; t.style.opacity = "1"; t.style.transform = "translateX(-50%) translateY(0)"; setTimeout(function () { t.style.opacity = "0"; t.style.transform = "translateX(-50%) translateY(20px)"; }, 1800); }

  /* ---------- pill helper ---------- */
  function rangePill(el, o) {
    o = o || {};
    var st = { start: o.start || "", end: o.end || "" };
    function label() { return (st.start || st.end) ? (pretty(st.start) + " \u2192 " + pretty(st.end || st.start)) : '<span class="ph">Start date</span><span class="dp-arrow">\u2192</span><span class="ph">End date</span>'; }
    function openPicker() { dateRange({ start: st.start, end: st.end, maxToday: o.maxToday, onApply: function (r) { st.start = r.start; st.end = r.end; paint(); if (o.onChange) o.onChange(r); } }); }
    function reset() { st.start = ""; st.end = ""; paint(); if (o.onChange) o.onChange({ start: "", end: "" }); }
    function paint() {
      var has = !!(st.start || st.end);
      el.innerHTML = '<span class="dp-pilltxt">' + label() + '</span>' +
        (has ? '<button class="dp-pillx" type="button" aria-label="Reset date">' + xIcon() + '</button>'
             : '<span class="dp-pillcal">' + CAL + '</span>');
      var x = el.querySelector(".dp-pillx"); if (x) x.addEventListener("click", function (e) { e.stopPropagation(); reset(); });
    }
    el.className = "dp-pill"; paint();
    el.onclick = openPicker;
    return { set: function (r) { st.start = r.start || ""; st.end = r.end || ""; paint(); }, get: function () { return st; } };
  }

  window.AskEvaPicker = { dateRange: dateRange, dateTime: dateTime, singleDate: singleDate, timeOnly: timeOnly, rangePill: rangePill, prettyRange: function (s, e) { return pretty(s) + " \u2192 " + pretty(e || s); } };
})();
