import 'dart:ui';
import 'dart:typed_data';
import 'package:flutter/material.dart';

class MediaViewerDialog extends StatefulWidget {
  final List<Uint8List> mediaList;
  final int initialIndex;

  const MediaViewerDialog({
    super.key,
    required this.mediaList,
    this.initialIndex = 0,
  });

  @override
  State<MediaViewerDialog> createState() => _MediaViewerDialogState();
}

class _MediaViewerDialogState extends State<MediaViewerDialog> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _previousPage() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _nextPage() {
    if (_currentIndex < widget.mediaList.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasMultiple = widget.mediaList.length > 1;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. Полупрозрачный размытый фон + Клик по пустому месту для закрытия
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), // Размытие фона заднего плана
              child: Container(
                color: Colors.black.withValues(alpha: 0.65), // Полупрозрачный черный цвет
                width: double.infinity,
                height: double.infinity,
              ),
            ),
          ),

          // 2. Карусель с изображениями
          PageView.builder(
            controller: _pageController,
            itemCount: widget.mediaList.length,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            itemBuilder: (context, index) {
              return Center(
                // GestureDetector с GestureDetector.opaque предотвращает закрытие при клике на саму картинку
                child: GestureDetector(
                  onTap: () {}, // Поглощаем клик по картинке
                  child: InteractiveViewer(
                    maxScale: 4.0,
                    child: Image.memory(
                      widget.mediaList[index],
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              );
            },
          ),

          // 3. Кнопка ЗАКРЫТЬ (Крестик)
          Positioned(
            top: 24,
            right: 24,
            child: IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
              style: IconButton.styleFrom(
                backgroundColor: Colors.black.withValues(alpha: 0.5),
                padding: const EdgeInsets.all(8),
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          // 4. Стрелка ВЛЕВО
          if (hasMultiple && _currentIndex > 0)
            Positioned(
              left: 16,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 26),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: 0.5),
                  padding: const EdgeInsets.all(12),
                ),
                onPressed: _previousPage,
              ),
            ),

          // 5. Стрелка ВПРАВО
          if (hasMultiple && _currentIndex < widget.mediaList.length - 1)
            Positioned(
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 26),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: 0.5),
                  padding: const EdgeInsets.all(12),
                ),
                onPressed: _nextPage,
              ),
            ),

          // 6. Счетчик картинок ("1 / 3")
          if (hasMultiple)
            Positioned(
              bottom: 24,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${_currentIndex + 1} / ${widget.mediaList.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}