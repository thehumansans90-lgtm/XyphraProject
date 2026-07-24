import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import 'package:file_picker/file_picker.dart' as file_picker_lib;
import 'dart:io';
import 'package:my_app/screens/auth_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/badge_manager.dart';
import 'package:my_app/widgets/status_indicator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_model.dart';
import '../services/chat_sync_service.dart';
import '../widgets/chat_header.dart';
import '../widgets/chat_welcome_card.dart';
import '../widgets/animated_message.dart';
import '../widgets/profile_sidebar.dart';

enum ActiveWorkspaceTab { chat, addFriend }

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

class _MainWorkspaceScreenState extends State<MainWorkspaceScreen> {
  final ChatSyncService _chatSyncService = ChatSyncService();
  ActiveWorkspaceTab _currentTab = ActiveWorkspaceTab.chat;
  bool _isProfileOpen = true;
  bool _isMobileChatOpen = false;

  final TextEditingController _msgController = TextEditingController();
  final FocusNode _msgFocusNode = FocusNode();
  final TextEditingController _searchFriendController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();

  late final UserProfile _savedMessagesUser, _xyphraBot;
  late UserProfile _selectedTargetUser;

  ChatMessage? _editingMessage;
  Uint8List? _attachedMediaBytes;
  String? _attachedMediaName;
  bool _isVideoMedia = false;

  final Map<String, List<ChatMessage>> _chatHistory = {};
  StreamSubscription<List<ChatMessage>>? _chatSubscription;
  StreamSubscription<List<ChatMessage>>? _globalIncomingMessagesSubscription;
  RealtimeChannel? _profilesRealtimeChannel;

  String _searchQuery = '';
  bool _isSearchingUsers = false;
  Timer? _searchDebounce;
  final List<UserProfile> _allGlobalUsers = [];
  final List<UserProfile> _searchResultsUsers = [];

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

  bool _checkIsUserOnline(UserProfile user) {
    if (user.badges.any((b) => b == 'BOT' || b == 'SAVED')) return true;
    if (user.id == widget.currentUser.id) return widget.isConnected;
    if (!widget.isConnected || !user.isOnline) return false;
    return user.lastSeen == null ||
        DateTime.now().toUtc().difference(user.lastSeen!.toUtc()).inSeconds <= 120;
  }

  Widget _buildStatusIndicatorForUser(UserProfile user, {double size = 10}) =>
      StatusIndicator(
        user: user,
        isConnected: widget.isConnected,
        size: size,
        enableAnimation: true,
      );

  @override
  void initState() {
    super.initState();
    _syncUserBadges(widget.currentUser);
    AuthService.saveSession(widget.currentUser);

    _savedMessagesUser = UserProfile(
      id: 'saved_messages_${widget.currentUser.id}',
      username: 'saved_messages',
      tag: '0000',
      displayName: 'Избранное',
      bio: 'Ваше личное пространство для заметок, файлов и сохраняемых сообщений.',
      avatarUrl: '',
      bannerColor: '0xFFFFC107',
      joinedDate: '21 июля 2026 г.',
      badges: ['SAVED'],
    );

    _xyphraBot = UserProfile(
      id: 'xyphra_bot',
      username: 'xyphra_official',
      tag: '0001',
      displayName: 'Xyphra Bot',
      bio: 'Официальный ассистент и гид по платформе Xyphra.',
      avatarUrl: '',
      bannerColor: '0xFF673AB7',
      joinedDate: '21 июля 2026 г.',
      badges: ['BOT', 'SYSTEM'],
    );

    _syncUserBadges(_xyphraBot);
    _allGlobalUsers.addAll([widget.currentUser, _savedMessagesUser, _xyphraBot]);
    _selectedTargetUser = _xyphraBot;

    _loadCachedMessages();
    _loadGlobalUsersFromServer();
    _subscribeToProfilesRealtime();
    _subscribeToGlobalIncomingMessages();
  }

  void _subscribeToGlobalIncomingMessages() {
    _globalIncomingMessagesSubscription?.cancel();
    _globalIncomingMessagesSubscription = _chatSyncService
        .subscribeToAllIncomingMessages(widget.currentUser.id, (messages) {
      if (!mounted || messages.isEmpty) return;
      final newMessage = messages.last;
      final senderId = newMessage.senderId;

      setState(() {
        final chat = _chatHistory.putIfAbsent(senderId, () => []);
        if (!chat.any((m) => m.id == newMessage.id)) {
          chat
            ..add(newMessage)
            ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
        }
      });

      _chatSyncService.saveChatHistory(_chatHistory);
      if (_selectedTargetUser.id == senderId) _scrollToBottom();
    });
  }

  Future<void> _saveLastActiveUserId(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_active_user_id_${widget.currentUser.id}', userId);
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
      _profilesRealtimeChannel = Supabase.instance.client
          .channel('public:profiles')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'profiles',
            callback: (_) => _loadGlobalUsersFromServer(),
          )
        ..subscribe();
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
    _searchDebounce =
        Timer(const Duration(milliseconds: 300), () => _performUserSearch(query));
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
    final cached = await _chatSyncService.loadChatHistory();
    final prefs = await SharedPreferences.getInstance();
    final savedUserId =
        prefs.getString('last_active_user_id_${widget.currentUser.id}');

    if (!mounted) return;
    setState(() {
      if (cached.isNotEmpty) {
        cached.forEach((k, list) => list.sort((a, b) => a.timestamp.compareTo(b.timestamp)));
        _chatHistory.addAll(cached);
      } else {
        _chatHistory[_xyphraBot.id] = [
          ChatMessage(
            id: 'welcome_msg',
            senderId: _xyphraBot.id,
            text:
                'Welcome To Xyphra! 🚀\nИсследуй возможности и находи друзей по их никнеймам.',
            timestamp: DateTime.now().toUtc(),
          )
        ];
      }

      if (savedUserId != null) {
        _selectedTargetUser = _allGlobalUsers.firstWhere(
            (u) => u.id == savedUserId,
            orElse: () => _selectedTargetUser);
      }
    });

    _subscribeToSelectedChat();
    _scrollToBottom();
  }

  void _subscribeToSelectedChat() {
    _chatSubscription?.cancel();
    _chatSubscription = null;
    final activeId = _selectedTargetUser.id;

    if (activeId == _xyphraBot.id || activeId == _savedMessagesUser.id) return;

    _chatSubscription = _chatSyncService.subscribeToChat(
      currentUserId: widget.currentUser.id,
      targetUserId: activeId,
      onData: (serverMessages) {
        if (mounted && _selectedTargetUser.id == activeId) {
          setState(() => _chatHistory[activeId] = serverMessages);
          _chatSyncService.saveChatHistory(_chatHistory);
        }
      },
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    if (_profilesRealtimeChannel != null) {
      Supabase.instance.client.removeChannel(_profilesRealtimeChannel!);
    }
    _chatSubscription?.cancel();
    _globalIncomingMessagesSubscription?.cancel();
    _msgController.dispose();
    _msgFocusNode.dispose();
    _searchFriendController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  ImageProvider? _getUserAvatarProvider(UserProfile user) {
    if (user.avatarBytes?.isNotEmpty == true) return MemoryImage(user.avatarBytes!);
    if (user.avatarUrl.isNotEmpty) return NetworkImage(user.avatarUrl);
    return null;
  }

  Future<void> _pickMediaFromGallery() async {
    try {
      final result = await file_picker_lib.FilePicker.pickFiles(
        type: file_picker_lib.FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'webp', 'mp4', 'mov', 'avi'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final bytes = file.bytes ?? (file.path != null ? await File(file.path!).readAsBytes() : null);
        
        if (bytes == null) return;
        
        final ext = file.name.toLowerCase();

        setState(() {
          _attachedMediaBytes = bytes;
          _attachedMediaName = file.name;
          _isVideoMedia =
              ext.endsWith('.mp4') || ext.endsWith('.mov') || ext.endsWith('.avi');
        });
      }
    } catch (e) {
      debugPrint('Ошибка при выборе файла: $e');
    }
  }

  void _openQuickCanvasModal() {
    showDialog(
      context: context,
      builder: (_) => QuickCanvasDialog(
        onCanvasExported: (bytes) => setState(() {
          _attachedMediaBytes = bytes;
          _attachedMediaName =
              'quick_sketch_${DateTime.now().millisecondsSinceEpoch}.png';
          _isVideoMedia = false;
        }),
      ),
    );
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
    showDialog(
      context: context,
      builder: (_) => SettingsDialog(
        user: widget.currentUser,
        onProfileUpdated: () =>
            mounted ? setState(() => _syncUserBadges(widget.currentUser)) : null,
        onLogout: _handleLogout,
        onDeleteAccount: _handleDeleteAccount,
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty && _attachedMediaBytes == null) return;

    final targetId = _selectedTargetUser.id;
    final mediaBytes = _attachedMediaBytes;
    final isVideo = _isVideoMedia;

    setState(() {
      _attachedMediaBytes = null;
      _attachedMediaName = null;
    });

    final messages = _chatHistory.putIfAbsent(targetId, () => []);

    if (_editingMessage != null) {
      final msgToUpdate = _editingMessage!;
      setState(() {
        msgToUpdate
          ..text = text
          ..isEdited = true;
        _editingMessage = null;
      });
      _msgController.clear();

      if (targetId != _xyphraBot.id && targetId != _savedMessagesUser.id) {
        await _chatSyncService.updateMessage(
          messageId: msgToUpdate.id,
          currentUserId: widget.currentUser.id,
          targetUserId: targetId,
          newText: text,
        );
      }
    } else {
      final now = DateTime.now().toUtc();
      final newMsg = ChatMessage(
        id: 'temp_${now.millisecondsSinceEpoch}',
        senderId: widget.currentUser.id,
        text: text,
        timestamp: now,
        mediaBytes: mediaBytes,
        isVideo: isVideo,
        isUploading: mediaBytes != null,
      );

      setState(() {
        messages
          ..add(newMsg)
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
        _msgController.clear();
      });

      _scrollToBottom();

      if (targetId != _xyphraBot.id && targetId != _savedMessagesUser.id) {
        final serverMsg = await _chatSyncService.sendMessage(
          senderId: widget.currentUser.id,
          targetUserId: targetId,
          content: text,
          mediaBytes: mediaBytes,
          isVideo: isVideo,
        );

        if (mounted && serverMsg != null) {
          setState(() {
            final idx = messages.indexWhere((m) => m.id == newMsg.id);
            if (idx != -1) messages[idx] = serverMsg;
            messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
          });
        }
      } else if (mediaBytes != null) {
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) setState(() => newMsg.isUploading = false);
      }
    }

    await _chatSyncService.saveChatHistory(_chatHistory);
    _msgFocusNode.requestFocus();
  }

  void _startEditingMessage(ChatMessage message) {
    setState(() {
      _editingMessage = message;
      _msgController.text = message.text;
    });
    _msgFocusNode.requestFocus();
  }

  void _editLastMessage() {
    if (_msgController.text.isNotEmpty) return;
    final lastMsg = (_chatHistory[_selectedTargetUser.id] ?? []).lastWhere(
      (m) => m.senderId == widget.currentUser.id,
      orElse: () => ChatMessage(
          id: '', senderId: '', text: '', timestamp: DateTime.now().toUtc()),
    );
    if (lastMsg.id.isNotEmpty) _startEditingMessage(lastMsg);
  }

  Future<void> _deleteMessage(ChatMessage message) async {
    if (message.senderId != widget.currentUser.id) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF16161D),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        title: const Text('Удалить сообщение?',
            style: TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        content: const Text(
            'Вы уверены, что хотите удалить это сообщение? Это действие нельзя отменить.',
            style: TextStyle(color: Colors.white70, fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child:
                  const Text('Отмена', style: TextStyle(color: Colors.white38))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent.withValues(alpha: 0.2),
                foregroundColor: Colors.redAccent,
                elevation: 0),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final targetId = _selectedTargetUser.id;

    setState(() => _chatHistory[targetId]?.removeWhere((m) => m.id == message.id));
    await _chatSyncService.saveChatHistory(_chatHistory);

    if (targetId != _xyphraBot.id && targetId != _savedMessagesUser.id) {
      await _chatSyncService.deleteMessage(
          messageId: message.id,
          currentUserId: widget.currentUser.id,
          targetUserId: targetId);
    }
  }

  Widget _buildAnimatedChatTile(
      {required Widget child,
      required bool isSelected,
      required VoidCallback onTap}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF1C1F2B) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isSelected
                ? Colors.deepPurpleAccent.withValues(alpha: 0.3)
                : Colors.transparent),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
            borderRadius: BorderRadius.circular(12), onTap: onTap, child: child),
      ),
    );
  }

  void _showMobileProfileBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Color(0xFF13151E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
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
    final chatUserIds =
        _chatHistory.entries.where((e) => e.value.isNotEmpty).map((e) => e.key).toSet();
    final chatUsers = _allGlobalUsers
        .where((u) => chatUserIds.contains(u.id) && u.id != widget.currentUser.id)
        .toList()
      ..sort((a, b) => _getLastMessageTime(b.id).compareTo(_getLastMessageTime(a.id)));

    return PopScope(
      canPop: !isMobile || !_isMobileChatOpen,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (isMobile && _isMobileChatOpen) {
          setState(() {
            _isMobileChatOpen = false;
          });
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0B0D12),
        body: Container(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              // 1. DOCK ПАНЕЛЬ СЛЕВА
              if (!isMobile || !_isMobileChatOpen)
                Container(
                  width: 64,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF13151E),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.deepPurpleAccent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.deepPurpleAccent.withValues(alpha: 0.25),
                                blurRadius: 10,
                                spreadRadius: 1)
                          ],
                        ),
                        child: const Icon(Icons.bolt_rounded,
                            color: Colors.deepPurpleAccent, size: 24),
                      ),
                      const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: Divider(color: Colors.white10, height: 1)),
                      InkWell(
                        onTap: () => setState(() => _currentTab = ActiveWorkspaceTab.chat),
                        borderRadius: BorderRadius.circular(14),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: _currentTab == ActiveWorkspaceTab.chat
                                ? const Color(0xFF1C1F2B)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: _currentTab == ActiveWorkspaceTab.chat
                                    ? Colors.deepPurpleAccent.withValues(alpha: 0.5)
                                    : Colors.transparent),
                          ),
                          child: AnimatedScale(
                            scale: _currentTab == ActiveWorkspaceTab.chat ? 1.15 : 1.0,
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOutBack,
                            child: Icon(Icons.chat_bubble_rounded,
                                color: _currentTab == ActiveWorkspaceTab.chat
                                    ? Colors.deepPurpleAccent
                                    : Colors.white38,
                                size: 20),
                          ),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                          icon: const Icon(Icons.settings_rounded,
                              color: Colors.white38, size: 22),
                          onPressed: _openSettingsModal,
                          tooltip: 'Настройки'),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),

              // 2. БОКОВАЯ ПАНЕЛЬ С ДРУЗЬЯМИ И ЧАТАМИ
              if (!isMobile || !_isMobileChatOpen)
                Expanded(
                  flex: isMobile ? 1 : 0,
                  child: Container(
                    width: isMobile ? null : 250,
                    margin: EdgeInsets.only(right: isMobile ? 0 : 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF13151E),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size.fromHeight(42),
                              backgroundColor: _currentTab == ActiveWorkspaceTab.addFriend
                                  ? Colors.deepPurpleAccent
                                  : const Color(0xFF1C1F2B),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () {
                              setState(() {
                                _currentTab = ActiveWorkspaceTab.addFriend;
                                if (isMobile) _isMobileChatOpen = true;
                              });
                              _performUserSearch(_searchFriendController.text);
                            },
                            icon: const Icon(Icons.person_add_rounded, size: 18),
                            label: const Text('Add Friend',
                                style:
                                    TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const Divider(color: Colors.white10, height: 1),

                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.all(8),
                            children: [
                              _buildAnimatedChatTile(
                                isSelected: _currentTab == ActiveWorkspaceTab.chat &&
                                    _selectedTargetUser.id == _savedMessagesUser.id,
                                onTap: () {
                                  _chatSubscription?.cancel();
                                  _chatSubscription = null;
                                  setState(() {
                                    _selectedTargetUser = _savedMessagesUser;
                                    _currentTab = ActiveWorkspaceTab.chat;
                                    if (isMobile) _isMobileChatOpen = true;
                                  });
                                  _saveLastActiveUserId(_savedMessagesUser.id);
                                },
                                child: ListTile(
                                  dense: true,
                                  leading: CircleAvatar(
                                      radius: 16,
                                      backgroundColor: Colors.amber.shade700,
                                      child: const Icon(Icons.bookmark_rounded,
                                          color: Colors.white, size: 18)),
                                  title: const Text('Избранное',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold)),
                                  subtitle: const Text('Файлы и заметки',
                                      style: TextStyle(color: Colors.white38, fontSize: 11),
                                      overflow: TextOverflow.ellipsis),
                                ),
                              ),
                              _buildAnimatedChatTile(
                                isSelected: _currentTab == ActiveWorkspaceTab.chat &&
                                    _selectedTargetUser.id == _xyphraBot.id,
                                onTap: () {
                                  _chatSubscription?.cancel();
                                  _chatSubscription = null;
                                  setState(() {
                                    _selectedTargetUser = _xyphraBot;
                                    _currentTab = ActiveWorkspaceTab.chat;
                                    if (isMobile) _isMobileChatOpen = true;
                                  });
                                  _saveLastActiveUserId(_xyphraBot.id);
                                },
                                child: ListTile(
                                  dense: true,
                                  leading: Stack(
                                    children: [
                                      const CircleAvatar(
                                          radius: 16,
                                          backgroundColor: Colors.deepPurpleAccent,
                                          child: Icon(Icons.smart_toy_rounded,
                                              color: Colors.white, size: 18)),
                                      Positioned(
                                          right: 0,
                                          bottom: 0,
                                          child: _buildStatusIndicatorForUser(_xyphraBot,
                                              size: 10)),
                                    ],
                                  ),
                                  title: Row(
                                    children: [
                                      Flexible(
                                          child: Text(_xyphraBot.displayName,
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold),
                                              overflow: TextOverflow.ellipsis)),
                                      if (_xyphraBot.badges.isNotEmpty) ...[
                                        const SizedBox(width: 5),
                                        BadgeManager.buildBadgesList(_xyphraBot.badges)
                                      ],
                                    ],
                                  ),
                                  subtitle: Text(
                                      '@${_xyphraBot.username}_${_xyphraBot.tag.replaceAll("#", "")}',
                                      style: const TextStyle(
                                          color: Colors.white38, fontSize: 11)),
                                ),
                              ),
                              const Divider(color: Colors.white10, height: 16),

                              for (final user in chatUsers.where((u) =>
                                  u.id != _xyphraBot.id &&
                                  u.id != _savedMessagesUser.id &&
                                  u.id != widget.currentUser.id))
                                _buildAnimatedChatTile(
                                  isSelected: _currentTab == ActiveWorkspaceTab.chat &&
                                      _selectedTargetUser.id == user.id,
                                  onTap: () {
                                    _chatSubscription?.cancel();
                                    _chatSubscription = null;
                                    setState(() {
                                      _selectedTargetUser = user;
                                      _currentTab = ActiveWorkspaceTab.chat;
                                      if (isMobile) _isMobileChatOpen = true;
                                    });
                                    _saveLastActiveUserId(user.id);
                                    _subscribeToSelectedChat();
                                  },
                                  child: ListTile(
                                    dense: true,
                                    leading: Stack(
                                      children: [
                                        CircleAvatar(
                                          radius: 16,
                                          backgroundColor: Colors.deepPurple,
                                          backgroundImage: _getUserAvatarProvider(user),
                                          child: _getUserAvatarProvider(user) == null
                                              ? Text(
                                                  user.displayName.isNotEmpty
                                                      ? user.displayName[0].toUpperCase()
                                                      : 'U',
                                                  style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold),
                                                )
                                              : null,
                                        ),
                                        Positioned(
                                          right: 0,
                                          bottom: 0,
                                          child: _buildStatusIndicatorForUser(user, size: 10),
                                        ),
                                      ],
                                    ),
                                    title: Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            user.displayName,
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (user.badges.isNotEmpty) ...[
                                          const SizedBox(width: 5),
                                          BadgeManager.buildBadgesList(user.badges)
                                        ],
                                      ],
                                    ),
                                    subtitle: Text(
                                      '@${user.username}',
                                      style: const TextStyle(
                                          color: Colors.white38, fontSize: 11),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // Профиль текущего пользователя внизу левого сайдбара
                        Builder(
                          builder: (context) {
                            final cleanTag =
                                widget.currentUser.tag.replaceAll('#', '');
                            final formattedUsername = (cleanTag.isNotEmpty &&
                                    !widget.currentUser.username.contains('_'))
                                ? '@${widget.currentUser.username}_$cleanTag'
                                : '@${widget.currentUser.username}';
                            final avatar =
                                _getUserAvatarProvider(widget.currentUser);

                            return Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Material(
                                color: const Color(0xFF1A1D28),
                                borderRadius: BorderRadius.circular(14),
                                clipBehavior: Clip.antiAlias,
                                child: Tooltip(
                                  message:
                                      'Ник: ${widget.currentUser.displayName}\nЮзернейм: $formattedUsername\nСтатус: ${_checkIsUserOnline(widget.currentUser) ? "В сети" : "Не в сети"}',
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF16161D),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.deepPurpleAccent
                                          .withValues(alpha: 0.3),
                                    ),
                                  ),
                                  textStyle: const TextStyle(
                                      color: Colors.white, fontSize: 12),
                                  child: ListTile(
                                    dense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 2),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14)),
                                    onTap: _openSettingsModal,
                                    leading: Stack(
                                      children: [
                                        CircleAvatar(
                                          radius: 18,
                                          backgroundColor: Colors.deepPurple,
                                          backgroundImage: avatar,
                                          child: avatar == null
                                              ? Text(
                                                  widget.currentUser.displayName
                                                          .isNotEmpty
                                                      ? widget.currentUser
                                                          .displayName[0]
                                                          .toUpperCase()
                                                      : 'U',
                                                  style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold),
                                                )
                                              : null,
                                        ),
                                        Positioned(
                                          right: 0,
                                          bottom: 0,
                                          child: _buildStatusIndicatorForUser(
                                              widget.currentUser,
                                              size: 10),
                                        ),
                                      ],
                                    ),
                                    title: Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            widget.currentUser.displayName,
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (widget.currentUser.badges.isNotEmpty) ...[
                                          const SizedBox(width: 5),
                                          BadgeManager.buildBadgesList(
                                              widget.currentUser.badges)
                                        ],
                                      ],
                                    ),
                                    subtitle: Text(
                                      formattedUsername,
                                      style: const TextStyle(
                                          color: Colors.white38, fontSize: 11),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    trailing: const Icon(Icons.settings_rounded,
                                        color: Colors.white38, size: 20),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),

              // 3. ОСНОВНОЙ ЭКРАН (ЧАТ / ПОИСК ДРУЗЕЙ)
              if (!isMobile || _isMobileChatOpen)
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF13151E),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.05)),
                    ),
                    child: Column(
                      children: [
                        // Кнопка возврата к списку чатов для мобильных устройств
                        if (isMobile)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 6),
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: Colors.white10),
                              ),
                            ),
                            child: Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                                      color: Colors.white70, size: 18),
                                  onPressed: () {
                                    setState(() {
                                      _isMobileChatOpen = false;
                                    });
                                  },
                                ),
                                Expanded(
                                  child: Text(
                                    _currentTab == ActiveWorkspaceTab.addFriend
                                        ? 'Поиск друзей'
                                        : _selectedTargetUser.displayName,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (_currentTab == ActiveWorkspaceTab.chat)
                                  IconButton(
                                    icon: const Icon(Icons.info_outline_rounded,
                                        color: Colors.white70, size: 20),
                                    onPressed: _showMobileProfileBottomSheet,
                                  ),
                              ],
                            ),
                          ),

                        AnimatedSize(
                          duration: const Duration(milliseconds: 200),
                          child: !widget.isConnected
                              ? Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 4, horizontal: 12),
                                  decoration: const BoxDecoration(
                                    color: Colors.amber,
                                    borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(20)),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.wifi_off_rounded,
                                          color: Colors.black, size: 14),
                                      SizedBox(width: 8),
                                      Text(
                                        'Автономный режим. Изменения сохраняются локально.',
                                        style: TextStyle(
                                            color: Colors.black,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            child: _currentTab == ActiveWorkspaceTab.addFriend
                                ? _buildAddFriendTab()
                                : _buildChatTab(
                                    _chatHistory[_selectedTargetUser.id] ?? []),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // 4. БОКОВАЯ ПАНЕЛЬ ПРОФИЛЯ ПОЛЬЗОВАТЕЛЯ (Только для десктопов)
              if (!isMobile)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOutCubic,
                  width: (_isProfileOpen && _currentTab == ActiveWorkspaceTab.chat)
                      ? 280
                      : 0,
                  margin: EdgeInsets.only(
                      left: (_isProfileOpen && _currentTab == ActiveWorkspaceTab.chat)
                          ? 8
                          : 0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: OverflowBox(
                      minWidth: 0,
                      maxWidth: 280,
                      alignment: Alignment.centerLeft,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: (_isProfileOpen &&
                                _currentTab == ActiveWorkspaceTab.chat)
                            ? 1.0
                            : 0.0,
                        child: ProfileSidebar(
                          user: _selectedTargetUser,
                          isMe: _selectedTargetUser.id == widget.currentUser.id,
                          isBot: _selectedTargetUser.badges.contains('BOT'),
                          sharedServers: const [],
                          onProfileUpdated: () => mounted ? setState(() {}) : null,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Вкладка добавления в друзья
  Widget _buildAddFriendTab() {
    final isMobile = MediaQuery.of(context).size.width < 768;
    final displayList = _searchResultsUsers.isEmpty && _searchQuery.isEmpty
        ? _allGlobalUsers
            .where((u) => u.id != _savedMessagesUser.id)
            .toList()
        : _searchResultsUsers;

    return Padding(
      padding: EdgeInsets.all(isMobile ? 12.0 : 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ПОИСК И ДОБАВЛЕНИЕ ДРУЗЕЙ',
            style: TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Введите имя пользователя или никнейм для мгновенного поиска в Supabase',
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _searchFriendController,
            style: const TextStyle(color: Colors.white),
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Поиск по @username в реальном времени...',
              hintStyle: const TextStyle(color: Colors.white24),
              prefixIcon: const Icon(Icons.search_rounded,
                  color: Colors.deepPurpleAccent),
              suffixIcon: _isSearchingUsers
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.deepPurpleAccent,
                        ),
                      ),
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFF1A1D28),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: displayList.isEmpty
                ? const Center(
                    child: Text('Пользователи не найдены',
                        style: TextStyle(color: Colors.white24)))
                : ListView.builder(
                    itemCount: displayList.length,
                    itemBuilder: (context, index) {
                      final user = displayList[index];
                      final isMe = user.id == widget.currentUser.id;
                      final avatar = _getUserAvatarProvider(user);
                      final cleanTag = user.tag.replaceAll('#', '');
                      final userTagText = (cleanTag.isNotEmpty &&
                              !user.username.contains('_'))
                          ? '@${user.username}_$cleanTag'
                          : '@${user.username}';

                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1D28),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.03),
                          ),
                        ),
                        child: Row(
                          children: [
                            Stack(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: Colors.deepPurpleAccent,
                                  backgroundImage: avatar,
                                  child: avatar == null
                                      ? Text(
                                          user.displayName.isNotEmpty
                                              ? user.displayName[0]
                                                  .toUpperCase()
                                              : 'U',
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold),
                                        )
                                      : null,
                                ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: _buildStatusIndicatorForUser(user,
                                      size: 11),
                                ),
                              ],
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          user.displayName,
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (user.badges.isNotEmpty) ...[
                                        const SizedBox(width: 6),
                                        BadgeManager.buildBadgesList(
                                            user.badges)
                                      ],
                                    ],
                                  ),
                                  Text(
                                    userTagText,
                                    style: const TextStyle(
                                        color: Colors.deepPurpleAccent,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                            if (isMe)
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8.0),
                                child: Text('Это вы',
                                    style: TextStyle(
                                        color: Colors.white24, fontSize: 12)),
                              )
                            else ...[
                              IconButton(
                                icon: const Icon(
                                    Icons.chat_bubble_outline_rounded,
                                    color: Colors.white54,
                                    size: 20),
                                tooltip: 'Написать',
                                onPressed: () {
                                  _chatSubscription?.cancel();
                                  _chatSubscription = null;
                                  setState(() {
                                    _selectedTargetUser = user;
                                    _currentTab = ActiveWorkspaceTab.chat;
                                    if (isMobile) _isMobileChatOpen = true;
                                  });
                                  _subscribeToSelectedChat();
                                },
                              ),
                              const SizedBox(width: 6),
                              IconButton(
                                icon: const Icon(Icons.person_add_alt_1_rounded,
                                    color: Colors.deepPurpleAccent, size: 22),
                                tooltip: 'Добавить в друзья',
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          'Запрос отправлен ${user.displayName}!'),
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                    ),
                                  );
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

  /// Вкладка чата
  Widget _buildChatTab(List<ChatMessage> currentMessages) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    final sortedMessages = List<ChatMessage>.from(currentMessages)
      ..sort((a, b) => a.timestamp.toUtc().compareTo(b.timestamp.toUtc()));

    return Column(
      children: [
        ChatHeader(
          targetUser: _selectedTargetUser,
          isProfileOpen: _isProfileOpen,
          onToggleProfile: () {
            if (isMobile) {
              _showMobileProfileBottomSheet();
            } else {
              setState(() => _isProfileOpen = !_isProfileOpen);
            }
          },
        ),
        const Divider(color: Colors.white10, height: 1),
        Expanded(
          child: ListView.builder(
            controller: _chatScrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: sortedMessages.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return ChatWelcomeCard(
                  targetUser: _selectedTargetUser,
                  isBot: _selectedTargetUser.badges.contains('BOT'),
                  isSavedMessages:
                      _selectedTargetUser.id == _savedMessagesUser.id,
                );
              }

              final msg = sortedMessages[index - 1];
              final isMe = msg.senderId == widget.currentUser.id;
              final showAvatar = index == 1 ||
                  sortedMessages[index - 2].senderId != msg.senderId;
              final senderUser = isMe
                  ? widget.currentUser
                  : _allGlobalUsers.firstWhere((u) => u.id == msg.senderId,
                      orElse: () => _selectedTargetUser);

              return AnimatedMessageTile(
                key: ValueKey(msg.id),
                message: msg,
                isMe: isMe,
                showAvatar: showAvatar,
                senderName: senderUser.displayName,
                avatarUrl: senderUser.avatarUrl,
                onEdit: isMe ? () => _startEditingMessage(msg) : null,
                onDelete: isMe ? () => _deleteMessage(msg) : null,
                onReply: () {},
                onForward: () {},
              );
            },
          ),
        ),

        // Панель ввода сообщений
        CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.arrowUp): _editLastMessage
          },
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  child: _editingMessage != null
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          margin: const EdgeInsets.only(bottom: 6),
                          decoration: BoxDecoration(
                              color: const Color(0xFF1C1F2B),
                              borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            children: [
                              const Icon(Icons.edit,
                                  size: 14, color: Colors.deepPurpleAccent),
                              const SizedBox(width: 8),
                              const Text('Редактирование сообщения',
                                  style: TextStyle(
                                      color: Colors.grey, fontSize: 12)),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.close,
                                    size: 14, color: Colors.grey),
                                onPressed: () => setState(() {
                                  _editingMessage = null;
                                  _msgController.clear();
                                }),
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  child: _attachedMediaBytes != null
                      ? Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1C1F2B),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.deepPurpleAccent
                                  .withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: _isVideoMedia
                                    ? Container(
                                        width: 44,
                                        height: 44,
                                        color: Colors.black,
                                        child: const Icon(
                                            Icons.play_circle_fill_rounded,
                                            color: Colors.white),
                                      )
                                    : Image.memory(_attachedMediaBytes!,
                                        width: 44,
                                        height: 44,
                                        fit: BoxFit.cover),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _attachedMediaName ??
                                          'Прикрепленный медиафайл',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      _isVideoMedia
                                          ? 'Видеофайл'
                                          : 'Изображение / Скетч',
                                      style: const TextStyle(
                                          color: Colors.white38, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close_rounded,
                                    color: Colors.white38, size: 18),
                                onPressed: () => setState(() {
                                  _attachedMediaBytes = null;
                                  _attachedMediaName = null;
                                }),
                              ),
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                TextField(
                  controller: _msgController,
                  focusNode: _msgFocusNode,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  onSubmitted: (_) => _sendMessage(),
                  decoration: InputDecoration(
                    hintText: _selectedTargetUser.id == _savedMessagesUser.id
                        ? 'Сохранить заметку или файл...'
                        : 'Написать @${_selectedTargetUser.displayName}',
                    hintStyle:
                        const TextStyle(color: Colors.white38, fontSize: 13),
                    filled: true,
                    fillColor: const Color(0xFF1A1D28),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    prefixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.photo_library_rounded,
                              color: Colors.deepPurpleAccent, size: 20),
                          tooltip: 'Прикрепить из галереи',
                          onPressed: _pickMediaFromGallery,
                        ),
                        IconButton(
                          icon: const Icon(Icons.brush_rounded,
                              color: Colors.amber, size: 20),
                          tooltip: 'Быстрый скетч (Quick Canvas)',
                          onPressed: _openQuickCanvasModal,
                        ),
                      ],
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _editingMessage != null
                            ? Icons.check_circle_rounded
                            : Icons.send_rounded,
                        color: Colors.deepPurpleAccent,
                      ),
                      onPressed: _sendMessage,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// ============================================================================
/// ДИАЛОГ УНИКАЛЬНОЙ ФИЧИ: QUICK CANVAS (БЫСТРЫЙ ЭСКИЗ / РИСОВАЛКА ДЛЯ ЧАТА)
/// ============================================================================
class QuickCanvasDialog extends StatefulWidget {
  final Function(Uint8List imageBytes) onCanvasExported;

  const QuickCanvasDialog({super.key, required this.onCanvasExported});

  @override
  State<QuickCanvasDialog> createState() => _QuickCanvasDialogState();
}

class _QuickCanvasDialogState extends State<QuickCanvasDialog> {
  final List<Offset?> _points = [];
  bool _isExporting = false;

  /// Генерация PNG-картинки из нарисованных точек
  Future<Uint8List> _generateImageBytes() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = Size(400, 400);

    // Заливаем фон темным цветом
    final bgPaint = Paint()..color = const Color(0xFF1A1D28);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Рисуем линии
    final painter = CanvasPainter(_points);
    painter.paint(canvas, size);

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.width.toInt(), size.height.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

    return byteData!.buffer.asUint8List();
  }

  Future<void> _exportAndSend() async {
    if (_points.isEmpty) return;

    setState(() => _isExporting = true);
    try {
      final imageBytes = await _generateImageBytes();
      widget.onCanvasExported(imageBytes);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('Ошибка при экспорте скетча: $e');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF13151E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 400,
        height: 480,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Быстрый скетч / Схема',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white38),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1D28),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: GestureDetector(
                  onPanStart: (details) {
                    setState(() => _points.add(details.localPosition));
                  },
                  onPanUpdate: (details) {
                    setState(() => _points.add(details.localPosition));
                  },
                  onPanEnd: (_) {
                    setState(() => _points.add(null));
                  },
                  child: CustomPaint(
                    painter: CanvasPainter(_points),
                    size: Size.infinite,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => setState(() => _points.clear()),
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                  label: const Text('Очистить', style: TextStyle(color: Colors.redAccent)),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurpleAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _isExporting ? null : _exportAndSend,
                  icon: _isExporting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send_rounded, size: 16),
                  label: const Text('Прикрепить к сообщению'),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}

class CanvasPainter extends CustomPainter {
  final List<Offset?> points;
  CanvasPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.deepPurpleAccent
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.0;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CanvasPainter oldDelegate) => true;
}

/// ============================================================================
/// ДИАЛОГ НАСТРОЕК ПОЛЬЗОВАТЕЛЯ
/// ============================================================================
class SettingsDialog extends StatefulWidget {
  final UserProfile user;
  final VoidCallback onProfileUpdated;
  final VoidCallback onLogout;
  final VoidCallback onDeleteAccount;

  const SettingsDialog({
    super.key,
    required this.user,
    required this.onProfileUpdated,
    required this.onLogout,
    required this.onDeleteAccount,
  });

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  bool _isEditing = false;
  late final TextEditingController _displayNameController;
  late final TextEditingController _bioController;
  Uint8List? _newAvatarBytes;

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController(text: widget.user.displayName);
    _bioController = TextEditingController(text: widget.user.bio);
  }

  @override
  void dispose() {
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
        final file = result.files.first;
        if (file.bytes != null) {
          setState(() {
            _newAvatarBytes = file.bytes;
          });
        }
      }
    } catch (e) {
      debugPrint('Ошибка при выборе аватара: $e');
    }
  }

  Future<void> _saveChanges() async {
    widget.user.displayName = _displayNameController.text.trim();
    widget.user.bio = _bioController.text.trim();

    if (_newAvatarBytes != null) {
      widget.user.avatarBytes = _newAvatarBytes;
    }

    await AuthService.saveSession(widget.user);
    widget.onProfileUpdated();

    if (mounted) {
      setState(() => _isEditing = false);
    }
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF16161D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Log Out', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to log out of your account?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pop(dialogContext); // Закрываем диалог подтверждения
              Navigator.pop(context);       // Закрываем диалог настроек
              widget.onLogout();
            },
            child: const Text('Log Out', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAccount() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF16161D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Account', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
        content: const Text(
          'Are you sure you want to permanently delete your account? This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pop(dialogContext); // Закрываем диалог подтверждения
              Navigator.pop(context);       // Закрываем диалог настроек
              widget.onDeleteAccount();
            },
            child: const Text('Delete Account', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ImageProvider? avatarProvider;
    if (_newAvatarBytes != null) {
      avatarProvider = MemoryImage(_newAvatarBytes!);
    } else if (widget.user.avatarBytes != null && widget.user.avatarBytes!.isNotEmpty) {
      avatarProvider = MemoryImage(widget.user.avatarBytes!);
    } else if (widget.user.avatarUrl.isNotEmpty) {
      avatarProvider = NetworkImage(widget.user.avatarUrl);
    }

    final cleanTag = widget.user.tag.replaceAll('#', '');
    final formattedUsername = (cleanTag.isNotEmpty && !widget.user.username.contains('_'))
        ? '@${widget.user.username}_$cleanTag'
        : '@${widget.user.username}';

    return Dialog(
      backgroundColor: const Color(0xFF13151E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 380,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Settings', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white38),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              GestureDetector(
                onTap: _isEditing ? _pickNewAvatar : null,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.deepPurple,
                      backgroundImage: avatarProvider,
                      child: avatarProvider == null
                          ? Text(
                              widget.user.displayName.isNotEmpty ? widget.user.displayName[0].toUpperCase() : 'U',
                              style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                            )
                          : null,
                    ),
                    if (_isEditing)
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 26),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              if (!_isEditing) ...[
                Text(
                  widget.user.displayName,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  formattedUsername,
                  style: const TextStyle(color: Colors.deepPurpleAccent, fontSize: 13, fontWeight: FontWeight.w500),
                ),
                if (widget.user.bio.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    widget.user.bio,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
                const SizedBox(height: 20),

                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(42),
                    backgroundColor: Colors.deepPurpleAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => setState(() => _isEditing = true),
                  icon: const Icon(Icons.edit_rounded, color: Colors.white, size: 18),
                  label: const Text('Edit Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ] else ...[
                const SizedBox(height: 6),
                const Text(
                  'Нажмите на фото, чтобы изменить аватар',
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
                const SizedBox(height: 14),

                TextField(
                  controller: _displayNameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Display Name',
                    labelStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: const Color(0xFF1A1D28),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _bioController,
                  maxLines: 2,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Bio',
                    labelStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: const Color(0xFF1A1D28),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => setState(() {
                          _isEditing = false;
                          _newAvatarBytes = null;
                        }),
                        child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
                      ),
                    ),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurpleAccent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _saveChanges,
                        child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],

              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Divider(color: Colors.white10),
              ),

              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(42),
                  backgroundColor: Colors.redAccent.withValues(alpha: 0.15),
                  foregroundColor: Colors.redAccent,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _confirmLogout,
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 10),

              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red.shade300,
                ),
                onPressed: _confirmDeleteAccount,
                icon: const Icon(Icons.delete_forever_rounded, size: 18),
                label: const Text('Delete Account', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}