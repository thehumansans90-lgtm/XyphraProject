import 'package:flutter/material.dart';
import '../models/user_model.dart';
import 'status_indicator.dart';
import '../screens/user_avatar.dart';

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

  bool get _isSavedMessages =>
      targetUser.id == 'saved_messages' ||
      targetUser.username == 'saved_messages' ||
      targetUser.badges.contains('SAVED');

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
        color: const Color(0xFF7C4DFF),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check, size: 9, color: Colors.white),
          SizedBox(width: 2),
          Text(
            'BOT',
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
    final onlineState =
        StatusIndicator.getStatus(targetUser, isConnected: true);

    // 🎯 Текст и цвета статуса (Учитывая Saved Messages)
    final String titleText = _isSavedMessages
        ? 'Saved Messages'
        : (targetUser.displayName.isNotEmpty
            ? targetUser.displayName
            : targetUser.username);

    final String statusText = _isSavedMessages
        ? 'Personal Storage'
        : StatusIndicator.getStatusText(onlineState);

    final Color statusColor = _isSavedMessages
        ? Colors.white38
        : StatusIndicator.getStatusColor(onlineState);

    final bool isGlowing = !_isSavedMessages &&
        (onlineState == UserOnlineState.online ||
            onlineState == UserOnlineState.bot);

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF10121B),
        border: Border(bottom: BorderSide(color: Color(0xFF1F212D), width: 1)),
      ),
      child: Row(
        children: [
          // 👤 AVATAR WITH STATUS INDICATOR
          Stack(
            alignment: Alignment.center,
            children: [
              UserAvatar(
                user: targetUser,
                isBot: _isBot,
                radius: 18,
              ),
              if (!_isSavedMessages)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: StatusIndicator(
                    user: targetUser,
                    isConnected: true,
                    size: 10,
                    enableAnimation: false,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),

          // 🏷️ USERNAME & STATUS
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
                        titleText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (_isOwner && !_isSavedMessages) ...[
                      const SizedBox(width: 6),
                      _buildOwnerBadge(),
                    ] else if (_isBot && !_isSavedMessages) ...[
                      const SizedBox(width: 6),
                      _buildBotBadge(),
                    ],
                  ],
                ),
                const SizedBox(height: 2),

                // 🟢 СТАТУС ТЕКСТ
                Row(
                  children: [
                    if (!_isSavedMessages) ...[
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: statusColor,
                          boxShadow: isGlowing
                              ? [
                                  BoxShadow(
                                    color: statusColor.withValues(alpha: 0.4),
                                    blurRadius: 4,
                                  )
                                ]
                              : null,
                        ),
                      ),
                      const SizedBox(width: 5),
                    ],
                    Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 🛠️ ACTION BUTTONS
          IconButton(
            icon:
                const Icon(Icons.call_rounded, color: Colors.white54, size: 19),
            tooltip: 'Start Voice Call',
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.videocam_rounded,
                color: Colors.white54, size: 19),
            tooltip: 'Start Video Call',
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.push_pin_rounded,
                color: Colors.white54, size: 19),
            tooltip: 'Pinned Messages',
            onPressed: () {},
          ),

          // 👤 PROFILE PANEL TOGGLE BUTTON WITH GLOW
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isProfileOpen
                  ? const Color(0xFF7C4DFF).withValues(alpha: 0.2)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isProfileOpen
                    ? const Color(0xFF7C4DFF)
                    : Colors.transparent,
                width: 1,
              ),
              boxShadow: isProfileOpen
                  ? [
                      BoxShadow(
                        color: const Color(0xFF7C4DFF).withValues(alpha: 0.3),
                        blurRadius: 10,
                        spreadRadius: 1,
                      )
                    ]
                  : [],
            ),
            child: IconButton(
              icon: Icon(
                Icons.account_box_rounded,
                color: isProfileOpen ? const Color(0xFF7C4DFF) : Colors.white54,
                size: 20,
              ),
              tooltip: 'User Profile',
              onPressed: onToggleProfile,
            ),
          ),
          const SizedBox(width: 12),

          // 🔍 SEARCH FIELD
          SizedBox(
            width: 180,
            height: 32,
            child: TextField(
              style: const TextStyle(fontSize: 12, color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search chat...',
                hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                filled: true,
                fillColor: const Color(0xFF181A26),
                suffixIcon: const Icon(
                  Icons.search_rounded,
                  color: Colors.white38,
                  size: 16,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
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
