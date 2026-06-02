import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// CachedNetworkImage with shimmer placeholder + graceful fallback. Use this
/// instead of CachedNetworkImage everywhere — it keeps placeholder cadence
/// consistent across the app.
class PremiumImage extends StatelessWidget {
  const PremiumImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.fallback,
    this.borderRadius,
    this.fadeInDuration = const Duration(milliseconds: 220),
  });

  final String? url;
  final BoxFit fit;
  final Widget? fallback;
  final BorderRadius? borderRadius;
  /// Fade-in for the loaded image. Set to [Duration.zero] when capturing
  /// the widget to a PNG (off-screen RepaintBoundary) so crests paint
  /// fully on the first frame instead of mid-fade.
  final Duration fadeInDuration;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final placeholder = _Shimmer(theme: theme);
    // Dark, on-brand fallback for a missing/broken image. Previously this
    // used the M3 `surfaceContainerHighest`, which on the seeded colour
    // scheme is a bright cyan — a broken card photo then rendered as a
    // glaring cyan rectangle.
    final fb = fallback ??
        const ColoredBox(
          color: Color(0xFF1A1815),
          child: Icon(Icons.image_not_supported_outlined, color: Color(0x66FFFFFF)),
        );

    Widget image;
    if (url == null || url!.isEmpty) {
      image = fb;
    } else {
      image = CachedNetworkImage(
        imageUrl: url!,
        fit: fit,
        fadeInDuration: fadeInDuration,
        placeholder: (_, __) => placeholder,
        errorWidget: (_, __, ___) => fb,
      );
    }

    if (borderRadius == null) return image;
    return ClipRRect(borderRadius: borderRadius!, child: image);
  }
}

class _Shimmer extends StatelessWidget {
  const _Shimmer({required this.theme});
  final ThemeData theme;
  @override
  Widget build(BuildContext context) {
    final base = theme.colorScheme.surfaceContainerHighest;
    final hi = theme.colorScheme.surfaceContainerHigh;
    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: hi,
      period: const Duration(milliseconds: 1100),
      child: ColoredBox(color: base),
    );
  }
}
