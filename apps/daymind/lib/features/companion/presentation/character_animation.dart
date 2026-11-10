import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderAbstractViewport;

import '../data/asset_importer.dart';
import '../domain/character_package.dart';
import '../domain/companion.dart';

/// Owns one bounded atlas. Hidden, covered, reduced-motion and background
/// portraits release it, rather than merely stopping a ticker with a live GPU image.
class CharacterAnimationView extends StatefulWidget {
  const CharacterAnimationView({
    super.key,
    required this.importer,
    required this.name,
    required this.expression,
    required this.fallback,
    this.active = true,
  });
  final StaticAssetImporter importer;
  final String name;
  final CompanionExpression expression;
  final Widget fallback;
  final bool active;
  @override
  State<CharacterAnimationView> createState() => _CharacterAnimationViewState();
}

class _CharacterAnimationViewState extends State<CharacterAnimationView>
    with WidgetsBindingObserver {
  ui.Image? _atlas;
  CharacterRenderData? _metadata;
  Timer? _timer;
  ScrollPosition? _scroll;
  int _generation = 0, _step = 0, _revision = 0;
  bool _visible = false, _foreground = true, _allowed = false;
  bool _loading = false, _failed = false, _visibilityScheduled = false;
  bool get _running => widget.active && _allowed && _foreground && _visible;
  CharacterMotion? get _motion =>
      _metadata?.motions[_metadata!.motionName(widget.expression)];

  @override
  void initState() {
    super.initState();
    _revision = widget.importer.revision;
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _allowed =
        TickerMode.valuesOf(context).enabled &&
        ModalRoute.isCurrentOf(context) != false &&
        !MediaQuery.disableAnimationsOf(context) &&
        !MediaQuery.accessibleNavigationOf(context);
    final position = Scrollable.maybeOf(context)?.position;
    if (position != _scroll) {
      _scroll?.removeListener(_scheduleVisibility);
      _scroll = position;
      _scroll?.addListener(_scheduleVisibility);
    }
    _scheduleVisibility();
    _sync();
  }

  @override
  void didUpdateWidget(CharacterAnimationView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.name != widget.name ||
        oldWidget.importer != widget.importer ||
        _revision != widget.importer.revision) {
      _revision = widget.importer.revision;
      _release();
      _failed = false;
    } else if (oldWidget.expression != widget.expression) {
      _timer?.cancel();
      _timer = null;
      _step = 0;
    }
    _scheduleVisibility();
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (mounted) setState(_sync);
  }

  void _scheduleVisibility() {
    if (_visibilityScheduled || !mounted) return;
    _visibilityScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _visibilityScheduled = false;
      if (!mounted) return;
      final box = context.findRenderObject();
      var visible = false;
      if (box is RenderBox && box.attached && box.hasSize) {
        final viewport = RenderAbstractViewport.maybeOf(box);
        final rect = MatrixUtils.transformRect(
          box.getTransformTo(viewport),
          Offset.zero & box.size,
        );
        final clip =
            viewport?.paintBounds ?? (Offset.zero & MediaQuery.sizeOf(context));
        visible = rect.overlaps(clip) && !rect.isEmpty;
      }
      if (visible != _visible) {
        setState(() {
          _visible = visible;
          _sync();
        });
      }
    });
  }

  void _release() {
    _generation++;
    _timer?.cancel();
    _timer = null;
    _atlas?.dispose();
    _atlas = null;
    _metadata = null;
    _loading = false;
    _step = 0;
  }

  void _sync() {
    if (!_running) {
      if (_atlas != null || _loading) _release();
      return;
    }
    if (_atlas != null) {
      _scheduleFrame();
    } else if (!_loading && !_failed) {
      _loading = true;
      unawaited(_load(++_generation));
    }
  }

  Future<void> _load(int generation) async {
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    ui.Image? image;
    bool stale() => !mounted || generation != _generation || !_running;
    try {
      final character = await widget.importer.character(widget.name);
      if (stale() || character == null) return;
      final bytes = await widget.importer.atlasBytes(character);
      if (stale()) return;
      if (bytes.length > 8 * 1024 * 1024) throw StateError('Atlas quá lớn.');
      buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      final meta = character.metadata;
      if (descriptor.width != meta.width || descriptor.height != meta.height) {
        throw StateError('Atlas không khớp metadata.');
      }
      if (stale()) return;
      codec = await descriptor.instantiateCodec();
      if (codec.frameCount != 1) throw StateError('Atlas phải là ảnh tĩnh.');
      image = (await codec.getNextFrame()).image;
      if (stale()) return;
      setState(() {
        _atlas = image;
        image = null; // Ownership transfers only after the generation check.
        _metadata = meta;
        _step = 0;
        _loading = false;
        _scheduleFrame();
      });
    } catch (_) {
      if (!stale()) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    } finally {
      image?.dispose();
      codec?.dispose();
      descriptor?.dispose();
      buffer?.dispose();
    }
  }

  void _scheduleFrame() {
    final motion = _motion;
    if (_timer != null ||
        !_running ||
        motion == null ||
        motion.frames.length < 2 ||
        (!motion.loop && _step == motion.frames.length - 1)) {
      return;
    }
    // Timings are validated/clamped to 84–5000ms, so delayed frames never catch
    // up in a burst or exceed twelve updates per second.
    _timer = Timer(
      Duration(
        milliseconds: _metadata!.frames[motion.frames[_step]].durationMs,
      ),
      () {
        _timer = null;
        if (!mounted || !_running) return;
        setState(() {
          _step = (_step + 1) % motion.frames.length;
          _scheduleFrame();
        });
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scroll?.removeListener(_scheduleVisibility);
    _release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final motion = _motion, atlas = _atlas;
    return RepaintBoundary(
      child: atlas == null || motion == null
          ? widget.fallback
          : CustomPaint(
              painter: CharacterFramePainter(
                atlas,
                _metadata!.frames[motion.frames[_step]],
              ),
            ),
    );
  }
}

class CharacterFramePainter extends CustomPainter {
  const CharacterFramePainter(this.atlas, this.frame);
  final ui.Image atlas;
  final SpriteFrame frame;
  @override
  void paint(Canvas canvas, Size size) {
    final target = applyBoxFit(
      BoxFit.contain,
      const Size(128, 128),
      size,
    ).destination;
    canvas.drawImageRect(
      atlas,
      Rect.fromLTWH(frame.x.toDouble(), frame.y.toDouble(), 128, 128),
      Alignment.center.inscribe(target, Offset.zero & size),
      Paint()..filterQuality = FilterQuality.low,
    );
  }

  @override
  bool shouldRepaint(CharacterFramePainter oldDelegate) =>
      oldDelegate.atlas != atlas || oldDelegate.frame != frame;
}
