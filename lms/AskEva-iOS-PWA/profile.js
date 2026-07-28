/* =========================================================
   AskEva — Profile Details interactions (vanilla JS)
   ========================================================= */
(function () {
  "use strict";

  const $ = (s, r) => (r || document).querySelector(s);
  const $$ = (s, r) => Array.from((r || document).querySelectorAll(s));
  const INR = (n) => "₹" + n.toLocaleString("en-IN", { minimumFractionDigits: 2, maximumFractionDigits: 2 });

  /* ---------- persistence layer (per-contact, survives refresh) ---------- */
  var CID = "";   // current chat contact id — namespaces ALL profile data so each chat is independent
  function pkey(k) { return "askeva.profile." + (CID ? CID + "." : "") + k; }
  function pLoad(k, d) { try { var v = JSON.parse(localStorage.getItem(pkey(k))); return v == null ? d : v; } catch (e) { return d; } }
  function pSave(k, v) { try { localStorage.setItem(pkey(k), JSON.stringify(v)); } catch (e) {} }
  function currentContact() { try { return (window.__chat && window.__chat.current) ? window.__chat.current() : null; } catch (e) { return null; } }
  function deriveInit(name) { var p = (name || "").trim().split(/\s+/); var s = ((p[0] || "")[0] || "") + ((p[1] || "")[0] || ""); return (s || (name || "?").slice(0, 2) || "?").toUpperCase(); }
  /* find a matching record in Leads so an existing contact's details sync in */
  function leadFor(c) {
    if (!c || !window.AskEvaLeads) return null;
    var ph = (c.phone || "").replace(/\D/g, ""), nm = (c.name || "").trim().toLowerCase();
    for (var i = 0; i < window.AskEvaLeads.length; i++) {
      var L = window.AskEvaLeads[i], lp = (L.mobile || "").replace(/\D/g, "");
      if (ph && lp && (lp === ph || lp.slice(-10) === ph.slice(-10))) return L;
      if (nm && (L.name || "").trim().toLowerCase() === nm) return L;
    }
    return null;
  }
  function leadAgentName(email) {
    if (!email) return "";
    if (window.AskEvaPeople && AskEvaPeople.roster) { var r = AskEvaPeople.roster("chat"); for (var i = 0; i < r.length; i++) if ((r[i].email || "") === email) return r[i].name; }
    return "";
  }
  function syncIdentity(c) {
    if (!c) return;
    var av = $(".hero .avatar"); if (av) { av.innerHTML = deriveInit(c.name) + '<span class="pres"></span>'; if (c.grad) av.style.background = "var(--eva-gradient)"; else if (c.color) av.style.background = c.color; }
    var nm = $(".hero .name"); if (nm) nm.textContent = c.name || "New contact";
    var ph = $("#copyPhone span"); if (ph) ph.textContent = c.phone ? (String(c.phone).charAt(0) === "+" ? c.phone : "+" + c.phone) : "\u2014";
  }

  /* ---------- Stage scaling ---------- */
  function fitStage() {
    const device = $(".device");
    if (!device) return;
    const pad = 24;
    const sx = (window.innerWidth - pad) / device.offsetWidth;
    const sy = (window.innerHeight - pad) / device.offsetHeight;
    const scale = Math.min(sx, sy, 1);
    device.style.transformOrigin = "center center";
    device.style.transform = "scale(" + scale + ")";
  }
  // Debounced + keyboard-aware: ignore height-only shrinks while typing (soft keyboard
  // opening lowers innerHeight and fires resize), and prefer visualViewport so focusing
  // an input doesn't visibly rescale the whole device.
  var _fitT, _lastW = window.innerWidth, _lastH = window.innerHeight;
  function onViewportChange() {
    var w = window.innerWidth, h = window.innerHeight;
    var ae = document.activeElement;
    var typing = ae && (ae.tagName === "INPUT" || ae.tagName === "TEXTAREA" || ae.isContentEditable);
    if (typing && w === _lastW && h < _lastH) { _lastH = h; return; }   // soft keyboard → skip re-fit
    _lastW = w; _lastH = h;
    clearTimeout(_fitT);
    _fitT = setTimeout(fitStage, 80);
  }
  window.addEventListener("resize", onViewportChange);
  if (window.visualViewport) window.visualViewport.addEventListener("resize", onViewportChange);

  /* ---------- Toast ---------- */
  let toastT;
  function toast(msg) {
    const t = $("#toast");
    t.textContent = msg;
    t.style.opacity = "1";
    t.style.transform = "translateX(-50%) translateY(0)";
    clearTimeout(toastT);
    toastT = setTimeout(() => {
      t.style.opacity = "0";
      t.style.transform = "translateX(-50%) translateY(20px)";
    }, 1900);
  }

  /* ---------- Drawer ---------- */
  const drawer = $("#drawer");
  const scrim = $("#scrim");
  function openDrawer() {
    var c = currentContact();
    if (c) { CID = c.id || "default"; syncIdentity(c); hydrate(c); }
    drawer.classList.remove("closed"); scrim.classList.add("show");
  }
  function closeDrawer() { drawer.classList.add("closed"); scrim.classList.remove("show"); }
  $("#closeBtn").addEventListener("click", closeDrawer);
  $("#scrim").addEventListener("click", closeDrawer);
  window.__drawer = { open: openDrawer, close: closeDrawer };

  /* ---------- Accordion ---------- */
  $$(".section .sec-head").forEach((head) => {
    head.addEventListener("click", () => {
      head.closest(".section").classList.toggle("open");
    });
  });

  /* ---------- Copy phone ---------- */
  $("#copyPhone").addEventListener("click", () => {
    const num = (($("#copyPhone span") || {}).textContent || "").trim();
    if (navigator.clipboard && num) navigator.clipboard.writeText(num).catch(() => {});
    toast("Phone number copied");
  });

  /* ---------- Call (reuse the full-screen Leads call screen) ---------- */
  var callQa = $(".quick-actions .qa");
  if (callQa) callQa.addEventListener("click", function () {
    var nm = ($(".hero .name") || {}).textContent || "Contact";
    var ph = (($("#copyPhone span") || {}).textContent || "").replace(/[^\d]/g, "");
    if (window.__callScreen) window.__callScreen({ name: nm.trim(), mobile: ph });
    else toast("Calling " + nm.trim() + "\u2026");
  });

  /* ---------- Mute toggle (reflect beside the chat name) ---------- */
  let muted = pLoad("muted", false);
  function applyMute() { var mq = $("#muteQa"); if (!mq) return; mq.querySelector(".qa-lbl").textContent = muted ? "Muted" : "Mute"; mq.style.background = muted ? "var(--accent-soft)" : ""; }
  applyMute();
  $("#muteQa").addEventListener("click", function () {
    muted = !muted;
    this.querySelector(".qa-lbl").textContent = muted ? "Muted" : "Mute";
    this.style.background = muted ? "var(--accent-soft)" : "";
    pSave("muted", muted);
    if (window.__chat && window.__chat.setMuted) window.__chat.setMuted(muted);
    toast(muted ? "Notifications muted" : "Notifications on");
  });

  /* ---------- Lead status (Add to Leads → Active Lead → Customer) ---------- */
  const leadStatusWrap = $("#leadStatusWrap");
  var LS_META = { addlead: { cls: "addlead", label: "Add to Leads" }, active: { cls: "active", label: "Active Lead" }, customer: { cls: "customer", label: "Customer" } };
  function curStatus() { return (window.__chat && window.__chat.getLeadStatus) ? (window.__chat.getLeadStatus(currentContact()) || "active") : "active"; }
  function renderLeadStatus() {
    if (!leadStatusWrap) return;
    var st = curStatus(), meta = LS_META[st] || LS_META.active;
    var html = '<span class="ls-badge ' + meta.cls + '"><span class="d"></span>' + meta.label + '</span>';
    if (st === "addlead") html += '<button class="ls-action alt" id="lsAdd"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M19 8v6M22 11h-6"/></svg>Add to Leads</button>';
    leadStatusWrap.innerHTML = html;
    var add = $("#lsAdd", leadStatusWrap); if (add) add.addEventListener("click", function () { if (window.__chat && window.__chat.addToLeads) window.__chat.addToLeads(currentContact()); renderLeadStatus(); });
    var sync = $("#lsSync", leadStatusWrap); if (sync) sync.addEventListener("click", function () { if (window.__chat && window.__chat.syncToCustomer) window.__chat.syncToCustomer(currentContact()); renderLeadStatus(); });
  }
  renderLeadStatus();
  window.__profileLeadStatus = function () { try { renderLeadStatus(); } catch (e) {} };

  /* ---------- Groups (synced with Contacts → Groups) ---------- */
  function cApi() { return window.AskEvaContactsAPI || null; }
  function contactGroupNames() { var a = cApi(); return a ? a.groups().map(function (g) { return g.name; }) : []; }
  function savedContactFor(c) { var a = cApi(); if (!a || !c) return null; var ph = (c.phone || "").replace(/\D/g, ""); if (!ph) return null; return a.list().filter(function (x) { var m = (x.mobile || "").replace(/\D/g, ""); return m && (m === ph || m.slice(-10) === ph.slice(-10)); })[0] || null; }
  function groupsForContact(c) { var a = cApi(); var sc = savedContactFor(c); if (!a || !sc) return []; var byId = {}; a.groups().forEach(function (g) { byId[g.id] = g.name; }); return (sc.groups || []).map(function (id) { return byId[id]; }).filter(Boolean); }
  function groupInitials(n) { var p = n.trim().split(/\s+/); return (p.length === 1 ? p[0].slice(0, 2) : p.map(function (w) { return w[0]; }).join("").slice(0, 2)).toUpperCase(); }
  function renderGroups() {
    const row = $(".group-row"); if (!row) return;
    const addBtn = $("#addGroup");
    $$(".group-chip", row).forEach(function (c) { c.remove(); });
    groupsForContact(currentContact()).forEach(function (g) {
      const chip = document.createElement("span");
      chip.className = "group-chip"; chip.title = g; chip.textContent = groupInitials(g);
      row.insertBefore(chip, addBtn);
    });
  }
  renderGroups();
  $("#addGroup").addEventListener("click", () => {
    var c = currentContact(); if (!c) { toast("Open a chat first"); return; }
    var have = groupsForContact(c).map(function (g) { return g.toLowerCase(); });
    const avail = contactGroupNames().filter(function (g) { return have.indexOf(g.toLowerCase()) < 0; });
    if (!avail.length) { toast(contactGroupNames().length ? "Already in every group" : "No groups yet — create one in Contacts"); return; }
    const host = document.querySelector(".device-screen") || document.body;
    const scrim = document.createElement("div"); scrim.className = "pf-sheetscrim";
    const sheet = document.createElement("div"); sheet.className = "pf-groupsheet";
    sheet.innerHTML = '<div class="gs-grip"></div><div class="gs-ttl">Add to group</div>' +
      avail.map(function (g) { return '<button class="gs-opt" data-g="' + escapeHtml(g) + '">' + escapeHtml(g) + '</button>'; }).join("");
    host.appendChild(scrim); host.appendChild(sheet);
    requestAnimationFrame(function () { scrim.classList.add("show"); sheet.classList.add("show"); });
    function close() { scrim.classList.remove("show"); sheet.classList.remove("show"); setTimeout(function () { scrim.remove(); sheet.remove(); }, 240); }
    scrim.addEventListener("click", close);
    $$(".gs-opt", sheet).forEach(function (b) { b.addEventListener("click", function () {
      var g = b.getAttribute("data-g"); var a = cApi();
      if (a && a.add) a.add({ mobile: c.phone, name: c.name, group: g });
      renderGroups(); close(); toast("Added to " + g);
    }); });
  });

  /* ---------- Add group (legacy id kept above) ---------- */

  /* ---------- shared per-conversation stores (tags + agents live in chat.js) ---------- */
  function getTagsStore() { if (window.__chat && window.__chat.getTags) return window.__chat.getTags(currentContact()); return pLoad("tags", []); }
  function saveTagsStore() { if (window.__chat && window.__chat.setTags) window.__chat.setTags(currentContact(), tags); else pSave("tags", tags); }

  /* ---------- Assigned agents (multiple · per conversation) ---------- */
  const agentSel = $("#agentSelect");
  const agentBox = $("#agentAssigned");
  if (agentSel) agentSel.style.display = "none";   // replaced by multi-agent chips
  const AG_PALETTE = ["#2BA84A", "#7C5CFF", "#FF9416", "#1E7FB0", "#E5499A", "#22B0E8", "#FF6B6B", "#5B7CFF"];
  function agInitials(n) { var p = (n || "").trim().split(/\s+/); return ((((p[0] || "")[0]) || "") + (((p[1] || "")[0]) || "")).toUpperCase() || (n || "?").slice(0, 2).toUpperCase(); }
  function agColor(n) { var h = 0; for (var i = 0; i < (n || "").length; i++) h = (h * 31 + n.charCodeAt(i)) >>> 0; return AG_PALETTE[h % AG_PALETTE.length]; }
  /* roster comes from the shared people store (Settings \u2192 Team) */
  function agentRoster() {
    if (window.AskEvaPeople && AskEvaPeople.roster) {
      var r = AskEvaPeople.roster("chat");
      if (r && r.length) return r.map(function (a) { return { name: a.name, role: a.role || "Agent" }; });
    }
    return [{ name: "Madhan", role: "Agent" }, { name: "Eshan Rao", role: "Admin" }, { name: "Kavya S", role: "Agent" }, { name: "Dev Patel", role: "Agent" }];
  }
  function getAssigned() {
    if (window.__chat && window.__chat.getAgents) return window.__chat.getAgents(currentContact());
    var single = pLoad("agent", ""); return single ? [single] : [];
  }
  function setAssigned(arr) {
    if (window.__chat && window.__chat.setAgents) window.__chat.setAgents(currentContact(), arr);
    else pSave("agent", arr[0] || "");
  }
  function renderAgents() {
    if (!agentBox) return;
    var assigned = getAssigned();
    var chips = assigned.map(function (n) {
      return '<span class="agent-chip"><span class="ac-av" style="background:' + agColor(n) + '">' + escapeHtml(agInitials(n)) + '</span><span class="ac-nm">' + escapeHtml(n) + '</span><span class="ac-x" data-rmagent="' + escapeHtml(n) + '"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><path d="M18 6L6 18M6 6l12 12"/></svg></span></span>';
    }).join("");
    agentBox.innerHTML = '<div class="agent-chips">' + chips +
      '<button class="agent-add" id="addAgentBtn"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><path d="M12 5v14M5 12h14"/></svg>Add agent</button></div>' +
      (assigned.length ? "" : '<div class="agent-empty">No agents assigned yet.</div>');
    var add = $("#addAgentBtn", agentBox); if (add) add.addEventListener("click", openAgentSheet);
    $$(".ac-x", agentBox).forEach(function (x) {
      x.addEventListener("click", function () {
        var n = x.getAttribute("data-rmagent");
        setAssigned(getAssigned().filter(function (a) { return a.toLowerCase() !== n.toLowerCase(); }));
        renderAgents(); toast("Removed " + n);
      });
    });
  }
  function openAgentSheet() {
    var assigned = getAssigned().map(function (a) { return a.toLowerCase(); });
    var avail = agentRoster().filter(function (a) { return assigned.indexOf(a.name.toLowerCase()) < 0; });
    var host = document.querySelector(".device-screen") || document.body;
    var scrim = document.createElement("div"); scrim.className = "pf-sheetscrim";
    var sheet = document.createElement("div"); sheet.className = "pf-groupsheet";
    sheet.innerHTML = '<div class="gs-grip"></div><div class="gs-ttl">Assign an agent</div>' +
      (avail.length
        ? avail.map(function (a) { return '<button class="gs-opt" data-ag="' + escapeHtml(a.name) + '">' + escapeHtml(a.name) + ' \u00b7 ' + escapeHtml(a.role) + '</button>'; }).join("")
        : '<div style="text-align:center;color:var(--ink-4);font-size:13px;font-weight:600;padding:18px;">All available agents are already assigned</div>');
    host.appendChild(scrim); host.appendChild(sheet);
    requestAnimationFrame(function () { scrim.classList.add("show"); sheet.classList.add("show"); });
    function close() { scrim.classList.remove("show"); sheet.classList.remove("show"); setTimeout(function () { scrim.remove(); sheet.remove(); }, 240); }
    scrim.addEventListener("click", close);
    $$(".gs-opt", sheet).forEach(function (b) {
      b.addEventListener("click", function () {
        var n = b.getAttribute("data-ag");
        setAssigned(getAssigned().concat([n])); renderAgents(); close(); toast("Assigned to " + n);
      });
    });
  }
  renderAgents();
  if (window.AskEvaPeople && AskEvaPeople.on) AskEvaPeople.on(renderAgents);

  /* ---------- Service window timers ---------- */
  function pad2(n) { return String(n).padStart(2, "0"); }
  const timers = $$(".timer-grid").map((grid) => {
    let total =
      parseInt(grid.dataset.deadlineH, 10) * 3600 +
      parseInt(grid.dataset.deadlineM, 10) * 60 +
      parseInt(grid.dataset.deadlineS, 10);
    return { grid, total };
  });
  function tickTimers() {
    timers.forEach((t) => {
      if (t.total > 0) t.total--;
      const h = Math.floor(t.total / 3600);
      const m = Math.floor((t.total % 3600) / 60);
      const s = t.total % 60;
      $("[data-hh]", t.grid).textContent = pad2(h);
      $("[data-mm]", t.grid).textContent = pad2(m);
      $("[data-ss]", t.grid).textContent = pad2(s);
    });
  }
  var _timerInt = setInterval(tickTimers, 1000);
  document.addEventListener("visibilitychange", function () {
    if (document.hidden) { clearInterval(_timerInt); _timerInt = null; }   // pause polling when tab is hidden
    else if (!_timerInt) { tickTimers(); _timerInt = setInterval(tickTimers, 1000); }
  });

  /* ---------- Payments / invoice ---------- */
  let items = [{ name: "Double Smash Combo", price: 349, qty: 1 }];
  let seq = 1;
  const invItems = $("#invItems");

  function renderItems() {
    invItems.innerHTML = "";
    items.forEach((it, i) => {
      const card = document.createElement("div");
      card.className = "inv-item";
      const lineTotal = (it.price || 0) * (it.qty || 0);
      card.innerHTML =
        '<div class="item-head"><span>Item #' + (i + 1) + '</span>' +
          (items.length > 1 ? '<button class="del" data-del="' + i + '"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 6h18M8 6V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6"/></svg></button>' : '') +
        '</div>' +
        '<label class="field-lbl">Product name</label>' +
        '<input class="input" data-f="name" data-i="' + i + '" maxlength="72" placeholder="Enter product name" value="' + escapeHtml(it.name) + '">' +
        '<div class="pq-row">' +
          '<div><label class="field-lbl">Price (₹)</label><input class="input" type="number" min="0" step="0.01" data-f="price" data-i="' + i + '" value="' + it.price + '"></div>' +
          '<div><label class="field-lbl">Qty</label><input class="input" type="number" min="1" step="1" data-f="qty" data-i="' + i + '" value="' + it.qty + '"></div>' +
        '</div>' +
        '<div class="item-total"><span class="lbl">Item total</span><span class="amt">' + INR(lineTotal) + '</span></div>';
      invItems.appendChild(card);
    });
    recalc();
  }
  function escapeHtml(s) { return String(s).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c])); }

  invItems.addEventListener("input", (e) => {
    const f = e.target.dataset.f, i = e.target.dataset.i;
    if (!f) return;
    const idx = parseInt(i, 10);
    if (f === "name") items[idx].name = e.target.value;
    else if (f === "price") items[idx].price = parseFloat(e.target.value) || 0;
    else if (f === "qty") items[idx].qty = parseInt(e.target.value, 10) || 0;
    // update just this card's item total + grand totals (no full re-render to keep focus)
    const card = e.target.closest(".inv-item");
    $(".item-total .amt", card).textContent = INR((items[idx].price || 0) * (items[idx].qty || 0));
    recalc();
  });
  invItems.addEventListener("click", (e) => {
    const del = e.target.closest("[data-del]");
    if (del) { items.splice(parseInt(del.dataset.del, 10), 1); seq = items.length; renderItems(); }
  });
  $("#addItem").addEventListener("click", () => {
    items.push({ name: "", price: 0, qty: 1 });
    renderItems();
    const inputs = $$(".inv-item input[data-f='name']");
    if (inputs.length) inputs[inputs.length - 1].focus();
  });
  $$(".pay-adj").forEach((el) => el.addEventListener("input", recalc));

  function recalc() {
    const sub = items.reduce((a, it) => a + (it.price || 0) * (it.qty || 0), 0);
    const disc = parseFloat($("#discount").value) || 0;
    const ship = parseFloat($("#shipping").value) || 0;
    const rate = parseFloat($("#taxRate").value) || 0;
    const taxable = Math.max(0, sub - disc);
    const tax = taxable * rate / 100;
    const grand = taxable + ship + tax;
    $("#subtotalView").textContent = INR(sub);
    $("#tSub").textContent = INR(sub);
    $("#tDisc").textContent = "−" + INR(disc);
    $("#tShip").textContent = INR(ship);
    $("#tTax").textContent = INR(tax);
    $("#tGrand").textContent = INR(grand);
  }
  function payOverlay(html) {
    var sc = document.createElement("div"); sc.className = "pay-ov";
    sc.style.cssText = "position:fixed;inset:0;z-index:200;background:rgba(15,26,14,.5);display:flex;align-items:flex-end;justify-content:center";
    sc.innerHTML = '<div style="width:100%;max-width:440px;background:#fff;border-radius:22px 22px 0 0;padding:18px 18px calc(20px + env(safe-area-inset-bottom,0px))">' + html + '</div>';
    document.body.appendChild(sc);
    sc.addEventListener("click", function (e) { if (e.target === sc) sc.remove(); });
    return sc;
  }
  function payBreakdown() {
    var sub = items.reduce(function (a, it) { return a + (it.price || 0) * (it.qty || 0); }, 0);
    var disc = parseFloat($("#discount").value) || 0, ship = parseFloat($("#shipping").value) || 0, rate = parseFloat($("#taxRate").value) || 0;
    var taxable = Math.max(0, sub - disc), tax = taxable * rate / 100, grand = taxable + ship + tax;
    return { sub: sub, disc: disc, ship: ship, rate: rate, tax: tax, grand: grand };
  }
  function payNm() { return ((($(".hero .name") || {}).textContent || "Customer").trim()).replace(/[<>&]/g, ""); }
  function runGateway(total, nm) {
    if (window.__payGateway) {
      window.__payGateway(total, { headNm: nm, headSub: "Invoice payment", totalLabel: "Amount due",
        success: function (amt) { var a = "\u20B9 " + Math.round(amt).toLocaleString("en-IN");
          return { bump: false, procT: "Processing payment\u2026", procS: "Securely charging " + nm, okT: "Payment Received", okS: a + " paid by " + nm, toast: "Payment of " + a + " received from " + nm }; } });
    } else { toast("Opening payment gateway\u2026"); }
  }
  function reviewAndPay(b, nm) {
    function row(k, v) { return '<div style="display:flex;justify-content:space-between;padding:7px 0;font-size:14px"><span style="color:var(--ink-2);font-weight:600">' + k + '</span><span style="font-weight:700;color:var(--ink)">' + v + '</span></div>'; }
    var html = '<div style="font-size:18px;font-weight:800;color:var(--ink);margin-bottom:3px">Review &amp; Pay</div>' +
      '<div style="font-size:12.5px;color:var(--ink-3);margin-bottom:14px">' + nm + ' \u00b7 ' + items.length + ' item' + (items.length > 1 ? "s" : "") + '</div>' +
      '<div style="border:1px solid var(--line);border-radius:14px;padding:10px 14px;margin-bottom:14px">' +
        row("Subtotal", INR(b.sub)) + row("Discount", "\u2212" + INR(b.disc)) + row("Shipping", b.ship ? INR(b.ship) : "Free") + row("GST (" + b.rate + "%)", INR(b.tax)) +
        '<div style="border-top:1px dashed var(--line);margin:5px 0"></div>' +
        '<div style="display:flex;justify-content:space-between;padding:7px 0;font-size:16px;font-weight:800;color:var(--ink)"><span>Total payable</span><span>' + INR(b.grand) + '</span></div>' +
      '</div>' +
      '<button id="rpPay" style="width:100%;border:none;border-radius:14px;padding:15px;background:linear-gradient(135deg,#3cc23f,#2ba84a);color:#fff;font-weight:800;font-size:15px;cursor:pointer;box-shadow:0 8px 20px -8px rgba(43,168,74,.7)">Pay ' + INR(b.grand) + '</button>';
    var ov = payOverlay(html);
    $("#rpPay", ov).addEventListener("click", function () { ov.remove(); closeDrawer(); runGateway(b.grand, nm); });
  }
  $("#sendInvoice").addEventListener("click", () => {
    var b = payBreakdown();
    if (b.grand <= 0) { toast("Add an item to collect payment"); return; }
    if (window.__chat && window.__chat.sendPaymentLink) {
      window.__chat.sendPaymentLink(b.grand, { items: items, shipping: b.ship, note: items.length === 1 && items[0].name ? items[0].name : items.length + " item(s)" });
      closeDrawer();
      toast("Payment link sent in chat \u00b7 tap it to collect");
    } else { toast("Payment link sent on WhatsApp"); }
  });
  renderItems();

  /* ---------- Catalog expand ---------- */
  const catProducts = $("#catalogProducts");
  const PRODUCTS = [
    ["Double Smash Combo", "₹349"], ["Classic Cheeseburger", "₹199"],
    ["Loaded Fries", "₹149"], ["Veg Crunch Burger", "₹179"], ["Cola (500ml)", "₹60"],
  ];
  let catOpen = false;
  $("#catalogCard").addEventListener("click", () => {
    catOpen = !catOpen;
    const chev = $("#catalogCard .chev");
    chev.style.transform = catOpen ? "rotate(180deg)" : "";
    chev.style.transition = "transform .26s cubic-bezier(.2,.8,.2,1)";
    if (catOpen && !catProducts.dataset.built) {
      catProducts.innerHTML = PRODUCTS.map((p) =>
        '<div style="display:flex;justify-content:space-between;align-items:center;padding:10px 13px;border:1px solid var(--line);border-radius:var(--r-sm);background:#fff;margin-bottom:8px;">' +
          '<span style="font-size:14px;color:var(--ink);font-weight:500;">' + p[0] + '</span>' +
          '<span style="font-size:14px;font-weight:800;color:var(--ink);">' + p[1] + '</span></div>'
      ).join("");
      catProducts.dataset.built = "1";
    }
    catProducts.style.display = catOpen ? "block" : "none";
  });

  /* ---------- Customer journey timeline ---------- */
  const JOURNEY = [
    { mode: "off", time: "02 Jun 2026, 12:20 PM" },
    { mode: "on", time: "02 Jun 2026, 12:18 PM" },
    { mode: "off", time: "02 Jun 2026, 12:17 PM" },
    { mode: "on", time: "02 Jun 2026, 12:17 PM" },
    { mode: "on", time: "02 Jun 2026, 12:16 PM" },
    { mode: "off", time: "02 Jun 2026, 12:16 PM" },
    { mode: "on", time: "02 Jun 2026, 12:15 PM" },
    { mode: "off", time: "02 Jun 2026, 12:15 PM" },
    { mode: "on", time: "02 Jun 2026, 12:11 PM" },
  ];
  const clockSvg = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></svg>';
  function renderJourney() {
    var tl = $("#timeline"); if (!tl) return;
    var logs = (window.__chat && window.__chat.getLogs) ? window.__chat.getLogs(currentContact()) : [];
    if (logs && logs.length) {
      tl.innerHTML = logs.map(function (l) {
        var on = /intervened/i.test(l.action) && !/stopped/i.test(l.action);
        return '<div class="tl-item"><span class="tl-node ' + (on ? "on" : "off") + '"></span>' +
          '<div class="tl-card"><div class="t"><span class="pip ' + (on ? "on" : "off") + '"></span>' + escapeHtml(l.action) + '</div>' +
          '<div class="ts">' + clockSvg + escapeHtml((l.agent ? l.agent + " \u00b7 " : "") + l.time) + '</div></div></div>';
      }).join("");
    } else {
      tl.innerHTML = JOURNEY.map(function (j) {
        var on = j.mode === "on";
        return '<div class="tl-item"><span class="tl-node ' + (on ? "on" : "off") + '"></span>' +
          '<div class="tl-card"><div class="t"><span class="pip ' + (on ? "on" : "off") + '"></span>Mode: Intervene ' + (on ? "On" : "Off") + '</div>' +
          '<div class="ts">' + clockSvg + j.time + '</div></div></div>';
      }).join("");
    }
  }
  renderJourney();
  window.__profileJourney = function () { try { renderJourney(); } catch (e) {} };

  /* ---------- Tags ---------- */
  let tags = getTagsStore();
  const tagChips = $("#tagChips");
  const xSvg = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><path d="M18 6L6 18M6 6l12 12"/></svg>';
  function renderTags() {
    tagChips.innerHTML = tags.length
      ? tags.map((t, i) => '<span class="chip">' + escapeHtml(t) + '<span class="x" data-tag="' + i + '">' + xSvg + '</span></span>').join("")
      : '<div class="empty" style="width:100%">No tags yet</div>';
    $("#tagCount").textContent = tags.length;
    $("#tagCount").style.display = tags.length ? "" : "none";
  }
  function addTag() {
    const v = $("#tagInput").value.trim();
    if (!v) return;
    if (tags.some((t) => t.toLowerCase() === v.toLowerCase())) { toast("Tag already added"); return; }
    tags.push(v); $("#tagInput").value = ""; saveTagsStore(); renderTags();
  }
  $("#addTag").addEventListener("click", addTag);
  $("#tagInput").addEventListener("keydown", (e) => { if (e.key === "Enter") addTag(); });
  tagChips.addEventListener("click", (e) => {
    const x = e.target.closest("[data-tag]");
    if (x) { tags.splice(parseInt(x.dataset.tag, 10), 1); saveTagsStore(); renderTags(); }
  });
  renderTags();

  /* ---------- Notes ---------- */
  let notes = pLoad("notes", []);
  let noteEdit = -1;
  const NOTE_MAX = 500;
  const noteList = $("#noteList");
  const ADD_NOTE_ICON = (function () { var b = $("#addNote"); return b ? b.innerHTML : ""; })();
  function setAddNoteMode(editing) {
    const ab = $("#addNote"); if (!ab) return;
    ab.classList.toggle("editing", editing);
    if (editing) { ab.classList.add("save-changes"); ab.innerHTML = "Save changes"; }
    else { ab.classList.remove("save-changes"); ab.innerHTML = ADD_NOTE_ICON; }
  }
  /* self-contained confirm dialog (profile.js can't reach chat.js's modal host) */
  function pfConfirm(opts) {
    const host = document.querySelector(".device-screen") || document.body;
    const scrim = document.createElement("div"); scrim.className = "pf-confirmscrim";
    const card = document.createElement("div"); card.className = "pf-confirmcard";
    card.innerHTML = '<div class="pfc-ttl">' + escapeHtml(opts.title || "Are you sure?") + '</div>' +
      '<div class="pfc-sub">' + escapeHtml(opts.body || "") + '</div>' +
      '<div class="pfc-acts"><button class="pfc-btn ghost" data-x="cancel">' + escapeHtml(opts.cancel || "Cancel") + '</button>' +
      '<button class="pfc-btn' + (opts.danger ? " danger" : "") + '" data-x="ok">' + escapeHtml(opts.ok || "Confirm") + '</button></div>';
    host.appendChild(scrim); host.appendChild(card);
    requestAnimationFrame(function () { scrim.classList.add("show"); card.classList.add("show"); });
    function close() { scrim.classList.remove("show"); card.classList.remove("show"); setTimeout(function () { scrim.remove(); card.remove(); }, 220); }
    scrim.addEventListener("click", close);
    card.querySelector('[data-x="cancel"]').addEventListener("click", close);
    card.querySelector('[data-x="ok"]').addEventListener("click", function () { close(); if (opts.onOk) opts.onOk(); });
  }
  const userSvg = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="8" r="4"/><path d="M4 21a8 8 0 0 1 16 0"/></svg>';
  const noteEditSvg = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M11 4H5a2 2 0 0 0-2 2v13a2 2 0 0 0 2 2h13a2 2 0 0 0 2-2v-6"/><path d="M18.5 2.5a2.12 2.12 0 0 1 3 3L12 15l-4 1 1-4Z"/></svg>';
  const noteDelSvg = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 6h18M8 6V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6"/></svg>';
  function syncNoteCounter() {
    const ta = $("#noteInput"), c = $("#noteCounter"); if (!ta || !c) return;
    if (ta.value.length > NOTE_MAX) ta.value = ta.value.slice(0, NOTE_MAX);
    c.textContent = ta.value.length + "/" + NOTE_MAX;
  }
  function renderNotes() {
    noteList.innerHTML = notes.length
      ? notes.map((n, i) => '<div class="note-card"><div class="body">' + escapeHtml(n.body) + '</div>' +
          '<div class="meta">' + userSvg + '<span class="meta-txt">' + escapeHtml(n.meta) + '</span>' +
          '<span class="note-acts"><button class="note-act" data-noteedit="' + i + '" aria-label="Edit note">' + noteEditSvg + '</button>' +
          '<button class="note-act del" data-notedel="' + i + '" aria-label="Delete note">' + noteDelSvg + '</button></span></div></div>').join("")
      : '<div class="empty">No notes yet</div>';
    $("#noteCount").textContent = notes.length;
    $("#noteCount").style.display = notes.length ? "" : "none";
    $$("[data-noteedit]", noteList).forEach((b) => b.addEventListener("click", () => startEditNote(+b.getAttribute("data-noteedit"))));
    $$("[data-notedel]", noteList).forEach((b) => b.addEventListener("click", () => delNote(+b.getAttribute("data-notedel"))));
  }
  function startEditNote(i) {
    const ta = $("#noteInput"); if (!ta || !notes[i]) return;
    ta.value = notes[i].body; noteEdit = i; syncNoteCounter(); ta.focus();
    setAddNoteMode(true);
  }
  function delNote(i) {
    pfConfirm({ title: "Delete note?", body: "This permanently removes this note. This can\u2019t be undone.", ok: "Delete", danger: true, onOk: function () {
      notes.splice(i, 1);
      if (noteEdit === i) { noteEdit = -1; const ta = $("#noteInput"); if (ta) ta.value = ""; syncNoteCounter(); setAddNoteMode(false); }
      else if (noteEdit > i) noteEdit--;
      pSave("notes", notes); renderNotes(); toast("Note deleted");
    } });
  }
  function addNote() {
    const ta = $("#noteInput"); let v = (ta.value || "").trim();
    if (!v) return;
    if (v.length > NOTE_MAX) v = v.slice(0, NOTE_MAX);
    if (noteEdit >= 0 && notes[noteEdit]) { notes[noteEdit].body = v; notes[noteEdit].meta = "You · edited just now"; noteEdit = -1; toast("Note updated"); }
    else { notes.unshift({ body: v, meta: "You · just now" }); toast("Note added"); }
    ta.value = ""; syncNoteCounter();
    setAddNoteMode(false);
    pSave("notes", notes);
    renderNotes();
  }
  $("#addNote").addEventListener("click", addNote);
  (function () { const ta = $("#noteInput"); if (ta) ta.addEventListener("input", syncNoteCounter); })();
  renderNotes(); syncNoteCounter();

  /* ---------- hydrate the whole drawer for the CURRENT contact ----------
     new chats start blank (manual entry); existing contacts sync from Leads. */
  function hydrate(c) {
    var firstOpen = !pLoad("_seeded", false);
    var lead = firstOpen ? leadFor(c) : null;
    muted = pLoad("muted", false); applyMute();
    renderLeadStatus();
    renderGroups();
    tags = getTagsStore(); renderTags();
    notes = pLoad("notes", (lead && lead.description) ? [{ body: lead.description, meta: "Synced from Leads" }] : []); renderNotes();
    items = [{ name: "", price: 0, qty: 1 }]; seq = 1; renderItems();
    renderAgents();
    renderJourney();
    if (firstOpen) { pSave("notes", notes); pSave("_seeded", true); }
  }

  /* ---------- init ---------- */
  fitStage();
  window.addEventListener("load", fitStage);
})();
