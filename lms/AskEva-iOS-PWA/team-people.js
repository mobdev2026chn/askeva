/* =========================================================
   AskEva — Team Members (Settings → Team)
   PASS 2: Team is now a VIEW over the Agents store
   (window.AskEvaPeople) — the single source of truth for
   people. Renders #memList from the store, writes back
   through it, and re-renders whenever people:changed fires
   (so Agents-tab edits reflect here instantly, and vice-versa).

   It also strips the shell's old DOM-only Team handlers by
   replacing their nodes with clones (removes stale listeners).
   ========================================================= */
(function () {
  "use strict";
  var $ = function (s, r) { return (r || document).querySelector(s); };
  var $$ = function (s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); };
  function esc(s) { return String(s == null ? "" : s).replace(/[&<>"]/g, function (c) { return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]; }); }
  function toast(m) {
    var t = document.getElementById("toast"); if (!t) return;
    t.textContent = m; t.style.opacity = "1"; t.style.transform = "translateX(-50%) translateY(0)";
    clearTimeout(t.__tt); t.__tt = setTimeout(function () { t.style.opacity = "0"; t.style.transform = "translateX(-50%) translateY(20px)"; }, 1900);
  }
  /* replace a node with a clone to strip any previously-attached listeners */
  function fresh(id) { var el = document.getElementById(id); if (!el) return null; var c = el.cloneNode(true); el.parentNode.replaceChild(c, el); return c; }

  var AV_COLORS = ["#2BA84A", "#22B0E8", "#7C5CFF", "#E5499A", "#FF9416", "#1E7FB0", "#E0541F", "#3BA4DD"];
  var MOD_LBL = { chat: "Chat", leads: "Leads", appt: "Appt", ticket: "Tickets" };

  var tries = 0;
  function start() {
    var P = window.AskEvaPeople;
    var memList = document.getElementById("memList");
    if (!P || !memList) { if (++tries < 50) setTimeout(start, 60); return; }

    var deptFilter = "all", query = "";

    function roleClass(role) { var r = (role || "").toLowerCase(); return r.indexOf("super") > -1 ? "super" : r.indexOf("admin") > -1 ? "admin" : "agent"; }

    /* ---- department chips + invite-form dept options ---- */
    function renderDepts() {
      var row = document.getElementById("deptRow"); if (!row) return;
      var ds = P.departments();
      row.innerHTML =
        '<button class="f-chip' + (deptFilter === "all" ? " on" : "") + '" data-dept="all">All</button>' +
        ds.map(function (d) { return '<button class="f-chip' + (deptFilter === d ? " on" : "") + '" data-dept="' + esc(d) + '">' + esc(d) + '</button>'; }).join("") +
        '<button class="dept-new" id="deptNewBtn">+ Department</button>';
      var sel = document.getElementById("invDept");
      if (sel) {
        var cur = sel.value;
        sel.innerHTML = ds.map(function (d) { return '<option>' + esc(d) + '</option>'; }).join("");
        if (cur && ds.indexOf(cur) > -1) sel.value = cur;
      }
    }

    function memCard(a, i) {
      var dept = a.dept || "Unassigned";
      var modsHtml = (a.mods && a.mods.length >= 4) ? '<span class="mem-mod all">All modules</span>'
        : (a.mods && a.mods.length ? a.mods.map(function (m) { return '<span class="mem-mod">' + esc(MOD_LBL[m] || m) + '</span>'; }).join("") : '<span class="mem-mod">—</span>');
      var color = AV_COLORS[i % AV_COLORS.length];
      return '<div class="mem" data-id="' + esc(a.id) + '" data-dept="' + esc(dept) + '">' +
        '<div class="mem-top"><div class="mem-av" style="background:' + color + '">' + esc((a.name || "?").charAt(0).toUpperCase()) + '</div>' +
        '<div class="mem-id"><div class="row1"><span class="nm">' + esc(a.name) + '</span><span class="mem-role ' + roleClass(a.role) + '">' + esc(a.role || "Agent") + '</span></div>' +
        '<div class="mem-you">' + esc(dept) + '</div></div>' +
        '<button class="mem-view" data-mem-view="' + esc(a.id) + '" aria-label="View details"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7-10-7-10-7Z"/><circle cx="12" cy="12" r="3"/></svg></button></div>' +
        '<div class="mem-contact"><div class="ln"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="5" width="18" height="14" rx="2"/><path d="m4 7 8 5 8-5"/></svg>' + esc(a.email) + '</div></div>' +
        '<div class="mem-foot"><div class="mem-mods">' + modsHtml + '</div>' +
          '<div class="swrap"><span class="l">' + (a.on ? "Active" : "Inactive") + '</span>' +
          '<button class="set-switch' + (a.on ? " on" : "") + '" data-mem-tgl="' + esc(a.id) + '" aria-label="Toggle active"></button></div></div></div>';
    }

    function render() {
      var people = P.list();
      var rows = people.filter(function (a) {
        var okD = (deptFilter === "all") || ((a.dept || "Unassigned") === deptFilter);
        var okQ = !query || (a.name + " " + a.email + " " + (a.role || "") + " " + (a.dept || "")).toLowerCase().indexOf(query) > -1;
        return okD && okQ;
      });
      memList.innerHTML = rows.length
        ? rows.map(memCard).join("")
        : '<div style="text-align:center;color:var(--ink-4);padding:26px 0;font-weight:600;">No members match</div>';
      var active = people.filter(function (a) { return a.on; }).length;
      var c = document.getElementById("memCount");
      if (c) c.textContent = people.length + " total \u00b7 " + active + " active";
    }

    function rerender() { renderDepts(); render(); }

    /* ---- member details bottom-sheet (the eye button) ---- */
    function ensureDetailUI() {
      if (document.getElementById("memdScrim")) return;
      if (!document.getElementById("memdStyles")) {
        var st = document.createElement("style"); st.id = "memdStyles";
        st.textContent =
          ".memd-scrim{position:fixed;inset:0;z-index:1400;background:rgba(15,30,18,.45);display:flex;align-items:flex-end;justify-content:center;opacity:0;pointer-events:none;transition:opacity .22s ease;}" +
          ".memd-scrim.show{opacity:1;pointer-events:auto;}" +
          ".memd-sheet{width:100%;max-width:520px;background:var(--surface,#fff);border-radius:24px 24px 0 0;padding:10px 18px 26px;box-shadow:0 -10px 40px rgba(0,0,0,.22);transform:translateY(18px);transition:transform .26s cubic-bezier(.2,.8,.2,1);position:relative;}" +
          ".memd-scrim.show .memd-sheet{transform:none;}" +
          ".memd-grab{width:40px;height:4px;border-radius:999px;background:var(--line,#e6e9e4);margin:2px auto 6px;}" +
          ".memd-x{position:absolute;top:14px;right:14px;width:32px;height:32px;border:none;background:var(--surface-2,#f3f5f1);border-radius:50%;color:var(--ink-3,#8a978d);font-size:20px;line-height:1;cursor:pointer;}" +
          ".memd-hero{display:flex;flex-direction:column;align-items:center;text-align:center;padding:8px 0 16px;border-bottom:1px solid var(--line,#eef1ec);}" +
          ".memd-av{width:68px;height:68px;border-radius:20px;display:grid;place-items:center;font-size:27px;font-weight:800;color:#fff;box-shadow:0 6px 16px rgba(0,0,0,.18);}" +
          ".memd-name{font-size:20px;font-weight:800;color:var(--ink,#15231a);letter-spacing:-.01em;margin-top:12px;}" +
          ".memd-badges{display:flex;align-items:center;gap:8px;margin-top:9px;}" +
          ".memd-status{display:inline-flex;align-items:center;gap:6px;font-size:11.5px;font-weight:700;color:var(--ink-3,#8a978d);}" +
          ".memd-status .dot{width:8px;height:8px;border-radius:50%;background:var(--ink-4,#aab2a5);}" +
          ".memd-status.on .dot{background:var(--eva-green,#3CC23F);box-shadow:0 0 0 3px rgba(60,194,63,.18);}" +
          ".memd-status.on{color:var(--eva-green-deep,#177A36);}" +
          ".memd-rows{margin-top:6px;}" +
          ".memd-row{display:flex;align-items:flex-start;justify-content:space-between;gap:16px;padding:13px 2px;border-bottom:1px solid var(--line,#eef1ec);}" +
          ".memd-row:last-child{border-bottom:none;}" +
          ".memd-row .k{font-size:12px;font-weight:700;letter-spacing:.04em;text-transform:uppercase;color:var(--ink-4,#aab2a5);flex:0 0 auto;}" +
          ".memd-row .v{font-size:14px;font-weight:700;color:var(--ink,#15231a);text-align:right;word-break:break-word;}" +
          ".memd-row.col{flex-direction:column;align-items:flex-start;gap:9px;}" +
          ".memd-mods{display:flex;gap:6px;flex-wrap:wrap;}" +
          ".mem-view{flex:0 0 auto;width:34px;height:34px;border-radius:10px;border:1px solid var(--line,#eef1ec);background:#fff;color:var(--accent-deep,#177A36);display:grid;place-items:center;cursor:pointer;transition:background .15s;}" +
          ".mem-view:active{background:var(--surface-2,#f3f5f1);}" +
          ".mem-view svg{width:18px;height:18px;}";
        document.head.appendChild(st);
      }
      var scrim = document.createElement("div");
      scrim.className = "memd-scrim"; scrim.id = "memdScrim";
      scrim.innerHTML = '<div class="memd-sheet" role="dialog" aria-modal="true"><div class="memd-grab"></div>' +
        '<button class="memd-x" id="memdClose" aria-label="Close">\u00d7</button><div id="memdBody"></div></div>';
      document.body.appendChild(scrim);
      scrim.addEventListener("click", function (e) { if (e.target === scrim || e.target.id === "memdClose") closeMemberDetail(); });
    }
    function closeMemberDetail() { var s = document.getElementById("memdScrim"); if (s) s.classList.remove("show"); }
    function openMemberDetail(id) {
      var a = P.get(id); if (!a) return;
      var e = (P.byId && P.byId(id)) || {};
      ensureDetailUI();
      var dept = a.dept || "Unassigned";
      var mobile = a.mobile ? ("+" + String(a.mobile).replace(/^\+/, "")) : "—";
      var mods = a.mods || [];
      var modsHtml = (mods.length >= 4) ? '<span class="mem-mod all">All modules</span>'
        : (mods.length ? mods.map(function (m) { return '<span class="mem-mod">' + esc(MOD_LBL[m] || m) + '</span>'; }).join("")
        : '<span class="mem-mod">No modules</span>');
      var body = document.getElementById("memdBody");
      body.innerHTML =
        '<div class="memd-hero">' +
          '<div class="memd-av" style="background:' + (e.color || "var(--eva-gradient)") + '">' + esc(e.initials || (a.name || "?").charAt(0).toUpperCase()) + '</div>' +
          '<div class="memd-name">' + esc(a.name) + (a.id === "eshan" ? ' <span style="font-weight:700;color:var(--ink-4);font-size:13px;">(You)</span>' : "") + '</div>' +
          '<div class="memd-badges"><span class="mem-role ' + roleClass(a.role) + '">' + esc(a.role || "Agent") + '</span>' +
            '<span class="memd-status' + (a.on ? " on" : "") + '"><span class="dot"></span>' + (a.on ? "Active" : "Inactive") + '</span></div>' +
        '</div>' +
        '<div class="memd-rows">' +
          '<div class="memd-row"><span class="k">Email</span><span class="v">' + esc(a.email || "—") + '</span></div>' +
          '<div class="memd-row"><span class="k">Mobile</span><span class="v">' + esc(mobile) + '</span></div>' +
          '<div class="memd-row"><span class="k">Department</span><span class="v">' + esc(dept) + '</span></div>' +
          '<div class="memd-row col"><span class="k">Module access</span><div class="memd-mods">' + modsHtml + '</div></div>' +
        '</div>';
      var s = document.getElementById("memdScrim");
      requestAnimationFrame(function () { s.classList.add("show"); });
    }

    /* ---- strip old shell listeners, then bind ours ---- */
    var teamSearch = fresh("teamSearch");
    if (teamSearch) teamSearch.addEventListener("input", function () { query = this.value.trim().toLowerCase(); render(); });

    var deptRow = fresh("deptRow");
    if (deptRow) deptRow.addEventListener("click", function (e) {
      if (e.target.closest("#deptNewBtn")) {
        var f = document.getElementById("deptForm");
        if (f) { f.hidden = !f.hidden; var di = document.getElementById("deptInput"); if (!f.hidden && di) di.focus(); }
        return;
      }
      var chip = e.target.closest(".f-chip"); if (!chip) return;
      deptFilter = chip.getAttribute("data-dept");
      $$(".f-chip", deptRow).forEach(function (x) { x.classList.toggle("on", x === chip); });
      render();
    });

    function addDept() {
      var di = document.getElementById("deptInput"), f = document.getElementById("deptForm");
      var name = (di && di.value || "").trim(); if (!name) { if (di) di.focus(); return; }
      var ok = P.addDept(name);
      if (di) di.value = ""; if (f) f.hidden = true;
      toast(ok ? 'Department \u201c' + name + '\u201d created' : "That department already exists");
    }
    var deptAdd = fresh("deptAdd"); if (deptAdd) deptAdd.addEventListener("click", addDept);
    var deptInput = fresh("deptInput"); if (deptInput) deptInput.addEventListener("keydown", function (e) { if (e.key === "Enter") addDept(); });

    /* toggle a member's active status (delegated) */
    memList.addEventListener("click", function (e) {
      var t = e.target.closest("[data-mem-tgl]"); if (!t) return;
      e.stopPropagation();
      var on = P.setActive(t.getAttribute("data-mem-tgl"));   // fires people:changed -> rerender
      var a = P.get(t.getAttribute("data-mem-tgl"));
      if (a) toast(a.name + (on ? " activated" : " deactivated"));
    });

    /* view a member's full details (eye button, delegated) */
    memList.addEventListener("click", function (e) {
      var v = e.target.closest("[data-mem-view]"); if (!v) return;
      e.stopPropagation();
      openMemberDetail(v.getAttribute("data-mem-view"));
    });

    /* invite member -> writes into the Agents store */
    var inviteForm = document.getElementById("inviteForm");
    function toggleInvite(show) {
      if (!inviteForm) return;
      inviteForm.hidden = (show === undefined) ? !inviteForm.hidden : !show;
      if (!inviteForm.hidden) { renderDepts(); var n = document.getElementById("invName"); if (n) n.focus(); }
    }
    ["inviteBtn", "teamInviteIcon"].forEach(function (id) { var b = fresh(id); if (b) b.addEventListener("click", function () { toggleInvite(); }); });
    var invCancel = fresh("invCancel"); if (invCancel) invCancel.addEventListener("click", function () { toggleInvite(false); });
    var invSave = fresh("invSave");
    if (invSave) invSave.addEventListener("click", function () {
      var nameEl = document.getElementById("invName"), emailEl = document.getElementById("invEmail");
      var name = (nameEl.value || "").trim(), email = (emailEl.value || "").trim();
      var role = document.getElementById("invRole").value, dept = document.getElementById("invDept").value;
      if (!name) { nameEl.focus(); return; }
      if (!/\S+@\S+\.\S+/.test(email)) { emailEl.focus(); toast("Enter a valid email"); return; }
      P.add({ name: name, email: email, role: role, dept: dept });   // fires people:changed -> rerender
      nameEl.value = ""; emailEl.value = "";
      toggleInvite(false);
      toast(name + " added to " + dept);
    });

    /* two-way sync: any change to the store re-renders Team */
    P.on(rerender);
    rerender();
  }

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", start);
  else start();
})();
