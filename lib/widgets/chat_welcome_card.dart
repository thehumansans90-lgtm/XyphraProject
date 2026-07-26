import 'package:flutter/material.dart';
import '../models/user_model.dart';
import 'status_indicator.dart';
import '../screens/user_avatar.dart';

class ChatWelcomeCard extends StatelessWidget {
  final UserProfile targetUser;
  final bool isBot;
  final bool isSavedMessages;

  const ChatWelcomeCard({
    super.key,
    required this.targetUser,
    this.isBot = false,
    this.isSavedMessages = false,
  });

  @override
  Widget build(BuildContext context) {
    // Определяем тип чата
    final bool effectiveIsSaved = isSavedMessages ||
        targetUser.id == 'saved_messages' ||
        targetUser.username == 'saved_messages' ||
        targetUser.badges.contains('SAVED');

    final bool effectiveIsBot =
        !effectiveIsSaved && (isBot || targetUser.badges.contains('BOT'));

    final String displayName = targetUser.displayName.isNotEmpty
        ? targetUser.displayName
        : targetUser.username;

    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 28, left: 16, right: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF131520).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF7C4DFF).withValues(alpha: 0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C4DFF).withValues(alpha: 0.05),
            blurRadius: 30,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 👤 АВАТАР С НЕОНОВЫМ ОРЕОЛОМ
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: effectiveIsSaved
                          ? Colors.amber.withValues(alpha: 0.25)
                          : const Color(0xFF7C4DFF).withValues(alpha: 0.3),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: UserAvatar(
                  user: targetUser,
                  isBot: effectiveIsBot,
                  radius: 42,
                ),
              ),
              // Индикатор статуса для людей/ботов
              if (!effectiveIsSaved)
                Positioned(
                  right: 2,
                  bottom: 2,
                  child: StatusIndicator(
                    user: targetUser,
                    isConnected: true,
                    size: 18,
                    enableAnimation: true,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),

          // 🏷️ ЗАГОЛОВОК И БЕЙДЖИ
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  effectiveIsSaved ? 'Saved Messages' : displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (effectiveIsBot) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7C4DFF), Color(0xFFB388FF)],
                    ),
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF7C4DFF).withValues(alpha: 0.4),
                        blurRadius: 6,
                      )
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bolt_rounded, size: 11, color: Colors.white),
                      SizedBox(width: 2),
                      Text(
                        'BOT',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),

          if (!effectiveIsSaved) ...[
            const SizedBox(height: 3),
            Text(
              '@${targetUser.username}${targetUser.tag.isNotEmpty ? targetUser.tag : ''}',
              style: TextStyle(
                color: const Color(0xFF7C4DFF).withValues(alpha: 0.8),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 12),

          // 💬 ТЕКСТ-ОПИСАНИЕ
          Text(
            effectiveIsSaved
                ? 'Your personal cloud vault for notes, media, and saved messages. Syncs instantly across all your devices.'
                : (effectiveIsBot
                    ? 'Beginning of secure communication log with AI Assistant $displayName.'
                    : 'This is the start of your encrypted direct message channel with $displayName.'),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13.5,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),

          // 🛠️ СТИЛЬНЫЕ ИНТЕРАКТИВНЫЕ ЧИПЫ (Скрыты для Избранного, адаптированы для Ботов и Людей)
          if (!effectiveIsSaved)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildActionChip(
                  icon: Icons.shield_outlined,
                  label: 'Encrypted',
                  color: Colors.greenAccent,
                  onTap: () {},
                ),
                if (effectiveIsBot)
                  _buildActionChip(
                    icon: Icons.smart_toy_outlined,
                    label: 'Official Bot',
                    color: const Color(0xFF7C4DFF),
                    onTap: () {},
                  )
                else
                  _buildActionChip(
                    icon: Icons.block_rounded,
                    label: 'Block',
                    color: Colors.redAccent,
                    isDestructive: true,
                    onTap: () {},
                  ),
              ],
            ),

          const SizedBox(height: 24),

          // 📅 ДАТА-РАЗДЕЛИТЕЛЬ BUBBLE
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        const Color(0xFF7C4DFF).withValues(alpha: 0.3),
                      ],
                    ),
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1F2130),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white10,
                    width: 0.8,
                  ),
                ),
                child: Text(
                  targetUser.joinedDate.isNotEmpty
                      ? targetUser.joinedDate
                      : 'July 21, 2026',
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF7C4DFF).withValues(alpha: 0.3),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Вспомогательный виджет для неоновых чипов
  Widget _buildActionChip({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isDestructive
                ? Colors.red.withValues(alpha: 0.1)
                : const Color(0xFF1A1D2C),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: color.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isDestructive ? Colors.redAccent : Colors.white54,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
