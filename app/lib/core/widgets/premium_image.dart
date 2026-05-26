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
  });

  final String? url;
  final BoxFit fit;
  final Widget? fallback;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final placeholder = _Shimmer(theme: theme);
    final fb = fallback ??
        ColoredBox(
          color: theme.colorScheme.surfaceContainerHighest,
          child: Icon(
            Icons.image_outlined,
            color: theme.colorScheme.outlineVariant,
          ),
        );

    Widget image;
    if (url == null || url!.isEmpty) {
      image = fb;
    } else {
      image = CachedNetworkImage(
        imageUrl: url!,
        fit: fit,
        fadeInDuration: const Duration(milliseconds: 220),
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
