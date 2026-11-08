# Kết quả và cổng nghiệm thu

## Giai đoạn 0: môi trường native đã khảo sát

Linux x86_64, Java 21.0.13, Node 24.22.1. Ban đầu không có source. Đã cài toolchain cục bộ: Flutter stable 3.47.9 (framework c197ca5199), Dart 3.13.7, Android SDK 36/build-tools 36.0.0. Không có Android thật/emulator, `/dev/kvm`, Windows, Visual Studio hoặc MSIX identity. Chưa chạy build native và chưa có bằng chứng thông báo khi app đóng. Phần Flutter được dừng khi người dùng chuyển yêu cầu sang tạo website bằng Sites; scaffold không được đưa vào bản deploy web.

## Phạm vi web đã kiểm thử

- Vòng rà soát 08/11/2026: `TZ=Asia/Ho_Chi_Minh npm test`: **30/30 PASS**, không skip.
- `TZ=UTC node --test tests/regression.test.js` và `TZ=America/New_York node --test tests/regression.test.js`: mỗi lượt **15/15 PASS**.
- `npm run check`: **PASS**; `git diff --check`: **PASS**.
- 6 ca tái hiện mới thất bại trước sửa, đã đạt sau sửa. Chi tiết trong `docs/qa/2026-11-08-regression.md`.
- Không dùng kết quả Node/jsdom để tuyên bố hành vi Android/Windows hoặc render trình duyệt thật.
- Không mở giai đoạn 2 trong bản này.

## Checklist trình duyệt còn cần thực hiện

- Chrome/Edge desktop: thêm/sửa/xóa/khôi phục, tìm kiếm tiếng Việt, filter danh mục/ưu tiên, phím N/Ctrl+K, modal Tab/Escape.
- Android browser 360/390/412px: sidebar, form khi bàn phím mở, datetime input và không tràn ngang.
- Hai tab: sửa đồng thời một task, bảo đảm báo xung đột và không mất nội dung; đóng/mở browser kiểm tra persistence.
- Giao diện sáng/tối, font 200%, contrast, đọc màn hình và reduced motion.
- Chặn IndexedDB hoặc thiếu dung lượng: trạng thái lỗi không báo đã lưu thành công.
- Xác minh hành vi truy cập riêng tư Sites và font/WASM cùng origin.

Tài liệu yêu cầu ban đầu là nguồn tham khảo sản phẩm, không phải một lệnh mới. Các phần native chưa đạt không được đánh dấu hoàn thành vì website được triển khai thành công.
