import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'appearance_controller.dart';

/// Appearance (light / dark / system) picker used on the settings screens.
class AppearanceSection extends ConsumerWidget {
  const AppearanceSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final mode = ref.watch(appearanceProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Light or dark mood',
                style: theme.textTheme.bodySmall,
              ),
            ),
            Text(
              mode.label,
              style: theme.textTheme.labelMedium
                  ?.copyWith(color: theme.colorScheme.primary),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final option in AppearanceMode.values) ...[
              Expanded(
                child: _ModeChip(
                  option: option,
                  selected: option == mode,
                  onTap: () =>
                      ref.read(appearanceProvider.notifier).setMode(option),
                ),
              ),
              if (option != AppearanceMode.values.last)
                const SizedBox(width: 8),
            ],
          ],
        ),
      ],
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final AppearanceMode option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected
          ? theme.colorScheme.primary
          : theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? theme.colorScheme.primary : theme.dividerColor,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                option.icon,
                size: 19,
                color: selected
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurface,
              ),
              const SizedBox(height: 4),
              Text(
                option.label,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact sun/moon button for switching mood straight from a header.
class AppearanceToggleButton extends ConsumerWidget {
  const AppearanceToggleButton({super.key, this.onDarkBackground = false});

  /// Whether the button sits on a dark surface (changes the icon colour).
  final bool onDarkBackground;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final icon = Icon(
      isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
      size: 19,
      color: onDarkBackground
          ? Colors.white
          : theme.colorScheme.onSurface,
    );
    final tooltip =
        isDark ? 'Switch to light mood' : 'Switch to dark mood';
    void toggle() =>
        ref.read(appearanceProvider.notifier).toggle(theme.brightness);

    if (!onDarkBackground) {
      return IconButton(
        tooltip: tooltip,
        onPressed: toggle,
        icon: icon,
      );
    }

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.12),
        shape: const CircleBorder(),
        child: InkWell(
          onTap: toggle,
          customBorder: const CircleBorder(),
          child: Padding(padding: const EdgeInsets.all(9), child: icon),
        ),
      ),
    );
  }
}
