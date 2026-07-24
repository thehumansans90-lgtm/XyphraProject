import 'dart:convert';
import 'dart:typed_data';

/// Перечисление статусов сети пользователя
enum UserStatus {
  online,
  idle,
  offline,
}

class UserProfile {
  final String id;
  String username;
  final String tag;
  String displayName;
  String bio;
  String avatarUrl;
  bool isOnline;
  bool isAppActive;
  Uint8List? avatarBytes;
  String bannerColor;
  final String joinedDate;
  final List<String> badges;
  DateTime? lastUsernameChange;
  DateTime? lastSeen;

  UserProfile({
    required this.id,
    required this.username,
    required this.tag,
    required this.displayName,
    required this.bio,
    required this.avatarUrl,
    this.avatarBytes,
    this.isOnline = false,
    this.isAppActive = false,
    required this.bannerColor,
    required this.joinedDate,
    required this.badges,
    this.lastUsernameChange,
    this.lastSeen,
  });

  UserProfile copyWith({
    String? username,
    String? displayName,
    String? bio,
    String? avatarUrl,
    bool? isOnline,
    bool? isAppActive,
    Uint8List? avatarBytes,
    String? bannerColor,
    List<String>? badges,
    DateTime? lastUsernameChange,
    DateTime? lastSeen,
  }) {
    return UserProfile(
      id: id,
      username: username ?? this.username,
      tag: tag,
      displayName: displayName ?? this.displayName,
      bio: bio ?? this.bio,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isOnline: isOnline ?? this.isOnline,
      isAppActive: isAppActive ?? this.isAppActive,
      avatarBytes: avatarBytes ?? this.avatarBytes,
      bannerColor: bannerColor ?? this.bannerColor,
      joinedDate: joinedDate,
      badges: badges ?? this.badges,
      lastUsernameChange: lastUsernameChange ?? this.lastUsernameChange,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'tag': tag,
        'displayName': displayName,
        'bio': bio,
        'avatarUrl': avatarUrl,
        'isOnline': isOnline,
        'isAppActive': isAppActive,
        'avatarBytes': avatarBytes != null ? base64Encode(avatarBytes!) : null,
        'bannerColor': bannerColor,
        'joinedDate': joinedDate,
        'badges': badges,
        'lastUsernameChange': lastUsernameChange?.toIso8601String(),
        'lastSeen': lastSeen?.toIso8601String(),
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'] ?? '',
        username: json['username'] ?? '',
        tag: json['tag'] ?? '',
        displayName: json['displayName'] ?? json['display_name'] ?? '',
        bio: json['bio'] ?? '',
        avatarUrl: json['avatarUrl'] ?? json['avatar_url'] ?? '',
        isOnline: json['isOnline'] ?? json['is_online'] ?? false,
        isAppActive: json['isAppActive'] ?? json['is_app_active'] ?? false,
        avatarBytes: json['avatarBytes'] != null
            ? base64Decode(json['avatarBytes'])
            : null,
        bannerColor: json['bannerColor'] ?? json['banner_color'] ?? '',
        joinedDate: json['joinedDate'] ?? json['joined_date'] ?? '',
        badges: List<String>.from(json['badges'] ?? []),
        lastUsernameChange: json['lastUsernameChange'] != null
            ? DateTime.tryParse(json['lastUsernameChange'])
            : null,
        lastSeen: json['lastSeen'] != null || json['last_seen'] != null
            ? DateTime.tryParse(json['lastSeen'] ?? json['last_seen'] ?? '')
            : null,
      );
}

class ChatMessage {
  final String id;
  final String senderId;
  String text;
  final DateTime timestamp;
  bool isEdited;

  // Поля для работы с медиа
  final bool isVideo;
  bool isUploading;
  final List<Uint8List>? mediaListBytes;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.timestamp,
    this.isEdited = false,
    this.isVideo = false,
    this.isUploading = false,
    List<Uint8List>? mediaListBytes,
    Uint8List? mediaBytes,
  }) : mediaListBytes =
            mediaListBytes ?? (mediaBytes != null ? [mediaBytes] : null);

  // Геттер для обратной совместимости, если где-то нужен 1-й файл
  Uint8List? get mediaBytes =>
      (mediaListBytes != null && mediaListBytes!.isNotEmpty)
          ? mediaListBytes!.first
          : null;

  ChatMessage copyWith({
    String? text,
    bool? isEdited,
    List<Uint8List>? mediaListBytes,
    bool? isVideo,
    bool? isUploading,
  }) {
    return ChatMessage(
      id: id,
      senderId: senderId,
      text: text ?? this.text,
      timestamp: timestamp,
      isEdited: isEdited ?? this.isEdited,
      mediaListBytes: mediaListBytes ?? this.mediaListBytes,
      isVideo: isVideo ?? this.isVideo,
      isUploading: isUploading ?? this.isUploading,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'senderId': senderId,
        'text': text,
        'timestamp': timestamp.toIso8601String(),
        'isEdited': isEdited,
        'isVideo': isVideo,
        'isUploading': isUploading,
        'mediaListBytes':
            mediaListBytes?.map((bytes) => base64Encode(bytes)).toList(),
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    List<Uint8List>? parsedMedia;

    if (json['mediaListBytes'] != null) {
      parsedMedia = (json['mediaListBytes'] as List)
          .map((item) => base64Decode(item as String))
          .toList();
    } else if (json['mediaBytes'] != null) {
      parsedMedia = [base64Decode(json['mediaBytes'])];
    }

    return ChatMessage(
      id: json['id'] ?? '',
      senderId: json['senderId'] ?? json['sender_id'] ?? '',
      text: json['text'] ?? '',
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
      isEdited: json['isEdited'] ?? json['is_edited'] ?? false,
      isVideo: json['isVideo'] ?? json['is_video'] ?? false,
      isUploading: json['isUploading'] ?? false,
      mediaListBytes: parsedMedia,
    );
  }
}