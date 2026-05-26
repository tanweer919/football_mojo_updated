import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/match_dto.dart';
import '../../data/repositories/scores_repository.dart';

/// Live matches state. Hydrates from REST then folds in WebSocket deltas.
/// Demonstrates the canonical Riverpod 2.x AsyncNotifier pattern: REST for
/// the initial snapshot, stream for live deltas.
class LiveMatchesNotifier extends AsyncNotifier<List<MatchDto>> {
  StreamSubscription<MatchUpdate>? _sub;

  @override
  Future<List<MatchDto>> build() async {
    final repo = ref.read(scoresRepositoryProvider);

    repo.subscribeFixtures();
    _sub = repo.updates().listen(_apply);
    ref.onDispose(() => _sub?.cancel());

    return repo.fetchLive();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => ref.read(scoresRepositoryProvider).fetchLive());
  }

  void _apply(MatchUpdate u) {
    final current = state.valueOrNull;
    if (current == null) return;

    final idx = current.indexWhere((m) => m.id == u.id);
    if (idx == -1) {
      // Match wasn't in the live set — likely transitioned to LIVE just now.
      // Trigger a refetch; cheap because the API is cached server-side for 5s.
      refresh();
      return;
    }

    final updated = current[idx].copyWith(
      status: u.status,
      minute: u.minute,
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
