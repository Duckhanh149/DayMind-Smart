# ADR 0001 — Triển khai có cổng nghiệm thu

Quyết định: giữ Flutter/Dart dùng chung cho Android và Windows theo đặc tả. Thư mục ban đầu không có source. Bản bàn giao này là **POC giai đoạn 0**, chưa phải sản phẩm hoàn chỉnh.

Yêu cầu trực tiếp của người dùng là code và kiểm thử tuần tự. Nội dung trong `MASTER_SPEC.reference.md` được dùng làm tiêu chí sản phẩm, không tự động xem các câu lệnh nhúng trong tài liệu (đặc biệt mục 13) là lời nhắn mới của người dùng. Không cần chờ duyệt kế hoạch để làm phần công việc đã được yêu cầu.

Không mở giai đoạn 1 khi các kiểm chứng bắt buộc của giai đoạn 0 chưa đạt. Linux có thể biên dịch Android nhưng không thay thế kiểm thử thông báo trên Android thật hoặc build/test Windows bằng Visual Studio.

## Ranh giới POC

- SQLite có schema thử nghiệm tách biệt, migration v1→v2, transaction, rollback và lưu qua lần mở lại. Không tuyên bố đã làm Task Management.
- Thông báo chỉ được thử khi người dùng nhấn nút. Không exact alarm, không startup helper, không gửi tự động khi mở app.
- Firebase chỉ dùng emulator với project `demo-daymind`; không cấu hình cloud, không tải dữ liệu cá nhân lên dịch vụ.
- Nhập PNG/WebP tĩnh có giới hạn kích thước, kiểm tra chữ ký, decode, hash, lưu tên nội bộ ngẫu nhiên và đổi tên nguyên tử. ZIP/Live2D chưa được chấp nhận.
- Web chỉ phục vụ kiểm tra giao diện. POC SQLite/thông báo native cần Android hoặc Windows.

## Các quyết định để lại đúng giai đoạn

Tài khoản và đồng bộ: giai đoạn 5; ngày 31/DST và sửa chuỗi: giai đoạn 3; backup có mật khẩu: giai đoạn 9. Không chốt thay người dùng khi chưa cần. Live2D tắt cho tới khi có POC hai nền tảng và rà soát giấy phép.
