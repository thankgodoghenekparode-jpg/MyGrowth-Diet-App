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

/// Consumes a reset token (from the emailed link) and sets a new password.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key, required this.token});

  final String token;

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      await ref.read(authControllerProvider.notifier).resetPassword(
            token: widget.token,
            newPassword: _password.text,
          );
      if (!mounted) return;
      Toast.success(context, 'Password updated. Please sign in.');
      context.go('/login');
    } on ApiException catch (e) {
      if (mounted) Toast.error(context, e.fieldError ?? e.message);
    } catch (_) {
      if (mounted) {
        Toast.error(context, 'Unable to reset your password right now.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasToken = widget.token.isNotEmpty;
    return AuthScaffold(
      title: 'Choose a new password',
      footer: TextButton(
        onPressed: () => context.go('/login'),
        child: const Text('Back to sign in'),
      ),
      child: !hasToken
          ? Text(
              'This reset link is incomplete. Please request a new link from '
              'the forgot-password page.',
              style: Theme.of(context).textTheme.bodyMedium,
            )
          : Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppTextField(
                    label: 'New password',
                    required: true,
                    controller: _password,
                    obscure: true,
                    helper: 'At least 8 characters',
                    prefixIcon: Icons.lock_outline_rounded,
                    validator: (v) => (v == null || v.length < 8)
                        ? 'Use at least 8 characters'
                        : null,
                  ),
                  const SizedBox(height: fieldGap),
                  AppTextField(
                    label: 'Confirm new password',
                    required: true,
                    controller: _confirm,
                    obscure: true,
                    prefixIcon: Icons.lock_outline_rounded,
                    validator: (v) =>
                        v != _password.text ? 'Passwords do not match' : null,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppButton(
                    label: 'Update password',
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
