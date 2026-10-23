import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/models/daily_diet_models.dart';
import '../../core/models/material_models.dart';
import '../../core/models/programme_models.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_badge.dart';
import '../../core/widgets/app_buttons.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/feedback_states.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/toast.dart';
import '../daily_diet/daily_diet_shared.dart';
import 'admin_daily_diet_providers.dart';
import 'admin_providers.dart';
import 'admin_shared.dart';

/// Admin management of the Daily Diet.
///
/// Two jobs: shape the structure members follow (which sections exist, what
/// they are called, their order and how each behaves) and fill in what each
/// section carries on a given day.
class AdminDailyDietScreen extends ConsumerStatefulWidget {
  const AdminDailyDietScreen({super.key});

  @override
  ConsumerState<AdminDailyDietScreen> createState() =>
      _AdminDailyDietScreenState();
}

class _AdminDailyDietScreenState extends ConsumerState<AdminDailyDietScreen> {
  int? _year;
  DateTime _date = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final programmesAsync = ref.watch(adminProgrammesProvider);
    final programmes = programmesAsync.value ?? const <AnnualProgramme>[];
    final year = _year ??
        (programmes.isNotEmpty
            ? programmes.first.year
            : DateTime.now().year);

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          _Header(
            year: year,
            years: programmes.map((p) => p.year).toSet().toList(),
            onYear: (y) => setState(() => _year = y),
          ),
          const _Tabs(),
          Expanded(
            child: TabBarView(
              children: [
                _StructureTab(year: year, programmes: programmes),
                _ContentTab(
                  year: year,
                  date: _date,
                  onDate: (d) => setState(() => _date = d),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A slim tab strip. [DefaultTabController] wraps the whole screen.
class _Tabs extends StatelessWidget {
  const _Tabs();

  @override
  Widget build(BuildContext context) {
    return const TabBar(
      tabs: [
        Tab(text: 'Structure', icon: Icon(Icons.view_list_rounded)),
        Tab(text: 'Day content', icon: Icon(Icons.event_note_rounded)),
      ],
    );
  }
}

/// The programme year this screen edits.
class _Header extends StatelessWidget {
  const _Header({
    required this.year,
    required this.years,
    required this.onYear,
  });

  final int year;
  final List<int> years;
  final ValueChanged<int> onYear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: adminPadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Daily Diet',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Set the devotional structure members follow, then fill in each '
            "day's content.",
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.inkMuted,
            ),
          ),
          if (years.length > 1) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              children: [
                for (final y in years)
                  ChoiceChip(
                    label: Text('$y'),
                    selected: y == year,
                    onSelected: (_) => onYear(y),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Structure
// ---------------------------------------------------------------------------

/// The list of sections members follow.
class _StructureTab extends ConsumerWidget {
  const _StructureTab({required this.year, required this.programmes});

  final int year;
  final List<AnnualProgramme> programmes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sectionsAsync = ref.watch(adminDailyDietSectionsProvider(year));

    return sectionsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: CardListSkeleton(count: 5),
      ),
      error: (error, _) => ErrorState(
        error: error,
        onRetry: () => ref.invalidate(adminDailyDietSectionsProvider(year)),
      ),
      data: (sections) {
        if (sections.isEmpty) {
          return Padding(
            padding: adminPadding(context),
            child: AppCard(
              child: EmptyState(
                icon: Icons.view_list_rounded,
                title: 'No sections yet',
                message:
                    'Add the sections members will follow each day — prayer, '
                    'scriptures, fasting and the rest.',
                actionLabel: 'Add a section',
                onAction: () => _openSectionSheet(context, ref, year: year),
              ),
            ),
          );
        }

        final programmeId = sections.first.programmeId;

        return ListView(
          padding: adminPadding(context),
          children: [
            SectionHeader(
              title: 'Sections',
              icon: Icons.view_list_rounded,
              subtitle: '${sections.length} in this order',
              actionLabel: 'Add section',
              onAction: () => _openSectionSheet(context, ref, year: year),
            ),
            for (var i = 0; i < sections.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _SectionCard(
                  section: sections[i],
                  isFirst: i == 0,
                  isLast: i == sections.length - 1,
                  onMove: (delta) => _move(
                    context,
                    ref,
                    sections: sections,
                    index: i,
                    delta: delta,
                    programmeId: programmeId,
                    year: year,
                  ),
                  onEdit: () => _openSectionSheet(
                    context,
                    ref,
                    year: year,
                    existing: sections[i],
                  ),
                  onToggle: (enabled) => _toggle(
                    context,
                    ref,
                    section: sections[i],
                    enabled: enabled,
                    year: year,
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Members see the sections in this order. Tap a section to rename '
              'it or change how it behaves.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: AppColors.inkMuted),
            ),
          ],
        );
      },
    );
  }

  Future<void> _move(
    BuildContext context,
    WidgetRef ref, {
    required List<AdminDailyDietSection> sections,
    required int index,
    required int delta,
    required String programmeId,
    required int year,
  }) async {
    final target = index + delta;
    if (target < 0 || target >= sections.length) return;
    final order = sections.map((s) => s.id).toList();
    final moved = order.removeAt(index);
    order.insert(target, moved);
    try {
      await ref.read(adminDailyDietControllerProvider).reorder(
            programmeId: programmeId,
            order: order,
            year: year,
          );
    } catch (error) {
      if (!context.mounted) return;
      Toast.show(
        context,
        message: _messageFor(error),
        tone: ToastTone.error,
      );
    }
  }

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref, {
    required AdminDailyDietSection section,
    required bool enabled,
    required int year,
  }) async {
    try {
      await ref.read(adminDailyDietControllerProvider).saveSection(
            year: year,
            id: section.id,
            key: section.key,
            label: section.label,
            behaviour: section.behaviour,
            enabled: enabled,
          );
    } catch (error) {
      if (!context.mounted) return;
      Toast.show(
        context,
        message: _messageFor(error),
        tone: ToastTone.error,
      );
    }
  }
}

/// One section in the structure.
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.section,
    required this.isFirst,
    required this.isLast,
    required this.onMove,
    required this.onEdit,
    required this.onToggle,
  });

  final AdminDailyDietSection section;
  final bool isFirst;
  final bool isLast;
  final void Function(int delta) onMove;
  final VoidCallback onEdit;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      onTap: onEdit,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: dailyDietTint(section.key),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              dailyDietIconFor(section.key),
              size: 19,
              color: AppColors.iconAccent,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  section.label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  section.key,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.inkMuted,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    StatusBadge(
                      label: section.behaviour.label,
                      tone: AppBadgeTone.neutral,
                      small: true,
                    ),
                    StatusBadge(
                      label: section.isPublished ? 'Published' : section.status,
                      tone: section.isPublished
                          ? AppBadgeTone.success
                          : AppBadgeTone.warning,
                      small: true,
                    ),
                    StatusBadge(
                      label: '${section.contentCount} content rows',
                      tone: AppBadgeTone.info,
                      small: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            children: [
              Switch(
                value: section.enabled,
                onChanged: onToggle,
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Move up',
                    icon: const Icon(Icons.keyboard_arrow_up_rounded),
                    onPressed: isFirst ? null : () => onMove(-1),
                  ),
                  IconButton(
                    tooltip: 'Move down',
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                    onPressed: isLast ? null : () => onMove(1),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Add or rename a section.
Future<void> _openSectionSheet(
  BuildContext context,
  WidgetRef ref, {
  required int year,
  AdminDailyDietSection? existing,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _SectionSheet(year: year, existing: existing),
  );
}

class _SectionSheet extends ConsumerStatefulWidget {
  const _SectionSheet({required this.year, this.existing});

  final int year;
  final AdminDailyDietSection? existing;

  @override
  ConsumerState<_SectionSheet> createState() => _SectionSheetState();
}

class _SectionSheetState extends ConsumerState<_SectionSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _keyController;
  late final TextEditingController _labelController;
  late final TextEditingController _descriptionController;
  late DailyDietBehaviour _behaviour;
  bool _saving = false;

  bool get _isNew => widget.existing == null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _keyController = TextEditingController(text: existing?.key ?? '');
    _labelController = TextEditingController(text: existing?.label ?? '');
    _descriptionController =
        TextEditingController(text: existing?.description ?? '');
    _behaviour = existing?.behaviour ?? DailyDietBehaviour.text;
  }

  @override
  void dispose() {
    _keyController.dispose();
    _labelController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final controller = ref.read(adminDailyDietControllerProvider);
    try {
      await controller.saveSection(
        year: widget.year,
        id: widget.existing?.id,
        key: _keyController.text.trim().toLowerCase(),
        label: _labelController.text.trim(),
        description: _descriptionController.text.trim(),
        behaviour: _behaviour,
        status: widget.existing?.isPublished == true ? 'PUBLISHED' : 'DRAFT',
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      Toast.show(
        context,
        message: _isNew ? 'Section added' : 'Section updated',
        tone: ToastTone.success,
      );
    } catch (error) {
      if (!mounted) return;
      Toast.show(
        context,
        message: _messageFor(error),
        tone: ToastTone.error,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.existing;
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isNew ? 'Add a section' : 'Edit section',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'Key',
                hint: 'scripture_reading',
                controller: _keyController,
                enabled: _isNew,
                helper: _isNew
                    ? 'Lowercase letters, numbers and underscores. It never '
                        'changes once the section exists.'
                    : 'The key cannot be changed.',
                validator: (value) {
                  final text = (value ?? '').trim();
                  if (text.isEmpty) return 'A key is required';
                  if (!RegExp(r'^[a-z0-9_]+$').hasMatch(text)) {
                    return 'Use lowercase letters, numbers and underscores';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                label: 'Label',
                hint: 'Scriptures reading',
                controller: _labelController,
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'A label is required'
                    : null,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                label: 'Description',
                hint: 'What the member should do in this section',
                controller: _descriptionController,
                maxLines: 3,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppDropdown<DailyDietBehaviour>(
                label: 'Behaviour',
                value: _behaviour,
                items: [
                  for (final b in DailyDietBehaviour.values)
                    DropdownMenuItem(
                      value: b,
                      child: Text('${b.label} — ${_behaviourHint(b)}'),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _behaviour = value);
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: _isNew ? 'Add section' : 'Save changes',
                icon: Icons.save_rounded,
                expand: true,
                busy: _saving,
                onPressed: _save,
              ),
              if (existing != null) ...[
                const SizedBox(height: AppSpacing.sm),
                _SectionActions(section: existing, year: widget.year),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Publish, archive and delete for one section.
class _SectionActions extends ConsumerWidget {
  const _SectionActions({required this.section, required this.year});

  final AdminDailyDietSection section;
  final int year;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(adminDailyDietControllerProvider);

    Future<void> run(Future<void> Function() action, String done) async {
      try {
        await action();
        if (!context.mounted) return;
        Toast.show(context, message: done, tone: ToastTone.success);
      } catch (error) {
        if (!context.mounted) return;
        Toast.show(
          context,
          message: _messageFor(error),
          tone: ToastTone.error,
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!section.isPublished)
          AppButton(
            label: 'Publish section',
            icon: Icons.publish_rounded,
            variant: AppButtonVariant.outlined,
            expand: true,
            onPressed: () => run(
              () => controller.publishSection(section.id, year),
              'Section published',
            ),
          ),
        if (section.isPublished) ...[
          AppButton(
            label: 'Archive section',
            icon: Icons.archive_outlined,
            variant: AppButtonVariant.outlined,
            expand: true,
            onPressed: () => run(
              () => controller.archiveSection(section.id, year),
              'Section archived',
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          AppButton(
            label: 'Delete section',
            icon: Icons.delete_outline_rounded,
            variant: AppButtonVariant.danger,
            expand: true,
            onPressed: () async {
              final confirmed = await confirmDialog(
                context,
                title: 'Delete this section?',
                message:
                    'The section and every day of content written under it '
                    'will be removed. Members will no longer see it.',
              );
              if (!confirmed || !context.mounted) return;
              await run(
                () => controller.deleteSection(section.id, year),
                'Section deleted',
              );
            },
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Day content
// ---------------------------------------------------------------------------

/// What each section carries on one day.
class _ContentTab extends ConsumerWidget {
  const _ContentTab({
    required this.year,
    required this.date,
    required this.onDate,
  });

  final int year;
  final DateTime date;
  final ValueChanged<DateTime> onDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateISO = dailyDietDateISO(date);
    final sectionsAsync = ref.watch(adminDailyDietSectionsProvider(year));
    final contentAsync = ref.watch(
      adminDailyDietContentProvider((year: year, month: null, date: dateISO)),
    );

    return sectionsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: CardListSkeleton(count: 5),
      ),
      error: (error, _) => ErrorState(
        error: error,
        onRetry: () => ref.invalidate(adminDailyDietSectionsProvider(year)),
      ),
      data: (sections) {
        if (sections.isEmpty) {
          return Padding(
            padding: adminPadding(context),
            child: AppCard(
              child: EmptyState(
                icon: Icons.view_list_rounded,
                title: 'No structure yet',
                message:
                    'Add the sections first, then come back to fill in what '
                    'each one carries on a given day.',
              ),
            ),
          );
        }

        final content = contentAsync.value ?? const <AdminDailyDietContent>[];
        // A date can be covered by a day row, a week row and a month row for
        // the same section; the closest scope is the one members see.
        final bySection = <String, List<AdminDailyDietContent>>{};
        for (final row in content) {
          bySection.putIfAbsent(row.sectionId, () => []).add(row);
        }

        return ListView(
          padding: adminPadding(context),
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppDateField(
                    label: 'Date',
                    value: date,
                    firstDate: DateTime(date.year - 1),
                    lastDate: DateTime(date.year + 1),
                    onChanged: (value) {
                      if (value != null) onDate(value);
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Content written for a day applies to that day. Content '
                    'written for a week applies to every day of the week, '
                    'and content written for a month applies to every day of '
                    'the month — the closest one wins.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.inkMuted,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: 'Publish this day',
                    icon: Icons.publish_rounded,
                    expand: true,
                    onPressed: () async {
                      try {
                        final count = await ref
                            .read(adminDailyDietControllerProvider)
                            .publishDay(dateISO, year);
                        if (!context.mounted) return;
                        Toast.show(
                          context,
                          message: '$count row(s) published',
                          tone: ToastTone.success,
                        );
                      } catch (error) {
                        if (!context.mounted) return;
                        Toast.show(
                          context,
                          message: _messageFor(error),
                          tone: ToastTone.error,
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            SectionHeader(
              title: 'Content for ${DateFormat('d MMM yyyy').format(date)}',
              icon: Icons.event_note_rounded,
              subtitle: '${sections.length} section(s)',
            ),
            for (final section in sections)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _ContentRow(
                  section: section,
                  rows: bySection[section.id] ?? const [],
                  onTap: () => _openContentEditor(
                    context,
                    year: year,
                    section: section,
                    dateISO: dateISO,
                    rows: bySection[section.id] ?? const [],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// One section's content for the selected day.
class _ContentRow extends StatelessWidget {
  const _ContentRow({
    required this.section,
    required this.rows,
    required this.onTap,
  });

  final AdminDailyDietSection section;

  /// The rows that cover this day: a day row, a week row and/or a month row.
  final List<AdminDailyDietContent> rows;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = _effectiveContent(rows);

    return AppCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: dailyDietTint(section.key),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              dailyDietIconFor(section.key),
              size: 19,
              color: AppColors.iconAccent,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  section.label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  content == null
                      ? 'Nothing written for this day'
                      : '${content.scope.label} — ${content.title}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: content == null
                        ? AppColors.inkMuted
                        : AppColors.inkSecondary,
                  ),
                ),
                if (content != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: 2,
                    children: [
                      StatusBadge(
                        label: content.isPublished ? 'Published' : content.status,
                        tone: content.isPublished
                            ? AppBadgeTone.success
                            : AppBadgeTone.warning,
                        small: true,
                      ),
                      if (content.materialIds.isNotEmpty)
                        StatusBadge(
                          label: '${content.materialIds.length} file(s)',
                          tone: AppBadgeTone.info,
                          small: true,
                        ),
                      if (content.durationTargetMinutes != null)
                        StatusBadge(
                          label: '${content.durationTargetMinutes} min target',
                          tone: AppBadgeTone.navy,
                          small: true,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: AppColors.inkMuted,
          ),
        ],
      ),
    );
  }
}

/// The row members actually see: the closest scope wins.
AdminDailyDietContent? _effectiveContent(List<AdminDailyDietContent> rows) {
  for (final scope in DailyDietScope.values) {
    for (final row in rows) {
      if (row.scope == scope) return row;
    }
  }
  return null;
}

/// Open the content editor for one section on one day.
Future<void> _openContentEditor(
  BuildContext context, {
  required int year,
  required AdminDailyDietSection section,
  required String dateISO,
  required List<AdminDailyDietContent> rows,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _ContentEditorSheet(
      year: year,
      section: section,
      dateISO: dateISO,
      rows: rows,
    ),
  );
}

/// The form that writes what a section carries on a day.
class _ContentEditorSheet extends ConsumerStatefulWidget {
  const _ContentEditorSheet({
    required this.year,
    required this.section,
    required this.dateISO,
    this.rows = const [],
  });

  final int year;
  final AdminDailyDietSection section;
  final String dateISO;

  /// Every row that covers the day, so the form can switch between the day,
  /// the week and the month version of this section.
  final List<AdminDailyDietContent> rows;

  @override
  ConsumerState<_ContentEditorSheet> createState() =>
      _ContentEditorSheetState();
}

class _ContentEditorSheetState extends ConsumerState<_ContentEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  late final TextEditingController _durationController;
  late final TextEditingController _urlController;
  late final List<TextEditingController> _detailTextControllers;
  late final List<TextEditingController> _detailLinesControllers;
  late DailyDietScope _scope;
  late List<String> _materialIds;
  late Map<String, dynamic> _existingDetails;
  bool _saving = false;

  AdminDailyDietSection get section => widget.section;

  /// The single-line extra fields this section owns.
  List<({String key, String label})> get _textFields =>
      _detailTextFields[section.key] ?? const [];

  /// The multi-line extra fields this section owns.
  List<({String key, String label})> get _linesFields =>
      _detailLinesFields[section.key] ?? const [];

  /// The stored row for a scope, if the admin has written one.
  AdminDailyDietContent? _rowFor(DailyDietScope scope) {
    for (final row in widget.rows) {
      if (row.scope == scope) return row;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _bodyController = TextEditingController();
    _durationController = TextEditingController();
    _urlController = TextEditingController();
    _detailTextControllers = [
      for (final _ in _textFields) TextEditingController(),
    ];
    _detailLinesControllers = [
      for (final _ in _linesFields) TextEditingController(),
    ];

    // Start on the scope that already has content, else on the day itself.
    var scope = DailyDietScope.day;
    for (final candidate in DailyDietScope.values) {
      if (_rowFor(candidate) != null) {
        scope = candidate;
        break;
      }
    }
    _scope = scope;
    _materialIds = [];
    _existingDetails = <String, dynamic>{};
    _loadScope(scope);
  }

  /// Repopulates the form from the row stored for [scope].
  void _loadScope(DailyDietScope scope) {
    final row = _rowFor(scope);
    final details = row?.details ?? const <String, dynamic>{};
    final textFields = _textFields;
    final linesFields = _linesFields;

    setState(() {
      _scope = scope;
      _titleController.text = row?.title ?? section.label;
      _bodyController.text = row?.body ?? '';
      _durationController.text = row?.durationTargetMinutes?.toString() ?? '';
      _urlController.text = row?.externalUrl ?? '';
      _materialIds = [...?row?.materialIds];
      _existingDetails = Map<String, dynamic>.from(details);
      for (var i = 0; i < textFields.length; i++) {
        _detailTextControllers[i].text =
            (details[textFields[i].key]?.toString() ?? '');
      }
      for (var i = 0; i < linesFields.length; i++) {
        _detailLinesControllers[i].text =
            _linesToText(details[linesFields[i].key]);
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _durationController.dispose();
    _urlController.dispose();
    for (final controller in _detailTextControllers) {
      controller.dispose();
    }
    for (final controller in _detailLinesControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic> _buildDetails() {
    // Keep whatever else the content carries (the reading plan's heading and
    // focus, for instance) and only override the fields this form owns.
    final details = Map<String, dynamic>.from(_existingDetails);
    final textFields = _textFields;
    for (var i = 0; i < textFields.length; i++) {
      final value = _detailTextControllers[i].text.trim();
      if (value.isNotEmpty) {
        details[textFields[i].key] = value;
      } else {
        details.remove(textFields[i].key);
      }
    }
    final linesFields = _linesFields;
    for (var i = 0; i < linesFields.length; i++) {
      final field = linesFields[i];
      final lines = _detailLinesControllers[i].text
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      if (lines.isNotEmpty) {
        details[field.key] = field.key == 'books'
            ? lines.map(_bookFromLine).toList()
            : lines;
      } else {
        details.remove(field.key);
      }
    }
    return details;
  }

  Future<void> _save({bool publish = true}) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final controller = ref.read(adminDailyDietControllerProvider);
    try {
      await controller.saveContent(
        year: widget.year,
        sectionId: section.id,
        date: widget.dateISO,
        scope: _scope,
        title: _titleController.text.trim(),
        body: _bodyController.text.trim(),
        details: _buildDetails(),
        materialIds: _materialIds,
        externalUrl: _urlController.text.trim().isEmpty
            ? null
            : _urlController.text.trim(),
        durationTargetMinutes:
            int.tryParse(_durationController.text.trim()),
        status: publish ? 'PUBLISHED' : 'DRAFT',
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      Toast.show(
        context,
        message: publish ? 'Content published' : 'Draft saved',
        tone: ToastTone.success,
      );
    } catch (error) {
      if (!mounted) return;
      Toast.show(
        context,
        message: _messageFor(error),
        tone: ToastTone.error,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                section.label,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                DateFormat('d MMMM yyyy').format(DateTime.parse(widget.dateISO)),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.inkMuted,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppDropdown<DailyDietScope>(
                label: 'Applies to',
                value: _scope,
                items: [
                  for (final s in DailyDietScope.values)
                    DropdownMenuItem(
                      value: s,
                      child: Text(s.label),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) _loadScope(value);
                },
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                _scopeHint(_scope, widget.dateISO),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.inkMuted,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                label: 'Title',
                controller: _titleController,
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'A title is required'
                    : null,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                label: 'Body',
                hint: 'What the member reads or does',
                controller: _bodyController,
                maxLines: 5,
              ),
              for (var i = 0; i < _textFields.length; i++) ...[
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  label: _textFields[i].label,
                  controller: _detailTextControllers[i],
                ),
              ],
              for (var i = 0; i < _linesFields.length; i++) ...[
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  label: _linesFields[i].label,
                  controller: _detailLinesControllers[i],
                  maxLines: 6,
                ),
              ],              if (section.behaviour == DailyDietBehaviour.timer) ...[
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  label: 'Prayer duration target (minutes)',
                  controller: _durationController,
                  keyboardType: TextInputType.number,
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                label: 'Link (optional)',
                hint: 'https://',
                controller: _urlController,
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: AppSpacing.md),
              _MaterialPicker(
                selected: _materialIds,
                onChanged: (ids) => setState(() => _materialIds = ids),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: 'Save and publish',
                icon: Icons.publish_rounded,
                expand: true,
                busy: _saving,
                onPressed: () => _save(publish: true),
              ),
              const SizedBox(height: AppSpacing.xs),
              AppButton(
                label: 'Save as draft',
                icon: Icons.save_outlined,
                variant: AppButtonVariant.outlined,
                expand: true,
                onPressed: _saving ? null : () => _save(publish: false),
              ),
              if (_rowFor(_scope) != null) ...[
                const SizedBox(height: AppSpacing.sm),
                AppButton(
                  label: 'Delete this content',
                  icon: Icons.delete_outline_rounded,
                  variant: AppButtonVariant.danger,
                  expand: true,
                  onPressed: () async {
                    final row = _rowFor(_scope);
                    if (row == null) return;
                    final confirmed = await confirmDialog(
                      context,
                      title: 'Delete this content?',
                      message:
                          'Members will fall back to the weekly or monthly '
                          'content for this section.',
                    );
                    if (!confirmed || !context.mounted) return;
                    try {
                      await ref
                          .read(adminDailyDietControllerProvider)
                          .deleteContent(row.id, widget.year);
                      if (!context.mounted) return;
                      Navigator.of(context).pop();
                      Toast.show(
                        context,
                        message: 'Content deleted',
                        tone: ToastTone.success,
                      );
                    } catch (error) {
                      if (!context.mounted) return;
                      Toast.show(
                        context,
                        message: _messageFor(error),
                        tone: ToastTone.error,
                      );
                    }
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Choose the library files attached to a section.
class _MaterialPicker extends ConsumerStatefulWidget {
  const _MaterialPicker({required this.selected, required this.onChanged});

  final List<String> selected;
  final ValueChanged<List<String>> onChanged;

  @override
  ConsumerState<_MaterialPicker> createState() => _MaterialPickerState();
}

class _MaterialPickerState extends ConsumerState<_MaterialPicker> {
  int _page = 1;
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final materialsAsync = ref.watch(
      adminMaterialsProvider(
        (page: _page, search: _search, status: 'PUBLISHED', category: ''),
      ),
    );

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Attached files',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              if (widget.selected.isNotEmpty)
                StatusBadge(
                  label: '${widget.selected.length}',
                  tone: AppBadgeTone.info,
                  small: true,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          AppTextField(
            label: 'Search the library',
            hint: 'Title or author',
            onChanged: (value) {
              setState(() {
                _search = value;
                _page = 1;
              });
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          materialsAsync.when(
            loading: () => const SkeletonBox(height: 60),
            error: (error, _) => ErrorState(
              error: error,
              compact: true,
              onRetry: () => ref.invalidate(adminMaterialsProvider(
                (page: _page, search: _search, status: 'PUBLISHED', category: ''),
              )),
            ),
            data: (result) {
              if (result.items.isEmpty) {
                return Text(
                  'No published materials found.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.inkMuted,
                      ),
                );
              }
              return Column(
                children: [
                  for (final material in result.items)
                    _MaterialOption(
                      material: material,
                      selected: widget.selected.contains(material.id),
                      onToggle: () {
                        final next = [...widget.selected];
                        if (next.contains(material.id)) {
                          next.remove(material.id);
                        } else {
                          next.add(material.id);
                        }
                        widget.onChanged(next);
                      },
                    ),
                  if (result.totalPages > 1) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          tooltip: 'Previous page',
                          icon: const Icon(Icons.chevron_left_rounded),
                          onPressed: _page > 1
                              ? () => setState(() => _page = _page - 1)
                              : null,
                        ),
                        Text('$_page of ${result.totalPages}'),
                        IconButton(
                          tooltip: 'Next page',
                          icon: const Icon(Icons.chevron_right_rounded),
                          onPressed: _page < result.totalPages
                              ? () => setState(() => _page = _page + 1)
                              : null,
                        ),
                      ],
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// One library material with a checkbox.
class _MaterialOption extends StatelessWidget {
  const _MaterialOption({
    required this.material,
    required this.selected,
    required this.onToggle,
  });

  final MaterialItem material;
  final bool selected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.check_box_rounded
                  : Icons.check_box_outline_blank_rounded,
              size: 20,
              color: selected ? AppColors.success : AppColors.inkMuted,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    material.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    [
                      material.category,
                      if (material.author != null && material.author!.isNotEmpty)
                        material.author!,
                    ].join(' • '),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Single-line extra fields, per section key.
const _detailTextFields = <String, List<({String key, String label})>>{
  'scripture_reading': [
    (key: 'reading', label: 'Scripture reading'),
    (key: 'heading', label: 'Book being read'),
    (key: 'focus', label: 'Focus for the month'),
    (key: 'note', label: 'Note'),
  ],
  'prayer': [
    (key: 'monthlyFocus', label: 'Prayer focus'),
  ],
  'fasting_and_prayer': [
    (key: 'guidance', label: 'Fasting guidance'),
  ],
  'proverbs_reading': [
    (key: 'proverb', label: 'Proverb'),
  ],
  'bible_study': [
    (key: 'topic', label: 'Study topic'),
  ],
};

/// Multi-line extra fields, one entry per line, per section key.
const _detailLinesFields = <String, List<({String key, String label})>>{
  'bible_study': [
    (key: 'teachings', label: 'Teachings (one per line)'),
  ],
  'declarations': [
    (key: 'declarations', label: 'Declarations (one per line)'),
  ],
  'audio_message': [
    (key: 'messages', label: 'Audio messages (one per line)'),
  ],
  'report': [
    (key: 'questions', label: 'Report questions (one per line)'),
  ],
  'music': [
    (key: 'songs', label: 'Songs (one per line)'),
  ],
  'literature_reading': [
    (key: 'books', label: 'Books — "Title | Author" (one per line)'),
  ],
};

/// Renders a stored detail list back into the editable text form.
String _linesToText(dynamic value) {
  if (value is List) {
    return value
        .map((entry) {
          if (entry is Map) {
            final title = (entry['title'] ?? '').toString();
            final author = (entry['author'] ?? '').toString();
            if (author.isEmpty) return title;
            return '$title | $author';
          }
          return entry.toString();
        })
        .join('\n');
  }
  if (value is Map) {
    final title = (value['title'] ?? '').toString();
    final author = (value['author'] ?? '').toString();
    if (author.isEmpty) return title;
    return '$title | $author';
  }
  if (value == null) return '';
  return value.toString();
}

/// The date a row of the given scope is filed against: the day itself, the
/// Sunday that starts its week, or the first of its month.
DateTime _scopeAnchor(DailyDietScope scope, String dateISO) {
  final date = DateTime.parse(dateISO);
  switch (scope) {
    case DailyDietScope.week:
      return date.subtract(Duration(days: date.weekday - DateTime.sunday));
    case DailyDietScope.month:
      return DateTime(date.year, date.month, 1);
    case DailyDietScope.day:
      return date;
  }
}

/// Explains where the content lands and who will see it.
String _scopeHint(DailyDietScope scope, String dateISO) {
  final anchor = _scopeAnchor(scope, dateISO);
  final stamp = DateFormat('d MMM yyyy').format(anchor);
  return switch (scope) {
    DailyDietScope.day => 'Only this day is affected.',
    DailyDietScope.week =>
      'Saved for the week starting Sunday $stamp — every day that week sees it.',
    DailyDietScope.month =>
      'Saved for the month from $stamp — every day that month sees it.',
  };
}

/// Parses a "Title | Author" line into the stored book shape.
Map<String, dynamic> _bookFromLine(String line) {  final parts = line.split('|');
  if (parts.length < 2) return {'title': parts.first.trim()};
  return {
    'title': parts.first.trim(),
    'author': parts.sublist(1).join('|').trim(),
  };
}

/// A short hint for a behaviour.
String _behaviourHint(DailyDietBehaviour behaviour) => switch (behaviour) {
      DailyDietBehaviour.text => 'the member reads it and marks it done',
      DailyDietBehaviour.material => 'the member opens the attached files',
      DailyDietBehaviour.timer => 'the member times their prayer',
      DailyDietBehaviour.tick => 'the member ticks it',
      DailyDietBehaviour.report => 'the member writes or uploads a report',
      DailyDietBehaviour.partner => 'it points to the prayer room',
    };

/// Turns an API failure into a short, human message.
String _messageFor(Object error) {
  if (error is ApiException) return error.message;
  return 'Something went wrong. Please try again.';
}
