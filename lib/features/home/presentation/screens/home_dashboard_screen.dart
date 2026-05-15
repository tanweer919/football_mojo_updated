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
import '../../../competitions/data/competitions_repository.dart';
import '../../../fantasy/data/models/fantasy_models.dart';
import '../../../fantasy/presentation/providers/fantasy_providers.dart';
import '../../../news/data/models/news_article.dart';
import '../../../news/presentation/providers/news_feed_provider.dart';
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
            const SizedBox(height: 8),
            _SectionHead(
              title: 'Live now',
              action: 'All matches →',
              onAction: () => context.push(RoutePaths.matches),
            ),
            const SizedBox(height: 10),
            const _LiveStrip(),
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
          return const _StripEmpty(
            title: 'Quiet across the leagues',
            subtitle: 'No live matches right now — the moment something kicks off, it lands here.',
            glyph: EmptyGlyph.football,
          );
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
