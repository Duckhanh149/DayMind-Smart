# iOS implementation status — 17/11/2026

Branch feature/ios-support; draft PR2 → native/flutter-app; PR1/main not merged. Latest iOS is the user's target; minimum15.0 follows pinned Flutter template. Automatic periodic checks remain OFF. Simulator builds are not iPhone IPAs.

| Phase | Evidence / gate |
| --- | --- |
| 0 audit | PASS Linux baseline247 tests, lockfile resolution, analyze; commit416a3d7 |
| 1 scaffold | PASS local template/plist/XML/analyze; Apple compile deferred to6; commit95f0960 |
| 2 reminders | PASS local34 targeted tests incl7 iOS queue/adapter cases; native pending6/7; commit11216fe |
| 3 offline/files | PASS44 local DB/backup/asset/workspace tests; Swift Keychain XCTest prepared, Apple pending6; commitd7ccd4c |
| 4 sync | PASS12 local config/sync-record tests; default offline, production project missing; commit4232d13 |
| 5 UI/Companion | PASS33 widget tests incl3 new iOS notch/keyboard/large-text cases; real editor overflow fixed; commit023fde9 |
| 6 macOS CI | Runs44069212891/44070028121 setup failures fixed.793cb7e Mac analyze/259 tests/Simulator build pass; Keychain native -34018 unsigned identity confirmed in xcresult. 3bec4d0 manual signature approach rejected at launch (Taskgated Invalid Signature), removed. Xcode-managed Simulator signing/embedded identity correction pending native run; native XCTest/smoke prepared; no signing secrets |
| 7 real iPhone | BLOCKED: user has iPhone, no Mac; local signing needs borrowed/rented Mac; see07_DEVICE_ACCEPTANCE.md |

Local baseline full regression: **257/257 passed**. Follow-up iOS/digest17 tests pass with actual Darwin transport serialization, dismiss-only digest actions, snapshot summary and atomic foreground callbacks. **259/259 full local tests pass**, analyze clean.793cb7e Android/Windows native CI44071902509 and Firebase Emulator44071902475 pass. Mac259 tests and build pass; Keychain/native smoke still pending. Workflow YAML and3 Simulator-signing boundary checks pass. No claim of signed build, iPhone banner, real cross-device production sync, iPhone RAM/CPU measurements or official release. Native Android/Windows+Emulator regression CI also needs to complete for this branch.

Resume: inspect git status and latest branch/workflow SHAs before editing; do not start another worker if a turn is already active. Read WORK_CHECKPOINT/PHASE_STATUS/BUILD_STATUS plus this table. Complete actual macOS run and resolve failures before phase7. Keep uncommitted work; no reset-hard, merge main, release or production config changes. Live2D remains OFF.
