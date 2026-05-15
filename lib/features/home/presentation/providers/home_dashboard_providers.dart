import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../scores/data/models/match_dto.dart';
import '../../../scores/data/repositories/scores_repository.dart';

/// Bundled fixtures for the home dashboard:
///   - upcoming: next 7 days, sorted by kickoff
///   - recent: finished within the last 48h, sorted by most recent first
class HomeFixtures {
  const HomeFixtures({required this.upcoming, required this.recent, required this.next});
  final List<MatchDto> upcoming;
  final List<MatchDto> recent;
  final MatchDto? next;
}

final homeFixturesProvider = FutureProvider<HomeFixtures>((ref) async {
  final repo = ref.read(scoresRepositoryProvider);
  // Pull a window: yesterday + today + tomorrow + day-after.
  final now = DateTime.now();
  final days = <DateTime>[
    DateTime(now.year, now.month, now.day - 1),
    DateTime(now.year, now.month, now.day),
    DateTime(now.year, now.month, now.day + 1),
    DateTime(now.year, now.month, now.day + 2),
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
      .where((m) =>
          m.isFinished &&
          m.kickoffAt.isAfter(now.subtract(const Duration(hours: 48))))
      .toList()
    ..sort((a, b) => b.kickoffAt.compareTo(a.kickoffAt));

  return HomeFixtures(
    upcoming: upcoming,
    recent: recent,
    next: upcoming.isEmpty ? null : upcoming.first,
  );
});
