import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/models/journal_models.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_badge.dart';
import '../../core/widgets/app_buttons.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/feedback_states.dart';
import '../../core/widgets/toast.dart';
import 'reflections_providers.dart';

/// Reflections (private journal), testimonies (consent-gated sharing) and
/// the private annual letter.
class ReflectionsScreen extends ConsumerWidget {
  const ReflectionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Reflections & Testimonies'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Reflections'),
              Tab(text: 'Testimonies'),
              Tab(text: 'Annual Letter'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _ReflectionsTab(),
            _TestimoniesTab(),
            _AnnualLetterTab(),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------- reflections

class _ReflectionsTab extends ConsumerWidget {
  const _ReflectionsTab();

  Future<void> _openSheet(BuildContext context, WidgetRef ref,
      {ReflectionEntry? entry}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: _ReflectionSheet(entry: entry),
      ),
    );
    if (saved == true) ref.invalidate(reflectionsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(reflectionsProvider);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(reflectionsProvider);
        await Future<void>.delayed(const Duration(milliseconds: 200));
      },
      child: async.when(
        loading: () => const Padding(
          padding: AppSpacing.pagePaddingMobile,
          child: CardListSkeleton(count: 4),
        ),
        error: (e, _) => ListView(
          padding: AppSpacing.pagePaddingMobile,
          children: [
            ErrorState(
              error: e,
              onRetry: () => ref.invalidate(reflectionsProvider),
            ),
          ],
        ),
        data: (entries) {
          return ListView(
            padding: Breakpoints.isCompact(context)
                ? AppSpacing.pagePaddingMobile
                : const EdgeInsets.all(AppSpacing.xl),
            children: [
              const _PrivacyBanner(
                icon: Icons.lock_outline_rounded,
                title: 'Private to you',
                message:
                    'Your journal is just that — yours. Admins cannot see '
                    'your reflections; they are never included in reports or '
                    'shared with anyone.',
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${entries.length} entr${entries.length == 1 ? 'y' : 'ies'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  AppButton(
                    label: 'New entry',
                    icon: Icons.edit_outlined,
                    onPressed: () => _openSheet(context, ref),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              if (entries.isEmpty)
                const AppCard(
                  child: EmptyState(
                    icon: Icons.menu_book_outlined,
                    title: 'No reflections yet',
                    message:
                        'A short note after Bible reading or prayer can '
                        'capture what God is doing. Start whenever you’re '
                        'ready — it stays private.',
                  ),
                )
              else
                for (final group in _groupEntries(entries).entries) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.xs),
                    child: Text(
                      DateFormat('EEEE, d MMMM yyyy').format(group.key),
                      style: Theme.of(context)
                          .textTheme
                          .labelLarge
                          ?.copyWith(
                            color: AppColors.navy700,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  for (final entry in group.value) ...[
                    _ReflectionCard(
                      entry: entry,
                      onEdit: () => _openSheet(context, ref, entry: entry),
                      onDelete: () => _delete(context, ref, entry),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                  ],
                ],
              const SizedBox(height: AppSpacing.xl),
            ],
          );
        },
      ),
    );
  }

  Future<void> _delete(
      BuildContext context, WidgetRef ref, ReflectionEntry entry) async {
    final ok = await confirmDialog(
      context,
      title: 'Delete reflection?',
      message:
          '“${entry.title}” will be permanently deleted. This cannot be '
          'undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    final client = ref.read(apiClientProvider);
    try {
      await client.delete('/me/reflections/${entry.id}');
      ref.invalidate(reflectionsProvider);
      if (context.mounted) Toast.success(context, 'Reflection deleted.');
    } on ApiException catch (e) {
      if (context.mounted) Toast.error(context, e.fieldError ?? e.message);
    } catch (_) {
      if (context.mounted) {
        Toast.error(context, 'Unable to delete just now.');
      }
    }
  }
}

Map<DateTime, List<ReflectionEntry>> _groupEntries(
    List<ReflectionEntry> entries) {
  final map = <DateTime, List<ReflectionEntry>>{};
  for (final e in entries) {
    final d = e.entryDate ?? e.createdAt ?? DateTime.now();
    final key = DateTime(d.year, d.month, d.day);
    map.putIfAbsent(key, () => []).add(e);
  }
  final keys = map.keys.toList()..sort((a, b) => b.compareTo(a));
  return {for (final k in keys) k: map[k]!};
}

class _ReflectionCard extends StatelessWidget {
  const _ReflectionCard({
    required this.entry,
    required this.onEdit,
    required this.onDelete,
  });

  final ReflectionEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onEdit,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.edit_note_outlined,
              size: 20, color: AppColors.gold600),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  entry.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Entry options',
            onSelected: (v) {
              if (v == 'edit') {
                onEdit();
              } else {
                onDelete();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReflectionSheet extends ConsumerStatefulWidget {
  const _ReflectionSheet({this.entry});

  final ReflectionEntry? entry;

  @override
  ConsumerState<_ReflectionSheet> createState() => _ReflectionSheetState();
}

class _ReflectionSheetState extends ConsumerState<_ReflectionSheet> {
  late final TextEditingController _title;
  late final TextEditingController _body;
  DateTime? _date;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.entry?.title ?? '');
    _body = TextEditingController(text: widget.entry?.body ?? '');
    _date = widget.entry?.entryDate;
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty || _body.text.trim().isEmpty) {
      Toast.error(context, 'Add a title and a few words before saving.');
      return;
    }
    setState(() => _busy = true);
    final client = ref.read(apiClientProvider);
    final body = {
      'title': _title.text.trim(),
      'body': _body.text.trim(),
      if (_date != null)
        'entryDate': DateFormat('yyyy-MM-dd').format(_date!),
    };
    try {
      if (widget.entry == null) {
        await client.post('/me/reflections', body: body);
      } else {
        await client.patch('/me/reflections/${widget.entry!.id}', body: body);
      }
      if (!mounted) return;
      Toast.success(
        context,
        widget.entry == null
            ? 'Reflection saved. Your journey matters.'
            : 'Reflection updated.',
      );
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) Toast.error(context, e.fieldError ?? e.message);
    } catch (_) {
      if (mounted) Toast.error(context, 'Unable to save just now.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.entry == null ? 'New reflection' : 'Edit reflection',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              AppIconButton(
                icon: Icons.close_rounded,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          AppTextField(
            label: 'Title',
            required: true,
            controller: _title,
            hint: 'What is this about?',
          ),
          const SizedBox(height: fieldGap),
          AppDateField(
            label: 'Date',
            value: _date,
            onChanged: (d) => setState(() => _date = d),
          ),
          const SizedBox(height: fieldGap),
          AppTextField(
            label: 'Entry',
            required: true,
            controller: _body,
            maxLines: 6,
            hint: 'Pour out your heart — this stays between you and God.',
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Save reflection',
            busy: _busy,
            expand: true,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------ testimonies

const _visibilityOptions = <(String, String)>[
  ('PRIVATE', 'Private — only me'),
  ('MINISTRY_ADMINS', 'Ministry admins (after consent)'),
  ('COMMUNITY', 'Church community (after consent)'),
];

class _TestimoniesTab extends ConsumerWidget {
  const _TestimoniesTab();

  Future<void> _openSheet(BuildContext context, WidgetRef ref,
      {Testimony? testimony}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: _TestimonySheet(testimony: testimony),
      ),
    );
    if (saved == true) ref.invalidate(testimoniesProvider);
  }

  Future<void> _delete(
      BuildContext context, WidgetRef ref, Testimony testimony) async {
    final ok = await confirmDialog(
      context,
      title: 'Delete testimony?',
      message:
          '“${testimony.title}” will be permanently deleted. This cannot be '
          'undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    final client = ref.read(apiClientProvider);
    try {
      await client.delete('/me/testimonies/${testimony.id}');
      ref.invalidate(testimoniesProvider);
      if (context.mounted) Toast.success(context, 'Testimony deleted.');
    } on ApiException catch (e) {
      if (context.mounted) Toast.error(context, e.fieldError ?? e.message);
    } catch (_) {
      if (context.mounted) {
        Toast.error(context, 'Unable to delete just now.');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(testimoniesProvider);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(testimoniesProvider);
        await Future<void>.delayed(const Duration(milliseconds: 200));
      },
      child: async.when(
        loading: () => const Padding(
          padding: AppSpacing.pagePaddingMobile,
          child: CardListSkeleton(count: 4),
        ),
        error: (e, _) => ListView(
          padding: AppSpacing.pagePaddingMobile,
          children: [
            ErrorState(
              error: e,
              onRetry: () => ref.invalidate(testimoniesProvider),
            ),
          ],
        ),
        data: (testimonies) {
          return ListView(
            padding: Breakpoints.isCompact(context)
                ? AppSpacing.pagePaddingMobile
                : const EdgeInsets.all(AppSpacing.xl),
            children: [
              const _PrivacyBanner(
                icon: Icons.verified_user_outlined,
                title: 'Nothing is shared without your consent',
                message:
                    'A testimony stays private until you choose otherwise. '
                    'Anything shared beyond your private space is reviewed '
                    'by ministry admins before it appears to others.',
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${testimonies.length} testimon'
                      '${testimonies.length == 1 ? 'y' : 'ies'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  AppButton(
                    label: 'New testimony',
                    icon: Icons.celebration_outlined,
                    onPressed: () => _openSheet(context, ref),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              if (testimonies.isEmpty)
                const AppCard(
                  child: EmptyState(
                    icon: Icons.celebration_outlined,
                    title: 'No testimonies yet',
                    message:
                        'God is at work — and recording it strengthens your '
                        'faith and encourages others when you choose to share.',
                  ),
                )
              else
                for (final testimony in sortedTestimonies(testimonies)) ...[
                  _TestimonyCard(
                    testimony: testimony,
                    onEdit: () => _openSheet(context, ref, testimony: testimony),
                    onDelete: () => _delete(context, ref, testimony),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                ],
              const SizedBox(height: AppSpacing.xl),
            ],
          );
        },
      ),
    );
  }
}

/// Newest first, for stable display ordering.
List<Testimony> sortedTestimonies(List<Testimony> items) {
  final sorted = [...items];
  sorted.sort((a, b) {
    final aDate = a.entryDate ?? a.createdAt;
    final bDate = b.entryDate ?? b.createdAt;
    if (aDate == null || bDate == null) return 0;
    return bDate.compareTo(aDate);
  });
  return sorted;
}

class _TestimonyCard extends StatelessWidget {
  const _TestimonyCard({
    required this.testimony,
    required this.onEdit,
    required this.onDelete,
  });

  final Testimony testimony;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final date = testimony.entryDate ?? testimony.createdAt;
    return AppCard(
      onTap: onEdit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  testimony.title,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Testimony options',
                onSelected: (v) {
                  if (v == 'edit') {
                    onEdit();
                  } else {
                    onDelete();
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
          if (date != null)
            Text(
              DateFormat('d MMM yyyy').format(date.toLocal()),
              style: Theme.of(context).textTheme.labelSmall,
            ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            testimony.body,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (testimony.tags.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xxs,
              runSpacing: AppSpacing.xxs,
              children: [
                for (final tag in testimony.tags)
                  StatusBadge(label: '#$tag', tone: AppBadgeTone.neutral, small: true),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              StatusBadge(
                label: _visibilityOptions
                    .firstWhere(
                      (o) => o.$1 == testimony.visibility,
                      orElse: () => (testimony.visibility, testimony.visibility),
                    )
                    .$2,
                tone: testimony.visibility == 'PRIVATE'
                    ? AppBadgeTone.neutral
                    : AppBadgeTone.info,
                small: true,
              ),
              if (testimony.approvalStatus != null)
                StatusBadge(
                  label: 'Approval: ${humanizeStatus(testimony.approvalStatus!)}',
                  tone: badgeToneFor(testimony.approvalStatus!),
                  small: true,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TestimonySheet extends ConsumerStatefulWidget {
  const _TestimonySheet({this.testimony});

  final Testimony? testimony;

  @override
  ConsumerState<_TestimonySheet> createState() => _TestimonySheetState();
}

class _TestimonySheetState extends ConsumerState<_TestimonySheet> {
  late final TextEditingController _title;
  late final TextEditingController _body;
  late final TextEditingController _tag;
  late final List<String> _tags;
  DateTime? _date;
  late String _visibility;
  late bool _consent;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.testimony?.title ?? '');
    _body = TextEditingController(text: widget.testimony?.body ?? '');
    _tag = TextEditingController();
    _tags = [...widget.testimony?.tags ?? const []];
    _date = widget.testimony?.entryDate;
    final visibility = widget.testimony?.visibility;
    _visibility =
        _visibilityOptions.any((o) => o.$1 == visibility) && visibility != null
            ? visibility
            : 'PRIVATE';
    _consent = widget.testimony?.consentToShare ?? false;
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _tag.dispose();
    super.dispose();
  }

  void _addTag() {
    final tag = _tag.text.trim();
    if (tag.isEmpty) return;
    setState(() {
      if (!_tags.contains(tag)) _tags.add(tag);
      _tag.clear();
    });
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty || _body.text.trim().isEmpty) {
      Toast.error(context, 'Add a title and the testimony before saving.');
      return;
    }
    if (_visibility != 'PRIVATE' && !_consent) {
      Toast.error(
        context,
        'Please tick the consent box to share this testimony, or switch it '
        'back to private.',
      );
      return;
    }
    setState(() => _busy = true);
    final client = ref.read(apiClientProvider);
    final body = {
      'title': _title.text.trim(),
      'body': _body.text.trim(),
      if (_date != null)
        'entryDate': DateFormat('yyyy-MM-dd').format(_date!),
      'tags': _tags,
      'visibility': _visibility,
      'consentToShare': _consent,
    };
    try {
      if (widget.testimony == null) {
        await client.post('/me/testimonies', body: body);
      } else {
        await client.patch('/me/testimonies/${widget.testimony!.id}',
            body: body);
      }
      if (!mounted) return;
      Toast.success(
        context,
        _visibility == 'PRIVATE'
            ? 'Testimony saved — private to you.'
            : 'Testimony saved. It will be reviewed before it’s shared.',
      );
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) Toast.error(context, e.fieldError ?? e.message);
    } catch (_) {
      if (mounted) Toast.error(context, 'Unable to save just now.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sharing = _visibility != 'PRIVATE';
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.testimony == null
                        ? 'New testimony'
                        : 'Edit testimony',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                AppIconButton(
                  icon: Icons.close_rounded,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              label: 'Title',
              required: true,
              controller: _title,
              hint: 'A short summary of what God did',
            ),
            const SizedBox(height: fieldGap),
            AppDateField(
              label: 'Date',
              value: _date,
              onChanged: (d) => setState(() => _date = d),
            ),
            const SizedBox(height: fieldGap),
            AppTextField(
              label: 'Testimony',
              required: true,
              controller: _body,
              maxLines: 6,
              hint: 'Share what happened…',
            ),
            const SizedBox(height: fieldGap),
            AppTextField(
              label: 'Tags',
              controller: _tag,
              hint: 'e.g. healing — press Enter or Add',
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _addTag(),
              suffix: TextButton(
                onPressed: _addTag,
                child: const Text('Add'),
              ),
            ),
            if (_tags.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xxs,
                children: [
                  for (final tag in _tags)
                    InputChip(
                      label: Text('#$tag'),
                      onDeleted: () => setState(() => _tags.remove(tag)),
                    ),
                ],
              ),
            ],
            const SizedBox(height: fieldGap),
            AppDropdown<String>(
              label: 'Visibility',
              value: _visibility,
              items: [
                for (final option in _visibilityOptions)
                  DropdownMenuItem(value: option.$1, child: Text(option.$2)),
              ],
              onChanged: (v) =>
                  setState(() => _visibility = v ?? 'PRIVATE'),
            ),
            if (sharing) ...[
              const SizedBox(height: AppSpacing.xs),
              CheckboxListTile(
                value: _consent,
                onChanged: (v) => setState(() => _consent = v ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text(
                  'I consent to share this testimony with the audience '
                  'selected above.',
                  style: TextStyle(fontSize: 13),
                ),
                subtitle: sharing
                    ? const Text(
                        'Required for sharing. You can switch back to private '
                        'anytime.',
                        style: TextStyle(fontSize: 12),
                      )
                    : null,
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'Save testimony',
              busy: _busy,
              expand: true,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------- annual letter

class _AnnualLetterTab extends ConsumerStatefulWidget {
  const _AnnualLetterTab();

  @override
  ConsumerState<_AnnualLetterTab> createState() => _AnnualLetterTabState();
}

class _AnnualLetterTabState extends ConsumerState<_AnnualLetterTab> {
  final _controller = TextEditingController();
  bool _initialized = false;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _saveDraft() async {
    setState(() => _busy = true);
    final client = ref.read(apiClientProvider);
    try {
      await client.put(
        '/me/annual-letter',
        body: {'content': _controller.text},
      );
      ref.invalidate(annualLetterProvider);
      if (mounted) {
        Toast.success(
          context,
          'Annual letter saved. It stays private — for your eyes only.',
        );
      }
    } on ApiException catch (e) {
      if (e.statusCode == 404 || e.statusCode == 501) {
        if (mounted) {
          Toast.show(
            context,
            message: 'Annual letters aren’t configured on the server yet — '
                'your draft is kept on this screen only for now.',
            tone: ToastTone.info,
            duration: const Duration(seconds: 5),
          );
        }
      } else if (mounted) {
        Toast.error(context, e.fieldError ?? e.message);
      }
    } catch (_) {
      if (mounted) {
        Toast.error(context, 'Unable to save the letter just now.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(annualLetterProvider);
    return async.when(
      loading: () => const Padding(
        padding: AppSpacing.pagePaddingMobile,
        child: SkeletonBox(height: 320, radius: 14),
      ),
      error: (e, _) => ErrorState(
        error: e,
        onRetry: () => ref.invalidate(annualLetterProvider),
      ),
      data: (letter) {
        if (!_initialized) {
          _controller.text = letter.content;
          _initialized = true;
        }
        return ListView(
          padding: Breakpoints.isCompact(context)
              ? AppSpacing.pagePaddingMobile
              : const EdgeInsets.all(AppSpacing.xl),
          children: [
            const _PrivacyBanner(
              icon: Icons.lock_outline_rounded,
              title: 'Private by default',
              message:
                  'This letter is for your eyes only. Write to the you of '
                  'next year — what God has done, what you’re believing for.',
            ),
            if (!letter.available) ...[
              const SizedBox(height: AppSpacing.md),
              AppCard(
                color: AppColors.warningSurface,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 20, color: AppColors.warning),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Annual letters aren’t configured on the server yet. '
                        'You can write here, and saving will be enabled once '
                        'it’s set up.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Letter to myself',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: _controller,
                    maxLines: 14,
                    minLines: 8,
                    decoration: const InputDecoration(
                      hintText:
                          'Dear future me,\n\nThis year, God…\n\nNext year, I '
                          'want to…',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: 'Save draft',
                    icon: Icons.save_outlined,
                    busy: _busy,
                    onPressed: _saveDraft,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------- shared

class _PrivacyBanner extends StatelessWidget {
  const _PrivacyBanner({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.navy50,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.navy700),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
