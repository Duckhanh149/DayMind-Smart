# Phase 6 — macOS CI and evidence

Workflow .github/workflows/ios-build.yml runs only the isolated feature/ios-support push (or explicit dispatch); no release/publishing/signing secret. Pinned Flutter3.47.9/SHA, lockfile, analyze, shared unit/widget tests, normal app simulator debug/no-codesign build, Swift XCTest Keychain, then actual Flutter startup/SQLite background worker reopen/CRUD/integrity and owned-artwork backup smoke. Uses latest available installed iPhone runtime, records exact Xcode/SDK/device selection; this is not a promise that runner includes the newest Apple SDK released that day.

Rebuilds lib/main.dart after integration entrypoint before exporting Simulator .app ZIP and repository source ZIP; evidence artifact contains tool versions, logs and XCTest result bundle. A Simulator ZIP is NOT an iPhone-installable IPA. Android/Windows native and Firebase Emulator workflows also cover this branch; main and PR1 are not merged/modified by this work.

Current result: PENDING actual GitHub run. Local Linux gates are recorded in STATUS.md. Do not infer Apple compilation or native security success from mock/unit tests. Update this file with run URL, tested SHA and real failures/results after CI; do not report completion with pending/failed jobs.

Hardware acceptance remains phase7 even when CI passes: signing/profile, terminated/background/locked/Focus notification banners, OS restart, latest physical iPhone, native keyboard/Files picker, upgrade/no-data-loss and memory/CPU. No production Firebase project configured; Emulator evidence cannot replace real authorized cross-device production acceptance.
