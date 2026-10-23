import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/toast.dart';
import 'login_screen.dart';

/// First-login flow: complete essential profile details.
class ProfileCompletionScreen extends ConsumerStatefulWidget {
  const ProfileCompletionScreen({super.key});

  @override
  ConsumerState<ProfileCompletionScreen> createState() =>
      _ProfileCompletionScreenState();
}

class _ProfileCompletionScreenState
    extends ConsumerState<ProfileCompletionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _timeZone = TextEditingController(text: 'Africa/Lagos');
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider);
    if (user != null) {
      _name.text = user.name;
      _phone.text = user.phone ?? '';
      _timeZone.text = user.timeZone;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _timeZone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      await ref.read(authControllerProvider.notifier).updateProfile({
        'name': _name.text.trim(),
        if (_phone.text.trim().isNotEmpty) 'phone': _phone.text.trim(),
        'timeZone': _timeZone.text.trim(),
        'profileCompleted': true,
      });
      if (!mounted) return;
      ref.read(authControllerProvider.notifier).acknowledgeProfileCompletion();
      Toast.success(context, 'Your profile is ready. Welcome!');
      final user = ref.read(currentUserProvider);
      context.go(user?.canUseAdminArea == true ? '/admin' : '/home');
    } on ApiException catch (e) {
      if (mounted) Toast.error(context, e.fieldError ?? e.message);
    } catch (_) {
      if (mounted) Toast.error(context, 'Unable to save your profile.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Complete your profile',
      footer: const SizedBox.shrink(),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'A few details help your prayer partners and admins recognise '
              'you, and keep dates in your local time.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Full name',
              required: true,
              controller: _name,
              textCapitalization: TextCapitalization.words,
              prefixIcon: Icons.person_outline_rounded,
              validator: (v) => (v == null || v.trim().length < 2)
                  ? 'Enter your full name'
                  : null,
            ),
            const SizedBox(height: fieldGap),
            AppTextField(
              label: 'Phone (optional)',
              controller: _phone,
              keyboardType: TextInputType.phone,
              prefixIcon: Icons.phone_outlined,
            ),
            const SizedBox(height: fieldGap),
            AppTextField(
              label: 'Time zone',
              required: true,
              controller: _timeZone,
              prefixIcon: Icons.public_outlined,
              helper: 'Default is Africa/Lagos',
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter a time zone' : null,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Save and continue',
              busy: _busy,
              expand: true,
              onPressed: _submit,
            ),
            TextButton(
              onPressed: () => context.go('/home'),
              child: const Text('Skip for now'),
            ),
          ],
        ),
      ),
    );
  }
}
