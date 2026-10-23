import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Filled button with a built-in busy state that prevents double submits.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.busy = false,
    this.icon,
    this.variant = AppButtonVariant.filled,
    this.expand = false,
    this.tooltip,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final IconData? icon;
  final AppButtonVariant variant;
  final bool expand;
  final String? tooltip;

  bool get _enabled => onPressed != null && !busy;

  @override
  Widget build(BuildContext context) {
    final child = busy
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: variant == AppButtonVariant.filled
                  ? Colors.white
                  : AppColors.linkText,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 19),
                const SizedBox(width: AppSpacing.xs),
              ],
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
            ],
          );

    Widget button;
    switch (variant) {
      case AppButtonVariant.filled:
        button = FilledButton(
          onPressed: _enabled ? onPressed : null,
          style: FilledButton.styleFrom(
            disabledBackgroundColor: AppColors.surfaceMuted,
            disabledForegroundColor: AppColors.inkMuted,
          ),
          child: child,
        );
      case AppButtonVariant.outlined:
        button = OutlinedButton(
          onPressed: _enabled ? onPressed : null,
          style: OutlinedButton.styleFrom(
            disabledForegroundColor: AppColors.inkMuted,
          ),
          child: child,
        );
      case AppButtonVariant.text:
        button = TextButton(
          onPressed: _enabled ? onPressed : null,
          child: child,
        );
      case AppButtonVariant.danger:
        button = FilledButton(
          onPressed: _enabled ? onPressed : null,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.danger,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.surfaceMuted,
            disabledForegroundColor: AppColors.inkMuted,
          ),
          child: child,
        );
    }

    if (expand) {
      button = SizedBox(width: double.infinity, child: button);
    }
    if (tooltip != null) {
      button = Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}

enum AppButtonVariant { filled, outlined, text, danger }

/// Small round icon button with consistent sizing.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.size = 40,
    this.filled = false,
    this.color,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final bool filled;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final btn = IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: size * 0.5),
      color: color ?? AppColors.iconAccent,
      style: IconButton.styleFrom(
        fixedSize: Size(size, size),
        backgroundColor: filled ? AppColors.navy100 : Colors.transparent,
        foregroundColor: color ?? AppColors.iconAccent,
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}
