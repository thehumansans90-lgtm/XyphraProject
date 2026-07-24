import 'package:flutter/material.dart';
import '../models/user_model.dart';

class ChatWelcomeCard extends StatelessWidget {
  final UserProfile targetUser;
  final bool isBot;
  final bool isSavedMessages; // Флаг для «Избранного»

  const ChatWelcomeCard({
    super.key,
    required this.targetUser,
    this.isBot = false,
    this.isSavedMessages = false,
  });

  // Определение изображения аватарки
  ImageProvider? _getAvatarImage() {
    if (targetUser.avatarBytes != null && targetUser.avatarBytes!.isNotEmpty) {
      return MemoryImage(targetUser.avatarBytes!);
    }
    if (targetUser.avatarUrl.isNotEmpty) {
      return NetworkImage(targetUser.avatarUrl);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final avatarImage = _getAvatarImage();

    // Проверяем, является ли пользователь ботом (через проп или бейдж в модели)
    final bool effectiveIsBot = isBot || targetUser.badges.contains('BOT');
    
    // Статус сети (если у тебя в UserModel есть поле isOnline)
    final bool isOnline = targetUser.isOnline;

    // Определяем цвет и всплывающий текст индикатора
    final Color statusColor = effectiveIsBot
        ? const Color(0xFF23A55A) // Зеленый для ботов
        : (isOnline ? const Color(0xFF23A55A) : const Color(0xFF80848E)); // Зеленый / Серый

    final String statusTooltip = effectiveIsBot
        ? 'В сети 24/7'
        : (isOnline ? 'В сети' : 'Не в сети');

    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // АВАТАР
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: isSavedMessages
                    ? Colors.amber.shade700
                    : Colors.deepPurpleAccent,
                backgroundImage: avatarImage,
                child: avatarImage == null
                    ? (isSavedMessages
                        ? const Icon(Icons.bookmark_rounded, size: 40, color: Colors.white)
                        : Text(
                            targetUser.displayName.isNotEmpty
                                ? targetUser.displayName[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              fontSize: 32,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ))
                    : null,
              ),
              // Динамический индикатор статуса (скрыт для Избранного)
              if (!isSavedMessages)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Tooltip(
                    message: statusTooltip,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF1E1F22),
                          width: 3.5,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // ИМЯ + БЕЙДЖИ
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  isSavedMessages
                      ? 'Избранное'
                      : (targetUser.displayName.isNotEmpty
                          ? targetUser.displayName
                          : targetUser.username),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (effectiveIsBot && !isSavedMessages) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.deepPurpleAccent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check, size: 10, color: Colors.white),
                      SizedBox(width: 2),
                      Text(
                        'БОТ',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          if (!isSavedMessages)
            Text(
              '@${targetUser.username}${targetUser.tag}',
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
          const SizedBox(height: 12),

          // ПРИВЕТСТВЕННЫЙ ТЕКСТ
          Text(
            isSavedMessages
                ? 'Ваше личное пространство для заметок, файлов и сохраняемых сообщений. Доступно только вам.'
                : (effectiveIsBot
                    ? 'Это начало вашей истории сообщений с ботом ${targetUser.displayName}.'
                    : 'Это начало истории ваших личных сообщений с ${targetUser.displayName}.'),
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 16),

          // КНОПКИ ДЕЙСТВИЙ (СКРЫТЫ ДЛЯ ИЗБРАННОГО)
          if (!isSavedMessages)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2B2D31),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  onPressed: () {},
                  icon: const Icon(Icons.blur_on, size: 16, color: Colors.deepPurpleAccent),
                  label: const Text('1 общий сервер'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2B2D31),
                    foregroundColor: Colors.redAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  onPressed: () {},
                  child: const Text('Заблокировать'),
                ),
              ],
            ),
          const SizedBox(height: 24),

          // РАЗДЕЛИТЕЛЬ ДАТЫ
          Row(
            children: [
              const Expanded(child: Divider(color: Colors.white10)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Text(
                  targetUser.joinedDate.isNotEmpty
                      ? targetUser.joinedDate
                      : '21 июля 2026 г.',
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ),
              const Expanded(child: Divider(color: Colors.white10)),
            ],
          ),
        ],
      ),
    );
  }
}