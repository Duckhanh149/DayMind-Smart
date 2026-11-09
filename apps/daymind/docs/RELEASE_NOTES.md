# DayMind SMART 0.1.0 Preview

Bản app đầu tiên cho điện thoại Android ARM64 (Android 7.0/API 24 trở lên) và máy tính Windows 10/11 x64 (Windows 10 1809 trở lên). Chưa có iPhone/iOS hoặc Windows ARM64.

## Tải và cài

- **DayMind-Android-ARM64.apk**: tải trên điện thoại, mở tệp APK và cho phép trình cài đặt từ nguồn bạn đã chọn khi Android yêu cầu. Đây là APK tối ưu ARM64, ký khóa phát triển cho preview.
- **DayMind-Windows-Setup.exe**: bộ cài theo tài khoản người dùng, không tự bật chạy lúc khởi động. Đi kèm runtime Visual C++ cần thiết; bộ cài chưa ký chứng thư phát hành.
- **DayMind-Windows-Portable.zip**: giải nén toàn bộ rồi chạy daymind_smart.exe. Giữ các DLL và thư mục data cạnh tệp exe.
- **SHA256SUMS.txt**: mã băm các tệp để đối chiếu tính toàn vẹn.

## Có thể sử dụng

Quản lý công việc cục bộ: thêm/sửa, hạn tùy chọn, lịch bắt đầu/kết thúc, ưu tiên, trạng thái, danh mục, Inbox, tìm kiếm, xóa/khôi phục, sáng/tối. Dữ liệu SQLite tồn tại qua lần đóng/mở app.

Companion 2D tĩnh **Mầm** do DayMind thiết kế, ba tính cách, lời thoại nhẹ nhàng trong app, bật/tắt/kích thước; thư viện nhập/chọn/xóa PNG/WebP tĩnh có kiểm tra giới hạn và đường dẫn. Nhân vật không phát âm thanh và không tạo lịch thông báo riêng. Font Be Vietnam Pro đi kèm giấy phép OFL, xem trong phần Thông tin & giấy phép.

## Kiểm chứng và giới hạn

28 kiểm thử tự động, kiểm tra Flutter analyze, build Android/Windows và native integration smoke trên runner Windows. UI được kiểm tra với màn hình nhỏ, desktop, font 200% và bàn phím. Chưa kiểm thử cài và sử dụng trên điện thoại thật hoặc máy Windows 10/11 của người dùng; đây là preview.

Chưa có nhắc việc nền, lịch lặp lại, Firebase/sync, hoạt ảnh, Companion nổi ngoài desktop hoặc Live2D. Dữ liệu mỗi thiết bị hiện độc lập; chưa tự chuyển dữ liệu từ web. Chưa có sao lưu bằng mật khẩu. APK chưa dùng khóa ký phát hành lâu dài; đây chưa phải bản Store hoặc cam kết tương thích cập nhật sản xuất.
