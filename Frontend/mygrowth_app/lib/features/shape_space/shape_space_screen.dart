import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';

class ShapeSpaceScreen extends ConsumerStatefulWidget {
  const ShapeSpaceScreen({super.key});

  @override
  ConsumerState<ShapeSpaceScreen> createState() => _ShapeSpaceScreenState();
}

class _ShapeSpaceScreenState extends ConsumerState<ShapeSpaceScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _timer;
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _sending = false;
  bool _isAnonymous = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 12), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final data = await ref.read(apiClientProvider).get('/shape-space/messages');
      if (!mounted) return;

      if (data is Map) {
        final conv = data['conversation'] as Map<String, dynamic>?;
        final rawMessages = data['messages'] as List? ?? [];

        setState(() {
          if (conv != null && !_sending) {
            _isAnonymous = conv['isAnonymous'] == true;
          }
          _messages = List<Map<String, dynamic>>.from(rawMessages);
          _loading = false;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted && !silent) {
        setState(() {
          _loading = false;
          _error = 'Unable to load the counselling conversation right now.';
        });
      }
    }
  }

  Future<void> _send() async {
    final body = _controller.text.trim();
    if (body.isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      await ref.read(apiClientProvider).post(
        '/shape-space/messages',
        body: {
          'body': body,
          'isAnonymous': _isAnonymous,
        },
      );
      _controller.clear();
      await _load(silent: true);
      _scrollToBottom();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Message could not be sent. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _report(Map<String, dynamic> message) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Report message'),
        children: ['Harassment or bullying', 'Inappropriate content', 'Spam', 'Other']
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
      await ref.read(apiClientProvider).post(
        '/shape-space/messages/${message['id']}/report',
        body: {'reason': reason},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you. The report has been received.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not submit report.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final myUserId = ref.watch(authControllerProvider).user?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.shield_outlined, size: 20),
            SizedBox(width: 8),
            Text('Shape Space'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => _load(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Pastoral care banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
            child: Row(
              children: [
                Icon(Icons.verified_user_outlined, size: 24, color: colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pastoral Counselling Space',
                        style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'A confidential 1-on-1 space with the Pastor / Main Admin. Your conversation is private.',
                        style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Message history
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => _load(),
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                  )
                : _messages.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.volunteer_activism_outlined, size: 54, color: colorScheme.primary.withValues(alpha: 0.8)),
                          const SizedBox(height: 16),
                          Text(
                            'Welcome to Shape Space',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Share your questions, burdens, prayer points, or counseling needs directly with the Pastor. Choose whether to show your name or remain anonymous.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isFromAdmin = message['isFromAdmin'] == true;
                      final isAnonymous = message['isAnonymous'] == true;
                      final isMe = message['own'] == true || (!isFromAdmin && message['user']?['id'] == myUserId);

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Align(
                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.sizeOf(context).width * 0.82,
                            ),
                            child: Card(
                              elevation: isFromAdmin ? 2 : 1,
                              color: isMe
                                  ? colorScheme.primaryContainer
                                  : isFromAdmin
                                  ? colorScheme.secondaryContainer
                                  : colorScheme.surfaceContainerHighest,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(16),
                                  topRight: const Radius.circular(16),
                                  bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
                                  bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (isFromAdmin) ...[
                                          const Icon(Icons.church, size: 16),
                                          const SizedBox(width: 4),
                                        ] else if (isAnonymous) ...[
                                          const Icon(Icons.visibility_off_outlined, size: 16),
                                          const SizedBox(width: 4),
                                        ],
                                        Text(
                                          isFromAdmin
                                              ? 'Pastor / Counselor'
                                              : (isAnonymous ? 'You (Anonymous)' : 'You'),
                                          style: theme.textTheme.labelMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: isFromAdmin ? colorScheme.onSecondaryContainer : null,
                                          ),
                                        ),
                                        const Spacer(),
                                        if (!isMe)
                                          PopupMenuButton<String>(
                                            tooltip: 'Options',
                                            padding: EdgeInsets.zero,
                                            iconSize: 18,
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
                                    const SizedBox(height: 6),
                                    SelectableText(
                                      message['body']?.toString() ?? '',
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: isMe
                                            ? colorScheme.onPrimaryContainer
                                            : isFromAdmin
                                            ? colorScheme.onSecondaryContainer
                                            : colorScheme.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Anonymity Toggle Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border(top: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5))),
            ),
            child: Row(
              children: [
                Icon(
                  _isAnonymous ? Icons.visibility_off : Icons.visibility,
                  size: 18,
                  color: _isAnonymous ? colorScheme.primary : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isAnonymous ? 'Send anonymously (Name hidden from Pastor)' : 'Send with your name visible',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _isAnonymous ? colorScheme.primary : colorScheme.onSurfaceVariant,
                      fontWeight: _isAnonymous ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
                Switch.adaptive(
                  value: _isAnonymous,
                  onChanged: (val) => setState(() => _isAnonymous = val),
                ),
              ],
            ),
          ),

          // Message input bar
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 2000,
                      decoration: InputDecoration(
                        hintText: _isAnonymous
                            ? 'Type your message (anonymous)...'
                            : 'Type your message for the Pastor...',
                        border: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(24)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
