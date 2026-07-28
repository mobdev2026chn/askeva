/* =========================================================
   AskEva — Functional chat interactions (vanilla JS)
   Composer, message engine, emoji, attachments, sub-panels,
   camera, header menu, chat-list navigation.
   ========================================================= */
(function () {
  "use strict";

  const $  = (s, r) => (r || document).querySelector(s);
  const $$ = (s, r) => Array.from((r || document).querySelectorAll(s));
  const esc = (s) => String(s).replace(/[&<>"']/g, (c) => ({ "&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;" }[c]));

  /* ---- shared toast (reuse profile.js toast element) ---- */
  let toastT;
  function toast(msg) {
    const t = $("#toast"); if (!t) return;
    t.textContent = msg;
    t.style.opacity = "1";
    t.style.transform = "translateX(-50%) translateY(0)";
    clearTimeout(toastT);
    toastT = setTimeout(() => { t.style.opacity = "0"; t.style.transform = "translateX(-50%) translateY(20px)"; }, 1900);
  }

  /* ---- time helper ---- */
  function nowTime() {
    const o = new Date();
    const d = new Date(o.getTime() + (o.getTimezoneOffset() + 330) * 60000); // IST (GMT+5:30)
    let h = d.getHours(); const m = String(d.getMinutes()).padStart(2, "0");
    const ap = h >= 12 ? "pm" : "am"; h = h % 12 || 12;
    return h + ":" + m + " " + ap;
  }

  /* ---- icon strings ---- */
  const I = {
    payCard: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="5" width="18" height="14" rx="2.5"/><path d="M3 10h18M7 15h4"/></svg>',
    starFilled: '<svg viewBox="0 0 24 24" fill="currentColor" stroke="currentColor" stroke-width="1.5" stroke-linejoin="round"><path d="m12 3 2.7 5.4 6 .9-4.3 4.2 1 6-5.4-2.8L6.6 19.5l1-6L3.3 9.3l6-.9z"/></svg>',
    starOutline: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linejoin="round" stroke-linecap="round"><path d="m12 3 2.7 5.4 6 .9-4.3 4.2 1 6-5.4-2.8L6.6 19.5l1-6L3.3 9.3l6-.9z"/></svg>',
    checkOne: '<svg viewBox="0 0 18 13" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M2 7l4 4 8-9"/></svg>',
    clock:    '<svg viewBox="0 0 18 13" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><circle cx="9" cy="6.5" r="5"/><path d="M9 3.6v3l2 1.4"/></svg>',
    bangTick: '<svg viewBox="0 0 18 13" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><circle cx="9" cy="6.5" r="5"/><path d="M9 4v3.2M9 9.2v.2"/></svg>',
    checkTwo: '<svg viewBox="0 0 18 13" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M1 7l3.5 3.5L11 2"/><path d="M7 10.5L8 11.5 16 2.5"/></svg>',
    play:     '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M8 5v14l11-7z"/></svg>',
    pin:      '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M14 4l6 6-3 1-3 3-1 5-3-3-4 4 4-4-3-3 5-1 3-3z"/></svg>',
    cam:      '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M9 4l-1.5 2H4a2 2 0 0 0-2 2v10a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2V8a2 2 0 0 0-2-2h-3.5L15 4z"/><circle cx="12" cy="13" r="3.4" fill="#0a0a0a"/></svg>',
    check:    '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><path d="M20 6L9 17l-5-5"/></svg>',
    back:     '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M15 18l-6-6 6-6"/></svg>',
    pinSmall: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M14 3l7 7-2.5.9-2.6 2.6L15 19l-2.7-2.7L8 20l4.3-4.3L9.5 13l5-2.4L17 8z"/></svg>',
    cameraSm: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M9 4l-1.4 2H4a2 2 0 0 0-2 2v10a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2V8a2 2 0 0 0-2-2h-3.6L15 4z"/><circle cx="12" cy="13" r="3.4"/></svg>',
    stickerSm: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14 3H7a3 3 0 0 0-3 3v12a3 3 0 0 0 3 3h7l6-6V6a3 3 0 0 0-3-3Z"/><path d="M14 21v-4a2 2 0 0 1 2-2h4"/><path d="M8.5 13c.7 1 1.9 1.6 3 1.6s2.3-.6 3-1.6"/></svg>',
    micSm: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="9" y="3" width="6" height="11" rx="3"/><path d="M5 11a7 7 0 0 0 14 0M12 18v3"/></svg>',
    docSm: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 2h8l4 4v16H6z"/><path d="M14 2v4h4M9 13h6M9 17h6"/></svg>',
  };
  const tickHTML = (state) =>
    '<span class="tick ' + (state === "read" ? "read" : "sent") + '">' + (state === "sent1" ? I.checkOne : I.checkTwo) + "</span>";

  /* =========================================================
     STATE — contacts / conversations
     ========================================================= */
  const PALETTE = ["#7C5CFF","#FF6B6B","#22B0E8","#FF9416","#1FA84A","#E5499A","#5B7CFF","#8C7BFF"];
  function avColor(i) { return PALETTE[i % PALETTE.length]; }

  const CONTACTS = [
    { id:"aarav", name:"Aarav Mehta", init:"AM", color:"var(--eva-gradient)", grad:true, status:"online",
      preview:"Done! I'll send the payment link now.", time:"12:20 pm", unread:0,
      thread:[
        { day:"TODAY" },
        { dir:"in",  type:"text", text:"Hi! I'd like to know today's burger combos 🍔", time:"12:09 pm" },
        { dir:"out", type:"text", text:"Hey Aarav 👋 Welcome to Burger Street! Here's our combo menu for today.", time:"12:10 pm", tick:"read" },
        { dir:"in",  type:"text", text:"Great, can I order the Double Smash combo?", time:"12:14 pm" },
        { dir:"out", type:"text", text:"Absolutely! Want me to add fries and a drink?", time:"12:15 pm", tick:"read" },
        { dir:"in",  type:"text", text:"Yes please, and a cola.", time:"12:18 pm" },
        { dir:"out", type:"text", text:"Done! Here's your order — tap Review and pay to confirm.", time:"12:20 pm", tick:"read" },
        { dir:"out", type:"order", orderId:"ev4471", shipping:100, biz:"Tunepath Technologies", paid:false, time:"12:20 pm", tick:"read",
          items:[ { name:"Double Smash Combo", price:349, qty:1 }, { name:"Loaded Fries", price:149, qty:1 }, { name:"Cola (500 ml)", price:60, qty:1 } ] },
      ]},
    { id:"priya", name:"Priya Nair", init:"PN", status:"last seen recently",
      preview:"Perfect, thanks a ton! 🙏", time:"11:48 am", unread:0, pinned:false,
      thread:[
        { day:"YESTERDAY" },
        { dir:"in",  type:"text", text:"Hi, is the festive catalog ready to publish?", time:"4:21 pm" },
        { dir:"out", type:"text", text:"Almost — final pricing review pending. Should be live by tomorrow morning.", time:"4:30 pm", tick:"read" },
        { dir:"in",  type:"text", text:"Got it, thanks for the update!", time:"4:32 pm" },
        { day:"TODAY" },
        { dir:"in",  type:"text", text:"Morning! Did the new catalog go live?", time:"11:40 am" },
        { dir:"out", type:"text", text:"Yes, pushed it 10 mins ago ✅", time:"11:44 am", tick:"read" },
        { dir:"out", type:"text", text:"You can see all 24 products under the Festive tab.", time:"11:45 am", tick:"read" },
        { dir:"in",  type:"text", text:"Perfect, thanks a ton! 🙏", time:"11:48 am" } ] },
    { id:"rohan", name:"Rohan Das", init:"RD", status:"online",
      preview:"Good morning 🤝", time:"8:54 am", unread:0, pinned:false,
      thread:[
        { day:"YESTERDAY" },
        { dir:"in",  type:"text", text:"Hey, can we reschedule today's demo to tomorrow?", time:"2:10 pm" },
        { dir:"out", type:"text", text:"Sure Rohan, does 11 am tomorrow work?", time:"2:14 pm", tick:"read" },
        { dir:"in",  type:"text", text:"11 am is perfect. See you then.", time:"2:16 pm" },
        { dir:"out", type:"text", text:"Booked ✅ I'll send a reminder in the morning.", time:"2:17 pm", tick:"read" },
        { day:"TODAY" },
        { dir:"out", type:"text", text:"Morning! Reminder for our 11 am demo today 🙂", time:"8:50 am", tick:"read" },
        { dir:"in",  type:"text", text:"Good morning 🤝", time:"8:54 am" } ] },
    { id:"sneha", name:"Sneha Iyer", init:"SI", status:"typing…",
      preview:"Nee enna panra", time:"5:02 pm", unread:2, pinned:false,
      thread:[
        { day:"TODAY" },
        { dir:"in",  type:"text", text:"Customer escalation on order #4471", time:"4:58 pm" },
        { dir:"out", type:"text", text:"Looking into it now. What's the issue exactly?", time:"4:59 pm", tick:"read" },
        { dir:"in",  type:"text", text:"Delivery delayed by 2 days, customer is upset.", time:"5:00 pm" },
        { dir:"out", type:"text", text:"Got it, I'll call the courier and update you in 10 mins.", time:"5:01 pm", tick:"delivered" },
        { dir:"in",  type:"text", text:"Nee enna panra", time:"5:02 pm" } ] },
    { id:"vikram", name:"Vikram Joshi", init:"VJ", status:"last seen today at 4:59 pm",
      preview:"Senior thaan", time:"4:59 pm", unread:1, pinned:false,
      thread:[
        { day:"YESTERDAY" },
        { dir:"in",  type:"text", text:"Can you approve my leave for Friday?", time:"6:40 pm" },
        { dir:"out", type:"text", text:"Approved 👍 Make sure to hand over the open tickets.", time:"6:52 pm", tick:"read" },
        { dir:"in",  type:"text", text:"Done, handed over to Madhan.", time:"6:55 pm" },
        { day:"TODAY" },
        { dir:"out", type:"text", text:"Who's covering the evening shift today?", time:"4:55 pm", tick:"read" },
        { dir:"in",  type:"text", text:"Senior thaan", time:"4:59 pm" } ] },
    { id:"team", name:"Burger Street · Team", init:"BS", color:"#FF9416", status:"6 members",
      preview:"Shift roster updated for the weekend.", time:"Yesterday", unread:0, pinned:false,
      thread:[
        { day:"MONDAY" },
        { dir:"in",  type:"text", text:"Reminder: inventory count this Friday before close.", time:"10:02 am" },
        { dir:"out", type:"text", text:"Noted. I'll prep the count sheets.", time:"10:15 am", tick:"read" },
        { day:"YESTERDAY" },
        { dir:"in",  type:"text", text:"New combo pricing is approved 🎉", time:"5:48 pm" },
        { dir:"in",  type:"text", text:"Shift roster updated for the weekend.", time:"6:12 pm" } ] },

    /* --- DUMMY HISTORY CHATS (temporary, for testing the History tab) --- */
    { id:"hist_meera", name:"Meera Krishnan", init:"MK", status:"last seen 15 May",
      preview:"Thank you, received the invoice!", time:"15 May", unread:0, pinned:false,
      thread:[
        { day:"15 MAY 2026" },
        { dir:"in",  type:"text", text:"Hi, could you share the invoice for last month's order?", time:"10:05 am" },
        { dir:"out", type:"text", text:"Sure Meera, sending it across now 📄", time:"10:11 am", tick:"read" },
        { dir:"out", type:"doc",  fileName:"Invoice-APR-2026.pdf", fileSize:"86 KB", time:"10:11 am", tick:"read" },
        { dir:"in",  type:"text", text:"Thank you, received the invoice!", time:"10:14 am" } ] },
    { id:"hist_arjun", name:"Arjun Reddy", init:"AR", status:"last seen 9 May",
      preview:"Great, I'll place the order then.", time:"9 May", unread:0, pinned:false,
      thread:[
        { day:"9 MAY 2026" },
        { dir:"in",  type:"text", text:"Do you have the 2kg combo pack in stock?", time:"2:40 pm" },
        { dir:"out", type:"text", text:"Yes, in stock! ₹899 with free delivery.", time:"2:43 pm", tick:"read" },
        { dir:"in",  type:"text", text:"Great, I'll place the order then.", time:"2:46 pm" } ] },
    { id:"hist_fatima", name:"Fatima Sheikh", init:"FS", status:"last seen 2 May",
      preview:"Perfect, see you on Saturday.", time:"2 May", unread:0, pinned:false,
      thread:[
        { day:"2 MAY 2026" },
        { dir:"in",  type:"text", text:"Can I book a tasting session for the weekend?", time:"5:20 pm" },
        { dir:"out", type:"text", text:"Absolutely! Saturday 4 pm works for us 🙂", time:"5:25 pm", tick:"read" },
        { dir:"in",  type:"text", text:"Perfect, see you on Saturday.", time:"5:27 pm" } ] },
  ];
  let current = CONTACTS[0];
  let listFilter = "all";
  let listQuery = "";   // chat-list search text
  let pickTag = "";     // active Tags-filter selection
  let pickAgent = "";   // active Agents-filter selection (agent name)

  /* ---- per-contact CRM state (agents / tags / intervened / prospect / logs),
     persisted so a refresh keeps it. Single source of truth, shared with the
     Profile drawer through window.__chat. ---- */
  const CSTATE_KEY = "askeva.chat.cstate.v1";
  function loadCState() { try { return JSON.parse(localStorage.getItem(CSTATE_KEY)) || {}; } catch (e) { return {}; } }
  function saveCState() {
    const out = {};
    CONTACTS.forEach((c) => { out[c.id] = { agents: c.agents || [], tags: c.tags || [], intervened: !!c.intervened, prospect: !!c.prospect, logs: c.logs || [], leadStatus: c.leadStatus || "active", statusLogs: c.statusLogs || [], lastTs: c.lastTs || Date.now() }; });
    try { localStorage.setItem(CSTATE_KEY, JSON.stringify(out)); } catch (e) {}
  }
  function hasThread(c) { return (c.thread || []).some((m) => m.dir); }
  function matchFilter(c) {
    switch (listFilter) {
      case "unread":     return c.unread > 0;
      case "read":       return !c.unread && hasThread(c);
      case "groups":     return !!c.group || /member/i.test(c.status || "") || /team/i.test(c.name || "");
      case "intervened": return !!c.intervened;
      case "prospects":  return !!c.prospect;
      case "addlead":    return c.leadStatus === "addlead";
      case "activelead": return c.leadStatus === "active";
      case "customers":  return c.leadStatus === "customer";
      case "tags":       return pickTag ? (c.tags || []).some((t) => t.toLowerCase() === pickTag.toLowerCase()) : true;
      case "agents":     return pickAgent ? (c.agents || []).some((a) => a.toLowerCase() === pickAgent.toLowerCase()) : true;
      default:           return true;
    }
  }
  const LS_LABEL = { addlead: "Add to Leads", active: "Active Lead", customer: "Customer" };
  function matchQuery(c) {
    const q = listQuery.trim().toLowerCase();
    if (!q) return true;
    if ((c.name || "").toLowerCase().indexOf(q) > -1) return true;
    if (String(c.phone || "").toLowerCase().indexOf(q) > -1) return true;
    if ((c.preview || "").toLowerCase().indexOf(q) > -1) return true;
    if ((c.tags || []).some((t) => t.toLowerCase().indexOf(q) > -1)) return true;
    if ((c.agents || []).some((a) => a.toLowerCase().indexOf(q) > -1)) return true;
    if ((LS_LABEL[c.leadStatus] || "").toLowerCase().indexOf(q) > -1) return true;
    return false;
  }

  // assign colors to non-grad avatars
  CONTACTS.forEach((c, i) => { if (!c.color) c.color = avColor(i); });

  /* seed per-contact CRM state, then overlay anything persisted from a prior session */
  const CSEED = {
    aarav:  { agents: ["Madhan"],    tags: ["VIP", "Combo"], intervened: false, prospect: false, leadStatus: "customer" },
    priya:  { agents: ["Eshan Rao"], tags: ["Catalog"],     intervened: false, prospect: true,  leadStatus: "active"   },
    rohan:  { agents: [],            tags: ["New"],         intervened: false, prospect: true,  leadStatus: "active"   },
    sneha:  { agents: ["Kavya S"],   tags: ["Escalation"],  intervened: true,  prospect: false, leadStatus: "active"   },
    vikram: { agents: ["Dev Patel"], tags: ["Senior"],      intervened: false, prospect: true,  leadStatus: "addlead"  },
    team:   { agents: ["Eshan Rao"], tags: [],              intervened: false, prospect: false, leadStatus: "active", histChat: true },
    /* dummy history chats (temporary) */
    hist_meera:  { agents: ["Madhan"],    tags: ["Invoice"], intervened: false, prospect: false, leadStatus: "customer", histChat: true },
    hist_arjun:  { agents: ["Eshan Rao"], tags: ["Combo"],   intervened: false, prospect: true,  leadStatus: "active",   histChat: true },
    hist_fatima: { agents: ["Kavya S"],   tags: ["Tasting"], intervened: false, prospect: true,  leadStatus: "active",   histChat: true }
  };
  /* older-than-24h conversation, surfaced under the History tab */
  const HIST = {
    aarav: [
      { day: "12 MAY 2026" },
      { dir: "in",  type: "text", text: "Hi, do you deliver to Indiranagar?", time: "6:40 pm" },
      { dir: "out", type: "text", text: "Yes we do! Orders above \u20B9199 ship free.", time: "6:42 pm", tick: "read", ai: true },
      { dir: "in",  type: "text", text: "Perfect, will order this weekend.", time: "6:45 pm" }
    ],
    sneha: [
      { day: "28 APR 2026" },
      { dir: "in",  type: "text", text: "My last order was delayed.", time: "3:10 pm" },
      { dir: "out", type: "text", text: "Apologies for that \u2014 I\u2019ve escalated it to our team.", time: "3:14 pm", tick: "read" }
    ]
  };
  function firstMsgIncoming(c) { const m = (c.thread || []).find((x) => x.dir); return !!(m && m.dir === "in"); }
  (function seedCState() {
    const saved = loadCState();
    CONTACTS.forEach((c) => {
      const sd = CSEED[c.id] || {}, pv = saved[c.id] || {};
      c.agents = pv.agents || sd.agents || [];
      c.tags = pv.tags || sd.tags || [];
      c.intervened = pv.intervened != null ? pv.intervened : !!sd.intervened;
      c.prospect = pv.prospect != null ? pv.prospect : !!sd.prospect;
      c.logs = pv.logs || [];
      c.leadStatus = pv.leadStatus || sd.leadStatus || (firstMsgIncoming(c) ? "active" : "addlead");
      c.statusLogs = pv.statusLogs || [];
      c.history = HIST[c.id] || c.history || [];
      c.lastTs = pv.lastTs != null ? pv.lastTs : (sd.histChat ? Date.now() - 48 * 3600 * 1000 : Date.now() - (3 + Math.floor(Math.random() * 120)) * 60000);
    });
  })();

  /* =========================================================
     MESSAGE ENGINE
     ========================================================= */
  const scrollEl = () => $("#chatScroll");
  function scrollToBottom(smooth) {
    const s = scrollEl(); if (!s) return;
    s.scrollTo({ top: s.scrollHeight, behavior: smooth ? "smooth" : "auto" });
  }

  function metaHTML(time, dir, tick) {
    if (dir === "out") return '<div class="meta">' + time + " " + tickHTML(tick || "read") + "</div>";
    return '<div class="meta">' + time + "</div>";
  }

  function bubbleInner(m) {
    const time = m.time || nowTime();
    switch (m.type) {
      case "payment": {
        const amt = "\u20B9 " + Math.round(m.amount).toLocaleString("en-IN");
        const paid = m.paid;
        return '<div class="pay-msg' + (paid ? " paid" : "") + '">' +
          '<div class="pm-top"><span class="pm-ic">' + I.payCard + '</span>' +
          '<div class="pm-tt"><div class="t">Payment request</div><div class="s">' + esc(m.note || "AskEva secure checkout") + '</div></div></div>' +
          '<div class="pm-amt">' + amt + '</div>' +
          '<button class="pm-btn" data-pay-link' + (paid ? " disabled" : "") + '>' + (paid ? I.checkOne + " Paid" : "Pay " + amt) + '</button>' +
          '</div>' + metaHTML(time, m.dir, m.tick);
      }
      case "order": {
        const oItems = m.items || [];
        const oCount = oItems.reduce((s, it) => s + (it.qty || 1), 0);
        const oSub = oItems.reduce((s, it) => s + it.price * (it.qty || 1), 0);
        const oTotal = oSub + (m.shipping || 0);
        const inr = (n) => "\u20B9" + Number(n).toFixed(2);
        const first = oItems[0] || { name: "Order", qty: 1 };
        const nameLine = first.name + (oItems.length > 1 ? " +" + (oItems.length - 1) + " more" : "");
        const itemLbl = oCount + (oCount === 1 ? " item" : " items");
        return '<div class="order-msg' + (m.paid ? " paid" : "") + '">' +
          '<div class="om-banner"><img src="assets/askeva-logo-white.png" alt="AskEva"></div>' +
          '<div class="om-body">' +
            '<div class="om-id">ORDER #' + esc((m.orderId || "order").toUpperCase()) + '</div>' +
            '<div class="om-item"><span class="om-thumb"><img src="assets/askeva-logo-white.png" alt=""></span>' +
              '<div><div class="nm">' + esc(nameLine) + '</div><div class="qt">' + itemLbl + '</div></div></div>' +
            '<div class="om-div"></div>' +
            '<div class="om-total"><span class="l">Total</span><span class="v">' + inr(oTotal) + '</span></div>' +
            '<div class="om-acts">' +
              '<button class="om-btn" data-order-review>Review and pay</button>' +
              '<button class="om-btn" data-order-pay>Pay now</button>' +
            '</div>' +
            '<div class="om-paid">' + I.checkOne + ' Paid \u00b7 ' + inr(oTotal) + '</div>' +
          '</div></div>' + metaHTML(time, m.dir, m.tick);
      }
      case "feedback": {
        const FB_TAGS = ["On time", "Friendly", "Knowledgeable", "Clear advice", "Would recommend"];
        if (m.submitted) {
          let fs = "";
          for (let i = 1; i <= 5; i++) fs += '<span class="fb-star ro' + (i <= m.rating ? " on" : "") + '">' + (i <= m.rating ? I.starFilled : I.starOutline) + '</span>';
          const tg = (m.tagsSel && m.tagsSel.length) ? '<div class="fb-tags ro">' + m.tagsSel.map((t) => '<span class="fb-chip on">' + esc(t) + '</span>').join("") + '</div>' : "";
          const cm = m.comment ? '<div class="fb-comment">“' + esc(m.comment) + '”</div>' : "";
          return '<div class="fb-msg done"><div class="fb-hd">' + I.starFilled + '<span>Thanks for your feedback!</span></div>' +
            '<div class="fb-stars ro">' + fs + '<span class="fb-num">' + m.rating + '/5</span></div>' + tg + cm +
            '</div>' + metaHTML(time, m.dir, m.tick);
        }
        let stars = "";
        for (let i = 1; i <= 5; i++) stars += '<button class="fb-star" data-star="' + i + '">' + I.starOutline + '</button>';
        const chips = FB_TAGS.map((t) => '<button class="fb-chip" data-tag="' + esc(t) + '">' + esc(t) + '</button>').join("");
        return '<div class="fb-msg"><div class="fb-hd">' + I.starOutline + '<span>How was your ' + (m.deptName ? esc(m.deptName) + " " : "") + 'appointment?</span></div>' +
          '<div class="fb-stars">' + stars + '</div>' +
          '<div class="fb-tags">' + chips + '</div>' +
          '<textarea class="fb-comment-in" data-fb-comment rows="2" placeholder="Add a comment (optional)"></textarea>' +
          '<button class="fb-submit" data-fb-submit disabled>Submit feedback</button>' +
          '</div>' + metaHTML(time, m.dir, m.tick);
      }
      case "text":
        return esc(m.text) + metaHTML(time, m.dir, m.tick);
      case "image":
      case "aiimage": {
        const lbl = m.type === "aiimage" ? "AI image" : "photo";
        const inner = m.src
          ? '<img class="ph-img" src="' + esc(m.src) + '" alt="' + esc(m.name || lbl) + '">'
          : '<span class="ph-stripe"><span class="lbl">' + (m.label || lbl) + '</span></span>';
        return '<span class="ph ' + (m.tall ? "tall" : "wide") + '">' + inner +
               metaHTML(time, m.dir, m.tick) + "</span>";
      }
      case "video":
        if (m.src) {
          return '<span class="ph wide vid"><video class="ph-img" src="' + esc(m.src) + '" controls preload="metadata"></video>' +
                 metaHTML(time, m.dir, m.tick) + "</span>";
        }
        return '<span class="ph wide"><span class="ph-stripe"><span class="lbl">video</span></span>' +
               '<span class="play">' + I.play + '</span>' +
               '<span class="vid-len">' + I.play + (m.len || "0:18") + "</span>" +
               metaHTML(time, m.dir, m.tick) + "</span>";
      case "voice": {
        const bars = Array.from({ length: 24 }, () => '<i style="height:' + (5 + Math.round(Math.random()*16)) + 'px"></i>').join("");
        return '<div class="voice"><button class="vplay">' + I.play + '</button>' +
               '<div class="wave">' + bars + '</div><span class="vdur">' + (m.len || "0:07") + "</span></div>" +
               metaHTML(time, m.dir, m.tick);
      }
      case "audiofile":
        return '<div class="afile"><button class="aplay">' + I.play + '</button>' +
               '<div class="afile-meta"><div class="t">' + esc(m.name || "Audio.mp3") + '</div>' +
               '<div class="s">' + esc(m.size || "—") + ' · ' + esc(m.len || "0:00") + '</div></div>' +
               '<span class="afile-ic"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M9 18V5l10-2v13"/><circle cx="6" cy="18" r="3"/><circle cx="16" cy="16" r="3"/></svg></span></div>' +
               metaHTML(time, m.dir, m.tick);
      case "location":
        return '<div class="loc-map"><span class="pin"><svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 2a7 7 0 0 0-7 7c0 5 7 13 7 13s7-8 7-13a7 7 0 0 0-7-7z"/><circle cx="12" cy="9" r="2.4" fill="#fff"/></svg></span></div>' +
               '<div class="loc-meta"><div class="t">' + esc(m.title || "Shared location") + '</div><div class="s">' + esc(m.sub || "Tap to open in Maps") + "</div></div>" +
               metaHTML(time, m.dir, m.tick);
      case "contact":
        return '<div class="cc-top"><div class="cc-av">' + esc(m.init || "?") + '</div>' +
               '<div><div class="cc-name">' + esc(m.name) + '</div><div class="cc-sub">' + esc(m.phone || "") + '</div></div></div>' +
               '<div class="cc-action">Message</div>' + metaHTML(time, m.dir, m.tick);
      case "document":
        return '<div class="doc-row"><div class="doc-ic">' + msLogo(m.kind || "pdf", 34) + '</div>' +
               '<div class="doc-meta"><div class="t">' + esc(m.name) + '</div><div class="s">' + esc(m.size || "—") + " · " + (m.ext || "pdf") + "</div></div></div>" +
               metaHTML(time, m.dir, m.tick);
      case "template": {
        const chips = (m.replies || []).map((r, i) => '<button class="tpl-qr" data-qr="' + i + '"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M9 17l-5-5 5-5M4 12h11a4 4 0 0 1 4 4v2"/></svg>' + esc(r) + "</button>").join("");
        return '<div class="tpl-head"><span class="tpl-ic"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="4" width="18" height="16" rx="2.5"/><path d="M3 9h18M7 13h7M7 16h4"/></svg></span><span class="tpl-name">' + esc(m.name || "Template") + '</span><span class="tpl-badge">' + esc(m.cat || "Template") + '</span></div>' +
          '<div class="tpl-body">' + esc(m.text) + '</div>' +
          (chips ? '<div class="tpl-qrs">' + chips + '</div>' : "") +
          metaHTML(time, m.dir, m.tick);
      }
      case "poll": {
        const opts = m.options.map((o, i) =>
          '<div class="poll-opt" data-opt="' + i + '"><span class="poll-bar"></span><div class="row">' +
          '<span class="poll-check">' + I.check + '</span><span class="txt">' + esc(o) + '</span><span class="pct"></span></div></div>'
        ).join("");
        return '<div class="poll-q">' + esc(m.q) + '</div><div class="poll-hint">' + (m.multi ? "Select one or more" : "Select one") + '</div>' +
               opts + '<div class="poll-foot">View votes</div>' + metaHTML(time, m.dir, m.tick);
      }
      case "event": {
        const dd = m.dateObj || {};
        return '<div class="ev-head"><div class="ev-cal"><div class="m">' + (dd.mon || "JUN") + '</div><div class="d">' + (dd.day || "10") + '</div></div>' +
               '<div class="ev-info"><div class="t">' + esc(m.title) + '</div>' +
               '<div class="s">📅 ' + esc(m.when || "") + '</div>' + (m.loc ? '<div class="s">📍 ' + esc(m.loc) + "</div>" : "") + "</div></div>" +
               '<div class="ev-actions"><button data-rsvp="yes">Going</button><button data-rsvp="maybe">Maybe</button><button data-rsvp="no">Can\'t go</button></div>' +
               metaHTML(time, m.dir, m.tick);
      }
      case "reminder": {
        var who = m.agent ? '<span class="rmb-for"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="8" r="3.4"/><path d="M5.5 20a6.5 6.5 0 0 1 13 0"/></svg>' + esc(m.agent) + '</span>' : "";
        var cust = m.customer ? '<span class="rmb-for"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 12a8 8 0 0 1-11.5 7.2L4 20.5l1.3-5.5A8 8 0 1 1 21 12Z"/></svg>' + esc(m.customer) + '</span>' : "";
        return '<div class="rmb"><div class="rmb-hd"><span class="rmb-ic"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M18 8a6 6 0 0 0-12 0c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.7 21a2 2 0 0 1-3.4 0"/></svg></span>Reminder set</div>' +
          '<div class="rmb-desc">' + esc(m.text || "") + '</div>' +
          '<div class="rmb-meta"><span class="rmb-when"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3.5 2"/></svg>' + esc(m.whenLabel || "") + '</span>' + who + cust + '</div></div>';
      }
      default: return esc(m.text || "");
    }
  }

  const typeClass = { text:"", image:"media", aiimage:"media", video:"media", voice:"voice-b", audiofile:"audiofile-b",
    location:"loc", contact:"contact", document:"doc", poll:"poll", event:"event", payment:"payment-b", feedback:"feedback-b", template:"template-b", reminder:"reminder-b", order:"order-b" };

  function addMessage(m) {
    const s = scrollEl(); if (!s) return null;
    const el = document.createElement("div");
    el.className = "bubble " + (m.type === "reminder" ? "system" : (m.dir === "out" ? "out" : "in")) + " " + (typeClass[m.type] || "") + (m.ai ? " ai-msg" : "");
    el.innerHTML = (m.ai ? '<span class="ai-by"><svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 2l1.9 4.7L19 8.3l-3.6 3.1 1 5.1L12 13.9 7.6 16.5l1-5.1L5 8.3l5.1-1.6z"/></svg>AskEva AI</span>' : "") + bubbleInner(m);
    s.appendChild(el);
    scrollToBottom(true);
    wireBubble(el, m);
    // animate ticks for fresh outgoing text/media
    if (m.dir === "out" && m.tick === undefined) animateTicks(el);
    // log only human agent messages sent during an active intervention
    if (m.dir === "out" && !m.ai && current && current.intervened) {
      try { if (window.AskEvaActivity) window.AskEvaActivity.log({ mobile: current.phone, name: current.name }, { type: "message", text: "Agent sent message \u00b7 " + actingAgent(), module: "Chat" }); } catch (e) {}
    }
    // any real (non-render) in/out message keeps the conversation Live (resets the 24h timer)
    if (!_rendering && current && (m.dir === "in" || m.dir === "out")) {
      const wasHistory = isHistory(current);
      current.lastTs = Date.now(); saveCState();
      if (wasHistory) renderList();
    }
    return el;
  }

  function setTickState(el, state) {
    const tick = $(".tick", el);
    if (!tick) return;
    el.classList.remove("msg-pending", "msg-failed");
    if (state === "sending") { tick.className = "tick sending"; tick.innerHTML = I.clock; el.classList.add("msg-pending"); }
    else if (state === "failed") { tick.className = "tick failed"; tick.innerHTML = I.bangTick; el.classList.add("msg-failed"); }
    else if (state === "sent") { tick.className = "tick sent"; tick.innerHTML = I.checkOne; }
    else if (state === "delivered") { tick.className = "tick sent"; tick.innerHTML = I.checkTwo; }
    else { tick.className = "tick read"; tick.innerHTML = I.checkTwo; }
  }

  function playTicks(el) {
    const tick = $(".tick", el);
    if (!tick) return;
    setTickState(el, "sent");                                          // sent
    setTimeout(() => setTickState(el, "delivered"), 700);             // delivered
    setTimeout(() => setTickState(el, "read"), 1600);                 // read
  }

  function animateTicks(el) {
    const tick = $(".tick", el);
    if (!tick) return;
    // Sync layer: while offline, hold the message as "Sending" and queue it
    // for delivery the moment connectivity returns.
    if (window.__sync && typeof window.__sync.isOffline === "function" && window.__sync.isOffline()) {
      setTickState(el, "sending");
      window.__sync.queueMessage(el, current ? current.name : "");
      return;
    }
    playTicks(el);
  }

  // exposed so the sync layer can drive message states (deliver on reconnect,
  // mark failed, retry) without re-implementing the tick glyphs.
  window.__chatTicks = { set: setTickState, play: playTicks };

  function wireBubble(el, m) {
    if (m.type === "template") {
      $$(".tpl-qr", el).forEach((b) => b.addEventListener("click", () => {
        if (b.disabled) return;
        const idx = parseInt(b.dataset.qr, 10);
        const txt = (m.replies || [])[idx] || "";
        $$(".tpl-qr", el).forEach((x) => { x.disabled = true; });
        b.classList.add("chosen");
        addMessage({ dir: "in", type: "text", text: txt, time: nowTime() });
        if (current) { current.preview = txt; current.time = nowTime(); renderList(); }
        if (current && !current.intervened) maybeAIHandle(true);
      }));
    }
    if (m.type === "poll") {
      $$(".poll-opt", el).forEach((opt) => {
        opt.addEventListener("click", () => votePoll(el, m, parseInt(opt.dataset.opt, 10)));
      });
      m._votes = m._votes || m.options.map(() => Math.floor(Math.random() * 3));
      renderPoll(el, m);
    }
    if (m.type === "event") {
      $$(".ev-actions button", el).forEach((b) => b.addEventListener("click", () => {
        $$(".ev-actions button", el).forEach((x) => x.classList.remove("on"));
        b.classList.add("on");
        toast("RSVP: " + b.textContent);
      }));
    }
    if (m.type === "voice") {
      const vp = $(".vplay", el);
      if (vp) vp.addEventListener("click", () => toast("Playing voice message"));
    }
    if (m.type === "audiofile") {
      const ap = $(".aplay", el);
      if (ap) ap.addEventListener("click", () => toast("Playing " + (m.name || "audio")));
    }
    if (m.type === "location") el.addEventListener("click", () => toast("Opening in Maps…"));
    if (m.type === "payment") {
      const pb = $("[data-pay-link]", el);
      if (pb) pb.addEventListener("click", () => {
        if (m.paid) return;
        if (window.__payGateway) {
          window.__payGateway(m.amount, {
            headNm: (current && current.name) || "Customer", headSub: "Invoice payment", totalLabel: "Amount due",
            success: function (amt) {
              const a = "\u20B9 " + Math.round(amt).toLocaleString("en-IN");
              return { bump: false,
                procT: "Processing payment…", procS: "Securely charging…",
                okT: "Payment Received", okS: a + " paid successfully",
                toast: "Payment of " + a + " received",
                onDone: function () {
                  m.paid = true; el.innerHTML = bubbleInner(m); wireBubble(el, m);
                  // sync the appointment + Payments tab
                  if (m.apptId && window.AX && AX.markApptPaid) { try { AX.markApptPaid(m.apptId); } catch (e) {} }
                  // once paid, automatically request feedback in this same chat
                  if (m.apptId) setTimeout(function () { sendFeedbackBubble({ apptId: m.apptId, deptName: m.deptName }); }, 850);
                } };
            }
          });
        } else { toast("Opening secure checkout…"); }
      });
    }
    if (m.type === "order") {
      const rv = $("[data-order-review]", el);
      const pn = $("[data-order-pay]", el);
      if (rv) rv.addEventListener("click", () => openOrderDetails(m, el));
      if (pn) pn.addEventListener("click", () => payOrder(m, el));
    }
    if (m.type === "feedback" && !m.submitted) {
      let rating = m.rating || 0;
      const tags = (m.tagsSel || []).slice();
      const sb = $("[data-fb-submit]", el);
      const paintStars = () => {
        $$("[data-star]", el).forEach((s) => {
          const v = parseInt(s.getAttribute("data-star"), 10);
          s.classList.toggle("on", v <= rating);
          s.innerHTML = v <= rating ? I.starFilled : I.starOutline;
        });
        if (sb) sb.disabled = rating < 1;
      };
      $$("[data-star]", el).forEach((s) => s.addEventListener("click", () => {
        rating = parseInt(s.getAttribute("data-star"), 10); paintStars();
      }));
      $$("[data-tag]", el).forEach((t) => t.addEventListener("click", () => {
        const v = t.getAttribute("data-tag"); const i = tags.indexOf(v);
        if (i > -1) { tags.splice(i, 1); t.classList.remove("on"); } else { tags.push(v); t.classList.add("on"); }
      }));
      if (sb) sb.addEventListener("click", () => {
        if (rating < 1) { toast("Please tap a star rating"); return; }
        const ci = $("[data-fb-comment]", el);
        m.rating = rating; m.tagsSel = tags.slice(); m.comment = ci ? ci.value.trim() : ""; m.submitted = true;
        el.innerHTML = bubbleInner(m); wireBubble(el, m);
        if (m.apptId && window.AX && AX.saveApptFeedback) { try { AX.saveApptFeedback(m.apptId, { rating: m.rating, tags: m.tagsSel, comment: m.comment }); } catch (e) {} }
        if (current) { current.preview = "Feedback · " + rating + "★"; current.time = nowTime(); renderList(); }
        toast("Thanks for your feedback!");
      });
      paintStars();
    }
  }

  /* append a feedback-request bubble into the current conversation */
  function sendFeedbackBubble(opts) {
    opts = opts || {};
    const fm = { dir: "out", type: "feedback", apptId: opts.apptId, deptName: opts.deptName || "", time: nowTime() };
    if (current) { current.thread = current.thread || []; current.thread.push(fm); current.preview = "Feedback request"; current.time = fm.time; }
    addMessage(fm);
    renderList();
    return fm;
  }

  function renderPoll(el, m) {
    const total = m._votes.reduce((a, b) => a + b, 0) || 1;
    $$(".poll-opt", el).forEach((opt, i) => {
      const v = m._votes[i];
      const pct = Math.round((v / total) * 100);
      $(".poll-bar", opt).style.width = pct + "%";
      $(".pct", opt).textContent = v ? pct + "%" : "";
    });
  }
  function votePoll(el, m, idx) {
    m._voted = m._voted || [];
    const opt = $$(".poll-opt", el)[idx];
    const had = m._voted.includes(idx);
    if (!m.multi) { m._voted.forEach((j) => { m._votes[j]--; $$(".poll-opt", el)[j].classList.remove("voted"); }); m._voted = []; }
    if (had) { m._votes[idx]--; m._voted = m._voted.filter((j) => j !== idx); opt.classList.remove("voted"); }
    else { m._votes[idx]++; m._voted.push(idx); opt.classList.add("voted"); }
    renderPoll(el, m);
  }

  /* ---------- typing indicator + auto reply ---------- */
  const REPLIES = [
    "Got it 👍", "Sure, one sec.", "Thanks for letting me know!", "Perfect, that works.",
    "Could you share a bit more detail?", "On it now.", "Sounds good 😊", "Let me check and get back to you.",
    "Appreciate it!", "Noted ✅",
  ];
  let typingEl = null;
  function showTyping() {
    if (typingEl) return;
    setHeaderStatus("typing…");
    const s = scrollEl(); if (!s) return;
    typingEl = document.createElement("div");
    typingEl.className = "bubble in";
    typingEl.innerHTML = '<div class="typing-dots"><span></span><span></span><span></span></div>';
    s.appendChild(typingEl); scrollToBottom(true);
  }
  function hideTyping() {
    if (typingEl) { typingEl.remove(); typingEl = null; }
    setHeaderStatus(current.status);
  }
  function autoReply(userText) {
    const delay = 900 + Math.random() * 900;
    setTimeout(() => {
      showTyping();
      setTimeout(() => {
        hideTyping();
        let r = REPLIES[Math.floor(Math.random() * REPLIES.length)];
        const t = userText.toLowerCase();
        if (/hi|hello|hey/.test(t)) r = "Hey! How can I help? 👋";
        else if (/price|cost|how much|₹/.test(t)) r = "Sharing the latest pricing now.";
        else if (/thanks|thank you|thx/.test(t)) r = "Anytime! 🙌";
        else if (/\?$/.test(userText.trim())) r = "Good question — let me confirm and revert.";
        addMessage({ dir:"in", type:"text", text:r, time:nowTime() });
      }, 1100 + Math.random() * 900);
    }, delay);
  }

  /* =========================================================
     COMPOSER
     ========================================================= */
  const input   = () => $("#msgInput");
  const micBtn  = () => $("#micSend");

  function refreshComposer() {
    const has = input().value.trim().length > 0;
    micBtn().classList.toggle("is-send", has);
    const cam = $("#cameraBtn");
    if (cam) cam.style.display = has ? "none" : "";
    autoGrow();
  }
  function autoGrow() {
    const ta = input(); if (!ta) return;
    if (!ta.value) { ta.style.height = ""; return; }   // empty: let CSS set the natural line height (avoids 0px when pane is hidden on load)
    ta.style.height = "auto";
    ta.style.height = Math.min(ta.scrollHeight, 96) + "px";
  }
  function sendText() {
    const ta = input(); const txt = ta.value.trim();
    if (!txt) return;
    addMessage({ dir:"out", type:"text", text:txt, time:nowTime() });
    ta.value = ""; refreshComposer();
    autoReply(txt);
  }

  /* ---------- voice recording ---------- */
  let recTimer = null, recSecs = 0, recPaused = false;
  const REC_PAUSE = '<svg viewBox="0 0 24 24" fill="currentColor"><rect x="7" y="6" width="3.4" height="12" rx="1"/><rect x="13.6" y="6" width="3.4" height="12" rx="1"/></svg>';
  const REC_PLAY = '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M8 5v14l11-7z"/></svg>';
  function recFmt() { var m = Math.floor(recSecs / 60), s = recSecs % 60; return m + ":" + String(s).padStart(2, "0"); }
  function recTick() { recSecs++; var t = $("#recTime"); if (t) t.textContent = recFmt(); }
  function buildWave() {
    var w = $("#recWave"); if (!w) return; var n = 26, h = "";
    for (var i = 0; i < n; i++) { var ht = 4 + Math.round(Math.abs(Math.sin(i * 0.8)) * 16); h += '<i style="height:' + ht + 'px;animation-delay:' + (i * 0.05).toFixed(2) + 's"></i>'; }
    w.innerHTML = h;
  }
  function startRec() {
    recSecs = 0; recPaused = false;
    $("#composerField").style.display = "none";
    var mic = micBtn(); if (mic) mic.style.display = "none";
    var cam = $("#cameraBtn"); if (cam) cam.style.display = "none";
    var bar = $("#recBar"); bar.hidden = false; bar.classList.remove("paused");
    var p = $("#recPause"); if (p) p.innerHTML = REC_PAUSE;
    $("#recTime").textContent = "0:00";
    buildWave();
    recTimer = setInterval(recTick, 1000);
  }
  function togglePauseRec() {
    var bar = $("#recBar"), p = $("#recPause");
    recPaused = !recPaused;
    if (recPaused) { clearInterval(recTimer); recTimer = null; if (bar) bar.classList.add("paused"); if (p) p.innerHTML = REC_PLAY; }
    else { if (bar) bar.classList.remove("paused"); if (p) p.innerHTML = REC_PAUSE; recTimer = setInterval(recTick, 1000); }
  }
  function stopRec(send) {
    clearInterval(recTimer); recTimer = null; recPaused = false;
    var cf = $("#composerField"); if (cf) cf.style.display = "";
    var mic = micBtn(); if (mic) { mic.style.display = ""; mic.classList.remove("recording"); }
    refreshComposer();
    var rb = $("#recBar"); if (rb) rb.hidden = true;
    if (send && recSecs > 0) {
      addMessage({ dir: "out", type: "voice", len: recFmt(), time: nowTime() });
      autoReply("voice");
    }
  }
  // Recording is "live" whenever the rec bar is showing (paused or not).
  function isRecording() { var b = $("#recBar"); return !!(b && !b.hidden); }
  // Leaving / switching the chat must always stop recording (never send).
  function cancelRecOnLeave() { if (isRecording()) stopRec(false); }

  /* =========================================================
     EMOJI PICKER
     ========================================================= */
  const EMOJI = {
    "😀": ["😀","😃","😄","😁","😆","😅","😂","🤣","🥲","🥹","😊","😇","🙂","🙃","😉","😌","😍","🥰","😘","😗","😙","😚","😋","😛","😝","😜","🤪","🤨","🧐","🤓","😎","🥸","🤩","🥳","😏","😒","😞","😔","😟","😕","🙁","☹️","😣","😖","😫","😩","🥺","😢","😭","😤","😠","😡","🤬","🤯","😳","🥵","🥶","😱","😨","😰","😥","😓","🤗","🤔","🤭","🤫","🤥","😶","😐","😑","😬","🙄","😯","😦","😧","😮","😲","🥱","😴","🤤","😪","😵","🤐","🥴","🤢","🤮","🤧","😷","🤒","🤕","🤑","🤠","😈","👿","👹","👺","🤡","💩","👻","💀","☠️","👽","👾","🤖","🎃","😺","😸","😹","😻","😼","😽","🙀","😿","😾"],
    "👍": ["👍","👎","👌","🤌","🤏","✌️","🤞","🫰","🤟","🤘","🤙","🫵","🫱","🫲","🫳","🫴","👈","👉","👆","👇","☝️","✋","🤚","🖐️","🖖","👋","🤝","🙏","✊","👊","🤛","🤜","👏","🙌","🫶","👐","🤲","💪","🦾","🖕","✍️","🤳","💅","🫦","👀","👁️","👅","👄","🧠","🦷","🦴","👣","🧑","👶","🧒","👦","👧","👨","👩","🧔","👴","👵","🙇","💁","🙅","🙆","🙋","🧏","🤦","🤷","👮","🕵️","💂","👷","🤴","👸","👰","🤵","🦸","🦹","🧙","🧚","🧛","🧜","🧝","🧞","🧟"],
    "🐶": ["🐶","🐱","🐭","🐹","🐰","🦊","🐻","🐼","🐻‍❄️","🐨","🐯","🦁","🐮","🐷","🐽","🐸","🐵","🙈","🙉","🙊","🐒","🐔","🐧","🐦","🐤","🐣","🦆","🦅","🦉","🦇","🐺","🐗","🐴","🦄","🐝","🪱","🐛","🦋","🐌","🐞","🐜","🪲","🦗","🕷️","🦂","🐢","🐍","🦎","🦖","🦕","🐙","🦑","🦐","🦀","🐡","🐠","🐟","🐬","🐳","🐋","🦈","🐊","🐅","🐆","🦓","🦍","🦧","🐘","🦛","🦏","🐪","🐫","🦒","🦘","🐃","🐂","🐄","🐎","🐖","🐏","🐑","🐐","🦌","🐕","🐩","🐈","🐓","🦃","🦚","🦜","🦢","🕊️","🐇","🦝","🦨","🦦","🦥","🐁","🐀","🐿️","🌲","🌳","🌴","🌵","🌷","🌹","🌺","🌸","🌼","🌻","🍀","🍁","🍄","🌾","💐"],
    "🍔": ["🍔","🍟","🍕","🌭","🥪","🌮","🌯","🫔","🥙","🧆","🥗","🥘","🍜","🍲","🍝","🍛","🍣","🍱","🍤","🍙","🍚","🍘","🍥","🥟","🦪","🍗","🍖","🥩","🥓","🌽","🥕","🧅","🧄","🥔","🍠","🥦","🥬","🥒","🌶️","🫑","🥑","🍅","🍆","🧀","🥚","🍳","🥞","🧇","🥐","🥖","🍞","🥨","🥯","🧈","🍩","🍪","🎂","🍰","🧁","🥧","🍫","🍬","🍭","🍮","🍯","🍦","🍨","🍧","🥧","🍎","🍏","🍐","🍊","🍋","🍌","🍉","🍇","🍓","🫐","🍈","🍒","🍑","🥭","🍍","🥥","🥝","🍅","☕","🍵","🧃","🥤","🧋","🍶","🍺","🍻","🥂","🍷","🥃","🍸","🍹","🍾","🧉","🧊"],
    "⚽": ["⚽","🏀","🏈","⚾","🥎","🎾","🏐","🏉","🥏","🎱","🪀","🏓","🏸","🏒","🏑","🥍","🏏","🪃","🥅","⛳","🪁","🏹","🎣","🤿","🥊","🥋","🎽","🛹","🛼","🛷","⛸️","🥌","🎿","⛷️","🏂","🪂","🏋️","🤼","🤸","⛹️","🤺","🤾","🏌️","🏇","🧘","🏄","🏊","🤽","🚣","🧗","🚴","🚵","🏆","🥇","🥈","🥉","🏅","🎖️","🎗️","🎫","🎟️","🎪","🤹","🎭","🩰","🎨","🎬","🎤","🎧","🎼","🎹","🥁","🎷","🎺","🎸","🪕","🎻","🎲","♟️","🎯","🎳","🎮","🕹️","🧩"],
    "✈️": ["✈️","🛫","🛬","🛩️","💺","🚀","🛸","🚁","🛶","⛵","🚤","🛥️","🛳️","⛴️","🚢","⚓","🚗","🚕","🚙","🚌","🚎","🏎️","🚓","🚑","🚒","🚐","🚚","🚛","🚜","🦯","🦽","🦼","🛴","🚲","🛵","🏍️","🛺","🚨","🚥","🚦","🛑","🚧","🗺️","🧭","🗿","🗽","🗼","🏰","🏯","🏟️","🎡","🎢","🎠","⛲","⛱️","🏖️","🏝️","🏜️","🌋","⛰️","🏔️","🗻","🏕️","⛺","🏠","🏡","🏘️","🏢","🏬","🏣","🏤","🏥","🏦","🏨","🏪","🏫","🏩","💒","🏛️","⛪","🕌","🕍","🛕","🕋","⛩️","🌁","🌃","🏙️","🌄","🌅","🌆","🌇","🌉","🎑","🌠","🎇","🎆"],
    "💡": ["💡","🔦","🕯️","🪔","📱","📲","💻","⌨️","🖥️","🖨️","🖱️","💽","💾","💿","📀","📷","📸","📹","🎥","📽️","📺","📻","🎙️","⏰","⏲️","⏱️","🕰️","⌚","📡","🔋","🔌","🧮","🔭","🔬","💉","🩸","💊","🩹","🩺","🚪","🛗","🪞","🪟","🛏️","🛋️","🪑","🚽","🚿","🛁","🧴","🧷","🧹","🧺","🧻","🪣","🧼","🪥","🧽","🧯","🛒","🚬","⚰️","🪦","🔑","🗝️","🔨","🪓","⛏️","⚒️","🛠️","🗡️","⚔️","🔫","🪃","🏹","🛡️","🔧","🪛","🔩","⚙️","🧰","🧲","🔗","⛓️","💰","💴","💵","💶","💷","💸","💳","🧾","✏️","✒️","🖋️","🖊️","🖌️","🖍️","📝","📋","📌","📎","📏","📐","✂️","🗃️","🗄️","🗑️","🔒","🔓","📦","📫","📮","📯"],
    "❤️": ["❤️","🧡","💛","💚","💙","💜","🖤","🤍","🤎","💔","❣️","💕","💞","💓","💗","💖","💘","💝","💟","♥️","💯","💢","💥","💫","💦","💨","🕳️","💬","💭","🗯️","♻️","✅","☑️","✔️","❌","❎","➕","➖","➗","✖️","🟰","💲","💱","™️","©️","®️","〰️","➰","➿","🔚","🔙","🔛","🔝","🔜","✨","⭐","🌟","🌠","⚡","🔥","🌈","☀️","🌙","⛅","☁️","🌧️","⛈️","❄️","💧","🌊","🎉","🎊","🎁","🎈","🎀","🏆","👑","💎","🔔","🔕","🎵","🎶","➡️","⬅️","⬆️","⬇️","↗️","↘️","↙️","↖️","🔁","🔂","🔄","▶️","⏸️","⏹️","⏺️","⏭️","⏮️","🔼","🔽"],
    "🚩": ["🏳️","🏴","🏁","🚩","🏳️‍🌈","🏳️‍⚧️","🏴‍☠️","🇮🇳","🇺🇸","🇬🇧","🇨🇦","🇦🇺","🇸🇬","🇦🇪","🇩🇪","🇫🇷","🇮🇹","🇪🇸","🇯🇵","🇨🇳","🇰🇷","🇧🇷","🇷🇺","🇿🇦","🇲🇽","🇳🇱","🇸🇪","🇨🇭","🇮🇪","🇳🇿","🇸🇦","🇶🇦","🇹🇷","🇮🇩","🇲🇾","🇹🇭","🇵🇭","🇻🇳","🇧🇩","🇵🇰","🇱🇰","🇳🇵","🇪🇬","🇳🇬","🇰🇪"]
  };
  let emojiBuilt = false;
  function buildEmoji() {
    if (emojiBuilt) return; emojiBuilt = true;
    const cats = $(".emoji-cats"), grid = $(".emoji-grid");
    Object.keys(EMOJI).forEach((k, i) => {
      const b = document.createElement("button");
      b.textContent = k; if (i === 0) b.classList.add("active");
      b.addEventListener("click", () => {
        $$(".emoji-cats button").forEach((x) => x.classList.remove("active"));
        b.classList.add("active"); fillEmoji(k);
      });
      cats.appendChild(b);
    });
    fillEmoji(Object.keys(EMOJI)[0]);
    function fillEmoji(cat) {
      grid.innerHTML = "";
      EMOJI[cat].forEach((e) => {
        const b = document.createElement("button"); b.textContent = e;
        b.addEventListener("click", () => {
          const ta = input(); ta.value += e; refreshComposer();
        });
        grid.appendChild(b);
      });
    }
  }
  function closeEmoji() {
    $("#emojiPanel").classList.remove("show");
    $("#convView").classList.remove("emoji-open");
  }
  function toggleEmoji() {
    buildEmoji();
    closeAttach();
    const p = $("#emojiPanel");
    const on = !p.classList.contains("show");
    p.classList.toggle("show", on);
    $("#convView").classList.toggle("emoji-open", on);
    if (on) scrollToBottom(true);
  }

  /* =========================================================
     ATTACHMENT SHEET
     ========================================================= */
  function openAttach() { $("#attachSheet").classList.add("show"); $("#sheetScrim").classList.add("show"); closeEmoji(); }
  function closeAttach() { $("#attachSheet").classList.remove("show"); $("#sheetScrim").classList.remove("show"); }

  /* =========================================================
     CATALOGUE  ·  DRAG-TO-ORDER  ·  ORDER CARD  ·  ORDER DETAILS
     ========================================================= */
  const CATALOG = [
    { id:"double", name:"Double Smash Combo",   price:349 },
    { id:"cheese", name:"Classic Cheeseburger", price:199 },
    { id:"wings",  name:"Peri Wings (6 pc)",     price:179 },
    { id:"fries",  name:"Loaded Fries",          price:149 },
    { id:"veg",    name:"Veg Crunch Burger",     price:179 },
    { id:"shake",  name:"Chocolate Shake",       price:129 },
    { id:"cola",   name:"Cola (500 ml)",         price:60  },
  ];
  const ORDER_BIZ = "Tunepath Technologies";
  const ORDER_SHIP = 100;
  let draftOrder = [];

  const _logoW = '<img src="assets/askeva-logo-white.png" alt="">';
  const _inr   = (n) => "\u20B9" + Number(n).toLocaleString("en-IN");
  const _inr2  = (n) => "\u20B9" + Number(n).toFixed(2);
  const _icX   = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="M18 6 6 18M6 6l12 12"/></svg>';
  const _icPlus  = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><path d="M12 5v14M5 12h14"/></svg>';
  const _icMinus = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12h14"/></svg>';
  const _icBag   = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 7h12l1 13H5z"/><path d="M9 7a3 3 0 0 1 6 0"/></svg>';
  const _icSend  = '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M3 20l18-8L3 4l3 8-3 8zM6 12h6"/></svg>';
  const _icDrag  = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3v6m0 6v6M3 12h6m6 0h6"/><path d="m8 7 4-4 4 4M8 17l4 4 4-4M7 8 3 12l4 4M17 8l4 4-4 4"/></svg>';

  /* ---- catalogue tray ---- */
  function buildCatalog() {
    const tray = $("#catTray"); if (!tray) return;
    tray.innerHTML =
      '<div class="cat-grip"></div>' +
      '<div class="cat-tray-head"><div class="tt"><span class="ci">' + _logoW + '</span>' +
        '<div><div class="nm">Catalogue</div><div class="sub">' + ORDER_BIZ + '</div></div></div>' +
        '<button class="cat-tray-close" id="catClose">' + _icX + '</button></div>' +
      '<div class="cat-hint">' + _icDrag + 'Drag a product into the chat, or tap + to build an order</div>' +
      '<div class="cat-row" id="catRow">' +
        CATALOG.map((p) =>
          '<div class="cat-card" data-pid="' + p.id + '">' +
            '<div class="cat-thumb">' + _logoW + '</div>' +
            '<div class="cat-name">' + esc(p.name) + '</div>' +
            '<div class="cat-foot"><span class="cat-price">' + _inr(p.price) + '</span>' +
            '<button class="cat-add" title="Add">' + _icPlus + '</button></div>' +
          '</div>'
        ).join("") +
      '</div>';
    $("#catClose").addEventListener("click", closeCatalog);
    $$("#catRow .cat-card").forEach((card) => {
      const p = CATALOG.find((x) => x.id === card.dataset.pid);
      $(".cat-add", card).addEventListener("click", (e) => { e.stopPropagation(); flyToDraft(card); addToDraft(p); });
      attachDrag(card, p);
    });
  }
  function openCatalog() {
    closeAttach();
    if (!$("#catRow")) buildCatalog();
    $("#catTray").classList.add("show");
  }
  function closeCatalog() { const t = $("#catTray"); if (t) t.classList.remove("show"); }

  /* ---- pointer-based drag from card → chat scroll ---- */
  function attachDrag(card, p) {
    let ghost = null, armed = false, startX = 0, startY = 0, dragging = false;
    const scroll = () => scrollEl();
    card.addEventListener("pointerdown", (e) => {
      if (e.target.closest(".cat-add")) return;
      startX = e.clientX; startY = e.clientY; dragging = false;
      const move = (ev) => {
        if (!dragging) {
          if (Math.hypot(ev.clientX - startX, ev.clientY - startY) < 8) return;
          dragging = true; card.classList.add("dragging");
          ghost = document.createElement("div");
          ghost.className = "cat-ghost";
          ghost.innerHTML = '<div class="cat-thumb">' + _logoW + '</div><div class="cat-name">' + esc(p.name) + '</div>' +
            '<div class="cat-foot"><span class="cat-price">' + _inr(p.price) + '</span></div>';
          document.body.appendChild(ghost);
        }
        ghost.style.left = ev.clientX + "px";
        ghost.style.top = ev.clientY + "px";
        const sc = scroll();
        const r = sc.getBoundingClientRect();
        const over = ev.clientX >= r.left && ev.clientX <= r.right && ev.clientY >= r.top && ev.clientY <= r.bottom;
        sc.classList.toggle("drop-armed", over);
        armed = over;
      };
      const up = () => {
        document.removeEventListener("pointermove", move);
        document.removeEventListener("pointerup", up);
        card.classList.remove("dragging");
        const sc = scroll(); sc.classList.remove("drop-armed");
        if (ghost) { ghost.remove(); ghost = null; }
        if (dragging && armed) { addToDraft(p); }
      };
      document.addEventListener("pointermove", move);
      document.addEventListener("pointerup", up);
    });
  }

  /* tiny fly animation from a card to the draft bar (for tap-add) */
  function flyToDraft(card) {
    const draft = $("#orderDraft");
    const from = $(".cat-thumb", card).getBoundingClientRect();
    const chip = document.createElement("div");
    chip.className = "fly-chip"; chip.innerHTML = _logoW;
    chip.style.left = from.left + from.width / 2 + "px";
    chip.style.top = from.top + from.height / 2 + "px";
    document.body.appendChild(chip);
    const tr = (draft.classList.contains("show") ? draft : $("#composer")).getBoundingClientRect();
    requestAnimationFrame(() => {
      chip.style.transition = "left .5s cubic-bezier(.4,0,.2,1), top .5s cubic-bezier(.5,0,.6,1), transform .5s ease, opacity .5s ease";
      chip.style.left = tr.left + 28 + "px";
      chip.style.top = tr.top + 18 + "px";
      chip.style.transform = "scale(.4)"; chip.style.opacity = ".2";
    });
    setTimeout(() => chip.remove(), 540);
  }

  /* ---- draft order bar ---- */
  function addToDraft(p) {
    const ex = draftOrder.find((x) => x.id === p.id);
    if (ex) ex.qty++; else draftOrder.push({ id:p.id, name:p.name, price:p.price, qty:1 });
    renderDraft();
  }
  function draftCount() { return draftOrder.reduce((s, x) => s + x.qty, 0); }
  function draftSub() { return draftOrder.reduce((s, x) => s + x.price * x.qty, 0); }
  function renderDraft() {
    const bar = $("#orderDraft"); if (!bar) return;
    if (!draftOrder.length) { bar.classList.remove("show"); bar.innerHTML = ""; return; }
    const sub = draftSub();
    bar.innerHTML =
      '<div class="od-draft-head"><span class="bag">' + _icBag + '</span>' +
        '<div class="meta"><div class="t">New order</div><div class="s">' + draftCount() + ' item' + (draftCount() > 1 ? "s" : "") + ' \u00b7 ' + ORDER_BIZ + '</div></div>' +
        '<button class="od-draft-clear" id="draftClear">Clear</button></div>' +
      '<div class="od-draft-list">' +
        draftOrder.map((it) =>
          '<div class="od-draft-item" data-id="' + it.id + '"><span class="th">' + _logoW + '</span>' +
          '<span class="nm">' + esc(it.name) + '</span>' +
          '<span class="qty"><button class="qbtn" data-dec>' + _icMinus + '</button>' +
          '<span class="qn">' + it.qty + '</span>' +
          '<button class="qbtn" data-inc>' + _icPlus + '</button></span>' +
          '<span class="lp">' + _inr(it.price * it.qty) + '</span></div>'
        ).join("") +
      '</div>' +
      '<div class="od-draft-foot"><span class="tot">Subtotal <span>' + _inr(sub) + '</span></span>' +
        '<button class="od-draft-send" id="draftSend">' + _icSend + ' Send order</button></div>';
    bar.classList.add("show");
    $("#draftClear").addEventListener("click", () => { draftOrder = []; renderDraft(); });
    $("#draftSend").addEventListener("click", sendOrder);
    $$(".od-draft-item", bar).forEach((row) => {
      const it = draftOrder.find((x) => x.id === row.dataset.id);
      $("[data-inc]", row).addEventListener("click", () => { it.qty++; renderDraft(); });
      $("[data-dec]", row).addEventListener("click", () => { it.qty--; if (it.qty <= 0) draftOrder = draftOrder.filter((x) => x !== it); renderDraft(); });
    });
  }

  function sendOrder() {
    if (!draftOrder.length) return;
    const items = draftOrder.map((x) => ({ name:x.name, price:x.price, qty:x.qty }));
    const oid = "ev" + String(Date.now()).slice(-6);
    const m = { dir:"out", type:"order", items, orderId:oid, shipping:ORDER_SHIP, biz:ORDER_BIZ, paid:false, time:nowTime() };
    if (current) { current.thread = current.thread || []; current.thread.push(m); current.preview = "Order \u00b7 " + draftCount() + " items"; current.time = m.time; }
    addMessage(m);
    if (current) renderList();
    draftOrder = []; renderDraft(); closeCatalog();
    toast("Order sent");
  }

  /* ---- order receipt → full-screen Order details ---- */
  function payOrder(m, el) {
    const items = m.items || [];
    const total = items.reduce((s, it) => s + it.price * (it.qty || 1), 0) + (m.shipping || 0);
    if (window.__payGateway) {
      window.__payGateway(total, { note: "Order #" + (m.orderId || ""), onPaid: () => { m.paid = true; markOrderPaid(el); } });
    } else { m.paid = true; markOrderPaid(el); toast("Paid " + _inr2(total)); }
  }
  function markOrderPaid(el) {
    const card = el ? $(".order-msg", el) : null;
    if (card) card.classList.add("paid");
  }

  function openOrderDetails(m, el) {
    const items = m.items || [];
    const sub = items.reduce((s, it) => s + it.price * (it.qty || 1), 0);
    const ship = m.shipping || 0;
    const total = sub + ship;
    const scr = $("#screen") || document.body;
    let host = $("#orderDetails");
    if (host) host.remove();
    host = document.createElement("div");
    host.className = "order-details"; host.id = "orderDetails";
    host.innerHTML =
      '<div class="od-status"><div><div class="clk">' + nowClock() + '</div></div>' +
        '<div class="sys"><svg width="18" height="13" viewBox="0 0 18 13"><rect x="0" y="3" width="2.6" height="7" rx="1"/><rect x="3.6" y="1.5" width="2.6" height="8.5" rx="1"/><rect x="7.2" y="0" width="2.6" height="10" rx="1"/><rect x="10.8" y="0" width="2.6" height="10" rx="1" opacity=".35"/></svg>' +
        '<svg width="17" height="13" viewBox="0 0 17 13"><path d="M8.5 3.2C5.6 3.2 3 4.4 1.2 6.3l1.4 1.4C4 6.2 6.1 5.3 8.5 5.3s4.5.9 5.9 2.4l1.4-1.4C14 4.4 11.4 3.2 8.5 3.2zM8.5 7.4c-1.2 0-2.3.5-3.1 1.3l3.1 3.1 3.1-3.1c-.8-.8-1.9-1.3-3.1-1.3z"/></svg>' +
        '<svg width="26" height="13" viewBox="0 0 26 13"><rect x="0.6" y="0.6" width="21" height="11.8" rx="3" fill="none" stroke="#fff" stroke-opacity=".5"/><rect x="2.2" y="2.2" width="16" height="8.6" rx="1.5"/><rect x="23" y="4" width="2" height="5" rx="1"/></svg>' +
        '</div></div>' +
      '<div class="od-head"><button class="od-back" id="odBack">' + I.back + '</button>' +
        '<div class="ttl">Order details</div><span></span></div>' +
      '<div class="od-scroll">' +
        '<div class="od-receipt">' +
          '<div class="od-logo">' + _logoW + '</div>' +
          '<div class="od-biz">' + esc(m.biz || ORDER_BIZ) + '</div>' +
          '<div class="od-ord">Order #' + esc(m.orderId || "") + '</div>' +
          '<div class="od-pillwrap"><span class="od-pill"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></svg>' + (m.paid ? "Paid" : "Awaiting payment") + '</span></div>' +
          '<hr class="od-dash">' +
          items.map((it) =>
            '<div class="od-line"><span class="th">' + _logoW + '</span>' +
            '<div class="info"><div class="nm">' + esc(it.name) + '</div><div class="qt">Qty ' + (it.qty || 1) + ' \u00b7 ' + _inr(it.price) + '</div></div>' +
            '<div class="pr">' + _inr(it.price * (it.qty || 1)) + '</div></div>'
          ).join("") +
          '<hr class="od-dash">' +
          '<div class="od-sums">' +
            '<div class="od-sumrow"><span>Subtotal</span><span class="v">' + _inr(sub) + '</span></div>' +
            '<div class="od-sumrow"><span>Shipping</span><span class="v">' + (ship ? _inr(ship) : "Free") + '</span></div>' +
          '</div>' +
        '</div>' +
      '</div>' +
      '<div class="od-foot"><div class="totrow"><span class="l">Total</span><span class="v">' + _inr(total) + '</span></div>' +
        '<button class="od-continue" id="odContinue"' + (m.paid ? " disabled" : "") + '>' + (m.paid ? "Paid" : "Continue to pay \u00b7 " + _inr(total)) + '</button></div>';
    scr.appendChild(host);
    requestAnimationFrame(() => host.classList.add("show"));
    const close = () => { host.classList.remove("show"); setTimeout(() => host.remove(), 360); };
    $("#odBack", host).addEventListener("click", close);
    const cont = $("#odContinue", host);
    if (cont && !m.paid) cont.addEventListener("click", () => {
      close();
      setTimeout(() => payOrder(m, el), 380);
    });
  }
  function nowClock() {
    const d = new Date(); let h = d.getHours(); const mm = String(d.getMinutes()).padStart(2, "0");
    const ap = h >= 12 ? "PM" : "AM"; h = h % 12 || 12; return h + ":" + mm + " " + ap;
  }

  /* =========================================================
     SUB-PANELS (full-screen, slide from right)
     ========================================================= */
  const panelHost = () => $("#panelHost");
  function openPanel(html) {
    const h = panelHost();
    h.dataset.open = "1";
    h.innerHTML = html;
    requestAnimationFrame(() => h.classList.add("show"));
    const back = $(".panel-back", h);
    if (back) back.addEventListener("click", closePanel);
  }
  function closePanel() {
    const h = panelHost();
    h.classList.remove("show");
    h.dataset.open = "";
    setTimeout(() => { if (!h.dataset.open) h.innerHTML = ""; }, 320);
  }
  function panelHeadHTML(title, sub) {
    return '<div class="panel-head"><button class="iconbtn panel-back">' + I.back + '</button>' +
      '<div class="pt"><div class="t">' + title + '</div>' + (sub ? '<div class="s">' + sub + "</div>" : "") + "</div></div>";
  }
  const stripeCell = (lbl) => '<span class="ph-stripe"><span class="lbl">' + lbl + "</span></span>";
  const selBox = '<span class="sel-box">' + I.check + "</span>";

  /* ---- GALLERY (real device images) ---- */
  function openGallery() {
    closeAttach();
    pickChatFile("image", true, function (files) {
      files.forEach(function (f, k) {
        var src = URL.createObjectURL(f);
        setTimeout(function () { addMessage({ dir:"out", type:"image", src:src, name:f.name, tall:(k % 2 === 0), time:nowTime() }); }, k * 150);
      });
      var n = files.length;
      setTimeout(function () { toast(n > 1 ? n + " photos sent" : "Photo sent"); autoReply("photo"); }, n * 150 + 150);
    });
  }

  /* ---- LOCATION ---- */
  const PLACES = [
    ["Burger Street — MG Road","1.2 km · Restaurant"],
    ["Phoenix Marketcity","3.4 km · Shopping mall"],
    ["Indiranagar Metro","2.1 km · Transit"],
    ["Cubbon Park","4.0 km · Park"],
  ];
  function openLocation() {
    closeAttach();
    const places = PLACES.map((p, i) =>
      '<div class="place-row" data-i="' + i + '"><span class="ic"><svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 2a7 7 0 0 0-7 7c0 5 7 13 7 13s7-8 7-13a7 7 0 0 0-7-7z"/><circle cx="12" cy="9" r="2.4" fill="#fff"/></svg></span>' +
      '<div><div style="font-size:14.5px;font-weight:600;color:var(--ink)">' + p[0] + '</div><div style="font-size:12px;color:var(--ink-3)">' + p[1] + "</div></div></div>"
    ).join("");
    openPanel(panelHeadHTML("Send location") +
      '<div class="loc-big"><span class="me"></span></div>' +
      '<div class="panel-body"><div class="send-loc-row" id="sendCur"><span class="ic"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 2v3M12 19v3M2 12h3M19 12h3"/><circle cx="12" cy="12" r="4"/></svg></span>' +
      '<div><div class="t">Send your current location</div><div class="s">Accurate to 12 meters</div></div></div>' +
      '<div class="list-sub">Nearby places</div>' + places + "</div>");
    $("#sendCur").addEventListener("click", () => { closePanel(); addMessage({ dir:"out", type:"location", title:"Current location", sub:"MG Road, Bengaluru", time:nowTime() }); toast("Location sent"); });
    $$(".place-row").forEach((r) => r.addEventListener("click", () => {
      const p = PLACES[r.dataset.i]; closePanel();
      addMessage({ dir:"out", type:"location", title:p[0].split("—")[0].trim(), sub:p[1], time:nowTime() }); toast("Location sent");
    }));
  }

  /* ---- CONTACT ---- */
  const PHONEBOOK = [
    ["Anjali Rao","+91 98860 11234"],["Kabir Shah","+91 99001 55621"],["Meera Pillai","+91 90087 44120"],
    ["Dev Kapoor","+91 81234 99876"],["Riya Sen","+91 70192 33445"],["Arjun Verma","+91 96320 78451"],
  ];
  function openContact() {
    closeAttach();
    const rows = PHONEBOOK.map((c, i) =>
      '<div class="contact-row" data-i="' + i + '"><span class="av" style="background:' + avColor(i) + '">' + c[0].split(" ").map((w)=>w[0]).join("") + '</span>' +
      '<div class="nm"><div class="t">' + c[0] + '</div><div class="s">' + c[1] + '</div></div>' + selBox + "</div>"
    ).join("");
    openPanel(panelHeadHTML("Send contact", "Select contacts") +
      '<div class="search-row"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><circle cx="11" cy="11" r="7"/><path d="M21 21l-4.3-4.3"/></svg><input placeholder="Search name or number"></div>' +
      '<div class="panel-body">' + rows + "</div>" +
      '<button class="send-fab" id="ctFab"><span class="badge" id="ctBadge">0</span>' + I.check + "</button>");
    const sel = new Set(); const fab = $("#ctFab"), badge = $("#ctBadge");
    $$(".contact-row").forEach((r) => r.addEventListener("click", () => {
      const i = r.dataset.i;
      if (sel.has(i)) { sel.delete(i); r.classList.remove("sel"); } else { sel.add(i); r.classList.add("sel"); }
      badge.textContent = sel.size; fab.classList.toggle("show", sel.size > 0);
    }));
    fab.addEventListener("click", () => {
      const arr = Array.from(sel); closePanel();
      arr.forEach((i, k) => { const c = PHONEBOOK[i];
        setTimeout(() => addMessage({ dir:"out", type:"contact", name:c[0], phone:c[1], init:c[0].split(" ").map((w)=>w[0]).join(""), time:nowTime() }), k * 160); });
      setTimeout(() => { toast(arr.length > 1 ? arr.length + " contacts sent" : "Contact sent"); }, arr.length * 160 + 150);
    });
  }

  /* ---- DOCUMENT ---- */
  /* Authentic Microsoft Office / file-type logos (Word·Excel·PowerPoint·PDF) */
  const MS_LOGO = {
    doc:{ c:"#2B579A", l:"W" }, docx:{ c:"#2B579A", l:"W" },
    xls:{ c:"#1E8E5A", l:"X" }, xlsx:{ c:"#1E8E5A", l:"X" },
    ppt:{ c:"#C43E1C", l:"P" }, pptx:{ c:"#C43E1C", l:"P" },
    pdf:{ c:"#E0392B", l:"PDF" },
  };
  function msLogo(kind, sz) {
    const o = MS_LOGO[kind] || MS_LOGO.doc;
    const multi = o.l.length > 1;
    const bw = multi ? 26 : 20, fs = multi ? 7.4 : 11;
    const h = Math.round(sz * 40 / 32);
    return '<svg viewBox="0 0 32 40" width="' + sz + '" height="' + h + '" fill="none" xmlns="http://www.w3.org/2000/svg" style="display:block">' +
      '<path d="M4 1h16l11 11v24a3 3 0 0 1-3 3H4a3 3 0 0 1-3-3V4a3 3 0 0 1 3-3z" fill="#fff" stroke="#E3E7EB" stroke-width="1.4"/>' +
      '<path d="M20 1l11 11h-8a3 3 0 0 1-3-3V1z" fill="#EDF0F3"/>' +
      '<rect x="1" y="21" width="' + bw + '" height="13" rx="2.4" fill="' + o.c + '"/>' +
      '<text x="' + (1 + bw / 2) + '" y="30.4" text-anchor="middle" font-family="Plus Jakarta Sans, Arial, sans-serif" font-weight="800" font-size="' + fs + '" fill="#fff" letter-spacing="-.2">' + o.l + '</text></svg>';
  }
  const DOCS = [
    ["Burger_Street_Menu.pdf","2.4 MB","pdf","pdf"],
    ["Invoice_4471.pdf","118 KB","pdf","pdf"],
    ["Q2_Sales_Report.xlsx","842 KB","xls","xlsx"],
    ["Catalog_Update.docx","356 KB","doc","docx"],
    ["Onboarding_Guide.pdf","1.1 MB","pdf","pdf"],
  ];
  /* ---- DOCUMENT (real device file) ---- */
  function openDocument() {
    closeAttach();
    pickChatFile("document", false, function (files) {
      var f = files[0];
      var ext = (f.name.split(".").pop() || "").toLowerCase();
      addMessage({ dir:"out", type:"document", name:f.name, size:fmtBytes(f.size), kind:docKind(ext), ext:ext, time:nowTime() });
      toast("Document sent");
    });
  }

  /* ---- POLL ---- */
  function openPoll() {
    closeAttach();
    openPanel(panelHeadHTML("Create poll") +
      '<div class="panel-body"><div class="creator">' +
      '<label class="field-lbl">Question</label><input class="c-input" id="pollQ" placeholder="Ask a question">' +
      '<label class="field-lbl">Options</label><div id="pollOpts">' +
      '<div class="opt-row"><input class="c-input" placeholder="Option 1"><button class="del">✕</button></div>' +
      '<div class="opt-row"><input class="c-input" placeholder="Option 2"><button class="del">✕</button></div>' +
      '</div><button class="add-opt" id="addOpt">＋ Add option</button>' +
      '<div class="toggle-row"><span class="t">Allow multiple answers</span><span class="sw" id="pollMulti"></span></div>' +
      '</div></div><div class="panel-foot"><button class="btn-send-panel" id="pollSend" disabled>Send poll</button></div>');
    const optsBox = $("#pollOpts"), q = $("#pollQ"), send = $("#pollSend");
    function refresh() {
      const filled = $$("#pollOpts .c-input").filter((i) => i.value.trim()).length;
      send.disabled = !(q.value.trim() && filled >= 2);
    }
    function wireDel() { $$("#pollOpts .del").forEach((d) => d.onclick = () => {
      if ($$("#pollOpts .opt-row").length > 2) { d.closest(".opt-row").remove(); refresh(); }
    }); }
    optsBox.addEventListener("input", refresh); q.addEventListener("input", refresh);
    $("#addOpt").addEventListener("click", () => {
      if ($$("#pollOpts .opt-row").length >= 12) return;
      const row = document.createElement("div"); row.className = "opt-row";
      row.innerHTML = '<input class="c-input" placeholder="Option ' + ($$("#pollOpts .opt-row").length + 1) + '"><button class="del">✕</button>';
      optsBox.appendChild(row); wireDel();
    });
    $("#pollMulti").addEventListener("click", function () { this.classList.toggle("on"); });
    wireDel();
    send.addEventListener("click", () => {
      const options = $$("#pollOpts .c-input").map((i) => i.value.trim()).filter(Boolean);
      const multi = $("#pollMulti").classList.contains("on");
      closePanel();
      addMessage({ dir:"out", type:"poll", q:q.value.trim(), options, multi, _votes:options.map(()=>0), time:nowTime() });
      toast("Poll sent");
    });
  }

  /* ---- EVENT ---- */
  const MONTHS = ["JAN","FEB","MAR","APR","MAY","JUN","JUL","AUG","SEP","OCT","NOV","DEC"];
  function openEvent() {
    closeAttach();
    openPanel(panelHeadHTML("Create event") +
      '<div class="panel-body"><div class="creator">' +
      '<label class="field-lbl">Event name</label><input class="c-input" id="evName" placeholder="e.g. Weekend Tasting">' +
      '<div class="two-col"><div><label class="field-lbl">Date</label><input class="c-input" id="evDate" type="date"></div>' +
      '<div><label class="field-lbl">Time</label><input class="c-input" id="evTime" type="time"></div></div>' +
      '<label class="field-lbl">Location (optional)</label><input class="c-input" id="evLoc" placeholder="Add location">' +
      '<label class="field-lbl">Description (optional)</label><input class="c-input" id="evDesc" placeholder="Add a note">' +
      '</div></div><div class="panel-foot"><button class="btn-send-panel" id="evSend" disabled>Send event</button></div>');
    const name = $("#evName"), date = $("#evDate"), send = $("#evSend");
    function refresh() { send.disabled = !(name.value.trim() && date.value); }
    $("#evName").addEventListener("input", refresh); $("#evDate").addEventListener("input", refresh);
    send.addEventListener("click", () => {
      const d = date.value ? new Date(date.value) : new Date();
      const when = d.toLocaleDateString("en-IN", { weekday:"short", day:"numeric", month:"short" }) + ($("#evTime").value ? " · " + fmtTime($("#evTime").value) : "");
      closePanel();
      addMessage({ dir:"out", type:"event", title:name.value.trim(), when, loc:$("#evLoc").value.trim(),
        dateObj:{ mon:MONTHS[d.getMonth()], day:d.getDate() }, time:nowTime() });
      toast("Event sent");
    });
    function fmtTime(t) { const [h,m] = t.split(":"); let hh = +h; const ap = hh >= 12 ? "PM":"AM"; hh = hh%12||12; return hh + ":" + m + " " + ap; }
  }

  /* ---- AI IMAGES ---- */
  function openAI() {
    closeAttach();
    openPanel(panelHeadHTML("AI images", "Describe what to create") +
      '<div class="panel-body"><div class="creator">' +
      '<label class="field-lbl">Prompt</label><input class="c-input" id="aiPrompt" placeholder="A gourmet burger on a marble table">' +
      '<label class="field-lbl">Style</label><div class="ai-styles" id="aiStyles">' +
      ["Photo","Illustration","3D","Minimal","Vivid"].map((s,i) => '<button class="ai-chip' + (i===0?" on":"") + '">' + s + "</button>").join("") +
      '</div></div><div id="aiResult"></div></div>' +
      '<div class="panel-foot"><button class="btn-send-panel" id="aiGen">✨ Generate</button></div>');
    $$("#aiStyles .ai-chip").forEach((c) => c.addEventListener("click", () => { $$("#aiStyles .ai-chip").forEach((x)=>x.classList.remove("on")); c.classList.add("on"); }));
    $("#aiGen").addEventListener("click", () => {
      const prompt = $("#aiPrompt").value.trim() || "AskEva image";
      const btn = $("#aiGen"); btn.textContent = "Generating…"; btn.disabled = true;
      const res = $("#aiResult");
      res.innerHTML = '<div class="ai-grid">' + Array.from({length:4}, (_,i) =>
        '<div class="ai-tile" data-i="' + i + '">' + stripeCell("v" + (i+1)) + '<span class="sel-box">' + I.check + "</span></div>").join("") + "</div>" +
        '<div style="text-align:center;font-size:12px;color:var(--ink-3);padding-bottom:14px">Tap a result to send</div>';
      setTimeout(() => { btn.textContent = "✨ Generate"; btn.disabled = false; }, 600);
      $$("#aiResult .ai-tile").forEach((t) => t.addEventListener("click", () => {
        closePanel(); addMessage({ dir:"out", type:"aiimage", tall:false, label:"AI image", time:nowTime() }); toast("AI image sent");
      }));
    });
  }

  /* =========================================================
     CAMERA
     ========================================================= */
  let camMode = "photo", camRec = false, camTimer = null, camSecs = 0, camFacing = "back";
  function openCamera() {
    closeAttach();
    $("#cameraScreen").classList.add("show");
    setCamMode("photo");
  }
  function closeCamera() {
    if (camRec) stopCamRec(false);
    $("#cameraScreen").classList.remove("show");
  }
  function setCamMode(mode) {
    camMode = mode;
    $$(".cam-mode").forEach((m) => m.classList.toggle("active", m.dataset.mode === mode));
    const shutter = $("#camShutter");
    shutter.classList.toggle("video", mode !== "photo");
    $("#camTimer").classList.remove("show");
  }
  function fmtSecs(s) { const m = Math.floor(s/60); return m + ":" + String(s%60).padStart(2,"0"); }
  function shutterPress() {
    if (camMode === "photo") {
      const f = $("#camFlash"); f.classList.remove("fire"); void f.offsetWidth; f.classList.add("fire");
      setTimeout(() => { closeCamera(); addMessage({ dir:"out", type:"image", tall:true, label:"photo", time:nowTime() }); toast("Photo sent"); autoReply("photo"); }, 360);
    } else {
      if (!camRec) startCamRec(); else stopCamRec(true);
    }
  }
  function startCamRec() {
    camRec = true; camSecs = 0;
    $("#camShutter").classList.add("recording");
    const t = $("#camTimer"); t.classList.add("show"); t.innerHTML = '<span class="rec-dot"></span>0:00';
    camTimer = setInterval(() => { camSecs++; t.innerHTML = '<span class="rec-dot"></span>' + fmtSecs(camSecs); }, 1000);
  }
  function stopCamRec(send) {
    camRec = false; clearInterval(camTimer);
    $("#camShutter").classList.remove("recording");
    $("#camTimer").classList.remove("show");
    if (send && camSecs > 0) {
      closeCamera();
      addMessage({ dir:"out", type:"video", len:fmtSecs(camSecs), time:nowTime() });
      toast(camMode === "vnote" ? "Video note sent" : "Video sent");
      autoReply("video");
    }
  }

  /* =========================================================
     HEADER MENU
     ========================================================= */
  function toggleMenu(show) {
    const m = $("#headMenu"), sc = $("#menuScrim");
    const on = show === undefined ? !m.classList.contains("show") : show;
    m.classList.toggle("show", on); sc.classList.toggle("show", on);
  }

  /* =========================================================
     IN-CHAT SEARCH  (search words, highlight, jump between hits)
     ========================================================= */
  const chevUp   = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="M18 15l-6-6-6 6"/></svg>';
  const chevDown = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="M6 9l6 6 6-6"/></svg>';
  let searchState = null;

  function openChatSearch() {
    toggleMenu(false); closeEmoji(); closeAttach();
    if ($("#chatSearchBar")) { $("#csInput").focus(); return; }
    const bar = document.createElement("div");
    bar.id = "chatSearchBar"; bar.className = "chat-search-bar";
    bar.innerHTML =
      '<button class="iconbtn" id="csBack" aria-label="Close search">' + I.back + '</button>' +
      '<div class="cs-field"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><circle cx="11" cy="11" r="7"/><path d="M21 21l-4.3-4.3"/></svg>' +
      '<input id="csInput" placeholder="Search messages" autocomplete="off" spellcheck="false"><button class="cs-clear" id="csClear" hidden>&times;</button></div>' +
      '<span class="cs-count" id="csCount"></span>' +
      '<div class="cs-navs"><button class="iconbtn cs-nav" id="csUp" disabled aria-label="Previous">' + chevUp + '</button>' +
      '<button class="iconbtn cs-nav" id="csDown" disabled aria-label="Next">' + chevDown + '</button></div>';
    $("#convView").appendChild(bar);
    requestAnimationFrame(() => bar.classList.add("show"));
    searchState = { hits: [], idx: -1 };
    const input = $("#csInput");
    setTimeout(() => input.focus(), 120);
    input.addEventListener("input", () => { $("#csClear").hidden = !input.value; runSearch(input.value); });
    input.addEventListener("keydown", (e) => {
      if (e.key === "Enter") { e.preventDefault(); stepSearch(e.shiftKey ? -1 : 1); }
      else if (e.key === "Escape") { e.preventDefault(); closeChatSearch(); }
    });
    $("#csClear").addEventListener("click", () => { input.value = ""; $("#csClear").hidden = true; runSearch(""); input.focus(); });
    $("#csBack").addEventListener("click", closeChatSearch);
    $("#csUp").addEventListener("click", () => stepSearch(-1));
    $("#csDown").addEventListener("click", () => stepSearch(1));
  }
  function closeChatSearch() {
    const bar = $("#chatSearchBar"); if (!bar) return;
    clearHighlights(scrollEl());
    bar.classList.remove("show");
    setTimeout(() => bar.remove(), 240);
    searchState = null;
  }
  function clearHighlights(root) {
    if (!root) return;
    $$("mark.search-hit", root).forEach((m) => { const t = document.createTextNode(m.textContent); m.parentNode.replaceChild(t, m); });
    $$(".bubble", root).forEach((b) => { b.normalize(); b.classList.remove("search-current"); });
  }
  function highlightIn(el, term) {
    const lc = term.toLowerCase(); let count = 0;
    const walker = document.createTreeWalker(el, NodeFilter.SHOW_TEXT, {
      acceptNode(n) {
        if (!n.nodeValue || !n.nodeValue.trim()) return NodeFilter.FILTER_REJECT;
        if (n.parentElement && n.parentElement.closest(".meta,.tick,.vid-len,.vdur,.poll-foot,mark")) return NodeFilter.FILTER_REJECT;
        return n.nodeValue.toLowerCase().indexOf(lc) !== -1 ? NodeFilter.FILTER_ACCEPT : NodeFilter.FILTER_REJECT;
      }
    });
    const nodes = []; while (walker.nextNode()) nodes.push(walker.currentNode);
    nodes.forEach((node) => {
      const text = node.nodeValue, low = text.toLowerCase(), frag = document.createDocumentFragment();
      let i = 0, pos;
      while ((pos = low.indexOf(lc, i)) !== -1) {
        if (pos > i) frag.appendChild(document.createTextNode(text.slice(i, pos)));
        const mk = document.createElement("mark"); mk.className = "search-hit";
        mk.textContent = text.slice(pos, pos + term.length);
        frag.appendChild(mk); count++; i = pos + term.length;
      }
      if (i < text.length) frag.appendChild(document.createTextNode(text.slice(i)));
      node.parentNode.replaceChild(frag, node);
    });
    return count;
  }
  function runSearch(raw) {
    const root = scrollEl(); clearHighlights(root);
    const term = raw.trim();
    searchState.hits = []; searchState.idx = -1;
    if (!term) { updateSearchCount(); return; }
    $$(".bubble", root).forEach((b) => { if (highlightIn(b, term) > 0) searchState.hits.push(b); });
    if (searchState.hits.length) { searchState.idx = searchState.hits.length - 1; focusHit(); } // newest first, like WhatsApp
    updateSearchCount();
  }
  function focusHit() {
    const b = searchState.hits[searchState.idx]; if (!b) return;
    searchState.hits.forEach((x) => x.classList.remove("search-current"));
    b.classList.add("search-current");
    const s = scrollEl();
    const top = b.offsetTop - s.clientHeight / 2 + b.offsetHeight / 2;
    s.scrollTo({ top: Math.max(0, top), behavior: "smooth" });
  }
  function stepSearch(dir) {
    if (!searchState || !searchState.hits.length) return;
    const n = searchState.hits.length;
    searchState.idx = (searchState.idx + dir + n) % n;
    focusHit(); updateSearchCount();
  }
  function updateSearchCount() {
    const c = $("#csCount"), up = $("#csUp"), dn = $("#csDown");
    if (!c) return;
    const n = searchState ? searchState.hits.length : 0;
    const has = $("#csInput") && $("#csInput").value.trim().length > 0;
    if (!n) { c.textContent = has ? "0" : ""; up.disabled = dn.disabled = true; return; }
    c.textContent = (searchState.idx + 1) + "/" + n;
    up.disabled = dn.disabled = false;
  }

  /* =========================================================
     MODAL / DIALOG  (mute, disappearing, confirm)
     ========================================================= */
  function modalHost() {
    let h = $("#chatModalHost");
    if (!h) {
      h = document.createElement("div"); h.id = "chatModalHost"; h.className = "chat-modal-scrim";
      (($("#panelHost") && $("#panelHost").parentElement) || document.body).appendChild(h);
    }
    return h;
  }
  function openModal(html) {
    const h = modalHost();
    h.innerHTML = '<div class="chat-modal">' + html + "</div>";
    requestAnimationFrame(() => h.classList.add("show"));
    h.onclick = (e) => { if (e.target === h) closeModal(); };
    return h;
  }
  function closeModal() {
    const h = $("#chatModalHost"); if (!h) return;
    h.classList.remove("show");
    setTimeout(() => { if (h && !h.classList.contains("show")) h.innerHTML = ""; }, 220);
  }
  function confirmDialog(o) {
    openModal('<div class="md-title">' + o.title + '</div><div class="md-sub">' + o.body + '</div>' +
      '<div class="md-actions"><button class="md-btn ghost" data-x="cancel">Cancel</button>' +
      '<button class="md-btn' + (o.danger ? " danger" : "") + '" data-x="ok">' + o.ok + "</button></div>");
    const h = $("#chatModalHost");
    h.querySelector('[data-x="cancel"]').onclick = closeModal;
    h.querySelector('[data-x="ok"]').onclick = () => { closeModal(); o.onOk && o.onOk(); };
  }
  function radioListHTML(opts, cur) {
    return '<div class="md-radios">' + opts.map((o) =>
      '<label class="radio-row" data-v="' + o[0] + '"><span class="rb' + (cur === o[0] ? " on" : "") + '"></span><span class="rl">' + o[1] + "</span></label>"
    ).join("") + "</div>";
  }
  function wireRadios(host, init, onChange) {
    let sel = init;
    $$(".radio-row", host).forEach((r) => r.addEventListener("click", () => {
      sel = r.dataset.v;
      $$(".radio-row .rb", host).forEach((x) => x.classList.remove("on"));
      r.querySelector(".rb").classList.add("on");
      onChange && onChange(sel);
    }));
    return () => sel;
  }

  /* ---- NEW CHAT (creates a contact + queues it for Leads sync) ---- */
  function initialsOf(name) {
    var p = name.trim().split(/\s+/);
    return ((p[0] || "").charAt(0) + (p[1] || "").charAt(0)).toUpperCase() || (name.charAt(0) || "?").toUpperCase();
  }
  function openNewChat() {
    openModal('<div class="md-title">New chat</div>' +
      '<div class="md-sub">Start a new chat conversation. New contacts are added to <b>Leads</b> automatically and assigned to an agent.</div>' +
      '<div class="md-field"><label>Name</label><input class="md-input" id="ncName" placeholder="Contact name" autocomplete="off"></div>' +
      '<div class="md-field"><label>Phone number</label><input class="md-input" id="ncPhone" type="tel" inputmode="numeric" placeholder="91 98765 43210" autocomplete="off"></div>' +
      '<div class="md-actions"><button class="md-btn ghost" data-x="cancel">Cancel</button><button class="md-btn" data-x="ok">Start chat</button></div>');
    const h = $("#chatModalHost");
    const nameI = h.querySelector("#ncName"), phoneI = h.querySelector("#ncPhone");
    setTimeout(() => nameI && nameI.focus(), 60);
    phoneI.addEventListener("input", () => { phoneI.value = phoneI.value.replace(/[^\d ]/g, ""); });
    h.querySelector('[data-x="cancel"]').onclick = closeModal;
    h.querySelector('[data-x="ok"]').onclick = () => {
      const name = (nameI.value || "").trim();
      const phone = (phoneI.value || "").replace(/\s/g, "");
      if (!name) { nameI.focus(); toast("Enter a contact name"); return; }
      if (phone.length < 8) { phoneI.focus(); toast("Enter a valid phone number"); return; }
      const now = new Date();
      const tm = ((now.getHours() % 12) || 12) + ":" + ("0" + now.getMinutes()).slice(-2) + " " + (now.getHours() < 12 ? "am" : "pm");
      const c = {
        id: "nc_" + Date.now(), name: name, init: initialsOf(name), color: "var(--eva-gradient)", grad: true,
        status: "online", preview: "Draft started", time: tm, unread: 0, pinned: false, phone: phone,
        thread: [{ day: "TODAY" }]
      };
      CONTACTS.unshift(c);
      // auto-capture: a new unknown chat becomes a real, owned Lead immediately
      var _newLead = createRealLeadFromChat(c, "Chat");
      c.leadStatus = "active";
      closeModal(); renderList(); openConversation(c);
      toast(_newLead ? "Chat started \u00b7 lead created & assigned to " + (String(_newLead.assigned || "").split("@")[0] || "an agent") : "Chat started");
    };
  }

  /* ---- contact multi-select (shared by New group / New broadcast) ---- */
  function pickContacts(o) {
    const rows = CONTACTS.filter((c) => !c.group && !c.broadcast).map((c) => {
      const bg = c.grad ? "background:var(--eva-gradient)" : "background:" + (c.color || "var(--eva-gradient)");
      return '<label class="pick-row"><span class="pick-av" style="' + bg + '">' + c.init + '</span>' +
        '<span class="pick-nm">' + esc(c.name) + '</span>' +
        '<span class="pick-cb"><input type="checkbox" value="' + c.id + '"></span></label>';
    }).join("");
    openModal('<div class="md-title">' + o.title + '</div>' +
      '<div class="md-sub">' + o.sub + '</div>' +
      (o.nameField ? '<div class="md-field"><input class="md-input" id="pkName" placeholder="' + o.nameField + '" autocomplete="off"></div>' : '') +
      '<div class="pick-list">' + rows + '</div>' +
      '<div class="md-actions"><button class="md-btn ghost" data-x="cancel">Cancel</button>' +
      '<button class="md-btn" data-x="ok">' + o.confirm + '</button></div>');
    const h = $("#chatModalHost");
    h.querySelector('[data-x="cancel"]').onclick = closeModal;
    h.querySelector('[data-x="ok"]').onclick = () => {
      const ids = $$('.pick-list input:checked', h).map((i) => i.value);
      const name = o.nameField ? (h.querySelector("#pkName").value || "").trim() : "";
      if (o.nameField && !name) { h.querySelector("#pkName").focus(); toast("Enter a name"); return; }
      if (ids.length < (o.min || 1)) { toast("Select at least " + (o.min || 1) + " contact" + ((o.min || 1) > 1 ? "s" : "")); return; }
      closeModal(); o.onConfirm(ids, name);
    };
  }

  function openNewGroup() {
    pickContacts({ title: "New group", sub: "Pick members, then name your group.", nameField: "Group name",
      confirm: "Create", min: 1,
      onConfirm: (ids, name) => {
        const now = new Date();
        const tm = ((now.getHours() % 12) || 12) + ":" + ("0" + now.getMinutes()).slice(-2) + " " + (now.getHours() < 12 ? "am" : "pm");
        const c = { id: "grp_" + Date.now(), name: name, init: initialsOf(name), color: "#5B8DEF", group: true,
          status: (ids.length + 1) + " members", preview: "Group created", time: tm, unread: 0, pinned: false,
          thread: [{ day: "TODAY" }, { dir: "in", type: "text", text: "Group \u201C" + name + "\u201D created with " + ids.length + " member" + (ids.length === 1 ? "" : "s") + ".", time: tm }] };
        CONTACTS.unshift(c); renderList(); openConversation(c);
        toast("Group \u201C" + name + "\u201D created");
      } });
  }

  function openNewBroadcast() {
    pickContacts({ title: "New broadcast", sub: "Send one message to many contacts privately.", nameField: "List name",
      confirm: "Create list", min: 2,
      onConfirm: (ids, name) => {
        const now = new Date();
        const tm = ((now.getHours() % 12) || 12) + ":" + ("0" + now.getMinutes()).slice(-2) + " " + (now.getHours() < 12 ? "am" : "pm");
        const c = { id: "bc_" + Date.now(), name: name, init: "\u{1F4E2}", color: "#2BA84A", broadcast: true,
          status: ids.length + " recipients", preview: "Broadcast list", time: tm, unread: 0, pinned: false,
          thread: [{ day: "TODAY" }, { dir: "in", type: "text", text: "Broadcast list with " + ids.length + " recipients. Messages are sent privately to each.", time: tm }] };
        CONTACTS.unshift(c); renderList(); openConversation(c);
        toast("Broadcast list \u201C" + name + "\u201D created");
      } });
  }

  /* ---- Starred messages ---- */
  let STARRED = [
    { who: "Aarav Mehta", text: "Done! I'll send the payment link now.", time: "Today, 12:20 pm" },
    { who: "Priya Nair", text: "Yes, pushed it 10 mins ago \u2705", time: "Today, 11:44 am" },
  ];
  function openStarred() {
    function body() {
      return STARRED.length
        ? STARRED.map((m, i) => '<div class="star-row"><div class="star-tx"><div class="who">' + esc(m.who) +
            '</div><div class="msg">' + esc(m.text) + '</div><div class="tm">' + esc(m.time) + '</div></div>' +
            '<button class="star-x" data-unstar="' + i + '" aria-label="Unstar">' + I.starFilled + '</button></div>').join("")
        : '<div class="star-empty">' + I.starOutline + '<div>No starred messages</div><span>Tap and hold any message, then Star it, to keep it here.</span></div>';
    }
    openModal('<div class="md-title">Starred messages</div>' +
      '<div class="md-sub">Quick access to messages you\u2019ve starred.</div>' +
      '<div class="star-list" id="starList">' + body() + '</div>' +
      '<div class="md-actions"><button class="md-btn" data-x="ok">Done</button></div>');
    const h = $("#chatModalHost");
    h.querySelector('[data-x="ok"]').onclick = closeModal;
    h.querySelector("#starList").addEventListener("click", (e) => {
      const b = e.target.closest("[data-unstar]"); if (!b) return;
      STARRED.splice(parseInt(b.getAttribute("data-unstar"), 10), 1);
      h.querySelector("#starList").innerHTML = body(); toast("Removed from starred");
    });
  }

  /* ---- MUTE ---- */
  const MUTE_LABELS = { "8h": "8 hours", "1w": "1 week", "always": "Always" };
  function openMuteDialog() {
    toggleMenu(false);
    if (current.muted) {
      confirmDialog({ title: "Unmute " + esc(current.name) + "?",
        body: "You'll start getting notifications for this chat again.", ok: "Unmute",
        onOk: () => { current.muted = null; updateMuteIndicator(); toast("Unmuted"); } });
      return;
    }
    openModal('<div class="md-title">Mute notifications</div>' +
      '<div class="md-sub">No notifications for new messages from ' + esc(current.name) + '.</div>' +
      radioListHTML([["8h", "8 hours"], ["1w", "1 week"], ["always", "Always"]], "8h") +
      '<div class="md-actions"><button class="md-btn ghost" data-x="cancel">Cancel</button><button class="md-btn" data-x="ok">Mute</button></div>');
    const h = $("#chatModalHost");
    const getSel = wireRadios(h, "8h");
    h.querySelector('[data-x="cancel"]').onclick = closeModal;
    h.querySelector('[data-x="ok"]').onclick = () => {
      const v = getSel(); current.muted = v; closeModal(); updateMuteIndicator();
      toast(v === "always" ? "Muted" : "Muted for " + MUTE_LABELS[v]);
    };
  }
  function updateMuteIndicator() {
    const nameEl = $("#chName"); if (!nameEl) return;
    const icon = current.muted
      ? ' <span class="ch-mute"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M16.8 7.2A5 5 0 0 0 7 8c0 1.5-.3 2.8-.7 3.8M5.5 5.5A5 5 0 0 0 5 8c0 7-3 9-3 9h13"/><path d="M13.7 21a2 2 0 0 1-3.4 0"/><path d="M3 3l18 18"/></svg></span>'
      : "";
    nameEl.innerHTML = esc(current.name) + icon;
  }

  /* ---- DISAPPEARING MESSAGES ---- */
  const DISAPPEAR_LABELS = { off: "Off", "24h": "24 hours", "7d": "7 days", "90d": "90 days" };
  function openDisappearing() {
    toggleMenu(false);
    const cur = current.disappearing || "off";
    openModal('<div class="md-title">Disappearing messages</div>' +
      '<div class="md-sub">New messages in this chat will disappear after the selected duration.</div>' +
      radioListHTML([["off", "Off"], ["24h", "24 hours"], ["7d", "7 days"], ["90d", "90 days"]], cur) +
      '<div class="md-actions"><button class="md-btn ghost" data-x="cancel">Cancel</button><button class="md-btn" data-x="ok">Save</button></div>');
    const h = $("#chatModalHost");
    const getSel = wireRadios(h, cur);
    h.querySelector('[data-x="cancel"]').onclick = closeModal;
    h.querySelector('[data-x="ok"]').onclick = () => {
      const v = getSel(); current.disappearing = v; closeModal();
      toast(v === "off" ? "Disappearing messages off" : "Disappearing: " + DISAPPEAR_LABELS[v]);
    };
  }

  /* =========================================================
     WALLPAPER
     ========================================================= */
  const WALLPAPERS = [
    { id: "default", label: "Default", swatch: "var(--wa-bg)" },
    { id: "sand",    label: "Sand",    bg: "#EDE4D3" },
    { id: "mint",    label: "Mint",    bg: "#DCEBDC" },
    { id: "sky",     label: "Sky",     bg: "#DCE7F1" },
    { id: "rose",    label: "Blush",   bg: "#F1E2E2" },
    { id: "lilac",   label: "Lilac",   bg: "#E6E2F1" },
    { id: "graphite",label: "Graphite",bg: "linear-gradient(160deg,#243029,#101712)" },
    { id: "forest",  label: "Forest",  bg: "linear-gradient(160deg,#0e4d36,#08321f)" },
  ];
  function applyWallpaper(id) {
    const w = WALLPAPERS.find((x) => x.id === id) || WALLPAPERS[0];
    const area = $("#convView .chat-area"); if (!area) return;
    if (w.id === "default") { area.style.background = ""; area.style.backgroundImage = ""; area.style.backgroundSize = ""; }
    else { area.style.background = w.bg; area.style.backgroundImage = "none"; }
    try { localStorage.setItem("eva.wallpaper", id); } catch (e) {}
  }
  function openWallpaperPanel() {
    toggleMenu(false);
    let cur = "default"; try { cur = localStorage.getItem("eva.wallpaper") || "default"; } catch (e) {}
    const cells = WALLPAPERS.map((w) =>
      '<button class="wp-cell' + (w.id === cur ? " on" : "") + '" data-wp="' + w.id + '">' +
      '<span class="wp-swatch" style="background:' + (w.swatch || w.bg) + '"><span class="wp-b in"></span><span class="wp-b out"></span></span>' +
      '<span class="wp-lbl">' + w.label + "</span></button>"
    ).join("");
    openPanel(panelHeadHTML("Wallpaper", "Tap a colour to apply") +
      '<div class="panel-body"><div class="wp-grid">' + cells + "</div></div>");
    $$(".wp-cell").forEach((b) => b.addEventListener("click", () => {
      $$(".wp-cell").forEach((x) => x.classList.remove("on"));
      b.classList.add("on"); applyWallpaper(b.dataset.wp); toast("Wallpaper applied");
    }));
  }

  /* =========================================================
     MEDIA, LINKS & DOCS
     ========================================================= */
  function openMediaPanel() {
    toggleMenu(false);
    const media = Array.from({ length: 12 }, (_, i) =>
      '<div class="mg-cell">' + stripeCell("IMG " + (i + 1)) + "</div>").join("");
    const docs = [
      ["Burger_Street_Menu.pdf", "2.4 MB · pdf", "pdf"],
      ["Invoice_4471.pdf", "118 KB · pdf", "pdf"],
      ["Q2_Sales_Report.xlsx", "842 KB · xlsx", "xls"],
      ["Catalog_Update.docx", "356 KB · docx", "doc"],
    ].map((d) =>
      '<div class="doc-file"><div class="doc-ic ' + d[2] + '">' + d[2].toUpperCase() + '</div>' +
      '<div class="doc-meta"><div class="t">' + d[0] + '</div><div class="s">' + d[1] + "</div></div></div>").join("");
    const links = [
      ["youtu.be/double-smash", "Double Smash Combo — How we build it"],
      ["maps.app/mg-road", "Burger Street — MG Road"],
      ["burgerstreet.in/menu", "Today's combo menu — Burger Street"],
    ].map((l) =>
      '<div class="link-row"><span class="lk-ic"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M10 13a5 5 0 0 0 7 0l3-3a5 5 0 0 0-7-7l-1.5 1.5"/><path d="M14 11a5 5 0 0 0-7 0l-3 3a5 5 0 0 0 7 7l1.5-1.5"/></svg></span>' +
      '<div class="lk-meta"><div class="t">' + l[1] + '</div><div class="s">' + l[0] + "</div></div></div>").join("");
    openPanel(panelHeadHTML("Media, links and docs", esc(current.name)) +
      '<div class="mg-tabs"><button class="on" data-mt="media">Media</button><button data-mt="docs">Docs</button><button data-mt="links">Links</button></div>' +
      '<div class="panel-body">' +
        '<div class="mg-pane" data-pane="media"><div class="mg-grid">' + media + "</div></div>" +
        '<div class="mg-pane" data-pane="docs" hidden>' + docs + "</div>" +
        '<div class="mg-pane" data-pane="links" hidden>' + links + "</div>" +
      "</div>");
    $$(".mg-tabs button").forEach((b) => b.addEventListener("click", () => {
      $$(".mg-tabs button").forEach((x) => x.classList.remove("on")); b.classList.add("on");
      $$(".mg-pane").forEach((p) => { p.hidden = p.dataset.pane !== b.dataset.mt; });
    }));
  }

  /* =========================================================
     SCREEN NAVIGATION (list <-> conversation)
     ========================================================= */
  function setHeaderStatus(txt) { const s = $("#chStatus"); if (s) s.textContent = txt; }
  function showList() {
    closeChatSearch();
    cancelRecOnLeave();
    $("#convView").classList.add("hide-right");
    $("#listView").classList.remove("hide-left");
    var _d = document.querySelector(".device-screen"); if (_d) _d.classList.remove("chat-conv");
  }
  var _chatLogged = {};
  function openConversation(c) {
    closeChatSearch();
    cancelRecOnLeave();
    var _d = document.querySelector(".device-screen"); if (_d) _d.classList.add("chat-conv");
    current = c;
    draftOrder = []; if ($("#orderDraft")) renderDraft(); closeCatalog();
    // PASS 4: record the first time a conversation is opened, on the lead timeline
    try {
      if (window.AskEvaActivity && c && !_chatLogged[c.id]) {
        _chatLogged[c.id] = 1;
        window.AskEvaActivity.log({ mobile: c.phone, name: c.name }, { type: "chat", text: "Chat conversation opened", module: "Chat" });
      }
    } catch (e) {}
    // header
    $("#chName").textContent = c.name;
    updateMuteIndicator();
    setHeaderStatus(c.status);
    const av = $("#chAvatar");
    av.textContent = c.init;
    av.style.background = c.grad ? "var(--eva-gradient)" : c.color;
    av.style.color = "#fff"; av.style.border = "none";
    // thread
    renderConversation();
    updateAddLeadMenu();
    // mark read in list
    c.unread = 0; renderList();
    $("#listView").classList.add("hide-left");
    $("#convView").classList.remove("hide-right");
    applyInterveneUI();
    setTimeout(scrollToBottom, 60);
    setTimeout(maybeAIHandle, 450);
  }

  function renderList() {
    const wrap = $("#listScroll"); if (!wrap) return;
    const sorted = CONTACTS.slice().filter((c) => scopeOk(c) && matchFilter(c) && matchQuery(c));
    if (!sorted.length) {
      const q = listQuery.trim();
      const label = q ? 'No chats match \u201C' + esc(q) + '\u201D'
        : pickTag ? 'No chats tagged \u201C' + esc(pickTag) + '\u201D'
        : pickAgent ? 'No chats assigned to ' + esc(pickAgent)
        : 'No ' + (listFilter === "all" ? "" : listFilter + " ") + 'chats here';
      wrap.innerHTML = '<div class="list-empty"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/></svg><div>' + label + '</div><div class="em-sub">Try a different filter or search</div></div>';
      return;
    }
    wrap.innerHTML = sorted.map((c) => {
      const avBg = c.grad ? "background:var(--eva-gradient)" : "background:" + c.color;
      const typing = /typing/i.test(c.status || "");
      // derive a WhatsApp-style preview line (media glyph + read ticks)
      let preInner;
      if (typing) {
        preInner = '<span class="typing">typing…</span>';
      } else {
        // outgoing read-receipt tick if the last threaded message was sent by us
        const last = c.thread ? c.thread.slice().reverse().find((m) => m.dir) : null;
        let tickPre = "";
        if (last && last.dir === "out") {
          const tk = last.tick === "read" ? "read" : "sent";
          tickPre = '<span class="tick ' + tk + '">' + I.checkTwo + "</span>";
        }
        // media-type glyph based on preview text
        let mediaIc = "";
        const p = c.preview || "";
        if (/sticker/i.test(p)) mediaIc = '<span class="pre-ic">' + I.stickerSm + "</span>";
        else if (/photo|image|pic/i.test(p)) mediaIc = '<span class="pre-ic">' + I.cameraSm + "</span>";
        else if (/voice|audio|recording/i.test(p)) mediaIc = '<span class="pre-ic">' + I.micSm + "</span>";
        else if (/document|\.pdf|file/i.test(p)) mediaIc = '<span class="pre-ic">' + I.docSm + "</span>";
        if (mediaIc) tickPre = ""; // glyph represents the previewed (incoming) message
        preInner = tickPre + mediaIc + '<span class="pretxt">' + esc(p) + "</span>";
      }
      const endBottom = c.unread
        ? '<span class="badge">' + c.unread + "</span>"
        : (c.muted ? '<span class="mutei">' + (I.muteSmall || "") + "</span>" : "");
      let meta2 = "";
      if (c.intervened) meta2 += '<span class="iv-tag">Intervened</span>';
      if (c.leadStatus === "addlead") meta2 += '<span class="ls-tag addlead">Add to Leads</span>';
      else if (c.leadStatus === "customer") meta2 += '<span class="ls-tag customer">Customer</span>';
      (c.tags || []).slice(0, 2).forEach((t) => { meta2 += '<span class="row-tag">' + esc(t) + '</span>'; });
      return '<div class="conv-row ' + (c.unread ? "unread" : "") + '" data-id="' + c.id + '">' +
        '<span class="av" style="' + avBg + '">' + c.init + "</span>" +
        '<div class="mid"><div class="nm">' + esc(c.name) + "</div>" +
        '<div class="pre">' + preInner + "</div>" +
        (meta2 ? '<div class="row-tags">' + meta2 + "</div>" : "") + "</div>" +
        '<div class="end"><span class="time">' + c.time + "</span>" +
        endBottom +
        "</div></div>";
    }).join("");
    $$(".conv-row", wrap).forEach((r) => r.addEventListener("click", () => {
      const c = CONTACTS.find((x) => x.id === r.dataset.id); openConversation(c);
    }));
  }

  /* =========================================================
     CHAT MODULE UPDATES — intervention · AI · agents · tags
     ========================================================= */

  /* acting (logged-in) agent, used on intervention log entries */
  function actingAgent() {
    try {
      if (window.AskEvaPeople && AskEvaPeople.list) {
        const me = AskEvaPeople.list().find((a) => a.you);
        if (me && me.name) return me.name;
      }
    } catch (e) {}
    return "Eshan Rao";
  }
  function stamp() {
    const d = new Date();
    return d.toLocaleDateString("en-IN", { day: "2-digit", month: "short", year: "numeric" }) + ", " +
      ((d.getHours() % 12) || 12) + ":" + String(d.getMinutes()).padStart(2, "0") + " " + (d.getHours() < 12 ? "AM" : "PM");
  }
  function logIntervention(c, action) {
    if (!c) return;
    const ag = actingAgent();
    c.logs = c.logs || [];
    c.logs.unshift({ action: action, agent: ag, time: stamp() });
    saveCState();
    try { if (window.AskEvaActivity) window.AskEvaActivity.log({ mobile: c.phone, name: c.name }, { type: "intervene", text: action + " \u00b7 " + ag, module: "Chat" }); } catch (e) {}
    try { if (window.__profileJourney) window.__profileJourney(); } catch (e) {}
  }

  /* ---- intervention bar (AI-active pill  <->  live take-over banner) ---- */
  function buildInterveneBar() {
    const composer = $(".chat-composer"); if (!composer || $("#interveneBar")) return;
    const bar = document.createElement("div");
    bar.id = "interveneBar"; bar.className = "intervene-bar";
    bar.innerHTML =
      '<div class="iv-hint"><span class="dot"></span>AskEva AI is handling this chat</div>' +
      '<button class="iv-btn" id="ivStart"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.1" stroke-linecap="round" stroke-linejoin="round"><path d="M14.5 9.5a3.5 3.5 0 1 0-5 0"/><path d="M4 21a8 8 0 0 1 12-6.9"/><path d="M16 17h6M19 14v6"/></svg>Intervene<span class="arr"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12h14M13 6l6 6-6 6"/></svg></span></button>' +
      '<div class="iv-takeover"><span class="tk-dot"></span><div class="tk-txt"><b>You\u2019ve taken over</b><span>AI is paused \u2014 you\u2019re chatting with the customer</span></div>' +
      '<button class="iv-close" id="ivClose"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="M18 6L6 18M6 6l12 12"/></svg>Close</button></div>';
    composer.parentNode.insertBefore(bar, composer.nextSibling);
    $("#ivStart").addEventListener("click", startIntervention);
    $("#ivClose").addEventListener("click", stopIntervention);
    buildChatFooters();
  }
  /* ---- History footer (template-only) + Notes bar (both pinned at bottom) ---- */
  function buildChatFooters() {
    const area = $(".chat-area"); if (!area) return;
    if (!$("#historyBar")) {
      const hb = document.createElement("div");
      hb.id = "historyBar"; hb.className = "history-bar"; hb.hidden = true;
      hb.innerHTML =
        '<div class="hb-note"><div class="hb-ttl">Chat Conversation closed!</div>' +
        '<div class="hb-sub">Please send a template to initiate a chat conversation</div></div>' +
        '<button class="hb-btn" id="hbTemplate"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M16 16l-4-4-4 4"/><path d="M12 12v9"/><path d="M20.39 18.39A5 5 0 0 0 18 9h-1.26A8 8 0 1 0 3 16.3"/></svg>Send template</button>';
      area.appendChild(hb);
      $("#hbTemplate", hb).addEventListener("click", function () {
        if (!(window.AskEvaTemplates && window.AskEvaTemplates.open)) { toast("Templates unavailable"); return; }
        window.AskEvaTemplates.open({ title: "Send a template", onSend: function (t) { sendTemplate(t); refreshChatMode(); toast("Message sent successfully"); } });
      });
    }
  }
  function refreshChatMode() {
    const area = $(".chat-area"); if (!area) return;
    const hist = !!(current && isHistory(current) && !current.group && !current.broadcast);
    area.classList.toggle("is-history", hist);
    const hb = $("#historyBar"); if (hb) hb.hidden = !hist;
    updateNotesCount();
  }
  /* ---- per-conversation Notes (max 500 chars · add / edit / delete) ---- */
  var NOTES_KEY = "askeva.chat.notes.v1";
  var _notes = null;
  function notesAll() { if (_notes) return _notes; try { _notes = JSON.parse(localStorage.getItem(NOTES_KEY)) || {}; } catch (e) { _notes = {}; } return _notes; }
  function notesSave() { try { localStorage.setItem(NOTES_KEY, JSON.stringify(notesAll())); } catch (e) {} }
  function notesFor(id) { var a = notesAll(); return (a[id] = a[id] || []); }
  function updateNotesCount() {
    const el = $("#nbCount"); if (!el) return;
    const n = current ? notesFor(current.id).length : 0;
    el.textContent = n ? n : ""; el.style.display = n ? "" : "none";
  }
  function openNotesSheet() {
    if (!current) return;
    const id = current.id;
    function rows() {
      const list = notesFor(id);
      if (!list.length) return '<div class="nt-empty">No notes yet. Add one below — visible only to your team.</div>';
      return '<div class="nt-list">' + list.map(function (n, i) {
        return '<div class="nt-item" data-i="' + i + '"><div class="nt-text"></div>' +
          '<div class="nt-meta"><span class="nt-ts">' + esc(n.when || "") + '</span>' +
          '<span class="nt-acts"><button class="nt-edit" data-edit="' + i + '">Edit</button><button class="nt-del" data-del="' + i + '">Delete</button></span></div></div>';
      }).join("") + '</div>';
    }
    function body() {
      return rows() +
        '<div class="nt-add"><textarea id="ntInput" class="nt-ta" rows="3" maxlength="500" placeholder="Write a note (max 500 characters)…"></textarea>' +
        '<div class="nt-addfoot"><span class="nt-counter" id="ntCount">0/500</span><button class="nt-save" id="ntSave">Add note</button></div></div>';
    }
    openPicker({ title: "Notes", sub: current.name, body: body(), onMount: function (sheet) {
      var ta, cnt, save, editIdx = -1;
      function sync() { if (cnt && ta) cnt.textContent = (ta.value.length) + "/500"; }
      function rerender() { notesSave(); updateNotesCount(); var nb = sheet.querySelector(".pick-body") || sheet; nb.innerHTML = body(); bindAll(sheet); }
      function bindAll(root) {
        var l2 = notesFor(id);
        $$(".nt-item", root).forEach(function (it) { var i = +it.getAttribute("data-i"); var t = it.querySelector(".nt-text"); if (t && l2[i]) t.textContent = l2[i].text; });
        ta = root.querySelector("#ntInput"); cnt = root.querySelector("#ntCount"); save = root.querySelector("#ntSave"); editIdx = -1;
        sync();
        if (ta) ta.addEventListener("input", sync);
        $$("[data-del]", root).forEach(function (b) { b.addEventListener("click", function () {
          var di = +b.getAttribute("data-del");
          confirmDialog({ title: "Delete note?", body: "This permanently removes this note. This can\u2019t be undone.", ok: "Delete", danger: true,
            onOk: function () { l2.splice(di, 1); rerender(); toast("Note deleted"); } });
        }); });
        $$("[data-edit]", root).forEach(function (b) { b.addEventListener("click", function () { var i = +b.getAttribute("data-edit"); ta.value = l2[i].text; editIdx = i; sync(); ta.focus(); save.textContent = "Save changes"; }); });
        if (save) save.addEventListener("click", function () {
          var v = (ta.value || "").trim(); if (!v) { ta.focus(); return; }
          if (v.length > 500) v = v.slice(0, 500);
          if (editIdx >= 0) { l2[editIdx].text = v; l2[editIdx].when = noteStamp(); toast("Note updated"); }
          else { l2.unshift({ text: v, when: noteStamp() }); toast("Note added"); }
          rerender();
        });
      }
      bindAll(sheet);
    }});
  }
  function noteStamp() {
    var d = new Date(), h = d.getHours(), m = ("0" + d.getMinutes()).slice(-2), ap = h < 12 ? "am" : "pm";
    return (d.getMonth() + 1) + "/" + d.getDate() + "/" + d.getFullYear() + " · " + ((h % 12) || 12) + ":" + m + " " + ap;
  }
  function applyInterveneUI() {
    const bar = $("#interveneBar"), composer = $(".chat-composer");
    if (!bar || !composer) return;
    refreshChatMode();
    if (current && (current.group || current.broadcast)) {
      bar.classList.remove("show", "ai", "live");
      composer.classList.remove("ai-hidden");
      return;
    }
    bar.classList.add("show");
    if (current && current.intervened) {
      bar.classList.add("live"); bar.classList.remove("ai");
      composer.classList.remove("ai-hidden");
    } else {
      bar.classList.add("ai"); bar.classList.remove("live");
      composer.classList.add("ai-hidden");
      closeEmoji(); closeAttach();
    }
  }
  function startIntervention() {
    if (!current) return;
    current.intervened = true; saveCState();
    applyInterveneUI(); renderList();
    logIntervention(current, "Agent intervened");
    setTimeout(() => { const i = input(); if (i) i.focus(); }, 60);
  }
  function stopIntervention() {
    if (!current) return;
    current.intervened = false; saveCState();
    applyInterveneUI(); renderList();
    logIntervention(current, "Agent stopped intervention");
    logIntervention(current, "Conversation returned to AI");
    setTimeout(() => maybeAIHandle(true), 300);
  }

  /* ---- AI auto-reply while AI is active ---- */
  const AI_REPLIES = [
    "Got it \u2014 let me pull that up for you right away.",
    "Sure! I can help with that. Could you share a little more detail?",
    "I\u2019ve noted that down. Is there anything else I can help you with?",
    "Happy to help! Here\u2019s what I found for you.",
    "Thanks for your patience \u2014 here are the details you asked for."
  ];
  let aiTimer = null;
  function aiReplyFor(text) {
    const t = (text || "").toLowerCase();
    if (/\bhi\b|hello|hey|good morning|good evening/.test(t)) return "Hi there! \uD83D\uDC4B I\u2019m AskEva, the AI assistant for this account. How can I help you today?";
    if (/price|cost|how much|menu|combo|offer/.test(t)) return "Here are our latest options and pricing. Would you like me to start an order for you?";
    if (/order|buy|book|reserve/.test(t)) return "Great! I can set that up. Could you confirm the item and quantity?";
    if (/thanks|thank you|thx/.test(t)) return "You\u2019re welcome! \uD83D\uDE4C Anything else I can help with?";
    if (/\?\s*$/.test(text || "")) return "Good question \u2014 let me check that and confirm for you.";
    return AI_REPLIES[Math.floor(Math.random() * AI_REPLIES.length)];
  }
  function maybeAIHandle(force) {
    const c0 = current;
    if (!c0 || c0.intervened || c0.group || c0.broadcast) return;
    if (isHistory(c0)) return;   // History chats are read-only (template-send only)
    const thread = c0.thread || [];
    let last = null; for (let i = thread.length - 1; i >= 0; i--) { if (thread[i].dir) { last = thread[i]; break; } }
    if (!last || last.dir !== "in" || last._aiHandled) return;
    last._aiHandled = true;
    clearTimeout(aiTimer);
    aiTimer = setTimeout(() => {
      if (current !== c0 || c0.intervened) return;
      showTyping();
      setTimeout(() => {
        hideTyping();
        if (current !== c0 || c0.intervened) return;
        const reply = aiReplyFor(last.text);
        addMessage({ dir: "out", type: "text", text: reply, time: nowTime(), ai: true });
        c0.preview = reply; c0.time = nowTime(); renderList();
      }, 1100 + Math.random() * 700);
    }, force ? 500 : 850);
  }

  /* ---- Tags / Agents filter pickers ---- */
  function allTags() {
    const set = {};
    CONTACTS.forEach((c) => (c.tags || []).forEach((t) => { set[t] = (set[t] || 0) + 1; }));
    return Object.keys(set).sort((a, b) => a.localeCompare(b)).map((t) => ({ name: t, count: set[t] }));
  }
  function chatAgents() {
    let list = [];
    try { if (window.AskEvaPeople && AskEvaPeople.roster) list = AskEvaPeople.roster("chat").map((a) => ({ name: a.name, role: a.role || "Agent", color: a.color })); } catch (e) {}
    if (!list.length) list = [{ name: "Madhan", role: "Agent" }, { name: "Eshan Rao", role: "Admin" }, { name: "Kavya S", role: "Agent" }, { name: "Dev Patel", role: "Agent" }];
    return list;
  }
  function agentCount(name) { return CONTACTS.filter((c) => (c.agents || []).some((a) => a.toLowerCase() === name.toLowerCase())).length; }
  function avInitials(name) { return (name || "?").split(/\s+/).map((w) => w[0]).join("").slice(0, 2).toUpperCase(); }

  let pickHost = null;
  function closePicker() {
    if (!pickHost) return;
    const sc = pickHost.scrim, sh = pickHost.sheet;
    sc.classList.remove("show"); sh.classList.remove("show");
    setTimeout(() => { sc.remove(); sh.remove(); }, 280);
    pickHost = null;
  }
  function openPicker(o) {
    if (pickHost) { try { pickHost.scrim.remove(); pickHost.sheet.remove(); } catch (e) {} pickHost = null; }
    $$(".pick-sheet, .pick-scrim").forEach((n) => n.remove());
    const host = $(".device-screen") || document.body;
    const scrim = document.createElement("div"); scrim.className = "pick-scrim";
    const sheet = document.createElement("div"); sheet.className = "pick-sheet";
    sheet.innerHTML = '<div class="pick-grip"></div><div class="pick-head"><div class="t">' + o.title + '</div><div class="s">' + o.sub + '</div></div>' +
      '<div class="pick-body">' + o.body + '</div>' + (o.clear ? '<button class="pick-clear" id="pkClear">' + o.clear + '</button>' : '');
    host.appendChild(scrim); host.appendChild(sheet);
    requestAnimationFrame(() => { scrim.classList.add("show"); sheet.classList.add("show"); });
    scrim.addEventListener("click", closePicker);
    pickHost = { scrim: scrim, sheet: sheet };
    if (o.onMount) o.onMount(sheet);
  }
  const pkCheck = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><path d="M20 6L9 17l-5-5"/></svg>';
  const pkTagIc = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M20.6 13.4l-7.2 7.2a2 2 0 0 1-2.8 0l-7-7V3h6.6l7.2 7.2a2 2 0 0 1 0 2.8z"/><circle cx="7.6" cy="7.6" r="1.4" fill="currentColor"/></svg>';
  function openTagFilter() {
    const tags = allTags();
    const body = tags.length
      ? tags.map((t) => '<button class="pick-opt' + (pickTag.toLowerCase() === t.name.toLowerCase() ? " on" : "") + '" data-tag="' + esc(t.name) + '"><span class="pk-tagic">' + pkTagIc + '</span><span class="pk-mid"><span class="nm">' + esc(t.name) + '</span><span class="sub">' + t.count + ' contact' + (t.count === 1 ? "" : "s") + '</span></span><span class="pk-check">' + pkCheck + '</span></button>').join("")
      : '<div class="pick-empty">No tags yet. Add tags from a customer\u2019s profile.</div>';
    openPicker({ title: "Filter by tag", sub: "Show customers with the selected tag", body: body, clear: pickTag ? "Clear tag filter" : "",
      onMount: function (sheet) {
        $$(".pick-opt", sheet).forEach((b) => b.addEventListener("click", () => { pickTag = b.dataset.tag; listFilter = "tags"; setActiveChip("tags", pickTag); closePicker(); renderList(); }));
        const cl = $("#pkClear", sheet); if (cl) cl.addEventListener("click", () => { pickTag = ""; listFilter = "tags"; setActiveChip("tags", ""); closePicker(); renderList(); });
      } });
  }
  function openAgentFilter() {
    const ags = chatAgents();
    const body = ags.length
      ? ags.map((a) => { const cnt = agentCount(a.name), col = a.color || "#2BA84A";
          return '<button class="pick-opt' + (pickAgent.toLowerCase() === a.name.toLowerCase() ? " on" : "") + '" data-agent="' + esc(a.name) + '"><span class="pk-av" style="background:' + col + '">' + esc(avInitials(a.name)) + '</span><span class="pk-mid"><span class="nm">' + esc(a.name) + '</span><span class="sub">' + esc(a.role) + ' \u00b7 ' + cnt + ' chat' + (cnt === 1 ? "" : "s") + '</span></span><span class="pk-check">' + pkCheck + '</span></button>'; }).join("")
      : '<div class="pick-empty">No chat agents found in Team Management.</div>';
    openPicker({ title: "Filter by agent", sub: "From Team Management \u00b7 show only their assigned customers", body: body, clear: pickAgent ? "Clear agent filter" : "",
      onMount: function (sheet) {
        $$(".pick-opt", sheet).forEach((b) => b.addEventListener("click", () => { pickAgent = b.dataset.agent; listFilter = "agents"; setActiveChip("agents", pickAgent); closePicker(); renderList(); }));
        const cl = $("#pkClear", sheet); if (cl) cl.addEventListener("click", () => { pickAgent = ""; listFilter = "agents"; setActiveChip("agents", ""); closePicker(); renderList(); });
      } });
  }
  function setActiveChip(key, pick) {
    $$(".filter-chip").forEach((ch) => {
      const k = ch.dataset.filter || ch.textContent.trim().toLowerCase();
      ch.classList.toggle("on", k === key);
      if (k === "tags" || k === "agents") {
        const ps = ch.querySelector(".fc-pick");
        const active = (k === key) && pick;
        ch.classList.toggle("has-pick", !!active);
        if (ps) ps.textContent = active ? " · " + pick : "";
      }
    });
  }

  /* =========================================================
     BATCH 2 — tabs · attach · templates · export · lead status
     ========================================================= */
  let listScope = "live";   // chat-list scope: live = active in last 24h, history = older
  let _rendering = false;   // true while painting a thread, so addMessage doesn't bump activity
  function isHistory(c) { return (Date.now() - (c.lastTs || 0)) > 86400000; }   // 24h with no in/out message
  function scopeOk(c) { return listScope === "history" ? isHistory(c) : !isHistory(c); }
  function setScopeTabs() { $$(".chat-scope button").forEach((b) => b.classList.toggle("on", b.dataset.scope === listScope)); }
  function switchScope(mode) {
    if (mode !== "live" && mode !== "history") return;
    listScope = mode; setScopeTabs(); renderList();
  }
  function renderConversation() {
    const s = scrollEl(); if (!s || !current) return;
    s.innerHTML = "";
    const enc = document.createElement("div"); enc.className = "enc-note";
    enc.innerHTML = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="5" y="11" width="14" height="9" rx="2"/><path d="M8 11V8a4 4 0 0 1 8 0v3"/></svg>Messages are end-to-end encrypted. Tap to learn more.';
    s.appendChild(enc);
    _rendering = true;
    (current.thread || []).forEach((m) => { if (m.day) { const p = document.createElement("div"); p.className = "day-pill"; p.textContent = m.day; s.appendChild(p); } else if (m.dir) addMessage(m); });
    _rendering = false;
    setTimeout(scrollToBottom, 40);
  }

  /* ---- attach-sheet handlers ---- */
  /* Real device-file pickers — same supported formats as Leads / Appointments */
  const FILE_ACCEPT = {
    image: "image/*",
    video: ".mp4,video/mp4",
    audio: ".mp3,.ogg,audio/mpeg,audio/ogg",
    document: ".csv,.doc,.docx,.xls,.xlsx,.ppt,.pptx,.pdf,.txt,text/csv,text/plain,application/pdf,application/msword,application/vnd.openxmlformats-officedocument.wordprocessingml.document,application/vnd.ms-excel,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet,application/vnd.ms-powerpoint,application/vnd.openxmlformats-officedocument.presentationml.presentation",
  };
  const FILE_VALID = {
    image: /\.(jpe?g|png|gif|webp|bmp|svg|heic|heif|tiff?|avif)$/i,
    video: /\.(mp4)$/i,
    audio: /\.(mp3|ogg)$/i,
    document: /\.(csv|docx?|xlsx?|pptx?|pdf|txt)$/i,
  };
  const FILE_HINT = { image:"JPG, PNG, GIF, WebP, SVG…", video:"MP4", audio:"MP3 or OGG", document:"CSV, Word, Excel, PPT, PDF or TXT" };
  function fmtBytes(b) {
    if (b == null) return "";
    if (b < 1024) return b + " B";
    if (b < 1048576) return (b / 1024).toFixed(b < 10240 ? 1 : 0) + " KB";
    return (b / 1048576).toFixed(b < 10485760 ? 1 : 0) + " MB";
  }
  function docKind(ext) {
    ext = (ext || "").toLowerCase();
    if (ext === "pdf") return "pdf";
    if (ext === "xls" || ext === "xlsx" || ext === "csv") return "xls";
    if (ext === "ppt" || ext === "pptx") return "ppt";
    return "doc";
  }
  function mediaDuration(file, kind, cb) {
    try {
      const el = document.createElement(kind === "audio" ? "audio" : "video");
      el.preload = "metadata";
      el.onloadedmetadata = function () {
        const s = el.duration;
        cb(isFinite(s) && s > 0 ? (Math.floor(s / 60) + ":" + String(Math.round(s % 60)).padStart(2, "0")) : "");
        try { URL.revokeObjectURL(el.src); } catch (e) {}
      };
      el.onerror = function () { cb(""); };
      el.src = URL.createObjectURL(file);
    } catch (e) { cb(""); }
  }
  function pickChatFile(kind, multiple, cb) {
    const inp = document.createElement("input");
    inp.type = "file"; inp.accept = FILE_ACCEPT[kind] || ""; if (multiple) inp.multiple = true;
    inp.style.display = "none"; document.body.appendChild(inp);
    inp.addEventListener("change", function () {
      const files = Array.prototype.slice.call(inp.files || []);
      inp.remove();
      const rule = FILE_VALID[kind];
      const ok = files.filter(function (f) { return !rule || rule.test(f.name); });
      if (files.length && !ok.length) { toast("Unsupported file — accepted: " + (FILE_HINT[kind] || "")); return; }
      if (ok.length < files.length) toast("Some files skipped — accepted: " + (FILE_HINT[kind] || ""));
      if (ok.length) cb(ok);
    });
    inp.click();
  }
  function openVideoAttach() {
    closeAttach();
    pickChatFile("video", false, function (files) {
      var f = files[0], src = URL.createObjectURL(f);
      mediaDuration(f, "video", function (len) {
        addMessage({ dir:"out", type:"video", src:src, name:f.name, len:len || "", time:nowTime() });
        toast("Video sent");
      });
    });
  }
  function openAudioAttach() {
    closeAttach();
    pickChatFile("audio", false, function (files) {
      var f = files[0];
      mediaDuration(f, "audio", function (len) {
        addMessage({ dir:"out", type:"audiofile", name:f.name, size:fmtBytes(f.size), len:len || "", time:nowTime() });
        toast("Audio sent");
      });
    });
  }

  /* ---- global Templates + Quick Replies (shared-library.js single source) ---- */
  function openTemplateSend() {
    closeAttach();
    if (!(window.AskEvaTemplates && window.AskEvaTemplates.open)) { toast("Templates unavailable"); return; }
    window.AskEvaTemplates.open({ title: "Send a template", onSend: function (t) { sendTemplate(t); } });
  }
  function sendTemplate(t) {
    const qrs = chatQRList();
    const replies = qrs.slice(0, 3).map((q) => q.t);
    const m = { dir: "out", type: "template", name: t.n, text: t.p, cat: t.cat || t.type || "Template", replies: replies, time: nowTime() };
    if (current) { current.thread = current.thread || []; current.thread.push(m); }
    addMessage(m);
    if (current) { current.preview = "Template \u00b7 " + t.n; current.time = m.time; renderList(); }
  }
  const pkSendIc = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 12h14m0 0-5-5m5 5-5 5"/></svg>';
  /* Chat owns its OWN quick replies, independent of the Leads/shared set
     (AskEvaQuickReplies). Seeded once from whatever's there so nothing is lost,
     then edited only from chat. Shape: {t: title, m: message}. */
  var CHAT_QR_KEY = "askeva.chat.qr.v1";
  var CHAT_QR_DEFAULTS = [
    { t: "Greeting", m: "Hi! \uD83D\uDC4B Thanks for messaging us. How can I help you today?" },
    { t: "One moment", m: "Sure — give me a moment while I check that for you." },
    { t: "Anything else", m: "Is there anything else I can help you with?" },
    { t: "Thanks", m: "Thank you for reaching out! Have a great day. \uD83D\uDE4C" }
  ];
  var chatQR = null;
  function chatQRList() {
    if (chatQR) return chatQR;
    try { chatQR = JSON.parse(localStorage.getItem(CHAT_QR_KEY)); } catch (e) { chatQR = null; }
    // migrate the earlier accidental copy: if the stored set is identical to the
    // shared Leads list, replace it with chat's own defaults so chat is independent
    var leads = (window.AskEvaQuickReplies && AskEvaQuickReplies.list()) || [];
    var looksLikeLeads = chatQR && leads.length && chatQR.length === leads.length &&
      chatQR.every(function (q, i) { return q.t === (leads[i].t || "") && q.m === (leads[i].m || ""); });
    if (!chatQR || looksLikeLeads) {
      chatQR = CHAT_QR_DEFAULTS.map(function (q) { return { t: q.t, m: q.m }; });
      chatQRSave();
    }
    return chatQR;
  }
  function chatQRSave() { try { localStorage.setItem(CHAT_QR_KEY, JSON.stringify(chatQR || [])); } catch (e) {} }
  function openChatQRAdd() {
    var body = '<div class="qra-form">' +
      '<label class="qra-lbl">Title</label><input id="cqrT" class="qra-in" type="text" placeholder="Quick reply title" maxlength="60">' +
      '<label class="qra-lbl">Message</label><textarea id="cqrM" class="qra-in" rows="4" placeholder="Type the message…" maxlength="1000"></textarea>' +
      '<button class="qra-save" id="cqrSave">Add quick reply</button>' +
      '<div class="qra-hint">It\u2019ll be saved to this chat and appear in your Quick replies list to send in one tap.</div></div>';
    openPicker({ title: "Add quick reply", sub: "Saved to this chat module only", body: body, onMount: function (sheet) {
      var save = sheet.querySelector("#cqrSave");
      save.addEventListener("click", function () {
        var t = (sheet.querySelector("#cqrT").value || "").trim();
        var m = (sheet.querySelector("#cqrM").value || "").trim();
        if (!t) { toast("Enter a title"); return; }
        if (!m) { toast("Enter a message"); return; }
        chatQRList().unshift({ t: t, m: m }); chatQRSave();
        closePicker(); toast("Quick reply added"); openQuickReply();
      });
    }});
  }
  function openQuickReply() {
    closeAttach();
    const qrs = chatQRList();
    const addBtn = '<button class="pick-opt pick-add" data-add="1"><span class="pk-qric">' +
      '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 5v14M5 12h14"/></svg></span>' +
      '<span class="pk-mid"><span class="nm">Add quick reply</span><span class="sub">Create one for this chat</span></span></button>';
    const list = qrs.length
      ? qrs.map((q, i) => '<button class="pick-opt" data-qr="' + i + '"><span class="pk-qric"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></svg></span><span class="pk-mid"><span class="nm">' + esc(q.t) + '</span><span class="sub">' + esc(q.m) + '</span></span><span class="pk-count">' + pkSendIc + '</span></button>').join("")
      : '<div class="pick-empty">No quick replies yet — add one below.</div>';
    openPicker({ title: "Quick replies", sub: "Tap to send instantly", body: addBtn + list, onMount: function (sheet) {
      var add = sheet.querySelector('[data-add]'); if (add) add.addEventListener("click", function () { closePicker(); openChatQRAdd(); });
      $$(".pick-opt[data-qr]", sheet).forEach((b) => b.addEventListener("click", () => {
        const q = qrs[parseInt(b.dataset.qr, 10)]; closePicker(); if (!q) return;
        const qm = { dir: "out", type: "text", text: q.m, time: nowTime() };
        if (current) { current.thread = current.thread || []; current.thread.push(qm); }
        addMessage(qm);
        if (current) { current.preview = q.m; current.time = qm.time; renderList(); }
        autoReply(q.m);
      }));
    }});
  }

  /* ---- chat export (TXT + PDF) ---- */
  function senderType(m) { return m.dir === "in" ? "Customer" : (m.ai ? "AI" : "Agent"); }
  function phoneOf(c) { return c.phone ? (String(c.phone).charAt(0) === "+" ? c.phone : "+" + c.phone) : "\u2014"; }
  function msgText(m) {
    switch (m.type) {
      case "text": return m.text || "";
      case "template": return "[Template: " + (m.name || "") + "] " + (m.text || "");
      case "image": case "aiimage": return "[Photo]";
      case "video": return "[Video]";
      case "voice": return "[Voice message]";
      case "document": return "[Document: " + (m.name || "") + "]";
      case "location": return "[Location: " + (m.title || "") + "]";
      case "payment": return "[Payment request: \u20B9" + Math.round(m.amount || 0) + "]";
      case "feedback": return m.submitted ? ("[Feedback: " + (m.rating || 0) + "/5]") : "[Feedback request]";
      default: return "[" + (m.type || "message") + "]";
    }
  }
  function buildTranscript(c) {
    const lines = ["AskEva — Chat Transcript", "Customer: " + c.name, "Phone: " + phoneOf(c), "Exported: " + stamp(), ""];
    const dump = (arr) => (arr || []).forEach((m) => {
      if (m.day) { lines.push("", "— " + m.day + " —"); return; }
      if (!m.dir) return;
      lines.push("[" + (m.time || "") + "] " + senderType(m) + ": " + msgText(m));
    });
    dump(c.thread);
    return lines.join("\n");
  }
  function downloadChatTxt(c) {
    const blob = new Blob([buildTranscript(c)], { type: "text/plain;charset=utf-8" });
    const a = document.createElement("a");
    a.href = URL.createObjectURL(blob);
    a.download = "chat-" + (c.name || "export").replace(/\s+/g, "_") + ".txt";
    document.body.appendChild(a); a.click();
    setTimeout(() => { URL.revokeObjectURL(a.href); a.remove(); }, 600);
    toast("Chat exported as TXT");
  }
  function downloadChatPdf(c) {
    const rows = (arr) => (arr || []).map((m) => {
      if (m.day) return '<tr><td colspan="3" class="day">' + esc(m.day) + '</td></tr>';
      if (!m.dir) return "";
      return '<tr><td class="tm">' + esc(m.time || "") + '</td><td class="who ' + (m.dir === "in" ? "cust" : (m.ai ? "ai" : "agent")) + '">' + senderType(m) + '</td><td class="msg">' + esc(msgText(m)) + '</td></tr>';
    }).join("");
    const css = "body{font-family:-apple-system,Segoe UI,Roboto,sans-serif;color:#15231A;margin:30px}h1{font-size:20px;margin:0 0 2px}.meta{color:#4D5D52;font-size:13px;margin-bottom:16px}.sec{font-size:12px;font-weight:800;letter-spacing:.06em;text-transform:uppercase;color:#2BA84A;margin:18px 0 6px}table{width:100%;border-collapse:collapse;font-size:13px}td{padding:7px 8px;border-bottom:1px solid #EEF1EC;vertical-align:top}td.tm{white-space:nowrap;color:#8A978D;width:72px}td.who{white-space:nowrap;font-weight:800;width:72px}td.who.cust{color:#2563EB}td.who.ai{color:#177A36}td.who.agent{color:#C77B16}td.day{text-align:center;color:#8A978D;font-weight:700;background:#F6F8F5}";
    const html = '<!doctype html><html><head><meta charset="utf-8"><title>Chat \u2014 ' + esc(c.name) + '</title><style>' + css + '</style></head><body>' +
      '<h1>Chat Transcript \u2014 ' + esc(c.name) + '</h1><div class="meta">Phone: ' + esc(phoneOf(c)) + ' &nbsp;\u00b7&nbsp; Exported: ' + esc(stamp()) + '</div>' +
      '<table>' + rows(c.thread) + '</table>' +
      '<scr' + 'ipt>window.onload=function(){setTimeout(function(){window.print();},350);};</scr' + 'ipt></body></html>';
    const w = window.open("", "_blank");
    if (!w) { toast("Allow pop-ups to export as PDF"); return; }
    w.document.open(); w.document.write(html); w.document.close();
    toast("Opening PDF \u2014 choose \u201CSave as PDF\u201D");
  }
  function openExport(c) {
    c = c || current; if (!c) return;
    openModal('<div class="md-title">Download chat</div><div class="md-sub">Export your conversation with ' + esc(c.name) + ' \u2014 includes name, phone, timestamps, sender type and full message history.</div>' +
      '<div class="md-actions" style="margin-top:16px"><button class="md-btn ghost" data-x="txt">Download .TXT</button><button class="md-btn" data-x="pdf">Download .PDF</button></div>');
    const h = $("#chatModalHost");
    h.querySelector('[data-x="txt"]').onclick = function () { closeModal(); downloadChatTxt(c); };
    h.querySelector('[data-x="pdf"]').onclick = function () { closeModal(); downloadChatPdf(c); };
  }

  /* ---- lead-status pipeline (Add to Leads → Active Lead → Customer) ---- */
  function logStatus(c, text) {
    c.statusLogs = c.statusLogs || [];
    c.statusLogs.unshift({ text: text, time: stamp() });
    saveCState();
    try { if (window.AskEvaActivity) window.AskEvaActivity.log({ mobile: c.phone, name: c.name }, { type: "status", text: text, module: "Leads" }); } catch (e) {}
  }
  function setLeadStatus(c, status, logText) {
    c = c || current; if (!c) return;
    c.leadStatus = status; saveCState();
    if (logText) logStatus(c, logText);
    updateLeadStatusUI(); renderList();
  }
  /* round-robin agent + REAL Lead creation. Resolves audit C-02/C-03: a chat is
     no longer just a cosmetic label — it writes an owned row into the Leads store. */
  var _leadRR = 0;
  function chatLeadAgents() {
    if (window.AskEvaPeople && window.AskEvaPeople.roster) {
      var r = window.AskEvaPeople.roster("leads").map(function (a) { return a.email; }).filter(Boolean);
      if (r.length) return r;
    }
    return ["testerr@gmail.com", "eshan@tunepath.com"];
  }
  function createRealLeadFromChat(c, source) {
    if (!c || !window.AskEvaAddLead) return null;
    var phone = (c.phone || "").replace(/\D/g, "");
    if (window.AskEvaActivity && window.AskEvaActivity.find) {
      var ex = window.AskEvaActivity.find({ mobile: phone, name: c.name });
      if (ex) { c._leadId = ex.id; return ex; }   // dedupe: never two leads per contact
    }
    var ags = chatLeadAgents(); var agent = ags[_leadRR++ % ags.length] || "Unassigned";
    var lead = window.AskEvaAddLead({ name: c.name || "New contact", mobile: phone, status: "new",
      source: source || "Chat", assigned: agent, description: "Auto-created from WhatsApp chat" });
    if (window.AskEvaSaveLeads) window.AskEvaSaveLeads();
    if (lead) c._leadId = lead.id;
    return lead;
  }
  function addToLeads(c) {
    c = c || current; if (!c) return;
    if (c.leadStatus !== "addlead") { toast("Already in Leads"); return; }
    setLeadStatus(c, "active", "Lead status changed to Active Lead");
    var L = createRealLeadFromChat(c, "Chat");
    toast(L ? c.name + " added to Leads \u00b7 assigned to " + (String(L.assigned || "").split("@")[0] || "an agent") : c.name + " \u2014 now an Active Lead");
  }
  function syncToCustomer(c) {
    c = c || current; if (!c) return;
    if (c.leadStatus === "customer") { toast("Already a customer"); return; }
    logStatus(c, "Lead synced");
    setLeadStatus(c, "customer", "Lead converted to Customer");
    if (window.AskEvaConvertLead) window.AskEvaConvertLead({ name: c.name, mobile: c.phone });
    toast(c.name + " converted to Customer");
  }
  function updateAddLeadMenu() { const btn = $("#hmAddLead"); if (btn) btn.style.display = (current && current.leadStatus === "addlead") ? "" : "none"; }
  function updateLeadStatusUI() { updateAddLeadMenu(); try { if (window.__profileLeadStatus) window.__profileLeadStatus(); } catch (e) {} }

  /* =========================================================
     WIRING
     ========================================================= */
  function init() {
    buildInterveneBar();
    // composer
    input().addEventListener("input", refreshComposer);
    input().addEventListener("keydown", (e) => {
      if (e.key === "Enter" && !e.shiftKey) { e.preventDefault(); sendText(); }
    });
    micBtn().addEventListener("click", () => {
      if (micBtn().classList.contains("is-send")) sendText();
      else if (micBtn().classList.contains("recording")) stopRec(true);
      else startRec();
    });
    $("#recCancel").addEventListener("click", () => stopRec(false));
    var _rs = $("#recSend"); if (_rs) _rs.addEventListener("click", () => stopRec(true));
    var _rp = $("#recPause"); if (_rp) _rp.addEventListener("click", togglePauseRec);
    $("#emojiBtn").addEventListener("click", toggleEmoji);
    $("#attachBtn").addEventListener("click", () => { closeEmoji(); openAttach(); });
    $("#cameraBtn").addEventListener("click", openCamera);
    $("#sheetScrim").addEventListener("click", closeAttach);
    input().addEventListener("focus", closeEmoji);

    // attachment options
    const acts = { gallery:openGallery, camera:openCamera, location:openLocation, contact:openContact,
      document:openDocument, poll:openPoll, event:openEvent, ai:openAI,
      video:openVideoAttach, audio:openAudioAttach, template:openTemplateSend, quick:openQuickReply, catalog:openCatalog };
    $$(".attach-item").forEach((b) => b.addEventListener("click", () => { const fn = acts[b.dataset.act]; if (fn) fn(); }));

    // camera controls
    $("#camClose").addEventListener("click", closeCamera);
    $("#camShutter").addEventListener("click", shutterPress);
    $$(".cam-mode").forEach((m) => m.addEventListener("click", () => setCamMode(m.dataset.mode)));
    $("#camFlip").addEventListener("click", () => { camFacing = camFacing === "back" ? "front" : "back"; toast(camFacing === "front" ? "Front camera" : "Back camera"); });
    $("#camFlash2").addEventListener("click", () => toast("Flash"));
    $("#camGallery").addEventListener("click", () => { closeCamera(); openGallery(); });

    // header
    $("#reopenBtn").addEventListener("click", showList);          // back arrow -> chat list
    $("#chProfile").addEventListener("click", () => { if (window.__drawer) window.__drawer.open(); }); // tap name/avatar -> profile
    $("#headSearchBtn").addEventListener("click", openChatSearch);
    $("#headMenuBtn").addEventListener("click", (e) => { e.stopPropagation(); toggleMenu(); });
    $("#menuScrim").addEventListener("click", () => toggleMenu(false));
    $$("#headMenu button").forEach((b) => b.addEventListener("click", () => {
      toggleMenu(false);
      switch (b.dataset.menu) {
        case "profile": if (window.__drawer) window.__drawer.open(); break;
        case "media": openMediaPanel(); break;
        case "search": openChatSearch(); break;
        case "mute": openMuteDialog(); break;
        case "download": openExport(); break;
        case "markunread":
          if (current) {
            current.unread = current.unread || 1;
            toast("Marked as unread");
            showList(); renderList();
          }
          break;
        case "addlead": addToLeads(); break;
        case "block": confirmDialog({ title: "Block " + esc(current.name) + "?",
          body: "Blocked contacts can no longer message or call you. You can unblock them anytime.", ok: "Block", danger: true,
          onOk: () => { if (current) { current.blocked = true; if (window.AskEvaContactsAPI) window.AskEvaContactsAPI.optOut({ name: current.name, mobile: current.phone }, "blocked"); } toast(esc(current && current.name) + " blocked"); } }); break;
        case "report": confirmDialog({ title: "Report " + esc(current.name) + "?",
          body: "The last 5 messages from this contact will be forwarded to AskEva. They won\u2019t be notified.", ok: "Report", danger: true,
          onOk: () => toast("Reported to AskEva") }); break;
      }
    }));

    // chat list
    renderList();
    $("#listBack") && $("#listBack").addEventListener("click", () => {});
    $$(".filter-chip").forEach((c) => c.addEventListener("click", () => {
      const k = c.dataset.filter || c.textContent.trim().toLowerCase();
      if (k === "tags") { openTagFilter(); return; }
      if (k === "agents") { openAgentFilter(); return; }
      listFilter = k; pickTag = ""; pickAgent = "";
      setActiveChip(k, "");
      renderList();
    }));
    // functional chat-list search (name \u00b7 phone \u00b7 tags \u00b7 agents \u00b7 partial \u00b7 case-insensitive)
    const lsInput = $(".list-search input");
    const lsClear = $(".list-search .ls-clear");
    if (lsInput) lsInput.addEventListener("input", () => {
      listQuery = lsInput.value || "";
      if (lsClear) lsClear.classList.toggle("show", !!listQuery.trim());
      renderList();
    });
    if (lsClear) lsClear.addEventListener("click", () => { lsInput.value = ""; listQuery = ""; lsClear.classList.remove("show"); renderList(); lsInput.focus(); });
    // Live Chat / History scope tabs (conversation-level, on the chat list)
    setScopeTabs();
    $$(".chat-scope button").forEach((b) => b.addEventListener("click", () => switchScope(b.dataset.scope)));
    $$(".list-tabs button").forEach((b) => b.addEventListener("click", () => {
      $$(".list-tabs button").forEach((x)=>x.classList.remove("active")); b.classList.add("active");
      if (b.dataset.tab !== "chats") toast(b.querySelector(".tl").textContent + " — coming soon");
    }));
    $("#listFab") && $("#listFab").addEventListener("click", openNewChat);
    $("#newCamBtn") && $("#newCamBtn").addEventListener("click", openCamera);

    // chat-list overflow (3-dot) menu
    const lMenu = $("#listMenu"), lScrim = $("#listMenuScrim"), lBtn = $("#listMenuBtn");
    function closeListMenu() { if (lMenu) lMenu.classList.remove("show"); if (lScrim) lScrim.classList.remove("show"); }
    function openListMenu() { if (lMenu) lMenu.classList.add("show"); if (lScrim) lScrim.classList.add("show"); }
    if (lBtn) lBtn.addEventListener("click", (e) => { e.stopPropagation(); (lMenu && lMenu.classList.contains("show")) ? closeListMenu() : openListMenu(); });
    if (lScrim) lScrim.addEventListener("click", closeListMenu);
    $$("#listMenu button").forEach((b) => b.addEventListener("click", () => {
      const a = b.getAttribute("data-lmenu"); closeListMenu();
      if (a === "tags") { openTagFilter(); return; }
      if (a === "agents") { openAgentFilter(); return; }
      if (a === "all" || a === "unread" || a === "read" || a === "intervened" || a === "prospects") {
        listFilter = a; pickTag = ""; pickAgent = "";
        setActiveChip(a, "");
        renderList();
      }
    }));

    // open the primary conversation initially
    openConversation(CONTACTS[0]);
    refreshComposer();

    // expose a small API for the app shell (Leads -> chat deep links)
    window.__chat = {
      openById: function (id) { var c = CONTACTS.find(function (x) { return x.id === id; }); if (c) openConversation(c); },
      /* open a chat with this person; if none exists yet, start a fresh one */
      openWith: function (name, phone) {
        name = (name || "").trim();
        var nm = name.toLowerCase();
        var c = nm && CONTACTS.find(function (x) { return (x.name || "").trim().toLowerCase() === nm; });
        if (!c) {
          var now = new Date();
          var tm = ((now.getHours() % 12) || 12) + ":" + ("0" + now.getMinutes()).slice(-2) + " " + (now.getHours() < 12 ? "am" : "pm");
          c = {
            id: "nc_" + Date.now(), name: name || "New contact", init: initialsOf(name || "New"),
            color: "var(--eva-gradient)", grad: true, status: "online",
            preview: "Draft started", time: tm, unread: 0, pinned: false, phone: (phone || "").replace(/\s/g, ""),
            thread: [{ day: "TODAY" }]
          };
          CONTACTS.unshift(c);
          if (phone) {
            window.__pendingChatLeads = window.__pendingChatLeads || [];
            window.__pendingChatLeads.push({ name: name, mobile: (phone || "").replace(/\s/g, ""), source: "Chat-Sync", channel: "Chat" });
          }
          renderList();
        }
        openConversation(c);
        return c;
      },
      /* deliver a message into a contact's thread WITHOUT navigating to it
         (used when a reminder fires for whoever it concerns) */
      deliverToThread: function (target, msg) {
        target = target || {}; msg = msg || {};
        var ph = (target.phone || "").replace(/\D/g, "");
        var c = (ph && CONTACTS.find(function (x) { var xp = (x.phone || "").replace(/\D/g, ""); return xp && xp.slice(-10) === ph.slice(-10); }))
             || (target.name && CONTACTS.find(function (x) { return (x.name || "").trim().toLowerCase() === (target.name || "").trim().toLowerCase(); })) || null;
        if (!c) {
          var now = new Date(); var tm = ((now.getHours() % 12) || 12) + ":" + ("0" + now.getMinutes()).slice(-2) + " " + (now.getHours() < 12 ? "am" : "pm");
          c = { id: "nc_" + Date.now(), name: target.name || "New contact", init: initialsOf(target.name || "New"),
            color: "var(--eva-gradient)", grad: true, status: "online", preview: "", time: tm, unread: 0, pinned: false, phone: ph, thread: [{ day: "TODAY" }] };
          CONTACTS.unshift(c);
        }
        var m = { dir: "in", type: msg.type || "text", time: nowTime() };
        if (m.type === "reminder") { m.text = msg.text || ""; m.whenLabel = msg.whenLabel || ""; m.agent = msg.agent || ""; m.customer = msg.customer || c.name; }
        else { m.text = msg.text || ""; }
        c.thread = c.thread || []; c.thread.push(m);
        c.lastTs = Date.now();
        c.preview = m.type === "reminder" ? ("\u23F0 Reminder \u00b7 " + (m.text || "")) : (m.text || "Message");
        c.time = m.time;
        if (c === current) addMessage(m); else c.unread = (c.unread || 0) + 1;
        renderList();
        return c;
      },
      showList: showList,
      contacts: CONTACTS,
      current: function () { return current; },
      setMuted: function (on) {
        if (!current) return;
        current.muted = on ? (current.muted || "always") : null;
        updateMuteIndicator();
        renderList();
      },
      isMuted: function () { return !!(current && current.muted); },
      /* WhatsApp-style share: pick a contact (or several) and send media into that
         chat (creating the conversation view). Used by the QR-code "Chat" share. */
      shareImage: function (opts) {
        opts = opts || {};
        pickContacts({ title: opts.title || "Send to", sub: opts.sub || "Select whom to send it to", confirm: "Send", min: 1,
          onConfirm: function (ids) {
            var tm = nowTime();
            ids.forEach(function (id) {
              var c = CONTACTS.find(function (x) { return x.id === id; });
              if (c) { c.thread = c.thread || []; c.thread.push({ dir: "out", type: "image", label: "photo", time: tm }); c.preview = "Photo"; c.time = tm; }
            });
            var first = CONTACTS.find(function (x) { return x.id === ids[0]; });
            renderList();
            if (first) openConversation(first);
            toast(ids.length > 1 ? ("Sent to " + ids.length + " chats") : ("Sent to " + (first ? first.name : "chat")));
          }
        });
      },
      sendPaymentLink: function (amount, opts) {
        opts = opts || {};
        var its = (opts.items && opts.items.length)
          ? opts.items.map(function (it) { return { name: it.name || "Item", price: it.price || 0, qty: it.qty || 1 }; })
          : [{ name: opts.note || "Payment", price: amount, qty: 1 }];
        var m = { type: "order", dir: "out", items: its, orderId: "ev" + String(Date.now()).slice(-6),
          shipping: opts.shipping || 0, biz: opts.biz || "AskEva", paid: false, time: nowTime() };
        addMessage(m);
        if (current) { current.preview = "Payment request \u00b7 \u20B9" + Math.round(amount).toLocaleString("en-IN"); current.time = m.time; renderList(); }
        return m;
      },
      /* Appointment flow: open the patient's chat and post a payment request
         that carries the appointment id (so paying syncs back to Appointments
         and auto-triggers the feedback request). */
      requestAppointmentPayment: function (target, opts) {
        opts = opts || {}; target = target || {};
        var c = (target.id && CONTACTS.find(function (x) { return x.id === target.id; })) || null;
        if (c) openConversation(c); else c = window.__chat.openWith(target.name, target.phone);
        var amount = Math.round(opts.amount || 0);
        var m = { type: "payment", dir: "out", amount: amount, note: opts.note || "Appointment payment",
          apptId: opts.apptId, deptName: opts.deptName || "", time: nowTime() };
        if (current) { current.thread = current.thread || []; current.thread.push(m); }
        addMessage(m);
        if (current) { current.preview = "Payment request \u00b7 \u20B9" + amount.toLocaleString("en-IN"); current.time = m.time; renderList(); }
        return c;
      },
      /* Appointment flow: open the patient's chat and post a feedback request
         (used directly for prepaid/zero-amount; auto-sent after payment otherwise). */
      requestAppointmentFeedback: function (target, opts) {
        opts = opts || {}; target = target || {};
        var c = (target.id && CONTACTS.find(function (x) { return x.id === target.id; })) || null;
        if (c) openConversation(c); else c = window.__chat.openWith(target.name, target.phone);
        sendFeedbackBubble({ apptId: opts.apptId, deptName: opts.deptName });
        return c;
      },
      /* Appointment USER-ALERT: silently deliver a configured WhatsApp template
         into the customer's chat thread (no navigation). Mirrors how appointment
         alerts go out as templates to the customer. */
      postApptAlert: function (target, tpl) {
        if (!tpl) return null;
        target = target || {};
        var ph = (target.phone || "").replace(/\D/g, "");
        var c = (ph && CONTACTS.find(function (x) { var xp = (x.phone || "").replace(/\D/g, ""); return xp && xp.slice(-10) === ph.slice(-10); }))
             || (target.name && CONTACTS.find(function (x) { return (x.name || "").trim().toLowerCase() === (target.name || "").trim().toLowerCase(); })) || null;
        if (!c) {
          var now = new Date(); var tm = ((now.getHours() % 12) || 12) + ":" + ("0" + now.getMinutes()).slice(-2) + " " + (now.getHours() < 12 ? "am" : "pm");
          c = { id: "nc_" + Date.now(), name: target.name || "Customer", init: initialsOf(target.name || "C"),
            color: "var(--eva-gradient)", grad: true, status: "online", preview: "", time: tm, unread: 0, pinned: false, phone: ph, thread: [{ day: "TODAY" }] };
          CONTACTS.unshift(c);
        }
        var replies = chatQRList().slice(0, 3).map(function (q) { return q.t; });
        var m = { dir: "out", type: "template", name: tpl.n || "Alert", text: tpl.text || tpl.p || "",
          cat: tpl.cat || "Template", replies: replies, time: nowTime() };
        c.thread = c.thread || []; c.thread.push(m); c.lastTs = Date.now();
        c.preview = "Template \u00b7 " + (tpl.n || "Alert"); c.time = m.time;
        if (c === current) addMessage(m);
        renderList();
        return c;
      },
      /* Ticketing → WhatsApp: silently deliver an agent message (reply / template /
         quick-reply / video note) from a ticket into the customer's chat thread,
         WITHOUT navigating away from the ticket. Everything an agent sends from a
         ticket reflects in Chats so it's ready for real WhatsApp integration. */
      postTicketMessage: function (target, msg) {
        target = target || {}; msg = msg || {};
        var ph = (target.phone || "").replace(/\D/g, "");
        var c = (ph && CONTACTS.find(function (x) { var xp = (x.phone || "").replace(/\D/g, ""); return xp && xp.slice(-10) === ph.slice(-10); }))
             || (target.name && CONTACTS.find(function (x) { return (x.name || "").trim().toLowerCase() === (target.name || "").trim().toLowerCase(); })) || null;
        if (!c) {
          var now = new Date(); var tm = ((now.getHours() % 12) || 12) + ":" + ("0" + now.getMinutes()).slice(-2) + " " + (now.getHours() < 12 ? "am" : "pm");
          c = { id: "nc_" + Date.now(), name: target.name || "Customer", init: initialsOf(target.name || "C"),
            color: "var(--eva-gradient)", grad: true, status: "online", preview: "", time: tm, unread: 0, pinned: false, phone: ph, thread: [{ day: "TODAY" }] };
          CONTACTS.unshift(c);
        }
        var m, preview;
        if (msg.type === "template") {
          var replies = chatQRList().slice(0, 3).map(function (q) { return q.t; });
          m = { dir: "out", type: "template", name: msg.name || "Template", text: msg.text || "", cat: msg.cat || "Template", replies: replies, time: nowTime() };
          preview = "Template \u00b7 " + (msg.name || "Template");
        } else if (msg.type === "video") {
          m = { dir: "out", type: "text", text: "\uD83C\uDFA5 Video note" + (msg.text ? " \u00b7 " + msg.text : ""), time: nowTime() };
          preview = "\uD83C\uDFA5 Video note";
        } else {
          m = { dir: "out", type: "text", text: msg.text || "", time: nowTime() };
          preview = msg.text || "Message";
        }
        c.thread = c.thread || []; c.thread.push(m); c.lastTs = Date.now();
        c.preview = preview; c.time = m.time;
        if (c === current) addMessage(m);
        renderList();
        return c;
      },
      setAgents: function (c, arr) { c = c || current; if (!c) return; c.agents = (arr || []).slice(); saveCState(); renderList(); },
      getTags: function (c) { c = c || current; return (c && c.tags) ? c.tags.slice() : []; },
      setTags: function (c, arr) { c = c || current; if (!c) return; c.tags = (arr || []).slice(); saveCState(); renderList(); },
      getLogs: function (c) { c = c || current; return (c && c.logs) ? c.logs.slice() : []; },
      isIntervened: function (c) { c = c || current; return !!(c && c.intervened); },
      rosterAgents: chatAgents,
      refresh: renderList,
      getLeadStatus: function (c) { c = c || current; return c ? c.leadStatus : null; },
      setLeadStatus: function (c, s, log) { setLeadStatus(c, s, log); },
      addToLeads: function (c) { addToLeads(c); },
      syncToCustomer: function (c) { syncToCustomer(c); },
      statusLogs: function (c) { c = c || current; return (c && c.statusLogs) ? c.statusLogs.slice() : []; },
      exportChat: function (c) { openExport(c); },
      /* Deliver a template into a specific person's chat, live. Resolves the
         contact by id, else by name/phone (creating the conversation if needed),
         opens it, and sends the template bubble so it reflects immediately. */
      sendTemplateTo: function (target, t) {
        if (!t) return null;
        target = target || {};
        var c = (target.id && CONTACTS.find(function (x) { return x.id === target.id; })) || null;
        if (c) openConversation(c);
        else c = window.__chat.openWith(target.name, target.phone);
        sendTemplate(t);
        return c;
      },
      /* Deliver a quick-reply (plain text) into a specific person's chat, live. */
      sendQuickReplyTo: function (target, text) {
        if (!text) return null;
        target = target || {};
        var c = (target.id && CONTACTS.find(function (x) { return x.id === target.id; })) || null;
        if (c) openConversation(c);
        else c = window.__chat.openWith(target.name, target.phone);
        var qm = { dir: "out", type: "text", text: text, time: nowTime() };
        if (current) { current.thread = current.thread || []; current.thread.push(qm); }
        addMessage(qm);
        if (current) { current.preview = text; current.time = qm.time; renderList(); }
        return c;
      },
      /* Post a reminder note into a person's chat so it reflects live. The
         reminder is internal (centered system note) and records who it's for —
         the agent (user) and/or the customer. */
      postReminderTo: function (target, info) {
        info = info || {}; target = target || {};
        var c = (target.id && CONTACTS.find(function (x) { return x.id === target.id; })) || null;
        if (c) openConversation(c);
        else c = window.__chat.openWith(target.name, target.phone);
        var rm = { type: "reminder", text: info.desc || "", whenLabel: info.whenLabel || "",
          agent: info.agent || "", customer: info.customer || (c && c.name) || "", time: nowTime() };
        if (current) { current.thread = current.thread || []; current.thread.push(rm); }
        addMessage(rm);
        if (current) { current.preview = "\u23F0 Reminder \u00b7 " + (info.desc || ""); current.time = rm.time; renderList(); }
        return c;
      }
    };
  }

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", init);
  else init();
})();
