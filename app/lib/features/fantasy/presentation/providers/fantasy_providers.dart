import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/fantasy_models.dart';
import '../../data/models/league_models.dart';
import '../../data/repositories/fantasy_repository.dart';

/// Default Global Cup slug — wired to the WC 2026 tournament seed.
const kGlobalCupSlug = 'wc2026-global-cup';

final tournamentProvider = FutureProvider.family<FantasyTournamentDto, String>((ref, slug) {
  return ref.read(fantasyRepositoryProvider).getTournament(slug);
});

final currentGameweekProvider =
    FutureProvider.family<FantasyGameweekDto?, String>((ref, slug) {
  return ref.read(fantasyRepositoryProvider).currentGameweek(slug);
});

final selectablePlayersProvider =
    FutureProvider.family<List<PlayerValuationDto>, String>((ref, slug) {
  return ref.read(fantasyRepositoryProvider).selectablePlayers(slug);
});

final myLineupProvider = FutureProvider.family<FantasyLineupDto?, ({String slug, String gameweekId})>((ref, args) {
  return ref.read(fantasyRepositoryProvider).myLineup(args.slug, args.gameweekId);
});

/// Owned-card fantasy boosts (playerId → [CardBoost]) for the signed-in user.
/// Drives the "+X% · RARITY" badge in the player picker + lineup builder so a
/// user can see which of their cards lift a player's projected points. Empty
/// for anonymous users or those with no cards.
final ownedCardBoostsProvider = FutureProvider<Map<String, CardBoost>>((ref) {
  return ref.read(fantasyRepositoryProvider).ownedCardMultipliers();
});

final leaderboardProvider = FutureProvider.family<List<LeaderboardEntry>, ({String slug, String gameweekId})>((ref, args) {
  return ref.read(fantasyRepositoryProvider).leaderboard(args.slug, args.gameweekId);
});

/// Mutable draft lineup state. Lives only while the lineup-builder screen is open.
class DraftLineupState {
  const DraftLineupState({this.picks = const {}, this.captainId});
  final Map<PlayerPosition, List<String>> picks; // playerIds per slot
  final String? captainId;

  DraftLineupState copyWith({Map<PlayerPosition, List<String>>? picks, String? captainId, bool clearCaptain = false}) =>
      DraftLineupState(
        picks: picks ?? this.picks,
        captainId: clearCaptain ? null : (captainId ?? this.captainId),
      );

  Iterable<String> get allPlayerIds => picks.values.expand((e) => e);

  int get filled => picks.values.fold<int>(0, (s, l) => s + l.length);
}

class DraftLineupNotifier extends Notifier<DraftLineupState> {
  @override
  DraftLineupState build() => const DraftLineupState(picks: {
        PlayerPosition.GK: <String>[],
        PlayerPosition.DEF: <String>[],
        PlayerPosition.MID: <String>[],
        PlayerPosition.FWD: <String>[],
      });

  void hydrate(FantasyLineupDto lineup) {
    final by = <PlayerPosition, List<String>>{
      PlayerPosition.GK: [], PlayerPosition.DEF: [], PlayerPosition.MID: [], PlayerPosition.FWD: [],
    };
    for (final p in lineup.picks) by[p.position]!.add(p.playerId);
    state = DraftLineupState(picks: by, captainId: lineup.captainId);
  }

  void setSlot(PlayerPosition pos, int slotIndex, String? playerId) {
    final next = {for (final e in state.picks.entries) e.key: List<String>.from(e.value)};
    final list = next[pos]!;
    while (list.length <= slotIndex) list.add('');
    if (playerId == null) {
      if (slotIndex < list.length) list[slotIndex] = '';
    } else {
      list[slotIndex] = playerId;
    }
    // Compact away empty strings to keep size accurate.
    next[pos] = list.where((s) => s.isNotEmpty).toList();
    final clearCaptain = state.captainId != null && !next.values.expand((x) => x).contains(state.captainId);
    state = state.copyWith(picks: next, clearCaptain: clearCaptain);
  }

  void setCaptain(String playerId) => state = state.copyWith(captainId: playerId);

  void clear() => state = build();
}

final draftLineupProvider = NotifierProvider<DraftLineupNotifier, DraftLineupState>(DraftLineupNotifier.new);

// Private leagues
final myLeaguesProvider =
    FutureProvider.family<List<FantasyLeagueSummary>, String?>((ref, tournamentId) {
  return ref.read(fantasyRepositoryProvider).myLeagues(tournamentId: tournamentId);
});

final leagueLeaderboardProvider = FutureProvider.family<List<LeaderboardEntry>,
    ({String leagueId, String gameweekId})>((ref, args) {
  return ref.read(fantasyRepositoryProvider).leagueLeaderboard(
        leagueId: args.leagueId,
        gameweekId: args.gameweekId,
      );
});
