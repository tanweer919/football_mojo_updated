import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/widgets/eyebrow.dart';
import '../../../../core/widgets/loading_skeletons.dart';
import '../../../../core/widgets/pcard.dart';
import '../../../../core/widgets/pitch_buttons.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/widgets/pitch_scaffold.dart';
import '../../../album/data/models/card_models.dart';
import '../../../competitions/data/competitions_repository.dart';
import '../../data/models/fantasy_models.dart';
import '../providers/fantasy_providers.dart';

/// Fantasy lobby — single, focused flow:
///   1. Big "what to do next" card  — either Build XI / Edit XI / GW locked.
///   2. Tournament summary  — stake, prize tiers, deadlines.
///   3. (Coming soon) other formats — collapsed teaser, no fake live counts.
///
/// Replaces the previous lobby's mock-rank hero, fake "8.4M live" badges, and
/// confusing 3-section split.
class FantasyHomeScreen extends ConsumerStatefulWidget {
  const FantasyHomeScreen({super.key, this.slug});
  final String? slug;
  @override
  ConsumerState<FantasyHomeScreen> createState() => _FantasyHomeScreenState();
}

class _FantasyHomeScreenState extends ConsumerState<FantasyHomeScreen> {
  Timer? _ticker;
  Duration _untilLock = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final String slug = widget.slug ?? ref.read(defaultFantasySlugProvider);
      final gw = ref.read(currentGameweekProvider(slug)).valueOrNull;
      if (gw == null) return;
      final remaining = gw.lockAt.difference(DateTime.now());
      if (mounted) setState(() => _untilLock = remaining.isNegative ? Duration.zero : remaining);
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String resolvedSlug = widget.slug ?? ref.watch(defaultFantasySlugProvider);
    final tournament = ref.watch(tournamentProvider(resolvedSlug));
    final gw = ref.watch(currentGameweekProvider(resolvedSlug));
    final lineupAsync = gw.maybeWhen<AsyncValue<FantasyLineupDto?>>(
      data: (g) => g == null
          ? const AsyncValue.data(null)
          : ref.watch(myLineupProvider((slug: resolvedSlug, gameweekId: g.id))),
      orElse: () => const AsyncValue.data(null),
    );
    final lineup = lineupAsync.valueOrNull;

    return PitchScreen(
      title: 'Fantasy',
      onBack: () => context.canPop() ? context.pop() : context.go('/home'),
      // Quick access to the scoring breakdown — was orphaned in the route
      // table before, no one could find it. Living up here keeps the
      // "how does this game work?" answer one tap away.
      trailing: CircleIconButton(
        icon: Icons.help_outline,
        onPressed: () => context.push(RoutePaths.scoringRules),
      ),
      child: tournament.when(
        loading: () => const _LoadingState(),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(20),
          child: Text('$e', style: const TextStyle(color: AppColors.live)),
        ),
        data: (t) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _PrimaryAction(
                  tournament: t,
                  gameweek: gw.valueOrNull,
                  lineup: lineup,
                  untilLock: _untilLock,
                  onBuild: (gameweekId) =>
                      context.push('/fantasy/${t.slug}/gameweek/$gameweekId/builder'),
                ),
              ),
              const SectionHead(title: 'About this cup', padding: EdgeInsets.fromLTRB(20, 24, 20, 12)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _AboutCard(tournament: t),
              ),
              const SectionHead(title: 'Top-3 prizes', padding: EdgeInsets.fromLTRB(20, 24, 20, 12)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: _PrizeShelf(),
              ),
              const SectionHead(title: 'Other formats', padding: EdgeInsets.fromLTRB(20, 24, 20, 12)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: _ComingSoonGrid(),
              ),
              const SizedBox(height: 32),
            ],
          ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.all(16),
        child: Column(children: [SkeletonBlock(height: 220, radius: 20), SizedBox(height: 16), SkeletonBlock(height: 140, radius: 16)]),
      );
}

/// Trims long cup names ("FootballMojo Global Cup 2026" → "Global Cup") so
/// the eyebrow stays on one line. Falls back to the full name when no known
/// pattern matches.
String _shortTournamentLabel(String name) {
  if (name.contains('Global Cup')) return 'Global Cup';
  if (name.contains('Champions League')) return 'Champions League';
  if (name.contains('World Cup')) return 'FIFA World Cup';
  return name;
}

// ─── PRIMARY ACTION CARD ───────────────────────────────────────────────────
// One card. One CTA. State varies by gameweek + lineup status.

class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({
    required this.tournament,
    required this.gameweek,
    required this.lineup,
    required this.untilLock,
    required this.onBuild,
  });
  final FantasyTournamentDto tournament;
  final FantasyGameweekDto? gameweek;
  final FantasyLineupDto? lineup;
  final Duration untilLock;
  final void Function(String gameweekId) onBuild;

  @override
  Widget build(BuildContext context) {
    final hasGw = gameweek != null;
    final locked = hasGw ? gameweek!.isLocked : false;
    final hasLineup = lineup != null;
    final ctaLabel = !hasGw
        ? 'No active gameweek'
        : locked
            ? 'View saved XI'
            : (hasLineup ? 'Edit your XI' : 'Build your XI');

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.r5),
        border: Border.all(color: AppColors.goldHairline),
        gradient: const LinearGradient(
          colors: [Color(0xFF1F1814), Color(0xFF110C09)],
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 50, spreadRadius: -20, offset: const Offset(0, 24)),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.r5),
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [Color(0x40C99A3D), Colors.transparent],
                    center: Alignment(1, -1),
                    radius: 0.8,
                  ),
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Eyebrow(
                      // Long names like "FootballMojo Global Cup 2026" wrap to
                      // two lines and crowd the title — show only the cup name
                      // (drop year) and let the headline carry the weight.
                      _shortTournamentLabel(tournament.name),
                      gold: true,
                      size: 11,
                    ),
                  ),
                  if (hasGw) Eyebrow('GW ${gameweek!.number}', gold: true, size: 11),
                ],
              ),
              const SizedBox(height: 14),
              RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.12,
                    color: AppColors.fg,
                    height: 1.05,
                  ),
                  children: [
                    if (!hasGw)
                      const TextSpan(text: 'Next gameweek\nopens soon.')
                    else if (locked)
                      const TextSpan(text: 'Gameweek\nlocked.')
                    else if (hasLineup)
                      const TextSpan(text: 'Tweak your\nXI before kickoff.')
                    else ...[
                      const TextSpan(text: 'Build your\n'),
                      TextSpan(
                        text: '5-a-side',
                        style: const TextStyle(
                          fontFamily: 'IowanOldStyle',
                          fontFamilyFallback: ['Charter', 'Georgia', 'serif'],
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w500,
                          color: AppColors.gold,
                        ),
                      ),
                      const TextSpan(text: ' XI.'),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (hasGw && !locked) _Countdown(remaining: untilLock),
              if (hasLineup) ...[
                const SizedBox(height: 14),
                _LineupSummary(lineup: lineup!, budget: tournament.budget),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: GoldButton(
                      label: ctaLabel,
                      onPressed: hasGw ? () => onBuild(gameweek!.id) : null,
                      icon: locked ? Icons.lock_outline : Icons.shield,
                      expand: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Countdown extends StatelessWidget {
  const _Countdown({required this.remaining});
  final Duration remaining;
  @override
  Widget build(BuildContext context) {
    final d = remaining.inDays;
    final h = remaining.inHours % 24;
    final m = remaining.inMinutes % 60;
    final s = remaining.inSeconds % 60;
    final clock = d > 0
        ? '${d}d ${h.toString().padLeft(2, '0')}h ${m.toString().padLeft(2, '0')}m'
        : '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return Row(
      children: [
        const Icon(Icons.timer_outlined, size: 14, color: AppColors.muted),
        const SizedBox(width: 6),
        const Eyebrow('Locks in', size: 10),
        const SizedBox(width: 8),
        Text(
          clock,
          style: const TextStyle(
            fontFamily: 'JetBrainsMono',
            fontFamilyFallback: ['SF Mono', 'Menlo', 'monospace'],
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.fg,
            letterSpacing: 0.8,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _LineupSummary extends StatelessWidget {
  const _LineupSummary({required this.lineup, required this.budget});
  final FantasyLineupDto lineup;
  final double budget;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.r3),
        border: Border.all(color: AppColors.borderSoft),
        color: AppColors.surface3.withValues(alpha: 0.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: _MiniStat(
              label: 'Spent',
              value: '${lineup.budgetUsed.toStringAsFixed(0)} / ${budget.toInt()}',
            ),
          ),
          Container(width: 1, height: 24, color: AppColors.borderSoft),
          Expanded(
            child: _MiniStat(
              label: 'Points',
              value: lineup.totalPoints.toStringAsFixed(0),
              gold: true,
            ),
          ),
          Container(width: 1, height: 24, color: AppColors.borderSoft),
          Expanded(
            child: _MiniStat(
              label: 'Rank',
              value: lineup.rank?.toString() ?? '—',
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value, this.gold = false});
  final String label;
  final String value;
  final bool gold;
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: gold ? AppColors.gold : AppColors.fg,
            letterSpacing: -0.32,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 2),
        Eyebrow(label, size: 9),
      ],
    );
  }
}

// ─── ABOUT CARD ────────────────────────────────────────────────────────────

class _AboutCard extends StatelessWidget {
  const _AboutCard({required this.tournament});
  final FantasyTournamentDto tournament;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.r4),
        border: Border.all(color: AppColors.borderSoft),
        color: AppColors.surface2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tournament.description ??
                'Pick 5 starters from any team in the cup. ${tournament.budget.toInt()}-pt budget. Captain scores ×2. New gameweek every round.',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: AppColors.fgSoft,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 14),
          Container(height: 1, color: AppColors.borderSoft),
          const SizedBox(height: 14),
          const Row(
            children: [
              Expanded(child: _AboutBullet(label: 'Entry', value: 'Free')),
              Expanded(child: _AboutBullet(label: 'Format', value: '5-a-side')),
              Expanded(child: _AboutBullet(label: 'Captain', value: '×2 pts')),
            ],
          ),
        ],
      ),
    );
  }
}

class _AboutBullet extends StatelessWidget {
  const _AboutBullet({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Eyebrow(label, size: 9),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.fg,
            letterSpacing: -0.14,
          ),
        ),
      ],
    );
  }
}

// ─── PRIZE SHELF ───────────────────────────────────────────────────────────

class _PrizeShelf extends StatelessWidget {
  const _PrizeShelf();
  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: const [
          Expanded(child: PCard(rarity: CardRarity.ICONIC,    rating: 99, name: 'Champion', position: '1ST', country: '2026')),
          SizedBox(width: 8),
          Expanded(child: PCard(rarity: CardRarity.LEGENDARY, rating: 95, name: 'Silver',   position: '2ND', country: '2026')),
          SizedBox(width: 8),
          Expanded(child: PCard(rarity: CardRarity.EPIC,      rating: 92, name: 'Bronze',   position: '3RD', country: '2026')),
        ],
      ),
    );
  }
}

// ─── COMING SOON GRID ──────────────────────────────────────────────────────

class _ComingSoonGrid extends StatelessWidget {
  const _ComingSoonGrid();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.r4),
        border: Border.all(color: AppColors.borderSoft),
        color: AppColors.surface2,
      ),
      child: Column(
        children: const [
          _SoonRow(icon: Icons.flash_on, label: '1v1 Ladder', desc: 'Quick weekly duels'),
          SizedBox(height: 8),
          _SoonRow(icon: Icons.sports_kabaddi, label: 'Friend leagues', desc: 'Round-robin or knockout'),
          SizedBox(height: 8),
          _SoonRow(icon: Icons.sort, label: 'Snake draft', desc: 'Live-pick squads'),
        ],
      ),
    );
  }
}

class _SoonRow extends StatelessWidget {
  const _SoonRow({required this.icon, required this.label, required this.desc});
  final IconData icon;
  final String label;
  final String desc;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: AppColors.surface3,
            border: Border.all(color: AppColors.borderSoft),
          ),
          child: Icon(icon, size: 16, color: AppColors.muted),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.fg,
                ),
              ),
              const SizedBox(height: 2),
              Eyebrow(desc, size: 10),
            ],
          ),
        ),
        const Eyebrow('Coming soon', size: 9),
      ],
    );
  }
}
