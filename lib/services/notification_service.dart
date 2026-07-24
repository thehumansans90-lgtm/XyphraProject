import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../widgets/desktop_toast_widget.dart';

class SystemNotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  /// Инициализация сервиса (вызываем в main.dart)
  static Future<void> init() async {
    if (kIsWeb) return;

    if (Platform.isAndroid || Platform.isIOS) {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings();

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      // В новых версиях используется именованный параметр settings:
      await _localNotifications.initialize(settings: initSettings);

      if (Platform.isAndroid) {
        final androidImplementation = _localNotifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        await androidImplementation?.requestNotificationsPermission();
      }
    }
  }

  /// Показ уведомления (мобилка -> верхняя шторка, ПК -> плашка сбоку)
  static Future<void> show({
    required BuildContext context,
    required String userName,
    required String message,
    required String avatarUrl,
  }) async {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      await _showMobileNotification(title: userName, body: message);
    } else {
      _showDesktopOverlay(
        context: context,
        userName: userName,
        message: message,
        avatarUrl: avatarUrl,
      );
    }
  }

  static Future<void> _showMobileNotification({
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'chat_messages_channel',
      'Сообщения чата',
      channelDescription: 'Уведомления о новых сообщениях',
      importance: Importance.max,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // В новых версиях методы принимают именованные аргументы:
    await _localNotifications.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      notificationDetails: notificationDetails,
    );
  }

  static void _showDesktopOverlay({
    required BuildContext context,
    required String userName,
    required String message,
    required String avatarUrl,
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => Positioned(
        top: 24,
        right: 24,
        child: DesktopToastWidget(
          userName: userName,
          message: message,
          avatarUrl: avatarUrl,
          onDismiss: () => entry.remove(),
        ),
      ),
    );

    overlay.insert(entry);
  }
}