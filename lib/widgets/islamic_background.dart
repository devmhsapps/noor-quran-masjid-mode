import 'dart:math' as math;

import 'package:flutter/material.dart';

class IslamicBackground extends StatelessWidget {
  const IslamicBackground({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF062D21), Color(0xFF0B3D2E), Color(0xFF08281E)],
            ),
          ),
        ),
        CustomPaint(painter: _IslamicPatternPainter()),
        child,
      ],
    );
  }
}

class _IslamicPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = const Color(0xFFC58A28).withValues(alpha: .16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final glow = Paint()..color = const Color(0xFFF8F5EE).withValues(alpha: .05);

    canvas.drawCircle(Offset(size.width * .08, size.height * .18), size.width * .33, glow);
    canvas.drawCircle(Offset(size.width * .92, size.height * .84), size.width * .38, glow);

    for (var y = 40.0; y < size.height; y += 76) {
      for (var x = -20.0; x < size.width + 20; x += 76) {
        final center = Offset(x, y);
        canvas.save();
        canvas.translate(center.dx, center.dy);
        canvas.rotate(math.pi / 4);
        canvas.drawRect(const Rect.fromCenter(center: Offset.zero, width: 30, height: 30), line);
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
