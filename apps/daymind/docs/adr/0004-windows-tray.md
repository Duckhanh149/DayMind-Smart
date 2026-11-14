# ADR 0004 — Đóng cửa sổ Windows thu vào khay theo lựa chọn người dùng

Người dùng xác nhận: “Thu vào khay hệ thống để tiếp tục nhắc; có nút Thoát hẳn. Khởi động cùng Windows vẫn mặc định tắt.” Lựa chọn này thay đổi mục tiêu Windows ở giai đoạn 2: đóng cửa sổ giữ ứng dụng đang chạy; **Thoát hẳn dừng nhắc**, không hứa OS scheduling khi mọi tiến trình đã thoát.

Native Win32 runner giữ một icon khay, menu Mở DayMind/Thoát hẳn, WM_CLOSE → ẩn nếu icon đã đăng ký. Nếu icon không tạo được, giữ cửa sổ truy cập được và cho phép thoát bình thường. Explorer khởi động lại thì đăng ký lại icon, nếu thất bại mở lại cửa sổ. Không startup registry/task/helper, không always-on-top. Cài đặt có thể tắt hành vi khay; giá trị lưu SQLite. Mặc định bật trên Windows theo yêu cầu trực tiếp này.

Một Flutter engine và một ReminderCoordinator tiếp tục chạy trong khay; không tạo scheduler thứ hai. Window visibility và lifecycle phối hợp để dùng toast khi ở nền, lời nhắc nội bộ khi foreground. Bấm toast mở Notification Center và hiện cửa sổ. Giờ yên lặng, revision, expiration, rate/group và quyền vẫn được kiểm tra. Máy ngủ hoặc OS tắt tiến trình có thể làm mất nhắc; không phát lại hàng loạt khi mở lại.

Kiểm thử mới: Flutter integration gọi WM_CLOSE thật qua channel rồi kiểm tra icon/process/window state và restore. Script PowerShell riêng mở executable release, gửi WM_CLOSE, xác nhận tiến trình còn chạy, gọi lệnh Mở rồi Thoát và xác nhận tiến trình kết thúc; kiểm tra không có startup registration. CI có thể khởi động Explorer trong session test để có tray. Đây vẫn là runner Windows Server, không thay thế kiểm tra Windows 10/11 của người dùng.

Ở commit `5b4af1e` trước phần khay: Windows analyze/53 tests/release/native integration/installer đạt, toast initialization=true; Android bị HTTP504 tải compiler Kotlin. `precache_kotlin.py` dùng đúng JAR release JetBrains và POM Maven, checksum ghim; repository local chỉ cho hai phiên bản compiler cụ thể. Không sửa SDK, TLS hoặc thay phiên bản compiler. Cấu hình Gradle đã được chạy local; bản có khay cần build/test lại trước khi tính đạt.
