import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/widgets/empty_states.dart';
import '../../../../core/widgets/eyebrow.dart';
import '../../../../core/widgets/live_dot.dart';
import '../../../../core/widgets/loading_skeletons.dart';
import '../../../../core/widgets/pitch_buttons.dart';
import '../../../../core/widgets/premium_image.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../../core/widgets/pcard.dart';
import '../../../album/data/models/card_models.dart' show CardRarity;
import '../../../competitions/data/competitions_repository.dart';
import '../../../fantasy/data/models/fantasy_models.dart';
import '../../../fantasy/presentation/providers/fantasy_providers.dart';
import '../../../insights/data/standings_repository.dart';
import '../../../market/data/market_models.dart';
import '../../../market/data/market_repository.dart';
import '../../../news/data/models/news_article.dart';
import '../../../news/presentation/providers/news_feed_provider.dart';
import '../../../profile/data/profile_models.dart' show ProfileTeam;
import '../../../profile/data/profile_repository.dart' show myProfileProvider;
import '../../../scores/data/models/match_dto.dart';
import '../../../scores/presentation/providers/live_matches_provider.dart';
import '../providers/home_dashboard_providers.dart';

/// PITCH home dashboard. Layout matches `design-specs/android/home.html`,
/// wired entirely to live providers — no mock content.
class HomeDashboardScreen extends ConsumerStatefulWidget {
  const HomeDashboardScreen({super.key});
  @override
  ConsumerState<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends ConsumerState<HomeDashboardScreen> {
  Timer? _tick;
  Duration _wcCountdown = _initialWcCountdown();

  static Duration _initialWcCountdown() {
    final now = DateTime.now();
    final wc = DateTime(2026, 6, 11, 16, 0);
    final d = wc.difference(now);
    return d.isNegative ? Duration.zero : d;
  }

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _wcCountdown = _initialWcCountdown());
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('EEEE · d MMM').format(DateTime.now());

    return RefreshIndicator(
      color: AppColors.gold,
      backgroundColor: AppColors.surface3,
      onRefresh: () async {
        ref.invalidate(liveMatchesProvider);
        ref.invalidate(homeFixturesProvider);
        ref.invalidate(newsFeedProvider);
        await Future.wait<dynamic>([
          ref.read(liveMatchesProvider.future),
          ref.read(homeFixturesProvider.future),
          ref.read(newsFeedProvider.future),
        ]);
      },
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: const EdgeInsets.only(bottom: 110),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: MediaQuery.viewPaddingOf(context).top),
            const _Appbar(),
            const SizedBox(height: 6),
            _Greeting(dateLabel: dateLabel),
            const SizedBox(height: 12),
            _WcHero(remaining: _wcCountdown),

            // Your teams — either the followed-team digest or a prompt
            // to pick teams. Sits between the WC hero and the rest of
            // the dashboard because following is the single biggest
            // signal we have for what content the user cares about.
            const _YourTeamsSection(),

            // Pre-WC hype strip — three primary CTAs to get an empty-feeling
            // home page into the rest of the product. Lives directly under
            // the countdown so it's the first thing users tap into once
            // they're not interrupted by a live match.
            const _SectionHead(title: 'Get ready'),
            const SizedBox(height: 8),
            const _PreWcHypeStrip(),

            const SizedBox(height: 8),
            _SectionHead(
              title: 'Live now',
              action: 'All matches →',
              onAction: () => context.push(RoutePaths.matches),
            ),
            const SizedBox(height: 10),
            const _LiveStrip(),

            // European leagues — recent results + upcoming fixtures grouped
            // by competition. Always rich pre-WC because PL/LaLiga/Serie A/
            // Bundesliga/Ligue 1 + UCL/UEL run from August to late May.
            const SizedBox(height: 16),
            _SectionHead(
              title: 'European leagues',
              action: 'Full schedule →',
              onAction: () => context.push(RoutePaths.matches),
            ),
            const SizedBox(height: 10),
            const _LeagueDigest(),

            // Group spotlight — surfaces the seeded WC2026 standings so
            // pre-tournament the home page already shows draw structure.
            const SizedBox(height: 8),
            _SectionHead(
              title: 'World Cup groups',
              action: 'All groups →',
              onAction: () => context.push(RoutePaths.standings),
            ),
            const SizedBox(height: 10),
            const _GroupSpotlight(),

            // Featured Iconic / Legendary cards — pulled from the seeded
            // market catalogue (works pre-WC because cards are seeded).
            const SizedBox(height: 16),
            _SectionHead(
              title: 'Featured cards',
              action: 'Market →',
              onAction: () => context.push('/market'),
            ),
            const SizedBox(height: 10),
            const _FeaturedCardsStrip(),

            const SizedBox(height: 16),
            _SectionHead(
              title: 'Your form',
              action: 'Manager →',
              onAction: () => context.push(RoutePaths.fantasyHome),
            ),
            const SizedBox(height: 14),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: _FantasyCard(),
            ),
            const SizedBox(height: 24),
            _SectionHead(
              title: "Today's stories",
              action: 'All news →',
              onAction: () => context.push(RoutePaths.news),
            ),
            const SizedBox(height: 14),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: _NewsList(),
            ),
            const SizedBox(height: 24),
            _SectionHead(
              title: 'Coming up',
              action: 'Schedule →',
              onAction: () => context.push(RoutePaths.matches),
            ),
            const SizedBox(height: 14),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: _UpcomingList(),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// APPBAR
// ─────────────────────────────────────────────────────────────────────────────

class _Appbar extends StatelessWidget {
  const _Appbar();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
      child: Row(
        children: [
          Container(
            width: 22, height: 22,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Color(0xFFF1E4B6), Color(0xFFE5C26B), Color(0xFF8E6422)],
                stops: [0.2, 0.6, 1.0],
                center: Alignment(-0.3, -0.4),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ShaderMask(
            shaderCallback: (rect) => const LinearGradient(
              colors: [AppColors.goldSoft, AppColors.goldDeep],
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
            ).createShader(rect),
            child: const Text(
              'PITCH',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.36,
                color: Colors.white,
              ),
            ),
          ),
          const Spacer(),
          CircleIconButton(icon: Icons.notifications_outlined, onPressed: () {}),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => context.push(RoutePaths.profile),
            child: const _AppbarAvatar(),
          ),
        ],
      ),
    );
  }
}

class _AppbarAvatar extends StatelessWidget {
  const _AppbarAvatar();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36, height: 36,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFFC99A3D), Color(0xFF7E5A1F)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.person_outline, color: Color(0xFF1E1810), size: 18),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GREETING
// ─────────────────────────────────────────────────────────────────────────────

class _Greeting extends StatelessWidget {
  const _Greeting({required this.dateLabel});
  final String dateLabel;
  @override
  Widget build(BuildContext context) {
    const h1Style = TextStyle(
      fontFamily: 'Inter',
      fontSize: 26,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.91,
      color: AppColors.fg,
      height: 1.1,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Eyebrow(dateLabel),
          const SizedBox(height: 6),
          RichText(
            text: const TextSpan(
              style: h1Style,
              children: [
                TextSpan(text: 'Welcome back to\n'),
                TextSpan(
                  text: 'PITCH.',
                  style: TextStyle(
                    fontFamily: 'IowanOldStyle',
                    fontFamilyFallback: ['Charter', 'Georgia', 'serif'],
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w500,
                    fontSize: 26,
                    color: AppColors.gold,
                    letterSpacing: -0.91,
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

// ─────────────────────────────────────────────────────────────────────────────
// WC HERO (real countdown to 11 Jun 2026)
// ─────────────────────────────────────────────────────────────────────────────

class _WcHero extends StatelessWidget {
  const _WcHero({required this.remaining});
  final Duration remaining;
  @override
  Widget build(BuildContext context) {
    final days = remaining.inDays;
    final hours = remaining.inHours % 24;
    final mins = remaining.inMinutes % 60;
    final secs = remaining.inSeconds % 60;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF211D17), Color(0xFF110F0D)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(AppRadii.r5),
          border: Border.all(color: AppColors.goldHairline),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.7),
              blurRadius: 60,
              offset: const Offset(0, 32),
              spreadRadius: -28,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Text('★ ', style: TextStyle(color: AppColors.goldDeep, fontSize: 11, height: 1)),
                Eyebrow('FIFA WORLD CUP 2026', gold: true, size: 11),
              ],
            ),
            const SizedBox(height: 18),
            RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.2,
                  color: AppColors.fg,
                  height: 1.0,
                ),
                children: [
                  const TextSpan(text: 'The world\nplays in '),
                  TextSpan(
                    text: '${days.clamp(0, 999)} days',
                    style: const TextStyle(
                      fontFamily: 'IowanOldStyle',
                      fontFamilyFallback: ['Charter', 'Georgia', 'serif'],
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w500,
                      color: AppColors.gold,
                      fontSize: 30,
                    ),
                  ),
                  const TextSpan(text: '.'),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Eyebrow('United States · Canada · Mexico · 16 cities'),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(child: _CountdownCell(n: days,  l: 'Days')),
                const SizedBox(width: 6),
                Expanded(child: _CountdownCell(n: hours, l: 'Hours')),
                const SizedBox(width: 6),
                Expanded(child: _CountdownCell(n: mins,  l: 'Min')),
                const SizedBox(width: 6),
                Expanded(child: _CountdownCell(n: secs,  l: 'Sec')),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: GoldButton(
                    label: 'Enter Global Cup',
                    onPressed: () => context.push(RoutePaths.fantasyHome),
                    expand: true,
                  ),
                ),
                const SizedBox(width: 8),
                GhostButton(
                  label: 'View bracket',
                  onPressed: () => context.push(RoutePaths.tournament),
                  small: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CountdownCell extends StatelessWidget {
  const _CountdownCell({required this.n, required this.l});
  final int n;
  final String l;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0x8C0F0E0D),
        borderRadius: BorderRadius.circular(AppRadii.r2),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        children: [
          Text(
            n.toString().padLeft(2, '0'),
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.04,
              color: AppColors.gold,
              height: 1.0,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 6),
          Eyebrow(l, size: 9),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION HEAD
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHead extends StatelessWidget {
  const _SectionHead({required this.title, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
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
          const Spacer(),
          if (action != null)
            GestureDetector(onTap: onAction, child: Eyebrow(action!, gold: true)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LIVE STRIP — wired to liveMatchesProvider
// ─────────────────────────────────────────────────────────────────────────────

class _LiveStrip extends ConsumerWidget {
  const _LiveStrip();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final live = ref.watch(liveMatchesProvider);
    return live.when(
      loading: () => SizedBox(
        height: 168,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: 3,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (_, __) => const SizedBox(width: 240, child: MatchCardSkeleton()),
        ),
      ),
      error: (e, _) => const _StripEmpty(
        title: 'Live scores paused',
        subtitle: 'Couldn’t reach the score feed. Pull to refresh.',
        glyph: EmptyGlyph.football,
      ),
      data: (matches) {
        if (matches.isEmpty) {
          // No live matches in this very moment. Don't editorialise about
          // the season — there are usually matches kicking off in a few
          // hours regardless of the time of year. The European leagues
          // section below has results + fixtures so home isn't dry.
          return const _NoLiveNowTile();
        }
        return SizedBox(
          height: 168,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            physics: const BouncingScrollPhysics(),
            itemCount: matches.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) => _LiveCard(match: matches[i]),
          ),
        );
      },
    );
  }
}

class _StripEmpty extends StatelessWidget {
  const _StripEmpty({
    required this.title,
    required this.subtitle,
    this.glyph = EmptyGlyph.football,
  });
  final String title;
  final String subtitle;
  final EmptyGlyph glyph;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.r4),
          border: Border.all(color: AppColors.borderSoft),
          gradient: const LinearGradient(
            colors: [AppColors.surface2, AppColors.surface],
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
          ),
        ),
        child: PitchEmptyState(title: title, subtitle: subtitle, glyph: glyph),
      ),
    );
  }
}

class _LiveCard extends StatelessWidget {
  const _LiveCard({required this.match});
  final MatchDto match;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push('/matches/${match.id}'),
      child: Container(
        width: 240,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.surface2, AppColors.surface],
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(AppRadii.r4),
          border: Border.all(color: AppColors.borderSoft),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: Eyebrow('LIVE', size: 9)),
                if (match.isLive) const LiveDot(),
              ],
            ),
            const SizedBox(height: 12),
            _LiveRow(team: match.homeTeam, score: match.homeScore, winning: match.homeScore > match.awayScore),
            const SizedBox(height: 6),
            _LiveRow(team: match.awayTeam, score: match.awayScore, winning: match.awayScore > match.homeScore),
            const Spacer(),
            Text(
              "${match.minute ?? 0}'",
              style: const TextStyle(
                fontFamily: 'JetBrainsMono',
                fontFamilyFallback: ['SF Mono', 'Menlo', 'monospace'],
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
                color: AppColors.pitch,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveRow extends StatelessWidget {
  const _LiveRow({required this.team, required this.score, required this.winning});
  final TeamDto team;
  final int score;
  final bool winning;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 22, height: 16,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: PremiumImage(url: team.crestUrl, fit: BoxFit.contain),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            team.shortName ?? team.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: AppColors.fg,
            ),
          ),
        ),
        Text(
          score.toString(),
          style: TextStyle(
            fontFamily: 'JetBrainsMono',
            fontFamilyFallback: const ['SF Mono', 'Menlo', 'monospace'],
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: winning ? AppColors.gold : AppColors.fg,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FANTASY CARD — wired to currentGameweek + myLineup
// ─────────────────────────────────────────────────────────────────────────────

class _FantasyCard extends ConsumerWidget {
  const _FantasyCard();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slug = ref.watch(defaultFantasySlugProvider);
    final tournament = ref.watch(tournamentProvider(slug));
    final gw = ref.watch(currentGameweekProvider(slug));
    final lineupAsync = gw.maybeWhen<AsyncValue<FantasyLineupDto?>>(
      data: (g) => g == null
          ? const AsyncValue.data(null)
          : ref.watch(myLineupProvider((slug: slug, gameweekId: g.id))),
      orElse: () => const AsyncValue.data(null),
    );

    return tournament.when(
      loading: () => const Skeleton(height: 200, radius: 20),
      error: (_, __) => const _FantasyEmpty(),
      data: (t) {
        final gameweekNum = gw.valueOrNull?.number;
        final lineup = lineupAsync.valueOrNull;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => context.push(RoutePaths.fantasyHome),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1F1814), Color(0xFF110C09)],
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(AppRadii.r4),
              border: Border.all(color: AppColors.goldHairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        gameweekNum == null
                            ? t.name
                            : '${t.name} · GW $gameweekNum',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.22,
                          color: AppColors.fg,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    ShaderMask(
                      shaderCallback: (r) => const LinearGradient(
                        colors: [AppColors.goldSoft, AppColors.goldDeep],
                        begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      ).createShader(r),
                      child: Text(
                        lineup?.rank?.toString() ?? '—',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 48,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1.92,
                          color: Colors.white,
                          height: 1.0,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Eyebrow(
                        lineup == null ? 'No lineup yet' : 'Manager rank',
                        size: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(height: 1, color: AppColors.borderSoft),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _FantasyStat(
                        v: lineup?.totalPoints.toStringAsFixed(0) ?? '0',
                        l: 'GW points',
                      ),
                    ),
                    Expanded(
                      child: _FantasyStat(
                        v: lineup == null
                            ? 'Build XI'
                            : (lineup.locked ? 'Locked' : 'Editable'),
                        l: 'Status',
                      ),
                    ),
                    Expanded(
                      child: _FantasyStat(
                        v: lineup?.budgetUsed.toStringAsFixed(1) ?? '0',
                        l: 'Spent',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FantasyEmpty extends StatelessWidget {
  const _FantasyEmpty();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1F1814), Color(0xFF110C09)],
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(AppRadii.r4),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: const Text(
        'No active fantasy gameweek yet — check back soon.',
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          color: AppColors.muted,
          height: 1.5,
        ),
      ),
    );
  }
}

class _FantasyStat extends StatelessWidget {
  const _FantasyStat({required this.v, required this.l});
  final String v;
  final String l;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          v,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.24,
            color: AppColors.fg,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 4),
        Eyebrow(l, size: 9),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NEWS LIST — wired to newsFeedProvider
// ─────────────────────────────────────────────────────────────────────────────

class _NewsList extends ConsumerWidget {
  const _NewsList();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(newsFeedProvider);
    return feed.when(
      loading: () => Column(
        children: List.generate(3, (_) => const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: NewsTileSkeleton(),
        )),
      ),
      error: (_, __) => const _ListEmpty(
        title: 'News on a tea break',
        subtitle: 'Couldn’t reach the news feed. Pull to refresh.',
        glyph: EmptyGlyph.paper,
      ),
      data: (page) {
        if (page.items.isEmpty) {
          return const _ListEmpty(
            title: 'No stories yet',
            subtitle: 'Sources update every 10 minutes — fresh headlines land here automatically.',
            glyph: EmptyGlyph.paper,
          );
        }
        final items = page.items.take(3).toList();
        return Column(
          children: [
            for (int i = 0; i < items.length; i++) ...[
              if (i > 0) Container(height: 1, color: AppColors.borderSoft),
              _NewsItem(article: items[i]),
            ],
          ],
        );
      },
    );
  }
}

class _NewsItem extends StatelessWidget {
  const _NewsItem({required this.article});
  final NewsArticleDto article;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push('/news/${article.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 88, height: 88,
                child: PremiumImage(url: article.imageUrl, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Eyebrow(article.source, gold: true, size: 9),
                  const SizedBox(height: 4),
                  Text(
                    article.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.21,
                      color: AppColors.fg,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Eyebrow(
                    DateFormat('d MMM').format(article.publishedAt.toLocal()),
                    size: 10,
                    color: AppColors.muted2,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// UPCOMING — wired to homeFixturesProvider
// ─────────────────────────────────────────────────────────────────────────────

class _UpcomingList extends ConsumerWidget {
  const _UpcomingList();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fixtures = ref.watch(homeFixturesProvider);
    return fixtures.when(
      loading: () => Column(
        children: List.generate(2, (_) => const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: MatchCardSkeleton(),
        )),
      ),
      error: (_, __) => const _ListEmpty(
        title: 'Schedule unavailable',
        subtitle: 'Couldn’t load fixtures right now. Pull to refresh.',
        glyph: EmptyGlyph.football,
      ),
      data: (f) {
        final list = f.upcoming.take(3).toList();
        if (list.isEmpty) {
          return const _ListEmpty(
            title: 'No matches in the next 48h',
            subtitle: 'Quiet on the calendar. Big-Five, UCL and WC fixtures land here automatically.',
            glyph: EmptyGlyph.football,
          );
        }
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.surface2, AppColors.surface],
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(AppRadii.r4),
            border: Border.all(color: AppColors.borderSoft),
          ),
          child: Column(
            children: [
              for (int i = 0; i < list.length; i++) ...[
                if (i > 0) const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Divider(height: 1),
                ),
                _UpcomingRow(match: list[i]),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _UpcomingRow extends StatelessWidget {
  const _UpcomingRow({required this.match});
  final MatchDto match;
  @override
  Widget build(BuildContext context) {
    final df = DateFormat('EEE · HH:mm');
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push('/matches/${match.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 28, height: 28,
              child: PremiumImage(url: match.homeTeam.crestUrl, fit: BoxFit.contain),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${match.homeTeam.shortName ?? match.homeTeam.name}  vs  ${match.awayTeam.shortName ?? match.awayTeam.name}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.fg,
                  letterSpacing: -0.13,
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 28, height: 28,
              child: PremiumImage(url: match.awayTeam.crestUrl, fit: BoxFit.contain),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  df.format(match.kickoffAt.toLocal()),
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.fg,
                  ),
                ),
                const SizedBox(height: 2),
                Eyebrow(
                  DateFormat('d MMM').format(match.kickoffAt.toLocal()),
                  size: 9,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ListEmpty extends StatelessWidget {
  const _ListEmpty({
    required this.title,
    required this.subtitle,
    this.glyph = EmptyGlyph.football,
  });
  final String title;
  final String subtitle;
  final EmptyGlyph glyph;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.r4),
        border: Border.all(color: AppColors.borderSoft),
        gradient: const LinearGradient(
          colors: [AppColors.surface2, AppColors.surface],
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
        ),
      ),
      child: PitchEmptyState(title: title, subtitle: subtitle, glyph: glyph),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PRE-WC HYPE STRIP — 3 large CTA cards under the countdown
// ─────────────────────────────────────────────────────────────────────────────

/// Three horizontally-scrolling action cards that turn the gap between
/// "European season done" and "WC kicks off" into productive engagement.
/// Each card is one tap from a real product surface (fantasy, market,
/// predictions) — they're not just dead promo art.
class _PreWcHypeStrip extends StatelessWidget {
  const _PreWcHypeStrip();
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 148,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        physics: const BouncingScrollPhysics(),
        children: [
          _HypeCard(
            eyebrow: 'Fantasy',
            title: 'Draft your\nGlobal Cup XI',
            body: 'Pick 5. Captain doubles. Locks at kickoff on 11 Jun.',
            icon: Icons.shield_outlined,
            tint: AppColors.gold,
            onTap: () => context.push(RoutePaths.fantasyHome),
          ),
          const SizedBox(width: 10),
          _HypeCard(
            eyebrow: 'Cards',
            title: 'Mint your\nfirst Iconic',
            body: 'Browse the catalogue. Free welcome-card on signup.',
            icon: Icons.style_outlined,
            tint: AppColors.pitch,
            onTap: () => context.push('/market'),
          ),
          const SizedBox(width: 10),
          _HypeCard(
            eyebrow: 'Predictions',
            title: 'Call the\nGolden Boot',
            body: 'Stake a guess on group winners + Golden Boot odds.',
            icon: Icons.emoji_events_outlined,
            tint: AppColors.info,
            onTap: () => context.push(RoutePaths.predictionsBoard),
          ),
          const SizedBox(width: 16),
        ],
      ),
    );
  }
}

class _HypeCard extends StatelessWidget {
  const _HypeCard({
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.icon,
    required this.tint,
    required this.onTap,
  });
  final String eyebrow;
  final String title;
  final String body;
  final IconData icon;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 240,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.r4),
          border: Border.all(color: tint.withValues(alpha: 0.35)),
          gradient: LinearGradient(
            colors: [
              tint.withValues(alpha: 0.18),
              const Color(0xFF110F0D),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(color: tint.withValues(alpha: 0.15), blurRadius: 18, spreadRadius: -4),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: tint),
                const SizedBox(width: 8),
                Eyebrow(eyebrow, color: tint, size: 10),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.34,
                  color: AppColors.fg,
                  height: 1.12,
                ),
              ),
            ),
            Text(
              body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 11.5,
                color: AppColors.muted,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LIVE STRIP — pre-WC empty state
// ─────────────────────────────────────────────────────────────────────────────

/// Replacement for the generic "no live matches" tile during the pre-WC
/// dead period. Frames the silence as "the world's about to start" and
/// pushes the user into fantasy / cards / predictions instead of leaving
/// a flat empty card.
/// Compact "no live right now" tile. Neutral — no claims about the season
/// being over (which was the wrong call: PL/LaLiga/Bundesliga/Serie A/
/// Ligue 1 all run August → late May and UCL knockouts span the spring).
/// The European-leagues digest under this tile is where users go next.
class _NoLiveNowTile extends StatelessWidget {
  const _NoLiveNowTile();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.r4),
          border: Border.all(color: AppColors.borderSoft),
          color: AppColors.surface2,
        ),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: AppColors.muted2.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.borderSoft),
              ),
              child: const Icon(Icons.schedule, color: AppColors.muted, size: 18),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'No matches kicking off right now.\nResults + next fixtures below.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12.5,
                  color: AppColors.muted,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EUROPEAN LEAGUES DIGEST — recent results + upcoming fixtures per league
// ─────────────────────────────────────────────────────────────────────────────

/// Groups the home fixtures window (yesterday → day-after) by `competitionId`
/// and renders one card per league with results above, next-up below. Three
/// competitions on screen at once keeps the home page legible without
/// turning into a fixture list. Order is leagues with content first.
class _LeagueDigest extends ConsumerWidget {
  const _LeagueDigest();

  /// Friendly names for the seeded competition codes. Anything not in this
  /// map falls back to the raw id (e.g., a new league added later).
  static const _competitionNames = <String, String>{
    'PL_2025':       'Premier League',
    'LALIGA_2025':   'La Liga',
    'BUNDESLIGA_2025': 'Bundesliga',
    'SERIEA_2025':   'Serie A',
    'LIGUE1_2025':   'Ligue 1',
    'UCL_2025':      'UEFA Champions League',
    'UEL_2025':      'UEFA Europa League',
    'WC2026':        'FIFA World Cup 2026',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(homeFixturesProvider);
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Skeleton(height: 220, radius: 16),
      ),
      error: (_, __) => const _StripEmpty(
        title: 'League schedule unavailable',
        subtitle: 'Couldn’t reach the fixtures feed. Pull to refresh.',
      ),
      data: (f) {
        // Group recent + upcoming by competitionId. Skip the WC: it has
        // its own spotlight section below.
        final byComp = <String, _CompBucket>{};
        for (final m in f.recent) {
          if (m.competitionId == 'WC2026') continue;
          byComp.putIfAbsent(m.competitionId, () => _CompBucket()).recent.add(m);
        }
        for (final m in f.upcoming) {
          if (m.competitionId == 'WC2026') continue;
          byComp.putIfAbsent(m.competitionId, () => _CompBucket()).upcoming.add(m);
        }
        if (byComp.isEmpty) {
          return const _StripEmpty(
            title: 'No European fixtures in the window',
            subtitle: 'No matches between yesterday and the day after tomorrow. Check back closer to the weekend.',
          );
        }
        // Sort: leagues with the most rows first (gives the user the most
        // immediately interesting content up top). Cap at 3 cards on home.
        final ranked = byComp.entries.toList()
          ..sort((a, b) => (b.value.total).compareTo(a.value.total));
        final top = ranked.take(3).toList();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              for (var i = 0; i < top.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                _LeagueCard(
                  name: _competitionNames[top[i].key] ?? top[i].key,
                  competitionId: top[i].key,
                  bucket: top[i].value,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _CompBucket {
  final List<MatchDto> recent = [];
  final List<MatchDto> upcoming = [];
  int get total => recent.length + upcoming.length;
}

class _LeagueCard extends StatelessWidget {
  const _LeagueCard({
    required this.name,
    required this.competitionId,
    required this.bucket,
  });
  final String name;
  final String competitionId;
  final _CompBucket bucket;

  @override
  Widget build(BuildContext context) {
    // Show up to 2 of each. Picking the most recent results and the most
    // imminent fixtures keeps the card scannable.
    final results = bucket.recent.take(2).toList();
    final fixtures = bucket.upcoming.take(2).toList();
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.r4),
        border: Border.all(color: AppColors.borderSoft),
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1815), Color(0xFF120F0D)],
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // League title row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                      color: AppColors.fg,
                    ),
                  ),
                ),
                Eyebrow(
                  '${bucket.recent.length} result${bucket.recent.length == 1 ? '' : 's'} · ${bucket.upcoming.length} up next',
                  size: 9,
                ),
              ],
            ),
          ),
          if (results.isNotEmpty) ...[
            Container(height: 1, color: AppColors.borderSoft),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: const Eyebrow('Results', gold: true, size: 9),
            ),
            for (final m in results) _LeagueResultRow(match: m),
          ],
          if (fixtures.isNotEmpty) ...[
            Container(height: 1, color: AppColors.borderSoft),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: const Eyebrow('Next up', gold: true, size: 9),
            ),
            for (final m in fixtures) _LeagueFixtureRow(match: m),
          ],
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

/// Finished match — both crests, score, "FT" tag.
class _LeagueResultRow extends StatelessWidget {
  const _LeagueResultRow({required this.match});
  final MatchDto match;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push('/matches/${match.id}'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
        child: Row(
          children: [
            _TeamCellInline(team: match.homeTeam, alignEnd: true),
            const SizedBox(width: 10),
            // Score block — bolder side = winner so users scan the table
            // and see who won at a glance.
            _ScoreBlock(
              home: match.homeScore,
              away: match.awayScore,
              winner: match.homeScore > match.awayScore
                  ? _Winner.home
                  : match.awayScore > match.homeScore
                      ? _Winner.away
                      : _Winner.draw,
            ),
            const SizedBox(width: 10),
            _TeamCellInline(team: match.awayTeam, alignEnd: false),
          ],
        ),
      ),
    );
  }
}

/// Pre-kickoff match — short kickoff time replaces the score.
class _LeagueFixtureRow extends StatelessWidget {
  const _LeagueFixtureRow({required this.match});
  final MatchDto match;
  @override
  Widget build(BuildContext context) {
    final df = DateFormat('EEE HH:mm');
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push('/matches/${match.id}'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
        child: Row(
          children: [
            _TeamCellInline(team: match.homeTeam, alignEnd: true),
            const SizedBox(width: 10),
            Container(
              constraints: const BoxConstraints(minWidth: 70),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surface3,
                borderRadius: BorderRadius.circular(AppRadii.r2),
                border: Border.all(color: AppColors.borderSoft),
              ),
              alignment: Alignment.center,
              child: Text(
                df.format(match.kickoffAt.toLocal()),
                style: const TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontFamilyFallback: ['SF Mono', 'Menlo', 'monospace'],
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.fg,
                ),
              ),
            ),
            const SizedBox(width: 10),
            _TeamCellInline(team: match.awayTeam, alignEnd: false),
          ],
        ),
      ),
    );
  }
}

enum _Winner { home, away, draw }

class _ScoreBlock extends StatelessWidget {
  const _ScoreBlock({required this.home, required this.away, required this.winner});
  final int home;
  final int away;
  final _Winner winner;
  @override
  Widget build(BuildContext context) {
    final style = const TextStyle(
      fontFamily: 'JetBrainsMono',
      fontFamilyFallback: ['SF Mono', 'Menlo', 'monospace'],
      fontSize: 13,
      fontWeight: FontWeight.w800,
      color: AppColors.fg,
    );
    final dim = const TextStyle(
      fontFamily: 'JetBrainsMono',
      fontFamilyFallback: ['SF Mono', 'Menlo', 'monospace'],
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: AppColors.muted,
    );
    return Container(
      constraints: const BoxConstraints(minWidth: 70),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface3,
        borderRadius: BorderRadius.circular(AppRadii.r2),
        border: Border.all(color: AppColors.borderSoft),
      ),
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$home', style: winner == _Winner.home ? style : dim),
          const SizedBox(width: 6),
          Text(':', style: dim),
          const SizedBox(width: 6),
          Text('$away', style: winner == _Winner.away ? style : dim),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// YOUR TEAMS — followed-team digest or first-time pick prompt
// ─────────────────────────────────────────────────────────────────────────────

/// Two states:
///   - User follows ≥1 team → "Your teams" rail of crests + fixtures
///     filtered to their teams.
///   - User follows 0 teams → an attention-grabbing prompt that opens
///     the team picker. Sits at the top of the dashboard so the user
///     sees it on first visit without scrolling.
class _YourTeamsSection extends ConsumerWidget {
  const _YourTeamsSection();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(myProfileProvider);
    return profileAsync.maybeWhen(
      data: (p) {
        final teams = p?.followedTeams ?? const <ProfileTeam>[];
        if (teams.isEmpty) return const _PickTeamsPrompt();
        return _FollowedTeamsRail(teams: teams);
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

/// Bright gold-bordered tile inviting the user to pick teams. Tappable
/// over the whole surface so it's hard to miss.
class _PickTeamsPrompt extends StatelessWidget {
  const _PickTeamsPrompt();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => context.push(RoutePaths.teamPicker),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.r4),
            border: Border.all(color: AppColors.goldHairline),
            gradient: LinearGradient(
              colors: [
                AppColors.gold.withValues(alpha: 0.18),
                const Color(0xFF110F0D),
              ],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.gold.withValues(alpha: 0.15),
                blurRadius: 24,
                spreadRadius: -6,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.gold.withValues(alpha: 0.22),
                  border: Border.all(color: AppColors.goldHairline),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.favorite_outline, color: AppColors.gold, size: 20),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Eyebrow('Personalise your home', gold: true, size: 10),
                    SizedBox(height: 4),
                    Text(
                      'Pick teams you follow.',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.24,
                        color: AppColors.fg,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Their fixtures, results and lineups jump to the top.',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: AppColors.muted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: AppColors.gold),
            ],
          ),
        ),
      ),
    );
  }
}

/// Followed-team digest. Top row: the crests of every followed team in a
/// horizontal scroll (tappable to manage). Below: a single condensed row
/// per team showing its next fixture or latest result.
class _FollowedTeamsRail extends ConsumerWidget {
  const _FollowedTeamsRail({required this.teams});
  final List<ProfileTeam> teams;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.r4),
          border: Border.all(color: AppColors.goldHairline.withValues(alpha: 0.5)),
          gradient: const LinearGradient(
            colors: [Color(0xFF1A1815), Color(0xFF110F0D)],
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Eyebrow('Your teams', gold: true, size: 10),
                const Spacer(),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => context.push(RoutePaths.teamPicker),
                  child: const Row(
                    children: [
                      Icon(Icons.tune, size: 14, color: AppColors.gold),
                      SizedBox(width: 4),
                      Text(
                        'Manage',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.gold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Crest scroller — clip teams to a reasonable max.
            SizedBox(
              height: 54,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: teams.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) => _CrestPill(team: teams[i]),
              ),
            ),
            const SizedBox(height: 8),
            // Per-team result/fixture row — pulled from homeFixturesProvider.
            _FollowedTeamFixtures(teamIds: teams.map((t) => t.id).toSet()),
          ],
        ),
      ),
    );
  }
}

class _CrestPill extends StatelessWidget {
  const _CrestPill({required this.team});
  final ProfileTeam team;
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36, height: 36,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surface2,
            border: Border.all(color: AppColors.borderSoft),
          ),
          child: PremiumImage(url: team.crestUrl, fit: BoxFit.contain),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 50,
          child: Text(
            team.shortName,
            maxLines: 1,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: AppColors.fgSoft,
            ),
          ),
        ),
      ],
    );
  }
}

/// Filters the home fixture window to only matches involving a followed
/// team. Picks the most relevant one per team (next upcoming fixture,
/// or most recent result if none coming up). Up to 3 rows on home.
class _FollowedTeamFixtures extends ConsumerWidget {
  const _FollowedTeamFixtures({required this.teamIds});
  final Set<String> teamIds;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (teamIds.isEmpty) return const SizedBox.shrink();
    final async = ref.watch(homeFixturesProvider);
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Skeleton(height: 32, radius: 8),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (f) {
        // Match counts as "yours" if either team id matches.
        bool involvesFollowed(MatchDto m) =>
            teamIds.contains(m.homeTeam.id) || teamIds.contains(m.awayTeam.id);
        final upcoming = f.upcoming.where(involvesFollowed).take(2).toList();
        final recent = f.recent.where(involvesFollowed).take(2).toList();
        if (upcoming.isEmpty && recent.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No upcoming fixtures for your teams in the next 48h.',
              style: TextStyle(color: AppColors.muted, fontSize: 11.5, height: 1.4),
            ),
          );
        }
        return Column(
          children: [
            for (final m in upcoming) _LeagueFixtureRow(match: m),
            for (final m in recent) _LeagueResultRow(match: m),
          ],
        );
      },
    );
  }
}

/// Compact crest + short name. `alignEnd: true` flips to right-aligned for
/// the home-team side of a row.
class _TeamCellInline extends StatelessWidget {
  const _TeamCellInline({required this.team, required this.alignEnd});
  final TeamDto team;
  final bool alignEnd;
  @override
  Widget build(BuildContext context) {
    final crest = SizedBox(
      width: 18, height: 18,
      child: PremiumImage(url: team.crestUrl, fit: BoxFit.contain),
    );
    final label = Text(
      team.shortName ?? team.name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
        color: AppColors.fg,
        letterSpacing: -0.13,
      ),
    );
    return Expanded(
      child: Row(
        mainAxisAlignment: alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: alignEnd
            ? [Flexible(child: label), const SizedBox(width: 8), crest]
            : [crest, const SizedBox(width: 8), Flexible(child: label)],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FEATURED CARDS STRIP — pulls Iconic / Legendary cards from the market
// ─────────────────────────────────────────────────────────────────────────────

const MarketFilters _kFeaturedCardsFilter = MarketFilters(
  rarities: {CardRarity.ICONIC, CardRarity.LEGENDARY},
  sort: MarketSort.rarityDesc,
);

/// Horizontal scroll of marquee market cards. Wired to the same provider
/// the Market screen uses so the data is always fresh and consistent.
/// Iconic + Legendary only — they're the rarities worth showcasing on home.
class _FeaturedCardsStrip extends ConsumerWidget {
  const _FeaturedCardsStrip();

  static int _ratingFor(CardRarity r) => switch (r) {
        CardRarity.COMMON => 75,
        CardRarity.UNCOMMON => 79,
        CardRarity.RARE => 84,
        CardRarity.EPIC => 88,
        CardRarity.LEGENDARY => 92,
        CardRarity.ICONIC => 95,
      };

  static String _shortEdition(String edition) {
    final dash = edition.indexOf('-');
    return dash < 0 ? edition : edition.substring(0, dash);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(marketFirstPageProvider(_kFeaturedCardsFilter));
    return SizedBox(
      height: 240,
      child: async.when(
        loading: () => ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: 4,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (_, __) => const SizedBox(width: 140, child: Skeleton(height: 240, radius: 14)),
        ),
        error: (_, __) => const _StripEmpty(
          title: 'Cards unavailable',
          subtitle: 'Couldn’t load the catalogue. Pull to refresh.',
        ),
        data: (page) {
          // Server might be empty if seed:cards hasn't run — surface
          // a CTA instead of a flat blank tile.
          if (page.items.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadii.r4),
                  border: Border.all(color: AppColors.borderSoft),
                  color: AppColors.surface2,
                ),
                child: const Text(
                  'No featured cards yet — run npm run seed:cards in backend/.',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ),
            );
          }
          // Take 8 — enough to scroll, few enough to keep the strip fast.
          final cards = page.items.take(8).toList();
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            physics: const BouncingScrollPhysics(),
            itemCount: cards.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final c = cards[i];
              final p = c.player;
              return SizedBox(
                width: 140,
                child: PCard(
                  rarity: c.rarity,
                  rating: _ratingFor(c.rarity),
                  name: p?.name,
                  position: p?.position,
                  country: p?.country ?? p?.team?.countryCode,
                  photoUrl: p?.photoUrl ?? c.artUrl,
                  clubCrestUrl: p?.team?.crestUrl,
                  leagueLabel: _shortEdition(c.edition),
                  editionLabel: c.edition,
                  onTap: () => context.push('/market/${c.id}'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GROUP SPOTLIGHT — rotating WC group + its 4 teams
// ─────────────────────────────────────────────────────────────────────────────

/// Picks one WC2026 group and renders the four crests in a single card.
/// Rotates based on the day so the home page doesn't feel static across
/// repeat visits — Group A on Monday, Group B on Tuesday, etc.
class _GroupSpotlight extends ConsumerWidget {
  const _GroupSpotlight();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(standingsProvider);
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Skeleton(height: 160, radius: 16),
      ),
      error: (_, __) => const _StripEmpty(
        title: 'Group draws loading',
        subtitle: 'Couldn’t reach the tournament feed. Pull to refresh.',
      ),
      data: (groups) {
        if (groups.isEmpty) {
          return const _StripEmpty(
            title: 'Group draws not seeded yet',
            subtitle: 'Run npm run seed:wc in backend/ to populate the tournament.',
          );
        }
        // Pick a stable group for the current day so it doesn't flicker
        // between rebuilds, but rotates across visits over the week.
        final dayOfYear = DateTime.now().difference(DateTime(DateTime.now().year)).inDays;
        final group = groups[dayOfYear % groups.length];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => context.push(RoutePaths.standings),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadii.r4),
                border: Border.all(color: AppColors.borderSoft),
                gradient: const LinearGradient(
                  colors: [Color(0xFF1A1815), Color(0xFF0F0D0B)],
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Eyebrow(group.name, gold: true, size: 11),
                      const Spacer(),
                      const Text(
                        '→',
                        style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // 4 teams in a 2×2 grid — crest + short name + position
                  // (or "—" when standings haven't started counting yet).
                  Row(
                    children: [
                      for (var i = 0; i < group.rows.length && i < 4; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        Expanded(child: _GroupTeamCell(row: group.rows[i])),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GroupTeamCell extends StatelessWidget {
  const _GroupTeamCell({required this.row});
  final StandingRow row;
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(width: 36, height: 36, child: PremiumImage(url: row.teamLogo, fit: BoxFit.contain)),
        const SizedBox(height: 6),
        Text(
          row.teamName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.fg,
            letterSpacing: -0.1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          row.played > 0 ? '${row.points} pts' : '—',
          style: TextStyle(
            fontFamily: 'JetBrainsMono',
            fontFamilyFallback: const ['SF Mono', 'Menlo', 'monospace'],
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: row.played > 0 ? AppColors.gold : AppColors.muted2,
          ),
        ),
      ],
    );
  }
}
