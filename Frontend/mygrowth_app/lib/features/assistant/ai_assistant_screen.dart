import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/network/api_client.dart';

class AiAssistantScreen extends ConsumerStatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  ConsumerState<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends ConsumerState<AiAssistantScreen> {
  final _input = TextEditingController();
  final List<Map<String, String>> _messages = [];
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _send([String? suggestion]) async {
    final text = (suggestion ?? _input.text).trim();
    if (text.isEmpty || _sending) return;

    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _sending = true;
      _error = null;
    });
    _input.clear();
    await _requestAnswer();
  }

  Future<void> _retry() async {
    if (_sending || _messages.isEmpty || _messages.last['role'] != 'user') {
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    await _requestAnswer();
  }

  Future<void> _requestAnswer() async {
    try {
      final data = await ref.read(apiClientProvider).post(
        '/me/ai-assistant',
        body: {'messages': _messages.takeLast(12).toList()},
      );
      final answer = data is Map ? data['answer']?.toString() : null;
      if (answer == null || answer.isEmpty) throw StateError('Empty response');
      if (mounted) {
        setState(() => _messages.add({'role': 'assistant', 'content': answer}));
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _error = error.code == 'AI_NOT_CONFIGURED'
            ? 'The assistant is being set up. Please try again later.'
            : 'I could not respond just now. Check your connection and try again.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'I could not respond just now. Check your connection and try again.');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final messageMaxWidth = viewportWidth < 760 ? viewportWidth * .88 : 760.0;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('AI Assistant')),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            if (_messages.isEmpty)
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.auto_awesome_outlined, size: 42),
                          const SizedBox(height: 12),
                          Text(
                            'How can I support your spiritual growth today?',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleLarge,
                          ),
                          const SizedBox(height: 18),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: [
                              'How do I use the Daily Diet?',
                              'Where can I read today\'s devotion?',
                              'How do I ask a question in Shape Space?',
                              'Guide me in a morning prayer',
                              'Explain a Bible passage to me',
                            ].map((question) => ActionChip(
                              label: Text(question),
                              onPressed: _sending ? null : () => _send(question),
                            )).toList(),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Ask how to use app features or get spiritual-growth guidance. AI answers may need confirmation from a ministry administrator.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(12),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[_messages.length - 1 - index];
                    final own = message['role'] == 'user';
                    return Align(
                      alignment:
                          own ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        padding: const EdgeInsets.all(12),
                        constraints: BoxConstraints(maxWidth: messageMaxWidth),
                        decoration: BoxDecoration(
                          color: own
                              ? theme.colorScheme.primaryContainer
                              : theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: SelectableText(message['content'] ?? ''),
                      ),
                    );
                  },
                ),
              ),
            if (_sending) const LinearProgressIndicator(),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  children: [
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                    if (_messages.isNotEmpty &&
                        _messages.last['role'] == 'user')
                      TextButton(
                        onPressed: _sending ? null : _retry,
                        child: const Text('Try again'),
                      ),
                  ],
                ),
              ),
            SafeArea(
              top: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 840),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _input,
                            minLines: 1,
                            maxLines: 4,
                            maxLength: 3000,
                            onSubmitted: (_) => _send(),
                            decoration: const InputDecoration(
                              hintText: 'Ask a question',
                              border: OutlineInputBorder(),
                              counterText: '',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: _sending ? null : () => _send(),
                          icon: const Icon(Icons.send_rounded),
                          tooltip: 'Send',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension<T> on Iterable<T> {
  Iterable<T> takeLast(int count) => skip(length > count ? length - count : 0);
}
