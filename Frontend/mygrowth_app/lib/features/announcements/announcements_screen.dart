import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/models/notification_models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_badge.dart';
import '../../core/widgets/app_buttons.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/feedback_states.dart';
import '../../core/widgets/toast.dart';
import '../programme/programme_providers.dart';

/// Ministry announcements: title, date, expandable body, link button.
class AnnouncementsScreen extends ConsumerWidget {
  const AnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(announcementsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Announcements')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(announcementsProvider);
          await Future<void>.delayed(const Duration(milliseconds: 200));
        },
        child: async.when(
          loading: () => const Padding(
            padding: AppSpacing.pagePaddingMobile,
            child: CardListSkeleton(count: 4),
          ),
          error: (e, _) => ListView(
            padding: AppSpacing.pagePaddingMobile,
            children: [
              ErrorState(
                error: e,
                onRetry: () => ref.invalidate(announcementsProvider),
              ),
            ],
          ),
          data: (announcements) {
            if (announcements.isEmpty) {
              return ListView(
                padding: AppSpacing.pagePaddingMobile,
                children: [
                  const EmptyState(
                    icon: Icons.campaign_outlined,
                    title: 'No announcements right now',
                    message:
                        'News from your ministry — events, programmes and '
                        'updates — will appear here.',
                  ),
                ],
              );
            }
            final wide = !Breakpoints.isCompact(context);
            final padding = wide
                ? const EdgeInsets.all(AppSpacing.xl)
                : AppSpacing.pagePaddingMobile;
            return ListView(
              padding: padding,
              children: [
                for (final announcement in announcements) ...[
                  _AnnouncementCard(announcement: announcement),
                  const SizedBox(height: AppSpacing.sm),
                ],
                const SizedBox(height: AppSpacing.xl),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AnnouncementCard extends StatefulWidget {
  const _AnnouncementCard({required this.announcement});

  final Announcement announcement;

  @override
  State<_AnnouncementCard> createState() => _AnnouncementCardState();
}

class _AnnouncementCardState extends State<_AnnouncementCard> {
  bool _expanded = false;

  Announcement get announcement => widget.announcement;

  void _copyLink(String url) {
    Clipboard.setData(ClipboardData(text: url));
    Toast.show(
      context,
      message: 'Link copied — open it in your browser: $url',
      tone: ToastTone.info,
      duration: const Duration(seconds: 5),
    );
  }

  @override
  Widget build(BuildContext context) {
    final date = announcement.createdAt ?? announcement.startsAt;
    final isLong = announcement.body.length > 160;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.gold100,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(Icons.campaign_outlined,
                    size: 20, color: AppColors.gold600),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      announcement.title,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (date != null)
                          Text(
                            DateFormat('d MMM yyyy').format(date.toLocal()),
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        if (announcement.createdByName != null &&
                            announcement.createdByName!.isNotEmpty) ...[
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            '· ${announcement.createdByName}',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (!announcement.isActiveNow)
                const StatusBadge(
                  label: 'Ended',
                  tone: AppBadgeTone.neutral,
                  small: true,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            announcement.body,
            maxLines: _expanded ? null : 3,
            overflow: _expanded ? null : TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(height: 1.55, color: AppColors.inkSecondary),
          ),
          if (isLong)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                child: Text(_expanded ? 'Show less' : 'Read more'),
              ),
            ),
          if (announcement.link != null &&
              announcement.link!.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xxs),
            Align(
              alignment: Alignment.centerLeft,
              child: AppButton(
                label: 'Open link',
                icon: Icons.link_rounded,
                variant: AppButtonVariant.outlined,
                onPressed: () => _copyLink(announcement.link!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
