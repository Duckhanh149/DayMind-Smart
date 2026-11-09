# DayMind SMART — Android & Windows

Ứng dụng Flutter native cho **điện thoại Android ARM64** và **Windows 10 (1809 trở lên)/11 x64**. Không phải vỏ WebView của website. Có quản lý công việc cục bộ, Companion 2D tĩnh, Reminder Engine, lịch ngày/tuần/tháng và công việc lặp lại. Preview 0.3.0 bổ sung trợ lý hằng ngày và thống kê. Dùng được không tài khoản. [Tiến độ từng giai đoạn](docs/PHASE_STATUS.md) ghi rõ phần chưa hoàn thành.

## Đã triển khai

- UI tiếng Việt do DayMind thiết kế: nền dịu, xanh lá trầm, font Be Vietnam Pro. Điện thoại dùng điều hướng dưới; desktop có sidebar; sáng/tối/theo hệ thống.
- Công việc: tạo/sửa, mô tả, 3 mức ưu tiên, 4 trạng thái, danh mục, Inbox, tìm kiếm, quá hạn, Sắp tới, xóa mềm/khôi phục. Hạn không bắt buộc; lịch bắt đầu/kết thúc tách riêng.
- Drift/SQLite có transaction và migration v1/2→v3; revision chặn sửa/xóa từ biểu mẫu cũ. Mở lại app vẫn có dữ liệu.
- Companion **Mầm** là nhân vật gốc, mặc định im lặng; 3 tính cách, lời thoại trong app có cooldown, bật/tắt, kích thước tùy chỉnh. Companion nằm trong vùng riêng, không nổi trên các nút hay biểu mẫu.
- Nhập/thư viện/chọn/xóa ảnh PNG/WebP tĩnh. Kiểm tra magic bytes, decode thật, tối đa 4 MB/tệp, 2048×2048 px, decode vừa trong 256×256, tổng thư viện 32 MB; tên hash, ghi nguyên tử và chặn đường dẫn vượt thư mục. Không nhận ZIP, GIF hoặc Live2D.
- Nhắc việc: một nhắc theo ưu tiên hoặc tối đa 8 mốc tự đặt; xem giờ hiệu lực, giờ yên lặng, gộp, snooze, dismiss, hủy lịch cũ khi sửa/hoàn thành. Trung tâm thông báo có tất cả/chưa đọc/quá hạn. Không xin quyền tự động. Android có receiver và lịch inexact có guard; Windows đóng cửa sổ thu vào khay theo lựa chọn của người dùng để tiếp tục nhắc, có Mở/Thoát hẳn; phần native khay đã qua kiểm thử CI. Không tự khởi động cùng Windows.
- Lịch ngày/tuần/tháng với múi giờ hiển thị; daily/weekly/monthly, khoảng lặp, thứ, số lần/ngày kết thúc, chọn rõ bỏ qua hay dùng cuối tháng thiếu ngày. Sửa một/từ lần này/toàn chuỗi, giữ lịch sử và ngoại lệ.
- Trợ lý hằng ngày: tối đa ba gợi ý có lý do, không lặp nhiều lần của cùng chuỗi; tùy chỉnh các thẻ trang Hôm nay. Thống kê 7/30 ngày dùng ngày hoàn thành thật, hiển thị mẫu số và loại việc hủy/thùng rác.
- Bản tóm tắt **mặc định tắt**, giờ gợi ý 07:00; một bản mỗi ngày địa phương khi bật. Đọc số liệu mới khi phát, không có nút hoàn thành/hoãn công việc. Đổi giờ/quyền không phát lại bản đã xử lý. Cần CI native của bản 0.3.0 để chốt phần mới.
- Android tắt automatic app backup; không tự tải công việc/ảnh lên cloud. Firebase Emulator POC ở `firebase/` đã đạt local/CI; chưa có account/sync trong ứng dụng.

## Chạy và build

SDK kiểm chứng: Flutter **3.47.9**, Dart **3.13.7**; Flutter commit `c197ca5199e9ee5661e865596c9c07294dfab51c`. Giữ `pubspec.lock`. Cần **JDK 21 đầy đủ**, Android SDK/NDK và Android licenses để build APK. Windows cần Visual Studio Desktop development with C++ và Windows SDK.

Chạy trong thư mục này:

```sh
flutter pub get --enforce-lockfile
python tool/precache_sqlite.py  # Khi đường download GitHub release bị HTTP504
flutter analyze
flutter test
flutter run -d <device-id>
flutter build apk --debug --target-platform android-arm64
```

Trên Windows:

```powershell
flutter build windows --release
flutter test integration_test/app_smoke_test.dart -d windows
```

`.github/workflows/native-build.yml` build/test trên Linux và Windows, xuất APK, bộ ứng dụng Windows kèm runtime VC++ và bộ cài Inno Setup. Bản cài đã kiểm chứng hiện ở [Actions run 42560998276](https://github.com/Duckhanh149/DayMind-Smart/actions/runs/42560998276): tải artifact Android hoặc Windows và giải nén. [PR #1](https://github.com/Duckhanh149/DayMind-Smart/pull/1) chờ chấp thuận hợp nhất; sau khi merge, workflow sẽ tạo **Releases → DayMind SMART 0.1.0 Preview** cùng SHA256SUMS khi cả hai nền tảng đạt. Chưa có GitHub Release ở thời điểm báo cáo này. Build thành công không thay thế kiểm thử thiết bị thật.

APK phân phối ở mục Releases được build tối ưu ARM64 nhưng vẫn ký bằng khóa phát triển cho bản preview; lệnh debug bên trên dành cho phát triển. Bộ cài Windows chưa ký mã phát hành. Chưa có bản iPhone/iOS, Windows ARM64, Play Store hoặc Microsoft Store. Không cần quyền báo thức chính xác, overlay hoặc chạy lúc khởi động. Quyền thông báo Android chỉ hỏi khi bạn chọn trong cài đặt; từ chối vẫn quản lý công việc bình thường.

## UI đã render bằng Flutter test

Đây là ảnh renderer Flutter headless, không phải screenshot thiết bị Android hoặc Windows thật. Dữ liệu trong ảnh chỉ là fixture của kiểm thử, không được tạo tự động khi người dùng mở app.

![Điện thoại](docs/ui/phone.png)
![Desktop](docs/ui/desktop.png)
![Companion](docs/ui/companion.png)
![Trung tâm thông báo](docs/ui/notifications.png)
![Lịch](docs/ui/calendar.png)
![Thống kê](docs/ui/analytics.png)

## Kiểm chứng và phạm vi còn lại

`flutter analyze`: không có lỗi/cảnh báo. `flutter test`: **104 kiểm thử đạt local**: domain, SQLite, migration, restart, conflict, safe import, cấu hình đồng thời, bố cục 390/360/768/1440 px, chữ 200%, bàn phím và CRUD UI.

Giai đoạn 2 đã đạt kiểm thử native; giai đoạn 3 đạt [CI 42608475322](https://github.com/Duckhanh149/DayMind-Smart/actions/runs/42608475322) với 82 Flutter tests, 16 receiver tests, Android cold-process smoke và Windows SQLite recurrence/tray/installer. Giai đoạn 4 hiện đạt 104 tests/analyze local; 23 receiver tests và smoke digest mới chờ CI. Đồng bộ trong app, hoạt ảnh, cửa sổ Companion nổi và Live2D chưa hoàn thành. Dữ liệu native và website hiện tách biệt. Chưa có backup/restore bằng mật khẩu.

Cổng nghiệm thu Android thiết bị thật, Windows 10/11 thực tế và thông báo OEM/Doze/reboot thật vẫn phải xác minh; không tuyên bố đã đạt chỉ từ widget tests hoặc compilation. Trạng thái build cụ thể xem `docs/BUILD_STATUS.md` và kết quả Actions. Các giai đoạn tính năng tiếp theo giữ theo master spec, không đánh dấu toàn bộ dự án đã hoàn tất.
