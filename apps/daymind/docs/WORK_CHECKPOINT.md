# Điểm tiếp tục DayMind

## Mục tiêu và lựa chọn đã xác nhận

Hoàn thiện Android và Windows 10/11 theo giai đoạn 0–9; kiểm chứng giai đoạn hiện tại trước giai đoạn kế tiếp. Firebase Emulator trước, chưa có production. Windows đóng → khay, Mở/Thoát hẳn; autostart mặc định tắt. Chỉ cập nhật `native/flutter-app` / PR [#1](https://github.com/Duckhanh149/DayMind-Smart/pull/1); không hợp nhất main. Không gửi khóa/mật khẩu vào chat hoặc repository. Live2D giữ tắt cho tới POC hai nền tảng và giấy phép.

Tác vụ “Tiếp tục DayMind” kiểm tra mỗi giờ (Asia/Saigon), nối tiếp khi hạn mức/môi trường cho phép; không bảo đảm chạy ngay khi hết giới hạn. Không khởi chạy thêm lượt code nếu lượt hiện tại còn hoạt động. Giữ mọi thay đổi chưa commit, kiểm tra workspace/process/CI mới nhất trước khi sửa; không hard reset.

## Cổng đã qua: 0–6

Source `67c4a433b76c62a7cdae36b2760a29c5a896a2e1`, tree `02ea0bbd5e224e546ca356faf7496503d71b0c53`; workspace đã soft-reset khớp remote sau khi kiểm tree. Remote0a3fa46d0e4abac719c69fd30467489007e312de / tree60b67ca71dd892a299563e40164e6cf6ed1ab977 đã cập nhật lockfile0.6.0+6 và CI path filter. CI42750776757: Windows195 tests +2 skip, GDI+ build và12 policy cases đạt; native resource probe dừng lúc kiểm dialog sau400ms khi overlay chưa tháo. Android197 tests/25 receiver/build/Keystore đạt, cold-smoke dừng vì adb dumpsys exit255 (chưa có stderr chẩn đoán); không tính thông báo/animation mới đã đạt. Emulator42750777094 đạt16+7. Source097ba5a trước đó đã đạt toàn bộ Android194/cold-process/account/3-frame animation. Không gán kết quả source cũ cho source mới. Không reset/ghi đè các thay đổi local.

- [Native CI42716570760](https://github.com/Duckhanh149/DayMind-Smart/actions/runs/42716570760): **Android và Windows đều thành công**. Android job129499547665:150 Flutter tests,25 receiver/recovery, Keystore/cold-process/digest, frame thật và account integration. Windows129499547254:149 tests +1 symlink test cần quyền host được skip, DPAPI/account/renderer/tray/installer đạt.
- [Emulator CI42716570825](https://github.com/Duckhanh149/DayMind-Smart/actions/runs/42716570825), job129499547130:16 cases thật +7 Auth/payload AOT đạt trên cùng source.
- Android artifact13719286315: ZIP SHA256 `48e3cdc20e60cdad1f1fad1b61258cc1b533f18c98ccf35d5935c8afb49b2467`; APK0.5.0/code2005,23555267bytes, minSdk24/target36/ARM64; CRC/OFL/signature v2 đạt. APK SHA256 `4ecfcdd78604517eea7d38060ef206e0316a8cdd7e2ab844cf24944e1fe56294`. Android Debug certificate, chưa có khóa ký sản xuất.
- Windows artifact13719600362: ZIP SHA256 `9f8c31a1748e1d0f1ff93c445ba6bbb0cda1f2172dbf00fecffc04a2c85d5fb0`; CRC/PE x64/runtime/OFL/0.5.0 đạt. Installer SHA256 `2461806e7a5f52ab38e93236ffa3e9624c8df21a1c15c4659e19220626de9ae9` (bootstrap x86, payload x64). Chưa ký sản xuất hoặc cài trên phần cứng Windows10/11 thật.
- Báo cáo gói và memory đã ghi `docs/qa/PHASE6_PACKAGES.json`, `PHASE6_RESOURCES.json`. File tải/chi tiết local nằm `/workspace/work/evidence/phase6-*`.

## Hiện tại: kiểm chứng giai đoạn7

Đọc lại `MASTER_SPEC.reference.md` phần Companion/phase7 và ADR0008 trước khi triển khai. Giai đoạn6 đã có editor tên/tính cách/18 mẫu/sáu sự kiện/bốn biểu cảm; preview ảnh, vị trí auto/manual, low-resource, metadata sync/CAS, cooldown/quiet hours và dấu ngày quá hạn qua restart. PNG/WebP nguồn giữ nguyên byte/hash; derivative≤256px và lazy library; quota128 nguồn/32MiB tính cả cache. Lời chào đợi múi giờ thực; cue foreground dùng lời thoại thấy được hoặc SnackBar khi tắt/cuộn khuất, không OS alert thứ hai.

Giai đoạn7 đang triển khai, chưa qua cổng native. Đã có SafeZip/preflight PNG/GIF/WebP, manifest/provenance/checksum/clip/expression, normalize atlas128px/tile (≤2048×1024), giữ nguồn nguyên byte, cài staging rename/quota, 2 lượt chuẩn bị tối đa và drain/cancel khi đổi tài khoản. UI có tiến độ/hủy/xem trước/xác nhận quyền; nhận PNG/WebP/GIF/ZIP. Renderer sở hữu một atlas, hủy generation cũ; modal/scroll/background/tray/TickerMode/reduced-motion dừng timer và dispose. Low-resource/static library vẫn dùng preview.

Source99ee91b9ac407c8433d97cace88b1805749f8f94 / tree5fb5001ea549c71a14b25b4644d1989191027b3a đã push và soft-reset khớp tree; workspace code sạch. Native CI42752885734: Windows dừng trước test ở upstream GitHub API403 rate limit; Android đang chạy tiếp. Emulator42752885523 đã đạt16+7. Sửa build đang chờ push: dùng token đọc sẵn của Actions chỉ cho HTTPS api.github.com, bỏ Authorization trên redirect; vẫn kiểm SHA256 upstream.10 Python driver tests đạt (gồm redirect/rate-limit); không xin hoặc ghi token thật vào repo/log. **199 Flutter tests toàn bộ đạt**, analyze sạch;10 Python driver guards đạt. Thêm sprite3 khung chữ nhật kiểm crop/pixel/letterbox, giữ clip/license; UI nhập đã rà phone200%/desktop (ảnh docs/ui/phase7-*.png là headless). Có thêm regression dialog exit2s (7 renderer cases đạt); Dialog probe dùng DialogRoute.completed và pump có hạn thay vì giả định400ms, vẫn giữ kiểm image.debugDisposed/RSS. Native account probe mới dùng local GIF preview128 khác ảnh private256 để kiểm sign-in/sign-out/reopen/delete thật và cloud không chứa asset ID; chưa chạy native trên source này. Android smoke giờ log lỗi đã che dữ liệu + chẩn đoán chỉ đọc, dùng serial tường minh; không retry hoặc restart để che lỗi, pidof transport failure không được coi là process đã đóng. Giữ mọi thay đổi trước khi push. Hướng dẫn gói CHARACTER_PACKAGE.md/ADR0009.

Windows native đã build đạt tại0a3fa46 nhưng cửa sổ nổi CHƯA qua runtime gate: layered/tool/noactivate GDI+, cùng process/không thêm Flutter engine, mặc định nổi/topmost/click-through OFF; kéo/resize/clamp/DPI, khay phục hồi803, policy SHQueryUserNotificationState + RECT fullscreen + quiet. Native close được await trước drain/xóa workspace. Có policy12 cases và exe tác động Win32 thật không đóng gói vào app; integration mới có ANIMATION_RESOURCE_POC và FLOATING_RESOURCE_POC. API QUNS không chứng minh mọi cấu hình Focus Assist/DND trên Windows10/11 thật.

Tiếp tục: xem CI42752885734/42752885523 của99ee91b; đọc completed job logs để sửa chặn thực tế trước khi push tiếp; push thay đổi tiếp theo bằng expected SHA sau khi đọc remote mới nhất, kiểm tree, soft-reset sau fetch; kiểm native CI cả hai nền tảng. Cần sửa mọi lỗi compile/probe; đo atlas/RSS/GDI/timing/quiet/fullscreen/focus/click-through/tray. Cần xem kết quả probe account-artwork mới và native floating playback/resource/fullscreen/focus/click-through trước khi đánh dấu7. Chưa đánh dấu7 đạt hoặc làm8. Crash staging recovery/single-instance còn cần rà trong release gate9; không xóa staging của tiến trình đang hoạt động.

Sau7:8 kiểm chứng Live2D/giấy phép, chỉ bật khi qua cổng;9 backup có mật khẩu/atomic restore, privacy/signing/install/upgrade/hardware. Nhớ rà migration preference `companionSize` cũ sang layout mới ở cổng upgrade9 (giá trị cũ vẫn giữ trong preferences; bản mới dùng companion_local).

## Không làm lại

- Giai đoạn0–5 đã qua cổng tại c1e61c2, xem PHASE_STATUS/BUILD_STATUS; không sửa lại SDK/JIT vì nhật ký lỗi cũ.
- Counter `imageCache.liveImageCount` có thể bằng0 sau clearLiveImages dù widget giữ frame; đã có regression + native frame assertions. Không bỏ kiểm tra renderer.
- Probe dùng PNG indexed gốc tạo offline, tránh cộng GPU fixture-generation surfaces. Báo cáo là debug runner/emulator, không là RAM release hoặc máy yếu. Cache đỉnh131072bytes cả hai nền tảng; Windows RSS453828608→đỉnh585482240→sau dọn461877248, Android547864576→565100544→528637952bytes.
- Driver Android có deadline600s, required markers và sanitized diagnostics. Force-stop chỉ mở debug session mới sau bài cold-process; không mô phỏng nhắc nền bằng force-stop. Không retry che test failures hoặc tắt tối ưu SDK.

## Chạy kiểm tra

Workspace `/workspace/work/native-repo/apps/daymind`; source `/workspace/work/env.sh` để dùng Flutter/Dart ghim. `flutter analyze`, `flutter test` (199 ở source bổ sung đạt local, chờ native CI). Emulator package riêng `emulator_test/`: pub get --enforce-lockfile trước; `RUN_EMULATOR=true dart test --concurrency=1 --reporter expanded`; CI còn chạy7 Auth/payload AOT.

Kiểm tra port trước khi mở Emulator mới: Auth9199, Firestore8180. Không chạy hai service trên cùng cổng; Java mồ côi không chứng minh Auth/CLI còn sống. Tránh full APK build local vì disk8GB/NDK đã dọn; dùng native CI, giữ checksum/TLS. Phần cứng Android OEM/Doze/reboot và Windows10/11 thật, production Firebase/signing vẫn là nghiệm thu cuối; chưa đánh dấu hoàn tất0–9 hoặc dừng automation.
