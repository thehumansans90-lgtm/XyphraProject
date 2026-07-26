import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../widgets/xyphra_logo.dart'; // 👈 Импортируем наш векторный логотип!

class UserAvatar extends StatelessWidget {
  final UserProfile user;
  final bool isBot;
  final double radius;

  const UserAvatar({
    super.key,
    required this.user,
    this.isBot = false,
    this.radius = 18.0,
  });

  /// 📌 Проверка: это чат «Избранное»?
  bool get _isSavedMessages {
    return user.id == 'saved_messages' ||
        user.username == 'saved_messages' ||
        user.badges.contains('SAVED');
  }

  /// 🤖 Проверка: это бот Xyphra?
  bool get _isBotUser {
    return isBot ||
        user.badges.contains('BOT') ||
        user.id.toLowerCase().contains('bot') ||
        user.username.toLowerCase().contains('bot');
  }

  /// 🖼️ Получение изображения (Bytes / File / Network)
  ImageProvider? _getAvatarImage() {
    if (user.avatarBytes != null && user.avatarBytes!.isNotEmpty) {
      return MemoryImage(user.avatarBytes!);
    }

    final url = user.avatarUrl.trim();
    if (url.isEmpty) return null;

    if (!kIsWeb &&
        (url.startsWith('/') ||
            url.contains(':\\') ||
            url.startsWith('file://'))) {
      final cleanPath = url.replaceFirst('file://', '');
      final file = File(cleanPath);
      if (file.existsSync()) {
        return FileImage(file);
      }
      return null;
    }

    if (url.startsWith('http://') || url.startsWith('https://')) {
      return NetworkImage(url);
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final avatarImage = _getAvatarImage();

    // 📌 1. ЕСЛИ ЭТО ИЗБРАННОЕ (Saved Messages) -> Оранжевая закладка
    if (_isSavedMessages) {
      return Container(
        width: radius * 2,
        height: radius * 2,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFB300), Color(0xFFFF8C00)],
          ),
        ),
        child: Icon(
          Icons.bookmark_rounded,
          color: Colors.white,
          size: radius * 1.1,
        ),
      );
    }

    // ⚡ 2. ЕСЛИ ЭТО БОТ XYPHRA И НЕТ СВОЕГО ФОТО -> Отрисовываем XyphraLogo!
    if (_isBotUser && avatarImage == null) {
      return Container(
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF10121B),
          border: Border.all(
            color: const Color(0xFF7C4DFF).withValues(alpha: 0.6),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7C4DFF).withValues(alpha: 0.2),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Center(
          child: XyphraLogo(
              size:
                  radius * 1.25), // 👈 Вшиваем XyphraLogo с неоновым молнией-X!
        ),
      );
    }

    // 👤 3. ОБЫЧНЫЙ ПОЛЬЗОВАТЕЛЬ (Аватарка или Первая буква)
    final String initial = user.displayName.isNotEmpty
        ? user.displayName[0].toUpperCase()
        : (user.username.isNotEmpty ? user.username[0].toUpperCase() : 'U');

    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFF2A2D3D),
      backgroundImage: avatarImage,
      child: avatarImage == null
          ? Text(
              initial,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: radius * 0.8,
              ),
            )
          : null,
    );
  }
}
