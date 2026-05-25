import 'package:flutter/material.dart';

import '../design/app_gradients.dart';
import '../design/app_spacing.dart';
import '../design/rarity_theme.dart';
import '../../features/album/data/models/card_models.dart';

/// `.rarity` from `components.css`. Mono uppercase 9px label, per-tier
/// background. Iconic animates the gradient sweep.
class RarityChip extends StatefulWidget {
  const RarityChip({super.key, required this.rarity, this.label});
  final CardRarity rarity;

  /// Override label — defaults to the tier's name (e.g. "Epic").
  final String? label;

  @override
  State<RarityChip> createState() => _RarityChipState();
}

class _RarityChipState extends State<RarityChip>
    with SingleTickerProviderStateMixin {
  AnimationController? _c;

  @override
  void initState() {
    super.initState();
    final theme = RarityTheme.of(widget.rarity);
    if (theme.iconic) {
      _c = AnimationController(vsync: this, duration: const Duration(seconds: 3))
        ..repeat();
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = RarityTheme.of(widget.rarity);
    final label = (widget.label ?? theme.label).toUpperCase();

    final textWidget = Text(
      label,
      style: TextStyle(
        fontFamily: 'JetBrainsMono',
        fontFamilyFallback: const ['SF Mono', 'Menlo', 'Roboto Mono', 'monospace'],
        fontSize: 9,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.6,
        color: theme.chipFg,
        height: 1.0,
      ),
    );

    final padding = const EdgeInsets.symmetric(horizontal: 7, vertical: 3);
    final radius = BorderRadius.circular(AppRadii.r1);

    BoxDecoration deco;
    if (theme.iconic) {
      // Animated iconic gradient — built in builder.
      return AnimatedBuilder(
        animation: _c!,
        builder: (_, __) {
          final shift = _c!.value;
          return Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: theme.chipBorder, width: 1),
              gradient: LinearGradient(
                colors: const [
                  Color(0xFF4DBADC),
                  Color(0xFFD656B5),
                  Color(0xFFE1C26F),
                  Color(0xFF4DBADC),
                ],
                stops: const [0, 0.5, 0.75, 1.0],
                begin: Alignment(-1 + shift * 2, 0),
                end:   Alignment( 1 + shift * 2, 0),
              ),
            ),
            child: textWidget,
          );
        },
      );
    } else if (widget.rarity == CardRarity.LEGENDARY) {
      deco = BoxDecoration(
        borderRadius: radius,
        gradient: AppGradients.buttonGold,
        border: Border.all(color: theme.chipBorder, width: 1),
      );
    } else {
      deco = BoxDecoration(
        color: theme.chipBg,
        borderRadius: radius,
        border: Border.all(color: theme.chipBorder, width: 1),
      );
    }

    return Container(padding: padding, decoration: deco, child: textWidget);
  }
}
