import 'package:flutter/material.dart';

import '../../../../core/widgets/premium_image.dart';

/// Renders an article thumbnail. When `imageUrl` is present and loads, shows
/// the image. When missing or broken, shows a *branded* fallback derived from
/// the source name — looks intentional, never "broken".
///
/// The fallback uses a deterministic source-color (hash of source name) so
/// the same publication always gets the same accent; plus a big source
/// initial as a centerpiece. Reads as a stylised "no-image" card, not a
/// missing asset.
class NewsThumb extends StatelessWidget {
  const NewsThumb({
    super.key,
    required this.imageUrl,
    required this.source,
    this.borderRadius,
    this.dense = false,
  });

  final String? imageUrl;
  final String source;
  final BorderRadius? borderRadius;
  /// Smaller initial typography for compact list rows.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final fallback = _BrandedFallback(source: source, dense: dense);
    return PremiumImage(
      url: imageUrl,
      fallback: fallback,
      borderRadius: borderRadius,
    );
  }
}

class _BrandedFallback extends StatelessWidget {
  const _BrandedFallback({required this.source, required this.dense});
  final String source;
  final bool dense;

  // FNV-1a 32-bit — deterministic, stable per source name.
  static int _hash(String s) {
    var h = 0x811c9dc5;
    for (var i = 0; i < s.length; i++) {
      h ^= s.codeUnitAt(i);
      h = (h * 0x01000193) & 0xffffffff;
    }
    return h;
  }

  /// Returns a (top, bottom) gradient pair seeded by the source name.
  (Color top, Color bottom) _palette(String source) {
    // Hue rotates per source; lightness clamped low so text stays readable.
    final h = _hash(source.toLowerCase());
    final hue = (h % 360).toDouble();
    final top = HSLColor.fromAHSL(1, hue, 0.32, 0.18).toColor();
    final bottom = HSLColor.fromAHSL(1, (hue + 28) % 360, 0.35, 0.10).toColor();
    return (top, bottom);
  }

  String get _initial {
    final s = source.trim();
    if (s.isEmpty) return 'N';
    return s.characters.first.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final (top, bottom) = _palette(source);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [top, bottom],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Big source initial as a watermark — centered, slightly off-axis
          // so it doesn't fight a possible source-pill overlay above.
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _initial,
                style: TextStyle(
                  fontFamily: 'IowanOldStyle',
                  fontFamilyFallback: const ['Charter', 'Georgia', 'serif'],
                  fontWeight: FontWeight.w800,
                  fontStyle: FontStyle.italic,
                  fontSize: dense ? 36 : 64,
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.85),
                  letterSpacing: -2,
                ),
              ),
            ),
          ),
          // Source caption — small, bottom-left.
          Positioned(
            left: dense ? 8 : 12,
            bottom: dense ? 6 : 10,
            child: Text(
              source.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: dense ? 8 : 9.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
