# Kiểm chứng bản native

Cập nhật 10/11/2026 (UTC). Nguồn native tại apps/daymind; web root độc lập.

## Checkpoint hiện tại

Preview **0.5.0 / giai đoạn0–6 đã qua cổng tự động** tại `67c4a433b76c62a7cdae36b2760a29c5a896a2e1`, [Native CI42716570760](https://github.com/Duckhanh149/DayMind-Smart/actions/runs/42716570760) và [Emulator CI42716570825](https://github.com/Duckhanh149/DayMind-Smart/actions/runs/42716570825).

- Phân tích mã sạch; 150 Flutter tests Android/Linux. Windows149 đạt, một ca tạo symlink cần quyền host được skip (đã chạy trên Linux).
- Android: APK release ARM64,25 receiver/recovery cases, Keystore, OS notification sau cold close/digest, frame Companion thật và real account sync đều đạt.
- Windows: DPAPI, SQLite/recurrence/account, renderer/resource probe, close→tray/Mở/Thoát, không autostart và installer đều đạt.
- Emulator:16 cases thật +7 Auth/payload AOT đạt trên cùng source.
- Kiểm tra gói tải từ đúng run: CRC ZIP/APK, PE x64/runtimes/OFL, minSdk24/target36/ARM64 và APK signature v2 đạt. Version0.5.0, Android versionCode2005. APK vẫn ký Android Debug, Windows chưa ký sản xuất; chưa xác minh đường cập nhật cùng chứng thư.
- Android artifact13719286315; Windows13719600362. Hash/package metadata tại [PHASE6_PACKAGES.json](qa/PHASE6_PACKAGES.json); số đo debug tại [PHASE6_RESOURCES.json](qa/PHASE6_RESOURCES.json). Cache đỉnh131072bytes hai nền tảng; Windows sau dọn461877248bytes so453828608 trước, Android528637952 so547864576 trước.

Source giai đoạn7 đầu097ba5a:194 tests/analyze local đạt; Emulator CI42732048719 đạt16+7. Native CI42732048732: Windows184 đạt/8 lỗi/2 skip ở Flutter tests do account-workspace harness chưa mô phỏng kênh close mới (chưa đến build GDI+); đã thêm stub chỉ trong unit test, giữ real integration không mock. Android job129552217598 đạt194 tests,25 receiver, APK/Keystore/cold-process/digest/account và probe hoạt ảnh ba khung (atlas384×128, quan sát đủ3 frame; RSS531386368→đỉnh533831680→sau pause542310400 bytes, debug emulator). Source0.6.0 tiếp theo bổ sung max-atlas120-frame/dispose/read/drain/account checks:197 tests/analyze local đạt, cần CI mới trên đúng commit. Chưa có animation/floating trong artifact0.5.0 source67c4a43 đã kiểm ở trên. Live2D vẫn tắt. Production Firebase/signing, backup/restore và phần cứng Android OEM/Doze/Windows10/11 còn trong cổng cuối. Số đo debug runner/emulator không thay cho máy yếu thật. Các đoạn “chờ CI” phía dưới là nhật ký lịch sử.

## Bằng chứng preview 0.1.0 trước đây


- Flutter 3.47.9 / Dart 3.13.7; JDK Temurin 21.0.13+9; Android SDK 35/36, NDK 28.2.13676358, CMake 3.22.1.
- flutter analyze: PASS, không issues. flutter test: 28/28 PASS trên Linux và runner Windows.
- UI phone/desktop/Companion được xem lại bằng PNG từ Flutter test. Kiểm tra 360/390/768/1440 px, chữ 200%, bàn phím, CRUD, SQLite transaction/migration/restart/revision và asset import budgets.
- Workflow 42500600905: Android APK build PASS; Windows release build PASS; Windows native integration startup + tạo/lưu công việc PASS; Inno Setup installer + bundled VC++ runtime PASS.
- Android artifact đã kiểm CRC ZIP/APK, manifest: dev.daymind.daymind_smart, version 0.1.0, minSdk 24, targetSdk 36. Bản debug đầu có ARM64/x86_64; bản phát cho điện thoại được tối ưu lại thành ARM64.
- Windows artifact đã kiểm CRC, PE x64, installer và các DLL runtime. Không xem đây là việc cài thủ công trên Windows 10/11 của người dùng.
- Build local Android trên cloud 8 GB hết dung lượng khi merge native libraries; phần đóng gói được chuyển sang GitHub Actions đã build thành công. Không tính lần local thất bại là PASS.
- Vòng cuối tại commit 7ffd0d5b081008cc8bfcfc95d679a2d886db2f8e, workflow 42560998276: Linux analyze/tests/build APK release ARM64 PASS; Windows analyze/tests/build/native integration/installer PASS. Publish job SKIPPED đúng thiết kế trên nhánh native/flutter-app.
- APK release: 22.084.732 bytes, chỉ ARM64; minSdk 24, targetSdk 36; apksigner verify PASS (v2), CRC PASS, có OFL trong asset bundle. SHA256 b4ec5102bfe11683048c0280481402ae64f14c48f16e54c16bd37034c8b9353e.
- Windows gói cuối: CRC PASS, có OFL trong asset bundle (nội dung tương đương LF/CRLF), installer và exe có PE header hợp lệ. Installer SHA256 62bbb28d7aa6fd3641fb346f871fe2063494364141679d95eb6a7f468f4d8d59.
- Artifacts hiện có tại workflow 42560998276: Android 13649473104; Windows 13648973240. PR #1 chờ chấp thuận hợp nhất vào main để tạo GitHub Release; chưa công bố release.
- Android thiết bị thật, Windows 10/11 cài thủ công, low-end hardware RAM/CPU: chưa chạy. Runner Windows native smoke không thay thế các mục này.
- Ở preview 0.1.0 ban đầu: thông báo khi app đóng, Firebase/sync, animation/floating companion/Live2D chưa có. Trạng thái nhắc việc mới xem checkpoint hiện tại ở trên; sync/animation/Live2D vẫn chưa hoàn thành.
- Chưa có chứng thư ký phát hành Windows hoặc khóa Android sản xuất. Đây là preview, chưa phải bản Store.

Giai đoạn 3 native checkpoint: [workflow 42606373902](https://github.com/Duckhanh149/DayMind-Smart/actions/runs/42606373902) ở `db618d9` đạt Android/Windows: 79 Flutter tests, **16 receiver/recovery tests thực thi**, emulator cold-process và Windows tray/installer. Vòng `d3ce1ea` đã đạt Windows với 80 tests và `RECURRENCE_POC` SQLite thật (complete một lần, future edit, giữ history); Android đang chạy smoke tại thời điểm ghi. Artifact Windows `13668657117` kiểm CRC/runtimes/OFL đạt; main exe x64 SHA256 `31ad0db5657630325c8132f9e4c595c3462be3fd08b8d3f57ae52fe43fd37b03`, installer (Inno bootstrap x86, payload x64) SHA256 `a7725717dac55941246b0b263fd250e5492e4b832b705a0d5d9d962119bd66ad`.

Hai ca QA lịch mới (chỉ có giờ kết thúc, chọn ngày tháng bên cạnh ngoài rolling horizon) đã sửa và toàn bộ **82 tests local đạt**, analyze sạch. Bản nguồn mới cần CI thực thi lại; không gán kết quả 80 tests cho source 82 tests.

Checkpoint giai đoạn 3 cuối: `740c8bfee8fd7f3d9d3d815f17637e6b7e26acfd`, [workflow 42608475322](https://github.com/Duckhanh149/DayMind-Smart/actions/runs/42608475322) **đạt cả hai native jobs**: 82 Flutter tests trên Linux/Windows, analyze sạch, 16 Android receiver tests thực thi, build APK + cold-process emulator smoke; Windows build, SQLite recurrence integration, tray process và installer đạt. Chuyển giai đoạn 4 sau checkpoint này. Preview publish bị skip đúng thiết kế nhánh PR.

Checkpoint giai đoạn 4 cuối: `94c39d579f5a438b32460e654a9599fc98415ed5`, [workflow 42615017005](https://github.com/Duckhanh149/DayMind-Smart/actions/runs/42615017005) **đạt cả hai native jobs**: 104 Flutter tests trên Linux/Windows, analyze sạch, 23 receiver/recovery/digest tests thực thi; Android OS phát một digest sau khi tiến trình đóng, không có task actions và đổi giờ/recovery không lặp; Windows build/native recurrence/tray/installer đạt. Chuyển giai đoạn 5 sau checkpoint này.

Vòng bổ sung giai đoạn 5: [CI 42660745167](https://github.com/Duckhanh149/DayMind-Smart/actions/runs/42660745167) tại `f569c45` đạt toàn bộ Windows: 119 Flutter tests, native DPAPI, Auth/Firestore thật, primary-device, logout/relogin/delete, tray và installer. Android dừng ở lint cấu hình mạng thiếu `includeSubdomains`; đã thêm thuộc tính tường minh. [Emulator CI 42659714694](https://github.com/Duckhanh149/DayMind-Smart/actions/runs/42659714694) đạt 14 ca và bảy ca Auth/payload AOT.

Sửa tiếp theo cần CI mới: xóa alarm/nội dung thông báo của kho cũ khi cold startup đổi đường dẫn SQLite; cache primary ràng buộc mã cài đặt; màn hình xem/chọn xung đột giữ Future ổn định và cập nhật state đồng bộ. Toàn bộ 121 Flutter tests và tám ca account/profile/UI 200% đạt local, Kotlin main/debug compile đạt. Native receiver suite yêu cầu ít nhất 25 ca thực thi. Chưa tính những thay đổi này đạt Android trước CI mới.

Windows trên source `4c8ceb8` / CI42665407040 đạt 121 tests, DPAPI và Auth/Firestore thật với profile/primary/logout/relogin/delete, tray/installer. Artifact `13697665534` đã kiểm CRC, runtime DLL và OFL: ZIP SHA256 `9124354b2bcf72cf397b135de2708f016d85e9a3e72791739060c36809cc810c`, installer SHA256 `0567159e733c1359c8e1d9f79ac7881ede5699e899ee64dd3bf55f29945c4de1`. Installer bootstrap x86 chứa payload x64; app chính có PE machine x64. Android ở workflow này vẫn cần kết quả cuối của cold-process/native account.

CI42665407040 Android: 121 Flutter tests, APK release, 25 receiver cases và Keystore/cold-process/digest đều đạt. Native account integration build và cài APK xong nhưng không mở kết nối kiểm thử; job hết hạn ở phút 55. Chưa đánh dấu giai đoạn 5 đạt. Đã thêm driver deadline 600 giây, start debug session mới sau khi kết thúc bài cold-process (giữ SQLite), required success markers và log chẩn đoán đã che token/đường dẫn VM service; đang chờ vòng CI kế tiếp. Kiểm chứng driver tại local đạt cho success marker, thiếu marker và dừng tiến trình bị treo; không dùng force-stop để mô phỏng thông báo nền.

Native giai đoạn6 sourcee5be376 / CI42712182080 đạt cả Android và Windows. Kiểm tra frame thật thay bộ đếm live-cache đã chạy thành công; native account/tray/installer/25 receiver/cold-process/digest giữ đạt. Đang tối ưu derivative256px và lazy library sau số đo Windows: nguồn9320ce9 RSS448167936→đỉnh645328896→sau dọn567029760bytes, cache131072bytes; Androide5be376 RSS553680896→đỉnh564011008→sau dọn536858624bytes. Tất cả là debug runner/emulator, không phải mức RAM bản release hoặc thiết bị yếu. Cần số đo source tối ưu mới trước khi chuyển7.

Windows source57d38e5 / job129493383717 đạt toàn bộ native và installer sau derivative/lazy library: RSS455356416→sau nhập574844928→đỉnh585175040→sau dọn461066240bytes; cache131072bytes. Nguồn nguyên byte được giữ; bộ147 tests tại source này đạt ở CI. Sửa cue visibility tiếp theo đạt150 tests local và analyze; chưa gán kết quả147 cho source150. Android của57d38e5 còn chờ kết quả cuối.
