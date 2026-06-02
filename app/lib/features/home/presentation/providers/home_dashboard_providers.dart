import 'package:flutter_riverpod/flutter_riverpod.dart';

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
