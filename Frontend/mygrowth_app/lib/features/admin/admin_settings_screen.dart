import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/appearance_section.dart';
import '../../core/widgets/app_buttons.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/feedback_states.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/toast.dart';
import 'admin_providers.dart';
import 'admin_shared.dart';

/// Settings: the small, safe set of ministry preferences the backend allows.
///
/// Keys are locked to the server's allow-list — the endpoint can only ever
/// change registration, goal and announcement-notification preferences.
class AdminSettingsScreen extends ConsumerWidget {
  const AdminSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const _SettingsBody();
  }
}

class _SettingsBody extends ConsumerStatefulWidget {
  const _SettingsBody();

  @override
  ConsumerState<_SettingsBody> createState() => _SettingsBodyState();
}

class _SettingsBodyState extends ConsumerState<_SettingsBody> {
  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(adminSettingsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(adminSettingsProvider);
        await Future<void>.delayed(const Duration(milliseconds: 300));
      },
      child: ListView(
        padding: adminPadding(context),
        children: [
          const SectionHeader(
            title: 'Settings',
            subtitle: 'Ministry-wide preferences',
            icon: Icons.settings_outlined,
          ),
          settings.when(
            loading: () => const CardListSkeleton(count: 3),
            error: (error, _) => ErrorState(
              error: error,
              onRetry: () => ref.invalidate(adminSettingsProvider),
            ),
            data: (data) {
              final values = asJsonMap(data['settings']);
              final allowed = (data['keys'] as List<dynamic>?)
                      ?.map((e) => e.toString())
                      .toList() ??
                  const <String>[];
              return _SettingsForm(
                initial: values,
                allowedKeys: allowed,
                onSaved: () => ref.invalidate(adminSettingsProvider),
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),

          // ------------------------------------------- appearance
          const SectionHeader(
            title: 'Appearance',
            subtitle: 'Choose the light or dark mood',
            icon: Icons.palette_outlined,
          ),
          const AppCard(child: AppearanceSection()),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

class _SettingsForm extends ConsumerStatefulWidget {
  const _SettingsForm({
    required this.initial,
    required this.allowedKeys,
    required this.onSaved,
  });

  final Map<String, dynamic> initial;
  final List<String> allowedKeys;
  final VoidCallback onSaved;

  @override
  ConsumerState<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends ConsumerState<_SettingsForm> {
  static const _approvalKey = 'registration.approvalRequired';
  static const _maxGoalsKey = 'goals.maxMonthlySuggested';
  static const _allowExtraKey = 'goals.allowExtra';
  static const _notifyKey = 'announcements.notifyOnPublish';

  late bool _approvalRequired = _bool(_approvalKey, fallback: true);
  late bool _allowExtra = _bool(_allowExtraKey, fallback: true);
  late bool _notifyOnPublish = _bool(_notifyKey, fallback: true);
  late final TextEditingController _maxGoals = TextEditingController(
    text: '${_int(_maxGoalsKey) ?? 5}',
  );
  bool _saving = false;

  bool _bool(String key, {required bool fallback}) {
    final value = widget.initial[key];
    return value is bool ? value : fallback;
  }

  int? _int(String key) {
    final value = widget.initial[key];
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  @override
  void dispose() {
    _maxGoals.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final maxGoals = int.tryParse(_maxGoals.text.trim());
    if (maxGoals == null || maxGoals < 1 || maxGoals > 10) {
      Toast.error(context, 'Suggested goals per month must be between 1 and 10.');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(apiClientProvider).patch('/admin/settings', body: {
        _approvalKey: _approvalRequired,
        _maxGoalsKey: maxGoals,
        _allowExtraKey: _allowExtra,
        _notifyKey: _notifyOnPublish,
      });
      if (!mounted) return;
      widget.onSaved();
      Toast.success(context, 'Settings saved.');
    } on ApiException catch (e) {
      if (!mounted) return;
      Toast.error(context, e.fieldError ?? e.message);
    } catch (_) {
      if (!mounted) return;
      Toast.error(context, 'Couldn’t save settings just now.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Membership & registration',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.xs),
              AppSwitchRow(
                label: 'Require approval for new members',
                subtitle:
                    'New sign-ups wait for an administrator to approve them.',
                value: _approvalRequired,
                onChanged: (value) =>
                    setState(() => _approvalRequired = value),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Goals',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.xs),
              AppTextField(
                label: 'Suggested goals per month (1–10)',
                controller: _maxGoals,
                keyboardType: TextInputType.number,
                helper: 'Guidance shown when members set monthly goals.',
              ),
              const SizedBox(height: fieldGap),
              AppSwitchRow(
                label: 'Allow extra goals',
                subtitle: 'Members may exceed the suggested number.',
                value: _allowExtra,
                onChanged: (value) => setState(() => _allowExtra = value),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Announcements',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.xs),
              AppSwitchRow(
                label: 'Notify members when an announcement is published',
                subtitle:
                    'Only applies to announcements for all members.',
                value: _notifyOnPublish,
                onChanged: (value) => setState(() => _notifyOnPublish = value),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AdminBanner(
          tone: AdminBannerTone.info,
          icon: Icons.info_outline_rounded,
          text: widget.allowedKeys.isEmpty
              ? 'Only these preferences can be changed here; roles and access '
                  'are managed in Admin Access Management.'
              : 'Editable keys: ${widget.allowedKeys.join(', ')}.',
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: 'Save settings',
          icon: Icons.save_outlined,
          expand: true,
          busy: _saving,
          onPressed: _save,
        ),
      ],
    );
  }
}
