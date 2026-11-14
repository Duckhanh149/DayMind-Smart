# Firebase Emulator và đồng bộ thử nghiệm

Dùng project `demo-daymind`, không cần tài khoản Firebase hoặc khóa dịch vụ. Chỉ dùng email/mật khẩu thử nghiệm. Cần Flutter 3.47.9, Python, Node 22+ và JDK 21 đầy đủ.

Từ thư mục ứng dụng:

```sh
flutter pub get --enforce-lockfile
cd emulator_test
flutter pub get --enforce-lockfile
python ../tool/precache_sqlite.py
cd ../firebase
npm ci
npm run test:emulator
```

Lệnh cuối khởi động Auth/Firestore, chạy Node security smoke và bộ Dart REST/hai SQLite thiết bị độc lập, sau đó dừng Emulator. Dữ liệu tài khoản ngẫu nhiên `example.invalid` được dọn sau kiểm thử. Không dùng VM flag, không retry lỗi assertion; helper chỉ retry lỗi tải SQLite HTTP502/503/504.

Chạy máy chủ cho ứng dụng (bản0.8.0 mặc định offline; chạy client với `flutter run --dart-define=DAYMIND_FIREBASE_MODE=emulator`):

```sh
npx firebase emulators:start --config firebase.json --project demo-daymind --only auth,firestore
```

Auth `127.0.0.1:9199`, Firestore `127.0.0.1:8180`, UI tắt. Windows truy cập loopback; Android Emulator truy cập `10.0.2.2`. Trong app mở Cài đặt → Tài khoản & đồng bộ. Chọn tường minh nếu muốn sao chép dữ liệu cục bộ; mặc định dùng kho tài khoản riêng. Điện thoại thật vẫn dùng local được; thử tài khoản qua USB cần build với `DAYMIND_EMULATOR_HOST=127.0.0.1` và `adb reverse tcp:9199 tcp:9199`, `adb reverse tcp:8180 tcp:8180`.

Khi đã có máy chủ chạy, chạy riêng bộ integration:

```sh
cd ../emulator_test
RUN_EMULATOR=true dart test --concurrency=1 --reporter expanded
```

Rules chỉ cho UID chủ sở hữu đọc/ghi. Task/ruleset/cấu hình nhắc dùng CAS `documents:commit.currentDocument.updateTime`; updateTime là chuỗi opaque giữ cả nanosecond. Không dùng dotted query precondition vì Emulator đã được kiểm chứng không xử lý nó như commit JSON. Payload sai schema/quan hệ, quá kích thước hoặc nén quá mức bị client chặn trước transaction.

Đăng xuất giữ thay đổi chưa gửi trong kho riêng, trở về kho local. Xóa tài khoản cần nhập lại mật khẩu, đặt `active:false` trước khi dọn records/settings/devices/Auth và xóa cache tài khoản trên máy. Giữ dấu UID đã xóa không chứa email/nội dung để ngăn thiết bị cũ tải dữ liệu lên lại. Ảnh nhân vật, credential và lịch sử nhắc không được đồng bộ.

Primary-device policy được xác minh khi online; máy chính cũ offline có thể còn phát theo lịch cache. Chưa kết nối Firebase production, chưa coi Emulator là nghiệm thu hai máy phần cứng thật. Chi tiết [ADR0007](../docs/adr/0007-account-sync.md).

Production được tách riêng; xem [FIREBASE_PRODUCTION](../docs/FIREBASE_PRODUCTION.md). Không dùng project thật với endpoints Emulator hoặc gửi credentials thật qua HTTP.
