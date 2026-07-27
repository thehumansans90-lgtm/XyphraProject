import 'dart:convert';
import 'dart:typed_data';

/// Перечисление статусов сети пользователя
enum UserStatus {
  online,
  idle,
  offline;

  String toJson() => name;

  factory UserStatus.fromJson(dynamic value) {
    if (value is String) {
      return UserStatus.values.firstWhere(
        (e) => e.name == value.toLowerCase(),
        orElse: () => UserStatus.offline,
      );
    }
    return UserStatus.offline;
  }
}

class UserProfile {
  final String id;
  String username;
  final String tag;
  String displayName;
  String email; // 👈 ДОБАВЛЕНО
  String bio;
  String avatarUrl;
  bool isOnline;
  bool isAppActive;
  UserStatus status;
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
    this.email = '', // 👈 ДОБАВЛЕНО
    required this.bio,
    required this.avatarUrl,
    this.avatarBytes,
    this.isOnline = false,
    this.isAppActive = false,
    this.status = UserStatus.offline,
    required this.bannerColor,
    required this.joinedDate,
    required this.badges,
    this.lastUsernameChange,
    this.lastSeen,
  });

  UserProfile copyWith({
    String? id,
    String? username,
    String? tag,
    String? displayName,
    String? email,
    String? bio,
    String? avatarUrl,
    bool? isOnline,
    bool? isAppActive,
    UserStatus? status,
    Uint8List? avatarBytes,
    String? bannerColor,
    String? joinedDate, // 👈 Добавлен опциональный параметр
    List<String>? badges,
    DateTime? lastUsernameChange,
    DateTime? lastSeen,
  }) {
    return UserProfile(
      id: id ?? this.id,
      username: username ?? this.username,
      tag: tag ?? this.tag,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      bio: bio ?? this.bio,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isOnline: isOnline ?? this.isOnline,
      isAppActive: isAppActive ?? this.isAppActive,
      status: status ?? this.status,
      avatarBytes: avatarBytes ?? this.avatarBytes,
      bannerColor: bannerColor ?? this.bannerColor,
      joinedDate: joinedDate ?? this.joinedDate,
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
        'email': email, // 👈 ДОБАВЛЕНО
        'bio': bio,
        'avatarUrl': avatarUrl,
        'isOnline': isOnline,
        'isAppActive': isAppActive,
        'status': status.toJson(),
        'avatarBytes': avatarBytes != null ? base64Encode(avatarBytes!) : null,
        'bannerColor': bannerColor,
        'joinedDate': joinedDate,
        'badges': badges,
        'lastUsernameChange': lastUsernameChange?.toIso8601String(),
        'lastSeen': lastSeen?.toIso8601String(),
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      tag: json['tag']?.toString() ?? '',
      displayName:
          (json['displayName'] ?? json['display_name'])?.toString() ?? '',
      email: (json['email'] ?? json['email_address'])?.toString() ??
          '', // 👈 ДОБАВЛЕНО
      bio: json['bio']?.toString() ?? '',
      avatarUrl: (json['avatarUrl'] ?? json['avatar_url'])?.toString() ?? '',
      isOnline: (json['isOnline'] ?? json['is_online']) as bool? ?? false,
      isAppActive:
          (json['isAppActive'] ?? json['is_app_active']) as bool? ?? false,
      status: UserStatus.fromJson(json['status']),
      avatarBytes: json['avatarBytes'] != null
          ? base64Decode(json['avatarBytes'] as String)
          : null,
      bannerColor:
          (json['bannerColor'] ?? json['banner_color'])?.toString() ?? '',
      joinedDate: (json['joinedDate'] ?? json['joined_date'])?.toString() ?? '',
      badges:
          (json['badges'] as List?)?.map((e) => e.toString()).toList() ?? [],
      lastUsernameChange: json['lastUsernameChange'] != null
          ? DateTime.tryParse(json['lastUsernameChange'].toString())
          : null,
      lastSeen: (json['lastSeen'] ?? json['last_seen']) != null
          ? DateTime.tryParse(
              (json['lastSeen'] ?? json['last_seen']).toString())
          : null,
    );
  }
}

class ChatMessage {
  final String id;
  final String senderId;
  String text;
  final DateTime timestamp;
  bool isEdited;
  bool isRead;

  // Поля для работы с медиа
  final bool isVideo;
  bool isUploading;
  final String? mediaUrl;
  final List<Uint8List>? mediaListBytes;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.timestamp,
    this.isEdited = false,
    this.isRead = false,
    this.isVideo = false,
    this.isUploading = false,
    this.mediaUrl,
    List<Uint8List>? mediaListBytes,
    Uint8List? mediaBytes,
  }) : mediaListBytes =
            mediaListBytes ?? (mediaBytes != null ? [mediaBytes] : null);

  Uint8List? get mediaBytes =>
      (mediaListBytes != null && mediaListBytes!.isNotEmpty)
          ? mediaListBytes!.first
          : null;

  ChatMessage copyWith({
    String? text,
    bool? isEdited,
    bool? isRead,
    String? mediaUrl,
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
      isRead: isRead ?? this.isRead,
      mediaUrl: mediaUrl ?? this.mediaUrl,
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
        'isRead': isRead,
        'isVideo': isVideo,
        'isUploading': isUploading,
        'mediaUrl': mediaUrl,
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
      parsedMedia = [base64Decode(json['mediaBytes'] as String)];
    }

    return ChatMessage(
      id: json['id']?.toString() ?? '',
      senderId: (json['senderId'] ?? json['sender_id'])?.toString() ?? '',
      text: (json['text'] ?? json['content'])?.toString() ?? '',
      timestamp: DateTime.tryParse(
              (json['timestamp'] ?? json['created_at'])?.toString() ?? '') ??
          DateTime.now(),
      isEdited: (json['isEdited'] ?? json['is_edited']) as bool? ?? false,
      isRead: (json['isRead'] ?? json['is_read']) as bool? ?? false,
      isVideo: (json['isVideo'] ?? json['is_video']) as bool? ?? false,
      isUploading: json['isUploading'] as bool? ?? false,
      mediaUrl: (json['mediaUrl'] ?? json['media_url'])?.toString(),
      mediaListBytes: parsedMedia,
    );
  }
}
