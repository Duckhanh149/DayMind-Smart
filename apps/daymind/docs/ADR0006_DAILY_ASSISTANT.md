# ADR0006 — Trợ lý hằng ngày, thống kê và digest

Giai đoạn 3 đã đạt CI 42608475322 trước khi triển khai phần này. Không đưa LLM hoặc dịch vụ AI bên ngoài vào gợi ý.

| Chỉ số | Cách tính |
| --- | --- |
| Đã hoàn thành trong kỳ | Trạng thái hiện tại completed và completedAt trong khoảng ngày địa phương. |
| Hoàn thành việc có hạn trong kỳ | Số completed trong cohort có deadline thuộc kỳ / tất cả việc có deadline thuộc kỳ. Không có hạn không thuộc mẫu số. |
| Đúng hạn khi hoàn thành | Completed trong kỳ, có deadline và completedAt <= dueAt / completed trong kỳ có deadline. |
| Đang quá hạn | DueAt < now, chưa terminal/xóa, trên mọi ngày; không phải số lịch sử trong kỳ. |
| Nhịp ngày/danh mục | Đếm completedAt thật, không sinh trend hoặc tỷ lệ khi mẫu số trống. |

Loại cancelled/deleted/skipped. Recurrence root được thay bằng occurrence; mỗi lần tính riêng. Mở lại việc cập nhật thống kê hiện trạng; không khẳng định đây là audit lịch sử bất biến. Fixture gốc có 3 completions (1 không hạn), 4 việc có hạn trong kỳ (2 completed), 2 completions có hạn (1 on-time): cả hai tỷ lệ 50%; 1 overdue hiện tại. Xem `test/daily_assistant_test.dart`.

Gợi ý tối đa ba series khác nhau, ưu tiên overdue, hạn/lịch hôm nay, priority và in-progress; tie-break ổn định, bỏ việc quá xa. Không tự đổi giờ, trạng thái, deadline hay phát thêm nhắc. Thẻ dashboard lưu riêng trong SQLite; cho phép ẩn tất cả thẻ mà CRUD vẫn hoạt động. Mầm vẫn ở trước gợi ý trên điện thoại.

Digest mặc định off; khi bật, gợi ý 07:00 giờ thiết bị. Event key SHA256(owner + civil date), không chứa giờ/revision nên đổi giờ/restart/cấp quyền không tạo lần thứ hai sau attempt. Quiet chỉ dời trong cùng ngày; khác ngày thì suppress. Không tạo/replay ngày quá khứ. Ba slot là rolling window: Android mở rộng trong alarm/recovery; Windows live engine tự replan khi đổi ngày trong vòng polling, không cần mở lại cửa sổ. Đọc số liệu fresh SQLite khi hiển thị, không dùng count snapshot từ lúc đặt lịch.

Digest có nhóm riêng, không làm tăng số "công việc cần nhắc", không có Done/Snooze. Dismiss chỉ tác động đúng loại nhóm. Native guard đối chiếu owner/ngày/giờ hiện hành để chặn lịch cũ ngay cả trước reconciliation. Thay setting trong lúc refresh được xếp replan kế tiếp. Windows nhóm từ các event unknown còn hợp lệ trong cửa sổ gộp, giữ việc high-priority đến trước.

Native cases bổ sung: fresh counts/parent filtering/end-only, nhóm/dismiss riêng, chặn forged Done/Snooze, rolling plan/once per date, DST gap/first fold, stale date và stale time. Android device smoke chỉ dùng debug receiver, không có trong release APK. Không thay thế nghiệm thu OEM/Doze hoặc máy Windows 10/11 thật.
