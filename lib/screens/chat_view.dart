import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart' as file_picker_lib;

import '../models/user_model.dart';
import '../services/chat_sync_service.dart';
import '../widgets/animated_message.dart';
import '../widgets/chat_header.dart';
import '../widgets/chat_welcome_card.dart';
import 'main_workspace_screen.dart';

class ChatView extends StatefulWidget {
  final UserProfile currentUser;
  final UserProfile selectedTargetUser;
  final UserProfile savedMessagesUser;
  final UserProfile xyphraBot;
  final List<ChatMessage> currentMessages;
  final ChatSyncService chatSyncService;
  final Map<String, List<ChatMessage>> chatHistory;
  final bool isMobile;
  final VoidCallback onToggleProfile;
  final VoidCallback onMessageStateChanged;

  const ChatView({
    super.key,
    required this.currentUser,
    required this.selectedTargetUser,
    required this.savedMessagesUser,
    required this.xyphraBot,
    required this.currentMessages,
    required this.chatSyncService,
    required this.chatHistory,
    required this.isMobile,
    required this.onToggleProfile,
    required this.onMessageStateChanged,
  });

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final TextEditingController _msgController = TextEditingController();
  final FocusNode _msgFocusNode = FocusNode();
  final ScrollController _chatScrollController = ScrollController();

  ChatMessage? _editingMessage;
  Uint8List? _attachedMediaBytes;
  String? _attachedMediaName;
  bool _isVideoMedia = false;

  @override
  void dispose() {
    _msgController.dispose();
    _msgFocusNode.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  // При reverse: true "низ" списка — это позиция 0.0
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> _pickMediaFromGallery() async {
    try {
      final result = await file_picker_lib.FilePicker.pickFiles(
        type: file_picker_lib.FileType.custom,
        allowedExtensions: [
          'jpg',
          'jpeg',
          'png',
          'gif',
          'webp',
          'mp4',
          'mov',
          'avi'
        ],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final bytes = file.bytes ??
            (file.path != null ? await File(file.path!).readAsBytes() : null);

        if (bytes == null) return;
        final ext = file.name.toLowerCase();

        setState(() {
          _attachedMediaBytes = bytes;
          _attachedMediaName = file.name;
          _isVideoMedia = ext.endsWith('.mp4') ||
              ext.endsWith('.mov') ||
              ext.endsWith('.avi');
        });
      }
    } catch (e) {
      debugPrint('File picker error: $e');
    }
  }

  void _openQuickCanvasModal() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Quick Canvas',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) => QuickCanvasDialog(
        onCanvasExported: (bytes) => setState(() {
          _attachedMediaBytes = bytes;
          _attachedMediaName =
              'quick_sketch_${DateTime.now().millisecondsSinceEpoch}.png';
          _isVideoMedia = false;
        }),
      ),
      transitionBuilder: (context, anim1, anim2, child) {
        return Transform.scale(
          scale: Curves.easeOutBack.transform(anim1.value),
          child: Opacity(opacity: anim1.value, child: child),
        );
      },
    );
  }

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty && _attachedMediaBytes == null) return;

    final targetId = widget.selectedTargetUser.id;
    final mediaBytes = _attachedMediaBytes;
    final isVideo = _isVideoMedia;

    setState(() {
      _attachedMediaBytes = null;
      _attachedMediaName = null;
    });

    final messages = widget.chatHistory.putIfAbsent(targetId, () => []);

    if (_editingMessage != null) {
      final msgToUpdate = _editingMessage!;
      setState(() {
        msgToUpdate
          ..text = text
          ..isEdited = true;
        _editingMessage = null;
      });
      _msgController.clear();

      if (targetId != widget.xyphraBot.id &&
          targetId != widget.savedMessagesUser.id) {
        await widget.chatSyncService.updateMessage(
          messageId: msgToUpdate.id,
          currentUserId: widget.currentUser.id,
          targetUserId: targetId,
          newText: text,
        );
      }
    } else {
      final now = DateTime.now();
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
        messages.add(newMsg);
        _msgController.clear();
      });

      _scrollToBottom();

      if (targetId != widget.xyphraBot.id &&
          targetId != widget.savedMessagesUser.id) {
        final serverMsg = await widget.chatSyncService.sendMessage(
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
          });
        }
      } else if (mediaBytes != null) {
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) setState(() => newMsg.isUploading = false);
      }
    }

    await widget.chatSyncService
        .saveChatHistory(widget.currentUser.id, widget.chatHistory);
    widget.onMessageStateChanged();
    _msgFocusNode.requestFocus();
  }

  void _cancelEditing() {
    setState(() {
      _editingMessage = null;
      _msgController.clear();
    });
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
    final messages = widget.chatHistory[widget.selectedTargetUser.id] ?? [];
    try {
      final lastMsg =
          messages.lastWhere((m) => m.senderId == widget.currentUser.id);
      _startEditingMessage(lastMsg);
    } catch (_) {}
  }

  Future<void> _deleteMessage(ChatMessage message) async {
    if (message.senderId != widget.currentUser.id) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.panelBgLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_rounded, color: AppTheme.danger),
            SizedBox(width: 10),
            Text('Delete Message?',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text('This action cannot be undone. Are you sure?',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 14)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel',
                  style: TextStyle(color: AppTheme.textMuted))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger.withValues(alpha: 0.2),
              foregroundColor: AppTheme.danger,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final targetId = widget.selectedTargetUser.id;

    setState(() {
      if (_editingMessage?.id == message.id) {
        _cancelEditing();
      }
      widget.chatHistory[targetId]?.removeWhere((m) => m.id == message.id);
    });

    await widget.chatSyncService
        .saveChatHistory(widget.currentUser.id, widget.chatHistory);
    widget.onMessageStateChanged();

    if (targetId != widget.xyphraBot.id &&
        targetId != widget.savedMessagesUser.id) {
      await widget.chatSyncService.deleteMessage(
          messageId: message.id,
          currentUserId: widget.currentUser.id,
          targetUserId: targetId);
    }
  }

  // 🧹 CLEAR CHAT HISTORY WITH LOADING BAR
  Future<void> _clearChatHistory() async {
    final targetId = widget.selectedTargetUser.id;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: const Color(0xFF181A26).withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFFFF5252)),
                    ),
                  ),
                  SizedBox(width: 16),
                  Text(
                    'Clearing message history...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    try {
      setState(() {
        _cancelEditing();
        widget.chatHistory[targetId]?.clear();
      });

      await widget.chatSyncService
          .saveChatHistory(widget.currentUser.id, widget.chatHistory);
      widget.onMessageStateChanged();

      if (targetId != widget.xyphraBot.id &&
          targetId != widget.savedMessagesUser.id) {
        await widget.chatSyncService.clearChatHistory(
          currentUserId: widget.currentUser.id,
          targetUserId: targetId,
        );
      }
    } catch (e) {
      debugPrint('Clear chat error: $e');
    } finally {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    }
  }

  // --- ENGLISH DATE & TIME FORMATTERS ---
  String _formatDateDivider(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final msgDate = DateTime(date.year, date.month, date.day);

    if (msgDate == today) {
      return 'Today';
    } else if (msgDate == yesterday) {
      return 'Yesterday';
    } else {
      const months = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December'
      ];
      final monthName = months[date.month - 1];
      return date.year == now.year
          ? '$monthName ${date.day}'
          : '$monthName ${date.day}, ${date.year}';
    }
  }

  String _formatTimeDivider(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Widget _buildTimeDivider(String text) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.0),
                    Colors.white.withValues(alpha: 0.12),
                  ],
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            margin: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1E202E).withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              text,
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.12),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sortedMessages = List<ChatMessage>.from(widget.currentMessages)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final reversedMessages = sortedMessages.reversed.toList();

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowUp): _editLastMessage,
        const SingleActivator(LogicalKeyboardKey.escape): _cancelEditing,
      },
      child: Column(
        children: [
          ChatHeader(
            targetUser: widget.selectedTargetUser,
            isProfileOpen: true,
            onToggleProfile: widget.onToggleProfile,
            onClearChat: _clearChatHistory,
          ),
          Divider(color: Colors.white.withValues(alpha: 0.05), height: 1),
          Expanded(
            child: ListView.builder(
              controller: _chatScrollController,
              reverse: true,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              itemCount: reversedMessages.length + 1,
              itemBuilder: (context, index) {
                if (index == reversedMessages.length) {
                  return ChatWelcomeCard(
                    targetUser: widget.selectedTargetUser,
                    isBot: widget.selectedTargetUser.badges.contains('BOT'),
                    isSavedMessages: widget.selectedTargetUser.id ==
                        widget.savedMessagesUser.id,
                  );
                }

                final msg = reversedMessages[index];
                final isMe = msg.senderId == widget.currentUser.id;

                final showAvatar = index == reversedMessages.length - 1 ||
                    reversedMessages[index + 1].senderId != msg.senderId;

                // --- DIVIDER LOGIC (DATE & HOUR BREAK) ---
                final bool isOldestMsgInList =
                    index == reversedMessages.length - 1;

                Widget? topDivider;

                if (!isOldestMsgInList) {
                  final prevMsg = reversedMessages[index + 1];
                  final currTime = msg.timestamp;
                  final prevTime = prevMsg.timestamp;

                  final isDifferentDay = currTime.year != prevTime.year ||
                      currTime.month != prevTime.month ||
                      currTime.day != prevTime.day;

                  if (isDifferentDay) {
                    topDivider =
                        _buildTimeDivider(_formatDateDivider(currTime));
                  } else {
                    final diffMinutes =
                        currTime.difference(prevTime).inMinutes.abs();
                    if (diffMinutes >= 60) {
                      // Displays both time and contextual date when > 1h passes
                      final timeStr = _formatTimeDivider(currTime);
                      final dateStr = _formatDateDivider(currTime);
                      topDivider = _buildTimeDivider('$timeStr · $dateStr');
                    }
                  }
                } else {
                  topDivider =
                      _buildTimeDivider(_formatDateDivider(msg.timestamp));
                }

                final messageTile = AnimatedMessageTile(
                  key: ValueKey(msg.id),
                  message: msg,
                  isMe: isMe,
                  showAvatar: showAvatar,
                  senderName: isMe
                      ? widget.currentUser.displayName
                      : widget.selectedTargetUser.displayName,
                  avatarUrl: isMe
                      ? widget.currentUser.avatarUrl
                      : widget.selectedTargetUser.avatarUrl,
                  onEdit: isMe ? () => _startEditingMessage(msg) : null,
                  onDelete: isMe ? () => _deleteMessage(msg) : null,
                  onReply: () {},
                  onForward: () {},
                );

                if (topDivider != null) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      topDivider,
                      messageTile,
                    ],
                  );
                }

                return messageTile;
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              children: [
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutBack,
                  child: _editingMessage != null
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: AppTheme.panelBgLight.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: AppTheme.primary.withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.edit_rounded,
                                  size: 18, color: AppTheme.primary),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Editing message',
                                        style: TextStyle(
                                            color: AppTheme.primary,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold)),
                                    Text('Press ESC to cancel',
                                        style: TextStyle(
                                            color: AppTheme.textMuted,
                                            fontSize: 10)),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close_rounded,
                                    size: 18, color: Colors.white54),
                                onPressed: _cancelEditing,
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutBack,
                  child: _attachedMediaBytes != null
                      ? Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.panelBgLight.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color:
                                    AppTheme.secondary.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: _isVideoMedia
                                    ? Container(
                                        width: 50,
                                        height: 50,
                                        color: Colors.black,
                                        child: const Icon(
                                            Icons.videocam_rounded,
                                            color: Colors.white,
                                            size: 28))
                                    : Image.memory(_attachedMediaBytes!,
                                        width: 50,
                                        height: 50,
                                        fit: BoxFit.cover),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_attachedMediaName ?? 'Attached File',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold),
                                        overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 2),
                                    Text(
                                        _isVideoMedia
                                            ? 'Video file'
                                            : 'Image / Canvas',
                                        style: const TextStyle(
                                            color: AppTheme.textMuted,
                                            fontSize: 12)),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded,
                                    color: AppTheme.danger, size: 22),
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
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.panelBgLight,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4))
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 4),
                        child: IconButton(
                          icon: const Icon(Icons.add_circle_outline_rounded,
                              color: AppTheme.textMuted, size: 26),
                          tooltip: 'Attach',
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              backgroundColor: Colors.transparent,
                              builder: (context) => Container(
                                margin: const EdgeInsets.all(16),
                                padding: const EdgeInsets.all(16),
                                decoration: AppTheme.glassDecoration,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ListTile(
                                      leading: const Icon(
                                          Icons.photo_library_rounded,
                                          color: AppTheme.primary),
                                      title: const Text('Media & Files',
                                          style:
                                              TextStyle(color: Colors.white)),
                                      onTap: () {
                                        Navigator.pop(context);
                                        _pickMediaFromGallery();
                                      },
                                    ),
                                    ListTile(
                                      leading: const Icon(Icons.brush_rounded,
                                          color: AppTheme.warning),
                                      title: const Text('Quick Canvas',
                                          style:
                                              TextStyle(color: Colors.white)),
                                      onTap: () {
                                        Navigator.pop(context);
                                        _openQuickCanvasModal();
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _msgController,
                          focusNode: _msgFocusNode,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 15),
                          maxLines: 5,
                          minLines: 1,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _sendMessage(),
                          decoration: InputDecoration(
                            hintText: widget.selectedTargetUser.id ==
                                    widget.savedMessagesUser.id
                                ? 'Save a note for yourself...'
                                : 'Message @${widget.selectedTargetUser.username}...',
                            hintStyle: const TextStyle(
                                color: Colors.white38, fontSize: 15),
                            border: InputBorder.none,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: InkWell(
                          onTap: _sendMessage,
                          borderRadius: BorderRadius.circular(16),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [
                                AppTheme.primary,
                                Color(0xFF9C27B0)
                              ]),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: const [
                                BoxShadow(
                                    color: AppTheme.primaryGlow, blurRadius: 10)
                              ],
                            ),
                            child: Icon(
                                _editingMessage != null
                                    ? Icons.check_rounded
                                    : Icons.send_rounded,
                                color: Colors.white,
                                size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class QuickCanvasDialog extends StatefulWidget {
  final Function(Uint8List imageBytes) onCanvasExported;

  const QuickCanvasDialog({super.key, required this.onCanvasExported});

  @override
  State<QuickCanvasDialog> createState() => _QuickCanvasDialogState();
}

class _QuickCanvasDialogState extends State<QuickCanvasDialog> {
  final List<CanvasPoint?> _points = [];
  bool _isExporting = false;

  Color _selectedColor = AppTheme.secondary;
  double _strokeWidth = 3.0;

  final List<Color> _colors = [
    AppTheme.secondary,
    AppTheme.primary,
    AppTheme.success,
    AppTheme.warning,
    AppTheme.danger,
    Colors.white,
  ];

  Future<Uint8List> _generateImageBytes(Size canvasSize) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final bgPaint = Paint()..color = AppTheme.bgDark;
    canvas.drawRect(
        Rect.fromLTWH(0, 0, canvasSize.width, canvasSize.height), bgPaint);

    final painter = CanvasPainter(_points);
    painter.paint(canvas, canvasSize);

    final picture = recorder.endRecording();
    final img = await picture.toImage(
        canvasSize.width.toInt(), canvasSize.height.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

    return byteData!.buffer.asUint8List();
  }

  Future<void> _exportAndSend(Size canvasSize) async {
    if (_points.isEmpty) return;
    setState(() => _isExporting = true);
    try {
      final imageBytes = await _generateImageBytes(canvasSize);
      widget.onCanvasExported(imageBytes);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('Export sketch error: $e');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: 500,
        height: 650,
        decoration: AppTheme.glassDecoration,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.brush_rounded, color: AppTheme.warning),
                    SizedBox(width: 10),
                    Text(
                      'Xyphra Quick Canvas',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white54),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    children: _colors
                        .map(
                          (c) => GestureDetector(
                            onTap: () => setState(() => _selectedColor = c),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: c,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _selectedColor == c
                                      ? Colors.white
                                      : Colors.transparent,
                                  width: 2,
                                ),
                                boxShadow: _selectedColor == c
                                    ? [
                                        BoxShadow(
                                            color: c.withValues(alpha: 0.6),
                                            blurRadius: 8)
                                      ]
                                    : [],
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                SizedBox(
                  width: 100,
                  child: Slider(
                    value: _strokeWidth,
                    min: 1,
                    max: 10,
                    activeColor: _selectedColor,
                    inactiveColor: Colors.white24,
                    onChanged: (v) => setState(() => _strokeWidth = v),
                  ),
                )
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final canvasSize =
                      Size(constraints.maxWidth, constraints.maxHeight);
                  return Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: AppTheme.bgDark,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 10)
                      ],
                    ),
                    child: GestureDetector(
                      onPanStart: (details) => setState(() => _points.add(
                          CanvasPoint(details.localPosition, _selectedColor,
                              _strokeWidth))),
                      onPanUpdate: (details) => setState(() => _points.add(
                          CanvasPoint(details.localPosition, _selectedColor,
                              _strokeWidth))),
                      onPanEnd: (_) => setState(() => _points.add(null)),
                      child: CustomPaint(
                          painter: CanvasPainter(_points), size: canvasSize),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                return Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => setState(() => _points.clear()),
                      icon: const Icon(Icons.delete_outline_rounded,
                          color: AppTheme.danger, size: 20),
                      label: const Text('Clear Canvas',
                          style: TextStyle(
                              color: AppTheme.danger,
                              fontWeight: FontWeight.bold)),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 10,
                        shadowColor: AppTheme.primaryGlow,
                      ),
                      onPressed: _isExporting
                          ? null
                          : () {
                              final renderBox =
                                  context.findRenderObject() as RenderBox?;
                              final size =
                                  renderBox?.size ?? const Size(460, 400);
                              _exportAndSend(Size(size.width, size.height));
                            },
                      icon: _isExporting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.send_rounded, size: 18),
                      label: const Text('Attach',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ],
                );
              },
            )
          ],
        ),
      ),
    );
  }
}

class CanvasPoint {
  final Offset offset;
  final Color color;
  final double width;
  CanvasPoint(this.offset, this.color, this.width);
}

class CanvasPainter extends CustomPainter {
  final List<CanvasPoint?> points;
  CanvasPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        final paint = Paint()
          ..color = points[i]!.color
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = points[i]!.width;
        canvas.drawLine(points[i]!.offset, points[i + 1]!.offset, paint);
      } else if (points[i] != null && points[i + 1] == null) {
        final paint = Paint()
          ..color = points[i]!.color
          ..style = PaintingStyle.fill;
        canvas.drawCircle(points[i]!.offset, points[i]!.width / 2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CanvasPainter oldDelegate) => true;
}
