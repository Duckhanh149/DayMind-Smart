import 'character_package.dart';
import 'companion.dart';

/// Playback contract for a renderer adapter. The host owns timers, visibility,
/// textures and platform resources; an adapter must release its own state on
/// dispose. This contract neither loads models nor authorizes an SDK.
abstract interface class CompanionRenderer<Frame> {
  Frame? get frame;
  Duration? get nextFrameDelay;
  void selectExpression(CompanionExpression expression, {bool restart = false});
  void advance();
  void dispose();
}

/// The shipped raster adapter. No Flutter, GPU, file or network dependency.
final class AtlasCompanionRenderer implements CompanionRenderer<SpriteFrame> {
  AtlasCompanionRenderer(
    CharacterRenderData metadata,
    CompanionExpression expression,
  ) : _metadata = metadata,
      _expression = expression;

  CharacterRenderData? _metadata;
  CompanionExpression _expression;
  int _step = 0;
  CharacterMotion? get _motion =>
      _metadata?.motions[_metadata!.motionName(_expression)];

  @override
  SpriteFrame? get frame {
    final motion = _motion;
    return motion == null ? null : _metadata!.frames[motion.frames[_step]];
  }

  @override
  Duration? get nextFrameDelay {
    final motion = _motion;
    if (motion == null ||
        motion.frames.length < 2 ||
        (!motion.loop && _step == motion.frames.length - 1)) {
      return null;
    }
    return Duration(milliseconds: frame!.durationMs);
  }

  @override
  void selectExpression(
    CompanionExpression expression, {
    bool restart = false,
  }) {
    if (restart || expression != _expression) _step = 0;
    _expression = expression;
  }

  @override
  void advance() {
    if (nextFrameDelay == null) return;
    _step = (_step + 1) % _motion!.frames.length;
  }

  @override
  void dispose() {
    _metadata = null;
    _step = 0;
  }
}
