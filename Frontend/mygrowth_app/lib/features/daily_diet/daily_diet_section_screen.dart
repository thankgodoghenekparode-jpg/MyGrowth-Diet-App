import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/daily_diet_models.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_badge.dart';
import '../../core/widgets/app_buttons.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/feedback_states.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/toast.dart';
import 'daily_diet_providers.dart';
import 'daily_diet_shared.dart';
import 'prayer_stopwatch.dart';

/// One section of the Daily Diet for one day.
///
/// The screen dispatches on the section's behaviour so each kind of content
/// gets the interaction it deserves: a stopwatch for prayer, a tick for
/// fasting, a report form for the weekly and monthly report, a list of files
/// for the material sections and a link into the prayer room for the prayer
/// accountability partner.
class DailyDietSectionScreen extends ConsumerWidget {
  const DailyDietSectionScreen({
    super.key,
    required this.sectionId,
    required this.dateISO,
  });

  final String sectionId;
  final String dateISO;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bundleAsync = ref.watch(dailyDietProvider(dateISO));

    return Scaffold(
      appBar: AppBar(
        title: Text(_titleFor(bundleAsync.value)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/diet');
            }
          },
        ),
      ),
      body: bundleAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: CardListSkeleton(count: 3),
        ),
        error: (error, _) => ErrorState(
          error: error,
          onRetry: () => ref.invalidate(dailyDietProvider(dateISO)),
        ),
        data: (bundle) {
          DailyDietSection? section;
          for (final s in bundle.sections) {
            if (s.id == sectionId) section = s;
          }
          final found = section;
          if (found == null) {
            return const EmptyState(
              icon: Icons.help_outline_rounded,
              title: 'Section unavailable',
              message:
                  'This section is no longer part of the published Daily Diet '
                  'for the selected day.',
            );
          }
          return _SectionBody(
            section: found,
            bundle: bundle,
            dateISO: dateISO,
          );
        },
      ),
    );
  }

  String _titleFor(DailyDietBundle? bundle) {
    if (bundle == null) return 'Daily Diet';
    for (final s in bundle.sections) {
      if (s.id == sectionId) return s.label;
    }
    return 'Daily Diet';
  }
}

/// The body of one section, dispatched on its behaviour.
class _SectionBody extends ConsumerStatefulWidget {
  const _SectionBody({
    required this.section,
    required this.bundle,
    required this.dateISO,
  });

  final DailyDietSection section;
  final DailyDietBundle bundle;
  final String dateISO;

  @override
  ConsumerState<_SectionBody> createState() => _SectionBodyState();
}

class _SectionBodyState extends ConsumerState<_SectionBody> {
  bool _busy = false;

  DailyDietSection get section => widget.section;

  Future<void> _save({
    DailyDietStatus status = DailyDietStatus.completed,
    String? note,
    int? actualDurationMinutes,
    String? attachmentFileId,
    bool keepExistingNote = true,
  }) async {
    setState(() => _busy = true);
    final writer = ref.read(dailyDietCompletionWriterProvider);
    try {
      await writer.save(
        sectionId: section.id,
        date: widget.dateISO,
        status: status,
        note: note ?? (keepExistingNote ? section.completion?.note : null),
        actualDurationMinutes: actualDurationMinutes ??
            section.completion?.actualDurationMinutes,
        attachmentFileId:
            attachmentFileId ?? section.completion?.attachmentFileId,
      );
      if (mounted) {
        Toast.show(context, message: 'Saved', tone: ToastTone.success);
      }
    } catch (error) {
      if (mounted) {
        Toast.show(
          context,
          message: _messageFor(error),
          tone: ToastTone.error,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clear() async {
    final completion = section.completion;
    if (completion == null) return;
    setState(() => _busy = true);
    final writer = ref.read(dailyDietCompletionWriterProvider);
    try {
      await writer.clear(completionId: completion.id, date: widget.dateISO);
      if (mounted) {
        Toast.show(context, message: 'Marked as not done', tone: ToastTone.info);
      }
    } catch (error) {
      if (mounted) {
        Toast.show(
          context,
          message: _messageFor(error),
          tone: ToastTone.error,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _upload() async {
    PlatformFile? picked;
    try {
      picked = await FilePicker.pickFile();
    } catch (error) {
      if (mounted) {
        Toast.show(
          context,
          message: 'Could not open the file picker.',
          tone: ToastTone.error,
        );
      }
      return;
    }
    final file = picked;
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      if (mounted) {
        Toast.show(
          context,
          message: 'That file could not be read.',
          tone: ToastTone.error,
        );
      }
      return;
    }

    setState(() => _busy = true);
    final writer = ref.read(dailyDietCompletionWriterProvider);
    try {
      final fileId = await writer.uploadFile(
        bytes: bytes,
        filename: file.name,
        contentType: _contentTypeFor(file.name),
      );
      if (fileId == null) {
        throw ApiException(
          0,
          'upload_failed',
          'The file could not be uploaded. Please try again.',
        );
      }
      await writer.save(
        sectionId: section.id,
        date: widget.dateISO,
        status: DailyDietStatus.completed,
        attachmentFileId: fileId,
        note: file.name,
      );
      if (mounted) {
        Toast.show(context, message: 'File attached', tone: ToastTone.success);
      }
    } catch (error) {
      if (mounted) {
        Toast.show(
          context,
          message: _messageFor(error),
          tone: ToastTone.error,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final section = widget.section;
    final bundle = widget.bundle;

    return ListView(
      padding: Breakpoints.isCompact(context)
          ? AppSpacing.pagePaddingMobile
          : const EdgeInsets.all(AppSpacing.xl),
      children: [
        _IntroCard(section: section),
        const SizedBox(height: AppSpacing.md),
        switch (section.behaviour) {
          DailyDietBehaviour.timer => _PrayerBlock(
              section: section,
              bundle: bundle,
              busy: _busy,
              onSave: (minutes) => _save(actualDurationMinutes: minutes),
              onClear: _clear,
            ),
          DailyDietBehaviour.tick => _FastingBlock(
              section: section,
              bundle: bundle,
              busy: _busy,
              onToggle: section.isCompleted ? _clear : () => _save(),
            ),
          DailyDietBehaviour.report => _ReportBlock(
              section: section,
              bundle: bundle,
              busy: _busy,
              onUpload: _upload,
              onSave: () => _save(),
            ),
          DailyDietBehaviour.partner => _PartnerBlock(
              section: section,
              busy: _busy,
              onDone: () => _save(),
            ),
          DailyDietBehaviour.material => _MaterialBlock(
              section: section,
              busy: _busy,
              onDone: () => _save(),
            ),
          DailyDietBehaviour.text => _TextBlock(
              section: section,
              bundle: bundle,
              busy: _busy,
              onDone: () => _save(),
            ),
        },
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}

/// The section title, its scope and whatever the administrator wrote.
class _IntroCard extends StatelessWidget {
  const _IntroCard({required this.section});

  final DailyDietSection section;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = section.content;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: dailyDietTint(section.key),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  dailyDietSectionIcon(section),
                  size: 20,
                  color: AppColors.iconAccent,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      section.label,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    if (content != null)
                      Text(
                        '${content.scope.label} • ${content.title}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.inkMuted,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (section.description != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(section.description!, style: theme.textTheme.bodySmall),
          ],
          if (content != null && content.hasBody) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              content.body!,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
            ),
          ],
          if (content?.externalUrl != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _LinkButton(url: content!.externalUrl!),
          ],
        ],
      ),
    );
  }
}

/// A "copy the link" control — the app has no in-app browser.
class _LinkButton extends StatelessWidget {
  const _LinkButton({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return AppButton(
      label: 'Copy link',
      icon: Icons.link_rounded,
      variant: AppButtonVariant.outlined,
      onPressed: () async {
        await Clipboard.setData(ClipboardData(text: url));
        if (!context.mounted) return;
        Toast.show(
          context,
          message: 'Link copied — open it in your browser.',
          tone: ToastTone.info,
        );
      },
    );
  }
}

/// Readings, topics, teachings and declarations.
class _TextBlock extends StatelessWidget {
  const _TextBlock({
    required this.section,
    required this.bundle,
    required this.busy,
    required this.onDone,
  });

  final DailyDietSection section;
  final DailyDietBundle bundle;
  final bool busy;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final content = section.content;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (content?.reading != null)
          _HighlightCard(
            icon: Icons.menu_book_rounded,
            label: 'Today\'s reading',
            value: content!.reading!,
          ),
        if (content?.heading != null)
          _HighlightCard(
            icon: Icons.library_books_outlined,
            label: 'Reading through',
            value: content!.heading!,
          ),
        if (content?.focus != null) ...[
          _HighlightCard(
            icon: Icons.center_focus_strong_outlined,
            label: 'Focus',
            value: content!.focus!,
          ),
        ],
        if (content?.readingNote != null) ...[
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            color: AppColors.surfaceMuted,
            child: Text(
              content!.readingNote!,
              style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
            ),
          ),
        ],
        if (content?.topic != null) ...[
          _HighlightCard(
            icon: Icons.history_edu_rounded,
            label: 'Study topic',
            value: content!.topic!,
          ),
        ],
        if (bundle.monthlyPlan?.theme != null &&
            section.key == 'bible_study') ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            'Month theme',
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.inkMuted,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            bundle.monthlyPlan!.theme!,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.brandText,
            ),
          ),
        ],
        if (content?.teachings.isNotEmpty ?? false) ...[
          const SizedBox(height: AppSpacing.md),
          SectionHeader(
            title: 'Teachings',
            icon: Icons.menu_book_rounded,
            subtitle: '${content!.teachings.length} point(s)',
          ),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < content.teachings.length; i++) ...[
                  if (i > 0) const SizedBox(height: AppSpacing.sm),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${i + 1}.',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: AppColors.iconAccent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          content.teachings[i],
                          style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
        if (content?.declarations.isNotEmpty ?? false) ...[
          const SizedBox(height: AppSpacing.md),
          SectionHeader(
            title: 'Declare out loud',
            icon: Icons.record_voice_over_rounded,
            subtitle: '${content!.declarations.length} declaration(s)',
          ),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < content.declarations.length; i++) ...[
                  if (i > 0) const Divider(height: AppSpacing.lg),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.format_quote_rounded,
                        size: 18,
                        color: AppColors.iconAccent,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          content.declarations[i],
                          style: theme.textTheme.bodyMedium?.copyWith(
                            height: 1.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
        if ((content?.teachings.isEmpty ?? true) &&
            (content?.declarations.isEmpty ?? true) &&
            content?.reading == null &&
            content?.topic == null &&
            (content?.hasBody ?? false)) ...[
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Text(
              content!.body!,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        _DoneButton(
          busy: busy,
          done: section.isCompleted,
          label: section.behaviour.doneLabel,
          onPressed: onDone,
        ),
      ],
    );
  }
}

/// A highlighted value (a reading, a topic).
class _HighlightCard extends StatelessWidget {
  const _HighlightCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        color: AppColors.surfaceMuted,
        child: Row(
          children: [
            Icon(icon, size: 22, color: AppColors.iconAccent),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.inkMuted,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.brandText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Files attached to the section: literature, audio messages, music.
class _MaterialBlock extends StatelessWidget {
  const _MaterialBlock({
    required this.section,
    required this.busy,
    required this.onDone,
  });

  final DailyDietSection section;
  final bool busy;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = section.content;
    // Only the literature section carries a reading list; other sections use
    // the same key for the books the month is working through.
    final books = section.key == 'literature_reading'
        ? (content?.books ?? const <Map<String, dynamic>>[])
        : const <Map<String, dynamic>>[];
    // The audio and music sections list what to listen to for the period.
    final messages = section.key == 'audio_message'
        ? (content?.messages ?? const <String>[])
        : const <String>[];
    final songs = section.key == 'music'
        ? (content?.songs ?? const <String>[])
        : const <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (messages.isNotEmpty) ...[
          SectionHeader(
            title: 'Audio messages',
            icon: Icons.headphones_rounded,
            subtitle: '${messages.length} message(s)',
          ),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < messages.length; i++) ...[
                  if (i > 0) const Divider(height: AppSpacing.md),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.play_circle_outline_rounded,
                        size: 18,
                        color: AppColors.iconAccent,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          messages[i],
                          style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (songs.isNotEmpty) ...[
          SectionHeader(
            title: 'Songs',
            icon: Icons.music_note_rounded,
            subtitle: '${songs.length} song(s)',
          ),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < songs.length; i++) ...[
                  if (i > 0) const Divider(height: AppSpacing.md),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.library_music_outlined,
                        size: 18,
                        color: AppColors.iconAccent,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          songs[i],
                          style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (books.isNotEmpty) ...[
          SectionHeader(
            title: 'Reading list',
            icon: Icons.auto_stories_rounded,
            subtitle: '${books.length} item(s)',
          ),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < books.length; i++) ...[
                  if (i > 0) const Divider(height: AppSpacing.md),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.bookmark_border_rounded,
                        size: 18,
                        color: AppColors.iconAccent,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (books[i]['title'] ?? '').toString(),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if ((books[i]['author'] ?? '').toString().isNotEmpty)
                              Text(
                                (books[i]['author'] ?? '').toString(),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: AppColors.inkMuted,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (section.materials.isEmpty)
          AppCard(
            child: EmptyState(
              icon: Icons.folder_open_rounded,
              title: 'Nothing attached yet',
              message:
                  'Your ministry uploads the files for this section. Check back '
                  'soon.',
            ),
          )
        else ...[
          SectionHeader(
            title: 'Files',
            icon: Icons.attach_file_rounded,
            subtitle: '${section.materials.length} file(s)',
          ),
          AppCard(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            child: Column(
              children: [
                for (var i = 0; i < section.materials.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  _MaterialTile(material: section.materials[i]),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        _DoneButton(
          busy: busy,
          done: section.isCompleted,
          label: section.behaviour.doneLabel,
          onPressed: onDone,
        ),
      ],
    );
  }
}

/// One attached file.
class _MaterialTile extends StatelessWidget {
  const _MaterialTile({required this.material});

  final DailyDietMaterial material;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final type = dailyDietFileTypeLabel(material.fileType, material.fileName);
    final size = dailyDietFileSize(material.sizeBytes);

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => context.push('/materials/${material.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: dailyDietTint(material.category),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _iconFor(type),
                size: 19,
                color: AppColors.iconAccent,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    material.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      type,
                      if (material.author != null && material.author!.isNotEmpty)
                        material.author!,
                      if (size.isNotEmpty) size,
                    ].join(' • '),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.inkMuted,
            ),
          ],
        ),
      ),
    );
  }

  static IconData _iconFor(String type) => switch (type) {
        'Audio' => Icons.headphones_rounded,
        'Video' => Icons.movie_rounded,
        'Image' => Icons.image_rounded,
        'PDF' => Icons.picture_as_pdf_rounded,
        'Document' => Icons.description_rounded,
        _ => Icons.insert_drive_file_rounded,
      };
}

/// Prayer: the direction for the week or month plus the stopwatch.
class _PrayerBlock extends StatelessWidget {
  const _PrayerBlock({
    required this.section,
    required this.bundle,
    required this.busy,
    required this.onSave,
    required this.onClear,
  });

  final DailyDietSection section;
  final DailyDietBundle bundle;
  final bool busy;
  final Future<void> Function(int minutes) onSave;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final content = section.content;
    final target = content?.durationTargetMinutes ??
        bundle.weeklyPlan?.prayerDurationTargetMinutes;
    final focus = content?.monthlyFocus ??
        bundle.monthlyPlan?.prayerFocus ??
        bundle.weeklyPlan?.keyLessonPrompt;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (focus != null) ...[
          SectionHeader(
            title: 'Prayer direction',
            icon: Icons.self_improvement_rounded,
          ),
          AppCard(
            color: AppColors.surfaceMuted,
            child: Text(
              focus,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        SectionHeader(title: 'Prayer timer', icon: Icons.timer_outlined),
        AppCard(
          child: PrayerStopwatch(
            initialMinutes: section.completion?.actualDurationMinutes,
            targetMinutes: target,
            onSave: onSave,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (section.isCompleted)
          AppButton(
            label: 'Clear prayer time',
            icon: Icons.undo_rounded,
            variant: AppButtonVariant.outlined,
            expand: true,
            busy: busy,
            onPressed: onClear,
          ),
      ],
    );
  }
}

/// Fasting: the schedule plus the tick.
class _FastingBlock extends StatelessWidget {
  const _FastingBlock({
    required this.section,
    required this.bundle,
    required this.busy,
    required this.onToggle,
  });

  final DailyDietSection section;
  final DailyDietBundle bundle;
  final bool busy;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final guidance = section.content?.body ??
        section.content?.guidance ??
        bundle.weeklyPlan?.fastingSchedule ??
        bundle.monthlyPlan?.fastingGuidance;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: 'Fasting schedule', icon: Icons.wb_sunny_rounded),
        AppCard(
          color: AppColors.surfaceMuted,
          child: Text(
            guidance ?? 'No fasting is scheduled for this day.',
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: 'Set my fasting days',
          icon: Icons.edit_calendar_outlined,
          variant: AppButtonVariant.outlined,
          expand: true,
          onPressed: () => context.push('/fasting'),
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          child: Column(
            children: [
              Row(
                children: [
                  Icon(
                    section.isCompleted
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 24,
                    color: section.isCompleted
                        ? AppColors.success
                        : AppColors.inkMuted,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      section.isCompleted
                          ? 'You marked this day as fasted.'
                          : 'Tap when you have completed your fast.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: section.isCompleted ? 'Undo — I did not fast' : 'I fasted today',
                icon: section.isCompleted
                    ? Icons.undo_rounded
                    : Icons.check_rounded,
                expand: true,
                busy: busy,
                variant:
                    section.isCompleted ? AppButtonVariant.outlined : AppButtonVariant.filled,
                onPressed: onToggle,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The weekly and monthly report: write it or upload it.
class _ReportBlock extends StatelessWidget {
  const _ReportBlock({
    required this.section,
    required this.bundle,
    required this.busy,
    required this.onUpload,
    required this.onSave,
  });

  final DailyDietSection section;
  final DailyDietBundle bundle;
  final bool busy;
  final VoidCallback onUpload;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final questions = section.content?.questions ?? const <String>[];
    final attachment = section.completion?.attachment;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (questions.isNotEmpty) ...[
          SectionHeader(
            title: 'Questions to answer',
            icon: Icons.help_outline_rounded,
            subtitle: '${questions.length} question(s)',
          ),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < questions.length; i++) ...[
                  if (i > 0) const SizedBox(height: AppSpacing.sm),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${i + 1}.',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: AppColors.iconAccent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          questions[i],
                          style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        SectionHeader(title: 'Your report', icon: Icons.assignment_rounded),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Write your report in the report centre, or attach a file '
                'here.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'Write a weekly report',
                icon: Icons.edit_note_rounded,
                variant: AppButtonVariant.outlined,
                expand: true,
                onPressed: () => context.push('/reports/new/weekly'),
              ),
              const SizedBox(height: AppSpacing.xs),
              AppButton(
                label: 'Write a monthly report',
                icon: Icons.edit_calendar_rounded,
                variant: AppButtonVariant.outlined,
                expand: true,
                onPressed: () => context.push('/reports/new/monthly'),
              ),
              const SizedBox(height: AppSpacing.xs),
              AppButton(
                label: 'Upload a file',
                icon: Icons.upload_file_rounded,
                variant: AppButtonVariant.outlined,
                expand: true,
                busy: busy,
                onPressed: onUpload,
              ),
              if (attachment != null) ...[
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Icon(
                      Icons.attach_file_rounded,
                      size: 18,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        attachment.originalName ?? 'Attached file',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    StatusBadge(
                      label: 'Attached',
                      tone: AppBadgeTone.success,
                      small: true,
                    ),
                  ],
                ),
              ],
              if (section.completion?.note != null &&
                  attachment == null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  section.completion!.note!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.inkMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _DoneButton(
          busy: busy,
          done: section.isCompleted,
          label: section.behaviour.doneLabel,
          onPressed: onSave,
        ),
      ],
    );
  }
}

/// The prayer accountability partner.
class _PartnerBlock extends StatelessWidget {
  const _PartnerBlock({
    required this.section,
    required this.busy,
    required this.onDone,
  });

  final DailyDietSection section;
  final bool busy;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: 'Prayer accountability partner',
          icon: Icons.handshake_rounded,
        ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                section.description ??
                    'Connect with your prayer accountability partner in the '
                        'prayer room.',
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'Open the prayer room',
                icon: Icons.self_improvement_rounded,
                expand: true,
                onPressed: () => context.go('/prayer'),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _DoneButton(
          busy: busy,
          done: section.isCompleted,
          label: section.behaviour.doneLabel,
          onPressed: onDone,
        ),
      ],
    );
  }
}

/// The primary tick-off control.
class _DoneButton extends StatelessWidget {
  const _DoneButton({
    required this.busy,
    required this.done,
    required this.label,
    required this.onPressed,
  });

  final bool busy;
  final bool done;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AppButton(
      label: done ? 'Completed' : label,
      icon: done ? Icons.check_circle_rounded : Icons.check_circle_outline_rounded,
      expand: true,
      busy: busy,
      variant: done ? AppButtonVariant.outlined : AppButtonVariant.filled,
      onPressed: done ? null : onPressed,
    );
  }
}

/// Turns an API failure into a short, human message.
String _messageFor(Object error) {
  if (error is ApiException) return error.message;
  return 'Something went wrong. Please try again.';
}

/// A conservative content type for an uploaded file.
String? _contentTypeFor(String filename) {
  final ext = filename.contains('.')
      ? filename.split('.').last.toLowerCase()
      : '';
  return switch (ext) {
    'pdf' => 'application/pdf',
    'txt' => 'text/plain',
    'docx' =>
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'mp3' => 'audio/mpeg',
    'wav' => 'audio/wav',
    'm4a' => 'audio/mp4',
    'ogg' => 'audio/ogg',
    'aac' => 'audio/aac',
    'flac' => 'audio/flac',
    'mp4' => 'video/mp4',
    'mov' => 'video/quicktime',
    'webm' => 'video/webm',
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'gif' => 'image/gif',
    'webp' => 'image/webp',
    'svg' => 'image/svg+xml',
    _ => null,
  };
}
