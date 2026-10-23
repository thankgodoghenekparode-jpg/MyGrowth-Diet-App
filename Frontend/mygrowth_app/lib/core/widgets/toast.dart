import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Success / error / info toast helpers with an accessible icon treatment.
class Toast {
  Toast._();

  static void show(
    BuildContext context, {
    required String message,
    ToastTone tone = ToastTone.neutral,
    Duration duration = const Duration(seconds: 3),
  }) {
    final (icon, color) = switch (tone) {
      ToastTone.success => (Icons.check_circle_rounded, AppColors.success),
      ToastTone.error => (Icons.error_rounded, AppColors.danger),
      ToastTone.info => (Icons.info_rounded, AppColors.gold400),
      ToastTone.neutral => (Icons.notifications_none_rounded, Colors.white),
    };
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          duration: duration,
          content: Row(
            children: [
              Icon(icon, color: tone == ToastTone.neutral ? Colors.white : color, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  static void success(BuildContext context, String message) =>
      show(context, message: message, tone: ToastTone.success);

  static void error(BuildContext context, String message) =>
      show(context, message: message, tone: ToastTone.error, duration: const Duration(seconds: 5));

  static void info(BuildContext context, String message) =>
      show(context, message: message, tone: ToastTone.info);
}

enum ToastTone { success, error, info, neutral }

/// Shows a confirmation dialog; resolves to true when confirmed.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: AppColors.danger)
              : null,
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
