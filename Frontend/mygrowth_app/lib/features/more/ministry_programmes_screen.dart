import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/config/app_config.dart';
import '../../core/widgets/app_back_button.dart';

class MinistryProgrammesScreen extends ConsumerStatefulWidget {
  const MinistryProgrammesScreen({super.key});

  @override
  ConsumerState<MinistryProgrammesScreen> createState() =>
      _MinistryProgrammesScreenState();
}

class _MinistryProgrammesScreenState
    extends ConsumerState<MinistryProgrammesScreen> {
  late Future<List<dynamic>> _events;
  bool _past = false;

  @override
  void initState() {
    super.initState();
    _events = _load();
  }

  Future<List<dynamic>> _load() async {
    final response =
        await ref
                .read(apiClientProvider)
                .get(_past ? '/events/past' : '/events')
            as Map<String, dynamic>;
    final data = response;
    if (data is List) return data;
    if (data is Map && data['events'] is List) return data['events'] as List;
    return const [];
  }

  Future<void> _register(String id) async {
    final user = ref.read(authControllerProvider).user;
    Map<String, dynamic>? guestDetails;
    if (user == null) {
      final name = TextEditingController();
      final email = TextEditingController();
      final phone = TextEditingController();
      final formKey = GlobalKey<FormState>();
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Register as a guest'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Full name'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter your name'
                      : null,
                ),
                TextFormField(
                  controller: email,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) =>
                      value == null ||
                          !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                              .hasMatch(value.trim())
                      ? 'Enter a valid email'
                      : null,
                ),
                TextFormField(
                  controller: phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone (optional)',
                  ),
                  keyboardType: TextInputType.phone,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(dialogContext, true);
                }
              },
              child: const Text('Register'),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        guestDetails = {
          'guestName': name.text.trim(),
          'guestEmail': email.text.trim(),
          if (phone.text.trim().isNotEmpty) 'guestPhone': phone.text.trim(),
        };
      }
      name.dispose();
      email.dispose();
      phone.dispose();
      if (confirmed != true || !mounted) return;
    }
    try {
      await ref
          .read(apiClientProvider)
          .post('/events/$id/register', body: guestDetails ?? {});
      if (!mounted) return;
      setState(() => _events = _load());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You are registered for this programme.')),
      );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: const AppBackButton(),
      title: Text(_past ? 'Past Programmes' : 'Upcoming Programmes'),
      actions: [
        TextButton(
          onPressed: () => setState(() {
            _past = !_past;
            _events = _load();
          }),
          child: Text(_past ? 'Upcoming' : 'Past'),
        ),
      ],
    ),
    body: FutureBuilder<List<dynamic>>(
      future: _events,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('Could not load programmes. ${snapshot.error}'),
          );
        }
        final events = snapshot.data ?? const [];
        if (events.isEmpty) {
          return Center(
            child: Text(
              _past
                  ? 'No past programmes yet.'
                  : 'No upcoming programmes have been published yet.',
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => setState(() => _events = _load()),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: events.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final event = events[index] as Map<String, dynamic>;
              final date = DateTime.tryParse('${event['startDate'] ?? ''}')
                  ?.toLocal();
              final banner = event['bannerFile'] as Map<String, dynamic>?;
              return Card(
                child: ListTile(
                  leading: banner?['id'] is String
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            AppConfig.resolveUrl(
                              '/api/v1/live-services/media/${banner!['id']}',
                            ),
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                const Icon(Icons.event_available_outlined),
                          ),
                        )
                      : const Icon(Icons.event_available_outlined),
                  title: Text('${event['title'] ?? 'Programme'}'),
                  trailing: !_past && event['registrationRequired'] == true
                      ? event['isRegistered'] == true
                            ? const Icon(
                                Icons.check_circle_outline,
                                semanticLabel: 'Registered',
                              )
                            : TextButton(
                                onPressed: () => _register('${event['id']}'),
                                child: const Text('Register'),
                              )
                      : null,
                  subtitle: Text(
                    [
                      if (date != null)
                        MaterialLocalizations.of(context).formatFullDate(date),
                      if ((event['venue'] as String?)?.isNotEmpty == true)
                        '${event['venue']}',
                      if ((event['meetingLink'] as String?)?.isNotEmpty == true)
                        '${event['meetingLink']}',
                      if ((event['description'] as String?)?.isNotEmpty == true)
                        '${event['description']}',
                    ].join(' · '),
                  ),
                ),
              );
            },
          ),
        );
      },
    ),
  );
}

class LiveServiceScreen extends ConsumerStatefulWidget {
  const LiveServiceScreen({super.key});

  @override
  ConsumerState<LiveServiceScreen> createState() => _LiveServiceScreenState();
}

class _LiveServiceScreenState extends ConsumerState<LiveServiceScreen> {
  late Future<Map<String, dynamic>> _service;
  YoutubePlayerController? _player;
  String? _videoId;

  @override
  void initState() {
    super.initState();
    _service = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final result =
        await ref.read(apiClientProvider).get('/live-services/current')
            as Map<String, dynamic>;
    final live = result['live'] as Map<String, dynamic>?;
    final videoId = _youtubeVideoId(live?['streamUrl'] as String?);
    if (videoId != _videoId) {
      _player?.close();
      _videoId = videoId;
      _player = videoId == null
          ? null
          : YoutubePlayerController.fromVideoId(
              videoId: videoId,
              autoPlay: false,
              params: const YoutubePlayerParams(showFullscreenButton: true),
            );
    }
    return result;
  }

  String? _youtubeVideoId(String? raw) {
    if (raw == null) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null) return null;
    String? id;
    if (uri.host == 'youtu.be' || uri.host.endsWith('.youtu.be')) {
      id = uri.pathSegments.isEmpty ? null : uri.pathSegments.last;
    } else if (uri.host.contains('youtube.com')) {
      id = uri.queryParameters['v'];
      if (id == null &&
          uri.pathSegments.length >= 2 &&
          const {'embed', 'live', 'shorts'}.contains(uri.pathSegments.first)) {
        id = uri.pathSegments[1];
      }
    }
    return id != null && RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(id)
        ? id
        : null;
  }

  @override
  void dispose() {
    _player?.close();
    super.dispose();
  }

  Future<void> _sendPrayerRequest(String? serviceId) async {
    final name = TextEditingController();
    final email = TextEditingController();
    final request = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final submit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Send a prayer request'),
        content: Form(
          key: formKey,
          child: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Your name'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter your name'
                      : null,
                ),
                TextFormField(
                  controller: email,
                  decoration: const InputDecoration(
                    labelText: 'Email (optional)',
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                TextFormField(
                  controller: request,
                  decoration: const InputDecoration(
                    labelText: 'Prayer request',
                  ),
                  maxLines: 4,
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter your request'
                      : null,
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
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (submit != true || !mounted) {
      name.dispose();
      email.dispose();
      request.dispose();
      return;
    }
    try {
      await ref
          .read(apiClientProvider)
          .post(
            '/live-services/prayer-requests',
            body: {
              'name': name.text.trim(),
              if (email.text.trim().isNotEmpty) 'email': email.text.trim(),
              'request': request.text.trim(),
              if (serviceId != null) 'liveServiceId': serviceId,
            },
          );
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Your prayer request has been sent.')),
        );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      name.dispose();
      email.dispose();
      request.dispose();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: const AppBackButton(),
      title: const Text('Live Service'),
    ),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _service,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('Could not load live service. ${snapshot.error}'),
          );
        }
        final live = snapshot.data?['live'] as Map<String, dynamic>?;
        final next = snapshot.data?['next'] as Map<String, dynamic>?;
        return RefreshIndicator(
          onRefresh: () async => setState(() => _service = _load()),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            children: [
              Icon(
                live == null ? Icons.live_tv_outlined : Icons.sensors_rounded,
                size: 56,
                color: live == null ? null : Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                live == null ? 'NO LIVE SERVICE CURRENTLY' : 'LIVE NOW',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              if (live != null) ...[
                const SizedBox(height: 12),
                if ((live['thumbnailFile'] as Map<String, dynamic>?)?['id']
                    is String)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(
                      AppConfig.resolveUrl(
                        '/api/v1/live-services/media/${(live['thumbnailFile'] as Map<String, dynamic>)['id']}',
                      ),
                      height: 210,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                Text(
                  '${live['title'] ?? 'Live Service'}',
                  textAlign: TextAlign.center,
                ),
                if ((live['minister'] as String?)?.isNotEmpty == true)
                  Text(
                    'Minister: ${live['minister']}',
                    textAlign: TextAlign.center,
                  ),
                if ((live['description'] as String?)?.isNotEmpty == true)
                  Text('${live['description']}', textAlign: TextAlign.center),
                Text(
                  _dateLabel(context, live['startedAt'] ?? live['scheduledAt']),
                  textAlign: TextAlign.center,
                ),
                if (_player != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: YoutubePlayer(
                        controller: _player!,
                        aspectRatio: 16 / 9,
                      ),
                    ),
                  )
                else if ((live['streamUrl'] as String?)?.isNotEmpty == true)
                  TextButton.icon(
                    onPressed: () => launchUrl(
                      Uri.parse('${live['streamUrl']}'),
                      mode: LaunchMode.externalApplication,
                    ),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Open live stream'),
                  ),
              ],
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _sendPrayerRequest(live?['id'] as String?),
                icon: const Icon(Icons.volunteer_activism_outlined),
                label: const Text('Send a prayer request'),
              ),
              if (live != null || next != null)
                TextButton.icon(
                  onPressed: () {
                    final service = live ?? next!;
                    final url = '${service['streamUrl'] ?? ''}';
                    final message =
                        '${service['title'] ?? 'Ministry service'}'
                        '${url.isEmpty ? '' : ' — $url'}';
                    launchUrl(
                      Uri.https('wa.me', '/', {'text': message}),
                      mode: LaunchMode.externalApplication,
                    );
                  },
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('Share service on WhatsApp'),
                ),
              const SizedBox(height: 24),
              if (live == null && next != null) ...[
                const Text(
                  'NEXT SCHEDULED SERVICE',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                if ((next['thumbnailFile'] as Map<String, dynamic>?)?['id']
                    is String)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(
                      AppConfig.resolveUrl(
                        '/api/v1/live-services/media/${(next['thumbnailFile'] as Map<String, dynamic>)['id']}',
                      ),
                      height: 210,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  '${next['title'] ?? 'Service'}',
                  textAlign: TextAlign.center,
                ),
                Text(
                  _dateLabel(context, next['scheduledAt']),
                  textAlign: TextAlign.center,
                ),
              ] else if (live == null)
                const Text(
                  'Check back when the next service is scheduled.',
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        );
      },
    ),
  );

  String _dateLabel(BuildContext context, dynamic value) {
    final date = DateTime.tryParse('$value')?.toLocal();
    if (date == null) return '';
    return '${MaterialLocalizations.of(context).formatFullDate(date)} · '
        '${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(date))}';
  }
}
