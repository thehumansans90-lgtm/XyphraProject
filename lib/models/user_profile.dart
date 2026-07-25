import 'dart:convert';
import 'dart:typed_data';

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
  final String username;
  final String tag;
  final String displayName;
  final String bio;
  final String avatarUrl;
  final bool isOnline;
  final bool isAppActive;
  final UserStatus status;
  final Uint8List? avatarBytes;
  final String bannerColor;
  final String joinedDate;
  final List<String> badges;
  final DateTime? lastUsernameChange;
  final DateTime? lastSeen;

  const UserProfile({
    required this.id,
    required this.username,
    required this.tag,
    required this.displayName,
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
    String? username,
    String? displayName,
    String? bio,
    String? avatarUrl,
    bool? isOnline,
    bool? isAppActive,
    UserStatus? status,
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
      status: status ?? this.status,
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
        'status': status.toJson(),
        'avatarBytes': avatarBytes != null ? base64Encode(avatarBytes!) : null,
        'bannerColor': bannerColor,
        'joinedDate': joinedDate,
        'badges': badges,
        'lastUsernameChange': lastUsernameChange?.toUtc().toIso8601String(),
        'lastSeen': lastSeen?.toUtc().toIso8601String(),
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    // Вспомогательная функция для корректной конвертации даты в UTC
    DateTime? parseDateTimeUtc(dynamic rawDate) {
      if (rawDate == null) return null;

      if (rawDate is String) {
        final parsed = DateTime.tryParse(rawDate);
        return parsed?.toUtc();
      }

      if (rawDate is int) {
        // Защита от метки времени в секундах или миллисекундах
        if (rawDate < 10000000000) {
          return DateTime.fromMillisecondsSinceEpoch(rawDate * 1000, isUtc: true);
        }
        return DateTime.fromMillisecondsSinceEpoch(rawDate, isUtc: true);
      }

      return null;
    }

    return UserProfile(
      id: json['id'] as String? ?? '',
      username: json['username'] as String? ?? '',
      tag: json['tag'] as String? ?? '',
      displayName: (json['displayName'] ?? json['display_name']) as String? ?? '',
      bio: json['bio'] as String? ?? '',
      avatarUrl: (json['avatarUrl'] ?? json['avatar_url']) as String? ?? '',
      isOnline: (json['isOnline'] ?? json['is_online']) as bool? ?? false,
      isAppActive: (json['isAppActive'] ?? json['is_app_active']) as bool? ?? false,
      status: UserStatus.fromJson(json['status']),
      avatarBytes: json['avatarBytes'] != null
          ? base64Decode(json['avatarBytes'] as String)
          : null,
      bannerColor: (json['bannerColor'] ?? json['banner_color']) as String? ?? '',
      joinedDate: (json['joinedDate'] ?? json['joined_date']) as String? ?? '',
      badges: (json['badges'] as List?)?.map((e) => e.toString()).toList() ?? [],
      lastUsernameChange: parseDateTimeUtc(json['lastUsernameChange'] ?? json['last_username_change']),
      lastSeen: parseDateTimeUtc(json['lastSeen'] ?? json['last_seen']),
    );
  }
}