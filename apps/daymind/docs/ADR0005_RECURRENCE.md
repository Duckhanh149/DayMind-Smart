# ADR0005 — Lịch lặp và trạng thái từng lần

- Rule lưu ngày dân sự, múi giờ IANA, khoảng lặp, weekday/count/until và policy tháng thiếu ngày tường minh. UTC được tính khi tạo occurrence; thay múi giờ hiển thị không đổi giờ của chuỗi.
- DST fold chọn instant đầu; gap chuyển tới phút hợp lệ kế tiếp trong ba giờ; ngày bị bỏ hoàn toàn được ghi skipped. Lịch thực hiện giữ thời lượng thực, deadline dịch theo giờ địa phương riêng.
- Occurrence có ID SHA256(taskId + civil date), snapshot/revision/status và override từng field. Một chuỗi tối đa một occurrence mỗi ngày. Không tạo vô hạn: mặc định -35/+90 ngày; mở tháng khác sẽ materialize khoảng xem và giữ lịch sử đã có.
- Một lần sửa snapshot; từ lần này cắt rule cũ và thêm segment giữ cadence anchor; toàn chuỗi sửa template từng segment. Completed/cancelled/skipped history giữ nguyên. Ngoại lệ và explicit deletion được giữ qua split; row hết cadence là retired, không làm đầy thùng rác. Xóa toàn chuỗi soft-delete root, khôi phục không mất history.
- Reminder event dùng root task revision + occurrence revision. Mode/rule inheritance: occurrence → segment → root → default. Nhắc tuyệt đối chỉ được đặt cho một lần; chuỗi dùng offset tương đối. Notification Center và native Done nhắm occurrence, không hoàn thành root.
- Lưu thay đổi template và materialize trong cùng transaction của controller trước khi Android receiver có thể đọc phiên bản mới. Stale form và fresh SQLite guards tránh sửa/nhắc từ snapshot cũ.
- 13 domain + 9 integration + 2 UI recurrence cases bổ sung trên regression giai đoạn 2. Bốn Android receiver cases mới kiểm tra Done một lần, revision/foreign-owner task, mode off một lần và custom segment inheritance.
