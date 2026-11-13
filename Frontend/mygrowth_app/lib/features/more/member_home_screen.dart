import 'package:mygrowth_app/core/models/activity_models.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_date.dart';
import '../progress/progress_providers.dart';

const _homeScriptures = [
  (
    text: 'For I know the plans I have for you, declares the LORD, plans to '
        'prosper you and not to harm you, plans to give you hope and a future.',
    reference: 'Jeremiah 29:11',
  ),
  (text: 'The LORD is my shepherd; I shall not want.', reference: 'Psalm 23:1'),
  (
    text: 'Trust in the LORD with all thine heart; and lean not unto thine '
        'own understanding.',
    reference: 'Proverbs 3:5',
  ),
  (
    text: 'I can do all things through Christ which strengtheneth me.',
    reference: 'Philippians 4:13',
  ),
  (
    text: 'Be strong and of a good courage; be not afraid, neither be thou '
        'dismayed.',
    reference: 'Joshua 1:9',
  ),
];

/// Member landing page following the supplied Growth Diet home reference.
class MemberHomeScreen extends ConsumerWidget {
  const MemberHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final now = appDateNow();
    final displayName = (user?.name ?? '').trim();
    final greeting = now.hour < 12
        ? 'Good morning'
        : now.hour < 17
        ? 'Good afternoon'
        : 'Good evening';
    final progress = ref.watch(progressSummaryProvider);

    return Stack(
      children: [
        Positioned.fill(child: ColoredBox(color: AppColors.background),
        ),
        if (Theme.of(context).brightness == Brightness.light)
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.24,
                child: Image.asset(
                  'assets/images/app_background.jpg',
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        Positioned.fill(
          child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(progressSummaryProvider);
          try {
            await ref.read(authControllerProvider.notifier).refreshUser();
          } catch (_) {
            // The current profile remains visible when refreshing offline.
          }
        },
        child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          const _HomeBrandHeader(),
          const SizedBox(height: 12),
          Builder(
            builder: (shellContext) => _WelcomeHero(
              greeting: greeting,
              name: displayName.isEmpty ? 'there' : displayName,
              avatarUrl: user?.avatarUrl,
              initials: user?.initials ?? '?',
              onNotifications: () => context.go('/notifications'),
              onMenu: () => Scaffold.of(shellContext).openDrawer(),
              onReadMore: () => context.go('/devotion'),
            ),
          ),
          const SizedBox(height: 16),
          _GrowthProgressCard(
            progress: progress,
            onTap: () => context.go('/progress'),
          ),
          const SizedBox(height: 28),
          Text(
            "Today's Activities",
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Column(
            children: [
              _HomeActionCard(
                icon: Icons.menu_book_rounded,
                title: 'Bible Reading',
                subtitle: 'Read and reflect on God’s Word',
                onTap: () => context.go('/bible'),
              ),
              const SizedBox(height: 12),
              _HomeActionCard(
                icon: Icons.auto_stories_rounded,
                title: "Today's Proverb",
                subtitle: 'Wisdom for today · Proverbs ${now.day}',
                onTap: () => context.go(
                  '/bible?book=Proverbs&chapter=${now.day}',
                ),
              ),
              const SizedBox(height: 12),
              _HomeActionCard(
                icon: Icons.record_voice_over_rounded,
                title: 'Daily Declarations',
                subtitle: 'Speak today’s declarations of faith',
                onTap: () => context.go('/diet?section=declarations'),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
          ),
        ),
        ),
      ],
    );
  }
}

class _HomeBrandHeader extends StatelessWidget {
  const _HomeBrandHeader();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final bannerWidth = constraints.maxWidth + 32;
      return OverflowBox(
        alignment: Alignment.center,
        minWidth: bannerWidth,
        maxWidth: bannerWidth,
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.white, Colors.white],
            stops: [0, .08, 1],
          ).createShader(bounds),
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (bounds) => const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.transparent,
                Colors.white,
                Colors.white,
                Colors.transparent,
              ],
              stops: [0, .06, .94, 1],
            ).createShader(bounds),
            child: Image.asset(
              'assets/images/home_brand_banner.png',
              width: bannerWidth,
              fit: BoxFit.fitWidth,
              semanticLabel: 'MyGrowth banner: Grow. Learn. Live it.',
            ),
          ),
        ),
      );
    },
  );
}

class _WelcomeHero extends ConsumerWidget {
  const _WelcomeHero({
    required this.greeting,
    required this.name,
    required this.avatarUrl,
    required this.initials,
    required this.onNotifications,
    required this.onMenu,
    required this.onReadMore,
  });

  final String greeting;
  final String name;
  final String? avatarUrl;
  final String initials;
  final VoidCallback onNotifications;
  final VoidCallback onMenu;
  final VoidCallback onReadMore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final resolvedAvatar = _avatarUri(
      avatarUrl,
      ref.read(apiClientProvider).baseUrl,
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Container(
        height: 280,
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
                AppColors.navy900.withValues(alpha: .22),
                AppColors.navy900.withValues(alpha: .94),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: onMenu,
                      tooltip: 'Open navigation menu',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.menu_rounded, color: Colors.white),
                    ),
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 230),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 19,
                                backgroundColor: AppColors.champagneGold,
                                backgroundImage: resolvedAvatar == null
                                    ? null
                                    : NetworkImage(resolvedAvatar),
                                child: resolvedAvatar == null
                                    ? Text(
                                        initials,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12,
                                        ),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      greeting,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.labelMedium
                                          ?.copyWith(
                                            color: Colors.white.withValues(
                                              alpha: .9,
                                            ),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            height: 1.1,
                                          ),
                                    ),
                                    Text(
                                      name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 14,
                                            height: 1.15,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: onNotifications,
                      tooltip: 'Notifications',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(
                        Icons.notifications_none_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  width: 42,
                  height: 3,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: AppColors.champagneGold,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Text(
                  "TODAY'S SCRIPTURE",
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppColors.softGold,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                _ScriptureCarousel(
                  textStyle: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontStyle: FontStyle.italic,
                    height: 1.2,
                  ),
                  referenceStyle: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white.withValues(alpha: .84),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: onReadMore,
                    iconAlignment: IconAlignment.end,
                    icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                    label: const Text('Devotion'),
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

class _ScriptureCarousel extends StatefulWidget {
  const _ScriptureCarousel({
    required this.textStyle,
    required this.referenceStyle,
  });

  final TextStyle? textStyle;
  final TextStyle? referenceStyle;

  @override
  State<_ScriptureCarousel> createState() => _ScriptureCarouselState();
}

class _ScriptureCarouselState extends State<_ScriptureCarousel> {
  late Timer _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 7), (_) => _showNext());
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _showNext({bool previous = false}) {
    setState(() {
      _index = (_index + (previous ? _homeScriptures.length - 1 : 1)) %
          _homeScriptures.length;
    });
    _timer.cancel();
    // Restart the automatic rotation after a manual swipe.
    _timer = Timer.periodic(const Duration(seconds: 7), (_) => _showNext());
  }

  @override
  Widget build(BuildContext context) {
    final scripture = _homeScriptures[_index];
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity.abs() > 80) _showNext(previous: velocity > 0);
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 450),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(.12, 0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        child: Column(
          key: ValueKey(scripture.reference),
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '\u201c${scripture.text}\u201d',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: widget.textStyle,
            ),
            const SizedBox(height: 5),
            Text(scripture.reference, style: widget.referenceStyle),
          ],
        ),
      ),
    );
  }
}

class _GrowthProgressCard extends StatelessWidget {
  const _GrowthProgressCard({required this.progress, required this.onTap});

  final AsyncValue<ProgressSummary> progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        mouseCursor: SystemMouseCursors.click,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
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
              final percent = (summary.completionRate * 100)
                  .round()
                  .clamp(0, 100);
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
        ),
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

class _HomeActionCard extends StatelessWidget {
  const _HomeActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.inkMuted.withValues(alpha: .22)),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.paleChampagne,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(icon, color: AppColors.goldText, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          subtitle,
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
                    Icons.chevron_right,
                    color: AppColors.inkMuted,
                    size: 21,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String? _avatarUri(String? avatarUrl, String apiBaseUrl) {
  if (avatarUrl == null || avatarUrl.isEmpty) return null;
  final parsed = Uri.tryParse(avatarUrl);
  if (parsed != null && parsed.hasScheme) return avatarUrl;
  final api = Uri.tryParse(apiBaseUrl);
  if (api == null) return null;
  final origin = Uri(
    scheme: api.scheme,
    host: api.host,
    port: api.hasPort ? api.port : null,
  );
  return origin
      .resolve(avatarUrl.startsWith('/') ? avatarUrl : '/$avatarUrl')
      .toString();
}




