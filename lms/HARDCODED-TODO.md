# Hardcoded-data audit — pending changes

Status of "remove hardcoded / make config-driven" work.

## ✅ DONE
- **Per-module variable mapping ("Map to field")** → `openTemplates()` now takes `opts.fields`
  (array OR a live function); `resolveFieldOptions()` uses it, `fieldOptions()` is the fallback.
  Callers wired: Leads send-template + Business/New-Lead alerts → `AskEvaLeadFields.mapFields()`
  (S.No + display-on fields incl. custom + Created/Updated At); Appointment alerts →
  `apptMapFields()` (ID + `AX.bookingFields()` + Payment/Status); Ticket templates →
  `ticketMapFields()` (ticket cols + `TK.ticketForm("ticketing")`). All stay live — add/remove a
  field in settings and the map list updates. (shared-library v6, leads-module v34,
  lead-settings v10, appointments-settings v10, ticketing-detail v12)
- **Lead statuses & sources** → shared `AskEvaLeadDropdowns` store; flows into Leads list, filters, add/edit form, kanban.
- **Lead custom fields** → Add/Edit Lead form renders them dynamically from Lead Fields config (type, Display, Mandatory, add, delete).
- **Leads Performance Dashboard filters** (`dash-perf.js`) → `SOURCES`, `STATUSES`, status donut (`ST`) and `STATUS_LABEL_TO_KEY` now derive from `AskEvaLeadDropdowns` + re-render on change. (committed, dash-perf.js v13)

## ⏳ PENDING (decided to do later)

### Critical / has a settings screen
1. **Ticket category fallback** (`ticketing.js` `CAT_ORDER`) — live picker already uses configured Departments; `CAT_ORDER` is only the no-departments fallback. Minor.

### Hardcoded with NO settings screen (making them configurable = new UI)
2. **Ticketing** (`ticketing.js`): `CHANNELS` (WhatsApp/Email/Phone/Web), `PRIO` (high/med/low), `STATUS` (open/pending/resolved). No editor exists. Note: Ticketing Settings → SLA has its own priority set (Critical/High/Medium/Low) which does NOT match ticket `PRIO` — possible alignment.
3. **Appointments booking form** (`appointments-detail.js`): duration chips `[15,30,45,60,90]`, modes `["Online","In-person","Phone"]`, payment types Prepaid/Postpaid. (Departments + booking *fields* already configurable.)
4. **Leads** (`leads-module.js`): follow-up types `["Call","Meeting","WhatsApp","Email"]`, note types `["Text","Audio","Image","Video","Document"]`, company→industry mapping.
5. **Subscription plans**: `PLANS` array in `home-dashboard.js` AND `CATALOG` in `subscription.js` are two separate definitions — duplication / two sources of truth. Candidate to unify.

### Not yet audited (offered)
- Account/business info (WABA number, business name, agent roster seeds), chat quick-replies / canned data.

---

## 🔜 NEXT MAIN TASK — per-module variable mapping ("Map to field")

**Problem:** `shared-library.js` → `openTemplates()` → `renderVarFill()` builds the
"✏️ Enter value / Map to field" dropdown from ONE hardcoded generic list:
`fieldOptions()` = `["Name","Mobile","Email","Company","City","Country","Date"]` (+ user attrs).
Every module (Leads / Appointments / Ticketing) gets the SAME list — not module-specific.

**Wanted:** the Map-to-field options must reflect the **module the template is sent from**,
sourced from that module's configured columns/fields:
- **Leads** (e.g. Business Alert → pick contact → Fill variables): from Lead Fields Configuration
  (`AskEvaLeadFields` display-on fields) + Status/Source/Assigned + Created At/Updated At.
  Cols: S.No, Name, Mobile, Status, Source, Assigned, Email, Created At, Updated At, Address,
  City, Country, Website, Lead Value, Tags, Description, + custom (test/username/office).
- **Appointments**: ID, Name, Age, DOB, Appointment Date, Appointment Timing, User, Department,
  Payment, Status, Action — appointment columns / `AX.bookingFields`.
- **Ticketing**: Assigned To, Customer Name, Mobile Number, Status, Ticket ID, Due Date, Subject,
  Department, + custom (csc csc), Actions — ticket columns / `TK.ticketForm`.

**Plan:**
- `openTemplates()` accepts a `fields` array (or `scope` key) from the caller; use it instead of
  always calling `fieldOptions()`.
- Each caller passes its module fields from live config (Leads/Appointments/Ticketing).
- `fieldOptions()` remains the fallback only.
- Keep live: add/remove a field in settings → map list updates.
- Callers to update: leads-module send-template + business/new-lead alerts; appointment alerts
  (appointments-settings/detail); ticket alerts (ticketing-settings2). Also compose-message uses
  the group mapping (keep its own contact-CSV columns).
