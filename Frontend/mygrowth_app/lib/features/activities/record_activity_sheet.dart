import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/models/activity_models.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_buttons.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/toast.dart';
import '../programme/programme_providers.dart';

/// Bottom sheet to record completion / progress / a missed activity.
///
/// This is the shared copy of the dashboard's record sheet, reused by the
/// Daily Diet checklist and the Bible Reading screen. It POSTs (or PATCHes)
/// `/me/activity-records` and invalidates the checklist for the activity's
/// date so the UI reflects the new record.
class RecordActivitySheet extends ConsumerStatefulWidget {
  const RecordActivitySheet({super.key, required this.activity, this.onSaved});

  final PlannedActivity activity;

  /// Called after a successful save (once the sheet has closed).
  final VoidCallback? onSaved;

  @override
  ConsumerState<RecordActivitySheet> createState() =>
      _RecordActivitySheetState();
}

class _RecordActivitySheetState extends ConsumerState<RecordActivitySheet> {
  late String _status = widget.activity.record?.status ?? 'COMPLETED';
  final _note = TextEditingController();
  final _duration = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _note.text = widget.activity.record?.note ?? '';
    _duration.text = widget.activity.record?.actualDuration ?? '';
  }

  @override
  void dispose() {
    _note.dispose();
    _duration.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final client = ref.read(apiClientProvider);
    final rawDate = widget.activity.date ?? DateTime.now();
    final date = DateTime(rawDate.year, rawDate.month, rawDate.day);
    final body = {
      'activityId': widget.activity.id,
      'date': DateFormat('yyyy-MM-dd').format(date),
      'status': _status,
      if (_note.text.trim().isNotEmpty) 'note': _note.text.trim(),
      if (_duration.text.trim().isNotEmpty)
        'actualDuration': _duration.text.trim(),
    };
    try {
      final existing = widget.activity.record;
      if (existing == null) {
        await client.post('/me/activity-records', body: body);
      } else {
        await client.patch('/me/activity-records/${existing.id}', body: {
          'status': _status,
          if (_note.text.trim().isNotEmpty) 'note': _note.text.trim(),
          if (_duration.text.trim().isNotEmpty)
            'actualDuration': _duration.text.trim(),
        });
      }
      if (!mounted) return;
      ref.invalidate(dailyChecklistProvider(date));
      final onSaved = widget.onSaved;
      Navigator.of(context).pop();
      final message = switch (_status) {
        'COMPLETED' => 'Recorded. Well done on keeping your diet plan!',
        'SKIPPED' => 'Saved. It’s okay — consistency grows one day at a time.',
        'IN_PROGRESS' => 'Saved. You can update this later today.',
        _ => 'Saved.',
      };
      Toast.success(context, message);
      if (onSaved != null) onSaved();
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(widget.activity.title,
                  style: Theme.of(context).textTheme.titleLarge),
            ),
            AppIconButton(
              icon: Icons.close_rounded,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        if (widget.activity.description != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(widget.activity.description!,
              style: Theme.of(context).textTheme.bodySmall),
        ],
        const SizedBox(height: AppSpacing.md),
        Text('How did it go?', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final option in const [
              ('COMPLETED', 'Completed', Icons.check_circle_outline),
              ('IN_PROGRESS', 'In progress', Icons.timelapse),
              ('SKIPPED', 'Missed today', Icons.pause_circle_outline),
            ])
              ChoiceChip(
                label: Text(option.$2),
                avatar: Icon(option.$3, size: 16),
                selected: _status == option.$1,
                onSelected: (_) => setState(() => _status = option.$1),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          label: 'Minutes spent (optional)',
          controller: _duration,
          keyboardType: TextInputType.number,
          hint: 'e.g. 20',
        ),
        const SizedBox(height: fieldGap),
        AppTextField(
          label: 'Private note (optional)',
          controller: _note,
          maxLines: 3,
          hint: 'Anything you’d like to remember about this activity',
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: 'Save',
          busy: _busy,
          expand: true,
          onPressed: _save,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Activity records are self-reported. Be honest and gracious with '
          'yourself.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );
  }
}

/// Shows the [RecordActivitySheet] with the app's standard sheet styling.
void showRecordActivitySheet(
  BuildContext context, {
  required PlannedActivity activity,
  VoidCallback? onSaved,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.viewInsetsOf(sheetContext).bottom + AppSpacing.lg,
      ),
      child: RecordActivitySheet(activity: activity, onSaved: onSaved),
    ),
  );
}
