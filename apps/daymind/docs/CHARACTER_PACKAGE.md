# Gói nhân vật DayMind v1

Giai đoạn7 đã đạt native CI42757179906/sourcee993033; xem BUILD_STATUS.md cho bằng chứng và giới hạn thiết bị. Không chứa Live2D hoặc mã thực thi. Chỉ nhập tài sản có quyền sử dụng; ứng dụng không xác nhận thay chủ sở hữu về giấy phép. Không tải tài nguyên qua mạng.

Có thể chọn trực tiếp PNG/WebP tĩnh (≤4 MiB), GIF/WebP động (≤8 MiB) hoặc ZIP DayMind (≤16 MiB). Phần xem trước nêu tác giả/ghi chú quyền, số khung và cho phép hủy. Cần xác nhận quyền trước “Nhập & sử dụng”. ZIP không tự trở thành model Live2D.

ZIP chứa `manifest.json` UTF-8 ở gốc, đúng một ảnh nguồn, tùy chọn một tệp giấy phép `.txt`. Không thêm README, script, DLL, SDK, URL ảnh hoặc tệp không có trong manifest. Ví dụ thực thi được nằm ở `test/fixtures/valid_character.zip`; đây là hình thử nghiệm gốc 8×8px, không phải nhân vật có bản quyền của bên khác:

```json
{
  "format": "daymind.character",
  "version": 1,
  "kind": "sprite",
  "name": "Mầm thử nghiệm",
  "image": "assets/sheet.png",
  "frames": [{"x": 0, "y": 0, "width": 8, "height": 8, "durationMs": 125}],
  "motions": {"idle": {"frames": [0], "loop": true}},
  "expressions": {"neutral": "idle"},
  "checksums": {"assets/sheet.png": "14807eb94a90b057d390a3098a5ab5e0498b166152e6ac0204e3bc698d483fab"},
  "provenance": {"author": "DayMind", "license": "Original synthetic test fixture"}
}
```

- `kind`: `static`, `sprite`, `animation`. Static dùng PNG/WebP một khung; sprite dùng ảnh tĩnh và `frames`; animation dùng GIF/WebP có thời lượng từ container. Không nhận APNG. Không dùng `frames` của sprite cho hai loại còn lại.
- `frames`: chỉ số từ0, hình chữ nhật nằm hoàn toàn trong ảnh. Sprite tối đa120 khung. Mỗi thời lượng được kẹp84–5000ms; thời lượng0 trong GIF dùng125ms. Tối đa dưới12 cập nhật/giây; không phát bù khung dồn khi máy bận.
- `motions`: tối đa16 tên ASCII dạng `idle`, `cheer`…; mỗi danh sách1–120 chỉ số hợp lệ, tổng thời lượng clip≤60s; `loop:false` giữ khung cuối. Nếu bỏ, ứng dụng tạo `idle` gồm các khung theo thứ tự.
- `expressions`: `neutral`, `happy`, `focused`, `resting` ánh xạ tới tên motion. Thiếu ánh xạ dùng neutral→idle→motion đầu. Hồ sơ lời thoại/tính cách độc lập với gói ảnh.
- `sampling`: tùy chọn `nearest` hoặc `smooth`, áp dụng khi chuẩn hóa ảnh nguồn.
- `checksums`: SHA256 chữ thường, đúng byte gốc cho ảnh và `licenseFile` nếu có. Không hash manifest tự tham chiếu. Tệp giấy phép UTF-8≤64KiB.
- `provenance.license`: bắt buộc,≤500 ký tự. `author`≤80, `source`≤300 là văn bản hiển thị; không tự mở/tải URL. Tên gói≤80. Unknown fields bị từ chối, không âm thầm thực thi hoặc bỏ qua.

Ảnh tĩnh/sheet≤2048×2048; GIF/WebP động≤1024×1024 và120 khung, kiểm trước khi cấp phát metadata codec. PNG metadata không liên quan pixel và WebP ICC/EXIF/XMP được loại ở bản đưa vào decoder; byte nguồn gốc vẫn giữ nguyên. Chuẩn hóa thành atlas PNG với tile128×128, tối đa2048×1024 (8MiB RGBA), thêm preview128px. Các motion giữ tọa độ chuẩn hóa, không giữ đường dẫn do ZIP cung cấp.

ZIP tối đa64 entry (kể cả thư mục),8MiB/tệp,32MiB tổng giải nén, tỉ lệ300:1, path sâu≤4. Chỉ store/deflate, kiểm CRC, header local/central và output thực tế. Từ chối ZIP64, mã hóa, link/reparse, traversal, đường dẫn tuyệt đối/backslash, tên thiết bị Windows, trùng tên/case, chồng vùng dữ liệu, payload thừa và cấu trúc không nhất quán. Không giải nén đường dẫn ZIP ra filesystem: installer chỉ viết tên cố định vào staging rồi rename nguyên tử.

Tối đa hai lượt chuẩn bị cùng lúc; normalize/lưu tuần tự và drain trước khi xóa tài khoản. Thư viện≤128 mục/32MiB tính cả nguồn, atlas, preview và metadata. Nguồn của gói được giữ byte/hash trong `source.bin`; không chỉnh sửa tại chỗ. Nhập trùng không nhân đôi quota. Dữ liệu ảnh/layout/chuyển động không được đưa vào cloud profile. Xóa gói dọn nguồn/atlas/cache và tham chiếu biểu cảm; thiếu/hỏng gói dùng Mầm, không tải bản thay thế trên mạng.

Trong thẻ, hoạt ảnh chỉ sở hữu một atlas; ra nền, thu khay, dialog che, cuộn khuất, TickerMode tắt hoặc giảm chuyển động sẽ dừng timer và giải phóng atlas. Low-resource dùng preview tĩnh. Thumbnail thư viện không tự hoạt ảnh. Không có audio hoặc scheduler nhắc việc riêng.

Gói thử nghiệm `test/fixtures/three_sprite_frames.zip` có ba panel chữ nhật, hai motion, ánh xạ biểu cảm và tệp ghi chú quyền. Kiểm thử xác nhận crop đúng panel, giữ tỷ lệ/viền trong suốt và pixel cuối; fixture không nằm trong bundle phát hành.
