import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// A single slide in an [ImageCarousel].
///
/// [image] is a bundled asset path. Replace the entries in a screen's slide
/// list to change the pictures — no other code needs to change.
class CarouselSlide {
  const CarouselSlide({
    required this.image,
    this.title,
    this.caption,
    this.icon,
    this.actionLabel,
  });

  /// Bundled asset path, e.g. `assets/images/dashboard.jpg`.
  final String image;
  final String? title;
  final String? caption;
  final IconData? icon;

  /// Optional call-to-action rendered as a pill button on the slide.
  final String? actionLabel;
}

/// Auto-advancing, swipeable image banner used as the hero on the home screens.
///
/// Designed as a drop-in placeholder strip: swap the [slides] you pass in and
/// the layout adapts. Images use `BoxFit.cover`, so mixed aspect ratios are
/// fine; a dark gradient keeps any text legible.
class ImageCarousel extends StatefulWidget {
  const ImageCarousel({
    super.key,
    required this.slides,
    this.height = 220,
    this.autoAdvance = true,
    this.interval = const Duration(seconds: 5),
    this.onTapSlide,
    this.onAction,
  });

  final List<CarouselSlide> slides;
  final double height;
  final bool autoAdvance;
  final Duration interval;

  /// Optional tap handler; receives the index of the tapped slide.
  final void Function(int index)? onTapSlide;

  /// Optional handler for the slide's call-to-action button.
  final void Function(int index)? onAction;

  @override
  State<ImageCarousel> createState() => _ImageCarouselState();
}

class _ImageCarouselState extends State<ImageCarousel> {
  final _controller = PageController();
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _restartTimer();
  }

  @override
  void didUpdateWidget(covariant ImageCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slides.length != widget.slides.length ||
        oldWidget.autoAdvance != widget.autoAdvance ||
        oldWidget.interval != widget.interval) {
      _restartTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _restartTimer() {
    _timer?.cancel();
    if (!widget.autoAdvance || widget.slides.length < 2) return;
    _timer = Timer.periodic(widget.interval, (_) {
      if (!mounted || !_controller.hasClients) return;
      final next = (_index + 1) % widget.slides.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.slides.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: widget.height,
          child: ClipRRect(
            borderRadius: AppSpacing.cardRadius,
            child: Stack(
              fit: StackFit.expand,
              children: [
                PageView.builder(
                  controller: _controller,
                  itemCount: widget.slides.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (context, i) => _Slide(
                    slide: widget.slides[i],
                    onTap: widget.onTapSlide == null
                        ? null
                        : () => widget.onTapSlide!(i),
                    onAction: widget.onAction == null
                        ? null
                        : () => widget.onAction!(i),
                  ),
                ),
                // Page dots. Positioned low so they never fight the text.
                if (widget.slides.length > 1)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: AppSpacing.sm,
                    child: _Dots(
                      count: widget.slides.length,
                      active: _index,
                      onSelect: (i) => _controller.animateToPage(
                        i,
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeOutCubic,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Slide extends StatelessWidget {
  const _Slide({required this.slide, this.onTap, this.onAction});

  final CarouselSlide slide;
  final VoidCallback? onTap;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final hasText = (slide.title ?? '').isNotEmpty ||
        (slide.caption ?? '').isNotEmpty ||
        (slide.actionLabel ?? '').isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            slide.image,
            fit: BoxFit.cover,
            // A missing or corrupt asset must never break the home screen.
            errorBuilder: (_, _, _) => ColoredBox(
              color: AppColors.darkEmerald,
              child: Center(
                child: Icon(
                  Icons.image_outlined,
                  color: Colors.white24,
                  size: 40,
                ),
              ),
            ),
          ),
          // Bottom-up scrim: keeps text legible over any photo.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.05),
                  Colors.black.withValues(alpha: 0.18),
                  Colors.black.withValues(alpha: 0.72),
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),
          if (hasText)
            Positioned(
              left: AppSpacing.md,
              right: AppSpacing.md,
              bottom: AppSpacing.xxl,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if ((slide.title ?? '').isNotEmpty)
                    Row(
                      children: [
                        if (slide.icon != null) ...[
                          Icon(slide.icon, color: AppColors.softGold, size: 17),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: Text(
                            slide.title!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  if ((slide.caption ?? '').isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      slide.caption!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                  if ((slide.actionLabel ?? '').isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _SlideAction(
                      label: slide.actionLabel!,
                      onPressed: onAction,
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Pill-shaped call-to-action rendered on top of a carousel slide.
class _SlideAction extends StatelessWidget {
  const _SlideAction({required this.label, this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: AppColors.champagneGold,
        borderRadius: BorderRadius.circular(30),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(30),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: AppColors.darkEmerald,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 15,
                  color: AppColors.darkEmerald,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({
    required this.count,
    required this.active,
    required this.onSelect,
  });

  final int count;
  final int active;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            Semantics(
              button: true,
              selected: i == active,
              label: 'Slide ${i + 1} of $count',
              child: GestureDetector(
                onTap: () => onSelect(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == active ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == active
                        ? AppColors.softGold
                        : Colors.white.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
