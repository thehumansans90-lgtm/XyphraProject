import 'package:flutter/material.dart';

/// Универсальный неоновый логотип Xyphra
/// Используется на экранах авторизации, в сайдбаре, рабочей области и т.д.
class XyphraLogo extends StatelessWidget {
  final double size;

  const XyphraLogo({super.key, this.size = 60});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _XyphraLogoPainter(),
      ),
    );
  }
}

class _XyphraLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Градиент для неонового свечения
    final paintGlow = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF7C4DFF), Color(0xFFE040FB)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.09
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    // Основная кисть для четких неоновых линий
    final paintLine = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFB388FF), Color(0xFFEA80FC), Colors.white],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.08
      ..strokeCap = StrokeCap.round;

    // Путь 1: Левая диагональ X
    final pathLeft = Path()
      ..moveTo(w * 0.2, h * 0.2)
      ..lineTo(w * 0.8, h * 0.8);

    // Путь 2: Правая диагональ в виде молнии (XYPHRA Bolt X)
    final pathBolt = Path()
      ..moveTo(w * 0.8, h * 0.2)
      ..lineTo(w * 0.48, h * 0.52)
      ..lineTo(w * 0.58, h * 0.52)
      ..lineTo(w * 0.2, h * 0.8);

    // Отрисовка свечения
    canvas.drawPath(pathLeft, paintGlow);
    canvas.drawPath(pathBolt, paintGlow);

    // Отрисовка четких линий
    canvas.drawPath(pathLeft, paintLine);
    canvas.drawPath(pathBolt, paintLine);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
