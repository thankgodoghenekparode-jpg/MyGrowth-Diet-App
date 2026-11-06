import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/section_header.dart';

class MinistryPartnershipScreen extends ConsumerStatefulWidget {
  const MinistryPartnershipScreen({super.key});

  @override
  ConsumerState<MinistryPartnershipScreen> createState() => _MinistryPartnershipScreenState();
}

class _MinistryPartnershipScreenState extends ConsumerState<MinistryPartnershipScreen> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String _frequency = 'MONTHLY';
  Map<String, dynamic>? _current;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() { _amount.dispose(); _note.dispose(); super.dispose(); }

  Future<void> _load() async {
    try {
      final result = await ref.read(apiClientProvider).get('/partnerships/mine') as Map<String, dynamic>;
      final data = result['partnership'] as Map<String, dynamic>?;
      if (!mounted) return;
      setState(() {
        _current = data;
        if (data != null) {
          _amount.text = '${data['amount']}';
          _note.text = '${data['note'] ?? ''}';
          _frequency = '${data['frequency']}';
        }
        _loading = false;
      });
    } catch (e) { if (mounted) setState(() { _loading = false; _error = '$e'; }); }
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amount.text.trim().replaceAll(',', ''));
    if (amount == null || amount <= 0) { setState(() => _error = 'Enter a valid amount greater than zero.'); return; }
    setState(() { _saving = true; _error = null; });
    try {
      final result = await ref.read(apiClientProvider).post('/partnerships', body: {
        'amount': amount, 'frequency': _frequency, 'note': _note.text.trim(),
      }) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() { _current = result['partnership'] as Map<String, dynamic>?; _saving = false; });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Your ministry partnership pledge has been saved.')));
    } catch (e) { if (mounted) setState(() { _saving = false; _error = '$e'; }); }
  }

  Future<void> _setStatus(String status) async {
    setState(() => _saving = true);
    try {
      final result = await ref.read(apiClientProvider).patch('/partnerships/mine', body: {'status': status}) as Map<String, dynamic>;
      if (mounted) setState(() { _current = result['partnership'] as Map<String, dynamic>?; _saving = false; });
    } catch (e) { if (mounted) setState(() { _saving = false; _error = '$e'; }); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Partner with the Ministry')),
    body: _loading ? const Center(child: CircularProgressIndicator()) : ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SectionHeader(title: 'Support the ministry', subtitle: 'Choose an amount and a giving rhythm that works for you.'),
        const SizedBox(height: 12),
        Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Your partnership helps sustain the ministry and its work. Give freely and choose a commitment that is right for you.'),
          const SizedBox(height: 12),
          Text('This records your pledge only. No payment will be taken in the app. The ministry will share payment instructions separately.', style: TextStyle(color: AppColors.inkSecondary)),
        ]))),
        const SizedBox(height: 20),
        TextField(controller: _amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Amount (NGN)', prefixText: '₦ ', border: OutlineInputBorder())),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(initialValue: _frequency, decoration: const InputDecoration(labelText: 'Frequency', border: OutlineInputBorder()), items: const [
          DropdownMenuItem(value: 'WEEKLY', child: Text('Weekly')),
          DropdownMenuItem(value: 'MONTHLY', child: Text('Monthly')),
          DropdownMenuItem(value: 'YEARLY', child: Text('Yearly')),
        ], onChanged: (v) { if (v != null) setState(() => _frequency = v); }),
        const SizedBox(height: 14),
        TextField(controller: _note, maxLength: 500, maxLines: 2, decoration: const InputDecoration(labelText: 'Note (optional)', border: OutlineInputBorder())),
        if (_error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
        const SizedBox(height: 8),
        FilledButton.icon(onPressed: _saving ? null : _save, icon: const Icon(Icons.favorite_outline), label: Text(_saving ? 'Saving…' : _current == null ? 'Become a partner' : 'Update my pledge')),
        if (_current != null) ...[
          const SizedBox(height: 14),
          Text('Pledge status: ${_current!['status']}'),
          Wrap(spacing: 8, children: [
            if (_current!['status'] == 'ACTIVE') TextButton(onPressed: _saving ? null : () => _setStatus('PAUSED'), child: const Text('Pause pledge')),
            if (_current!['status'] == 'PAUSED') TextButton(onPressed: _saving ? null : () => _setStatus('ACTIVE'), child: const Text('Resume pledge')),
            if (_current!['status'] != 'ENDED') TextButton(onPressed: _saving ? null : () => _setStatus('ENDED'), child: const Text('End pledge')),
          ]),
        ],
      ],
    ),
  );
}
