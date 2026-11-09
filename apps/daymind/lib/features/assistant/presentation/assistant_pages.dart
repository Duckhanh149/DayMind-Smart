import 'package:flutter/material.dart';

import '../../../app/controller.dart';
import '../../recurrence/domain/recurrence.dart';
import '../../tasks/presentation/task_editor.dart';
import '../domain/daily_assistant.dart';

Future<void> editDashboard(
  BuildContext context,
  WorkspaceController controller,
) async {
  final chosen = {...controller.dashboard.cards};
  bool saving = false;
  await showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, update) => AlertDialog(
        title: const Text('Trang hôm nay của bạn'),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final card in dashboardCards.entries)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(card.value),
                    value: chosen.contains(card.key),
                    onChanged: saving
                        ? null
                        : (value) => update(() {
                            value == true
                                ? chosen.add(card.key)
                                : chosen.remove(card.key);
                          }),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: saving ? null : () => Navigator.pop(context),
            child: const Text('Để sau'),
          ),
          FilledButton(
            onPressed: saving
                ? null
                : () async {
                    update(() => saving = true);
                    try {
                      await controller.configureDashboard(chosen);
                      if (context.mounted) Navigator.pop(context);
                    } catch (e) {
                      if (context.mounted) {
                        update(() => saving = false);
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text('$e')));
                      }
                    }
                  },
            child: const Text('Lưu bố cục'),
          ),
        ],
      ),
    ),
  );
}

class FocusSuggestions extends StatelessWidget {
  const FocusSuggestions({super.key, required this.controller});
  final WorkspaceController controller;
  @override
  Widget build(BuildContext context) {
    final zone = controller.reminders?.preferences.timezoneId ?? 'UTC';
    final suggestions = suggestTasks(
      controller.visibleTasks,
      controller.now(),
      zone,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Một việc để bắt đầu',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            const Text(
              'Gợi ý theo hạn, mức ưu tiên và trạng thái bạn đã đặt. Bạn chọn nhịp độ của mình.',
              style: TextStyle(fontSize: 12),
            ),
            if (suggestions.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Text(
                  'Chưa có việc phù hợp để gợi ý. Bạn có thể nghỉ ngơi hoặc thêm một việc mới.',
                ),
              ),
            for (final s in suggestions)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.arrow_outward_rounded),
                title: Text(s.task.title),
                subtitle: Text(s.reason),
                onTap: () => showTaskEditor(context, task: s.task),
              ),
          ],
        ),
      ),
    );
  }
}

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key, required this.controller});
  final WorkspaceController controller;
  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  int days = 7;
  String percent(double? value) =>
      value == null ? 'Chưa có dữ liệu' : '${(value * 100).round()}%';
  Widget metric(String label, String value, String detail) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 10),
          Text(value, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(detail, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final c = widget.controller,
        now = c.now(),
        zone = c.reminders?.preferences.timezoneId ?? 'UTC';
    final through = localDay(now, zone), from = addDate(through, 1 - days);
    final data = AnalyticsSnapshot.calculate(
      c.visibleTasks,
      from: from,
      through: through,
      zone: zone,
      now: now,
    );
    final max = data.completionsByDay.values.fold(1, (a, b) => a > b ? a : b);
    return ListView(
      key: const Key('analytics-page'),
      padding: const EdgeInsets.only(bottom: 110),
      children: [
        Text(
          'Tiến bộ theo nhịp của bạn',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text('$from đến $through · $zone'),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          children: [
            for (final n in [7, 30])
              ChoiceChip(
                label: Text('$n ngày'),
                selected: days == n,
                onSelected: (_) => setState(() => days = n),
              ),
          ],
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth > 760 ? 2 : 1;
            final width = (constraints.maxWidth - 12 * (columns - 1)) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: width,
                  child: metric(
                    'Đã hoàn thành trong kỳ',
                    '${data.completed}',
                    'Dựa trên ngày hoàn thành; mỗi lần lặp được tính riêng.',
                  ),
                ),
                SizedBox(
                  width: width,
                  child: metric(
                    'Hoàn thành việc có hạn trong kỳ',
                    percent(data.dueCompletionRate),
                    '${data.dueCompleted}/${data.dueCount} việc có hạn trong khoảng ngày đã chọn hiện đã xong. Việc không có hạn không nằm trong mẫu số.',
                  ),
                ),
                SizedBox(
                  width: width,
                  child: metric(
                    'Đúng hạn khi hoàn thành',
                    percent(data.onTimeRate),
                    '${data.onTime}/${data.withDeadline} việc hoàn thành trong kỳ và có hạn. Đúng hạn nghĩa là hoàn thành trước hoặc đúng hạn.',
                  ),
                ),
                SizedBox(
                  width: width,
                  child: metric(
                    'Đang quá hạn',
                    '${data.overdue}',
                    'Số hiện tại trên mọi ngày, không phải lịch sử của khoảng đã chọn.',
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Những việc đã hoàn thành',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Mở lại một việc sẽ cập nhật số đã hoàn thành. Việc đã hủy và trong thùng rác không được tính.',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 14),
                for (final day in data.completionsByDay.entries)
                  Semantics(
                    label: '${day.key}: ${day.value} việc đã hoàn thành',
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 72,
                            child: Text(
                              '${day.key.substring(8)}/${day.key.substring(5, 7)}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          Expanded(
                            child: LinearProgressIndicator(
                              value: day.value / max,
                              minHeight: 10,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text('${day.value}'),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Hoàn thành theo danh mục',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                if (data.completedByCategory.isEmpty)
                  const Text('Chưa có công việc hoàn thành trong khoảng này.'),
                for (final item in data.completedByCategory.entries)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      c.categories
                              .where((x) => x.id == item.key)
                              .firstOrNull
                              ?.name ??
                          'Hộp thư',
                    ),
                    trailing: Text('${item.value}'),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        FocusSuggestions(controller: c),
      ],
    );
  }
}
