# Ký và phát hành

Bản0.7.0 hiện là preview đã qua native CI43160174675 và kiểm tra gói tại nguồn 8372826a. Chưa có signing identity sản xuất được cấu hình, chưa xác minh nâng cấp điện thoại thật hoặc tin cậy Authenticode trên máy người dùng. Không gọi artifact debug/unsigned là production. Không gỡ app cũ để cài đè khi khác chữ ký; giữ dữ liệu/bản sao lưu trước mọi thử nghiệm.

Workflow Build Android and Windows mặc định preview và **publish=false**. Push chỉ build/test/artifact. Không tự merge main hoặc tạo Release. Chỉ manual từ main với publish=true, sau cả jobs đạt, mới tạo prerelease theo phiên bản pubspec; không thay artifact Release đã có. Không chạy publish/production thay người dùng khi chưa có điều kiện.

Để kiểm chứng chế độ production, cấu hình trực tiếp trên GitHub repository → Settings → Secrets and variables → Actions. Không gửi giá trị vào chat, issue, PR hay repository:

| Loại | Tên |
| --- | --- |
| Secret | DAYMIND_ANDROID_KEYSTORE_BASE64, DAYMIND_ANDROID_STORE_PASSWORD, DAYMIND_ANDROID_KEY_PASSWORD, DAYMIND_ANDROID_KEY_ALIAS |
| Variable công khai | DAYMIND_ANDROID_CERT_SHA256 |
| Secret | DAYMIND_WINDOWS_PFX_BASE64, DAYMIND_WINDOWS_PFX_PASSWORD |
| Variable công khai | DAYMIND_WINDOWS_CERT_SHA256 |

Người sở hữu ứng dụng giữ keystore/khóa Android ổn định và bản sao an toàn; chưa tạo khóa thay họ. Windows cần certificate code-signing có quyền dùng và chain được hệ điều hành tin cậy; không tự mua chứng thư hoặc thêm self-signed certificate vào Trusted Root để giả kết quả. Các fingerprint là SHA256 certificate, không phải hash tệp keystore/PFX.

Chọn workflow signing=production, publish=false để build kiểm tra trước. Android giải mã keystore vào RUNNER_TEMP với quyền0600, Gradle release nhận secrets qua environment; không fallback debug khi cấu hình thiếu. Apksigner phải xác minh chữ ký và khớp fingerprint trước upload. Các build debug/receiver không dùng signing production. Windows ký app trước đóng installer, sau đó ký installer; kiểm signer, trust chain và timestamp. Tệp/private key tạm được dọn cả khi lỗi, không có trong artifact. Production path chưa chạy với khóa thật; parser/guard không thay bằng chứng ký thật.

Trước phát hành phải cài bản ký cũ rồi nâng cấp bản ký mới trên Android và Windows, kiểm công việc/SQLite/lịch sử occurrence/ảnh/phiên mã hóa và không phát backlog. So chứng chỉ với bản đang cài; signature mismatch phải dừng. Cần kiểm Windows10/11/Focus Assist và Android OEM/Doze/reboot/máy yếu; CI Server/emulator không thay cho phần cứng đích. Firebase vẫn dùng Emulator theo lựa chọn hiện tại, chưa quảng bá đồng bộ production.
