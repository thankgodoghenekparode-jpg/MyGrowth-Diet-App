import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/auth/auth_controller.dart';

class ShapeSpaceScreen extends ConsumerStatefulWidget {
  const ShapeSpaceScreen({super.key});

  @override
  ConsumerState<ShapeSpaceScreen> createState() => _ShapeSpaceScreenState();
}

class _ShapeSpaceScreenState extends ConsumerState<ShapeSpaceScreen> {
  final _answerController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _refreshTimer;
  List<Map<String, dynamic>> _questions = [];
  Map<String, dynamic>? _selectedQuestion;
  List<Map<String, dynamic>> _answers = [];
  bool _loading = true;
  bool _loadingThread = false;
  bool _sending = false;
  bool _answerAnonymously = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _loadQuestions(silent: true),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _answerController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadQuestions({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);
    try {
      final data = await ref
          .read(apiClientProvider)
          .get('/shape-space/questions')
          .timeout(const Duration(seconds: 20));
      if (!mounted) return;
      setState(() {
        _questions = List<Map<String, dynamic>>.from(
          data is Map ? data['questions'] as List? ?? const [] : const [],
        );
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (mounted && !silent) {
        setState(() {
          _loading = false;
          _error = 'Unable to load the Shape Space community right now.';
        });
      }
    }
  }

  Future<void> _openQuestion(Map<String, dynamic> question) async {
    setState(() {
      _selectedQuestion = question;
      _loadingThread = true;
      _answers = [];
    });
    try {
      final data = await ref
          .read(apiClientProvider)
          .get('/shape-space/questions/${question['id']}')
          .timeout(const Duration(seconds: 20));
      if (!mounted || data is! Map) return;
      setState(() {
        _selectedQuestion = Map<String, dynamic>.from(
          data['question'] as Map? ?? question,
        );
        _answers = List<Map<String, dynamic>>.from(
          data['answers'] as List? ?? const [],
        );
        _loadingThread = false;
      });
      _scrollToBottom();
    } catch (_) {
      if (mounted) {
        setState(() => _loadingThread = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open that question.')),
        );
      }
    }
  }

  Future<void> _askQuestion() async {
    final controller = TextEditingController();
    var anonymous = false;
    final post = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            scrollable: true,
          title: const Text('Ask the community'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                minLines: 3,
                maxLines: 7,
                maxLength: 2000,
                decoration: const InputDecoration(
                  hintText: 'What would you like to ask?',
                  border: OutlineInputBorder(),
                ),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Post anonymously'),
                value: anonymous,
                onChanged: (value) => setDialogState(() => anonymous = value),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final body = controller.text.trim();
                if (body.isNotEmpty) {
                  Navigator.pop(dialogContext, {
                    'body': body,
                    'isAnonymous': anonymous,
                  });
                }
              },
              child: const Text('Post question'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (post == null || !mounted) return;

    setState(() => _sending = true);
    try {
      final data = await ref
          .read(apiClientProvider)
          .post('/shape-space/questions', body: post);
      await _loadQuestions(silent: true);
      final question = data is Map ? data['question'] : null;
      if (question is Map<String, dynamic> && mounted) {
        await _openQuestion(question);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not post your question. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendAnswer() async {
    final body = _answerController.text.trim();
    final question = _selectedQuestion;
    if (body.isEmpty || question == null || _sending) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(apiClientProvider)
          .post(
            '/shape-space/questions/${question['id']}/answers',
            body: {'body': body, 'isAnonymous': _answerAnonymously},
          );
      _answerController.clear();
      await _openQuestion(question);
      await _loadQuestions(silent: true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not post your answer. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _report(Map<String, dynamic> post) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Report post'),
        children:
            ['Harassment or bullying', 'Inappropriate content', 'Spam', 'Other']
                .map(
                  (reason) => SimpleDialogOption(
                    onPressed: () => Navigator.pop(context, reason),
                    child: Text(reason),
                  ),
                )
                .toList(),
      ),
    );
    if (reason == null || !mounted) return;
    try {
      await ref
          .read(apiClientProvider)
          .post(
            '/shape-space/messages/${post['messageId'] ?? post['id']}/report',
            body: {'reason': reason},
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thanks. The post was reported for review.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not submit the report.')),
        );
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _dateLabel(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (date == null) return '';
    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;
    return isToday
        ? DateFormat('h:mm a').format(date)
        : DateFormat('d MMM, h:mm a').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: _selectedQuestion == null
            ? IconButton(
                tooltip: 'Back to Home',
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/home');
                  }
                },
                icon: const Icon(Icons.arrow_back),
              )
            : IconButton(
                tooltip: 'Back to questions',
                onPressed: () => setState(() => _selectedQuestion = null),
                icon: const Icon(Icons.arrow_back),
              ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Shape Space'),
            Text('Community Q&A', style: theme.textTheme.labelSmall),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh questions',
            onPressed: () => _loadQuestions(),
          ),
        ],
      ),
      body: _selectedQuestion == null
          ? _buildFeed(theme, colors)
          : _buildThread(theme, colors),
      floatingActionButton: _selectedQuestion == null
          ? FloatingActionButton.extended(
              onPressed: _sending ? null : _askQuestion,
              icon: const Icon(Icons.add_comment_outlined),
              label: const Text('Ask a question'),
            )
          : null,
    );
  }

  Widget _buildFeed(ThemeData theme, ColorScheme colors) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => _loadQuestions(),
              child: const Text('Try again'),
            ),
          ],
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: [
        Card(
          color: colors.primaryContainer.withValues(alpha: 0.65),
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.forum_outlined),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ask, share, and learn together',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Questions are shared with the community. Anyone can join the conversation, and you can post anonymously.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (_questions.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Column(
              children: [
                Icon(Icons.question_answer_outlined, size: 48),
                SizedBox(height: 12),
                Text('No questions yet'),
                SizedBox(height: 4),
                Text('Start the conversation by asking the community.'),
              ],
            ),
          )
        else
          for (final question in _questions) ...[
            Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => _openQuestion(question),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            child: Icon(
                              question['isAnonymous'] == true
                                  ? Icons.person_off_outlined
                                  : Icons.person_outline,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              question['authorName']?.toString() ??
                                  'Community member',
                              style: theme.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            _dateLabel(question['createdAt']),
                            style: theme.textTheme.labelSmall,
                          ),
                          if (question['own'] != true)
                            PopupMenuButton<String>(
                              tooltip: 'Question options',
                              onSelected: (_) => _report(question),
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'report',
                                  child: Text('Report question'),
                                ),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        question['body']?.toString() ?? '',
                        style: theme.textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 17,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${question['answerCount'] ?? 0} answers',
                            style: theme.textTheme.labelMedium,
                          ),
                          const Spacer(),
                          const Text('Join in'),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right, size: 18),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
      ],
    );
  }

  Widget _buildThread(ThemeData theme, ColorScheme colors) {
    final question = _selectedQuestion!;
    return Column(
      children: [
        Expanded(
          child: _loadingThread
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      color: colors.primaryContainer.withValues(alpha: 0.55),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    question['authorName']?.toString() ??
                                        'Community member',
                                    style: theme.textTheme.labelLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Text(
                                  _dateLabel(question['createdAt']),
                                  style: theme.textTheme.labelSmall,
                                ),
                                if (question['own'] != true)
                                  PopupMenuButton<String>(
                                    tooltip: 'Question options',
                                    onSelected: (_) => _report(question),
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(
                                        value: 'report',
                                        child: Text('Report question'),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              question['body']?.toString() ?? '',
                              style: theme.textTheme.titleMedium,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Community answers',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (_answers.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: Text('No answers yet. Be the first to help.'),
                        ),
                      ),
                    for (final answer in _answers)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      answer['authorName']?.toString() ??
                                          'Community member',
                                      style: theme.textTheme.labelLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                  Text(
                                    _dateLabel(answer['createdAt']),
                                    style: theme.textTheme.labelSmall,
                                  ),
                                  if (answer['own'] != true)
                                    PopupMenuButton<String>(
                                      tooltip: 'Answer options',
                                      onSelected: (_) => _report(answer),
                                      itemBuilder: (_) => const [
                                        PopupMenuItem(
                                          value: 'report',
                                          child: Text('Report answer'),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              SelectableText(answer['body']?.toString() ?? ''),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border(top: BorderSide(color: colors.outlineVariant)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  dense: true,
                  title: const Text('Answer anonymously'),
                  value: _answerAnonymously,
                  onChanged: (value) =>
                      setState(() => _answerAnonymously = value),
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _answerController,
                        minLines: 1,
                        maxLines: 4,
                        maxLength: 2000,
                        decoration: const InputDecoration(
                          hintText: 'Share an answer…',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(24)),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          counterText: '',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      tooltip: 'Post answer',
                      onPressed: _sending ? null : _sendAnswer,
                      icon: _sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
