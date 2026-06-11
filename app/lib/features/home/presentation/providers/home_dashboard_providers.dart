import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/favourites/favourites_provider.dart';
import '../../../news/data/models/news_article.dart';
import '../../../news/data/repositories/news_repository.dart';
import '../../../scores/data/models/match_dto.dart';
import '../../../scores/data/repositories/scores_repository.dart';
import '../../../scores/presentation/providers/live_matches_provider.dart';

/// Bundled fixtures for the home dashboard:
///   - upcoming: all upcoming matches in the query window, sorted by kickoff
///   - recent: all finished matches in the query window, sorted by most recent
class HomeFixtures {
  const HomeFixtures({required this.upcoming, required this.recent, required this.next});
  final List<MatchDto> upcoming;
  final List<MatchDto> recent;
  final MatchDto? next;
}

/// What the home "match" zone shows: the hero match + the rail beneath it,
/// decided together so they never duplicate or disagree.
class HomeMatchFeed {
  const HomeMatchFeed({
    required this.hero,
    required this.railTitle,
    required this.railItems,
  });
  final MatchDto? hero;
  final String railTitle;
  final List<MatchDto> railItems;
}

/// Hero priority: a followed team's live match → the earliest-started live
/// match → (nothing live) the next fixture if it kicks off within 30 min →
/// otherwise the latest result (shown until 30 min before the next kickoff).
/// Rail: ≥2 live → "Live now" (the live matches not in the hero); otherwise
/// "Upcoming matches" (the next 3 scheduled fixtures, hero excluded).
final homeMatchFeedProvider = Provider<HomeMatchFeed>((ref) {
  final live = ref.watch(liveMatchesProvider).valueOrNull ?? const <MatchDto>[];
  final fixtures = ref.watch(homeFixturesProvider).valueOrNull;
  final followed =
      ref.watch(favouriteTeamsProvider).valueOrNull ?? const <String>{};
  final now = DateTime.now();

  final liveSorted = [...live]
    ..sort((a, b) => a.kickoffAt.compareTo(b.kickoffAt));
  // `upcoming` keeps live matches in-bundle, so filter to genuinely scheduled
  // ones for the rail + the hero result logic.
  final scheduled = [
    for (final m in (fixtures?.upcoming ?? const <MatchDto>[]))
      if (!m.isLive) m,
  ]..sort((a, b) => a.kickoffAt.compareTo(b.kickoffAt));
  final recent = fixtures?.recent ?? const <MatchDto>[];

  MatchDto? hero;
  if (liveSorted.isNotEmpty) {
    hero = liveSorted.firstWhere(
      (m) =>
          followed.contains(m.homeTeam.id) || followed.contains(m.awayTeam.id),
      orElse: () => liveSorted.first,
    );
  } else {
    final next = scheduled.isNotEmpty ? scheduled.first : null;
    final startsSoon =
        next != null && next.kickoffAt.difference(now).inMinutes <= 30;
    hero = startsSoon ? next : (recent.isNotEmpty ? recent.first : next);
  }

  final String railTitle;
  final List<MatchDto> railItems;
  if (liveSorted.length >= 2) {
    railTitle = 'Live now';
    railItems = [for (final m in liveSorted) if (m.id != hero?.id) m];
  } else {
    railTitle = 'Upcoming matches';
    railItems =
        [for (final m in scheduled) if (m.id != hero?.id) m].take(3).toList();
  }

  return HomeMatchFeed(hero: hero, railTitle: railTitle, railItems: railItems);
});

final homeFixturesProvider = FutureProvider<HomeFixtures>((ref) async {
  final repo = ref.read(scoresRepositoryProvider);
  // Window: 2 days back → 14 days forward (17 day-queries, down from 25)
  // to cut network work on app load. Still wide enough to surface recent
  // results + the next upcoming match (incl. the WC opener, ~a week out)
  // for the home "Match" hero and the followed-team digest. Each day is
  // cached server-side, but fewer client round-trips = faster, lighter load.
  final now = DateTime.now();
  final days = <DateTime>[
    for (int i = -2; i <= 14; i++)
      DateTime(now.year, now.month, now.day + i),
  ];
  final results = await Future.wait(days.map((d) => repo.fetchFixtures(day: d)));
  // The same real-world fixture can appear as TWO different DB rows:
  // the WC seed inserts a match with a synthetic id (and possibly its
  // own team-id codes + a placeholder kickoff time), while the
  // api-football poller inserts the same fixture with a numeric id,
  // its own team ids, and the official time. Dedup-by-id misses these.
  //
  // We collapse on a source-agnostic natural key: the two team NAMES
  // (normalised + order-independent) plus the UTC calendar date. Two
  // teams never play each other twice on one calendar day, so this is
  // safe and survives both id mismatches and within-day time drift.
  // When two rows collapse we keep the most "real" one — a live /
  // finished row beats a SCHEDULED placeholder.
  String norm(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  String keyOf(MatchDto m) {
    final t = m.kickoffAt.toUtc();
    final date = '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
    final pair = [norm(m.homeTeam.name), norm(m.awayTeam.name)]..sort();
    return '${pair[0]}|${pair[1]}|$date';
  }
  int rank(MatchDto m) => m.status == MatchStatus.SCHEDULED ? 0 : 1;
  final byKey = <String, MatchDto>{};
  for (final m in results.expand((e) => e)) {
    final k = keyOf(m);
    final existing = byKey[k];
    if (existing == null || rank(m) > rank(existing)) {
      byKey[k] = m;
    }
  }
  final all = byKey.values.toList();

  final upcoming = all
      .where((m) =>
          // A live match must stay in the list no matter how long ago it
          // kicked off — the old `kickoffAt > now-5min` guard dropped any
          // fixture more than 5 minutes into play, so it vanished from both
          // this bundle and the World Cup schedule mid-match.
          m.isLive ||
          (!m.isFinished &&
              m.kickoffAt.isAfter(now.subtract(const Duration(minutes: 5)))))
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
