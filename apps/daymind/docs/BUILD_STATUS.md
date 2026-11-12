# Kiểm chứng bản native — 12/11/2026 UTC

## Bản sửa 0.7.1 — lỗi người dùng báo ngày 12/11/2026

Local đã đạt full230 Flutter tests, thêm2 ca ảnh lớn/restore và1 ca UI cutout (4/4 UI), analyze sạch,25 Python guards. CI nguồnf7fc156 (Native43222438614/Emulator43222438592) dừng trước tests vì path dependency Emulator lock còn0.7.0+8. Đã sửa lock thành0.7.1+9, không nâng package khác; cập nhật About/diagnostics0.7.1. Cần CI nguồn kế tiếp. Đang kiểm chứng lại nguồn mới; kết quả0.7.0 bên dưới là bằng chứng lịch sử, không thay cho native CI của0.7.1. Không phát hành chính thức hoặc bật lại tác vụ kiểm tra tự động.

- Tái hiện lỗi Windows trả `Asia/Saigon` nhưng timezone/latest rút gọn thiếu alias. Chuyển runtime và backup worker sang latest_all, chuẩn hóa tên thiết bị về Asia/Ho_Chi_Minh; reminder/recurrence đọc được alias đã lưu, không dùng UTC âm thầm cho Việt Nam. Kiểm thử native platform response và giờ09:00→02:00UTC.
- Thêm JPEG (.jpg/.jpeg), BMP không nén24/32bit, preflight kích thước trước codec. Ảnh tối đa16MiB/4096²; GIF/WebP động16MiB/1024²/120frames; ZIP vẫn16MiB và các giới hạn giải nén giữ nguyên. Thư viện64MiB/128mục; atlas/runtime vẫn128px/khung, không tăng engine hoặc lịch nhắc.
- Preview ảnh tĩnh có tùy chọn xóa nền màu phẳng nối với biên rồi cắt viền trong suốt, chạy local/isolate trên ảnh≤256px; xem trước/hoàn tác trước cài. Nền nhiều màu không giả nhận diện chủ thể, báo dùng PNG trong suốt. Không sửa tệp gốc trên máy. Không áp dụng cho hoạt ảnh/Live2D.
- Backup cho phép thư viện64MiB, plaintext tối đa96MiB để chứa base64 và JSON. Bản sao lớn cần đo release/máy yếu; số đo near-limit cũ chỉ cho giới hạn cũ, không chứng minh mức mới.


**Preview 0.7.0+8 đã qua cổng phần mềm tự động Android/Windows; nghiệm thu phát hành còn mở.** Native tại `apps/daymind`, website root độc lập. Không tự merge/publish.

## Nguồn và kết quả

Nguồn `8372826a11389aaaa886b9230eff242b9b8d75d9`, tree `a8f60fff07c2383c8ec8491977091dd0ba82d69b`.

[Build Android and Windows — run43160174675](https://github.com/Duckhanh149/DayMind-Smart/actions/runs/43160174675):

| Cổng | Kết quả |
| --- | --- |
| Android job 130989190737 | SUCCESS; analyze, 225 Flutter tests, 25 Python guards, 27 receiver/recovery cases, release ARM64. Keystore/cold notification/digest/quiet/no replay, PID isolation+5 overlapping integrity cycles, backup/account/artwork/deletion và host allTestsPassed. |
| Windows job 130989190950 | SUCCESS; analyze, 223 Flutter tests+2 symlink skip do host privilege, 25 Python guards, build/DPAPI, policy12/component100/window probes, backup/account, launch2/tray/Mở/Thoát/no startup. |
| Cài/nâng/gỡ/cài lại Windows | PASS trên runner; 0.6.1→0.7.0 giữ3 task rows/2 artwork files/4 domain records/category/series/completed history/reminder/profile. |
| Publish job 130994253356 | SKIPPED đúng thiết kế; không tạo Release/merge. |
| Firebase Emulator43157911425/job 130982037755 | SUCCESS; 16 ca thật+7 AOT tại70c3331. lib/backend/packages/Android/Windows/integration trees giống837, đã kiểm. |

[Native evidence](qa/PHASE9_NATIVE_837.json), [resource evidence](qa/PHASE9_RESOURCES_837.json). Android dùng adapter SDK chính thức `flutter drive --no-dds` với nguyên app_smoke_test/assertions/markers; không bỏ qua host golden failure của run cũ. SQLite native chạy process `:reminders`, ACK sau recovery/close và không tự xóa DB lỗi; [ADR0012](adr/0012-android-sqlite-process-isolation.md).

HEAD sau837 nếu chỉ đổi tài liệu thì artifacts vẫn ghi nguồn 837; phải so diff/code trees, không gọi đó là build mới. Workflow path filters không build lại tài liệu.

## Tải preview đã kiểm

| Artifact | Cách dùng |
| --- | --- |
| [Android ARM64 ZIP13917549464](https://github.com/Duckhanh149/DayMind-Smart/actions/runs/43160174675/artifacts/13917549464) | Giải nén `app-arm64-v8a-release.apk`; Android7/API24+, ARM64. Version0.7.0/code2008, target36. Cần đăng nhập GitHub để tải artifact. |
| [Windows ZIP13918351430](https://github.com/Duckhanh149/DayMind-Smart/actions/runs/43160174675/artifacts/13918351430) | Giải nén, dùng `windows-installer/DayMind-Setup.exe`; hoặc giữ toàn bộ `windows/x64/runner/Release` rồi chạy `daymind_smart.exe`. Windows10(1809+)/11 x64. |

Theo metadata12/11/2026, GitHub lưu artifacts đến10/02/2027; có thể bị quản trị xóa sớm. Không phải GitHub Release hoặc bản Store.

| Tệp | SHA256 |
| --- | --- |
| Android ZIP | `bc2173f0b2782d9eead7f6e6e54e1c3377bd0fb4a67e345035873eeb94e9d960` |
| APK | `fb27f5182d372d01da8d4fb30a0d40c6641e0b25d7e70ee0ab3c065b295ccd5c` |
| Windows ZIP | `0fb317df3fff831df9d834deaf5c791b1b1aa01732793d1d20d2e11c16eac4b9` |
| Windows app EXE | `b6bb649b06c526eb6497d91af86fdb7bd7bf10c6b280ae124c4347405e0ba836` |
| Windows installer | `2b4f9c46ca3bacb8f3414e5a882d602826b652dcee519e9c669d63284a96b510` |

[PHASE9_PACKAGES_837.json](qa/PHASE9_PACKAGES_837.json) ghi bytes/CRC/metadata/license/cert. Đã tải, kiểm SHA theo digest GitHub. APK ARM64-only/v2/không debuggable/không DebugReceiver/OFL+cryptography Apache; Windows PE x64/runtime/OFL+Apache/không probes-userdata-private signing files đạt. Installer bootstrap x86 mang payload x64.

**Android dùng chứng thư Android Debug preview; Windows app/installer chưa ký.** Không coi đây là production signing hoặc chuỗi nâng cấp ổn định. Không gỡ app đang dùng chỉ để vượt khác chữ ký, không xóa dữ liệu cũ.

## Các mục phát hành chưa đạt

- Android OEM/Doze/reboot và máy yếu thực; Windows10/11 DND/Focus Assist/DPI/installation thực; file dialogs/document providers và accessibility trên thiết bị. [DEVICE_CHECKLIST](qa/DEVICE_CHECKLIST.md).
- Signing identity production, trust/timestamp và nâng cấp từ bản ký cũ trên cả nền tảng. [PRODUCTION_SIGNING](PRODUCTION_SIGNING.md). Chưa có khóa/chứng thư thật; cấu hình trực tiếp Actions, không gửi bí mật qua chat/repo.
- Firebase production chưa cấu hình theo lựa chọn Emulator trước; không quảng bá đồng bộ production.
- Live2D OFF, không SDK/model; raster fallback8 đạt, cổng kỹ thuật/giấy phép để bật Live2D chưa đạt.

[PHASE9_RESOURCES_837.json](qa/PHASE9_RESOURCES_837.json) chỉ đo debug CI/emulator, không chứng minh FPS/latency/RAM release trên máy yếu. Windows app thực nhận quiet state6 và giữ surface/render0; visible behavior kiểm riêng bằng controlled reader/real Win32-GDI+ component. Android RSS chỉ process Flutter. Codec Linux near-limit [PHASE9_BACKUP_AOT.json](qa/PHASE9_BACKUP_AOT.json) dùng synthetic buffers, không là ảnh import/restore native.

## Bằng chứng lịch sử

0–6:67c4a43/Native42716570760/Emulator42716570825. Giai đoạn7:e993033/Native42757179906/qa/PHASE7_*. Giai đoạn8 raster:213a820/Native42762621177/Emulator42762620985/ADR0010.

Run4738d3b/614deadd/70c3331 từng thất bại Android hoặc Windows; PHASE9_FIRST_NATIVE/PHASE9_NATIVE_614/PHASE9_NATIVE_70 giữ kết quả thật. Run837 là nguồn đầu tiên giai đoạn 9 đạt sạch cả hai native jobs. Nhật ký đầy đủ ở git history; [WORK_CHECKPOINT](WORK_CHECKPOINT.md) là điểm tiếp tục.
