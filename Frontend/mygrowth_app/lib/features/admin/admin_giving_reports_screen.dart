import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/widgets/app_back_button.dart';
import '../partnerships/giving_documents.dart';

class AdminGivingReportsScreen extends ConsumerStatefulWidget {
  const AdminGivingReportsScreen({super.key});
  @override
  ConsumerState<AdminGivingReportsScreen> createState() =>
      _AdminGivingReportsScreenState();
}

class _AdminGivingReportsScreenState
    extends ConsumerState<AdminGivingReportsScreen> {
  String _period = 'DAILY';
  DateTime _date = DateTime.now();
  late Future<Map<String, dynamic>> _report;

  String get _dateKey =>
      '${_date.year.toString().padLeft(4, '0')}-'
      '${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _report = _load();
  }

  Future<Map<String, dynamic>> _load() async =>
      await ref
              .read(apiClientProvider)
              .get(
                '/admin/giving/reports',
                query: {'period': _period, 'date': _dateKey},
              )
          as Map<String, dynamic>;

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null)
      setState(() {
        _date = date;
        _report = _load();
      });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: const AppBackButton(),
      title: const Text('Giving Reports'),
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DropdownButton<String>(
                value: _period,
                items: const [
                  DropdownMenuItem(value: 'DAILY', child: Text('Daily')),
                  DropdownMenuItem(value: 'WEEKLY', child: Text('Weekly')),
                  DropdownMenuItem(value: 'MONTHLY', child: Text('Monthly')),
                ],
                onChanged: (value) {
                  if (value != null)
                    setState(() {
                      _period = value;
                      _report = _load();
                    });
                },
              ),
              OutlinedButton.icon(
                onPressed: _selectDate,
                icon: const Icon(Icons.calendar_month_outlined),
                label: Text(_dateKey),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<Map<String, dynamic>>(
            future: _report,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting)
                return const Center(child: CircularProgressIndicator());
              if (snapshot.hasError)
                return Center(
                  child: Text(
                    'Could not load giving report. ${snapshot.error}',
                  ),
                );
              final report = snapshot.data ?? {};
              final categories = report['categories'] as List<dynamic>? ?? [];
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons.account_balance_wallet_outlined,
                      ),
                      title: Text('NGN ${report['totalAmount'] ?? 0} received'),
                      subtitle: Text(
                        '${report['count'] ?? 0} completed gifts · ${report['period']} · ${report['date']} (${report['timezone']})',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final item in categories) ...[
                    Builder(
                      builder: (context) {
                        final row = item as Map<String, dynamic>;
                        return ListTile(
                          title: Text('${row['name']}'),
                          subtitle: Text('${row['count']} gifts'),
                          trailing: Text('NGN ${row['amount']}'),
                        );
                      },
                    ),
                  ],
                  if ((report['transactions'] as List<dynamic>? ?? []).isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: Text('No confirmed gifts in this period.'),
                      ),
                    ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed:
                        (report['transactions'] as List<dynamic>? ?? []).isEmpty
                        ? null
                        : () async {
                            try {
                              await shareGivingReport(report);
                            } catch (e) {
                              if (context.mounted)
                                ScaffoldMessenger.of(
                                  context,
                                ).showSnackBar(SnackBar(content: Text('$e')));
                            }
                          },
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Download report PDF'),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    ),
  );
}
