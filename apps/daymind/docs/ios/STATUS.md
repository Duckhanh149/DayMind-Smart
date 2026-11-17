# iOS implementation status — 17/11/2026

**Software phases0–6 passed; phase7 is blocked on Mac+iPhone access.** Branch `feature/ios-support`, [draft PR2](https://github.com/Duckhanh149/DayMind-Smart/pull/2) targets `native/flutter-app`. PR1/main remain unmerged; periodic automation remains OFF. User requested latest iOS; CI tested the latest available installed runtime iOS26.5/iPhone Air, not the user's physical device. Minimum iOS15.0 follows pinned Flutter3.47.9.

| Phase | Gate / evidence |
| --- | --- |
| 0 audit | PASS: Linux baseline247 tests, dependency lock/analyze; audit current0.8.0 rather than document's0.7.1; commit416a3d7 |
| 1 scaffold | PASS: isolated generated target, Bundle ID dev.daymind.daymindSmart, Apple compilation verified in6; commit95f0960 |
| 2 reminders | PASS automated:60-slot shared queue, cancel/repair/no past replay, UTC/quiet/DST policy, atomic foreground callbacks, real plugin contract, separate ready/permission states. Native initialization/permission query works; banners/actions on physical phone remain7; initial11216fe, corrected4b9963a |
| 3 offline/files | PASS:44 local regression tests, native Swift Keychain2 tests, actual iOS SQLite reopen/CRUD/integrity and owned-image/asset-backup roundtrip; initiald7ccd4c |
| 4 sync | PASS config/Emulator:12 local config/sync-record tests plus real Emulator CI. Default offline; production project/client setup and real cross-device acceptance remain missing; initial4232d13 |
| 5 UI/Companion | PASS33 widget tests, including3 iOS small/notch/keyboard/large-text cases; editor overflow fixed;80dp configurable Companion hides during typing; original icon. Native keyboard/VoiceOver/performance remain7; commit023fde9 |
| 6 macOS CI | PASS [44086368066](https://github.com/Duckhanh149/DayMind-Smart/actions/runs/44086368066):259 shared tests, analyze, normal Simulator build, both Keychain XCTest tests, real Flutter startup/SQLite/files smoke, final normal-app rebuild and packaged ZIPs |
| 7 real iPhone | BLOCKED: user has iPhone, no Mac. Needs borrowed/rented Mac with Xcode/local Personal Team signing; see07_DEVICE_ACCEPTANCE.md. No iPhone IPA/App Store release |

Runtime source `4b9963a3371f8eb30448cc39cccee98d2a5b2425`, tree `b6e2c82ab5aee64493d6e87c0582ef09c5dbacd1`. [Android/Windows native regression44086368080](https://github.com/Duckhanh149/DayMind-Smart/actions/runs/44086368080) PASS. [Firebase Emulator44087260988](https://github.com/Duckhanh149/DayMind-Smart/actions/runs/44087260988) PASS with CI-only token setup9904e53; runtime/lib/ios/Android/Windows/pubspec identical. Download/evidence hashes and exact limits: [QA report](../qa/IOS_PORT_20261117.json), [CI report](06_CI_AND_DEVICE_TESTS.md).

A pending OS request or native success does not prove a visible banner. This run observed permission not granted and never auto-requested it. Physical notification/Focus/reboot, upgrade and RAM/CPU evidence remain open. Firebase production remains unconfigured; no data was backed up to a production cloud. Live2D OFF, no iOS floating overlay. No official release or main merge.

Resume only with new requirements or Mac+iPhone availability: read WORK_CHECKPOINT/PHASE_STATUS/BUILD_STATUS and this table, inspect workspace/latest CI, preserve uncommitted changes, avoid duplicate coding turns. Do not restart periodic checks.
