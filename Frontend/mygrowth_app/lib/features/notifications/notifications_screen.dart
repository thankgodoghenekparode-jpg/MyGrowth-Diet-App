import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/models/notification_models.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_badge.dart';
import '../../core/widgets/app_buttons.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/feedback_states.dart';
import '../../core/widgets/toast.dart';
import '../programme/programme_providers.dart';
import 'notification_prefs_section.dart';

/// In-app notifications: grouped by day, tap to open, preferences sheet.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  Future<void> _markAllRead(BuildContext context, WidgetRef ref) async {
    final client = ref.read(apiClientProvider);
    try {
      await client.post('/me/notifications/read-all');
      ref.invalidate(notificationsProvider);
      ref.invalidate(unreadNotificationCountProvider);
      if (context.mounted) Toast.success(context, 'All caught up!');
    } on ApiException catch (e) {
      if (context.mounted) Toast.error(context, e.fieldError ?? e.message);
    } catch (_) {
      if (context.mounted) {
        Toast.error(context, 'Unable to mark all as read just now.');
      }
    }
  }

  void _openPreferences(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppSpacing.lg,
          bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Notification preferences',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  AppIconButton(
                    icon: Icons.close_rounded,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              const NotificationPrefsSection(),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notificationsProvider);
    final unread = ref.watch(unreadNotificationCountProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          AppIconButton(
            icon: Icons.tune_rounded,
            tooltip: 'Notification preferences',
            filled: true,
            onPressed: () => _openPreferences(context),
          ),
          const SizedBox(width: AppSpacing.xs),
          AppIconButton(
            icon: Icons.done_all_rounded,
            tooltip: 'Mark all as read',
            filled: true,
            onPressed: unread > 0
                ? () => _markAllRead(context, ref)
                : null,
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(notificationsProvider);
          await Future<void>.delayed(const Duration(milliseconds: 200));
        },
        child: async.when(
          loading: () => const Padding(
            padding: AppSpacing.pagePaddingMobile,
            child: CardListSkeleton(count: 5),
          ),
          error: (e, _) => ListView(
            padding: AppSpacing.pagePaddingMobile,
            children: [
              ErrorState(
                error: e,
                onRetry: () => ref.invalidate(notificationsProvider),
              ),
            ],
          ),
          data: (notifications) {
            if (notifications.isEmpty) {
              return ListView(
                padding: AppSpacing.pagePaddingMobile,
                children: [
                  const EmptyState(
                    icon: Icons.notifications_none_rounded,
                    title: 'No notifications',
                    message:
                        'Updates about plans, reports and prayer sessions '
                        'will appear here. Nothing to catch up on — enjoy '
                        'the quiet!',
                  ),
                ],
              );
            }
            final groups = _groupByDay(notifications);
            return ListView(
              padding: Breakpoints.isCompact(context)
                  ? AppSpacing.pagePaddingMobile
                  : const EdgeInsets.all(AppSpacing.xl),
              children: [
                if (unread > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: StatusBadge(
                      label: '$unread unread',
                      tone: AppBadgeTone.navy,
                    ),
                  ),
                for (final group in groups.entries) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.xs),
                    child: Text(
                      _dayLabel(group.key),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: AppColors.navy700,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  for (final notification in group.value) ...[
                    _NotificationTile(
                      notification: notification,
                      onTap: () => _open(context, ref, notification),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                  ],
                ],
                const SizedBox(height: AppSpacing.xl),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    AppNotification notification,
  ) async {
    if (!notification.read) {
      final client = ref.read(apiClientProvider);
      try {
        await client.post('/me/notifications/${notification.id}/read');
        ref.invalidate(notificationsProvider);
        ref.invalidate(unreadNotificationCountProvider);
      } catch (_) {
        // Best effort: still navigate below.
      }
    }
    final link = notification.link;
    if (!context.mounted) return;
    if (link != null && link.trim().isNotEmpty) {
      context.go(link);
    }
  }
}

Map<DateTime, List<AppNotification>> _groupByDay(
    List<AppNotification> notifications) {
  final sorted = [...notifications]
    ..sort((a, b) {
      final aDate = a.createdAt ?? DateTime.now();
      final bDate = b.createdAt ?? DateTime.now();
      return bDate.compareTo(aDate);
    });
  final map = <DateTime, List<AppNotification>>{};
  for (final n in sorted) {
    final d = n.createdAt ?? DateTime.now();
    final key = DateTime(d.year, d.month, d.day);
    map.putIfAbsent(key, () => []).add(n);
  }
  final keys = map.keys.toList()..sort((a, b) => b.compareTo(a));
  return {for (final k in keys) k: map[k]!};
}

String _dayLabel(DateTime day) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  if (diff < 7) return DateFormat('EEEE').format(day);
  return DateFormat('EEEE, d MMMM yyyy').format(day);
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final createdAt = notification.createdAt?.toLocal();
    return AppCard(
      color: notification.read ? null : AppColors.navy50,
      highlight: !notification.read,
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.navy100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _iconFor(notification.type),
              size: 18,
              color: AppColors.navy700,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: notification.read
                            ? FontWeight.w500
                            : FontWeight.w700,
                      ),
                ),
                if (notification.body != null &&
                    notification.body!.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    notification.body!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                if (createdAt != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('HH:mm').format(createdAt),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ],
            ),
          ),
          if (!notification.read)
            Container(
              width: 9,
              height: 9,
              margin: const EdgeInsets.only(top: 6, left: AppSpacing.xs),
              decoration: BoxDecoration(
                color: AppColors.gold500,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }

  IconData _iconFor(String type) {
    switch (type.toUpperCase()) {
      case 'REPORT':
        return Icons.fact_check_outlined;
      case 'PRAYER':
      case 'PRAYER_SESSION':
        return Icons.self_improvement_outlined;
      case 'ANNOUNCEMENT':
        return Icons.campaign_outlined;
      case 'MATERIAL':
        return Icons.local_library_outlined;
      case 'GOAL':
        return Icons.flag_outlined;
      case 'SYSTEM':
        return Icons.info_outline_rounded;
      default:
        return Icons.notifications_none_rounded;
    }
  }
}
