import 'package:flutter/material.dart';

import '../../../../core/widgets/premium_image.dart';
import '../../../world_cup/data/world_cup_models.dart';

// ─── Brand palette (kept local so the off-screen render is self-contained
//     and never depends on inherited theme) ─────────────────────────────
const _gold = Color(0xFFD9B65A);
const _goldSoft = Color(0xFFEBD9A8);
const _goldDeep = Color(0xFFB78A2E);
const _ink = Color(0xFF0C0A07);
const _card = Color(0xFF1E1A14);
const _hairline = Color(0x33D9B65A);
const _qualify = Color(0xFF5BBF8A);

// ─── Data ─────────────────────────────────────────────────────────────

class GroupPrediction {
  const GroupPrediction({required this.letter, required this.ordered});
  final String letter;
  /// Predicted finishing order 1..4 (may contain fewer if unresolved).
  final List<WcTeamRef> ordered;
}

class TiePrediction {
  const TiePrediction({
    required this.number,
    required this.left,
    required this.right,
    required this.winnerId,
  });
  final int number;
  final WcTeamRef? left;
  final WcTeamRef? right;
  final String? winnerId;

  bool isWinner(WcTeamRef? t) => t != null && t.id == winnerId;
}

/// The entire prediction, resolved by the bracket screen, ready to lay out
/// as one shareable poster: all 12 groups (1–4), the 8 best-thirds, and
/// every knockout head-to-head through to the final.
class FullBracketPrediction {
  const FullBracketPrediction({
    required this.groups,
    required this.bestThirds,
    required this.r32,
    required this.r16,
    required this.qf,
    required this.sf,
    required this.bronzeTie,
    required this.finalTie,
    required this.champion,
  });
  final List<GroupPrediction> groups;
  final List<WcTeamRef> bestThirds;
  final List<TiePrediction> r32; // 16
  final List<TiePrediction> r16; // 8
  final List<TiePrediction> qf;  // 4
  final List<TiePrediction> sf;  // 2
  final TiePrediction? bronzeTie;
  final TiePrediction? finalTie;
  final WcTeamRef? champion;
}

// ─── Poster ─────────────────────────────────────────────────────────────

/// Full-bracket prediction poster. Rendered at a FIXED WIDTH with intrinsic
/// height (see ShareService.renderTallArtifactToFile) so the whole layout —
/// groups → thirds → knockouts → champion — fits in a single tall image
/// suitable for Twitter / WhatsApp.
class BracketPredictionCard extends StatelessWidget {
  const BracketPredictionCard({
    super.key,
    required this.prediction,
    this.userHandle,
  });

  final FullBracketPrediction prediction;
  final String? userHandle;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF181410), _ink],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(28, 30, 28, 26),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(),
          const SizedBox(height: 22),
          const Text(
            'MY WORLD CUP 2026 PREDICTION',
            style: TextStyle(
              color: _goldSoft,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Every group, every knockout, all the way to the trophy.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              height: 1.1,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 22),

          if (prediction.champion != null) ...[
            _ChampionBanner(team: prediction.champion!),
            const SizedBox(height: 24),
          ],

          _sectionLabel('GROUP STAGE'),
          const SizedBox(height: 12),
          _GroupsGrid(groups: prediction.groups),

          if (prediction.bestThirds.isNotEmpty) ...[
            const SizedBox(height: 24),
            _sectionLabel('BEST THIRD-PLACE QUALIFIERS'),
            const SizedBox(height: 12),
            _ThirdsWrap(teams: prediction.bestThirds),
          ],

          if (prediction.r32.isNotEmpty) ...[
            const SizedBox(height: 26),
            _sectionLabel('ROUND OF 32'),
            const SizedBox(height: 12),
            _TieColumns(ties: prediction.r32, perRow: 2),
          ],
          if (prediction.r16.isNotEmpty) ...[
            const SizedBox(height: 22),
            _sectionLabel('ROUND OF 16'),
            const SizedBox(height: 12),
            _TieColumns(ties: prediction.r16, perRow: 2),
          ],
          if (prediction.qf.isNotEmpty) ...[
            const SizedBox(height: 22),
            _sectionLabel('QUARTER-FINALS'),
            const SizedBox(height: 12),
            _TieColumns(ties: prediction.qf, perRow: 2),
          ],
          if (prediction.sf.isNotEmpty) ...[
            const SizedBox(height: 22),
            _sectionLabel('SEMI-FINALS'),
            const SizedBox(height: 12),
            _TieColumns(ties: prediction.sf, perRow: 2),
          ],
          if (prediction.bronzeTie != null) ...[
            const SizedBox(height: 22),
            _sectionLabel('THIRD-PLACE PLAY-OFF'),
            const SizedBox(height: 12),
            _TieCard(tie: prediction.bronzeTie!),
          ],
          if (prediction.finalTie != null) ...[
            const SizedBox(height: 22),
            _sectionLabel('FINAL'),
            const SizedBox(height: 12),
            _TieCard(tie: prediction.finalTie!, large: true),
          ],

          const SizedBox(height: 26),
          _footer(),
        ],
      ),
    );
  }

  static Widget _sectionLabel(String text) => Row(
        children: [
          Container(width: 3, height: 14, color: _gold),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              color: _goldDeep,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.6,
            ),
          ),
        ],
      );

  static Widget _header() => Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Color(0xFFF1E4B6), Color(0xFFE5C26B), Color(0xFF8E6422)],
                stops: [0.2, 0.6, 1.0],
                center: Alignment(-0.3, -0.4),
              ),
            ),
          ),
          const SizedBox(width: 9),
          ShaderMask(
            shaderCallback: (rect) => const LinearGradient(
              colors: [_goldSoft, _goldDeep],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ).createShader(rect),
            child: const Text(
              'PITCH',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                color: Colors.white,
              ),
            ),
          ),
          const Spacer(),
          const Text(
            'FootballMojo',
            style: TextStyle(
              color: _goldDeep,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
            ),
          ),
        ],
      );

  Widget _footer() => Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _hairline),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Make your prediction at',
                    style: TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'footballmojo.in',
                    style: const TextStyle(
                      color: _goldSoft,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            if (userHandle != null)
              Text(
                userHandle!.startsWith('@') ? userHandle! : '@$userHandle',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
      );
}

class _ChampionBanner extends StatelessWidget {
  const _ChampionBanner({required this.team});
  final WcTeamRef team;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
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
            width: 60,
            height: 60,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: PremiumImage(url: team.crestUrl, fit: BoxFit.contain, fadeInDuration: Duration.zero),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.emoji_events_rounded, color: _goldSoft, size: 18),
                    SizedBox(width: 6),
                    Text(
                      'MY CHAMPION',
                      style: TextStyle(
                        color: _goldSoft,
                        fontSize: 12,
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
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
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

// ─── Groups grid (3 columns × 4 rows of group cards) ────────────────────

class _GroupsGrid extends StatelessWidget {
  const _GroupsGrid({required this.groups});
  final List<GroupPrediction> groups;

  @override
  Widget build(BuildContext context) {
    const cols = 3;
    final rows = <Widget>[];
    for (var i = 0; i < groups.length; i += cols) {
      final slice = groups.sublist(i, (i + cols).clamp(0, groups.length));
      rows.add(Padding(
        padding: EdgeInsets.only(bottom: i + cols < groups.length ? 10 : 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var c = 0; c < cols; c++) ...[
              if (c > 0) const SizedBox(width: 10),
              Expanded(
                child: c < slice.length
                    ? _GroupCard(group: slice[c])
                    : const SizedBox.shrink(),
              ),
            ],
          ],
        ),
      ));
    }
    return Column(mainAxisSize: MainAxisSize.min, children: rows);
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group});
  final GroupPrediction group;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 7, 8, 8),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'GROUP ${group.letter}',
            style: const TextStyle(
              color: _goldSoft,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          for (var i = 0; i < group.ordered.length; i++)
            _GroupTeamRow(pos: i + 1, team: group.ordered[i]),
        ],
      ),
    );
  }
}

class _GroupTeamRow extends StatelessWidget {
  const _GroupTeamRow({required this.pos, required this.team});
  final int pos;
  final WcTeamRef team;
  @override
  Widget build(BuildContext context) {
    // 1–2 qualify (gold), 3 best-third candidate (amber), 4 out (muted).
    final Color tone = pos <= 2
        ? _qualify
        : pos == 3
            ? _goldDeep
            : Colors.white38;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        children: [
          SizedBox(
            width: 12,
            child: Text(
              '$pos',
              style: TextStyle(
                color: tone,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 16,
            height: 16,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: PremiumImage(url: team.crestUrl, fit: BoxFit.contain, fadeInDuration: Duration.zero),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              team.shortName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: pos <= 2 ? Colors.white : Colors.white54,
                fontSize: 11,
                fontWeight: pos <= 2 ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Best thirds ────────────────────────────────────────────────────────

class _ThirdsWrap extends StatelessWidget {
  const _ThirdsWrap({required this.teams});
  final List<WcTeamRef> teams;
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final t in teams)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _hairline),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: PremiumImage(url: t.crestUrl, fit: BoxFit.contain, fadeInDuration: Duration.zero),
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  t.shortName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ─── Knockout ties ──────────────────────────────────────────────────────

class _TieColumns extends StatelessWidget {
  const _TieColumns({required this.ties, required this.perRow});
  final List<TiePrediction> ties;
  final int perRow;
  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < ties.length; i += perRow) {
      final slice = ties.sublist(i, (i + perRow).clamp(0, ties.length));
      rows.add(Padding(
        padding: EdgeInsets.only(bottom: i + perRow < ties.length ? 8 : 0),
        // IntrinsicHeight bounds the row's cross axis to its tallest child
        // so CrossAxisAlignment.stretch is valid even when the whole poster
        // is laid out with an unbounded (intrinsic) height for capture.
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var c = 0; c < perRow; c++) ...[
                if (c > 0) const SizedBox(width: 8),
                Expanded(
                  child: c < slice.length
                      ? _TieCard(tie: slice[c])
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ),
      ));
    }
    return Column(mainAxisSize: MainAxisSize.min, children: rows);
  }
}

class _TieCard extends StatelessWidget {
  const _TieCard({required this.tie, this.large = false});
  final TiePrediction tie;
  final bool large;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: large ? 12 : 8),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _hairline),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TieTeamLine(team: tie.left, winner: tie.isWinner(tie.left), large: large),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Text(
              'v',
              style: TextStyle(
                color: Colors.white24,
                fontSize: large ? 12 : 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          _TieTeamLine(team: tie.right, winner: tie.isWinner(tie.right), large: large),
        ],
      ),
    );
  }
}

class _TieTeamLine extends StatelessWidget {
  const _TieTeamLine({
    required this.team,
    required this.winner,
    required this.large,
  });
  final WcTeamRef? team;
  final bool winner;
  final bool large;
  @override
  Widget build(BuildContext context) {
    final crestSize = large ? 26.0 : 20.0;
    if (team == null) {
      return Row(
        children: [
          SizedBox(width: crestSize, height: crestSize),
          const SizedBox(width: 8),
          const Text('TBD',
              style: TextStyle(color: Colors.white30, fontSize: 12)),
        ],
      );
    }
    return Row(
      children: [
        SizedBox(
          width: crestSize,
          height: crestSize,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: PremiumImage(url: team!.crestUrl, fit: BoxFit.contain, fadeInDuration: Duration.zero),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            large ? team!.name : team!.shortName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: winner ? _goldSoft : Colors.white60,
              fontSize: large ? 16 : 12.5,
              fontWeight: winner ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ),
        if (winner) ...[
          const SizedBox(width: 4),
          Icon(Icons.check_circle, color: _gold, size: large ? 18 : 13),
        ],
      ],
    );
  }
}
