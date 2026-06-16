import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/ads/ad_widgets.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/util/region.dart';
import '../../../../core/util/watch_country.dart';
import '../../../../core/widgets/eyebrow.dart';
import '../../../highlights/highlight_link.dart';
import '../../data/ai_preview_repository.dart';
import '../../../../core/widgets/live_dot.dart';
import '../../../../core/widgets/pitch_buttons.dart';
import '../../../../core/widgets/premium_image.dart';
import '../../../../core/widgets/score_flip.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../insights/data/insights_repository.dart';
import '../../../insights/data/models/broadcast_dto.dart';
import '../../../insights/data/models/lineup_dto.dart';
import '../../../insights/data/models/match_event_dto.dart';
import '../../../insights/data/models/match_stats_dto.dart';
import '../../../scores/data/models/match_dto.dart';
import '../../../scores/data/repositories/scores_repository.dart';
import '../widgets/match_share_card.dart';

/// Match detail — single scrollable page with hero + stats + events + lineups
/// stacked vertically. Each section handles its own loading/error/empty
/// state, so partial failures (e.g. lineups not yet announced) never blank
/// the whole screen.
class MatchDetailScreen extends ConsumerStatefulWidget {
  const MatchDetailScreen({super.key, required this.matchId});
  final String matchId;
  @override
  ConsumerState<MatchDetailScreen> createState() => _MatchDetailScreenState();
}

class _MatchDetailScreenState extends ConsumerState<MatchDetailScreen> {
  late final Future<MatchDto?> _matchFuture;
  // Mutable, live-patched copy of the match. Seeded from the initial fetch,
  // then folded forward by WebSocket deltas so the hero score ticks live.
  MatchDto? _match;
  StreamSubscription<MatchUpdate>? _sub;

  @override
  void initState() {
    super.initState();
    final repo = ref.read(scoresRepositoryProvider);
    _matchFuture = repo.fetchMatch(widget.matchId).then((m) {
      if (mounted && m != null) setState(() => _match ??= m);
      return m;
    });
    repo.subscribeMatch(widget.matchId);
    _sub = repo.updates().listen(_applyUpdate);
  }

  void _applyUpdate(MatchUpdate u) {
    final base = _match;
    if (!mounted || u.id != widget.matchId || base == null) return;
    final scoreChanged =
        u.homeScore != base.homeScore || u.awayScore != base.awayScore;
    setState(() {
      _match = base.copyWith(
        status: u.status,
        minute: u.minute,
        minuteExtra: u.minuteExtra,
        homeScore: u.homeScore,
        awayScore: u.awayScore,
        homePenalties: u.homePenalties,
        awayPenalties: u.awayPenalties,
      );
    });
    // A goal fires a score delta → refresh the key-moments + stats so the new
    // event/possession lands without the user pulling to refresh.
    if (scoreChanged) {
      ref.invalidate(matchEventsProvider(widget.matchId));
      ref.invalidate(matchStatsProvider(widget.matchId));
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    ref.read(scoresRepositoryProvider).unsubscribeMatch(widget.matchId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: FutureBuilder<MatchDto?>(
        future: _matchFuture,
        builder: (_, snap) {
          final topInset = MediaQuery.viewPaddingOf(context).top;
          if (snap.connectionState != ConnectionState.done) {
            return _LoadingState(topInset: topInset);
          }
          if (snap.hasError) {
            return _NotFound(
              topInset: topInset,
              title: 'Match unavailable',
              detail: '${snap.error}',
            );
          }
          // Prefer the live-patched copy so socket score deltas show.
          final match = _match ?? snap.data;
          if (match == null) {
            return _NotFound(
              topInset: topInset,
              title: 'Match details not yet available',
              detail:
                  'This fixture is from a league we don’t track in detail. Tap the back arrow to return to scores.',
            );
          }
          return _MatchBody(match: match, topInset: topInset);
        },
      ),
    );
  }
}

// ─── BODY ──────────────────────────────────────────────────────────────────

class _MatchBody extends StatelessWidget {
  const _MatchBody({required this.match, required this.topInset});
  final MatchDto match;
  final double topInset;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        SliverToBoxAdapter(child: SizedBox(height: topInset + 6)),
        SliverToBoxAdapter(child: _Topbar(match: match)),
        SliverToBoxAdapter(child: _Hero(match: match)),
        SliverToBoxAdapter(child: _AiPreviewBlock(match: match)),
        // Self-hiding: renders nothing until the backend serves broadcast data.
        SliverToBoxAdapter(child: _WhereToWatchBlock(matchId: match.id)),
        SliverToBoxAdapter(child: _SectionHead(title: 'Stats', icon: Icons.bar_chart)),
        SliverToBoxAdapter(child: _StatsBlock(matchId: match.id)),
        SliverToBoxAdapter(child: _SectionHead(title: 'Key moments', icon: Icons.timeline)),
        SliverToBoxAdapter(child: _EventsBlock(matchId: match.id, homeTeamId: match.homeTeam.id)),
        SliverToBoxAdapter(child: _SectionHead(title: 'Line-ups', icon: Icons.group)),
        SliverToBoxAdapter(child: _LineupsBlock(matchId: match.id)),
        const SliverToBoxAdapter(
          child: Center(child: PitchBannerAd(padding: EdgeInsets.fromLTRB(16, 20, 16, 0))),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }
}

// ─── AI MATCH PREVIEW (on-demand) ────────────────────────────────────────────

/// Collapsed by default — only calls the AI when the user taps "Generate".
/// The backend caches per-match, so repeat taps and other users are free.
class _AiPreviewBlock extends ConsumerStatefulWidget {
  const _AiPreviewBlock({required this.match});
  final MatchDto match;
  @override
  ConsumerState<_AiPreviewBlock> createState() => _AiPreviewBlockState();
}

class _AiPreviewBlockState extends ConsumerState<_AiPreviewBlock> {
  bool _loading = false;
  String? _error;
  AiMatchPreview? _preview;

  // Before kickoff it's a preview; once live/finished it's a summary. The
  // response's `kind` confirms it, but we label up-front from the match state.
  bool get _isSummary =>
      _preview?.isSummary ?? (widget.match.isLive || widget.match.isFinished);
  String get _noun => _isSummary ? 'summary' : 'preview';

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final p = await ref.read(aiPreviewRepositoryProvider).matchPreview(widget.match.id);
      if (!mounted) return;
      setState(() {
        _preview = p;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      final code = apiErrorCode(e);
      setState(() {
        _loading = false;
        _error = code.contains('ai_unavailable') || code.contains('ai_request_failed')
            ? 'AI $_noun isn’t available right now.'
            : 'Couldn’t generate the $_noun. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.r4),
          border: Border.all(color: AppColors.goldHairline),
          gradient: const LinearGradient(
            colors: [Color(0xFF1F1814), Color(0xFF12100D)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, size: 16, color: AppColors.gold),
                const SizedBox(width: 8),
                Text(
                  'AI match $_noun',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.fg,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _body(),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_preview != null) return _AiPreviewContent(preview: _preview!);
    if (_loading) {
      return Row(
        children: [
          const SizedBox(
            width: 16, height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold),
          ),
          const SizedBox(width: 10),
          Text('Writing the $_noun…',
              style: const TextStyle(color: AppColors.muted, fontSize: 13)),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isSummary
              ? 'Get an AI-written summary — the scoreline, key moments, stats and what it means, grounded in live reports.'
              : 'Get a quick, AI-written preview — recent form, key injuries, head-to-head and what’s at stake.',
          style: const TextStyle(color: AppColors.fgSoft, fontSize: 12.5, height: 1.4),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(color: AppColors.live, fontSize: 12)),
        ],
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: GoldButton(
            label: _error == null ? 'Generate $_noun' : 'Try again',
            icon: Icons.auto_awesome,
            onPressed: _generate,
          ),
        ),
      ],
    );
  }
}

class _AiPreviewContent extends StatelessWidget {
  const _AiPreviewContent({required this.preview});
  final AiMatchPreview preview;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          preview.content,
          style: const TextStyle(color: AppColors.fg, fontSize: 13.5, height: 1.5),
        ),
        if (preview.sources.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Eyebrow('Sources', size: 9),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [for (final s in preview.sources) _AiSourceChip(source: s)],
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            const Icon(Icons.auto_awesome, size: 11, color: AppColors.muted2),
            const SizedBox(width: 5),
            const Expanded(
              child: Text(
                'AI-generated with Google Search · may contain mistakes.',
                style: TextStyle(color: AppColors.muted2, fontSize: 10.5),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AiSourceChip extends StatelessWidget {
  const _AiSourceChip({required this.source});
  final AiSource source;

  String _label() {
    final uri = source.uri;
    if (uri != null) {
      try {
        final host = Uri.parse(uri).host.replaceFirst('www.', '');
        if (host.isNotEmpty) return host;
      } catch (_) {}
    }
    return source.title;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: source.uri == null
          ? null
          : () => launchUrl(Uri.parse(source.uri!), mode: LaunchMode.externalApplication),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: AppColors.borderSoft),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.link, size: 11, color: AppColors.muted),
            const SizedBox(width: 4),
            Text(
              _label(),
              style: const TextStyle(color: AppColors.fgSoft, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState({required this.topInset});
  final double topInset;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, topInset + 60, 16, 16),
      child: const Skeleton(height: 240, radius: 20),
    );
  }
}

// ─── TOPBAR ────────────────────────────────────────────────────────────────

class _Topbar extends StatelessWidget {
  const _Topbar({required this.match});
  final MatchDto match;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          CircleIconButton(icon: Icons.chevron_left, onPressed: () => context.pop()),
          Expanded(
            child: Center(
              child: Eyebrow(match.stage ?? 'Match', gold: true, size: 11),
            ),
          ),
          CircleIconButton(
            icon: Icons.share_outlined,
            onPressed: () => shareMatchGraphic(context, match),
          ),
        ],
      ),
    );
  }
}

// ─── HERO ──────────────────────────────────────────────────────────────────

class _Hero extends ConsumerWidget {
  const _Hero({required this.match});
  final MatchDto match;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Goalscorers chip-row. Render only when there's at least one goal so
    // pre-match / 0-0 heroes don't grow an empty band. Pulled from the
    // same events provider the Events tab uses — Riverpod dedupes, so we
    // pay one fetch even though it's referenced twice on the page.
    final heroEvents = ref.watch(matchEventsProvider(match.id)).maybeWhen(
          data: (es) => es
              .where((e) => _isGoalEvent(e) || e.kind == EventKind.red)
              .toList(),
          orElse: () => const <MatchEventDto>[],
        );
    final showScore = match.isLive || match.isFinished;
    // State-aware ambient glow behind the scoreline — red while live, champagne
    // otherwise — so a live match reads as "live" the instant you open it.
    final Color heroGlow =
        match.isLive ? AppColors.live.withValues(alpha: 0.22) : AppColors.goldGlow;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.r5),
          border: Border.all(color: AppColors.borderSoft),
          gradient: const LinearGradient(
            colors: [Color(0xFF1A1714), Color(0xFF0F0D0B)],
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.r5),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [heroGlow, Colors.transparent],
                      center: const Alignment(0, -1),
                      radius: 0.85,
                    ),
                  ),
                ),
              ),
            ),
            Column(
              children: [
                if (match.isLive)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.live.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: AppColors.live.withValues(alpha: 0.40)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const LiveDot(),
                        const SizedBox(width: 7),
                        const Text(
                          'LIVE',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.live,
                            letterSpacing: 1.6,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 1,
                          height: 11,
                          color: AppColors.live.withValues(alpha: 0.35),
                        ),
                        const SizedBox(width: 8),
                        // Minute ticks via setState on each socket update.
                        Text(
                          match.status == MatchStatus.HALF_TIME
                              ? 'HT'
                              : match.minuteLabel,
                          style: const TextStyle(
                            fontFamily: 'JetBrainsMono',
                            fontFamilyFallback: ['SF Mono', 'Menlo', 'monospace'],
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.fg,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Eyebrow(
                    match.isFinished
                        ? 'Full time'
                        : DateFormat('EEE d MMM · HH:mm').format(match.kickoffAt.toLocal()),
                    gold: true,
                    size: 10,
                  ),
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: _Side(team: match.homeTeam, alignEnd: false)),
                    if (showScore)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ScoreFlip(
                              value: match.homeScore,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 48,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1.92,
                                color: AppColors.fg,
                                height: 1.0,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Text(
                              '–',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 40,
                                fontWeight: FontWeight.w300,
                                color: AppColors.muted.withValues(alpha: 0.7),
                                height: 1.0,
                              ),
                            ),
                            const SizedBox(width: 14),
                            ScoreFlip(
                              value: match.awayScore,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 48,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1.92,
                                color: AppColors.fg,
                                height: 1.0,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 18),
                        child: Text(
                          'vs',
                          style: TextStyle(
                            fontFamily: 'IowanOldStyle',
                            fontFamilyFallback: ['Charter', 'Georgia', 'serif'],
                            fontStyle: FontStyle.italic,
                            fontSize: 22,
                            color: AppColors.gold,
                          ),
                        ),
                      ),
                    Expanded(child: _Side(team: match.awayTeam, alignEnd: true)),
                  ],
                ),
                if (heroEvents.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _HeroGoalscorers(
                    events: heroEvents,
                    homeTeamId: match.homeTeam.id,
                  ),
                ],
                if (match.hasHighlight) ...[
                  const SizedBox(height: 16),
                  Center(child: HighlightChip(match: match)),
                ],
                if (match.venue != null) ...[
                  const SizedBox(height: 18),
                  Container(height: 1, color: AppColors.borderSoft),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Eyebrow(match.venue!, size: 10),
                      if (match.stage != null) Eyebrow(match.stage!, size: 10),
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Hero events: goals (incl. own-goals + penalties, but not missed penalties)
/// and red cards. Red cards render as a red card glyph on the sent-off
/// player's own side.
bool _isGoalEvent(MatchEventDto e) =>
    e.kind == EventKind.goal ||
    e.kind == EventKind.ownGoal ||
    e.kind == EventKind.penalty ||
    e.kind == EventKind.red;

/// Two-column scorer strip rendered under the score in the hero. Each side
/// lists the team's scorers with minute marks (`Mbappé 23'`, `Yamal 67'`).
/// Own-goals are intentionally credited to the *opposite* side so the
/// scoreboard reads correctly.
class _HeroGoalscorers extends StatelessWidget {
  const _HeroGoalscorers({required this.events, required this.homeTeamId});
  final List<MatchEventDto> events;
  final String homeTeamId;

  @override
  Widget build(BuildContext context) {
    final home = <MatchEventDto>[];
    final away = <MatchEventDto>[];
    for (final e in events) {
      // Own goals score for the opposing side — flip the bucket they land in.
      final scoresForHome = e.kind == EventKind.ownGoal
          ? e.teamId != homeTeamId
          : e.teamId == homeTeamId;
      (scoresForHome ? home : away).add(e);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _ScorerColumn(events: home, alignEnd: false)),
        const SizedBox(width: 12),
        Expanded(child: _ScorerColumn(events: away, alignEnd: true)),
      ],
    );
  }
}

class _ScorerColumn extends StatelessWidget {
  const _ScorerColumn({required this.events, required this.alignEnd});
  final List<MatchEventDto> events;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        for (final e in events)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!alignEnd) ...[_ballIcon(e), const SizedBox(width: 6)],
                Flexible(
                  child: Text(
                    _label(e),
                    textAlign: alignEnd ? TextAlign.right : TextAlign.left,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.fg,
                      height: 1.3,
                    ),
                  ),
                ),
                if (alignEnd) ...[const SizedBox(width: 6), _ballIcon(e)],
              ],
            ),
          ),
      ],
    );
  }

  Widget _ballIcon(MatchEventDto e) {
    if (e.kind == EventKind.red) {
      return Container(
        width: 9,
        height: 12,
        decoration: BoxDecoration(
          color: AppColors.live,
          borderRadius: BorderRadius.circular(2),
        ),
      );
    }
    // All goals — including penalties — use the ball glyph. Own-goals reuse it
    // in red so they read as goals while standing out from a side's tallies.
    final color = e.kind == EventKind.ownGoal ? AppColors.live : AppColors.gold;
    return Icon(Icons.sports_soccer, size: 12, color: color);
  }

  String _label(MatchEventDto e) {
    final name = e.playerName ?? 'Unknown';
    final extra = e.kind == EventKind.ownGoal
        ? ' (OG)'
        : e.kind == EventKind.penalty
            ? ' (P)'
            : '';
    return '$name$extra · ${e.displayMinute}';
  }
}

class _Side extends StatelessWidget {
  const _Side({required this.team, required this.alignEnd});
  final TeamDto team;
  final bool alignEnd;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 56, height: 56,
          child: PremiumImage(url: team.crestUrl, fit: BoxFit.contain),
        ),
        const SizedBox(height: 10),
        Text(
          team.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: alignEnd ? TextAlign.end : TextAlign.start,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.24,
            color: AppColors.fg,
          ),
        ),
        const SizedBox(height: 4),
        Eyebrow(team.shortName ?? '', size: 9),
      ],
    );
  }
}

// ─── SECTION HEAD ──────────────────────────────────────────────────────────

class _SectionHead extends StatelessWidget {
  const _SectionHead({required this.title, required this.icon});
  final String title;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.gold),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.26,
              color: AppColors.fg,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── WHERE TO WATCH ──────────────────────────────────────────────────────────

/// Broadcasters grouped by country. The viewer's own country (detected from
/// the device region — no location permission) is pinned to the top and
/// highlighted; every other country sits behind a collapsible "More countries"
/// row. Renders nothing until the backend's broadcast source returns data, so
/// the section stays invisible rather than showing a broken empty card.
class _WhereToWatchBlock extends ConsumerWidget {
  const _WhereToWatchBlock({required this.matchId});
  final String matchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(matchBroadcastsProvider(matchId)).maybeWhen(
          data: (b) => b.where((e) => e.broadcasters.isNotEmpty).toList(),
          orElse: () => const <MatchBroadcastDto>[],
        );
    if (entries.isEmpty) return const SizedBox.shrink();

    final cc = ref.watch(watchCountryProvider);
    MatchBroadcastDto? mine;
    if (cc != null) {
      for (final e in entries) {
        if (e.countryCode == cc) {
          mine = e;
          break;
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHead(title: 'Where to watch', icon: Icons.live_tv),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              if (mine != null)
                _CountryBroadcast(
                  entry: mine,
                  highlighted: true,
                  onChangeRegion: () => _pickRegion(context, ref, entries),
                )
              else
                _RegionPrompt(onTap: () => _pickRegion(context, ref, entries)),
              const SizedBox(height: 10),
              // Only the user's card renders inline; the full ~200-country
              // list lives behind a searchable, lazily-built sheet so the
              // section stays light.
              _BrowseAllButton(
                count: entries.length,
                onTap: () => _browseAll(context, entries),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pickRegion(
      BuildContext context, WidgetRef ref, List<MatchBroadcastDto> entries) async {
    final code = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CountryBrowserSheet(entries: entries, pick: true),
    );
    if (code != null) ref.read(watchCountryProvider.notifier).set(code);
  }

  void _browseAll(BuildContext context, List<MatchBroadcastDto> entries) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CountryBrowserSheet(entries: entries, pick: false),
    );
  }
}

/// Shown when we can't match the viewer's region to any listed country.
class _RegionPrompt extends StatelessWidget {
  const _RegionPrompt({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.r4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.r4),
          color: AppColors.surface,
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
        ),
        child: const Row(
          children: [
            Icon(Icons.public, size: 18, color: AppColors.gold),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Pick your country to see where to watch',
                style: TextStyle(
                    fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.fg),
              ),
            ),
            Icon(Icons.chevron_right, size: 20, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

class _BrowseAllButton extends StatelessWidget {
  const _BrowseAllButton({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.r4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.r4),
          color: AppColors.surface,
          border: Border.all(color: AppColors.borderSoft),
        ),
        child: Row(
          children: [
            const Icon(Icons.public, size: 18, color: AppColors.muted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Browse all $count countries',
                style: const TextStyle(
                    fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.fg),
              ),
            ),
            const Icon(Icons.search, size: 18, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

/// Searchable, lazily-rendered country browser in a bottom sheet. In [pick]
/// mode each row is a selectable country tile that returns its code; otherwise
/// each row is a full broadcaster card. `ListView.builder` keeps it cheap even
/// with ~200 countries.
class _CountryBrowserSheet extends StatefulWidget {
  const _CountryBrowserSheet({required this.entries, required this.pick});
  final List<MatchBroadcastDto> entries;
  final bool pick;

  @override
  State<_CountryBrowserSheet> createState() => _CountryBrowserSheetState();
}

class _CountryBrowserSheetState extends State<_CountryBrowserSheet> {
  String _q = '';
  late final List<MatchBroadcastDto> _sorted =
      [...widget.entries]..sort((a, b) => a.countryName.compareTo(b.countryName));

  @override
  Widget build(BuildContext context) {
    final q = _q.trim().toLowerCase();
    final list = q.isEmpty
        ? _sorted
        : _sorted
            .where((e) =>
                e.countryName.toLowerCase().contains(q) || e.countryCode.toLowerCase().contains(q))
            .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderSoft, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                autofocus: true,
                onChanged: (v) => setState(() => _q = v),
                style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: AppColors.fg),
                decoration: InputDecoration(
                  hintText: widget.pick ? 'Search for your country…' : 'Search countries…',
                  hintStyle: const TextStyle(color: AppColors.muted),
                  prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.muted),
                  filled: true,
                  fillColor: AppColors.surface,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadii.r4),
                    borderSide: const BorderSide(color: AppColors.borderSoft),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadii.r4),
                    borderSide: const BorderSide(color: AppColors.borderSoft),
                  ),
                ),
              ),
            ),
            Expanded(
              child: list.isEmpty
                  ? const Center(
                      child: Text('No countries match',
                          style: TextStyle(fontFamily: 'Inter', color: AppColors.muted)))
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: list.length,
                      itemBuilder: (_, i) {
                        final e = list[i];
                        if (widget.pick) {
                          return ListTile(
                            dense: true,
                            leading: Text(countryFlagEmoji(e.countryCode),
                                style: const TextStyle(fontSize: 22)),
                            title: Text(
                              e.countryName.isNotEmpty ? e.countryName : e.countryCode,
                              style: const TextStyle(
                                  fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.fg),
                            ),
                            trailing: Text('${e.broadcasters.length}',
                                style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.muted)),
                            onTap: () => Navigator.pop(context, e.countryCode),
                          );
                        }
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _CountryBroadcast(entry: e, highlighted: false),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One country card: flag + name header, then a row per broadcaster.
class _CountryBroadcast extends StatelessWidget {
  const _CountryBroadcast({required this.entry, required this.highlighted, this.onChangeRegion});
  final MatchBroadcastDto entry;
  final bool highlighted;
  final VoidCallback? onChangeRegion;

  @override
  Widget build(BuildContext context) {
    final flag = countryFlagEmoji(entry.countryCode);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.r4),
        color: AppColors.surface,
        border: Border.all(
          color: highlighted ? AppColors.gold : AppColors.borderSoft,
          width: highlighted ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (flag.isNotEmpty) ...[
                Text(flag, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  entry.countryName.isNotEmpty ? entry.countryName : entry.countryCode,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: highlighted ? AppColors.gold : AppColors.fg,
                  ),
                ),
              ),
              if (highlighted)
                GestureDetector(
                  onTap: onChangeRegion,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Your region',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.gold,
                        ),
                      ),
                      if (onChangeRegion != null) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.edit, size: 12, color: AppColors.gold),
                      ],
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          for (final b in entry.broadcasters) _BroadcasterRow(broadcaster: b),
        ],
      ),
    );
  }
}

class _BroadcasterRow extends StatelessWidget {
  const _BroadcasterRow({required this.broadcaster});
  final BroadcasterDto broadcaster;

  @override
  Widget build(BuildContext context) {
    final url = broadcaster.url;
    return InkWell(
      onTap: (url == null || url.isEmpty)
          ? null
          : () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            SizedBox(
              width: 22, height: 22,
              child: PremiumImage(
                url: broadcaster.logo,
                fit: BoxFit.contain,
                fallback: const Icon(Icons.tv, size: 16, color: AppColors.muted),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                broadcaster.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.fg,
                ),
              ),
            ),
            if (url != null && url.isNotEmpty)
              const Icon(Icons.open_in_new, size: 14, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

// ─── STATS ─────────────────────────────────────────────────────────────────

class _StatsBlock extends ConsumerWidget {
  const _StatsBlock({required this.matchId});
  final String matchId;

  static const _ordered = <_StatRow>[
    _StatRow('Ball Possession', isPercent: true),
    _StatRow('Total Shots'),
    _StatRow('Shots on Goal'),
    _StatRow('Corner Kicks'),
    _StatRow('Fouls'),
    _StatRow('Yellow Cards'),
    _StatRow('Total passes', display: 'Passes'),
    _StatRow('Passes %', display: 'Pass accuracy', isPercent: true),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(matchStatsProvider(matchId));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: async.when(
        loading: () => const Skeleton(height: 200, radius: 16),
        error: (_, __) => const _SectionEmpty(text: 'Stats temporarily unavailable.'),
        data: (teams) {
          if (teams.length != 2) {
            return const _SectionEmpty(
              text: 'Stats appear shortly after kickoff.',
            );
          }
          final home = teams[0];
          final away = teams[1];
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.r4),
              border: Border.all(color: AppColors.borderSoft),
              color: AppColors.surface,
            ),
            child: Column(
              children: [
                for (int i = 0; i < _ordered.length; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  _StatBar(home: home, away: away, row: _ordered[i]),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatRow {
  const _StatRow(this.key, {this.display, this.isPercent = false});
  final String key;
  final String? display;
  final bool isPercent;
}

class _StatBar extends StatelessWidget {
  const _StatBar({required this.home, required this.away, required this.row});
  final TeamMatchStatsDto home;
  final TeamMatchStatsDto away;
  final _StatRow row;

  @override
  Widget build(BuildContext context) {
    final hVal = home[row.key] ?? 0;
    final aVal = away[row.key] ?? 0;
    final total = (hVal + aVal).abs();
    final hRatio = total == 0 ? 0.5 : hVal / total;
    String fmt(num v) => row.isPercent ? '${v.toStringAsFixed(0)}%' : v.toStringAsFixed(0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 44,
              child: Text(
                fmt(hVal),
                style: const TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontFamilyFallback: ['SF Mono', 'Menlo', 'monospace'],
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.fg,
                ),
              ),
            ),
            Expanded(
              child: Text(
                row.display ?? row.key,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  color: AppColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(
              width: 44,
              child: Text(
                fmt(aVal),
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontFamilyFallback: ['SF Mono', 'Menlo', 'monospace'],
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.fg,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              flex: (hRatio * 100).round().clamp(1, 99),
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.gold,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              flex: ((1 - hRatio) * 100).round().clamp(1, 99),
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderSoft,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── EVENTS ────────────────────────────────────────────────────────────────

class _EventsBlock extends ConsumerWidget {
  const _EventsBlock({required this.matchId, required this.homeTeamId});
  final String matchId;
  final String homeTeamId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(matchEventsProvider(matchId));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: async.when(
        loading: () => const Skeleton(height: 120, radius: 16),
        error: (_, __) => const _SectionEmpty(text: 'Events temporarily unavailable.'),
        data: (events) {
          if (events.isEmpty) {
            return const _SectionEmpty(text: 'Goals, cards and subs land here in real time.');
          }
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.r4),
              border: Border.all(color: AppColors.borderSoft),
              color: AppColors.surface,
            ),
            child: Column(
              children: [
                for (final e in events)
                  _EventTile(event: e, isHome: e.teamId == homeTeamId),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event, required this.isHome});
  final MatchEventDto event;
  final bool isHome;

  IconData get _icon => switch (event.kind) {
        EventKind.goal || EventKind.penalty => Icons.sports_soccer,
        EventKind.ownGoal => Icons.swap_calls,
        EventKind.penaltyMissed => Icons.do_not_disturb_on_outlined,
        EventKind.yellow => Icons.square,
        EventKind.red => Icons.square,
        EventKind.sub => Icons.sync_alt,
        EventKind.varCheck => Icons.crop_square_outlined,
        _ => Icons.circle,
      };
  Color get _color => switch (event.kind) {
        EventKind.goal || EventKind.penalty => AppColors.gold,
        EventKind.ownGoal => AppColors.live,
        EventKind.yellow => const Color(0xFFFCD34D),
        EventKind.red => AppColors.live,
        EventKind.sub => AppColors.pitch,
        _ => AppColors.muted,
      };

  @override
  Widget build(BuildContext context) {
    final left = isHome
        ? _eventSide(event: event, icon: _icon, color: _color, alignEnd: false)
        : const SizedBox.shrink();
    final right = isHome
        ? const SizedBox.shrink()
        : _eventSide(event: event, icon: _icon, color: _color, alignEnd: true);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: left),
          SizedBox(
            width: 44,
            child: Text(
              event.displayMinute,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'JetBrainsMono',
                fontFamilyFallback: ['SF Mono', 'Menlo', 'monospace'],
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.muted,
              ),
            ),
          ),
          Expanded(child: right),
        ],
      ),
    );
  }
}

Widget _eventSide({
    required MatchEventDto event,
    required IconData icon,
    required Color color,
    required bool alignEnd,
  }) {
    final col = Column(
      crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          event.playerName ?? '—',
          textAlign: alignEnd ? TextAlign.end : TextAlign.start,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.fg,
          ),
        ),
        if (event.assistName != null && event.kind == EventKind.goal) ...[
          const SizedBox(height: 2),
          Text(
            'assist · ${event.assistName}',
            textAlign: alignEnd ? TextAlign.end : TextAlign.start,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              color: AppColors.muted,
            ),
          ),
        ],
      ],
    );
    final pip = Icon(icon, size: 16, color: color);
    return Row(
      mainAxisAlignment: alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: alignEnd
          ? [Flexible(child: col), const SizedBox(width: 8), pip]
          : [pip, const SizedBox(width: 8), Flexible(child: col)],
    );
}

// ─── LINEUPS ───────────────────────────────────────────────────────────────

class _LineupsBlock extends ConsumerStatefulWidget {
  const _LineupsBlock({required this.matchId});
  final String matchId;
  @override
  ConsumerState<_LineupsBlock> createState() => _LineupsBlockState();
}

/// Tabbed pitch view. One tab per team; selected tab paints the 11-on-a-
/// pitch view + bench list below.
class _LineupsBlockState extends ConsumerState<_LineupsBlock> {
  int _tab = 0;
  @override
  Widget build(BuildContext context) {
    final async = ref.watch(matchLineupsProvider(widget.matchId));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: async.when(
        loading: () => const Skeleton(height: 320, radius: 16),
        error: (_, __) => const _SectionEmpty(text: 'Line-ups temporarily unavailable.'),
        data: (lineups) {
          if (lineups.isEmpty) {
            return const _SectionEmpty(
              text: 'Line-ups confirmed about an hour before kickoff.',
            );
          }
          // api-football returns [home, away]. Clamp the tab in case the
          // upstream payload is missing one side.
          final selected = _tab.clamp(0, lineups.length - 1);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _LineupTabs(
                lineups: lineups,
                selectedIndex: selected,
                onSelect: (i) => setState(() => _tab = i),
              ),
              const SizedBox(height: 10),
              _LineupPitchCard(lineup: lineups[selected]),
            ],
          );
        },
      ),
    );
  }
}

/// Pill segmented control — one tab per team. Crest + short name keeps the
/// affordance scannable without breaking the dark luxe theme.
class _LineupTabs extends StatelessWidget {
  const _LineupTabs({
    required this.lineups,
    required this.selectedIndex,
    required this.onSelect,
  });
  final List<LineupDto> lineups;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(AppRadii.r4),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Row(
        children: [
          for (int i = 0; i < lineups.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onSelect(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: i == selectedIndex ? AppColors.gold.withValues(alpha: 0.18) : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadii.r3),
                    border: i == selectedIndex
                        ? Border.all(color: AppColors.goldHairline)
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (lineups[i].teamLogo != null) ...[
                        SizedBox(width: 18, height: 18, child: PremiumImage(url: lineups[i].teamLogo, fit: BoxFit.contain)),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Text(
                          lineups[i].teamName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: i == selectedIndex ? AppColors.gold : AppColors.fgSoft,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LineupPitchCard extends StatelessWidget {
  const _LineupPitchCard({required this.lineup});
  final LineupDto lineup;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.r4),
        border: Border.all(color: AppColors.borderSoft),
        color: AppColors.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Eyebrow(
                lineup.formation.isEmpty ? 'Formation' : 'Formation · ${lineup.formation}',
                gold: true,
                size: 10,
              ),
              const Spacer(),
              if (lineup.coachName != null)
                Text(
                  lineup.coachName!,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    color: AppColors.muted,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          // Aspect-ratioed pitch container — keeps positions consistent
          // across phones. 0.72 ≈ half-pitch portrait, which is what
          // every football tactic board uses.
          AspectRatio(
            aspectRatio: 0.72,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.r3),
              child: _Pitch(players: lineup.startXI),
            ),
          ),
          if (lineup.substitutes.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Eyebrow('Substitutes', size: 10),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final s in lineup.substitutes)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      border: Border.all(color: AppColors.borderSoft),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (s.number != null) ...[
                          Text(
                            '${s.number}',
                            style: const TextStyle(
                              fontFamily: 'JetBrainsMono',
                              fontFamilyFallback: ['SF Mono', 'Menlo', 'monospace'],
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: AppColors.gold,
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          s.displayName,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.fgSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// The painted pitch + positioned player chips.
///
/// Positioning: api-football's `grid = "row:col"` puts row 1 at the goal
/// line. We map row → vertical fraction (GK ~10% from top, last outfield
/// row ~85%) and col → horizontal fraction within that row. When the grid
/// is missing for any player, we fall back to grouping by position and
/// distributing evenly.
class _Pitch extends StatelessWidget {
  const _Pitch({required this.players});
  final List<LineupPlayer> players;

  @override
  Widget build(BuildContext context) {
    final positioned = _layout(players);
    return Stack(
      fit: StackFit.expand,
      children: [
        // Pitch surface — green gradient + mowing stripes + lines.
        const Positioned.fill(child: CustomPaint(painter: _PitchPainter())),
        for (final p in positioned)
          Align(
            alignment: Alignment(p.x * 2 - 1, p.y * 2 - 1),
            child: FractionallySizedBox(
              widthFactor: 0.20,
              child: _PitchChip(player: p.player),
            ),
          ),
      ],
    );
  }

  /// Map every player to a normalized (x, y) in [0,1] within the pitch.
  /// Prefers the grid attribute when present, falls back to position rows.
  static List<_Placed> _layout(List<LineupPlayer> players) {
    final hasGrid = players.any((p) => p.row != null && p.col != null);
    if (hasGrid) {
      // Group by row to size columns row-by-row (formations vary the
      // column count per row — 4-3-3 has 4 then 3 then 3).
      final byRow = <int, List<LineupPlayer>>{};
      for (final p in players) {
        final r = p.row ?? 1;
        byRow.putIfAbsent(r, () => []).add(p);
      }
      final rows = byRow.keys.toList()..sort();
      final maxRow = rows.last;
      final placed = <_Placed>[];
      for (final r in rows) {
        final rowPlayers = byRow[r]!..sort((a, b) => (a.col ?? 0).compareTo(b.col ?? 0));
        // y: row 1 → 0.10, maxRow → 0.85, linear interp.
        final y = maxRow <= 1 ? 0.5 : 0.10 + ((r - 1) / (maxRow - 1)) * 0.75;
        for (var i = 0; i < rowPlayers.length; i++) {
          final n = rowPlayers.length;
          // Evenly distribute across 90% of pitch width. api-football numbers
          // grid columns right-to-left from the team's attacking perspective,
          // so col 1 sits on the right — mirror the index to match the
          // broadcast convention (and Google's lineup view).
          final x = n == 1 ? 0.5 : 0.95 - (i / (n - 1)) * 0.90;
          placed.add(_Placed(rowPlayers[i], x, y));
        }
      }
      return placed;
    }

    // No grid → group by position letter (G/D/M/F) and lay out by line.
    final order = ['G', 'D', 'M', 'F'];
    final byPos = {for (final p in order) p: <LineupPlayer>[]};
    for (final p in players) {
      final k = p.pos.isNotEmpty ? p.pos[0].toUpperCase() : 'M';
      (byPos[k] ?? byPos['M']!).add(p);
    }
    final activeLines = order.where((k) => byPos[k]!.isNotEmpty).toList();
    final placed = <_Placed>[];
    for (var i = 0; i < activeLines.length; i++) {
      final line = byPos[activeLines[i]]!;
      final y = activeLines.length <= 1
          ? 0.5
          : 0.10 + (i / (activeLines.length - 1)) * 0.75;
      for (var j = 0; j < line.length; j++) {
        final n = line.length;
        final x = n == 1 ? 0.5 : 0.05 + (j / (n - 1)) * 0.90;
        placed.add(_Placed(line[j], x, y));
      }
    }
    return placed;
  }
}

class _Placed {
  const _Placed(this.player, this.x, this.y);
  final LineupPlayer player;
  final double x;
  final double y;
}

class _PitchChip extends StatelessWidget {
  const _PitchChip({required this.player});
  final LineupPlayer player;
  @override
  Widget build(BuildContext context) {
    final label =
        player.number != null ? '${player.number}' : (player.pos.isNotEmpty ? player.pos[0] : '?');
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 40, height: 40,
          child: Stack(
            children: [
              // Player headshot, falling back to the gold number disc when no
              // photo is available (or it fails to load).
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF1E1810),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.5),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 6, offset: const Offset(0, 2))],
                ),
                child: ClipOval(
                  child: PremiumImage(
                    url: player.photoUrl,
                    fit: BoxFit.cover,
                    fallback: _numberDisc(label),
                  ),
                ),
              ),
              // Jersey number badge, kept inside the avatar bounds.
              Positioned(
                right: 0, bottom: 0,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 14),
                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC99A3D),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: const Color(0xFF1E1810), width: 1),
                  ),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E1810),
                      height: 1.0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(
            player.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.1,
            ),
          ),
        ),
      ],
    );
  }

  /// Gold disc with the jersey number — shown when there's no headshot.
  Widget _numberDisc(String label) => DecoratedBox(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [Color(0xFFEFD8A1), Color(0xFFC99A3D)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E1810),
              height: 1.0,
            ),
          ),
        ),
      );
}

/// Pitch surface — dark green gradient with alternating mowing stripes,
/// halfway line, centre circle, and 18-yard boxes. Bottom half of the
/// pitch only is drawn because lineups are portrait. (Full top-to-bottom
/// pitch read-out — both halves — fits the data better than a half pitch.)
class _PitchPainter extends CustomPainter {
  const _PitchPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Base gradient.
    final base = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF1F4F31), Color(0xFF153A24)],
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
      ).createShader(rect);
    canvas.drawRect(rect, base);

    // Mowing stripes — 8 alternating bands.
    final stripe = Paint()..color = Colors.white.withValues(alpha: 0.04);
    final bandH = size.height / 8;
    for (int i = 0; i < 8; i += 2) {
      canvas.drawRect(Rect.fromLTWH(0, i * bandH, size.width, bandH), stripe);
    }

    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.32)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    // Outer frame.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(8, 8, size.width - 16, size.height - 16),
        const Radius.circular(4),
      ),
      line,
    );
    // Halfway line + centre circle + spot.
    canvas.drawLine(Offset(8, size.height / 2), Offset(size.width - 8, size.height / 2), line);
    canvas.drawCircle(size.center(Offset.zero), size.width * 0.13, line);
    canvas.drawCircle(size.center(Offset.zero), 2, Paint()..color = Colors.white.withValues(alpha: 0.5));
    // 18-yard boxes (top + bottom).
    final boxW = size.width * 0.52;
    final boxH = size.height * 0.12;
    final boxX = (size.width - boxW) / 2;
    canvas.drawRect(Rect.fromLTWH(boxX, 8, boxW, boxH), line);
    canvas.drawRect(Rect.fromLTWH(boxX, size.height - 8 - boxH, boxW, boxH), line);
    // 6-yard boxes.
    final smallW = size.width * 0.28;
    final smallH = size.height * 0.05;
    final smallX = (size.width - smallW) / 2;
    canvas.drawRect(Rect.fromLTWH(smallX, 8, smallW, smallH), line);
    canvas.drawRect(Rect.fromLTWH(smallX, size.height - 8 - smallH, smallW, smallH), line);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// (_LineupCard + _PlayerChip removed — replaced by _LineupPitchCard above.)

// ─── HELPERS ───────────────────────────────────────────────────────────────

class _SectionEmpty extends StatelessWidget {
  const _SectionEmpty({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.r4),
        border: Border.all(color: AppColors.borderSoft),
        color: AppColors.surface,
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          color: AppColors.muted,
          height: 1.4,
        ),
      ),
    );
  }
}

class _NotFound extends StatelessWidget {
  const _NotFound({required this.topInset, required this.title, required this.detail});
  final double topInset;
  final String title;
  final String detail;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, topInset + 6, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [CircleIconButton(icon: Icons.chevron_left, onPressed: () => context.pop())]),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.r5),
              border: Border.all(color: AppColors.borderSoft),
              gradient: const LinearGradient(
                colors: [Color(0xFF1A1714), Color(0xFF0F0D0B)],
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Eyebrow('Match', gold: true),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.44,
                    color: AppColors.fg,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  detail,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: AppColors.muted,
                    height: 1.5,
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
