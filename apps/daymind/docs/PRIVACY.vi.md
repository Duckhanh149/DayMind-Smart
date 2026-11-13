# Quyền riêng tư DayMind SMART

Ngày10/11/2026. Bản native Android/Windows, chưa có dịch vụ Firebase production.

Ứng dụng dùng được không tài khoản hoặc internet. Công việc, lịch lặp, cấu hình, lịch sử nhắc và nhân vật lưu trong thư mục ứng dụng. Mỗi tài khoản có SQLite/thư viện riêng. Android tắt automatic app backup. Phiên thử nghiệm được bảo vệ bằng Android Keystore hoặc Windows DPAPI; không đưa vào tệp sao lưu.

Đăng nhập/đồng bộ là lựa chọn tường minh qua Firebase Auth/Firestore Emulator. Máy chủ thử nghiệm nhận thông tin đăng nhập thử và bản ghi công việc/hồ sơ đã chọn đồng bộ, không nhận ảnh nhân vật, đường dẫn, vị trí desktop hoặc lịch sử thông báo. Không dùng mật khẩu thật cho Emulator. Chưa kết nối Firebase chính thức. Xóa tài khoản cần xác thực lại; máy chủ giữ dấu UID đã xóa không có email/nội dung để chặn thiết bị cũ tái tải dữ liệu. Export/bản sao lưu do người dùng tạo hoặc tệp ở thiết bị khác không tự bị thu hồi.

Quyền thông báo chỉ được hỏi khi người dùng chọn. Từ chối vẫn quản lý công việc. Windows đóng thu khay để tiếp tục nhắc, có Mở/Thoát hẳn, autostart mặc định tắt. Cửa sổ Companion opt-in; chỉ dùng trạng thái notification OS và hình học cửa sổ để ẩn khi tập trung/toàn màn hình. Không lưu tên ứng dụng, vị trí người dùng, lịch sử hoạt động, micro/camera hoặc âm thanh.

Không quảng cáo/analytics SDK/telemetry tự động. Consent xuất chẩn đoán mặc định tắt và riêng theo không gian. Khi người dùng cho phép và bấm xuất, tệp chỉ gồm phiên bản/nền tảng/build/schema/quyền thông báo/cờ lỗi. Không có task, UID/email/token, ảnh, đường dẫn hoặc thông báo lỗi thô. Người dùng tự quyết định có gửi tệp đó hay không; app không có endpoint tự upload báo lỗi.

Nhập ảnh/gói dùng tệp người dùng có quyền. Kiểm giới hạn trước codec, giữ nguồn nguyên byte trong kho riêng; có thể xóa khỏi thư viện. File picker Android tạo bản cache riêng của lựa chọn; app cố gắng dọn sau dùng và lúc mở lại. Tệp gốc/provider/backup ngoài thư mục app thuộc nơi lưu được chọn, không tự xóa theo tài khoản. Tệp `.daymind` được mã hóa có mật khẩu; người dùng giữ mật khẩu. Nhà cung cấp tệp được chọn trong hộp thoại hệ điều hành có thể là dịch vụ cloud của người dùng.

Live2D không bật, không tự tải SDK/model hoặc chấp nhận hợp đồng. Font và thư viện mã nguồn mở có giấy phép trong mục Thông tin & giấy phép. Các thay đổi trước phân phối production cần cập nhật chính sách theo dịch vụ thực dùng.

Từ0.8.0 mặc định offline, Firebase production phải cấu hình riêng qua HTTPS và tách session/workspace/backup owner với Emulator. Cloud không phải E2EE. Chẩn đoán opt-in có tối đa128 mã enum tương đối trong phiên, quyền/khay/trạng thái OS/số lượng event; không task/title/UID/email/đường dẫn/token/raw exception và không tự upload. Tắt đồng ý xóa trace trong RAM. Công cụ đo test-only không được nhúng vào app release.
