import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Rounded status pill with consistent semantic colours.
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    this.tone = AppBadgeTone.neutral,
    this.icon,
    this.small = false,
  });

  final String label;
  final AppBadgeTone tone;
  final IconData? icon;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      AppBadgeTone.neutral => (AppColors.surfaceMuted, AppColors.inkSecondary),
      AppBadgeTone.success => (AppColors.successSurface, AppColors.success),
      AppBadgeTone.warning => (AppColors.warningSurface, AppColors.warning),
      AppBadgeTone.danger => (AppColors.dangerSurface, AppColors.danger),
      AppBadgeTone.info => (AppColors.infoSurface, AppColors.info),
      AppBadgeTone.navy => (AppColors.navy100, AppColors.navy800),
      AppBadgeTone.gold => (AppColors.gold100, AppColors.gold600),
    };
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 8 : 10,
        vertical: small ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: small ? 11 : 13, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w700,
                  fontSize: small ? 11 : 12,
                ),
          ),
        ],
      ),
    );
  }
}

enum AppBadgeTone { neutral, success, warning, danger, info, navy, gold }

/// Maps backend status strings to sensible badge tones/labels.
AppBadgeTone badgeToneFor(String status) {
  switch (status.toUpperCase()) {
    case 'COMPLETED':
    case 'REVIEWED':
    case 'ACCEPTED':
    case 'ACTIVE':
    case 'APPROVED':
    case 'PUBLISHED':
      return AppBadgeTone.success;
    case 'IN_PROGRESS':
    case 'SUBMITTED':
    case 'PROPOSED':
    case 'PENDING':
    case 'TEMPORARILY_UNAVAILABLE':
      return AppBadgeTone.warning;
    case 'SKIPPED':
    case 'CANCELLED':
    case 'DECLINED':
    case 'ABANDONED':
    case 'REJECTED':
    case 'SUSPENDED':
    case 'ARCHIVED':
    case 'MISSED':
      return AppBadgeTone.danger;
    case 'REQUIRES_FOLLOW_UP':
      return AppBadgeTone.info;
    case 'PAUSED':
    case 'DRAFT':
    case 'RESCHEDULED':
    case 'NOT_APPLICABLE':
      return AppBadgeTone.neutral;
    default:
      return AppBadgeTone.neutral;
  }
}

String humanizeStatus(String status) {
  final words = status
      .replaceAll('_', ' ')
      .toLowerCase()
      .split(' ')
      .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
      .join(' ');
  return words;
}
