# AskEva Flutter App — UI/Navigation Fidelity Audit

**Date:** 2026-06-30
**Design source of truth:** `d:\asklms-main\lms\` (web/PWA prototype — `*.js` modules + `AskEva App - MASTER.html`)
**Audited target:** `d:\asklms-main\askeva_app\` (Flutter)
**Method:** 8 parallel per-module audits (dashboard, leads, chats, appointments, ticketing, profile, settings, shell). Read-only — no code changed.

---

## Verdict

The Flutter app reproduces the **visual design** of the `lms` source with high fidelity — colors, cards, headers, segmented controls, pills, layouts and section ordering nearly all match. The gap is almost entirely **behavioral**:

- **Toggles are decorative** — painted switches with no `onTap`/state (Team active, profile password meter, several settings).
- **Action buttons are no-ops or toasts** — `onPressed: () {}` or `nav.toast(...)` stand in for sheets, forms, and flows (New Lead, Edit Profile, Invite member, New Ticket, attachments, compose send).
- **Sub-tabs switch the highlight but not the body** — Lead Settings, Ticketing Settings, Appointments Settings, and the appointment/ticket detail tab strips all track tab state but render only one (or zero) of the panes.
- **Filters / search / pagination are visual only** — present but unwired across Leads, Chats, Contacts, Appointments, Ticketing, Payments.
- **Whole sub-systems are missing** — RBAC/roles editor, 2FA, QR generator, import wizards, business-card scanner, agent-intervene chat mode, most message types, notification center, push alerts.

Data wiring is partial: Login, Leads list, Contacts, Chat rooms/messages, Profile account/transactions, Appointments list, and Ticketing list/dashboard read **live** from the API; everything else is hardcoded sample data.

---

## Severity ranking by module

| Module | Visual fidelity | Behavioral fidelity | Biggest gap |
|---|---|---|---|
| **Settings** | Medium (wrong grouping) | ❌ Very low | Entire RBAC/roles, 2FA, QR, user-attributes CRUD missing; invented "WhatsApp Business" group not in design |
| **Chats/Conversation** | High | ❌ Very low | Agent-intervene mode, ~12 message types, functional compose, contacts CRUD all missing |
| **Ticketing** | High | ❌ Low | Ticket Details tab (the main one) absent; detail opens on empty Call Logs; all 8 settings sub-screens missing |
| **Appointments** | High | ❌ Low | 7-tab detail stub (only Feedback), no lifecycle actions, 3 of 4 settings tabs empty, form non-functional |
| **Leads** | High | ⚠️ Low-Medium | 3 of 4 settings tabs dead, no New/Edit form, filters static, no import/scan, Kanban read-only |
| **Profile** | High | ⚠️ Medium | Team CRUD inert, Account tab too thin, Pricing tab wrong content, Edit/Password dead |
| **Dashboard** | High | ⚠️ Medium | Payment flow doesn't complete, Add Fund math static, period/date-range menus inert |
| **Shell/Nav** | High | ⚠️ Medium | Notification center static, no logout confirm, no dark mode, auth flow shallow |

Routes themselves are **correct** — Flutter's sidebar matches the MASTER merged route set (Dashboard, Compose, Contacts, Chats, Leads, Appointments, Ticketing, Profile, Settings). No phantom routes. (My earlier note that Contacts was an unexpected top-level item was wrong — the MASTER shell does ship Contacts as a top-level drawer item.)

---

## Cross-cutting patterns to fix once, everywhere

1. **Wire sub-tab bodies.** Lead Settings, Ticketing Settings, Appointments Settings, and both detail screens track tab state but only render one pane. This is a recurring bug, not per-screen.
2. **Make toggles real.** Replace painted switches with stateful, persisted toggles (Team active, settings prefs, alert cards).
3. **Replace toasts/no-ops with the actual sheet/form** for: create/edit entities, invite member, attachments, compose send, reminders, notes, send-template.
4. **Wire filters/search/pagination** that already render to actually filter the loaded lists.
5. **Drive lists from the repositories that already exist** — several screens fetch live data but then render hardcoded rows anyway (Appointments dashboard/payments/detail, Ticketing detail via `fetchTicket` which is never called).

---

## Recommended build order

**Phase 1 — High-impact, defining behaviors**
1. Chat **agent-intervene mode** + missing **message-type bubbles** (image/doc/voice/location/poll/payment/etc.) — the core product behavior, currently mostly `[type]` text.
2. **Ticket Details** detail tab (SLA countdown, properties, replies, status/assign) as the default tab.
3. **Appointment 7-tab detail** + lifecycle actions (confirm/complete/reschedule/cancel).
4. **Settings RBAC** (Agents list + Roles/permissions editor) + **2FA** — the largest missing sub-systems.

**Phase 2 — Cross-cutting wiring**
5. Fix all **sub-tab body switching** (Lead/Ticketing/Appointments settings, detail strips).
6. Wire **filters, search, pagination** across Leads/Chats/Contacts/Appointments/Ticketing/Payments.
7. Make **toggles + Team CRUD + Edit Profile + Password** functional.

**Phase 3 — Forms, wizards, flows**
8. New/Edit **Lead** and **Ticket** and **Appointment** forms.
9. **Compose** real send (country-code picker, template, group, CSV mapping, schedule).
10. **Import wizard**, **business-card scanner**, Sync/Export/Sample-CSV.
11. Dashboard **payment-complete flow** + Add Fund live math; **Upgrade plan** sheet.

**Phase 4 — Shell polish**
12. Real **notification center** (full screen, tabs, day grouping, live badge on all headers).
13. **Logout confirm**, **dark-mode/Appearance**, **push alerts**, deeper **auth** (sign-up, forgot, OTP verify modal, 2FA gate).

---

## Per-module detail

> Full feature-parity tables, navigation/interaction gaps, and layout differences for each module are recorded below. Each was produced by a dedicated audit against the specific `lms` source files for that module.

---

## 1. Dashboard
**lms:** `home-dashboard.js`, `dash-perf.js`, `chart-theme.js`, `#app-home` markup, `home-dashboard.css`, `subscription.js renderDash()`.
**Flutter:** `dashboard_screen.dart`, `dashboard_sheets.dart`, `trend_chart.dart`, `donut_chart.dart`.
**Purpose:** Home overview — WABA status, wallet balance + Add Fund, message-limit gauge, current plan, total-conversation stats, broadcast/API trend charts.

Section ordering and chart geometry are a faithful port. The gaps are all interaction:
- **Payment gateway Pay button** just dismisses — no processing/success animation, no wallet update, no transaction log.
- **Add Fund** charge math is static ₹0.00 (no 2.5% gateway + 18% GST recompute), no min-₹3000 validation, amount hardcoded 3088.50 to the gateway; Bank challan upload is decorative; UPI/bank-collection variant (QR + copy) missing.
- **3-dot period menu** (Today/7/28 days) and **date-range pill** are inert decorations (no rescale/redraw).
- **Upgrade plan sheet** + conditional "Upgrade Now" missing (always "Renew Now").
- Payment sheet: UPI app chips & net-banking bank tiles not selectable, no Name-on-Card / card formatting / Luhn.
- Minor: Message Limit "0%" vs lms "0.1%"; "Report" row label static.

## 2. Leads
**lms:** `leads-module.js`, `lead-settings.js`, `leads-interactions.js`, `merge-unify.js`.
**Flutter:** `leads_screen.dart`, `lead_detail_screen.dart`, `leads_sheets.dart`, `company_profile_screen.dart`.

- **Lead Settings:** `_tab` is tracked but body always renders Reminders — **Configuration (Lead Fields + Dropdown Fields), Webhook, Quick Reply tabs are dead/missing.**
- **No New/Edit Lead form** — FAB and Edit button only toast.
- **Filters static** — dropdowns non-functional, Apply/Clear just pop, count badge hardcoded 0, no active-filter chips.
- **Selection mode + Bulk Update + Bulk Delete + Undo** all missing (single delete only, no undo).
- **Import Leads wizard** and **business-card scanner** entirely absent; Sync/Export/Sample-CSV toolbar chips are no-ops.
- Lead-action sheet grid matches visually, but Reminders, Send Template, Notes, Activity Logs, Call Logs, and full-screen Call all only toast.
- **Kanban is read-only** (lms supports drag-to-change-status with converted-lock + customer creation on drop).
- **Lead Detail** drops Contact/Company/Location/Description/Custom-fields/Created-Updated sections; value/tags hardcoded `—`; timeline is one fake row.
- **Companies** card has no `onTap` (lms opens that company's customers list); orphan `CompanyProfileScreen` with fabricated data is reachable from nowhere.
- **Customer lifecycle** state cycling (Active/At-risk/Churned) missing; "Active" badge static.
- Status model is a fixed 5-value enum vs lms dynamic dropdown-driven custom statuses.

## 3. Chats / Conversation / Contacts / Compose
**lms:** `chat.js`, `compose-message.js`, `contacts.js`, `contacts2.js`, `audio-note.js`.
**Flutter:** `chats_screen.dart`, `conversation_screen.dart`, `compose_screen.dart`, `contacts_screen.dart`, `conversation_launch.dart`, `conversation_profile_sheet.dart`.

Largest gap surface in the app.
- **Agent-intervene mode** (AI-handling pill ↔ take-over banner, composer gating, AI auto-reply) — entirely missing; this is the defining real-time behavior.
- **~12 message types render as `[type]` text** — image, video, voice, audio, location, contact, document, poll, event, payment request, feedback, reminder. Only text/order/template bubbles exist (order/template buttons inert, template badge hardcoded "Marketing").
- **Attachment sheet** items are dead taps (only Catalogue partly wired); catalogue +/draft-order/Send-order inert.
- **Compose** non-functional: no country-code picker/validation, no template picker, no real group select, no CSV upload/mapping, Send Now/Schedule only toast.
- **Chat-list** drops preview ticks/media glyphs/typing/mute/intervened/lead-status tags; filter set reduced (no Unread/Intervened/Prospects/Tags/Agents pickers); search only toasts; no New Chat/Group/Broadcast.
- **Contacts** is read-only over Leads API — Add/Edit/Manage-Groups/Import/Export/Sample-CSV/select-bulk all toast; Opt-out (Unsubscribed/Blocked) always empty.
- Conversation header status hardcoded "online"; no overflow menu (Mute/Media/Mark-unread/Add-to-Leads/Block/Report/Export); no in-chat search; no day separators / E2E banner; no notes; no lead-status pipeline.
- Composer: no emoji picker, no voice recording, no camera.
- Profile sheet is well-built but mostly hardcoded.

## 4. Appointments
**lms:** `appointments.js`, `appointments-dashboard.js`, `-bookings.js`, `-detail.js`, `-detail2.js`, `-payments.js`, `-settings.js`.
**Flutter:** `appointments_screen.dart`, `appointment_sheets.dart`, `detail_screens.dart (AppointmentDetailScreen)`, `appointments_repository.dart`.

- **Detail is a stub:** 4 tabs vs 7, and only Feedback renders; no hero/status tags, no lifecycle actions (Confirm/Complete/Reschedule/Cancel/Delete/Call/Message/Request-payment).
- **New Appointment form** cosmetic only — no real pickers, no validation, no availability, save just pops.
- **Settings:** 3 of 4 tabs empty — Webhook, Booking Form (reorder + add-field wizard), Departments render nothing; only Alerts has content (and no config screen).
- **Bookings:** list view lacks status sub-tabs (Current/Rescheduled/Completed/Feedbacks/Upcoming), search, week strip; calendar is a fixed June-2026 grid with inert month chevrons and a schedule that doesn't react to day selection.
- **Agent filter pill** decorative — no scoping anywhere; FAB shown on Payments/Settings (should hide).
- **Dashboard** missing KPI row, trend chart, calendar/donut/monthly charts; tiles + agent performance hardcoded (repository ignored).
- **Payments** search/status-filter static; no summary tiles; no pagination.

## 5. Ticketing
**lms:** `ticketing.js`, `-dashboard.js`, `-detail.js`, `-tickets.js`, `-settings.js`, `-settings2.js`.
**Flutter:** `ticketing_screen.dart`, `detail_screens.dart (TicketDetailScreen)`, `ticketing_repository.dart`.

- **Ticket Details tab missing** — detail has 4 tabs vs 5, omits the main "Ticket Details" tab and opens on an empty Call Logs state. SLA countdown/breach, properties, replies thread + composer, status/assign/priority changes, feedback stars — all absent. (`fetchTicket` is defined but never called; detail uses constructor args only.)
- **No create/edit ticket form** ("New" → toast).
- **Tickets list** status tabs (only 3 of 6 — missing Starred/Spam/Feedbacks), search, and pagination are visual only; counts hardcoded; per-row action sheets missing; Export & bulk-select unwired.
- **Kanban** status-only with no drag-and-drop; **Table** 6 cols (vs 9) with no column reorder.
- **Settings hub cards not tappable** — all 8 sub-screens (Department, SLA Policies, Ticket Form, Business Hours, Quick Reply, Video Note, Notification, Webhook) missing.
- **Dashboard** missing "Total Tickets" tile, empty progress bars, no date-range, no trend-bar/donut/agent-bar interaction or agent filter.

## 6. Profile / Team / Subscription
**lms:** `profile-page.js`, `profile-account.js`, `subscription.js`, `team-people.js` (and `profile.js` = per-contact CRM drawer, separate surface, no Flutter counterpart).
**Flutter:** `profile_screen.dart`, `profile_sheets.dart`.

Header + 6-tab structure match. Gaps:
- **Team CRUD inert:** active toggle is static paint; no Add/Invite handler; no view/edit/delete per-member; no dept chips/search.
- **Account tab too thin** — flat 5-row card vs lms's WhatsApp profile card + Account Details (8 rows) + Company Details (9 rows).
- **Edit Profile** button is a no-op (no sheet, no logo upload/crop).
- **Password tab** is static "••••••••" rows + decorative strength meter; no real fields, eye toggles, validation, or save.
- **Pricing tab wrong content** — generic SaaS plan cards instead of lms per-country WhatsApp conversation rates + plan-features card.
- **Subscription** hero missing status pill / 4-metric grid / progress bar; only Renew (no Upgrade/Compare, no Billing History); Renew sheet inert (no live recompute, no plan mutation/transaction); invented "usage gauges" card not in design.
- **Transactions** flat list, no expandable detail (balance/GST/gateway/method/total/invoice download), no pagination.

## 7. Settings
**lms:** `settings-agents.js`, `-roles.js`, `-security.js`, `-userattrs.js`, `-qr.js`, `#app-settings` panes.
**Flutter:** `settings_screen.dart`, `about_screen.dart`.

Weakest module behaviorally.
- **Wrong hub structure** — Flutter invents "WhatsApp Business"/"Automation" groups (WABA, templates, quick replies, auto-reply, read-receipts) with no design source; lms groups are "Workspace" + "Security & Preferences".
- **Agents** → a single row that navigates to **Profile** (wrong); no agents list/toggles/create-edit form/row-actions/detail.
- **Roles / RBAC editor** entirely missing — the module-permissions accordion (~18 modules, 60+ permissions, 13 roles) has no Flutter equivalent. Largest single gap.
- **2FA/Securities** → toast (no TOTP wizard, QR, backup codes).
- **QR Code** generator + history — no entry point at all.
- **User Attributes** → toast with wrong count (6 vs 25); no CRUD table.
- **Notifications** (push + sounds), **Login Activity**, **Appearance/Dark-mode** sub-pages missing.
- **About** is the closest match (content nearly verbatim). Logout works.

## 8. App Shell & Navigation
**lms:** `app-shell.js`, `app-shell.merged.js`, `notifications.js`, `push-alerts.js`, `sync-layer.js`, shell markup.
**Flutter:** `main.dart`, `app_shell.dart`, `app_nav.dart`, `app_sidebar.dart`, `splash_screen.dart`, `login_screen.dart`.

Routes are **correct** (match MASTER merged set; no phantom routes; drawer/active-state/width faithfully ported). Gaps:
- **Notification center** is a static single-item card — "Mark all read" / "View all" have no onTap; no full screen (tabs All/Tickets/Leads/Appointments + status + date-range), no day grouping, no live feed.
- **No unread badge** on the bell; bell only wired on Dashboard (not other headers).
- **No logout confirmation modal** (lms requires Cancel/Confirm; Flutter logs out instantly).
- **No dark-mode/Appearance** sub-view (app is light-only).
- **No push alerts** (low-balance card / generic banner).
- **Auth shallow:** Sign-up and Forgot-password are dead labels; no OTP verify modal, no 2FA/backup-code gate.
- Minor: scrim uses default Material barrier (not the design's green-tinted scrim); no splash→login logo FLIP; no per-route scroll-position memory / chat-return context.
