import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/user_model.dart';
import '../utils/badge_manager.dart';
import 'edit_profile_dialog.dart';
import 'status_indicator.dart';
import '../screens/user_avatar.dart';

class ProfileSidebar extends StatefulWidget {
  final UserProfile user;
  final bool isMe;
  final bool isBot;
  final List<String> sharedServers;
  final VoidCallback? onProfileUpdated;

  const ProfileSidebar({
    super.key,
    required this.user,
    required this.isMe,
    this.isBot = false,
    required this.sharedServers,
    this.onProfileUpdated,
  });

  @override
  State<ProfileSidebar> createState() => _ProfileSidebarState();
}

class _ProfileSidebarState extends State<ProfileSidebar> {
  String _getFormattedUsername() {
    if (widget.user.username.isEmpty) return '';
    if (widget.user.tag.isNotEmpty &&
        !widget.user.username.contains('#') &&
        !widget.user.username.contains('_')) {
      final cleanTag = widget.user.tag.startsWith('#')
          ? widget.user.tag
          : '#${widget.user.tag}';
      return '@${widget.user.username}$cleanTag';
    }
    return '@${widget.user.username}';
  }

  Color _getPrimaryAccentColor() {
    try {
      String cleanHex = widget.user.bannerColor.replaceAll('#', '').trim();
      if (cleanHex.length == 6) {
        cleanHex = 'FF$cleanHex';
      }
      return Color(int.parse(cleanHex, radix: 16));
    } catch (_) {
      return const Color(0xFF7C4DFF); // Яркий пурпурный акцент по умолчанию
    }
  }

  void _openEditProfileDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => EditProfileDialog(
        user: widget.user,
        onProfileUpdated: () {
          widget.onProfileUpdated?.call();
          if (mounted) {
            setState(() {});
          }
        },
      ),
    );
  }

  void _copyUsername() {
    final formattedUser = _getFormattedUsername();
    Clipboard.setData(ClipboardData(text: formattedUser));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Скопировано: $formattedUser'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = _getPrimaryAccentColor();
    final formattedUsername = _getFormattedUsername();

    return Container(
      width: 310,
      decoration: const BoxDecoration(
        color: Color(0xFF0E0F14),
        border: Border(left: BorderSide(color: Color(0xFF1F212D), width: 1)),
      ),
      child: Stack(
        children: [
          // 🌌 Мягкое неоновое свечение на заднем фоне
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentColor.withValues(alpha: 0.25),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
                child: const SizedBox.expand(),
              ),
            ),
          ),

          // 📜 Основное содержимое панели
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              children: [
                const SizedBox(height: 10),

                // 👤 Главная карточка профиля
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161722).withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.1),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Аватарка (используем универсальный UserAvatar)
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 84,
                            height: 84,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  accentColor,
                                  accentColor.withValues(alpha: 0.2),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                          ),
                          UserAvatar(
                            user: widget.user,
                            isBot: widget.isBot,
                            radius: 36,
                          ),
                          Positioned(
                            right: 2,
                            bottom: 2,
                            child: StatusIndicator(
                              user: widget.user,
                              isConnected: true,
                              size: 20,
                              enableAnimation: true,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Отображаемое имя
                      Text(
                        widget.user.displayName.isNotEmpty
                            ? widget.user.displayName
                            : widget.user.username,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      const SizedBox(height: 6),

                      // Бейджи
                      BadgeManager.buildBadgesList(widget.user.badges),

                      const SizedBox(height: 8),

                      // Скопировать @username
                      InkWell(
                        onTap: _copyUsername,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF0E0F14).withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  formattedUsername,
                                  style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.copy_rounded,
                                size: 12,
                                color: Colors.white38,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 📝 Карточка "О себе"
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF14151F),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.person_outline_rounded,
                            size: 14,
                            color: accentColor,
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'О СЕБЕ',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.user.bio.isNotEmpty
                            ? widget.user.bio
                            : 'Пользователь пока ничего не рассказал о себе.',
                        style: TextStyle(
                          color: widget.user.bio.isNotEmpty
                              ? Colors.white.withValues(alpha: 0.85)
                              : Colors.white30,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),

                // 🌐 Карточка "Общие сервера"
                if (widget.sharedServers.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF14151F),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.hub_outlined,
                              size: 14,
                              color: accentColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'ОБЩИЕ СЕРВЕРА (${widget.sharedServers.length})',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: widget.sharedServers.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 6),
                          itemBuilder: (context, index) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A1C29),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.dns_rounded,
                                    size: 16,
                                    color: accentColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      widget.sharedServers[index],
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 20),
              ],
            ),
          ),

          // ✏️ Кнопка "Редактировать профиль" в углу
          if (widget.isMe)
            Positioned(
              top: 14,
              right: 14,
              child: IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF1E202E),
                  hoverColor: accentColor.withValues(alpha: 0.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(
                  Icons.edit_rounded,
                  size: 16,
                  color: Colors.white70,
                ),
                onPressed: _openEditProfileDialog,
                tooltip: 'Редактировать профиль',
              ),
            ),
        ],
      ),
    );
  }
}
