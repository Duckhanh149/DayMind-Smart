# Ảnh giao diện

Các PNG là ảnh Flutter renderer headless, đã nạp font thật và xem lại; không phải ảnh chụp phần cứng Android hoặc Windows.

Ảnh tài khoản giai đoạn 5 trên source `4c8ceb8`:

- [Điện thoại 390 px](account-phone.png)
- [Biểu mẫu sau khi cuộn](account-form.png)
- [Máy tính 1440 px](account-desktop.png)

Form không điền thông tin đăng nhập. Hai ca chụp ảnh đạt; kiểm thử chức năng riêng gồm đăng nhập, cách ly profile và giải quyết xung đột với cỡ chữ 200%. Các ảnh dashboard/lịch/Companion/thông báo còn lại được tạo tại checkpoint của các giai đoạn trước; xem BUILD_STATUS.md cho bằng chứng theo commit.

Giai đoạn6: [editor điện thoại360px](companion-editor-phone.png) và [editor desktop1440px](companion-editor-desktop.png), Flutter renderer với font thật, đã xem lại. Điện thoại cần cuộn biểu mẫu; ảnh thể hiện vùng preview và nút lưu. Bốn ca chức năng kiểm tra cả chữ100/200%, validation, preview không lưu và lưu hồ sơ. Không dùng ảnh này làm bằng chứng renderer phần cứng.
