# ADR0010 — Giữ Live2D tắt và duy trì adapter raster

Ngày 10/11/2026 UTC. Quyết định phát triển bản không Live2D theo nhánh fallback của MASTER_SPEC.reference.md, giai đoạn8. Cổng bật Live2D **chưa đạt**: chưa có chấp thuận giấy phép áp dụng cho DayMind, model có quyền hoặc POC render model thật trên Android/Windows. Không tải/cài SDK, chấp nhận hợp đồng hoặc gửi yêu cầu tới nhà cung cấp thay người dùng.

Đánh giá nguồn chính thức và các phần chưa chứng minh ở [LIVE2D_GATE.md](../LIVE2D_GATE.md). DayMind nhập model ngoài có thể cần xét diện Expandable Application; không suy ra miễn phí từ doanh thu hay giấy phép wrapper. Core, Components, wrapper và model phải được kiểm tra riêng.

`CompanionRenderer<Frame>` là contract Dart thuần cho chọn biểu cảm, khung hiện tại, thời lượng bước kế, tiến bước và dispose. `AtlasCompanionRenderer` thực thi contract này trong renderer đang dùng thật; host Flutter giữ quyền sở hữu timer/texture/lifecycle, Windows dùng adapter native hiện có. Chưa có adapter Live2D giả hoặc cờ bật từ xa. Việc tích hợp tương lai cần thay đổi mã, kiểm filesystem/model refs, ngân sách tài nguyên và cả hai nền tảng trước phát hành.

Importer từ chối tên model Cubism trực tiếp hoặc bên trong ZIP đã kiểm giới hạn, trước chuẩn hóa/lưu. Lỗi tiếng Việt hướng dẫn dùng ảnh/gói raster, không xóa ảnh cũ. Widget giữ ảnh tĩnh/Mầm khi load renderer thất bại. Regression kiểm thư viện cũ còn nguyên, driver raster tiếp tục chạy và dispose; tests ảnh hỏng/lifecycle được giữ.

Trong QA tìm thấy cooldown lời thoại làm mất lời nhắc foreground: chỉ bỏ thông báo dự phòng nếu **chính cue đó** đã được nhận thành lời thoại và đang nhìn thấy. Không thêm OS notification/scheduler. Motion revision tăng khi nhận lời thoại mới; hai cue cùng biểu cảm có thể chạy lại clip one-shot mà không decode/resend atlas. Reload/sync/cooldown không tự chạy lại. Native component kiểm tile thực, dừng timer cuối clip và replay không gửi bitmap.

Nhánh fallback chỉ qua cổng sau regression local và CI Android/Windows/Emulator của chính source mới; kết quả phase7 không thay thế. Tiếp tục giai đoạn9 khi nhánh này đạt, không ghi “Live2D đã hoàn thành/render thành công”.
