import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_controller.dart';
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
import 'admin_models.dart';
import 'admin_providers.dart';
import 'admin_shared.dart';

/// Activity Management: the standard activity categories, plus a pointer to
/// where dated daily activities are authored.
class AdminActivitiesScreen extends ConsumerWidget {
  const AdminActivitiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const _ActivitiesBody();
  }
}

class _ActivitiesBody extends ConsumerStatefulWidget {
  const _ActivitiesBody();

  @override
  ConsumerState<_ActivitiesBody> createState() => _ActivitiesBodyState();
}

class _ActivitiesBodyState extends ConsumerState<_ActivitiesBody> {
  Future<void> _openEditor(AdminActivityCategory category) async {
    await showAdminSheet(
      context: context,
      builder: (_) => _CategorySheet(category: category),
    );
    if (mounted) ref.invalidate(adminActivityCategoriesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(adminActivityCategoriesProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(adminActivityCategoriesProvider);
        await Future<void>.delayed(const Duration(milliseconds: 300));
      },
      child: ListView(
        padding: adminPadding(context),
        children: [
          const SectionHeader(
            title: 'Activity Management',
            subtitle: 'Configure the activity categories used across the plan',
            icon: Icons.checklist_outlined,
          ),
          AdminBanner(
            tone: AdminBannerTone.navy,
            icon: Icons.view_week_outlined,
            text:
                'These are the category labels members see. Dated daily '
                'activities (prayer, reading, fasting…) are authored under '
                'Weekly & Daily Plans for each programme month.',
          ),
          const SizedBox(height: AppSpacing.xs),
          Align(
            alignment: Alignment.centerLeft,
            child: AppButton(
              label: 'Open Weekly & Daily Plans',
              icon: Icons.open_in_new_rounded,
              variant: AppButtonVariant.outlined,
              onPressed: () => context.go('/admin/weekly-plans'),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          categories.when(
            loading: () => const CardListSkeleton(count: 6),
            error: (error, _) => ErrorState(
              error: error,
              onRetry: () => ref.invalidate(adminActivityCategoriesProvider),
            ),
            data: (items) {
              if (items.isEmpty) {
                return const AppCard(
                  child: EmptyState(
                    icon: Icons.checklist_outlined,
                    title: 'No activity categories',
                    message:
                        'The server returned no activity categories. They may '
                        'not have been seeded yet.',
                  ),
                );
              }
              final sorted = [...items]
                ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
              return Column(
                children: [
                  for (final category in sorted)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _CategoryCard(
                        category: category,
                        onEdit: () => _openEditor(category),
                        onChanged: () =>
                            ref.invalidate(adminActivityCategoriesProvider),
                      ),
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

class _CategoryCard extends ConsumerStatefulWidget {
  const _CategoryCard({
    required this.category,
    required this.onEdit,
    required this.onChanged,
  });

  final AdminActivityCategory category;
  final VoidCallback onEdit;
  final VoidCallback onChanged;

  @override
  ConsumerState<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends ConsumerState<_CategoryCard> {
  bool _busy = false;

  Future<void> _toggle(bool enabled) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(apiClientProvider)
          .patch('/admin/activity-categories/${widget.category.key}',
              body: {'enabled': enabled});
      if (!mounted) return;
      widget.onChanged();
      Toast.success(
        context,
        enabled ? 'Category enabled.' : 'Category disabled.',
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      Toast.error(context, e.fieldError ?? e.message);
    } catch (_) {
      if (!mounted) return;
      Toast.error(context, 'Couldn’t update this category just now.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.category;
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.navy50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.category_outlined,
                size: 21, color: AppColors.navy700),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        c.displayLabel,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    StatusBadge(
                      label: c.enabled ? 'Enabled' : 'Disabled',
                      tone:
                          c.enabled ? AppBadgeTone.success : AppBadgeTone.neutral,
                      small: true,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'key: ${c.key}${c.sortOrder != 0 ? ' · order ${c.sortOrder}' : ''}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                if (c.description != null && c.description!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    c.description!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: AppSpacing.xs),
                AppButton(
                  label: 'Edit category',
                  icon: Icons.edit_outlined,
                  variant: AppButtonVariant.outlined,
                  onPressed: widget.onEdit,
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: c.enabled,
            onChanged: _busy ? null : _toggle,
          ),
        ],
      ),
    );
  }
}

class _CategorySheet extends ConsumerStatefulWidget {
  const _CategorySheet({required this.category});

  final AdminActivityCategory category;

  @override
  ConsumerState<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends ConsumerState<_CategorySheet> {
  late final TextEditingController _label =
      TextEditingController(text: widget.category.label);
  late final TextEditingController _description =
      TextEditingController(text: widget.category.description ?? '');
  late final TextEditingController _sortOrder =
      TextEditingController(text: '${widget.category.sortOrder}');
  late bool _enabled = widget.category.enabled;
  bool _saving = false;

  @override
  void dispose() {
    _label.dispose();
    _description.dispose();
    _sortOrder.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_label.text.trim().isEmpty) {
      Toast.error(context, 'Give the category a label.');
      return;
    }
    setState(() => _saving = true);
    final body = <String, dynamic>{
      'label': _label.text.trim(),
      'description': _nullIfEmpty(_description.text),
      'enabled': _enabled,
    };
    final order = int.tryParse(_sortOrder.text.trim());
    if (order != null) body['sortOrder'] = order;
    try {
      await ref
          .read(apiClientProvider)
          .patch('/admin/activity-categories/${widget.category.key}', body: body);
      if (!mounted) return;
      Toast.success(context, 'Category saved.');
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      Toast.error(context, e.fieldError ?? e.message);
    } catch (_) {
      if (!mounted) return;
      Toast.error(context, 'Couldn’t save this category just now.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Edit ${widget.category.displayLabel}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'key: ${widget.category.key}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          label: 'Label',
          controller: _label,
          required: true,
        ),
        const SizedBox(height: fieldGap),
        AppTextField(
          label: 'Description',
          controller: _description,
          maxLines: 3,
        ),
        const SizedBox(height: fieldGap),
        AppTextField(
          label: 'Sort order',
          controller: _sortOrder,
          keyboardType: TextInputType.number,
          helper: 'Lower numbers appear first.',
        ),
        const SizedBox(height: fieldGap),
        AppSwitchRow(
          label: 'Enabled',
          subtitle: 'Disabled categories stay on record but are hidden.',
          value: _enabled,
          onChanged: (value) => setState(() => _enabled = value),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: 'Save category',
          icon: Icons.save_outlined,
          expand: true,
          busy: _saving,
          onPressed: _save,
        ),
        const SizedBox(height: AppSpacing.xs),
        AppButton(
          label: 'Cancel',
          variant: AppButtonVariant.text,
          expand: true,
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

String? _nullIfEmpty(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
