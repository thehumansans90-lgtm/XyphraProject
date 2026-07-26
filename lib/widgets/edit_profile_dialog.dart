import 'package:file_picker/file_picker.dart' as file_picker_lib;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import 'photo_cropper_dialog.dart';
import '../screens/user_avatar.dart';

class EditProfileDialog extends StatefulWidget {
  final UserProfile user;
  final VoidCallback onProfileUpdated;

  const EditProfileDialog({
    super.key,
    required this.user,
    required this.onProfileUpdated,
  });

  @override
  State<EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<EditProfileDialog> {
  late final TextEditingController _displayNameController;
  late final TextEditingController _usernameController;
  late final TextEditingController _bioController;
  Uint8List? _newAvatarBytes;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _displayNameController =
        TextEditingController(text: widget.user.displayName);
    _usernameController =
        TextEditingController(text: _getFullUsernameForEdit());
    _bioController = TextEditingController(text: widget.user.bio);
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  String _getFullUsernameForEdit() {
    if (widget.user.tag.isNotEmpty &&
        !widget.user.username.contains('#') &&
        !widget.user.username.contains('_')) {
      final cleanTag = widget.user.tag.startsWith('#')
          ? widget.user.tag
          : '#${widget.user.tag}';
      return '${widget.user.username}$cleanTag';
    }
    return widget.user.username;
  }

  bool _validateUsername(String username) {
    final digitCount = RegExp(r'\d').allMatches(username).length;
    if (digitCount < 1) {
      return false;
    }
    return RegExp(r'^[a-zA-Z0-9_#]+$').hasMatch(username);
  }

  Future<void> _pickNewAvatar() async {
    try {
      final result = await file_picker_lib.FilePicker.pickFiles(
        type: file_picker_lib.FileType.image,
        allowMultiple: false,
        withData: true,
      );

      if (result != null &&
          result.files.isNotEmpty &&
          result.files.first.bytes != null) {
        final Uint8List rawBytes = result.files.first.bytes!;

        if (!mounted) return;

        // Crop image dialog
        final dynamic croppedResult = await showDialog<dynamic>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => PhotoCropperDialog(imageBytes: rawBytes),
        );

        if (croppedResult != null && croppedResult is List<int>) {
          setState(() {
            _newAvatarBytes = Uint8List.fromList(croppedResult);
          });
        }
      }
    } catch (e) {
      debugPrint('Error picking avatar: $e');
    }
  }

  Future<void> _saveProfile() async {
    final newName = _displayNameController.text.trim();
    final rawUsername = _usernameController.text.trim().replaceAll('@', '');
    final newBio = _bioController.text.trim();

    if (rawUsername.isNotEmpty && !_validateUsername(rawUsername)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Username must contain letters, at least 1 digit, and may use "_" or "#"'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      if (newName.isNotEmpty) {
        widget.user.displayName = newName;
      }
      if (rawUsername.isNotEmpty) {
        widget.user.username = rawUsername;
      }
      widget.user.bio = newBio;

      if (_newAvatarBytes != null) {
        widget.user.avatarBytes = _newAvatarBytes;
      }

      await AuthService.saveUser(widget.user);
      widget.onProfileUpdated();

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error saving profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save profile: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Dynamically pass selected avatar bytes without modifying UserAvatar class parameters
    final displayUser = _newAvatarBytes != null
        ? widget.user.copyWith(avatarBytes: _newAvatarBytes)
        : widget.user;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 440,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF10121B).withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7C4DFF).withValues(alpha: 0.25),
              blurRadius: 35,
              spreadRadius: -5,
            )
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Edit Profile',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon:
                        const Icon(Icons.close_rounded, color: Colors.white54),
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Avatar with Camera Overlay
              GestureDetector(
                onTap: _isSaving ? null : _pickNewAvatar,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    UserAvatar(
                      user: displayUser,
                      radius: 46,
                    ),
                    Container(
                      width: 92,
                      height: 92,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Display Name
              TextField(
                controller: _displayNameController,
                enabled: !_isSaving,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Display Name',
                  labelStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: const Color(0xFF1A1D2A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Username
              TextField(
                controller: _usernameController,
                enabled: !_isSaving,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Username (@username)',
                  labelStyle: const TextStyle(color: Colors.white54),
                  hintText: 'e.g., user_123 or dev#4085',
                  hintStyle: const TextStyle(color: Colors.white24),
                  filled: true,
                  fillColor: const Color(0xFF1A1D2A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Bio
              TextField(
                controller: _bioController,
                enabled: !_isSaving,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'About Me / Bio',
                  labelStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: const Color(0xFF1A1D2A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C4DFF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _isSaving ? null : _saveProfile,
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Save Changes',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
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
}
