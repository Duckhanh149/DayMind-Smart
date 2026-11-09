# Điểm tiếp tục DayMind

## Mục tiêu và lựa chọn đã xác nhận

Hoàn thiện ứng dụng Android và Windows 10/11 theo các giai đoạn 0–9; kiểm chứng giai đoạn hiện tại trước khi triển khai giai đoạn kế tiếp. Dùng Firebase Emulator trước khi có dự án production. Đóng cửa sổ Windows thu vào khay để tiếp tục nhắc; menu có Mở và Thoát hẳn; tự khởi động cùng Windows mặc định tắt.

Người dùng muốn tiếp tục sau khi phải chờ giới hạn. Tác vụ nền “Tiếp tục DayMind” đã được bật để kiểm tra mỗi giờ theo múi giờ Asia/Saigon và thử nối tiếp khi hạn mức/môi trường cho phép; không chạy song song với phiên đang thực hiện dự án. Không bảo đảm tiếp tục ngay khi giới hạn vừa hết. Tài liệu này giữ điểm nối để lượt sau bảo toàn công việc và kiểm tra CI đúng commit trước khi thay đổi.

## Nguồn và kiểm chứng gần nhất

- Nhánh: `native/flutter-app`, PR [#1](https://github.com/Duckhanh149/DayMind-Smart/pull/1). Không cập nhật `main` khi cổng hợp nhất chưa được chấp thuận.
- Source checkpoint: `4c8ceb8dff81ae2a87c701734ac7a533f24d07e9`.
- Giai đoạn 0–4 đã qua cổng tự động; chi tiết trong [PHASE_STATUS.md](PHASE_STATUS.md).
- Giai đoạn 5: 121 kiểm thử Flutter và phân tích mã sạch tại local; Kotlin main/debug biên dịch đạt. Tám ca account/profile/UI bao gồm chọn bản xung đột với chữ 200%.
- [Emulator CI 42665407030](https://github.com/Duckhanh149/DayMind-Smart/actions/runs/42665407030) đã đạt 14 ca dữ liệu/Auth thật và bảy ca Auth/payload AOT trên checkpoint này.
- [Native CI 42665407040](https://github.com/Duckhanh149/DayMind-Smart/actions/runs/42665407040): Windows đã đạt 121 tests, DPAPI/Auth/Firestore/profile/primary/logout/relogin/delete, tray và installer. Android đã build release, đạt 25 receiver cases và Keystore/cold-process/digest. Lượt native account treo sau khi cài APK kiểm thử và bị hủy khi job hết thời gian; chưa tính ca này đạt. Driver mới giới hạn 10 phút, khởi động debug process mới và thu log chẩn đoán đã che dữ liệu nhạy cảm. Cần chạy lại CI sau thay đổi driver.

## Việc kế tiếp

1. Xử lý mọi lỗi còn lại của cổng giai đoạn 5, cập nhật bằng chứng theo đúng commit.
2. Hoàn thiện giai đoạn 6: personality/dialogue editor, expression mapping, placement an toàn, low-resource và đo tài nguyên. Hiện Mầm mới có bản tĩnh cùng thư viện PNG/WebP, ba tính cách và cooldown.
3. Giai đoạn 7: animation/package import an toàn và cửa sổ Companion nổi Windows.
4. Giai đoạn 8: kiểm chứng kỹ thuật và giấy phép Live2D; không gọi ảnh tĩnh là Live2D hoặc bật tính năng khi chưa qua cổng.
5. Giai đoạn 9: sao lưu/khôi phục có mật khẩu, tối ưu, kiểm thử cuối và đóng gói. Firebase production, khóa ký phát hành và nghiệm thu phần cứng thật chưa có.

## Chạy kiểm tra

Từ `apps/daymind`: `flutter analyze`, `flutter test`. Bộ Emulator là package riêng ở `emulator_test/`; chạy `flutter pub get --enforce-lockfile` ở đó trước khi dùng `firebase/npm run test:emulator`. CI native còn chạy kiểm tra receiver thực thi thật, Android Emulator và Windows process/integration.

Mã nguồn chạy được và kiểm thử tự động không thay thế nghiệm thu Android OEM/Doze/reboot hoặc Windows 10/11 trên phần cứng người dùng. Chưa có Firebase production; không gửi khóa dịch vụ hoặc mật khẩu thật vào chat/repository.
