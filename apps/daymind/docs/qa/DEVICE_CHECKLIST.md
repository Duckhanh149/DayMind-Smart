> Bản0.8.0 đã đạt CI native và kiểm gói; thiết bị thật/Firebase live/kýproduction vẫn chưa nghiệm thu. Xem [ma trận và công cụ thu thập](../RESOURCE_AND_DEVICE_ACCEPTANCE.md). Không suy diễn CI Server/Emulator thành nghiệm thu phần cứng.

# Nghiệm thu thiết bị và bản ký — đang chờ

Các cổng phần mềm tự động 0–9 đã đạt tại nguồn 8372826a; giai đoạn 8 dùng raster fallback, Live2D vẫn tắt. Bằng chứng trong [PHASE_STATUS](../PHASE_STATUS.md) và [PHASE9_NATIVE_837](PHASE9_NATIVE_837.json). CI Windows Server và Android emulator không chứng minh hành vi trên điện thoại OEM, máy yếu hoặc Windows10/11 của người dùng. Các mục bên dưới **chưa chạy trên phần cứng đích**. Chỉ đánh dấu đạt khi thực sự chạy, ghi OS/kiến trúc, phiên bản app/commit, giờ dự kiến/thực tế và bằng chứng đã bỏ thông tin riêng tư. Không ghi mật khẩu, token, tên công việc thật hoặc đường dẫn cá nhân.

Nguồn native: `apps/daymind`, nhánh `native/flutter-app`, PR#1. Lấy đúng artifact/commit được [BUILD_STATUS](../BUILD_STATUS.md) xác nhận; gói preview chưa có chữ ký sản xuất. Không gỡ ứng dụng đang dùng để vượt lỗi khác chữ ký, vì có thể mất dữ liệu. Dùng dữ liệu thử trên thiết bị riêng và sao lưu trước khi thử nâng cấp. Firebase vẫn dùng Emulator theo lựa chọn hiện tại; không cần khóa thật.

## Android ARM64, Android7 trở lên

1. Cài bản được ghi nhận; tạo/sửa việc không hạn và có hạn, danh mục, ưu tiên; khởi động lại app và kiểm tra dữ liệu. Hoàn thành một occurrence rồi sửa một/lần này trở đi/cả chuỗi; lịch sử cũ phải còn.
2. Android13+: từ chối quyền thông báo, đóng/mở lại; CRUD vẫn dùng được, không tự hỏi lại. Bật quyền trong Cài đặt khi muốn; thử cả kênh bị tắt và tiết kiệm pin. Không yêu cầu quyền exact alarm mặc định.
3. Tạo một mốc nhắc tương lai, ghi giờ dự kiến, đưa app về nền và đóng tiến trình bình thường; ghi giờ hiển thị thật. Inexact có thể chậm. Hoàn thành/sửa hạn phải vô hiệu mốc cũ, snooze chỉ tạo một mốc thay thế. Phân biệt đóng app với Force stop của Android.
4. Thử reboot, Doze/OEM battery restrictions và đổi múi giờ trước mốc tương lai. Nhắc hết hạn không phát hàng loạt sau mở lại; quiet22–07 không phát backlog07:00. Digest chỉ khi bật và tối đa một bản/ngày.
5. PNG/WebP/GIF/sprite: nhập, xem trước, xác nhận quyền, đổi biểu cảm, đóng/mở lại. File giả/ảnh quá lớn/ZIP traversal/Live2D phải bị từ chối; ảnh cũ giữ nguyên. Companion tắt không làm mất nhắc, bật không thêm OS alert hoặc âm thanh.
6. Font200%, bàn phím/TalkBack, màn hình nhỏ: nút thêm/lưu, lịch và dialog vẫn dùng được; Companion không che vùng thao tác. Thử giao diện sáng/tối, reduced motion/low-resource và thư viện gần128 mục/atlas120 khung trên máy yếu; ghi RSS/CPU/frame time thực.
7. Sao lưu có mật khẩu ra document provider thật, mở lại và xem preview. Sai mật khẩu/tệp bị sửa phải không đổi dữ liệu. Khôi phục thêm bản sao giữ task/series/history/ảnh cũ, dừng nhắc/digest, không phát lịch cũ; bấm restore lần hai bị chặn. Khác tài khoản không cho restore. Không chụp mật khẩu.
8. Khi có signing identity sản xuất, cài bản ký cũ rồi nâng cấp bản ký mới cùng chứng chỉ, kiểm task/occurrence/ảnh/session và nhắc tương lai. Chưa chạy; xem [PRODUCTION_SIGNING](../PRODUCTION_SIGNING.md). CI APK dùng chứng thư debug không chứng minh đường nâng cấp production.

## Windows10 (build17763 trở lên) và Windows11 x64

1. Chạy trên từng OS thật và DPI100/150/200%; font200%, bàn phím/đọc màn hình, sáng/tối. `Ctrl+N` mở biểu mẫu ngay sau mở app, `Escape` đóng mà không đổi dữ liệu. CRUD, SQLite, lịch và import dùng được khi offline.
2. Đóng cửa sổ phải thu vào khay, còn tiến trình và tiếp tục nhắc. Mở từ menu khay hoặc chạy app lần hai phải mở cửa sổ cũ; không tạo workspace/engine thứ hai. Thoát hẳn phải dừng tiến trình; nhắc sau đó không được đảm bảo. Khởi động cùng Windows mặc định tắt, không tạo startup helper.
3. Chỉ khi người dùng bật Companion nổi: kéo/đổi cỡ/khôi phục màn hình, click-through và always-on-top opt-in. Bật/tắt fullscreen, Focus Assist/DND thật trên cả OS; nhân vật phải tự ẩn theo policy, không chiếm focus, không thêm toast. Không dùng controlled component probe thay kết quả OS thật.
4. Toast im lặng và mốc tương lai khi nền/thu khay: ghi giờ và hành động. Mở toast vào Notification Center, dismiss không hoàn thành, complete/snooze không nhân đôi. Không dùng API periodic; không tuyên bố nhắc khi Thoát hẳn hoặc reboot lúc autostart tắt.
5. Thử file dialog lưu/mở backup thật và các ca restore như Android. Dọn cache không xóa tệp gốc đã chọn. Thư viện/mật khẩu/tài khoản không có trong tệp chẩn đoán; chẩn đoán mặc định tắt, chỉ xuất khi chọn, không tự upload.
6. Cài0.6.1→nâng0.7.0→gỡ→cài lại trên tài khoản Windows thử: task/danh mục/series/occurrence completed/ảnh nguyên byte còn, app đúng phiên bản, khay/launch2/Thoát hoạt động và không startup. CI installer gate là bằng chứng tự động riêng; còn cần Windows10/11 thật.
7. Chữ ký production: kiểm Authenticode trust/timestamp trên cả OS, nâng cấp từ bản ký cũ, không thêm self-signed certificate vào Trusted Root để giả kết quả. Chưa có identity để thực thi.

## Firebase Emulator và cách ghi kết quả

Auth9199/Firestore8180, project`demo-daymind`; xem [hướng dẫn Emulator](../../firebase/README.md). Trên Android USB dùng `adb reverse`/host thử nghiệm theo cấu hình, không mở Emulator ra internet. Thử hai thiết bị cùng tài khoản online/offline, sửa xung đột giữ cả bản, chọn primary, logout/login/xóa. Ảnh không upload; giới hạn duplicate khi hai primary offline phải được mô tả đúng.

Mỗi bản ghi gồm: commit, artifact SHA256, app version, OS/kiến trúc, ngày giờ, số mục đã chạy, PASS/FAIL/chưa chạy, thao tác tái hiện và giới hạn. Ảnh headless trong docs/ui và số đo debug CI chỉ bổ sung, không thay nghiệm thu này. Dự án chưa hoàn tất0–9 khi các cổng phát hành còn mở.
