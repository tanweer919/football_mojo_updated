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
  // Pull a wider window: 7 days back + 7 days forward so the home page
  // always has rich content regardless of match scheduling gaps.
  final now = DateTime.now();
  final days = <DateTime>[
    for (int i = -7; i <= 7; i++)
      DateTime(now.year, now.month, now.day + i),
  ];
  final results = await Future.wait(days.map((d) => repo.fetchFixtures(day: d)));
  final all = results.expand((e) => e).toList();

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
