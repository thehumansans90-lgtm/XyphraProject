import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const double size = 1024.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, size, size));

  // 1. Прозрачный общий холст
  final center = Offset(size / 2, size / 2);
  final radius = size * 0.44; // Слегка отступаем от краев для аккуратности

  // 2. Фон-сфера с объемным неоновым градиентом
  final bgGradient = RadialGradient(
    colors: [
      const Color(0xFF1F1A3A), // Светлый фиолетово-синий центр
      const Color(0xFF0F0B1E), // Тёмная глубина
      const Color(0xFF05030A), // Почти чёрный край
    ],
    stops: const [0.0, 0.7, 1.0],
  );

  final bgPaint = Paint()
    ..shader = bgGradient.createShader(
      Rect.fromCircle(center: center, radius: radius),
    );

  // Рисуем основной круг
  canvas.drawCircle(center, radius, bgPaint);

  // 3. Неоновый ободок (Внешнее рамка-свечение круга)
  final strokeGlowPaint = Paint()
    ..shader = const SweepGradient(
      colors: [
        Color(0xFF7C4DFF),
        Color(0xFFE040FB),
        Color(0xFF00E5FF),
        Color(0xFF7C4DFF),
      ],
    ).createShader(Rect.fromCircle(center: center, radius: radius))
    ..style = PaintingStyle.stroke
    ..strokeWidth = 14
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

  final strokePaint = Paint()
    ..shader = const SweepGradient(
      colors: [
        Color(0xFFB388FF),
        Color(0xFFEA80FC),
        Color(0xFF80D8FF),
        Color(0xFFB388FF),
      ],
    ).createShader(Rect.fromCircle(center: center, radius: radius))
    ..style = PaintingStyle.stroke
    ..strokeWidth = 8;

  canvas.drawCircle(center, radius, strokeGlowPaint);
  canvas.drawCircle(center, radius, strokePaint);

  // 4. Отрисовка стилизованного логотипа внутри круга
  _drawXyphraLogoInCircle(canvas, size);

  // 5. Сохраняем в PNG
  final picture = recorder.endRecording();
  final img = await picture.toImage(size.toInt(), size.toInt());
  final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
  final buffer = byteData!.buffer.asUint8List();

  final directory = Directory('assets/icon');
  if (!await directory.exists()) {
    await directory.create(recursive: true);
  }

  final file = File('assets/icon/app_icon.png');
  await file.writeAsBytes(buffer);

  // ignore: avoid_print
  print('✨ УЛЬТРА-ИКОНКА СОЗДАНА: assets/icon/app_icon.png');
  exit(0);
}

void _drawXyphraLogoInCircle(Canvas canvas, double size) {
  final w = size;
  final h = size;

  // Тень/Свечение логотипа
  final paintGlow = Paint()
    ..shader = const LinearGradient(
      colors: [Color(0xFF7C4DFF), Color(0xFFE040FB)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ).createShader(Rect.fromLTWH(0, 0, w, h))
    ..style = PaintingStyle.stroke
    ..strokeWidth = w * 0.075
    ..strokeCap = StrokeCap.round
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28);

  // Основной яркий контур
  final paintLine = Paint()
    ..shader = const LinearGradient(
      colors: [Color(0xFFD1C4E9), Color(0xFFEA80FC), Colors.white],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ).createShader(Rect.fromLTWH(0, 0, w, h))
    ..style = PaintingStyle.stroke
    ..strokeWidth = w * 0.065
    ..strokeCap = StrokeCap.round;

  // Координаты отцентрированы внутри круга
  final pathLeft = Path()
    ..moveTo(w * 0.32, h * 0.32)
    ..lineTo(w * 0.68, h * 0.68);

  final pathBolt = Path()
    ..moveTo(w * 0.68, h * 0.32)
    ..lineTo(w * 0.48, h * 0.52)
    ..lineTo(w * 0.56, h * 0.52)
    ..lineTo(w * 0.32, h * 0.68);

  // Рисуем мягкое свечение
  canvas.drawPath(pathLeft, paintGlow);
  canvas.drawPath(pathBolt, paintGlow);

  // Рисуем четкий неоновый вектор
  canvas.drawPath(pathLeft, paintLine);
  canvas.drawPath(pathBolt, paintLine);
}