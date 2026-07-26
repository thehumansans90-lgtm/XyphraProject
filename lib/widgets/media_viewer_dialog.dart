import 'dart:ui';
import 'dart:typed_data';
import 'package:flutter/material.dart';

class MediaViewerDialog extends StatefulWidget {
  final List<Uint8List>? mediaList;
  final List<String>? mediaUrls;
  final int initialIndex;

  const MediaViewerDialog({
    super.key,
    this.mediaList,
    this.mediaUrls,
    this.initialIndex = 0,
  });

  @override
  State<MediaViewerDialog> createState() => _MediaViewerDialogState();
}

class _MediaViewerDialogState extends State<MediaViewerDialog> {
  late PageController _pageController;
  late int _currentIndex;

  int get _totalCount {
    if (widget.mediaUrls != null && widget.mediaUrls!.isNotEmpty) {
      return widget.mediaUrls!.length;
    }
    if (widget.mediaList != null && widget.mediaList!.isNotEmpty) {
      return widget.mediaList!.length;
    }
    return 0;
  }

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
    if (_currentIndex < _totalCount - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Widget _buildImageItem(int index) {
    // 1. Отображение по сетевым ссылкам Supabase (Основной случай)
    if (widget.mediaUrls != null && index < widget.mediaUrls!.length) {
      final url = widget.mediaUrls![index];
      return Image.network(
        url,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.broken_image_rounded, color: Colors.white54, size: 48),
              SizedBox(height: 8),
              Text(
                'Ошибка загрузки',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          );
        },
      );
    }

    // 2. Отображение по байтам (Локально до отправки)
    if (widget.mediaList != null && index < widget.mediaList!.length) {
      return Image.memory(
        widget.mediaList![index],
        fit: BoxFit.contain,
      );
    }

    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final hasMultiple = _totalCount > 1;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. Размытый фон + закрытие по клику мимо картинки
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                color: Colors.black.withValues(alpha: 0.75),
                width: double.infinity,
                height: double.infinity,
              ),
            ),
          ),

          // 2. Карусель с изображениями
          if (_totalCount > 0)
            PageView.builder(
              controller: _pageController,
              itemCount: _totalCount,
              onPageChanged: (index) => setState(() => _currentIndex = index),
              itemBuilder: (context, index) {
                return Center(
                  child: GestureDetector(
                    onTap: () {}, // Поглощаем клик по картинке
                    child: InteractiveViewer(
                      maxScale: 4.0,
                      child: _buildImageItem(index),
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
              icon: const Icon(Icons.close_rounded,
                  color: Colors.white, size: 28),
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
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 26),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: 0.5),
                  padding: const EdgeInsets.all(12),
                ),
                onPressed: _previousPage,
              ),
            ),

          // 5. Стрелка ВПРАВО
          if (hasMultiple && _currentIndex < _totalCount - 1)
            Positioned(
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.arrow_forward_ios_rounded,
                    color: Colors.white, size: 26),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${_currentIndex + 1} / $_totalCount',
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
