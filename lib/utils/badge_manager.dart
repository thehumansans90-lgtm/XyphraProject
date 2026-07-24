import 'package:flutter/material.dart';

class BadgeConfig {
  final String code;
  final String label;
  final Color color;
  final IconData icon;
  final List<String> users;
  final bool isVisible;

  const BadgeConfig({
    required this.code,
    required this.label,
    required this.color,
    required this.icon,
    this.users = const [],
    this.isVisible = true,
  });
}

class BadgeManager {
  static final Map<String, BadgeConfig> _badges = {
    'OWNER': const BadgeConfig(
      code: 'OWNER',
      label: 'OWNER',
      color: Color(0xFFFFD700),
      icon: Icons.military_tech_rounded,
      users: [
        '1784749445751',
      ],
    ),
    'TESTER': const BadgeConfig(
      code: 'TESTER',
      label: 'TESTER',
      color: Color(0xFFE040FB),
      icon: Icons.bug_report_rounded,
      users: [
        '1784833068033'
      ],
    ),
    'BOT': const BadgeConfig(
      code: 'BOT',
      label: 'BOT',
      color: Color(0xFF5865F2),
      icon: Icons.smart_toy_rounded,
      users: [],
    ),
    'VERIFIED': const BadgeConfig(
      code: 'VERIFIED',
      label: 'VERIFIED',
      color: Color(0xFF00E676),
      icon: Icons.verified_rounded,
      users: [],
      isVisible: false,
    ),
    'MEMBER': const BadgeConfig(
      code: 'MEMBER',
      label: 'MEMBER',
      color: Color(0xFF9E9E9E),
      icon: Icons.person_rounded,
      users: [],
    ),
  };

  static List<String> getBadgesForUser({
    required String userId,
    required String username,
    required List<String> currentBadges,
  }) {
    final cleanUname = username.toLowerCase().trim();
    final cleanId = userId.trim();
    final Set<String> updatedBadges = Set.from(currentBadges);

    updatedBadges.remove('AB:A');
    updatedBadges.add('VERIFIED');

    _badges.forEach((code, config) {
      if (config.users.isNotEmpty) {
        final hasMatch = config.users.any((entry) {
          final cleanEntry = entry.toLowerCase().trim();
          return (cleanId.isNotEmpty && cleanEntry == cleanId) || cleanEntry == cleanUname;
        });

        if (hasMatch) {
          updatedBadges.add(code);
        }
      }
    });

    return updatedBadges.toList();
  }

  static Widget buildBadgeWidget(String badgeCode) {
    final codeUpper = badgeCode.toUpperCase();
    final config = _badges[codeUpper];

    if (config == null || !config.isVisible) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            config.color.withValues(alpha: 0.25),
            config.color.withValues(alpha: 0.10),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: config.color.withValues(alpha: 0.6),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: config.color.withValues(alpha: 0.2),
            blurRadius: 6,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: config.color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              config.icon,
              size: 11,
              color: config.color,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            config.label,
            style: TextStyle(
              color: config.color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }

  static Widget buildBadgesList(List<String> badges) {
    if (badges.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: badges.map((b) {
          final widget = buildBadgeWidget(b);
          if (widget is SizedBox) return widget;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: widget,
          );
        }).toList(),
      ),
    );
  }
}