/* =========================================================
   AskEva — Settings · QR Code (part 2)
   Generate WhatsApp QR Code: enter a message + format, get a
   real scannable QR (encodes a wa.me share link with the
   message), preview it, and keep a history with working
   Open-in-WhatsApp / Download / Edit / Delete actions.
   Renders into #qrView. Self-contained.
   ========================================================= */
(function () {
  "use strict";
  var view = document.getElementById("qrView"); if (!view) return;
  var $ = function (s, r) { return (r || document).querySelector(s); };
  var $$ = function (s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); };
  function esc(s) { return String(s == null ? "" : s).replace(/[&<>"]/g, function (c) { return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]; }); }
  var toastT;
  function toast(m) { var t = document.getElementById("toast"); if (!t) return; t.textContent = m; t.style.opacity = "1"; t.style.transform = "translateX(-50%) translateY(0)"; clearTimeout(toastT); toastT = setTimeout(function () { t.style.opacity = "0"; t.style.transform = "translateX(-50%) translateY(20px)"; }, 1900); }

  var FORMATS = [["png", "PNG"], ["svg", "SVG"], ["jpg", "JPG"]];

  /* a WhatsApp share link that opens chat with the message prefilled */
  function waLink(msg) { return "https://wa.me/?text=" + encodeURIComponent(msg); }
  /* real QR via QR Server (CORS-enabled, scannable). High EC so the centre logo doesn't break scanning */
  function qrUrl(msg, fmt, size) {
    size = size || 300;
    var f = fmt === "svg" ? "svg" : fmt === "jpg" ? "jpg" : "png";
    return "https://api.qrserver.com/v1/create-qr-code/?size=" + size + "x" + size + "&margin=6&ecc=H&format=" + f +
      "&data=" + encodeURIComponent(waLink(msg));
  }
  function qrImg(msg, fmt, cls) {
    return '<div class="qr-canvas ' + (cls || "") + '"><img crossorigin="anonymous" alt="QR code" src="' + qrUrl(msg, fmt === "svg" ? "png" : fmt) + '" onerror="this.closest(\'.qr-canvas\').classList.add(\'err\')">' +
      '<span class="qr-logo">' + WA + '</span><div class="qr-fallback">' + QRI + '<span>QR preview needs a connection</span></div></div>';
  }

  /* store */
  var QK = "askeva.set.qr.v2";
  var SEED = [
    { id: "q1", msg: "Hello, I need more info about AskEva", fmt: "png", created: "01-06-2026 3:57 PM" },
    { id: "q2", msg: "Book a product demo", fmt: "png", created: "27-03-2026 6:26 PM" },
    { id: "q3", msg: "Talk to sales about pricing", fmt: "png", created: "31-12-2025 10:54 AM" },
    { id: "q4", msg: "Hello, greetings from AskEva", fmt: "png", created: "25-12-2025 11:56 AM" },
    { id: "q5", msg: "I'd like to start a free trial", fmt: "png", created: "26-11-2025 8:11 PM" },
    { id: "q6", msg: "Request a callback from support", fmt: "png", created: "20-11-2025 12:04 PM" }
  ];
  var hist; try { hist = JSON.parse(localStorage.getItem(QK)) || null; } catch (e) { hist = null; }
  if (!hist) hist = SEED.slice();
  function save() { try { localStorage.setItem(QK, JSON.stringify(hist)); } catch (e) {} }

  var draft = { msg: "", fmt: "png" };
  var current = null;      // last generated item shown in the preview
  var editingId = null;

  /* =========================================================
     RENDER
     ========================================================= */
  function render() {
    view.innerHTML =
      '<div class="qr-card"><div class="qr-h">Generate WhatsApp QR Code</div>' +
        '<label class="qr-lbl"><span class="req">*</span> Enter Message</label>' +
        '<div class="qr-input"><input id="qrMsg" type="text" placeholder="Enter message for QR" value="' + esc(draft.msg) + '" maxlength="400"></div>' +
        '<label class="qr-lbl">Select Format</label>' +
        '<button class="qr-select" id="qrFmt"><span class="v">' + fmtLabel(draft.fmt) + '</span><span class="cv">' + CHEV + '</span></button>' +
        '<button class="qr-gen" id="qrGen">' + QRMINI + 'Generate QR Code</button>' +
      '</div>' +

      '<div class="qr-card"><div class="qr-h">Generated QR Code</div>' +
        '<div class="qr-preview" id="qrPreview">' +
          (current
            ? qrImg(current.msg, current.fmt, "big") +
              '<div class="qr-pmsg">' + esc(current.msg) + '</div>' +
              '<div class="qr-pacts"><button class="qr-pbtn wa" data-pa="open">' + WA + 'Chat</button>' +
              '<button class="qr-pbtn" data-pa="download">' + DL + 'Download</button></div>'
            : '<div class="qr-empty">' + QRI + '<span>Generated QR code will appear here</span></div>') +
        '</div>' +
      '</div>' +

      '<div class="qr-card"><div class="qr-h">' + CLOCK + 'QR Code History</div>' +
        '<div class="qr-grid">' + (hist.length ? hist.map(histCard).join("") : '<div class="qr-empty2">No QR codes yet.</div>') + '</div>' +
      '</div>';

    /* wire generate panel */
    var mi = $("#qrMsg", view); mi.addEventListener("input", function (e) { draft.msg = e.target.value; });
    $("#qrFmt", view).addEventListener("click", function () {
      radioSheet("Select Format", FORMATS.map(function (f) { return [f[0], f[1]]; }), draft.fmt, function (v) { draft.fmt = v; render(); });
    });
    $("#qrGen", view).addEventListener("click", generate);

    /* preview actions */
    $$("#qrPreview [data-pa]", view).forEach(function (b) { b.addEventListener("click", function () {
      if (!current) return;
      if (b.getAttribute("data-pa") === "open") openWa(current); else downloadQr(current);
    }); });

    /* history actions */
    $$(".qr-hcard", view).forEach(function (card) {
      var id = card.getAttribute("data-id"), item = function () { return hist.filter(function (x) { return x.id === id; })[0]; };
      $(".qa-open", card).addEventListener("click", function () { openWa(item()); });
      $(".qa-dl", card).addEventListener("click", function () { downloadQr(item()); });
      $(".qa-edit", card).addEventListener("click", function () { var it = item(); draft.msg = it.msg; draft.fmt = it.fmt; editingId = id; render(); var sc = $(".set-scroll", document.getElementById("sub-qr")); if (sc) sc.scrollTo({ top: 0, behavior: "smooth" }); var mm = $("#qrMsg", view); if (mm) mm.focus(); toast("Loaded into editor"); });
      $(".qa-del", card).addEventListener("click", function () { confirmModal("Delete QR code?", "This QR code will be removed from history.", "Delete", function () { hist = hist.filter(function (x) { return x.id !== id; }); save(); render(); toast("QR code deleted"); }); });
    });
  }
  function fmtLabel(f) { var hit = FORMATS.filter(function (x) { return x[0] === f; })[0]; return hit ? hit[1] : "PNG"; }

  function histCard(it) {
    return '<div class="qr-hcard" data-id="' + it.id + '">' +
      qrImg(it.msg, it.fmt, "thumb") +
      '<div class="qr-hmsg"><b>Message:</b> ' + esc(it.msg) + '</div>' +
      '<div class="qr-hcreated"><b>Created:</b> ' + esc(it.created) + '</div>' +
      '<div class="qr-hacts"><button class="qa-open" aria-label="Chat">' + WA + '</button>' +
        '<button class="qa-dl" aria-label="Download">' + DL + '</button>' +
        '<button class="qa-edit" aria-label="Edit">' + EDIT + '</button>' +
        '<button class="qa-del" aria-label="Delete">' + TRASH + '</button></div></div>';
  }

  /* =========================================================
     ACTIONS
     ========================================================= */
  function generate() {
    var msg = (draft.msg || "").trim();
    if (!msg) { toast("Enter a message first"); var mi = $("#qrMsg", view); if (mi) mi.focus(); return; }
    if (editingId) {
      var ex = hist.filter(function (x) { return x.id === editingId; })[0];
      if (ex) { ex.msg = msg; ex.fmt = draft.fmt; ex.created = nowStr(); current = ex; editingId = null; save(); render(); toast("QR code updated"); return; }
    }
    var item = { id: "q" + Date.now().toString(36), msg: msg, fmt: draft.fmt, created: nowStr() };
    hist.unshift(item); current = item; save();
    draft.msg = ""; render(); toast("QR code generated");
  }
  function openWa(it) { if (!it) return; if (window.__appRoute) window.__appRoute("chats"); setTimeout(function () { if (window.__chat && window.__chat.shareImage) window.__chat.shareImage({ title: "Send QR Code", sub: "Select whom to send the QR code to" }); }, 110); }
  function downloadQr(it) {
    if (!it) return;
    var url = qrUrl(it.msg, it.fmt, 512);
    fetch(url).then(function (r) { return r.blob(); }).then(function (b) {
      var a = document.createElement("a"); var href = URL.createObjectURL(b);
      a.href = href; a.download = "whatsapp-qr-" + slug(it.msg) + "." + (it.fmt === "jpg" ? "jpg" : it.fmt === "svg" ? "svg" : "png");
      document.body.appendChild(a); a.click(); a.remove();
      setTimeout(function () { URL.revokeObjectURL(href); }, 3000);
      toast("Downloaded " + it.fmt.toUpperCase());
    }).catch(function () { try { window.open(url, "_blank"); toast("Opened QR image"); } catch (e) { toast("Download failed"); } });
  }
  function slug(s) { return (s || "qr").toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "").slice(0, 24) || "qr"; }
  function nowStr() {
    var d = new Date(2026, 5, 5, 13, 12); var dd = pad(d.getDate()), mm = pad(d.getMonth() + 1), yy = d.getFullYear();
    var h = d.getHours(), ap = h < 12 ? "AM" : "PM"; h = h % 12 || 12;
    return dd + "-" + mm + "-" + yy + " " + h + ":" + pad(d.getMinutes()) + " " + ap;
  }
  function pad(n) { return n < 10 ? "0" + n : "" + n; }

  /* =========================================================
     sheet + modal primitives (scoped to settings pane)
     ========================================================= */
  var scrim, sheet, host = document.getElementById("app-settings");
  function ensureSheet() { if (scrim) return; scrim = document.createElement("div"); scrim.className = "ax-scrim qr-scrim"; sheet = document.createElement("div"); sheet.className = "ax-sheet qr-sheet"; scrim.addEventListener("click", closeSheet); host.appendChild(scrim); host.appendChild(sheet); }
  function openSheet(html) { ensureSheet(); sheet.innerHTML = html; sheet.scrollTop = 0; requestAnimationFrame(function () { scrim.classList.add("show"); sheet.classList.add("show"); }); return sheet; }
  function closeSheet() { if (sheet) { scrim.classList.remove("show"); sheet.classList.remove("show"); } }
  function radioSheet(title, opts, cur, onPick) {
    var html = '<div class="ax-grip"></div><div class="ax-sheet-head"><div class="ax-sheet-ttl">' + esc(title) + '</div></div><div class="ax-reasons">' +
      opts.map(function (o) { return '<button class="ax-reason' + (cur === o[0] ? " on" : "") + '" data-v="' + o[0] + '">' + esc(o[1]) + '</button>'; }).join("") + '</div>';
    var s = openSheet(html);
    $$(".ax-reason", s).forEach(function (b) { b.addEventListener("click", function () { closeSheet(); onPick(b.getAttribute("data-v")); }); });
  }
  var cScrim, onGo;
  function confirmModal(title, sub, go, cb) {
    if (!cScrim) { cScrim = document.createElement("div"); cScrim.className = "ax-modal-scrim qr-modal"; host.appendChild(cScrim); cScrim.addEventListener("click", function (e) { if (e.target === cScrim) cScrim.classList.remove("show"); }); }
    cScrim.innerHTML = '<div class="ax-modal"><div class="mic">' + WARN + '</div><div class="mt">' + esc(title) + '</div><div class="ms">' + esc(sub) + '</div><div class="mb"><button class="keep" id="qrKeep">Keep</button><button class="go" id="qrGo">' + esc(go) + '</button></div></div>';
    onGo = cb;
    $("#qrKeep", cScrim).addEventListener("click", function () { cScrim.classList.remove("show"); });
    $("#qrGo", cScrim).addEventListener("click", function () { cScrim.classList.remove("show"); if (onGo) onGo(); });
    requestAnimationFrame(function () { cScrim.classList.add("show"); });
  }

  /* icons */
  var WA = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14 9a2 2 0 0 1-2 2H6l-4 4V4c0-1.1.9-2 2-2h8a2 2 0 0 1 2 2v5Z"/><path d="M18 9h2a2 2 0 0 1 2 2v11l-4-4h-6a2 2 0 0 1-2-2v-1"/><circle cx="5.2" cy="6.4" r=".7" fill="currentColor" stroke="none"/><circle cx="8" cy="6.4" r=".7" fill="currentColor" stroke="none"/><circle cx="10.8" cy="6.4" r=".7" fill="currentColor" stroke="none"/></svg>';
  var WARN = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 9v4M12 17h.01"/><path d="M10.3 3.9 2 19a2 2 0 0 0 1.7 3h16.6a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0Z"/></svg>';
  var QRI = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="3" width="7" height="7" rx="1"/><rect x="14" y="3" width="7" height="7" rx="1"/><rect x="3" y="14" width="7" height="7" rx="1"/><path d="M14 14h3v3M21 14v.01M14 21h.01M17.5 21h.01M21 17.5v3.5"/></svg>';
  var QRMINI = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="3" width="7" height="7" rx="1"/><rect x="14" y="3" width="7" height="7" rx="1"/><rect x="3" y="14" width="7" height="7" rx="1"/><path d="M14 14h3M14 18h3M18 14v7"/></svg>';
  var DL = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 4v10m0 0 4-4m-4 4-4-4M5 19h14"/></svg>';
  var EDIT = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M11 4H5a2 2 0 0 0-2 2v13a2 2 0 0 0 2 2h13a2 2 0 0 0 2-2v-6"/><path d="M18.5 2.5a2.12 2.12 0 0 1 3 3L12 15l-4 1 1-4Z"/></svg>';
  var TRASH = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 7h16M9 7V5a2 2 0 0 1 2-2h2a2 2 0 0 1 2 2v2M6 7l1 13a2 2 0 0 0 2 2h6a2 2 0 0 0 2-2l1-13"/></svg>';
  var CHEV = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m6 9 6 6 6-6"/></svg>';
  var CLOCK = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3.5 2"/></svg>';

  render();
  window.__qr = { render: render };
})();
