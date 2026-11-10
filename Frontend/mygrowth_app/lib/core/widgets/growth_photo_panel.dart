import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Branded photo slot used on the member's key growth screens. Bundled photos
/// appear when available; the layered fallback keeps the layout intentional
/// while a ministry photo is still being selected.
class GrowthPhotoPanel extends StatelessWidget {
  const GrowthPhotoPanel({
    super.key,
    required this.image,
    required this.title,
    required this.caption,
    this.height = 190,
    this.tag,
    this.alignment = Alignment.center,
    this.child,
  });

  final String image;
  final String title;
  final String caption;
  final double height;
  final String? tag;
  final Alignment alignment;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              image,
              fit: BoxFit.cover,
              alignment: alignment,
              errorBuilder: (_, _, _) => const _PhotoFallback(),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x1609162A), Color(0xE809162A)],
                  stops: [0.12, 1],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (tag != null)
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.surface.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 6,
                        ),
                        child: Text(
                          tag!,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: AppColors.brandText,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ),
                  const Spacer(),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      height: 1.15,
                      shadows: const [
                        Shadow(blurRadius: 12, color: Colors.black54),
                      ],
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    caption,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.92),
                      shadows: const [
                        Shadow(blurRadius: 8, color: Colors.black54),
                      ],
                    ),
                  ),
                  if (child != null) ...[const SizedBox(height: 10), child!],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoFallback extends StatelessWidget {
  const _PhotoFallback();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFB6A18A), Color(0xFF13203F), Color(0xFF09162A)],
      ),
    ),
    child: Center(
      child: Icon(
        Icons.add_photo_alternate_outlined,
        size: 42,
        color: Colors.white.withValues(alpha: 0.7),
      ),
    ),
  );
}
