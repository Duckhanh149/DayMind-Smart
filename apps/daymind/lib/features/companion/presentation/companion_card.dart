import 'package:flutter/material.dart';

import '../../../app/controller.dart';
import '../domain/companion.dart';

class CompanionCard extends StatelessWidget {
  const CompanionCard({
    super.key,
    required this.controller,
    this.compact = false,
  });
  final WorkspaceController controller;
  final bool compact;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
      final layout = controller.companionLayout;
      final size = layout.effectiveSize(
        width: MediaQuery.sizeOf(context).width,
        textScale: scale,
      );
      final file = controller.importer.resolve(controller.companionAssetName);
      final portrait = SizedBox(
        key: const Key('companion-portrait'),
        width: size,
        height: size,
        child: Semantics(
          label:
              '${controller.companion.name}, bạn đồng hành 2D · ${companionExpressionLabels[controller.expression]}',
          child: file != null && file.existsSync()
              ? Image(
                  image: ResizeImage(
                    FileImage(file),
                    width: layout.lowResource ? 128 : 256,
                    height: layout.lowResource ? 128 : 256,
                    policy: ResizeImagePolicy.fit,
                    allowUpscaling: false,
                  ),
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) =>
                      MamMascot(expression: controller.expression),
                )
              : MamMascot(expression: controller.expression),
        ),
      );
      final words = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${controller.companion.name} ở đây cùng bạn',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          Text(
            controller.dialogue,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (!compact)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Companion 2D · Luôn im lặng',
                style: TextStyle(fontSize: 11),
              ),
            ),
        ],
      );
      final narrow = constraints.maxWidth - 40 - size - 16 < 140 * scale;
      final right = layout.placement == CompanionPlacement.right;
      return Card(
        color: Theme.of(context).colorScheme.secondaryContainer
            .withValues(alpha: .45),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: narrow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: right
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: portrait,
                    ),
                    const SizedBox(height: 12),
                    words,
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (!right) ...[portrait, const SizedBox(width: 16)],
                    Expanded(child: words),
                    if (right) ...[const SizedBox(width: 16), portrait],
                  ],
                ),
        ),
      );
    },
  );
}

class MamMascot extends StatelessWidget {
  const MamMascot({super.key, this.expression = CompanionExpression.neutral});
  final CompanionExpression expression;
  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _MamPainter(expression));
}

class _MamPainter extends CustomPainter {
  _MamPainter(this.expression);
  final CompanionExpression expression;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    final paint = Paint()..isAntiAlias = true;
    canvas.drawOval(
      const Rect.fromLTWH(14, 86, 72, 9),
      paint..color = const Color(0x18637547),
    );
    final leaf = Path()
      ..moveTo(50, 28)
      ..quadraticBezierTo(20, 22, 27, 5)
      ..quadraticBezierTo(55, 2, 50, 28);
    canvas.drawPath(leaf, paint..color = const Color(0xff95b76c));
    final leaf2 = Path()
      ..moveTo(49, 28)
      ..quadraticBezierTo(50, 4, 75, 8)
      ..quadraticBezierTo(78, 29, 49, 28);
    canvas.drawPath(leaf2, paint..color = const Color(0xff6f9857));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(15, 25, 70, 64),
        const Radius.circular(31),
      ),
      paint..color = const Color(0xffdbe8b9),
    );
    canvas.drawOval(
      const Rect.fromLTWH(7, 55, 18, 24),
      paint..color = const Color(0xffc3d897),
    );
    canvas.drawOval(const Rect.fromLTWH(77, 55, 18, 24), paint);
    canvas.drawOval(
      const Rect.fromLTWH(23, 63, 13, 7),
      paint..color = const Color(0xffe8b8a1),
    );
    canvas.drawOval(const Rect.fromLTWH(64, 63, 13, 7), paint);
    paint
      ..color = const Color(0xff3e543a)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    if (expression == CompanionExpression.resting) {
      canvas.drawLine(const Offset(32, 55), const Offset(40, 55), paint);
      canvas.drawLine(const Offset(60, 55), const Offset(68, 55), paint);
    } else if (expression == CompanionExpression.happy) {
      for (final x in [36.0, 64.0]) {
        canvas.drawPath(
          Path()
            ..moveTo(x - 4, 56)
            ..quadraticBezierTo(x, 48, x + 4, 56),
          paint,
        );
      }
    } else {
      canvas.drawCircle(
        const Offset(36, 55),
        3,
        paint..style = PaintingStyle.fill,
      );
      canvas.drawCircle(const Offset(64, 55), 3, paint);
      paint.style = PaintingStyle.stroke;
      if (expression == CompanionExpression.focused) {
        canvas.drawLine(const Offset(31, 47), const Offset(40, 49), paint);
        canvas.drawLine(const Offset(60, 49), const Offset(69, 47), paint);
      }
    }
    final mouth = Path()..moveTo(44, 65);
    if (expression == CompanionExpression.focused ||
        expression == CompanionExpression.resting) {
      mouth.lineTo(56, 65);
    } else {
      mouth.quadraticBezierTo(
        50,
        expression == CompanionExpression.happy ? 77 : 71,
        56,
        65,
      );
    }
    canvas.drawPath(mouth, paint..style = PaintingStyle.stroke);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MamPainter oldDelegate) =>
      oldDelegate.expression != expression;
}
