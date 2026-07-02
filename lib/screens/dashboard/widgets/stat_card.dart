import 'package:flutter/material.dart';
import '../../../core/theme/app_animations.dart';
import '../../../core/theme/app_theme.dart';

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color? iconColor;
  final Color? bgColor;
  final String? subtitle;

  // Optional count-up animation: if set, animates from 0→animatedEnd on mount.
  final double? animatedEnd;
  final String Function(double)? formatter;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.iconColor,
    this.bgColor,
    this.subtitle,
    this.animatedEnd,
    this.formatter,
  });

  @override
  Widget build(BuildContext context) {
    final bg = bgColor ?? AppColors.primaryLight;
    final ic = iconColor ?? AppColors.primary;
    final valueStyle = Theme.of(context).textTheme.headlineSmall?.copyWith(
      fontWeight: FontWeight.w800,
      color: AppColors.textPrimary,
    );

    Widget valueWidget;
    if (animatedEnd != null && formatter != null) {
      valueWidget = TweenAnimationBuilder<double>(
        duration: AppAnimations.countUp,
        curve: Curves.easeOut,
        tween: Tween(begin: 0, end: animatedEnd!),
        builder: (_, v, __) => Text(formatter!(v), style: valueStyle),
      );
    } else {
      valueWidget = Text(value, style: valueStyle);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: ic, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                valueWidget,
                const SizedBox(height: 2),
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
