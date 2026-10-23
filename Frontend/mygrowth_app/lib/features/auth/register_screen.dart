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

/// Public registration. Always creates a Member account; the backend never
/// accepts a role from client input.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  bool _agreed = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_agreed) {
      Toast.error(context, 'Please accept the privacy notice to continue.');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(authControllerProvider.notifier).register(
            name: _name.text.trim(),
            email: _email.text.trim(),
            password: _password.text,
            phone: _phone.text.trim(),
          );
      if (!mounted) return;
      Toast.success(
          context, 'Account created. Welcome to MyGrowth Diet App!');
      context.go('/setup-profile');
    } on ApiException catch (e) {
      if (!mounted) return;
      Toast.error(context, e.fieldError ?? e.message);
    } catch (_) {
      if (!mounted) return;
      Toast.error(context, 'Unable to create your account right now.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Create your account',
      footer: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('Already have an account?',
              style: Theme.of(context).textTheme.bodySmall),
          TextButton(
            onPressed: () => context.go('/login'),
            child: const Text('Sign in'),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Registration creates a member account. Administrative access '
              'is granted separately by the ministry.',
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
              label: 'Email address',
              required: true,
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              prefixIcon: Icons.mail_outline_rounded,
              validator: (v) {
                final value = v?.trim() ?? '';
                if (value.isEmpty) return 'Enter your email address';
                if (!value.contains('@') || !value.contains('.')) {
                  return 'Enter a valid email address';
                }
                return null;
              },
            ),
            const SizedBox(height: fieldGap),
            AppTextField(
              label: 'Phone number (optional)',
              controller: _phone,
              keyboardType: TextInputType.phone,
              prefixIcon: Icons.phone_outlined,
            ),
            const SizedBox(height: fieldGap),
            AppTextField(
              label: 'Password',
              required: true,
              controller: _password,
              obscure: true,
              helper: 'At least 8 characters',
              prefixIcon: Icons.lock_outline_rounded,
              validator: (v) {
                if (v == null || v.length < 8) {
                  return 'Use at least 8 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: fieldGap),
            AppTextField(
              label: 'Confirm password',
              required: true,
              controller: _confirm,
              obscure: true,
              prefixIcon: Icons.lock_outline_rounded,
              validator: (v) =>
                  v != _password.text ? 'Passwords do not match' : null,
            ),
            const SizedBox(height: AppSpacing.sm),
            CheckboxListTile(
              value: _agreed,
              onChanged: (v) => setState(() => _agreed = v ?? false),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(
                'I understand that my personal reflections and reports stay '
                'private, and I accept the ministry’s privacy notice.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            AppButton(
              label: 'Create account',
              busy: _busy,
              expand: true,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
