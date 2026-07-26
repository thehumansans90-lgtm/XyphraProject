import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../utils/badge_manager.dart';
import '../widgets/status_indicator.dart';
import '../widgets/xyphra_logo.dart';
import 'main_workspace_screen.dart';

class PlayerListView extends StatelessWidget {
  final UserProfile currentUser;
  final UserProfile savedMessagesUser;
  final UserProfile xyphraBot;
  final List<UserProfile> chatUsers;
  final UserProfile selectedTargetUser;
  final ActiveWorkspaceTab currentTab;
  final Map<String, int> unreadCountsMap;
  final bool isConnected;
  final Function(UserProfile) onSelectUser;
  final VoidCallback onAddFriendTap;
  final VoidCallback onOpenSettings;

  const PlayerListView({
    super.key,
    required this.currentUser,
    required this.savedMessagesUser,
    required this.xyphraBot,
    required this.chatUsers,
    required this.selectedTargetUser,
    required this.currentTab,
    required this.unreadCountsMap,
    required this.isConnected,
    required this.onSelectUser,
    required this.onAddFriendTap,
    required this.onOpenSettings,
  });

  bool _checkIsUserOnline(UserProfile user) {
    if (user.badges.any((b) => b == 'BOT' || b == 'SAVED')) return true;
    if (user.id == currentUser.id) return isConnected;
    if (!isConnected || !user.isOnline) return false;
    return user.lastSeen == null ||
        DateTime.now().toUtc().difference(user.lastSeen!.toUtc()).inSeconds <=
            120;
  }

  Widget _buildStatusIndicator(UserProfile user, {double size = 12}) {
    final bool isSelf = user.id == currentUser.id;
    final effectiveUser = isSelf ? user.copyWith(isOnline: true) : user;
    final isOnline = isSelf ? true : _checkIsUserOnline(user);

    return StatusIndicator(
      user: effectiveUser,
      isConnected: isOnline,
      size: size,
      enableAnimation: true,
    );
  }

  Widget _buildUserAvatarWidget(UserProfile user, {double radius = 22}) {
    ImageProvider? provider;
    if (user.avatarBytes?.isNotEmpty == true) {
      provider = MemoryImage(user.avatarBytes!);
    } else if (user.avatarUrl.isNotEmpty) {
      provider = NetworkImage(user.avatarUrl);
    }

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: CircleAvatar(
        radius: radius,
        backgroundColor: AppTheme.primary.withValues(alpha: 0.5),
        backgroundImage: provider,
        child: provider == null
            ? Text(
                user.displayName.isNotEmpty
                    ? user.displayName[0].toUpperCase()
                    : 'U',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: radius * 0.8,
                  fontWeight: FontWeight.bold,
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildChatListTile({
    required UserProfile user,
    required String title,
    required String subtitle,
    IconData? iconOverride,
    Color? iconColor,
    bool isBot = false,
  }) {
    final isSelected = currentTab == ActiveWorkspaceTab.chat &&
        selectedTargetUser.id == user.id;
    final unread = unreadCountsMap[user.id] ?? 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onSelectUser(user),
          borderRadius: BorderRadius.circular(16),
          hoverColor: AppTheme.panelBgLight.withValues(alpha: 0.5),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: isSelected
                ? AppTheme.highlightDecoration
                : BoxDecoration(borderRadius: BorderRadius.circular(16)),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    if (iconOverride != null)
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                            color: iconColor?.withValues(alpha: 0.2),
                            shape: BoxShape.circle),
                        child: Icon(iconOverride, color: iconColor, size: 22),
                      )
                    else if (isBot)
                      const SizedBox(
                          width: 44, height: 44, child: XyphraLogo(size: 44))
                    else
                      _buildUserAvatarWidget(user, radius: 22),
                    if (iconOverride == null)
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: _buildStatusIndicator(user, size: 14),
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : AppTheme.textMain,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (user.badges.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            BadgeManager.buildBadgesList(user.badges),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                            color: isSelected
                                ? Colors.white70
                                : AppTheme.textMuted,
                            fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (unread > 0)
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: AppTheme.danger,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: AppTheme.danger, blurRadius: 8)
                      ],
                    ),
                    child: Text(
                      '$unread',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentUserFooter() {
    final cleanTag = currentUser.tag.replaceAll('#', '');
    final formattedUsername =
        (cleanTag.isNotEmpty && !currentUser.username.contains('_'))
            ? '@${currentUser.username}_$cleanTag'
            : '@${currentUser.username}';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.panelBgLight.withValues(alpha: 0.8),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
        border: const Border(top: BorderSide(color: Colors.white12)),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              _buildUserAvatarWidget(currentUser, radius: 20),
              Positioned(
                right: -2,
                bottom: -2,
                child: _buildStatusIndicator(currentUser, size: 12),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(currentUser.displayName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis),
                Text(formattedUsername,
                    style: const TextStyle(
                        color: AppTheme.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.mic_rounded,
                    color: AppTheme.textMuted, size: 20),
                onPressed: () {},
                splashRadius: 20,
              ),
              IconButton(
                icon: const Icon(Icons.headphones_rounded,
                    color: AppTheme.textMuted, size: 20),
                onPressed: () {},
                splashRadius: 20,
              ),
              IconButton(
                icon: const Icon(Icons.settings_rounded,
                    color: AppTheme.textMuted, size: 20),
                onPressed: onOpenSettings,
                splashRadius: 20,
              ),
            ],
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: InkWell(
            onTap: onAddFriendTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: currentTab == ActiveWorkspaceTab.addFriend
                      ? [
                          AppTheme.primary,
                          AppTheme.primary.withValues(alpha: 0.7)
                        ]
                      : [AppTheme.panelBgLight, AppTheme.panelBgLight],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: currentTab == ActiveWorkspaceTab.addFriend
                    ? const [
                        BoxShadow(
                            color: AppTheme.primaryGlow,
                            blurRadius: 12,
                            offset: Offset(0, 4))
                      ]
                    : [],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_add_rounded,
                      color: currentTab == ActiveWorkspaceTab.addFriend
                          ? Colors.white
                          : AppTheme.textMain,
                      size: 22),
                  const SizedBox(width: 10),
                  Text('Добавить друга',
                      style: TextStyle(
                          color: currentTab == ActiveWorkspaceTab.addFriend
                              ? Colors.white
                              : AppTheme.textMain,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ),
        Divider(color: Colors.white.withValues(alpha: 0.05), height: 1),
        Expanded(
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              _buildChatListTile(
                user: savedMessagesUser,
                title: 'Избранное',
                subtitle: 'Файлы и заметки',
                iconOverride: Icons.bookmark_rounded,
                iconColor: AppTheme.warning,
              ),
              _buildChatListTile(
                user: xyphraBot,
                title: xyphraBot.displayName,
                subtitle: 'ИИ-Ассистент Xyphra',
                isBot: true,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                child: Text('ПРИВАТНЫЕ СООБЩЕНИЯ',
                    style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2)),
              ),
              for (final user in chatUsers)
                _buildChatListTile(
                  user: user,
                  title: user.displayName,
                  subtitle: '@${user.username}',
                ),
            ],
          ),
        ),
        _buildCurrentUserFooter(),
      ],
    );
  }
}
