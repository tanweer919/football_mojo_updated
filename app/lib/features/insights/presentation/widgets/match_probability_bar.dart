import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/app_colors.dart';
import '../../data/insights_repository.dart';

/// Compact win-probability strip for a match-list row — home% · bar · away%,
/// from api-football's statistical model (no bookmaker odds). Renders nothing
/// until the prediction loads or if the model has no read.
class MatchProbabilityBar extends ConsumerWidget {
  const MatchProbabilityBar({super.key, required this.fixtureId});
  final String fixtureId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(matchPreviewProvider(fixtureId)).valueOrNull;
    if (p == null) return const SizedBox.shrink();
    final h = p.homePercent, d = p.drawPercent, a = p.awayPercent;
    if (h + d + a <= 0) return const SizedBox.shrink();

    Widget seg(double v, Color c) => Expanded(
          flex: v.round().clamp(1, 1000),
          child: ColoredBox(color: c),
        );
    Widget pct(double v, Color c) => Text(
          '${v.round()}%',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: c,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        );

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          pct(h, AppColors.pitch),
          const SizedBox(width: 7),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: SizedBox(
                height: 5,
                child: Row(
                  children: [
                    seg(h, AppColors.pitch),
                    seg(d, AppColors.muted2),
                    seg(a, AppColors.info),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 7),
          pct(a, AppColors.info),
        ],
      ),
    );
  }
}
