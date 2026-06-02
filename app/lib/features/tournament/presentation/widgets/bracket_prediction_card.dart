import 'package:flutter/material.dart';

import '../../../../core/share/share_card_frame.dart';
import '../../../../core/widgets/premium_image.dart';
import '../../../world_cup/data/world_cup_models.dart';

/// The full predicted road to the trophy, resolved into one team list per
/// knockout round. Built by the bracket screen from the user's picks.
class BracketPrediction {
  const BracketPrediction({
    required this.groupWinners,
    required this.lastSixteen,
    required this.quarterFinalists,
    required this.semiFinalists,
    required this.finalists,
    required this.champion,
  });

  final List<WcTeamRef> groupWinners;     // 12 — GROUP_<L>_1
  final List<WcTeamRef> lastSixteen;      // 16 — R32 winners
  final List<WcTeamRef> quarterFinalists; // 8  — R16 winners
  final List<WcTeamRef> semiFinalists;    // 4  — QF winners
  final List<WcTeamRef> finalists;        // 2  — SF winners
  final WcTeamRef? champion;              // 1  — final winner

  bool get hasChampion => champion != null;
}

/// Single-graphic share card laying the whole prediction out group-stage
/// to final as a narrowing funnel of crests, ending on the champion.
/// Rendered off-screen to a PNG by ShareService for the share sheet.
class BracketPredictionCard extends StatelessWidget {
  const BracketPredictionCard({
    super.key,
    required this.prediction,
    this.userHandle,
  });

  final BracketPrediction prediction;
  final String? userHandle;

  @override
  Widget build(BuildContext context) {
    return ShareCardFrame(
      title: 'MY WORLD CUP 2026 PREDICTION',
      subtitle: 'My road to the trophy.',
      userHandle: userHandle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Champion hero — the headline of the whole graphic.
          if (prediction.champion != null) _ChampionBanner(team: prediction.champion!),
          const SizedBox(height: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _CrestRound(
                  label: 'GROUP WINNERS',
                  teams: prediction.groupWinners,
                  crestSize: 30,
                ),
                _CrestRound(
                  label: 'ROUND OF 16',
                  teams: prediction.lastSixteen,
                  crestSize: 30,
                ),
                _CrestRound(
                  label: 'QUARTER-FINALS',
                  teams: prediction.quarterFinalists,
                  crestSize: 38,
                ),
                _CrestRound(
                  label: 'SEMI-FINALS',
                  teams: prediction.semiFinalists,
                  crestSize: 44,
                  withNames: true,
                ),
                _CrestRound(
                  label: 'FINAL',
                  teams: prediction.finalists,
                  crestSize: 52,
                  withNames: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChampionBanner extends StatelessWidget {
  const _ChampionBanner({required this.team});
  final WcTeamRef team;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0x44D9B65A), Color(0x11D9B65A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x88D9B65A), width: 1.5),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: PremiumImage(url: team.crestUrl, fit: BoxFit.contain),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.emoji_events_rounded,
                        color: Color(0xFFEBD9A8), size: 16),
                    SizedBox(width: 6),
                    Text(
                      'MY CHAMPION',
                      style: TextStyle(
                        color: Color(0xFFEBD9A8),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.6,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  team.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
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

/// One round of the funnel — a gold mono label and a centred wrap of
/// crests (optionally with short-name captions for the late rounds).
class _CrestRound extends StatelessWidget {
  const _CrestRound({
    required this.label,
    required this.teams,
    required this.crestSize,
    this.withNames = false,
  });
  final String label;
  final List<WcTeamRef> teams;
  final double crestSize;
  final bool withNames;

  @override
  Widget build(BuildContext context) {
    if (teams.isEmpty) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFB78A2E),
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.6,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 8,
          children: [
            for (final t in teams)
              _Crest(team: t, size: crestSize, withName: withNames),
          ],
        ),
      ],
    );
  }
}

class _Crest extends StatelessWidget {
  const _Crest({required this.team, required this.size, required this.withName});
  final WcTeamRef team;
  final double size;
  final bool withName;
  @override
  Widget build(BuildContext context) {
    final crest = Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1A14),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: const Color(0x33D9B65A)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: PremiumImage(url: team.crestUrl, fit: BoxFit.contain),
      ),
    );
    if (!withName) return crest;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        crest,
        const SizedBox(height: 4),
        SizedBox(
          width: size + 18,
          child: Text(
            team.shortName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
