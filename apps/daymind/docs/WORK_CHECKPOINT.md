# Điểm tiếp tục DayMind

## Mục tiêu và lựa chọn đã xác nhận

Hoàn thiện Android và Windows 10/11 theo giai đoạn0–9; kiểm chứng giai đoạn hiện tại trước giai đoạn kế tiếp. Firebase Emulator trước, chưa có production. Windows đóng→khay, Mở/Thoát hẳn; autostart mặc định tắt. Chỉ cập nhật `native/flutter-app` / PR[#1](https://github.com/Duckhanh149/DayMind-Smart/pull/1); không hợp nhất main. Không gửi khóa/mật khẩu vào chat hoặc repository. Live2D giữ tắt cho tới POC hai nền tảng và giấy phép.

Tác vụ “Tiếp tục DayMind” kiểm tra mỗi giờ (Asia/Saigon), nối tiếp khi hạn mức/môi trường cho phép; không bảo đảm chạy ngay khi hết giới hạn. Không khởi chạy thêm lượt code nếu lượt hiện tại còn hoạt động. Giữ mọi thay đổi chưa commit, kiểm tra workspace/process/CI mới nhất trước khi sửa; không hard reset.

## Bằng chứng đã xác minh

- Giai đoạn0–5: source `c1e61c2187ebdb78c503b027416d66b4eec30257`, [Native CI42683631256](https://github.com/Duckhanh149/DayMind-Smart/actions/runs/42683631256) và [Emulator CI42683630803](https://github.com/Duckhanh149/DayMind-Smart/actions/runs/42683630803):121 Flutter tests;25 Android receiver/Keystore/cold-process/digest/account, Windows DPAPI/account/tray/installer;14 Emulator+7 AOT đạt.
- Companion giai đoạn6 trước tối ưu ảnh: source `e5be376a887366662286626db4bd2a457dfbbe13`, [CI42712182080](https://github.com/Duckhanh149/DayMind-Smart/actions/runs/42712182080) **cả hai nền tảng đạt**. Windows job129484322286, Android129484322538;144 Flutter tests (Windows có ca symlink cần quyền host được skip),25 receiver và toàn bộ native markers đạt.
- Metadata profile sync: [Emulator CI42709633834](https://github.com/Duckhanh149/DayMind-Smart/actions/runs/42709633834), sourceca3cbd9:16 tests+7 AOT đạt. Mã sync/rules không đổi trong các tinh chỉnh renderer tiếp theo.

## Giai đoạn đang hoàn thiện: 6

Editor tên/ba tính cách/18 mẫu lời thoại/sáu sự kiện/bốn biểu cảm, preview, ánh xạ ảnh cục bộ; auto/manual vị trí/kích thước, low-resource. Metadata dùng outbox/CAS/conflict archive, không upload ảnh/layout. Cooldown30s, giờ yên lặng không thoại; dấu ngày quá hạn lưu cục bộ qua restart, chỉ gợi ý khi xem Hôm nay. Không có scheduler/âm thanh riêng.

**Source tối ưu đã đẩy `57d38e5f5d956c251c73e31dba4c7d591048d4fe`, chưa chuyển7.** [Native CI42714789128](https://github.com/Duckhanh149/DayMind-Smart/actions/runs/42714789128) và [Emulator CI42714789361](https://github.com/Duckhanh149/DayMind-Smart/actions/runs/42714789361) đang chạy; chờ đúng source này trước khi code7. Workspace đã đồng bộ soft reset sau khi đối chiếu tree `fe0f0875593b4b82a9528a8c114a83cfcde0254e`. PR#1 đã cập nhật.

- Nguồn PNG/WebP giữ nguyên byte/hash; derivative PNG≤256px trong `.previews/`. UI dùng derivative (128px chân dung low-resource/64px thumbnail). Quota128 nguồn/32MiB tính cả derivative; legacy cache tạo một lượt theo nhu cầu, chặn symlink và dọn cả nguồn/cache khi xóa.
- Library dùng ListView ngang theo viewport; menu biểu cảm chỉ text. Hồi quy thư viện128 ảnh với chữ200%, quota/retry legacy, nguồn không bị đổi.
- Lời chào startup đợi ReminderCoordinator lấy múi giờ; standalone controller đọc quiet settings đã lưu. Kiểm thử23:00 Asia/Ho_Chi_Minh khi16:00UTC; không tiêu cooldown trước khi có cấu hình thực.
- **Local cuối:150/150 Flutter tests và analyze sạch** (`/workspace/work/evidence/phase6-150-final.txt`, `phase6-thumbnail-analyze.txt`). Kotlin main/debug compile đã đạt sau thay đổi typed foreground cue; Kotlin không đổi trong tối ưu ảnh.
- Native probe dùng bốn PNG indexed2048² gốc tạo offline, đổi24 lần, đo RSS trước/sau nhập/đỉnh mẫu/sau dọn và cache. Bắt buộc `RawImage.image != null`, frame≤128px và chân dung trong viewport. Chờ CI trên source tối ưu để so sánh Windows, đồng thời giữ sửa visibility bên dưới trước khi qua cổng6.

Sửa cuối chưa commit: thẻ lời thoại Hôm nay/Companion có GlobalKey; xác nhận text nằm trong viewport trước khi chọn cách hiển thị cue foreground. Khi Companion tắt hoặc text bị cuộn khuất, hiện SnackBar có Xem Notification Center, không tạo OS alert thứ hai. Hai UI tests (100/200% chữ) đã đạt; bộ150 cuối ở phase6-150-final.txt đã đạt, analyze visibility sạch. Ca thứ ba xác nhận khi lời thoại thực sự thấy được thì không có SnackBar/OS alert trùng. Không chuyển7 chỉ dựa trên CI57d38e5 khi sửa này còn chưa commit/kiểm chứng.

CI57d38e5: Windows job129493383717 đã đạt renderer/account/tray/installer. RSS trước455356416, sau nhập574844928, đỉnh585175040, sau dọn461066240bytes; cache131072bytes. So với nguồn9320ce9, phần RSS sau dọn gần baseline hơn (5,4MiB so113MiB); không suy diễn là số đo release/thiết bị yếu. Emulator CI42714789361 đạt; Android CI42714789128 còn chờ kết quả cuối tại thời điểm ghi.

## Lịch sử cần tránh làm lại

ca3cbd9 Windows đạt, Android dừng ở `liveImageCount > 0`. Hai regression renderer chứng minh `clearLiveImages()` có thể xóa tracking dù widget vẫn giữ frame; e5be376 đổi sang kiểm tra frame thật và native đã đạt. Không cần bỏ kiểm tra renderer hoặc sửa SDK/JIT.

Số đo trước tối ưu: Windows source9320ce9 RSS448167936→đỉnh645328896→sau dọn567029760bytes; Androide5be376 RSS553680896→đỉnh564011008→sau dọn536858624bytes. Cache đỉnh131072bytes. Đây là debug runner/emulator, chưa phải RAM release hoặc máy yếu. Bài probe đầu ca3cbd9 còn cộng GPU surface dùng tạo fixture; không dùng nó để suy ra RAM renderer.

Driver Android `tool/android_native_integration.py` có deadline600s, required markers, sanitized diagnostics và debug session mới sau bài OS cold-process; không dùng force-stop mô phỏng nhắc nền. Không tắt tối ưu SDK hoặc retry che lỗi test.

## Chạy và tiếp tục

Workspace `/workspace/work/native-repo/apps/daymind`; source `/workspace/work/env.sh` để dùng Flutter/Dart đã ghim. `flutter analyze`, `flutter test`. Bộ Emulator package riêng `emulator_test/`: pub get --enforce-lockfile trước; `RUN_EMULATOR=true dart test --concurrency=1 --reporter expanded`. CI chạy thêm7 Auth/payload AOT.

Kiểm tra port trước khi mở Emulator mới: Auth9199, Firestore8180. CLI/Java có thể mồ côi sau phiên dừng; không suy diễn một process Java nghĩa là cả suite đang hoạt động. Không chạy hai service trên cùng cổng. Tránh full APK build local vì disk8GB/NDK đã dọn; dùng native CI và giữ checksum/TLS.

Sau source tối ưu qua cả native jobs và Emulator: cập nhật PHASE_STATUS/BUILD_STATUS/PR bằng commit/run thật, rồi thực hiện7 (animation/safe package/floating Windows),8 (Live2D có cổng),9 (backup có mật khẩu/restore/release). Chưa có animation/floating implementation. Hardware Android OEM/Doze/reboot, Windows10/11 thật, production/signing vẫn là nghiệm thu cuối; không đánh dấu hoàn tất0–9 từ runner.
