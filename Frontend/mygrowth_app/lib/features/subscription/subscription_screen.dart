import 'package:mygrowth_app/core/auth/auth_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key, this.paymentReference});

  final String? paymentReference;

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  Map<String, dynamic>? _status;
  bool _loading = true;
  bool _working = false;
  String? _message;
  String _selectedPlanId = '1_month';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      final reference = widget.paymentReference;
      if (reference != null && reference.isNotEmpty) {
        final verified = await api.post('/subscription/verify/${Uri.encodeComponent(reference)}');
        if (verified is Map && verified['paid'] == true) {
          _message = 'Payment confirmed. Your access is active.';
        } else {
          _message = 'Payment is still being confirmed. Please check again shortly.';
        }
      }
      final status = await api.get('/subscription/status');
      if (mounted) {
        setState(() {
          _status = status is Map<String, dynamic> ? status : null;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _message = error is ApiException ? error.message : 'Could not load subscription details.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _subscribe() async {
    setState(() {
      _working = true;
      _message = null;
    });
    try {
      final result = await ref.read(apiClientProvider).post(
        '/subscription/checkout',
        body: {'planId': _selectedPlanId},
      );
      final url = result is Map ? result['checkoutUrl'] as String? : null;
      if (url == null || !await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)) {
        throw Exception('Could not open Monnify checkout.');
      }
    } catch (error) {
      if (mounted) {
        setState(() => _message = error is ApiException ? error.message : error.toString());
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _status ?? const <String, dynamic>{};
    final active = status['active'] == true;
    final expires = DateTime.tryParse(status['expiresAt']?.toString() ?? '');
    final configured = status['paymentConfigured'] == true;
    final plans = status['plans'] is List
        ? (status['plans'] as List)
            .whereType<Map>()
            .map((plan) => Map<String, dynamic>.from(plan))
            .toList()
        : <Map<String, dynamic>>[
            {
              'id': '1_month',
              'label': '1 month',
              'durationDays': status['periodDays'] ?? 30,
              'price': status['price'] ?? 1000,
            },
          ];

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppSpacing.cardRadius,
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.workspace_premium_rounded, size: 42, color: AppColors.iconAccent),
              const SizedBox(height: AppSpacing.md),
              Text(active ? 'Your access is active' : 'Choose your access period',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSpacing.sm),
              Text(active && expires != null
                  ? 'Access is available until ${DateFormat('d MMMM yyyy').format(expires.toLocal())}.'
                  : 'Get full access to the Growth Diet, study materials, programme plans and devotions.'),
              const SizedBox(height: AppSpacing.md),
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else ...[
                Text('Select an access plan', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                RadioGroup<String>(
                  groupValue: _selectedPlanId,
                  onChanged: (value) {
                    if (!_working && value != null) {
                      setState(() => _selectedPlanId = value);
                    }
                  },
                  child: Column(
                    children: plans.map((plan) {
                      final planId = plan['id']?.toString() ?? '';
                      final durationDays = plan['durationDays'] ?? 30;
                      final price = NumberFormat.currency(
                        locale: 'en_NG',
                        symbol: '₦',
                        decimalDigits: 0,
                      ).format((plan['price'] as num?) ?? 0);
                      return RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        activeColor: AppColors.brandText,
                        value: planId,
                        title: Text(plan['label']?.toString() ?? 'Subscription'),
                        subtitle: Text('$price • $durationDays days'),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                if (kIsWeb)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _working || !configured || plans.isEmpty ? null : _subscribe,
                      icon: _working
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.lock_open_rounded),
                      label: Text(configured
                          ? (active ? 'Renew selected plan' : 'Continue to payment')
                          : 'Payments are being set up'),
                    ),
                  )
                else
                  const Text('Complete payment from the web version. In-app purchase billing will be added for store releases.'),
              ],
              if (_message != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(_message!, style: Theme.of(context).textTheme.bodyMedium),
              ],
              if (widget.paymentReference != null && !_loading) ...[
                const SizedBox(height: AppSpacing.sm),
                TextButton.icon(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Check payment again'),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text('Payments are processed securely by Monnify. Access starts after the payment is verified.',
            style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

