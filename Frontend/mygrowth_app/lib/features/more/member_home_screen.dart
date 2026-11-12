import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/models/activity_models.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_date.dart';
import '../programme/programme_providers.dart';
import '../progress/progress_providers.dart';

DateTime _memberHomeToday() {
  final date = appDateNow();
  return DateTime(date.year, date.month, date.day);
}

/// Member landing page following the supplied Growth Diet home reference.
class MemberHomeScreen extends ConsumerWidget {
  const MemberHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final now = appDateNow();
    final firstName = (user?.name ?? '').trim().split(RegExp(r'\s+')).first;
    final greeting = now.hour < 12
        ? 'Good morning,'
        : now.hour < 17
            ? 'Good afternoon,'
            : 'Good evening,';
    final checklist = ref.watch(dailyChecklistProvider(_memberHomeToday()));
    final progress = ref.watch(progressSummaryProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(dailyChecklistProvider(_memberHomeToday()));
        ref.invalidate(progressSummaryProvider);
        try {
          await ref.read(authControllerProvider.notifier).refreshUser();
        } catch (_) {
          // The current profile remains visible when refreshing offline.
        }
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          Builder(
            builder: (shellContext) => _WelcomeHero(
              greeting: greeting,
              name: firstName.isEmpty ? 'there' : '$firstName!',
              avatarUrl: user?.avatarUrl,
              initials: user?.initials ?? '?',
              date: now,
              onNotifications: () => context.go('/notifications'),
              onMenu: () => Scaffold.of(shellContext).openDrawer(),
            ),
          ),
          const SizedBox(height: 16),
          _ScriptureCard(onReadMore: () => context.go('/devotion')),
          const SizedBox(height: 16),
          _GrowthProgressCard(progress: progress),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: Text(
                  "Today's Activities",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              TextButton(
                onPressed: () => context.go('/diet'),
                child: const Text('See all'),
              ),
            ],
          ),
          Text(
            DateFormat('EEEE, d MMMM').format(now),
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.inkSecondary),
          ),
          const SizedBox(height: 8),
          checklist.when(
            loading: () => const _ActivityLoadingCard(),
            error: (error, _) => _ActivityMessage(
              icon: Icons.cloud_off_outlined,
              message: 'Activities could not load. Tap to try again.',
              onTap: () => ref.invalidate(
                dailyChecklistProvider(_memberHomeToday()),
              ),
            ),
            data: (items) => items.isEmpty
                ? _ActivityMessage(
                    icon: Icons.event_available_outlined,
                    message: 'No activities are scheduled for today.',
                    onTap: () => context.go('/diet'),
                  )
                : Column(
                    children: [
                      for (final activity in items.take(3))
                        _ActivityCard(
                          activity: activity,
                          onTap: () => context.go('/diet'),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: () => context.go('/diet'),
            icon: const Icon(Icons.checklist_rounded),
            label: const Text("Open today's activities"),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.navy800,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _WelcomeHero extends ConsumerWidget {
  const _WelcomeHero({
    required this.greeting,
    required this.name,
    required this.avatarUrl,
    required this.initials,
    required this.date,
    required this.onNotifications,
    required this.onMenu,
  });

  final String greeting;
  final String name;
  final String? avatarUrl;
  final String initials;
  final DateTime date;
  final VoidCallback onNotifications;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final resolvedAvatar = _avatarUri(avatarUrl, ref.read(apiClientProvider).baseUrl);
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Container(
        height: 174,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/prayer.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.navy900.withValues(alpha: .48),
                AppColors.navy900.withValues(alpha: .78),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 25,
                      backgroundColor: AppColors.champagneGold,
                      backgroundImage:
                          resolvedAvatar == null ? null : NetworkImage(resolvedAvatar),
                      child: resolvedAvatar == null
                          ? Text(
                              initials,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$greeting\n$name',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Keep growing in Christ.',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.white.withValues(alpha: .85),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: onMenu,
                      tooltip: 'Open navigation menu',
                      icon: const Icon(Icons.menu_rounded, color: Colors.white),
                    ),
                    IconButton(
                      onPressed: onNotifications,
                      tooltip: 'Notifications',
                      icon: const Icon(
                        Icons.notifications_none_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .94),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    DateFormat('EEE, d MMM, yyyy').format(date),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.navy900,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScriptureCard extends StatelessWidget {
  const _ScriptureCard({required this.onReadMore});

  final VoidCallback onReadMore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        constraints: const BoxConstraints(minHeight: 174),
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/bible.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                AppColors.navy900.withValues(alpha: .93),
                AppColors.navy900.withValues(alpha: .4),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "TODAY'S SCRIPTURE",
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppColors.softGold,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  '“For I know the plans I have for you, plans to give you hope and a future.”',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontStyle: FontStyle.italic,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Jeremiah 29:11',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white.withValues(alpha: .84),
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: onReadMore,
                    iconAlignment: IconAlignment.end,
                    icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                    label: const Text('Read more'),
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.champagneGold,
                      foregroundColor: AppColors.navy900,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 8,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GrowthProgressCard extends StatelessWidget {
  const _GrowthProgressCard({required this.progress});

  final AsyncValue<ProgressSummary> progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy900.withValues(alpha: .07),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: progress.when(
        loading: () => const SizedBox(
          height: 70,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => const _ProgressUnavailable(),
        data: (summary) {
          final percent = (summary.completionRate * 100).round().clamp(0, 100);
          return Row(
            children: [
              SizedBox(
                width: 70,
                height: 70,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: percent / 100,
                      strokeWidth: 7,
                      backgroundColor: AppColors.navy100,
                      color: AppColors.champagneGold,
                      strokeCap: StrokeCap.round,
                    ),
                    Center(
                      child: Text(
                        '$percent%',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Growth Progress',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${summary.completedActivities} of ${summary.totalActivities} activities recorded',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.inkSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: percent / 100,
                        minHeight: 7,
                        backgroundColor: AppColors.navy100,
                        color: AppColors.navy800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProgressUnavailable extends StatelessWidget {
  const _ProgressUnavailable();

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(Icons.insights_outlined, color: AppColors.goldText, size: 40),
          const SizedBox(width: AppSpacing.md),
          const Expanded(
            child: Text('Your Growth Diet progress will appear here.'),
          ),
        ],
      );
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.activity, required this.onTap});

  final PlannedActivity activity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final complete = activity.isCompleted;
    final icon = switch (activity.categoryKey) {
      'scripture_reading' || 'bible_study' || 'proverbs_reading' =>
        Icons.menu_book_rounded,
      'prayer' || 'fasting_and_prayer' || 'prayer_and_affirmations' =>
        Icons.self_improvement_rounded,
      _ => Icons.auto_stories_rounded,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.paleChampagne,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: AppColors.goldText),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activity.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if ((activity.description ?? activity.categoryLabel ?? '')
                          .isNotEmpty)
                        Text(
                          activity.description ?? activity.categoryLabel!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.inkSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(
                  complete ? Icons.check_circle_rounded : Icons.chevron_right,
                  color: complete ? AppColors.success : AppColors.inkMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActivityLoadingCard extends StatelessWidget {
  const _ActivityLoadingCard();

  @override
  Widget build(BuildContext context) => const Card(
        child: Padding(
          padding: EdgeInsets.all(22),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
}

class _ActivityMessage extends StatelessWidget {
  const _ActivityMessage({
    required this.icon,
    required this.message,
    required this.onTap,
  });

  final IconData icon;
  final String message;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: AppColors.goldText),
                const SizedBox(width: 12),
                Expanded(child: Text(message)),
              ],
            ),
          ),
        ),
      );
}

String? _avatarUri(String? avatarUrl, String apiBaseUrl) {
  if (avatarUrl == null || avatarUrl.isEmpty) return null;
  final parsed = Uri.tryParse(avatarUrl);
  if (parsed != null && parsed.hasScheme) return avatarUrl;
  final api = Uri.tryParse(apiBaseUrl);
  if (api == null) return null;
  final origin = Uri(scheme: api.scheme, host: api.host, port: api.hasPort ? api.port : null);
  return origin.resolve(avatarUrl.startsWith('/') ? avatarUrl : '/$avatarUrl').toString();
}
