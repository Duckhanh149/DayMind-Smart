# Điểm tiếp tục DayMind — 12/11/2026 UTC

## Bản sửa 0.7.1 — lỗi người dùng báo ngày 12/11/2026

Windows dacd03b/43222966273 đã đạt231 tests+2skip/component100/backup/tray/install-upgrade0.7.1. Khi kiểm ZIP13947541498 phát hiện metadata Inno vẫn0.7.0 dù EXE0.7.1; không phát gói đó như bản đã kiểm đầy đủ. Sửa Inno lấy ProductVersion/VersionNumbers từ EXE, bổ sung kiểm registry DisplayVersion sau nâng/cài lại. Cần native nguồn Windows installer mới. Android dacd03b còn kiểm cold-process.

Nguồn đang kiểm: dacd03b3df3fa28d081ed74c3ed01f09cd07a06e; Native43222966273 đang chạy; Emulator43222966423/job131198918278 SUCCESS trên đúng nguồn mới. Workspace đã khớp remote, PR#1 mở. Phần sửa lock5files đã publish; không cần làm lại hoặc bật automation.

Local đã đạt full230 Flutter tests, thêm2 ca ảnh lớn/restore và1 ca UI cutout (4/4 UI), analyze sạch,25 Python guards. CI nguồnf7fc156 (Native43222438614/Emulator43222438592) dừng trước tests vì path dependency Emulator lock còn0.7.0+8. Đã sửa lock thành0.7.1+9, không nâng package khác; cập nhật About/diagnostics0.7.1. Cần CI nguồn kế tiếp. Đang kiểm chứng lại nguồn mới; kết quả0.7.0 bên dưới là bằng chứng lịch sử, không thay cho native CI của0.7.1. Không phát hành chính thức hoặc bật lại tác vụ kiểm tra tự động.

- Tái hiện lỗi Windows trả `Asia/Saigon` nhưng timezone/latest rút gọn thiếu alias. Chuyển runtime và backup worker sang latest_all, chuẩn hóa tên thiết bị về Asia/Ho_Chi_Minh; reminder/recurrence đọc được alias đã lưu, không dùng UTC âm thầm cho Việt Nam. Kiểm thử native platform response và giờ09:00→02:00UTC.
- Thêm JPEG (.jpg/.jpeg), BMP không nén24/32bit, preflight kích thước trước codec. Ảnh tối đa16MiB/4096²; GIF/WebP động16MiB/1024²/120frames; ZIP vẫn16MiB và các giới hạn giải nén giữ nguyên. Thư viện64MiB/128mục; atlas/runtime vẫn128px/khung, không tăng engine hoặc lịch nhắc.
- Preview ảnh tĩnh có tùy chọn xóa nền màu phẳng nối với biên rồi cắt viền trong suốt, chạy local/isolate trên ảnh≤256px; xem trước/hoàn tác trước cài. Nền nhiều màu không giả nhận diện chủ thể, báo dùng PNG trong suốt. Không sửa tệp gốc trên máy. Không áp dụng cho hoạt ảnh/Live2D.
- Backup cho phép thư viện64MiB, plaintext tối đa96MiB để chứa base64 và JSON. Bản sao lớn cần đo release/máy yếu; số đo near-limit cũ chỉ cho giới hạn cũ, không chứng minh mức mới.


## Trạng thái hiện tại

**Các cổng phần mềm tự động 0–9 đã đạt; nghiệm thu phát hành chưa hoàn tất.** Giai đoạn8 dùng nhánh raster không Live2D theo fallback của đặc tả. Chưa đánh dấu toàn dự án hoàn thành hoặc tạm dừng tác vụ kiểm tra khi các mục thiết bị thật/ký phát hành còn mở.

Nguồn đã kiểm chứng: `8372826a11389aaaa886b9230eff242b9b8d75d9`, tree `a8f60fff07c2383c8ec8491977091dd0ba82d69b`, **0.7.0+8**. Các thay đổi sau nguồn này chỉ ghi kết quả trong tài liệu; phải so git diff trước khi tái sử dụng bằng chứng. PR [#1](https://github.com/Duckhanh149/DayMind-Smart/pull/1) vẫn mở, chưa merge hoặc tạo Release.

[Native CI43160174675](https://github.com/Duckhanh149/DayMind-Smart/actions/runs/43160174675) đã kết thúc:

- Android job 130989190737 **SUCCESS**:225 Flutter tests, 27 receiver/recovery tests thực thi, 25 Python guards, analyze sạch, build release ARM64. Keystore, notification/digest sau khi cả Flutter và `:reminders` đóng bằng `am kill`, quiet/edit/recovery không replay đều đạt. Adapter chính thức `flutter drive --no-dds` chạy nguyên target/assertions và kết thúc allTestsPassed; không còn host loading failure.
- Android native:PID khác Flutter, năm chu kỳ giữ Dart write transaction đồng thời native recovery, mỗi chu kỳ và sau restore đều `integrity_check` đạt. Backup đúng/sai mật khẩu, copy/owner/atomic/no replay và account/artwork/logout/relogin/deletion đạt.
- Windows job 130989190950 **SUCCESS**:223 Flutter tests+2 symlink guards skip do quyền host (Linux chạy đủ225), 25 Python guards, analyze/build/DPAPI/account/backup đạt. Policy12, component100/0 failure và window15/7/7/7; actual app tôn trọng OS quiet state6. Launch lần hai mở cửa sổ cũ, close→tray/Mở/Thoát, không startup.
- Installer Windows:baseline0.6.1→nâng0.7.0→gỡ→cài lại thực tế đạt, giữ3 task rows/2 artwork files/4 domain records, gồm category/recurrence/completed history/reminder/profile. Runner Server chưa thay cho Windows10/11 phần cứng thật.
- Publish job 130994253356 **SKIPPED** đúng thiết kế; chưa phát hành.

[Emulator43157911425](https://github.com/Duckhanh149/DayMind-Smart/actions/runs/43157911425), job 130982037755/source `70c3331b8e8fb07edfbd5f58f6ef677b393faa04`:**16 ca thật+7 AOT đạt**. Đã so blobs/trees:lib, Android, Windows, Firebase, emulator_test, integration_test và pubspec/lock giống837; thay đổi837 chỉ host adapter/workflow paths/tài liệu. Tree IDs tại [PHASE9_NATIVE_837.json](qa/PHASE9_NATIVE_837.json). Không rerun cùng suite khi chỉ sửa tài liệu.

## Gói preview đã kiểm

Tải từ [CI nguồn 837](https://github.com/Duckhanh149/DayMind-Smart/actions/runs/43160174675). Artifacts có hạn lưu; không thay bằng artifact khác nếu chưa kiểm nguồn/hash.

- [Android artifact13917549464](https://github.com/Duckhanh149/DayMind-Smart/actions/runs/43160174675/artifacts/13917549464):APK SHA256 `fb27f5182d372d01da8d4fb30a0d40c6641e0b25d7e70ee0ab3c065b295ccd5c`. ARM64-only, min24/target36, 0.7.0/code2008, CRC/v2/OFL/Apache notices đạt; không debuggable/DebugReceiver, automatic backup tắt, mọi DB receiver trong private process. Chứng thư **Android Debug preview**, chưa là khóa production ổn định.
- [Windows artifact13918351430](https://github.com/Duckhanh149/DayMind-Smart/actions/runs/43160174675/artifacts/13918351430):installer SHA256 `2b4f9c46ca3bacb8f3414e5a882d602826b652dcee519e9c669d63284a96b510`. CRC/PE/version0.7.0/runtime/OFL/Apache notices đạt, 34 files, không probes/userdata/private signing files. App x64, installer bootstrap x86/payload x64, **chưa ký Authenticode**.

ZIP/EXE/APK bytes và hashes đầy đủ: [PHASE9_PACKAGES_837.json](qa/PHASE9_PACKAGES_837.json). Số đo: [PHASE9_RESOURCES_837.json](qa/PHASE9_RESOURCES_837.json). RSS/latency là debug CI/emulator; Android RSS không gồm private receiver process. Windows backup probe70s gồm UI/sync/poll/KDF/assertions, không phải latency restore thuần. Near-limit AOT codec Linux peak400388KiB chỉ dùng synthetic buffers, không là image-import/native restore hoặc máy yếu: [PHASE9_BACKUP_AOT.json](qa/PHASE9_BACKUP_AOT.json).

## Việc tiếp theo — cần điều kiện bên ngoài

1. Chạy [DEVICE_CHECKLIST](qa/DEVICE_CHECKLIST.md) trên Android ARM64 thật (OEM/Doze/reboot, document provider, TalkBack/font200%, dữ liệu cũ, máy yếu) và cả Windows10/11 x64 (DND/Focus Assist thật, DPI, file dialog, thông báo/khay, cài/nâng/gỡ/cài lại). Chưa có thiết bị này trong môi trường Linux/CI Server. Ghi commit/hash/OS và kết quả đã bỏ thông tin riêng tư; không ghi PASS từ widget tests hoặc controlled component.
2. Chủ ứng dụng cấu hình signing identity ổn định trực tiếp GitHub Actions theo [PRODUCTION_SIGNING](PRODUCTION_SIGNING.md), rồi chạy `signing=production,publish=false`. Chưa có khóa Android/chứng thư Windows production để thực thi. Không hỏi/gửi/công bố giá trị khóa, mật khẩu trong chat/repo; không tự mua chứng thư hoặc chấp nhận hợp đồng. Sau đó kiểm trust/timestamp và nâng từ bản ký cũ trên thiết bị thật. Không gỡ ứng dụng đang dùng để vượt lỗi khác chữ ký.
3. Firebase tiếp tục **Emulator trước** theo lựa chọn người dùng; production chưa cấu hình, không quảng bá cloud production. Không cần khóa thật để dùng Emulator.
4. Live2D **OFF**, không SDK/model hoặc hợp đồng đã chấp nhận. Chỉ bật sau POC Android/Windows và giấy phép SDK/model theo [LIVE2D_GATE](LIVE2D_GATE.md). Nhánh raster đã đạt cổng 8, không tự bật hoặc coi PNG là Live2D.
5. Khi đủ bằng chứng nghiệm thu, cập nhật trạng thái và đề nghị bước phát hành cụ thể. **Không tự merge main/publish**, không tạm dừng kiểm tra như thể đã xong. Lần kiểm tra sau chưa có điều kiện mới thì giữ checkpoint và chờ, không rebuild/retry cùng cổng đã đạt.

## Ràng buộc tiếp tục

Hoàn thiện Android ARM64/Windows10(1809+)/11 x64 tuần tự0–9. Windows close→tray để tiếp tục nhắc, có Mở/Thoát hẳn, autostart mặc định **OFF**. Offline/local không cần tài khoản. Không gửi tin nhắn cho người khác hoặc đưa bí mật vào logs.

Trước thay đổi:đọc WORK_CHECKPOINT/PHASE_STATUS/BUILD_STATUS; kiểm workspace/process/remote/CI mới nhất, không mở thêm worker nếu lượt code còn hoạt động. Giữ mọi thay đổi chưa commit, không hard-reset. Cập nhật `native/flutter-app` bằng expected HEAD/lease; nếu nhánh đổi phải fetch/so trước, không ghi đè. Không merge main. Checkpoint giúp lượt tiếp theo nối tiếp khi môi trường/hạn mức cho phép; không hứa tự chạy ngay khi hết hạn mức.

Workspace `/workspace/work/native-repo/apps/daymind`;`source /workspace/work/env.sh`, Flutter3.47.9/Dart3.13.7 ghim commit c197ca5199e9ee5661e865596c9c07294dfab51c. Cổng cuối đã đạt `flutter analyze`,`flutter test`225,`python3 -m unittest discover -s tool -p 'test_*driver.py'`25 và actionlint. Kiểm port9199/8180/process trước khi mở Emulator mới. Không full-build APK local trên disk8GB; dùng CI nếu thực sự đổi nguồn build.

Không sửa SDK/JIT, bỏ assertion, chấp nhận0tests hoặc retry che failure. Android cold close dùng `am kill` cả hai process, không force-stop giả nhắc nền. Không bỏ private IPC/ACK-after-DB-close/error-handler giữ file lỗi. [ADR0012](adr/0012-android-sqlite-process-isolation.md) ghi barriers và adapter chính thức đã qua native.

## Bằng chứng trước đó

0–6 tại67c4a43/Native42716570760/Emulator42716570825; 7 tạie993033/Native42757179906; 8 raster tại213a820/Native42762621177/Emulator42762620985. Xem PHASE_STATUS và qa/PHASE6_*, PHASE7_*, PHASE8_*.

Failure trung gian9 giữ tại qa/PHASE9_FIRST_NATIVE.json, PHASE9_NATIVE_614.json, PHASE9_NATIVE_70.json và git history; không gọi run đó thành công. Nguồn837 là nguồn đầu tiên giai đoạn 9 đạt sạch hai jobs sau sửa timezone backup, reminder cache, SQLite process isolation và host drive adapter. Không làm lại việc đã qua từ checkpoint cũ.
