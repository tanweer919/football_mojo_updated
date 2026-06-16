import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/design/app_colors.dart';
import '../scores/data/models/match_dto.dart';
import 'youtube_embed.dart';

/// Short match label, e.g. "Canada 1-1 Bosnia".
String highlightTitle(MatchDto m) {
  final h = m.homeTeam.shortName ?? m.homeTeam.name;
  final a = m.awayTeam.shortName ?? m.awayTeam.name;
  return '$h ${m.homeScore}-${m.awayScore} $a';
}

/// Open a finished match's highlight in the YouTube app (falling back to the
/// browser). In-app WebView embedding proved unreliable for these clips —
/// YouTube blocks WebView user-agents and many clips disable embedding — so we
/// hand off to YouTube directly, which always works. (The in-app player screen
/// is kept behind RoutePaths.highlightPlayer if we ever revisit inline play.)
Future<void> openHighlight(BuildContext context, MatchDto m) async {
  final raw = m.highlightUrl;
  if (raw == null || raw.isEmpty) return;
  final id = youtubeIdFrom(raw);
  final uri = Uri.parse(id != null ? 'https://www.youtube.com/watch?v=$id' : raw);
  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!opened) {
    final viaBrowser = await launchUrl(uri, mode: LaunchMode.platformDefault);
    if (!viaBrowser && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn’t open the highlight')),
      );
    }
  }
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
