import 'package:flutter/material.dart';

import '../application/recurrence_service.dart';
import '../domain/recurrence.dart';

const repeatLabels = ['Hằng ngày', 'Hằng tuần', 'Hằng tháng'];

Future<EditScope?> chooseEditScope(
  BuildContext context, {
  bool deleting = false,
  bool scheduleChanged = false,
}) => showDialog<EditScope>(
  context: context,
  builder: (context) => SimpleDialog(
    title: Text(deleting ? 'Xóa những lần nào?' : 'Áp dụng thay đổi cho'),
    children: [
      if (!scheduleChanged)
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, EditScope.one),
          child: const Padding(
            padding: EdgeInsets.all(8),
            child: Text('Chỉ lần này'),
          ),
        ),
      SimpleDialogOption(
        onPressed: () => Navigator.pop(context, EditScope.future),
        child: const Padding(
          padding: EdgeInsets.all(8),
          child: Text('Lần này và những lần sau'),
        ),
      ),
      SimpleDialogOption(
        onPressed: () => Navigator.pop(context, EditScope.all),
        child: const Padding(
          padding: EdgeInsets.all(8),
          child: Text('Toàn bộ chuỗi'),
        ),
      ),
      const Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Lịch sử đã hoàn thành được giữ nguyên. Các chỉnh sửa riêng của từng lần vẫn được giữ khi thay đổi mẫu chuỗi.',
        ),
      ),
    ],
  ),
);

class RecurrenceEditor extends StatefulWidget {
  const RecurrenceEditor({
    super.key,
    this.initial,
    required this.date,
    required this.zone,
    required this.onChanged,
  });
  final RepeatSpec? initial;
  final DateTime date;
  final String zone;
  final ValueChanged<RepeatChange> onChanged;
  @override
  State<RecurrenceEditor> createState() => _RecurrenceEditorState();
}

class _RecurrenceEditorState extends State<RecurrenceEditor> {
  late String frequency = widget.initial?.frequency.name ?? 'none';
  late String firstDate = widget.initial?.firstDate ?? dateKey(widget.date);
  late int minute =
      widget.initial?.minute ?? widget.date.hour * 60 + widget.date.minute;
  late int interval = widget.initial?.interval ?? 1;
  late Set<int> weekdays =
      widget.initial?.weekdays.toSet() ?? {widget.date.weekday};
  late MonthDayPolicy? policy = widget.initial?.monthPolicy;
  late String ending = widget.initial?.count != null
      ? 'count'
      : widget.initial?.until != null
      ? 'until'
      : 'never';
  late int count = widget.initial?.count ?? 10;
  late String until = widget.initial?.until ?? addDate(firstDate, 30);
  late final zone = TextEditingController(
    text: widget.initial?.zone ?? widget.zone,
  );
  @override
  void dispose() {
    zone.dispose();
    super.dispose();
  }

  void changed() {
    widget.onChanged(
      RepeatChange(
        enabled: frequency != 'none',
        spec: frequency == 'none'
            ? null
            : RepeatSpec(
                frequency: RepeatFrequency.values.byName(frequency),
                firstDate: firstDate,
                zone: zone.text.trim(),
                minute: minute,
                interval: interval,
                weekdays: weekdays.toList()..sort(),
                monthPolicy: policy,
                count: ending == 'count' ? count : null,
                until: ending == 'until' ? until : null,
              ),
      ),
    );
  }

  Future<void> pickDate(bool end) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: civilDate(end ? until : firstDate),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
    );
    if (selected != null && mounted) {
      setState(() {
        if (end) {
          until = dateKey(selected);
        } else {
          firstDate = dateKey(selected);
        }
      });
      changed();
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      DropdownButtonFormField<String>(
        key: const Key('repeat-frequency'),
        initialValue: frequency,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Lặp lại'),
        items: [
          const DropdownMenuItem(value: 'none', child: Text('Không lặp')),
          for (final f in RepeatFrequency.values)
            DropdownMenuItem(value: f.name, child: Text(repeatLabels[f.index])),
        ],
        onChanged: (value) {
          setState(() => frequency = value!);
          changed();
        },
      ),
      if (frequency != 'none') ...[
        const SizedBox(height: 12),
        TextFormField(
          key: const Key('repeat-interval'),
          initialValue: '$interval',
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText:
                'Mỗi bao nhiêu ${frequency == 'daily'
                    ? 'ngày'
                    : frequency == 'weekly'
                    ? 'tuần'
                    : 'tháng'}?',
          ),
          onChanged: (value) {
            interval = int.tryParse(value) ?? 0;
            changed();
          },
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => pickDate(false),
          icon: const Icon(Icons.event_repeat),
          label: Text('Ngày bắt đầu chuỗi: $firstDate'),
        ),
        if (frequency == 'weekly')
          Wrap(
            spacing: 6,
            children: [
              for (var d = 1; d <= 7; d++)
                FilterChip(
                  label: Text(d == 7 ? 'CN' : 'T${d + 1}'),
                  selected: weekdays.contains(d),
                  onSelected: (value) {
                    setState(() {
                      value ? weekdays.add(d) : weekdays.remove(d);
                    });
                    changed();
                  },
                ),
            ],
          ),
        if (frequency == 'monthly') ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<MonthDayPolicy>(
            key: const Key('month-day-policy'),
            initialValue: policy,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Khi tháng không có ngày này *',
            ),
            items: const [
              DropdownMenuItem(
                value: MonthDayPolicy.skip,
                child: Text('Bỏ qua tháng đó'),
              ),
              DropdownMenuItem(
                value: MonthDayPolicy.lastDay,
                child: Text('Dùng ngày cuối tháng'),
              ),
            ],
            onChanged: (value) {
              setState(() => policy = value);
              changed();
            },
          ),
        ],
        const SizedBox(height: 12),
        TextField(
          controller: zone,
          decoration: const InputDecoration(
            labelText: 'Múi giờ IANA',
            helperText: 'Ví dụ: Asia/Ho_Chi_Minh, America/New_York',
          ),
          onChanged: (_) => changed(),
        ),
        OutlinedButton(
          onPressed: () async {
            final time = await showTimePicker(
              context: context,
              initialTime: TimeOfDay(hour: minute ~/ 60, minute: minute % 60),
            );
            if (time != null && mounted) {
              setState(() => minute = time.hour * 60 + time.minute);
              changed();
            }
          },
          child: Text(
            'Giờ mặc định khi chưa có lịch: ${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}',
          ),
        ),
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: ending,
          decoration: const InputDecoration(labelText: 'Kết thúc chuỗi'),
          items: const [
            DropdownMenuItem(
              value: 'never',
              child: Text('Không đặt ngày kết thúc'),
            ),
            DropdownMenuItem(value: 'count', child: Text('Sau một số lần')),
            DropdownMenuItem(value: 'until', child: Text('Đến hết một ngày')),
          ],
          onChanged: (value) {
            setState(() => ending = value!);
            changed();
          },
        ),
        if (ending == 'count')
          TextFormField(
            key: const Key('repeat-count'),
            initialValue: '$count',
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Số lần (1–10.000)'),
            onChanged: (value) {
              count = int.tryParse(value) ?? 0;
              changed();
            },
          ),
        if (ending == 'until')
          OutlinedButton(
            onPressed: () => pickDate(true),
            child: Text('Đến hết ngày: $until'),
          ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'Giờ chuỗi theo múi giờ trên. Lịch thực hiện giữ thời lượng; hạn hoàn thành dịch theo ngày. Giờ bị bỏ qua do DST chuyển tới phút hợp lệ kế tiếp; giờ trùng chọn lần đầu.',
            style: TextStyle(fontSize: 12),
          ),
        ),
      ],
    ],
  );
}
