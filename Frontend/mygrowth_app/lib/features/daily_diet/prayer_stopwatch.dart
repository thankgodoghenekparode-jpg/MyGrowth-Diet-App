import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_buttons.dart';
import '../../core/widgets/app_text_field.dart';

/// The prayer stopwatch.
///
/// Members set the duration they are able to pray: either by running the
/// stopwatch while they pray, or by typing the number of minutes straight
/// away. The recorded minutes are stored with the tick-off.
class PrayerStopwatch extends StatefulWidget {
  const PrayerStopwatch({
    super.key,
    this.initialMinutes,
    this.targetMinutes,
    this.onSave,
  });

  /// The minutes already recorded for this section, if any.
  final int? initialMinutes;

  /// The duration the ministry suggests for this week.
  final int? targetMinutes;

  /// Called with the number of minutes to record.
  final Future<void> Function(int minutes)? onSave;

  @override
  State<PrayerStopwatch> createState() => _PrayerStopwatchState();
}

class _PrayerStopwatchState extends State<PrayerStopwatch> {
  Timer? _timer;
  int _elapsedSeconds = 0;
  bool _running = false;
  bool _saving = false;
  late final TextEditingController _manualController;

  @override
  void initState() {
    super.initState();
    _elapsedSeconds = (widget.initialMinutes ?? 0) * 60;
    _manualController = TextEditingController(
      text: widget.initialMinutes == null ? '' : '${widget.initialMinutes}',
    );
  }

  @override
  void didUpdateWidget(covariant PrayerStopwatch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialMinutes != oldWidget.initialMinutes &&
        widget.initialMinutes != null) {
      _stop();
      _elapsedSeconds = widget.initialMinutes! * 60;
      _manualController.text = '${widget.initialMinutes}';
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _manualController.dispose();
    super.dispose();
  }

  void _start() {
    if (_running) return;
    setState(() => _running = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsedSeconds += 1);
    });
  }

  void _pause() {
    _stop();
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    if (mounted) setState(() => _running = false);
  }

  void _reset() {
    _stop();
    setState(() => _elapsedSeconds = 0);
    _manualController.clear();
  }

  int get _elapsedMinutes => (_elapsedSeconds / 60).round();

  String get _display {
    final hours = _elapsedSeconds ~/ 3600;
    final minutes = (_elapsedSeconds % 3600) ~/ 60;
    final seconds = _elapsedSeconds % 60;
    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    return hours > 0
        ? '$hours:$mm:$ss'
        : '${minutes.toString().padLeft(2, '0')}:$ss';
  }

  Future<void> _save() async {
    final typed = int.tryParse(_manualController.text.trim());
    final minutes = typed ?? _elapsedMinutes;
    if (minutes <= 0) {
      _manualController.text = '';
      return;
    }
    final onSave = widget.onSave;
    if (onSave == null) return;
    setState(() => _saving = true);
    try {
      await onSave(minutes);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final target = widget.targetMinutes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: AppSpacing.controlRadius,
          ),
          child: Column(
            children: [
              Text(
                _display,
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.brandText,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                target == null
                    ? 'Time spent in prayer'
                    : '$target minutes suggested for this week',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.inkMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: _running ? 'Pause' : (_elapsedSeconds > 0 ? 'Resume' : 'Start'),
                icon: _running
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                variant: AppButtonVariant.filled,
                onPressed: _running ? _pause : _start,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            AppButton(
              label: 'Reset',
              icon: Icons.restart_alt_rounded,
              variant: AppButtonVariant.outlined,
              onPressed: _elapsedSeconds == 0 ? null : _reset,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          label: 'Minutes prayed',
          hint: 'e.g. 30',
          controller: _manualController,
          keyboardType: TextInputType.number,
          helper: 'Set the duration manually if you already know it.',
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: 'Save prayer time',
          icon: Icons.save_rounded,
          expand: true,
          busy: _saving,
          onPressed: (_elapsedMinutes == 0 &&
                  (int.tryParse(_manualController.text.trim()) ?? 0) == 0)
              ? null
              : _save,
        ),
      ],
    );
  }
}
