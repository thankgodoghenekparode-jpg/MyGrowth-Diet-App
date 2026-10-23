import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/models/programme_models.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_badge.dart';
import '../../core/widgets/app_buttons.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/feedback_states.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/toast.dart';
import '../programme/programme_providers.dart';
import 'admin_providers.dart';
import 'admin_shared.dart';

/// Annual programme library: create, edit, publish and archive years.
class AdminProgrammesScreen extends ConsumerWidget {
  const AdminProgrammesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final programmes = ref.watch(adminProgrammesProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(adminProgrammesProvider);
        await Future<void>.delayed(const Duration(milliseconds: 300));
      },
      child: ListView(
        padding: adminPadding(context),
        children: [
          SectionHeader(
            title: 'Annual Programmes',
            subtitle: 'Each programme year holds the ministry’s plan',
            icon: Icons.event_note_outlined,
          ),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              AppButton(
                label: 'Create programme',
                icon: Icons.add_rounded,
                onPressed: () => context.go('/admin/programmes/new'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          programmes.when(
            loading: () => const CardListSkeleton(count: 3),
            error: (error, _) => ErrorState(
              error: error,
              onRetry: () => ref.invalidate(adminProgrammesProvider),
            ),
            data: (items) {
              if (items.isEmpty) {
                return AppCard(
                  child: EmptyState(
                    icon: Icons.event_note_outlined,
                    title: 'No programme years yet',
                    message:
                        'Create the first annual programme — members see its '
                        'monthly, weekly and daily plans as you publish them.',
                    actionLabel: 'Create programme',
                    onAction: () => context.go('/admin/programmes/new'),
                  ),
                );
              }
              return Column(
                children: [
                  for (final programme in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _ProgrammeCard(programme: programme),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

class _ProgrammeCard extends ConsumerStatefulWidget {
  const _ProgrammeCard({required this.programme});

  final AnnualProgramme programme;

  @override
  ConsumerState<_ProgrammeCard> createState() => _ProgrammeCardState();
}

class _ProgrammeCardState extends ConsumerState<_ProgrammeCard> {
  bool _busy = false;

  void _invalidate() {
    ref.invalidate(adminProgrammesProvider);
    ref.invalidate(programmeYearsProvider);
    ref.invalidate(currentProgrammeProvider);
  }

  Future<void> _publish() async {
    final confirmed = await confirmDialog(
      context,
      title: 'Publish this programme?',
      message:
          'It becomes visible to all members, including its plans as they '
          'are published.',
      confirmLabel: 'Publish',
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      final client = ref.read(apiClientProvider);
      await client.post('/admin/programmes/${widget.programme.id}/publish');
      if (!mounted) return;
      _invalidate();
      Toast.success(context, 'Programme published. Members can see it now.');
    } on ApiException catch (e) {
      if (!mounted) return;
      Toast.error(context, e.fieldError ?? e.message);
    } catch (_) {
      if (!mounted) return;
      Toast.error(context, 'Couldn’t publish just now.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _archive() async {
    final confirmed = await confirmDialog(
      context,
      title: 'Archive this programme?',
      message:
          'It moves out of the active list. Existing records and reports are '
          'kept — you can still see it with the archived filter.',
      confirmLabel: 'Archive',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      final client = ref.read(apiClientProvider);
      await client.post('/admin/programmes/${widget.programme.id}/archive');
      if (!mounted) return;
      _invalidate();
      Toast.success(context, 'Programme archived.');
    } on ApiException catch (e) {
      if (!mounted) return;
      Toast.error(context, e.fieldError ?? e.message);
    } catch (_) {
      if (!mounted) return;
      Toast.error(context, 'Couldn’t archive just now.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final programme = widget.programme;
    final dateRange = programme.startDate == null && programme.endDate == null
        ? 'Dates not set'
        : '${fmtDate(programme.startDate)} – ${fmtDate(programme.endDate)}';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.navy100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${programme.year}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.navy800,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      programme.title.isEmpty
                          ? 'Programme ${programme.year}'
                          : programme.title,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateRange,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              StatusBadge(
                label: humanizeStatus(programme.status),
                tone: badgeToneFor(programme.status),
                small: true,
              ),
            ],
          ),
          if (programme.ministryName.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              programme.ministryName,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              AppButton(
                label: 'Edit',
                icon: Icons.edit_outlined,
                variant: AppButtonVariant.outlined,
                busy: _busy,
                onPressed: () =>
                    context.go('/admin/programmes/edit/${programme.id}'),
              ),
              if (programme.status != 'PUBLISHED')
                AppButton(
                  label: 'Publish',
                  icon: Icons.publish_rounded,
                  variant: AppButtonVariant.outlined,
                  busy: _busy,
                  onPressed: _publish,
                ),
              if (programme.status != 'ARCHIVED')
                AppButton(
                  label: 'Archive',
                  icon: Icons.archive_outlined,
                  variant: AppButtonVariant.text,
                  busy: _busy,
                  onPressed: _archive,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
