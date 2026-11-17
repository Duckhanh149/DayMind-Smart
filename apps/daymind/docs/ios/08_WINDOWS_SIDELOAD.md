# Bản iPhone và cài từ Windows

DayMind-iPhone-unsigned.ipa là bản Release/AOT ARM64 cho iPhone, iOS 15 trở lên. Gói chưa ký và chưa có provisioning profile: không thể cài bằng cách mở link trên Safari. Không phải bản App Store/TestFlight hoặc chứng nhận đã kiểm thử trên iPhone thật.

Không cần sở hữu Mac: macOS GitHub Actions biên dịch; Windows có thể ký/cài cá nhân qua AltServer/AltStore Classic. Khả năng tương thích với phiên bản iOS cụ thể phải được xác nhận khi cài. Chỉ tải công cụ từ https://altstore.io/ và làm theo https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows . Cài các thành phần Apple theo hướng dẫn chính thức, kết nối iPhone, chọn Trust, cài AltStore bằng AltServer, sau đó nhập IPA qua My Apps trong AltStore. Bật Developer Mode khi iOS yêu cầu và tin cậy hồ sơ trong Cài đặt nếu cần. Apple Account chỉ nhập trực tiếp trong công cụ trên máy của anh; không gửi tài khoản, mật khẩu, chứng chỉ hay hồ sơ vào chat/repository.

Apple Account miễn phí thường cần ký lại sau khoảng 7 ngày, có giới hạn ứng dụng và yêu cầu làm mới qua AltServer. TestFlight cần tài khoản Apple Developer trả phí và cấu hình ký/phân phối riêng; dự án chưa có link TestFlight.

Trước khi thay bản đang dùng, xuất và kiểm tra bản sao lưu; không xóa app để thử nâng cấp. Công cụ ký có thể thay Bundle ID/team: phải kiểm tra quyền Keychain và dữ liệu giữ lại trên thiết bị. Sau cài, kiểm tra offline CRUD, lưu/mở lại dữ liệu, Companion, cấp quyền thông báo rồi thử khi nền/khóa màn hình/đóng app, Focus và khởi động lại. Ghi kết quả theo 07_DEVICE_ACCEPTANCE.md; các mục này vẫn PENDING đến khi có bằng chứng trên iPhone thật. Firebase mặc định offline; chưa cấu hình production. Live2D tắt.
