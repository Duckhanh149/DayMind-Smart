# Firebase production và môi trường thử nghiệm

Từ0.8.0, bản build mặc định **chỉ dùng local**, không kết nối Emulator ngầm. Không tự chuyển từ production sang Emulator khi cấu hình lỗi. App vẫn mở dữ liệu local khi cấu hình cloud thiếu/sai và nêu trạng thái trong Tài khoản. Không có project production/credential được cung cấp trong lượt này nên **chưa deploy hoặc nghiệm thu máy chủ production thật**.

## Cấu hình build

- Emulator: `flutter run --dart-define=DAYMIND_FIREBASE_MODE=emulator`. Project bắt buộc `demo-*`, host chỉ localhost/127.0.0.1/::1/10.0.2.2; điện thoại USB dùng adb reverse. Không dùng email/mật khẩu thật trên Emulator. CI integration dùng RUN_ACCOUNT_EMULATOR=true, không nhúng vào app release.
- Production: sao chép `firebase/production-client.example.json` sang **firebase.production.local.json** trong apps/daymind (đã gitignore). Điền project ID thật và Firebase Web API key trực tiếp ở máy/build environment, không gửi chat/PR. Chạy `python tool/validate_firebase_production.py firebase.production.local.json`, rồi `flutter build windows --release --dart-define-from-file=firebase.production.local.json` hoặc `flutter build apk --release --target-platform android-arm64 --dart-define-from-file=firebase.production.local.json`.
- Service-account JSON/private key **không phải** cấu hình client, không nhúng vào app hoặc commit. Validator từ chối trường lạ/private_key và project demo. Firebase Web API key là cấu hình client phân phối trong app; quyền dữ liệu phải dựa vào Firebase Auth và Firestore Rules, không dựa vào việc giấu API key. Hạn chế API sử dụng trong Google Cloud theo nền tảng; không cấu hình hạn chế Android làm hỏng REST client Windows dùng chung key.

Production chỉ tạo URI HTTPS tới identitytoolkit.googleapis.com, securetoken.googleapis.com, firestore.googleapis.com. HTTP redirects bị chặn, không chuyển token sang origin khác. Auth REST response phải có aud/iss/sub khớp project/UID; đây là kiểm scope của response qua TLS, không phải tự xác minh chữ ký JWT phía client. Firestore/Auth server xác minh chữ ký và quyền thật.

## Session và dữ liệu

Keystore/DPAPI khóa theo backend/project; không tái dùng token Emulator cho production. Account SQLite/thư viện production nằm trong namespace project riêng, local root giữ nguyên. Backup production cũng ràng buộc owner theo project+UID bằng digest, nên UID trùng ở hai project không cho restore chéo; backup Emulator0.7.x vẫn dùng owner cũ. Không tự sao chép dữ liệu thử lên production; người dùng phải chọn copy-local khi đăng nhập. Không xóa dữ liệu cũ để sửa cấu hình.

Cloud hiện dùng TLS và cơ chế bảo vệ lưu trữ của Firebase, **không phải mã hóa đầu-cuối dữ liệu công việc**. Người quản trị có quyền dự án có thể truy cập dữ liệu cloud. Ảnh nhân vật/lịch sử thông báo/credentials không đồng bộ. Backup `.daymind` được mã hóa bằng mật khẩu riêng.

## Thiết lập và deploy thật — cần chủ dự án

1. Tạo/chọn Firebase project thật, bật Email/Password Authentication và Firestore **Native mode**. Chọn vùng dữ liệu, chính sách mật khẩu/email-enumeration protection, hạn mức và cảnh báo chi phí phù hợp. Không mở rules kiểu allow-all hoặc dùng service-account trong client. Chưa có App Check desktop/REST hoặc MFA trong bản này; không tuyên bố đã bật.
2. Xem lại `firebase/firestore.rules`. Đăng nhập Firebase CLI qua luồng OAuth an toàn của chủ dự án; không gửi token/key trong chat. Deploy riêng rules bằng `firebase deploy --config firebase.production.json --project PROJECT_ID --only firestore:rules` từ thư mục firebase. Config production không chứa mục emulators, không tự deploy khi chạy test.
3. Rules chỉ cho UID chủ sở hữu với provider password. Chặn anonymous/không đăng nhập/truy cập chéo, schema sai/trường thừa/payload quá cỡ. Tombstone active:false chặn stale client ghi/tái kích hoạt sau xóa tài khoản; vẫn cho chủ sở hữu dọn records trước xóa Auth.
4. Dùng tài khoản synthetic riêng ở project kiểm chứng: signup/signin/refresh/reauth/delete; owner A CRUD, B/anonymous không đọc/ghi/xóa A; CAS stale-write; tombstone/no resurrection; reconnect/offline/primary-device. Dọn tài khoản/dữ liệu thử. Không chạy kiểm thử phá hủy trên tài khoản có dữ liệu thật.
5. Chỉ đánh dấu production live khi có project ID, nguồn rules đã deploy, bản client tương ứng và kết quả thực tế. Các test Emulator/URI/config hiện tại không thay bước này. Chưa được cấp project nên chưa có bằng chứng live trong lượt sửa này.
