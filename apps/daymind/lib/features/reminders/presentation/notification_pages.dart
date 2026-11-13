import 'package:flutter/material.dart';

import '../../../app/controller.dart';
import '../../tasks/data/database.dart';
import '../../tasks/presentation/task_editor.dart';
import '../application/reminder_coordinator.dart';
import '../domain/reminder.dart';
import '../../../platform/window_lifecycle.dart';
import '../../../platform/notification_scheduler.dart';

class NotificationSettingsSection extends StatelessWidget {
  const NotificationSettingsSection({
    super.key,
    required this.reminders,
    this.window,
  });
  final ReminderCoordinator reminders;
  final WindowLifecycle? window;
  Future<void> _run(BuildContext context, Future<void> action) async {
    try {
      await action;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _time(BuildContext context, String key, int minute) async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minute ~/ 60, minute: minute % 60),
    );
    if (time != null && context.mounted) {
      await _run(
        context,
        reminders.configure({key: time.hour * 60 + time.minute}),
      );
    }
  }

  String _clock(int minute) =>
      '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}';
  @override
  Widget build(BuildContext context) {
    final prefs = reminders.preferences;
    final scheduler = reminders.engine.scheduler;
    final osSetting = scheduler is PlatformNotificationScheduler
        ? scheduler.osSetting
        : window?.notificationSetting;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Nhắc đúng lúc, không làm phiền',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Text(
              reminders.granted ? 'Thông báo đã sẵn sàng.' : 'Chưa có quyền hoặc kênh thông báo đang tắt. Công việc vẫn dùng bình thường.',
            ),
            if (!reminders.granted) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _run(context, reminders.requestPermission()),
                icon: const Icon(Icons.notifications_active_outlined),
                label: Text(
                  prefs.permissionPrompted
                      ? 'Mở cài đặt thông báo'
                      : 'Cho phép thông báo',
                ),
              ),
            ],
            const SizedBox(height: 16),
            DropdownButtonFormField<ReminderPreset>(
              initialValue: prefs.preset,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Chế độ nhắc'),
              items: const [
                DropdownMenuItem(
                  value: ReminderPreset.minimal,
                  child: Text('Tối giản'),
                ),
                DropdownMenuItem(
                  value: ReminderPreset.normal,
                  child: Text('Bình thường'),
                ),
                DropdownMenuItem(
                  value: ReminderPreset.custom,
                  child: Text('Tùy chỉnh'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  _run(context, reminders.configure({'preset': value.name}));
                }
              },
            ),
            const SizedBox(height: 8),
            Text(switch (prefs.preset) {
              ReminderPreset.minimal =>
                'Chỉ nhắc khi bạn đặt riêng cho công việc.',
              ReminderPreset.normal => 'Một nhắc trước hạn: ưu tiên cao 30 phút, vừa 15 phút, thấp đúng hạn.',
              ReminderPreset.custom => 'Chọn khoảng nhắc mặc định trước hạn.',
            }, style: Theme.of(context).textTheme.bodySmall),
            if (prefs.preset == ReminderPreset.custom)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: TextFormField(
                  initialValue: '${prefs.defaultOffsetMinutes}',
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Số phút trước hạn',
                  ),
                  onFieldSubmitted: (value) => _run(
                    context,
                    reminders.configure({
                      'defaultOffsetMinutes': int.tryParse(value) ?? -1,
                    }),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: prefs.digestEnabled,
              title: const Text('Bản tóm tắt hằng ngày'),
              subtitle: const Text(
                'Mỗi ngày một bản khi bạn bật. Xem số việc hôm nay và quá hạn; không tạo thêm chuỗi nhắc quá hạn.',
              ),
              onChanged: (value) =>
                  _run(context, reminders.configure({'digestEnabled': value})),
            ),
            if (prefs.digestEnabled)
              OutlinedButton(
                onPressed: () =>
                    _time(context, 'digestMinute', prefs.digestMinute),
                child: Text(
                  'Giờ tóm tắt: ${_clock(prefs.digestMinute)} · giờ thiết bị',
                ),
              ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: prefs.primaryDevice,
              title: const Text('Nhắc trên thiết bị này'),
              subtitle: const Text(
                'Tắt để giữ công việc và lịch sử trong ứng dụng mà không phát thông báo OS.',
              ),
              onChanged: (value) =>
                  _run(context, reminders.configure({'primaryDevice': value})),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Giờ yên lặng'),
              subtitle: const Text(
                'Không vượt chế độ Không làm phiền của hệ điều hành.',
              ),
              value: prefs.quietEnabled,
              onChanged: (value) =>
                  _run(context, reminders.configure({'quietEnabled': value})),
            ),
            if (prefs.quietEnabled)
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton(
                    onPressed: () =>
                        _time(context, 'quietStart', prefs.quietStart),
                    child: Text('Từ ${_clock(prefs.quietStart)}'),
                  ),
                  OutlinedButton(
                    onPressed: () => _time(context, 'quietEnd', prefs.quietEnd),
                    child: Text('Đến ${_clock(prefs.quietEnd)}'),
                  ),
                ],
              ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              isExpanded: true,
              initialValue: prefs.groupingMinutes,
              decoration: const InputDecoration(labelText: 'Gộp nhắc gần nhau'),
              items: [1, 5, 10, 15, 30, 60]
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text('Cửa sổ $value phút'),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  _run(
                    context,
                    reminders.configure({'groupingMinutes': value}),
                  );
                }
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Múi giờ: ${prefs.timezoneId}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Text(
              reminders.engine.scheduler.supportsClosedApp
                  ? 'Android dùng lịch nhắc không chính xác tuyệt đối; hệ điều hành có thể trì hoãn. Không yêu cầu quyền báo thức chính xác hoặc bỏ qua tiết kiệm pin. Buộc dừng (Force stop) trong cài đặt Android sẽ chặn nhắc cho tới khi mở lại app.'
                  : '${window?.notificationLifetime ?? 'Windows chỉ tiếp tục nhắc khi DayMind còn chạy trong khay.'} Thoát hẳn, kết thúc tiến trình, đăng xuất hoặc khởi động lại: không có nhắc nền. DayMind không tự khởi động cùng Windows. Khi app đang ở trước màn hình, lời nhắc hiện trong app; hệ điều hành có thể không hiện banner khi Không làm phiền.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (window != null) ...[
              const SizedBox(height: 8),
              Text(
                'Quyền thông báo Windows: ${switch (osSetting) {
                  0 => 'được phép',
                  1 || 2 || 3 || 4 => 'đang bị chặn bởi cài đặt hoặc chính sách hệ điều hành',
                  _ => 'chưa xác minh được',
                }}. Gửi thành công không xác nhận banner đã hiện.',
              ),
              OutlinedButton(
                onPressed: () =>
                    _run(context, window!.openNotificationSettings()),
                child: const Text('Mở cài đặt thông báo Windows'),
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _run(context, reminders.test()),
              icon: const Icon(Icons.notifications_none),
              label: const Text('Hiện một thông báo thử im lặng'),
            ),
            if (reminders.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'Chưa lên lịch được: ${reminders.error}',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class NotificationCenterPage extends StatefulWidget {
  const NotificationCenterPage({super.key, required this.controller});
  final WorkspaceController controller;
  @override
  State<NotificationCenterPage> createState() => _NotificationCenterPageState();
}

class _NotificationCenterPageState extends State<NotificationCenterPage> {
  bool unread = false, overdue = false;
  Future<void> _run(Future<void> action) async {
    try {
      await action;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  static const labels = {
    'planned': 'Chờ quyền / lịch nền',
    'scheduled': 'Đã lên lịch',
    'unknown': 'Đã tới giờ · chưa xác nhận hiển thị OS',
    'dismissed': 'Đã bỏ qua',
    'snoozed': 'Đã hoãn',
    'cancelled': 'Đã hủy lịch cũ',
    'suppressed': 'Không làm phiền',
    'expired': 'Đã hết thời điểm nhắc',
  };
  Widget item(ReminderEventRecord event, ReminderCoordinator service) {
    final task = widget.controller.visibleTasks
        .where((t) => t.id == (event.occurrenceId ?? event.taskId))
        .firstOrNull;
    final active =
        task != null &&
        !task.terminal &&
        task.deletedAt == null &&
        task.reminderRevision == event.taskRevision &&
        (event.occurrenceId == null ||
            task.revision == event.occurrenceRevision);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (event.ruleId == 'digest')
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    '☀ Bản tóm tắt hằng ngày',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              Text(event.title, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 6),
              Text(
                '${service.localTime(event.scheduledMs)} · ${labels[event.state] ?? event.state}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (task != null && task.deletedAt == null)
                    TextButton(
                      onPressed: () => showTaskEditor(context, task: task),
                      child: const Text('Mở công việc'),
                    ),
                  if (!event.read)
                    TextButton(
                      onPressed: () => _run(service.markRead(event)),
                      child: const Text('Đánh dấu đã đọc'),
                    ),
                  if (![
                    'cancelled',
                    'expired',
                    'dismissed',
                    'snoozed',
                  ].contains(event.state))
                    TextButton(
                      onPressed: () => _run(service.dismiss(event)),
                      child: const Text('Bỏ qua'),
                    ),
                  if (active &&
                      [
                        'planned',
                        'scheduled',
                        'unknown',
                        'suppressed',
                      ].contains(event.state))
                    PopupMenuButton<int>(
                      tooltip: 'Hoãn nhắc',
                      onSelected: (minutes) => _run(
                        service.snooze(event, Duration(minutes: minutes)),
                      ),
                      itemBuilder: (_) => [10, 30, 60]
                          .map(
                            (minutes) => PopupMenuItem(
                              value: minutes,
                              child: Text('Hoãn $minutes phút'),
                            ),
                          )
                          .toList(),
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text('Hoãn…'),
                      ),
                    ),
                  if (active)
                    FilledButton.tonalIcon(
                      onPressed: () => _run(widget.controller.toggle(task)),
                      icon: const Icon(Icons.check),
                      label: const Text('Hoàn thành'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = widget.controller.reminders;
    if (service == null) {
      return const Center(child: Text('Thông báo chưa được khởi tạo.'));
    }
    final events = service.events
        .where(
          (e) =>
              (!unread || (!e.read && e.state == 'unknown')) &&
              (!overdue ||
                  widget.controller.visibleTasks.any(
                    (t) =>
                        t.id == (e.occurrenceId ?? e.taskId) &&
                        t.overdue(widget.controller.now()),
                  )),
        )
        .toList();
    return ListView(
      padding: const EdgeInsets.only(bottom: 100),
      children: [
        Text(
          'Trung tâm thông báo',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 12),
        const Text(
          'Bỏ qua không hoàn thành công việc. Không nhắc quá hạn lặp lại tự động.',
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Tất cả'),
              selected: !unread,
              onSelected: (_) => setState(() => unread = false),
            ),
            ChoiceChip(
              label: const Text('Chưa đọc'),
              selected: unread,
              onSelected: (_) => setState(() => unread = true),
            ),
            FilterChip(
              label: const Text('Quá hạn'),
              selected: overdue,
              onSelected: (value) => setState(() => overdue = value),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (events.isEmpty)
          const Padding(
            padding: EdgeInsets.all(28),
            child: Text('Chưa có sự kiện nhắc phù hợp.'),
          ),
        for (final event in events) item(event, service),
        const SizedBox(height: 20),
        NotificationSettingsSection(reminders: service),
      ],
    );
  }
}
