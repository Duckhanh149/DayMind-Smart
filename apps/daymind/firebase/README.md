# Firebase Emulator POC

Chỉ chạy local, project `demo-daymind`; không cần tài khoản Firebase, service key hoặc dự án cloud. Node 22+, JDK 21+.

```sh
npm ci
npm run test:emulator
```

Auth `127.0.0.1:9199`, Firestore `127.0.0.1:8180`; UI tắt. Hai tài khoản ngẫu nhiên dùng `example.invalid`, tự xóa khi kiểm thử thành công. Emulator bị dừng sau script, không export dữ liệu. Không dùng mật khẩu thật. Có thể đặt `FIREBASE_EMULATORS_PATH` vào thư mục cache được phép ghi.

Kiểm tra REST thật với emulator: Auth A/B, CRUD có token, từ chối anonymous/cross-user, CAS qua `documents:commit` với `currentDocument.updateTime`, từ chối ghi phiên bản cũ, dọn dữ liệu. Không dùng tham số dotted query cho precondition vì bản emulator này không xử lý đúng như commit JSON; đã kiểm chứng lỗi đó.

Rules hiện chứng minh namespace theo UID; chưa là bộ rules phát hành cho schema đồng bộ. POC không bật sync hoặc gửi công việc trong ứng dụng lên emulator. Outbox, retry, conflict UI và account isolation SQLite thuộc giai đoạn 5, chưa được đánh dấu đạt bằng POC này.

Kết quả Linux 09/11/2026: firebase-tools 15.35.0 + JDK 21.0.13, script thoát 0. Log: `PASS: Auth A/B, authenticated Firestore CRUD, cross-user/anonymous denial, CAS stale-write rejection, cleanup. Emulator only.`
