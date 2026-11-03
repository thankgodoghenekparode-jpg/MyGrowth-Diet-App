import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/appearance_section.dart';
import '../../core/widgets/app_badge.dart';
import '../../core/widgets/app_buttons.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/toast.dart';
import '../notifications/notification_prefs_section.dart';

/// Profile & settings: personal details, notification preferences, privacy
/// notes and account actions.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final api = ref.read(apiClientProvider);
    final avatarUrl = user?.avatarUrl;
    final isAdminArea =
        GoRouterState.of(context).uri.path.startsWith('/admin');

    return Scaffold(
      appBar: AppBar(title: const Text('Profile & Settings')),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(authControllerProvider.notifier).refreshUser();
          ref.invalidate(notificationPrefsProvider);
          await Future<void>.delayed(const Duration(milliseconds: 200));
        },
        child: ListView(
          padding: Breakpoints.isCompact(context)
              ? AppSpacing.pagePaddingMobile
              : const EdgeInsets.all(AppSpacing.xl),
          children: [
            // --------------------------------------------- identity card
            AppCard(
              child: Row(
                children: [
                  GestureDetector(
                    onTap: user == null ? null : () => _changeAvatar(context, ref),
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: AppColors.avatarBg,
                          backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                              ? NetworkImage(
                                  _resolveAvatarUrl(avatarUrl, api.baseUrl),
                                  headers: api.accessToken == null
                                      ? null
                                      : {'Authorization': 'Bearer ${api.accessToken}'},
                                )
                              : null,
                          child: (user?.avatarUrl == null || user!.avatarUrl!.isEmpty)
                              ? Text(
                                  user?.initials ?? '?',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                  ),
                                )
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: AppColors.navy700,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.name ?? 'Member',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        if (user != null)
                          Text(
                            user.email,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        const SizedBox(height: AppSpacing.xs),
                        Wrap(
                          spacing: AppSpacing.xs,
                          runSpacing: AppSpacing.xs,
                          children: [
                            StatusBadge(
                              label: switch (user?.role) {
                                'MAIN_ADMIN' => 'Main Admin',
                                'ADMIN' => 'Admin',
                                _ => 'Member',
                              },
                              tone: AppBadgeTone.navy,
                            ),
                            StatusBadge(
                              label:
                                  '${humanizeStatus(user?.status ?? 'ACTIVE')} membership',
                              tone: badgeToneFor(user?.status ?? 'ACTIVE'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            if (user != null)
              _ProfileForm(
                key: ValueKey(user.id),
                initialName: user.name,
                initialPhone: user.phone ?? '',
                initialTimeZone: user.timeZone,
              ),
            const SizedBox(height: AppSpacing.lg),

            // ------------------------------------- admin/member switch
            if (user != null && user.canUseAdminArea)
              AppCard(
                onTap: () =>
                    context.go(isAdminArea ? '/home' : '/admin'),
                child: Row(
                  children: [
                    Icon(
                      isAdminArea
                          ? Icons.home_outlined
                          : Icons.admin_panel_settings_outlined,
                      color: AppColors.navy700,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        isAdminArea
                            ? 'Switch to member area'
                            : 'Switch to admin area',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded,
                        size: 20, color: AppColors.inkMuted),
                  ],
                ),
              ),
            if (user != null && user.canUseAdminArea)
              const SizedBox(height: AppSpacing.lg),

            // ------------------------------------------- appearance
            const SectionHeader(
              title: 'Appearance',
              subtitle: 'Choose the light or dark mood',
              icon: Icons.palette_outlined,
            ),
            const AppCard(child: AppearanceSection()),
            const SizedBox(height: AppSpacing.lg),

            // ------------------------------------ notification settings
            const SectionHeader(
              title: 'Notification preferences',
              subtitle: 'Choose how MyGrowth keeps in touch',
              icon: Icons.notifications_outlined,
            ),
            const AppCard(child: NotificationPrefsSection()),
            const SizedBox(height: AppSpacing.lg),

            // ------------------------------------------ privacy & tone
            const SectionHeader(
              title: 'Privacy & your data',
              icon: Icons.shield_outlined,
            ),
            AppCard(
              color: AppColors.navy50,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '“Small steps, faithful days, lasting growth.”',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: AppColors.navy800,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '• Your reflections journal and annual letter are private '
                    'to you — administrators cannot see them.\n'
                    '• Testimonies are only shared if you give consent, and '
                    'only after ministry approval.\n'
                    '• Activity records and reports are self-reported and '
                    'shared only with ministry administrators for '
                    'accountability.\n'
                    '• Prayer partners only ever see general availability — '
                    'never your exact schedule.',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(height: 1.6),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // ------------------------------------------------- sign out
            AppButton(
              label: 'Sign out',
              icon: Icons.logout_rounded,
              variant: AppButtonVariant.outlined,
              expand: true,
              onPressed: () async {
                final ok = await confirmDialog(
                  context,
                  title: 'Sign out?',
                  message:
                      'You’ll need to sign in again to access your growth '
                      'plan. Your progress stays safe.',
                  confirmLabel: 'Sign out',
                );
                if (!ok || !context.mounted) return;
                await ref.read(authControllerProvider.notifier).signOut();
                if (context.mounted) context.go('/login');
              },
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}

Future<void> _changeAvatar(BuildContext context, WidgetRef ref) async {
  final source = await showModalBottomSheet<String>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from gallery'),
            onTap: () => Navigator.of(ctx).pop('gallery'),
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt_outlined),
            title: const Text('Take a photo'),
            onTap: () => Navigator.of(ctx).pop('camera'),
          ),
          ListTile(
            leading: const Icon(Icons.close),
            title: const Text('Cancel'),
            onTap: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    ),
  );
  if (source == null) return;

  try {
    final image = await ImagePicker().pickImage(
      source: source == 'camera' ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 90,
    );
    if (image == null) return;
    final bytes = await image.readAsBytes();
    final extension = image.name.split('.').last.toLowerCase();
    final subtype = switch (extension) {
      'jpg' => 'jpeg',
      'png' => 'png',
      'webp' => 'webp',
      'gif' => 'gif',
      _ => 'jpeg',
    };

    final api = ref.read(apiClientProvider);
    final data = await api.upload(
      '/files',
      bytes: bytes,
      fieldName: 'file',
      filename: image.name,
      contentType: 'image/$subtype',
    );
    final uploadedFile = data is Map ? data['file'] : null;
    final nestedData = data is Map ? data['data'] : null;
    final fileId = uploadedFile is Map
        ? uploadedFile['id']
        : nestedData is Map
            ? nestedData['id']
            : data is Map
                ? data['id']
                : null;
    if (fileId == null) throw ApiException(500, 'upload_failed', 'Invalid upload response');
    await api.patch('/me', body: {'avatarFileId': fileId});
    await ref.read(authControllerProvider.notifier).refreshUser();
    if (context.mounted) Toast.success(context, 'Profile photo updated');
  } on ApiException catch (e) {
    if (context.mounted) Toast.error(context, e.message);
  } catch (error) {
    debugPrint('Profile photo update failed: $error');
    if (context.mounted) {
      Toast.error(context, 'Could not upload that photo. Try a JPG or PNG image.');
    }
  }
}

String _resolveAvatarUrl(String avatarUrl, String apiBaseUrl) {
  final parsed = Uri.tryParse(avatarUrl);
  if (parsed != null && parsed.hasScheme) return avatarUrl;

  final base = Uri.parse(apiBaseUrl);
  final basePath = base.path.replaceFirst(RegExp(r'/+$'), '');
  var path = avatarUrl;
  if (basePath.isNotEmpty && path.startsWith('$basePath/')) {
    path = path.substring(basePath.length);
  } else if (path.startsWith('/api/v1/')) {
    path = path.substring('/api/v1'.length);
  }
  final normalizedPath = path.startsWith('/') ? path : '/$path';
  return base.replace(path: '$basePath$normalizedPath').toString();
}

class _ProfileForm extends ConsumerStatefulWidget {
  const _ProfileForm({
    super.key,
    required this.initialName,
    required this.initialPhone,
    required this.initialTimeZone,
  });

  final String initialName;
  final String initialPhone;
  final String initialTimeZone;

  @override
  ConsumerState<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<_ProfileForm> {
  late final TextEditingController _name =
      TextEditingController(text: widget.initialName);
  late final TextEditingController _phone =
      TextEditingController(text: widget.initialPhone);
  late final TextEditingController _timeZone =
      TextEditingController(text: widget.initialTimeZone);
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _timeZone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      Toast.error(context, 'Please add your name.');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(authControllerProvider.notifier).updateProfile({
        'name': _name.text.trim(),
        'phone': _phone.text.trim(),
        'timeZone': _timeZone.text.trim().isEmpty
            ? 'Africa/Lagos'
            : _timeZone.text.trim(),
      });
      if (mounted) Toast.success(context, 'Profile updated.');
    } on ApiException catch (e) {
      if (mounted) Toast.error(context, e.fieldError ?? e.message);
    } catch (_) {
      if (mounted) Toast.error(context, 'Unable to save your profile just now.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Personal details',
          icon: Icons.person_outline_rounded,
        ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                label: 'Full name',
                required: true,
                controller: _name,
                prefixIcon: Icons.person_outline_rounded,
              ),
              const SizedBox(height: fieldGap),
              AppTextField(
                label: 'Phone',
                controller: _phone,
                keyboardType: TextInputType.phone,
                prefixIcon: Icons.phone_outlined,
              ),
              const SizedBox(height: fieldGap),
              AppTextField(
                label: 'Time zone',
                controller: _timeZone,
                hint: 'Africa/Lagos',
                prefixIcon: Icons.public_rounded,
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'Save changes',
                icon: Icons.save_outlined,
                busy: _busy,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
