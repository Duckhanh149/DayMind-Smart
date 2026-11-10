import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../app/controller.dart';
import '../data/asset_importer.dart';
import '../data/character_preparer.dart';

class CharacterImportDialog extends StatefulWidget {
  const CharacterImportDialog({
    super.key,
    required this.controller,
    required this.source,
    required this.fileName,
  });
  final WorkspaceController controller;
  final File source;
  final String fileName;
  @override
  State<CharacterImportDialog> createState() => _CharacterImportDialogState();
}

class _CharacterImportDialogState extends State<CharacterImportDialog> {
  StaticAssetPreview? _prepared;
  bool _cancelled = false, _rights = false, _saving = false;
  int _done = 0, _total = 0;
  String? _error;
  @override
  void initState() {
    super.initState();
    unawaited(_prepare());
  }

  Future<void> _prepare() async {
    try {
      final preview = await widget.controller.importer.prepareCharacter(
        widget.source,
        widget.fileName,
        cancelled: () => _cancelled || !mounted,
        progress: (done, total) {
          if (mounted) {
            setState(() {
              _done = done;
              _total = total;
            });
          }
        },
      );
      if (mounted && !_cancelled) setState(() => _prepared = preview);
    } on CharacterImportCancelled {
      // Closing the preview cancels decoding without installing anything.
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _install() async {
    if (_saving || !_rights || _prepared == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final name = await widget.controller.importer.installPrepared(
        _prepared!,
        rightsConfirmed: true,
      );
      await widget.controller.configure((p) => p.copyWith(assetName: name));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '$e';
        });
      }
    }
  }

  @override
  void dispose() {
    _cancelled = true;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prepared = _prepared, meta = _prepared?.animation?.metadata;
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        title: const Text('Xem trước nhân vật'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (prepared == null && _error == null) ...[
                  LinearProgressIndicator(
                    value: _total > 0 ? _done / _total : null,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _total > 0
                        ? 'Chuẩn hóa khung $_done / $_total…'
                        : 'Kiểm tra định dạng, kích thước và checksum…',
                  ),
                ],
                if (prepared != null) ...[
                  SizedBox(
                    height: 160,
                    child: Image.memory(
                      prepared.bytes,
                      cacheWidth: 128,
                      cacheHeight: 128,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (meta != null) ...[
                    Text(
                      meta.name,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      '${meta.frames.length} khung · ${meta.motions.length} chuyển động · tối đa 12 hình/giây',
                    ),
                    const SizedBox(height: 8),
                    Text('Quyền sử dụng: ${meta.provenance.license}'),
                    if (meta.provenance.author.isNotEmpty)
                      Text('Tác giả: ${meta.provenance.author}'),
                    if (meta.provenance.source.isNotEmpty)
                      Text('Nguồn: ${meta.provenance.source}'),
                  ],
                  const SizedBox(height: 12),
                  const Text(
                    'Chỉ lưu trên thiết bị này. Ít tài nguyên: dùng ảnh tĩnh. Hoạt ảnh dừng khi bị che hoặc ra nền. Model Live2D chưa được hỗ trợ.',
                  ),
                  CheckboxListTile(
                    key: const Key('character-rights'),
                    contentPadding: EdgeInsets.zero,
                    value: _rights,
                    onChanged: _saving
                        ? null
                        : (v) => setState(() => _rights = v == true),
                    title: const Text(
                      'Tôi sở hữu hoặc có quyền sử dụng nhân vật này.',
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ],
                if (_error != null)
                  Text(
                    _error!,
                    key: const Key('character-import-error'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            key: const Key('install-character'),
            onPressed: prepared != null && _rights && !_saving
                ? _install
                : null,
            child: Text(_saving ? 'Đang lưu…' : 'Nhập & sử dụng'),
          ),
        ],
      ),
    );
  }
}
