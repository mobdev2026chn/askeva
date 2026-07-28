/* =========================================================
   AskEva — Ticket Detail (rich)
   Mobile translation of the web ticket detail page:
     header (Subject/Agent/Status/Priority) · Contact Info ·
     SLA Information · Ticket Properties · tabs:
     Ticket Details / Send Template / Activity Logs /
     Ticket History / Call Logs
   Renders into #txDetail. Uses window.TK + window.TKTickets.
   ========================================================= */
(function () {
  "use strict";
  var TK = window.TK; if (!TK) return;
  var $ = TK.$, $$ = TK.$$, esc = TK.esc, toast = TK.toast;
  var el = document.getElementById("txDetail"); if (!el) return;

  var MIN = 60000, NOW = new Date(2026, 5, 5, 12, 0, 0);
  var TM = function () { return window.TKTickets; };

  var curId = null, tab = "details", histPage = 1;
  // Live Map-to-field list for Ticket templates: the configured ticket-form
  // fields (incl. custom) + the system columns the ticket table carries.
  function ticketMapFields() {
    var out = ["Ticket ID", "Customer Name", "Mobile Number", "Assigned To", "Status", "Due Date"];
    var tf = (window.TK && TK.ticketForm) ? TK.ticketForm("ticketing") : null;
    if (tf && tf.length) tf.forEach(function (f) { if (f && f.name) out.push(f.name); });
    return out.filter(function (x, i, a) { return x && a.indexOf(x) === i; });
  }
  var TABS = [["details", "Ticket Details"], ["template", "Send Template"], ["activity", "Activity Logs"], ["history", "Ticket History"], ["calls", "Call Logs"]];

  function open(id) { var t = TK.getT(id); if (!t) return; curId = id; tab = "details"; histPage = 1; t.unread = false; TK.save(); render(); el.classList.add("show"); }
  function close() { el.classList.remove("show"); if (TM()) TM().render(); }

  function wlbl(s) { return (TM().WST_LBL[s] || "Pending"); }
  function wcls(s) { return (TM().WST_CLS[s] || "amber"); }
  function plbl(p) { return (TM().WPRIO_LBL[p] || "Low"); }
  function did(t) { return TM().displayId(t); }
  /* every agent message sent from a ticket reflects in the customer's WhatsApp chat */
  function chatTarget(t) { var c = TK.custById(t.customer) || {}; return { name: t.custName || c.name || "Customer", phone: t.mobile || c.mobile || "" }; }
  function chatDeliver(t, msg) { if (window.__chat && window.__chat.postTicketMessage) { try { window.__chat.postTicketMessage(chatTarget(t), msg); } catch (e) {} } }

  /* SLA breach state */
  function slaDefRes(t) { var d = (window.TK && TK.slaDefaults) ? TK.slaDefaults().res : 3; return t.slaRes || d; }
  function slaDefFirst(t) { var d = (window.TK && TK.slaDefaults) ? TK.slaDefaults().first : 1; return t.slaFirst || d; }
  function elapsed(t) { return (NOW.getTime() - t.createdMs) / MIN; }
  function resBreached(t) { return t.wstatus !== "completed" && elapsed(t) > slaDefRes(t); }
  function frBreached(t) { return t.wstatus !== "completed" && elapsed(t) > slaDefFirst(t); }

  /* ---- shared helpers: download, call (unified screen + log), chat ---- */
  function dl(name, content, mime) {
    try {
      var blob = new Blob([content], { type: mime || "text/plain;charset=utf-8" });
      var url = URL.createObjectURL(blob);
      var a = document.createElement("a"); a.href = url; a.download = name; a.style.display = "none";
      document.body.appendChild(a); a.click();
      setTimeout(function () { document.body.removeChild(a); URL.revokeObjectURL(url); }, 120);
      return true;
    } catch (e) { return false; }
  }
  function placeCall(t) {
    var c = TK.custById(t.customer) || { name: t.custName || "Customer" };
    var num = (t.mobile || "").replace(/\D/g, "");
    (t.calls = t.calls || []).unshift({ dir: "out", title: "Outgoing call", num: "91" + num, when: fmtDT(NOW.getTime()) });
    TK.save();
    if (window.__callScreen) window.__callScreen({ name: c.name || t.custName || "Customer", mobile: num ? "91 " + num : "" });
    else toast("Calling 91" + num);
    if (tab === "calls") rebody();
  }
  function accessChat(t) {
    var c = TK.custById(t.customer) || { name: t.custName || "" };
    var contacts = (window.__chat && window.__chat.contacts) || [];
    var nm = (c.name || t.custName || "").trim().toLowerCase();
    var match = contacts.filter(function (x) { return (x.name || "").trim().toLowerCase() === nm; })[0];
    close();
    if (window.__openChatFrom) {
      window.__openChatFrom("ticketing", match ? match.id : null, "Ticket", { name: (c.name || t.custName || ""), phone: c.mobile });
    } else {
      if (window.__appRoute) window.__appRoute("chats", { keepChat: true });
      if (window.__chat) { if (match) window.__chat.openById(match.id); else if (window.__chat.openWith) window.__chat.openWith((c.name || t.custName || ""), c.mobile); else window.__chat.showList(); }
    }
  }
  function downloadTicket(t) {
    var c = TK.custById(t.customer) || {}, ag = TK.agentById(t.assignee) || {};
    var lines = [
      "Ticket: " + did(t), "Subject: " + t.subject, "Customer: " + (c.name || t.custName || "—"),
      "Mobile: 91" + (t.mobile || "").replace(/\D/g, ""), "Company: " + (t.company || "N/A"),
      "Department: " + (t.department || "—"), "Assignee: " + (ag.name || "Unassigned"),
      "Status: " + wlbl(t.wstatus), "Priority: " + plbl(t.wpriority), "Source: " + (t.source || "form"),
      "Due: " + fmtDT(t.dueMs)
    ];
    if (t.thread && t.thread[0]) lines.push("", "Description:", t.thread[0].text);
    var ok = dl(did(t) + ".txt", lines.join("\n"), "text/plain;charset=utf-8");
    toast(ok ? "Downloaded " + did(t) : "Download blocked by browser");
  }
  var STAR = '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 2l2.9 6.3 6.9.6-5.2 4.6 1.6 6.8L12 17.3 5.8 20.9l1.6-6.8L2.2 8.9l6.9-.6z"/></svg>';
  /* view any document attached to the ticket (image inline, pdf in frame,
     others as a file card + download) */
  function viewDoc(t) {
    if (!t || !t.doc) { toast("No document attached"); return; }
    var name = t.doc, data = t.docData || "";
    var isImg = /^data:image\//.test(data) || /\.(png|jpe?g|gif|webp|bmp|svg)$/i.test(name);
    var isPdf = /^data:application\/pdf/.test(data) || /\.pdf$/i.test(name);
    var inner;
    if (data && isImg) inner = '<img src="' + data + '" alt="' + esc(name) + '" style="width:100%;border-radius:12px;display:block;">';
    else if (data && isPdf) inner = '<iframe src="' + data + '" style="width:100%;height:58vh;border:none;border-radius:12px;background:#fff;"></iframe>';
    else if (data) inner = '<div class="td-docfile">' + IC.doc + '<div class="t">' + esc(name) + '</div><div class="s">Preview not available — download to open.</div></div>';
    else inner = '<div class="td-docfile">' + IC.doc + '<div class="t">' + esc(name) + '</div><div class="s">This attachment isn\u2019t stored on this device.</div></div>';
    var dlBtn = data ? '<a class="ax-sheetbtn" href="' + data + '" download="' + esc(name) + '" style="text-align:center;text-decoration:none;display:block;">Download</a>' : '';
    TK.openSheet('<div class="ax-grip"></div><div class="ax-sheet-head"><div class="ax-sheet-ttl">Attachment</div><div class="ax-sheet-sub">' + esc(name) + '</div></div><div class="td-docview">' + inner + '</div>' + dlBtn);
  }
  function feedbackCard(t) {
    if (t.wstatus !== "completed") return "";
    var r = t.rating || 0;
    var stars = [1, 2, 3, 4, 5].map(function (v) { return '<button class="tdfb-star' + (v <= r ? " on" : "") + '" data-v="' + v + '" aria-label="' + v + ' star">' + STAR + '</button>'; }).join("");
    return '<div class="td-card"><div class="sc-hd">' + IC.flag + 'Customer Feedback</div>' +
      '<div class="tdfb-row">' + stars + '</div>' +
      '<div class="tdfb-note">' + (r ? ('Rated ' + r + ' / 5 · thank you!') : 'Tap a star to record feedback for this resolved ticket.') + '</div></div>';
  }

  function render() {
    var t = TK.getT(curId); if (!t) return;
    var justEscalated = (window.TK && TK.escalateBreached) ? TK.escalateBreached(t) : false;
    if (justEscalated) TK.save();
    var ag = t.assignee && t.assignee !== "unassigned" ? TK.agentById(t.assignee) : null;
    var c = TK.custById(t.customer) || { name: t.custName || ".", initials: "?", color: "#999", company: "" };
    if (justEscalated) setTimeout(function () { toast("SLA breached \u2014 escalated to " + (t.escalatedToName || "department head") + " \u00b7 now Pending"); }, 220);

    el.innerHTML =
      '<div class="ax-bar"><button class="ax-iconbtn" data-x="close" aria-label="Back">' + IC.back + '</button>' +
        '<div class="ttl">' + esc(did(t)) + '</div><button class="ax-iconbtn" data-x="edit" aria-label="Edit ticket">' + IC.edit + '</button></div>' +
      '<div class="ax-scroll" id="tdScroll">' +
        '<div class="td-head">' +
          '<button class="hl" data-x="edit"><span class="ic">' + IC.edit + '</span><span class="k">Subject:</span><span class="v">' + esc(t.subject) + '</span></button>' +
          '<div class="td-meta">' +
            '<span class="mi"><span class="ic">' + IC.user + '</span><span class="k">Agent:</span><b>' + esc(ag ? ag.name : "Unassigned") + '</b></span>' +
            '<span class="mi"><span class="ic">' + IC.flag + '</span><span class="k">Status:</span><b class="st ' + wcls(t.wstatus) + '">' + esc(wlbl(t.wstatus)) + '</b></span>' +
            '<span class="mi"><span class="ic">' + IC.alert + '</span><span class="k">Priority:</span><b class="pr ' + t.wpriority + '">' + esc(plbl(t.wpriority)) + '</b></span>' +
          '</div>' +
        '</div>' +
        '<div class="td-tabs" id="tdTabs">' + TABS.map(function (o) {
          return '<button class="tdt' + (tab === o[0] ? " on" : "") + '" data-t="' + o[0] + '">' + esc(o[1]) + '</button>';
        }).join("") + '</div>' +
        '<div class="td-body" id="tdBody">' + bodyFor(t, c, ag) + '</div>' +
      '</div>';

    $('[data-x="close"]', el).addEventListener("click", close);
    $$('[data-x="edit"]', el).forEach(function (b) { b.addEventListener("click", function () { if (window.TKTickets && window.TKTickets.openForm) window.TKTickets.openForm(t); }); });
    $$("#tdTabs .tdt", el).forEach(function (b) { b.addEventListener("click", function () { tab = b.getAttribute("data-t"); rebody(); } ); });
    bindBody(t, c, ag);
  }
  function rebody() {
    var t = TK.getT(curId); var ag = t.assignee && t.assignee !== "unassigned" ? TK.agentById(t.assignee) : null;
    var c = TK.custById(t.customer) || { name: t.custName || ".", initials: "?", color: "#999", company: "" };
    $$("#tdTabs .tdt", el).forEach(function (b) { b.classList.toggle("on", b.getAttribute("data-t") === tab); });
    $("#tdBody", el).innerHTML = bodyFor(t, c, ag); bindBody(t, c, ag);
    var sc = $("#tdScroll", el); if (sc) sc.scrollTop = 0;
  }

  /* =========================================================
     TAB BODIES
     ========================================================= */
  function bodyFor(t, c, ag) {
    if (tab === "template") return tplBody(t);
    if (tab === "activity") return activityBody(t);
    if (tab === "history") return historyBody(t);
    if (tab === "calls") return callsBody(t);
    return detailsBody(t, c, ag);
  }

  /* ---- Ticket Details ---- */
  function detailsBody(t, c, ag) {
    var notes = (t.notes || []);
    var notesHTML = notes.length ? notes.map(function (n) {
      return '<div class="td-note"><div class="nh"><span class="who">' + esc(n.who || c.name) + '</span><span class="tm">' + esc(n.when) + '</span></div><div class="nt">' + esc(n.text) + '</div></div>';
    }).join("") : '<div class="td-nonote">No personal notes found. Add a note to track important information.</div>';

    var replies = (t.thread || []).filter(function (m) { return m.from === "agent" || m.from === "customer"; }).slice(-4).map(function (m) {
      var out = m.from === "agent";
      var who = out ? (TK.agentById(m.who) || { name: "Agent" }).name : c.name;
      var body;
      if (m.kind === "video") {
        var vurl = m.videoUrl || (window.TK && TK.videoNoteURL ? TK.videoNoteURL(m.videoId) : null);
        body = '<div class="td-vnote">' +
          (vurl ? '<video class="td-vnplayer" controls playsinline src="' + vurl + '"></video>'
                : '<div class="td-vnthumb">' + IC.video + '</div>') +
          '<div class="td-vnmeta"><span class="td-vntag">' + IC.video + 'Video note</span>' +
            '<span class="td-vntitle">' + esc(m.text) + '</span></div></div>';
      } else {
        body = '<div class="tx">' + esc(m.text) + '</div>';
      }
      return '<div class="td-reply ' + (out ? "out" : "") + '"><div class="rb"><div class="who">' + esc(who) + '</div>' + body + '</div></div>';
    }).join("");

    return contactCard(t, c) + slaCard(t) + propsCard(t, ag) +
      '<div class="td-card">' +
        '<div class="td-descrow"><span class="k">' + IC.info + 'Description:</span><span class="v">' + esc((t.thread[0] && t.thread[0].text) || t.subject) + '</span></div>' +
        '<div class="td-statusrow"><span class="lbl">Update Status</span>' +
          '<button class="td-statusdd" id="tdStatus"><span>' + esc(wlbl(t.wstatus)) + '</span>' + IC.chevD + '</button></div>' +
        '<div class="td-actbtns">' +
          '<button class="td-gbtn" data-a="note">' + IC.note + 'Add Note</button>' +
          '<button class="td-gbtn" data-a="switch">' + IC.swap + 'Switch Agent</button>' +
          '<button class="td-gbtn" data-a="chat">' + IC.chat + 'Access Chat</button>' +
          '<button class="td-gbtn" data-a="call">' + IC.phone + 'Call</button>' +
        '</div>' +
        '<div class="td-notes">' + notesHTML + '</div>' +
        '<button class="td-chatlink" data-a="chat">' + IC.chat + 'View conversation in Chats' + IC.chevR + '</button>' +
        '<div class="td-addreply"><div class="lbl">Add Reply</div>' +
          '<div class="td-qr"><button class="td-qrbtn" data-a="quick">' + IC.chat + 'Quick Replies' + IC.chevD + '</button>' +
            '<button class="td-qrbtn" data-a="video">' + IC.video + 'Video Notes' + IC.chevD + '</button></div>' +
          '<textarea id="tdReply" rows="3" placeholder="Type your reply here…"></textarea>' +
          '<div class="td-sendrow"><button class="td-send" id="tdSend" disabled>' + IC.send + 'Send Reply</button></div>' +
        '</div>' +
      '</div>' + feedbackCard(t);
  }

  function contactCard(t, c) {
    return '<div class="td-card side"><div class="sc-hd">' + IC.user + 'Contact Information</div>' +
      '<div class="sc-contact"><span class="av" style="background:' + (c.color || "#999") + '">' + esc(c.initials || (c.name || "?").charAt(0)) + '</span>' +
        '<span class="nm">' + esc(c.name || t.custName || ".") + '</span></div>' +
      '<div class="sc-phone">' + IC.phone + '91' + esc((t.mobile || "").replace(/\D/g, "")) + '</div></div>';
  }
  var SLA_MON = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
  function slaPad(n) { return n < 10 ? "0" + n : "" + n; }
  function slaParts(ms) { ms = Math.max(0, ms); var s = Math.floor(ms / 1000); return { d: Math.floor(s / 86400), h: Math.floor((s % 86400) / 3600), m: Math.floor((s % 3600) / 60), s: s % 60 }; }
  function slaCell(n, u) { return '<div class="sla-cell"><span class="n">' + slaPad(n) + '</span><span class="u">' + u + '</span></div>'; }
  function slaDurLabel(min) {
    if (min == null || isNaN(min)) return "\u2014";
    if (min % 1440 === 0 && min >= 1440) { var d = min / 1440; return d + (d === 1 ? " day" : " days"); }
    if (min % 60 === 0 && min >= 60) { var h = min / 60; return h + (h === 1 ? " hour" : " hours"); }
    return min + (min === 1 ? " minute" : " minutes");
  }
  function slaDue(ms) { var d = new Date(ms); var h = d.getHours(), ap = h < 12 ? "am" : "pm", h12 = h % 12 || 12; return d.getDate() + " " + SLA_MON[d.getMonth()] + " " + d.getFullYear() + ", " + h12 + ":" + slaPad(d.getMinutes()) + " " + ap; }
  function slaInner(t) {
    var now = Date.now();
    var pol = (window.TK && TK.slaForTicket) ? TK.slaForTicket(t) : null;
    var _def = (window.TK && TK.slaDefaults) ? TK.slaDefaults() : { res: 3, first: 1 };
    var resMin = (pol && pol.slaRes != null) ? pol.slaRes : (t.slaRes || _def.res);
    var frMin = (pol && pol.slaFirst != null) ? pol.slaFirst : (t.slaFirst || _def.first);
    var resTotal = resMin * MIN, frTotal = frMin * MIN;
    // SLA runs against the REAL wall clock from when the ticket actually started.
    // Tickets are stamped on a frozen demo clock, so use a real-time slaStartMs
    // (stamped once, lazily) — otherwise every ticket reads as days old → instant breach.
    if (t.slaStartMs == null) { t.slaStartMs = Date.now(); TK.save(); }
    var startMs = t.slaStartMs;
    var resDue = startMs + resTotal, frDue = startMs + frTotal;
    var resRem = resDue - now, frRem = frDue - now;
    var done = t.wstatus === "completed";
    var responded = done || !!t.firstRespondedMs || (t.thread && t.thread.some(function (m) { return m.from === "agent"; }));
    var h = '<div class="sla-policy">Policy: ' + esc((pol && pol.policy) || t.slaPolicy || t.department || "Default") + '</div>';
    if (done) {
      h += '<div class="sla-within ok solo">' + IC.check + ' Resolved within target</div>';
    } else if (resRem > 0) {
      var p = slaParts(resRem), pct = Math.max(3, Math.min(100, (1 - resRem / resTotal) * 100));
      h += '<div class="sla-count"><div class="sla-cells">' + slaCell(p.d, "DAYS") + slaCell(p.h, "HOURS") + slaCell(p.m, "MINS") + slaCell(p.s, "SECS") + '</div>' +
        '<div class="sla-bar"><i style="width:' + pct + '%"></i></div>' +
        '<div class="sla-within ok">' + IC.check + ' Within SLA Target<span class="due">Due: ' + slaDue(resDue) + '</span></div></div>';
    } else {
      h += '<div class="sla-banner"><span class="ic">' + IC.alarm + '</span><b>SLA BREACHED !</b><span class="s">Immediate escalation required</span>' +
        '<span class="s2">Due date exceeded \u2014 Please complete urgently</span></div>';
    }
    if (t.escalated) h += '<div class="sla-kv"><span class="k">Escalated to</span><span class="v">' + esc(t.escalatedToName || "Department head") + '</span></div>';
    h += '<div class="sla-kv"><span class="k">Resolution Target</span><span class="v">' + slaDurLabel(resMin) + '</span></div>';
    h += '<div class="sla-kv"><span class="k">First Response</span><span class="v">' + slaDurLabel(frMin) + '</span></div>';
    if (!done && !responded) {
      if (frRem > 0) {
        var fp = slaParts(frRem);
        h += '<div class="sla-frbox"><div class="t">' + IC.alarm + ' First Response timer</div>' +
          '<div class="sla-cells">' + slaCell(fp.m, "MINS") + slaCell(fp.s, "SECS") + '</div></div>';
      } else {
        h += '<div class="sla-banner mini"><span class="ic">' + IC.alert + '</span><b>You Missed It!</b><span class="s">First response time exceeded!</span></div>';
      }
    }
    return h;
  }
  function slaShell(t) { return '<div class="sc-hd">' + IC.cal + 'SLA Information</div>' + slaInner(t); }
  function slaCard(t) { return '<div class="td-card side" id="tdSla">' + slaShell(t) + '</div>'; }
  /* live SLA ticker — updates the countdown every second while the detail is open */
  setInterval(function () {
    var node = document.getElementById("tdSla"); if (!node || node.offsetParent === null) return;
    var t = TK.getT(curId); if (!t) return;
    node.innerHTML = slaShell(t);
  }, 1000);
  function propsCard(t, ag) {
    function row(k, v, cls) { return '<div class="pr-row"><span class="k">' + k + '</span><span class="v ' + (cls || "") + '">' + v + '</span></div>'; }
    return '<div class="td-card side"><div class="sc-hd">' + IC.doc + 'Ticket Properties</div>' +
      row("Ticket ID", esc(did(t))) +
      row("Priority", '<span class="pr-badge ' + t.wpriority + '">' + esc(plbl(t.wpriority)) + '</span>', "raw") +
      row("Department", esc(t.department || "—"), "link") +
      row("Agent", esc(ag ? ag.name : "Unassigned")) +
      row("Source", esc(t.source || "form")) +
      row("Company", esc(t.company || "N/A"), "link") +
      (t.doc ? row("Document", '<button class="pr-doc" id="tdDocBtn">' + IC.doc + '<span class="dn">' + esc(t.doc) + '</span>' + IC.eye + '</button>', "raw") : "") +
      '</div>';
  }

  /* ---- Send Template ---- */
  var TPL_LIST = [
    { name: "Order Update", text: "Hi, your request has been received and our team is working on it. We'll update you shortly." },
    { name: "Resolution Confirmation", text: "Your ticket has been resolved. Please let us know if you need any further assistance." },
    { name: "Awaiting Response", text: "We're waiting on a few details from you to proceed. Could you please share them at your earliest convenience?" },
    { name: "Escalation Notice", text: "Your issue has been escalated to our specialist team and is being treated as a priority." },
    { name: "Feedback Request", text: "We'd love your feedback on how we handled your request. It only takes a moment!" }
  ];
  /* prefer the shared Template Library; the hardcoded TPL_LIST is only a last resort */
  function tplList() {
    var L = (window.AskEvaTemplates && AskEvaTemplates.list && AskEvaTemplates.list()) || [];
    if (L.length) return L.map(function (x) { return { name: x.n || x.name || "Template", text: x.p || x.text || "" }; });
    return TPL_LIST;
  }
  var tplSel = null;
  function tplBody(t) {
    return '<div class="td-card">' +
      '<label class="td-lbl">Mobile Number</label>' +
      '<div class="td-roinput">91' + esc((t.mobile || "").replace(/\D/g, "")) + '</div>' +
      '<button class="td-bigbtn" id="tdTpl">' + IC.upload + (tplSel ? esc(tplSel.name) : 'Select Template') + '</button>' +
      '<label class="td-lbl mt">Description:</label>' +
      '<textarea id="tdTplDesc" class="td-area" rows="4" placeholder="Enter description for this template">' + esc(tplSel ? tplSel.text : "") + '</textarea>' +
      '<div class="td-foot1 two"><button class="ax-btn ghost" id="tdTplReset">Reset</button>' +
        '<button class="ax-btn primary" id="tdTplSend">' + IC.send + 'Send Template</button></div>' +
    '</div>';
  }

  /* ---- Activity Logs ---- */
  function activityBody(t) {
    var creator = "testerr@gmail.com", viewer = "eshan@tunepath.com";
    // real events recorded on this ticket (status / agent / priority / dept changes)
    var live = (t.activity || []).map(function (e) {
      var det = e.meta
        ? ['<div class="r"><span class="k">Field</span><span class="v">' + esc(e.meta.Field || "\u2014") + '</span></div>' +
           '<div class="r"><span class="k">Old Value</span><span class="v">' + esc(e.meta.oldVal || "\u2014") + '</span></div>' +
           '<div class="r"><span class="k">Updated Value</span><span class="v">' + esc(e.meta.newVal || "\u2014") + '</span></div>' +
           '<div class="r"><span class="k">When</span><span class="v">' + esc(fmtDT(e.ms)) + '</span></div>']
        : ["View Details"];
      return { ic: e.meta && e.meta.Field === "Agent" ? "user" : "edit", tone: "", title: e.text, who: e.who || viewer, ms: e.ms, details: det, _html: !!e.meta };
    });
    var base = [
      { ic: "eye", tone: "", title: "Ticket Viewed", who: viewer, ms: NOW.getTime(), details: ["View Details"] },
      resBreached(t) ? { ic: "clock", tone: "red", title: "SLA Breached", who: "system", ms: t.createdMs + slaDefRes(t) * MIN, details: ["View SLA Breach Details", "View Details"] } : null,
      frBreached(t) ? { ic: "clock", tone: "", title: "FIRST_RESPONSE_BREACHED", who: "system", ms: t.createdMs + slaDefFirst(t) * MIN, details: ["View Details"] } : null,
      { ic: "plus", tone: "green", title: "Ticket Created", who: creator, ms: t.createdMs, details: ["View Details"] }
    ].filter(Boolean);
    // newest first: live events (already newest-first) on top of the baseline
    var items = live.concat(base);
    var rows = items.map(function (it) {
      var details = it._html
        ? '<details class="al-exp"><summary class="al-vd">' + IC.chevR + 'View Details</summary><div class="al-expbody">' + it.details.join("") + '</div></details>'
        : it.details.map(function (d) { return '<button class="al-vd">' + IC.chevR + esc(d) + '</button>'; }).join("");
      return '<div class="al-item"><span class="al-node ' + it.tone + '">' + (IC[it.ic] || IC.edit || "") + '</span>' +
        '<div class="al-b"><div class="al-r1"><span class="al-t">' + esc(it.title) + '</span><span class="al-ts">' + fmtDT(it.ms) + '</span></div>' +
        '<div class="al-who">' + esc(it.who) + '</div>' + details + '</div></div>';
    }).join("");
    return '<div class="td-card"><div class="td-cardtop"><button class="td-bigbtn sm" id="tdDl">' + IC.download + 'Download Logs</button></div>' +
      '<div class="al-list">' + rows + '</div></div>';
  }

  /* ---- Ticket History ---- */
  var HIST_PP = 10;
  function historyBody(t) {
    var all = TK.tickets.filter(function (x) { return !x.spam; });
    var pages = Math.max(1, Math.ceil(all.length / HIST_PP));
    if (histPage > pages) histPage = pages;
    var start = (histPage - 1) * HIST_PP, slice = all.slice(start, start + HIST_PP);
    var rows = slice.map(function (x, i) {
      var desc = (x.thread && x.thread[0] && x.thread[0].text) || x.subject || "—";
      desc = desc.length > 64 ? desc.slice(0, 64) + "…" : desc;
      var cur = x.id === curId;
      return '<div class="th-row' + (cur ? ' cur' : '') + '"><span class="sn">' + (start + i + 1) + '</span>' +
        '<div class="m"><div class="r1"><span class="tid">' + esc(did(x)) + '</span>' +
          '<span class="td-statusmini ' + wcls(x.wstatus) + '">' + esc(wlbl(x.wstatus)) + '</span>' +
          '<span class="pr-badge ' + x.wpriority + '">' + esc(plbl(x.wpriority)) + '</span>' +
          (cur ? '<span class="th-curtag">current</span>' : '') + '</div>' +
          '<div class="r2">' + esc(x.department) + ' · ' + esc((TK.agentById(x.assignee) || { name: "—" }).name) + '</div>' +
          '<div class="r3"><span class="k">Description</span>' + esc(desc) + '</div></div>' +
        '<button class="th-eye" data-id="' + x.id + '" aria-label="View ' + esc(did(x)) + '">' + IC.eye + '</button></div>';
    }).join("");
    var pager = pages > 1 ? '<div class="th-pager"><span class="rng">' + (start + 1) + '-' + (start + slice.length) + ' of ' + all.length + ' tickets</span>' +
      '<div class="pg"><button class="th-pg arr" data-pg="' + (histPage - 1) + '"' + (histPage <= 1 ? ' disabled' : '') + '>' + IC.chevL + '</button>' +
      Array.apply(null, { length: pages }).map(function (_, i) { return '<button class="th-pg num' + (i + 1 === histPage ? ' on' : '') + '" data-pg="' + (i + 1) + '">' + (i + 1) + '</button>'; }).join("") +
      '<button class="th-pg arr" data-pg="' + (histPage + 1) + '"' + (histPage >= pages ? ' disabled' : '') + '>' + IC.chevR + '</button></div></div>' : '';
    return '<div class="td-card"><div class="th-hd"><div class="th-ttl">Ticket History <span>(' + all.length + ' tickets)</span></div>' +
      '<button class="td-bigbtn sm" id="tdRefresh">' + IC.refresh + 'Refresh</button></div>' +
      '<div class="th-list">' + rows + '</div>' + pager + '</div>';
  }

  /* ---- Call Logs ---- */
  function callsBody(t) {
    var calls = t.calls || [];
    if (!calls.length) {
      return '<div class="td-card"><div class="td-empty2"><div class="ic">' + IC.phone + '</div><div class="t">No call logs yet</div>' +
        '<div class="s">Calls placed from this ticket will appear here.</div>' +
        '<button class="td-bigbtn sm mt" data-a="call">' + IC.phone + 'Call customer</button></div></div>';
    }
    var rows = calls.map(function (cl) {
      return '<div class="td-callrow"><span class="ic ' + (cl.dir || "out") + '">' + IC.phone + '</span>' +
        '<div class="m"><div class="r1">' + esc(cl.title || "Outgoing call") + '</div>' +
          '<div class="r2">' + esc(cl.num || "") + ' · ' + esc(cl.when || "") + '</div></div>' +
        '<button class="th-eye" data-a="call" aria-label="Call again">' + IC.phone + '</button></div>';
    }).join("");
    return '<div class="td-card"><div class="th-hd"><div class="th-ttl">Call Logs <span>(' + calls.length + ')</span></div>' +
      '<button class="td-bigbtn sm" data-a="call">' + IC.phone + 'Call customer</button></div>' +
      '<div class="td-calllist">' + rows + '</div></div>';
  }

  /* =========================================================
     BIND
     ========================================================= */
  function bindBody(t, c, ag) {
    if (tab === "details") {
      var st = $("#tdStatus", el); if (st) st.addEventListener("click", function () {
        TK.radioSheet("Update Status", (TM().WST_SET || TM().WST).map(function (s) { return { v: s[0], label: s[1], on: t.wstatus === s[0] }; }), function (v) {
          t.wstatus = v; t.status = v === "completed" ? "resolved" : (v === "pending" || v === "awaiting") ? "pending" : "open";
          if (v === "completed" && !t.completedMs) t.completedMs = NOW.getTime();
          TK.save(); render(); toast("Status updated to " + wlbl(v));
          if (TK.notifyCustomer) TK.notifyCustomer(t, v);
        });
      });
      $$('.td-gbtn[data-a]', el).forEach(function (b) { b.addEventListener("click", function () { gAction(b.getAttribute("data-a"), t); }); });
      $$('.td-chatlink[data-a]', el).forEach(function (b) { b.addEventListener("click", function () { gAction(b.getAttribute("data-a"), t); }); });
      var docBtn = $("#tdDocBtn", el); if (docBtn) docBtn.addEventListener("click", function () { viewDoc(t); });
      $$('.tdfb-star', el).forEach(function (sBtn) { sBtn.addEventListener("click", function () {
        t.rating = +sBtn.getAttribute("data-v"); TK.save(); rebody(); toast("Feedback saved · " + t.rating + "★");
      }); });
      $$('.td-qrbtn[data-a]', el).forEach(function (b) { b.addEventListener("click", function () { qrAction(b.getAttribute("data-a"), t); }); });
      var ta = $("#tdReply", el), send = $("#tdSend", el);
      if (ta) ta.addEventListener("input", function () { if (send) send.disabled = !ta.value.trim(); });
      if (send) send.addEventListener("click", function () {
        var v = ta.value.trim(); if (!v) return;
        t.thread.push({ from: "agent", who: t.assignee && t.assignee !== "unassigned" ? t.assignee : "eshan", text: v, mins: 0 });
        t.updated = 0; TK.save(); chatDeliver(t, { type: "text", text: v }); rebody(); toast("Reply sent to " + chatTarget(t).name + " on WhatsApp");
      });
    } else if (tab === "template") {
      var tpl = $("#tdTpl", el); if (tpl) tpl.addEventListener("click", function () {
        // Universal template sender (shared-library.js single source of truth)
        if (window.AskEvaTemplates && window.AskEvaTemplates.open) {
          window.AskEvaTemplates.open({ title: "Select template", fields: ticketMapFields, onSend: function (t) {
            tplSel = { name: (t && (t.n || t.name)) || "Template", text: (t && (t.p || t.text)) || "" };
            rebody();
          } });
          return;
        }
        var _tpls = tplList();
        var html = '<div class="ax-grip"></div><div class="ax-sheet-head"><div class="ax-sheet-ttl">Select template</div></div><div class="ax-optlist">' +
          _tpls.map(function (x, i) { return '<button class="ax-opt" data-i="' + i + '"><span class="t"><span class="nm">' + esc(x.name) + '</span><span class="co">' + esc(x.text.slice(0, 46)) + '\u2026</span></span></button>'; }).join("") + '</div>';
        var s = TK.openSheet(html);
        $$(".ax-opt", s).forEach(function (b) { b.addEventListener("click", function () { tplSel = _tpls[+b.getAttribute("data-i")]; TK.closeSheet(); rebody(); }); });
      });
      var rs = $("#tdTplReset", el); if (rs) rs.addEventListener("click", function () { tplSel = null; var d = $("#tdTplDesc", el); if (d) d.value = ""; rebody(); toast("Reset"); });
      var snd = $("#tdTplSend", el); if (snd) snd.addEventListener("click", function () {
        var d = $("#tdTplDesc", el); var msg = (d && d.value.trim()) || (tplSel && tplSel.text) || "";
        if (!msg) { toast("Select a template first"); return; }
        t.thread.push({ from: "agent", who: t.assignee && t.assignee !== "unassigned" ? t.assignee : "eshan", text: msg, mins: 0 });
        t.updated = 0; TK.save();
        chatDeliver(t, { type: "template", name: (tplSel && tplSel.name) || "Template", text: msg });
        toast("Template sent to " + chatTarget(t).name + " on WhatsApp");
        tplSel = null; tab = "details"; rebody();
      });
    } else if (tab === "activity") {
      var dl2 = $("#tdDl", el); if (dl2) dl2.addEventListener("click", function () { downloadActivity(t); });
      $$(".al-vd", el).forEach(function (b) { b.addEventListener("click", function () {
        var label = b.textContent.trim();
        TK.openSheet('<div class="ax-grip"></div><div class="ax-sheet-head"><div class="ax-sheet-ttl">' + esc(label) + '</div>' +
          '<div class="ax-sheet-sub">' + esc(did(t)) + ' · ' + esc(t.subject) + '</div></div>' +
          '<div class="td-vdsheet"><div class="r"><span class="k">Event</span><span class="v">' + esc(label.replace(/^View /, "").replace(/ Details$/, "")) + '</span></div>' +
          '<div class="r"><span class="k">Ticket</span><span class="v">' + esc(did(t)) + '</span></div>' +
          '<div class="r"><span class="k">When</span><span class="v">' + esc(fmtDT(NOW.getTime())) + '</span></div></div>');
      }); });
    } else if (tab === "history") {
      var rf = $("#tdRefresh", el); if (rf) rf.addEventListener("click", function () { rebody(); toast("Refreshed"); });
      $$(".th-eye", el).forEach(function (b) { b.addEventListener("click", function () { open(b.getAttribute("data-id")); }); });
      $$(".th-pg[data-pg]", el).forEach(function (b) { b.addEventListener("click", function () {
        var p = +b.getAttribute("data-pg"); var all = TK.tickets.filter(function (x) { return !x.spam; });
        var pages = Math.max(1, Math.ceil(all.length / HIST_PP)); if (p < 1 || p > pages || p === histPage) return;
        histPage = p; rebody();
      }); });
    } else if (tab === "calls") {
      $$('[data-a="call"]', el).forEach(function (b) { b.addEventListener("click", function () { placeCall(t); }); });
    }
  }

  function gAction(a, t) {
    if (a === "note") {
      var html = '<div class="ax-grip"></div><div class="ax-sheet-head"><div class="ax-sheet-ttl">Add note</div></div>' +
        '<div class="ax-field"><label class="ax-label">Internal note</label><div class="ax-control area"><textarea id="tdNoteInp" rows="3" placeholder="Track important information…"></textarea></div></div>' +
        '<button class="ax-sheetbtn" id="tdNoteSave">Save note</button>';
      var s = TK.openSheet(html);
      $("#tdNoteSave", s).addEventListener("click", function () {
        var v = ($("#tdNoteInp", s).value || "").trim(); if (!v) { toast("Write a note"); return; }
        (t.notes = t.notes || []).unshift({ who: ".", when: fmtDT(NOW.getTime()), text: v }); TK.save();
        TK.closeSheet(); rebody(); toast("Note added");
      });
    } else if (a === "switch") {
      var html2 = '<div class="ax-grip"></div><div class="ax-sheet-head"><div class="ax-sheet-ttl">Switch agent</div></div><div class="ax-optlist">' +
        TK.AGENTS.map(function (x) { return '<button class="ax-opt' + (t.assignee === x.id ? " on" : "") + '" data-id="' + x.id + '"><span class="av" style="background:' + x.color + '">' + esc(x.initials) + '</span><span class="t"><span class="nm">' + esc(x.name) + '</span><span class="co">' + esc(x.role) + '</span></span><span class="tick">' + IC.check + '</span></button>'; }).join("") + '</div>';
      var s2 = TK.openSheet(html2);
      $$(".ax-opt", s2).forEach(function (b) { b.addEventListener("click", function () { t.assignee = b.getAttribute("data-id"); t.assignedMs = NOW.getTime(); TK.save(); TK.closeSheet(); render(); toast("Switched to " + TK.agentById(t.assignee).name); }); });
    } else if (a === "chat") { accessChat(t); }
    else if (a === "download") { downloadTicket(t); }
    else if (a === "refresh") { render(); toast("Refreshed"); }
    else if (a === "call") { placeCall(t); }
  }
  function downloadActivity(t) {
    var lines = ["Activity Logs — " + did(t), t.subject, ""];
    lines.push("Ticket Viewed · eshan@tunepath.com · " + fmtDT(NOW.getTime()));
    if (resBreached(t)) lines.push("SLA Breached · system · " + fmtDT(t.createdMs + slaDefRes(t) * MIN));
    if (frBreached(t)) lines.push("FIRST_RESPONSE_BREACHED · system · " + fmtDT(t.createdMs + slaDefFirst(t) * MIN));
    lines.push("Ticket Created · testerr@gmail.com · " + fmtDT(t.createdMs));
    var ok = dl(did(t) + "-activity.txt", lines.join("\n"), "text/plain;charset=utf-8");
    toast(ok ? "Activity logs downloaded" : "Download blocked by browser");
  }
  function qrAction(a, t) {
    if (a === "quick") {
      var REPLIES = ((window.TK && TK.quickReplies && TK.quickReplies()) || []).filter(function (q) { return q && (q.msg || q.title); });
      if (!REPLIES.length) { toast("No quick replies yet — add them in Ticketing Settings › Quick Reply"); return; }
      var qrClock = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></svg>';
      var qrSend = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 12h14m0 0-5-5m5 5-5 5"/></svg>';
      var html = '<div class="ax-grip"></div><div class="ax-sheet-head"><div class="ax-sheet-ttl">Quick replies</div><div class="ax-sheet-sub">Tap to insert into your reply</div></div><div class="pick-body tdqr-sheet">' +
        REPLIES.map(function (q, i) {
          return '<button class="pick-opt" data-i="' + i + '"><span class="pk-qric">' + qrClock + '</span>' +
            '<span class="pk-mid"><span class="nm">' + esc(q.title || q.msg) + '</span>' + (q.msg ? '<span class="sub">' + esc(q.msg) + '</span>' : '') + '</span>' +
            '<span class="pk-count">' + qrSend + '</span></button>';
        }).join("") + '</div>';
      var s = TK.openSheet(html);
      $$(".pick-opt", s).forEach(function (b) { b.addEventListener("click", function () { var q = REPLIES[+b.getAttribute("data-i")]; var ta = $("#tdReply", el); if (ta && q) { ta.value = q.msg || q.title; var sb = $("#tdSend", el); if (sb) sb.disabled = false; } TK.closeSheet(); }); });
    } else {
      var notes = (window.TK && TK.videoNotes) ? TK.videoNotes() : [];
      if (!notes.length) { toast("No video notes configured — add one in Settings › Video Note"); return; }
      var html2 = '<div class="ax-grip"></div><div class="ax-sheet-head"><div class="ax-sheet-ttl">Send a video note</div>' +
        '<div class="ax-sheet-sub">Choose a configured video note to send</div></div><div class="ax-optlist">' +
        notes.map(function (v) {
          return '<button class="ax-opt" data-id="' + v.id + '"><span class="av empty" style="background:var(--accent-soft);color:var(--accent-deep)">' + IC.video + '</span>' +
            '<span class="t"><span class="nm">' + esc(v.title) + '</span>' + (v.desc ? '<span class="sub">' + esc(v.desc) + '</span>' : '') + '</span></button>';
        }).join("") + '</div>';
      var s2 = TK.openSheet(html2);
      $$(".ax-opt", s2).forEach(function (b) {
        b.addEventListener("click", function () {
          var v = notes.filter(function (x) { return x.id === b.getAttribute("data-id"); })[0]; if (!v) return;
          TK.closeSheet();
          t.thread = t.thread || [];
          t.thread.push({ from: "agent", who: t.assignee && t.assignee !== "unassigned" ? t.assignee : "eshan",
            kind: "video", videoId: v.id, videoUrl: (TK.videoNoteURL ? TK.videoNoteURL(v.id) : null), text: v.title, mins: 0 });
          t.updated = 0; TK.save(); rebody();
          chatDeliver(t, { type: "video", text: v.title });
          if (TK.notifyCustomer) { try { TK.notifyCustomer(t, "videonote"); } catch (e) {} }
          toast("Video note sent to " + chatTarget(t).name + " on WhatsApp");
        });
      });
    }
  }

  function fmtDT(ms) { var d = new Date(ms); return pad(d.getDate()) + "/" + pad(d.getMonth() + 1) + "/" + d.getFullYear() + ", " + pad(d.getHours()) + ":" + pad(d.getMinutes()) + ":" + pad(d.getSeconds()); }
  function pad(n) { return n < 10 ? "0" + n : "" + n; }

  /* icons */
  var IC = {
    back: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M15 19l-7-7 7-7"/></svg>',
    edit: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M11 4H5a2 2 0 0 0-2 2v13a2 2 0 0 0 2 2h13a2 2 0 0 0 2-2v-6"/><path d="M18.5 2.5a2.12 2.12 0 0 1 3 3L12 15l-4 1 1-4Z"/></svg>',
    user: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="8" r="4"/><path d="M4 21c0-4 3.6-6 8-6s8 2 8 6"/></svg>',
    flag: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M5 21V4M5 4h11l-2 4 2 4H5"/></svg>',
    alert: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="M12 8v4M12 16h.01"/></svg>',
    phone: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linejoin="round"><path d="M5 4h3l1.5 4-2 1.5a12 12 0 0 0 5 5L14 12l4 1.5V17a2 2 0 0 1-2 2A14 14 0 0 1 5 6Z"/></svg>',
    cal: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="5" width="18" height="16" rx="2.5"/><path d="M3 10h18M8 3v4M16 3v4"/></svg>',
    doc: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 2h8l4 4v16H6z"/><path d="M14 2v4h4M9 13h6M9 17h6"/></svg>',
    info: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="M12 11v5M12 8h.01"/></svg>',
    chevD: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m6 9 6 6 6-6"/></svg>',
    chevR: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m9 6 6 6-6 6"/></svg>',
    chevL: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m15 6-6 6 6 6"/></svg>',
    note: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 5h16M4 10h16M4 15h10"/></svg>',
    swap: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M7 4 4 7l3 3M4 7h13M17 20l3-3-3-3M20 17H7"/></svg>',
    chat: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14 9a2 2 0 0 1-2 2H6l-4 4V4c0-1.1.9-2 2-2h8a2 2 0 0 1 2 2v5Z"/><path d="M18 9h2a2 2 0 0 1 2 2v11l-4-4h-6a2 2 0 0 1-2-2v-1"/><circle cx="5.2" cy="6.4" r=".7" fill="currentColor" stroke="none"/><circle cx="8" cy="6.4" r=".7" fill="currentColor" stroke="none"/><circle cx="10.8" cy="6.4" r=".7" fill="currentColor" stroke="none"/></svg>',
    download: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 4v10m0 0 4-4m-4 4-4-4M5 19h14"/></svg>',
    refresh: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 12a9 9 0 1 0 3-6.7L3 8M3 4v4h4"/></svg>',
    video: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linejoin="round"><rect x="3" y="6" width="13" height="12" rx="2"/><path d="m16 10 5-3v10l-5-3"/></svg>',
    send: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 12l16-8-6 16-3-7-7-1Z"/></svg>',
    upload: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M16 16l-4-4-4 4"/><path d="M12 12v9"/><path d="M20.39 18.39A5 5 0 0 0 18 9h-1.26A8 8 0 1 0 3 16.3"/></svg>',
    alarm: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="13" r="8"/><path d="M12 9v4l2.5 2M5 3 2 6M19 3l3 3"/></svg>',
    eye: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7-10-7-10-7Z"/><circle cx="12" cy="12" r="3"/></svg>',
    check: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="m5 12 4 4 10-11"/></svg>',
    clock: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3.5 2"/></svg>',
    plus: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"><path d="M12 5v14M5 12h14"/></svg>',
    eyeS: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7-10-7-10-7Z"/><circle cx="12" cy="12" r="3"/></svg>'
  };
  IC.eye = IC.eyeS;

  window.TKDetail = { open: open, close: close };
})();
