import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/brand_logo.dart';
import '../../../core/widgets/toast.dart';

/// Shared branding header used on all auth screens.
class AuthBrandHeader extends StatelessWidget {
  const AuthBrandHeader({super.key, this.showTagline = true});

  final bool showTagline;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const BrandLogo(size: 68),
        const SizedBox(height: AppSpacing.md),
        Text(
          'MyGrowth Diet App',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          'Healings Erhuvwuigho Azuike Ministry',
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppColors.inkSecondary),
        ),
        if (showTagline) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Growing in the Word. Consistent in Prayer.\nAccountable in Purpose.',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: AppColors.inkMuted, height: 1.5),
          ),
        ],
      ],
    );
  }
}

/// Auth screens share a responsive scaffold: centred card on wide screens.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.child,
    required this.footer,
  });

  final String title;
  final Widget child;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AuthBrandHeader(),
                  const SizedBox(height: AppSpacing.xl),
                  AppCard(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        child,
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  footer,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      await ref.read(authControllerProvider.notifier).signIn(
            email: _email.text.trim(),
            password: _password.text,
          );
      if (!mounted) return;
      final auth = ref.read(authControllerProvider);
      final user = auth.user;
      Toast.success(context, 'Welcome back${user == null ? '' : ', ${user.name.split(' ').first}'}!');
      if (user != null && user.isPendingApproval) {
        context.go('/home');
      } else if (auth.needsProfileCompletion) {
        context.go('/setup-profile');
      } else {
        context.go(user?.canUseAdminArea == true ? '/admin' : '/home');
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      Toast.error(context, e.fieldError ?? e.message);
    } catch (_) {
      if (!mounted) return;
      Toast.error(context, 'Unable to sign in right now. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Sign in',
      footer: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('New to MyGrowth?',
              style: Theme.of(context).textTheme.bodySmall),
          TextButton(
            onPressed: () => context.go('/register'),
            child: const Text('Create an account'),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              label: 'Email address',
              required: true,
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              prefixIcon: Icons.mail_outline_rounded,
              hint: 'you@example.com',
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
              label: 'Password',
              required: true,
              controller: _password,
              obscure: true,
              textInputAction: TextInputAction.done,
              prefixIcon: Icons.lock_outline_rounded,
              onSubmitted: (_) => _submit(),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Enter your password' : null,
            ),
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => context.go('/forgot-password'),
                child: const Text('Forgot password?'),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            AppButton(
              label: 'Sign in',
              busy: _busy,
              expand: true,
              onPressed: _submit,
            ),
            const SizedBox(height: AppSpacing.md),
            const _PrivacyNotice(),
          ],
        ),
      ),
    );
  }
}

class _PrivacyNotice extends StatelessWidget {
  const _PrivacyNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.navy50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, size: 17, color: AppColors.navy600),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              'Your reflections, prayer requests and reports are private. '
              'They are only shared according to the visibility you choose.',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}
