import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:daymind_smart/main.dart' as app;
import 'package:daymind_smart/app/controller.dart';
import 'package:daymind_smart/features/tasks/presentation/workspace_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native startup and durable task creation', (tester) async {
    await app.main();
    await tester.pumpAndSettle();
    expect(find.byType(WorkspaceScreen), findsOneWidget);
    await tester.tap(find.byKey(const Key('add-task')));
    await tester.pumpAndSettle();
    final title = 'Native smoke ${DateTime.now().millisecondsSinceEpoch}';
    await tester.enterText(find.byKey(const Key('task-title')), title);
    await tester.tap(find.byKey(const Key('save-task')));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    final controller = ProviderScope.containerOf(
      tester.element(find.byType(WorkspaceScreen)),
    ).read(workspaceProvider);
    final tasks = await controller.repository.list();
    expect(
      tasks.any((task) => task.title == title && task.dueAt == null),
      true,
    );
    final task = tasks.firstWhere((task) => task.title == title);
    await controller.delete(task);
    await tester.pumpAndSettle();
  });
}
