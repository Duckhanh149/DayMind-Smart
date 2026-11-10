# Kiểm chứng bản native

Cập nhật 10/11/2026 (UTC). Nguồn native tại apps/daymind; web root độc lập.

## Checkpoint hiện tại

Source0.7.0+8 (giai đoạn9) đang chuẩn bị CI mới:217 Flutter tests,18 Python driver/signing guards,16 real Emulator đạt local/analyze sạch. Backup/restore native, mutex Windows, installer/upgrade và package checks chưa được gán PASS. Production signing chưa có identity; Live2D vẫn khóa. Xem WORK_CHECKPOINT/BACKUP_FORMAT/PRODUCTION_SIGNING/PRIVACY.vi.

Source213a820 /0.6.1+7 đã đạt Native42762621177 cả Android/Windows và Emulator42762620985 (16+7). Windows component100 checks0 failures. Nhánh không Live2D: contract atlas renderer, chặn model trước lưu và sửa regression cooldown/replay. Local203/203 Flutter tests, analyze sạch,14 Python guards và16 ca Emulator thật đạt. Xem LIVE2D_GATE.md/ADR0010. Đủ cổng fallback8, bắt đầu9; Live2D chưa được cấp quyền/POC để bật.

Preview **0.6.0, giai đoạn0–7 qua cổng tự động** tại e99303392f476fa842a793bbd28c09f538f94c27, [Native42757179906](https://github.com/Duckhanh149/DayMind-Smart/actions/runs/42757179906).

- Android:199 tests,25 receiver/recovery, release ARM64/Keystore/cold-process/digest, real account/artwork isolation, renderer và max-atlas120×6 đạt.
- Windows:197 tests+2 symlink guards cần quyền host được skip (Linux chạy); build/DPAPI/account,12 policy, component94+window probes15/7/7/7, tray/Open/Quit/không startup/installer đạt.
- Emulator42752885523/source99ee91b:16 real+7 AOT đạt. lib/firebase/emulator_test/pubspec trees giống e993033; không có thay đổi backend sau đó.14 Python guards đạt trên native CI.
- Package reports [PHASE7_PACKAGES.json](qa/PHASE7_PACKAGES.json), [PHASE7_RESOURCES.json](qa/PHASE7_RESOURCES.json). Android artifact13736237923: ZIP11284344bytes SHA bb39c6c0f74d50e8b997a4027d64e13991dc16216b932ece0b6c060ca36b561e; APK23751875bytes SHA41ccfaa0305d45cfe225a8064e3a8c90e2e1a6591a2c8e522cde45b47abc22d3,0.6.0/code2006/min24/target36/ARM64, CRC/OFL/v2 và không DebugReceiver đạt. Vẫn certificate Android Debug; production upgrade-chain chưa xác minh.
- Windows artifact13735829615: ZIP28560777bytes SHA92a15ac95101a4de6f7c1fae16ced2746125334cf571dfc1cdbb761e399dd72e, CRC/PE x64/runtime/OFL/0.6.0 đạt; không probe/userdata. Installer SHA dd1a18f173f27c616c7437699d1e7e3a7a2432d2b4076812e66678eb707093aa, bootstrap x86/payload x64, chưa ký sản xuất.
- Actual Windows OS state6/quiet-time: app ẩn đúng, zero surface/render. Component executable dùng chính C++ class với controlled notification reader và real Win32/GDI+ (không engine) để test visible/fullscreen/noactivate/click-through/max atlas. Component20 vòng GDI14→14, RSS14.8→25.9MB; app GDI18→18 khi bị chặn. Đây không là kiểm thử bật/tắt Windows10/11 DND thật.
- Mọi handle max-atlas dispose; Windows RSS461660160→đỉnh564637696→sau pause559857664, Android540454912→564314112→539529216bytes. Debug runner/emulator không thay cho release/GPU hoặc phần cứng yếu. Phone200%/desktop screenshots là headless UI evidence.

Live2D vẫn khóa, chưa SDK/model hoặc technical POC/license approval. Giai đoạn8 đánh giá tiếp;9 còn backup/restore, migration/signing/install/upgrade/privacy và hardware acceptance. Không nói hoàn thành0–9. Bằng chứng0–6 tại67c4a43 / Native42716570760 / Emulator42716570825 và qa/PHASE6_*; các đoạn phía dưới là lịch sử.

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
