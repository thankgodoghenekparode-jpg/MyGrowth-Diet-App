import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/models/programme_models.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_buttons.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/feedback_states.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/toast.dart';
import '../programme/programme_providers.dart';
import 'admin_providers.dart';
import 'admin_shared.dart';

const String kMinistryName = 'Healings Erhuvwuigho Azuike Ministry';

/// Create (`programmeId == null`) or edit an annual programme.
class ProgrammeEditScreen extends ConsumerWidget {
  const ProgrammeEditScreen({super.key, this.programmeId});

  final String? programmeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _ProgrammeEditBody(programmeId: programmeId);
  }
}

class _ProgrammeEditBody extends ConsumerStatefulWidget {
  const _ProgrammeEditBody({this.programmeId});

  final String? programmeId;

  @override
  ConsumerState<_ProgrammeEditBody> createState() =>
      _ProgrammeEditBodyState();
}

class _ProgrammeEditBodyState extends ConsumerState<_ProgrammeEditBody> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _year =
      TextEditingController(text: '${DateTime.now().year + 1}');
  final TextEditingController _ministry =
      TextEditingController(text: kMinistryName);
  final TextEditingController _description = TextEditingController();
  final TextEditingController _prayerFocus = TextEditingController();
  final TextEditingController _affirmation = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;
  String _status = 'DRAFT';
  bool _prefilled = false;
  bool _saving = false;
  String? _titleError;
  String? _yearError;

  bool get _isCreate => widget.programmeId == null;

  @override
  void dispose() {
    _title.dispose();
    _year.dispose();
    _ministry.dispose();
    _description.dispose();
    _prayerFocus.dispose();
    _affirmation.dispose();
    super.dispose();
  }

  void _apply(AnnualProgramme programme) {
    _title.text = programme.title;
    _year.text = '${programme.year}';
    if (programme.ministryName.isNotEmpty) {
      _ministry.text = programme.ministryName;
    }
    _description.text = programme.description ?? '';
    _prayerFocus.text = programme.prayerFocus ?? '';
    _affirmation.text = programme.dailyAffirmation ?? '';
    _startDate = programme.startDate;
    _endDate = programme.endDate;
    _status = programme.status;
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    final year = int.tryParse(_year.text.trim());
    setState(() {
      _titleError = title.isEmpty ? 'A title is required' : null;
      _yearError = (year == null || year < 2000 || year > 2100)
          ? 'Enter a year between 2000 and 2100'
          : null;
    });
    if (_titleError != null || _yearError != null || _saving) return;

    setState(() => _saving = true);
    final body = <String, dynamic>{
      'title': title,
      'year': year,
      'ministryName': _ministry.text.trim(),
      'description': _description.text.trim(),
      'prayerFocus': _prayerFocus.text.trim(),
      'dailyAffirmation': _affirmation.text.trim(),
      'status': _status,
      if (_startDate != null)
        'startDate': DateFormat('yyyy-MM-dd').format(_startDate!),
      if (_endDate != null)
        'endDate': DateFormat('yyyy-MM-dd').format(_endDate!),
    };
    try {
      final client = ref.read(apiClientProvider);
      if (_isCreate) {
        await client.post('/admin/programmes', body: body);
      } else {
        await client.patch(
          '/admin/programmes/${widget.programmeId}',
          body: body,
        );
      }
      if (!mounted) return;
      ref.invalidate(adminProgrammesProvider);
      ref.invalidate(programmeYearsProvider);
      ref.invalidate(currentProgrammeProvider);
      if (widget.programmeId != null) {
        ref.invalidate(adminProgrammeProvider(widget.programmeId!));
      }
      Toast.success(
        context,
        _isCreate
            ? 'Programme created. Add monthly plans next!'
            : 'Programme saved.',
      );
      context.go('/admin/programmes');
    } on ApiException catch (e) {
      if (!mounted) return;
      Toast.error(context, e.fieldError ?? e.message);
    } catch (_) {
      if (!mounted) return;
      Toast.error(context, 'Couldn’t save the programme just now.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCreate) return _form(context, ref);

    final programmeAsync = ref.watch(adminProgrammeProvider(widget.programmeId!));
    return programmeAsync.when(
      loading: () => ListView(
        padding: adminPadding(context),
        children: const [
          SkeletonBox(height: 320, radius: 14),
        ],
      ),
      error: (error, _) => ErrorState(
        error: error,
        onRetry: () =>
            ref.invalidate(adminProgrammeProvider(widget.programmeId!)),
      ),
      data: (programme) {
        if (programme == null) {
          return EmptyState(
            icon: Icons.event_busy_outlined,
            title: 'Programme not found',
            message: 'It may have been removed.',
            actionLabel: 'Back to programmes',
            onAction: () => context.go('/admin/programmes'),
          );
        }
        if (!_prefilled) {
          _prefilled = true;
          _apply(programme);
        }
        return _form(context, ref);
      },
    );
  }

  Widget _form(BuildContext context, WidgetRef ref) {
    final programmes = ref.watch(adminProgrammesProvider);
    final enteredYear = int.tryParse(_year.text.trim());
    final duplicateYear = programmes.maybeWhen(
      data: (items) => items.any(
        (p) =>
            p.year == enteredYear &&
            (_isCreate || p.id != widget.programmeId),
      ),
      orElse: () => false,
    );

    return ListView(
      padding: adminPadding(context),
      children: [
        SectionHeader(
          title: _isCreate ? 'Create Annual Programme' : 'Edit Programme',
          subtitle: _isCreate
              ? 'Set the foundation for a new programme year'
              : 'Update the programme details',
          icon: Icons.event_note_outlined,
        ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                label: 'Title',
                controller: _title,
                required: true,
                errorText: _titleError,
                hint: 'e.g. My Growth Diet Plan ${_year.text}',
                onChanged: (_) => setState(() => _titleError = null),
              ),
              const SizedBox(height: fieldGap),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  SizedBox(
                    width: Breakpoints.isCompact(context) ? 160 : 200,
                    child: AppTextField(
                      label: 'Programme year',
                      controller: _year,
                      required: true,
                      errorText: _yearError,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() => _yearError = null),
                    ),
                  ),
                  SizedBox(
                    width: Breakpoints.isCompact(context) ? 160 : 200,
                    child: AppDropdown<String>(
                      label: 'Status',
                      value: _status,
                      items: const [
                        DropdownMenuItem(value: 'DRAFT', child: Text('Draft')),
                        DropdownMenuItem(
                            value: 'PUBLISHED', child: Text('Published')),
                        DropdownMenuItem(
                            value: 'ARCHIVED', child: Text('Archived')),
                      ],
                      onChanged: (value) =>
                          setState(() => _status = value ?? 'DRAFT'),
                    ),
                  ),
                ],
              ),
              if (duplicateYear) ...[
                const SizedBox(height: AppSpacing.sm),
                AdminBanner(
                  text:
                      'A programme for $enteredYear already exists. Saving '
                      'will create a second one — consider editing the '
                      'existing year instead.',
                  tone: AdminBannerTone.warning,
                  icon: Icons.warning_amber_outlined,
                ),
              ],
              const SizedBox(height: fieldGap),
              AppTextField(
                label: 'Ministry name',
                controller: _ministry,
              ),
              const SizedBox(height: fieldGap),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  SizedBox(
                    width: Breakpoints.isCompact(context)
                        ? double.infinity
                        : 240,
                    child: AppDateField(
                      label: 'Start date',
                      value: _startDate,
                      onChanged: (value) =>
                          setState(() => _startDate = value),
                    ),
                  ),
                  SizedBox(
                    width: Breakpoints.isCompact(context)
                        ? double.infinity
                        : 240,
                    child: AppDateField(
                      label: 'End date',
                      value: _endDate,
                      onChanged: (value) => setState(() => _endDate = value),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: fieldGap),
              AppTextField(
                label: 'Description',
                controller: _description,
                maxLines: 3,
                hint: 'What is this programme year about?',
              ),
              const SizedBox(height: fieldGap),
              AppTextField(
                label: 'Annual prayer focus',
                controller: _prayerFocus,
                maxLines: 3,
                hint: 'The theme the ministry prays through the year with',
              ),
              const SizedBox(height: fieldGap),
              AppTextField(
                label: 'Daily affirmation',
                controller: _affirmation,
                maxLines: 3,
                hint: 'A short statement members read each day',
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'Cancel',
                      variant: AppButtonVariant.text,
                      onPressed:
                          _saving ? null : () => context.go('/admin/programmes'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    flex: 2,
                    child: AppButton(
                      label: _isCreate ? 'Create programme' : 'Save changes',
                      icon: Icons.save_outlined,
                      busy: _saving,
                      onPressed: _save,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Tip: after creating a year, add its monthly plans, then weekly '
          'and daily activities.',
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );
  }
}
