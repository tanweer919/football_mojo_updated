import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/widgets/eyebrow.dart';
import '../../../../core/widgets/live_dot.dart';
import '../../../../core/widgets/pitch_buttons.dart';
import '../../../../core/widgets/premium_image.dart';
import '../../../../core/widgets/score_flip.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../insights/data/insights_repository.dart';
import '../../../insights/data/models/lineup_dto.dart';
import '../../../insights/data/models/match_event_dto.dart';
import '../../../insights/data/models/match_stats_dto.dart';
import '../../../scores/data/models/match_dto.dart';
import '../../../scores/data/repositories/scores_repository.dart';

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

  @override
  void initState() {
    super.initState();
    final repo = ref.read(scoresRepositoryProvider);
    _matchFuture = repo.fetchMatch(widget.matchId);
    repo.subscribeMatch(widget.matchId);
  }

  @override
  void dispose() {
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
          final match = snap.data;
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
        SliverToBoxAdapter(child: _SectionHead(title: 'Stats', icon: Icons.bar_chart)),
        SliverToBoxAdapter(child: _StatsBlock(matchId: match.id)),
        SliverToBoxAdapter(child: _SectionHead(title: 'Key moments', icon: Icons.timeline)),
        SliverToBoxAdapter(child: _EventsBlock(matchId: match.id, homeTeamId: match.homeTeam.id)),
        SliverToBoxAdapter(child: _SectionHead(title: 'Line-ups', icon: Icons.group)),
        SliverToBoxAdapter(child: _LineupsBlock(matchId: match.id)),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
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
            onPressed: () => SharePlus.instance.share(
              ShareParams(text: '${match.homeTeam.name} vs ${match.awayTeam.name}'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── HERO ──────────────────────────────────────────────────────────────────

class _Hero extends StatelessWidget {
  const _Hero({required this.match});
  final MatchDto match;
  @override
  Widget build(BuildContext context) {
    final showScore = match.isLive || match.isFinished;
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
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [Color(0x33A0E1B5), Colors.transparent],
                      center: Alignment(0, -1),
                      radius: 0.8,
                    ),
                  ),
                ),
              ),
            ),
            Column(
              children: [
                if (match.isLive)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const LiveDot(),
                      const SizedBox(width: 6),
                      Text(
                        match.status == MatchStatus.HALF_TIME ? 'HT' : "${match.minute ?? 0}'",
                        style: const TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontFamilyFallback: ['SF Mono', 'Menlo', 'monospace'],
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.live,
                          letterSpacing: 1.65,
                        ),
                      ),
                    ],
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
                            const SizedBox(width: 10),
                            Container(width: 4, height: 4, decoration: const BoxDecoration(color: AppColors.muted2, shape: BoxShape.circle)),
                            const SizedBox(width: 10),
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

class _LineupsBlock extends ConsumerWidget {
  const _LineupsBlock({required this.matchId});
  final String matchId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(matchLineupsProvider(matchId));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: async.when(
        loading: () => const Skeleton(height: 220, radius: 16),
        error: (_, __) => const _SectionEmpty(text: 'Line-ups temporarily unavailable.'),
        data: (lineups) {
          if (lineups.isEmpty) {
            return const _SectionEmpty(
              text: 'Line-ups confirmed about an hour before kickoff.',
            );
          }
          return Column(
            children: [
              for (final l in lineups) ...[
                _LineupCard(lineup: l),
                const SizedBox(height: 10),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _LineupCard extends StatelessWidget {
  const _LineupCard({required this.lineup});
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
              if (lineup.teamLogo != null) ...[
                SizedBox(
                  width: 22, height: 22,
                  child: PremiumImage(url: lineup.teamLogo, fit: BoxFit.contain),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  lineup.teamName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.fg,
                  ),
                ),
              ),
              if (lineup.formation.isNotEmpty) Eyebrow(lineup.formation, gold: true, size: 10),
            ],
          ),
          const SizedBox(height: 10),
          if (lineup.startXI.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: lineup.startXI
                  .map((p) => _PlayerChip(name: p.name, number: p.number ?? 0, position: p.pos))
                  .toList(),
            )
          else
            const _SectionEmpty(text: 'Line-up not announced yet.'),
          if (lineup.substitutes.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Eyebrow('Substitutes', size: 9),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: lineup.substitutes
                  .map((p) => _PlayerChip(name: p.name, number: p.number ?? 0, position: p.pos, sub: true))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlayerChip extends StatelessWidget {
  const _PlayerChip({required this.name, required this.number, required this.position, this.sub = false});
  final String name;
  final int number;
  final String position;
  final bool sub;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(99),
        color: sub ? AppColors.surface2 : AppColors.surface3,
        border: Border.all(color: sub ? AppColors.borderSoft : AppColors.goldHairline.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 18,
            child: Text(
              '$number',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontFamilyFallback: const ['SF Mono', 'Menlo', 'monospace'],
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: sub ? AppColors.muted : AppColors.gold,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            name,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.fg,
            ),
          ),
        ],
      ),
    );
  }
}

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
