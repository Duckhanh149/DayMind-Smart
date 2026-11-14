# Sao lưu DayMind v1

Giao diện Cài đặt → Sao lưu & khôi phục. Mật khẩu riêng ít nhất10 ký tự, tối đa1024 byte UTF-8; không chuẩn hóa hoặc lưu mật khẩu. Quên mật khẩu không có đường reset. Bộ chọn tệp hệ điều hành quyết định nơi lưu; dùng tệp mới để giữ bản trước. Không tự tải bản sao lưu lên cloud.

Tệp `.daymind` có magic ASCII DMSBKUP1 (8 byte), salt ngẫu nhiên16 byte, nonce12 byte, độ dài ciphertext uint32 big-endian4 byte, ciphertext và GCM tag16 byte. Toàn bộ header là AAD. PBKDF2-HMAC-SHA256 cố định600000 vòng/256 bit và AES-256-GCM qua cryptography2.9.0 (Apache2.0); không cho tệp chọn số vòng/thuật toán. RNG `Random.secure`. Giới hạn plaintext96MiB, file96MiB+56 byte; kiểm header/size trước KDF, kiểm depth JSON trước parse. KDF/AES/parse chạy isolate, không khóa UI. Xóa các buffer key/clear có thể xóa được; Dart strings/GC không có cam kết zeroization toàn bộ RAM.

Payload schema1 gồm UUID bản sao lưu, thời gian UTC, owner UID hoặc null nằm trong ciphertext, tối đa5000 SyncRecord/4MiB JSON, cấu hình≤64KiB,128 nhân vật/64MiB gồm nguồn+atlas/preview/metadata/license. Không chứa token, mật khẩu đăng nhập, mã thiết bị, quyền OS, outbox hoặc lịch sử thông báo. Xung đột đồng bộ đang mở phải được giải quyết trước export để không bỏ một bản đang sửa.

Tên asset chỉ là hash và loại đã biết; các tệp package chỉ có tên cố định. Giữ nguyên nguồn/hash, metadata và giấy phép. Importer kiểm lại checksum, định dạng ảnh/ZIP, giới hạn atlas và cổng Live2D trước lưu. Không trích đường dẫn tùy ý. Có kiểm ZIP-model không vượt cổng bằng backup.

Khôi phục chỉ vào đúng không gian đã tạo (UID phải khớp; local→local). Tạo bản sao task/series/rule/occurrence bằng mã mới, giữ công việc đang có. Marker UUID trong cùng transaction ngăn nhập lần hai. Người dùng chọn riêng việc thay cấu hình giao diện/Companion/nhắc; ảnh được thêm vào thư viện, không thay file cũ. Floating tắt; nhắc thiết bị và digest tạm dừng, không nhập delivery ledger hay phát backlog. Bật nhắc lại tường minh trong Cài đặt. Consent chẩn đoán không được kế thừa.

Host serialize thao tác với đổi/xóa tài khoản; dừng sync/controller/reminders và native scheduling khi restore, rồi phục hồi các dịch vụ cả khi lỗi. Preflight relations ở DB memory; chuẩn bị ảnh trong staging. Journal chỉ ghi UUID/tên hash mới; thêm file trước transaction, commit dữ liệu+marker cùng SQLite. Rollback xóa đúng file mới. Crash trước commit được journal dọn, sau commit giữ file; startup dọn staging tên UUID dành riêng trước khi mở workspace. Không xóa tệp gốc được chọn từ ổ đĩa. Android dọn cache tạm thuộc plugin sau dùng/lúc mở app; cache OS/provider ngoài app thuộc hệ điều hành.

Local đã kiểm AEAD/mật khẩu sai/sửa header, giới hạn, roundtrip recurrence/history/ảnh, khác owner/relations, SQL failure thật và journal crash trước/sau commit. Native probe trên Android/Windows phải xác minh file mã hóa, tài khoản Emulator thật, giữ dữ liệu/ảnh và không thêm delivery log trên chính source mới; xem BUILD_STATUS.

Từ0.7.1, ảnh nguồn tĩnh (gồm JPEG/BMP) tối đa16MiB và tổng assets64MiB; plaintext96MiB gồm base64/JSON. Định dạng framing/KDF không thay đổi. Bản cũ có thể từ chối backup lớn hơn giới hạn cũ; nâng phiên bản trước restore. Giới hạn lớn mới chưa được nghiệm thu hiệu năng thiết bị yếu.

Từ0.8.0, owner của backup production ràng buộc digest(project+UID); không cho restore chéo project/Emulator dù UID giống nhau. Backup Emulator cũ giữ ownerUID cũ, local vẫnnull. Không chứa tên project trong plaintext và không chuyển session/credentials.
