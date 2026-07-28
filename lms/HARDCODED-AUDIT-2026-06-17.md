# AskEva — Hardcoded-Data Audit (deep pass)

> **UPDATE — fixes applied (in order):**
> - ✅ **#1 Ticket quick replies** now read from `AskEvaQuickReplies.list()` (Settings → Quick Reply). No more hardcoded 4.
> - ✅ **#2 Ticket template fallback** now sources `AskEvaTemplates.list()`; hardcoded `TPL_LIST` kept only as last-resort.
> - ✅ **#3 SLA default minutes** centralized → `TK.slaDefaults()` (one source, persisted, default 3/1) used by ticket creation, detail timer, breach/escalation. No more literal 3/1 scattered.
> - ⏸️ **#4 Subscription plans** — investigated: NOT a true duplicate. `home-dashboard.js` PLANS = WhatsApp feature add-ons (MMLite/Coexistence); `subscription.js` CATALOG = billing tiers (Ecommerce/Enterprise). Different data, different screens — **left as-is** to avoid breakage.
> - ⏳ **#5+ (🟠 vocab + option lists, 🟡 sample data)** — these need new settings UIs or removal of demo data; flagged below. Not bulk-changed to honor "don't break what works." Pick which to build next.

Read-only audit below (original).

Legend: 🔴 should be config-driven now (a settings screen exists) · 🟠 hardcoded, no settings UI yet (making it dynamic = new UI) · 🟡 demo seed/sample data (normal for a prototype, will be replaced by real backend) · ⚪ cosmetic/internal constant (safe to leave)

---

## 1. TICKETING

### 🔴 Duplicated lists that already have a real source of truth
| What | Where | Problem | Fix |
|---|---|---|---|
| **Quick replies** in ticket reply | `ticketing-detail.js` ~486 `REPLIES = [4 strings]` | Hardcoded, ignores the Quick Replies you configure in Settings. Chat + Leads already use `AskEvaQuickReplies.list()`. | Pull from `AskEvaQuickReplies.list()`. |
| **Templates** fallback sheet | `ticketing-detail.js` ~293 `TPL_LIST = [5 templates]` | A second hardcoded template list. The primary path already uses `AskEvaTemplates.open()`; this is the fallback when that's missing — but it can show stale/wrong templates. | Drop the fallback or source it from `AskEvaTemplates.list()`. |

### 🟠 Core ticket vocab — no settings screen
| What | Where | Note |
|---|---|---|
| **Channels** | `ticketing.js:61` `["WhatsApp","Email","Phone","Web"]` | Not editable anywhere. |
| **Priorities** | `ticketing.js:62` `{high,med,low}` | Ticket priority. **Mismatch:** the dashboard/table use `WPRIO` = Critical/High/Medium/Low (`ticketing-tickets.js:64`) while the core uses high/med/low — two different priority sets in one module. Worth aligning. |
| **Statuses (core)** | `ticketing.js:63` `{open,pending,resolved}` | Separate from the 6-state `WST` (assigned/inprogress/awaiting/pending/completed/reopened) in `ticketing-tickets.js:58`. Two status vocabularies. |
| **Category fallback** | `ticketing.js:60` `CAT_ORDER` | Only used when no Departments are configured (live picker already uses configured depts). Minor. |

### 🔴 SLA "minute" defaults (the minute settings you mentioned)
| What | Where | Problem |
|---|---|---|
| **Default SLA times** | `ticketing-tickets.js` ~757 + ~529 `slaRes: 3, slaFirst: 1` | Every new/imported ticket is hardcoded to **3 min resolution / 1 min first-response**. |
| **SLA fallback** | `ticketing-detail.js` (`t.slaRes || 3`, `t.slaFirst || 1`) and `ticketing-tickets.js` escalation | Same 3/1 fallback repeated. |
| Note | — | A real SLA **policy** editor exists (`ticketing-settings.js` `slas`, matched by dept+priority via `TK.slaForTicket`). The timer uses it **when a policy matches**, else falls back to 3/1. Recommendation: make the 3/1 fallback a single configurable "default SLA" rather than a literal sprinkled in 3 places. |

### 🟡 Demo seed / sample data
- `ticketing.js:65` `CUSTOMERS` (Aarav Mehta, Priya Nair, …), `ticketing.js:102` `SEED` tickets.
- `ticketing-settings.js:198` seed `slas` (Priority Support / Standard Resolution / Billing Escalation) with literal dates `06/02/2026`…
- `ticketing-settings.js:311` seed Departments (Support L1/L2, Development Team, …) with literal "Oct 22, 2025" dates.
- `ticketing-detail.js:315` Activity log: hardcoded `creator = "testerr@gmail.com"`, `viewer = "eshan@tunepath.com"` and a fabricated "Ticket Viewed / Created" timeline.
- `ticketing-detail.js` default assignee literal `"eshan"` when unassigned (also in `ticketing.js` openForm).

---

## 2. APPOINTMENTS

### 🟠 Booking-form option lists — no settings screen
| What | Where | Note |
|---|---|---|
| **Default duration** | `appointments-detail.js:354` `dur: 30`; slot fallback `30` at ~427 | New appointment defaults to 30 min; slot step falls back to 30. |
| **Mode chips** | `appointments-detail.js:401` `["Virtual","Manual"]` | Hardcoded (note: detail view at :349/:352 defaults `mode:"Online"` — label mismatch "Online" vs "Virtual"). |
| **Payment types** | `appointments-detail.js:403` Prepaid / Postpaid | Hardcoded pair. |
| **Static booking fields** | `appointments-detail.js:622` Name/Age/Mobile/DOB/Department | The 5 system fields are hardcoded (custom fields ARE configurable via the Add-Field wizard). Expected, but listed for completeness. |
| Alert/reminder hours | `appointments-settings.js:90` `["1 hour","2 hours",…,"24 hours"]` | Reminder-timing options hardcoded. |

### 🟡 Demo seed
- `appointments.js` `SEED` appointments, `AX.METHODS`, `orderId: "ORD-"+(10500+len)` literal numbering.

---

## 3. LEADS

### 🟠 Option lists — no settings screen
| What | Where | Note |
|---|---|---|
| **Follow-up types** | `leads-module.js:1327` `["Call","Meeting","WhatsApp","Email"]` | Hardcoded. |
| **Industries** | `leads-module.js:373` `INDUSTRIES = [7 strings]` + `COMPANY_META` map (company→industry) | Hardcoded mapping. |
| Note types (audit prior) | `leads-module.js` | `["Text","Audio","Image","Video","Document"]` per earlier audit. |

### 🟡 Demo seed / sample data
- `leads-module.js:135` `LEADS` seed (Łôūīš Můťhūśâmÿ, Jashim, Nagaraj…) with literal dates + `assigned:"testerr@gmail.com"`, `"eshan@tunepath.com"`.
- `leads-module.js:1160` **Call logs** — fabricated ("2 min 14 sec", "Yesterday", "3 days ago", "Last week"). Pure sample.
- `leads-module.js:1288` Follow-up sample rows ("Quarterly review call · 12 Jun 2026", "Discovery call · 10 Jun 2026").
- `leads-module.js:1151` Activity sample rows.

---

## 4. CROSS-CUTTING

| What | Where | Severity | Note |
|---|---|---|---|
| **Subscription plans** | `home-dashboard.js` `PLANS` **and** `subscription.js` `CATALOG` | 🔴 | Two separate definitions of the same plans — duplication / two sources of truth. Unify. |
| **Business identity** | profile/account: business name "AskEva", agent "Eshan", `eshan@tunepath.com`, WABA number | 🟡 | Seeded; will come from account/WABA on integration. |
| **Agent roster seeds** | `settings-agents.js`, `ticketing.js` AGENTS | 🟡 | Demo agents; `settings-agents` is the live editor. |
| **Default assignee `"eshan"`** | ticketing create/reply, appointments create | 🟠 | Literal fallback identity sprinkled across modules — should derive from the current logged-in user. |
| **`NOW` frozen demo clock** | ticketing/appointments | ⚪ | Intentional demo "today". SLA already switched to real wall-clock via `slaStartMs`. |

---

## Recommended order (once you confirm)
1. **🔴 Quick replies + templates in ticket detail** → use `AskEvaQuickReplies` / `AskEvaTemplates` (small, no new UI, removes wrong data).
2. **🔴 SLA default minutes** → single configurable default instead of literal 3/1 in 3 spots.
3. **🔴 Unify subscription plans** → one source.
4. **🟠 Ticket priority/status vocab alignment** (high/med/low vs Critical…; core status vs WST).
5. **🟠 Appointments + Leads option lists** → settings-backed (needs small new UI each).
6. **🟡 Seed/sample data** (call logs, activity logs, lead/ticket/appt seeds) → leave until backend, or blank out the obviously-fake sample lists (Leads call logs, ticket activity emails) if you want them gone now.

> Tell me which numbers to do and I'll implement only those.
