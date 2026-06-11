import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/match_dto.dart';
import '../../data/repositories/scores_repository.dart';

/// Live matches state. Hydrates from REST then folds in WebSocket deltas.
/// Demonstrates the canonical Riverpod 2.x AsyncNotifier pattern: REST for
/// the initial snapshot, stream for live deltas.
class LiveMatchesNotifier extends AsyncNotifier<List<MatchDto>> {
  StreamSubscription<MatchUpdate>? _sub;
  StreamSubscription<MatchUpdate>? _fixturesSub;

  @override
  Future<List<MatchDto>> build() async {
    final repo = ref.read(scoresRepositoryProvider);

    repo.subscribeFixtures();
    // We're in the `fixtures` room, which receives `fixtures.update` for EVERY
    // match — that's the stream to fold here. (`updates()` carries
    // `match.update`, which only reaches per-match rooms we never join from
    // home, so on its own the hero/rail never updated live.) Listen to both so
    // a finished match is dropped and scores tick wherever the event arrives.
    _fixturesSub = repo.fixturesUpdates().listen(_apply);
    _sub = repo.updates().listen(_apply);
    ref.onDispose(() {
      _sub?.cancel();
      _fixturesSub?.cancel();
    });

    return repo.fetchLive();
  }

  Future<void> refresh() async {
    // Refetch WITHOUT blanking the rail. Setting AsyncLoading here made the
    // home hero (which watches this) flip from the live match back to "next
    // upcoming" on every resync. Keep the current data on screen; only swap it
    // out on a successful fetch, and keep it on error rather than dropping to
    // empty.
    try {
      final fresh = await ref.read(scoresRepositoryProvider).fetchLive();
      state = AsyncData(fresh);
    } catch (_) {
      /* keep the existing live rail */
    }
  }

  void _apply(MatchUpdate u) {
    final current = state.valueOrNull ?? const <MatchDto>[];

    final idx = current.indexWhere((m) => m.id == u.id);
    if (idx == -1) {
      // Unknown match — only resync when it actually went LIVE, so finished /
      // scheduled chatter doesn't trigger a refetch storm (each of which used
      // to blank the rail). Cheap: the API is cached server-side for ~5s.
      if (u.status == MatchStatus.LIVE || u.status == MatchStatus.HALF_TIME) {
        refresh();
      }
      return;
    }

    final updated = current[idx].copyWith(
      status: u.status,
      minute: u.minute,
      minuteExtra: u.minuteExtra,
      homeScore: u.homeScore,
      awayScore: u.awayScore,
      homePenalties: u.homePenalties,
      awayPenalties: u.awayPenalties,
    );

    // If a match just finished, drop it from the live list.
    if (updated.isFinished) {
      state = AsyncData([...current]..removeAt(idx));
    } else {
      state = AsyncData([...current]..[idx] = updated);
    }
  }
}

final liveMatchesProvider =
    AsyncNotifierProvider<LiveMatchesNotifier, List<MatchDto>>(LiveMatchesNotifier.new);
