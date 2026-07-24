import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../utils/badge_manager.dart';
import 'photo_cropper_dialog.dart';

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
  bool get _isBot => widget.isBot || widget.user.badges.contains('BOT');

  bool _validateUsername(String username) {
    final digitCount = RegExp(r'\d').allMatches(username).length;
    if (digitCount < 1) {
      return false;
    }
    final validCharacters = RegExp(r'^[a-zA-Z0-9_#]+$');
    return validCharacters.hasMatch(username);
  }

  String _getFormattedUsername() {
    if (widget.user.username.isEmpty) return '';

    if (widget.user.tag.isNotEmpty &&
        !widget.user.username.contains('#') &&
        !widget.user.username.contains('_')) {
      final cleanTag =
          widget.user.tag.startsWith('#') ? widget.user.tag : '#${widget.user.tag}';
      return '@${widget.user.username}$cleanTag';
    }

    return '@${widget.user.username}';
  }

  String _getFullUsernameForEdit() {
    if (widget.user.tag.isNotEmpty &&
        !widget.user.username.contains('#') &&
        !widget.user.username.contains('_')) {
      final cleanTag =
          widget.user.tag.startsWith('#') ? widget.user.tag : '#${widget.user.tag}';
      return '${widget.user.username}$cleanTag';
    }
    return widget.user.username;
  }

  Widget _buildStatusIndicator() {
    Color statusColor;
    String statusTooltip;

    if (_isBot) {
      statusColor = const Color(0xFF23A55A);
      statusTooltip = 'В сети 24/7';
    } else if (widget.user.isOnline) {
      statusColor = const Color(0xFF23A55A);
      statusTooltip = 'В сети';
    } else if (widget.user.isAppActive) {
      statusColor = const Color(0xFFFEE75C);
      statusTooltip = 'В приложении';
    } else {
      statusColor = const Color(0xFF80848E);
      statusTooltip = 'Не в сети';
    }

    return Tooltip(
      message: statusTooltip,
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: statusColor,
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xFF121218),
            width: 3.5,
          ),
        ),
      ),
    );
  }

  void _openEditProfileDialog() {
    final displayNameController =
        TextEditingController(text: widget.user.displayName);
    final usernameController =
        TextEditingController(text: _getFullUsernameForEdit());
    final bioController = TextEditingController(text: widget.user.bio);
    Uint8List? tempAvatarBytes = widget.user.avatarBytes;
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF16161D),
            title: const Text('Edit Profile', style: TextStyle(color: Colors.white)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: Colors.deepPurple,
                          backgroundImage: tempAvatarBytes != null &&
                                  tempAvatarBytes!.isNotEmpty
                              ? MemoryImage(tempAvatarBytes!)
                              : (widget.user.avatarUrl.isNotEmpty
                                  ? NetworkImage(widget.user.avatarUrl)
                                      as ImageProvider
                                  : null),
                          child: (tempAvatarBytes == null &&
                                  widget.user.avatarUrl.isEmpty)
                              ? Text(
                                  widget.user.displayName.isNotEmpty
                                      ? widget.user.displayName[0].toUpperCase()
                                      : 'U',
                                  style: const TextStyle(
                                      fontSize: 24, color: Colors.white),
                                )
                              : null,
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: InkWell(
                            onTap: isSaving ? null : () async {
                              final ImagePicker picker = ImagePicker();
                              
                              final XFile? image = await picker.pickImage(
                                source: ImageSource.gallery,
                                imageQuality: 80, 
                              );

                              await Future.delayed(const Duration(milliseconds: 100));

                              if (image == null) return;

                              final Uint8List rawBytes = await image.readAsBytes();

                              if (!context.mounted) return;

                              final dynamic result = await showDialog<dynamic>(
                                context: context,
                                barrierDismissible: false,
                                builder: (ctx) => PhotoCropperDialog(imageBytes: rawBytes),
                              );

                              if (result != null && result is List<int>) {
                                await Future.delayed(const Duration(milliseconds: 50));
                                
                                setDialogState(() {
                                  tempAvatarBytes = Uint8List.fromList(result);
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: Colors.deepPurpleAccent,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.camera_alt,
                                  size: 12, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Display Name',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: displayNameController,
                    enabled: !isSaving,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      filled: true,
                      fillColor: Color(0xFF0F0F13),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('ИМЯ ПОЛЬЗОВАТЕЛЯ (@USERNAME)',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: usernameController,
                    enabled: !isSaving,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      filled: true,
                      fillColor: Color(0xFF0F0F13),
                      border: OutlineInputBorder(),
                      hintText: 'например: HonyaDevXYPHRA#4085 или user_123',
                      hintStyle: TextStyle(color: Colors.white24),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Должен содержать хотя бы 1-2 цифры. Можно использовать "_" и "#".',
                    style: TextStyle(color: Colors.white38, fontSize: 10),
                  ),
                  const SizedBox(height: 12),
                  const Text('About Me (Bio)',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: bioController,
                    enabled: !isSaving,
                    maxLines: 3,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      filled: true,
                      fillColor: Color(0xFF0F0F13),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurpleAccent),
                onPressed: isSaving
                    ? null
                    : () async {
                        final newName = displayNameController.text.trim();
                        final rawUsername =
                            usernameController.text.trim().replaceAll('@', '');
                        final newBio = bioController.text.trim();

                        if (rawUsername.isNotEmpty) {
                          if (!_validateUsername(rawUsername)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Юзернейм должен содержать буквы, хотя бы 1-2 цифры и может использовать "_" или "#"!'),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                            return;
                          }
                          widget.user.username = rawUsername;
                        }

                        setDialogState(() {
                          isSaving = true;
                        });

                        if (newName.isNotEmpty) widget.user.displayName = newName;
                        widget.user.bio = newBio;
                        if (tempAvatarBytes != null) {
                          widget.user.avatarBytes = tempAvatarBytes;
                        }

                        try {
                          await AuthService.saveUser(widget.user);
                          widget.onProfileUpdated?.call();

                          if (mounted) {
                            setState(() {});
                          }

                          if (context.mounted) {
                            Navigator.of(dialogContext).pop();
                          }
                        } catch (e) {
                          setDialogState(() {
                            isSaving = false;
                          });
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Ошибка при сохранении: $e'),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                          }
                        }
                      },
                child: isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Save Changes'),
              ),
            ],
          );
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
        duration: const Duration(seconds: 2),
      ),
    );
  }

  ImageProvider? _getAvatarProvider() {
    if (widget.user.avatarBytes != null &&
        widget.user.avatarBytes!.isNotEmpty) {
      return MemoryImage(widget.user.avatarBytes!);
    } else if (widget.user.avatarUrl.isNotEmpty) {
      return NetworkImage(widget.user.avatarUrl);
    }
    return null;
  }

  Color _getBannerColor() {
    try {
      final cleanHex = widget.user.bannerColor.replaceAll('#', '');
      return Color(int.parse(cleanHex, radix: 16));
    } catch (_) {
      return const Color(0xFF2D264D);
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatarProvider = _getAvatarProvider();
    final bannerColor = _getBannerColor();
    final formattedUsername = _getFormattedUsername();

    return Container(
      width: 280,
      color: const Color(0xFF121218),
      child: Column(
        children: [
          // Banner & Avatar
          Container(
            height: 120,
            color: bannerColor,
            child: Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.deepPurple,
                    backgroundImage: avatarProvider,
                    child: avatarProvider == null
                        ? Text(
                            widget.user.displayName.isNotEmpty
                                ? widget.user.displayName[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              fontSize: 28,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: _buildStatusIndicator(),
                  ),
                ],
              ),
            ),
          ),

          // User Info
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.user.displayName.isNotEmpty
                            ? widget.user.displayName
                            : widget.user.username,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (widget.isMe) ...[
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurpleAccent,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: _openEditProfileDialog,
                        child: const Text(
                          'Edit Profile',
                          style: TextStyle(fontSize: 11, color: Colors.white),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),

                // 🎯 Динамический вывод ВСЕХ бейджей через BadgeManager
                BadgeManager.buildBadgesList(widget.user.badges),

                const SizedBox(height: 8),

                Tooltip(
                  message: formattedUsername,
                  child: InkWell(
                    onTap: _copyUsername,
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Expanded(
                            child: SelectableText(
                              formattedUsername,
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 13),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.copy, size: 11, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                const Text(
                  'О СЕБЕ',
                  style: TextStyle(
                      color: Colors.grey,
                      fontSize: 10,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.user.bio.isNotEmpty
                      ? widget.user.bio
                      : 'Информация отсутствует',
                  style: TextStyle(
                    color: widget.user.bio.isNotEmpty
                        ? Colors.white70
                        : Colors.white38,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          if (widget.sharedServers.isNotEmpty) ...[
            const Divider(color: Colors.white10),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'ОБЩИЕ СЕРВЕРА',
                  style: TextStyle(
                      color: Colors.grey,
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: widget.sharedServers.length,
                itemBuilder: (context, index) => ListTile(
                  dense: true,
                  leading: const Icon(Icons.dns,
                      size: 18, color: Colors.deepPurpleAccent),
                  title: Text(
                    widget.sharedServers[index],
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}