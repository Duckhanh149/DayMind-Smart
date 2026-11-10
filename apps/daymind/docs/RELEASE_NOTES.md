# Preview 0.6.0 — giai đoạn7 qua cổng tự động

- Nhập GIF/WebP động và ZIP DayMind chứa sprite/manifest; xem trước, tiến độ/hủy và xác nhận quyền sử dụng.
- Atlas tối đa120 khung,128px/khung; nguồn giữ nguyên byte/checksum. Không tải ảnh lên cloud.
- Hoạt ảnh dừng và nhả texture khi cuộn khuất, bị hộp thoại che, thu khay hoặc ra nền. Low-resource/giảm chuyển động dùng ảnh tĩnh.
- Windows có Companion nổi tùy chọn, mặc định tắt; kéo/resize, khôi phục vị trí, topmost/click-through tường minh. Cùng tiến trình, không thêm Flutter engine hoặc lịch nhắc.
- Cửa sổ nổi tự ẩn khi fullscreen, giờ yên lặng và các trạng thái công khai của Windows notification API. Cần nghiệm thu Focus Assist/DND trên Windows10/11 thật.

Sourcee993033 đã đạt native CI42757179906; xem BUILD_STATUS.md/qa/PHASE7_* cho kiểm chứng và số đo. Live2D tắt; production Firebase, ký phát hành, backup và nghiệm thu thiết bị còn ở các cổng sau. Xem BUILD_STATUS.md cho commit/CI cụ thể. Android vẫn dùng chứng thư debug của preview; không coi là đường nâng cấp sản xuất.

# Preview 0.5.0 — giai đoạn6 qua cổng tự động

- Đổi tên/tính cách, sửa lời thoại theo sự kiện, xem trước và ánh xạ bốn biểu cảm.
- Vị trí/kích thước an toàn, chế độ ít tài nguyên và ảnh biểu cảm lưu riêng trên từng máy.
- Xem trước PNG/WebP trước khi nhập; giới hạn thư viện và chặn liên kết/tệp không hợp lệ.
- Hồ sơ đồng bộ qua Emulator với phát hiện xung đột; ảnh không tự tải lên. Các máy cần bản0.5.0 để đồng bộ kiểu hồ sơ mới.
- Ảnh hiển thị được thu nhỏ và cache riêng; giữ nguyên nguồn, tải thư viện theo vùng nhìn thấy, tính cả cache vào quota32MiB.
- Lời chào khởi động dùng múi giờ/giờ yên lặng thực tế.
- Gợi ý quá hạn không lặp khi restart cùng ngày; Companion tắt vẫn nhận nhắc trong ứng dụng.

Chưa có animation/floating Windows hoặc Live2D. Chưa phải bản phát hành sản xuất; xem BUILD_STATUS.md trước khi dùng artifact.

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
