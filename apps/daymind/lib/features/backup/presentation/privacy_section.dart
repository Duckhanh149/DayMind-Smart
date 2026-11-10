import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../app/controller.dart';

Map<String, dynamic> diagnosticSummary(WorkspaceController c) => {
  'schema': 1,
  'appVersion': '0.7.0',
  'platform': Platform.operatingSystem,
  'build': kReleaseMode ? 'release' : 'debug',
  'databaseSchema': c.repository.db.schemaVersion,
  'notificationsGranted': c.reminders?.granted ?? false,
  'errors': {
    'reminders': c.reminders?.error != null,
    'companion': c.companionError != null,
    'floating': c.floatingError != null,
  },
};

class PrivacySection extends StatefulWidget {
  const PrivacySection({super.key, required this.controller});
  final WorkspaceController controller;
  @override
  State<PrivacySection> createState() => _PrivacySectionState();
}

class _PrivacySectionState extends State<PrivacySection> {
  bool busy = false;
  String? message;
  Future<void> export() async {
    final c = widget.controller;
    if (!c.diagnosticsConsent || busy) return;
    setState(() => busy = true);
    try {
      final saved = await FilePicker.saveFile(
        fileName: 'DayMind-diagnostics.json',
        bytes: Uint8List.fromList(
          utf8.encode(
            const JsonEncoder.withIndent('  ').convert(diagnosticSummary(c)),
          ),
        ),
      );
      if (mounted && saved != null) {
        setState(
          () => message =
              'Đã lưu chẩn đoán trên thiết bị. Chỉ chia sẻ tệp nếu bạn muốn.',
        );
      }
    } catch (_) {
      if (mounted) setState(() => message = 'Chưa lưu được tệp chẩn đoán.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Quyền riêng tư & chẩn đoán',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          const Text(
            'DayMind không quảng cáo, theo dõi vị trí hay tự gửi báo lỗi. Công việc, ảnh và lịch sử thông báo lưu trong không gian riêng trên thiết bị. Firebase Emulator chỉ nhận dữ liệu khi bạn chọn đăng nhập/đồng bộ thử nghiệm; ảnh nhân vật không được đồng bộ.',
          ),
          const SizedBox(height: 12),
          const Text(
            'Windows chỉ đọc trạng thái thông báo và hình học cửa sổ để tạm ẩn nhân vật khi tập trung/toàn màn hình; không lưu tên ứng dụng hoặc lịch sử hoạt động. Tệp sao lưu/chẩn đoán do bạn chọn nơi lưu; nhà cung cấp tệp được chọn có thể là dịch vụ đám mây của bạn.',
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: widget.controller.diagnosticsConsent,
            onChanged: busy
                ? null
                : (v) async {
                    setState(() => busy = true);
                    try {
                      await widget.controller.configureDiagnostics(v);
                    } catch (_) {
                      if (mounted) {
                        setState(
                          () => message = 'Chưa lưu được lựa chọn chẩn đoán.',
                        );
                      }
                    } finally {
                      if (mounted) setState(() => busy = false);
                    }
                  },
            title: const Text('Cho phép xuất chẩn đoán khi tôi yêu cầu'),
            subtitle: const Text(
              'Mặc định tắt. Chỉ gồm phiên bản, nền tảng, trạng thái quyền và cờ lỗi; không nội dung công việc, tài khoản, ảnh, đường dẫn hoặc thông báo lỗi thô.',
            ),
          ),
          OutlinedButton(
            onPressed: busy || !widget.controller.diagnosticsConsent
                ? null
                : export,
            child: const Text('Lưu tệp chẩn đoán để tự gửi'),
          ),
          if (message != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(message!),
            ),
        ],
      ),
    ),
  );
}
