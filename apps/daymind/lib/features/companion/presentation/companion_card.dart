import 'package:flutter/material.dart';

import '../../../app/controller.dart';

class CompanionCard extends StatelessWidget {
  const CompanionCard({
    super.key,
    required this.controller,
    this.compact = false,
  });
  final WorkspaceController controller;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final size = compact ? 56.0 : controller.preferences.companionSize;
    final file = controller.importer.resolve(controller.preferences.assetName);
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer
          .withValues(alpha: .45),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: size,
              height: size,
              child: Semantics(
                label: 'Mầm, nhân vật đồng hành 2D tĩnh',
                child: file != null && file.existsSync()
                    ? Image(
                        image: ResizeImage(
                          FileImage(file),
                          width: 256,
                          height: 256,
                          policy: ResizeImagePolicy.fit,
                          allowUpscaling: false,
                        ),
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const MamMascot(),
                      )
                    : const MamMascot(),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mầm ở đây cùng bạn',
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MamMascot extends StatelessWidget {
  const MamMascot({super.key});
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _MamPainter());
}

class _MamPainter extends CustomPainter {
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
    canvas.drawCircle(
      const Offset(36, 55),
      3,
      paint..color = const Color(0xff3e543a),
    );
    canvas.drawCircle(const Offset(64, 55), 3, paint);
    final smile = Path()
      ..moveTo(44, 65)
      ..quadraticBezierTo(50, 71, 56, 65);
    canvas.drawPath(
      smile,
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
