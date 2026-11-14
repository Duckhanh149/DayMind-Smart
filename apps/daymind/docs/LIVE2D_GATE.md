# Live2D — quyết định phát hành hiện tại

Đánh giá 10/11/2026 UTC, sau cổng7 tại e993033. **Giữ Live2D tắt và phát triển tiếp bản không Live2D** theo nhánh được cho phép trong MASTER_SPEC.reference.md, giai đoạn8: “Otherwise ship without Live2D and retain extension interface.” Đây không là tuyên bố đã POC hoặc được cấp quyền Live2D.

DayMind hiện dùng mã raster/GDI+ tự viết và ảnh do người dùng nhập. Chưa tải, cài, link hoặc phân phối Cubism Core/Framework/model mẫu; các gói0.6.0 đã kiểm không chứa SDK/model Live2D. Những điều kiện dưới đây áp dụng cho việc tích hợp Live2D sau này, không tự áp dụng giấy phép SDK cho ảnh PNG/GIF độc lập hiện có.

## Cơ sở giấy phép

Đã đọc nguồn chính thức, không chấp nhận thỏa thuận hay gửi yêu cầu thay người dùng:

- [Cubism Proprietary Software License](https://www.live2d.com/eula/live2d-proprietary-software-license-agreement_en.html): phần mở đầu nêu tải/cài/dùng phần mềm là chấp nhận điều khoản. Cubism Core dùng giấy phép riêng; không coi giấy phép wrapper là giấy phép Core.
- Cùng văn bản,1.5 định nghĩa Expandable Application gồm việc thêm/kết hợp file/data để dùng số model không xác định.2.1 yêu cầu xin/chấp thuận riêng trước khi xuất bản loại này;2.2 nói miễn trừ cá nhân/doanh nghiệp nhỏ không áp dụng cho Expandable Application. DayMind dự kiến nhập model ngoài nên **cần xác nhận phân loại/quyền phát hành này**, không tự kết luận miễn phí theo doanh thu hoặc chỉ vì phi thương mại.
- [Trang SDK Release License chính thức](https://www.live2d.com/en/download/cubism-sdk/release-license/) cũng tách trường hợp Expandable Application và yêu cầu xét duyệt/thỏa thuận riêng. Chưa có văn bản áp dụng cho DayMind.
- [Open Software License](https://www.live2d.com/eula/live2d-open-software-license-agreement_en.html) áp dụng cho Components. [Framework LICENSE](https://github.com/Live2D/CubismNativeFramework/blob/develop/LICENSE.md) và [Samples LICENSE](https://github.com/Live2D/CubismNativeSamples/blob/develop/LICENSE.md) tách rõ Core/Components; không suy ra cùng quyền cho mọi thành phần.
- [Điều kiện model mẫu](https://www.live2d.com/eula/live2d-sample-model-terms_en.html): model có nhóm/quyền riêng, bao gồm nhân vật của bên khác. Chưa có model được chọn với provenance/quyền đủ cho DayMind; không bundle model anime hoặc sample chỉ vì có trong repo công khai.

Các snapshot văn bản/hashes truy xuất nằm ở qa/PHASE8_LICENSE_SOURCES.json; đây là dấu vết đánh giá, không là bản cấp phép. Điều khoản có thể thay đổi; cần đọc lại trước tích hợp/phát hành và có phê duyệt bằng văn bản đúng phạm vi.

## Cơ sở kỹ thuật và phần chưa kiểm chứng

[Native Samples README](https://github.com/Live2D/CubismNativeSamples/blob/develop/README.md) nêu Core không nằm trong repo và phải lấy riêng; có các renderer OpenGL/Vulkan/D3D11 cùng các mẫu nền tảng. Nhánh develop là tham chiếu có thể đổi, không là bằng chứng chạy trên hai nền tảng DayMind.

[Metadata pub.dev live2d_flutter1.0.3](https://pub.dev/packages/live2d_flutter/versions/1.0.3) khai báo Android/Windows và Flutter>=3.22/Dart>=3.4. Đó là khai báo khả năng, chưa chứng minh tương thích Flutter3.47.9/Dart3.13.7, filesystem import hoặc resource budget của DayMind. URL repository hunmer/flutter_live2d không đọc được trong phiên đánh giá; chưa kiểm giấy phép wrapper từ source. Không cài package hoặc chạy hook có thể tải Core trước khi quyết định giấy phép được duyệt.

Chưa có: pin Core/SDK và wrapper phù hợp; model có quyền; render model thật Android ARM64 và Windows10/11; bridge texture/surface không thêm Flutter engine; lifecycle/dispose/background; motion/expression mapping, low-resource và RAM/CPU; importer giữ cấu trúc model, giới hạn đường dẫn/texture/script/network references. Không dùng POC GIF/sprite làm bằng chứng Live2D.

## Chốt nhánh an toàn

Cổng để **bật** Live2D chưa đạt. Không có switch từ xa, pubspec dependency hoặc SDK/model binary. Nhập model phải báo rõ chưa hỗ trợ, không diễn giải model thành raster hay thực thi code. Giữ contract renderer độc lập Flutter/Firebase cho adapter tương lai; driver atlas hiện tại tiếp tục hoạt động và phải qua regression. Sau kiểm chứng nhánh không Live2D có thể đến giai đoạn9; không cần người dùng gửi khóa/mật khẩu hay chấp nhận hợp đồng để dùng task manager/raster companion.
