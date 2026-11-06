import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';

class AdminMinistryPartnershipsScreen extends ConsumerStatefulWidget {
  const AdminMinistryPartnershipsScreen({super.key});
  @override
  ConsumerState<AdminMinistryPartnershipsScreen> createState() => _AdminMinistryPartnershipsScreenState();
}

class _AdminMinistryPartnershipsScreenState extends ConsumerState<AdminMinistryPartnershipsScreen> {
  List<dynamic> _rows = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final response = await ref.read(apiClientProvider).get('/admin/ministry-partnerships') as Map<String, dynamic>;
      if (mounted) setState(() { _rows = response['data'] as List<dynamic>? ?? []; _loading = false; });
    } catch (e) { if (mounted) setState(() { _error = '$e'; _loading = false; }); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ministry Partnerships')),
    body: _loading ? const Center(child: CircularProgressIndicator()) : _error != null
      ? Center(child: Text(_error!))
      : _rows.isEmpty ? const Center(child: Text('No ministry partnership pledges yet.'))
      : RefreshIndicator(onRefresh: _load, child: ListView.separated(
          padding: const EdgeInsets.all(16), itemCount: _rows.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final p = _rows[index] as Map<String, dynamic>;
            final user = p['user'] as Map<String, dynamic>? ?? {};
            final frequency = '${p['frequency']}'.toLowerCase();
            return Card(child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.volunteer_activism_outlined)),
              title: Text('${user['name'] ?? 'Member'} · ${p['currency']} ${p['amount']} / $frequency'),
              subtitle: Text('${user['email'] ?? ''}\n${p['status']} · Updated ${p['updatedAt'] ?? ''}'),
              isThreeLine: true,
            ));
          },
        )),
  );
}
