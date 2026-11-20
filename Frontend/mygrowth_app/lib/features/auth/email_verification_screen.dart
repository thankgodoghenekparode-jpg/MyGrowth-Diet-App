import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/toast.dart';
import 'login_screen.dart';

/// Completes signup by checking the 6-digit code emailed to the new member.
/// No session exists until this screen succeeds.
class EmailVerificationScreen extends ConsumerStatefulWidget {
  const EmailVerificationScreen({super.key, required this.email});

  final String email;

  @override
  ConsumerState<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState
    extends ConsumerState<EmailVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  Timer? _resendTimer;
  bool _busy = false;
  bool _resending = false;
  int _resendIn = 0;

  @override
  void initState() {
    super.initState();
    if (widget.email.isNotEmpty) _startCooldown(60);
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _code.dispose();
    super.dispose();
  }

  void _startCooldown(int seconds) {
    _resendTimer?.cancel();
    if (!mounted) return;
    setState(() => _resendIn = seconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _resendIn--);
      if (_resendIn <= 0) timer.cancel();
    });
  }

  Future<void> _verify() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (widget.email.isEmpty) {
      Toast.error(context, 'Go back and register to verify an email address.');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .verifyEmailOtp(email: widget.email, code: _code.text.trim());
      if (!mounted) return;
      TextInput.finishAutofillContext();
      Toast.success(context, 'Email verified. Welcome to MyGrowth Diet App!');
      final auth = ref.read(authControllerProvider);
      if (auth.needsProfileCompletion) {
        context.go('/setup-profile');
      } else {
        context.go(auth.user?.canUseAdminArea == true ? '/admin' : '/home');
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      Toast.error(context, e.fieldError ?? e.message);
    } catch (_) {
      if (!mounted) return;
      Toast.error(context, 'Unable to verify that code right now.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    if (widget.email.isEmpty || _resendIn > 0 || _resending) return;
    setState(() => _resending = true);
    try {
      final retryAfter = await ref
          .read(authControllerProvider.notifier)
          .resendEmailOtp(widget.email);
      if (!mounted) return;
      _startCooldown(retryAfter);
      Toast.success(context, 'A new verification code has been sent.');
    } on ApiException catch (e) {
      if (!mounted) return;
      Toast.error(context, e.fieldError ?? e.message);
    } catch (_) {
      if (!mounted) return;
      Toast.error(context, 'Unable to resend the code right now.');
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasEmail = widget.email.isNotEmpty;
    return AuthScaffold(
      title: 'Verify your email',
      footer: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'Need to use another email?',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          TextButton(
            onPressed: () => context.go('/register'),
            child: const Text('Register again'),
          ),
        ],
      ),
      child: !hasEmail
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'This verification link is missing an email address. Please '
                  'register again or sign in to request a new code.',
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: 'Back to registration',
                  expand: true,
                  onPressed: () => context.go('/register'),
                ),
              ],
            )
          : Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.mark_email_read_outlined,
                    size: 42,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Enter the 6-digit code we sent to ${widget.email}.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'The code expires in 10 minutes. This step secures your '
                    'account before you can use the app.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    label: 'Verification code',
                    required: true,
                    controller: _code,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    maxLength: 6,
                    hint: '000000',
                    prefixIcon: Icons.password_outlined,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    autofillHints: const [AutofillHints.oneTimeCode],
                    validator: (v) => (v == null || v.trim().length != 6)
                        ? 'Enter the 6-digit code'
                        : null,
                    onSubmitted: (_) => _verify(),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: 'Verify and continue',
                    busy: _busy,
                    expand: true,
                    onPressed: _verify,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'Didn’t get the code?',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      TextButton(
                        onPressed: _resendIn > 0 || _resending ? null : _resend,
                        child: Text(
                          _resendIn > 0
                              ? 'Resend in ${_resendIn}s'
                              : (_resending ? 'Sending…' : 'Resend code'),
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () => context.go('/login'),
                    child: const Text('Back to sign in'),
                  ),
                ],
              ),
            ),
    );
  }
}
