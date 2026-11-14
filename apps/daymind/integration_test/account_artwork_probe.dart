import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:daymind_smart/app/workspace_host.dart';
import 'package:daymind_smart/features/companion/domain/floating_settings.dart';
import 'package:daymind_smart/platform/floating_companion.dart';

import 'animation_fixture.dart';
import 'companion_fixtures.dart';

/// Uses different-sized artwork to detect a retained native bitmap after a
/// real Auth workspace switch. No production account or remote asset storage.
class AccountArtworkProbe {
  AccountArtworkProbe(
    this.name,
    this.created,
    this.previousName,
    this.previousEnabled,
    this.previousFloating,
    this.previousLowResource,
  );
  final String name;
  final bool created, previousEnabled;
  final bool previousLowResource;
  final String? previousName;
  final FloatingCompanionSettings previousFloating;
  String? privateName;
  File? privateSource;

  static Future<AccountArtworkProbe> start(
    WidgetTester tester,
    WorkspaceHost host,
  ) async {
    final c = host.controller!;
    final previous = c.preferences, floating = c.floatingSettings;
    final low = c.companionLayout.lowResource;
    final names = c.importer.installed();
    final folder = await Directory.systemTemp.createTemp(
      'daymind-account-art-',
    );
    late String name;
    try {
      final source = await File('${folder.path}/local.gif')
          .writeAsBytes(base64Decode(companionGifFixture));
      name = await c.importer.installPrepared(
        await c.importer.prepareCharacter(source, 'local.gif'),
        rightsConfirmed: true,
      );
    } finally {
      await folder.delete(recursive: true);
    }
    await c.configure(
      (p) => p.copyWith(assetName: name, companionEnabled: true),
    );
    await c.updateCompanionLayout((s) => s.copy(lowResource: true));
    if (Platform.isWindows) {
      await c.updateFloating((s) => s.copy(enabled: true));
      await _native(tester, 128);
    }
    return AccountArtworkProbe(
      name,
      !names.contains(name),
      previous.assetName,
      previous.companionEnabled,
      floating,
      low,
    );
  }

  static Future<void> _native(WidgetTester tester, int width) async {
    if (!Platform.isWindows) return;
    Map<dynamic, dynamic> state = {};
    bool matches() => width == 0
        ? state['exists'] == false && state['atlasWidth'] == 0
        : state['exists'] == true && state['atlasWidth'] == width;
    for (var i = 0; i < 80; i++) {
      state = (await FloatingCompanionService.channel
          .invokeMapMethod<dynamic, dynamic>('state'))!;
      if (matches()) return;
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(
      matches(),
      isTrue,
      reason: 'Account artwork retained native state: $state',
    );
  }

  Future<void> freshAccount(WidgetTester tester, WorkspaceHost host) async {
    expect(host.controller!.preferences.assetName, isNull);
    expect(host.controller!.importer.installed(), isEmpty);
    await _native(tester, 0);
    final c = host.controller!;
    privateName = await c.importer.installBytes(
      base64Decode(companionPngFixtures.first),
      'private.png',
    );
    privateSource = c.importer.resolve(privateName)!;
    await c.configure((p) => p.copyWith(assetName: privateName));
    if (Platform.isWindows) {
      await c.updateFloating((s) => s.copy(enabled: true));
      await _native(tester, 256);
    }
  }

  Future<void> localRestored(WidgetTester tester, WorkspaceHost host) async {
    expect(host.account, isNull);
    expect(host.controller!.preferences.assetName, name);
    expect(host.controller!.importer.resolve(name)!.existsSync(), isTrue);
    expect(host.controller!.preferences.assetName, isNot(privateName));
    await _native(tester, 128);
  }

  Future<void> privateRestored(WidgetTester tester, WorkspaceHost host) async {
    expect(host.controller!.preferences.assetName, privateName);
    expect(
      host.controller!.importer.resolve(privateName)!.path,
      privateSource!.path,
    );
    expect(
      await privateSource!.readAsBytes(),
      base64Decode(companionPngFixtures.first),
    );
    await _native(tester, 256);
  }

  Future<void> finish(WidgetTester tester, WorkspaceHost host) async {
    await localRestored(tester, host);
    expect(
      privateSource!.existsSync(),
      isFalse,
      reason: 'Verified deletion must remove private art.',
    );
    final c = host.controller!;
    if (Platform.isWindows) {
      await c.updateFloating((s) => s.copy(enabled: false));
      await _native(tester, 0);
    }
    await c.configure(
      (p) => p.copyWith(
        assetName: previousName,
        resetAsset: previousName == null,
        companionEnabled: previousEnabled,
      ),
    );
    if (created) await c.removeCompanionAsset(name);
    await c.updateCompanionLayout(
      (s) => s.copy(lowResource: previousLowResource),
    );
    await c.updateFloating((_) => previousFloating);
  }
}
