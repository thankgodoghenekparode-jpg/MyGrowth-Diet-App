import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/widgets/app_back_button.dart';

class AdminMinistryPlatformScreen extends ConsumerStatefulWidget {
  const AdminMinistryPlatformScreen({super.key});
  @override
  ConsumerState<AdminMinistryPlatformScreen> createState() =>
      _AdminMinistryPlatformScreenState();
}

class _AdminMinistryPlatformScreenState
    extends ConsumerState<AdminMinistryPlatformScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: const AppBackButton(),
      title: const Text('Ministry Platform'),
      bottom: TabBar(
        controller: _tabs,
        isScrollable: true,
        tabs: const [
          Tab(text: 'Giving'),
          Tab(text: 'Partners'),
          Tab(text: 'Categories'),
          Tab(text: 'Programmes'),
          Tab(text: 'Live'),
          Tab(text: 'Prayer'),
        ],
      ),
    ),
    body: TabBarView(
      controller: _tabs,
      children: const [
        _AdminDataList(
          path: '/admin/giving/transactions',
          kind: _AdminListKind.giving,
        ),
        _AdminDataList(
          path: '/admin/giving/partners',
          kind: _AdminListKind.partners,
        ),
        _AdminDataList(
          path: '/admin/giving/categories',
          kind: _AdminListKind.categories,
        ),
        _AdminDataList(path: '/admin/events', kind: _AdminListKind.events),
        _AdminDataList(path: '/admin/live-services', kind: _AdminListKind.live),
        _AdminDataList(
          path: '/admin/prayer-requests',
          kind: _AdminListKind.prayers,
        ),
      ],
    ),
  );
}

enum _AdminListKind { giving, partners, categories, events, live, prayers }

class _AdminDataList extends ConsumerStatefulWidget {
  const _AdminDataList({required this.path, required this.kind});
  final String path;
  final _AdminListKind kind;
  @override
  ConsumerState<_AdminDataList> createState() => _AdminDataListState();
}

class _AdminDataListState extends ConsumerState<_AdminDataList> {
  late Future<Map<String, dynamic>> _data;
  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  Future<Map<String, dynamic>> _load() async =>
      await ref.read(apiClientProvider).get(widget.path)
          as Map<String, dynamic>;

  Future<void> _markRead(Map<String, dynamic> row) async {
    try {
      await ref
          .read(apiClientProvider)
          .patch('/admin/prayer-requests/${row['id']}', body: {'isRead': true});
      if (mounted) setState(() => _data = _load());
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _changeServiceStatus(
    Map<String, dynamic> row,
    String status,
  ) async {
    try {
      await ref
          .read(apiClientProvider)
          .patch('/admin/live-services/${row['id']}', body: {'status': status});
      if (mounted) setState(() => _data = _load());
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _changeEventStatus(
    Map<String, dynamic> row,
    String status,
  ) async {
    try {
      await ref
          .read(apiClientProvider)
          .patch('/admin/events/${row['id']}', body: {'status': status});
      if (mounted) setState(() => _data = _load());
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _setCategoryActive(Map<String, dynamic> row, bool active) async {
    try {
      await ref
          .read(apiClientProvider)
          .patch(
            '/admin/giving/categories/${row['id']}',
            body: {'isActive': active},
          );
      if (mounted) setState(() => _data = _load());
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _deleteRecord(String path, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete record?'),
        content: Text('Delete “$title”? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ref.read(apiClientProvider).delete(path);
      if (mounted) setState(() => _data = _load());
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _showRegistrations(Map<String, dynamic> row) async {
    try {
      final result =
          await ref
                  .read(apiClientProvider)
                  .get('/admin/events/${row['id']}/registrations')
              as Map<String, dynamic>;
      if (!mounted) return;
      final registrations = result['items'] as List<dynamic>? ?? [];
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Attendees · ${row['title']}'),
          content: SizedBox(
            width: 400,
            child: registrations.isEmpty
                ? const Text('No attendees registered yet.')
                : ListView(
                    shrinkWrap: true,
                    children: registrations.map((value) {
                      final registration = value as Map<String, dynamic>;
                      final user =
                          registration['user'] as Map<String, dynamic>?;
                      final name = user == null
                          ? registration['guestName'] ?? 'Guest'
                          : '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'
                                .trim();
                      return ListTile(
                        title: Text('$name'),
                        subtitle: Text(
                          [
                            '${user?['email'] ?? registration['guestEmail'] ?? ''}',
                            if (registration['guestPhone'] != null)
                              '${registration['guestPhone']}',
                          ].where((value) => value.isNotEmpty).join(' · '),
                        ),
                      );
                    }).toList(),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<Map<String, dynamic>?> _uploadImage() async {
    final selected = await FilePicker.pickFile(
      dialogTitle: 'Choose an image',
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'gif'],
    );
    if (selected == null) return null;
    final bytes = await selected.readAsBytes();
    final extension = selected.extension?.toLowerCase();
    final mimeType = switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      _ => null,
    };
    final result = await ref
        .read(apiClientProvider)
        .upload(
          '/admin/files',
          bytes: bytes,
          fieldName: 'file',
          filename: selected.name,
          contentType: mimeType,
        );
    return (result as Map<String, dynamic>)['file'] as Map<String, dynamic>?;
  }

  Future<void> _createRecord([Map<String, dynamic>? existing]) async {
    final title = TextEditingController();
    final streamUrl = TextEditingController();
    final minister = TextEditingController();
    final description = TextEditingController();
    final venue = TextEditingController();
    final meetingLink = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final event = widget.kind == _AdminListKind.events;
    final editing = existing != null;
    title.text = '${existing?['title'] ?? ''}';
    streamUrl.text = '${existing?['streamUrl'] ?? ''}';
    minister.text = '${existing?['minister'] ?? ''}';
    description.text = '${existing?['description'] ?? ''}';
    venue.text = '${existing?['venue'] ?? ''}';
    meetingLink.text = '${existing?['meetingLink'] ?? ''}';
    _newEventCategory = '${existing?['category'] ?? 'CHURCH_SERVICE'}';
    _newStreamPlatform = '${existing?['platform'] ?? 'YOUTUBE'}';
    var starts =
        DateTime.tryParse(
          '${existing?[event ? 'startDate' : 'scheduledAt'] ?? ''}',
        )?.toLocal() ??
        DateTime.now().add(const Duration(days: 1));
    var registrationRequired = existing?['registrationRequired'] == true;
    String? imageFileId = event
        ? (existing?['bannerFileId'] as String?)
        : (existing?['thumbnailFileId'] as String?);
    final existingImage = event
        ? (existing?['bannerFile'] as Map<String, dynamic>?)
        : (existing?['thumbnailFile'] as Map<String, dynamic>?);
    var imageFileName = existingImage?['originalName'] as String?;
    var uploadingImage = false;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            event
                ? (editing ? 'Edit programme' : 'New programme')
                : (editing ? 'Edit live service' : 'Schedule live service'),
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: title,
                    decoration: const InputDecoration(labelText: 'Title'),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Enter a title' : null,
                  ),
                  if (event)
                    DropdownButtonFormField<String>(
                      initialValue: _newEventCategory,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: const [
                        DropdownMenuItem(
                          value: 'CHURCH_SERVICE',
                          child: Text('Church service'),
                        ),
                        DropdownMenuItem(
                          value: 'PRAYER_MEETING',
                          child: Text('Prayer meeting'),
                        ),
                        DropdownMenuItem(
                          value: 'CONFERENCE',
                          child: Text('Conference'),
                        ),
                        DropdownMenuItem(
                          value: 'SPECIAL_PROGRAMME',
                          child: Text('Special programme'),
                        ),
                        DropdownMenuItem(
                          value: 'BIBLE_STUDY',
                          child: Text('Bible study'),
                        ),
                        DropdownMenuItem(
                          value: 'FASTING_PROGRAMME',
                          child: Text('Fasting programme'),
                        ),
                        DropdownMenuItem(
                          value: 'ONLINE_MEETING',
                          child: Text('Online meeting'),
                        ),
                        DropdownMenuItem(
                          value: 'OTHER_EVENT',
                          child: Text('Other'),
                        ),
                      ],
                      onChanged: (value) => setDialogState(
                        () => _newEventCategory = value ?? 'CHURCH_SERVICE',
                      ),
                    ),
                  if (event) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: uploadingImage
                            ? null
                            : () async {
                                setDialogState(() => uploadingImage = true);
                                try {
                                  final file = await _uploadImage();
                                  if (file != null && dialogContext.mounted) {
                                    setDialogState(() {
                                      imageFileId = '${file['id']}';
                                      imageFileName = '${file['originalName']}';
                                    });
                                  }
                                } catch (error) {
                                  if (dialogContext.mounted) {
                                    ScaffoldMessenger.of(dialogContext)
                                      ..hideCurrentSnackBar()
                                      ..showSnackBar(
                                        SnackBar(content: Text('$error')),
                                      );
                                  }
                                } finally {
                                  if (dialogContext.mounted) {
                                    setDialogState(
                                      () => uploadingImage = false,
                                    );
                                  }
                                }
                              },
                        icon: uploadingImage
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.image_outlined),
                        label: Text(
                          imageFileName ??
                              (uploadingImage
                                  ? 'Uploading image…'
                                  : 'Upload banner'),
                        ),
                      ),
                    ),
                    TextFormField(
                      controller: description,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                      ),
                      maxLines: 3,
                    ),
                    TextFormField(
                      controller: venue,
                      decoration: const InputDecoration(
                        labelText: 'Venue / meeting location',
                      ),
                    ),
                    TextFormField(
                      controller: meetingLink,
                      decoration: const InputDecoration(
                        labelText: 'Online meeting link',
                      ),
                      keyboardType: TextInputType.url,
                    ),
                    TextFormField(
                      controller: minister,
                      decoration: const InputDecoration(
                        labelText: 'Minister / speaker',
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Registration required'),
                      value: registrationRequired,
                      onChanged: (value) =>
                          setDialogState(() => registrationRequired = value),
                    ),
                  ] else ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: uploadingImage
                            ? null
                            : () async {
                                setDialogState(() => uploadingImage = true);
                                try {
                                  final file = await _uploadImage();
                                  if (file != null && dialogContext.mounted) {
                                    setDialogState(() {
                                      imageFileId = '${file['id']}';
                                      imageFileName = '${file['originalName']}';
                                    });
                                  }
                                } catch (error) {
                                  if (dialogContext.mounted) {
                                    ScaffoldMessenger.of(dialogContext)
                                      ..hideCurrentSnackBar()
                                      ..showSnackBar(
                                        SnackBar(content: Text('$error')),
                                      );
                                  }
                                } finally {
                                  if (dialogContext.mounted) {
                                    setDialogState(
                                      () => uploadingImage = false,
                                    );
                                  }
                                }
                              },
                        icon: uploadingImage
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.image_outlined),
                        label: Text(
                          imageFileName ??
                              (uploadingImage
                                  ? 'Uploading image…'
                                  : 'Upload thumbnail'),
                        ),
                      ),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: _newStreamPlatform,
                      decoration: const InputDecoration(labelText: 'Platform'),
                      items: const [
                        DropdownMenuItem(
                          value: 'YOUTUBE',
                          child: Text('YouTube'),
                        ),
                        DropdownMenuItem(
                          value: 'FACEBOOK',
                          child: Text('Facebook'),
                        ),
                        DropdownMenuItem(
                          value: 'OTHER_PLATFORM',
                          child: Text('Other'),
                        ),
                      ],
                      onChanged: (value) => setDialogState(
                        () => _newStreamPlatform = value ?? 'YOUTUBE',
                      ),
                    ),
                    TextFormField(
                      controller: minister,
                      decoration: const InputDecoration(labelText: 'Minister'),
                    ),
                    TextFormField(
                      controller: streamUrl,
                      decoration: const InputDecoration(
                        labelText: 'Streaming URL',
                      ),
                      keyboardType: TextInputType.url,
                    ),
                    TextFormField(
                      controller: description,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                      ),
                      maxLines: 3,
                    ),
                  ],
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: dialogContext,
                          initialDate: starts,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now().add(
                            const Duration(days: 3650),
                          ),
                        );
                        if (date == null || !dialogContext.mounted) return;
                        final time = await showTimePicker(
                          context: dialogContext,
                          initialTime: TimeOfDay.fromDateTime(starts),
                        );
                        if (time == null) return;
                        setDialogState(
                          () => starts = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            time.hour,
                            time.minute,
                          ),
                        );
                      },
                      icon: const Icon(Icons.schedule_outlined),
                      label: Text(
                        '${MaterialLocalizations.of(context).formatFullDate(starts)} · ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(starts))}',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate())
                  Navigator.pop(dialogContext, true);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (saved != true || !mounted) {
      title.dispose();
      streamUrl.dispose();
      minister.dispose();
      description.dispose();
      venue.dispose();
      meetingLink.dispose();
      return;
    }
    final body = event
        ? <String, dynamic>{
            'title': title.text.trim(),
            'category': _newEventCategory,
            'description': description.text.trim(),
            'venue': venue.text.trim(),
            'meetingLink': meetingLink.text.trim().isEmpty
                ? null
                : meetingLink.text.trim(),
            'minister': minister.text.trim(),
            'registrationRequired': registrationRequired,
            'bannerFileId': imageFileId,
            'startDate': starts.toUtc().toIso8601String(),
            'status': existing?['status'] ?? 'DRAFT',
            'timezone': 'Africa/Lagos',
          }
        : <String, dynamic>{
            'title': title.text.trim(),
            'minister': minister.text.trim(),
            'streamUrl': streamUrl.text.trim().isEmpty
                ? null
                : streamUrl.text.trim(),
            'description': description.text.trim(),
            'platform': _newStreamPlatform,
            'thumbnailFileId': imageFileId,
            'scheduledAt': starts.toUtc().toIso8601String(),
            'status': existing?['status'] ?? 'SCHEDULED',
            'timezone': 'Africa/Lagos',
          };
    title.dispose();
    streamUrl.dispose();
    minister.dispose();
    description.dispose();
    venue.dispose();
    meetingLink.dispose();
    try {
      final path = event ? '/admin/events' : '/admin/live-services';
      if (editing) {
        await ref
            .read(apiClientProvider)
            .patch('$path/${existing['id']}', body: body);
      } else {
        await ref.read(apiClientProvider).post(path, body: body);
      }
      if (mounted) setState(() => _data = _load());
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  String _newEventCategory = 'CHURCH_SERVICE';
  String _newStreamPlatform = 'YOUTUBE';

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: _data,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting)
        return const Center(child: CircularProgressIndicator());
      if (snapshot.hasError)
        return Center(child: Text('Could not load records. ${snapshot.error}'));
      final payload = snapshot.data ?? {};
      final rows = payload['items'] as List<dynamic>? ?? [];
      final summary = payload['summary'] as Map<String, dynamic>?;
      if (rows.isEmpty)
        return RefreshIndicator(
          onRefresh: () async => setState(() => _data = _load()),
          child: ListView(
            children: [
              if (summary != null) _GivingSummary(summary: summary),
              if (widget.kind == _AdminListKind.events ||
                  widget.kind == _AdminListKind.live)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: OutlinedButton.icon(
                    onPressed: _createRecord,
                    icon: const Icon(Icons.add),
                    label: Text(
                      widget.kind == _AdminListKind.events
                          ? 'Create programme'
                          : 'Schedule service',
                    ),
                  ),
                ),
              const SizedBox(height: 200),
              const Center(child: Text('No records yet.')),
            ],
          ),
        );
      return RefreshIndicator(
        onRefresh: () async => setState(() => _data = _load()),
        child: ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount:
              rows.length +
              (summary == null ? 0 : 1) +
              ((widget.kind == _AdminListKind.events ||
                      widget.kind == _AdminListKind.live)
                  ? 1
                  : 0),
          itemBuilder: (context, index) {
            if (summary != null && index == 0)
              return _GivingSummary(summary: summary);
            final offset = summary == null ? 0 : 1;
            if ((widget.kind == _AdminListKind.events ||
                    widget.kind == _AdminListKind.live) &&
                index == offset) {
              return OutlinedButton.icon(
                onPressed: _createRecord,
                icon: const Icon(Icons.add),
                label: Text(
                  widget.kind == _AdminListKind.events
                      ? 'Create programme'
                      : 'Schedule service',
                ),
              );
            }
            final row =
                rows[index -
                        offset -
                        ((widget.kind == _AdminListKind.events ||
                                widget.kind == _AdminListKind.live)
                            ? 1
                            : 0)]
                    as Map<String, dynamic>;
            return _tile(row);
          },
        ),
      );
    },
  );

  Widget _tile(Map<String, dynamic> row) {
    switch (widget.kind) {
      case _AdminListKind.giving:
        final category = row['category'] as Map<String, dynamic>? ?? {};
        return Card(
          child: ListTile(
            leading: const Icon(Icons.volunteer_activism_outlined),
            title: Text(
              '${category['name'] ?? 'Giving'} · ₦${row['amount'] ?? ''}',
            ),
            subtitle: Text(
              '${row['status']} · ${row['donorName'] ?? 'Guest'} · ${row['receiptNumber'] ?? row['paymentReference']}',
            ),
          ),
        );
      case _AdminListKind.categories:
        final active = row['isActive'] == true;
        return Card(
          child: ListTile(
            leading: const Icon(Icons.category_outlined),
            title: Text('${row['name'] ?? 'Category'}'),
            subtitle: Text(
              '${row['type'] ?? ''} · ${active ? 'Active' : 'Inactive'}',
            ),
            trailing: Switch(
              value: active,
              onChanged: (value) => _setCategoryActive(row, value),
            ),
          ),
        );
      case _AdminListKind.partners:
        final user = row['user'] as Map<String, dynamic>? ?? {};
        return Card(
          child: ListTile(
            leading: const Icon(Icons.volunteer_activism_outlined),
            title: Text(
              '${user['firstName'] ?? ''} ${user['lastName'] ?? ''} · ₦${row['amount'] ?? ''}',
            ),
            subtitle: Text(
              '${user['email'] ?? ''} · ${row['frequency']} · ${row['status']}',
            ),
          ),
        );
      case _AdminListKind.events:
        return Card(
          child: ListTile(
            leading: const Icon(Icons.event_outlined),
            title: Text('${row['title'] ?? 'Programme'}'),
            subtitle: Text(
              '${row['status']} · ${row['category']} · ${row['_count']?['registrations'] ?? 0} registered',
            ),
            onTap: () => _showRegistrations(row),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'DELETE') {
                  _deleteRecord(
                    '/admin/events/${row['id']}',
                    '${row['title']}',
                  );
                } else if (value == 'EDIT') {
                  _createRecord(row);
                } else {
                  _changeEventStatus(row, value);
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'EDIT',
                  child: Text('Edit programme'),
                ),
                if (row['status'] != 'PUBLISHED')
                  const PopupMenuItem(
                    value: 'PUBLISHED',
                    child: Text('Publish'),
                  ),
                if (row['status'] == 'PUBLISHED')
                  const PopupMenuItem(
                    value: 'COMPLETED',
                    child: Text('Mark completed'),
                  ),
                if (row['status'] != 'CANCELLED' &&
                    row['status'] != 'COMPLETED')
                  const PopupMenuItem(
                    value: 'CANCELLED',
                    child: Text('Cancel programme'),
                  ),
                const PopupMenuItem(
                  value: 'DELETE',
                  child: Text('Delete programme'),
                ),
              ],
            ),
          ),
        );
      case _AdminListKind.live:
        final status = '${row['status'] ?? 'SCHEDULED'}';
        return Card(
          child: ListTile(
            leading: Icon(
              status == 'LIVE' ? Icons.sensors_rounded : Icons.live_tv_outlined,
            ),
            title: Text('${row['title'] ?? 'Service'}'),
            subtitle: Text(
              '$status · ${row['platform']} · ${row['scheduledAt'] ?? ''}',
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'DELETE') {
                  _deleteRecord(
                    '/admin/live-services/${row['id']}',
                    '${row['title']}',
                  );
                } else if (value == 'EDIT') {
                  _createRecord(row);
                } else {
                  _changeServiceStatus(row, value);
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'EDIT', child: Text('Edit service')),
                if (status != 'LIVE' && status != 'ENDED')
                  const PopupMenuItem(
                    value: 'LIVE',
                    child: Text('Start broadcast'),
                  ),
                if (status == 'LIVE')
                  const PopupMenuItem(
                    value: 'ENDED',
                    child: Text('End broadcast'),
                  ),
                const PopupMenuItem(
                  value: 'DELETE',
                  child: Text('Delete service'),
                ),
              ],
            ),
          ),
        );
      case _AdminListKind.prayers:
        final read = row['isRead'] == true;
        return Card(
          child: ListTile(
            leading: Icon(
              read
                  ? Icons.mark_email_read_outlined
                  : Icons.mark_email_unread_outlined,
            ),
            title: Text('${row['name']}${read ? ' · Read' : ''}'),
            subtitle: Text('${row['request'] ?? ''}'),
            trailing: read
                ? null
                : IconButton(
                    tooltip: 'Mark as read',
                    onPressed: () => _markRead(row),
                    icon: const Icon(Icons.done),
                  ),
          ),
        );
    }
  }
}

class _GivingSummary extends StatelessWidget {
  const _GivingSummary({required this.summary});
  final Map<String, dynamic> summary;
  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.primaryContainer,
    child: ListTile(
      leading: const Icon(Icons.account_balance_wallet_outlined),
      title: Text('Confirmed giving: ₦${summary['totalPaid'] ?? 0}'),
      subtitle: Text('${summary['paidCount'] ?? 0} completed transactions'),
    ),
  );
}
