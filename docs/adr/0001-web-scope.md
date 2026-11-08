# ADR 0001 — Website Sites theo yêu cầu chuyển hướng

Người dùng yêu cầu mới: tạo website bằng Sites, trong ngữ cảnh DayMind SMART. Giữ cùng sản phẩm, thay mục tiêu bàn giao hiện tại từ native Flutter sang website riêng tư. Bản thử native tạm dừng; không đánh dấu giai đoạn 0 native đã đạt.

Bản web triển khai core local task management: JavaScript modules, SQLite WASM (sql.js 1.15.2) và snapshot IndexedDB. Đây là thích nghi cho mục tiêu web vừa được yêu cầu, không thay thế Flutter cho sản phẩm Android/Windows trong tương lai. Không có tài khoản hoặc upload dữ liệu công việc.

Dùng static hosting do script Vinext/site-workflow không có trong môi trường. Vẫn giữ manifest chính thức, một Site ID, source Git và archive chứa đúng output. Không chạy trình duyệt thay thế khi thiếu cua_repl.js, theo Sites skill.

Revision CAS cho mỗi snapshot chặn ghi đè giữa tab; expected task revision chặn form mở lâu ghi đè văn bản mới hơn. Khi lỗi ghi lưu, phục hồi snapshot trước đó và hiển thị lỗi. Chưa có đồng bộ đa thiết bị; không tuyên bố những bảo đảm của Firebase.

Múi giờ là múi giờ hệ thống trình duyệt (Intl), UTC instants trong SQLite. Không implement recurrence nên chưa chốt ngày 31 hoặc DST. scheduledEndAt > dueAt chỉ cảnh báo; start > end bị từ chối. Không có nhắc việc, digest, âm thanh hoặc request quyền thông báo tự động.

Giai đoạn 2 chỉ bắt đầu sau khi kiểm thử trình duyệt của bản web và các quyết định nền tảng được giải quyết. Thông báo khi trang đóng trên web có ràng buộc khác native và phải có POC riêng.
