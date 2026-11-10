import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daymind_smart/app/controller.dart';
import 'package:daymind_smart/features/companion/data/asset_importer.dart';
import 'package:daymind_smart/features/companion/data/character_preparer.dart';
import 'package:daymind_smart/features/companion/presentation/character_import_dialog.dart';
import 'package:daymind_smart/features/tasks/data/database.dart';

class CancelPreviewImporter extends StaticAssetImporter {
  CancelPreviewImporter(super.directory);
  final ready = Completer<StaticAssetPreview>();
  bool Function()? cancelled;
  @override
  Future<StaticAssetPreview> prepareCharacter(
    File source,
    String displayName, {
    bool Function()? cancelled,
    void Function(int, int)? progress,
  }) {
    this.cancelled = cancelled;
    return ready.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Future<void> until(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 100 && finder.evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(finder, findsOneWidget);
  }

  Future<void> open(
    WidgetTester tester,
    WorkspaceController c,
    File file,
    String name, {
    double scale = 1,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<bool>(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => CharacterImportDialog(
                    controller: c,
                    source: file,
                    fileName: name,
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
  }

  testWidgets(
    'GIF preview at 200% text requires rights and installs original only after confirmation',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      final root = Directory.systemTemp.createTempSync('daymind-preview-');
      final db = DaymindDatabase(NativeDatabase.memory());
      final c = WorkspaceController(
        SqliteTaskRepository(db),
        StaticAssetImporter(root),
      );
      await c.load();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        c.dispose();
        await db.close();
        root.deleteSync(recursive: true);
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final source = File('test/fixtures/three_frames.gif');
      await open(tester, c, source, 'leaf.gif', scale: 2);
      await until(tester, find.byKey(const Key('character-rights')));
      expect(c.importer.installed(), isEmpty);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('install-character')))
            .onPressed,
        isNull,
      );
      await tester.ensureVisible(find.byKey(const Key('character-rights')));
      await tester.tap(find.byKey(const Key('character-rights')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('install-character')));
      await until(tester, find.text('open').hitTestable());
      expect(c.preferences.assetName, endsWith('.character'));
      final bytes = await tester.runAsync(
        () => c.importer.resolve(c.preferences.assetName)!.readAsBytes(),
      );
      expect(bytes, await tester.runAsync(source.readAsBytes));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'invalid package reports its error without changing the current selection',
    (tester) async {
      final root = Directory.systemTemp.createTempSync(
        'daymind-preview-invalid-',
      );
      final db = DaymindDatabase(NativeDatabase.memory());
      final c = WorkspaceController(
        SqliteTaskRepository(db),
        StaticAssetImporter(root),
      );
      await c.load();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        c.dispose();
        await db.close();
        root.deleteSync(recursive: true);
      });
      await open(tester, c, File('test/fixtures/three_frames.gif'), 'fake.zip');
      await until(tester, find.byKey(const Key('character-import-error')));
      expect(c.importer.installed(), isEmpty);
      expect(c.preferences.assetName, isNull);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('install-character')))
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expect(find.byType(CharacterImportDialog), findsNothing);
    },
  );

  testWidgets(
    'cancelling preparation signals cancellation and ignores late results',
    (tester) async {
      final root = Directory.systemTemp.createTempSync(
        'daymind-preview-cancel-',
      );
      final importer = CancelPreviewImporter(root);
      final db = DaymindDatabase(NativeDatabase.memory());
      final c = WorkspaceController(SqliteTaskRepository(db), importer);
      await c.load();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        c.dispose();
        await db.close();
        root.deleteSync(recursive: true);
      });
      await open(tester, c, File('test/fixtures/three_frames.gif'), 'leaf.gif');
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expect(importer.cancelled!(), isTrue);
      importer.ready.completeError(const CharacterImportCancelled());
      await tester.pump();
      expect(c.importer.installed(), isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
