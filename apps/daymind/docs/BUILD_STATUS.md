# Kiểm chứng bản native 0.1.0

Ngày 08/11/2026. Nguồn native tại apps/daymind; web root vẫn độc lập.

- Flutter 3.47.9 / Dart 3.13.7; JDK Temurin 21.0.13+9 (checksum xác minh); Android SDK 36, NDK 28.2.13676358.
- flutter analyze: PASS, không issues.
- flutter test: 28/28 PASS. Bao gồm SQLite transaction/migration/restart/revision, Companion asset budgets/path validation/decode, queue settings và widget tests responsive/keyboard/font 200%.
- Render phone/desktop/Companion đã xem lại bằng PNG từ Flutter test. Không gọi đây là test thiết bị thật.
- Build APK local: đang thực hiện; cập nhật khi có kết quả.
- Windows build/installer/native smoke: workflow được chuẩn bị, chưa tuyên bố đạt cho tới khi Actions có kết quả.
- Android thiết bị thật, Windows 10/11 cài thủ công, low-end hardware RAM/CPU: chưa chạy.
- Thông báo khi app đóng, Android reboot, MSIX identity/Windows activation, sync/Firebase: chưa có; nằm trong các giai đoạn tiếp.
- Chưa có chứng thư ký phát hành; APK debug và Windows package chưa phải bản phát hành Store.

Không đổi sharing của website hoặc repository, không thêm secret, không tự bật background/startup helper.
