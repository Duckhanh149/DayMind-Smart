import 'package:flutter/material.dart';

import '../../../app/controller.dart';
import '../domain/companion.dart';
import 'companion_card.dart';

class CompanionSettingsSection extends StatefulWidget {
  const CompanionSettingsSection({super.key, required this.controller});
  final WorkspaceController controller;
  @override
  State<CompanionSettingsSection> createState() =>
      _CompanionSettingsSectionState();
}

class _CompanionSettingsSectionState extends State<CompanionSettingsSection> {
  double? previewSize;
  Future<void> act(Future<void> action) async {
    try {
      await action;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller, layout = widget.controller.companionLayout;
    final images = c.importer.installed();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Hiển thị Companion'),
              subtitle: const Text('Không có âm thanh hoặc bộ nhắc riêng.'),
              value: c.preferences.companionEnabled,
              onChanged: (v) =>
                  act(c.configure((p) => p.copyWith(companionEnabled: v))),
            ),
            if (c.companionError != null)
              Text(
                c.companionError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const Divider(),
            const SizedBox(height: 12),
            Text(
              'Hồ sơ & lời thoại',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '${c.companion.name} · ${personalityLabels[c.companion.personality]}',
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const Key('edit-companion-profile'),
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => CompanionProfileEditor(controller: c),
              ),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Sửa tính cách, lời thoại & biểu cảm'),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tên, tính cách và mẫu lời thoại được đồng bộ khi dùng tài khoản. Ảnh và vị trí chỉ lưu trên thiết bị này.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 24),
            DropdownButtonFormField<CompanionPlacement>(
              key: ValueKey(layout.placement),
              isExpanded: true,
              initialValue: layout.placement,
              decoration: const InputDecoration(labelText: 'Vị trí trong thẻ'),
              items: const [
                DropdownMenuItem(
                  value: CompanionPlacement.automatic,
                  child: Text('Tự động · ưu tiên công việc'),
                ),
                DropdownMenuItem(
                  value: CompanionPlacement.left,
                  child: Text('Bên trái thẻ'),
                ),
                DropdownMenuItem(
                  value: CompanionPlacement.right,
                  child: Text('Bên phải thẻ'),
                ),
              ],
              onChanged: (v) {
                if (v != null) {
                  act(
                    c.updateCompanionLayout(
                      (current) => current.copy(placement: v),
                    ),
                  );
                }
              },
            ),
            if (layout.placement != CompanionPlacement.automatic) ...[
              const SizedBox(height: 16),
              Text(
                'Kích thước yêu cầu: ${(previewSize ?? layout.size).round()} dp',
              ),
              Slider(
                key: const Key('companion-size'),
                value: previewSize ?? layout.size,
                min: 40,
                max: 144,
                divisions: 26,
                label: '${(previewSize ?? layout.size).round()} dp',
                onChanged: (v) => setState(() => previewSize = v),
                onChangeEnd: (v) async {
                  await act(
                    c.updateCompanionLayout((current) => current.copy(size: v)),
                  );
                  if (mounted) setState(() => previewSize = null);
                },
              ),
            ],
            const SizedBox(height: 10),
            const Text(
              'Mầm tự thu nhỏ khi chữ lớn hoặc vùng thẻ chật. Thẻ không phủ lên nút thêm việc, bàn phím hoặc hộp thoại.',
              style: TextStyle(fontSize: 12),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              key: const Key('companion-low-resource'),
              value: layout.lowResource,
              title: const Text('Chế độ ít tài nguyên'),
              subtitle: const Text(
                'Thu nhỏ nhân vật, giảm ảnh giải mã và giới hạn bộ nhớ ảnh. Không tự chạy hoạt ảnh.',
              ),
              onChanged: (v) => act(
                c.updateCompanionLayout(
                  (current) => current.copy(lowResource: v),
                ),
              ),
            ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Ảnh biểu cảm trên máy này'),
              subtitle: const Text('Không tải ảnh hoặc tên tệp lên máy chủ.'),
              children: [
                for (final expression in CompanionExpression.values)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: DropdownButtonFormField<String>(
                      key: ValueKey(
                        '${expression.name}:${c.expressionAssets[expression]}:${images.length}',
                      ),
                      isExpanded: true,
                      initialValue:
                          images.contains(c.expressionAssets[expression])
                          ? c.expressionAssets[expression]
                          : '',
                      decoration: InputDecoration(
                        labelText: companionExpressionLabels[expression],
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('Dùng ảnh chính / Mầm'),
                        ),
                        for (var i = 0; i < images.length; i++)
                          DropdownMenuItem(
                            value: images[i],
                            child: Text('Nhân vật ${i + 1}'),
                          ),
                      ],
                      onChanged: (name) => act(
                        c.mapExpression(expression, name == '' ? null : name),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class CompanionProfileEditor extends StatefulWidget {
  const CompanionProfileEditor({super.key, required this.controller});
  final WorkspaceController controller;
  @override
  State<CompanionProfileEditor> createState() => _CompanionProfileEditorState();
}

class _CompanionProfileEditorState extends State<CompanionProfileEditor> {
  late final original = widget.controller.companion;
  late final name = TextEditingController(text: original.name);
  late final templates = {...original.templates};
  late final expressions = {...original.expressions};
  late Personality tone = original.personality;
  CompanionEvent event = CompanionEvent.appOpen;
  late final text = TextEditingController(text: original.templateFor(event));
  String? error;
  bool busy = false, preview = false;
  String get keyName => CompanionProfile.templateKey(tone, event);
  void stash() {
    if (text.text == defaultDialogue(event, tone)) {
      templates.remove(keyName);
    } else {
      templates[keyName] = text.text;
    }
  }

  void select({Personality? personality, CompanionEvent? selected}) {
    stash();
    setState(() {
      tone = personality ?? tone;
      event = selected ?? event;
      text.text = templates[keyName] ?? defaultDialogue(event, tone);
      preview = false;
      error = null;
    });
  }

  CompanionProfile draft() {
    stash();
    return CompanionProfile(
      name: name.text.trim(),
      personality: tone,
      templates: templates,
      expressions: expressions,
    );
  }

  Future<void> save() async {
    setState(() => error = null);
    try {
      final profile = draft();
      setState(() => busy = true);
      await widget.controller.saveCompanion(profile, expected: original);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    name.dispose();
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String? message;
    if (preview) {
      try {
        message = draft().messageFor(
          event,
          task: 'Chuẩn bị kế hoạch',
          summary: 'Hôm nay: 2 việc cần làm · 1 quá hạn',
        );
      } catch (_) {
        message = null;
      }
    }
    final expression =
        expressions[event] ?? widget.controller.companion.expressionFor(event);
    return AlertDialog(
      title: const Text('Bạn đồng hành theo ý bạn'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: const Key('companion-name'),
                controller: name,
                maxLength: 60,
                decoration: const InputDecoration(labelText: 'Tên hiển thị'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<Personality>(
                key: ValueKey(tone),
                isExpanded: true,
                initialValue: tone,
                decoration: const InputDecoration(
                  labelText: 'Tính cách dùng cho hồ sơ',
                ),
                items: [
                  for (final p in Personality.values)
                    DropdownMenuItem(
                      value: p,
                      child: Text(personalityLabels[p]!),
                    ),
                ],
                onChanged: busy
                    ? null
                    : (v) {
                        if (v != null) select(personality: v);
                      },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<CompanionEvent>(
                key: ValueKey(event),
                isExpanded: true,
                initialValue: event,
                decoration: const InputDecoration(labelText: 'Sự kiện'),
                items: [
                  for (final e in CompanionEvent.values)
                    DropdownMenuItem(
                      value: e,
                      child: Text(companionEventLabels[e]!),
                    ),
                ],
                onChanged: busy
                    ? null
                    : (v) {
                        if (v != null) select(selected: v);
                      },
              ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('companion-template'),
                controller: text,
                minLines: 3,
                maxLines: 7,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Lời thoại',
                  helperText: 'Biến hỗ trợ: {name}, {task}, {summary}',
                  helperMaxLines: 3,
                ),
                onChanged: (_) => setState(() {
                  error = null;
                }),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<CompanionExpression>(
                key: ValueKey('${event.name}:${expression.name}'),
                isExpanded: true,
                initialValue: expression,
                decoration: const InputDecoration(labelText: 'Biểu cảm'),
                items: [
                  for (final e in CompanionExpression.values)
                    DropdownMenuItem(
                      value: e,
                      child: Text(companionExpressionLabels[e]!),
                    ),
                ],
                onChanged: busy
                    ? null
                    : (v) {
                        if (v != null) setState(() => expressions[event] = v);
                      },
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: busy
                        ? null
                        : () {
                            setState(() {
                              templates.remove(keyName);
                              text.text = defaultDialogue(event, tone);
                              error = null;
                              preview = false;
                            });
                          },
                    child: const Text('Dùng lời thoại mặc định'),
                  ),
                  OutlinedButton(
                    key: const Key('preview-companion-reply'),
                    onPressed: busy
                        ? null
                        : () {
                            try {
                              draft();
                              setState(() => preview = true);
                            } catch (e) {
                              setState(() => error = '$e');
                            }
                          },
                    child: const Text('Xem trước'),
                  ),
                ],
              ),
              if (preview && message != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Column(
                    children: [
                      const Text(
                        'Bản xem trước · dữ liệu minh họa',
                        style: TextStyle(fontSize: 12),
                      ),
                      SizedBox(
                        width: 80,
                        height: 80,
                        child: MamMascot(expression: expression),
                      ),
                      Text(message),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              const Text(
                'Mỗi lời thoại cách nhau ít nhất 30 giây. Việc quá hạn chỉ gợi ý khi bạn xem, tối đa một lần/ngày. Giờ yên lặng không tự hiện lời thoại.',
                style: TextStyle(fontSize: 12),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          key: const Key('save-companion-profile'),
          onPressed: busy ? null : save,
          child: Text(busy ? 'Đang lưu…' : 'Lưu hồ sơ'),
        ),
      ],
    );
  }
}
