import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/ads/ad_widgets.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/util/watch_country.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/widgets/empty_states.dart';
import '../../../../core/widgets/eyebrow.dart';
import '../../../../core/widgets/live_dot.dart';
import '../../../../core/widgets/loading_skeletons.dart';
import '../../../../core/widgets/premium_image.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../../core/widgets/pcard.dart';
import '../../../album/data/models/card_models.dart' show CardRarity;
import '../../../competitions/data/competitions_repository.dart';
import '../../../fantasy/data/models/fantasy_models.dart';
import '../../../fantasy/presentation/providers/fantasy_providers.dart';
import '../../../insights/data/insights_repository.dart';
import '../../../insights/data/models/broadcast_dto.dart';
import '../../../insights/data/models/match_event_dto.dart';
import '../../../insights/data/standings_repository.dart';
import '../../../highlights/highlight_link.dart';
import '../../../market/data/market_models.dart';
import '../../../market/data/market_repository.dart';
import '../../../news/data/models/news_article.dart';
import '../../../news/presentation/providers/home_news_provider.dart';
import '../../../predictions/data/predictions_repository.dart';
import '../../../tournament/data/wc2026_bracket.dart' show wc2026TotalPicks;
import '../../../world_cup/data/world_cup_models.dart';
import '../../../world_cup/data/world_cup_repository.dart';
import '../../../news/presentation/providers/news_feed_provider.dart';
import '../../../news/presentation/widgets/news_thumb.dart';
import '../../../profile/data/profile_models.dart' show ProfileTeam;
import '../../../profile/data/profile_repository.dart' show myProfileProvider;

import '../../../profile/presentation/widgets/notification_bell.dart';
import '../../../scores/data/models/match_dto.dart';
import '../../../scores/presentation/providers/live_matches_provider.dart';
import '../../../../core/config/remote_app_config.dart';
import '../providers/home_dashboard_providers.dart';
import '../../data/daily_brief_repository.dart';

/// PITCH home dashboard. Layout matches `design-specs/android/home.html`,
/// wired entirely to live providers — no mock content.
class HomeDashboardScreen extends ConsumerStatefulWidget {
  const HomeDashboardScreen({super.key});
  @override
  ConsumerState<HomeDashboardScreen> createState() =>
      _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends ConsumerState<HomeDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.gold,
      backgroundColor: AppColors.surface3,
      onRefresh: () async {
        ref.invalidate(liveMatchesProvider);
        ref.invalidate(homeFixturesProvider);
        ref.invalidate(newsFeedProvider);
        ref.invalidate(homeNewsProvider);
        // The invalidates above already trigger a refetch. Awaiting keeps
        // the spinner up until data lands, but must never hang it — a slow
        // or unreachable backend would otherwise spin forever. Bound it and
        // swallow errors so the indicator always dismisses.
        try {
          await Future.wait<dynamic>([
            ref.read(liveMatchesProvider.future),
            ref.read(homeFixturesProvider.future),
            ref.read(homeNewsProvider.future),
          ]).timeout(const Duration(seconds: 10));
        } catch (_) {/* refetch continues in the background */}
      },
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsets.only(bottom: 110),
        // Section rhythm: _SectionHead now owns its own top/bottom
        // padding (see widget definition) so the column body doesn't
        // need ad-hoc SizedBox spacers between sections. The constant
        // we use everywhere is the _SectionGap below — apply it ONCE
        // between major non-section-head blocks (hero/cards), let
        // _SectionHead handle the rest.
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: MediaQuery.viewPaddingOf(context).top),
            const _Appbar(),

            // Match hero — the single most relevant match right now, then a
            // rail of the remaining live / upcoming fixtures just beneath it.
            const _SectionHead(title: 'Match'),
            const _NextMatchHero(),
            const SizedBox(height: 14),
            const _HomeMatchRail(),

            // Small banner above the matchday brief.
            const PitchBannerAd(padding: EdgeInsets.fromLTRB(16, 14, 16, 0)),

            // AI matchday brief — today's preview / yesterday's results.
            const _MatchdayBrief(),

            // Bracket card — user's WC2026 bracket: champion + progress,
            // or a CTA when they haven't started.
            const _SectionGap(),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: _BracketCard(),
            ),

            // Large MREC below the fold — self-hides on the ads kill-switch /
            // Pro / no consent, so it's safe to anchor here mid-feed.
            const SizedBox(height: 14),
            const Center(
              child: PitchBannerAd(
                large: true,
                padding: EdgeInsets.symmetric(horizontal: 16),
              ),
            ),

            // (Watch-ad-for-card CTA moved to the Collection + Wallet
            // screens — home stays focused.)

            // Your teams — followed-team digest (crests + news + their
            // own fixture digest inside the card). Header opens the dedicated
            // My Team page (countdown + group + fixtures).
            _SectionHead(
              title: 'Your teams',
              action: 'My Team →',
              onAction: () => context.push(RoutePaths.myTeam),
            ),
            const _YourTeamsSection(),

            // European leagues — hidden during WC mode since all domestic
            // seasons are over and the section is empty.
            _EuroLeaguesSection(wcMode: ref.watch(wcModeProvider)),

            // Group spotlight — seeded WC2026 standings so pre-tournament
            // the home page already shows draw structure.
            _SectionHead(
              title: 'World Cup groups',
              action: 'All groups →',
              onAction: () => context.push(RoutePaths.standings),
            ),
            const _GroupSpotlight(),

            // (Removed: WC upcoming schedule + host venues — both moved
            // to /world-cup screen so tournament context lives there.)

            // Featured Iconic / Legendary cards from the seeded market.
            _SectionHead(
              title: 'Featured cards',
              action: 'Market →',
              onAction: () => context.push('/market'),
            ),
            const _FeaturedCardsStrip(),

            _SectionHead(
              title: 'Your form',
              action: 'Manager →',
              onAction: () => context.push(RoutePaths.fantasyHome),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: _FantasyCard(),
            ),

            _SectionHead(
              title: "Today's stories",
              action: 'All news →',
              onAction: () => context.push(RoutePaths.news),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: _NewsList(),
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
    final dateLabel =
        DateFormat('EEE · d MMM').format(DateTime.now()).toUpperCase();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
      child: Row(
        children: [
          // Dot centred against the whole PITCH + date block.
          Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Color(0xFFF1E4B6),
                  Color(0xFFE5C26B),
                  Color(0xFF8E6422),
                ],
                stops: [0.2, 0.6, 1.0],
                center: Alignment(-0.3, -0.4),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShaderMask(
                shaderCallback: (rect) => const LinearGradient(
                  colors: [AppColors.goldSoft, AppColors.goldDeep],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
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
              const SizedBox(height: 1),
              Text(
                dateLabel,
                style: const TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontFamilyFallback: ['SF Mono', 'Menlo', 'monospace'],
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: AppColors.muted,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const Spacer(),
          const _GemChip(),
          const SizedBox(width: 8),
          const NotificationBell(),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => context.push(RoutePaths.profile),
            child: const UserAvatar(size: 36, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

/// Compact gem-balance pill in the app bar. Taps through to the wallet.
/// Shows nothing until the profile (and thus the balance) has loaded so
/// it never flashes a "0".
class _GemChip extends ConsumerWidget {
  const _GemChip();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gems = ref.watch(myProfileProvider).maybeWhen(
          data: (p) => p?.gems,
          orElse: () => null,
        );
    if (gems == null) return const SizedBox.shrink();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push(RoutePaths.wallet),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.gold.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: AppColors.goldHairline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.diamond, size: 13, color: AppColors.gold),
            const SizedBox(width: 5),
            Text(
              _compact(gems),
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.gold,
                letterSpacing: -0.2,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 1234 → "1.2k" so the pill never grows wide.
  static String _compact(int n) {
    if (n < 1000) return '$n';
    if (n < 1000000) {
      final k = n / 1000;
      return '${k.toStringAsFixed(k >= 100 ? 0 : 1)}k';
    }
    return '${(n / 1000000).toStringAsFixed(1)}M';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GREETING
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// SECTION HEAD
// ─────────────────────────────────────────────────────────────────────────────

/// Uniform vertical gap between home-page sections. Use between
/// non-section-head blocks (e.g. the WC hero → bracket card). Sections
/// that start with a _SectionHead already get their own top spacing from
/// the head's internal padding, so they don't need this.
class _SectionGap extends StatelessWidget {
  const _SectionGap();
  static const double height = 12;
  @override
  Widget build(BuildContext context) => const SizedBox(height: height);
}

class _SectionHead extends StatelessWidget {
  const _SectionHead({required this.title, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) {
    return Padding(
      // Self-contained spacing: top for separation from the previous section,
      // bottom to its own content. Callers never wrap this in a SizedBox.
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
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
            // Behavior.opaque + extra hit padding — the previous bare
            // GestureDetector wrapped a small text label with no hit area
            // around it, so taps in the spaces between letters fell
            // through and the user thought the buttons didn't work.
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onAction,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                child: Eyebrow(action!, gold: true),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MATCH HERO — one big card showing the next/current match
// ─────────────────────────────────────────────────────────────────────────────

/// Single-match feature card. Picks the most relevant match right now
/// — completely team-agnostic (any followed-team filter would conflict
/// with what the user sees in the Your teams section just below):
///   1. The first live match in the feed.
///   2. Otherwise the next upcoming kickoff in chronological order.
class _NextMatchHero extends ConsumerWidget {
  const _NextMatchHero();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final live = ref.watch(liveMatchesProvider);
    final fixtures = ref.watch(homeFixturesProvider);

    // Wait for BOTH to resolve before deciding — otherwise the live list (which
    // resolves fast, often empty) makes the hero flash "no matches live" before
    // the slower fixtures load and the real upcoming match appears.
    if (live.isLoading || fixtures.isLoading) {
      return const _HeroSkeleton();
    }

    // Hero + rail are decided together (see homeMatchFeedProvider).
    final selected = ref.watch(homeMatchFeedProvider).hero;
    if (selected == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: _NoLiveNowTile(),
      );
    }
    return _MatchFeatureCard(match: selected);
  }
}

class _HeroSkeleton extends StatelessWidget {
  const _HeroSkeleton();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Skeleton(height: 140, radius: 14),
    );
  }
}

/// Big feature card used by the "Match" section. Showcases one match
/// with competition pill, both crests + names, central score / time
/// chip, and a status line (LIVE pulse + minute, or kickoff countdown).
class _MatchFeatureCard extends StatelessWidget {
  const _MatchFeatureCard({required this.match});
  final MatchDto match;

  @override
  Widget build(BuildContext context) {
    final isLive = match.isLive;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => context.push('/matches/${match.id}'),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1F1B16), Color(0xFF120F0D)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(AppRadii.r4),
            border: Border.all(
              color:
                  isLive
                      ? AppColors.live.withValues(alpha: 0.5)
                      : AppColors.goldHairline,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _MatchHeroBadge(match: match),
              const SizedBox(height: 18),
              // Symmetric three-column layout (mirrors the World Cup
              // opening-match card): each team is a centred crest-above-
              // name column, the score / kickoff chip sits dead centre.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _MatchHeroSide(team: match.homeTeam)),
                  _MatchHeroCenter(match: match),
                  Expanded(child: _MatchHeroSide(team: match.awayTeam)),
                ],
              ),
              // Goals + red cards per side (live/finished), like match detail.
              _MatchHeroEvents(match: match),
              // Compact "where to watch" — live/upcoming only, self-hides.
              _HeroWhereToWatch(match: match),
              // Finished match with a highlight → in-app "Highlights" pill.
              if (match.hasHighlight) ...[
                const SizedBox(height: 12),
                Center(child: HighlightChip(match: match)),
              ],
              // Footer only for UPCOMING matches: a thin divider + the kickoff
              // line. Live + finished are fully carried by the badge (LIVE/min,
              // FT) + events, and the stadium is dropped to keep the hero short.
              if (!match.isLive && !match.isFinished) ...[
                const SizedBox(height: 16),
                Container(height: 1, color: AppColors.borderSoft),
                const SizedBox(height: 10),
                Center(child: _MatchHeroStatus(match: match)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MatchHeroBadge extends StatelessWidget {
  const _MatchHeroBadge({required this.match});
  final MatchDto match;
  @override
  Widget build(BuildContext context) {
    final comp = _competitionLabel(match.competitionId);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: AppColors.goldHairline),
          ),
          child: Text(
            comp,
            style: const TextStyle(
              fontFamily: 'JetBrainsMono',
              fontFamilyFallback: ['SF Mono', 'Menlo', 'monospace'],
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: AppColors.gold,
              letterSpacing: 1.0,
            ),
          ),
        ),
        const Spacer(),
        // Same live badge as the all-matches list: a red pill with the dot and
        // the minute, or HT at half-time (isLive includes HALF_TIME).
        if (match.isLive)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.live.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const LiveDot(size: 7),
                const SizedBox(width: 6),
                Text(
                  match.status == MatchStatus.HALF_TIME
                      ? 'HT'
                      : match.minuteLabel,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: AppColors.live,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          )
        else if (match.isFinished)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.muted.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(99),
            ),
            child: const Text(
              'FT',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: AppColors.muted,
                letterSpacing: 0.8,
              ),
            ),
          ),
      ],
    );
  }

  /// Friendly competition name from id; falls back to the id itself.
  static String _competitionLabel(String? id) {
    if (id == null) return 'MATCH';
    const map = <String, String>{
      'PL_2025': 'PREMIER LEAGUE',
      'LALIGA_2025': 'LA LIGA',
      'BUNDESLIGA_2025': 'BUNDESLIGA',
      'SERIEA_2025': 'SERIE A',
      'LIGUE1_2025': 'LIGUE 1',
      'UCL_2025': 'UCL',
      'UEL_2025': 'UEL',
      'WC2026': 'WORLD CUP 2026',
    };
    return map[id] ?? id.toUpperCase();
  }
}

class _MatchHeroSide extends StatelessWidget {
  const _MatchHeroSide({required this.team});
  final TeamDto team;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 52,
          height: 52,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: PremiumImage(url: team.crestUrl, fit: BoxFit.contain),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          team.shortName ?? team.name,
          maxLines: 2,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppColors.fg,
            letterSpacing: -0.2,
            height: 1.15,
          ),
        ),
      ],
    );
  }
}

class _MatchHeroCenter extends StatelessWidget {
  const _MatchHeroCenter({required this.match});
  final MatchDto match;
  @override
  Widget build(BuildContext context) {
    // Live or finished → show the score; upcoming → the kickoff time.
    final isLiveOrFinished = match.isLive || match.isFinished;
    final label =
        isLiveOrFinished
            ? '${match.homeScore} – ${match.awayScore}'
            : DateFormat('HH:mm').format(match.kickoffAt.toLocal());
    // Sized to the crest height (52) so the chip sits centred against the
    // crests in the symmetric three-column row.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: SizedBox(
        height: 52,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0x8C0F0E0D),
                  borderRadius: BorderRadius.circular(AppRadii.r3),
                  border: Border.all(color: AppColors.borderSoft),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontFamilyFallback: const ['SF Mono', 'Menlo', 'monospace'],
                    fontSize: isLiveOrFinished ? 20 : 17,
                    fontWeight: FontWeight.w800,
                    color: isLiveOrFinished ? AppColors.fg : AppColors.gold,
                    letterSpacing: -0.4,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              if (match.hasPenaltyShootout)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    'pens ${match.penaltyLabel}',
                    style: const TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontFamilyFallback: ['SF Mono', 'Menlo', 'monospace'],
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.gold,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MatchHeroStatus extends StatelessWidget {
  const _MatchHeroStatus({required this.match});
  final MatchDto match;
  @override
  Widget build(BuildContext context) {
    if (match.isLive) {
      return Text(
        "${match.minute ?? 0}' · IN PROGRESS",
        style: const TextStyle(
          fontFamily: 'JetBrainsMono',
          fontFamilyFallback: ['SF Mono', 'Menlo', 'monospace'],
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: AppColors.live,
          letterSpacing: 0.8,
        ),
      );
    }
    if (match.isFinished) {
      return const Text(
        'FULL TIME',
        style: TextStyle(
          fontFamily: 'JetBrainsMono',
          fontFamilyFallback: ['SF Mono', 'Menlo', 'monospace'],
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: AppColors.muted,
          letterSpacing: 0.8,
        ),
      );
    }
    final local = match.kickoffAt.toLocal();
    final now = DateTime.now();
    final daysAhead =
        DateTime(
          local.year,
          local.month,
          local.day,
        ).difference(DateTime(now.year, now.month, now.day)).inDays;
    final dayLabel =
        daysAhead == 0
            ? 'TODAY'
            : daysAhead == 1
            ? 'TOMORROW'
            : DateFormat('EEE d MMM').format(local).toUpperCase();
    final tzAbbrev = local.timeZoneName;
    return Text(
      '$dayLabel · ${DateFormat('HH:mm').format(local)} $tzAbbrev',
      style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 10.5,
        fontWeight: FontWeight.w800,
        color: AppColors.gold,
        letterSpacing: 0.6,
      ),
    );
  }
}

/// Two-column goals + red-cards strip under the hero scoreline (live/finished),
/// mirroring the match-detail hero. Own goals are credited to the opposite
/// side; red cards stay with the player's own team.
/// Tiny "where to watch" pill for the home hero — live/upcoming matches only.
/// Shows the viewer's-country broadcaster (tap → open it), or a generic
/// "Where to watch" chip (tap → match detail). Self-hides when finished or
/// when there's no broadcast data, to keep the home hero compact.
class _HeroWhereToWatch extends ConsumerWidget {
  const _HeroWhereToWatch({required this.match});
  final MatchDto match;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (match.isFinished) return const SizedBox.shrink();

    final entries = ref.watch(matchBroadcastsProvider(match.id)).maybeWhen(
          data: (b) => b.where((e) => e.broadcasters.isNotEmpty).toList(),
          orElse: () => const <MatchBroadcastDto>[],
        );
    if (entries.isEmpty) return const SizedBox.shrink();

    final cc = ref.watch(watchCountryProvider);
    BroadcasterDto? top;
    if (cc != null) {
      for (final e in entries) {
        if (e.countryCode == cc && e.broadcasters.isNotEmpty) {
          top = e.broadcasters.first;
          break;
        }
      }
    }
    final label = top?.name ?? 'Where to watch';
    final url = top?.url;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Center(
        child: GestureDetector(
          onTap: () {
            if (url != null && url.isNotEmpty) {
              launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
            } else {
              context.push('/matches/${match.id}');
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.bg.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: AppColors.goldHairline),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.live_tv, size: 13, color: AppColors.gold),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.fgSoft,
                    ),
                  ),
                ),
                if (url != null && url.isNotEmpty) ...[
                  const SizedBox(width: 5),
                  const Icon(Icons.open_in_new, size: 11, color: AppColors.muted),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MatchHeroEvents extends ConsumerWidget {
  const _MatchHeroEvents({required this.match});
  final MatchDto match;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!match.isLive && !match.isFinished) return const SizedBox.shrink();
    final events = ref.watch(matchEventsProvider(match.id)).maybeWhen(
          data: (es) => [
            for (final e in es)
              if (e.kind == EventKind.goal ||
                  e.kind == EventKind.ownGoal ||
                  e.kind == EventKind.penalty ||
                  e.kind == EventKind.red)
                e
          ],
          orElse: () => const <MatchEventDto>[],
        );
    if (events.isEmpty) return const SizedBox.shrink();

    final home = <MatchEventDto>[];
    final away = <MatchEventDto>[];
    for (final e in events) {
      final isHome = e.kind == EventKind.ownGoal
          ? e.teamId != match.homeTeam.id
          : e.teamId == match.homeTeam.id;
      (isHome ? home : away).add(e);
    }
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _HeroEventColumn(events: home, alignEnd: false)),
          const SizedBox(width: 12),
          Expanded(child: _HeroEventColumn(events: away, alignEnd: true)),
        ],
      ),
    );
  }
}

class _HeroEventColumn extends StatelessWidget {
  const _HeroEventColumn({required this.events, required this.alignEnd});
  final List<MatchEventDto> events;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        for (final e in events)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 1.5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!alignEnd) ...[_glyph(e), const SizedBox(width: 5)],
                Flexible(
                  child: Text(
                    _label(e),
                    textAlign: alignEnd ? TextAlign.right : TextAlign.left,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.fgSoft,
                      height: 1.25,
                    ),
                  ),
                ),
                if (alignEnd) ...[const SizedBox(width: 5), _glyph(e)],
              ],
            ),
          ),
      ],
    );
  }

  Widget _glyph(MatchEventDto e) {
    if (e.kind == EventKind.red) {
      return Container(
        width: 8,
        height: 11,
        decoration: BoxDecoration(
          color: AppColors.live,
          borderRadius: BorderRadius.circular(2),
        ),
      );
    }
    final color = e.kind == EventKind.ownGoal ? AppColors.live : AppColors.gold;
    return Icon(Icons.sports_soccer, size: 11, color: color);
  }

  String _label(MatchEventDto e) {
    final name = e.playerName ?? '—';
    final extra = e.kind == EventKind.ownGoal
        ? ' (OG)'
        : e.kind == EventKind.penalty
            ? ' (P)'
            : '';
    return '$name$extra ${e.displayMinute}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MATCHDAY BRIEF — AI digest: today's preview / yesterday's results
// ─────────────────────────────────────────────────────────────────────────────

class _MatchdayBrief extends ConsumerStatefulWidget {
  const _MatchdayBrief();
  @override
  ConsumerState<_MatchdayBrief> createState() => _MatchdayBriefState();
}

class _MatchdayBriefState extends ConsumerState<_MatchdayBrief> {
  bool _wantRecap = false; // false = today's preview, true = yesterday's recap
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return ref.watch(dailyBriefProvider).maybeWhen(
          data: (brief) {
            if (brief.isEmpty) return const SizedBox.shrink();
            final hasPreview = brief.preview != null;
            final hasRecap = brief.recap != null;
            final bothShown = hasPreview && hasRecap;
            // Default to today's preview; fall back to recap if there's no
            // preview (rest day today but matches yesterday).
            final showRecap = hasRecap && (_wantRecap || !hasPreview);
            final digest = showRecap ? brief.recap! : brief.preview!;
            final label = showRecap
                ? 'YESTERDAY · ${digest.matchCount} result${digest.matchCount == 1 ? '' : 's'}'
                : 'TODAY · ${digest.matchCount} match${digest.matchCount == 1 ? '' : 'es'}';

            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
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
                        const Text(
                          'Matchday brief',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.fg,
                          ),
                        ),
                        const Spacer(),
                        if (bothShown) _toggle(showRecap),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Eyebrow(label, gold: !showRecap, size: 9),
                    const SizedBox(height: 8),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 180),
                      alignment: Alignment.topCenter,
                      child: Text(
                        digest.content,
                        maxLines: _expanded ? null : 5,
                        overflow: _expanded ? null : TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.fgSoft,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _expanded = !_expanded),
                      child: Text(
                        _expanded ? 'Show less' : 'Read more',
                        style: const TextStyle(
                          color: AppColors.gold,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.auto_awesome, size: 11, color: AppColors.muted.withValues(alpha: 0.6)),
                        const SizedBox(width: 5),
                        const Expanded(
                          child: Text(
                            'AI-generated with Google Search · may contain mistakes',
                            style: TextStyle(color: AppColors.muted, fontSize: 10.5),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
          orElse: () => const SizedBox.shrink(),
        );
  }

  Widget _toggle(bool showRecap) {
    Widget pill(String text, bool active, VoidCallback onTap) => GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: active ? AppColors.gold.withValues(alpha: 0.16) : Colors.transparent,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(
                color: active ? AppColors.goldHairline : AppColors.borderSoft,
              ),
            ),
            child: Text(
              text,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: active ? AppColors.gold : AppColors.muted,
              ),
            ),
          ),
        );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        pill('Today', !showRecap, () => setState(() {
              _wantRecap = false;
              _expanded = false;
            })),
        const SizedBox(width: 6),
        pill('Yesterday', showRecap, () => setState(() {
              _wantRecap = true;
              _expanded = false;
            })),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LIVE / UPCOMING RAIL — horizontal cards directly under the hero
// ─────────────────────────────────────────────────────────────────────────────

class _HomeMatchRail extends ConsumerWidget {
  const _HomeMatchRail();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // While the underlying data loads, reserve the rail's height with skeleton
    // cards so content below doesn't jump when it resolves.
    final loading = ref.watch(liveMatchesProvider).isLoading ||
        ref.watch(homeFixturesProvider).isLoading;
    if (loading) {
      return SizedBox(
        height: 150,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: 3,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (_, __) => const SizedBox(
            width: 286,
            child: Skeleton(height: 150, radius: 14),
          ),
        ),
      );
    }
    final feed = ref.watch(homeMatchFeedProvider);
    if (feed.railItems.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHead(
          title: feed.railTitle,
          action: 'All matches →',
          // Bottom-nav tab → go(), not push() (a shell sibling push can no-op).
          onAction: () => context.go(RoutePaths.matches),
        ),
        SizedBox(
          // Snug to the card content (header + two team rows + divider +
          // footer) so upcoming cards don't carry a tall empty bottom band.
          height: 150,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: feed.railItems.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) => _RailMatchCard(match: feed.railItems[i]),
          ),
        ),
      ],
    );
  }
}

class _RailMatchCard extends StatelessWidget {
  const _RailMatchCard({required this.match});
  final MatchDto match;

  @override
  Widget build(BuildContext context) {
    final live = match.isLive;
    final showScore = live || match.isFinished;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push('/matches/${match.id}'),
      child: Container(
        width: 286,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1A1714), Color(0xFF0F0D0B)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(AppRadii.r4),
          border: Border.all(
            color: live
                ? AppColors.live.withValues(alpha: 0.4)
                : AppColors.borderSoft,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _railHeader(match),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontFamilyFallback: ['SF Mono', 'Menlo', 'monospace'],
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: AppColors.muted,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (live) ...[
                  const LiveDot(size: 6),
                  const SizedBox(width: 5),
                  const Text(
                    'LIVE',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: AppColors.live,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
            _RailTeamRow(
              team: match.homeTeam,
              score: showScore ? match.homeScore : null,
            ),
            const SizedBox(height: 9),
            _RailTeamRow(
              team: match.awayTeam,
              score: showScore ? match.awayScore : null,
            ),
            const SizedBox(height: 11),
            Container(height: 1, color: AppColors.borderSoft),
            const SizedBox(height: 8),
            _RailFooter(match: match),
          ],
        ),
      ),
    );
  }

  static String _railHeader(MatchDto m) {
    final comp = _MatchHeroBadge._competitionLabel(m.competitionId);
    final stage = m.stage;
    return (stage != null && stage.isNotEmpty)
        ? '$comp · ${stage.toUpperCase()}'
        : comp;
  }
}

class _RailTeamRow extends StatelessWidget {
  const _RailTeamRow({required this.team, required this.score});
  final TeamDto team;
  final int? score;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 22,
          height: 22,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: PremiumImage(url: team.crestUrl, fit: BoxFit.contain),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            team.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.fg,
              letterSpacing: -0.2,
            ),
          ),
        ),
        if (score != null)
          Text(
            '$score',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppColors.gold,
              height: 1.0,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
      ],
    );
  }
}

/// Footer line. Live → `73' · ↑ Last scorer` (or `HT`); finished → `FT`;
/// upcoming → the local kickoff. Mirrors the live-now card in the design.
class _RailFooter extends ConsumerWidget {
  const _RailFooter({required this.match});
  final MatchDto match;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const live = AppColors.pitch; // green mono, as in the design
    if (match.isFinished) {
      return Text('FT', style: _style(AppColors.muted));
    }
    if (!match.isLive) {
      return Text(_kickoffLabel(match), style: _style(AppColors.gold));
    }
    if (match.status == MatchStatus.HALF_TIME) {
      return Text('HT', style: _style(live));
    }
    final lastGoal = ref.watch(matchEventsProvider(match.id)).maybeWhen(
          data: (es) {
            for (final e in es.reversed) {
              if (e.kind == EventKind.goal ||
                  e.kind == EventKind.ownGoal ||
                  e.kind == EventKind.penalty) {
                return e;
              }
            }
            return null;
          },
          orElse: () => null,
        );
    final minute = match.minuteLabel;
    final scorer = (lastGoal?.playerName != null)
        ? '  ·  ↑ ${lastGoal!.playerName} (${lastGoal.minute}\')'
        : '';
    return Text('$minute$scorer', maxLines: 1, overflow: TextOverflow.ellipsis, style: _style(live));
  }

  static String _kickoffLabel(MatchDto m) {
    final local = m.kickoffAt.toLocal();
    final now = DateTime.now();
    final days = DateTime(local.year, local.month, local.day)
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;
    final day = days == 0
        ? 'TODAY'
        : days == 1
            ? 'TOMORROW'
            : DateFormat('EEE d MMM').format(local).toUpperCase();
    return '$day · ${DateFormat('HH:mm').format(local)}';
  }

  static TextStyle _style(Color c) => TextStyle(
        fontFamily: 'JetBrainsMono',
        fontFamilyFallback: const ['SF Mono', 'Menlo', 'monospace'],
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: c,
        letterSpacing: 0.2,
      );
}

class _StripEmpty extends StatelessWidget {
  const _StripEmpty({required this.title, required this.subtitle});
  final String title;
  final String subtitle;
  static const EmptyGlyph glyph = EmptyGlyph.football;
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
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: PitchEmptyState(title: title, subtitle: subtitle, glyph: glyph),
      ),
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
      data:
          (g) =>
              g == null
                  ? const AsyncValue.data(null)
                  : ref.watch(myLineupProvider((slug: slug, gameweekId: g.id))),
      orElse: () => const AsyncValue.data(null),
    );

    return tournament.when(
      loading: () => const Skeleton(height: 180, radius: 16),
      error: (_, __) => const _FantasyEmpty(),
      data: (t) {
        final gameweekNum = gw.valueOrNull?.number;
        final lineup = lineupAsync.valueOrNull;
        final hasLineup = lineup != null;
        // Two distinct visual states:
        //   - hasLineup    → "live result" panel with rank + GW points
        //     plus a budget-used progress bar.
        //   - !hasLineup   → CTA panel inviting the user to build their XI,
        //     with deadline + a primary action button. No fake zeros.
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => context.push(RoutePaths.fantasyHome),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1F1814), Color(0xFF110C09)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppRadii.r4),
              border: Border.all(color: AppColors.goldHairline),
              boxShadow: [
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.10),
                  blurRadius: 24,
                  spreadRadius: -8,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child:
                hasLineup
                    ? _FantasyLive(
                      tournament: t,
                      gameweek: gw.valueOrNull,
                      lineup: lineup,
                    )
                    : _FantasyCta(
                      tournament: t,
                      gameweekNum: gameweekNum,
                      gameweek: gw.valueOrNull,
                    ),
          ),
        );
      },
    );
  }
}

/// State A — user has a lineup. Show their rank + GW points + spend.
class _FantasyLive extends StatelessWidget {
  const _FantasyLive({
    required this.tournament,
    required this.gameweek,
    required this.lineup,
  });
  final FantasyTournamentDto tournament;
  final FantasyGameweekDto? gameweek;
  final FantasyLineupDto lineup;
  @override
  Widget build(BuildContext context) {
    final budget = tournament.budget;
    final pct =
        budget == 0 ? 0.0 : (lineup.budgetUsed / budget).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title row + status badge.
          Row(
            children: [
              Expanded(
                child: Text(
                  gameweek == null
                      ? tournament.name
                      : '${tournament.name} · GW ${gameweek!.number}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.18,
                    color: AppColors.fg,
                  ),
                ),
              ),
              _StatusBadge(locked: lineup.locked),
            ],
          ),
          const SizedBox(height: 12),
          // Rank + points side by side, both prominent.
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Eyebrow('Manager rank', size: 9),
                    const SizedBox(height: 2),
                    ShaderMask(
                      shaderCallback:
                          (r) => const LinearGradient(
                            colors: [AppColors.goldSoft, AppColors.goldDeep],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ).createShader(r),
                      child: Text(
                        lineup.rank == null ? '—' : '#${lineup.rank}',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1.5,
                          color: Colors.white,
                          height: 1.0,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 56, color: AppColors.borderSoft),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Eyebrow('Points', size: 9),
                    const SizedBox(height: 2),
                    Text(
                      lineup.totalPoints.toStringAsFixed(0),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.5,
                        color: AppColors.fg,
                        height: 1.0,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Budget bar — exact spend with the budget context.
          Row(
            children: [
              Eyebrow(
                'Budget · ${lineup.budgetUsed.toStringAsFixed(1)} / $budget',
                size: 9,
                gold: true,
              ),
              const Spacer(),
              Text(
                '${(pct * 100).round()}%',
                style: const TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontFamilyFallback: ['SF Mono', 'Menlo', 'monospace'],
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: SizedBox(
              height: 4,
              child: Stack(
                children: [
                  Container(color: AppColors.surface3),
                  FractionallySizedBox(
                    widthFactor: pct,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.goldDeep, AppColors.gold],
                        ),
                      ),
                    ),
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

/// State B — no lineup yet. CTA card that wraps the deadline + an inline
/// "Build your XI" button. Replaces the previous "rank: —, points: 0,
/// status: Build XI" feel-bad zeros.
class _FantasyCta extends StatelessWidget {
  const _FantasyCta({
    required this.tournament,
    required this.gameweekNum,
    required this.gameweek,
  });
  final FantasyTournamentDto tournament;
  final int? gameweekNum;
  final FantasyGameweekDto? gameweek;
  @override
  Widget build(BuildContext context) {
    // Compute the deadline string. "Locks Sun 14:00" beats "locks at
    // 2026-06-11T16:00:00Z" for at-a-glance scanning.
    final lockLabel = gameweek == null ? null : _formatLock(gameweek!.lockAt);
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Eyebrow(
                  gameweekNum == null
                      ? tournament.name
                      : '${tournament.name} · GW $gameweekNum',
                  gold: true,
                  size: 10,
                ),
              ),
              if (lockLabel != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: AppColors.borderSoft),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.schedule,
                        size: 11,
                        color: AppColors.muted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        lockLabel,
                        style: const TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontFamilyFallback: ['SF Mono', 'Menlo', 'monospace'],
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.muted,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          RichText(
            text: const TextSpan(
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.36,
                color: AppColors.fg,
                height: 1.15,
              ),
              children: [
                TextSpan(text: 'Draft your XI '),
                TextSpan(
                  text: 'before kickoff.',
                  style: TextStyle(
                    fontFamily: 'IowanOldStyle',
                    fontFamilyFallback: ['Charter', 'Georgia', 'serif'],
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w500,
                    color: AppColors.gold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '5 picks. 100-pt budget. Captain doubles. Cards you own boost points further.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12.5,
              color: AppColors.muted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.gold,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Build your XI',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E1810),
                      ),
                    ),
                    SizedBox(width: 5),
                    Icon(
                      Icons.arrow_forward,
                      size: 14,
                      color: Color(0xFF1E1810),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Render a lock timestamp as "Sun 14:00" or "Today 18:00" — short
  /// enough to live in the small pill, accurate enough to plan around.
  static String _formatLock(DateTime t) {
    final local = t.toLocal();
    final now = DateTime.now();
    final isToday =
        local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    final isTomorrow =
        local.difference(DateTime(now.year, now.month, now.day)).inDays == 1;
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    final prefix =
        isToday
            ? 'Today'
            : isTomorrow
            ? 'Tmrw'
            : const [
              'Mon',
              'Tue',
              'Wed',
              'Thu',
              'Fri',
              'Sat',
              'Sun',
            ][local.weekday - 1];
    return '$prefix $hh:$mm';
  }
}

/// Compact LOCKED / EDITABLE indicator for the live state.
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.locked});
  final bool locked;
  @override
  Widget build(BuildContext context) {
    final color = locked ? AppColors.muted2 : AppColors.pitch;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            locked ? Icons.lock_outline : Icons.edit_outlined,
            size: 10,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            locked ? 'LOCKED' : 'EDITABLE',
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontFamilyFallback: const ['SF Mono', 'Menlo', 'monospace'],
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
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
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
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

// ─────────────────────────────────────────────────────────────────────────────
// NEWS LIST — wired to newsFeedProvider
// ─────────────────────────────────────────────────────────────────────────────

class _NewsList extends ConsumerWidget {
  const _NewsList();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(homeNewsProvider);
    return feed.when(
      loading:
          () => const Column(
            children: [
              _NewsHeroSkeleton(),
              SizedBox(height: 10),
              NewsTileSkeleton(),
              SizedBox(height: 10),
              NewsTileSkeleton(),
            ],
          ),
      error:
          (_, __) => const _ListEmpty(
            title: 'News on a tea break',
            subtitle: 'Couldn’t reach the news feed. Pull to refresh.',
            glyph: EmptyGlyph.paper,
          ),
      data: (page) {
        if (page.items.isEmpty) {
          return const _ListEmpty(
            title: 'No stories yet',
            subtitle:
                'Sources update every 10 minutes — fresh headlines land here automatically.',
            glyph: EmptyGlyph.paper,
          );
        }
        // Hero takes the lead story (already image-prioritised by the
        // provider); the rest render as compact rows under it.
        final hero = page.items.first;
        final rest = page.items.skip(1).take(6).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _NewsHero(article: hero),
            if (rest.isNotEmpty) const SizedBox(height: 10),
            for (final article in rest) _NewsRow(article: article),
          ],
        );
      },
    );
  }
}

/// Big magazine-style hero card. 16:9 image with a bottom scrim, source
/// pill + breaking/new badge on the image, headline + summary beneath.
class _NewsHero extends StatelessWidget {
  const _NewsHero({required this.article});
  final NewsArticleDto article;
  @override
  Widget build(BuildContext context) {
    final age = DateTime.now().difference(article.publishedAt.toLocal());
    final isBreaking = age.inHours < 1;
    return Material(
      color: AppColors.surface2,
      borderRadius: BorderRadius.circular(AppRadii.r4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/news/${article.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  NewsThumb(imageUrl: article.imageUrl, source: article.source),
                  // Bottom scrim so the source pill stays legible over
                  // both photo + branded-fallback backgrounds.
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0x00000000), Color(0xAA000000)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0.55, 1.0],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    bottom: 12,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            article.source.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                        if (isBreaking) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.live,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: const Text(
                              'BREAKING',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    article.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      color: AppColors.fg,
                      height: 1.25,
                    ),
                  ),
                  if (article.summary != null &&
                      article.summary!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      article.summary!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        color: AppColors.muted,
                        height: 1.4,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.schedule,
                        size: 12,
                        color: AppColors.muted2,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        relativeTime(article.publishedAt),
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.muted2,
                        ),
                      ),
                    ],
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

/// Compact row for stories #2 / #3 — bigger image than the old 88x88,
/// branded fallback when the image is missing, relative-time stamp.
class _NewsRow extends StatelessWidget {
  const _NewsRow({required this.article});
  final NewsArticleDto article;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Material(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(AppRadii.r4),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/news/${article.id}'),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 104,
                    height: 78,
                    child: NewsThumb(
                      imageUrl: article.imageUrl,
                      source: article.source,
                      dense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Eyebrow(article.source, gold: true, size: 9),
                      const SizedBox(height: 4),
                      Text(
                        article.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                          color: AppColors.fg,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.schedule,
                            size: 11,
                            color: AppColors.muted2,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            relativeTime(article.publishedAt),
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.muted2,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Skeleton placeholder matching the hero's footprint while the home news
/// query is in-flight. Keeps layout stable on load (no jump).
class _NewsHeroSkeleton extends StatelessWidget {
  const _NewsHeroSkeleton();
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(AppRadii.r4),
        border: Border.all(color: AppColors.borderSoft),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(color: AppColors.surface3),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBlock(height: 16, radius: 4),
                SizedBox(height: 8),
                SkeletonBlock(height: 12, radius: 4),
              ],
            ),
          ),
        ],
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
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
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
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.muted2.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.borderSoft),
              ),
              child: const Icon(
                Icons.schedule,
                color: AppColors.muted,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'No matches live right now.\nResults & upcoming fixtures below.',
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

/// Wraps the European leagues section so it can be hidden during WC mode.
class _EuroLeaguesSection extends StatelessWidget {
  const _EuroLeaguesSection({required this.wcMode});
  final bool wcMode;
  @override
  Widget build(BuildContext context) {
    if (wcMode) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHead(
          title: 'European leagues',
          action: 'Full schedule →',
          onAction: () => context.push(RoutePaths.matches),
        ),
        const _LeagueDigest(),
      ],
    );
  }
}

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
    'PL_2025': 'Premier League',
    'LALIGA_2025': 'La Liga',
    'BUNDESLIGA_2025': 'Bundesliga',
    'SERIEA_2025': 'Serie A',
    'LIGUE1_2025': 'Ligue 1',
    'UCL_2025': 'UEFA Champions League',
    'UEL_2025': 'UEFA Europa League',
    'WC2026': 'FIFA World Cup 2026',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(homeFixturesProvider);
    return async.when(
      loading:
          () => const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Skeleton(height: 220, radius: 16),
          ),
      error:
          (_, __) => const _StripEmpty(
            title: 'League schedule unavailable',
            subtitle: 'Couldn’t reach the fixtures feed. Pull to refresh.',
          ),
      data: (f) {
        // Group recent + upcoming by competitionId. Skip the WC: it has
        // its own spotlight section below.
        final byComp = <String, _CompBucket>{};
        for (final m in f.recent) {
          if (m.competitionId == 'WC2026') continue;
          byComp
              .putIfAbsent(m.competitionId, () => _CompBucket())
              .recent
              .add(m);
        }
        for (final m in f.upcoming) {
          if (m.competitionId == 'WC2026') continue;
          byComp
              .putIfAbsent(m.competitionId, () => _CompBucket())
              .upcoming
              .add(m);
        }
        if (byComp.isEmpty) {
          return const _StripEmpty(
            title: 'No European fixtures in the window',
            subtitle:
                'No matches between yesterday and the day after tomorrow. Check back closer to the weekend.',
          );
        }
        // Sort: leagues with the most rows first (gives the user the most
        // immediately interesting content up top). Cap at 3 cards on home.
        final ranked =
            byComp.entries.toList()
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
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
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
              winner:
                  match.homeScore > match.awayScore
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
  const _ScoreBlock({
    required this.home,
    required this.away,
    required this.winner,
  });
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
    // Three example crests as decorative chips — make the empty state
    // feel concrete instead of abstract ("pick teams" → "look, like
    // these"). They aren't tappable; the whole panel routes to the picker.
    const sampleCrests = [
      ('FRA', AppColors.info),
      ('BRA', AppColors.pitch),
      ('ARG', AppColors.live),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => context.push(RoutePaths.teamPicker),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.r4),
            border: Border.all(color: AppColors.goldHairline),
            gradient: const LinearGradient(
              colors: [Color(0xFF221C14), Color(0xFF12100D)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.gold.withValues(alpha: 0.10),
                blurRadius: 28,
                spreadRadius: -8,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: AppColors.goldHairline),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.favorite, size: 10, color: AppColors.gold),
                        SizedBox(width: 5),
                        Text(
                          'PERSONALISE',
                          style: TextStyle(
                            fontFamily: 'JetBrainsMono',
                            fontFamilyFallback: [
                              'SF Mono',
                              'Menlo',
                              'monospace',
                            ],
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: AppColors.gold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.chevron_right,
                    color: AppColors.gold,
                    size: 22,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              RichText(
                text: const TextSpan(
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.36,
                    color: AppColors.fg,
                    height: 1.15,
                  ),
                  children: [
                    TextSpan(text: 'Pick the clubs and\nnational teams '),
                    TextSpan(
                      text: 'you live for.',
                      style: TextStyle(
                        fontFamily: 'IowanOldStyle',
                        fontFamilyFallback: ['Charter', 'Georgia', 'serif'],
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w500,
                        color: AppColors.gold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Their fixtures, results and lineups jump to the top of every screen.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12.5,
                  color: AppColors.muted,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              // Mock crest row — visual primer for what "following" looks
              // like once they've picked. Always uses 3 sample WC nations
              // so the prompt feels football-shaped even on first install.
              Row(
                children: [
                  for (var i = 0; i < sampleCrests.length; i++) ...[
                    Transform.translate(
                      offset: Offset(-12.0 * i, 0),
                      child: _MockCrest(
                        code: sampleCrests[i].$1,
                        tint: sampleCrests[i].$2,
                      ),
                    ),
                  ],
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.gold,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Choose teams',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1E1810),
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward,
                          size: 12,
                          color: Color(0xFF1E1810),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mock crest used by the pick-teams empty state. Decorative — not tied
/// to a real team. Three of these sit overlapping at the bottom of the
/// prompt so the empty state visually previews what "following" looks like.
class _MockCrest extends StatelessWidget {
  const _MockCrest({required this.code, required this.tint});
  final String code;
  final Color tint;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: tint.withValues(alpha: 0.20),
        border: Border.all(color: tint.withValues(alpha: 0.6), width: 1.5),
        boxShadow: [
          BoxShadow(color: tint.withValues(alpha: 0.25), blurRadius: 12),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        code,
        style: TextStyle(
          fontFamily: 'JetBrainsMono',
          fontFamilyFallback: const ['SF Mono', 'Menlo', 'monospace'],
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: tint,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

/// Followed-team digest. Crest rail → recent results + upcoming fixtures
/// → team news headlines. This is the primary personalised section on the
/// home page and needs to feel worth coming back to.
class _FollowedTeamsRail extends StatefulWidget {
  const _FollowedTeamsRail({required this.teams});
  final List<ProfileTeam> teams;

  @override
  State<_FollowedTeamsRail> createState() => _FollowedTeamsRailState();
}

class _FollowedTeamsRailState extends State<_FollowedTeamsRail> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final teams = widget.teams;
    // Followed set can shrink (via Manage) between builds — keep the index valid.
    final sel = _selected.clamp(0, teams.length - 1);
    // One team → no tabs, just that team's digest. More than one → the crests
    // act as tabs and only the selected team's news + fixtures show, so we
    // never dump every team's content on top of each other.
    final multi = teams.length > 1;
    final active = teams[sel];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.r4),
          border: Border.all(
            color: AppColors.goldHairline.withValues(alpha: 0.5),
          ),
          gradient: const LinearGradient(
            colors: [Color(0xFF1A1815), Color(0xFF110F0D)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
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
            // Crest scroller — doubles as the team tab-bar when >1 team.
            SizedBox(
              height: 54,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: teams.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) => _CrestPill(
                  team: teams[i],
                  selected: multi && i == sel,
                  onTap: multi ? () => setState(() => _selected = i) : null,
                ),
              ),
            ),
            const SizedBox(height: 8),
            // News + fixtures for the selected team only.
            _FollowedTeamNews(teamId: active.id),
            Container(height: 1, color: AppColors.borderSoft),
            const SizedBox(height: 8),
            _FollowedTeamFixtures(teamIds: {active.id}),
          ],
        ),
      ),
    );
  }
}

/// Shows up to 3 news articles for a followed team inside the team card.
class _FollowedTeamNews extends ConsumerWidget {
  const _FollowedTeamNews({required this.teamId});
  final String teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(teamNewsProvider(teamId));
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (articles) {
        if (articles.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Eyebrow('Team news', gold: true, size: 9),
            const SizedBox(height: 6),
            for (int i = 0; i < articles.length; i++) ...[
              if (i > 0) Container(height: 1, color: AppColors.borderSoft.withValues(alpha: 0.5)),
              _TeamNewsRow(article: articles[i]),
            ],
          ],
        );
      },
    );
  }
}

class _TeamNewsRow extends StatelessWidget {
  const _TeamNewsRow({required this.article});
  final NewsArticleDto article;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push('/news/${article.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (article.imageUrl != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: PremiumImage(
                    url: article.imageUrl!,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    article.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.fg,
                      height: 1.3,
                      letterSpacing: -0.13,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Eyebrow(article.source, size: 9),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CrestPill extends StatelessWidget {
  const _CrestPill({required this.team, this.selected = false, this.onTap});
  final ProfileTeam team;
  final bool selected;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected
                  ? AppColors.gold.withValues(alpha: 0.14)
                  : AppColors.surface2,
              border: Border.all(
                color: selected ? AppColors.gold : AppColors.borderSoft,
                width: selected ? 1.5 : 1,
              ),
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
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: selected ? AppColors.gold : AppColors.fgSoft,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows recent results + upcoming fixtures for followed teams.
class _FollowedTeamFixtures extends ConsumerWidget {
  const _FollowedTeamFixtures({required this.teamIds});
  final Set<String> teamIds;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (teamIds.isEmpty) return const SizedBox.shrink();
    final async = ref.watch(homeFixturesProvider);
    return async.when(
      loading:
          () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Skeleton(height: 32, radius: 8),
          ),
      error: (_, __) => const SizedBox.shrink(),
      data: (f) {
        bool involvesFollowed(MatchDto m) =>
            teamIds.contains(m.homeTeam.id) || teamIds.contains(m.awayTeam.id);
        final recent = f.recent.where(involvesFollowed).take(4).toList();
        final upcoming = f.upcoming.where(involvesFollowed).take(3).toList();
        if (upcoming.isEmpty && recent.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No fixtures found for your teams. Check back soon.',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 11.5,
                height: 1.4,
              ),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (recent.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.only(bottom: 4, top: 4),
                child: Eyebrow('Latest results', gold: true, size: 9),
              ),
              for (final m in recent) _LeagueResultRow(match: m),
            ],
            if (upcoming.isNotEmpty) ...[
              Padding(
                padding: EdgeInsets.only(
                  bottom: 4,
                  top: recent.isNotEmpty ? 8 : 4,
                ),
                child: const Eyebrow('Coming up', gold: true, size: 9),
              ),
              for (final m in upcoming) _LeagueFixtureRow(match: m),
            ],
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
      width: 18,
      height: 18,
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
        mainAxisAlignment:
            alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
        children:
            alignEnd
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
        loading:
            () => ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 4,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder:
                  (_, __) => const SizedBox(
                    width: 140,
                    child: Skeleton(height: 240, radius: 14),
                  ),
            ),
        error:
            (_, __) => const _StripEmpty(
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
      loading:
          () => const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Skeleton(height: 160, radius: 16),
          ),
      error:
          (_, __) => const _StripEmpty(
            title: 'Group draws loading',
            subtitle: 'Couldn’t reach the tournament feed. Pull to refresh.',
          ),
      data: (groups) {
        if (groups.isEmpty) {
          return const _StripEmpty(
            title: 'Group draws not seeded yet',
            subtitle:
                'Run npm run seed:wc in backend/ to populate the tournament.',
          );
        }
        // Pick a stable group for the current day so it doesn't flicker
        // between rebuilds, but rotates across visits over the week.
        final dayOfYear =
            DateTime.now().difference(DateTime(DateTime.now().year)).inDays;
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
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
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
                        style: TextStyle(
                          color: AppColors.gold,
                          fontWeight: FontWeight.w800,
                        ),
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
        SizedBox(
          width: 36,
          height: 36,
          child: PremiumImage(url: row.teamLogo, fit: BoxFit.contain),
        ),
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

// ─────────────────────────────────────────────────────────────────────────────
// BRACKET CARD — surfaces the user's WC bracket on home
// ─────────────────────────────────────────────────────────────────────────────
//
// Three render states:
//   1. No bracket yet  → gold CTA: "Predict the bracket · earn up to 250 gems"
//   2. In progress     → champion crest + progress bar + "X / 55 picks"
//   3. Locked + scored → champion + points so far + leaderboard rank hint
//
// Tap routes to /tournament/bracket. Listens to myBracketProvider + the
// groups provider (needed to resolve the champion teamId → team object
// so we can show the crest + name).
class _BracketCard extends ConsumerWidget {
  const _BracketCard();
  static const _competitionId = 'WC2026';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mine = ref.watch(myBracketProvider(_competitionId));
    final groups = ref.watch(wcGroupsProvider(_competitionId));
    return mine.when(
      loading: () => const SkeletonBlock(height: 92, radius: AppRadii.r4),
      // Unauthed or unreachable — fall back to the CTA state so the
      // surface still funnels users into the bracket.
      error: (_, __) => const _BracketCta(),
      data: (b) {
        if (b == null) return const _BracketCta();
        WcTeamRef? champion;
        final championId = b.championId;
        if (championId != null) {
          for (final g in groups.valueOrNull ?? const <WcGroup>[]) {
            for (final s in g.standings) {
              if (s.team.id == championId) {
                champion = s.team;
                break;
              }
            }
            if (champion != null) break;
          }
        }
        return _BracketStatus(bracket: b, champion: champion);
      },
    );
  }
}

class _BracketCta extends StatelessWidget {
  const _BracketCta();
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadii.r4),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.r4),
        onTap: () => context.push(RoutePaths.bracket),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1F1814), Color(0xFF110C09)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(AppRadii.r4),
            border: Border.all(color: AppColors.goldHairline),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.gold.withValues(alpha: 0.16),
                  border: Border.all(color: AppColors.goldHairline),
                ),
                child: const Icon(
                  Icons.account_tree_outlined,
                  size: 20,
                  color: AppColors.gold,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Eyebrow('WORLD CUP BRACKET', gold: true, size: 10),
                    SizedBox(height: 2),
                    Text(
                      'Predict who wins the trophy',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        color: AppColors.fg,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Group stage → final. Earn gems for every correct pick — 500 for the champion.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: AppColors.muted,
                        height: 1.35,
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

class _BracketStatus extends StatelessWidget {
  const _BracketStatus({required this.bracket, required this.champion});
  final BracketDto bracket;
  final WcTeamRef? champion;

  /// 48 group positions + 8 best-thirds + 32 knockout winners = 88.
  /// Single source of truth so it can't drift from the bracket screen.
  static const _totalSlots = wc2026TotalPicks;

  @override
  Widget build(BuildContext context) {
    final filled = bracket.totalPickCount;
    final pct = (filled / _totalSlots).clamp(0.0, 1.0);
    final scored = bracket.pointsAwarded > 0;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadii.r4),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.r4),
        onTap: () => context.push(RoutePaths.bracket),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
          decoration: BoxDecoration(
            color: AppColors.surface2,
            borderRadius: BorderRadius.circular(AppRadii.r4),
            border: Border.all(color: AppColors.goldHairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Champion crest or trophy fallback.
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.gold.withValues(alpha: 0.16),
                      border: Border.all(color: AppColors.goldHairline),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child:
                        champion?.crestUrl != null
                            ? Padding(
                              padding: const EdgeInsets.all(4),
                              child: PremiumImage(
                                url: champion!.crestUrl,
                                fit: BoxFit.contain,
                              ),
                            )
                            : const Icon(
                              Icons.emoji_events_rounded,
                              size: 20,
                              color: AppColors.gold,
                            ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Eyebrow('YOUR BRACKET', gold: true, size: 10),
                        const SizedBox(height: 2),
                        Text(
                          champion != null
                              ? 'Champion: ${champion!.shortName}'
                              : 'Pick your champion',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                            color: AppColors.fg,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (scored)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        '${bracket.pointsAwarded} pts',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.gold,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    )
                  else
                    const Icon(Icons.chevron_right, color: AppColors.muted),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 6,
                  backgroundColor: AppColors.surface3,
                  valueColor: const AlwaysStoppedAnimation(AppColors.gold),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    bracket.isLocked
                        ? 'Locked  ·  $filled / $_totalSlots picks'
                        : '$filled / $_totalSlots picks',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.muted,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const Spacer(),
                  if (!bracket.isLocked && filled < _totalSlots)
                    const Text(
                      'Tap to continue →',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.gold,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
