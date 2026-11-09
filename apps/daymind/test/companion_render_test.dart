import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daymind_smart/app/controller.dart';
import 'package:daymind_smart/features/companion/data/asset_importer.dart';
import 'package:daymind_smart/features/companion/presentation/companion_card.dart';
import 'package:daymind_smart/features/tasks/data/database.dart';

import '../integration_test/companion_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final low in [false, true]) {
    testWidgets(
      'decoded portrait stays visible after cache eviction (lowResource=$low)',
      (tester) async {
        final temp = Directory.systemTemp.createTempSync('daymind-render-');
        final db = DaymindDatabase(NativeDatabase.memory());
        final c = WorkspaceController(
          SqliteTaskRepository(db),
          StaticAssetImporter(temp),
        );
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          c.dispose();
          await db.close();
          temp.deleteSync(recursive: true);
          PaintingBinding.instance.imageCache.clear();
          PaintingBinding.instance.imageCache.clearLiveImages();
          PaintingBinding.instance.imageCache.maximumSizeBytes =
              16 * 1024 * 1024;
        });
        await c.load();
        await c.updateCompanionLayout((v) => v.copy(lowResource: low));
        final names = await tester.runAsync(() async {
          final result = <String>[];
          for (final fixture in companionPngFixtures) {
            result.add(
              await c.importer.installBytes(
                base64Decode(fixture),
                'fixture.png',
              ),
            );
          }
          return result;
        });
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ListenableBuilder(
                listenable: c,
                builder: (_, _) =>
                    SingleChildScrollView(child: CompanionCard(controller: c)),
              ),
            ),
          ),
        );
        for (final name in names!) {
          await tester.runAsync(
            () => precacheImage(
              ResizeImage(
                FileImage(c.importer.resolve(name)!),
                width: low ? 128 : 256,
                height: low ? 128 : 256,
                policy: ResizeImagePolicy.fit,
                allowUpscaling: false,
              ),
              tester.element(find.byType(CompanionCard)),
            ),
          );
          await c.configure((p) => p.copyWith(assetName: name));
          await tester.pumpAndSettle();
          final portrait = find.byKey(const Key('companion-portrait'));
          final raw = find.descendant(
            of: portrait,
            matching: find.byType(RawImage),
          );
          expect(raw, findsOneWidget);
          expect(tester.widget<RawImage>(raw).image!.width, low ? 128 : 256);
          expect(portrait.hitTestable(), findsOneWidget);
          // Cache tracking and widget-owned frames have separate lifetimes.
          PaintingBinding.instance.imageCache.clearLiveImages();
          expect(PaintingBinding.instance.imageCache.liveImageCount, 0);
          await tester.pump();
          expect(tester.widget<RawImage>(raw).image, isNotNull);
          expect(tester.takeException(), isNull);
        }
      },
    );
  }
}
