import 'package:flutter/material.dart';

import '../../../../core/share/share_card_frame.dart';
import '../../data/models/fantasy_models.dart';

/// Share artifact for a fantasy lineup. Five player chips in a stacked
/// pitch layout (GK / DEF / MID / UTL / FWD), captain badge, total points.
class LineupShareCard extends StatelessWidget {
  const LineupShareCard({
    super.key,
    required this.lineup,
    required this.playerNamesById,
    required this.playerTeamsById,
    required this.tournamentName,
    required this.gameweekName,
    this.userHandle,
  });

  final FantasyLineupDto lineup;
  final Map<String, String> playerNamesById;
  final Map<String, String?> playerTeamsById;
  final String tournamentName;
  final String gameweekName;
  final String? userHandle;

  @override
  Widget build(BuildContext context) {
    final byPos = <PlayerPosition, List<LineupPick>>{};
    for (final p in lineup.picks) {
      byPos.putIfAbsent(p.position, () => []).add(p);
    }
    final gk = byPos[PlayerPosition.GK]?.firstOrNull;
    final def = byPos[PlayerPosition.DEF]?.firstOrNull;
    final mid = byPos[PlayerPosition.MID]?.firstOrNull;
    final fwd = byPos[PlayerPosition.FWD]?.firstOrNull;
    // The 5th pick (UTL) is whichever outfield duplicate exists.
    final utl = lineup.picks
        .where((p) =>
            p.position != PlayerPosition.GK &&
            p.playerId != def?.playerId &&
            p.playerId != mid?.playerId &&
            p.playerId != fwd?.playerId)
        .firstOrNull;

    return ShareCardFrame(
      title: tournamentName.toUpperCase(),
      subtitle: gameweekName,
      userHandle: userHandle,
      child: Column(
        children: [
          // Total points pill at the top of the pitch area.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0x33D9B65A), Color(0x11D9B65A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: const Color(0x66D9B65A)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'TOTAL',
                  style: TextStyle(
                    color: Color(0xFFB78A2E),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  lineup.totalPoints.toStringAsFixed(1),
                  style: const TextStyle(
                    color: Color(0xFFEBD9A8),
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 4),
                const Text(
                  'pts',
                  style: TextStyle(
                    color: Color(0xFFB78A2E),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF14281C), Color(0xFF0A1810)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0x33D9B65A)),
              ),
              padding: const EdgeInsets.all(14),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // FWD row sits at the top — final-third of the pitch in
                  // the rendered orientation (we keep GK at the bottom so
                  // the artwork reads as "attacking up").
                  _Row(
                    picks: [fwd, utl],
                    captainId: lineup.captainId,
                    namesById: playerNamesById,
                    teamsById: playerTeamsById,
                  ),
                  _Row(
                    picks: [mid],
                    captainId: lineup.captainId,
                    namesById: playerNamesById,
                    teamsById: playerTeamsById,
                  ),
                  _Row(
                    picks: [def],
                    captainId: lineup.captainId,
                    namesById: playerNamesById,
                    teamsById: playerTeamsById,
                  ),
                  _Row(
                    picks: [gk],
                    captainId: lineup.captainId,
                    namesById: playerNamesById,
                    teamsById: playerTeamsById,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.picks,
    required this.captainId,
    required this.namesById,
    required this.teamsById,
  });
  final List<LineupPick?> picks;
  final String captainId;
  final Map<String, String> namesById;
  final Map<String, String?> teamsById;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (final p in picks)
          if (p != null)
            _Chip(
              name: namesById[p.playerId] ?? 'Player',
              team: teamsById[p.playerId],
              position: p.position.name,
              isCaptain: p.playerId == captainId,
            ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.name,
    required this.team,
    required this.position,
    required this.isCaptain,
  });
  final String name;
  final String? team;
  final String position;
  final bool isCaptain;

  @override
  Widget build(BuildContext context) {
    final lastName = name.contains(' ') ? name.split(' ').last : name;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1A14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCaptain ? const Color(0xFFEBD9A8) : const Color(0x33D9B65A),
          width: isCaptain ? 2 : 1,
        ),
        boxShadow: isCaptain
            ? [
                BoxShadow(
                  color: const Color(0xFFEBD9A8).withValues(alpha: 0.30),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  position,
                  style: const TextStyle(
                    color: Color(0xFFB78A2E),
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              if (isCaptain) ...[
                const SizedBox(width: 4),
                Container(
                  width: 14,
                  height: 14,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEBD9A8),
                    shape: BoxShape.circle,
                  ),
                  child: const Text(
                    'C',
                    style: TextStyle(
                      color: Color(0xFF0C0A07),
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            lastName.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (team != null)
            Text(
              team!,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}
