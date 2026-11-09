import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/workspace_host.dart';
import '../application/sync_service.dart';
import '../data/sync_store.dart';
import '../domain/account.dart';
import '../domain/sync_record.dart';
import '../../companion/domain/companion.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key, required this.host});
  final WorkspaceHost host;
  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final email = TextEditingController(), password = TextEditingController();
  final form = GlobalKey<FormState>();
  bool create = false, copyLocal = false, busy = false;
  String? error;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> run(Future<void> Function() action) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
    } on AccountFailure catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Chưa thực hiện được. Nội dung trên thiết bị vẫn được giữ.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> deleteAccount() async {
    final secret = TextEditingController();
    bool confirmed = false;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Xóa tài khoản thử nghiệm?'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Xóa công việc, lịch lặp, cấu hình nhắc và thư viện nhân vật trong không gian tài khoản này. Dữ liệu cục bộ trước khi đăng nhập vẫn được giữ. Thao tác không có nút hoàn tác.',
                ),
                const SizedBox(height: 12),
                const Text(
                  'Máy chủ giữ một dấu đã xóa theo mã tài khoản, không chứa email hoặc nội dung công việc, để ngăn thiết bị cũ tải dữ liệu lên lại.',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: secret,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(
                    labelText: 'Nhập lại mật khẩu thử nghiệm',
                  ),
                  onChanged: (_) => update(() {}),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: confirmed,
                  onChanged: (v) => update(() => confirmed = v == true),
                  title: const Text('Tôi hiểu dữ liệu tài khoản sẽ bị xóa.'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: confirmed && secret.text.isNotEmpty
                  ? () => Navigator.pop(context, true)
                  : null,
              child: const Text('Xóa tài khoản'),
            ),
          ],
        ),
      ),
    );
    final value = secret.text;
    secret.dispose();
    if (accepted == true && mounted) {
      await run(() => widget.host.deleteAccount(value));
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.host,
    builder: (context, _) {
      final host = widget.host, service = host.sync, account = host.account;
      return ListView(
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          Text(
            'Tài khoản & đồng bộ',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Firebase Emulator · thử nghiệm',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Dùng email và mật khẩu thử, không dùng mật khẩu thật. Chưa kết nối Firebase chính thức. Trên Android Emulator, máy chủ chạy trên máy tính phát triển; trên Windows, máy chủ chạy trên chính máy đó. Dữ liệu cục bộ dùng được khi không có máy chủ.',
                  ),
                ],
              ),
            ),
          ),
          if (host.sessionError != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(host.sessionError!),
            ),
          const SizedBox(height: 16),
          if (account == null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        create ? 'Tạo tài khoản thử' : 'Đăng nhập để đồng bộ',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const Key('account-email'),
                        controller: email,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.username],
                        decoration: const InputDecoration(
                          labelText: 'Email thử nghiệm',
                        ),
                        validator: (v) =>
                            v != null &&
                                v.trim().contains('@') &&
                                v.length <= 320
                            ? null
                            : 'Nhập email hợp lệ.',
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        key: const Key('account-password'),
                        controller: password,
                        obscureText: true,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: const InputDecoration(
                          labelText: 'Mật khẩu thử nghiệm',
                        ),
                        validator: (v) =>
                            v != null && v.length >= 6 && v.length <= 256
                            ? null
                            : 'Mật khẩu cần từ 6 đến 256 ký tự.',
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: create,
                        onChanged: busy
                            ? null
                            : (v) => setState(() => create = v),
                        title: const Text('Tạo tài khoản mới'),
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: copyLocal,
                        onChanged: busy
                            ? null
                            : (v) => setState(() => copyLocal = v == true),
                        title: const Text(
                          'Sao chép và đồng bộ công việc cục bộ',
                        ),
                        subtitle: const Text(
                          'Bao gồm danh mục, lịch lặp, thùng rác và cấu hình nhắc. Giữ nguyên bản cục bộ; không sao chép ảnh nhân vật. Bỏ chọn để dùng không gian tài khoản riêng.',
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        key: const Key('account-submit'),
                        onPressed: busy
                            ? null
                            : () {
                                if (form.currentState!.validate()) {
                                  run(
                                    () => host.signIn(
                                      email.text.trim(),
                                      password.text,
                                      create: create,
                                      copyLocal: copyLocal,
                                    ),
                                  );
                                }
                              },
                        child: Text(
                          busy
                              ? 'Đang kết nối…'
                              : create
                              ? 'Tạo & đồng bộ'
                              : 'Đăng nhập & đồng bộ',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      account.email,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    Text(switch (service?.state) {
                      SyncState.working => 'Đang đồng bộ…',
                      SyncState.offline =>
                        'Đang ngoại tuyến · thay đổi được giữ trên thiết bị',
                      SyncState.attention => 'Cần kiểm tra đồng bộ',
                      _ =>
                        service?.pendingCount == 0 &&
                                service?.lastSynced != null
                            ? 'Đã đồng bộ'
                            : 'Đang chờ kết nối',
                    }),
                    if (service != null)
                      Text(
                        '${service.pendingCount} thay đổi đang chờ · ${service.conflictCount} xung đột',
                      ),
                    if (service?.message != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(service!.message!),
                      ),
                    const SizedBox(height: 16),
                    const Text(
                      'Hồ sơ Companion đồng bộ tên, tính cách, lời thoại và biểu cảm. Ảnh, vị trí, kích thước và chế độ ít tài nguyên chỉ lưu trên từng thiết bị.',
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: busy || service == null
                          ? null
                          : () => run(service.sync),
                      child: const Text('Đồng bộ ngay'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: busy || service == null
                          ? null
                          : () => run(() => host.notificationDevice(true)),
                      child: Text(
                        service?.primaryHere == true
                            ? 'Thiết bị nhận nhắc chính: máy này'
                            : 'Chọn máy này nhận nhắc chính',
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Khi kết nối, chỉ thiết bị chính nhận nhắc. Thiết bị chính cũ đang mất mạng có thể còn báo theo lịch đã lưu cho đến khi kết nối lại; không tự chuyển thiết bị chính.',
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: busy ? null : () => run(host.signOut),
                      child: const Text('Đăng xuất · trở về dữ liệu cục bộ'),
                    ),
                    const Text(
                      'Thay đổi chưa gửi được giữ trong không gian tài khoản trên máy và tiếp tục khi đăng nhập lại.',
                    ),
                    TextButton(
                      onPressed: busy ? null : deleteAccount,
                      child: const Text('Xóa tài khoản & dữ liệu tài khoản'),
                    ),
                  ],
                ),
              ),
            ),
            if (service != null) _ConflictList(service: service, run: run),
          ],
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      );
    },
  );
}

class _ConflictList extends StatefulWidget {
  const _ConflictList({required this.service, required this.run});
  final SyncService service;
  final Future<void> Function(Future<void> Function()) run;
  @override
  State<_ConflictList> createState() => _ConflictListState();
}

class _ConflictListState extends State<_ConflictList> {
  late Future<List<ConflictHeader>> rowsFuture;
  StreamSubscription<void>? subscription;
  SyncService get service => widget.service;
  @override
  void initState() {
    super.initState();
    watch();
  }

  void watch() {
    rowsFuture = service.store.conflicts(history: true);
    subscription = service.changes.listen((_) {
      if (mounted) {
        setState(() {
          rowsFuture = service.store.conflicts(history: true);
        });
      }
    });
  }

  @override
  void didUpdateWidget(_ConflictList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service != service) {
      unawaited(subscription?.cancel());
      watch();
    }
  }

  @override
  void dispose() {
    unawaited(subscription?.cancel());
    super.dispose();
  }

  Future<void> open(BuildContext context, ConflictHeader h) async {
    final c = await service.store.conflict(h.id);
    if (c == null || !context.mounted) return;
    final categories = {
      for (final value in await service.store.repository.categories())
        value.id: value.name,
    };
    if (!context.mounted) return;
    final choice = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          h.status == 'active'
              ? 'Chọn bản muốn tiếp tục dùng'
              : 'Bản lưu xung đột',
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Bản trên thiết bị',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(describeRecord(c.local, categories: categories)),
              const Divider(),
              const Text(
                'Bản máy chủ',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                c.remote == null
                    ? 'Không còn bản máy chủ.'
                    : describeRecord(c.remote!.record, categories: categories),
              ),
              const SizedBox(height: 12),
              const Text(
                'Cả hai bản được giữ trong lịch sử xung đột sau khi chọn.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
          if (h.status == 'active') ...[
            TextButton(
              onPressed: c.remote == null
                  ? null
                  : () => Navigator.pop(context, false),
              child: const Text('Dùng bản máy chủ'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Giữ bản thiết bị'),
            ),
          ],
        ],
      ),
    );
    if (choice != null) {
      await widget.run(() => service.resolve(h.id, keepLocal: choice));
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<ConflictHeader>>(
    future: rowsFuture,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return ListTile(
          title: const Text('Chưa tải được bản lưu xung đột.'),
          trailing: TextButton(
            onPressed: () => setState(() {
              rowsFuture = service.store.conflicts(history: true);
            }),
            child: const Text('Thử lại'),
          ),
        );
      }
      if (!snapshot.hasData) {
        return const Padding(
          padding: EdgeInsets.all(16),
          child: LinearProgressIndicator(),
        );
      }
      final rows = snapshot.data ?? [];
      if (rows.isEmpty) return const SizedBox.shrink();
      return Card(
        child: ExpansionTile(
          initiallyExpanded: rows.any((h) => h.status == 'active'),
          title: const Text('Xung đột & bản lưu'),
          children: [
            for (final h in rows)
              ListTile(
                title: Text(h.label),
                subtitle: Text(
                  h.status == 'active'
                      ? 'Cần chọn bản tiếp tục dùng'
                      : 'Đã xử lý · giữ cả hai bản',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => open(context, h),
              ),
          ],
        ),
      );
    },
  );
}

String describeRecord(
  SyncRecord r, {
  Map<String, String> categories = const {},
}) {
  if (r.deleted) return 'Đã bỏ cấu hình hoặc ngoại lệ riêng.';
  final d = r.data;
  const words = {
    'todo': 'Cần làm',
    'inProgress': 'Đang làm',
    'completed': 'Đã hoàn thành',
    'cancelled': 'Đã hủy',
    'skipped': 'Bỏ qua',
    'low': 'Thấp',
    'medium': 'Vừa',
    'high': 'Cao',
    'auto': 'Tự động',
    'off': 'Tắt',
    'custom': 'Tự đặt',
    'daily': 'Hằng ngày',
    'weekly': 'Hằng tuần',
    'monthly': 'Hằng tháng',
  };
  String word(Object? v) => words[v] ?? '$v';
  String time(Object? raw) {
    if (raw == null) return 'không đặt';
    final t = DateTime.parse(raw as String).toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)} · ${two(t.day)}/${two(t.month)}/${t.year}';
  }

  String field(String name, Object? value) => switch (name) {
    'title' => 'Tên: $value',
    'description' => 'Mô tả: $value',
    'priority' => 'Ưu tiên: ${word(value)}',
    'categoryId' =>
      'Danh mục: ${value == null ? 'không chọn' : categories[value] ?? 'chưa tải tên danh mục'}',
    'dueAt' => 'Hạn: ${time(value)}',
    'scheduledStartAt' => 'Bắt đầu: ${time(value)}',
    'scheduledEndAt' => 'Kết thúc: ${time(value)}',
    _ => '',
  };
  String draft(Map<dynamic, dynamic> j) => [
    '${j['title']}',
    if ((j['description'] as String? ?? '').isNotEmpty) '${j['description']}',
    'Trạng thái: ${word(j['status'] ?? 'todo')} · Ưu tiên: ${word(j['priority'] ?? 'medium')}',
    field('categoryId', j['categoryId']),
    field('dueAt', j['dueAt']),
    field('scheduledStartAt', j['scheduledStartAt']),
    field('scheduledEndAt', j['scheduledEndAt']),
  ].join('\n');
  return switch (r.kind) {
    SyncKind.task =>
      '${draft(d)}${d['deletedAt'] != null ? '\nĐang ở thùng rác' : ''}\nSửa lúc: ${time(d['updatedAt'])}',
    SyncKind.category => '${d['name']}',
    SyncKind.recurrence =>
      (d['rules'] as List)
          .map((raw) {
            final j = raw as Map, spec = j['spec'] as Map;
            final days = (spec['weekdays'] as List? ?? [])
                .map((v) => v == 7 ? 'Chủ nhật' : 'Thứ ${(v as int) + 1}')
                .join(', ');
            return [
              '${j['enabled'] == true ? 'Đang áp dụng' : 'Đã dừng'} · ${word(spec['frequency'])} · khoảng lặp ${spec['interval']}',
              'Từ ${spec['firstDate']} · ${spec['zone']}',
              if (days.isNotEmpty) days,
              if (spec['until'] != null) 'Kết thúc ${spec['until']}',
              if (spec['count'] != null) '${spec['count']} lần',
              if (j['activeFrom'] != null) 'Áp dụng từ ${j['activeFrom']}',
              if (j['cutoff'] != null) 'Áp dụng đến ${j['cutoff']}',
              if (spec['frequency'] == 'monthly')
                spec['monthPolicy'] == 'lastDay'
                    ? 'Dùng ngày cuối tháng nếu thiếu ngày'
                    : 'Bỏ qua tháng thiếu ngày',
              draft(j['template'] as Map),
            ].join('\n');
          })
          .join('\n\n'),
    SyncKind.occurrence =>
      '${d['date']} · ${word(d['status'])}${d['deleted'] == true ? ' · Đã xóa lần này' : ''}\n${d['draft'] != null ? draft(d['draft'] as Map) : (d['overrides'] as Map).entries.map((e) => field(e.key as String, e.value)).join('\n')}',
    SyncKind.reminderConfig =>
      'Chế độ: ${word(d['mode'])}\n${(d['rules'] as List).map((raw) {
        final j = raw as Map;
        final when = j['kind'] == 'absolute' ? time(j['absoluteAt']) : 'Trước ${j['kind'] == 'due' ? 'hạn' : 'giờ bắt đầu'} ${j['offsetMinutes']} phút';
        return '${j['enabled'] == true ? 'Bật' : 'Tắt'} · $when';
      }).join('\n')}',
    SyncKind.companionProfile => _describeCompanion(d),
  };
}

String _describeCompanion(Map<String, dynamic> data) {
  final profile = CompanionProfile.fromJson(data);
  return [
    profile.name,
    'Tính cách: ${personalityLabels[profile.personality]}',
    for (final event in CompanionEvent.values)
      '${companionEventLabels[event]}: ${companionExpressionLabels[profile.expressionFor(event)]}',
    for (final p in Personality.values)
      for (final event in CompanionEvent.values)
        if (profile.templates.containsKey(
          CompanionProfile.templateKey(p, event),
        ))
          '${personalityLabels[p]} · ${companionEventLabels[event]}\n${profile.templateFor(event, tone: p)}',
  ].join('\n\n');
}
