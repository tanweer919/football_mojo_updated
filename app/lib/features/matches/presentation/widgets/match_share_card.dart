import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/deeplink/chottu_link_service.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/share/share_service.dart';
import '../../../scores/data/models/match_dto.dart';

/// Render the [MatchShareCard] graphic off-screen and hand it to the share
/// sheet alongside a ChottuLink deep link. Crests are warmed first so they
/// paint on the captured frame. If the render fails we surface a snackbar and
/// still share the link, so it never silently dead-ends.
/// Shared by the match-detail share button and the match-list long-press.
Future<void> shareMatchGraphic(BuildContext context, MatchDto match) async {
  HapticFeedback.selectionClick();
  final messenger = ScaffoldMessenger.maybeOf(context);

  Future<void> warm(String? url) async {
    if (url == null || url.isEmpty) return;
    try {
      await precacheImage(NetworkImage(url), context);
    } catch (_) {/* fall back to the lettered disc */}
  }

  await Future.wait([
    warm(match.homeTeam.crestUrl),
    warm(match.awayTeam.crestUrl),
  ]).timeout(const Duration(seconds: 5), onTimeout: () => const []);
  if (!context.mounted) return;

  String? path;
  try {
    path = await ShareService.instance.renderArtifactToFile(
      context: context,
      logicalSize: MatchShareCard.logicalSize,
      filename: 'pitch_match_${match.id}.png',
      // 2x keeps it crisp (2160×2700) while avoiding the ~52MB bitmap a 3x
      // capture of this 1080×1350 card needs — that OOM'd the render on-device.
      pixelRatio: 2.0,
      builder: (_) => MatchShareCard(match: match),
    );
  } catch (_) {
    path = null;
  }
  if (path == null) {
    messenger?.showSnackBar(const SnackBar(
      content: Text('Couldn’t build the match graphic — sharing a link instead.'),
    ));
  }

  final showScore = match.isLive || match.isFinished;
  await ChottuLinkService.instance.shareMatch(
    matchId: match.id,
    homeTeam: match.homeTeam.name,
    awayTeam: match.awayTeam.name,
    homeScore: showScore ? match.homeScore : null,
    awayScore: showScore ? match.awayScore : null,
    imagePath: path,
  );
}

/// Shareable 1080×1350 match graphic in the PITCH gold/dark style.
///
/// Adapts to match state:
///   • upcoming (SCHEDULED) → "MATCHDAY", VS, local kickoff + venue, a hype line
///   • live (LIVE/HT)       → "LIVE", running score + minute
///   • finished             → "FULL TIME", final score (+ pens if any)
///
/// Render off-screen via [ShareService] — precache both crests first so they
/// paint on the captured frame.
class MatchShareCard extends StatelessWidget {
  const MatchShareCard({super.key, required this.match});

  final MatchDto match;

  static const Size logicalSize = Size(1080, 1350);

  bool get _showScore => match.isLive || match.isFinished;

  String get _statusWord {
    if (match.isLive) return 'LIVE';
    if (match.isFinished) return 'FULL TIME';
    return 'MATCHDAY';
  }

  String get _kickoffLine {
    final local = match.kickoffAt.toLocal();
    return DateFormat('EEE, d MMM · h:mm a').format(local).toUpperCase();
  }

  String get _subline {
    if (match.isLive) {
      final m = match.minute;
      return m != null ? "LIVE · $m'" : 'LIVE NOW';
    }
    if (match.isFinished) return 'FULL TIME';
    return _kickoffLine;
  }

  String get _hypeOrContext {
    if (match.isFinished) {
      if (match.homeScore == match.awayScore) return 'Honours even.';
      final winner =
          match.homeScore > match.awayScore ? match.homeTeam : match.awayTeam;
      return '${winner.name} take it.';
    }
    if (match.isLive) return 'Follow every kick live.';
    return 'Who comes out on top?';
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF14110D), Color(0xFF0A0908)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Soft gold glow behind the scoreline.
          const Align(
            alignment: Alignment(0, -0.15),
            child: _Glow(),
          ),
          // Multi-stop top edge — echoes the tournament-graphic neon bar but
          // tuned to our champagne palette.
          const Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              height: 12,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    Color(0xFF4DBADC),
                    AppColors.gold,
                    Color(0xFFD656B5),
                  ]),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(64, 80, 64, 64),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(),
                const Spacer(flex: 2),
                // Big status word.
                Text(
                  _statusWord,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 84,
                    height: 0.95,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -2,
                    color: AppColors.fg,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  match.stage?.toUpperCase() ?? 'WORLD CUP 2026',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                    color: AppColors.gold,
                  ),
                ),
                const Spacer(flex: 2),
                _matchPanel(),
                const Spacer(flex: 2),
                Text(
                  _subline,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    color: match.isLive ? AppColors.live : AppColors.fgSoft,
                  ),
                ),
                if (!_showScore && (match.venue?.isNotEmpty ?? false)) ...[
                  const SizedBox(height: 10),
                  Text(
                    match.venue!.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6,
                      color: AppColors.muted,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  _hypeOrContext,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: AppColors.fg,
                  ),
                ),
                const Spacer(flex: 2),
                _footer(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [Color(0xFFF1E4B6), Color(0xFFE5C26B), Color(0xFF8E6422)],
              stops: [0.2, 0.6, 1.0],
              center: Alignment(-0.3, -0.4),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Solid champagne fill rather than a ShaderMask — off-screen toImage
        // capture of a ShaderMask is unreliable under Impeller (release), which
        // produced a blank/failed graphic in the Play Store build.
        const Text(
          'PITCH',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 32,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.6,
            color: Color(0xFFEBD9A8),
          ),
        ),
        const Spacer(),
        const Text(
          'WORLD CUP 2026',
          style: TextStyle(
            color: Color(0xFFB78A2E),
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }

  Widget _matchPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF211D17), Color(0xFF161310)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.goldHairline, width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _TeamColumn(team: match.homeTeam)),
              _centrePiece(),
              Expanded(child: _TeamColumn(team: match.awayTeam)),
            ],
          ),
          const SizedBox(height: 24),
          // Champagne accent bar.
          Container(
            height: 6,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(99),
              gradient: const LinearGradient(colors: [
                AppColors.goldSoft,
                AppColors.gold,
                AppColors.goldDeep,
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _centrePiece() {
    if (_showScore) {
      final pens = (match.homePenalties != null && match.awayPenalties != null);
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${match.homeScore} – ${match.awayScore}',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 88,
                height: 1,
                fontWeight: FontWeight.w900,
                letterSpacing: -2,
                color: AppColors.fg,
              ),
            ),
            if (pens)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '(${match.homePenalties}–${match.awayPenalties} pens)',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.muted,
                  ),
                ),
              ),
          ],
        ),
      );
    }
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        'VS',
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 56,
          fontWeight: FontWeight.w900,
          letterSpacing: -1,
          color: AppColors.gold,
        ),
      ),
    );
  }

  Widget _footer() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('FOLLOW LIVE ON',
                style: TextStyle(color: AppColors.muted, fontSize: 18, letterSpacing: 1)),
            SizedBox(height: 4),
            Text(
              'footballmojo.in',
              style: TextStyle(
                color: Color(0xFFEBD9A8),
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const Spacer(),
        Text(
          'FootballMojo',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 900,
      height: 900,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [AppColors.goldGlow, Colors.transparent],
          stops: [0.0, 0.7],
        ),
      ),
    );
  }
}

class _TeamColumn extends StatelessWidget {
  const _TeamColumn({required this.team});
  final TeamDto team;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Crest(team: team),
        const SizedBox(height: 18),
        Text(
          team.name,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 30,
            height: 1.05,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            color: AppColors.fg,
          ),
        ),
      ],
    );
  }
}

/// Team crest from its network URL; falls back to a champagne disc with the
/// 3-letter short name when the crest is missing/unloadable.
class _Crest extends StatelessWidget {
  const _Crest({required this.team});
  final TeamDto team;

  String get _abbr {
    final s = (team.shortName?.isNotEmpty ?? false) ? team.shortName! : team.name;
    return s.length <= 3 ? s.toUpperCase() : s.substring(0, 3).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: 132,
      height: 132,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [Color(0xFF2D2A27), Color(0xFF1B1A18)],
        ),
        border: Border.fromBorderSide(BorderSide(color: AppColors.goldHairline)),
      ),
      alignment: Alignment.center,
      child: Text(
        _abbr,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 38,
          fontWeight: FontWeight.w900,
          color: AppColors.gold,
        ),
      ),
    );

    final url = team.crestUrl;
    if (url == null || url.isEmpty) return fallback;
    return SizedBox(
      width: 132,
      height: 132,
      child: Image.network(
        url,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }
}
