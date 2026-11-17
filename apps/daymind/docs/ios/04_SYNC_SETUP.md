# Phase 4 — Firebase configuration for iOS

Offline remains default, including simulator CI. Uses existing shared Firebase REST Auth/Firestore gateway; no dependency migration or Apple Firebase SDK plist is needed to compile this REST client. Emulator build is explicit (demo project/loopback only); production factory requires valid project/client key and official HTTPS hosts, refuses token redirects, validates project scope before persisting refresh session. Keychain namespace is isolated per backend/project; account workspaces and backup owner hashes are already scoped. Firestore rules require password provider and same UID, bounded validated schema/tombstones. Conflict/refresh/offline behavior unchanged. Device list now labels iOS correctly.

| Required before production or real cross-device acceptance | Status |
| --- | --- |
| User-controlled Firebase project, Auth email/password enabled | Missing |
| Register iOS app dev.daymind.daymindSmart (or user's final unique Bundle ID) | Missing |
| Valid client config and API restriction compatible with this REST client | Missing; no public/admin credentials added |
| Deploy reviewed Firestore rules; run unauthorized/other-user/schema rejection probes in dedicated test project | Pending project; Emulator rules CI retained |
| Actual iPhone ↔ Android/Windows account, edit/offline reconnect/conflict/logout isolation | Pending real devices/config |

See ../FIREBASE_PRODUCTION.md for build configuration; never use service-account credentials in this app. For a bundle-restricted iOS client key, verify the Firebase REST endpoint's X-Ios-Bundle-Identifier requirement against the final Bundle ID before enabling production; no runtime identity header is guessed from a local signing override. Keep emulator build separate from personal production app. Simulator127.0.0.1 refers to Mac host; iPhone127.0.0.1 refers to the phone and is not a remote Emulator connection. No arbitrary ATS exception or LAN endpoint weakening added.

Local configuration/sync-record tests pass; account workspace regression already passed in phase3. Emulator CI and native secure-store channel are required in phase6. No production project has been contacted/deployed; no claim that data is already backed up to Firebase or synchronized on iPhone.
