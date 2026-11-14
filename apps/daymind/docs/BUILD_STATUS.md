# Preview 0.8.0+10 — cập nhật 14/11/2026

Nguồn phần mềm đã kiểm: `d3749182de8afdcde62610f848ef0681eff91516`, tree `b27186411272920070d9a6ecc500241b3ce93822`. [Native CI](https://github.com/Duckhanh149/DayMind-Smart/actions/runs/43435282895) **đạt cả Android và Windows**; [Firebase Emulator](https://github.com/Duckhanh149/DayMind-Smart/actions/runs/43435282802) đạt. Chưa hợp nhất main hoặc phát hành chính thức. Các commit tài liệu sau nguồn này không tạo build mới.

## Tải bản đã kiểm

Cần đăng nhập GitHub để tải artifact; hạn lưu đến 11/02/2027.

| Gói | Cách dùng |
| --- | --- |
| [Windows 10/11 x64 ZIP](https://github.com/Duckhanh149/DayMind-Smart/actions/runs/43435282895/artifacts/14044235287) | Giải nén và chạy `windows-installer/DayMind-Setup.exe`. Portable: giữ nguyên toàn bộ `windows/x64/runner/Release`, chạy `daymind_smart.exe`. |
| [Android ARM64 ZIP](https://github.com/Duckhanh149/DayMind-Smart/actions/runs/43435282895/artifacts/14044365559) | Giải nén `app-arm64-v8a-release.apk`; Android 7/API24+, ARM64, target36, versionCode2010. |

Đây là preview: Windows chưa ký Authenticode, APK dùng chứng thư Android Debug. **Không gỡ app đang có dữ liệu để vượt lỗi khác chữ ký**. Xuất và kiểm tra bản sao lưu trước nâng cấp; xem [ký production](PRODUCTION_SIGNING.md). Bản build mặc định dùng SQLite cục bộ; chưa kết nối Firebase production. Hướng dẫn cấu hình ở [FIREBASE_PRODUCTION](FIREBASE_PRODUCTION.md).

Windows ZIP SHA256 `a94d22cc3466460211af90e154311e80ea9312d455c67ec3b317cd6ee3ea61d1`; installer `5b60bda597f925915351c64963dd9bce1be12a7da3193ffc7af250c2f91fc9e7`. Android ZIP `3dfa8843c4ba45c49406bc146b635f64162408d9b2226fab7b09723d4af1f9e5`; APK `fc8c385e13188d0ed68c79093e4d997c47bda5fa286e19b41fa3b11426cd4da4`. Đã đối chiếu digest GitHub, CRC, phiên bản PE/APK, ABI, runtime VC++, font OFL/Apache notices và không có debug receiver/tệp probe/dữ liệu người dùng/khóa ký trong gói. [Báo cáo gói](qa/HARDENING_080_PACKAGES.json).

## Thay đổi và kiểm chứng

- Windows dùng AppUserModelID thống nhất, đọc trạng thái OS và phân biệt quyền đã biết với khả năng gửi yêu cầu. Quyền không đọc được vẫn hiển thị **chưa xác định**, không coi là được cấp. CI thực sự gửi qua OS khi cửa sổ ẩn và được API chấp nhận; runner đang quiet state6, Setting trả `0x80070490`, không có toast trong history và **chưa xác nhận banner**. Không sửa DND/chính sách OS. Close→tray chỉ khi khay sẵn sàng; Thoát hẳn/đăng xuất/reboot không nhắc, autostart tắt.
- Firebase tách local/Emulator/production; production chỉ dùng HTTPS chính thức, không chuyển token theo redirect. Session, workspace và owner của backup cách ly theo project, giữ nguyên UID của SQLite/sync. Rules kiểm chủ sở hữu, provider password, schema/kích thước và tombstone. Không có project thật nên chưa deploy hoặc nghiệm thu production.
- Chẩn đoán mặc định tắt, chỉ xuất khi người dùng yêu cầu; tối đa128 mã trạng thái trong phiên, thời gian tương đối và HRESULT dạng số. Không ghi task/title/email/UID/token/đường dẫn hoặc thông báo lỗi thô. Bỏ một bản sao plaintext không cần thiết khi mã hóa backup lớn.
- Android:247 Flutter tests,27 receiver/recovery được bộ thu thập xác nhận, Keystore/scoped session, cold OS notification/digest/quiet/no replay, SQLite process isolation +5 vòng ghi/recovery, backup/account/artwork và SDK drive đạt. Namespace host test bổ sung nằm trong Gradle task; bộ đếm receiver chỉ đếm ReminderRuntimeTest nên không gán tổng28 cho báo cáo.
- Windows:245 Flutter tests +2 symlink skip do đặc quyền runner (Linux chạy đủ),100 component checks Win32/GDI+ với notification reader được kiểm soát; DPAPI/scoped session, live hidden-window OS attempt, backup/account/artwork, tray/Mở/Thoát/không autostart đạt. Cài0.6.1→nâng0.8.0→gỡ→cài lại giữ4 task rows/2 ảnh/6 domain records và registry DisplayVersion đúng.
- Firebase Emulator: security mở rộng,16 Dart thật +7 AOT đạt. Local:247 Flutter, analyze sạch,35 targeted reminder/diagnostic và27 Python guards đạt. [Báo cáo native](qa/HARDENING_080_NATIVE.json), [local](qa/HARDENING_080_LOCAL.json).

## RAM/CPU và cổng còn mở

Profile AOT chạy Companion120 khung và sync6 lần trong120 giây, nhập ba BMP hợp lệ tổng hơn36MiB, capture/encrypt/decrypt dữ liệu thật. Soak: Android peak RSS255,3MiB/CPU43,1% một core; Windows324,8MiB/18,8%. Lifetime peak sau backup lớn khoảng634MiB Android và548MiB Windows; máy ít RAM vẫn cần kiểm. CPU có thể >100% khi cộng nhiều thread. Đây là tiến trình Flutter sau các fixture khác, không phải RAM idle mới mở app, không gồm process Android reminders hoặc chứng nhận trên thiết bị thật. Floating Windows bị OS quiet policy chi phối; bài soak đo animation trong dialog. [Số đo đầy đủ](qa/HARDENING_080_RESOURCES.json), [cách thu thập và nghiệm thu](RESOURCE_AND_DEVICE_ACCEPTANCE.md).

Chưa có thiết bị Android OEM/Windows10/11 thật, project Firebase production hoặc danh tính ký phát hành. Battery saver/Doze/reboot/DND/nâng cấp trên thiết bị thật, tải sát64MiB assets/96MiB plaintext và chạy nhiều giờ còn mở. Firebase cloud không phải E2EE; ảnh nhân vật không đồng bộ. Live2D vẫn tắt chờ kỹ thuật/giấy phép. Automation kiểm tra định kỳ đã tắt theo yêu cầu và giữ tắt.
