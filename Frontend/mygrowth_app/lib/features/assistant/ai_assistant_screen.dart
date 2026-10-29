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
    try {
      final data = await ref
          .read(apiClientProvider)
          .post(
            '/me/ai-assistant',
            body: {'messages': _messages.takeLast(12).map((m) => m).toList()},
          );
      final answer = data is Map ? data['answer']?.toString() : null;
      if (answer == null || answer.isEmpty) throw StateError('Empty response');
      if (mounted) {
        setState(() => _messages.add({'role': 'assistant', 'content': answer}));
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(
          () => _error = error.code == 'AI_NOT_CONFIGURED'
              ? 'The assistant is being set up. Please try again later.'
              : 'I could not respond just now. Please try again.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'I could not respond just now. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('AI Assistant')),
    body: Column(
      children: [
        if (_messages.isEmpty)
          Expanded(
            child: Center(
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
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children:
                          [
                                'Help me reflect on today\'s devotion',
                                'Guide me in a morning prayer',
                                'Explain a Bible passage to me',
                                'Give me an encouraging scripture for faith',
                                'How can I build consistency in prayer?',
                              ]
                              .map(
                                (q) => ActionChip(
                                  label: Text(q),
                                  onPressed: _sending ? null : () => _send(q),
                                ),
                              )
                              .toList(),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Powered by Google Gemini. For reflection and learning. Speak with the Pastor in Shape Space for personal pastoral care.',
                      textAlign: TextAlign.center,
                    ),
                  ],
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
              itemBuilder: (context, i) {
                final message = _messages[_messages.length - 1 - i];
                final own = message['role'] == 'user';
                return Align(
                  alignment: own ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    padding: const EdgeInsets.all(12),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.sizeOf(context).width * .86,
                    ),
                    decoration: BoxDecoration(
                      color: own
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
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
            padding: const EdgeInsets.all(8),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        SafeArea(
          top: false,
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
      ],
    ),
  );
}

extension<T> on Iterable<T> {
  Iterable<T> takeLast(int count) => skip(length > count ? length - count : 0);
}
