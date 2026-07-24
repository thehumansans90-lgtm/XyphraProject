import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';

class ChatHeader extends StatelessWidget {
  final UserProfile targetUser;
  final bool isProfileOpen;
  final VoidCallback onToggleProfile;

  const ChatHeader({
    super.key,
    required this.targetUser,
    required this.isProfileOpen,
    required this.onToggleProfile,
  });

  /// Универсальное безопасное получение аватара
  ImageProvider? _getAvatarImage() {
    // 1. Байты из памяти (высший приоритет)
    if (targetUser.avatarBytes != null && targetUser.avatarBytes!.isNotEmpty) {
      return MemoryImage(targetUser.avatarBytes!);
    }

    final url = targetUser.avatarUrl.trim();
    if (url.isEmpty) return null;

    // 2. Локальный файл (проверка kIsWeb для избежания краша в браузере)
    if (!kIsWeb && (url.startsWith('/') || url.contains(':\\') || url.startsWith('file://'))) {
      final cleanPath = url.replaceFirst('file://', '');
      final file = File(cleanPath);
      if (file.existsSync()) {
        return FileImage(file);
      }
      return null;
    }

    // 3. Сетевой URL (http/https)
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return NetworkImage(url);
    }

    return null;
  }

  bool get _isOwner {
    final cleanUsername = targetUser.username.replaceAll('@', '').toLowerCase();
    final cleanId = targetUser.id.toLowerCase();
    return cleanId == 'honya_4305' ||
        cleanUsername.contains('honya_4305') ||
        targetUser.badges.contains('OWNER');
  }

  bool get _isBot => targetUser.badges.contains('BOT');

  Widget _buildBotBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: Colors.deepPurpleAccent,
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check, size: 9, color: Colors.white),
          SizedBox(width: 2),
          Text(
            'БОТ',
            style: TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOwnerBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
        ),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withValues(alpha: 0.3),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.workspace_premium_rounded, size: 10, color: Colors.black),
          SizedBox(width: 2),
          Text(
            'OWNER',
            style: TextStyle(
              color: Colors.black,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final avatarImage = _getAvatarImage();

    final bool isOnline = _isBot || targetUser.isOnline;
    final String statusText = _isBot
        ? 'в сети 24/7'
        : (isOnline ? 'в сети' : 'был(а) недавно');

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF16161D),
        border: Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          // АВАТАР СОБЕСЕДНИКА
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.deepPurple,
            backgroundImage: avatarImage,
            child: avatarImage == null
                ? Text(
                    targetUser.displayName.isNotEmpty
                        ? targetUser.displayName[0].toUpperCase()
                        : (targetUser.username.isNotEmpty
                            ? targetUser.username[0].toUpperCase()
                            : 'U'),
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 10),

          // ИМЯ, БЕЙДЖИ И СТАТУС СЕТИ
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        targetUser.displayName.isNotEmpty
                            ? targetUser.displayName
                            : targetUser.username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (_isOwner) ...[
                      const SizedBox(width: 6),
                      _buildOwnerBadge(),
                    ] else if (_isBot) ...[
                      const SizedBox(width: 6),
                      _buildBotBadge(),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isOnline ? Colors.greenAccent : Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      statusText,
                      style: TextStyle(
                        color: isOnline ? Colors.greenAccent : Colors.white38,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // КНОПКИ ДЕЙСТВИЙ
          IconButton(
            icon: const Icon(Icons.call, color: Colors.grey, size: 20),
            tooltip: 'Звонок',
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.videocam, color: Colors.grey, size: 20),
            tooltip: 'Видеозвонок',
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.push_pin, color: Colors.grey, size: 20),
            tooltip: 'Закрепленные сообщения',
            onPressed: () {},
          ),
          IconButton(
            icon: Icon(
              Icons.account_box,
              color: isProfileOpen ? Colors.deepPurpleAccent : Colors.grey,
              size: 20,
            ),
            tooltip: 'Профиль пользователя',
            onPressed: onToggleProfile,
          ),
          const SizedBox(width: 8),

          // ПОЛЕ ПОИСКА ПО ЧАТУ
          SizedBox(
            width: 180,
            height: 32,
            child: TextField(
              style: const TextStyle(fontSize: 13, color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Искать в чате...',
                hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                filled: true,
                fillColor: const Color(0xFF0F0F13),
                suffixIcon: const Icon(Icons.search, color: Colors.grey, size: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}