import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/models/material_models.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_badge.dart';
import '../../core/widgets/app_buttons.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/feedback_states.dart';
import '../../core/widgets/pagination.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/toast.dart';
import 'admin_file_reader.dart';
import 'admin_providers.dart';
import 'admin_shared.dart';

/// Materials Library: searchable, filterable study materials with an
/// upload-or-link editor. Uploads read a local path on native builds; the
/// browser has no filesystem, so it explains the limitation honestly.
class AdminMaterialsScreen extends ConsumerWidget {
  const AdminMaterialsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const _MaterialsBody();
  }
}

const _materialCategories = <(String, String)>[
  ('PDF_DOCUMENT', 'PDF document'),
  ('AUDIO_MESSAGE', 'Audio message'),
  ('VIDEO', 'Video'),
  ('BIBLE_STUDY_NOTES', 'Bible study notes'),
  ('LITERATURE_REFERENCE', 'Literature reference'),
  ('PRAYER_GUIDE', 'Prayer guide'),
  ('SCRIPTURE_READING_LINK', 'Scripture reading link'),
  ('CONFESSION_DECLARATION', 'Confession & declaration'),
  ('ANNOUNCEMENT', 'Announcement'),
  ('OTHER', 'Other'),
];

String _categoryLabel(String key) {
  for (final c in _materialCategories) {
    if (c.$1 == key) return c.$2;
  }
  return humanizeStatus(key);
}

class _MaterialsBody extends ConsumerStatefulWidget {
  const _MaterialsBody();

  @override
  ConsumerState<_MaterialsBody> createState() => _MaterialsBodyState();
}

class _MaterialsBodyState extends ConsumerState<_MaterialsBody> {
  int _page = 1;
  String _search = '';
  String _status = '';
  String _category = '';

  void _setFilter(void Function() apply) {
    setState(() {
      apply();
      _page = 1;
    });
  }

  DropdownMenuItem<String> _item(String value, String label) =>
      DropdownMenuItem<String>(value: value, child: Text(label));

  Future<void> _openEditor(MaterialItem? material) async {
    await showAdminSheet(
      context: context,
      builder: (_) => _MaterialSheet(material: material),
    );
    if (mounted) ref.invalidate(adminMaterialsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final query = (
      page: _page,
      search: _search,
      status: _status,
      category: _category,
    );
    final result = ref.watch(adminMaterialsProvider(query));
    final compact = Breakpoints.isCompact(context);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(adminMaterialsProvider);
        await Future<void>.delayed(const Duration(milliseconds: 300));
      },
      child: ListView(
        padding: adminPadding(context),
        children: [
          SectionHeader(
            title: 'Materials Library',
            subtitle: 'Upload files or link external resources for members',
            icon: Icons.library_books_outlined,
            actionLabel: 'Add material',
            onAction: () => _openEditor(null),
          ),

          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AdminSearchField(
                  hint: 'Title, description or author…',
                  onChanged: (value) => _setFilter(() => _search = value),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    SizedBox(
                      width: compact ? double.infinity : 200,
                      child: AppDropdown<String>(
                        label: 'Status',
                        value: _status,
                        items: [
                          _item('', 'All statuses'),
                          _item('DRAFT', 'Draft'),
                          _item('PUBLISHED', 'Published'),
                          _item('ARCHIVED', 'Archived'),
                        ],
                        onChanged: (value) =>
                            _setFilter(() => _status = value ?? ''),
                      ),
                    ),
                    SizedBox(
                      width: compact ? double.infinity : 220,
                      child: AppDropdown<String>(
                        label: 'Category',
                        value: _category,
                        items: [
                          _item('', 'All categories'),
                          for (final c in _materialCategories)
                            _item(c.$1, c.$2),
                        ],
                        onChanged: (value) =>
                            _setFilter(() => _category = value ?? ''),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          result.when(
            loading: () => const CardListSkeleton(count: 5),
            error: (error, _) => ErrorState(
              error: error,
              onRetry: () => ref.invalidate(adminMaterialsProvider(query)),
            ),
            data: (page) {
              if (page.items.isEmpty) {
                return AppCard(
                  child: EmptyState(
                    icon: Icons.library_books_outlined,
                    title: 'No materials here yet',
                    message:
                        'Add study materials, prayers and audio messages for '
                        'members. Anything you add stays a draft until you '
                        'publish it.',
                    actionLabel: 'Add material',
                    onAction: () => _openEditor(null),
                  ),
                );
              }
              return Column(
                children: [
                  for (final material in page.items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _MaterialCard(
                        material: material,
                        onEdit: () => _openEditor(material),
                        onChanged: () => ref.invalidate(adminMaterialsProvider),
                      ),
                    ),
                  PaginationFooter(
                    page: page.page,
                    totalPages: page.totalPages,
                    totalItems: page.total,
                    onPrevious: () => setState(() => _page -= 1),
                    onNext: () => setState(() => _page += 1),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

class _MaterialCard extends ConsumerStatefulWidget {
  const _MaterialCard({
    required this.material,
    required this.onEdit,
    required this.onChanged,
  });

  final MaterialItem material;
  final VoidCallback onEdit;
  final VoidCallback onChanged;

  @override
  ConsumerState<_MaterialCard> createState() => _MaterialCardState();
}

class _MaterialCardState extends ConsumerState<_MaterialCard> {
  bool _busy = false;

  IconData get _icon {
    if (widget.material.isAudio) return Icons.headphones_outlined;
    if (widget.material.isVideo) return Icons.videocam_outlined;
    if (widget.material.isLink) return Icons.link_rounded;
    return Icons.description_outlined;
  }

  Future<void> _run(String label, Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      widget.onChanged();
      Toast.success(context, label);
    } on ApiException catch (e) {
      if (!mounted) return;
      Toast.error(context, e.fieldError ?? e.message);
    } catch (_) {
      if (!mounted) return;
      Toast.error(context, 'Couldn’t complete that just now.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _publish() async {
    final confirmed = await confirmDialog(
      context,
      title: 'Publish “${widget.material.title}”?',
      message: 'Members with access will see this material immediately.',
      confirmLabel: 'Publish',
    );
    if (!confirmed || !mounted) return;
    await _run('Material published.', () async {
      await ref
          .read(apiClientProvider)
          .post('/admin/materials/${widget.material.id}/publish');
    });
  }

  Future<void> _archive() async {
    final confirmed = await confirmDialog(
      context,
      title: 'Archive this material?',
      message:
          'It stays on record but is hidden from members until re-published.',
      confirmLabel: 'Archive',
    );
    if (!confirmed || !mounted) return;
    await _run('Material archived.', () async {
      await ref
          .read(apiClientProvider)
          .post('/admin/materials/${widget.material.id}/archive');
    });
  }

  Future<void> _delete() async {
    final confirmed = await confirmDialog(
      context,
      title: 'Delete this material?',
      message:
          'This permanently removes the material. Members who completed it '
          'keep their own activity records.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await _run('Material deleted.', () async {
      await ref
          .read(apiClientProvider)
          .delete('/admin/materials/${widget.material.id}');
    });
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.material;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.navy50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_icon, size: 21, color: AppColors.navy700),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            m.title.isEmpty ? 'Untitled material' : m.title,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        StatusBadge(
                          label: humanizeStatus(m.status),
                          tone: badgeToneFor(m.status),
                          small: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xxs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        StatusBadge(
                          label: _categoryLabel(m.category),
                          tone: AppBadgeTone.navy,
                          small: true,
                        ),
                        if (m.year != null)
                          Text('${m.year}',
                              style:
                                  Theme.of(context).textTheme.labelSmall),
                        if (m.month != null)
                          Text('· ${monthNameOf(m.month!)}',
                              style:
                                  Theme.of(context).textTheme.labelSmall),
                        Text(
                          m.isFile
                              ? '· File attached'
                              : m.isLink
                                  ? '· External link'
                                  : '· No file or link yet',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                    if (m.description != null && m.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        m.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    if (m.author != null && m.author!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        m.author!,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              AppButton(
                label: 'Edit',
                icon: Icons.edit_outlined,
                variant: AppButtonVariant.outlined,
                onPressed: widget.onEdit,
              ),
              if (m.status != 'PUBLISHED')
                AppButton(
                  label: 'Publish',
                  icon: Icons.publish_rounded,
                  variant: AppButtonVariant.outlined,
                  busy: _busy,
                  onPressed: _publish,
                ),
              if (m.status != 'ARCHIVED')
                AppButton(
                  label: 'Archive',
                  icon: Icons.archive_outlined,
                  variant: AppButtonVariant.text,
                  busy: _busy,
                  onPressed: _archive,
                ),
              AppButton(
                label: 'Delete',
                icon: Icons.delete_outline_rounded,
                variant: AppButtonVariant.text,
                busy: _busy,
                onPressed: _delete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MaterialSheet extends ConsumerStatefulWidget {
  const _MaterialSheet({this.material});

  final MaterialItem? material;

  @override
  ConsumerState<_MaterialSheet> createState() => _MaterialSheetState();
}

class _MaterialSheetState extends ConsumerState<_MaterialSheet> {
  late final TextEditingController _title =
      TextEditingController(text: widget.material?.title ?? '');
  late final TextEditingController _description =
      TextEditingController(text: widget.material?.description ?? '');
  late final TextEditingController _author =
      TextEditingController(text: widget.material?.author ?? '');
  late final TextEditingController _year = TextEditingController(
    text: widget.material?.year == null ? '' : '${widget.material!.year}',
  );
  late final TextEditingController _url =
      TextEditingController(text: widget.material?.externalUrl ?? '');
  final TextEditingController _path = TextEditingController();

  late String _category = widget.material?.category ?? 'PDF_DOCUMENT';
  late int? _month = widget.material?.month;
  late String _visibility = 'ALL_MEMBERS';
  late bool _trackCompletion = widget.material?.trackCompletion ?? false;
  late String? _fileId = widget.material?.fileId;
  String? _fileName;
  double _uploadProgress = 0;
  bool _uploading = false;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _author.dispose();
    _year.dispose();
    _url.dispose();
    _path.dispose();
    super.dispose();
  }

  Future<void> _upload() async {
    final path = _path.text.trim();
    if (path.isEmpty) {
      Toast.error(context, 'Type the full path of a file to upload.');
      return;
    }
    setState(() {
      _uploading = true;
      _uploadProgress = 0;
    });
    try {
      final payload = await readAdminFile(path);
      if (!mounted) return;
      if (payload == null) {
        Toast.error(context, 'No file found at that path.');
        return;
      }
      final result = await ref.read(apiClientProvider).upload(
            '/admin/files',
            bytes: payload.bytes,
            fieldName: 'file',
            filename: payload.filename,
            contentType: payload.contentType,
            onProgress: (value) {
              if (mounted) setState(() => _uploadProgress = value);
            },
          );
      if (!mounted) return;
      final map = asJsonMap(result);
      final file = asJsonMap(map['file'] ?? map);
      _fileId = strOf(file['id'], '');
      _fileName = strOf(file['originalName'] ?? payload.filename, '');
      Toast.success(context, 'File uploaded. Save to attach it.');
    } on UnsupportedError {
      if (!mounted) return;
      Toast.error(
        context,
        'Uploading a local file isn’t available in the browser yet. Paste an '
        'external link instead.',
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      Toast.error(context, e.fieldError ?? e.message);
    } catch (_) {
      if (!mounted) return;
      Toast.error(context, 'Couldn’t read or upload that file just now.');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_title.text.trim().isEmpty) {
      Toast.error(context, 'Give the material a title.');
      return;
    }
    final url = _nullIfEmpty(_url.text);
    if ((_fileId == null || _fileId!.isEmpty) && url == null) {
      Toast.error(context, 'Upload a file or add an external link.');
      return;
    }
    setState(() => _saving = true);
    final body = <String, dynamic>{
      'title': _title.text.trim(),
      'category': _category,
      'description': _nullIfEmpty(_description.text),
      'authorSpeaker': _nullIfEmpty(_author.text),
      if (int.tryParse(_year.text.trim()) != null)
        'programmeYear': int.parse(_year.text.trim()),
      if (_month != null) 'month': _month,
      if (_fileId != null && _fileId!.isNotEmpty) 'fileId': _fileId,
      'externalUrl': ?url,
      'visibility': _visibility,
      'trackCompletion': _trackCompletion,
    };
    try {
      final client = ref.read(apiClientProvider);
      final material = widget.material;
      if (material == null) {
        await client.post('/admin/materials', body: body);
      } else {
        await client.patch('/admin/materials/${material.id}', body: body);
      }
      if (!mounted) return;
      Toast.success(context, 'Material saved.');
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      Toast.error(context, e.fieldError ?? e.message);
    } catch (_) {
      if (!mounted) return;
      Toast.error(context, 'Couldn’t save this material just now.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.material != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          editing ? 'Edit material' : 'Add material',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Members see published materials in their library.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          label: 'Title',
          controller: _title,
          required: true,
          hint: 'e.g. Prayer guide for March',
        ),
        const SizedBox(height: fieldGap),
        AppDropdown<String>(
          label: 'Category',
          value: _category,
          items: [
            for (final c in _materialCategories)
              DropdownMenuItem(value: c.$1, child: Text(c.$2)),
          ],
          onChanged: (value) {
            if (value == null) return;
            setState(() => _category = value);
          },
        ),
        const SizedBox(height: fieldGap),
        AppTextField(
          label: 'Description',
          controller: _description,
          maxLines: 3,
        ),
        const SizedBox(height: fieldGap),
        Row(
          children: [
            Expanded(
              child: AppTextField(
                label: 'Author / speaker',
                controller: _author,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: AppTextField(
                label: 'Programme year',
                controller: _year,
                keyboardType: TextInputType.number,
                hint: 'e.g. 2026',
              ),
            ),
          ],
        ),
        const SizedBox(height: fieldGap),
        Row(
          children: [
            Expanded(
              child: AppDropdown<int?>(
                label: 'Month (optional)',
                value: _month,
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('Any month')),
                  for (var m = 1; m <= 12; m++)
                    DropdownMenuItem<int?>(
                      value: m,
                      child: Text(monthNameOf(m)),
                    ),
                ],
                onChanged: (value) => setState(() => _month = value),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: AppDropdown<String>(
                label: 'Visibility',
                value: _visibility,
                items: const [
                  DropdownMenuItem(
                      value: 'ALL_MEMBERS', child: Text('All members')),
                  DropdownMenuItem(
                      value: 'ADMINS_ONLY', child: Text('Admins only')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _visibility = value);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: fieldGap),
        AppTextField(
          label: 'External link (optional)',
          controller: _url,
          hint: 'https://…',
          helper: 'Use a link when the resource lives somewhere else.',
        ),
        const SizedBox(height: fieldGap),
        AdminBanner(
          tone: AdminBannerTone.info,
          icon: Icons.upload_file_outlined,
          text: _fileId == null
              ? 'Upload a file from this device, or paste an external link. '
                  'At least one is required before publishing.'
              : 'Attached file: ${_fileName ?? 'uploaded file'}.',
        ),
        const SizedBox(height: AppSpacing.sm),
        AppTextField(
          label: 'File path to upload',
          controller: _path,
          hint: '/Users/you/Documents/notes.pdf',
          helper:
              'Reads a file on this device. Not available in a web browser — '
              'use an external link there instead.',
        ),
        const SizedBox(height: AppSpacing.xs),
        if (_uploading)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: ProgressBar(value: _uploadProgress),
          ),
        AppButton(
          label: _fileId == null ? 'Upload file' : 'Replace file',
          icon: Icons.upload_rounded,
          variant: AppButtonVariant.outlined,
          expand: true,
          busy: _uploading,
          onPressed: _upload,
        ),
        const SizedBox(height: AppSpacing.md),
        AppSwitchRow(
          label: 'Track completion',
          subtitle: 'Let members mark this material as read/listened.',
          value: _trackCompletion,
          onChanged: (value) => setState(() => _trackCompletion = value),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: editing ? 'Save material' : 'Add material',
          icon: Icons.save_outlined,
          expand: true,
          busy: _saving,
          onPressed: _save,
        ),
        const SizedBox(height: AppSpacing.xs),
        AppButton(
          label: 'Cancel',
          variant: AppButtonVariant.text,
          expand: true,
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

String? _nullIfEmpty(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
