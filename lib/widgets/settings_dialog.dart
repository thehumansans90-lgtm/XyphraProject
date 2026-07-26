import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import 'photo_cropper_dialog.dart';

class SettingsDialog extends StatefulWidget {
  final UserProfile user;
  final VoidCallback onProfileUpdated;

  const SettingsDialog({
    super.key,
    required this.user,
    required this.onProfileUpdated,
  });

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late TextEditingController _displayNameController;
  late TextEditingController _usernameController;
  late TextEditingController _bioController;
  Uint8List? _tempAvatarBytes;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _displayNameController =
        TextEditingController(text: widget.user.displayName);
    _usernameController = TextEditingController(text: widget.user.username);
    _bioController = TextEditingController(text: widget.user.bio);
    _tempAvatarBytes = widget.user.avatarBytes;
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickAndCropAvatar() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null || !mounted) return;

    final bytes = await image.readAsBytes();

    if (!mounted) return;

    final resultBytes = await showDialog<Uint8List>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PhotoCropperDialog(imageBytes: bytes),
    );

    if (resultBytes != null && mounted) {
      setState(() {
        _tempAvatarBytes = resultBytes;
      });
    }
  }

  void _removeAvatar() {
    setState(() {
      _tempAvatarBytes = null;
      widget.user.avatarBytes = null;
      widget.user.avatarUrl = '';
    });
  }

  Future<void> _saveSettings() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    final now = DateTime.now();
    final newUsername = _usernameController.text.trim();

    if (newUsername.isNotEmpty) {
      widget.user.username = newUsername;
      widget.user.lastUsernameChange = now;
    }

    widget.user.displayName = _displayNameController.text.trim();
    widget.user.bio = _bioController.text.trim();
    widget.user.avatarBytes = _tempAvatarBytes;

    await AuthService.saveUser(widget.user);
    widget.onProfileUpdated();

    if (mounted) {
      setState(() => _isSaving = false);
      Navigator.pop(context);
    }
  }

  ImageProvider? _getAvatarProvider() {
    if (_tempAvatarBytes != null && _tempAvatarBytes!.isNotEmpty) {
      return MemoryImage(_tempAvatarBytes!);
    }

    final url = widget.user.avatarUrl.trim();
    if (url.isEmpty) return null;

    if (url.startsWith('/') ||
        url.contains(':\\') ||
        url.startsWith('file://')) {
      final cleanPath = url.replaceFirst('file://', '');
      final file = File(cleanPath);
      if (file.existsSync()) {
        return FileImage(file);
      }
      return null;
    }

    if (url.startsWith('http://') || url.startsWith('https://')) {
      return NetworkImage(url);
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final avatarProvider = _getAvatarProvider();

    return Dialog(
      backgroundColor: const Color(0xFF13151E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Container(
        width: 500,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Profile Settings',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white38),
                  onPressed: _isSaving ? null : () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Center(
                      child: Column(
                        children: [
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 46,
                                backgroundColor: const Color(0xFF7C4DFF),
                                backgroundImage: avatarProvider,
                                child: avatarProvider == null
                                    ? Text(
                                        _displayNameController.text.isNotEmpty
                                            ? _displayNameController.text[0]
                                                .toUpperCase()
                                            : 'U',
                                        style: const TextStyle(
                                          fontSize: 32,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      )
                                    : null,
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: GestureDetector(
                                  onTap: _isSaving ? null : _pickAndCropAvatar,
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF7C4DFF),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.crop_rotate_rounded,
                                        size: 16, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (avatarProvider != null) ...[
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: _isSaving ? null : _removeAvatar,
                              icon: const Icon(Icons.delete_outline,
                                  size: 14, color: Colors.redAccent),
                              label: const Text(
                                'Remove avatar',
                                style: TextStyle(
                                    color: Colors.redAccent, fontSize: 12),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildInputField('Display Name', _displayNameController,
                        'Your display name'),
                    const SizedBox(height: 14),
                    _buildInputField('Username (@username)',
                        _usernameController, 'username'),
                    const SizedBox(height: 14),
                    _buildInputField(
                        'About Me', _bioController, 'Tell us about yourself...',
                        maxLines: 2),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isSaving ? null : () => Navigator.pop(context),
                  child: const Text('Cancel',
                      style: TextStyle(color: Colors.white38)),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C4DFF),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _isSaving ? null : _saveSettings,
                  child: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Save',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField(
      String label, TextEditingController controller, String hint,
      {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
              color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          enabled: !_isSaving,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white24),
            filled: true,
            fillColor: const Color(0xFF1A1D28),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}
