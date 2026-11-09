# Tiến độ DayMind — 09/11/2026

Không đánh đồng mã đã viết, kiểm thử tự động, build và nghiệm thu thiết bị. Tài liệu tham chiếu là tiêu chí sản phẩm; mục 13 copy/paste không thay cho yêu cầu trực tiếp mới của người dùng.

| Giai đoạn | Hiện trạng và bằng chứng | Cổng còn thiếu |
| --- | --- | --- |
| 0 | Flutter Android/Windows build và SQLite/import/render tĩnh đã chạy ở preview 0.1.0. Firebase Auth/Firestore Emulator POC mới đạt local và CI 42566629407. | Nhắc nền Android khi đóng tiến trình; Windows packaging/activation/đóng tiến trình; phần cứng đích. |
| 1 | CRUD local, migration, transaction/revision, không cần deadline, danh mục, bộ lọc, dashboard, giao diện responsive; 28 kiểm thử nền tảng trước, hiện tổng 53 đạt local. | Kiểm tra sử dụng dài ngày trên máy người dùng. |
| 2 | Reminder rules/ledger/dedup/quiet/snooze/dismiss, quyền, Notification Center; 22 clock/SQLite + 2 UI mới đạt. Có receiver Android và kiểm thử recovery. Windows live engine có guard. | Build/kiểm thử receiver mới đang sửa và chạy lại; Android emulator smoke được thêm; Windows thoát hoàn toàn chưa hỗ trợ. Không đánh dấu hoàn thành. |
| 3 | Chưa triển khai calendar day/week/month và occurrence/series editing. | Toàn bộ kiểm thử recurrence/DST/monthly. |
| 4 | Chưa có digest và analytics hoàn chỉnh. | Opt-in digest, denominator/fixtures, dashboard tùy chỉnh. |
| 5 | Người dùng chọn Emulator; đã kiểm chứng kết nối Auth, Firestore, owner rules và CAS precondition. **Chưa có đồng bộ trong app.** | Account isolation SQLite, outbox/retry/tombstone/conflict UI, hai thiết bị offline/online, primary-device policy. |
| 6 | Mầm gốc + PNG/WebP tĩnh, thư viện, 3 tính cách, cooldown, mặc định im lặng đã có. | Editor lời thoại/expressions/placement và đo tài nguyên. |
| 7 | Chưa có animation package và cửa sổ Companion nổi Windows. | Safe ZIP/sprite/GIF, lifecycle/performance, floating/fullscreen/click-through. |
| 8 | Live2D tắt; chưa tích hợp SDK hoặc phân phối model. | POC Android/Windows, giấy phép SDK/model và duyệt phạm vi phát hành. |
| 9 | CI, installer/portable Windows và APK ARM64 preview; dark mode, chữ 200%, nhập file an toàn được kiểm thử. | Backup/restore có mật khẩu, privacy/release review, chữ ký phát hành, thiết bị và regression đầy đủ. |

Phiên bản đã xác minh trước thay đổi nhắc việc: commit `7ffd0d5`, workflow `42560998276`. Commit nhắc việc đầu `2d46299`: Windows analyze/52 tests/build/native integration/installer đạt; Android bị lỗi tải SQLite HTTP 504, chưa được tính đạt. Commit `4fbf5f2`: Firebase Emulator CI đạt; Android SDK37 không có trong repository SDK hiện tại; Windows gặp HTTP504 khi tải SQLite. Đã chọn lại `flutter_local_notifications 22.0.0` (compile SDK36, Windows adapter 3.1.1) và chỉ retry những lỗi HTTP502/503/504 của native asset SQLite; không retry che lỗi kiểm thử hay mã ứng dụng.

Không yêu cầu tài khoản cloud hoặc khóa thật để tiếp tục Emulator. Không tự bật Live2D/startup helper hay sửa `main` trong khi PR #1 còn mở.

Vòng local cuối: `flutter analyze` không vấn đề, **53/53** kiểm thử đạt, gồm rollback nguyên tử task + custom reminder khi cấu hình sai và CRUD khi từ chối quyền. `tool/precache_sqlite.py` tải qua API phát hành GitHub chính thức và kiểm SHA256 từ gói sqlite3 3.9.1 đã ghim; ba asset Linux/Android ARM64/x64 đạt. Không đổi binary, TLS hoặc checksum. Ảnh Notification Center đã xem tại `docs/ui/notifications.png`. CI mới cần chạy trên commit chứa bước precache này trước khi nghiệm thu Android.
