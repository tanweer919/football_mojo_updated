import 'package:flutter/material.dart';

import '../../../../core/share/share_card_frame.dart';
import '../../../world_cup/data/world_cup_models.dart';

class BracketShareCard extends StatelessWidget {
  const BracketShareCard({
    super.key,
    required this.groups,
    required this.picks,
    required this.championTeam,
    this.userHandle,
  });

  final List<WcGroup> groups;
  final Map<String, String> picks;
  final WcTeamRef? championTeam;
  final String? userHandle;

  WcTeamRef? _teamById(String id) {
    for (final g in groups) {
      for (final s in g.standings) {
        if (s.team.id == id) return s.team;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final pickedGroupRows = <_GroupPickRow>[];
    for (final g in groups) {
      final win = _teamById(picks['GROUP_${g.letter}_1'] ?? '');
      final run = _teamById(picks['GROUP_${g.letter}_2'] ?? '');
      if (win == null && run == null) continue;
      pickedGroupRows.add(_GroupPickRow(
          letter: g.letter, winner: win, runnerUp: run));
    }

    return ShareCardFrame(
      title: 'MY WORLD CUP BRACKET',
      subtitle: 'How it ends, in my book.',
      userHandle: userHandle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (championTeam != null) ...[
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0x33D9B65A), Color(0x11D9B65A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0x66D9B65A)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.emoji_events_rounded,
                      color: Color(0xFFEBD9A8), size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'MY CHAMPION',
                          style: TextStyle(
                            color: Color(0xFFEBD9A8),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          championTeam!.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          if (pickedGroupRows.isNotEmpty) ...[
            const Text(
              'GROUP STAGE',
              style: TextStyle(
                color: Color(0xFFB78A2E),
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 3.0,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 6,
                ),
                itemCount: pickedGroupRows.length,
                itemBuilder: (_, i) => _GroupRowView(row: pickedGroupRows[i]),
              ),
            ),
          ] else
            const Expanded(
              child: Center(
                child: Text(
                  'Pick groups & a champion to fill out your bracket.',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GroupPickRow {
  _GroupPickRow({required this.letter, this.winner, this.runnerUp});
  final String letter;
  final WcTeamRef? winner;
  final WcTeamRef? runnerUp;
}

class _GroupRowView extends StatelessWidget {
  const _GroupRowView({required this.row});
  final _GroupPickRow row;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1A14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x33D9B65A)),
      ),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFF2A2419),
              shape: BoxShape.circle,
            ),
            child: Text(
              row.letter,
              style: const TextStyle(
                color: Color(0xFFEBD9A8),
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  row.winner?.shortName ?? '—',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  row.runnerUp?.shortName ?? '—',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
