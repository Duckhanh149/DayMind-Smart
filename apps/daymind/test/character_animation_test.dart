import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daymind_smart/features/companion/data/asset_importer.dart';
import 'package:daymind_smart/features/companion/domain/companion.dart';
import 'package:daymind_smart/features/companion/presentation/character_animation.dart';

final paints = find.byWidgetPredicate(
  (w) => w is CustomPaint && w.painter is CharacterFramePainter,
);
CharacterFramePainter painter(WidgetTester tester) =>
    tester.widget<CustomPaint>(paints).painter! as CharacterFramePainter;
Future<void> loaded(WidgetTester tester) async {
  for (var i = 0; i < 50 && paints.evaluate().isEmpty; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
  expect(paints, findsOneWidget);
}

class DelayedCharacterImporter extends StaticAssetImporter {
  DelayedCharacterImporter(super.directory);
  final ready = Completer<InstalledCharacter?>();
  bool requested = false;
  @override
  Future<InstalledCharacter?> character(String? name) {
    requested = true;
    return ready.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late StaticAssetImporter importer;
  late String name;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('daymind-animation-');
    importer = StaticAssetImporter(root);
    name = await importer.installPrepared(
      await importer.prepareCharacter(
        File('test/fixtures/three_frames.gif'),
        'leaf.gif',
      ),
      rightsConfirmed: true,
    );
    final file = File('${root.path}/$name/asset.json');
    final meta = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    meta['motions']['cheer'] = {
      'frames': [2, 1],
      'loop': false,
    };
    meta['expressions']['happy'] = 'cheer';
    await file.writeAsString(jsonEncode(meta));
    await importer.drain();
    importer = StaticAssetImporter(root);
  });
  tearDown(() async {
    await importer.drain();
    await root.delete(recursive: true);
  });
  Widget portrait({
    bool active = true,
    CompanionExpression expression = CompanionExpression.neutral,
  }) => SizedBox(
    width: 80,
    height: 80,
    child: CharacterAnimationView(
      importer: importer,
      name: name,
      expression: expression,
      active: active,
      fallback: const Text('static'),
    ),
  );

  testWidgets(
    'timings advance bounded atlas tiles and expression clips stop on their final frame',
    (tester) async {
      var expression = CompanionExpression.neutral;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (_, set) {
                update = set;
                return portrait(expression: expression);
              },
            ),
          ),
        ),
      );
      await loaded(tester);
      expect(painter(tester).frame.x, 0);
      expect(
        (painter(tester).atlas.width, painter(tester).atlas.height),
        (384, 128),
      );
      await tester.pump(const Duration(milliseconds: 124));
      expect(painter(tester).frame.x, 0);
      await tester.pump(const Duration(milliseconds: 1));
      expect(painter(tester).frame.x, 128);
      final atlas = painter(tester).atlas;
      update(() => expression = CompanionExpression.happy);
      await tester.pump();
      expect(painter(tester).atlas, same(atlas));
      expect(painter(tester).frame.x, 256);
      await tester.pump(const Duration(milliseconds: 200));
      expect(painter(tester).frame.x, 128);
      await tester.pump(const Duration(seconds: 10));
      expect(painter(tester).frame.x, 128);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(atlas.debugDisposed, isTrue);
    },
  );

  testWidgets(
    'tray visibility and application background release textures and resume from first frame',
    (tester) async {
      var active = true;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (_, set) {
                update = set;
                return portrait(active: active);
              },
            ),
          ),
        ),
      );
      await loaded(tester);
      final atlas = painter(tester).atlas;
      update(() => active = false);
      await tester.pump();
      expect(paints, findsNothing);
      expect(atlas.debugDisposed, isTrue);
      await tester.pump(const Duration(seconds: 10));
      update(() => active = true);
      await tester.pump();
      await loaded(tester);
      final resumed = painter(tester).atlas;
      expect(painter(tester).frame.x, 0);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(resumed.debugDisposed, isTrue);
      expect(paints, findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await loaded(tester);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'scrolling out of view releases the atlas and returning reloads it',
    (tester) async {
      final scroll = ScrollController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              controller: scroll,
              child: Column(
                children: [portrait(), const SizedBox(height: 1800)],
              ),
            ),
          ),
        ),
      );
      await loaded(tester);
      final atlas = painter(tester).atlas;
      scroll.jumpTo(600);
      await tester.pump();
      await tester.pump();
      expect(paints, findsNothing);
      expect(atlas.debugDisposed, isTrue);
      scroll.jumpTo(0);
      await tester.pump();
      await loaded(tester);
      await tester.pumpWidget(const SizedBox.shrink());
      scroll.dispose();
    },
  );

  testWidgets(
    'a modal dialog pauses and disposes the covered portrait until dismissed',
    (tester) async {
      late BuildContext page;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              page = context;
              return Scaffold(body: portrait());
            },
          ),
        ),
      );
      await loaded(tester);
      final atlas = painter(tester).atlas;
      final dialog = showDialog<void>(
        context: page,
        builder: (_) => const AlertDialog(content: Text('Dialog')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(paints, findsNothing);
      expect(atlas.debugDisposed, isTrue);
      Navigator.pop(tester.element(find.byType(AlertDialog)));
      await dialog;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await loaded(tester);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'reduced motion and TickerMode never allocate an animated atlas',
    (tester) async {
      for (final reduced in [true, false]) {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(disableAnimations: reduced),
              child: TickerMode(
                enabled: reduced,
                child: Scaffold(body: portrait()),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pump(const Duration(seconds: 2));
        expect(paints, findsNothing);
        expect(find.text('static'), findsOneWidget);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'disposing during async load cannot attach a stale texture or restart a timer',
    (tester) async {
      final installed = await tester.runAsync(() => importer.character(name));
      final delayed = DelayedCharacterImporter(root);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 80,
              height: 80,
              child: CharacterAnimationView(
                importer: delayed,
                name: name,
                expression: CompanionExpression.neutral,
                fallback: const Text('static'),
              ),
            ),
          ),
        ),
      );
      expect(delayed.requested, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      delayed.ready.complete(installed);
      await tester.pump(const Duration(seconds: 1));
      expect(paints, findsNothing);
      expect(tester.takeException(), isNull);
      await delayed.drain();
    },
  );
}
