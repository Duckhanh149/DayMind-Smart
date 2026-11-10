import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart'
    show RenderAbstractViewport, RenderBox, MatrixUtils;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/controller.dart';
import '../../../app/workspace_host.dart';
import '../../../platform/picker_cache.dart';
import '../../backup/presentation/backup_page.dart';
import '../../backup/presentation/privacy_section.dart';
import '../../account_sync/presentation/account_page.dart';
import '../../companion/presentation/companion_card.dart';
import '../../companion/presentation/companion_settings.dart';
import '../../companion/presentation/character_import_dialog.dart';
import '../../reminders/presentation/notification_pages.dart';
import '../domain/task.dart';
import 'task_editor.dart';
import '../../calendar/presentation/calendar_page.dart';
import '../../assistant/domain/daily_assistant.dart';
import '../../assistant/presentation/assistant_pages.dart';
import '../../recurrence/presentation/recurrence_editor.dart';

const pageLabels = {
  'today': 'Hôm nay',
  'calendar': 'Lịch',
  'analytics': 'Thống kê',
  'all': 'Tất cả công việc',
  'inbox': 'Hộp thư',
  'upcoming': 'Sắp tới',
  'completed': 'Đã hoàn thành',
  'trash': 'Thùng rác',
  'companion': 'Companion',
  'settings': 'Cài đặt',
  'notifications': 'Thông báo',
  'backup': 'Sao lưu',
};
const pageIcons = {
  'today': Icons.wb_sunny_outlined,
  'calendar': Icons.calendar_month_outlined,
  'analytics': Icons.bar_chart_outlined,
  'all': Icons.grid_view_rounded,
  'inbox': Icons.inbox_outlined,
  'upcoming': Icons.event_outlined,
  'completed': Icons.task_alt,
  'trash': Icons.delete_outline,
  'companion': Icons.eco_outlined,
  'settings': Icons.settings_outlined,
  'notifications': Icons.notifications_outlined,
  'backup': Icons.backup_outlined,
};

class WorkspaceScreen extends ConsumerStatefulWidget {
  const WorkspaceScreen({super.key, required this.page});
  final String page;
  @override
  ConsumerState<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends ConsumerState<WorkspaceScreen> {
  final search = TextEditingController();
  final scaffoldKey = GlobalKey<ScaffoldState>();
  String? category;
  TaskPriority? priority;
  bool overdueOnly = false, importing = false;
  late final Timer timer;
  final libraryScroll = ScrollController();
  final dialogueKey = GlobalKey();
  bool get dialogueVisible {
    if (ModalRoute.of(context)?.isCurrent == false) return false;
    final box = dialogueKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return false;
    final viewport = RenderAbstractViewport.maybeOf(box);
    final bounds = MatrixUtils.transformRect(
      box.getTransformTo(viewport),
      Offset.zero & box.size,
    );
    final clip =
        viewport?.paintBounds ?? (Offset.zero & MediaQuery.sizeOf(context));
    return clip.contains(bounds.center);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.page == 'today') {
        act(ref.read(workspaceProvider).overdueVisible());
      }
    });
    timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(WorkspaceScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.page != widget.page && widget.page == 'today') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) act(ref.read(workspaceProvider).overdueVisible());
      });
    }
  }

  @override
  void dispose() {
    timer.cancel();
    libraryScroll.dispose();
    search.dispose();
    super.dispose();
  }

  void navigate(
    String page, {
    String? categoryId,
    TaskPriority? selectedPriority,
    bool lateOnly = false,
  }) {
    setState(() {
      category = categoryId;
      priority = selectedPriority;
      overdueOnly = lateOnly;
      search.clear();
    });
    context.go('/$page');
    scaffoldKey.currentState?.closeDrawer();
  }

  void notice(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$error')));
  }

  Future<void> act(Future<void> action) async {
    try {
      await action;
    } catch (error) {
      notice(error);
    }
  }

  Future<void> categoryDialog() async {
    final name = TextEditingController();
    String? error;
    bool saving = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Danh mục mới'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  key: const Key('category-name'),
                  controller: name,
                  maxLength: 40,
                  decoration: const InputDecoration(labelText: 'Tên danh mục'),
                ),
                if (error != null)
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Để sau'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      update(() => saving = true);
                      try {
                        await ref
                            .read(workspaceProvider)
                            .addCategory(name.text, 0xff6b8b72);
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                      } catch (e) {
                        if (dialogContext.mounted) update(() => error = '$e');
                      } finally {
                        if (dialogContext.mounted) update(() => saving = false);
                      }
                    },
              child: const Text('Tạo danh mục'),
            ),
          ],
        ),
      ),
    );
    // Dialog's exit animation can still reference its text controller.
    Future<void>.delayed(const Duration(milliseconds: 500), name.dispose);
  }

  Widget sidebar(WorkspaceController controller) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(14, 26, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.eco_rounded,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'daymind',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text('S M A R T', style: TextStyle(fontSize: 9)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Text(
              'KHÔNG GIAN CỦA BẠN',
              style: TextStyle(fontSize: 10, letterSpacing: 1),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                for (final page in [
                  'today',
                  'all',
                  'calendar',
                  'analytics',
                  'inbox',
                  'upcoming',
                  'completed',
                  'notifications',
                ])
                  ListTile(
                    dense: true,
                    selected: widget.page == page && category == null,
                    selectedTileColor: Theme.of(context)
                        .colorScheme
                        .secondaryContainer
                        .withValues(alpha: .6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    leading: Icon(pageIcons[page], size: 21),
                    title: Text(pageLabels[page]!),
                    onTap: () => navigate(page),
                  ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(left: 14),
                        child: Text(
                          'DANH MỤC',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: categoryDialog,
                      icon: const Icon(Icons.add, size: 20),
                      tooltip: 'Thêm danh mục',
                    ),
                  ],
                ),
                for (final item in controller.categories)
                  ListTile(
                    dense: true,
                    selected: category == item.id,
                    leading: Icon(
                      Icons.circle,
                      color: Color(item.color),
                      size: 10,
                    ),
                    title: Text(item.name),
                    onTap: () => navigate('all', categoryId: item.id),
                  ),
                const SizedBox(height: 20),
                ListTile(
                  leading: const Icon(Icons.eco_outlined),
                  title: const Text('Companion'),
                  selected: widget.page == 'companion',
                  onTap: () => navigate('companion'),
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: const Text('Thùng rác'),
                  selected: widget.page == 'trash',
                  onTap: () => navigate('trash'),
                ),
                ListTile(
                  leading: const Icon(Icons.settings_outlined),
                  title: const Text('Cài đặt'),
                  selected: widget.page == 'settings',
                  onTap: () => navigate('settings'),
                ),
              ],
            ),
          ),
          const Divider(),
          Row(
            children: [
              Icon(
                Icons.lock_outline,
                size: 14,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  controller.busy
                      ? 'Đang lưu trên thiết bị…'
                      : 'Cục bộ · Không cần tài khoản',
                  style: const TextStyle(fontSize: 10),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  Widget statistic(
    String label,
    int value,
    IconData icon,
    String note,
    VoidCallback onTap,
  ) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (compact)
                Row(
                  children: [
                    Icon(
                      icon,
                      color: Theme.of(context).colorScheme.primary,
                      size: 22,
                    ),
                    const Spacer(),
                    Text(
                      '$value',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                )
              else ...[
                Icon(
                  icon,
                  color: Theme.of(context).colorScheme.primary,
                  size: 23,
                ),
                const SizedBox(height: 12),
                Text(
                  '$value',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
              if (!compact) ...[
                const SizedBox(height: 6),
                Text(note, style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget taskCard(Task task, WorkspaceController controller) {
    final categoryName = controller.categories
        .where((c) => c.id == task.categoryId)
        .firstOrNull
        ?.name;
    final late = task.overdue(controller.now());
    return Padding(
      key: ValueKey(task.id),
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: InkWell(
          onTap: task.deletedAt == null
              ? () => showTaskEditor(context, task: task)
              : null,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 14, 8, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (task.deletedAt == null)
                  Semantics(
                    label: 'Hoàn thành ${task.title}',
                    child: Checkbox(
                      value: task.status == TaskStatus.completed,
                      onChanged: controller.busy
                          ? null
                          : (_) => act(controller.toggle(task)),
                    ),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Icon(Icons.delete_outline),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          decoration: task.status == TaskStatus.completed
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      if (task.description.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Text(
                            task.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 12,
                        runSpacing: 6,
                        children: [
                          Text(
                            task.dueAt == null
                                ? 'Không thời hạn'
                                : '${late ? 'Quá hạn · ' : ''}${dateLabel(task.dueAt!)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: late
                                  ? Theme.of(context).colorScheme.error
                                  : null,
                            ),
                          ),
                          if (task.scheduledStartAt != null)
                            Text(
                              'Bắt đầu ${dateLabel(task.scheduledStartAt!)}',
                              style: const TextStyle(fontSize: 11),
                            ),
                          if (categoryName != null)
                            Text(
                              categoryName,
                              style: const TextStyle(fontSize: 11),
                            ),
                          Text(
                            'Ưu tiên ${priorityLabels[task.priority.index].toLowerCase()}',
                            style: TextStyle(
                              fontSize: 11,
                              color: task.priority == TaskPriority.high
                                  ? Theme.of(context).colorScheme.tertiary
                                  : null,
                            ),
                          ),
                          if (task.occurrenceId != null)
                            const Text(
                              '↻ Lặp lại',
                              style: TextStyle(fontSize: 11),
                            ),
                          if (task.status != TaskStatus.todo)
                            Text(
                              statusLabels[task.status.index],
                              style: const TextStyle(fontSize: 11),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (task.deletedAt != null)
                  IconButton(
                    onPressed: controller.busy
                        ? null
                        : () => act(controller.restore(task)),
                    icon: const Icon(Icons.restore),
                    tooltip: 'Khôi phục ${task.title}',
                  )
                else
                  PopupMenuButton<String>(
                    tooltip: 'Tùy chọn ${task.title}',
                    onSelected: (value) {
                      if (value == 'edit') showTaskEditor(context, task: task);
                      if (value == 'delete') {
                        if (task.occurrenceId == null) {
                          act(controller.delete(task));
                        } else {
                          chooseEditScope(context, deleting: true).then((
                            scope,
                          ) {
                            if (scope != null) {
                              act(controller.delete(task, scope: scope));
                            }
                          });
                        }
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Text('Sửa chi tiết'),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Chuyển vào thùng rác'),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget taskContent(WorkspaceController controller) {
    final now = controller.now();
    final view =
        TaskView.values.where((v) => v.name == widget.page).firstOrNull ??
        TaskView.today;
    final items = filterTasks(
      controller.visibleTasks,
      view: view,
      now: now,
      search: search.text,
      category: category,
      priority: priority,
      overdueOnly: overdueOnly,
    );
    final summary = DaySummary.calculate(
      controller.visibleTasks,
      now,
      controller.reminders?.preferences.timezoneId ?? 'UTC',
    );
    final today = summary.open,
        completed = summary.completed,
        late = summary.overdue;
    final high = controller.visibleTasks
        .where(
          (t) =>
              t.deletedAt == null &&
              !t.terminal &&
              t.priority == TaskPriority.high,
        )
        .length;
    return ListView(
      padding: const EdgeInsets.only(bottom: 110),
      children: [
        Text(
          widget.page == 'today'
              ? 'Một ngày có chủ đích.'
              : category == null
              ? pageLabels[widget.page] ?? 'Công việc'
              : controller.categories
                        .where((c) => c.id == category)
                        .firstOrNull
                        ?.name ??
                    'Danh mục',
          style: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          widget.page == 'today'
              ? 'Nhẹ tâm trí. Rõ việc cần làm.'
              : 'Từng việc nhỏ, theo nhịp độ của bạn.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 24),
        if (widget.page == 'today') ...[
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => editDashboard(context, controller),
              icon: const Icon(Icons.dashboard_customize_outlined),
              label: const Text('Tùy chỉnh trang hôm nay'),
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth > 760 ? 4 : 2;
              final width =
                  (constraints.maxWidth - 12 * (columns - 1)) / columns;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  if (controller.dashboard.cards.contains('today'))
                    SizedBox(
                      width: width,
                      child: statistic(
                        'Cần làm hôm nay',
                        today,
                        Icons.wb_sunny_outlined,
                        'Gồm việc đã quá hạn',
                        () => navigate('today'),
                      ),
                    ),
                  if (controller.dashboard.cards.contains('completed'))
                    SizedBox(
                      width: width,
                      child: statistic(
                        'Đã xong hôm nay',
                        completed,
                        Icons.task_alt,
                        'Ghi nhận mọi nỗ lực',
                        () => navigate('completed'),
                      ),
                    ),
                  if (controller.dashboard.cards.contains('overdue'))
                    SizedBox(
                      width: width,
                      child: statistic(
                        'Đang quá hạn',
                        late,
                        Icons.schedule,
                        'Chọn một việc để tiếp tục',
                        () => navigate('all', lateOnly: true),
                      ),
                    ),
                  if (controller.dashboard.cards.contains('high'))
                    SizedBox(
                      width: width,
                      child: statistic(
                        'Ưu tiên cao',
                        high,
                        Icons.flag_outlined,
                        'Điều cần tập trung',
                        () => navigate(
                          'all',
                          selectedPriority: TaskPriority.high,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          if (controller.preferences.companionEnabled) ...[
            CompanionCard(
              controller: controller,
              dialogueKey: dialogueKey,
              compact: MediaQuery.sizeOf(context).width < 600,
            ),
            const SizedBox(height: 24),
          ],
          if (controller.dashboard.cards.contains('suggestions')) ...[
            FocusSuggestions(controller: controller),
            const SizedBox(height: 16),
          ],
        ],
        TextField(
          key: const Key('search-tasks'),
          controller: search,
          decoration: InputDecoration(
            hintText: 'Tìm công việc…',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: search.text.isEmpty
                ? null
                : IconButton(
                    onPressed: () => setState(search.clear),
                    icon: const Icon(Icons.close),
                    tooltip: 'Xóa tìm kiếm',
                  ),
          ),
          onChanged: (_) {
            setState(() {
              category = null;
              priority = null;
              overdueOnly = false;
            });
            if (widget.page != 'all') context.go('/all');
          },
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Tất cả ưu tiên'),
              selected: priority == null,
              onSelected: (_) => setState(() {
                priority = null;
                overdueOnly = false;
              }),
            ),
            ChoiceChip(
              label: const Text('Ưu tiên cao'),
              selected: priority == TaskPriority.high,
              onSelected: (selected) => setState(
                () => priority = selected ? TaskPriority.high : null,
              ),
            ),
            if (category != null || overdueOnly)
              ActionChip(
                label: const Text('Bỏ bộ lọc'),
                onPressed: () => setState(() {
                  category = null;
                  overdueOnly = false;
                }),
              ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: Text(
                '${items.length} công việc',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (widget.page != 'trash')
              TextButton.icon(
                onPressed: () => showTaskEditor(context, categoryId: category),
                icon: const Icon(Icons.add),
                label: const Text('Thêm mới'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Column(
                children: [
                  Icon(
                    widget.page == 'trash'
                        ? Icons.delete_outline
                        : Icons.eco_outlined,
                    size: 42,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    search.text.isNotEmpty
                        ? 'Chưa tìm thấy việc phù hợp.'
                        : 'Một khoảng trống dễ chịu.',
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.page == 'upcoming'
                        ? 'Công việc có lịch bắt đầu hoặc hạn từ ngày mai sẽ ở đây.'
                        : widget.page == 'trash'
                        ? 'Việc đã xóa có thể khôi phục tại đây.'
                        : 'Ghi lại một việc nhỏ để bắt đầu. Không bắt buộc đặt hạn.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        for (final task in items) taskCard(task, controller),
        const SizedBox(height: 20),
        Text(
          'Dữ liệu lưu trên thiết bị này · ${controller.now().timeZoneName}',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Future<void> importCharacter(WorkspaceController controller) async {
    if (importing) return;
    setState(() => importing = true);
    try {
      final picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['png', 'webp', 'gif', 'zip'],
      );
      if (picked == null) return;
      if (picked.path == null) {
        throw const ValidationException(
          'Không đọc được tệp đã chọn. Hãy chọn ảnh trên thiết bị.',
        );
      }
      if (!mounted) return;
      await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => CharacterImportDialog(
          controller: controller,
          source: File(picked.path!),
          fileName: picked.name,
        ),
      );
    } catch (error) {
      notice(error);
    } finally {
      final cleaned = await clearAndroidPickerCache();
      if (!cleaned && mounted) {
        notice(
          'Chưa dọn được bản tệp tạm của bộ chọn. Hãy mở lại ứng dụng để thử dọn cache.',
        );
      }
      if (mounted) setState(() => importing = false);
    }
  }

  Widget characterLibrary(WorkspaceController controller) {
    final names = controller.importer.installed();
    if (names.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: SizedBox(
        key: const Key('companion-library'),
        height: 196 + (MediaQuery.textScalerOf(context).scale(12) - 12) * 2,
        child: Scrollbar(
          controller: libraryScroll,
          thumbVisibility: true,
          child: ListView.builder(
            controller: libraryScroll,
            scrollDirection: Axis.horizontal,
            itemExtent: 148,
            itemCount: names.length,
            itemBuilder: (_, index) {
              final name = names[index];
              return SizedBox(
                width: 132,
                child: Column(
                  children: [
                    SizedBox(
                      width: 96,
                      height: 96,
                      child: CompanionAssetImage(
                        importer: controller.importer,
                        name: name,
                        decodeSize: controller.companionLayout.lowResource
                            ? 64
                            : 128,
                      ),
                    ),
                    Text(
                      'Nhân vật ${index + 1}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Chọn nhân vật ${index + 1}',
                          icon: Icon(
                            controller.preferences.assetName == name
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                          ),
                          onPressed: controller.busy
                              ? null
                              : () => act(
                                  controller.configure(
                                    (prefs) => prefs.copyWith(assetName: name),
                                  ),
                                ),
                        ),
                        IconButton(
                          tooltip: 'Xóa nhân vật ${index + 1}',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: controller.busy
                              ? null
                              : () async {
                                  try {
                                    await controller.removeCompanionAsset(name);
                                    if (mounted) setState(() {});
                                  } catch (error) {
                                    notice(error);
                                  }
                                },
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget companionContent(WorkspaceController controller) => ListView(
    padding: const EdgeInsets.only(bottom: 100),
    children: [
      Text(
        'Một người bạn nhỏ.',
        style: Theme.of(context).textTheme.headlineMedium
            ?.copyWith(fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 8),
      const Text('Ở đây để đồng hành, không làm phiền.'),
      const SizedBox(height: 24),
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CompanionCard(controller: controller, dialogueKey: dialogueKey),
              const SizedBox(height: 20),
              CompanionSettingsSection(controller: controller),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Nhân vật của bạn',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'PNG/WebP tĩnh ≤4 MiB, GIF/WebP động ≤8 MiB hoặc ZIP DayMind ≤16 MiB. Tối đa 120 khung; thư viện ≤32 MiB. Chỉ dùng tài sản bạn có quyền sử dụng.',
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: importing
                            ? null
                            : () => importCharacter(controller),
                        icon: const Icon(Icons.image_outlined),
                        label: Text(
                          importing ? 'Đang kiểm tra ảnh…' : 'Nhập nhân vật 2D',
                        ),
                      ),
                      if (controller.preferences.assetName != null)
                        TextButton(
                          onPressed: () => act(
                            controller.configure(
                              (prefs) => prefs.copyWith(resetAsset: true),
                            ),
                          ),
                          child: const Text('Dùng lại Mầm mặc định'),
                        ),
                      characterLibrary(controller),
                      const SizedBox(height: 8),
                      const Text(
                        'Mầm là nhân vật gốc của DayMind. Hoạt ảnh dùng tệp bạn nhập; Companion nổi có trên Windows. Live2D chưa được bật.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
  Widget settingsContent(WorkspaceController controller) => ListView(
    padding: const EdgeInsets.only(bottom: 100),
    children: [
      Text(
        'Không gian theo ý bạn.',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 24),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Giao diện', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: controller.preferences.theme,
                decoration: const InputDecoration(labelText: 'Chế độ màu'),
                items: const [
                  DropdownMenuItem(
                    value: 'system',
                    child: Text('Theo hệ thống'),
                  ),
                  DropdownMenuItem(value: 'light', child: Text('Sáng')),
                  DropdownMenuItem(value: 'dark', child: Text('Tối')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    act(
                      controller.configure(
                        (prefs) => prefs.copyWith(theme: value),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 20),
              if (Platform.isWindows)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: controller.preferences.windowsTrayEnabled,
                  title: const Text('Thu vào khay khi đóng cửa sổ'),
                  subtitle: const Text(
                    'DayMind tiếp tục nhắc trong khay. Menu khay có Mở DayMind và Thoát hẳn. Không tự khởi động cùng Windows.',
                  ),
                  onChanged: (value) => act(
                    controller.configure(
                      (prefs) => prefs.copyWith(windowsTrayEnabled: value),
                    ),
                  ),
                ),
              if (controller.window?.error != null)
                Text(
                  controller.window!.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.eco_outlined),
                title: const Text('Companion & tính cách'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => navigate('companion'),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 20),
      if (ref.read(workspaceHostProvider) != null) ...[
        Card(
          child: ListTile(
            leading: const Icon(Icons.sync_rounded),
            title: const Text('Tài khoản & đồng bộ'),
            subtitle: const Text('Tùy chọn · Firebase Emulator'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => navigate('account'),
          ),
        ),
        const SizedBox(height: 20),
      ],
      const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dữ liệu & quyền riêng tư',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 12),
              Text(
                'Công việc và nhân vật lưu trên thiết bị. Tài khoản và đồng bộ là tùy chọn. Mỗi tài khoản có không gian riêng; ảnh nhân vật không tự tải lên máy chủ.',
              ),
              SizedBox(height: 10),
              Text(
                'Gỡ ứng dụng hoặc xóa dữ liệu có thể làm mất công việc chưa đồng bộ. Hãy tạo bản sao lưu có mật khẩu và giữ ở nơi an toàn.',
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 20),
      if (ref.read(workspaceHostProvider) != null) ...[
        OutlinedButton.icon(
          onPressed: () => navigate('backup'),
          icon: const Icon(Icons.backup_outlined),
          label: const Text('Sao lưu & khôi phục bằng mật khẩu'),
        ),
        const SizedBox(height: 20),
      ],
      if (controller.reminders != null)
        NotificationSettingsSection(reminders: controller.reminders!),
      const SizedBox(height: 20),
      PrivacySection(controller: controller),
      const SizedBox(height: 20),
      OutlinedButton(
        onPressed: () => showLicensePage(
          context: context,
          applicationName: 'DayMind SMART',
          applicationVersion: '0.7.0',
          applicationLegalese: 'Mầm — nhân vật gốc của DayMind',
        ),
        child: const Text('Thông tin & giấy phép mã nguồn mở'),
      ),
    ],
  );
  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(workspaceProvider);
    ref.listen<int>(workspaceProvider.select((c) => c.inAppSequence), (
      _,
      next,
    ) {
      final c = ref.read(workspaceProvider);
      if (!c.preferences.companionEnabled ||
          c.companionAnnouncementSequence != next ||
          !{'today', 'companion'}.contains(widget.page) ||
          !dialogueVisible) {
        final message = c.inAppAnnouncement;
        if (message != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              action: SnackBarAction(
                label: 'Xem',
                onPressed: () => navigate('notifications'),
              ),
            ),
          );
        }
      }
    });
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    final special = [
      'companion',
      'settings',
      'notifications',
      'analytics',
      'account',
      'backup',
    ].contains(widget.page);
    final content =
        widget.page == 'backup' && ref.read(workspaceHostProvider) != null
        ? BackupPage(host: ref.read(workspaceHostProvider)!)
        : widget.page == 'account' && ref.read(workspaceHostProvider) != null
        ? AccountPage(host: ref.read(workspaceHostProvider)!)
        : widget.page == 'companion'
        ? companionContent(controller)
        : widget.page == 'settings'
        ? settingsContent(controller)
        : widget.page == 'notifications'
        ? NotificationCenterPage(controller: controller)
        : widget.page == 'analytics'
        ? AnalyticsPage(controller: controller)
        : widget.page == 'calendar'
        ? CalendarPage(controller: controller)
        : taskContent(controller);
    final scaffold = Scaffold(
      key: scaffoldKey,
      appBar: wide
          ? null
          : AppBar(
              title: const Text(
                'daymind',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              actions: [
                IconButton(
                  onPressed: () => navigate('notifications'),
                  icon: Badge(
                    isLabelVisible:
                        controller.reminders?.events.any(
                          (e) => e.state == 'unknown' && !e.read,
                        ) ??
                        false,
                    child: const Icon(Icons.notifications_outlined),
                  ),
                  tooltip: 'Thông báo',
                ),
                IconButton(
                  onPressed: () => navigate('settings'),
                  icon: const Icon(Icons.tune_rounded),
                  tooltip: 'Cài đặt',
                ),
              ],
            ),
      drawer: wide ? null : Drawer(width: 280, child: sidebar(controller)),
      body: SafeArea(
        child: Row(
          children: [
            if (wide) SizedBox(width: 240, child: sidebar(controller)),
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  wide ? 32 : 18,
                  wide ? 32 : 18,
                  wide ? 32 : 18,
                  0,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1400),
                    child: content,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: special || widget.page == 'trash'
          ? null
          : FloatingActionButton.extended(
              key: const Key('add-task'),
              onPressed: () => showTaskEditor(context, categoryId: category),
              icon: const Icon(Icons.add),
              label: const Text('Thêm việc'),
            ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: [
                'today',
                'calendar',
                'upcoming',
                'analytics',
              ].indexOf(widget.page).clamp(0, 3),
              onDestinationSelected: (index) => navigate(
                ['today', 'calendar', 'upcoming', 'analytics'][index],
              ),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.wb_sunny_outlined),
                  label: 'Hôm nay',
                ),
                NavigationDestination(
                  icon: Icon(Icons.calendar_month_outlined),
                  label: 'Lịch',
                ),
                NavigationDestination(
                  icon: Icon(Icons.event_outlined),
                  label: 'Sắp tới',
                ),
                NavigationDestination(
                  icon: Icon(Icons.bar_chart_outlined),
                  label: 'Thống kê',
                ),
              ],
            ),
    );
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): () =>
            showTaskEditor(context),
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () =>
            navigate('all'),
      },
      child: Focus(autofocus: true, child: scaffold),
    );
  }
}
