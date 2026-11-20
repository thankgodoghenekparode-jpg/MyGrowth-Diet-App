import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/widgets/app_back_button.dart';
import 'giving_documents.dart';
import 'ministry_partnership_screen.dart';

class GivingScreen extends ConsumerStatefulWidget {
  const GivingScreen({super.key});

  @override
  ConsumerState<GivingScreen> createState() => _GivingScreenState();
}

class _GivingScreenState extends ConsumerState<GivingScreen> {
  final _amount = TextEditingController();
  final _guestName = TextEditingController();
  final _guestEmail = TextEditingController();
  List<dynamic> _categories = [];
  String? _categoryId;
  String? _reference;
  bool _loading = true;
  bool _working = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _amount.dispose();
    _guestName.dispose();
    _guestEmail.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final result =
          await ref.read(apiClientProvider).get('/giving/categories')
              as List<dynamic>;
      if (!mounted) return;
      setState(() {
        _categories = result;
        _categoryId = _categories.isEmpty
            ? null
            : (_categories.first as Map<String, dynamic>)['id'] as String?;
        _loading = false;
      });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = '$e';
          _loading = false;
        });
    }
  }

  Future<void> _give() async {
    final amount = double.tryParse(_amount.text.trim().replaceAll(',', ''));
    final user = ref.read(currentUserProvider);
    if (_categoryId == null || amount == null || amount <= 0) {
      setState(
        () => _error = 'Choose a giving category and enter a valid amount.',
      );
      return;
    }
    if (user == null &&
        (_guestName.text.trim().isEmpty ||
            !_guestEmail.text.trim().contains('@'))) {
      setState(
        () => _error =
            'Enter your name and a valid email address for the receipt.',
      );
      return;
    }
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final data =
          await ref
                  .read(apiClientProvider)
                  .post(
                    '/giving/initialize',
                    body: {
                      'categoryId': _categoryId,
                      'amount': amount,
                      if (user == null) 'donorName': _guestName.text.trim(),
                      if (user == null) 'donorEmail': _guestEmail.text.trim(),
                      if (user == null) 'isGuest': true,
                    },
                  )
              as Map<String, dynamic>;
      final checkout = Uri.tryParse('${data['checkoutUrl'] ?? ''}');
      if (checkout == null ||
          !checkout.hasScheme ||
          !await launchUrl(checkout, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not open the secure Monnify checkout.');
      }
      if (mounted)
        setState(() => _reference = data['paymentReference'] as String?);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _verify() async {
    final reference = _reference;
    if (reference == null) return;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final data =
          await ref.read(apiClientProvider).post('/giving/verify/$reference')
              as Map<String, dynamic>;
      if (!mounted) return;
      if (data['paid'] == true) {
        final receipt = data['receipt'] as Map<String, dynamic>?;
        if (receipt != null) await shareGivingReceipt(receipt);
        if (mounted) setState(() => _reference = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Giving received. Receipt ${data['receiptNumber'] ?? ''}',
            ),
          ),
        );
      } else {
        setState(
          () => _error =
              'Payment is not confirmed yet. Please try again shortly.',
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isGuest = ref.watch(currentUserProvider) == null;
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('Giving & Partnership'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'Give to support the ministry',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Choose a giving category and amount. Payments are securely processed by Monnify.',
                ),
                const SizedBox(height: 20),
                if (_categories.isNotEmpty)
                  DropdownButtonFormField<String>(
                    value: _categoryId,
                    decoration: const InputDecoration(
                      labelText: 'Giving category',
                      border: OutlineInputBorder(),
                    ),
                    items: _categories.map((item) {
                      final category = item as Map<String, dynamic>;
                      return DropdownMenuItem(
                        value: category['id'] as String,
                        child: Text('${category['name']}'),
                      );
                    }).toList(),
                    onChanged: (value) => setState(() => _categoryId = value),
                  )
                else if (_error == null)
                  const Text('Giving categories are not available yet.'),
                if (isGuest) ...[
                  const SizedBox(height: 14),
                  TextField(
                    controller: _guestName,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Your name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _guestEmail,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email for your receipt',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                TextField(
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Amount (NGN)',
                    prefixText: '₦ ',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _working || _categories.isEmpty ? null : _give,
                  icon: const Icon(Icons.favorite_outline),
                  label: Text(
                    _working ? 'Please wait…' : 'Continue to secure payment',
                  ),
                ),
                if (_reference != null) ...[
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _working ? null : _verify,
                    child: const Text('I completed payment — verify'),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                if (!isGuest) ...[
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const _GivingHistoryScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: const Text('View giving history'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const MinistryPartnershipScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.volunteer_activism_outlined),
                    label: const Text('Become a ministry partner'),
                  ),
                ],
              ],
            ),
    );
  }
}

class _GivingHistoryScreen extends ConsumerStatefulWidget {
  const _GivingHistoryScreen();
  @override
  ConsumerState<_GivingHistoryScreen> createState() =>
      _GivingHistoryScreenState();
}

class _GivingHistoryScreenState extends ConsumerState<_GivingHistoryScreen> {
  late Future<Map<String, dynamic>> _history;
  @override
  void initState() {
    super.initState();
    _history = _load();
  }

  Future<Map<String, dynamic>> _load() async =>
      await ref.read(apiClientProvider).get('/giving/history')
          as Map<String, dynamic>;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: const AppBackButton(),
      title: const Text('Giving History'),
    ),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _history,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError)
          return Center(
            child: Text('Sign in to view giving history. ${snapshot.error}'),
          );
        final data = snapshot.data ?? {};
        final rows = data['transactions'] as List<dynamic>? ?? [];
        if (rows.isEmpty)
          return const Center(child: Text('No giving transactions yet.'));
        return ListView.builder(
          itemCount: rows.length,
          itemBuilder: (context, index) {
            final row = rows[index] as Map<String, dynamic>;
            final category = row['category'] as Map<String, dynamic>? ?? {};
            return ListTile(
              leading: const Icon(Icons.receipt_outlined),
              title: Text(
                '${category['name'] ?? 'Giving'} · ₦${row['amount'] ?? ''}',
              ),
              subtitle: Text(
                '${row['status'] ?? ''} · ${row['receiptNumber'] ?? row['paymentReference'] ?? ''}',
              ),
              trailing: row['status'] == 'PAID'
                  ? IconButton(
                      tooltip: 'Download receipt',
                      icon: const Icon(Icons.download_outlined),
                      onPressed: () async {
                        try {
                          await shareGivingReceipt(row);
                        } catch (e) {
                          if (context.mounted)
                            ScaffoldMessenger.of(context)
                                .showSnackBar(SnackBar(content: Text('$e')));
                        }
                      },
                    )
                  : null,
            );
          },
        );
      },
    ),
  );
}
