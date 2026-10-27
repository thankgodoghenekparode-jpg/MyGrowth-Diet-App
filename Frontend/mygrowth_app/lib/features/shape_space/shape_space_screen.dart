import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/network/api_client.dart';

class ShapeSpaceScreen extends ConsumerStatefulWidget {
  const ShapeSpaceScreen({super.key});
  @override
  ConsumerState<ShapeSpaceScreen> createState() => _ShapeSpaceScreenState();
}

class _ShapeSpaceScreenState extends ConsumerState<ShapeSpaceScreen> {
  final _controller = TextEditingController();
  Timer? _timer;
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await ref
          .read(apiClientProvider)
          .get('/shape-space/messages');
      if (!mounted) return;
      setState(() {
        _messages = (data is Map ? data['messages'] : null) is List
            ? List<Map<String, dynamic>>.from(data['messages'] as List)
            : [];
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (mounted)
        setState(() {
          _loading = false;
          _error = 'Unable to load the conversation right now.';
        });
    }
  }

  Future<void> _send() async {
    final body = _controller.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(apiClientProvider)
          .post('/shape-space/messages', body: {'body': body});
      _controller.clear();
      await _load();
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Message could not be sent. Please try again.'),
          ),
        );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _report(Map<String, dynamic> message) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Report message'),
        children:
            ['Harassment or bullying', 'Inappropriate content', 'Spam', 'Other']
                .map(
                  (item) => SimpleDialogOption(
                    onPressed: () => Navigator.pop(context, item),
                    child: Text(item),
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
            '/shape-space/messages/${message['id']}/report',
            body: {'reason': reason},
          );
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you. The message was reported to the team.'),
          ),
        );
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not report this message.')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(authControllerProvider).user?.id;
    return Scaffold(
      appBar: AppBar(title: const Text('Shape Space')),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: Text(
              'A shared room for encouragement and thoughtful conversation. Be kind and protect one another’s privacy.',
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!),
                        TextButton(
                          onPressed: _load,
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                  )
                : _messages.isEmpty
                ? const Center(
                    child: Text('Start the conversation with a kind word.'),
                  )
                : ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[_messages.length - 1 - index];
                      final user = message['user'] is Map
                          ? message['user'] as Map
                          : const {};
                      final own = user['id'] == me;
                      final name =
                          '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'
                              .trim();
                      return Align(
                        alignment: own
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.sizeOf(context).width * .82,
                          ),
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          own
                                              ? 'You'
                                              : (name.isEmpty
                                                    ? 'Member'
                                                    : name),
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelLarge,
                                        ),
                                      ),
                                      if (!own)
                                        PopupMenuButton<String>(
                                          tooltip: 'Message options',
                                          onSelected: (_) => _report(message),
                                          itemBuilder: (_) => const [
                                            PopupMenuItem(
                                              value: 'report',
                                              child: Text('Report message'),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                  Text(message['body']?.toString() ?? ''),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 1000,
                      decoration: const InputDecoration(
                        hintText: 'Share something encouraging',
                        border: OutlineInputBorder(),
                        counterText: '',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                    tooltip: 'Send message',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
