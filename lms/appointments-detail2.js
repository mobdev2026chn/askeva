/* =========================================================
   AskEva — Appointment DETAIL (tabbed, full rebuild)
   Mobile translation of the web "Appointment Details" page:
     tabs → Appointment Details · Complete · Reschedule ·
            Activity Logs · Profile · Notes · Feedback
   Overrides AX.openDetail from appointments-detail.js.
   Persists notes / completion history / reschedule history /
   activity timeline on each appointment, and re-renders the
   underlying Bookings list so everything stays in sync.
   ========================================================= */
(function (AX) {
  "use strict";
  if (!AX || !AX.pane) return;
  var $ = AX.$, $$ = AX.$$, I = AX.I, esc = AX.esc, pad = AX.pad;
  var detailEl = document.getElementById("axDetail");
  if (!detailEl) return;

  /* ---------- one-time CSS ---------- */
  if (!document.getElementById("apxStyles")) {
    var st = document.createElement("style"); st.id = "apxStyles";
    st.textContent = [
      ".apx-tabs{display:flex;gap:4px;overflow-x:auto;scrollbar-width:none;padding:4px 12px 0;border-bottom:1px solid var(--line);background:var(--surface);}",
      ".apx-tabs::-webkit-scrollbar{display:none;}",
      ".apx-tab{flex:0 0 auto;display:inline-flex;align-items:center;gap:6px;border:none;background:transparent;cursor:pointer;font-family:var(--font-body);font-size:13.5px;font-weight:700;color:var(--ink-3);padding:11px 10px 12px;position:relative;white-space:nowrap;}",
      ".apx-tab svg{width:15px;height:15px;}",
      ".apx-tab.on{color:var(--eva-green-deep);}",
      ".apx-tab-done{opacity:.42;cursor:not-allowed;}",
      ".apx-tab.on::after{content:'';position:absolute;left:8px;right:8px;bottom:-1px;height:2.5px;border-radius:2px;background:var(--eva-green);}",
      ".apx-body{padding:14px 14px 30px;}",
      ".apx-card{background:var(--surface);border:1px solid var(--line);border-radius:16px;box-shadow:var(--shadow-xs);padding:16px;margin-bottom:13px;}",
      ".apx-hcard{padding:18px 18px 20px;}",
      ".apx-card>.hd{display:flex;align-items:center;gap:8px;font-size:15px;font-weight:800;color:var(--ink);letter-spacing:-.01em;margin-bottom:14px;}",
      ".apx-card>.hd svg{width:18px;height:18px;color:var(--eva-green-deep);}",
      ".apx-hcard .ttl{display:flex;align-items:center;gap:8px;font-size:16px;font-weight:800;color:var(--eva-green-deep);letter-spacing:-.01em;margin-bottom:16px;padding-bottom:14px;border-bottom:1px solid var(--line);}",
      ".apx-hcard .ttl svg{width:18px;height:18px;}",
      ".apx-meta{display:grid;grid-template-columns:1fr 1fr;gap:18px 16px;}",
      ".apx-meta .k{font-size:11px;font-weight:700;letter-spacing:.04em;text-transform:uppercase;color:var(--ink-4);margin-bottom:6px;}",
      ".apx-meta .v{font-size:14px;line-height:1.35;font-weight:700;color:var(--ink);word-break:break-word;}",
      ".apx-meta .v .vt{display:inline-block;margin-top:2px;font-size:13px;font-weight:600;color:var(--ink-2);}",
      ".apx-meta .full{grid-column:1 / -1;}",
      ".apx-stpill{display:inline-block;font-size:11px;font-weight:800;padding:3px 10px;border-radius:999px;border:1px solid;}",
      ".apx-stpill.current{color:#9A6B05;background:#FBF1D8;border-color:#F0DFB0;}",
      ".apx-stpill.resched{color:#2563EB;background:#E5EEFD;border-color:#CFE0FB;}",
      ".apx-stpill.completed{color:var(--eva-green-deep);background:var(--accent-soft);border-color:var(--accent-soft-2);}",
      ".apx-stpill.cancelled{color:#C23A18;background:#FCE9E3;border-color:#F5CDC0;}",
      ".apx-field{margin-bottom:14px;}",
      ".apx-field label{display:block;font-size:12.5px;font-weight:700;color:var(--ink-2);margin-bottom:6px;}",
      ".apx-field label .req{color:#E5484D;margin-right:2px;}",
      ".apx-ro,.apx-in,.apx-ta,.apx-sel{width:100%;font-family:var(--font-body);font-size:14px;color:var(--ink);background:var(--surface-2);border:1.5px solid var(--line);border-radius:11px;padding:12px 13px;}",
      ".apx-ro{color:var(--ink-2);}",
      ".apx-in:focus,.apx-ta:focus,.apx-sel:focus{outline:none;border-color:var(--eva-green);background:#fff;box-shadow:0 0 0 3px rgba(61,200,56,.16);}",
      ".apx-ta{resize:none;min-height:120px;line-height:1.5;}",
      ".apx-two{display:grid;grid-template-columns:1fr 1fr;gap:11px;}",
      ".apx-count{display:block;text-align:right;font-size:11.5px;font-weight:600;color:var(--ink-4);margin-top:5px;}",
      ".apx-btnrow{display:flex;justify-content:flex-end;gap:10px;margin-top:14px;flex-wrap:wrap;}",
      ".apx-btn{border:none;cursor:pointer;font-family:var(--font-body);font-size:13.5px;font-weight:800;border-radius:11px;padding:11px 18px;display:inline-flex;align-items:center;gap:7px;}",
      ".apx-btn svg{width:16px;height:16px;}",
      ".apx-btn.green{background:var(--eva-gradient);color:#fff;box-shadow:var(--shadow-xs);}",
      ".apx-btn.amber{background:linear-gradient(135deg,#F5B829,#E59A0E);color:#fff;box-shadow:var(--shadow-xs);}",
      ".apx-btn.ghost{background:#fff;color:var(--ink-2);border:1.5px solid var(--line);}",
      ".apx-btn:active{transform:translateY(1px);}",
      ".apx-hist{margin-top:16px;}",
      ".apx-hist .hd{display:flex;align-items:center;gap:8px;font-size:14px;font-weight:800;color:var(--ink);margin-bottom:10px;}",
      ".apx-hist .hd svg{width:16px;height:16px;color:var(--eva-green-deep);}",
      ".apx-hrow{display:flex;gap:10px;padding:11px 0;border-bottom:1px solid var(--line);font-size:13px;}",
      ".apx-hrow:last-child{border-bottom:none;}",
      ".apx-hrow .sn{flex:0 0 22px;font-weight:800;color:var(--ink-4);}",
      ".apx-hrow .ds{flex:1;color:var(--ink);font-weight:600;line-height:1.45;}",
      ".apx-hrow .dt{flex:0 0 auto;color:var(--ink-4);font-weight:600;font-size:12px;text-align:right;}",
      ".apx-empty2{text-align:center;color:var(--ink-4);font-size:13px;font-weight:600;padding:24px 10px;}",
      ".apx-stats{display:grid;grid-template-columns:1fr 1fr;gap:11px;margin-bottom:14px;}",
      ".apx-stat{background:var(--surface);border:1px solid var(--line);border-radius:14px;padding:14px;text-align:center;box-shadow:var(--shadow-xs);}",
      ".apx-stat .l{font-size:11.5px;font-weight:700;color:var(--ink-3);margin-bottom:7px;}",
      ".apx-stat .v{font-size:22px;font-weight:800;color:var(--eva-green-deep);letter-spacing:-.02em;display:flex;align-items:center;justify-content:center;gap:6px;}",
      ".apx-stat .v svg{width:16px;height:16px;}",
      ".apx-prof{display:flex;align-items:center;gap:14px;border-left:3px solid var(--eva-green);padding:4px 0 4px 14px;margin-bottom:4px;}",
      ".apx-prof .av{width:62px;height:62px;border-radius:50%;background:var(--eva-gradient);color:#fff;display:grid;place-items:center;font-size:24px;font-weight:800;flex:0 0 62px;}",
      ".apx-prof .nm{font-size:19px;font-weight:800;color:var(--eva-green-deep);letter-spacing:-.01em;}",
      ".apx-chips{display:flex;gap:8px;flex-wrap:wrap;margin-top:8px;}",
      ".apx-chip{display:inline-flex;align-items:center;gap:6px;font-size:12px;font-weight:700;color:var(--ink-2);background:var(--accent-soft);border:1px solid var(--accent-soft-2);border-radius:999px;padding:5px 11px;}",
      ".apx-chip svg{width:13px;height:13px;color:var(--eva-green-deep);}",
      ".apx-kv{font-size:13px;line-height:2;}",
      ".apx-kv b{color:var(--ink);} .apx-kv .mut{color:var(--ink-4);}",
      ".apx-tag{display:inline-block;font-size:11px;font-weight:700;padding:3px 9px;border-radius:7px;margin:2px 5px 2px 0;}",
      ".apx-tag.dep{color:#2563EB;background:#E5EEFD;border:1px solid #CFE0FB;}",
      ".apx-tag.mgr{color:var(--eva-green-deep);background:var(--accent-soft);border:1px solid var(--accent-soft-2);}",
      ".apx-tl{position:relative;padding-left:22px;}",
      ".apx-tl .ev{position:relative;padding:0 0 18px 0;}",
      ".apx-tl .ev::before{content:'';position:absolute;left:-18px;top:3px;width:11px;height:11px;border-radius:50%;border:2.5px solid var(--eva-green);background:var(--surface);}",
      ".apx-tl .ev::after{content:'';position:absolute;left:-13px;top:16px;bottom:0;width:2px;background:var(--line);}",
      ".apx-tl .ev:last-child::after{display:none;}",
      ".apx-tl .et{font-size:14px;font-weight:700;color:var(--ink);}",
      ".apx-tl .ed{font-size:11.5px;color:var(--ink-4);font-weight:600;margin-top:3px;}",
      ".apx-tl details{margin-top:7px;}",
      ".apx-tl summary{font-size:12.5px;font-weight:700;color:var(--eva-green-deep);cursor:pointer;list-style:none;display:inline-flex;align-items:center;gap:5px;}",
      ".apx-tl summary::-webkit-details-marker{display:none;}",
      ".apx-tl .exp{margin-top:8px;font-size:12.5px;color:var(--ink-2);line-height:1.7;background:var(--surface-2);border-radius:10px;padding:10px 12px;}",
      ".apx-tl .exp-r{display:flex;gap:12px;justify-content:space-between;padding:3px 0;}",
      ".apx-tl .exp-r .k{flex:0 0 auto;font-weight:800;color:var(--ink-3);}",
      ".apx-tl .exp-r .v{flex:1;text-align:right;color:var(--ink);font-weight:600;overflow-wrap:anywhere;}",
      ".apx-ntypes{display:flex;gap:7px;flex-wrap:wrap;margin-bottom:13px;}",
      ".apx-ntype{display:inline-flex;align-items:center;gap:6px;border:1.5px solid var(--line);background:#fff;border-radius:10px;padding:8px 12px;cursor:pointer;font-family:var(--font-body);font-size:12.5px;font-weight:700;color:var(--ink-2);}",
      ".apx-ntype svg{width:14px;height:14px;}",
      ".apx-ntype.on{border-color:var(--eva-green);color:var(--eva-green-deep);background:var(--accent-soft);}",
      ".apx-note{display:flex;gap:11px;padding:12px 0;border-bottom:1px solid var(--line);}",
      ".apx-note:last-child{border-bottom:none;}",
      ".apx-note .nic{flex:0 0 32px;width:32px;height:32px;border-radius:9px;background:var(--accent-soft);color:var(--eva-green-deep);display:grid;place-items:center;}",
      ".apx-note .nic svg{width:16px;height:16px;}",
      ".apx-note .nb{flex:1;min-width:0;}",
      ".apx-note .nt{font-size:13.5px;color:var(--ink);font-weight:600;line-height:1.45;word-break:break-word;}",
      ".apx-note .nm{font-size:11px;color:var(--ink-4);font-weight:600;margin-top:4px;}",
      ".apx-note .ntype{font-size:10px;font-weight:800;text-transform:uppercase;letter-spacing:.04em;color:var(--eva-green-deep);}",
      ".apx-fb{border:1px solid #BBDEFB;background:#E8F2FE;border-radius:14px;padding:16px;display:flex;gap:12px;}",
      ".apx-fb .fic{flex:0 0 26px;width:26px;height:26px;border-radius:50%;background:#2563EB;color:#fff;display:grid;place-items:center;font-weight:800;font-size:14px;height:26px;}",
      ".apx-fb .ft{font-size:14px;font-weight:800;color:var(--ink);margin-bottom:6px;}",
      ".apx-fb .fl{font-size:12.5px;color:var(--ink-2);line-height:1.7;}",
      ".apx-stars{display:flex;gap:3px;margin:6px 0;}",
      ".apx-stars svg{width:20px;height:20px;color:#E2E5E0;}",
      ".apx-stars svg.on{color:#F5B829;}",
      ".apx-autolist{display:flex;flex-direction:column;gap:9px;}",
      ".apx-autorow{display:flex;align-items:center;gap:11px;background:var(--surface-2);border:1px solid var(--line);border-radius:12px;padding:11px 12px;}",
      ".apx-autorow .ic{flex:0 0 32px;width:32px;height:32px;border-radius:9px;background:var(--accent-soft);color:var(--eva-green-deep);display:grid;place-items:center;}",
      ".apx-autorow .ic svg{width:16px;height:16px;}",
      ".apx-autorow .tx{flex:1;min-width:0;}",
      ".apx-autorow .tx .t{font-size:13px;font-weight:800;color:var(--ink);}",
      ".apx-autorow .tx .s{font-size:11.5px;font-weight:600;color:var(--ink-3);margin-top:2px;}",
      ".apx-autorow .autobadge{flex:0 0 auto;font-size:10px;font-weight:800;letter-spacing:.04em;text-transform:uppercase;color:var(--eva-green-deep);background:var(--accent-soft);border:1px solid var(--accent-soft-2);border-radius:999px;padding:3px 9px;}",
      ".apx-card .hd svg{width:16px;height:16px;flex:0 0 auto;}",
      "#apxRsDate svg{width:15px;height:15px;flex:0 0 auto;color:var(--ink-4);}",
      ".apx-tl summary svg{width:12px;height:12px;}",
      ".apx-stat .v svg{width:15px;height:15px;}",
      ".apx-subhd{display:flex;align-items:center;gap:7px;font-size:13px;font-weight:800;color:var(--ink);margin-bottom:8px;}",
      ".apx-subhd svg{width:15px;height:15px;flex:0 0 auto;color:var(--eva-green-deep);}",
      /* two-column rows: reserve room for a 2-line label so the boxes below stay aligned */
      ".apx-two>.apx-field>label,.apx-two>div>.apx-field>label{min-height:38px;line-height:1.35;}",
      ".apx-two .apx-field{margin-bottom:0;}",
      ".apx-two{margin-bottom:14px;align-items:start;}",
      /* ===== Profile tab redesign (web-parity) ===== */
      ".apf-card{padding:0;overflow:hidden;}",
      ".apf-hd{display:flex;align-items:center;gap:9px;font-size:14.5px;font-weight:800;color:var(--ink);letter-spacing:-.01em;padding:14px 16px;border-bottom:1px solid var(--line);}",
      ".apf-hd.sm{font-size:13.5px;padding:13px 16px;}",
      ".apf-hd svg{width:17px;height:17px;color:var(--ink-2);flex:0 0 auto;}",
      ".apf-prof{display:flex;align-items:center;gap:12px;margin:12px;padding:11px 12px;border:1px solid var(--line);border-left:4px solid var(--eva-green);border-radius:12px;}",
      ".apf-av{width:46px;height:46px;border-radius:50%;background:var(--eva-gradient);display:grid;place-items:center;flex:0 0 46px;box-shadow:var(--shadow-xs);}",
      ".apf-av svg{width:24px;height:24px;color:#fff;}",
      "#apxRsDT{gap:10px;background:var(--accent-soft);border-color:var(--accent-soft-2);color:var(--eva-green-deep);} #apxRsDT svg{width:17px;height:17px;flex:0 0 17px;color:var(--eva-green-deep);}",
      ".apf-pinfo{min-width:0;}",
      ".apf-nm{font-size:17px;font-weight:800;color:var(--eva-green-deep);letter-spacing:-.015em;line-height:1.15;word-break:break-word;}",
      ".apf-chips{display:flex;gap:7px;flex-wrap:wrap;margin-top:7px;}",
      ".apf-chip{display:inline-flex;align-items:center;gap:5px;font-size:11.5px;font-weight:700;color:var(--ink-2);background:var(--accent-soft);border-radius:7px;padding:4px 9px;}",
      ".apf-chip svg{width:14px;height:14px;color:var(--eva-green-deep);flex:0 0 auto;}",
      ".apf-sechd{display:flex;align-items:center;gap:9px;font-size:16px;font-weight:800;color:var(--ink);letter-spacing:-.01em;margin:20px 2px 12px;}",
      ".apf-sechd svg{width:19px;height:19px;color:var(--eva-green-deep);flex:0 0 auto;}",
      ".apf-stats{display:grid;grid-template-columns:1fr 1fr;gap:11px;margin-bottom:13px;}",
      ".apf-stat{background:var(--surface);border:1px solid var(--line);border-radius:13px;padding:15px 12px;text-align:center;box-shadow:var(--shadow-xs);}",
      ".apf-stat .l{font-size:12px;font-weight:600;color:var(--ink-3);margin-bottom:9px;}",
      ".apf-stat .v{display:flex;align-items:center;justify-content:center;gap:7px;font-size:23px;font-weight:800;color:var(--eva-green-deep);letter-spacing:-.02em;line-height:1;}",
      ".apf-stat .v svg{width:17px;height:17px;color:var(--eva-green);}",
      ".apf-tl{padding:4px 16px 12px;}",
      ".apf-tlrow{display:flex;justify-content:space-between;align-items:center;gap:12px;padding:10px 0;border-bottom:1px solid var(--line);font-size:13.5px;}",
      ".apf-tlrow:last-child{border-bottom:none;}",
      ".apf-tlrow .k{font-weight:800;color:var(--ink);}",
      ".apf-tlrow .v{font-weight:700;color:var(--eva-green-deep);}",
      ".apf-tlrow .v.mut{color:var(--ink-4);}",
      ".apf-svc{padding:14px 16px 16px;}",
      ".apf-svlbl{font-size:12.5px;font-weight:800;color:var(--ink-2);margin-bottom:8px;}",
      ".apf-svlbl.mt{margin-top:15px;}",
      ".apf-tags{display:flex;flex-wrap:wrap;gap:7px;}",
      ".apf-tag{display:inline-block;font-size:11.5px;font-weight:700;padding:4px 10px;border-radius:7px;}",
      ".apf-tag.dep{color:#2563EB;background:#E5EEFD;border:1px solid #CFE0FB;}",
      ".apf-tag.mgr{color:var(--eva-green-deep);background:var(--accent-soft);border:1px solid var(--accent-soft-2);}",
      ".apf-appt{padding:15px 16px;}",
      ".apf-apptop{display:flex;align-items:center;gap:10px;margin-bottom:14px;}",
      ".apf-apnum{font-size:12px;font-weight:800;color:var(--ink-4);}",
      ".apf-apid{font-size:15px;font-weight:800;color:var(--ink);letter-spacing:-.01em;}",
      ".apf-apptop .apx-stpill{margin-left:auto;}",
      ".apf-apgrid{display:grid;grid-template-columns:1fr 1fr;gap:14px;}",
      ".apf-kv .k{font-size:10.5px;font-weight:800;letter-spacing:.05em;text-transform:uppercase;color:var(--ink-4);margin-bottom:4px;}",
      ".apf-kv .v{font-size:13.5px;font-weight:700;color:var(--ink);word-break:break-word;}"
    ].join("");
    document.head.appendChild(st);
  }

  /* ---------- helpers ---------- */
  function initials(name) { var p = (name || "").trim().split(/\s+/); return (((p[0] || "")[0] || "") + ((p[1] || "")[0] || "")).toUpperCase() || "?"; }
  function hm(mins) { return pad(Math.floor(mins / 60)) + ":" + pad(mins % 60); }
  function fmtDMY(isoStr) { if (!isoStr) return "\u2014"; var p = isoStr.split("-"); return p[2] + "/" + p[1] + "/" + p[0]; }
  function fmtDT(ts) { var d = new Date(ts); var hh = d.getHours(), ap = hh >= 12 ? "PM" : "AM", h12 = hh % 12 || 12; return pad(d.getDate()) + "/" + pad(d.getMonth() + 1) + "/" + d.getFullYear() + " " + h12 + ":" + pad(d.getMinutes()) + " " + ap; }
  function fmtDTlines(ts) { var d = new Date(ts); var hh = d.getHours(), ap = hh >= 12 ? "PM" : "AM", h12 = hh % 12 || 12; return pad(d.getDate()) + "/" + pad(d.getMonth() + 1) + "/" + d.getFullYear() + '<br><span class="vt">' + h12 + ":" + pad(d.getMinutes()) + " " + ap + '</span>'; }
  function nowParts() { var d = new Date(); var hh = d.getHours(), ap = hh >= 12 ? "PM" : "AM", h12 = hh % 12 || 12; return { date: pad(d.getDate()) + "/" + pad(d.getMonth() + 1) + "/" + d.getFullYear(), time: h12 + ":" + pad(d.getMinutes()) + " " + ap, ts: d.getTime() }; }

  /* friendly appointment code: A0000001 … (oldest = 1, newest = highest) */
  function ensureCodes() {
    var max = 0; AX.appts.forEach(function (a) { if (a.code) max = Math.max(max, a.code); });
    var uncoded = AX.appts.filter(function (a) { return !a.code; }).sort(function (x, y) { return (y.created || 0) - (x.created || 0); });
    if (uncoded.length) { uncoded.forEach(function (a) { a.code = ++max; }); AX.save(); }
  }
  AX.apptCode = function (a) { if (!a) return ""; if (!a.code) ensureCodes(); return "A" + String(a.code || 0).padStart(7, "0"); };

  function ensureMeta(a) {
    if (!a.notes) a.notes = [];
    if (!a.completionHistory) a.completionHistory = [];
    if (!a.rescheduleHistory) a.rescheduleHistory = [];
    if (!a.createdTs) { var base = AX.fromISO(a.date); base.setHours(9, 15, 0, 0); a.createdTs = base.getTime() - ((a.created || 0) * 60000); }
    if (!a.activity) { a.activity = [{ kind: "created", text: 'Appointment for "' + a.name + '" was created', ts: a.createdTs }]; }
  }
  function logActivity(a, kind, text) {
    ensureMeta(a);
    a.activity.unshift({ kind: kind, text: text, ts: Date.now(), meta: (arguments.length > 3 ? arguments[3] : null) });
    // cross-post onto the matching lead's timeline (keep module + lead in sync)
    try { if (window.AskEvaActivity) window.AskEvaActivity.log({ mobile: a.mobile, name: a.name }, { type: "appointment", text: text, module: "Appointments" }); } catch (e) {}
    try { if (window.AskEvaActivity) window.AskEvaActivity.log({ mobile: a.mobile, name: a.name }, { type: "appointment", text: text, module: "Appointments" }); } catch (e) {}
  }

  /* derive the user-facing status label */
  function statusInfo(a) {
    if (a.status === "completed") return { cls: "completed", txt: "Completed" };
    if (a.status === "cancelled") return { cls: "cancelled", txt: "Cancelled" };
    if (a.rescheduled) return { cls: "resched", txt: "Rescheduled" };
    return { cls: "current", txt: "Current" };
  }

  /* user-facing label for a raw status value (used in activity metadata) */
  function statusLabel(st, resched) {
    if (st === "completed") return "Completed";
    if (st === "cancelled") return "Cancelled";
    if (resched) return "Rescheduled";
    if (st === "pending") return "Pending";
    return "Confirmed";
  }

  /* ---------- detail state ---------- */
  var curId = null, detTab = "details", noteType = "Text";
  var TABS = [
    ["details", "Appointment Details", I.user],
    ["complete", "Complete", I.check],
    ["reschedule", "Reschedule", I.repeat],
    ["activity", "Activity Logs", I.clock],
    ["profile", "Profile", I.card],
    ["notes", "Notes", I.edit],
    ["feedback", "Feedback", I.msg]
  ];

  AX.openDetail = function (id) {
    var a = AX.getAppt(id); if (!a) return;
    ensureMeta(a); AX.save();
    curId = id; detTab = "details"; noteType = "Text";
    render();
    detailEl.classList.add("show");
  };

  function render() {
    var a = AX.getAppt(curId); if (!a) { detailEl.classList.remove("show"); return; }
    var code = AX.apptCode(a);
    detailEl.innerHTML =
      '<div class="ax-bar"><button class="ax-iconbtn" data-x="back" aria-label="Bookings">' + I.back + '</button>' +
        '<div class="ttl">Appointment ' + esc(code) + '</div><span class="spacer"></span></div>' +
      '<div class="apx-tabs">' + TABS.map(function (t) {
        var dis = (t[0] === "complete" && a.status === "completed");
        return '<button class="apx-tab' + (detTab === t[0] ? " on" : "") + (dis ? " apx-tab-done" : "") + '" data-t="' + t[0] + '">' + t[2] + t[1] + '</button>';
      }).join("") + '</div>' +
      '<div class="ax-scroll"><div class="apx-body" id="apxBody">' + tabContent(a) + '</div></div>';

    detailEl.querySelector('[data-x="back"]').addEventListener("click", function () { detailEl.classList.remove("show"); AX.render(); });
    // tab strip is built ONCE here; switching tabs only swaps the body so the
    // strip's horizontal scroll position (and the rest of the chrome) is kept.
    $$(".apx-tab", detailEl).forEach(function (b) { b.addEventListener("click", function () { if (b.classList.contains("apx-tab-done")) return; detTab = b.getAttribute("data-t"); setBody(); }); });
    wireTab(a);
    scrollActiveTabIntoView();
    var sc = detailEl.querySelector(".ax-scroll"); if (sc) sc.scrollTop = 0;
  }

  /* swap only the body + active-tab highlight (no full rebuild) */
  function setBody() {
    var a = AX.getAppt(curId); if (!a) { detailEl.classList.remove("show"); return; }
    var body = document.getElementById("apxBody");
    if (!body) { render(); return; }
    $$(".apx-tab", detailEl).forEach(function (b) { b.classList.toggle("on", b.getAttribute("data-t") === detTab); });
    body.innerHTML = tabContent(a);
    wireTab(a);
    scrollActiveTabIntoView();
    var sc = detailEl.querySelector(".ax-scroll"); if (sc) sc.scrollTop = 0;
  }
  function scrollActiveTabIntoView() {
    var strip = detailEl.querySelector(".apx-tabs"), act = detailEl.querySelector(".apx-tab.on");
    if (strip && act) strip.scrollLeft = Math.max(0, act.offsetLeft - 12);
  }

  function headerCard(a) {
    var dep = AX.deptById(a.department), u = AX.userById(a.user) || { name: "\u2014" };
    var si = statusInfo(a);
    return '<div class="apx-card apx-hcard">' +
      '<div class="ttl">' + I.user + esc(a.name) + '\u2019s Appointment Details</div>' +
      '<div class="apx-meta">' +
        kv("Created At", fmtDTlines(a.createdTs)) +
        kv("ID", AX.apptCode(a)) +
        kv("User", esc(u.name)) +
        kv("Department", esc(dep.name)) +
        kv("Status", '<span class="apx-stpill ' + si.cls + '">' + si.txt + '</span>') +
        kv("Description", esc(a.description || "\u2014")) +
      '</div></div>';
  }
  function kv(k, v) { return '<div' + (k === "Description" ? ' class="full"' : "") + '><div class="k">' + k + '</div><div class="v">' + v + '</div></div>'; }

  function tabContent(a) {
    switch (detTab) {
      case "details": return headerCard(a) + detailsTab(a);
      case "complete": return headerCard(a) + completeTab(a);
      case "reschedule": return headerCard(a) + rescheduleTab(a);
      case "activity": return activityTab(a);
      case "profile": return profileTab(a);
      case "notes": return notesTab(a);
      case "feedback": return feedbackTab(a);
    }
    return "";
  }

  /* =================== APPOINTMENT DETAILS =================== */
  function roField(label, val) { return '<div class="apx-field"><label><span class="req">*</span>' + label + '</label><div class="apx-ro">' + esc(val || "\u2014") + '</div></div>'; }
  function detailsTab(a) {
    var dep = AX.deptById(a.department), u = AX.userById(a.user) || { name: "\u2014" };
    var done = a.status === "completed" || a.status === "cancelled";
    return '<div class="apx-card"><div class="hd">' + I.edit + 'Appointment Details</div>' +
      '<div class="apx-two">' + roField("Name", a.name) + roField("Age", a.age) + '</div>' +
      roField("Mobile Number", a.mobile) +
      '<div class="apx-two">' + roField("Date of Birth", fmtDMY(a.dob)) + roField("Select User", u.name) + '</div>' +
      '<div class="apx-two">' + roField("Department", dep.name) + roField("Appointment Date", fmtDMY(a.date)) + '</div>' +
      '<div class="apx-two">' + roField("Appointment Timing", hm(a.time) + " - " + hm(a.time + a.dur)) + roField("Payment Type", a.paymentType === "prepaid" ? "Prepaid" : "Postpaid") + '</div>' +
      '<div class="apx-field"><label>Description</label><div class="apx-ro" style="min-height:60px">' + esc(a.description || "\u2014") + '</div></div>' +
      (done ? '' : '<div class="apx-btnrow"><button class="apx-btn ghost" data-go="edit">' + I.edit + 'Edit</button>' +
        '<button class="apx-btn amber" data-go="reschedule">' + I.repeat + 'Reschedule Appointment</button>' +
        '<button class="apx-btn green" data-go="complete">' + I.check + 'Mark as Complete</button></div>') +
    '</div>';
  }

  /* =================== COMPLETE =================== */
  function completeTab(a) {
    var done = a.status === "completed";
    var form = done
      ? '<div class="apx-empty2">This appointment is already completed.</div>'
      : '<div class="apx-field"><label><span class="req">*</span>Completion Notes/Description</label>' +
        '<textarea class="apx-ta" id="apxCompNote" maxlength="500" placeholder="Enter completion notes and details about the appointment outcome"></textarea>' +
        '<span class="apx-count" id="apxCompCount">0/500</span></div>' +
        '<div class="apx-btnrow"><button class="apx-btn ghost" data-go="details">Cancel</button>' +
        '<button class="apx-btn green" id="apxDoComplete">' + I.check + 'Mark as Complete</button></div>';
    return '<div class="apx-card"><div class="hd">' + I.check + 'Complete Appointment</div>' + form + '</div>' +
      histCard("Completion History", a.completionHistory, "No completion history available");
  }

  /* =================== RESCHEDULE =================== */
  function slotOptions(a) {
    var step = a.dur || 15, opts = "";
    for (var m = 540; m + step <= 1200; m += step) {
      opts += '<option value="' + m + '"' + (m === a.time ? " selected" : "") + '>' + hm(m) + " - " + hm(m + step) + "</option>";
    }
    return opts;
  }
  function rescheduleTab(a) {
    var done = a.status === "completed" || a.status === "cancelled";
    var form = done
      ? '<div class="apx-empty2">This appointment can no longer be rescheduled.</div>'
      : '<div class="apx-field"><label><span class="req">*</span>New Appointment Date &amp; Time</label>' +
            '<button class="apx-ro" id="apxRsDT" type="button" style="text-align:left;cursor:pointer;display:flex;align-items:center;justify-content:space-between">' +
              '<span id="apxRsDTLbl">Select date &amp; time</span>' + I.cal + '</button></div>' +
        '<div class="apx-field"><label><span class="req">*</span>Reschedule Reason/Description</label>' +
          '<textarea class="apx-ta" id="apxRsReason" maxlength="500" placeholder="Enter reason for rescheduling"></textarea>' +
          '<span class="apx-count" id="apxRsCount">0/500</span></div>' +
        '<div class="apx-btnrow"><button class="apx-btn ghost" data-go="details">Cancel</button>' +
        '<button class="apx-btn green" id="apxDoResched">' + I.repeat + 'Save Reschedule</button></div>';
    return '<div class="apx-card"><div class="hd">' + I.repeat + 'Reschedule Appointment</div>' + form + '</div>' +
      histCard("Reschedule History", a.rescheduleHistory, "No reschedule history available");
  }

  /* shared history card */
  function histCard(title, list, empty) {
    var body = (list && list.length)
      ? list.map(function (h, i) { return '<div class="apx-hrow"><span class="sn">' + (i + 1) + '</span><span class="ds">' + esc(h.desc) + '</span><span class="dt">' + esc(h.date) + '<br>' + esc(h.time) + '</span></div>'; }).join("")
      : '<div class="apx-empty2">' + empty + '</div>';
    return '<div class="apx-card apx-hist"><div class="hd">' + I.clock + title + '</div>' + body + '</div>';
  }

  /* =================== ACTIVITY LOGS =================== */
  function activityTab(a) {
    var dep = AX.deptById(a.department), u = AX.userById(a.user) || { name: "\u2014" };
    var evs = (a.activity || []).map(function (e) {
      function row(k, v) { return v ? '<div class="exp-r"><span class="k">' + k + '</span><span class="v">' + esc(v) + '</span></div>' : ""; }
      var det;
      if (e.meta && e.kind === "completed") {
        var m = e.meta;
        det = row("Completed by", m.completedBy) +
          row("Previous Status", m.prevStatus || "\u2014") +
          row("Completed at", fmtDT(e.ts)) +
          row("Department", m.dept) +
          row("Appointment", m.date && m.time ? m.date + " \u00b7 " + m.time : "") +
          (m.amount ? row("Payment", m.amount + (m.payStatus ? " \u00b7 " + m.payStatus : "")) : "") +
          row("Description", m.note);
      } else if (e.meta && e.kind === "rescheduled") {
        det = row("Rescheduled to", (e.meta.date || "") + (e.meta.time ? " \u00b7 " + e.meta.time : "")) + row("Reason", e.meta.note) + row("At", fmtDT(e.ts));
      } else if (e.meta && (e.kind === "status" || e.kind === "agent")) {
        det = row("Field", e.meta.Field || (e.kind === "agent" ? "Agent" : "Status")) +
          row("Old Value", e.meta.prevStatus || "\u2014") +
          row("Updated Value", e.meta.newStatus || "\u2014") +
          row("At", fmtDT(e.ts));
      } else {
        det = row("Department", dep.name) + row("User", u.name) +
          row("Date", fmtDMY(a.date) + " \u00b7 " + hm(a.time) + " - " + hm(a.time + a.dur)) +
          row("Status", statusInfo(a).txt);
      }
      return '<div class="ev"><div class="et">' + esc(e.text) + '</div><div class="ed">' + fmtDT(e.ts) + '</div>' +
        '<details><summary>' + I.chevR + 'View Details</summary><div class="exp">' + det + '</div></details></div>';
    }).join("");
    return '<div class="apx-card"><div class="hd">' + I.clock + 'Appointment Activity Timeline</div>' +
      '<div class="apx-tl">' + (evs || '<div class="apx-empty2">No activity yet</div>') + '</div></div>';
  }

  /* =================== PROFILE =================== */
  function profileTab(a) {
    var same = AX.appts.filter(function (x) { return x.mobile && x.mobile === a.mobile; });
    var totalVisits = same.length;
    var completed = same.filter(function (x) { return x.status === "completed"; }).length;
    var resched = same.filter(function (x) { return x.rescheduled; }).length;
    var totalNotes = same.reduce(function (s, x) { return s + ((x.notes || []).length); }, 0);
    var dates = same.map(function (x) { return x.date; }).sort();
    var firstVisit = dates[0];
    var compDates = same.filter(function (x) { return x.status === "completed"; }).map(function (x) { return x.date; }).sort();
    var lastVisit = compDates.length ? compDates[compDates.length - 1] : null;
    var deps = {}, mgrs = {};
    same.forEach(function (x) { deps[AX.deptById(x.department).name] = 1; var u = AX.userById(x.user); if (u) mgrs[u.name] = 1; });
    var u0 = AX.userById(a.user) || { name: "\u2014" };
    var si = statusInfo(a);
    return '<div class="apx-card apf-card"><div class="apf-hd">' + I.card + 'Profile Overview</div>' +
        '<div class="apf-prof"><div class="apf-av">' + I.user + '</div>' +
          '<div class="apf-pinfo"><div class="apf-nm">' + esc(a.name || "\u2014") + '</div>' +
            '<div class="apf-chips"><span class="apf-chip">' + I.phone + esc(a.mobile || "\u2014") + '</span>' +
              '<span class="apf-chip">' + I.cal + 'Age: ' + esc(a.age || "\u2014") + '</span></div></div></div></div>' +
      '<div class="apf-sechd">' + I.users + 'Visit Statistics</div>' +
      '<div class="apf-stats">' +
        statCard("Total Visits", totalVisits, I.clock) +
        statCard("Completed", completed, I.check) +
        statCard("Rescheduled", resched, I.repeat) +
        statCard("Total Notes", totalNotes, I.msg) +
      '</div>' +
      '<div class="apx-card apf-card"><div class="apf-hd sm">' + I.cal + 'Visit Timeline</div>' +
        '<div class="apf-tl">' +
          '<div class="apf-tlrow"><span class="k">First Visit</span><span class="v">' + fmtDMY(firstVisit) + '</span></div>' +
          '<div class="apf-tlrow"><span class="k">Last Visit</span><span class="v ' + (lastVisit ? "" : "mut") + '">' + (lastVisit ? fmtDMY(lastVisit) : "N/A") + '</span></div>' +
          '<div class="apf-tlrow"><span class="k">Current Visit</span><span class="v">' + fmtDMY(a.date) + '</span></div>' +
        '</div></div>' +
      '<div class="apx-card apf-card"><div class="apf-hd sm">' + I.users + 'Service Details</div>' +
        '<div class="apf-svc"><div class="apf-svlbl">Departments Visited</div>' +
          '<div class="apf-tags">' + Object.keys(deps).map(function (d) { return '<span class="apf-tag dep">' + esc(d) + '</span>'; }).join("") + '</div>' +
          '<div class="apf-svlbl mt">Managers Interacted</div>' +
          '<div class="apf-tags">' + Object.keys(mgrs).map(function (m) { return '<span class="apf-tag mgr">' + esc(m) + '</span>'; }).join("") + '</div>' +
        '</div></div>' +
      '<div class="apf-sechd">' + I.clock + 'Current Appointment Details</div>' +
      '<div class="apx-card apf-card apf-appt">' +
        '<div class="apf-apptop"><span class="apf-apnum">#1</span><span class="apf-apid">' + esc(AX.apptCode(a)) + '</span>' +
          '<span class="apx-stpill ' + si.cls + '">' + si.txt + '</span></div>' +
        '<div class="apf-apgrid">' +
          '<div class="apf-kv"><div class="k">Date</div><div class="v">' + fmtDMY(a.date) + '</div></div>' +
          '<div class="apf-kv"><div class="k">Timing</div><div class="v">' + hm(a.time) + ' \u2013 ' + hm(a.time + a.dur) + '</div></div>' +
          '<div class="apf-kv"><div class="k">Department</div><div class="v">' + esc(AX.deptById(a.department).name) + '</div></div>' +
          '<div class="apf-kv"><div class="k">Manager</div><div class="v">' + esc(u0.name) + '</div></div>' +
        '</div>' +
      '</div>';
  }
  function statCard(l, v, ic) { return '<div class="apx-stat"><div class="l">' + l + '</div><div class="v">' + ic + v + '</div></div>'; }

  /* =================== NOTES =================== */
  var NOTE_TYPES = [["Text", I.msg], ["Audio", I.phone], ["Image", I.card], ["Video", I.repeat], ["Document", I.note]];
  // upload rules per note type — accept= drives the OS file picker, VALID hard-rejects (e.g. .exe)
  var NOTE_ACCEPT = {
    Audio: ".mp3,.ogg,audio/mpeg,audio/ogg",
    Image: "image/*",
    Video: ".mp4,video/mp4",
    Document: ".csv,.doc,.docx,.xls,.xlsx,.ppt,.pptx,.pdf,.txt,text/csv,text/plain,application/pdf,application/msword,application/vnd.openxmlformats-officedocument.wordprocessingml.document,application/vnd.ms-excel,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet,application/vnd.ms-powerpoint,application/vnd.openxmlformats-officedocument.presentationml.presentation"
  };
  var NOTE_VALID = {
    Audio: /\.(mp3|ogg)$/i,
    Image: /\.(jpe?g|png|gif|webp|bmp|svg|heic|heif|tiff?|avif)$/i,
    Video: /\.(mp4)$/i,
    Document: /\.(csv|docx?|xlsx?|pptx?|pdf|txt)$/i
  };
  var NOTE_HINT = { Audio: "MP3 or OGG", Image: "JPG, PNG, GIF, WebP, SVG…", Video: "MP4", Document: "CSV, Word, Excel, PPT, PDF or TXT" };
  var noteFileName = "";   // selected upload filename for the current non-text note
  function notesTab(a) {
    var hist = (a.notes && a.notes.length)
      ? a.notes.map(function (n) {
          return '<div class="apx-note"><span class="nic">' + (typeIcon(n.type)) + '</span><div class="nb">' +
            '<div class="ntype">' + esc(n.type) + '</div><div class="nt">' + esc(n.text) + '</div>' +
            '<div class="nm">' + esc(n.date) + ' &middot; ' + esc(n.time) + '</div></div></div>';
        }).join("")
      : '<div class="apx-empty2">No notes added yet</div>';
    return '<div class="apx-card"><div class="hd">' + I.edit + 'Appointment Notes</div>' +
        '<div style="font-size:13px;font-weight:800;color:var(--ink);margin-bottom:9px">Add New Note</div>' +
        '<div style="font-size:12px;font-weight:700;color:var(--ink-2);margin-bottom:7px">Select Note Type:</div>' +
        '<div class="apx-ntypes">' + NOTE_TYPES.map(function (t) {
          return '<button class="apx-ntype' + (noteType === t[0] ? " on" : "") + '" data-nt="' + t[0] + '">' + t[1] + t[0] +
            (noteType === t[0] && t[0] !== "Text" ? '<i class="nt-x" data-ntx title="Clear selection"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="M18 6 6 18M6 6l12 12"/></svg></i>' : '') + '</button>';
        }).join("") + '</div>' +
        (noteType === "Text"
          ? '<div class="apx-field"><textarea class="apx-ta" id="apxNoteText" maxlength="200" style="min-height:90px" placeholder="Add a note about this appointment"></textarea>' +
            '<span class="apx-count" id="apxNoteCount">0/200</span></div>'
          : noteType === "Audio"
          ? (window.AskEvaAudioNote ? window.AskEvaAudioNote.blockHTML() : "")
          : '<div class="apx-field"><label class="nt-upload' + (noteFileName ? " has" : "") + '" id="apxUpWrap">' +
              '<input type="file" id="apxNoteFile" accept="' + (NOTE_ACCEPT[noteType] || "") + '" hidden>' +
              '<span class="nt-uptext" id="apxUpText">' + (noteFileName ? (typeIcon(noteType) + '<span class="fn">' + esc(noteFileName) + '</span>') : (I.note + 'Choose ' + noteType.toLowerCase() + ' file')) + '</span></label>' +
              '<div class="af-uphint">Accepted: ' + (NOTE_HINT[noteType] || "") + '</div></div>') +
        '<div class="apx-btnrow"><button class="apx-btn green" id="apxAddNote">' + I.plus + 'Add Note</button></div>' +
      '</div>' +
      '<div class="apx-card apx-hist"><div class="hd">' + I.note + 'Notes History</div>' + hist + '</div>';
  }
  function typeIcon(t) { for (var i = 0; i < NOTE_TYPES.length; i++) if (NOTE_TYPES[i][0] === t) return NOTE_TYPES[i][1]; return I.msg; }

  /* =================== FEEDBACK =================== */
  function feedbackTab(a) {
    var inner;
    if (a.rating) {
      var stars = "";
      for (var i = 1; i <= 5; i++) stars += '<svg viewBox="0 0 24 24" fill="currentColor" class="' + (i <= a.rating ? "on" : "") + '"><path d="m12 3 2.7 5.4 6 .9-4.3 4.2 1 6L12 16.9 6.6 19.5l1-6L3.3 9.3l6-.9z"/></svg>';
      var tagsHTML = (a.feedbackTags && a.feedbackTags.length)
        ? '<div class="apx-chips" style="margin:10px 0 4px">' + a.feedbackTags.map(function (t) { return '<span class="apx-chip">' + esc(t) + '</span>'; }).join("") + '</div>'
        : "";
      inner = '<div class="apx-stars">' + stars + '</div>' + tagsHTML +
        '<div style="font-size:13.5px;color:var(--ink-2);line-height:1.6">' + esc(a.feedback || "No comment provided.") + '</div>';
    } else {
      inner = '<div class="apx-fb"><span class="fic">i</span><div><div class="ft">No Feedback Found</div>' +
        '<div class="fl">No feedback responses found for:<br>&bull; <b>Appointment:</b> ' + esc(AX.apptCode(a)) +
        '<br>&bull; <b>Patient:</b> ' + esc(a.name) + '<br>&bull; <b>Mobile:</b> ' + esc(a.mobile) +
        '<br><br>Note: Feedback is matched using the mobile number registered with this appointment.</div></div></div>';
    }
    return '<div class="apx-card"><div class="hd">' + I.msg + 'Feedback' + '</div>' +
      '<div style="font-size:14px;font-weight:800;color:var(--ink);margin-bottom:3px">Feedback for ' + esc(a.name) + '</div>' +
      '<div style="font-size:12px;color:var(--ink-3);font-weight:600;margin-bottom:14px">Appointment: ' + esc(AX.apptCode(a)) + ' &middot; Mobile: ' + esc(a.mobile) + '</div>' +
      inner + '</div>';
  }

  /* =================== WIRING per tab =================== */
  function wireTab(a) {
    // generic "go to tab / edit"
    $$("[data-go]", detailEl).forEach(function (b) {
      b.addEventListener("click", function () {
        var g = b.getAttribute("data-go");
        if (g === "edit") { detailEl.classList.remove("show"); AX.openForm(a.id); return; }
        detTab = g; setBody();
      });
    });
    // completed → request payment / feedback in chat
    $$("[data-reqchat]", detailEl).forEach(function (b) {
      b.addEventListener("click", function () {
        var k = b.getAttribute("data-reqchat");
        if (AX.sendApptToChat) AX.sendApptToChat(a, k);
        else AX.toast("Chat is unavailable");
      });
    });

    if (detTab === "complete" && a.status !== "completed") {
      var cn = $("#apxCompNote", detailEl), cc = $("#apxCompCount", detailEl);
      if (cn) cn.addEventListener("input", function () { cc.textContent = cn.value.length + "/500"; });
      var cbtn = $("#apxDoComplete", detailEl);
      if (cbtn) cbtn.addEventListener("click", function () {
        var note = (cn && cn.value.trim()) || "";
        if (!note) { AX.toast("Enter completion notes"); if (cn) cn.focus(); return; }
        var np = nowParts();
        var prevLabel = statusLabel(a.status, a.rescheduled);
        var u2 = AX.userById(a.user) || { name: "\u2014" };
        var dep2 = AX.deptById(a.department) || { name: "\u2014" };
        a.status = "completed";
        if (a.paymentType === "prepaid") a.payStatus = "paid";
        a.completionHistory.unshift({ desc: note, date: np.date, time: np.time });
        a.completedTs = Date.now();
        logActivity(a, "completed", 'Appointment for "' + a.name + '" was marked complete', {
          completedBy: u2.name, prevStatus: prevLabel, newStatus: "Completed", note: note,
          dept: dep2.name, date: fmtDMY(a.date), time: hm(a.time) + " - " + hm(a.time + a.dur),
          amount: a.amount ? AX.inr(a.amount) : "", payStatus: a.amount ? AX.payLabel(a.payStatus) : ""
        });
        AX.save(); detTab = "activity"; setBody(); AX.render(); AX.toast("Marked as complete");
        if (AX.notifyCustomer) AX.notifyCustomer(a, "completion");
      });
    }

    if (detTab === "reschedule" && !(a.status === "completed" || a.status === "cancelled")) {
      var temp = { date: null, time: null };
      var dtBtn = $("#apxRsDT", detailEl), dtLbl = $("#apxRsDTLbl", detailEl);
      if (dtBtn) dtBtn.addEventListener("click", function () {
        if (!(window.AskEvaPicker && window.AskEvaPicker.dateTime)) { AX.toast("Date picker unavailable"); return; }
        var baseDate = temp.date || a.date;
        var baseMin = (temp.time != null) ? temp.time : a.time;
        var hh = String(Math.floor(baseMin / 60)).padStart(2, "0"), mm = String(baseMin % 60).padStart(2, "0");
        window.AskEvaPicker.dateTime({ value: baseDate + "T" + hh + ":" + mm, minToday: true, onPick: function (p) {
          temp.date = p.date;
          var t = (p.time || "").split(":");
          temp.time = (parseInt(t[0], 10) || 0) * 60 + (parseInt(t[1], 10) || 0);
          dtLbl.textContent = fmtDMY(p.date) + " · " + hm(temp.time);
          dtLbl.style.color = "var(--ink)";
        } });
      });
      var rr = $("#apxRsReason", detailEl), rc = $("#apxRsCount", detailEl);
      if (rr) rr.addEventListener("input", function () { rc.textContent = rr.value.length + "/500"; });
      var rbtn = $("#apxDoResched", detailEl);
      if (rbtn) rbtn.addEventListener("click", function () {
        var reason = (rr && rr.value.trim()) || "";
        if (temp.date == null || temp.time == null) { AX.toast("Pick a new date & time"); return; }
        if (!reason) { AX.toast("Enter a reschedule reason"); if (rr) rr.focus(); return; }
        var np = nowParts(), oldTxt = fmtDMY(a.date) + " " + hm(a.time);
        a.date = temp.date; a.time = temp.time; a.rescheduled = true;
        if (a.status === "cancelled" || a.status === "completed") { a.status = "pending"; if (a.payStatus !== "paid") a.payStatus = "pending"; }
        a.rescheduleHistory.unshift({ desc: reason + " (from " + oldTxt + " to " + fmtDMY(a.date) + " " + hm(a.time) + ")", date: np.date, time: np.time });
        logActivity(a, "rescheduled", 'Appointment for "' + a.name + '" was rescheduled to ' + fmtDMY(a.date) + ", " + hm(a.time));
        AX.state.day = a.date;
        AX.save(); detTab = "details"; setBody(); AX.render(); AX.toast("Rescheduled to " + fmtDMY(a.date) + " " + hm(a.time));
        if (AX.notifyCustomer) AX.notifyCustomer(a, "reschedule");
      });
    }

    if (detTab === "notes") {
      $$(".apx-ntype", detailEl).forEach(function (b) { b.addEventListener("click", function (e) {
        if (e.target.closest("[data-ntx]")) { noteType = "Text"; noteFileName = ""; if (window.AskEvaAudioNote) window.AskEvaAudioNote.clear(); setBody(); return; }
        noteType = b.getAttribute("data-nt"); noteFileName = ""; if (window.AskEvaAudioNote) window.AskEvaAudioNote.clear(); setBody();
      }); });
      var nt = $("#apxNoteText", detailEl), ncount = $("#apxNoteCount", detailEl);
      if (nt) nt.addEventListener("input", function () { ncount.textContent = nt.value.length + "/200"; });
      if (noteType === "Audio" && window.AskEvaAudioNote) window.AskEvaAudioNote.wire(detailEl, { toast: AX.toast });
      var nFile = $("#apxNoteFile", detailEl);
      if (nFile) nFile.addEventListener("change", function () {
        var f = this.files && this.files[0]; if (!f) return;
        var rule = NOTE_VALID[noteType];
        if (rule && !rule.test(f.name)) {
          this.value = ""; noteFileName = "";
          $("#apxUpText", detailEl).innerHTML = I.note + 'Choose ' + noteType.toLowerCase() + ' file';
          $("#apxUpWrap", detailEl).classList.remove("has");
          AX.toast("Unsupported file \u2014 accepted: " + (NOTE_HINT[noteType] || ""));
          return;
        }
        noteFileName = f.name;
        $("#apxUpText", detailEl).innerHTML = typeIcon(noteType) + '<span class="fn">' + esc(f.name) + '</span>';
        $("#apxUpWrap", detailEl).classList.add("has");
      });
      var addBtn = $("#apxAddNote", detailEl);
      if (addBtn) addBtn.addEventListener("click", function () {
        var np = nowParts(), txt;
        if (noteType === "Text") {
          txt = (nt && nt.value.trim()) || "";
          if (!txt) { AX.toast("Enter a note"); if (nt) nt.focus(); return; }
        } else if (noteType === "Audio") {
          var r = window.AskEvaAudioNote && window.AskEvaAudioNote.result();
          if (!r) { AX.toast("Record or choose an audio file"); return; }
          txt = r.name;
        } else {
          if (!noteFileName) { AX.toast("Choose a " + noteType.toLowerCase() + " file"); return; }
          txt = noteFileName;
        }
        a.notes.unshift({ type: noteType, text: txt, date: np.date, time: np.time });
        logActivity(a, "note", noteType + " note added");
        noteFileName = ""; if (window.AskEvaAudioNote) window.AskEvaAudioNote.clear();
        AX.save(); setBody(); AX.toast("Note added");
      });
    }
  }

  /* make sure codes exist up-front so the list shows them immediately */
  ensureCodes();

})(window.AX);
