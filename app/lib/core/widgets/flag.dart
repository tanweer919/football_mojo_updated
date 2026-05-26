import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Country flag pip — fetches the SVG asset from api-football's media bucket.
///
/// URL format (per openapi.yaml):
///   https://media.api-sports.io/flags/{code}.svg
///
/// Codes are ISO-3166-1 alpha-2 lowercase (e.g. `gb`, `fr`, `ar`, `us`).
/// Some countries have variants like `gb-eng`, `gb-sct` for the Home Nations.
class Flag extends StatelessWidget {
  const Flag({super.key, required this.code, this.width = 22, this.height = 16});
  final String code;
  final double width;
  final double height;

  static String urlFor(String code) =>
      'https://media.api-sports.io/flags/${code.toLowerCase()}.svg';

  @override
  Widget build(BuildContext context) {
    final url = urlFor(code);
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            SvgPicture.network(
              url,
              fit: BoxFit.cover,
              placeholderBuilder: (_) => Container(
                color: const Color(0xFF36322F),
              ),
            ),
            // 8% white inset hairline (matches the spec's box-shadow inset).
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 0.5),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
