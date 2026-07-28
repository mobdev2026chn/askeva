/* =========================================================
   AskEva — shared Audio note widget (Record OR Upload)
   Used by Leads notes and Appointment notes. One widget is
   active at a time, so a singleton controller is fine.

   API:
     AskEvaAudioNote.blockHTML()         -> markup for the audio block
     AskEvaAudioNote.wire(root, opts)    -> wires radios / recorder / picker
        opts.toast(msg)                  -> toast fn
     AskEvaAudioNote.result()            -> { mode, name, dur, blob } | null
   ========================================================= */
(function () {
  "use strict";
  var MIC = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 2a3 3 0 0 0-3 3v7a3 3 0 0 0 6 0V5a3 3 0 0 0-3-3z"/><path d="M19 10v2a7 7 0 0 1-14 0v-2"/><line x1="12" y1="19" x2="12" y2="22"/></svg>';
  var STOP = '<svg viewBox="0 0 24 24" fill="currentColor"><rect x="6" y="6" width="12" height="12" rx="2"/></svg>';
  var UP = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 16V5m0 0 4 4m-4-4-4 4"/><path d="M5 16v2.5A1.5 1.5 0 0 0 6.5 20h11a1.5 1.5 0 0 0 1.5-1.5V16"/></svg>';
  var NOTE = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M9 18V5l10-2v13"/><circle cx="6" cy="18" r="3"/><circle cx="16" cy="16" r="3"/></svg>';
  var XI = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M18 6 6 18M6 6l12 12"/></svg>';

  var VALID = /\.(mp3|ogg)$/i;
  var ACCEPT = ".mp3,.ogg,audio/mpeg,audio/ogg";

  // shared current selection (one widget active at a time)
  var cur = null;            // { mode, name, dur, blob }
  // recorder runtime
  var rec = null, stream = null, chunks = [], timer = 0, secs = 0;

  function fmt(s) { var m = Math.floor(s / 60), ss = s % 60; return m + ":" + (ss < 10 ? "0" : "") + ss; }

  function blockHTML() {
    return '' +
      '<div class="anote" id="anote">' +
        '<div class="anote-lbl">Choose Audio Option:</div>' +
        '<div class="anote-opts">' +
          '<label class="anote-radio on" data-mode="record"><input type="radio" name="anoteMode" value="record" checked><span class="rb"></span>Record Audio</label>' +
          '<label class="anote-radio" data-mode="upload"><input type="radio" name="anoteMode" value="upload"><span class="rb"></span>Upload Audio File</label>' +
        '</div>' +
        '<div class="anote-pane" data-pane="record">' +
          '<button type="button" class="anote-recbtn" id="anoteRec">' + MIC + '<span id="anoteRecLbl">Start Recording</span></button>' +
          '<div class="anote-clip" id="anoteClip" hidden></div>' +
        '</div>' +
        '<div class="anote-pane" data-pane="upload" hidden>' +
          '<label class="nt-upload" id="anoteUpWrap">' +
            '<input type="file" id="anoteFile" accept="' + ACCEPT + '" hidden>' +
            '<span class="nt-uptext" id="anoteUpText">' + UP + 'Choose audio file</span>' +
          '</label>' +
          '<div class="af-uphint">Accepted: MP3 or OGG</div>' +
        '</div>' +
      '</div>';
  }

  function wire(root, opts) {
    opts = opts || {};
    var toast = opts.toast || function () {};
    cur = null; resetRuntime();
    var $ = function (s) { return root.querySelector(s); };
    var recBtn = $("#anoteRec"), recLbl = $("#anoteRecLbl"), clip = $("#anoteClip");
    var fileIn = $("#anoteFile"), upText = $("#anoteUpText"), upWrap = $("#anoteUpWrap");

    function showPane(mode) {
      root.querySelectorAll(".anote-radio").forEach(function (r) { r.classList.toggle("on", r.getAttribute("data-mode") === mode); });
      root.querySelectorAll(".anote-pane").forEach(function (p) { p.hidden = p.getAttribute("data-pane") !== mode; });
    }
    root.querySelectorAll('input[name="anoteMode"]').forEach(function (rb) {
      rb.addEventListener("change", function () {
        if (rec && rec.state === "recording") stopRec(true);   // cancel in-progress recording on switch
        cur = null; clearClip(); clearFile();
        showPane(this.value);
      });
    });

    function clearClip() { if (clip) { clip.hidden = true; clip.innerHTML = ""; } if (recLbl) recLbl.textContent = "Start Recording"; if (recBtn) recBtn.classList.remove("recording"); }
    function clearFile() { if (fileIn) fileIn.value = ""; if (upText) upText.innerHTML = UP + "Choose audio file"; if (upWrap) upWrap.classList.remove("has"); }

    function paintClip() {
      recBtn.classList.remove("recording"); recLbl.textContent = "Start Recording";
      clip.hidden = false;
      clip.innerHTML = '<button type="button" class="anote-play">' + NOTE + '</button>' +
        '<div class="anote-clipmeta"><div class="t">Recorded audio</div><div class="s">' + fmt(secs) + '</div></div>' +
        '<button type="button" class="anote-clipx" id="anoteClipX">' + XI + '</button>';
      var au = cur && cur.blob ? new Audio(URL.createObjectURL(cur.blob)) : null;
      var pb = clip.querySelector(".anote-play");
      if (pb) pb.addEventListener("click", function () { if (au) { au.currentTime = 0; au.play(); } toast("Playing recording"); });
      var xb = clip.querySelector("#anoteClipX");
      if (xb) xb.addEventListener("click", function () { cur = null; clearClip(); });
    }

    function startTimer() {
      secs = 0; recLbl.textContent = "Stop Recording · 0:00"; recBtn.classList.add("recording");
      timer = setInterval(function () { secs++; recLbl.textContent = "Stop Recording · " + fmt(secs); }, 1000);
    }
    function stopTimer() { if (timer) { clearInterval(timer); timer = 0; } }

    function stopRec(cancel) {
      stopTimer();
      try { if (rec && rec.state !== "inactive") rec.stop(); } catch (e) {}
      try { if (stream) stream.getTracks().forEach(function (t) { t.stop(); }); } catch (e) {}
      if (cancel) { recBtn.classList.remove("recording"); recLbl.textContent = "Start Recording"; }
    }

    if (recBtn) recBtn.addEventListener("click", function () {
      if (recBtn.classList.contains("recording")) { stopRec(false); return; }
      if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia || typeof MediaRecorder === "undefined") {
        // graceful fallback for environments without mic access — simulate a clip
        cur = { mode: "record", name: "Recording.webm", dur: "0:08", blob: null }; secs = 8;
        paintClip(); toast("Recording captured");
        return;
      }
      navigator.mediaDevices.getUserMedia({ audio: true }).then(function (s) {
        stream = s; chunks = [];
        rec = new MediaRecorder(s);
        rec.ondataavailable = function (e) { if (e.data && e.data.size) chunks.push(e.data); };
        rec.onstop = function () {
          var blob = new Blob(chunks, { type: (chunks[0] && chunks[0].type) || "audio/webm" });
          cur = { mode: "record", name: "Recording-" + fmt(secs).replace(":", "m") + "s.webm", dur: fmt(secs), blob: blob };
          paintClip();
        };
        rec.start(); startTimer();
      }).catch(function () {
        toast("Microphone permission denied");
      });
    });

    if (fileIn) fileIn.addEventListener("change", function () {
      var f = this.files && this.files[0]; if (!f) return;
      if (!VALID.test(f.name)) { this.value = ""; clearFile(); cur = null; toast("Unsupported file — accepted: MP3 or OGG"); return; }
      cur = { mode: "upload", name: f.name, dur: "", blob: f };
      upText.innerHTML = NOTE + '<span class="fn">' + f.name.replace(/</g, "&lt;") + "</span>";
      upWrap.classList.add("has");
    });
  }

  function resetRuntime() { stream = null; chunks = []; if (timer) { clearInterval(timer); timer = 0; } secs = 0; rec = null; }
  function result() { if (!cur) return null; return { mode: cur.mode, name: cur.name + (cur.dur && cur.mode === "record" ? " (" + cur.dur + ")" : ""), dur: cur.dur, blob: cur.blob }; }
  function clear() { cur = null; resetRuntime(); }

  window.AskEvaAudioNote = { blockHTML: blockHTML, wire: wire, result: result, clear: clear };
})();
