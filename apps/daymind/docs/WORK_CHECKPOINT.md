# Điểm tiếp tục DayMind

## Mục tiêu và lựa chọn đã xác nhận

Hoàn thiện Android và Windows 10/11 theo giai đoạn 0–9; kiểm chứng giai đoạn hiện tại trước giai đoạn kế tiếp. Firebase Emulator trước, chưa có production. Windows đóng → khay, Mở/Thoát hẳn; autostart mặc định tắt. Chỉ cập nhật `native/flutter-app` / PR [#1](https://github.com/Duckhanh149/DayMind-Smart/pull/1); không hợp nhất main. Không gửi khóa/mật khẩu vào chat hoặc repository. Live2D giữ tắt cho tới POC hai nền tảng và giấy phép.

Tác vụ “Tiếp tục DayMind” kiểm tra mỗi giờ (Asia/Saigon), nối tiếp khi hạn mức/môi trường cho phép; không bảo đảm chạy ngay khi hết giới hạn. Không khởi chạy thêm lượt code nếu lượt hiện tại còn hoạt động. Giữ mọi thay đổi chưa commit, kiểm tra workspace/process/CI mới nhất trước khi sửa; không hard reset.

## Cổng đã qua: 0–6

Source `67c4a433b76c62a7cdae36b2760a29c5a896a2e1`, tree `02ea0bbd5e224e546ca356faf7496503d71b0c53`; workspace đã soft-reset khớp remote sau khi kiểm tree. Remote b360a34 là checkpoint tài liệu giai đoạn6; code giai đoạn7 đang được lưu tiếp trên nhánh native/flutter-app. Không reset/ghi đè các thay đổi local.

- [Native CI42716570760](https://github.com/Duckhanh149/DayMind-Smart/actions/runs/42716570760): **Android và Windows đều thành công**. Android job129499547665:150 Flutter tests,25 receiver/recovery, Keystore/cold-process/digest, frame thật và account integration. Windows129499547254:149 tests +1 symlink test cần quyền host được skip, DPAPI/account/renderer/tray/installer đạt.
- [Emulator CI42716570825](https://github.com/Duckhanh149/DayMind-Smart/actions/runs/42716570825), job129499547130:16 cases thật +7 Auth/payload AOT đạt trên cùng source.
- Android artifact13719286315: ZIP SHA256 `48e3cdc20e60cdad1f1fad1b61258cc1b533f18c98ccf35d5935c8afb49b2467`; APK0.5.0/code2005,23555267bytes, minSdk24/target36/ARM64; CRC/OFL/signature v2 đạt. APK SHA256 `4ecfcdd78604517eea7d38060ef206e0316a8cdd7e2ab844cf24944e1fe56294`. Android Debug certificate, chưa có khóa ký sản xuất.
- Windows artifact13719600362: ZIP SHA256 `9f8c31a1748e1d0f1ff93c445ba6bbb0cda1f2172dbf00fecffc04a2c85d5fb0`; CRC/PE x64/runtime/OFL/0.5.0 đạt. Installer SHA256 `2461806e7a5f52ab38e93236ffa3e9624c8df21a1c15c4659e19220626de9ae9` (bootstrap x86, payload x64). Chưa ký sản xuất hoặc cài trên phần cứng Windows10/11 thật.
- Báo cáo gói và memory đã ghi `docs/qa/PHASE6_PACKAGES.json`, `PHASE6_RESOURCES.json`. File tải/chi tiết local nằm `/workspace/work/evidence/phase6-*`.

## Hiện tại: bắt đầu giai đoạn7

Đọc lại `MASTER_SPEC.reference.md` phần Companion/phase7 và ADR0008 trước khi triển khai. Giai đoạn6 đã có editor tên/tính cách/18 mẫu/sáu sự kiện/bốn biểu cảm; preview ảnh, vị trí auto/manual, low-resource, metadata sync/CAS, cooldown/quiet hours và dấu ngày quá hạn qua restart. PNG/WebP nguồn giữ nguyên byte/hash; derivative≤256px và lazy library; quota128 nguồn/32MiB tính cả cache. Lời chào đợi múi giờ thực; cue foreground dùng lời thoại thấy được hoặc SnackBar khi tắt/cuộn khuất, không OS alert thứ hai.

Giai đoạn7 đang triển khai, chưa qua cổng native. Đã có SafeZip/preflight PNG/GIF/WebP, manifest/provenance/checksum/clip/expression, normalize atlas128px/tile (≤2048×1024), giữ nguồn nguyên byte, cài staging rename/quota, 2 lượt chuẩn bị tối đa và drain/cancel khi đổi tài khoản. UI có tiến độ/hủy/xem trước/xác nhận quyền; nhận PNG/WebP/GIF/ZIP. Renderer sở hữu một atlas, hủy generation cũ; modal/scroll/background/tray/TickerMode/reduced-motion dừng timer và dispose. Low-resource/static library vẫn dùng preview.

Local: **193 tests toàn bộ đạt** trước giới hạn queue cuối; sau thay đổi queue,14 ca store/floating/import UI đạt (store thêm1 → tổng dự kiến194). Analyze sạch trước probe cuối; chạy lại analyze/full suite và xem log mới nhất trước coi source mới sạch. Hướng dẫn gói `CHARACTER_PACKAGE.md`, ADR0009. Không coi unit tests là cổng7.

Windows native đã viết nhưng CHƯA build/runtime kiểm chứng: layered/tool/noactivate GDI+, cùng process/không thêm Flutter engine, mặc định nổi/topmost/click-through OFF; kéo/resize/clamp/DPI, khay phục hồi803, policy SHQueryUserNotificationState + RECT fullscreen + quiet. Native close được await trước drain/xóa workspace. Có policy12 cases và exe tác động Win32 thật không đóng gói vào app; integration mới có ANIMATION_RESOURCE_POC và FLOATING_RESOURCE_POC. API QUNS không chứng minh mọi cấu hình Focus Assist/DND trên Windows10/11 thật.

Tiếp tục: đẩy source lên nhánh/PR bằng expected SHA (parent b360a34 nếu chưa có commit mới), kiểm tree, soft-reset sau fetch; kiểm native CI cả hai nền tảng. Cần sửa mọi lỗi compile/probe; đo atlas/RSS/GDI/timing/quiet/fullscreen/focus/click-through/tray. Cần thêm kiểm texture/floating khi đổi tài khoản, playback native ngoài low-resource, ảnh UI động/chữ lớn. Chưa đánh dấu7 đạt hoặc làm8. Crash staging recovery/single-instance còn cần rà trong release gate9; không xóa staging của tiến trình đang hoạt động.

Sau7:8 kiểm chứng Live2D/giấy phép, chỉ bật khi qua cổng;9 backup có mật khẩu/atomic restore, privacy/signing/install/upgrade/hardware. Nhớ rà migration preference `companionSize` cũ sang layout mới ở cổng upgrade9 (giá trị cũ vẫn giữ trong preferences; bản mới dùng companion_local).

## Không làm lại

- Giai đoạn0–5 đã qua cổng tại c1e61c2, xem PHASE_STATUS/BUILD_STATUS; không sửa lại SDK/JIT vì nhật ký lỗi cũ.
- Counter `imageCache.liveImageCount` có thể bằng0 sau clearLiveImages dù widget giữ frame; đã có regression + native frame assertions. Không bỏ kiểm tra renderer.
- Probe dùng PNG indexed gốc tạo offline, tránh cộng GPU fixture-generation surfaces. Báo cáo là debug runner/emulator, không là RAM release hoặc máy yếu. Cache đỉnh131072bytes cả hai nền tảng; Windows RSS453828608→đỉnh585482240→sau dọn461877248, Android547864576→565100544→528637952bytes.
- Driver Android có deadline600s, required markers và sanitized diagnostics. Force-stop chỉ mở debug session mới sau bài cold-process; không mô phỏng nhắc nền bằng force-stop. Không retry che test failures hoặc tắt tối ưu SDK.

## Chạy kiểm tra

Workspace `/workspace/work/native-repo/apps/daymind`; source `/workspace/work/env.sh` để dùng Flutter/Dart ghim. `flutter analyze`, `flutter test` (193 toàn bộ vừa đạt; tổng194 sau queue cuối, cần chạy đầy đủ/CI). Emulator package riêng `emulator_test/`: pub get --enforce-lockfile trước; `RUN_EMULATOR=true dart test --concurrency=1 --reporter expanded`; CI còn chạy7 Auth/payload AOT.

Kiểm tra port trước khi mở Emulator mới: Auth9199, Firestore8180. Không chạy hai service trên cùng cổng; Java mồ côi không chứng minh Auth/CLI còn sống. Tránh full APK build local vì disk8GB/NDK đã dọn; dùng native CI, giữ checksum/TLS. Phần cứng Android OEM/Doze/reboot và Windows10/11 thật, production Firebase/signing vẫn là nghiệm thu cuối; chưa đánh dấu hoàn tất0–9 hoặc dừng automation.
