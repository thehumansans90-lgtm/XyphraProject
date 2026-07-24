import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import 'media_viewer_dialog.dart';

class AnimatedMessageTile extends StatefulWidget {
  final ChatMessage message;
  final bool isMe;
  final bool showAvatar;
  final String senderName;
  final String avatarUrl;
  final Uint8List? avatarBytes;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onReply;
  final VoidCallback? onForward;

  const AnimatedMessageTile({
    super.key,
    required this.message,
    required this.isMe,
    this.showAvatar = true,
    this.senderName = '',
    this.avatarUrl = '',
    this.avatarBytes,
    this.onEdit,
    this.onDelete,
    this.onReply,
    this.onForward,
  });

  @override
  State<AnimatedMessageTile> createState() => _AnimatedMessageTileState();
}

class _AnimatedMessageTileState extends State<AnimatedMessageTile> {
  bool _isHovered = false;

  void _openGallery(BuildContext context, int initialIndex) {
    if (widget.message.mediaListBytes == null || widget.message.mediaListBytes!.isEmpty) return;

    showDialog(
      context: context,
      useSafeArea: false,
      builder: (_) => MediaViewerDialog(
        mediaList: widget.message.mediaListBytes!,
        initialIndex: initialIndex,
      ),
    );
  }

  void _showMobileMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF16161D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.isMe && widget.onEdit != null)
                ListTile(
                  leading: const Icon(Icons.edit_outlined, color: Colors.white),
                  title: const Text('Редактировать', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    widget.onEdit?.call();
                  },
                ),
              ListTile(
                leading: const Icon(Icons.reply_rounded, color: Colors.white),
                title: const Text('Ответить', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  widget.onReply?.call();
                },
              ),
              ListTile(
                leading: const Icon(Icons.shortcut_rounded, color: Colors.white),
                title: const Text('Переслать', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  widget.onForward?.call();
                },
              ),
              if (widget.isMe && widget.onDelete != null)
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                  title: const Text('Удалить', style: TextStyle(color: Colors.redAccent)),
                  onTap: () {
                    Navigator.pop(context);
                    widget.onDelete?.call();
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  ImageProvider? _getAvatarImage() {
    if (widget.avatarBytes != null && widget.avatarBytes!.isNotEmpty) {
      return MemoryImage(widget.avatarBytes!);
    }
    if (widget.avatarUrl.isNotEmpty) {
      return NetworkImage(widget.avatarUrl);
    }
    return null;
  }

  // Виджет одной интерактивной картинки с эффектом затемнения
  Widget _buildMediaItem(Uint8List bytes, int index, {double? height}) {
    return ValueNotifierWidget(
      builder: (context, isItemHovered) {
        return Container(
          height: height,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _openGallery(context, index),
              splashColor: Colors.black38,
              highlightColor: Colors.black.withValues(alpha: 0.4), // Исправлено withOpacity -> withValues
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(
                    bytes,
                    fit: BoxFit.cover,
                  ),
                  // Эффект затемнения при наведении
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    color: isItemHovered
                        ? Colors.black.withValues(alpha: 0.25) // Исправлено withOpacity -> withValues
                        : Colors.transparent,
                  ),
                  if (widget.message.isVideo)
                    const Center(
                      child: CircleAvatar(
                        backgroundColor: Colors.black54,
                        child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Генерация сетки из нескольких картинок
  Widget _buildMediaGrid(List<Uint8List> mediaList) {
    final count = mediaList.length;

    if (count == 1) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 280, maxWidth: 380),
        child: AspectRatio(
          aspectRatio: 4 / 3,
          child: _buildMediaItem(mediaList[0], 0),
        ),
      );
    }

    if (count == 2) {
      return SizedBox(
        height: 180,
        width: 360,
        child: Row(
          children: [
            Expanded(child: _buildMediaItem(mediaList[0], 0)),
            const SizedBox(width: 4),
            Expanded(child: _buildMediaItem(mediaList[1], 1)),
          ],
        ),
      );
    }

    return SizedBox(
      height: 220,
      width: 360,
      child: Row(
        children: [
          Expanded(child: _buildMediaItem(mediaList[0], 0)),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              children: [
                Expanded(child: _buildMediaItem(mediaList[1], 1)),
                const SizedBox(height: 4),
                Expanded(
                  child: count > 3
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            _buildMediaItem(mediaList[2], 2),
                            GestureDetector(
                              onTap: () => _openGallery(context, 2),
                              child: Container(
                                color: const Color(0x99000000), // Исправлено Colors.black60 -> полупрозрачный черный
                                alignment: Alignment.center,
                                child: Text(
                                  '+${count - 2}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : _buildMediaItem(mediaList[2], 2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final avatarImage = _getAvatarImage();
    final mediaList = widget.message.mediaListBytes;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onLongPress: () => _showMobileMenu(context),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: EdgeInsets.only(
                top: widget.showAvatar ? 12.0 : 2.0,
                bottom: 2.0,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: widget.showAvatar
                        ? CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.deepPurpleAccent,
                            backgroundImage: avatarImage,
                            child: avatarImage == null
                                ? Text(
                                    widget.senderName.isNotEmpty
                                        ? widget.senderName[0].toUpperCase()
                                        : 'U',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.showAvatar) ...[
                          Row(
                            children: [
                              Text(
                                widget.senderName,
                                style: TextStyle(
                                  color: widget.isMe ? Colors.deepPurpleAccent : Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${widget.message.timestamp.hour.toString().padLeft(2, '0')}:${widget.message.timestamp.minute.toString().padLeft(2, '0')}',
                                style: const TextStyle(color: Colors.white38, fontSize: 10),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                        ],
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: widget.isMe ? const Color(0xFF2D264D) : const Color(0xFF181B24),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: widget.isMe
                                  ? Colors.deepPurpleAccent.withValues(alpha: 0.3) // Исправлено withOpacity
                                  : Colors.white.withValues(alpha: 0.05),          // Исправлено withOpacity
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (mediaList != null && mediaList.isNotEmpty) ...[
                                _buildMediaGrid(mediaList),
                                if (widget.message.text.isNotEmpty) const SizedBox(height: 6),
                              ],
                              if (widget.message.text.isNotEmpty)
                                Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.end,
                                  spacing: 6,
                                  children: [
                                    Text(
                                      widget.message.text,
                                      style: const TextStyle(
                                        color: Color(0xFFE2E4ED),
                                        fontSize: 14,
                                        height: 1.3,
                                      ),
                                    ),
                                    if (widget.message.isEdited)
                                      const Text(
                                        '(изменено)',
                                        style: TextStyle(
                                          color: Colors.white38,
                                          fontSize: 10,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_isHovered)
              Positioned(
                right: 12,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF222634),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4), // Исправлено withOpacity
                        blurRadius: 8,
                      ),
                    ],
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.isMe && widget.onEdit != null)
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 15, color: Colors.white70),
                          onPressed: widget.onEdit,
                          padding: const EdgeInsets.all(5),
                          constraints: const BoxConstraints(),
                        ),
                      IconButton(
                        icon: const Icon(Icons.reply_rounded, size: 15, color: Colors.white70),
                        onPressed: widget.onReply,
                        padding: const EdgeInsets.all(5),
                        constraints: const BoxConstraints(),
                      ),
                      IconButton(
                        icon: const Icon(Icons.shortcut_rounded, size: 15, color: Colors.white70),
                        onPressed: widget.onForward,
                        padding: const EdgeInsets.all(5),
                        constraints: const BoxConstraints(),
                      ),
                      if (widget.isMe && widget.onDelete != null)
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, size: 15, color: Colors.redAccent),
                          onPressed: widget.onDelete,
                          padding: const EdgeInsets.all(5),
                          constraints: const BoxConstraints(),
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
}

class ValueNotifierWidget extends StatefulWidget {
  final Widget Function(BuildContext context, bool isHovered) builder;
  const ValueNotifierWidget({super.key, required this.builder});

  @override
  State<ValueNotifierWidget> createState() => _ValueNotifierWidgetState();
}

class _ValueNotifierWidgetState extends State<ValueNotifierWidget> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: widget.builder(context, _isHovered),
    );
  }
}