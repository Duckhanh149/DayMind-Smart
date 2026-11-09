# Kiểm chứng bản native 0.1.0

Cập nhật 09/11/2026 (Asia/Saigon). Nguồn native tại apps/daymind; web root độc lập.

- Flutter 3.47.9 / Dart 3.13.7; JDK Temurin 21.0.13+9; Android SDK 35/36, NDK 28.2.13676358, CMake 3.22.1.
- flutter analyze: PASS, không issues. flutter test: 28/28 PASS trên Linux và runner Windows.
- UI phone/desktop/Companion được xem lại bằng PNG từ Flutter test. Kiểm tra 360/390/768/1440 px, chữ 200%, bàn phím, CRUD, SQLite transaction/migration/restart/revision và asset import budgets.
- Workflow 42500600905: Android APK build PASS; Windows release build PASS; Windows native integration startup + tạo/lưu công việc PASS; Inno Setup installer + bundled VC++ runtime PASS.
- Android artifact đã kiểm CRC ZIP/APK, manifest: dev.daymind.daymind_smart, version 0.1.0, minSdk 24, targetSdk 36. Bản debug đầu có ARM64/x86_64; bản phát cho điện thoại được tối ưu lại thành ARM64.
- Windows artifact đã kiểm CRC, PE x64, installer và các DLL runtime. Không xem đây là việc cài thủ công trên Windows 10/11 của người dùng.
- Build local Android trên cloud 8 GB hết dung lượng khi merge native libraries; phần đóng gói được chuyển sang GitHub Actions đã build thành công. Không tính lần local thất bại là PASS.
- Vòng cuối bổ sung OFL vào asset bundle/LicensePage, APK release ARM64 ký khóa preview, checksums và bản tải GitHub Releases; chờ workflow cuối xác minh rồi ghi kết quả.
- Android thiết bị thật, Windows 10/11 cài thủ công, low-end hardware RAM/CPU: chưa chạy. Runner Windows native smoke không thay thế các mục này.
- Thông báo khi app đóng/reboot, MSIX identity/activation, Firebase/sync, animation/floating companion/Live2D: chưa có; thuộc các giai đoạn tiếp.
- Chưa có chứng thư ký phát hành Windows hoặc khóa Android sản xuất. Đây là preview, chưa phải bản Store.
