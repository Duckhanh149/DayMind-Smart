import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../app/workspace_host.dart';
import '../../../platform/picker_cache.dart';
import '../data/backup_codec.dart';
import '../domain/backup_snapshot.dart';

class BackupPage extends StatefulWidget {
  const BackupPage({super.key, required this.host});
  final WorkspaceHost host;
  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  final password = TextEditingController(),
      confirmation = TextEditingController();
  bool busy = false, restoring = false, settings = false, rights = false;
  BackupSnapshot? preview;
  String? message, error;
  @override
  void dispose() {
    password.dispose();
    confirmation.dispose();
    super.dispose();
  }

  Future<void> run(Future<void> Function() action) async {
    setState(() {
      busy = true;
      error = null;
      message = null;
    });
    try {
      await action();
    } on BackupFailure catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Chưa thực hiện được sao lưu/khôi phục. Hãy kiểm tra dung lượng và quyền truy cập tệp; dữ liệu đang có được giữ.',
        );
      }
    } finally {
      await clearAndroidPickerCache();
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> export() => run(() async {
    BackupCodec.validatePassword(password.text);
    if (password.text != confirmation.text) {
      throw const BackupFailure('Hai mật khẩu sao lưu chưa khớp.');
    }
    final snapshot = await widget.host.captureBackup();
    final encrypted = await BackupCodec.encrypt(snapshot, password.text);
    if (!mounted) return;
    final result = await FilePicker.saveFile(
      fileName:
          'DayMind-${snapshot.createdAt.substring(0, 10)}-${snapshot.id.substring(0, 8)}.daymind',
      bytes: encrypted,
      dialogTitle: 'Lưu bản sao lưu mã hóa',
    );
    if (mounted && result != null) {
      setState(() {
        password.clear();
        confirmation.clear();
        message =
            'Đã lưu bản sao lưu mã hóa. Hãy giữ mật khẩu ở nơi riêng an toàn.';
      });
    }
  });

  Future<void> open() => run(() async {
    BackupCodec.validatePassword(password.text);
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['daymind'],
    );
    if (picked == null) return;
    if (picked.path == null) {
      throw const BackupFailure('Hãy chọn bản sao lưu trên thiết bị.');
    }
    final file = File(picked.path!);
    if (await FileSystemEntity.type(file.path, followLinks: false) !=
            FileSystemEntityType.file ||
        await file.length() > BackupCodec.maxFileBytes) {
      throw const BackupFailure(
        'Tệp sao lưu không hợp lệ hoặc lớn hơn 48 MiB.',
      );
    }
    final builder = BytesBuilder(copy: false);
    await for (final chunk in file.openRead(0, BackupCodec.maxFileBytes + 1)) {
      builder.add(chunk);
    }
    if (builder.length > BackupCodec.maxFileBytes) invalidBackup();
    final snapshot = await BackupCodec.decrypt(
      builder.takeBytes(),
      password.text,
    );
    if (snapshot.owner != widget.host.account?.uid) {
      throw const BackupFailure(
        'Hãy mở đúng tài khoản hoặc chế độ cục bộ đã tạo bản sao lưu này.',
      );
    }
    if (mounted) {
      setState(() {
        preview = snapshot;
        rights = false;
        settings = false;
        password.clear();
      });
    }
  });

  Future<void> restore() => run(() async {
    final snapshot = preview;
    if (snapshot == null || (snapshot.assets.isNotEmpty && !rights)) return;
    await widget.host.restoreBackup(snapshot, companionSettings: settings);
    if (mounted) {
      setState(() {
        preview = null;
        password.clear();
        confirmation.clear();
        message = 'Đã thêm bản sao công việc và thư viện. Nhắc việc đang tạm dừng; hãy bật lại trong Cài đặt khi sẵn sàng.';
      });
    }
  });

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: ListView(
      padding: const EdgeInsets.only(bottom: 100),
      children: [
        Text(
          'Sao lưu & khôi phục',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 16),
        const Text(
          'Tệp có mật khẩu, gồm công việc/lịch lặp, cấu hình và thư viện nhân vật của không gian đang mở. Không chứa phiên đăng nhập, mã thiết bị hoặc lịch sử thông báo. Không tự tải bản sao lưu lên mạng.',
        ),
        const SizedBox(height: 12),
        const Text(
          'Dùng mật khẩu riêng dài ít nhất 10 ký tự. DayMind không giữ mật khẩu; quên mật khẩu sẽ không mở được tệp.',
        ),
        const SizedBox(height: 20),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('Sao lưu')),
            ButtonSegment(value: true, label: Text('Khôi phục')),
          ],
          selected: {restoring},
          onSelectionChanged: busy
              ? null
              : (v) => setState(() {
                  restoring = v.single;
                  preview = null;
                  error = null;
                  message = null;
                  password.clear();
                  confirmation.clear();
                }),
        ),
        const SizedBox(height: 20),
        if (preview == null) ...[
          TextField(
            controller: password,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(labelText: 'Mật khẩu sao lưu'),
            enabled: !busy,
          ),
          if (!restoring) ...[
            const SizedBox(height: 12),
            TextField(
              controller: confirmation,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(labelText: 'Nhập lại mật khẩu'),
              enabled: !busy,
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: busy
                ? null
                : restoring
                ? open
                : export,
            icon: Icon(restoring ? Icons.folder_open_outlined : Icons.save_alt),
            label: Text(
              restoring ? 'Chọn & mở bản sao lưu' : 'Tạo bản sao lưu mã hóa',
            ),
          ),
        ] else ...[
          Text(
            'Ngày tạo: ${preview!.createdAt.substring(0, 10)} · ${preview!.taskCount} công việc (gồm thùng rác) · ${preview!.assets.length} nhân vật',
          ),
          const SizedBox(height: 12),
          const Text(
            'Khôi phục thêm bản sao với mã mới, giữ mọi công việc hiện tại. Không thể nhập bản sao lưu này lần thứ hai ở cùng không gian. Nhắc việc/tóm tắt tạm dừng sau khôi phục; không phát lại lịch cũ.',
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: settings,
            onChanged: busy
                ? null
                : (v) => setState(() => settings = v == true),
            title: const Text(
              'Khôi phục giao diện, Companion và cấu hình nhắc',
            ),
            subtitle: const Text(
              'Thay cấu hình đang dùng; nhân vật nổi vẫn tắt.',
            ),
          ),
          if (preview!.assets.isNotEmpty)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: rights,
              onChanged: busy
                  ? null
                  : (v) => setState(() => rights = v == true),
              title: const Text(
                'Tôi có quyền sử dụng các tệp nhân vật trong bản sao lưu.',
              ),
            ),
          FilledButton(
            onPressed: busy || (preview!.assets.isNotEmpty && !rights)
                ? null
                : restore,
            child: const Text('Thêm bản sao công việc'),
          ),
          TextButton(
            onPressed: busy ? null : () => setState(() => preview = null),
            child: const Text('Chọn tệp khác'),
          ),
        ],
        if (busy)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: LinearProgressIndicator(),
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (message != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(message!),
          ),
      ],
    ),
  );
}
