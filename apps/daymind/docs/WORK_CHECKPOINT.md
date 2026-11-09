# Điểm tiếp tục DayMind

## Mục tiêu và lựa chọn đã xác nhận

Hoàn thiện ứng dụng Android và Windows 10/11 theo các giai đoạn 0–9; kiểm chứng giai đoạn hiện tại trước khi triển khai giai đoạn kế tiếp. Dùng Firebase Emulator trước khi có dự án production. Đóng cửa sổ Windows thu vào khay để tiếp tục nhắc; menu có Mở và Thoát hẳn; tự khởi động cùng Windows mặc định tắt.

Người dùng muốn tiếp tục sau khi phải chờ giới hạn. Tác vụ nền “Tiếp tục DayMind” đã được bật để kiểm tra mỗi giờ theo múi giờ Asia/Saigon và thử nối tiếp khi hạn mức/môi trường cho phép; không chạy song song với phiên đang thực hiện dự án. Không bảo đảm tiếp tục ngay khi giới hạn vừa hết. Tài liệu này giữ điểm nối để lượt sau bảo toàn công việc và kiểm tra CI đúng commit trước khi thay đổi.

## Nguồn và kiểm chứng gần nhất

- Nhánh `native/flutter-app`, PR [#1](https://github.com/Duckhanh149/DayMind-Smart/pull/1). Không tự hợp nhất `main`.
- Source `c1e61c2187ebdb78c503b027416d66b4eec30257`: **giai đoạn 0–5 đã qua cổng tự động**.
- [Native CI42683631256](https://github.com/Duckhanh149/DayMind-Smart/actions/runs/42683631256): 121 Flutter tests; Android25 receiver/Keystore/cold-process/digest/native account; Windows DPAPI/native account/tray/installer đều đạt.
- [Emulator CI42683630803](https://github.com/Duckhanh149/DayMind-Smart/actions/runs/42683630803): 14 ca dữ liệu/Auth thật và bảy ca Auth/payload AOT đạt.
- Lượt Android trước treo sau cài APK kiểm thử; driver mới khởi động debug process mới, deadline10 phút, required markers và sanitized diagnostics đã chạy đạt. Không bỏ điều kiện validate hoặc tắt tối ưu SDK.

## Việc đang tiếp tục

Giai đoạn 6 đã triển khai editor hồ sơ/tính cách/lời thoại, biểu cảm vector và ánh xạ PNG/WebP, preview nhập, vị trí auto/manual, low-resource, metadata sync/CAS. Regression mới kiểm tra count/concurrent quota, symlink, WebP động bị từ chối, draft/stale editor, phone360/390/desktop1440 và chữ200%. Hai ca Emulator bổ sung profile convergence/conflict đã chạy đạt (tổng16). Native integration thêm RSS/cache benchmark `COMPANION_RESOURCE_POC`, cần CI source mới trước khi qua cổng6.

Kiểm chứng local cuối: 142 Flutter tests, analyze sạch, 16 Emulator cases, Kotlin main/debug compile đạt; bốn ca editor/preview/save chữ100/200% đạt. Ảnh headless đã xem. Native CI source6 đang kiểm chứng; không được triển khai giai đoạn7 trước khi qua cổng.

Source giai đoạn6 đã đẩy: `ca3cbd9646e061a080148aa7a5b5fd5d3a8b2d56`, tree `fa98f10f701e60e57a01a72d182711c40ea3cc36`. [Native CI42709633872](https://github.com/Duckhanh149/DayMind-Smart/actions/runs/42709633872), [Emulator CI42709633834](https://github.com/Duckhanh149/DayMind-Smart/actions/runs/42709633834) đang chạy. PR#1 đã cập nhật phạm vi Companion và điều kiện cổng. Workspace đã đồng bộ bằng soft reset sau khi xác minh remote tree; không hard reset.

Bằng chứng chi tiết tại `/workspace/work/evidence/phase6-*`; giữ thay đổi chưa commit. Không chạy lại emulator trên cổng đang dùng: Auth9199, Firestore8180; nếu CLI đã dừng, kiểm tra process/cổng rồi phục hồi test service, không suy diễn Java orphan là toàn bộ suite đang chạy. Cập nhật checkpoint/PR bằng commit và kết quả thật sau vòng native CI.

Giữ mọi thay đổi chưa commit khi phiên dừng; kiểm tra source/CI mới nhất trước khi nối tiếp. Không gọi PNG là Live2D, không coi runner Server/emulator là phần cứng Windows10/11 hoặc Android OEM thật.

## Chạy kiểm tra

Từ `apps/daymind`: `flutter analyze`, `flutter test`. Bộ Emulator là package riêng ở `emulator_test/`; chạy `flutter pub get --enforce-lockfile` ở đó trước khi dùng `firebase/npm run test:emulator`. CI native còn chạy kiểm tra receiver thực thi thật, Android Emulator và Windows process/integration.

Mã nguồn chạy được và kiểm thử tự động không thay thế nghiệm thu Android OEM/Doze/reboot hoặc Windows 10/11 trên phần cứng người dùng. Chưa có Firebase production; không gửi khóa dịch vụ hoặc mật khẩu thật vào chat/repository.

Windows job129475431472 của CI42709633872 đã đạt native/account/tray/installer, cache ảnh đỉnh mẫu131072bytes. RSS452476928→744235008bytes bao gồm `Picture.toImage` tạo fixture lớn trong runtime debug, nên chưa dùng số này làm mức sử dụng của renderer. Probe đang được tinh chỉnh dùng PNG indexed gốc tạo offline (không có GPU surface tạo fixture), tách thời gian nhập/chọn và RSS sau dọn; cần CI source mới cho báo cáo bộ nhớ đáng diễn giải. Emulator CI42709633834 đã đạt16 tests +7 AOT. Android sourceca3 vẫn chờ kết quả cuối; không chuyển giai đoạn7.
