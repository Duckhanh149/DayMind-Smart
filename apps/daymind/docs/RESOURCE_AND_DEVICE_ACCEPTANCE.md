# Đo tài nguyên và nghiệm thu phần cứng

Không dùng Windows Server/Android Emulator để gán PASS cho Windows10/11/OEM thật. Các công cụ bên dưới ghi metadata định trước, không ghi task/title/email/UID/token/đường dẫn cá nhân/serial hoặc tên ứng dụng khác. Không gửi báo cáo tự động. Dùng thư mục xuất do người dùng chọn, kiểm file trước khi chia sẻ.

## Profile native trong CI

CI chạy AOT **profile** qua SDK drive adapter trên Android/Windows, giữ đầy đủ expect assertions. `RUN_RESOURCE_SOAK=true` chỉ ở integration target; app release không tạo fixture hoặc tự đo/upload. Profile mặc định120 giây thời gian thật, có thể đặt DAYMIND_RESOURCE_SOAK_SECONDS từ120–600. Có đo hoạt ảnh120 khung hiển thị thực (kiểm nhiều khung đã vẽ), tạo và đồng bộ ít nhất vài bản ghi synthetic, nhập ba BMP12MiB hợp lệ, capture/encrypt/decrypt backup tổng source hơn36MiB. Kiểm restore nguyên tử/no replay riêng bằng backupProbe, không gọi codec-only thành restore lớn đã nghiệm thu.

ResourceSampler lấy current RSS/lifetime max RSS và CPU tất cả thread bằng clock_gettime(CLOCK_PROCESS_CPUTIME_ID) trên Android/Linux, GetProcessTimes trên Windows. CPU phần trăm tính theo một core, có thể >100%. Peak theo mẫu250ms không phải peak tuyệt đối của từng bước; lifetime max RSS bao gồm cả phần trước profile. Số đo Flutter process không gồm private Android :reminders process. Mọi trường CPU unavailable phải null/false, không giả bằng0; native gate yêu cầu API CPU đọc được. Mỗi stage được in ở RESOURCE_STAGE_POC riêng để không bị Android cắt dòng; summary RESOURCE_SOAK_POC không chứa dữ liệu cá nhân. Không log PID, đường dẫn hoặc dữ liệu fixture.

Profile hoạt ảnh dùng MediaQuery tắt reduced-motion **chỉ bên trong dialog của test** để đo renderer; app người dùng vẫn tôn trọng accessibility/DND/fullscreen. Companion nổi thực có thể bị Windows Server quiet state6 chặn; không gọi đó là đo floating đang render. Component Win32/GDI+ kiểm visible route riêng với controlled notification reader, không thay Focus Assist/DND thật.

Driver dùng deadline có giới hạn: SDK12min/Android outer20min khi soak, default driver5min/outer10min khi không soak. Windows wrapper20min. Nếu thiếu RESOURCE_SOAK_POC hoặc có assertion failure, không coi profiling đạt. Số đo profile trên VM/emulator không phải low-end/physical certification hoặc bản release đã ký.

## Android thật — chỉ thu thập, không đổi cài đặt

Chạy app bằng dữ liệu thử, chọn chế độ battery saver/Doze/DND trên máy. Từ máy có Android platform-tools:

```sh
python tool/android_device_report.py --serial SERIAL --scenario batterySaver --seconds 600 --output android-battery.json
```

Serial chỉ dùng để chọn thiết bị, không ghi vào report. Công cụ đọc API level, battery-saver/deep-idle, PSS/RSS qua dumpsys meminfo và CPU theo cửa sổ thống kê OS. Không force-stop, xóa app, sửa data, bật exact alarm hoặc tự đổi Doze. Android có thể từ chối chỉ số; khi đó ghi null/unknown. CPU OS-window không tương đương CPU interval của native probe. App main/:reminders chỉ được cộng khi OS trả các process đó; không suy diễn khi không có dữ liệu.

Thử quyền thông báo bị từ chối/kênh bị tắt, đóng tiến trình bình thường (khác Force stop), reboot, Doze/OEM battery restrictions, đổi múi giờ, quiet hours/digest/no backlog, foreground/notification actions. Ghi giờ dự kiến/thật và quan sát bằng mắt. Force stop của Android chặn nhắc cho tới khi mở lại; không coi đây là lỗi bộ lên lịch. TalkBack/font200%/document provider/backup lớn cũng cần thực tế. Không chụp task hoặc mật khẩu thật.

## Windows10/11 thật — chỉ thu thập

Chạy trên cả Windows10 build17763+ và Windows11 x64; cùng bản cài/hash đã xác nhận. Thu từng scenario riêng trong PowerShell:

```powershell
./tool/windows_device_report.ps1 -Scenario tray -Seconds 600 -OutputPath windows-tray.json
./tool/windows_device_report.ps1 -Scenario doNotDisturb -Seconds 600 -OutputPath windows-dnd.json
./tool/windows_device_report.ps1 -Scenario afterExit -Seconds 30 -OutputPath windows-exit.json
```

Mở app/thu khay/Thoát hẳn và bật DND/Focus Assist bằng UI hệ điều hành, không dùng registry override giả kết quả. Script ghi OS build, process count, window visible, working set/private bytes, CPU và SHQueryUserNotificationState; không đọc tiêu đề cửa sổ hoặc nội dung notifications. Mã OS5 là accepts notifications;6 quiet time. Public API không đảm bảo bao phủ mọi chế độ DND/banner. Tệp chẩn đoán trong app có ToastNotifier.Setting sau khi bật đồng ý.

Windows hiện **không có nhắc sau khi tiến trình thoát/reboot/đăng xuất**. Close→tray chỉ khi iconReady+trayEnabled thật; khay lỗi/tắt thì close thoát. Không autostart, service hoặc helper nền. Gửi API thành công/history xuất hiện không chứng minh banner đã hiện. CI test đặt defaultTargetPlatform đúng OS thật (FLUTTER_TEST mặc định Android dù runnerWindows); không giả quyền/OSstate. CI tray probe kiểm engine route lúc cửa sổ ẩn và OS history nếu state5; nếu OS chặn, ghi trạng thái và không gọi đó là visible banner PASS.

## Nâng cấp và kết quả

Dùng tài khoản Windows/Android profile thử riêng, tạo fixture task/category/recurrence/completed history/artwork/notification, xuất backup có mật khẩu rồi cài bản cũ→mới. Không gỡ app có dữ liệu để vượt khác chữ ký. Kiểm nguyên dữ liệu/ảnh/hash và nhắc tương lai/no replay. CI Inno đã có gate thật; còn phải chạy Windows10/11 và chuỗi ký production thật. Không tự cài certificate vào Trusted Root để giả trust.

Hai script để notificationVisibility/dataRetention ở not_observed/not_verified: chúng **không tự đánh dấu nghiệm thu đạt**. Ghi kết quả theo mẫu bên dưới, chỉ PASS cho mục đã quan sát:

| Nguồn/hash | OS/build/thiết bị loại chung | Scenario/thời lượng | RAM/CPU | Notification giờ dự kiến/thật | Dữ liệu sau nâng cấp | Kết quả |
| --- | --- | --- | --- | --- | --- | --- |
| Chưa chạy | Android OEM thật | Battery/Doze/reboot | Chưa đo | Chưa quan sát | Chưa kiểm | Chưa chạy |
| Chưa chạy | Windows10 thật | Tray/DND/reboot/upgrade | Chưa đo | Chưa quan sát | Chưa kiểm | Chưa chạy |
| Chưa chạy | Windows11 thật | Tray/DND/reboot/upgrade | Chưa đo | Chưa quan sát | Chưa kiểm | Chưa chạy |

Môi trường hiện tại là Linux, không có thiết bị Android/Windows thật được kết nối. Các dòng trên không được đổi thành PASS từ CI hoặc script thu thập. Xem thêm qa/DEVICE_CHECKLIST.md.
