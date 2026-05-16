import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:pry_app/core/theme/app_theme.dart';

/// Original "Imperial Helm" emblem painted from primitives — not a copy
/// of any external artwork. Acts as the brand mark across the app.
///
/// Composition (purely geometric):
///  • shield-like back medallion (steel)
///  • domed helmet with curved brim
///  • crimson plume rising from the crown
///  • single golden ring framing the whole mark
///  • ornamental gold dot on the visor
class AppLogo extends StatelessWidget {
  final double size;
  final bool showRing;
  final Color background;

  const AppLogo({
    super.key,
    this.size = 96,
    this.showRing = true,
    this.background = AppTheme.steel,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ImperialHelmPainter(
          background: background,
          showRing: showRing,
        ),
      ),
    );
  }
}

class _ImperialHelmPainter extends CustomPainter {
  final Color background;
  final bool showRing;

  _ImperialHelmPainter({required this.background, required this.showRing});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;
    final r = math.min(w, h) / 2;

    // 1. Background medallion (round shield).
    canvas.drawCircle(Offset(cx, cy), r, Paint()..color = background);

    // 2. Outer gold ring.
    if (showRing) {
      final ring = Paint()
        ..color = AppTheme.gold
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.05;
      canvas.drawCircle(Offset(cx, cy), r * 0.94, ring);
    }

    // 3. Crimson plume — slim teardrop above the crown.
    final plumePath = Path()
      ..moveTo(cx, cy - r * 0.95)
      ..quadraticBezierTo(
          cx + r * 0.10, cy - r * 0.55, cx, cy - r * 0.40)
      ..quadraticBezierTo(
          cx - r * 0.10, cy - r * 0.55, cx, cy - r * 0.95)
      ..close();
    canvas.drawPath(plumePath, Paint()..color = AppTheme.crimson);

    // 4. Helmet dome (rounded body) with subtle gold rim outline.
    final helmRect = Rect.fromLTWH(
      cx - r * 0.55,
      cy - r * 0.45,
      r * 1.10,
      r * 0.95,
    );
    final helmPath = Path()
      ..moveTo(helmRect.left, helmRect.bottom - r * 0.05)
      ..arcToPoint(
        Offset(helmRect.right, helmRect.bottom - r * 0.05),
        radius: Radius.circular(r * 0.65),
        clockwise: true,
      )
      ..lineTo(helmRect.right, helmRect.bottom + r * 0.05)
      // brim — flares slightly outward
      ..quadraticBezierTo(
        helmRect.right + r * 0.10,
        helmRect.bottom + r * 0.18,
        helmRect.right - r * 0.10,
        helmRect.bottom + r * 0.22,
      )
      ..lineTo(helmRect.left + r * 0.10, helmRect.bottom + r * 0.22)
      ..quadraticBezierTo(
        helmRect.left - r * 0.10,
        helmRect.bottom + r * 0.18,
        helmRect.left,
        helmRect.bottom + r * 0.05,
      )
      ..close();

    canvas.drawPath(
      helmPath,
      Paint()..color = AppTheme.steelLight,
    );
    canvas.drawPath(
      helmPath,
      Paint()
        ..color = AppTheme.gold.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.025,
    );

    // 5. Visor band — a darker horizontal strip across the helmet.
    final visorRect = Rect.fromLTWH(
      helmRect.left + r * 0.05,
      cy - r * 0.05,
      helmRect.width - r * 0.10,
      r * 0.20,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(visorRect, Radius.circular(r * 0.05)),
      Paint()..color = AppTheme.ink,
    );

    // 6. Central golden stud on the visor.
    canvas.drawCircle(
      Offset(cx, cy + r * 0.05),
      r * 0.06,
      Paint()..color = AppTheme.gold,
    );
  }

  @override
  bool shouldRepaint(covariant _ImperialHelmPainter oldDelegate) =>
      oldDelegate.background != background || oldDelegate.showRing != showRing;
}
