# Bản0.8.0+10 đang kiểm — 13/11/2026

Đã sửa Windows permission/lifecycle limits, diagnostic opt-in, Firebase production build configuration và namespace/security rules. Local245 Flutter tests/analyze/27 Python guards và Firebase Emulator security+16 Dart+7AOT đã đạt. **Native và đo tài nguyên nguồn mới đang chờ CI**; chưa có kết quả0.8.0 hoặc phát hành chính thức. Bằng chứng0.7.1 bên dưới là lịch sử.

Firebase production thật/thiết bị AndroidOEM/Windows10/11/kýproduction chưa được cung cấp. Hướng dẫn [Firebase production](FIREBASE_PRODUCTION.md), [đo tài nguyên và nghiệm thu thật](RESOURCE_AND_DEVICE_ACCEPTANCE.md). Automation vẫn tắt, không merge main/Release. Windows chỉ nhắc khi tiến trình còn chạy (close→tray nếu khay sẵn sàng); quit/reboot không nhắc.

---

# Bản sửa preview0.7.1+9 — 12/11/2026

**Native Android/Windows đã đạt trên nguồn66e4ae5d68ac2639619b4da6ca98917111c94607**, [CI43225672366](https://github.com/Duckhanh149/DayMind-Smart/actions/runs/43225672366). Các commit sau chỉ cập nhật docs, không phải build mới. Chưa phát hành chính thức/merge main.

- Android job131208073702:233 Flutter tests, 27 receiver/recovery cases, Keystore/cold OS notification+digest/quiet/no replay, SQLite process isolation+5 overlapping integrity cycles, backup/account/artwork và host allTestsPassed đạt.
- Windows job131208073178:231 Flutter tests+2 symlink skip do host privilege (Linux chạy đủ), 100 component checks, DPAPI/backup/account/tray/launch2/quit/no startup đạt. Cài0.6.1→nâng0.7.1→gỡ→cài lại giữ dữ liệu; kiểm cả PE và registry DisplayVersion0.7.1 đạt.
- Emulator43222966423/job131198918278/source dacd03b:16 ca thật+7AOT đạt; lib/backend/package/integration/Android trees giống66, đã kiểm. Publish131214639652 SKIPPED.

## Tải và kiểm gói

Cần đăng nhập GitHub; artifact có hạn lưu trongActions.

| Gói | Cách dùng |
| --- | --- |
| [Windows10/11 x64 ZIP13949435030](https://github.com/Duckhanh149/DayMind-Smart/actions/runs/43225672366/artifacts/13949435030) | Giải nén, chạy windows-installer/DayMind-Setup.exe để cập nhật. Portable:giữ toàn bộ windows/x64/runner/Release rồi chạydaymind_smart.exe. Không cần gỡ bản cũ có dữ liệu. |
| [Android ARM64 ZIP13949065397](https://github.com/Duckhanh149/DayMind-Smart/actions/runs/43225672366/artifacts/13949065397) | Giải nén app-arm64-v8a-release.apk; Android7/API24+, ARM64, target36, code2009. Vẫn Android Debug preview; khác chứng thư phải dừng, không gỡ app có dữ liệu để vượt lỗi ký. |

Windows ZIP SHA256`a9039d3674dd61c39f360a322ef85d6e86df31b04a112fe27568d2a2c8d8a55b`; installer`5dbe0ac6933051ab90696ebbf71809b8a7d77fd75b647e61c5b1262f3d1791ab`. Android ZIP`c8af4cb567aa84dc343a6b568852645077a39e0c6eb8a46707c7dd85871a20d5`; APK`17479d989bd4447e408c89fd451c47c00a6665821f2022454de10df9a08a415e`.

[Package evidence](qa/USER_FIXES_071_PACKAGES.json) ghi bytes/cert/CRC/version/OFL/Apache/runtime/private receivers/no probes-userdata. AppWindowsx64, installerbootstrapx86/payloadx64; metadata0.7.1 lấy từ EXE, không còn số0.7.0 ghi tay. App/installerWindows chưa ký Authenticode. [Native evidence](qa/USER_FIXES_071_NATIVE.json), [local tests](qa/USER_FIXES_071.json).

## Thay đổi và nghiệm thu còn lại

SửaAsia/Saigon→Asia/Ho_Chi_Minh làm chặn lên lịch Windows, thêm JPEG/BMP, ảnh16MiB/4096², thư viện64MiB. Preview ảnh tĩnh có xóa nền màu phẳng/cắt viền local≤256px và hoàn tác. Nền phức tạp không có AI segmentation; hoạt ảnh không áp dụng. [Character formats](CHARACTER_PACKAGE.md), [backup](BACKUP_FORMAT.md).

Thiết bị AndroidOEM/Doze/reboot/máy yếu, Windows10/11/DND/DPI/file dialog thật và production signing/trust/upgrade-chain còn mở:[DEVICE_CHECKLIST](qa/DEVICE_CHECKLIST.md), [PRODUCTION_SIGNING](PRODUCTION_SIGNING.md). Giới hạn backup plaintext96MiB mới chưa nghiệm thu RAM/latency trên máy yếu; debug/synthetic measurements cũ không thay nghiệm thu này. Firebase vẫnEmulator theo lựa chọn người dùng, Live2D OFF. Automation đãtắt theo yêu cầu, không tự bật lại.

Nguồnf7fc156 thất bại enforce-lockfile trướctests; dacd03b quaappnative nhưng installermetadata0.7.0, chưa qua packagegate. Nguồn66 ở trên là gói0.7.1 đã sửa và kiểm đầy đủ các cổng tự động. Bằng chứng0–9 của0.7.0 trước đó tại qa/PHASE9_*837 và git history. Chưa coi toàn dự án nghiệm thu phát hành chính thức.
