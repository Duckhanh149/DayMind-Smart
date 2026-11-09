# Kiểm chứng thiết bị — chưa thực hiện trên môi trường Linux

Chỉ đánh dấu PASS sau khi ghi thiết bị, OS, commit/source hash, phiên bản build, giờ thực tế và bằng chứng. Screenshot trình duyệt không thay cho Android/Windows.

## Android

1. `flutter doctor -v`, `flutter analyze`, `flutter test`, `flutter build apk --debug`.
2. `flutter devices`; `flutter test integration_test/app_smoke_test.dart -d <device-id>`.
3. Tạo/sửa công việc không hạn và có hạn; đóng/mở lại: nội dung, trạng thái và danh mục còn nguyên. Xóa mềm/khôi phục và thử biểu mẫu revision cũ.
4. Mở Cài đặt → cho phép thông báo → thông báo thử im lặng. Tạo việc có mốc nhắc tương lai, kiểm tra Notification Center, đưa app về nền rồi đóng tiến trình bằng thao tác bình thường. Ghi giờ dự kiến và giờ hiển thị thực tế. Inexact có thể chậm; không hứa đúng giây.
5. Từ chối quyền: app vẫn hoạt động, không tự hỏi lại sau restart.
6. Kiểm tra Android 13+, kênh thông báo tắt, tiết kiệm pin, đổi múi giờ, reboot. Phân biệt đóng app và Force stop (Force stop có thể chặn thông báo theo chính sách Android).
7. Nhập PNG/WebP hợp lệ; từ chối file giả/ZIP/ảnh quá lớn; asset tồn tại sau restart. Kiểm tra màn hình nhỏ, bàn phím và font 200%.

## Windows 10/11 + Visual Studio Desktop C++

1. `flutter doctor -v`, `flutter build windows --release`.
2. Kiểm tra SQLite, import, fallback tĩnh và DPI 100/150/200%.
3. Toast hiện tại: thử nút im lặng, thử mốc khi ứng dụng ở nền nhưng còn chạy, bấm toast mở Notification Center. Bản hiện tại không hỗ trợ nhắc khi thoát hoàn toàn. POC MSIX/identity, lịch đóng tiến trình/reboot/cancel/pending còn thiếu; không có nút lịch thử 60 giây để suy diễn khả năng đó.
4. Không đánh dấu Windows đạt chỉ vì plugin khai báo hỗ trợ. Không dùng API periodic trên Windows.
5. MSIX/signing và background/startup helper chưa bật. Chỉ thiết kế helper sau khi biết hành vi thực tế và lựa chọn của người dùng.

## Firebase

`npm ci` trong firebase/, sau đó `npm run test:emulator`. Chỉ kết nối localhost/emulator. Kiểm thử Flutter integration dùng emulator host qua `--dart-define=EMULATOR_HOST=10.0.2.2` (Android emulator), localhost (Windows), hoặc `adb reverse` trên Android USB. Không gửi secret vào source.

## Cổng nghiệm thu

Bản ghi POC ban đầu (xem ADR0002/0003 và PHASE_STATUS cho trạng thái mới): SQLite + migration; Android thông báo khi app đóng; Windows build/package/activation; Auth + Firestore emulator; import sandbox; render tĩnh. Các bằng chứng còn thiếu vẫn là cổng nền tảng chưa đạt, dù mã tính năng local đã được bổ sung theo yêu cầu tiếp tục của người dùng. Không đánh dấu sản phẩm đủ 0–9 từ build hoặc emulator POC.

CI Android debug fixture: `tool/android_reminder_smoke.py` cài APK debug x86_64 vào emulator, kiểm tra cold-process bằng dumpsys, revision/quiet guards và recovery không phát lại quá khứ. Debug receiver không nằm trong APK release. Đó không phải kiểm chứng OEM, Doze hoặc reboot vật lý.

## Companion giai đoạn 6

Thử ảnh2048² với thư viện gần128 ảnh trên điện thoại cấu hình thấp và Windows10/11 thật; ghi RSS/CPU/frame time, OS và phiên bản. Đổi ảnh/biểu cảm nhiều lần, bật/tắt low-resource, thu khay/mở lại và kiểm tra cache/ảnh cũ được thu hồi. So sánh lời thoại/cooldown/giờ yên lặng, gợi ý quá hạn sau restart, thẻ40/56/72/80/96/144dp và chữ200%; FAB, bàn phím, dialog/nút lưu vẫn thao tác được. Log CI `COMPANION_RESOURCE_POC` là số đo runner/emulator debug, không phải kết quả thiết bị này.
