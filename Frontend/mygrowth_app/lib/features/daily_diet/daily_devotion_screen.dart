import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';

class DailyDevotionScreen extends ConsumerStatefulWidget {
  const DailyDevotionScreen({super.key});

  @override
  ConsumerState<DailyDevotionScreen> createState() => _DailyDevotionScreenState();
}

class _DailyDevotionScreenState extends ConsumerState<DailyDevotionScreen> {
  DateTime _currentDate = DateTime.now();
  Map<String, dynamic>? _devotion;
  bool _loading = true;
  String? _error;
  bool _savingNote = false;
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDevotion();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadDevotion() async {
    setState(() => _loading = true);
    final dateStr = _formatDate(_currentDate);
    try {
      final data = await ref.read(apiClientProvider).get('/devotions?date=$dateStr');
      if (!mounted) return;

      if (data is Map) {
        final dev = data['devotion'] as Map<String, dynamic>?;
        setState(() {
          _devotion = dev;
          _notesController.text = dev?['reflectionNotes']?.toString() ?? '';
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Unable to load devotion for this day.';
        });
      }
    }
  }

  Future<void> _toggleComplete() async {
    if (_devotion == null) return;
    final currentStatus = _devotion!['isCompleted'] == true;
    final newStatus = !currentStatus;

    try {
      await ref.read(apiClientProvider).post(
        '/devotions/${_devotion!['id']}/complete',
        body: {
          'isBookmarked': _devotion!['isBookmarked'],
          'reflectionNotes': _notesController.text.trim(),
        },
      );
      setState(() {
        _devotion!['isCompleted'] = newStatus;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newStatus ? 'Marked today’s devotion as completed! 🎉' : 'Completion cleared.'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update devotion status.')),
        );
      }
    }
  }

  Future<void> _toggleBookmark() async {
    if (_devotion == null) return;
    final isBookmarked = _devotion!['isBookmarked'] == true;
    final newBookmark = !isBookmarked;

    try {
      await ref.read(apiClientProvider).post(
        '/devotions/${_devotion!['id']}/complete',
        body: {
          'isBookmarked': newBookmark,
          'reflectionNotes': _notesController.text.trim(),
        },
      );
      setState(() {
        _devotion!['isBookmarked'] = newBookmark;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newBookmark ? 'Added to your bookmarked devotions.' : 'Removed bookmark.'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update bookmark.')),
        );
      }
    }
  }

  Future<void> _saveNotes() async {
    if (_devotion == null) return;
    setState(() => _savingNote = true);
    try {
      await ref.read(apiClientProvider).post(
        '/devotions/${_devotion!['id']}/complete',
        body: {
          'isBookmarked': _devotion!['isBookmarked'],
          'reflectionNotes': _notesController.text.trim(),
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notes saved successfully.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save notes.')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingNote = false);
    }
  }

  void _changeDate(int daysDelta) {
    setState(() {
      _currentDate = _currentDate.add(Duration(days: daysDelta));
    });
    _loadDevotion();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isToday = DateUtils.isSameDay(_currentDate, DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Devotion'),
        actions: [
          if (_devotion != null)
            IconButton(
              icon: Icon(
                _devotion!['isBookmarked'] == true ? Icons.bookmark : Icons.bookmark_border,
                color: _devotion!['isBookmarked'] == true ? Colors.amber : null,
              ),
              tooltip: 'Bookmark',
              onPressed: _toggleBookmark,
            ),
          IconButton(
            icon: const Icon(Icons.calendar_today),
            tooltip: 'Pick Date',
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _currentDate,
                firstDate: DateTime(2025, 1, 1),
                lastDate: DateTime(2028, 12, 31),
              );
              if (picked != null) {
                setState(() => _currentDate = picked);
                _loadDevotion();
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Date navigation header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _changeDate(-1),
                  tooltip: 'Previous day',
                ),
                Column(
                  children: [
                    Text(
                      _formatDate(_currentDate),
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    if (isToday)
                      Text(
                        'Today',
                        style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.primary),
                      ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => _changeDate(1),
                  tooltip: 'Next day',
                ),
              ],
            ),
          ),

          // Content body
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
                        ElevatedButton(
                          onPressed: _loadDevotion,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : _devotion == null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.menu_book_outlined, size: 56, color: colorScheme.outline),
                          const SizedBox(height: 16),
                          Text(
                            'Devotion Pending for ${_formatDate(_currentDate)}',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'The devotional content for this day is being prepared by the pastoral team. Please check back soon or browse another day.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(18),
                    children: [
                      // Title
                      Text(
                        _devotion!['title']?.toString() ?? 'Daily Devotion',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'By ${_devotion!['author'] ?? 'Pastor Healings E. Azuike'}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Anchor Scripture Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colorScheme.primary.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.format_quote, color: colorScheme.primary, size: 22),
                                const SizedBox(width: 8),
                                Text(
                                  _devotion!['anchorScripture']?.toString() ?? '',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                            if (_devotion!['scriptureText'] != null) ...[
                              const SizedBox(height: 8),
                              SelectableText(
                                '"${_devotion!['scriptureText']}"',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontStyle: FontStyle.italic,
                                  height: 1.4,
                                ),
                              ),
                            ],
                            if (_devotion!['scriptureReading'] != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Scripture Reading: ${_devotion!['scriptureReading']}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Main Devotional Content
                      SelectableText(
                        _devotion!['content']?.toString() ?? '',
                        style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
                      ),
                      const SizedBox(height: 22),

                      // Thought for the day
                      if (_devotion!['thoughtForTheDay'] != null) ...[
                        Card(
                          elevation: 0,
                          color: colorScheme.surfaceContainerHighest,
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.lightbulb_outline, color: Colors.amber.shade800),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Thought for Today',
                                        style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _devotion!['thoughtForTheDay']?.toString() ?? '',
                                        style: theme.textTheme.bodyMedium,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Confession & Prayer
                      if (_devotion!['confession'] != null || _devotion!['prayer'] != null) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: colorScheme.secondaryContainer.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_devotion!['confession'] != null) ...[
                                Text(
                                  'Daily Confession',
                                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                SelectableText(
                                  _devotion!['confession']?.toString() ?? '',
                                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                                ),
                                const SizedBox(height: 12),
                              ],
                              if (_devotion!['prayer'] != null) ...[
                                Text(
                                  'Prayer Point',
                                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                SelectableText(
                                  _devotion!['prayer']?.toString() ?? '',
                                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // One-year Bible reading plan
                      if (_devotion!['oneYearBibleReading'] != null) ...[
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.auto_stories_outlined),
                          title: const Text('One-Year Bible Reading Plan'),
                          subtitle: Text(_devotion!['oneYearBibleReading']?.toString() ?? ''),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Personal Reflection Notes
                      Text(
                        'My Personal Reflection Notes',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _notesController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: 'What did the Holy Spirit speak to you today?',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: _savingNote
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.save_outlined),
                            onPressed: _saveNotes,
                            tooltip: 'Save Notes',
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Complete button
                      FilledButton.icon(
                        onPressed: _toggleComplete,
                        icon: Icon(
                          _devotion!['isCompleted'] == true ? Icons.check_circle : Icons.check_circle_outline,
                        ),
                        label: Text(
                          _devotion!['isCompleted'] == true
                              ? 'Completed Today’s Devotion'
                              : 'Mark as Completed',
                        ),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: _devotion!['isCompleted'] == true ? Colors.green : null,
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
