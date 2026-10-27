import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/models/app_user.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_buttons.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/feedback_states.dart';
import '../../core/widgets/toast.dart';

/// The member's notification preferences (GET/PUT `/me/notification-preferences`).
final notificationPrefsProvider =
    FutureProvider.autoDispose<NotificationPrefs>(
  (ref) async {
    final client = ref.watch(apiClientProvider);
    try {
      final data = await client.get('/me/notification-preferences');
      if (data is Map<String, dynamic>) {
        return NotificationPrefs.fromJson(data);
      }
      return const NotificationPrefs();
    } on ApiException catch (e) {
      if (e.statusCode == 404 || e.statusCode == 501) {
        // Endpoint not configured yet — fall back to defaults.
        return const NotificationPrefs();
      }
      rethrow;
    }
  },
);

/// Reusable notification-preferences editor, used by the notifications
/// screen bottom sheet and the profile screen.
class NotificationPrefsSection extends ConsumerStatefulWidget {
  const NotificationPrefsSection({super.key});

  @override
  ConsumerState<NotificationPrefsSection> createState() =>
      _NotificationPrefsSectionState();
}

class _NotificationPrefsSectionState
    extends ConsumerState<NotificationPrefsSection> {
  final _reminderTime = TextEditingController();
  final _sessionMinutes = TextEditingController();
  bool _emailEnabled = true;
  bool _dailyReminderEnabled = true;
  bool _weeklyReportReminder = true;
  bool _monthlyReportReminder = true;
  bool _sessionReminders = true;
  String _summaryFrequency = 'DAILY';
  bool _initialized = false;
  bool _busy = false;

  @override
  void dispose() {
    _reminderTime.dispose();
    _sessionMinutes.dispose();
    super.dispose();
  }

  void _initFrom(NotificationPrefs prefs) {
    _emailEnabled = prefs.emailEnabled;
    _dailyReminderEnabled = prefs.dailyReminderEnabled;
    _reminderTime.text = prefs.dailyReminderTime;
    _weeklyReportReminder = prefs.weeklyReportReminder;
    _monthlyReportReminder = prefs.monthlyReportReminder;
    _sessionReminders = prefs.sessionReminders;
    _sessionMinutes.text = '${prefs.sessionReminderMinutes}';
    _summaryFrequency =
        const ['DAILY', 'WEEKLY', 'OFF'].contains(prefs.summaryFrequency)
            ? prefs.summaryFrequency
            : 'DAILY';
    _initialized = true;
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final client = ref.read(apiClientProvider);
    final prefs = NotificationPrefs(
      emailEnabled: _emailEnabled,
      dailyReminderEnabled: _dailyReminderEnabled,
      dailyReminderTime: _reminderTime.text.trim().isEmpty
          ? '06:00'
          : _reminderTime.text.trim(),
      weeklyReportReminder: _weeklyReportReminder,
      monthlyReportReminder: _monthlyReportReminder,
      sessionReminders: _sessionReminders,
      sessionReminderMinutes:
          int.tryParse(_sessionMinutes.text.trim()) ?? 30,
      timeZone: ref.read(notificationPrefsProvider).value?.timeZone ??
          'Africa/Lagos',
      summaryFrequency: _summaryFrequency,
    );
    try {
      await client.put(
        '/me/notification-preferences',
        body: prefs.toJson(),
      );
      ref.invalidate(notificationPrefsProvider);
      if (mounted) Toast.success(context, 'Notification preferences saved.');
    } on ApiException catch (e) {
      if (mounted) Toast.error(context, e.fieldError ?? e.message);
    } catch (_) {
      if (mounted) {
        Toast.error(context, 'Unable to save preferences just now.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(notificationPrefsProvider);
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: SkeletonBox(height: 280, radius: 14),
      ),
      error: (e, _) => ErrorState(
        error: e,
        compact: true,
        onRetry: () => ref.invalidate(notificationPrefsProvider),
      ),
      data: (prefs) {
        if (!_initialized) _initFrom(prefs);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            AppSwitchRow(
              label: 'Email notifications',
              subtitle: 'Receive updates by email as well.',
              value: _emailEnabled,
              onChanged: (v) => setState(() => _emailEnabled = v),
            ),
            AppSwitchRow(
              label: 'Daily devotion reminder',
              subtitle: 'A gentle reminder to read your devotion and daily plan.',
              value: _dailyReminderEnabled,
              onChanged: (v) => setState(() => _dailyReminderEnabled = v),
            ),
            if (_dailyReminderEnabled) ...[
              AppTextField(
                label: 'Daily reminder time (HH:MM)',
                controller: _reminderTime,
                hint: '06:00',
                keyboardType: TextInputType.datetime,
              ),
              const SizedBox(height: fieldGap),
            ],
            AppSwitchRow(
              label: 'Weekly report reminder',
              value: _weeklyReportReminder,
              onChanged: (v) => setState(() => _weeklyReportReminder = v),
            ),
            AppSwitchRow(
              label: 'Monthly report reminder',
              value: _monthlyReportReminder,
              onChanged: (v) => setState(() => _monthlyReportReminder = v),
            ),
            AppSwitchRow(
              label: 'Prayer session reminders',
              subtitle: 'Get reminded before prayer-partner sessions.',
              value: _sessionReminders,
              onChanged: (v) => setState(() => _sessionReminders = v),
            ),
            if (_sessionReminders) ...[
              AppTextField(
                label: 'Remind me this many minutes before',
                controller: _sessionMinutes,
                hint: '30',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: fieldGap),
            ],
            AppDropdown<String>(
              label: 'Email summary frequency',
              value: _summaryFrequency,
              items: const [
                DropdownMenuItem(value: 'DAILY', child: Text('Daily')),
                DropdownMenuItem(value: 'WEEKLY', child: Text('Weekly')),
                DropdownMenuItem(value: 'OFF', child: Text('Off')),
              ],
              onChanged: (v) =>
                  setState(() => _summaryFrequency = v ?? 'DAILY'),
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'Save preferences',
              icon: Icons.save_outlined,
              busy: _busy,
              expand: true,
              onPressed: _save,
            ),
          ],
        );
      },
    );
  }
}
