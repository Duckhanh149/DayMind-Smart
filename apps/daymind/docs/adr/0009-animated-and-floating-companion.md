# ADR0009 — Hoạt ảnh giới hạn và cửa sổ nổi Windows

Trạng thái: giai đoạn7 đạt cổng tự động tại e993033 / Native42757179906, Emulator99ee91b/42752885523 (lib/backend/package trees giống nhau). Component94 checks, policy12 và actual app/tray/account đạt; xem qa/PHASE7_RESOURCES.json, PHASE7_PACKAGES.json.

GIF/WebP/sprite được preflight trước codec và chuẩn hóa thành atlas128px/tile. Giữ nguồn nguyên byte; preview, atlas, checksum/provenance và motion metadata ở thiết bị. Parser ZIP chạy trong isolate, không trích đường dẫn ra thư mục đích. Decode UI luôn dispose codec/buffer/picture/image khi hủy hoặc đổi generation; đọc/lưu được drain trước khi xóa workspace.

Renderer Flutter dùng một atlas và timer thời lượng khung≥84ms. Không tạo engine hoặc ticker toàn màn hình cho thumbnail. Khi offscreen/hidden/modal/background/reduced-motion, dispose texture; thấp tài nguyên dùng ảnh tĩnh. Nhân vật chỉ nhận sự kiện từ controller/Reminder Engine, không có thông báo hoặc âm thanh riêng.

Windows là cửa sổ Win32 layered/tool/no-activate trong cùng tiến trình, render GDI+ từ PNG dẫn xuất đã giới hạn; không tạo Flutter engine thứ hai, không giữ khóa tệp ảnh. Topmost/click-through/nổi mặc định tắt. Có kéo/resize, clamp work-area/DPI và chấm resize nhìn thấy; cài đặt và khay có đường phục hồi vị trí/nhận chuột. Đóng main vẫn thu khay; Thoát hẳn dọn cả cửa sổ nổi. Đổi tài khoản phải đợi close native trước drain/xóa ảnh cũ.

Policy native kiểm RECT foreground so monitor và API công khai `SHQueryUserNotificationState`; ẩn khi busy/presentation/D3D fullscreen/not-present/quiet-time và quiet hours do ứng dụng cung cấp. Không đọc/lưu title/process/activity của ứng dụng khác. API Windows không cung cấp bằng chứng mọi quy tắc Focus Assist/Do Not Disturb hiện đại; cần nghiệm thu Windows10/11 thật, không suy diễn từ runner Server. Timer frame dừng và DIB được giải phóng khi policy ẩn; bitmap CPU giới hạn vẫn giữ để phục hồi, giải phóng khi close/đổi nhân vật/tài khoản.

Bài gate mới: unit ZIP/header/schema/cancel/atomic/quota, widget chuyển khung/modal/scroll/lifecycle/reduced motion và nhập chữ200%; native atlas/frame/resource POC Android/Windows; executable kiểm12 policy cases và executable tác động Win32 thật: một Flutter view, không lấy focus, mặc định style, drag/resize/clamp, fullscreen hide/restore, click-through. Probe ở `companion-tests`, không nằm trong bundle phát hành. Chỉ gán kết quả khi đúng probe thực thi đạt trên source tương ứng; xem WORK_CHECKPOINT.

Live2D vẫn tắt và không có SDK/model phân phối. Giai đoạn8 chỉ xử lý sau cổng7.

CI660465f quan sát QUNS_QUIET_TIME=6 trên profile Windows mới: app thật phải ẩn và dừng render, không sửa policy để chạy bài visible. Component executable độc lập dùng cùng FloatingCompanionWindow với NotificationReader được kiểm soát; đây là dependency C++ trong constructor chỉ test truyền, không có MethodChannel override trong app. Component bắt buộc chạy real Win32 drag/resize/fullscreen/noactivate/click-through và real GDI+ atlas tối đa20 vòng; không tạo Flutter engine. Bài app thật xác nhận một Flutter view và trạng thái OS thực (visible nếu cho phép, zero surface/render nếu bị chặn), quiet/tray/account. Điều này không chứng minh người dùng đã bật/tắt Focus Assist/DND trên phần cứng10/11; mục đó vẫn ở nghiệm thu cuối.
