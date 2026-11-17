# DAYMIND SMART — KẾ HOẠCH TRIỂN KHAI iOS CHO CODEX

**Mục tiêu:** Đưa ứng dụng Flutter DayMind SMART hiện có lên **iPhone cá nhân**, người phát triển **chỉ có Windows**. Tái sử dụng mã nguồn tối đa; không làm hỏng Android/Windows; không đưa ứng dụng lên App Store ở giai đoạn này.

**Trạng thái tài liệu:** Kế hoạch thực hiện, không phải báo cáo đã build thành công.

## 0. Căn cứ và giới hạn

Đã kiểm tra bản ZIP mã nguồn có sẵn trong cuộc trò chuyện: `apps/daymind/pubspec.yaml` ghi `version: 0.7.1+9`, Dart SDK `^3.13.7`, các thư viện `flutter_riverpod 3.5.0`, `go_router 18.1.3`, `drift 2.35.3`, `sqlite3 3.9.1`, `path_provider 2.1.6`, `file_picker 13.3.2`, `flutter_local_notifications 22.0.0`, `timezone 0.11.2`, `flutter_timezone 5.0.1`. Bản ZIP này **chưa có** `apps/daymind/ios/`. `lib/platform/notification_scheduler.dart` có `supportsClosedApp => Platform.isAndroid`, và `lib/features/account_sync/data/firebase_rest.dart` có endpoint Emulator (`http`, `emulator-only`).

**BẮT BUỘC:** Codex phải kiểm tra repo thực tế đang mở; có thể là 0.8.0 hoặc mới hơn. Nếu khác với căn cứ trên, ưu tiên mã nguồn thực tế, cập nhật báo cáo, không áp đặt giả định. Không thể build/ký/chạy iOS native trên Windows: cần macOS + Xcode cho giai đoạn cuối. Không cam kết build thành công khi chưa chạy Xcode.

## 1. Quy tắc bất biến

1. **Không viết lại DayMind**: giữ Flutter, module hiện có, giao diện/phong cách C, dữ liệu người dùng, hành vi Android/Windows.
2. **Không làm phiền**: mặc định tối đa một mốc nhắc thông thường/công việc (theo cấu hình hiện hành); không tự thúc giục quá hạn liên tục; tôn trọng giờ yên tĩnh, quyền thông báo, Snooze và lựa chọn tắt nhắc. Companion không tạo thông báo độc lập.
3. **Offline-first**: CRUD hoạt động không mạng, SQLite giữ dữ liệu; đồng bộ chỉ khi có cấu hình hợp lệ.
4. **Không giả vờ tương thích**: không stub trả về `success` khi chưa lên lịch; capability thực tế phải hiển thị rõ trong UI/log.
5. **Không phát hành hay thay đổi cấu hình production khi chưa có chấp thuận**; không commit secrets, provisioning profile, certificate, token, API admin key.
6. Mỗi giai đoạn: mã nguồn + test + tài liệu + báo cáo thay đổi. Không sửa các phần ngoài phạm vi nếu không cần thiết.

## 2. Kiến trúc mục tiêu

```text
Flutter UI (Android / Windows / iOS)
    ├── Task / Calendar / Recurrence / Analytics
    ├── Companion UI & Behavior Engine
    ├── Application Services / Riverpod
    ├── Local Persistence (Drift/SQLite)
    ├── Sync Abstraction (Emulator / production cấu hình riêng)
    └── Reminder Engine (domain, không phụ thuộc OS)
          └── NotificationScheduler interface
               ├── Android scheduler (giữ hiện trạng)
               ├── Windows scheduler (giữ hiện trạng)
               └── iOS scheduler (UNUserNotificationCenter/plugin được kiểm chứng)
```

Đặc biệt: không nhét iOS-specific code vào domain Reminder Engine. Sử dụng adapter/platform service, feature detection và dependency injection theo kiến trúc repo hiện có.

## 3. Kế hoạch theo giai đoạn

### Phase 0 — Audit và baseline (Windows; KHÔNG sửa code)

- Xác định branch, commit, phiên bản thực tế, trạng thái git, Flutter/Dart SDK, lockfile và cấu trúc monorepo.
- Liệt kê tất cả chỗ dùng `Platform.isAndroid`, `Platform.isWindows`, MethodChannel, native notification, quyền hệ thống, đường dẫn tệp, plugin, thư viện SQLite, tải asset Companion.
- Kiểm tra từng dependency và phiên bản hiện có hỗ trợ iOS; ghi bằng chứng từ pub.dev/changelog/SDK docs, không tự đoán.
- Kiểm tra `notification_scheduler.dart`, `reminder_engine.dart`, `reminder_coordinator.dart`, `firebase_rest.dart`, logic recurring, notification logs, sync, backup/restore.
- Chạy `flutter pub get`, `flutter analyze`, `flutter test` trong `apps/daymind` nếu môi trường cho phép; lưu baseline và lỗi có sẵn.
- Đầu ra: `docs/ios/00_COMPATIBILITY_AUDIT.md` (bảng file, vấn đề, P0/P1/P2, hướng sửa), `docs/ios/00_BASELINE_TESTS.md`.
- **Gate:** chưa sửa code trước khi hoàn thành audit.

### Phase 1 — Scaffold iOS (Windows)

- Tạo nhánh `feature/ios-support` (không xóa nhánh hiện tại).
- Nếu chưa có `ios/`, chạy từ `apps/daymind`: `flutter create --platforms=ios .`; kiểm tra git diff, giữ nguyên Bundle ID đã có nếu repo mới hơn đã tạo iOS.
- Đặt tên ứng dụng DayMind SMART, app icon, display name, deployment target dựa trên yêu cầu plugin và iOS cần hỗ trợ; không tự chọn target quá cao nếu không cần.
- Chuẩn bị `Info.plist`, entitlement và quyền cần thiết ở mức tối thiểu; chỉ xin quyền thông báo vào thời điểm có ngữ cảnh.
- Không cấu hình signing giả hoặc commit provisioning profile.
- Đầu ra: `ios/` hợp lệ về mặt cấu trúc và `docs/ios/01_MAC_BUILD_SETUP.md`.
- **Gate:** `flutter analyze`/test trên Windows không regress; ghi rõ chưa kiểm chứng iOS native.

### Phase 2 — Adapter iOS Notifications (ưu tiên P0)

- Kiểm tra API thực tế của `flutter_local_notifications` bản đang dùng và `DarwinInitializationSettings`, `DarwinNotificationDetails`, lịch timezone, notification actions; chỉ dùng API có thật.
- Tạo adapter iOS phù hợp interface `NotificationScheduler`; triển khai `initialize`, quyền thông báo, `schedule`, `cancel`, `reschedule`, `pending`, click/action callback và xử lý mở app từ notification theo khả năng plugin.
- `supportsClosedApp` trên iOS chỉ true nếu lịch thông báo được **giao cho OS** thành công; không cần app chạy nền để đợi timer Dart. Không yêu cầu background execution không cần thiết.
- iOS chỉ giữ tối đa khoảng **64 local notifications pending**: sử dụng cửa sổ lập lịch hữu hạn (rolling horizon), ưu tiên các nhắc gần nhất; khi app mở lại/đồng bộ/cập nhật dữ liệu, bổ sung lịch; giải thích giới hạn: khi app không mở rất lâu, các mốc xa hơn cửa sổ có thể chưa được đặt.
- Quy tắc giờ yên tĩnh: xử lý trước khi đặt lịch; không tự ý bật critical alerts, time-sensitive interruption hay bỏ qua Focus. Nếu reminder bị dời, bảo đảm không vượt deadline theo cách gây hiểu lầm; nêu rõ chính sách trong settings.
- Hủy lịch khi hoàn thành/xóa/sửa deadline; Snooze tạo đúng một mốc mới; chống trùng bằng stable event ID; không replay hàng loạt notification cũ sau sync hoặc đổi múi giờ.
- Xin quyền notification theo ngữ cảnh, cho phép từ chối; hiển thị trạng thái quyền và đường dẫn Settings; nếu OS từ chối, vẫn lưu task.
- Không tạo notification riêng từ Companion; foreground dùng in-app cue nhẹ, không che nút, không âm thanh mặc định.
- Đầu ra: adapter, test bằng fake scheduler, `docs/ios/02_NOTIFICATION_BEHAVIOR.md` gồm matrix foreground/background/terminated/reboot/Focus/timezone.
- **Gate:** kiểm thử domain unit pass, iOS integration đánh dấu `PENDING_MAC_DEVICE` cho đến khi có iPhone thật.

### Phase 3 — Dữ liệu, file và offline

- Kiểm tra Drift/SQLite và native SQLite bundle cho iOS, đường dẫn Application Support/Documents, migrations và transaction; không dùng đường dẫn Windows/Android hard-coded.
- Đảm bảo local DB tồn tại qua đóng/mở app, không bị ghi đè khi upgrade, backup/restore an toàn và giới hạn dung lượng tệp.
- Kiểm tra import file ảnh/GIF/sprite và đường dẫn sandbox iOS; tránh giả định có thể đọc file bên ngoài sandbox lâu dài.
- Test create/edit/delete/reopen, recurrence, timezone, restore, migration; giữ tính tương thích dữ liệu.
- Đầu ra: test + `docs/ios/03_STORAGE_AND_FILES.md`.

### Phase 4 — Firebase / account sync

- Phân biệt Emulator và production: cấu hình qua môi trường/DI; không dùng endpoint HTTP emulator cho bản iPhone cá nhân production.
- Nếu repo chưa có Firebase production, chỉ chuẩn bị abstraction/config; cần người dùng cung cấp Firebase project, iOS app registration và thông tin client hợp lệ trước khi bật.
- Không hardcode service account/admin credentials. Kiểm tra Firebase Auth, Firestore rules, refresh token, TLS, lỗi offline và conflict resolution; không đổi logic sync đang chạy trên Android/Windows.
- Test đồng bộ iPhone ↔ Android/Windows chỉ khi có môi trường test thực tế; trước đó chỉ xác nhận qua mocks/emulator.
- Đầu ra: `docs/ios/04_SYNC_SETUP.md`, test và bảng những cấu hình còn thiếu.

### Phase 5 — UI/UX và Companion iPhone

- Kiểm tra safe area, notch/Dynamic Island, keyboard, accessibility text scale, dark mode, thao tác chạm, điều hướng, portrait và màn hình nhỏ.
- Companion mặc định nhỏ gọn (~80dp theo thiết kế), tự ẩn/thu nhỏ khi nhập liệu, không che nút, thanh tab hay form; có tùy chọn kích thước và tắt hẳn.
- V1 iOS ưu tiên PNG/WebP/GIF/sprite và biểu cảm trong ứng dụng. Không triển khai overlay nhân vật nổi trên toàn iOS. Live2D là **feature flag OFF** cho đến khi xác minh SDK, iOS build, RAM và giấy phép.
- Đảm bảo không phát âm thanh mặc định, không tự tạo notification mới.
- Đầu ra: checklist màn hình + widget tests + `docs/ios/05_UI_COMPANION.md`.

### Phase 6 — CI macOS và kiểm thử native

- Tạo GitHub Actions workflow macOS (nếu repo có GitHub CI) để chạy `flutter pub get`, `flutter analyze`, `flutter test`, `flutter build ios --simulator --no-codesign` theo cấu hình được hỗ trợ; kiểm tra CocoaPods/Xcode khi thực thi.
- CI simulator **không chứng minh** notification khi app terminated, signing hay hoạt động trên iPhone thật.
- Không thêm secret signing vào repo; dùng secrets bảo mật chỉ nếu về sau cần build ký tự động.
- Đầu ra: `docs/ios/06_CI_AND_DEVICE_TESTS.md` và kết quả CI thực tế; nếu chưa chạy, đánh dấu pending.

### Phase 7 — Mac + iPhone thật (BẮT BUỘC ngoài Windows)

- Mượn/thuê Mac có Xcode tương thích và iPhone thật. Cài Flutter, Xcode, CocoaPods nếu cần; clone repo và mở `ios/Runner.xcworkspace`.
- Đăng nhập Apple Account trong Xcode, chọn Personal Team, bật Automatically manage signing, đặt Bundle ID duy nhất, cắm iPhone, bật Developer Mode và Trust.
- Chạy `flutter doctor -v`, `flutter pub get`, `flutter run -d <iphone>`; xử lý lỗi build/signing từ log thật.
- Kiểm thử notification khi app foreground/background/terminated, khóa màn hình, Focus, giờ yên tĩnh, restart, timezone, từ chối quyền; thử hàng chục task, lịch lặp và thông báo sát nhau.
- Test offline/online, backup/restore, sync (nếu đã cấu hình), Companion memory và không che UI.
- **Apple Account miễn phí:** cài cá nhân qua Xcode có thể bị giới hạn provisioning, thường cần ký lại sau khoảng 7 ngày. Không yêu cầu mua Apple Developer Program cho mục tiêu ban đầu.
- Đầu ra: `docs/ios/07_DEVICE_ACCEPTANCE.md` với PASS/FAIL/PENDING và bằng chứng log/ảnh chụp.

## 4. Tiêu chí nghiệm thu bắt buộc

- [ ] Không làm hỏng build/test Android và Windows hiện có.
- [ ] iOS app mở được trên iPhone thật, CRUD task và SQLite hoạt động offline.
- [ ] Lịch nhắc được giao cho hệ điều hành và vẫn phát khi DayMind không chạy (theo giới hạn iOS).
- [ ] Hoàn thành/sửa/xóa task hủy đúng notification chưa phát.
- [ ] Không gửi spam, không tự lặp overdue, tôn trọng quiet hours và quyền người dùng.
- [ ] Không phát trùng sau reopen/sync/Snooze; có test cho DST/timezone và recurrence.
- [ ] Không che nút bằng Companion, không có overlay ngoài app, âm thanh mặc định tắt.
- [ ] Không mất dữ liệu sau restart/upgrade; import/backup hợp lệ.
- [ ] Không lộ credentials, log không chứa token/nội dung nhạy cảm.
- [ ] CI iOS simulator pass và test iPhone thật pass trước khi gọi là “hoàn thành”.

## 5. Cách Codex phải làm việc

- Trước mỗi phase: báo các file dự kiến sửa và rủi ro; sau phase: báo file đã sửa, test đã chạy, test chưa chạy, vấn đề còn lại.
- Không nâng cấp hàng loạt dependency chỉ để thử; nếu bắt buộc, nêu lý do, phạm vi và rủi ro.
- Không xóa dữ liệu/migrations, không thay đổi schema tùy tiện; có test migration.
- Không che giấu lỗi bằng `catch (_) {}` hoặc trả thành công giả; logging có phân loại lỗi nhưng không lộ dữ liệu cá nhân.
- Không tự tuyên bố “iOS hoàn thiện” chỉ vì Dart tests pass trên Windows.
- Mỗi phase có commit riêng khi được người dùng đồng ý; nếu thiếu Apple/Firebase config, dừng đúng điểm cần quyết định.

## 6. PROMPT ĐẦU TIÊN — DÁN NGUYÊN VĂN VÀO CODEX

> Bạn là senior Flutter/iOS engineer. Hãy đọc toàn bộ file `DAYMIND_IOS_CODEX_IMPLEMENTATION_PLAN.md` tại root repository và thực hiện **chỉ Phase 0 (Audit + Baseline)** trước. Mã nguồn repo hiện tại là nguồn sự thật; không giả định repo vẫn ở 0.7.1. Xác minh version, cấu trúc, plugin iOS, các chỗ phụ thuộc Android/Windows, NotificationScheduler, SQLite/Drift, Firebase Emulator/production, Companion và các test. Tạo `docs/ios/00_COMPATIBILITY_AUDIT.md` và `docs/ios/00_BASELINE_TESTS.md`, chỉ rõ file/line, mức ưu tiên P0/P1/P2, giải pháp, những gì có thể làm trên Windows và những gì cần macOS. Chạy test hiện có nếu khả thi. **Chưa sửa code, chưa tạo thư mục iOS, chưa nâng cấp dependency.** Sau đó dừng, báo kết quả và đề xuất thứ tự triển khai Phase 1–7 để tôi phê duyệt. Không tuyên bố build iOS thành công nếu chưa dùng macOS/Xcode.

## 7. PROMPT SAU KHI DUYỆT PHASE 0

> Hãy tiếp tục Phase 1 của `DAYMIND_IOS_CODEX_IMPLEMENTATION_PLAN.md` dựa trên audit đã được duyệt. Chỉ sửa những file cần thiết, giữ nguyên Android/Windows, chạy regression tests và cập nhật tài liệu. Sau khi xong, dừng và báo rõ thay đổi, kết quả test, hạn chế Windows và điều kiện để bắt đầu Phase 2. Không tự chuyển sang phase tiếp theo.

## 8. Những việc người dùng cần cung cấp sau

- Repo DayMind phiên bản mới nhất (0.8.0 nếu đã có), nếu khác repo Codex đang mở.
- Phiên bản iPhone/iOS và mục tiêu minimum iOS version nếu có.
- Quyết định dùng Firebase production hay chỉ offline cho bản iPhone cá nhân.
- Một máy Mac (mượn/thuê) để ký/cài bản cuối, và Apple Account của chính người dùng.

**Ưu tiên thực hiện:** Audit → scaffold → iOS reminders → SQLite/file → sync → Companion/UI → CI → Mac/iPhone thật.
