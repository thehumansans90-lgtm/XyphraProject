import 'package:flutter/material.dart';
import '../models/user_model.dart';

/// Статусы присутствия пользователя
enum UserOnlineState {
  online,   // В сети (зеленая точка)
  away,     // Неактивен / Недавно был (желтая точка)
  offline,  // Не в сети (серая точка)
  bot,      // Бот или Системный аккаунт (всегда онлайн)
}

/// Отдельный виджет индикатора активности (Точка статуса)
class StatusIndicator extends StatelessWidget {
  final UserProfile user;
  final bool isConnected;
  final double size;
  final bool enableAnimation;

  const StatusIndicator({
    super.key,
    required this.user,
    this.isConnected = true,
    this.size = 10.0,
    this.enableAnimation = true,
  });

  /// Вычисление текущего статуса на основе данных профиля
  UserOnlineState get currentState {
    // 1. Проверка на ботов/системные аккаунты
    if (user.badges.contains('BOT') || user.badges.contains('SAVED')) {
      return UserOnlineState.bot;
    }

    // 2. Если нет соединения с сервером или флаг isOnline явный false
    if (!isConnected || !user.isOnline) {
      return UserOnlineState.offline;
    }

    // 3. Проверка по lastSeen с приведением к UTC (избегаем ошибок часовых поясов)
    if (user.lastSeen != null) {
      final lastSeenUtc = user.lastSeen!.toUtc();
      final nowUtc = DateTime.now().toUtc();
      final difference = nowUtc.difference(lastSeenUtc).inSeconds;

      // Если разница больше 2 минут, переводим в "Неактивен" или "Оффлайн"
      if (difference > 120) {
        return UserOnlineState.away;
      }
    }

    return UserOnlineState.online;
  }

  /// Получение цвета точки
  Color _getStatusColor(UserOnlineState state) {
    switch (state) {
      case UserOnlineState.online:
      case UserOnlineState.bot:
        return const Color(0xFF00E676); // Ярко-зеленый
      case UserOnlineState.away:
        return const Color(0xFFFFB300); // Желтый / Неактивен
      case UserOnlineState.offline:
        return const Color(0xFF5C6170); // Серый / Офлайн
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = currentState;
    final color = _getStatusColor(state);

    if (state == UserOnlineState.online && enableAnimation) {
      return _PulsingStatusDot(color: color, size: size);
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF13151E), width: 2),
      ),
    );
  }
}

/// Анимированная (пульсирующая) точка для статуса "В сети"
class _PulsingStatusDot extends StatefulWidget {
  final Color color;
  final double size;

  const _PulsingStatusDot({
    required this.color,
    required this.size,
  });

  @override
  State<_PulsingStatusDot> createState() => _PulsingStatusDotState();
}

class _PulsingStatusDotState extends State<_PulsingStatusDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 1.5, end: 4.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF13151E), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.4),
                blurRadius: _animation.value,
                spreadRadius: _animation.value / 3,
              ),
            ],
          ),
        );
      },
    );
  }
}