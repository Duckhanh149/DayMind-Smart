# DAYMIND SMART — MASTER SPECIFICATION FOR CODEX

**Version:** 1.0 — 2026-11-08
**Status:** Architecture and implementation instructions; NO application code in this document.
**Language:** Vietnamese requirements, English identifiers.
**Target:** Android and Windows desktop; personal productivity app; Flutter shared UI/core.
**Core principle:** *Nhắc đúng lúc, không làm phiền* — conventional, calm defaults; extensive customization optional.

> **Instructions for Codex:** Read this entire file before changing the repository. Treat `MUST` as acceptance requirements; `SHOULD` as recommended; `FUTURE` as out-of-scope. Never silently substitute a different architecture. Before coding, inspect repository, report existing structure, SDK/tool versions, dependencies, and platform constraints. Propose a phase plan and implement one phase at a time with tests. Do not claim a feature works until it has been run and tested on its intended platform. Ask for decisions marked **OPEN** rather than inventing behavior.

## 1. Product goals and scope

DayMind SMART manages personal tasks, deadlines, scheduled work, recurring routines, calendar, reminders, daily digest, productivity analytics, optional cross-device sync, and an optional 2D Companion. Main app is useful without internet, account, or Companion. UI style C: professional, information-rich dashboard with progressive disclosure and a simple default flow. Android must remain touch-friendly; Windows offers denser multi-pane views.

**Non-goals for initial release:** chatbot AI, commercial character marketplace, automatically downloaded copyrighted characters, continuous monitoring of user activity, guaranteed exact-to-the-second notifications, unrequested aggressive alarm mode, full-screen interruptions, location tracking, arbitrary executable plugins, a custom Java/Spring backend.

### Modules
1. Task Management — CRUD, priorities, categories, status, soft delete, search/filter, Inbox.
2. Smart Reminder — relative/absolute reminders, snooze, quiet hours, dedup, rate control.
3. Calendar/Schedule — day/week/month, scheduled start/end vs deadline.
4. Recurrence — daily/weekly/monthly, weekday selection, occurrence-specific completion.
5. Daily Assistant — optional daily digest and rule-based priority suggestion.
6. Analytics — completion, on-time rate, overdue trends; locally computed.
7. Account & Sync — optional Firebase Auth/Firestore, offline queue, conflict handling.
8. Companion — import 2D character assets, personalities, dialogue templates, expression mapping, unobtrusive rendering.

## 2. Competitive review and decisions

| Reference | Verified pattern | DayMind decision |
|---|---|---|
| Todoist | Automatic/custom/recurring reminders; snooze; user-configurable channels | Support user-set reminders and default presets; do not require multiple reminders by default. |
| TickTick | Multiple reminders, reminder popup actions (Dismiss/Start Focus/Done/Snooze) | Provide useful actions but avoid aggressive constant reminders. |
| Microsoft To Do | Separate due date, reminder and repeat; planned list; natural-language entry on supported platforms | Keep due date separate from reminder; quick-create first. Natural language optional later, with explicit confirmation. |

**Sources:**
- https://www.todoist.com/help/todoist/features/introduction-to-reminders-9PezfU
- https://help.ticktick.com/articles/7055782395743567872
- https://support.microsoft.com/en-us/todo/add-due-dates-and-reminders-in-microsoft-to-do
- https://support.microsoft.com/en-us/todo/smart-due-date-reminder-recognition-in-microsoft-to-do

### Design gaps to fix BEFORE production
- Distinguish `scheduledStartAt`, `scheduledEndAt`, `dueAt`, and `reminder.triggerAt`; no implied due date when absent.
- Define recurrence semantics: next occurrence, per-occurrence completion, edits to single vs future vs whole series, DST, 29–31 monthly dates, skipped dates.
- Avoid notification floods after reboot, sync, offline periods, timezone changes, quiet hours.
- Design Windows notification behavior when app is not running; platform plugin alone is not proof of reliability.
- Define Android permission denial and battery optimization degradation without nagging.
- Define two-device dedup limits: offline simultaneous devices cannot be guaranteed exactly-once.
- Define conflicts, soft deletion/tombstones, migrations, backups, export, user data privacy.
- Define safe character package import, memory limits, asset licensing and fallback rendering.
- Avoid misleading analytics: denominator, skipped/cancelled/recurring occurrences must be explicit.
- Add accessibility, responsive layouts, keyboard support, dark mode, empty/error states, localization.

## 3. Non-intrusive notification contract (HIGHEST PRIORITY)

**Default preset NORMAL:**
- One scheduled reminder per task with a deadline, based on priority: HIGH 30 minutes before, MEDIUM 15 minutes before, LOW at deadline. If that relative time is already past when created, DO NOT immediately fire a backlog; offer user choice or schedule at deadline if future.
- If no `dueAt`, do not create a deadline-based reminder. User may explicitly add an absolute reminder.
- Daily digest optional, enabled by user or clearly disclosed during onboarding, default suggested 07:00 local; only one per day. User can disable.
- No automatic repeated overdue pings. Overdue items stay visible in dashboard/digest.
- Completion acknowledgment stays in-app, not an OS notification.
- Companion has no independent notification scheduler and no automatic voice playback.
- Quiet hours 22:00–07:00 local; non-urgent alerts suppressed/deferred to digest or first permitted window; avoid bunching. No default DND bypass.
- Snooze is **explicit user action** and schedules one replacement reminder. Dismiss is not completion.
- Group similar near-time reminders when semantically safe; avoid losing an urgent/high-priority item. Configurable grouping window; suggest 10 minutes, but confirm via UX testing.
- Do not automatically create 3 reminders for high priority; prior brainstorming suggested more, but THIS contract supersedes it.
- Offer MINIMAL, NORMAL (default), CUSTOM. No aggressive preset unless user explicitly opts in in future.
- Respect notification permission, OS focus modes and platform policies. Do not repeatedly prompt permission after denial.

**Deduplication/idempotency:** event key = taskId + occurrenceId (or one-off sentinel) + reminderRuleId + scheduledTriggerInstant + revision. Persist event lifecycle `PLANNED -> SCHEDULED -> DELIVERED/UNKNOWN -> DISMISSED/SNOOZED/CANCELLED`; delivery confirmation can be unavailable on platforms, so avoid false 'delivered' claims. Ensure edits/completions cancel or invalidate obsolete events. Maintain delivery ledger and avoid catch-up bursts.

**Multi-device:** user may select PRIMARY device for OS notifications; others show in-app activity by default. If primary offline, do not claim automatic failover is guaranteed. Local scheduling and cloud sync need distinct ownership rules; document unavoidable offline duplicate edge case.

**Quiet-hour boundary:** if reminder due 23:00 and quiet hours end 07:00, do not push stale 23:00 alert at 07:00 if deadline passed; prefer daily digest/overdue list. If critical exact-time alerts are later added, require explicit per-reminder consent.

## 4. Technical architecture

### Stack (proposed, validate before pinning)
- Flutter + Dart: Android and Windows app.
- Riverpod: state management and dependency injection.
- GoRouter or equivalent declarative navigation; one chosen implementation.
- Local-first SQLite via Drift (recommended) or another documented typed persistence solution; migrations and transactions required.
- Firebase Authentication + Cloud Firestore optional for account/sync. User can use local-only mode. Do not upload local assets or private task text without explicit sync choice.
- Platform notification adapter interface; Android and Windows implementations tested separately. Consider `flutter_local_notifications` current supported version, but verify SDK/Gradle/Windows MSIX requirements and plugin limitations in the actual build.
- Timezone-aware scheduling, UTC instants plus IANA timezone identifiers for recurring local wall-clock rules.
- Separate character asset store under application data; metadata in local DB. Live2D optional adapter after proof-of-concept.

### Layers and dependency direction
`Presentation (Flutter widgets + state)` -> `Application (use cases, orchestration)` -> `Domain (entities, rules, contracts)` <- `Infrastructure (SQLite, Firebase, notifications, asset storage, platform APIs)`.

**Domain MUST NOT import Flutter widgets, Firebase, or platform-specific notification libraries.** Define contracts for TaskRepository, ReminderRepository, SyncGateway, NotificationScheduler, CompanionRenderer, AssetImporter, Clock, TimezoneService, PermissionGateway. Mock adapters in unit tests.

### Proposed folder organization
```
lib/
  app/                 # bootstrap, router, theme, localization, DI
  core/                # errors, IDs, clock, timezone, result, utils
  features/
    tasks/{domain,application,data,presentation}/
    reminders/{domain,application,data,presentation}/
    calendar/{domain,application,presentation}/
    recurrence/{domain,application,data}/
    daily_assistant/{domain,application,presentation}/
    analytics/{domain,application,presentation}/
    account_sync/{domain,application,data,presentation}/
    companion/{domain,application,data,presentation}/
  platform/
    android_notifications/
    windows_notifications/
    windows_companion_window/
  shared/widgets/
test/ integration_test/ docs/
```
Folders are logical guidance, not a mandate to create empty boilerplate files.

### Core event flows
- `CreateTask` -> validate -> local transaction task+reminder rules -> compute due events -> schedule OS notifications -> enqueue sync -> update UI.
- `EditTask` -> increment revision -> invalidate previous reminder event keys -> recompute -> reschedule -> enqueue sync.
- `CompleteTask` -> status `COMPLETED`, `completedAt`, occurrence-specific when recurring -> cancel future notifications -> update analytics -> sync.
- `SnoozeReminder` -> user-chosen new instant -> invalidate prior pending trigger -> schedule one replacement -> log action.
- `SyncIncomingChange` -> reconcile version/conflict -> recompute only future relevant schedules -> never replay expired notifications.
- `ReminderFired` -> check current task/occurrence/revision/quiet hours/dedup -> OS notification OR in-app Companion dialogue based on app state, not two independent alerts.

## 5. Data model and invariants

### Local entities
- `Task`: id UUID, ownerId nullable, title required, description, categoryId nullable, priority LOW/MEDIUM/HIGH, status TODO/IN_PROGRESS/COMPLETED/CANCELLED, scheduledStartAt nullable, scheduledEndAt nullable, dueAt nullable, timezoneId, createdAt, updatedAt, completedAt nullable, deletedAt nullable, revision integer, syncState.
- `ReminderRule`: id, taskId, occurrenceScope, kind RELATIVE_TO_DUE/RELATIVE_TO_START/ABSOLUTE, offsetMinutes nullable, absoluteAt nullable, enabled, revision.
- `ReminderEvent`: id/eventKey unique, ruleId, taskId, occurrenceId nullable, scheduledAt, state, platformNotificationId nullable, updatedAt.
- `RecurrenceRule`: id, taskId, frequency DAILY/WEEKLY/MONTHLY, interval, daysOfWeek nullable, localTime, timezoneId, endDate/count nullable, monthDayPolicy explicit.
- `TaskOccurrence`: id, taskId, occurrenceLocalDate, scheduledAt, dueAt, status, completedAt, overriddenFields, unique taskId+occurrence key.
- `NotificationLog`: id, eventKey, deviceId, outcome (scheduled/display_attempt/acknowledged/unknown/dismissed/snoozed), at; retention policy.
- `UserSettings`: notificationPreset, digestEnabled/time, quietHours, grouping, primaryDeviceId, accessibility, companion display prefs.
- `SyncOutbox`: mutationId, entityType, entityId, baseRevision, payload, createdAt, retryState; `SyncConflict` table for unresolved edits.
- `Character`, `CharacterAsset`, `Expression`, `Motion`, `Personality`, `DialogueTemplate`, `CompanionProfile`, `CompanionSettings`.

**Invariants:** `scheduledStartAt <= scheduledEndAt` if both exist; `scheduledEndAt <= dueAt` only if product decides to enforce (OPEN: normally warn, not reject); title nonempty; no duplicate eventKey; overdue is computed (`dueAt < now` and not terminal), never a persisted Task status; completed/cancelled/soft-deleted tasks do not generate future alerts; one occurrence completion does not complete recurrence series.

### Sync conflict policy
Use local transactions + outbox; server timestamps alone are NOT sufficient for safe concurrent edits. Prefer explicit per-document revision/compare-and-set where feasible, with a conflict record for concurrent divergent edits. Preserve tombstones to prevent resurrection after offline deletion. Never silently discard text. Sync character *metadata* only in v1; asset files remain local unless user explicitly exports/imports. Security rules: authenticated user can only access own documents; test unauthorized reads/writes.

## 6. UX specification

### Android navigation
Bottom navigation: `Hôm nay`, `Lịch`, `Sắp tới`, `Thống kê`; top bell for Notification Center; Settings and Companion accessible from profile/menu. Add Task FAB in safe zone. Keyboard never blocked by Companion.

### Windows navigation
Left sidebar (Dashboard, Tasks, Calendar, Upcoming, Analytics, Companion, Settings); center list/table/calendar; right detail pane. Collapsible panes and responsive layout; keyboard shortcuts, focus order, hover tooltips, high-contrast support.

### Screens and must-have states
1. Dashboard: today counts, progress, high priority, overdue, quick add; loading/empty/offline/sync status.
2. Task list: filters status/priority/category/date, sort, search, bulk actions optional later.
3. Add/Edit Task: Quick (title, optional due) / Advanced (description, start/end, due, category, priority, recurrence, reminders, notes). Preview effective notification times. Warn on invalid/past times; no mandatory due date.
4. Task details: complete/reopen, snooze, edit, delete, history.
5. Calendar: day/week/month, distinguish start/end vs due, handle overlaps and timezone.
6. Reminder settings: MINIMAL/NORMAL/CUSTOM, quiet hours, digest, device choice, permission state, test notification button (explicit action).
7. Notification Center: unread/all/overdue, mark read, dismiss, snooze, complete, open task. `Dismiss != Complete`.
8. Analytics: defined metrics and ranges, no fake precision.
9. Companion Library: import/preview/delete character; profile + personality editor, expression mapping, low-resource mode.
10. Account/Sync: local-only, sign-in, sync status, conflicts, export/backup, logout behavior.

### Companion UI constraints
- Default Android size approx 80dp (test 72–96dp); small mode 40–56dp; adjustable manual 40–144dp; respect accessibility text scaling.
- Auto mode DEFAULT: small in safe region, shrink/vanish on edit forms, keyboard, modal, dense calendar. Manual mode lets user choose position/size/visibility; safety zones override overlap temporarily.
- Only image's visible interactive bounds intercept taps; transparent pixels should not block primary controls.
- Windows: optional floating window with drag/resize, always-on-top opt-in, click-through mode and hide on fullscreen; never enable always-on-top automatically.
- Default muted, no unrequested sound; Companion never creates additional OS notification.
- Full companion view can display larger character; list/task screens prioritize productivity UI.

## 7. Companion asset and behavior architecture

**Import types:** Static PNG/WebP, animated GIF/WebP, sprite sheet+validated metadata, optional Live2D model package. Support imported *user-owned/licensed* files only. Do not bundle/distribute copyrighted anime characters without authorization.

**Import pipeline:** file picker -> temporary sandbox -> extension+magic byte validation -> bounded decompression/extraction (zip-slip and zip bomb defense) -> manifest validation -> path traversal/symlink rejection -> resource budget checks -> preview -> atomic install to app data -> metadata transaction. Never execute scripts or external code from character package.

**Package format:** DayMind-defined manifest for static/sprite assets; Live2D files retain model-specific structure. Do not assume a PNG becomes a Live2D model. Define format version, checksums, relative paths, expressions, motions, thumbnails, provenance/license note.

**Behavior Engine:** event types `APP_OPEN`, `REMINDER_DUE`, `TASK_COMPLETED`, `TASK_OVERDUE_VISIBLE`, `DAILY_DIGEST`, `QUIET_HOURS`; selects dialogue by personality + event + template variables + cooldown; selects expression/motion if available, otherwise neutral/static fallback. Character and Personality are independent; CompanionProfile pairs them. No independent scheduler.

**Low-resource mode:** pause hidden animations, limit frame rate/texture size, lazy load, unload inactive model, measure RAM/CPU on low-end hardware. Live2D remains a separately gated feature until Android AND Windows proof-of-concept, model filesystem import, rendering lifecycle and licensing are verified.

**Licensing and tech references:**
- https://docs.live2d.com/en/cubism-sdk-manual/platform/
- https://www.live2d.com/en/sdk/license/
- https://pub.dev/documentation/live2d_flutter/latest/

## 8. Platform notification risks — mandatory technical spikes

### Android
- Android 13+ notification runtime permission; explain and request at contextual moment, no repeated prompts.
- Exact alarms are restricted; use inexact scheduling where appropriate. Only request special alarm access for explicitly precise user-facing needs and check Play policy. Handle denial gracefully.
- Handle reboot, timezone changes, daylight-saving changes, app upgrade, notification channel settings, battery restrictions and OS delivery delay.
- Source: https://developer.android.com/develop/background-work/services/alarms
- Source: https://support.google.com/googleplay/android-developer/answer/16558241?hl=en

### Windows
- Verify `flutter_local_notifications` support with pinned SDK version and actual package. Its Windows implementation supports toast but NOT periodic repeat API. Package identity/MSIX affects cancel and active notification query; test behavior packaged and unpackaged.
- Verify whether scheduled notifications persist/activate when app is fully closed and after reboot; document observed limitations. If not reliable, evaluate Windows App SDK `AppNotificationManager` adapter or a justified native helper, with explicit consent for startup/background behavior.
- Do NOT assume Android action buttons, cancellation, background delivery and Windows behavior match.
- Sources: https://pub.dev/packages/flutter_local_notifications
- https://pub.dev/packages/flutter_local_notifications_windows
- https://learn.microsoft.com/en-us/windows/apps/develop/notifications/

## 9. Delivery plan — Codex phases and exit gates

### Phase 0 — Discovery and proof-of-concept
- Inspect repo/toolchains; produce dependency compatibility matrix (Flutter/Dart/Android SDK/Gradle/Windows/MSIX).
- Run minimal Android and Windows builds.
- Prove: local database transaction+migration, local notification scheduled after app closed on Android, Windows notification packaging/activation, basic Firebase Auth/Firestore emulator connectivity, file import sandbox, static character rendering.
- **Gate:** written POC report with observed platform behavior; no unverified claims.

### Phase 1 — Core local-first tasks
- Implement domain/entities, SQLite schema/migrations, CRUD, categories, priorities, statuses, Inbox, quick/advanced task form, dashboard and task list.
- **Gate:** tests for validation, persistence after restart, no due date, soft delete, basic UI navigation.

### Phase 2 — Reminder Engine + anti-spam
- Implement reminder rules/events, scheduler adapters, quiet hours, dedup, snooze, permission UX, Notification Center, cancellation on edit/complete, reboot recovery.
- **Gate:** automated clock-based unit tests; device smoke tests Android and Windows; no notification flood.

### Phase 3 — Calendar + recurrence
- Day/week/month views; per-occurrence state; timezone/DST and monthly edge cases.
- **Gate:** recurrence test matrix and editing one/this-and-future/all occurrences behavior confirmed.

### Phase 4 — Daily assistant + analytics
- Optional digest, rule-based prioritization, progress and overdue analytics, configurable cards.
- **Gate:** no automatic extra alerts, metrics reproducible with fixtures.

### Phase 5 — Account + sync
- Local-only migration to signed-in account, Firestore security rules, outbox, retry, conflict UI, primary notification device settings, delete/export.
- **Gate:** two-device offline/online reconciliation tests, no silent data loss, no burst of old reminders.

### Phase 6 — Companion static + personality
- Import PNG/WebP, library, personality/dialogue templates, expressions, event mapping, auto/manual placement, muted default.
- **Gate:** UI remains usable with Companion enabled, safe file import tests, memory measurements.

### Phase 7 — Animated and Windows desktop companion
- GIF/sprite rendering, resource budgets, optional floating desktop character.
- **Gate:** performance, fullscreen, keyboard, click-through, OS focus mode tests.

### Phase 8 — Live2D optional feature gate
- Confirm SDK license, Windows/Android renderer, user-imported model loading, memory use, fallback; release only if tests pass.
- **Gate:** explicit written approval of licensing and technical POC. Otherwise ship without Live2D and retain extension interface.

### Phase 9 — Release readiness
- Accessibility, localization Vietnamese, dark mode, permission guidance, backup/restore, migration rollback strategy, error reporting opt-in, privacy policy if distributed, signing/installers, regression tests.

## 10. Required tests / acceptance scenarios

**Notification:**
1. Normal priority task due 20:00 -> at most one default reminder at 19:45; no automatic repeated overdue alerts.
2. High due 20:00 -> one default at 19:30, NOT 3 reminders.
3. No deadline -> no deadline reminder.
4. Complete at 19:00 -> scheduled reminder cancelled/inactivated.
5. Edit deadline -> obsolete event never fires.
6. Snooze 10 min -> exactly one replacement reminder, unless subsequently cancelled.
7. Quiet hours -> no noisy alert; no catch-up burst at 07:00.
8. 20 overdue tasks imported from cloud -> no 20 immediate alerts.
9. Two devices with same account -> primary device policy followed when online; offline limitation documented.
10. Permission denied -> task CRUD still works, settings explain reduced reliability without nagging.

**Recurrence/time:**
11. Monthly task on 31st -> explicit policy for February and 30-day months.
12. DST forward/back and timezone travel -> no duplicate/vanished occurrence.
13. Completing one occurrence doesn't complete future occurrences.
14. Delete/restore series -> no resurrected stale alerts.

**Companion:**
15. 80dp Android Companion never overlaps FAB, bottom nav, keyboard, dialog, save button.
16. Manual placement preference survives restart; safe-region override works.
17. Companion off -> reminders still work; Companion on -> no extra OS notifications.
18. Invalid zip, zip-slip, oversized image, unsupported model -> import rejected safely.
19. Live2D fails -> static fallback and no crash.

**Data/security:**
20. Offline create/edit -> persisted across restart and synced once online.
21. Concurrent edits -> conflict detected, user can choose resolution; no silent overwrite.
22. User A cannot read User B Firestore documents.
23. Logout/account switch does not leak task or character metadata across users.
24. Analytics count recurring occurrences and cancellations consistently.

## 11. Definition of Done per phase

Every phase must deliver: (a) code and migration notes, (b) tests + actual command/output summary, (c) screenshots or manual UX test checklist for Android/Windows as applicable, (d) known limitations, (e) updated architecture decisions in `docs/adr/`, (f) no silent scope expansion. `flutter analyze` and relevant automated tests must pass. Windows packaging and real-device notification behavior must be verified, not inferred from compilation alone.

## 12. Open decisions — ask user before irreversible implementation

1. **Local-only first or Firebase sign-in from first run?** Recommendation: local-first, optional sign-in.
2. **Daily digest default on or opt-in?** Recommendation: explicit opt-in during onboarding; never surprise user.
3. **Windows installer distribution:** MSIX preferred if notification capabilities need package identity; verify actual behavior.
4. **Monthly recurrence on day 31:** skip months without day vs use last day; user setting or explicit product default needed.
5. **Sync conflict UX:** show both versions and allow selection/merge; choose merge granularity.
6. **Backup/restore:** local export format and encryption/password strategy.
7. **Companion asset sync:** default metadata only, asset export/import; cloud asset storage deferred.
8. **Live2D release scope and license:** POC before commitment.
9. **Task scheduling rule:** whether `scheduledEndAt > dueAt` is warning or error (recommend warning).
10. **Windows app closed:** acceptable reminder reliability target and whether user opts into background/startup helper.

## 13. First message to Codex (copy/paste)

> Read `DAYMIND_SMART_CODEX_MASTER_SPEC.md` in full. Do not start implementing everything. First inspect the current repository and report: (1) what already exists, (2) discrepancies with the spec, (3) platform/library risks, (4) exact phase-0 POC plan with commands and success criteria, (5) open questions that block work. Respect the non-intrusive notification contract as the highest-priority requirement. Once I approve the plan, implement Phase 0 only; show tests and actual results before moving to Phase 1. Never claim a Windows or Android notification behavior without platform verification.

---

## Appendix: Source notes / verification date

Checked 2026-11-08. Third-party APIs, package versions and platform policy may change. Codex MUST check versions and compatibility at implementation time rather than copying version numbers from this spec.

- Todoist reminders: https://www.todoist.com/help/todoist/features/introduction-to-reminders-9PezfU
- TickTick reminder actions: https://help.ticktick.com/articles/7055782395743567872
- Microsoft To Do due/remind/repeat: https://support.microsoft.com/en-us/todo/add-due-dates-and-reminders-in-microsoft-to-do
- Android alarms: https://developer.android.com/develop/background-work/services/alarms
- Android Play exact-alarm policy: https://support.google.com/googleplay/android-developer/answer/16558241?hl=en
- Flutter notifications plugin: https://pub.dev/packages/flutter_local_notifications
- Windows notifications: https://learn.microsoft.com/en-us/windows/apps/develop/notifications/
- Live2D platform support: https://docs.live2d.com/en/cubism-sdk-manual/platform/
- Live2D license: https://www.live2d.com/en/sdk/license/
