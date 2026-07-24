import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';

class ChatSyncService {
  static const String _messagesCacheKey = 'xyphra_chat_messages_cache';
  final SupabaseClient _supabase = Supabase.instance.client;

  /// 1. Подписка на ВСЕ сообщения для фонового получения уведомлений и счетчиков
  StreamSubscription<List<ChatMessage>> subscribeToAllIncomingMessages(
    String currentUserId,
    void Function(List<ChatMessage>) onData,
  ) {
    return _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: true)
        .map((data) {
          final userMessages = data.where((msg) {
            final sender = msg['sender_id']?.toString();
            final receiver = msg['receiver_id']?.toString();
            return sender == currentUserId || receiver == currentUserId;
          }).toList();

          final messages = userMessages.map((json) {
            return ChatMessage(
              id: json['id'].toString(),
              senderId: json['sender_id']?.toString() ?? '',
              text: json['text'] ?? json['content'] ?? '',
              timestamp: DateTime.parse(json['created_at']).toUtc(),
              isVideo: json['is_video'] ?? false,
              isEdited: json['is_edited'] ?? false,
              isRead: json['is_read'] ?? false,
            );
          }).toList();

          messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
          return messages;
        })
        .listen(onData);
  }

  /// 2. Подписка на сообщения конкретного диалога
  Stream<List<ChatMessage>> subscribeToChatMessages({
    required String currentUserId,
    required String targetUserId,
  }) {
    return _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: true)
        .map((data) {
          final isSavedMessages = currentUserId == targetUserId;

          final filtered = data.where((msg) {
            final sender = msg['sender_id']?.toString();
            final receiver = msg['receiver_id']?.toString();

            if (isSavedMessages) {
              return sender == currentUserId && receiver == currentUserId;
            }

            return (sender == currentUserId && receiver == targetUserId) ||
                (sender == targetUserId && receiver == currentUserId);
          }).toList();

          final messages = filtered.map((json) {
            return ChatMessage(
              id: json['id'].toString(),
              senderId: json['sender_id']?.toString() ?? '',
              text: json['text'] ?? json['content'] ?? '',
              timestamp: DateTime.parse(json['created_at']).toUtc(),
              isVideo: json['is_video'] ?? false,
              isEdited: json['is_edited'] ?? false,
              isRead: json['is_read'] ?? false,
            );
          }).toList();

          messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
          return messages;
        });
  }

  /// Удобный алиас для подписки
  StreamSubscription<List<ChatMessage>> subscribeToChat({
    required String currentUserId,
    required String targetUserId,
    required void Function(List<ChatMessage>) onData,
  }) {
    return subscribeToChatMessages(
      currentUserId: currentUserId,
      targetUserId: targetUserId,
    ).listen(onData);
  }

  /// 3. Пометить сообщения от собеседника как прочитанные
  Future<void> markMessagesAsRead({
    required String currentUserId,
    required String targetUserId,
  }) async {
    try {
      await _supabase
          .from('messages')
          .update({'is_read': true})
          .eq('sender_id', targetUserId)
          .eq('receiver_id', currentUserId)
          .eq('is_read', false);
    } catch (e) {
      debugPrint('Ошибка обновления статуса прочтения: $e');
    }
  }

  /// 4. Подписка на количество непрочитанных сообщений от конкретного пользователя
  Stream<int> streamUnreadCount({
    required String currentUserId,
    required String targetUserId,
  }) {
    return _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .map((data) {
          return data.where((msg) {
            final sender = msg['sender_id']?.toString();
            final receiver = msg['receiver_id']?.toString();
            final isRead = msg['is_read'] ?? false;
            return sender == targetUserId && receiver == currentUserId && !isRead;
          }).length;
        });
  }

  /// 5. Получение ID пользователей, с которыми есть активные переписки
  Future<Set<String>> fetchActiveChatUserIds(String currentUserId) async {
    try {
      final response = await _supabase
          .from('messages')
          .select('sender_id, receiver_id')
          .or('sender_id.eq.$currentUserId,receiver_id.eq.$currentUserId');

      final Set<String> activeIds = {};
      for (var row in response as List) {
        final s = row['sender_id']?.toString();
        final r = row['receiver_id']?.toString();
        if (s != null && s != currentUserId) activeIds.add(s);
        if (r != null && r != currentUserId) activeIds.add(r);
      }
      return activeIds;
    } catch (e) {
      debugPrint('Ошибка загрузки активных диалогов: $e');
      return {};
    }
  }

  /// 6. Универсальный метод отправки сообщения
  Future<ChatMessage?> sendMessage({
    required String senderId,
    required String targetUserId,
    required String content,
    Uint8List? mediaBytes,
    bool isVideo = false,
  }) async {
    return sendMessageToServer(
      senderId: senderId,
      receiverId: targetUserId,
      text: content,
      mediaBytes: mediaBytes,
      isVideo: isVideo,
    );
  }

  /// 7. Отправка сообщения на сервер Supabase с загрузкой медиафайла
  Future<ChatMessage?> sendMessageToServer({
    required String senderId,
    required String receiverId,
    required String text,
    Uint8List? mediaBytes,
    bool isVideo = false,
  }) async {
    try {
      String? mediaUrl;

      if (mediaBytes != null && mediaBytes.isNotEmpty) {
        final ext = isVideo ? 'mp4' : 'png';
        final fileName = '${senderId}_${DateTime.now().millisecondsSinceEpoch}.$ext';

        await _supabase.storage.from('chat_media').uploadBinary(
              fileName,
              mediaBytes,
              fileOptions: FileOptions(
                contentType: isVideo ? 'video/mp4' : 'image/png',
                upsert: true,
              ),
            );

        mediaUrl = _supabase.storage.from('chat_media').getPublicUrl(fileName);
      }

      final nowUtc = DateTime.now().toUtc();

      final response = await _supabase
          .from('messages')
          .insert({
            'sender_id': senderId,
            'receiver_id': receiverId,
            'text': text,
            'content': text,
            'media_url': mediaUrl,
            'is_video': isVideo,
            'is_edited': false,
            'is_read': false,
            'created_at': nowUtc.toIso8601String(),
          })
          .select()
          .single();

      final createdMessage = ChatMessage(
        id: response['id'].toString(),
        senderId: response['sender_id'],
        text: response['text'] ?? response['content'] ?? '',
        timestamp: DateTime.parse(response['created_at']).toUtc(),
        mediaBytes: mediaBytes,
        isVideo: response['is_video'] ?? isVideo,
        isEdited: response['is_edited'] ?? false,
        isRead: false,
      );

      await _appendMessageToCache(chatId: receiverId, message: createdMessage);

      return createdMessage;
    } catch (e) {
      debugPrint('Ошибка отправки сообщения на сервер: $e');
      return null;
    }
  }

  /// 8. Удаление сообщения из Supabase и локального кэша
  Future<bool> deleteMessage({
    required String messageId,
    required String currentUserId,
    required String targetUserId,
  }) async {
    try {
      if (messageId.startsWith('temp_')) {
        await removeMessageFromCache(chatId: targetUserId, messageId: messageId);
        return true;
      }

      final msgResponse = await _supabase
          .from('messages')
          .select('media_url')
          .eq('id', messageId)
          .maybeSingle();

      if (msgResponse != null && msgResponse['media_url'] != null) {
        final String mediaUrl = msgResponse['media_url'];
        final uri = Uri.tryParse(mediaUrl);
        if (uri != null && uri.pathSegments.isNotEmpty) {
          final fileName = uri.pathSegments.last;
          await _supabase.storage.from('chat_media').remove([fileName]);
        }
      }

      await _supabase
          .from('messages')
          .delete()
          .eq('id', messageId)
          .eq('sender_id', currentUserId);

      await removeMessageFromCache(chatId: targetUserId, messageId: messageId);
      return true;
    } catch (e) {
      debugPrint('Ошибка при удалении сообщения: $e');
      await removeMessageFromCache(chatId: targetUserId, messageId: messageId);
      return false;
    }
  }

  /// 9. Редактирование сообщения в Supabase и обновление кэша
  Future<bool> updateMessage({
    required String messageId,
    required String currentUserId,
    required String targetUserId,
    required String newText,
  }) async {
    try {
      if (messageId.startsWith('temp_')) return false;

      await _supabase
          .from('messages')
          .update({
            'text': newText,
            'content': newText,
            'is_edited': true,
          })
          .eq('id', messageId)
          .eq('sender_id', currentUserId);

      await _updateMessageInCache(
        chatId: targetUserId,
        messageId: messageId,
        newText: newText,
      );

      return true;
    } catch (e) {
      debugPrint('Ошибка при редактировании сообщения: $e');
      return false;
    }
  }

  /// 10. Стрим статуса пользователя (Online / Idle / Offline)
  Stream<UserStatus> subscribeToUserDetailedStatus(String userId) {
    return _supabase
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .map((data) {
          if (data.isEmpty) return UserStatus.offline;

          final profile = data.first;
          final bool isOnline = profile['is_online'] ?? false;
          final String? lastSeenRaw = profile['last_seen'];

          if (!isOnline) return UserStatus.offline;

          if (lastSeenRaw != null) {
            final lastSeen = DateTime.parse(lastSeenRaw).toUtc();
            final difference = DateTime.now().toUtc().difference(lastSeen);

            if (difference.inMinutes >= 2) {
              return UserStatus.idle;
            }
          }

          return UserStatus.online;
        });
  }

  /// 11. Локальный кэш
  Future<void> saveChatHistory(Map<String, List<ChatMessage>> history) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final Map<String, dynamic> rawMap = {};

      history.forEach((chatId, messages) {
        rawMap[chatId] = messages.map((m) => m.toJson()).toList();
      });

      await prefs.setString(_messagesCacheKey, jsonEncode(rawMap));
    } catch (e) {
      debugPrint('Ошибка сохранения кэша: $e');
    }
  }

  Future<Map<String, List<ChatMessage>>> loadChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawData = prefs.getString(_messagesCacheKey);
      if (rawData == null || rawData.isEmpty) return {};

      final Map<String, dynamic> decoded = jsonDecode(rawData);
      final Map<String, List<ChatMessage>> result = {};

      decoded.forEach((chatId, messagesRaw) {
        if (messagesRaw is List) {
          final list = messagesRaw
              .map((item) => ChatMessage.fromJson(Map<String, dynamic>.from(item)))
              .toList();

          list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
          result[chatId] = list;
        }
      });

      return result;
    } catch (e) {
      debugPrint('Ошибка загрузки кэша: $e');
      return {};
    }
  }

  Future<void> _appendMessageToCache({
    required String chatId,
    required ChatMessage message,
  }) async {
    try {
      final history = await loadChatHistory();
      final chatList = history[chatId] ?? [];

      if (!chatList.any((m) => m.id == message.id)) {
        chatList.add(message);
        history[chatId] = chatList;
        await saveChatHistory(history);
      }
    } catch (e) {
      debugPrint('Ошибка добавления сообщения в кэш: $e');
    }
  }

  Future<void> _updateMessageInCache({
    required String chatId,
    required String messageId,
    required String newText,
  }) async {
    try {
      final history = await loadChatHistory();
      if (history.containsKey(chatId)) {
        final list = history[chatId]!;
        final index = list.indexWhere((m) => m.id == messageId);
        if (index != -1) {
          final oldMsg = list[index];
          list[index] = ChatMessage(
            id: oldMsg.id,
            senderId: oldMsg.senderId,
            text: newText,
            timestamp: oldMsg.timestamp,
            mediaBytes: oldMsg.mediaBytes,
            isVideo: oldMsg.isVideo,
            isEdited: true,
            isRead: oldMsg.isRead,
          );
          await saveChatHistory(history);
        }
      }
    } catch (e) {
      debugPrint('Ошибка обновления сообщения в кэше: $e');
    }
  }

  Future<void> removeMessageFromCache({
    required String chatId,
    required String messageId,
  }) async {
    try {
      final history = await loadChatHistory();
      if (history.containsKey(chatId)) {
        history[chatId]!.removeWhere((m) => m.id == messageId);
        await saveChatHistory(history);
      }
    } catch (e) {
      debugPrint('Ошибка удаления сообщения из кэша: $e');
    }
  }

  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_messagesCacheKey);
  }
}