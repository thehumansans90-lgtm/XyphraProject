import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class PhotoCropperDialog extends StatefulWidget {
  final Uint8List imageBytes;

  const PhotoCropperDialog({
    super.key,
    required this.imageBytes,
  });

  @override
  State<PhotoCropperDialog> createState() => _PhotoCropperDialogState();
}

class _PhotoCropperDialogState extends State<PhotoCropperDialog> {
  final TransformationController _transformationController = TransformationController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  Future<void> _cropAndSave() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    ui.Codec? codec;
    ui.FrameInfo? frame;
    ui.Image? originalImage;
    ui.Image? croppedImage;

    try {
      // 1. Декодируем исходное изображение
      codec = await ui.instantiateImageCodec(widget.imageBytes);
      frame = await codec.getNextFrame();
      originalImage = frame.image;

      final double imgWidth = originalImage.width.toDouble();
      final double imgHeight = originalImage.height.toDouble();

      // Размеры вьюпорта и области обрезки
      const double viewportWidth = 380.0;
      const double viewportHeight = 300.0;
      const double cropSize = 220.0;

      // 2. Расчет вписывания (BoxFit.contain)
      final double scaleX = viewportWidth / imgWidth;
      final double scaleY = viewportHeight / imgHeight;
      final double fittedScale = scaleX < scaleY ? scaleX : scaleY;

      final double fittedW = imgWidth * fittedScale;
      final double fittedH = imgHeight * fittedScale;

      final double initialOffsetX = (viewportWidth - fittedW) / 2;
      final double initialOffsetY = (viewportHeight - fittedH) / 2;

      // 3. Расчет пользовательской трансформации
      final Matrix4 matrix = _transformationController.value;
      final double userScale = matrix.getMaxScaleOnAxis();
      final double userTranslationX = matrix.storage[12];
      final double userTranslationY = matrix.storage[13];

      const Offset cropCenterInViewport = Offset(viewportWidth / 2, viewportHeight / 2);

      final double cropCenterInFittedX = cropCenterInViewport.dx - userTranslationX;
      final double cropCenterInFittedY = cropCenterInViewport.dy - userTranslationY;

      final double cropCenterInImageX = (cropCenterInFittedX - initialOffsetX) / (fittedScale * userScale);
      final double cropCenterInImageY = (cropCenterInFittedY - initialOffsetY) / (fittedScale * userScale);

      final double cropRadiusInImage = (cropSize / 2) / (fittedScale * userScale);

      // 4. Отрисовка с помощью Canvas
      const int outputSize = 512;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      final cropRect = Rect.fromLTWH(0, 0, outputSize.toDouble(), outputSize.toDouble());
      canvas.clipPath(Path()..addOval(cropRect));

      final double outputScale = outputSize / (cropRadiusInImage * 2);
      canvas.scale(outputScale, outputScale);
      canvas.translate(
        -(cropCenterInImageX - cropRadiusInImage),
        -(cropCenterInImageY - cropRadiusInImage),
      );

      canvas.drawImage(
        originalImage,
        Offset.zero,
        Paint()..filterQuality = FilterQuality.high,
      );

      final picture = recorder.endRecording();
      croppedImage = await picture.toImage(outputSize, outputSize);
      picture.dispose(); // Освобождаем память

      final byteData = await croppedImage.toByteData(format: ui.ImageByteFormat.png);

      if (byteData != null && mounted) {
        final Uint8List resultBytes = byteData.buffer.asUint8List();
        Navigator.pop(context, resultBytes);
      } else if (mounted) {
        Navigator.pop(context, widget.imageBytes);
      }
    } catch (e) {
      debugPrint('Ошибка кроппера: $e');
      if (mounted) {
        Navigator.pop(context, widget.imageBytes);
      }
    } finally {
      // Очистка нативных ресурсов во избежание утечки памяти
      originalImage?.dispose();
      croppedImage?.dispose();
      codec?.dispose();

      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF13151E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Настройка фотографии',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white38),
                  onPressed: _isProcessing ? null : () => Navigator.pop(context, null),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Поле настройки и маски
            Container(
              height: 300,
              width: double.infinity,
              clipBehavior: Clip.hardEdge,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.deepPurpleAccent.withValues(alpha: 0.5)),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  InteractiveViewer(
                    transformationController: _transformationController,
                    boundaryMargin: const EdgeInsets.all(200),
                    minScale: 0.8,
                    maxScale: 4.0,
                    panEnabled: !_isProcessing,
                    scaleEnabled: !_isProcessing,
                    child: Image.memory(
                      widget.imageBytes,
                      fit: BoxFit.contain,
                    ),
                  ),

                  // Маска обрезки
                  IgnorePointer(
                    child: Stack(
                      children: [
                        ColorFiltered(
                          colorFilter: ColorFilter.mode(
                            Colors.black.withValues(alpha: 0.65),
                            BlendMode.srcOut,
                          ),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Container(color: Colors.black),
                              Center(
                                child: Container(
                                  width: 220,
                                  height: 220,
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Рамка с сеткой
                        Center(
                          child: Container(
                            width: 220,
                            height: 220,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1.5),
                            ),
                            child: CustomPaint(
                              painter: CropGridPainter(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            const Text(
              'Зажмите и двигайте мышкой для позиционирования',
              style: TextStyle(color: Colors.white38, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isProcessing ? null : () => Navigator.pop(context, null),
                  child: const Text('Отмена', style: TextStyle(color: Colors.white38)),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurpleAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _isProcessing ? null : _cropAndSave,
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_rounded, size: 18),
                  label: Text(
                    _isProcessing ? 'Обработка...' : 'Применить',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class CropGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(size.width / 3, 0), Offset(size.width / 3, size.height), paint);
    canvas.drawLine(Offset(size.width * 2 / 3, 0), Offset(size.width * 2 / 3, size.height), paint);

    canvas.drawLine(Offset(0, size.height / 3), Offset(size.width, size.height / 3), paint);
    canvas.drawLine(Offset(0, size.height * 2 / 3), Offset(size.width, size.height * 2 / 3), paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}