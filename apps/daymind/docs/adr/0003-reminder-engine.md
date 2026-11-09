# ADR 0003 — Nhắc việc có kiểm tra trạng thái khi phát

Ngày: 2026-11-09. Phạm vi: mã giai đoạn 2; chưa vượt cổng thiết bị.

SQLite schema 3 bổ sung `extension_records`, `reminder_events`, `delivery_logs`; migration từ 1/2 giữ nguyên công việc. Event key chứa task/occurrence/rule/instant/revision, platform ID tự tăng, không dùng hash làm ID notification. `unknown` nghĩa là đã thử hiển thị, không xác nhận hệ điều hành đã giao.

Android dùng AlarmManager inexact và receiver native đọc lại SQLite trước khi phát. Kiểm tra task/revision, occurrence khi có, quyền, thiết bị chính và giờ yên lặng; khôi phục sau boot/update/đổi giờ chỉ lên lịch tương lai, tối đa 128. Đánh dấu thử phát trước khi gọi OS; ưu tiên tránh nhắc trùng khi tiến trình ngừng đột ngột. Không exact alarm, không vượt DND, không yêu cầu bỏ tiết kiệm pin. Nhiều nhắc trong một cửa sổ gộp một notification, chỉ lần đầu có thể phát âm thanh. Trong ứng dụng dùng sự kiện nội bộ.

Windows hiện dùng timer có guard khi tiến trình còn chạy, với toast im lặng khi ứng dụng ở nền. Không đăng ký lịch đóng tiến trình vì chưa chứng minh expiration/cancellation/package identity. Giao diện ghi rõ giới hạn; không tự cài helper hoặc startup. Phần này chưa đạt tiêu chí Windows khi thoát hoàn toàn.

Từ chối quyền không chặn CRUD; chỉ yêu cầu khi người dùng chọn, sau từ chối hướng tới Settings. Không phát lại quá hạn khi cấp lại quyền. Một snooze là một replacement, dismiss không hoàn thành task. Task và cấu hình reminder được lưu cùng transaction; lỗi scheduler không làm báo task chưa lưu sau khi dữ liệu đã commit.

Kiểm chứng local: `flutter analyze` không có vấn đề; `flutter test --reporter expanded` **52/52 đạt** (22 kiểm thử clock/SQLite nhắc việc + 2 kiểm thử UI mới, bao gồm 200% chữ). Kiểm thử receiver/recovery Android bằng Robolectric được thêm vào CI, chờ kết quả. Đã thêm manifest quyền thường/thông báo, receivers, desugaring; APK/Windows cần build lại với dependency mới.

Cổng còn mở: Android chạy khi đóng app/Doze/force-stop/reboot trên thiết bị; Windows 10/11 cài đặt và thông báo khi thoát tiến trình. Robolectric và runner CI không thay thế các kết quả này. Các giai đoạn 3–9 chưa được đánh dấu hoàn thành.
