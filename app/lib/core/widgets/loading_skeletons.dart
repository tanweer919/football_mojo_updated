import 'package:flutter/material.dart';

import '../design/app_colors.dart';
import '../design/app_spacing.dart';

/// Diagonally-sweeping shimmer overlay over a child of any shape. Cheap
/// (single AnimationController + a ShaderMask) and keeps the layout intact —
/// no asset-heavy Lottie file, no large color blocks.
class ShimmerSurface extends StatefulWidget {
  const ShimmerSurface({super.key, required this.child, this.intensity = 1.0});
  final Widget child;
  final double intensity;
  @override
  State<ShimmerSurface> createState() => _ShimmerSurfaceState();
}

class _ShimmerSurfaceState extends State<ShimmerSurface>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
        ..repeat();
  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = _ctrl.value;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (rect) {
            final dx = (t * 2 - 1) * rect.width;
            return LinearGradient(
              colors: [
                Colors.transparent,
                AppColors.gold.withValues(alpha: 0.18 * widget.intensity),
                Colors.transparent,
              ],
              stops: const [0.35, 0.5, 0.65],
              begin: Alignment(-1 + dx / rect.width, -0.5),
              end: Alignment(1 + dx / rect.width, 0.5),
            ).createShader(rect);
          },
          child: widget.child,
        );
      },
    );
  }
}

/// Skeleton block used as the surface inside ShimmerSurface — dark fill with
/// a gold hairline so it looks like a "real" Pitch component while loading.
class SkeletonBlock extends StatelessWidget {
  const SkeletonBlock({super.key, this.height = 80, this.width, this.radius = 12});
  final double height;
  final double? width;
  final double radius;
  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width ?? double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.borderSoft),
      ),
    );
  }
}

/// PCard-shaped skeleton (0.66 aspect) with shimmer.
class PCardSkeleton extends StatelessWidget {
  const PCardSkeleton({super.key});
  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 0.66,
      child: ShimmerSurface(
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.r4),
            border: Border.all(color: AppColors.goldHairline.withValues(alpha: 0.4)),
            gradient: const LinearGradient(
              colors: [Color(0xFF1F1814), Color(0xFF110C09)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _bar(width: 28, height: 22),
                  _bar(width: 20, height: 12),
                ],
              ),
              const Spacer(),
              _bar(width: 64, height: 12),
              const SizedBox(height: 4),
              _bar(width: 40, height: 9),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bar({required double width, required double height}) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.surface3,
          borderRadius: BorderRadius.circular(3),
        ),
      );
}

/// Match-card-shaped skeleton — 2 team rows + status pill + score blocks.
class MatchCardSkeleton extends StatelessWidget {
  const MatchCardSkeleton({super.key});
  @override
  Widget build(BuildContext context) {
    return ShimmerSurface(
      child: Container(
        height: 110,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.r4),
          border: Border.all(color: AppColors.borderSoft),
          color: AppColors.surface2,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [_pill(40), const Spacer(), _pill(28)]),
            const Spacer(),
            _row(),
            const SizedBox(height: 8),
            _row(),
          ],
        ),
      ),
    );
  }

  Widget _pill(double w) => Container(
        width: w,
        height: 14,
        decoration: BoxDecoration(
          color: AppColors.surface3,
          borderRadius: BorderRadius.circular(99),
        ),
      );

  Widget _row() => Row(
        children: [
          Container(width: 22, height: 16, color: AppColors.surface3),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 14,
              decoration: BoxDecoration(
                color: AppColors.surface3,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(width: 22, height: 16, color: AppColors.surface3),
        ],
      );
}

/// News-tile skeleton — 88×88 image stub + 2 text bars.
class NewsTileSkeleton extends StatelessWidget {
  const NewsTileSkeleton({super.key});
  @override
  Widget build(BuildContext context) {
    return ShimmerSurface(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.r4),
          border: Border.all(color: AppColors.borderSoft),
          color: AppColors.surface2,
        ),
        child: Row(
          children: [
            Container(
              width: 88, height: 64,
              decoration: BoxDecoration(
                color: AppColors.surface3,
                borderRadius: BorderRadius.circular(AppRadii.r3),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(width: 60, height: 8, color: AppColors.surface3),
                  const SizedBox(height: 8),
                  Container(width: double.infinity, height: 12, color: AppColors.surface3),
                  const SizedBox(height: 6),
                  Container(width: 140, height: 12, color: AppColors.surface3),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
