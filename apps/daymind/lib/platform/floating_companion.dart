import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../app/controller.dart';

/// One native tool window in the existing process; no Flutter engine, scheduler,
/// account data or original import paths are passed to it.
class FloatingCompanionService with WidgetsBindingObserver {
  FloatingCompanionService(this.controller);
  static const channel = MethodChannel('daymind/companion');
  final WorkspaceController controller;
  Future<void> _tail = Future.value();
  Timer? _policyTimer;
  bool _stopped = false;
  String? _signature, _sentArt;
  int _generation = 0;

  void start() {
    WidgetsBinding.instance.addObserver(this);
    channel.setMethodCallHandler((call) async {
      if (_stopped) return;
      if (call.method == 'moved') {
        final v = (call.arguments as Map).cast<String, dynamic>();
        try {
          await controller.updateFloating(
            (s) => s.copy(
              x: v['x'] as int,
              y: v['y'] as int,
              size: v['size'] as int,
            ),
          );
        } catch (_) {
          controller.reportFloatingError('Chưa lưu được vị trí cửa sổ nổi.');
        }
      } else if (call.method == 'recovered') {
        await controller.updateFloating(
          (s) => s.copy(resetPosition: true, clickThrough: false),
        );
      }
    });
    controller.addListener(_changed);
    _policyTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _changed(),
    );
    _changed();
  }

  @override
  void didChangeAccessibilityFeatures() => _changed();

  void _changed() {
    if (_stopped) return;
    final generation = ++_generation;
    _tail = _tail.then((_) async {
      if (_stopped || generation != _generation) return;
      try {
        await _update(generation);
      } catch (_) {
        _signature = null;
        _sentArt = null;
        // On any partial native/configuration failure, remove old artwork.
        try {
          await channel.invokeMethod<void>('close');
        } catch (_) {}
        if (!_stopped) {
          controller.reportFloatingStatus(null);
          controller.reportFloatingError(
            'Chưa mở được Companion nổi. Hãy tắt rồi bật lại hoặc dùng nhân vật trong ứng dụng.',
          );
        }
      }
    });
  }

  Future<Uint8List> _bounded(File file) async {
    final result = BytesBuilder(copy: false);
    await for (final bytes in file.openRead(0, 8 * 1024 * 1024 + 1)) {
      result.add(bytes);
    }
    if (result.length > 8 * 1024 * 1024) {
      throw StateError('Atlas vượt giới hạn.');
    }
    return result.takeBytes();
  }

  Future<void> _update(int generation) async {
    final c = controller, settings = c.floatingSettings;
    final enabled = settings.enabled && c.preferences.companionEnabled;
    final quiet = c.reminders?.preferences.quietAt(c.now()) ?? false;
    final name = c.companionAssetName,
        low =
            c.companionLayout.lowResource ||
            WidgetsBinding
                .instance
                .platformDispatcher
                .accessibilityFeatures
                .disableAnimations ||
            WidgetsBinding
                .instance
                .platformDispatcher
                .accessibilityFeatures
                .accessibleNavigation;
    final art = '${c.importer.revision}:$name:$low';
    final signature = jsonEncode({
      ...settings.toJson(),
      'enabled': enabled,
      'art': art,
      'expression': c.expression.name,
      'motionRevision': c.companionMotionSequence,
      'quiet': quiet,
    });
    if (signature == _signature) {
      if (enabled) await _readStatus();
      return;
    }
    if (!enabled) {
      await channel.invokeMethod<void>('close');
      _signature = signature;
      _sentArt = null;
      c.reportFloatingError(null);
      c.reportFloatingStatus(null);
      return;
    }
    final data = <String, dynamic>{
      ...settings.toJson(),
      'quiet': quiet,
      'lowResource': low,
      'expression': c.expression.name,
      'motionRevision': c.companionMotionSequence,
      'artKey': art,
      'frames': <Map<String, int>>[],
      'sequence': <int>[],
      'loop': false,
    };
    if (name != null && name.endsWith('.character') && !low) {
      final character = await c.importer.character(name);
      if (character == null) throw StateError('Không đọc được gói nhân vật.');
      final m = character.metadata,
          motion = m.motions[m.motionName(c.expression)]!;
      data['frames'] = m.frames.map((f) => f.toJson()).toList();
      data['sequence'] = motion.frames;
      data['loop'] = motion.loop;
      if (art != _sentArt) {
        data['image'] = await c.importer.atlasBytes(character);
      }
    } else if (name != null) {
      final file = await c.importer.renderFile(name);
      if (file == null) throw StateError('Không đọc được ảnh nhân vật.');
      if (art != _sentArt) data['image'] = await _bounded(file);
    } else if (art != _sentArt) {
      data['image'] = Uint8List(0); // Original vector Mầm, drawn natively.
    }
    if (_stopped || generation != _generation) return;
    await channel.invokeMethod<void>('configure', data);
    _signature = signature;
    _sentArt = art;
    c.reportFloatingError(null);
    await _readStatus();
  }

  Future<void> _readStatus() async {
    final state = await channel.invokeMapMethod<dynamic, dynamic>('state');
    if (_stopped || state == null) return;
    final message = switch (state['reason']) {
      'quiet' => 'Đang ẩn theo giờ yên lặng của DayMind.',
      'focus' => 'Windows đang hạn chế thông báo (chế độ tập trung, nghỉ hoặc trình chiếu); nhân vật tạm ẩn.',
      'fullscreen' => 'Đang ẩn khi ứng dụng khác dùng toàn màn hình.',
      _ => state['visible'] == true ? 'Nhân vật nổi đang hiển thị.' : null,
    };
    controller.reportFloatingStatus(message);
  }

  Future<void> recover() => channel.invokeMethod<void>('recover');

  Future<void> stop() async {
    if (_stopped) return;
    _stopped = true;
    _generation++;
    _policyTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    controller.removeListener(_changed);
    channel.setMethodCallHandler(null);
    await _tail;
    await channel.invokeMethod<void>('close');
    _sentArt = null;
    _signature = null;
  }
}
