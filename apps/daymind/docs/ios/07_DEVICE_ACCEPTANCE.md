# Phase 7 — Real iPhone acceptance: PENDING

User requested latest version; no exact iPhone model/iOS build, Mac access or signing team has been verified. CI is a build/test Mac, not a connected physical iPhone. No signed IPA/App Store/TestFlight release exists. Automatic periodic project checks remain OFF as requested.

Prepare a Mac with compatible latest Xcode and the same pinned Flutter, connect iPhone, enable Developer Mode/Trust. Clone feature/ios-support, run flutter doctor -v and flutter pub get in apps/daymind, open ios/Runner.xcworkspace. In Xcode Accounts sign in locally, select Personal Team / Automatically manage signing, use a unique Bundle ID if required, select connected iPhone then run flutter run -d DEVICE. Never send Apple ID/password/certificates/profiles in chat or commit them. Free Apple Account personal signing often expires after about7 days; re-sign locally. Paid program is not required for the initial personal-device test. Production Firebase stays disabled unless an actual reviewed client project is configured separately.

| Real-device gate | Status / evidence |
| --- | --- |
| Latest actual model, iOS build, compatible Mac/Xcode; signed install | PENDING |
| Offline CRUD/reopen/recurrence/SQLite integrity | PENDING |
| Permissions allow/deny/re-enable from Settings; persisted pending60 | PENDING |
| Foreground in-app cue, background, terminated, locked screen | PENDING; pending ack is not banner evidence |
| Focus/DND, quiet hours, Asia/Saigon alias, DST and OS restart | PENDING |
| 70+ reminders nearest60, open/refill, edit/complete/delete cancellation, one Snooze | PENDING |
| Files picker copies owned PNG/WebP/GIF/sprite; rotation/keyboard/200%/VoiceOver | PENDING |
| RAM/CPU/heat with animation, large backup and optional sync | PENDING |
| Upgrade same Bundle ID/team/signature, preserve SQLite/assets, interrupted restore | PENDING; export verified backup before testing |
| Authorized real cross-device Firebase after project/config/rules verification | PENDING project and devices |

Record PASS/FAIL with OS/build version, duration, log/PII-free screenshot and steps; never replace missing evidence with a checked box. A source/Simulator download does not satisfy this gate.
