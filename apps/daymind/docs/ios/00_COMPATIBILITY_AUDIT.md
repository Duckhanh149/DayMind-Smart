# Phase 0 — Audit iOS, 17/11/2026

Nguồn thực tế `0f03082638b644a078095986951ceb3bfdacd2af`, app0.8.0+10; native/flutter-app/PR1 mở, workspace sạch, không worker khác. Nền tảng thực thi hiện tại Linux; không gọi đây là Windows hoặc Mac đã kiểm. Tái sử dụng app Flutter, không viết lại hoặc merge main. Tài liệu đính kèm tham chiếu0.7.1; các prompt mẫu dừng riêng từng phase không thay yêu cầu trực tiếp triển khai0–7.

| Ưu tiên | Vị trí | Vấn đề | Hướng xử lý |
| --- | --- | --- | --- |
| P0 | lib/platform/notification_scheduler.dart | Chỉ Android/Windows; schedule() ngoài Android không giao OS | Adapter Darwin của FLN22; pending thực, UTC instant, queue60/64, không thành công giả |
| P0 | lib/platform/secure_session_store.dart | daymind/secure chưa có iOS native | Keychain riêng app, AfterFirstUnlockThisDeviceOnly, backend/project namespace; không UserDefaults plaintext |
| P0 | reminder_engine.dart reconcile() |128 pending, digest đặt lịch trực tiếp; iOS chỉ khoảng64 | Capability cửa sổ tổng60, digest chung hàng đợi; sửa/hủy/reconcile trạng thái OS; không replay past |
| P0 | reminder_coordinator.dart refresh() | Mọi non-Android chạy Dart claim/poll; gây trùng với OS iOS | iOS OS-owned delivery, foreground qua delegate, tap/Snooze/Dismiss mở app, callbacks được đệm đến coordinator ready |
| P1 | app/workspace_host.dart | Nhãn thiết bị non-Windows thành Android | Nhãn iPhone; resolver event dùng DB hiện tại; scope session/backup và quiesce đổi tài khoản giữ nguyên |
| P1 | notifications settings UI | supportsClosedApp suy thành Android/Windows | Mô tả iOS riêng: quyền, Focus, cửa sổ60, mở lại để bổ sung; không critical/time-sensitive/background entitlement |
| P1 | Firebase REST/fromBuild | Production đã tách và default offline | Giữ nguyên HTTPS/rules/token validation; iOS production/config/live còn cần project thật |
| P1 | ios/ | Chưa có target | Flutter pinned template, BundleID hợp lệ, minimum theo Flutter template (phase1 xác lập15.0); signing thiết bị để trống |
| P1 | UI/Companion/import/backup | Cần kiểm notch/keyboard/sandbox/documents picker/codec trên Apple | Widget regression; macOS simulator native kiểm Keychain/SQLite/files và handoff; iPhone thật vẫn pending |
| P2 | Live2D/floating | Chỉ Windows có cửa sổ nổi | Không overlay iOS, Live2D OFF; giữ raster và accessibility |

Các native channel: daymind/secure cần iOS; daymind/window/companion đã guardWindows; daymind/reminders guardAndroid. path_provider/Drift dùng Application Support và platform-independent paths. Backup dùng bounded files/atomic staging và owner scope; không đổi schema.

Dependency evidence từ phiên bản pin trong PUB_CACHE/pubspec.lock: FLN22 ios/flutter_local_notifications.podspec target13.0; flutter_timezone5.0.1 target11.0; path_provider_foundation có iOS; file_picker13.3.2 có iOS/document picker; sqlite3 3.9.1 có native asset hook iOS. Flutter3.47.9/Dart3.13.7 có iOS template. Riverpod/go_router/crypto/cryptography/timezone/uuid/path là Dart dùng chung. Metadata này xác nhận mục tiêu được khai báo, không chứng minh linker/runtime iPhone. Nguồn: https://pub.dev/packages/flutter_local_notifications/versions/22.0.0 ; https://pub.dev/packages/sqlite3/versions/3.9.1 ; https://pub.dev/packages/file_picker/versions/13.3.2 ; https://pub.dev/packages/flutter_timezone/versions/5.0.1 .

Không nâng dependency hàng loạt. CocoaPods/Xcode/Swift/Simulator chỉ xác nhận ở phase6. Windows có thể author scaffold/Dart/Swift source, không build/ký IPA; môi trường hiện tại cũng không có Mac/iPhone. macOS CI không thay ký/cài và Focus/terminated/reboot/upgrade trên iPhone thật.
