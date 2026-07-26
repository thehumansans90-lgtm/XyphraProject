import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../utils/badge_manager.dart';
import 'chat_sync_service.dart';

enum UserStatus { online, idle, offline }

class AuthService {
  static const String _currentUserKey = 'xyphra_current_user';
  static final SupabaseClient _supabase = Supabase.instance.client;
  static Timer? _heartbeatTimer;

  static void _applyBadges(UserProfile user) {
    final updatedList = BadgeManager.getBadgesForUser(
      userId: user.id.toString(),
      username: user.username,
      currentBadges: user.badges,
    );

    user.badges.clear();
    user.badges.addAll(updatedList);
  }

  /// Парсит дату last_seen в UTC
  static DateTime? _parseLastSeen(dynamic rawDate) {
    if (rawDate == null) return null;
    if (rawDate is String) {
      return DateTime.tryParse(rawDate)?.toUtc();
    }
    return null;
  }

  /// Запуск фонового пинга на сервер каждые 30 секунд
  static void startHeartbeatTimer(String userId) {
    _heartbeatTimer?.cancel();
    // Первый пинг сразу при запуске
    updatePresenceStatus(userId, isOnline: true);

    // Затем каждые 30 секунд
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      updatePresenceStatus(userId, isOnline: true);
    });
  }

  /// Остановка фонового пинга
  static void stopHeartbeatTimer() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  static Future<void> saveSession(UserProfile user) async {
    final prefs = await SharedPreferences.getInstance();

    user.isOnline = true;
    _applyBadges(user);

    if (user.avatarBytes != null && user.avatarBytes!.isNotEmpty) {
      final uploadedUrl =
          await _uploadAvatarToSupabase(user.id, user.avatarBytes!);
      if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
        user.avatarUrl = uploadedUrl;
      }
    }

    await prefs.setString(_currentUserKey, jsonEncode(user.toJson()));

    try {
      final Map<String, dynamic> updateData = {
        'id': user.id,
        'username': user.username,
        'tag': user.tag,
        'display_name': user.displayName,
        'bio': user.bio,
        'banner_color': user.bannerColor,
        'is_online': true,
        'last_seen': DateTime.now().toUtc().toIso8601String(),
        'badges': List<String>.from(user.badges),
      };

      if (user.avatarUrl.isNotEmpty) {
        updateData['avatar_url'] = user.avatarUrl;
      }

      await _supabase.from('profiles').upsert(
            updateData,
            onConflict: 'id',
          );

      // Запускаем постоянный пинг в сеть
      startHeartbeatTimer(user.id);
      debugPrint('✅ Профиль успешно синхронизирован с Supabase!');
    } catch (e) {
      debugPrint('❌ Ошибка отправки в Supabase profiles: $e');
    }
  }

  static Future<void> updatePresenceStatus(String userId,
      {required bool isOnline, bool isIdle = false}) async {
    try {
      await _supabase.from('profiles').update({
        'is_online': isOnline,
        'last_seen': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', userId);

      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_currentUserKey);
      if (data != null && data.isNotEmpty) {
        final localUser = UserProfile.fromJson(jsonDecode(data));
        localUser.isOnline = isOnline;
        await prefs.setString(_currentUserKey, jsonEncode(localUser.toJson()));
      }
    } catch (e) {
      debugPrint('Ошибка обновления статуса: $e');
    }
  }

  static Future<String?> _uploadAvatarToSupabase(
      String userId, Uint8List imageBytes) async {
    try {
      final fileName = '$userId/avatar.png';

      await _supabase.storage.from('avatars').uploadBinary(
            fileName,
            imageBytes,
            fileOptions: const FileOptions(
              contentType: 'image/png',
              upsert: true,
            ),
          );

      final publicUrl =
          _supabase.storage.from('avatars').getPublicUrl(fileName);
      return '$publicUrl?v=${DateTime.now().millisecondsSinceEpoch}';
    } catch (e) {
      debugPrint('❌ Ошибка загрузки аватарки в Storage: $e');
      return null;
    }
  }

  static Future<void> saveUser(UserProfile user) async {
    await saveSession(user);
  }

  static Future<UserProfile?> getCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_currentUserKey);
      if (data == null || data.isEmpty) return null;

      final localUser = UserProfile.fromJson(jsonDecode(data));

      try {
        final serverProfile = await _supabase
            .from('profiles')
            .select()
            .eq('id', localUser.id)
            .maybeSingle();

        if (serverProfile != null) {
          localUser.displayName =
              serverProfile['display_name'] ?? localUser.displayName;
          localUser.username = serverProfile['username'] ?? localUser.username;
          localUser.bio = serverProfile['bio'] ?? localUser.bio;
          localUser.avatarUrl =
              serverProfile['avatar_url'] ?? localUser.avatarUrl;
          localUser.bannerColor =
              serverProfile['banner_color'] ?? localUser.bannerColor;
          localUser.isOnline = true;
          localUser.lastSeen = _parseLastSeen(serverProfile['last_seen']);

          if (serverProfile['badges'] != null) {
            localUser.badges.clear();
            localUser.badges.addAll(List<String>.from(serverProfile['badges']));
          }

          _applyBadges(localUser);

          await prefs.setString(
              _currentUserKey, jsonEncode(localUser.toJson()));
        }
      } catch (_) {}

      // Запускаем таймер постоянного обновления
      startHeartbeatTimer(localUser.id);

      return localUser;
    } catch (e) {
      await logout();
      return null;
    }
  }

  /// Получение профилей по списку ID
  static Stream<List<UserProfile>> streamProfilesByIds(List<String> userIds) {
    if (userIds.isEmpty) {
      return Stream.value([]);
    }

    return _supabase.from('profiles').stream(primaryKey: ['id']).map((list) {
      return list
          .where((json) => userIds.contains(json['id']?.toString()))
          .map((json) {
        final badgesList = json['badges'] != null
            ? List<String>.from(json['badges'])
            : <String>[];
        final user = UserProfile(
          id: json['id'] ?? '',
          username: json['username'] ?? '',
          tag: json['tag'] ?? '',
          displayName: json['display_name'] ?? '',
          bio: json['bio'] ?? '',
          avatarUrl: json['avatar_url'] ?? '',
          bannerColor: json['banner_color'] ?? '0xFF9C27B0',
          joinedDate: json['joined_date'] ?? json['joinedDate'] ?? '',
          badges: badgesList,
          isOnline: json['is_online'] ?? false,
          lastSeen: _parseLastSeen(json['last_seen']), // FIXED
        );

        _applyBadges(user);

        return user;
      }).toList();
    });
  }

  static Stream<List<UserProfile>> streamAllProfiles() {
    return _supabase.from('profiles').stream(primaryKey: ['id']).map((list) {
      return list.map((json) {
        final badgesList = json['badges'] != null
            ? List<String>.from(json['badges'])
            : <String>[];
        final user = UserProfile(
          id: json['id'] ?? '',
          username: json['username'] ?? '',
          tag: json['tag'] ?? '',
          displayName: json['display_name'] ?? '',
          bio: json['bio'] ?? '',
          avatarUrl: json['avatar_url'] ?? '',
          bannerColor: json['banner_color'] ?? '0xFF9C27B0',
          joinedDate: json['joined_date'] ?? json['joinedDate'] ?? '',
          badges: badgesList,
          isOnline: json['is_online'] ?? false,
          lastSeen: _parseLastSeen(json['last_seen']), // FIXED
        );

        _applyBadges(user);

        return user;
      }).toList();
    });
  }

  /// Очистка состояния и выключение таймера
  static Future<void> logout() async {
    stopHeartbeatTimer();
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_currentUserKey);
    if (data != null && data.isNotEmpty) {
      try {
        final localUser = UserProfile.fromJson(jsonDecode(data));
        await updatePresenceStatus(localUser.id, isOnline: false);
        await ChatSyncService().clearCache(localUser.id);
      } catch (_) {}
    }
    await prefs.remove(_currentUserKey);
  }

  static Future<List<UserProfile>> searchUsers(String query) async {
    try {
      final cleanQuery = query.trim();

      dynamic response;
      if (cleanQuery.isEmpty) {
        response = await _supabase.from('profiles').select().limit(50);
      } else {
        response = await _supabase
            .from('profiles')
            .select()
            .or('username.ilike.%$cleanQuery%,display_name.ilike.%$cleanQuery%')
            .limit(20);
      }

      return (response as List).map((json) {
        final badgesList = json['badges'] != null
            ? List<String>.from(json['badges'])
            : <String>[];
        final user = UserProfile(
          id: json['id'] ?? '',
          username: json['username'] ?? '',
          tag: json['tag'] ?? '',
          displayName: json['display_name'] ?? '',
          bio: json['bio'] ?? '',
          avatarUrl: json['avatar_url'] ?? '',
          bannerColor: json['banner_color'] ?? '0xFF9C27B0',
          joinedDate: json['joined_date'] ?? json['joinedDate'] ?? '',
          badges: badgesList,
          isOnline: json['is_online'] ?? false,
          lastSeen: _parseLastSeen(json['last_seen']), // FIXED
        );

        _applyBadges(user);

        return user;
      }).toList();
    } catch (e) {
      debugPrint('Ошибка при поиске пользователей: $e');
      return [];
    }
  }

  static Future<bool> isUsernameTaken(String username) async {
    try {
      if (username.trim().isEmpty) return false;
      final response = await _supabase
          .from('profiles')
          .select('id')
          .ilike('username', username.trim())
          .maybeSingle();
      return response != null;
    } catch (e) {
      return false;
    }
  }

  static Future<UserProfile?> findUserByUsername(String username) async {
    try {
      if (username.trim().isEmpty) return null;
      final response = await _supabase
          .from('profiles')
          .select()
          .ilike('username', username.trim())
          .maybeSingle();

      if (response == null) return null;

      final badgesList = response['badges'] != null
          ? List<String>.from(response['badges'])
          : <String>[];
      final user = UserProfile(
        id: response['id'] ?? '',
        username: response['username'] ?? '',
        tag: response['tag'] ?? '',
        displayName: response['display_name'] ?? '',
        bio: response['bio'] ?? '',
        avatarUrl: response['avatar_url'] ?? '',
        bannerColor:
            response['banner_color'] ?? response['bannerColor'] ?? '0xFF9C27B0',
        joinedDate: response['joined_date'] ?? response['joinedDate'] ?? '',
        badges: badgesList,
        isOnline: response['is_online'] ?? false,
        lastSeen: _parseLastSeen(response['last_seen']), // FIXED
      );

      _applyBadges(user);

      return user;
    } catch (e) {
      debugPrint('Ошибка поиска пользователя: $e');
      return null;
    }
  }

  static Future<void> toggleTesterBadge(String userId, bool isTester) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('badges')
          .eq('id', userId)
          .single();
      List<String> currentBadges = List<String>.from(response['badges'] ?? []);

      if (isTester && !currentBadges.contains('TESTER')) {
        currentBadges.add('TESTER');
      } else if (!isTester) {
        currentBadges.remove('TESTER');
      }

      await _supabase.from('profiles').update(
          {'badges': List<String>.from(currentBadges)}).eq('id', userId);
      debugPrint('Статус тестера обновлен для $userId: $isTester');
    } catch (e) {
      debugPrint('Ошибка при изменении бейджа тестера: $e');
    }
  }
}
