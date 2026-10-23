import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

/// Administrator access management — **Main Admin only**.
///
/// Grants, suspends, reactivates and revokes administrator access, and creates
/// new (initially pending) administrator accounts. The backend is the real
/// security boundary; this screen mirrors its rules and explains them.
class AdminAccessScreen extends ConsumerWidget {
  const AdminAccessScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user?.isMainAdmin != true) {
      return const _NotMainAdmin();
    }
    return const _AccessBody();
  }
}

class _NotMainAdmin extends StatelessWidget {
  const _NotMainAdmin();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: adminPadding(context),
      children: const [
        SectionHeader(
          title: 'Admin Access Management',
          subtitle: 'Grant and revoke administrator access',
          icon: Icons.admin_panel_settings_outlined,
        ),
        AppCard(
          child: EmptyState(
            icon: Icons.lock_outline_rounded,
            title: 'Main Admin only',
            message:
                'Only the Main Admin can manage administrator access. If you '
                'believe you should have this permission, contact the Main '
                'Admin for the ministry.',
          ),
        ),
      ],
    );
  }
}

class _AccessBody extends ConsumerStatefulWidget {
  const _AccessBody();

  @override
  ConsumerState<_AccessBody> createState() => _AccessBodyState();
}

class _AccessBodyState extends ConsumerState<_AccessBody> {
  final Set<String> _busy = <String>{};

  static const _forbiddenMessage =
      'Only the Main Admin can manage administrator access.';

  void _report(Object error, {String fallback = 'Couldn’t update access just now.'}) {
    if (!mounted) return;
    if (error is ApiException) {
      if (error.isForbidden) {
        Toast.error(context, _forbiddenMessage);
        return;
      }
      Toast.error(context, error.fieldError ?? error.message);
      return;
    }
    Toast.error(context, fallback);
  }

  Future<void> _openCreateSheet() async {
    await showAdminSheet(
      context: context,
      builder: (_) => _CreateAdminSheet(
        onCreated: () => ref.invalidate(adminAdministratorsProvider),
      ),
    );
  }

  Future<void> _runAction(
    AdminAdministrator admin,
    String action, {
    required String successMessage,
    bool destructive = false,
  }) async {
    if (_busy.contains(admin.id)) return;
    if (destructive) {
      final confirmed = await confirmDialog(
        context,
        title: action == 'revoke'
            ? 'Revoke administrator access?'
            : 'Suspend administrator access?',
        message: action == 'revoke'
            ? '${admin.name} will immediately lose all administrative access. '
                'Their member account stays active.'
            : '${admin.name} will be signed out of the admin area and cannot '
                'use it until reactivated.',
        confirmLabel: action == 'revoke' ? 'Revoke' : 'Suspend',
        destructive: true,
      );
      if (!confirmed) return;
    }
    setState(() => _busy.add(admin.id));
    try {
      await ref.read(apiClientProvider).patch(
            '/admin/admins/${admin.id}/access',
            body: {'action': action},
          );
      if (!mounted) return;
      ref.invalidate(adminAdministratorsProvider);
      Toast.success(context, successMessage);
    } catch (error) {
      _report(error);
    } finally {
      if (mounted) setState(() => _busy.remove(admin.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final admins = ref.watch(adminAdministratorsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(adminAdministratorsProvider);
        await Future<void>.delayed(const Duration(milliseconds: 300));
      },
      child: ListView(
        padding: adminPadding(context),
        children: [
          const SectionHeader(
            title: 'Admin Access Management',
            subtitle: 'Grant and revoke administrator access',
            icon: Icons.admin_panel_settings_outlined,
          ),
          const AdminBanner(
            text: 'Administrator access is separate from membership. Suspending '
                'or revoking access signs the administrator out of the admin '
                'area immediately, but leaves their member account untouched.',
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              AppButton(
                label: 'Create administrator',
                icon: Icons.person_add_alt_1_rounded,
                onPressed: _openCreateSheet,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          admins.when(
            loading: () => const CardListSkeleton(count: 4),
            error: (error, _) => ErrorState(
              error: error,
              onRetry: () => ref.invalidate(adminAdministratorsProvider),
            ),
            data: (page) {
              if (page.items.isEmpty) {
                return AppCard(
                  child: EmptyState(
                    icon: Icons.admin_panel_settings_outlined,
                    title: 'No administrators yet',
                    message:
                        'Create an administrator account, then grant it access '
                        'when you are ready for it to sign in.',
                    actionLabel: 'Create administrator',
                    onAction: _openCreateSheet,
                  ),
                );
              }
              return Column(
                children: [
                  for (final admin in page.items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _AdminCard(
                        admin: admin,
                        busy: _busy.contains(admin.id),
                        onGrant: () => _runAction(
                          admin,
                          'grant',
                          successMessage: 'Administrator access granted.',
                        ),
                        onSuspend: () => _runAction(
                          admin,
                          'suspend',
                          successMessage: 'Administrator access suspended.',
                          destructive: true,
                        ),
                        onReactivate: () => _runAction(
                          admin,
                          'reactivate',
                          successMessage: 'Administrator access reactivated.',
                        ),
                        onRevoke: () => _runAction(
                          admin,
                          'revoke',
                          successMessage: 'Administrator access revoked.',
                          destructive: true,
                        ),
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

class _AdminCard extends StatelessWidget {
  const _AdminCard({
    required this.admin,
    required this.busy,
    required this.onGrant,
    required this.onSuspend,
    required this.onReactivate,
    required this.onRevoke,
  });

  final AdminAdministrator admin;
  final bool busy;
  final VoidCallback onGrant;
  final VoidCallback onSuspend;
  final VoidCallback onReactivate;
  final VoidCallback onRevoke;

  AppBadgeTone get _accessTone => switch (admin.status) {
        'ACTIVE' => AppBadgeTone.success,
        'SUSPENDED' => AppBadgeTone.warning,
        'REVOKED' => AppBadgeTone.danger,
        _ => AppBadgeTone.neutral,
      };

  String get _accessLabel => switch (admin.status) {
        'ACTIVE' => 'Access active',
        'SUSPENDED' => 'Access suspended',
        'REVOKED' => 'Access revoked',
        'PENDING_GRANT' => 'Awaiting grant',
        _ => humanizeStatus(admin.status),
      };

  @override
  Widget build(BuildContext context) {
    final mainAdmin = admin.isProtectedMainAdmin;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InitialsAvatar(name: admin.name.isEmpty ? admin.email : admin.name),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      admin.name.isEmpty ? 'Unnamed administrator' : admin.name,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      admin.email,
                      style: Theme.of(context).textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xxs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        StatusBadge(
                          label: mainAdmin ? 'Main Admin' : 'Administrator',
                          tone: mainAdmin
                              ? AppBadgeTone.navy
                              : AppBadgeTone.gold,
                          small: true,
                        ),
                        StatusBadge(
                          label: _accessLabel,
                          tone: _accessTone,
                          small: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            [
              'Added ${fmtDate(admin.createdAt)}',
              if (admin.createdByName != null &&
                  admin.createdByName!.trim().isNotEmpty)
                'by ${admin.createdByName}',
              if (admin.lastActivityAt != null)
                'Last sign-in ${fmtDateTime(admin.lastActivityAt)}',
            ].join(' · '),
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (mainAdmin)
            const AdminBanner(
              tone: AdminBannerTone.navy,
              icon: Icons.verified_user_outlined,
              text: 'This is the Main Admin account. The Main Admin’s own '
                  'access cannot be suspended or revoked here.',
            )
          else
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                if (admin.canGrant)
                  AppButton(
                    label: 'Grant access',
                    icon: Icons.check_circle_outline_rounded,
                    variant: AppButtonVariant.filled,
                    busy: busy,
                    onPressed: onGrant,
                  ),
                if (admin.canReactivate)
                  AppButton(
                    label: 'Reactivate',
                    icon: Icons.restart_alt_rounded,
                    variant: AppButtonVariant.filled,
                    busy: busy,
                    onPressed: onReactivate,
                  ),
                if (admin.canSuspend)
                  AppButton(
                    label: 'Suspend',
                    icon: Icons.pause_circle_outline_rounded,
                    variant: AppButtonVariant.outlined,
                    busy: busy,
                    onPressed: onSuspend,
                  ),
                if (admin.canRevoke)
                  AppButton(
                    label: 'Revoke',
                    icon: Icons.block_rounded,
                    variant: AppButtonVariant.danger,
                    busy: busy,
                    onPressed: onRevoke,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _CreateAdminSheet extends ConsumerStatefulWidget {
  const _CreateAdminSheet({required this.onCreated});

  final VoidCallback onCreated;

  @override
  ConsumerState<_CreateAdminSheet> createState() => _CreateAdminSheetState();
}

class _CreateAdminSheetState extends ConsumerState<_CreateAdminSheet> {
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;
    final firstName = _firstName.text.trim();
    final lastName = _lastName.text.trim();
    final email = _email.text.trim();
    final password = _password.text;
    if (firstName.isEmpty || lastName.isEmpty) {
      Toast.error(context, 'Enter the administrator’s first and last name.');
      return;
    }
    if (email.isEmpty) {
      Toast.error(context, 'Enter an email address for the administrator.');
      return;
    }
    if (password.length < 8) {
      Toast.error(context, 'Choose a password of at least 8 characters.');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(apiClientProvider).post(
            '/admin/admins',
            body: {
              'firstName': firstName,
              'lastName': lastName,
              'email': email,
              'password': password,
            },
          );
      if (!mounted) return;
      widget.onCreated();
      Navigator.of(context).pop();
      Toast.success(
        context,
        'Administrator created. Grant access when you’re ready for them to '
        'sign in.',
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.isForbidden) {
        Toast.error(context, 'Only the Main Admin can manage administrator access.');
      } else {
        Toast.error(context, e.fieldError ?? e.message);
      }
    } catch (_) {
      if (!mounted) return;
      Toast.error(context, 'Couldn’t create that administrator just now.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Create administrator',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'The new account starts with no administrative access — grant it '
          'here once you are ready.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          label: 'First name',
          controller: _firstName,
          textCapitalization: TextCapitalization.words,
          enabled: !_saving,
        ),
        const SizedBox(height: fieldGap),
        AppTextField(
          label: 'Last name',
          controller: _lastName,
          textCapitalization: TextCapitalization.words,
          enabled: !_saving,
        ),
        const SizedBox(height: fieldGap),
        AppTextField(
          label: 'Email',
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          prefixIcon: Icons.mail_outline_rounded,
          enabled: !_saving,
        ),
        const SizedBox(height: fieldGap),
        AppTextField(
          label: 'Temporary password',
          controller: _password,
          helper: 'At least 8 characters. Share it securely.',
          obscure: true,
          enabled: !_saving,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: 'Create administrator',
          icon: Icons.person_add_alt_1_rounded,
          expand: true,
          busy: _saving,
          onPressed: _submit,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Administrator accounts are managed by the Main Admin.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.inkMuted,
              ),
        ),
      ],
    );
  }
}
