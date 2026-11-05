import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/utils/app_date.dart';
import '../../core/widgets/bible_reference_text.dart';

class DailyDevotionScreen extends ConsumerStatefulWidget {
  const DailyDevotionScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  ConsumerState<DailyDevotionScreen> createState() =>
      _DailyDevotionScreenState();
}

class _DailyDevotionScreenState extends ConsumerState<DailyDevotionScreen> {
  DateTime _currentDate = appToday();
  Map<String, dynamic>? _devotion;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDevotion();
  }

  String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  Future<void> _loadDevotion() async {
    setState(() => _loading = true);

    // Use the supplied January 2027 devotion content for those dates.
    if (_currentDate.year == 2027 && _currentDate.month == 1) {
      final bundled = await _loadBundledDevotion();
      if (!mounted) return;
      if (bundled != null) {
        setState(() {
          _devotion = bundled;
          _loading = false;
          _error = null;
        });
        return;
      }
    }

    try {
      final date = Uri.encodeQueryComponent(_formatDate(_currentDate));
      final data = await ref.read(apiClientProvider).get('/devotions?date=$date');
      if (!mounted) return;

      if (data is Map && data['devotion'] is Map) {
        setState(() {
          _devotion = Map<String, dynamic>.from(data['devotion'] as Map);
          _loading = false;
          _error = null;
        });
        return;
      }
    } catch (_) {
      // Use the bundled devotion if the API is unavailable.
    }

    final bundled = await _loadBundledDevotion();
    if (!mounted) return;
    setState(() {
      _devotion = bundled;
      _loading = false;
      _error = bundled == null ? 'Unable to load devotion for this day.' : null;
    });
  }

  Future<Map<String, dynamic>?> _loadBundledDevotion() async {
    try {
      final raw = await rootBundle.loadString('assets/devotions.json');
      final entries = jsonDecode(raw) as List<dynamic>;
      for (final entry in entries) {
        if (entry is Map &&
            entry['month'] == _currentDate.month &&
            entry['day'] == _currentDate.day) {
          return Map<String, dynamic>.from(entry);
        }
      }
    } catch (_) {
      // The asset may be unavailable in a development build.
    }
    return null;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _currentDate,
      firstDate: appStartDate,
      lastDate: DateTime(2028, 12, 31),
    );
    if (picked == null) return;
    setState(() => _currentDate = picked);
    _loadDevotion();
  }

  void _changeDate(int days) {
    setState(() => _currentDate = _currentDate.add(Duration(days: days)));
    _loadDevotion();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isToday = DateUtils.isSameDay(_currentDate, appToday());
    final title = _devotion?['title']?.toString() ?? 'Daily Devotion';
    final anchor = _devotion?['anchorScripture']?.toString() ?? '';
    final reading = (_devotion?['scriptureReading'] ??
            _devotion?['bibleReading'] ??
            _devotion?['oneYearBibleReading'])
        ?.toString();
    final scriptureText = _devotion?['scriptureText']?.toString();
    final content = _devotion?['content']?.toString() ?? '';

    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(title: const Text('Daily Devotion')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  tooltip: 'Previous day',
                  onPressed: () => _changeDate(-1),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        _formatDate(_currentDate),
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (isToday)
                        Text(
                          'Today',
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: colors.primary),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  tooltip: 'Next day',
                  onPressed: () => _changeDate(1),
                ),
                IconButton(
                  icon: const Icon(Icons.calendar_today_outlined),
                  tooltip: 'Choose date',
                  onPressed: _pickDate,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error!),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: _loadDevotion,
                              child: const Text('Try again'),
                            ),
                          ],
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: colors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (anchor.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            BibleReferenceText(
                              text: anchor,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: colors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          if (reading != null && reading.trim().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            BibleReferenceText(
                              text: reading,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colors.primary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                          if (scriptureText != null &&
                              scriptureText.trim().isNotEmpty) ...[
                            const SizedBox(height: 16),
                            BibleReferenceText(
                              text: scriptureText,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontStyle: FontStyle.italic,
                                height: 1.55,
                              ),
                            ),
                          ],
                          if (content.isNotEmpty) ...[
                            const SizedBox(height: 22),
                            BibleReferenceText(
                              text: content,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                height: 1.7,
                              ),
                            ),
                          ],
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}
