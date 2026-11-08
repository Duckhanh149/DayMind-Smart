# Kiểm chứng thiết bị — chưa thực hiện trên môi trường Linux

Chỉ đánh dấu PASS sau khi ghi thiết bị, OS, commit/source hash, phiên bản build, giờ thực tế và bằng chứng. Screenshot trình duyệt không thay cho Android/Windows.

## Android

1. `flutter doctor -v`, `flutter analyze`, `flutter test`, `flutter build apk --debug`.
2. `flutter devices`; `flutter test integration_test/platform_smoke_test.dart -d <device-id>`.
3. Mở POC, thử SQLite hai lần, đóng/mở lại: bộ đếm tiếp tục tăng.
4. Nhấn thử thông báo, cho phép quyền. Đóng app bình thường, đợi tối thiểu 60 giây và ghi độ trễ thực tế. Inexact có thể chậm; không hứa đúng giây.
5. Từ chối quyền: app vẫn hoạt động, không tự hỏi lại sau restart.
6. Kiểm tra Android 13+, kênh thông báo tắt, tiết kiệm pin, đổi múi giờ, reboot. Phân biệt đóng app và Force stop (Force stop có thể chặn thông báo theo chính sách Android).
7. Nhập PNG/WebP hợp lệ; từ chối file giả/ZIP/ảnh quá lớn; asset tồn tại sau restart. Kiểm tra màn hình nhỏ, bàn phím và font 200%.

## Windows 10/11 + Visual Studio Desktop C++

1. `flutter doctor -v`, `flutter build windows --release`.
2. Kiểm tra SQLite, import, fallback tĩnh và DPI 100/150/200%.
3. Toast: build unpackaged và package MSIX có identity hợp lệ. Nhấn lịch thử 60 giây rồi thoát hoàn toàn app; ghi nhận có/không, độ trễ, activation khi bấm toast, reboot, hủy và truy vấn pending.
4. Không đánh dấu Windows đạt chỉ vì plugin khai báo hỗ trợ. Không dùng API periodic trên Windows.
5. MSIX/signing và background/startup helper chưa bật. Chỉ thiết kế helper sau khi biết hành vi thực tế và lựa chọn của người dùng.

## Firebase

`npm ci` trong firebase/, sau đó `npm run test:emulator`. Chỉ kết nối localhost/emulator. Kiểm thử Flutter integration dùng emulator host qua `--dart-define=EMULATOR_HOST=10.0.2.2` (Android emulator), localhost (Windows), hoặc `adb reverse` trên Android USB. Không gửi secret vào source.

## Cổng nghiệm thu

Giai đoạn 0 cần báo cáo thực tế: SQLite + migration; Android thông báo khi app đóng; Windows build/package/activation; Auth + Firestore emulator; import sandbox; render tĩnh. Thiếu bất kỳ bằng chứng nền tảng nào thì giữ trạng thái BLOCKED và chưa chuyển giai đoạn 1.
