/* =========================================================
   AskEva — Settings · Securities / 2FA (part 4)
   Working Two-Factor Authentication setup:
     3-step wizard (Device Name → Scan QR → Verify) that
     generates a REAL base32 TOTP secret + otpauth QR (scannable
     by Google/Microsoft Authenticator/Authy), verifies the live
     6-digit code via Web Crypto HMAC-SHA1, then issues backup
     codes and marks 2FA enabled. Disable/regenerate supported.
   Renders into #secView. Self-contained.
   ========================================================= */
(function () {
  "use strict";
  var view = document.getElementById("secView"); if (!view) return;
  var $ = function (s, r) { return (r || document).querySelector(s); };
  var $$ = function (s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); };
  function esc(s) { return String(s == null ? "" : s).replace(/[&<>"]/g, function (c) { return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]; }); }
  var toastT;
  function toast(m) { var t = document.getElementById("toast"); if (!t) return; t.textContent = m; t.style.opacity = "1"; t.style.transform = "translateX(-50%) translateY(0)"; clearTimeout(toastT); toastT = setTimeout(function () { t.style.opacity = "0"; t.style.transform = "translateX(-50%) translateY(20px)"; }, 1900); }

  /* ---------- persisted 2FA state ---------- */
  var SK = "askeva.set.2fa.v3";
  var st; try { st = JSON.parse(localStorage.getItem(SK)) || null; } catch (e) { st = null; }
  /* 2FA is OFF by default — the login bypass stays removed, so once you ENROLL
     your own authenticator (Settings → Securities → set up), every login will
     require the live code. Until then, password sign-in works normally. */
  if (!st) st = { enabled: false, device: "", secret: "", backups: [] };
  function save() { try { localStorage.setItem(SK, JSON.stringify(st)); } catch (e) {} }

  /* wizard working state */
  var step = 1, draft = { device: "", secret: "", code: "" };

  /* ---------- base32 (RFC 4648) ---------- */
  var B32 = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";
  function randSecret(len) { len = len || 20; var bytes = new Uint8Array(len); (window.crypto || {}).getRandomValues ? crypto.getRandomValues(bytes) : bytes.forEach(function (_, i) { bytes[i] = Math.floor(Math.random() * 256); }); var out = "", bits = 0, val = 0; for (var i = 0; i < bytes.length; i++) { val = (val << 8) | bytes[i]; bits += 8; while (bits >= 5) { out += B32[(val >>> (bits - 5)) & 31]; bits -= 5; } } return out; }
  function b32decode(s) { s = s.replace(/=+$/, "").toUpperCase().replace(/\s/g, ""); var bits = 0, val = 0, out = []; for (var i = 0; i < s.length; i++) { var idx = B32.indexOf(s[i]); if (idx < 0) continue; val = (val << 5) | idx; bits += 5; if (bits >= 8) { out.push((val >>> (bits - 8)) & 0xff); bits -= 8; } } return new Uint8Array(out); }

  /* ---------- TOTP via Web Crypto (HMAC-SHA1) ---------- */
  function totp(secret, forCounter) {
    var key = b32decode(secret);
    var counter = forCounter == null ? Math.floor(Date.now() / 1000 / 30) : forCounter;
    var buf = new ArrayBuffer(8), dv = new DataView(buf);
    dv.setUint32(0, Math.floor(counter / 0x100000000)); dv.setUint32(4, counter >>> 0);
    return crypto.subtle.importKey("raw", key, { name: "HMAC", hash: "SHA-1" }, false, ["sign"])
      .then(function (k) { return crypto.subtle.sign("HMAC", k, buf); })
      .then(function (sig) {
        var h = new Uint8Array(sig), off = h[h.length - 1] & 0xf;
        var bin = ((h[off] & 0x7f) << 24) | (h[off + 1] << 16) | (h[off + 2] << 8) | h[off + 3];
        return ("000000" + (bin % 1000000)).slice(-6);
      });
  }
  function otpauthUri(device, secret) {
    return "otpauth://totp/" + encodeURIComponent("AskEva:" + (device || "Account")) + "?secret=" + secret + "&issuer=AskEva&algorithm=SHA1&digits=6&period=30";
  }
  function qrUrl(uri) { return "https://api.qrserver.com/v1/create-qr-code/?size=320x320&margin=8&ecc=M&data=" + encodeURIComponent(uri); }
  function backupCodes() { var out = []; for (var i = 0; i < 10; i++) { var g = []; for (var j = 0; j < 3; j++) { var s = ""; for (var k = 0; k < 4; k++) s += "0123456789ABCDEF"[Math.floor(Math.random() * 16)]; g.push(s); } out.push(g.join("-")); } return out; }
  function todayISO() { var d = new Date(); return d.getFullYear() + "-" + ("0" + (d.getMonth() + 1)).slice(-2) + "-" + ("0" + d.getDate()).slice(-2); }
  function addedLabel() { if (!st.added) return "\u2014"; var p = st.added.split("-"), M = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]; return M[(+p[1] || 1) - 1] + " " + (+p[2]) + ", " + p[0]; }
  function downloadCodes(codes) { try { var blob = new Blob(["AskEva Two-Factor Backup Codes\nDevice: " + (st.device || "Authenticator") + "\n\n" + codes.join("\n") + "\n\nEach code can be used once."], { type: "text/plain" }); var a = document.createElement("a"); a.href = URL.createObjectURL(blob); a.download = "askeva-backup-codes.txt"; document.body.appendChild(a); a.click(); a.remove(); setTimeout(function () { URL.revokeObjectURL(a.href); }, 2000); toast("Backup codes downloaded"); } catch (e) { toast("Download failed"); } }

  /* =========================================================
     RENDER
     ========================================================= */
  function render() {
    var pill = document.getElementById("twofaPill");
    if (pill) { pill.classList.toggle("warn", !st.enabled); pill.innerHTML = '<span class="d"></span>' + (st.enabled ? "Enabled" : "Not Enabled"); }
    view.innerHTML = st.enabled ? enabledView() : setupView();
    if (st.enabled) wireEnabled(); else wireSetup();
  }

  /* ---------- ENABLED state ---------- */
  function enabledView() {
    var n = (st.backups || []).length;
    return '<div class="sec-banner ok"><span class="ic">' + IC.shieldOk + '</span><div class="tx"><div class="t">Two-Factor Authentication</div>' +
        '<div class="s">Your account is protected with an authenticator app.</div></div><span class="sec-badge ok">Enabled</span></div>' +
      '<div class="sec-enh"><span class="ic">' + IC.shieldOk + '</span><div class="tx"><div class="t">Enabled Authenticators</div>' +
        '<div class="s">1 authenticator currently protecting your account</div></div></div>' +
      '<div class="sec-authcard">' +
        '<div class="sa-top"><span class="sa-lock">' + IC.lock + '</span><span class="sa-name">' + esc(st.device || "Authenticator") + '</span>' +
          '<span class="sa-acts">' +
            '<button class="sa-ic" id="secBackups" title="View backup codes" aria-label="View backup codes">' + IC.shield + '</button>' +
            '<button class="sa-ic" id="secRegen" title="Generate new codes" aria-label="Generate new codes">' + IC.refresh + '</button>' +
            '<button class="sa-ic danger" id="secDisable" title="Disable 2FA" aria-label="Disable 2FA">' + IC.shieldOff + '</button>' +
          '</span></div>' +
        '<div class="sa-grid">' +
          '<div class="sa-cell"><div class="k">' + IC.cal + 'Added date</div><div class="v">' + esc(addedLabel()) + '</div></div>' +
          '<div class="sa-cell"><div class="k">' + IC.shield + 'Backup codes</div><div class="v">' + n + '/10 available</div></div>' +
          '<div class="sa-cell"><div class="k">' + IC.check + 'Status</div><div class="v"><span class="sa-status">' + IC.check + 'Active</span></div></div>' +
        '</div>' +
      '</div>';
  }
  function wireEnabled() {
    $("#secBackups", view).addEventListener("click", function () { showBackups(st.backups, false); });
    $("#secRegen", view).addEventListener("click", function () {
      confirmModal("Generate new backup codes?", "Your current backup codes will stop working immediately. Save the new ones somewhere safe.", "Generate", function () {
        st.backups = backupCodes(); save(); render(); showBackups(st.backups, true); toast("New backup codes generated");
      });
    });
    $("#secDisable", view).addEventListener("click", function () {
      confirmModal("Disable 2FA?", "Your account will no longer require an authenticator code at login.", "Disable", function () {
        st = { enabled: false, device: "", secret: "", backups: [], added: "" }; save(); step = 1; draft = { device: "", secret: "", code: "" }; render(); toast("Two-factor authentication disabled");
      });
    });
  }

  /* ---------- SETUP wizard ---------- */
  var STEPS = [["Device Name"], ["Scan QR Code"], ["Verify"]];
  function setupView() {
    return '<div class="sec-banner warn"><span class="ic">' + IC.shieldWarn + '</span><div class="tx"><div class="t">Two-Factor Authentication</div>' +
        '<div class="s">Your account is not yet protected — enable 2FA to stay secure</div></div><span class="sec-badge warn">Not Enabled</span></div>' +
      stepper() +
      (step === 1 ? stepName() : step === 2 ? stepScan() : stepVerify()) +
      (step === 1 ? guide() + supported() : "");
  }
  function stepper() {
    return '<div class="sec-stepper">' + STEPS.map(function (s, i) {
      var n = i + 1, cls = n < step ? "done" : n === step ? "on" : "";
      return (i ? '<span class="line ' + (n <= step ? "fill" : "") + '"></span>' : "") +
        '<div class="st ' + cls + '"><span class="dot">' + (n < step ? IC.check : n) + '</span><span class="lb">' + s[0] + '</span></div>';
    }).join("") + '</div>';
  }

  function stepName() {
    return '<div class="sec-card lead"><div class="sc-h">' + IC.info + 'Setup New Authenticator</div>' +
      '<label class="sec-lbl">Device Name <span class="req">*</span></label>' +
      '<div class="sec-input"><input id="secDevice" type="text" placeholder="e.g., Google Auth on iPhone" value="' + esc(draft.device) + '"></div>' +
      '<div class="sec-hint">Give this authenticator a descriptive name to identify it later.</div>' +
      '<button class="sec-gen" id="secGen"' + (draft.device.trim() ? "" : " disabled") + '>' + IC.lock + 'Generate Secret &amp; QR</button></div>';
  }
  function stepScan() {
    var uri = otpauthUri(draft.device, draft.secret);
    return '<div class="sec-card"><div class="sc-h">' + IC.qr + 'Scan QR Code</div>' +
      '<div class="sec-qrwrap"><div class="qr-canvas big"><img crossorigin="anonymous" alt="2FA QR" src="' + qrUrl(uri) + '" onerror="this.closest(\'.qr-canvas\').classList.add(\'err\')"><div class="qr-fallback">' + IC.qr + '<span>QR needs a connection</span></div></div></div>' +
      '<div class="sec-or">or enter the key manually</div>' +
      '<div class="sec-secret"><code id="secKey">' + fmtSecret(draft.secret) + '</code><button class="sec-copy" id="secCopy" aria-label="Copy">' + IC.copy + '</button></div>' +
      '<div class="sec-hint">Open your authenticator app, add an account, and scan this QR (or type the key). A 6-digit code will appear.</div>' +
      '<div class="ax-savebar two"><button class="ax-btn ghost" id="secBack2">Back</button><button class="ax-btn primary" id="secNext2">Continue</button></div></div>';
  }
  function stepVerify() {
    return '<div class="sec-card"><div class="sc-h">' + IC.shield + 'Verify</div>' +
      '<div class="sec-hint" style="margin-bottom:14px">Enter the 6-digit code shown in your authenticator app for <b>' + esc(draft.device) + '</b>.</div>' +
      '<div class="sec-otp" id="secOtp">' + [0,1,2,3,4,5].map(function (i) { return '<input class="otp" inputmode="numeric" maxlength="1" data-i="' + i + '">'; }).join("") + '</div>' +
      '<div class="sec-err" id="secErr"></div>' +
      '<div class="ax-savebar two"><button class="ax-btn ghost" id="secBack3">Back</button><button class="ax-btn primary" id="secVerify">' + IC.check + 'Verify &amp; Enable</button></div></div>';
  }
  function fmtSecret(s) { return (s || "").replace(/(.{4})/g, "$1 ").trim(); }

  function wireSetup() {
    if (step === 1) {
      var di = $("#secDevice", view); di.addEventListener("input", function (e) { draft.device = e.target.value; var g = $("#secGen", view); if (g) g.disabled = !e.target.value.trim(); });
      $("#secGen", view).addEventListener("click", function () {
        if (!draft.device.trim()) { toast("Enter a device name"); return; }
        draft.secret = randSecret(20); step = 2; render();
      });
    } else if (step === 2) {
      $("#secCopy", view).addEventListener("click", function () { copy(draft.secret); toast("Secret key copied"); });
      $("#secBack2", view).addEventListener("click", function () { step = 1; render(); });
      $("#secNext2", view).addEventListener("click", function () { step = 3; draft.code = ""; render(); });
    } else {
      var inputs = $$("#secOtp .otp", view);
      inputs.forEach(function (inp, i) {
        inp.addEventListener("input", function () { inp.value = inp.value.replace(/\D/g, "").slice(0, 1); if (inp.value && i < 5) inputs[i + 1].focus(); $("#secErr", view).textContent = ""; });
        inp.addEventListener("keydown", function (e) { if (e.key === "Backspace" && !inp.value && i > 0) inputs[i - 1].focus(); });
        inp.addEventListener("paste", function (e) { e.preventDefault(); var d = (e.clipboardData.getData("text") || "").replace(/\D/g, "").slice(0, 6).split(""); d.forEach(function (ch, k) { if (inputs[k]) inputs[k].value = ch; }); var n = Math.min(d.length, 5); inputs[n].focus(); });
      });
      setTimeout(function () { if (inputs[0]) inputs[0].focus(); }, 60);
      $("#secBack3", view).addEventListener("click", function () { step = 2; render(); });
      $("#secVerify", view).addEventListener("click", verify);
    }
  }

  function verify() {
    var inputs = $$("#secOtp .otp", view), code = inputs.map(function (i) { return i.value; }).join("");
    if (code.length !== 6) { $("#secErr", view).textContent = "Enter all 6 digits."; return; }
    var counter = Math.floor(Date.now() / 1000 / 30);
    // accept current ± 1 window (clock skew)
    Promise.all([totp(draft.secret, counter - 1), totp(draft.secret, counter), totp(draft.secret, counter + 1)])
      .then(function (codes) {
        if (codes.indexOf(code) > -1) {
          st.enabled = true; st.device = draft.device.trim(); st.secret = draft.secret; st.backups = backupCodes(); st.added = todayISO(); save();
          showBackups(st.backups, true);
        } else {
          $("#secErr", view).textContent = "Incorrect code. Make sure your device clock is correct and try the latest code.";
          inputs.forEach(function (i) { i.value = ""; }); if (inputs[0]) inputs[0].focus();
        }
      }).catch(function () { $("#secErr", view).textContent = "Could not verify. Try again."; });
  }

  function showBackups(codes, firstTime) {
    var html = '<div class="ax-grip"></div>' +
      '<div class="bk-head"><span class="bk-hic">' + IC.shieldOk + '</span><div class="bk-htx"><div class="t">Backup Codes - ' + esc(st.device || "Authenticator") + '</div>' +
        '<div class="s">Keep these one-time codes safe \u2014 they\u2019re your secure fallback access.</div></div><button class="bk-x" id="bkClose" aria-label="Close">' + IC.x + '</button></div>' +
      '<div class="bk-warn"><span class="ic">' + IC.warn + '</span><div class="tx"><b>Important: Save these backup codes!</b>' +
        '<span>These codes can be used to access your account if you lose your authenticator device. Each code can only be used once.</span></div></div>' +
      '<div class="bk-grid">' + codes.map(function (c) { return '<div class="bk-code"><span>' + esc(c) + '</span><button class="bk-copy" data-c="' + esc(c) + '" aria-label="Copy code">' + IC.copy + '</button></div>'; }).join("") + '</div>' +
      '<div class="bk-instr"><div class="h">Instructions</div><div class="r">' + IC.lock + 'Store these codes in a secure location.</div></div>' +
      '<div class="bk-foot"><button class="cfg-btn ghost" id="bkDl">' + IC.download + 'Download</button>' +
        '<button class="cfg-btn ghost" id="bkCopyAll">' + IC.copy + 'Copy All</button>' +
        '<button class="cfg-btn primary" id="bkDone">' + IC.shieldOk + (firstTime ? "I\u2019ve Saved These Codes" : "Done") + '</button></div>';
    var s = openSheet(html);
    $$(".bk-copy", s).forEach(function (b) { b.addEventListener("click", function () { copy(b.getAttribute("data-c")); toast("Code copied"); }); });
    $("#bkClose", s).addEventListener("click", function () { closeSheet(); if (firstTime) { step = 1; draft = { device: "", secret: "", code: "" }; render(); } });
    $("#bkDl", s).addEventListener("click", function () { downloadCodes(codes); });
    $("#bkCopyAll", s).addEventListener("click", function () { copy(codes.join("\n")); toast("All backup codes copied"); });
    $("#bkDone", s).addEventListener("click", function () { closeSheet(); if (firstTime) { step = 1; draft = { device: "", secret: "", code: "" }; render(); toast("Two-factor authentication enabled"); } });
  }

  /* ---------- guide + supported apps ---------- */
  function guide() {
    var items = [
      [IC.edit, "1. Name It", "Choose a friendly name for your authenticator device."],
      [IC.qr, "2. Scan QR Code", "Open your authenticator app and scan the QR code shown."],
      [IC.search, "3. Manual Entry", "Alternatively, enter the secret key manually into your app."],
      [IC.shield, "4. Verify", "Enter the 6-digit code from your authenticator app to verify."],
      [IC.list, "5. Save Backup Codes", "Download or copy your backup codes and keep them secure."]
    ];
    return '<div class="sec-guide"><div class="sg-h">' + IC.info + 'Setup New Authenticator</div>' +
      '<div class="sg-grid">' + items.map(function (it) { return '<div class="sg-card"><span class="ic">' + it[0] + '</span><div class="t">' + it[1] + '</div><div class="s">' + it[2] + '</div></div>'; }).join("") + '</div></div>';
  }
  function supported() {
    var GA = '<svg viewBox="0 0 48 48"><path fill="#5BB974" d="M24 4 9 30.5h9.5L24 21l5.5 9.5H39z"/><path fill="#1A73E8" d="M30.2 31 24 42l-6.2-11z" transform="rotate(120 24 27)"/><circle cx="24" cy="24" r="3.4" fill="#fff"/><path fill="#1A73E8" d="M24 44 13.5 26h21z" opacity=".85"/></svg>';
    var MS = '<svg viewBox="0 0 48 48"><rect x="7" y="7" width="15.5" height="15.5" fill="#F25022"/><rect x="25.5" y="7" width="15.5" height="15.5" fill="#7FBA00"/><rect x="7" y="25.5" width="15.5" height="15.5" fill="#00A4EF"/><rect x="25.5" y="25.5" width="15.5" height="15.5" fill="#FFB900"/></svg>';
    var AU = '<svg viewBox="0 0 48 48"><circle cx="24" cy="24" r="20" fill="#EC1C24"/><path fill="#fff" d="M24 12a12 12 0 1 0 0 24 12 12 0 0 0 0-24Zm0 5.5a6.5 6.5 0 1 1 0 13 6.5 6.5 0 0 1 0-13Z"/><circle cx="24" cy="24" r="3.4" fill="#fff"/></svg>';
    var DUO = '<svg viewBox="0 0 48 48"><circle cx="24" cy="24" r="20" fill="#60BC46"/><path fill="#fff" d="M16 15h6.5c5 0 8.5 3.6 8.5 9s-3.5 9-8.5 9H16Zm6 5v8c2.6 0 4.3-1.6 4.3-4s-1.7-4-4.3-4Z"/></svg>';
    var ANY = '<svg viewBox="0 0 48 48"><circle cx="24" cy="24" r="20" fill="#EAF9E6"/><path fill="none" stroke="#177A36" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round" d="M24 14v10l6 4"/><circle cx="24" cy="24" r="13" fill="none" stroke="#177A36" stroke-width="2.6"/></svg>';
    var apps = [[GA, "Google Authenticator"], [MS, "Microsoft Authenticator"], [AU, "Authy"], [DUO, "Duo Mobile"], [ANY, "Any TOTP-Compatible App"]];
    return '<div class="sec-supported"><div class="ss-h">Supported Authenticator Apps</div><div class="ss-row">' +
      apps.map(function (a) { return '<span class="ss-app"><span class="ss-ic">' + a[0] + '</span>' + esc(a[1]) + '</span>'; }).join("") + '</div></div>';
  }

  function copy(t) { try { navigator.clipboard.writeText(t); } catch (e) { var ta = document.createElement("textarea"); ta.value = t; document.body.appendChild(ta); ta.select(); try { document.execCommand("copy"); } catch (x) {} ta.remove(); } }

  /* ---------- sheet + modal ---------- */
  var scrim, sheet, host = document.getElementById("app-settings");
  function ensureSheet() { if (scrim) return; scrim = document.createElement("div"); scrim.className = "ax-scrim sec-scrim"; sheet = document.createElement("div"); sheet.className = "ax-sheet sec-sheet"; scrim.addEventListener("click", closeSheet); host.appendChild(scrim); host.appendChild(sheet); }
  function openSheet(html) { ensureSheet(); sheet.innerHTML = html; sheet.scrollTop = 0; requestAnimationFrame(function () { scrim.classList.add("show"); sheet.classList.add("show"); }); return sheet; }
  function closeSheet() { if (sheet) { scrim.classList.remove("show"); sheet.classList.remove("show"); } }
  var cScrim, onGo;
  function confirmModal(title, sub, go, cb) {
    if (!cScrim) { cScrim = document.createElement("div"); cScrim.className = "ax-modal-scrim sec-modal"; host.appendChild(cScrim); cScrim.addEventListener("click", function (e) { if (e.target === cScrim) cScrim.classList.remove("show"); }); }
    cScrim.innerHTML = '<div class="ax-modal"><div class="mic">' + IC.warn + '</div><div class="mt">' + esc(title) + '</div><div class="ms">' + esc(sub) + '</div><div class="mb"><button class="keep" id="scKeep">Keep</button><button class="go" id="scGo">' + esc(go) + '</button></div></div>';
    onGo = cb;
    $("#scKeep", cScrim).addEventListener("click", function () { cScrim.classList.remove("show"); });
    $("#scGo", cScrim).addEventListener("click", function () { cScrim.classList.remove("show"); if (onGo) onGo(); });
    requestAnimationFrame(function () { cScrim.classList.add("show"); });
  }

  var IC = {
    shieldWarn: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3 5 6v5c0 4.5 3 8 7 9 4-1 7-4.5 7-9V6l-7-3Z"/><path d="M12 9v3M12 15h.01"/></svg>',
    shieldOk: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3 5 6v5c0 4.5 3 8 7 9 4-1 7-4.5 7-9V6l-7-3Z"/><path d="m9.5 12 1.8 1.8L15 10"/></svg>',
    shieldOff: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3 5 6v5c0 4.5 3 8 7 9 4-1 7-4.5 7-9V6l-7-3Z"/><path d="m9.5 9.5 5 5M14.5 9.5l-5 5"/></svg>',
    shield: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3 5 6v5c0 4.5 3 8 7 9 4-1 7-4.5 7-9V6l-7-3Z"/><path d="m9.5 12 1.8 1.8L15 10"/></svg>',
    info: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="M12 11v5M12 8h.01"/></svg>',
    edit: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M11 4H5a2 2 0 0 0-2 2v13a2 2 0 0 0 2 2h13a2 2 0 0 0 2-2v-6"/><path d="M18.5 2.5a2.12 2.12 0 0 1 3 3L12 15l-4 1 1-4Z"/></svg>',
    qr: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="3" width="7" height="7" rx="1"/><rect x="14" y="3" width="7" height="7" rx="1"/><rect x="3" y="14" width="7" height="7" rx="1"/><path d="M14 14h3v3M20 14v.01M14 20h.01M17.5 20h.01M20 17v3"/></svg>',
    search: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><circle cx="11" cy="11" r="7"/><path d="M21 21l-4.3-4.3"/></svg>',
    list: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M8 6h13M8 12h13M8 18h13M3 6h.01M3 12h.01M3 18h.01"/></svg>',
    lock: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="5" y="10" width="14" height="10" rx="2.5"/><path d="M8 10V7a4 4 0 0 1 8 0v3"/></svg>',
    check: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="m5 12 4 4 10-11"/></svg>',
    refresh: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 12a9 9 0 1 1-3-6.7L21 8M21 3v5h-5"/></svg>',
    cal: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="5" width="18" height="16" rx="2.5"/><path d="M3 10h18M8 3v4M16 3v4"/></svg>',
    download: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 4v10m0 0 4-4m-4 4-4-4M5 19h14"/></svg>',
    x: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M18 6 6 18M6 6l12 12"/></svg>',
    copy: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="9" y="9" width="12" height="12" rx="2.5"/><path d="M5 15V5a2 2 0 0 1 2-2h8"/></svg>',
    warn: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 9v4M12 17h.01"/><path d="M10.3 3.9 2 19a2 2 0 0 0 1.7 3h16.6a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0Z"/></svg>'
  };

  render();
  window.__security = {
    render: render,
    enabled: function () { return !!st.enabled; },
    device: function () { return st.device || ""; },
    backupsLeft: function () { return (st.backups || []).length; },
    /* verify a live 6-digit TOTP from the user's authenticator (±1 step skew) */
    verifyCode: function (code) {
      code = (code || "").replace(/\D/g, "");
      if (!st.enabled || !st.secret || code.length !== 6) return Promise.resolve(false);
      var counter = Math.floor(Date.now() / 1000 / 30);
      return Promise.all([totp(st.secret, counter - 1), totp(st.secret, counter), totp(st.secret, counter + 1)])
        .then(function (cs) { return cs.indexOf(code) > -1; }).catch(function () { return false; });
    },
    /* one-time backup code — consumed on success */
    verifyBackup: function (code) {
      code = (code || "").trim().toLowerCase();
      var list = (st.backups || []).map(function (c) { return c.toLowerCase(); });
      var i = list.indexOf(code);
      if (i > -1) { st.backups.splice(i, 1); save(); return true; }
      return false;
    }
  };
})();
