# ADR 0002 — Tiếp tục sản phẩm native theo yêu cầu mới

Người dùng yêu cầu tự thiết kế UI, làm app dùng được trên điện thoại và Windows 10/11, đồng thời hỏi rõ phần nhân vật ảo. Tiếp tục Flutter dùng chung như master spec; thêm bản quản lý công việc local-first và Companion tĩnh được yêu cầu. Website cũ được giữ riêng, không thay Flutter bằng WebView/PWA.

Lõi công việc được xây và kiểm thử trước phần Companion. Đánh dấu riêng khả năng build, widget tests, native integration tests và device acceptance; không xem compilation là bằng chứng thông báo khi app đóng. Những cổng POC chưa có thiết bị không tự được đánh dấu đạt. Đây là bản app đầu tiên có phạm vi cụ thể, không tuyên bố hoàn tất các giai đoạn 0–9.

Dùng Riverpod và GoRouter, domain không nhập Flutter/Firebase/plugin. Typed persistence qua Drift/SQLite. Loại các dependency Firebase/thông báo chưa dùng khỏi native app để không tạo cấu hình hoặc quyền giả. Dữ liệu web/native độc lập cho tới khi triển khai export/import hoặc sync có lựa chọn rõ ràng.

Companion tĩnh là Mầm gốc, không liên quan ChatGPT Pets. Tính cách độc lập với ảnh; các lời thoại theo event nằm trong app, có cooldown, không scheduler riêng, không âm thanh. PNG/WebP tĩnh được validate và cài vào thư mục riêng; không cài code hoặc ZIP. Live2D giữ tắt cho tới khi có POC Android/Windows và giấy phép.

Một biểu mẫu sống trong một widget State; Future chỉ đóng biểu mẫu nếu State còn mounted. Giao dịch SQLite và revision ngăn mất nội dung do biểu mẫu cũ. Cấu hình được cập nhật bằng hàm áp dụng trên state mới nhất trong hàng đợi, tránh ghi đè trường khác khi thao tác nhanh.

Giao diện tự điều chỉnh: nav dưới trên điện thoại, sidebar từ 1000 px. Companion nằm trong một card dành riêng; biểu mẫu Dialog có vùng cuộn và nút lưu an toàn khi bàn phím mở. Không bật overlay hệ điều hành hoặc always-on-top.
