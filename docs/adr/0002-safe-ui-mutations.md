# ADR 0002 — Lưu dữ liệu và biểu mẫu bất đồng bộ

Vòng sửa lỗi ngày 08/11/2026, giữ schema SQLite v2 và dữ liệu hiện hữu.

- Thành công chỉ được hiển thị sau khi IndexedDB commit. Lỗi đọc/ghi báo chưa lưu và giữ nguyên bản nháp; rollback chỉ áp dụng trước khi commit bền vững thành công.
- BroadcastChannel là tín hiệu tải lại giữa tab, không phải điều kiện commit. Lỗi kênh không được làm đảo ngược trạng thái giao dịch đã lưu.
- Mỗi lần mở biểu mẫu có một session mới. Kết quả của thao tác cũ chỉ được đóng hoặc gắn lỗi vào biểu mẫu thuộc session đó. Không phụ thuộc thời điểm phát `dialog.close` event của trình duyệt.
- Lưu nhanh chỉ xóa ô nhập nếu nội dung vẫn bằng nội dung đã gửi. Không chuyển trang nếu người dùng đã điều hướng trong lúc chờ lưu.
- Xóa từ chi tiết kiểm tra revision như sửa. Văn bản vừa cập nhật ở tab khác phải được xem lại trước khi xóa.
- Render định kỳ giữ focus vào công việc/danh mục đang thao tác bằng bàn phím; nếu dòng không còn hiển thị, chuyển đến thao tác khả dụng hoặc tiêu đề danh sách.
- Sắp tới xét cả lịch bắt đầu và hạn, theo ngày địa phương. Không tạo hạn giả cho công việc chỉ có lịch bắt đầu.
- Tìm kiếm toàn cục bỏ các bộ lọc cũ và đồng bộ route `#all`.
