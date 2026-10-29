import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';

class AdminShapeSpaceScreen extends ConsumerStatefulWidget {
  const AdminShapeSpaceScreen({super.key});

  @override
  ConsumerState<AdminShapeSpaceScreen> createState() => _AdminShapeSpaceScreenState();
}

class _AdminShapeSpaceScreenState extends ConsumerState<AdminShapeSpaceScreen> {
  List<Map<String, dynamic>> _conversations = [];
  bool _loading = true;
  String? _error;
  Timer? _refreshTimer;

  // Selected conversation detail
  Map<String, dynamic>? _selectedConversation;
  List<Map<String, dynamic>> _threadMessages = [];
  bool _loadingThread = false;
  bool _sendingReply = false;
  final _replyController = TextEditingController();
  final _threadScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadConversations();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) => _loadConversations(silent: true));
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _replyController.dispose();
    _threadScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadConversations({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final data = await ref.read(apiClientProvider).get('/admin/shape-space/conversations');
      if (!mounted) return;
      if (data is Map && data['conversations'] is List) {
        setState(() {
          _conversations = List<Map<String, dynamic>>.from(data['conversations'] as List);
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted && !silent) {
        setState(() {
          _loading = false;
          _error = 'Unable to load pastoral counseling conversations.';
        });
      }
    }
  }

  Future<void> _openConversation(Map<String, dynamic> conv) async {
    setState(() {
      _selectedConversation = conv;
      _loadingThread = true;
      _threadMessages = [];
    });

    try {
      final data = await ref.read(apiClientProvider).get('/admin/shape-space/conversations/${conv['id']}');
      if (!mounted) return;
      if (data is Map) {
        setState(() {
          _selectedConversation = data['conversation'] as Map<String, dynamic>? ?? conv;
          _threadMessages = List<Map<String, dynamic>>.from(data['messages'] as List? ?? []);
          _loadingThread = false;
        });
        _scrollToBottom();
        _loadConversations(silent: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingThread = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load conversation thread.')),
        );
      }
    }
  }

  Future<void> _sendReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty || _selectedConversation == null || _sendingReply) return;

    setState(() => _sendingReply = true);
    try {
      await ref.read(apiClientProvider).post(
        '/admin/shape-space/conversations/${_selectedConversation!['id']}/reply',
        body: {'body': text},
      );
      _replyController.clear();
      await _openConversation(_selectedConversation!);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not send pastoral reply.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sendingReply = false);
    }
  }

  Future<void> _toggleStatus() async {
    if (_selectedConversation == null) return;
    final currentStatus = _selectedConversation!['status']?.toString();
    final newStatus = currentStatus == 'RESOLVED' ? 'OPEN' : 'RESOLVED';

    try {
      await ref.read(apiClientProvider).patch(
        '/admin/shape-space/conversations/${_selectedConversation!['id']}/status',
        body: {'status': newStatus},
      );
      setState(() {
        _selectedConversation!['status'] = newStatus;
      });
      _loadConversations(silent: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Marked conversation as $newStatus')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update status.')),
        );
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_threadScrollController.hasClients) {
        _threadScrollController.animateTo(
          _threadScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDesktop = MediaQuery.sizeOf(context).width > 768;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shape Space — Pastoral Care'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadConversations(),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => _loadConversations(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : isDesktop
          ? Row(
              children: [
                SizedBox(
                  width: 380,
                  child: _buildConversationsList(colorScheme, theme),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: _selectedConversation == null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.forum_outlined, size: 48, color: colorScheme.outline),
                              const SizedBox(height: 12),
                              Text(
                                'Select a counselling thread to view and reply',
                                style: theme.textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        )
                      : _buildThreadView(colorScheme, theme),
                ),
              ],
            )
          : _selectedConversation == null
          ? _buildConversationsList(colorScheme, theme)
          : PopScope(
              canPop: false,
              onPopInvokedWithResult: (didPop, _) {
                if (!didPop) setState(() => _selectedConversation = null);
              },
              child: _buildThreadView(colorScheme, theme, showBackButton: true),
            ),
    );
  }

  Widget _buildConversationsList(ColorScheme colorScheme, ThemeData theme) {
    if (_conversations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.mark_chat_unread_outlined, size: 48, color: colorScheme.outline),
              const SizedBox(height: 12),
              const Text('No pastoral counseling messages yet.'),
              const SizedBox(height: 6),
              Text(
                'When members reach out through Shape Space, their messages will appear here.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: _conversations.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final conv = _conversations[index];
        final isSelected = _selectedConversation?['id'] == conv['id'];
        final isAnonymous = conv['isAnonymous'] == true;
        final unread = (conv['unreadCount'] as num? ?? 0).toInt();
        final isResolved = conv['status'] == 'RESOLVED';

        return ListTile(
          selected: isSelected,
          selectedTileColor: colorScheme.primaryContainer.withValues(alpha: 0.25),
          leading: CircleAvatar(
            backgroundColor: isAnonymous ? Colors.blueGrey.shade700 : colorScheme.primary,
            child: Icon(
              isAnonymous ? Icons.visibility_off : Icons.person,
              color: Colors.white,
              size: 20,
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  conv['memberName']?.toString() ?? 'Member',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: unread > 0 ? FontWeight.bold : FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isResolved)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Resolved',
                    style: theme.textTheme.labelSmall?.copyWith(color: Colors.green.shade800),
                  ),
                ),
            ],
          ),
          subtitle: Text(
            conv['lastMessage']?['body']?.toString() ?? 'No messages yet',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: unread > 0 ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
            ),
          ),
          trailing: unread > 0
              ? Badge.count(count: unread)
              : const Icon(Icons.chevron_right, size: 18),
          onTap: () => _openConversation(conv),
        );
      },
    );
  }

  Widget _buildThreadView(ColorScheme colorScheme, ThemeData theme, {bool showBackButton = false}) {
    final conv = _selectedConversation!;
    final isAnonymous = conv['isAnonymous'] == true;
    final isResolved = conv['status'] == 'RESOLVED';

    return Column(
      children: [
        // Thread header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
          ),
          child: Row(
            children: [
              if (showBackButton)
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => setState(() => _selectedConversation = null),
                ),
              CircleAvatar(
                backgroundColor: isAnonymous ? Colors.blueGrey.shade700 : colorScheme.primary,
                child: Icon(
                  isAnonymous ? Icons.visibility_off : Icons.person,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      conv['memberName']?.toString() ?? 'Member',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    if (!isAnonymous && conv['memberEmail'] != null)
                      Text(
                        conv['memberEmail'].toString(),
                        style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                      )
                    else if (isAnonymous)
                      Text(
                        'Identity protected by member request',
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.amber.shade800),
                      ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                icon: Icon(isResolved ? Icons.replay : Icons.check_circle_outline, size: 16),
                label: Text(isResolved ? 'Reopen' : 'Mark Resolved'),
                onPressed: _toggleStatus,
              ),
            ],
          ),
        ),

        // Messages list
        Expanded(
          child: _loadingThread
              ? const Center(child: CircularProgressIndicator())
              : _threadMessages.isEmpty
              ? const Center(child: Text('No messages in this conversation yet.'))
              : ListView.builder(
                  controller: _threadScrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _threadMessages.length,
                  itemBuilder: (context, index) {
                    final msg = _threadMessages[index];
                    final isFromAdmin = msg['isFromAdmin'] == true;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Align(
                        alignment: isFromAdmin ? Alignment.centerRight : Alignment.centerLeft,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.sizeOf(context).width * 0.75,
                          ),
                          child: Card(
                            elevation: isFromAdmin ? 2 : 1,
                            color: isFromAdmin
                                ? colorScheme.primaryContainer
                                : colorScheme.surfaceContainerHighest,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        isFromAdmin
                                            ? 'You (Pastor / Counselor)'
                                            : (msg['senderName']?.toString() ?? 'Member'),
                                        style: theme.textTheme.labelMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  SelectableText(msg['body']?.toString() ?? ''),
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

        // Pastor reply bar
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _replyController,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 2000,
                    decoration: const InputDecoration(
                      hintText: 'Type your pastoral counseling reply...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(24)),
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      counterText: '',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _sendingReply ? null : _sendReply,
                  icon: _sendingReply
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                  tooltip: 'Send pastoral reply',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
