import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart' as file_picker_lib;
import 'package:flutter/services.dart';
import 'package:my_app/screens/auth_screen.dart' hide XyphraLogo;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/chat_sync_service.dart';
import '../utils/badge_manager.dart';
import '../widgets/profile_sidebar.dart';
import '../widgets/status_indicator.dart';
import '../widgets/xyphra_logo.dart';

import 'chat_view.dart';
import 'player_list_view.dart';

class AppTheme {
  static const Color bgDark = Color(0xFF07090E);
  static const Color panelBg = Color(0xFF10121B);
  static const Color panelBgLight = Color(0xFF1A1D2A);
  static const Color primary = Color(0xFF7C4DFF);
  static const Color primaryGlow = Color(0x667C4DFF);
  static const Color secondary = Color(0xFF00E5FF);
  static const Color danger = Color(0xFFFF1744);
  static const Color success = Color(0xFF00E676);
  static const Color warning = Color(0xFFFFC107);
  static const Color textMain = Color(0xFFF8F9FA);
  static const Color textMuted = Color(0xFF8B92A5);

  static BoxDecoration glassDecoration = BoxDecoration(
    color: panelBg.withValues(alpha: 0.7),
    borderRadius: BorderRadius.circular(24),
    border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1.5),
    boxShadow: [
      BoxShadow(
          color: Colors.black.withValues(alpha: 0.4),
          blurRadius: 20,
          offset: const Offset(0, 10)),
    ],
  );

  static BoxDecoration highlightDecoration = BoxDecoration(
    gradient: const LinearGradient(
      colors: [Color(0xFF232533), Color(0xFF1A1D2A)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: primary.withValues(alpha: 0.3)),
    boxShadow: const [
      BoxShadow(color: primaryGlow, blurRadius: 15, spreadRadius: -5)
    ],
  );
}

enum ActiveWorkspaceTab { chat, addFriend, servers }

class MainWorkspaceScreen extends StatefulWidget {
  final UserProfile currentUser;
  final bool isConnected;
  final VoidCallback? onLogout;

  const MainWorkspaceScreen({
    super.key,
    required this.currentUser,
    this.isConnected = true,
    this.onLogout,
  });

  @override
  State<MainWorkspaceScreen> createState() => _MainWorkspaceScreenState();
}

class _MainWorkspaceScreenState extends State<MainWorkspaceScreen>
    with TickerProviderStateMixin {
  final ChatSyncService _chatSyncService = ChatSyncService();
  ActiveWorkspaceTab _currentTab = ActiveWorkspaceTab.chat;
  bool _isProfileOpen = true;
  bool _isMobileChatOpen = false;

  final TextEditingController _searchFriendController = TextEditingController();

  late final UserProfile _savedMessagesUser;
  late final UserProfile _xyphraBot;
  late UserProfile _selectedTargetUser;

  final Map<String, List<ChatMessage>> _chatHistory = {};
  StreamSubscription<List<ChatMessage>>? _chatSubscription;
  StreamSubscription<List<ChatMessage>>? _globalIncomingMessagesSubscription;
  RealtimeChannel? _profilesRealtimeChannel;

  final Map<String, int> _unreadCountsMap = {};
  final Set<String> _activeChatUserIds = {};

  String _searchQuery = '';
  bool _isSearchingUsers = false;
  Timer? _searchDebounce;
  final List<UserProfile> _allGlobalUsers = [];
  final List<UserProfile> _searchResultsUsers = [];

  late AnimationController _bgAnimationController;

  @override
  void initState() {
    super.initState();
    _bgAnimationController =
        AnimationController(vsync: this, duration: const Duration(seconds: 10))
          ..repeat(reverse: true);

    _syncUserBadges(widget.currentUser);

    _savedMessagesUser = UserProfile(
      id: 'saved_messages_${widget.currentUser.id}',
      username: 'saved_messages',
      tag: '0000',
      displayName: 'Избранное (Saved)',
      bio:
          'Ваше личное защищенное пространство для заметок, файлов и сохраняемых сообщений.',
      avatarUrl: '',
      bannerColor: '0xFFFFC107',
      joinedDate: '21 июля 2026 г.',
      badges: ['SAVED'],
    );

    _xyphraBot = UserProfile(
      id: 'xyphra_bot',
      username: 'xyphra_official',
      tag: '0001',
      displayName: 'Xyphra Assistant',
      bio: 'Официальный умный ИИ-ассистент и гид по нейросети Xyphra.',
      avatarUrl: '',
      bannerColor: '0xFF7C4DFF',
      joinedDate: '21 июля 2026 г.',
      badges: ['BOT', 'SYSTEM', 'VERIFIED'],
    );

    _syncUserBadges(_xyphraBot);
    _allGlobalUsers
        .addAll([widget.currentUser, _savedMessagesUser, _xyphraBot]);
    _selectedTargetUser = _xyphraBot;

    _loadCachedMessages();
    _loadGlobalUsersFromServer();
    _subscribeToProfilesRealtime();
    _subscribeToGlobalIncomingMessages();
  }

  @override
  void dispose() {
    _bgAnimationController.dispose();
    _searchDebounce?.cancel();
    if (_profilesRealtimeChannel != null) {
      Supabase.instance.client.removeChannel(_profilesRealtimeChannel!);
    }
    _chatSubscription?.cancel();
    _globalIncomingMessagesSubscription?.cancel();
    _searchFriendController.dispose();
    super.dispose();
  }

  void _syncUserBadges(UserProfile user) {
    final updated = BadgeManager.getBadgesForUser(
      userId: user.id.toString(),
      username: user.username,
      currentBadges: user.badges,
    );
    user.badges
      ..clear()
      ..addAll(updated);
  }

  void _subscribeToGlobalIncomingMessages() {
    _globalIncomingMessagesSubscription?.cancel();
    _globalIncomingMessagesSubscription = _chatSyncService
        .subscribeToAllIncomingMessages(widget.currentUser.id, (messages) {
      if (!mounted || messages.isEmpty) return;
      final newMessage = messages.last;
      final senderId = newMessage.senderId;

      setState(() {
        _activeChatUserIds.add(senderId);
        final chat = _chatHistory.putIfAbsent(senderId, () => []);
        if (!chat.any((m) => m.id == newMessage.id)) {
          chat
            ..add(newMessage)
            ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
        }
      });

      _chatSyncService.saveChatHistory(widget.currentUser.id, _chatHistory);
      if (_selectedTargetUser.id != senderId) {
        setState(() {
          _unreadCountsMap[senderId] = (_unreadCountsMap[senderId] ?? 0) + 1;
        });
      }
    });
  }

  Future<void> _saveLastActiveUserId(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'last_active_user_id_${widget.currentUser.id}', userId);
    } catch (e) {
      debugPrint('Ошибка сохранения активного чата: $e');
    }
  }

  DateTime _getLastMessageTime(String userId) {
    final messages = _chatHistory[userId];
    return messages?.isNotEmpty == true
        ? messages!.last.timestamp.toUtc()
        : DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }

  void _subscribeToProfilesRealtime() {
    try {
      _profilesRealtimeChannel =
          Supabase.instance.client.channel('public:profiles').onPostgresChanges(
                event: PostgresChangeEvent.all,
                schema: 'public',
                table: 'profiles',
                callback: (_) => _loadGlobalUsersFromServer(),
              )..subscribe();
    } catch (e) {
      debugPrint('Ошибка подписки Realtime Profiles: $e');
    }
  }

  Future<void> _loadGlobalUsersFromServer() async {
    final users = await AuthService.searchUsers('');
    if (mounted && users.isNotEmpty) {
      setState(() {
        for (final user in users) {
          _syncUserBadges(user);
          final i = _allGlobalUsers.indexWhere((u) => u.id == user.id);
          i != -1 ? _allGlobalUsers[i] = user : _allGlobalUsers.add(user);
        }
      });
      _performUserSearch(_searchQuery);
    }
  }

  void _onSearchChanged(String query) {
    setState(() => _searchQuery = query);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
        const Duration(milliseconds: 350), () => _performUserSearch(query));
  }

  Future<void> _performUserSearch(String query) async {
    if (!mounted) return;
    setState(() => _isSearchingUsers = true);
    try {
      final serverResults = await AuthService.searchUsers(
          query.trim().replaceAll('@', '').toLowerCase());
      if (mounted) {
        final filteredResults =
            serverResults.where((u) => u.id != _savedMessagesUser.id).toList();
        for (final u in filteredResults) {
          _syncUserBadges(u);
        }

        setState(() {
          _searchResultsUsers
            ..clear()
            ..addAll(filteredResults);
          _isSearchingUsers = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isSearchingUsers = false);
    }
  }

  Future<void> _loadCachedMessages() async {
    final cached =
        await _chatSyncService.loadChatHistory(widget.currentUser.id);
    final prefs = await SharedPreferences.getInstance();
    final savedUserId =
        prefs.getString('last_active_user_id_${widget.currentUser.id}');

    if (!mounted) return;
    setState(() {
      if (cached.isNotEmpty) {
        cached.forEach((k, list) {
          list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
          _activeChatUserIds.add(k);
        });
        _chatHistory.addAll(cached);
      } else {
        _chatHistory[_xyphraBot.id] = [
          ChatMessage(
            id: 'welcome_msg',
            senderId: _xyphraBot.id,
            text:
                'Добро пожаловать в Xyphra! 🚀\nИсследуй возможности экосистемы, общайся и находи друзей. Я здесь, чтобы помочь тебе разобраться.',
            timestamp: DateTime.now().toUtc(),
          )
        ];
        _activeChatUserIds.add(_xyphraBot.id);
      }

      if (savedUserId != null) {
        _selectedTargetUser = _allGlobalUsers.firstWhere(
            (u) => u.id == savedUserId,
            orElse: () => _selectedTargetUser);
      }
    });

    _subscribeToSelectedChat();
  }

  void _subscribeToSelectedChat() {
    _chatSubscription?.cancel();
    _chatSubscription = null;
    final activeId = _selectedTargetUser.id;

    setState(() {
      _unreadCountsMap[activeId] = 0;
    });

    if (activeId == _xyphraBot.id || activeId == _savedMessagesUser.id) return;

    _chatSubscription = _chatSyncService.subscribeToChat(
      currentUserId: widget.currentUser.id,
      targetUserId: activeId,
      onData: (serverMessages) {
        if (mounted && _selectedTargetUser.id == activeId) {
          setState(() => _chatHistory[activeId] = serverMessages);
          _chatSyncService.saveChatHistory(widget.currentUser.id, _chatHistory);
        }
      },
    );
  }

  void _selectUserAndSwitchChat(UserProfile user) {
    _chatSubscription?.cancel();
    _chatSubscription = null;
    setState(() {
      _selectedTargetUser = user;
      _currentTab = ActiveWorkspaceTab.chat;
    });
    _saveLastActiveUserId(user.id);
    _subscribeToSelectedChat();
  }

  void _navigateToAuth() {
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => AuthScreen(onLoginSuccess: () {})),
        (_) => false,
      );
    }
  }

  Future<void> _handleLogout() async {
    await AuthService.logout();
    _navigateToAuth();
  }

  Future<void> _handleDeleteAccount() async {
    try {
      await Supabase.instance.client
          .from('profiles')
          .delete()
          .eq('id', widget.currentUser.id);
      await AuthService.logout();
      _navigateToAuth();
    } catch (e) {
      debugPrint('Error deleting account: $e');
    }
  }

  void _openSettingsModal() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Settings',
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, anim1, anim2) => AdvancedSettingsDialog(
        user: widget.currentUser,
        onProfileUpdated: () => mounted
            ? setState(() => _syncUserBadges(widget.currentUser))
            : null,
        onLogout: _handleLogout,
        onDeleteAccount: _handleDeleteAccount,
      ),
      transitionBuilder: (context, anim1, anim2, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
              .animate(
                  CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic)),
          child: Opacity(opacity: anim1.value, child: child),
        );
      },
    );
  }

  void _showMobileProfileBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.88,
        decoration: BoxDecoration(
          color: AppTheme.panelBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: const [
            BoxShadow(
                color: AppTheme.primaryGlow, blurRadius: 30, spreadRadius: -10)
          ],
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(3)),
            ),
            Expanded(
              child: ProfileSidebar(
                user: _selectedTargetUser,
                isMe: _selectedTargetUser.id == widget.currentUser.id,
                isBot: _selectedTargetUser.badges.contains('BOT'),
                sharedServers: const [],
                onProfileUpdated: () => mounted ? setState(() {}) : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    final allChatUserIds = {
      ..._chatHistory.entries
          .where((e) => e.value.isNotEmpty)
          .map((e) => e.key),
      ..._activeChatUserIds,
    };

    final chatUsers = _allGlobalUsers
        .where((u) =>
            allChatUserIds.contains(u.id) && u.id != widget.currentUser.id)
        .toList()
      ..sort((a, b) =>
          _getLastMessageTime(b.id).compareTo(_getLastMessageTime(a.id)));

    return PopScope(
      canPop: !isMobile || !_isMobileChatOpen,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (isMobile && _isMobileChatOpen) {
          setState(() => _isMobileChatOpen = false);
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.bgDark,
        body: Stack(
          children: [
            AnimatedBuilder(
              animation: _bgAnimationController,
              builder: (context, child) {
                return Positioned(
                  top: -200 +
                      (math.sin(_bgAnimationController.value * math.pi) * 50),
                  left: -200 +
                      (math.cos(_bgAnimationController.value * math.pi) * 50),
                  child: Container(
                    width: 600,
                    height: 600,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppTheme.primary.withValues(alpha: 0.05),
                          Colors.transparent
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    if (!isMobile || !_isMobileChatOpen)
                      Container(
                        width: 72,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: AppTheme.glassDecoration,
                        child: Column(
                          children: [
                            const SizedBox(height: 20),
                            const XyphraLogo(size: 48),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 16),
                              child: Divider(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  height: 1),
                            ),
                            _buildNavButton(
                                icon: Icons.chat_bubble_rounded,
                                tab: ActiveWorkspaceTab.chat,
                                tooltip: 'Чаты'),
                            const SizedBox(height: 12),
                            _buildNavButton(
                                icon: Icons.explore_rounded,
                                tab: ActiveWorkspaceTab.servers,
                                tooltip: 'Серверы (Скоро)'),
                            const Spacer(),
                            _buildNavButton(
                                icon: Icons.settings_rounded,
                                onTap: _openSettingsModal,
                                tooltip: 'Настройки',
                                isAction: true),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    if (!isMobile || !_isMobileChatOpen)
                      Expanded(
                        flex: isMobile ? 1 : 0,
                        child: Container(
                          width: isMobile ? null : 320,
                          margin: EdgeInsets.only(right: isMobile ? 0 : 12),
                          decoration: AppTheme.glassDecoration,
                          child: PlayerListView(
                            currentUser: widget.currentUser,
                            savedMessagesUser: _savedMessagesUser,
                            xyphraBot: _xyphraBot,
                            chatUsers: chatUsers
                                .where((u) =>
                                    u.id != _xyphraBot.id &&
                                    u.id != _savedMessagesUser.id)
                                .toList(),
                            selectedTargetUser: _selectedTargetUser,
                            currentTab: _currentTab,
                            unreadCountsMap: _unreadCountsMap,
                            isConnected: widget.isConnected,
                            onSelectUser: (user) {
                              if (isMobile) {
                                _isMobileChatOpen = true;
                              }
                              _selectUserAndSwitchChat(user);
                            },
                            onAddFriendTap: () {
                              setState(() {
                                _currentTab = ActiveWorkspaceTab.addFriend;
                                if (isMobile) _isMobileChatOpen = true;
                              });
                              _performUserSearch(_searchFriendController.text);
                            },
                            onOpenSettings: _openSettingsModal,
                          ),
                        ),
                      ),
                    if (!isMobile || _isMobileChatOpen)
                      Expanded(
                        child: Container(
                          decoration: AppTheme.glassDecoration.copyWith(
                            image: const DecorationImage(
                              image: NetworkImage(
                                  'https://www.transparenttextures.com/patterns/cubes.png'),
                              opacity: 0.02,
                              repeat: ImageRepeat.repeat,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Column(
                              children: [
                                if (isMobile)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                    decoration: const BoxDecoration(
                                      color: AppTheme.panelBg,
                                      border: Border(
                                          bottom: BorderSide(
                                              color: Colors.white10)),
                                    ),
                                    child: Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(
                                              Icons.arrow_back_ios_new_rounded,
                                              color: Colors.white,
                                              size: 20),
                                          onPressed: () => setState(
                                              () => _isMobileChatOpen = false),
                                        ),
                                        Expanded(
                                          child: Text(
                                            _currentTab ==
                                                    ActiveWorkspaceTab.addFriend
                                                ? 'Поиск друзей'
                                                : _selectedTargetUser
                                                    .displayName,
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (_currentTab ==
                                            ActiveWorkspaceTab.chat)
                                          IconButton(
                                            icon: const Icon(
                                                Icons.info_outline_rounded,
                                                color: Colors.white,
                                                size: 22),
                                            onPressed:
                                                _showMobileProfileBottomSheet,
                                          ),
                                      ],
                                    ),
                                  ),
                                AnimatedSize(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeOutBack,
                                  child: !widget.isConnected
                                      ? Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 6, horizontal: 16),
                                          decoration: BoxDecoration(
                                            color: AppTheme.warning,
                                            boxShadow: [
                                              BoxShadow(
                                                  color: AppTheme.warning
                                                      .withValues(alpha: 0.5),
                                                  blurRadius: 10)
                                            ],
                                          ),
                                          child: const Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.wifi_off_rounded,
                                                  color: Colors.black87,
                                                  size: 16),
                                              SizedBox(width: 10),
                                              Text(
                                                  'Автономный режим. Синхронизация приостановлена.',
                                                  style: TextStyle(
                                                      color: Colors.black87,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.bold)),
                                            ],
                                          ),
                                        )
                                      : const SizedBox.shrink(),
                                ),
                                Expanded(
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 400),
                                    switchInCurve: Curves.easeOutQuart,
                                    switchOutCurve: Curves.easeInQuart,
                                    transitionBuilder: (child, animation) =>
                                        FadeTransition(
                                      opacity: animation,
                                      child: SlideTransition(
                                        position: Tween<Offset>(
                                                begin: const Offset(0.05, 0),
                                                end: Offset.zero)
                                            .animate(animation),
                                        child: child,
                                      ),
                                    ),
                                    child: _currentTab ==
                                            ActiveWorkspaceTab.addFriend
                                        ? _buildAddFriendTab()
                                        : _currentTab ==
                                                ActiveWorkspaceTab.servers
                                            ? _buildServersTabDummy()
                                            : ChatView(
                                                currentUser: widget.currentUser,
                                                selectedTargetUser:
                                                    _selectedTargetUser,
                                                savedMessagesUser:
                                                    _savedMessagesUser,
                                                xyphraBot: _xyphraBot,
                                                currentMessages: _chatHistory[
                                                        _selectedTargetUser
                                                            .id] ??
                                                    [],
                                                chatSyncService:
                                                    _chatSyncService,
                                                chatHistory: _chatHistory,
                                                isMobile: isMobile,
                                                onToggleProfile: () {
                                                  if (isMobile) {
                                                    _showMobileProfileBottomSheet();
                                                  } else {
                                                    setState(() =>
                                                        _isProfileOpen =
                                                            !_isProfileOpen);
                                                  }
                                                },
                                                onMessageStateChanged: () =>
                                                    setState(() {}),
                                              ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (!isMobile)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeOutCubic,
                        width: (_isProfileOpen &&
                                _currentTab == ActiveWorkspaceTab.chat)
                            ? 320
                            : 0,
                        margin: EdgeInsets.only(
                            left: (_isProfileOpen &&
                                    _currentTab == ActiveWorkspaceTab.chat)
                                ? 12
                                : 0),
                        decoration: AppTheme.glassDecoration,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: OverflowBox(
                            minWidth: 0,
                            maxWidth: 320,
                            alignment: Alignment.centerLeft,
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 250),
                              opacity: (_isProfileOpen &&
                                      _currentTab == ActiveWorkspaceTab.chat)
                                  ? 1.0
                                  : 0.0,
                              child: ProfileSidebar(
                                user: _selectedTargetUser,
                                isMe: _selectedTargetUser.id ==
                                    widget.currentUser.id,
                                isBot:
                                    _selectedTargetUser.badges.contains('BOT'),
                                sharedServers: const [],
                                onProfileUpdated: () =>
                                    mounted ? setState(() {}) : null,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavButton(
      {required IconData icon,
      ActiveWorkspaceTab? tab,
      VoidCallback? onTap,
      required String tooltip,
      bool isAction = false}) {
    final isActive = tab != null && _currentTab == tab;
    return Tooltip(
      message: tooltip,
      decoration: BoxDecoration(
          color: AppTheme.panelBgLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white12)),
      textStyle: const TextStyle(color: Colors.white, fontSize: 12),
      child: InkWell(
        onTap: onTap ?? () => setState(() => _currentTab = tab!),
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutExpo,
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: isActive
                ? AppTheme.primary
                : (isAction
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.transparent),
            borderRadius: BorderRadius.circular(isActive ? 16 : 25),
            boxShadow: isActive
                ? const [
                    BoxShadow(
                        color: AppTheme.primaryGlow,
                        blurRadius: 15,
                        offset: Offset(0, 4))
                  ]
                : [],
          ),
          child: Icon(icon,
              color: isActive ? Colors.white : AppTheme.textMuted, size: 24),
        ),
      ),
    );
  }

  Widget _buildServersTabDummy() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.rocket_launch_rounded, size: 80, color: AppTheme.primary),
          SizedBox(height: 20),
          Text('Серверы и Сообщества',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold)),
          SizedBox(height: 10),
          Text(
              'Эта функция появится в следующем глобальном обновлении.\nСледите за новостями Xyphra!',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textMuted, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildAddFriendTab() {
    final isMobile = MediaQuery.of(context).size.width < 768;
    final displayList = _searchResultsUsers.isEmpty && _searchQuery.isEmpty
        ? _allGlobalUsers
            .where(
                (u) => u.id != _savedMessagesUser.id && u.id != _xyphraBot.id)
            .toList()
        : _searchResultsUsers;

    return Padding(
      padding: EdgeInsets.all(isMobile ? 16.0 : 32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Поиск и Добавление',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5)),
          const SizedBox(height: 8),
          const Text(
              'Найди друзей по их уникальному @username или никнейму в базе Supabase.',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 14)),
          const SizedBox(height: 32),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.panelBgLight.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
              boxShadow: [
                BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    blurRadius: 20)
              ],
            ),
            child: TextField(
              controller: _searchFriendController,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Поиск по @username в реальном времени...',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon:
                    const Icon(Icons.search_rounded, color: AppTheme.primary),
                suffixIcon: _isSearchingUsers
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppTheme.primary)))
                    : null,
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              ),
            ),
          ),
          const SizedBox(height: 32),
          const Text('РЕЗУЛЬТАТЫ ПОИСКА',
              style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2)),
          const SizedBox(height: 16),
          Expanded(
            child: displayList.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_search_rounded,
                            size: 64,
                            color: AppTheme.textMuted.withValues(alpha: 0.3)),
                        const SizedBox(height: 16),
                        const Text('Никого не найдено',
                            style: TextStyle(
                                color: AppTheme.textMuted, fontSize: 16)),
                      ],
                    ),
                  )
                : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: displayList.length,
                    itemBuilder: (context, index) {
                      final user = displayList[index];
                      final isMe = user.id == widget.currentUser.id;
                      final cleanTag = user.tag.replaceAll('#', '');
                      final userTagText =
                          (cleanTag.isNotEmpty && !user.username.contains('_'))
                              ? '@${user.username}_$cleanTag'
                              : '@${user.username}';

                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.panelBgLight.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.05)),
                        ),
                        child: Row(
                          children: [
                            Stack(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: AppTheme.primary,
                                  child: Text(user.displayName[0].toUpperCase(),
                                      style:
                                          const TextStyle(color: Colors.white)),
                                ),
                                Positioned(
                                  right: -2,
                                  bottom: -2,
                                  child: StatusIndicator(
                                    user: user,
                                    isConnected: user.isOnline,
                                    size: 14,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                          child: Text(user.displayName,
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold),
                                              overflow: TextOverflow.ellipsis)),
                                      if (user.badges.isNotEmpty) ...[
                                        const SizedBox(width: 8),
                                        BadgeManager.buildBadgesList(
                                            user.badges),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(userTagText,
                                      style: const TextStyle(
                                          color: AppTheme.secondary,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                            if (isMe)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                    color: Colors.white10,
                                    borderRadius: BorderRadius.circular(20)),
                                child: const Text('Это вы',
                                    style: TextStyle(
                                        color: Colors.white54,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold)),
                              )
                            else ...[
                              IconButton(
                                icon: const Icon(Icons.chat_bubble_rounded,
                                    color: Colors.white70, size: 24),
                                tooltip: 'Написать',
                                style: IconButton.styleFrom(
                                    backgroundColor: AppTheme.panelBg,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12))),
                                onPressed: () {
                                  if (isMobile) {
                                    _isMobileChatOpen = true;
                                  }
                                  _selectUserAndSwitchChat(user);
                                },
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.person_add_alt_1_rounded,
                                    color: Colors.white, size: 24),
                                tooltip: 'Добавить в друзья',
                                style: IconButton.styleFrom(
                                    backgroundColor: AppTheme.primary,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12))),
                                onPressed: () {
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(SnackBar(
                                    content: Text(
                                        'Запрос отправлен ${user.displayName}! 🚀'),
                                    backgroundColor: AppTheme.success,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                  ));
                                },
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class AdvancedSettingsDialog extends StatefulWidget {
  final UserProfile user;
  final VoidCallback onProfileUpdated;
  final VoidCallback onLogout;
  final VoidCallback onDeleteAccount;

  const AdvancedSettingsDialog({
    super.key,
    required this.user,
    required this.onProfileUpdated,
    required this.onLogout,
    required this.onDeleteAccount,
  });

  @override
  State<AdvancedSettingsDialog> createState() => _AdvancedSettingsDialogState();
}

class _AdvancedSettingsDialogState extends State<AdvancedSettingsDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isEditing = false;
  late final TextEditingController _displayNameController;
  late final TextEditingController _bioController;
  Uint8List? _newAvatarBytes;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _displayNameController =
        TextEditingController(text: widget.user.displayName);
    _bioController = TextEditingController(text: widget.user.bio);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _displayNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickNewAvatar() async {
    try {
      final result = await file_picker_lib.FilePicker.pickFiles(
        type: file_picker_lib.FileType.image,
        allowMultiple: false,
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        if (result.files.first.bytes != null && mounted) {
          setState(() => _newAvatarBytes = result.files.first.bytes);
        }
      }
    } catch (e) {
      debugPrint('Ошибка выбора аватара: $e');
    }
  }

  Future<void> _saveChanges() async {
    widget.user.displayName = _displayNameController.text.trim();
    widget.user.bio = _bioController.text.trim();
    if (_newAvatarBytes != null) widget.user.avatarBytes = _newAvatarBytes;

    await AuthService.saveSession(widget.user);
    widget.onProfileUpdated();
    if (mounted) setState(() => _isEditing = false);
  }

  void _confirmAction(
      String title, String text, Color btnColor, VoidCallback action) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.panelBgLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title,
            style: TextStyle(color: btnColor, fontWeight: FontWeight.bold)),
        content: Text(text, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text('Отмена', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: btnColor),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
              action();
            },
            child: const Text('Подтвердить',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 600,
        height: 600,
        decoration: AppTheme.glassDecoration,
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              color: Colors.black12,
              child: Row(
                children: [
                  const Icon(Icons.settings_suggest_rounded,
                      color: AppTheme.primary, size: 28),
                  const SizedBox(width: 12),
                  const Text('Настройки Xyphra',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                    icon:
                        const Icon(Icons.close_rounded, color: Colors.white54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            TabBar(
              controller: _tabController,
              indicatorColor: AppTheme.primary,
              labelColor: AppTheme.primary,
              unselectedLabelColor: Colors.white54,
              tabs: const [
                Tab(icon: Icon(Icons.person_rounded), text: 'Профиль'),
                Tab(icon: Icon(Icons.security_rounded), text: 'Аккаунт'),
                Tab(icon: Icon(Icons.palette_rounded), text: 'Внешний вид'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildProfileTab(),
                  _buildAccountTab(),
                  _buildAppearanceTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileTab() {
    ImageProvider? avatarProvider;
    if (_newAvatarBytes != null) {
      avatarProvider = MemoryImage(_newAvatarBytes!);
    } else if (widget.user.avatarBytes?.isNotEmpty == true) {
      avatarProvider = MemoryImage(widget.user.avatarBytes!);
    } else if (widget.user.avatarUrl.isNotEmpty) {
      avatarProvider = NetworkImage(widget.user.avatarUrl);
    }

    final cleanTag = widget.user.tag.replaceAll('#', '');
    final formattedUsername =
        (cleanTag.isNotEmpty && !widget.user.username.contains('_'))
            ? '@${widget.user.username}_$cleanTag'
            : '@${widget.user.username}';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          GestureDetector(
            onTap: _isEditing ? _pickNewAvatar : null,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: AppTheme.primary.withValues(alpha: 0.4),
                          blurRadius: 20)
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: AppTheme.primary,
                    backgroundImage: avatarProvider,
                    child: avatarProvider == null
                        ? Text(
                            widget.user.displayName.isNotEmpty
                                ? widget.user.displayName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 36,
                                fontWeight: FontWeight.bold),
                          )
                        : null,
                  ),
                ),
                if (_isEditing)
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: BoxShape.circle),
                    child: const Icon(Icons.camera_alt_rounded,
                        color: Colors.white, size: 32),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (!_isEditing) ...[
            Text(widget.user.displayName,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold)),
            Text(formattedUsername,
                style: const TextStyle(
                    color: AppTheme.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.w500)),
            if (widget.user.bio.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(widget.user.bio,
                    textAlign: TextAlign.center,
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 14)),
              ),
            ],
            const SizedBox(height: 32),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                minimumSize: const Size(200, 48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () => setState(() => _isEditing = true),
              icon: const Icon(Icons.edit_rounded),
              label: const Text('Редактировать профиль',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ] else ...[
            TextField(
              controller: _displayNameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Отображаемое имя',
                labelStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _bioController,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'О себе',
                labelStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () => setState(() {
                    _isEditing = false;
                    _newAvatarBytes = null;
                  }),
                  child: const Text('Отмена',
                      style: TextStyle(color: Colors.white54)),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _saveChanges,
                  child: const Text('Сохранить',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAccountTab() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Управление аккаунтом',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Material(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: const Icon(Icons.email_rounded, color: Colors.white70),
              title:
                  const Text('Email', style: TextStyle(color: Colors.white70)),
              subtitle: const Text('Скрыто из соображений безопасности',
                  style: TextStyle(color: Colors.white38)),
              trailing: ElevatedButton(
                onPressed: () {},
                style:
                    ElevatedButton.styleFrom(backgroundColor: Colors.white10),
                child: const Text('Изменить'),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Material(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading:
                  const Icon(Icons.password_rounded, color: Colors.white70),
              title:
                  const Text('Пароль', style: TextStyle(color: Colors.white70)),
              trailing: ElevatedButton(
                onPressed: () {},
                style:
                    ElevatedButton.styleFrom(backgroundColor: Colors.white10),
                child: const Text('Обновить'),
              ),
            ),
          ),
          const Spacer(),
          const Divider(color: Colors.white10),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.warning.withValues(alpha: 0.2),
                    foregroundColor: AppTheme.warning,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () => _confirmAction(
                      'Выйти из аккаунта',
                      'Вы уверены, что хотите выйти?',
                      AppTheme.warning,
                      widget.onLogout),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Выйти'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.danger.withValues(alpha: 0.2),
                    foregroundColor: AppTheme.danger,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () => _confirmAction(
                      'Удалить аккаунт',
                      'Это навсегда удалит ваши данные!',
                      AppTheme.danger,
                      widget.onDeleteAccount),
                  icon: const Icon(Icons.delete_forever_rounded),
                  label: const Text('Удалить аккаунт'),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildAppearanceTab() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Тема оформления (Демо)',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Row(
            children: [
              _buildThemeCard(
                  'Dark Cyber', AppTheme.bgDark, AppTheme.primary, true),
              const SizedBox(width: 16),
              _buildThemeCard('Light Glass', const Color(0xFFE0E5EC),
                  const Color(0xFF4A90E2), false),
            ],
          ),
          const SizedBox(height: 32),
          SwitchListTile(
            title: const Text('Анимация частиц на фоне',
                style: TextStyle(color: Colors.white)),
            subtitle: const Text('Влияет на производительность',
                style: TextStyle(color: Colors.white54)),
            activeThumbColor: AppTheme.primary,
            value: true,
            onChanged: (val) {},
          ),
          SwitchListTile(
            title: const Text('Компактный режим сообщений',
                style: TextStyle(color: Colors.white)),
            activeThumbColor: AppTheme.primary,
            value: false,
            onChanged: (val) {},
          )
        ],
      ),
    );
  }

  Widget _buildThemeCard(String name, Color bg, Color accent, bool isSelected) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isSelected ? accent : Colors.transparent, width: 2),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                      color: accent.withValues(alpha: 0.4), blurRadius: 12)
                ]
              : [],
        ),
        child: Column(
          children: [
            Container(
                width: 40,
                height: 40,
                decoration:
                    BoxDecoration(color: accent, shape: BoxShape.circle)),
            const SizedBox(height: 12),
            Text(name,
                style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
