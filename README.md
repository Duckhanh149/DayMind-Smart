# DayMind SMART

Ứng dụng **Android và Windows 10/11** nằm tại [apps/daymind](apps/daymind/README.md). Xem giao diện, Companion Mầm, cách build và trạng thái kiểm chứng trong thư mục đó. Website local-first hiện có được giữ ở root bên dưới.

## DayMind SMART · Web

Website được tạo bằng Sites theo yêu cầu mới nhất. Bản này triển khai **phần quản lý công việc cục bộ của giai đoạn 1 trên web**. Không phải bản Flutter Android/Windows hoàn chỉnh.

## Sử dụng

Thêm công việc bằng nút góc phải hoặc phím `N`; tìm bằng `Ctrl/Cmd + K`. Nhấp tên để sửa; nút tròn hoàn thành/mở lại. Xóa mềm và khôi phục qua Thùng rác. Danh mục có thể thêm bằng dấu `+`. Cài đặt cung cấp bộ dữ liệu mẫu theo lựa chọn, chế độ lưu trữ bền vững và mô tả giới hạn lưu dữ liệu. Không có task giả được tạo tự động.

- Tiếng Việt, giao diện đáp ứng màn hình, giao diện tối, nhãn trợ năng, phím tắt, focus và reduced motion.
- Thời hạn không bắt buộc; mốc bắt đầu/kết thúc tách biệt với hạn.
- SQLite 1.15.2 qua sql.js WASM; schema version 2, migration v1→v2 và transaction.
- Snapshot SQLite lưu bền trong IndexedDB. Giao dịch chỉ báo thành công sau khi IndexedDB commit. Compare-and-set revision chặn ghi đè đồng thời giữa tab; bản sửa chi tiết cũ bị từ chối thay vì âm thầm mất chữ.
- Tên, mô tả được escape khi render, truy vấn có bind parameters. Không upload công việc lên máy chủ.

## Kiểm thử

Node 24: `npm ci --ignore-scripts`, `npm test`, `npm run check`.

`tests/core.test.js`: domain, SQLite, migration, rollback, restart, tombstone, stale revision, category validation, tìm kiếm/lọc, số liệu đếm và giao dịch IndexedDB giữa hai kết nối.

`tests/ui.test.js`: tích hợp DOM bằng jsdom, kiểm tra thêm nhanh không hạn, tạo/sửa và lỗi giờ, hoàn thành/mở lại, xóa/khôi phục, tìm kiếm, danh mục, theme và nội dung có ký tự HTML. **jsdom không phải trình duyệt thật và không đo bố cục/render.**

`tests/regression.test.js`: 15 ca kiểm tra lỗi đã sửa: tìm kiếm toàn cục, lịch bắt đầu trong Sắp tới, ranh giới ngày địa phương, báo lỗi lưu đúng, giữ bản nháp khi đang lưu, focus bàn phím, xung đột khi xóa giữa tab, lỗi kênh thông báo nội bộ và chặn submit lặp. Tổng cộng 30 kiểm thử; báo cáo tại `docs/qa/2026-11-08-regression.md`.

`scripts/check.mjs`: manifest, metadata tiếng Việt, ID DOM, các file/font được tự lưu trong site, cú pháp module và payload WASM.

## Giới hạn và các giai đoạn tiếp

Môi trường chưa cung cấp `cua_repl.js`; theo Sites skill không chạy preview/browser bằng đường thay thế. Chưa xác minh trực quan desktop/mobile, bàn phím ảo hoặc offline cold start. Chưa có service worker; trang đang mở có thể thao tác dữ liệu không cần kết nối, nhưng tải lại khi offline chưa được bảo đảm. Đóng trình duyệt không có lịch thông báo nền.

Xóa dữ liệu trình duyệt, chế độ riêng tư hoặc cơ chế dọn dung lượng có thể mất công việc. Chưa có sao lưu/khôi phục và mã hóa bằng mật khẩu. Tính năng lưu trữ bền vững chỉ được yêu cầu khi người dùng nhấn; trình duyệt quyết định có cấp không.

Các thẻ dashboard là số đếm cục bộ đơn giản, chưa phải module analytics giai đoạn 4. Nhịp độ = việc hoàn thành trong ngày / (việc hoàn thành trong ngày + việc chưa hoàn thành có hạn hoặc lịch bắt đầu hôm nay); loại công việc đã xóa/hủy, không phải on-time rate.

Chưa triển khai các giai đoạn 2–9: Reminder Engine, recurrence/calendar đầy đủ, daily digest, analytics chuyên sâu, Firebase sync, Companion, animation/floating window, Live2D, đóng gói native. Không tự chuyển giai đoạn trước khi kiểm thử và chốt các quyết định liên quan.

## Triển khai

Static source/output trong `dist/`; không cần bundler/build. `.openai/hosting.json` giữ Site ID và `static.directory=dist`. Dependency ứng dụng là file vendor có version và giấy phép trong `dist/vendor/`; jsdom/fake-indexeddb chỉ dùng trong kiểm thử.

Do môi trường không cài các script project-setup/site-workflow của Sites, đã chuẩn bị source tĩnh bằng quy trình Git + tar tương đương định dạng hosting. Không tạo lại Site ID. Không lưu credential trong source hoặc artifact.
