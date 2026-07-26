import 'package:flutter/material.dart';
import '../models/user_model.dart';

/// Статусы присутствия пользователя
enum UserOnlineState {
  online, // В сети (зеленая точка)
  away, // Неактивен (желтая точка)
  offline, // Не в сети (серая точка)
  bot, // Бот / Системный аккаунт (всегда онлайн)
}

/// Анимированный индикатор активности
class StatusIndicator extends StatefulWidget {
  final UserProfile user;
  final bool isConnected;
  final double size;
  final bool enableAnimation;

  const StatusIndicator({
    super.key,
    required this.user,
    this.isConnected = true,
    this.size = 12.0,
    this.enableAnimation = true,
  });

  /// 🎯 ЕДИНЫЙ ИСТОЧНИК ПРАВДЫ ДЛЯ ВСЕГО ПРИЛОЖЕНИЯ
  static UserOnlineState getStatus(UserProfile user,
      {bool isConnected = true}) {
    final badges = user.badges;
    if (badges.contains('BOT') || badges.contains('SAVED')) {
      return UserOnlineState.bot;
    }

    if (!isConnected || !user.isOnline) {
      return UserOnlineState.offline;
    }

    if (user.lastSeen != null) {
      final lastSeenUtc =
          user.lastSeen!.isUtc ? user.lastSeen! : user.lastSeen!.toUtc();
      final nowUtc = DateTime.now().toUtc();
      final differenceInSeconds = nowUtc.difference(lastSeenUtc).inSeconds;

      if (differenceInSeconds <= 120 && user.isAppActive) {
        return UserOnlineState.online;
      }
      if (differenceInSeconds <= 300) {
        return UserOnlineState.away;
      }
      return UserOnlineState.offline;
    }

    return user.isAppActive ? UserOnlineState.online : UserOnlineState.offline;
  }

  /// 💬 ЕДИНЫЙ ТЕКСТ СТАТУСА НА АНГЛИЙСКОМ
  static String getStatusText(UserOnlineState state) {
    switch (state) {
      case UserOnlineState.online:
        return 'Online';
      case UserOnlineState.away:
        return 'Away';
      case UserOnlineState.bot:
        return 'Online 24/7';
      case UserOnlineState.offline:
        return 'Offline';
    }
  }

  /// 🎨 ЕДИНЫЙ ЦВЕТ СТАТУСА
  static Color getStatusColor(UserOnlineState state) {
    switch (state) {
      case UserOnlineState.online:
      case UserOnlineState.bot:
        return const Color(0xFF00E676); // Neon Green
      case UserOnlineState.away:
        return const Color(0xFFFFB300); // Yellow/Amber
      case UserOnlineState.offline:
        return const Color(0xFF6C727F); // Grey
    }
  }

  @override
  State<StatusIndicator> createState() => _StatusIndicatorState();
}

class _StatusIndicatorState extends State<StatusIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.4).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _updatePulseState();
  }

  @override
  void didUpdateWidget(covariant StatusIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updatePulseState();
  }

  void _updatePulseState() {
    final state =
        StatusIndicator.getStatus(widget.user, isConnected: widget.isConnected);
    if (widget.enableAnimation &&
        (state == UserOnlineState.online || state == UserOnlineState.bot)) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else {
      if (_pulseController.isAnimating) {
        _pulseController.stop();
        _pulseController.value = 0.0;
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state =
        StatusIndicator.getStatus(widget.user, isConnected: widget.isConnected);
    final baseColor = StatusIndicator.getStatusColor(state);
    final isGlowingState =
        state == UserOnlineState.online || state == UserOnlineState.bot;

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final pulseValue = isGlowingState ? _pulseAnimation.value : 1.0;
        final glowRadius = widget.size * 0.6 * pulseValue;
        final glowSpread = widget.size * 0.15 * pulseValue;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: baseColor,
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFF13151E),
              width: widget.size * 0.18,
            ),
            boxShadow: [
              BoxShadow(
                color: baseColor.withValues(alpha: isGlowingState ? 0.6 : 0.15),
                blurRadius: glowRadius,
                spreadRadius: glowSpread,
              ),
              if (isGlowingState)
                BoxShadow(
                  color: baseColor.withValues(alpha: 0.3),
                  blurRadius: glowRadius * 1.8,
                  spreadRadius: glowSpread * 1.2,
                ),
            ],
          ),
        );
      },
    );
  }
}
