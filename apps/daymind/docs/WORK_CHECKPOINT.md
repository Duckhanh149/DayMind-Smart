# Điểm tiếp tục DayMind — 12/11/2026

## Nguồn hiện tại — bản sửa preview đã sẵn sàng

App0.7.1+9, nguồn66e4ae5d68ac2639619b4da6ca98917111c94607/tree db2c111089172027e9f11fcc9c005f1ec4f4a596. [Native43225672366](https://github.com/Duckhanh149/DayMind-Smart/actions/runs/43225672366) **SUCCESS cả Android và Windows**; publish SKIPPED. PR[#1](https://github.com/Duckhanh149/DayMind-Smart/pull/1) mở, chưa merge/main/Release. Người dùng đã **tắt tác vụ kiểm tra tự động**; không bật lại. Các commit sau nguồn66 chỉ ghi tài liệu kết quả, không thay app.

Đã đọc checkpoint/PHASE_STATUS/BUILD_STATUS và kiểm workspace/remote/CI/process trước sửa; không worker code khác, không bỏ thay đổi local. Phản hồi múi giờ/thông báo và mở rộng2D đã sửa, kiểm thử và tạo gói preview mới. Bước tiếp theo là người dùng cài0.7.1 trên thiết bị thật, kiểm múi giờ Asia/Ho_Chi_Minh, nút thông báo thử và luồng nhập/xóa nền ảnh. Không cần rebuild cùng nguồn nếu chưa có failure hoặc thay đổi mới.

## Các sửa đã thực hiện

- Runtime/backup worker dùng timezone/latest_all; chuẩn hóa Windows Asia/Saigon về Asia/Ho_Chi_Minh. Reminder/recurrence đọc alias cũ. Tái hiện reduced database thiếu alias, kiểm native response và09:00Việt Nam→02:00UTC. Không đổi ngày giờ công việc đã lưu hoặc âm thầm dùngUTC choViệt Nam.
- Nhập trực tiếp JPEG(.jpg/.jpeg), BMP không nén24/32bit ngoài PNG/WebP/GIF/ZIP. Ảnh16MiB, tĩnh4096², động1024²/120khung; thư viện64MiB/128mục. Atlas/render giữ128px/khung, không thêm engine/scheduler. ZIP vẫn16MiB với giới hạn giải nén cũ.
- Nút xóa nền màu phẳng nối với biên/cắt viền cho ảnh tĩnh trong preview; local isolate≤256px, có hoàn tác. Lưu PNG mới khi xác nhận, không sửa tệp nguồn trên máy. Nền phức tạp không có AI segmentation; dùngPNGtrong suốt. Hoạt ảnh/Live2D không đi qua nút này.
- Backup đọc tên ảnh mới/nguồn16MiB/tổng assets64MiB/plaintext96MiB. Format/KDF không đổi. Bản cũ có thể từ chối backup mới lớn hoặc JPEG/BMP; nâng0.7.1 trước restore. Mức96MiB chưa nghiệm thu RAM trên máy yếu; số đo near-limit cũ không áp dụng cho mức mới.
- Lock Emulator path dependency và About/diagnostics đều0.7.1. Installer66 lấy ProductVersion và VersionNumbers từ EXE đã build, không giữ version ghi tay; gate mới kiểm registry DisplayVersion sau nâng/cài lại.

## Kiểm chứng và tải bản0.7.1

Android131208073702:233 Flutter tests, 27 receiver/recovery, Keystore/cold notification+digest/quiet/no replay, PID isolation+5 overlapping integrity cycles, backup/account/artwork và host allTestsPassed đạt. Windows131208073178:231tests+2symlink skip, component100/0 failure, DPAPI/backup/account/tray/launch2/quit/no startup đạt. Baseline0.6.1→0.7.1→uninstall/reinstall giữ3task rows/2artworks/4domain records; **registry DisplayVersion đúng**. Publish131214639652 SKIPPED.

Emulator43222966423/job131198918278/source dacd03b đạt16 ca thật+7AOT. Đã kiểm lib/backend/packages/Android/integration/workflow trees giống66. Báo cáo [USER_FIXES_071_NATIVE.json](qa/USER_FIXES_071_NATIVE.json), [USER_FIXES_071_PACKAGES.json](qa/USER_FIXES_071_PACKAGES.json), [local tests](qa/USER_FIXES_071.json). Local full230 +2large/restore +1newUI (UI4/4 ở200%), analyze sạch, 25Python guards. CI chạy đủ233.

- [Windows ZIP13949435030](https://github.com/Duckhanh149/DayMind-Smart/actions/runs/43225672366/artifacts/13949435030):SHAa9039d3674dd61c39f360a322ef85d6e86df31b04a112fe27568d2a2c8d8a55b. InstallerSHA5dbe0ac6933051ab90696ebbf71809b8a7d77fd75b647e61c5b1262f3d1791ab. Chạy windows-installer/DayMind-Setup.exe hoặc giữ toàn bộ runner/Release choportable.
- [Android ZIP13949065397](https://github.com/Duckhanh149/DayMind-Smart/actions/runs/43225672366/artifacts/13949065397):SHA c8af4cb567aa84dc343a6b568852645077a39e0c6eb8a46707c7dd85871a20d5. APK0.7.1/code2009/min24/target36/ARM64, v2, khôngDebugReceiver, private receivers/OFL/Apache đạt. APK SHA17479d989bd4447e408c89fd451c47c00a6665821f2022454de10df9a08a415e.

Windows CRC/PE/version0.7.1/runtime/OFL/Apache/no probes-userdata-signing keys đạt; installer metadata cũ đã sửa. Android Debug certificate/Windows unsigned làpreview, không phải kýproduction. Các tệp đã tải nằm evidence/fix071-*.zip; đã kiểmSHA theoGitHub. Số đo backup native trongJSON làfixture/debug, chỉ FlutterRSS không gồm processreminders; không chứng minh máy yếu hoặc payload96MiB.

## Lịch sử không làm lại

F7fc156/Native43222438614/Emulator43222438592 dừng trước tests vì path lock còn0.7.0; đã sửa lock/About/diagnostics ởdacd03b. Dacd03b/Native43222966273 đã đạtappnative/Emulator nhưngWindowsZIP13947541498 có metadata installer0.7.0:không dùng gói đó làm bộ cài đã kiểm đầy đủ. Nguồn66 sửa Inno lấyversion từ EXE và kiểmregistry; đã kiểm lại thực tế. Không retry che assertion. Lượt local đầu ENOSPC đã dọn cache tái tạo được và chạy lại full đạt; không xóa dữ liệu người dùng. Các báo cáo PHASE9_*837/0.7.0 là lịch sử.

## Ràng buộc và cổng phát hành

Firebase **Emulator trước**, chưa production. Windows close→tray/Mở/Thoát hẳn, autostart OFF. Live2D OFF, không SDK/model hoặc hợp đồng đã chấp nhận; raster fallback8 theo spec đã đạt. Production signing identity/trust/timestamp/upgrade-chain và nghiệm thu Android OEM/Doze/reboot/máy yếu, Windows10/11 DND/DPI/file dialog thật còn mở. Không gọi preview debug/unsigned là chính thức; không gỡ app đang dùng để vượt khác chữ ký. Không hỏi/gửi/công bố khóa/mật khẩu. Hướng dẫnPRODUCTION_SIGNING/qa/DEVICE_CHECKLIST.

Workspace /workspace/work/native-repo/apps/daymind; source /workspace/work/env.sh, Flutter3.47.9/Dart3.13.7 ghim. Không full APK local trên disk8GB; dùngCI. Kiểm port9199/8180/process trước mởEmulator. Git cập nhật bằng expectedHEAD/lease, fetch/so trước khi soft-reset đồng bộ; không hard-reset hoặc ghi đè thay đổi khác. Không bật automation dù dự án chưa nghiệm thu; người dùng đã hủy tác vụ đó.
