# Kiểm thử lại DayMind Web — 08/11/2026

## Phạm vi

Rà soát source và kiểm thử lại core SQLite, snapshot IndexedDB, DOM, thao tác bất đồng bộ, điều hướng và ranh giới ngày địa phương. Không mở thêm giai đoạn tính năng.

## Lỗi tái hiện và sửa

Sáu ca đầu tiên đã thất bại trên bản trước khi sửa (1 ca kiểm tra chặn lưu trữ đã đạt):

1. Sắp tới bỏ sót công việc chỉ có lịch bắt đầu; thứ tự không theo mốc sắp tới gần nhất.
2. Tìm kiếm toàn cục giữ bộ lọc danh mục/ưu tiên cũ nên thiếu kết quả, route không khớp.
3. Ghi IndexedDB thất bại nhưng thanh trạng thái vẫn báo đã lưu.
4. Render mỗi phút làm mất focus bàn phím trên dòng công việc.
5. Hoàn thành lần lưu cũ có thể tác động biểu mẫu mới; nút lưu của biểu mẫu mới có thể còn bị khóa.
6. Nút xóa trong chi tiết cũ không kiểm tra revision nên có thể xóa nội dung vừa được tab khác cập nhật.

Đã kiểm tra thêm: giữ bản nháp ô thêm nhanh, giữ lựa chọn trang sau điều hướng khi đang lưu, session biểu mẫu danh mục, focus danh mục, lỗi đọc snapshot, lỗi BroadcastChannel sau commit, chặn submit lặp, ranh giới qua nửa đêm.

## Lệnh và kết quả thực tế

| Lệnh | Kết quả |
|---|---|
| `TZ=Asia/Ho_Chi_Minh npm test` | 30 tests, 30 pass, 0 fail, 0 skip |
| `TZ=UTC node --test tests/regression.test.js` | 15 tests, 15 pass, 0 fail, 0 skip |
| `TZ=America/New_York node --test tests/regression.test.js` | 15 tests, 15 pass, 0 fail, 0 skip |
| `npm run check` | PASS: manifest, metadata, DOM IDs, tài nguyên local, cú pháp module, WASM |
| `git diff --check` | PASS |

Node 24.22.1; jsdom 31.0.0; fake-indexeddb 6.2.5; SQLite WASM thực. DOM tests chạy bằng jsdom, không phải trình duyệt thật. Transaction IndexedDB được mô phỏng để chủ động tạo lỗi dung lượng và trì hoãn thao tác; không đo độ bền phần cứng.

## Giới hạn còn lại

`SITES_MANAGED_LINUX_CONTAINER=1`, không có tool `cua_repl.js`. Sites SKILL.md chỉ thị: “If `cua_repl.js` is unavailable, skip browser QA: do not start a preview server, install a browser, or improvise another browser-control path.” Vì vậy chưa xác minh render Chrome/Edge, kích thước mobile, bàn phím ảo, Tab/focus bằng trình duyệt thật hoặc offline cold start. Các mục kiểm tra đó vẫn ở `QA.md`.

Không xác nhận Android/Windows native hoặc thông báo khi app đóng. Không đổi schema, không xóa hay reset dữ liệu người dùng.
