import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/app_colors.dart';
import '../../core/router/route_paths.dart';
import '../scores/data/models/match_dto.dart';
import 'highlight_player_screen.dart';

/// Short match label for the player top bar, e.g. "Canada 1-1 Bosnia".
String highlightTitle(MatchDto m) {
  final h = m.homeTeam.shortName ?? m.homeTeam.name;
  final a = m.awayTeam.shortName ?? m.awayTeam.name;
  return '$h ${m.homeScore}-${m.awayScore} $a';
}

/// Open the in-app YouTube player for a finished match's highlight.
void openHighlight(BuildContext context, MatchDto m) {
  final url = m.highlightUrl;
  if (url == null || url.isEmpty) return;
  context.push(
    RoutePaths.highlightPlayer,
    extra: HighlightArgs(url: url, title: highlightTitle(m)),
  );
}

/// Compact "Highlights" pill with a play glyph — the standard affordance shown
/// on finished matches across the home hero, match cards and match detail.
class HighlightChip extends StatelessWidget {
  const HighlightChip({super.key, required this.match, this.dense = false});
  final MatchDto match;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => openHighlight(context, match),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 10, vertical: dense ? 4 : 5),
        decoration: BoxDecoration(
          color: AppColors.live.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: AppColors.live.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.play_circle_fill, size: dense ? 12 : 14, color: AppColors.live),
            SizedBox(width: dense ? 4 : 5),
            Text(
              'Highlights',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: dense ? 10 : 11,
                fontWeight: FontWeight.w800,
                color: AppColors.live,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
