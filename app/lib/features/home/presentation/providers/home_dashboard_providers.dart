import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../news/data/models/news_article.dart';
import '../../../news/data/repositories/news_repository.dart';
import '../../../scores/data/models/match_dto.dart';
import '../../../scores/data/repositories/scores_repository.dart';

/// Bundled fixtures for the home dashboard:
///   - upcoming: all upcoming matches in the query window, sorted by kickoff
///   - recent: all finished matches in the query window, sorted by most recent
class HomeFixtures {
  const HomeFixtures({required this.upcoming, required this.recent, required this.next});
  final List<MatchDto> upcoming;
  final List<MatchDto> recent;
  final MatchDto? next;
}

final homeFixturesProvider = FutureProvider<HomeFixtures>((ref) async {
  final repo = ref.read(scoresRepositoryProvider);
  // Window: 3 days back → 21 days forward. The forward edge is wide
  // enough to capture WC2026 fixtures while they're still 1-3 weeks
  // out so the "Matches" strip can fall back to the next upcoming
  // game when nothing is live today. Day-level fixtures are cached
  // server-side so 25 parallel calls cost little.
  final now = DateTime.now();
  final days = <DateTime>[
    for (int i = -3; i <= 21; i++)
      DateTime(now.year, now.month, now.day + i),
  ];
  final results = await Future.wait(days.map((d) => repo.fetchFixtures(day: d)));
  // Two layers of dedupe:
  //   1. Same match id appearing in adjacent-day queries (UTC bucket
  //      bleed for late-night kickoffs).
  //   2. Same real-world fixture with DIFFERENT ids — the WC seed
  //      uses synthetic ids like `WC2026-GF-portugal-dr-congo`, while
  //      api-football inserts the same match again with a numeric
  //      id once the fixture publishes. We dedupe on the natural
  //      key (homeId|awayId|kickoff-hour) so the same Portugal vs
  //      DR Congo doesn't show twice. Prefer the row that has live
  //      data (status != SCHEDULED) when collapsing duplicates so
  //      the live row wins over the seed placeholder.
  final byKey = <String, MatchDto>{};
  String keyOf(MatchDto m) {
    final t = m.kickoffAt.toUtc();
    final hour = '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}T${t.hour.toString().padLeft(2, '0')}';
    return '${m.homeTeam.id}|${m.awayTeam.id}|$hour';
  }
  for (final m in results.expand((e) => e)) {
    final k = keyOf(m);
    final existing = byKey[k];
    if (existing == null) {
      byKey[k] = m;
    } else {
      // Prefer the row that's live/finished over a SCHEDULED twin.
      final existingIsScheduled = existing.status == MatchStatus.SCHEDULED;
      final candidateBetter = existingIsScheduled && m.status != MatchStatus.SCHEDULED;
      if (candidateBetter) byKey[k] = m;
    }
  }
  final all = byKey.values.toList();

  final upcoming = all
      .where((m) =>
          !m.isFinished &&
          m.kickoffAt.isAfter(now.subtract(const Duration(minutes: 5))))
      .toList()
    ..sort((a, b) => a.kickoffAt.compareTo(b.kickoffAt));

  final recent = all
      .where((m) => m.isFinished)
      .toList()
    ..sort((a, b) => b.kickoffAt.compareTo(a.kickoffAt));

  return HomeFixtures(
    upcoming: upcoming,
    recent: recent,
    next: upcoming.isEmpty ? null : upcoming.first,
  );
});

/// News filtered by team ID — used by the "Your teams" section to show
/// relevant stories for followed teams. Limited to 3 items for the home feed.
final teamNewsProvider = FutureProvider.family<List<NewsArticleDto>, String>(
  (ref, teamId) async {
    final repo = ref.read(newsRepositoryProvider);
    final page = await repo.list(teamId: teamId, limit: 3);
    return page.items;
  },
);
