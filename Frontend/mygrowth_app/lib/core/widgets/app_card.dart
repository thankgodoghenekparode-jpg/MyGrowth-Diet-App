import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// The standard surface: white card, hairline border, soft radius.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = AppSpacing.cardPadding,
    this.margin = EdgeInsets.zero,
    this.onTap,
    this.highlight,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;
  final bool? highlight;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final highlighted = highlight ?? false;
    final card = Card(
      color: color ?? AppColors.surface,
      elevation: 0,
      margin: margin,
      shape: RoundedRectangleBorder(
        borderRadius: AppSpacing.cardRadius,
        side: BorderSide(
          color: highlighted ? AppColors.gold400 : AppColors.border,
          width: highlighted ? 1.4 : 1,
        ),
      ),
      child: Padding(padding: padding, child: child),
    );
    if (onTap == null) return card;
    return Card(
      color: color ?? AppColors.surface,
      elevation: 0,
      margin: margin,
      shape: RoundedRectangleBorder(
        borderRadius: AppSpacing.cardRadius,
        side: BorderSide(
          color: highlighted ? AppColors.gold400 : AppColors.border,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// A card with a title, optional trailing action and content.
class TitledCard extends StatelessWidget {
  const TitledCard({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.icon,
    this.padding = AppSpacing.cardPadding,
  });

  final String title;
  final Widget child;
  final Widget? trailing;
  final IconData? icon;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: AppColors.navy700),
                const SizedBox(width: AppSpacing.xs),
              ],
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }
}

/// Gold-accented highlight card used for affirmations, confessions and
/// prayer focus messages.
class VerseCard extends StatelessWidget {
  const VerseCard({
    super.key,
    required this.text,
    this.label,
    this.caption,
    this.icon = Icons.format_quote_rounded,
    this.tone = VerseTone.navy,
  });

  final String text;
  final String? label;
  final String? caption;
  final IconData icon;
  final VerseTone tone;

  @override
  Widget build(BuildContext context) {
    final style = switch (tone) {
      VerseTone.navy => (
          bg: AppColors.brandSurface,
          fg: Colors.white,
          accent: AppColors.gold400,
          subtle: Colors.white70,
        ),
      VerseTone.gold => (
          bg: AppColors.gold100,
          fg: AppColors.accentText,
          accent: AppColors.gold600,
          subtle: AppColors.inkSecondary,
        ),
      VerseTone.light => (
          bg: AppColors.surface,
          fg: AppColors.ink,
          accent: AppColors.gold500,
          subtle: AppColors.inkSecondary,
        ),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: style.bg,
        borderRadius: AppSpacing.cardRadius,
        border: tone == VerseTone.light
            ? Border.all(color: AppColors.border)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: style.accent, size: 20),
              const SizedBox(width: AppSpacing.xs),
              if (label != null)
                Expanded(
                  child: Text(
                    label!.toUpperCase(),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: style.subtle,
                          letterSpacing: 1.1,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            text,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: style.fg,
                  height: 1.6,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w500,
                ),
          ),
          if (caption != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              caption!,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: style.subtle,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

enum VerseTone { navy, gold, light }
