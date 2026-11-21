import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/models/activity_models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_date.dart';
import '../progress/progress_providers.dart';

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

    // The wallpaper is painted by the app chrome (and by the navigation
    // shell), so the home page only owns its content.
    return SizedBox.expand(
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(progressSummaryProvider);
          try {
            await ref.read(authControllerProvider.notifier).refreshUser();
          } catch (_) {
            // The current profile remains visible when refreshing offline.
          }
        },
        // The horizontal gutter lives on each child instead of on the list so
        // the hero card can sit 8 px closer to each edge than the other cards.
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(top: 12, bottom: 28),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Builder(
                builder: (shellContext) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SizedBox(
                    height: 72,
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () =>
                              Scaffold.of(shellContext).openDrawer(),
                          tooltip: 'Open navigation menu',
                          visualDensity: VisualDensity.compact,
                          icon: Icon(
                            Icons.menu_rounded,
                            color: AppColors.brandText,
                          ),
                        ),
                        Expanded(
                          child: Align(
                            alignment: Alignment.center,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxWidth: 280,
                                maxHeight: 68,
                              ),
                              child: const _HomeBrandLockup(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: _WelcomeHero(
                greeting: greeting,
                name: displayName.isEmpty ? 'there' : displayName,
                avatarUrl: user?.avatarUrl,
                initials: user?.initials ?? '?',
                onNotifications: () => context.go('/notifications'),
                onReadMore: () => context.go('/devotion'),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _GrowthProgressCard(
                progress: progress,
                onTap: () => context.go('/progress'),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                "Today's Activities",
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _HomeActionCard(
                    icon: Icons.credit_card_rounded,
                    title: 'Subscription',
                    subtitle: 'View your plan and access',
                    onTap: () => context.go('/subscription'),
                  ),
                  const SizedBox(height: 8),
                  _HomeActionCard(
                    icon: Icons.live_tv_rounded,
                    title: 'Live service',
                    subtitle: 'Watch services and send a prayer request',
                    onTap: () => context.go('/live'),
                  ),
                  const SizedBox(height: 8),
                  _HomeActionCard(
                    icon: Icons.volunteer_activism_rounded,
                    title: 'Partnership',
                    subtitle: 'Support the ministry and become a partner',
                    onTap: () => context.go('/giving'),
                  ),
                  const SizedBox(height: 8),
                  _HomeActionCard(
                    icon: Icons.event_available_rounded,
                    title: 'upcoming Event',
                    subtitle: 'See what is happening at the ministry',
                    onTap: () => context.go('/upcoming'),
                  ),
                  const SizedBox(height: 8),
                  _HomeActionCard(
                    icon: Icons.headphones_rounded,
                    title: 'Listen to music',
                    subtitle: 'Play worship music while you use the app',
                    onTap: () => context.go('/music'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _HomeBrandLockup extends StatelessWidget {
  const _HomeBrandLockup();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          'MyGrowth Diet. LEARN, GROW, BECOME. Your personal journey of faith and growth.',
      child: Row(
        children: [
          SizedBox(
            width: 157,
            height: 68,
            child: ClipRect(
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    top: 3,
                    width: 280,
                    height: 68,
                    child: Image.asset(
                      'assets/images/mygrowth_brand_lockup.png',
                      fit: BoxFit.contain,
                      alignment: Alignment.centerLeft,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'LEARN, GROW,\nBECOME',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontFamily: 'PlayfairDisplay',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.08,
                    letterSpacing: .15,
                    color: AppColors.brandText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Your personal journey of faith and growth',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'PlayfairDisplay',
                    fontSize: 7,
                    fontStyle: FontStyle.italic,
                    height: 1.05,
                    color: AppColors.brandText,
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

class _WelcomeHero extends ConsumerWidget {
  const _WelcomeHero({
    required this.greeting,
    required this.name,
    required this.avatarUrl,
    required this.initials,
    required this.onNotifications,
    required this.onReadMore,
  });

  final String greeting;
  final String name;
  final String? avatarUrl;
  final String initials;
  final VoidCallback onNotifications;
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
      // The hero is at least 220 high, but it grows with its content so larger
      // text scales never overflow the card. The card lives inside a scrolling
      // list, so its height is unbounded: the column must size to its children
      // instead of using a Spacer/Expanded, which would need a bounded height.
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 220),
        child: DecoratedBox(
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
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 23,
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
                                        fontSize: 13,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 10),
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
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          height: 1.1,
                                        ),
                                  ),
                                  Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                      height: 1.15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
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
                  const SizedBox(height: 18),
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
                      label: const Text('Daily Devotion'),
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
  final _random = Random();
  List<({String text, String reference})> _scriptures = const [];
  int _index = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_loadScriptures());
    _timer = Timer.periodic(const Duration(seconds: 7), (_) => _showNext());
  }

  Future<void> _loadScriptures() async {
    final data = jsonDecode(
      await rootBundle.loadString('assets/bible/web.json'),
    ) as Map<String, dynamic>;
    final scriptures = <({String text, String reference})>[];
    for (final book in data['books'] as List<dynamic>) {
      final name = (book as Map<String, dynamic>)['name'] as String;
      final chapters = book['chapters'] as List<dynamic>;
      for (var chapterIndex = 0; chapterIndex < chapters.length; chapterIndex++) {
        final verses = chapters[chapterIndex] as List<dynamic>;
        for (var verseIndex = 0; verseIndex < verses.length; verseIndex++) {
          final text = verses[verseIndex];
          if (text is String && text.trim().isNotEmpty) {
            scriptures.add((
              text: text,
              reference: '$name ${chapterIndex + 1}:${verseIndex + 1}',
            ));
          }
        }
      }
    }
    scriptures.shuffle(_random);
    if (!mounted) return;
    setState(() {
      _scriptures = scriptures;
      _index = 0;
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _showNext({bool previous = false}) {
    if (_scriptures.isEmpty) return;
    setState(() {
      if (previous) {
        _index = (_index - 1 + _scriptures.length) % _scriptures.length;
      } else {
        _index++;
        if (_index >= _scriptures.length) {
          _scriptures.shuffle(_random);
          _index = 0;
        }
      }
    });
    _timer.cancel();
    // Restart the automatic rotation after a manual swipe.
    _timer = Timer.periodic(const Duration(seconds: 7), (_) => _showNext());
  }

  @override
  Widget build(BuildContext context) {
    final scripture = _scriptures.isEmpty
        ? (text: 'Loading scripture…', reference: '')
        : _scriptures[_index];
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
              final percent = (summary.completionRate * 100).round().clamp(
                0,
                100,
              );
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
            border: Border.all(
              color: AppColors.inkMuted.withValues(alpha: .22),
            ),
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
