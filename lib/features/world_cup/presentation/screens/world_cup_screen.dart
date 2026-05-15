import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/widgets/eyebrow.dart';
import '../../../../core/widgets/pitch_buttons.dart';
import '../../../../core/widgets/pitch_scaffold.dart';
import '../../../../core/widgets/premium_image.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../data/world_cup_models.dart';
import '../../data/world_cup_repository.dart';

const _wcCompetitionId = 'WC2026';

class WorldCupScreen extends ConsumerWidget {
  const WorldCupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(wcOverviewProvider(_wcCompetitionId));
    final groups = ref.watch(wcGroupsProvider(_wcCompetitionId));

    return PitchScreen(
      title: 'FIFA World Cup 2026',
      onBack: context.canPop() ? () => context.pop() : null,
      trailing: CircleIconButton(icon: Icons.help_outline, onPressed: () {}),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            // Hero
            overview.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Skeleton(height: 220, radius: 20),
              ),
              error: (e, _) => _ErrorTile(message: '$e'),
              data: (o) => _Hero(overview: o),
            ),
            const SizedBox(height: 24),
            // Opening match
            overview.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (o) => o.openingMatch == null
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _OpeningMatchCard(opening: o.openingMatch!),
                    ),
            ),
            // Groups
            const SectionHead(title: 'Groups', action: 'All →'),
            groups.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Skeleton(height: 240, radius: 16),
              ),
              error: (e, _) => _ErrorTile(message: '$e'),
              data: (gs) {
                if (gs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'Groups will appear once the draw is complete.',
                      style: TextStyle(color: AppColors.muted, fontSize: 13),
                    ),
                  );
                }
                return SizedBox(
                  height: 240,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: gs.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (_, i) => _GroupCard(group: gs[i]),
                  ),
                );
              },
            ),
            // Venues
            const SectionHead(title: 'Venues'),
            overview.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (o) {
                if (o.venues.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'Venue list publishes after the host cities confirm.',
                      style: TextStyle(color: AppColors.muted, fontSize: 13),
                    ),
                  );
                }
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.6,
                    children: o.venues.take(6).map(_VenueCard.new).toList(),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ─── HERO ──────────────────────────────────────────────────────────────────

class _Hero extends StatelessWidget {
  const _Hero({required this.overview});
  final WcOverview overview;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.r5),
          border: Border.all(color: AppColors.goldHairline),
          gradient: const LinearGradient(
            colors: [Color(0xFF211D17), Color(0xFF120F0D)],
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.7),
              blurRadius: 60,
              spreadRadius: -28,
              offset: const Offset(0, 32),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Text('★ ', style: TextStyle(color: AppColors.goldDeep)),
                Eyebrow('FIFA World Cup 2026', gold: true, size: 11),
              ],
            ),
            const SizedBox(height: 14),
            RichText(
              text: const TextSpan(
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.62,
                  color: AppColors.fg,
                  height: 0.95,
                ),
                children: [
                  TextSpan(text: 'North America\nopens its '),
                  TextSpan(
                    text: 'gates.',
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
            const SizedBox(height: 12),
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                _MetaPip('${overview.teamCount} nations'),
                _MetaPip('${overview.venueCount} cities'),
                _MetaPip('${overview.matchCount} matches'),
                _MetaPip(_dateRange(overview.startsAt, overview.endsAt)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _dateRange(DateTime a, DateTime b) {
    final df = DateFormat('d MMM');
    return '${df.format(a)} – ${df.format(b)}';
  }
}

class _MetaPip extends StatelessWidget {
  const _MetaPip(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 4, height: 4,
          decoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Eyebrow(text, size: 10),
      ],
    );
  }
}

// ─── OPENING MATCH ─────────────────────────────────────────────────────────

class _OpeningMatchCard extends StatelessWidget {
  const _OpeningMatchCard({required this.opening});
  final WcOpeningMatch opening;
  @override
  Widget build(BuildContext context) {
    final df = DateFormat('EEE d MMM · HH:mm');
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.r5),
        border: Border.all(color: AppColors.border),
        color: AppColors.surface,
      ),
      child: Column(
        children: [
          Eyebrow('Opening match · ${opening.stage ?? "Group A"}'),
          const SizedBox(height: 4),
          Eyebrow(df.format(opening.kickoffAt.toLocal())),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(child: _OpenSide(team: opening.homeTeam, alignEnd: false)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'vs',
                  style: TextStyle(
                    fontFamily: 'IowanOldStyle',
                    fontFamilyFallback: ['Charter', 'Georgia', 'serif'],
                    fontStyle: FontStyle.italic,
                    fontSize: 18,
                    color: AppColors.gold,
                  ),
                ),
              ),
              Expanded(child: _OpenSide(team: opening.awayTeam, alignEnd: true)),
            ],
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: AppColors.borderSoft),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: Eyebrow(opening.venue ?? '—', size: 10)),
              if (opening.stage != null) Eyebrow(opening.stage!, size: 10, gold: true),
            ],
          ),
        ],
      ),
    );
  }
}

class _OpenSide extends StatelessWidget {
  const _OpenSide({required this.team, required this.alignEnd});
  final WcTeamRef team;
  final bool alignEnd;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 56, height: 40,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: PremiumImage(url: team.crestUrl, fit: BoxFit.contain),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          team.name,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w800,
            fontSize: 16,
            letterSpacing: -0.24,
            color: AppColors.fg,
          ),
        ),
        const SizedBox(height: 4),
        Eyebrow(team.shortName, size: 9),
      ],
    );
  }
}

// ─── GROUP CARD ────────────────────────────────────────────────────────────

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group});
  final WcGroup group;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.r4),
        border: Border.all(color: AppColors.borderSoft),
        gradient: const LinearGradient(
          colors: [AppColors.surface2, AppColors.surface],
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.78,
                    color: AppColors.fg,
                  ),
                  children: [
                    const TextSpan(text: 'Group '),
                    TextSpan(
                      text: group.letter,
                      style: const TextStyle(
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
            ],
          ),
          const SizedBox(height: 12),
          // Header row
          const _GroupRow.header(),
          for (final s in group.standings)
            _GroupRow(standing: s),
        ],
      ),
    );
  }
}

class _GroupRow extends StatelessWidget {
  const _GroupRow({required this.standing}) : isHeader = false;
  const _GroupRow.header() : standing = null, isHeader = true;
  final GroupStandingRow? standing;
  final bool isHeader;
  @override
  Widget build(BuildContext context) {
    if (isHeader) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: const [
            SizedBox(width: 16, child: Eyebrow('#', size: 9)),
            SizedBox(width: 28),
            Expanded(child: Eyebrow('Team', size: 9)),
            SizedBox(width: 22, child: Center(child: Eyebrow('P', size: 9))),
            SizedBox(width: 28, child: Center(child: Eyebrow('GD', size: 9))),
            SizedBox(width: 22, child: Center(child: Eyebrow('Pts', size: 9))),
          ],
        ),
      );
    }
    final s = standing!;
    final isQualifying = s.position <= 2;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.borderSoft, width: 1)),
      ),
      child: Row(
        children: [
          if (isQualifying)
            Container(
              width: 2, height: 14,
              margin: const EdgeInsets.only(right: 4),
              color: AppColors.gold,
            )
          else
            const SizedBox(width: 6),
          SizedBox(width: 12, child: MonoNum('${s.position}', size: 10, color: AppColors.muted)),
          const SizedBox(width: 8),
          SizedBox(
            width: 22, height: 16,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: PremiumImage(url: s.team.crestUrl, fit: BoxFit.contain),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              s.team.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: AppColors.fg,
                letterSpacing: -0.12,
              ),
            ),
          ),
          SizedBox(width: 22, child: Center(child: MonoNum(s.played.toString(), size: 10, color: AppColors.muted))),
          SizedBox(width: 28, child: Center(child: MonoNum((s.goalDiff >= 0 ? '+' : '') + s.goalDiff.toString(), size: 10, color: AppColors.muted))),
          SizedBox(width: 22, child: Center(child: MonoNum(s.points.toString(), size: 12, color: AppColors.gold, weight: FontWeight.w800))),
        ],
      ),
    );
  }
}

// ─── VENUE CARD ────────────────────────────────────────────────────────────

class _VenueCard extends StatelessWidget {
  const _VenueCard(this.venue);
  final WcVenueSummary venue;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.r3),
        border: Border.all(color: AppColors.borderSoft),
        gradient: const LinearGradient(
          colors: [AppColors.surface2, AppColors.surface],
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: 0, top: 0, bottom: 0,
            child: Container(
              width: 4,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.gold, Color(0xFF7E5A1F)],
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Eyebrow(venue.name.split(',').last.trim(), gold: true, size: 9),
              Text(
                venue.name.split(',').first,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.fg,
                  letterSpacing: -0.13,
                ),
              ),
              Eyebrow('${venue.matchCount} matches', size: 10),
            ],
          ),
        ],
      ),
    );
  }
}

class _ErrorTile extends StatelessWidget {
  const _ErrorTile({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Text(
        message,
        style: const TextStyle(color: AppColors.live, fontSize: 12),
      ),
    );
  }
}
