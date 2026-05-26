import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/widgets/empty_states.dart';
import '../../../../core/widgets/eyebrow.dart';
import '../../../../core/widgets/loading_skeletons.dart';
import '../../../../core/widgets/pitch_scaffold.dart';
import '../../../../core/widgets/premium_image.dart';
import '../../data/world_cup_models.dart';
import '../../data/world_cup_repository.dart';

/// Full-screen group standings — every group, every team, with the qualifying
/// rail (positions 1–2 marked gold). Lighter UX equivalent of the World Cup
/// hub's compact horizontal rail.
class StandingsScreen extends ConsumerWidget {
  const StandingsScreen({super.key, required this.competitionId});
  final String competitionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(wcGroupsProvider(competitionId));
    return PitchScreen(
      title: 'Group standings',
      onBack: () => context.canPop() ? context.pop() : context.go('/world-cup'),
      child: groups.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(16),
          child: SkeletonBlock(height: 280, radius: 16),
        ),
        error: (_, __) => const PitchEmptyState(
          eyebrow: 'Standings',
          title: 'Couldn’t load standings',
          subtitle: 'Pull to retry once you’re back online.',
          glyph: EmptyGlyph.trophy,
        ),
        data: (gs) {
          if (gs.isEmpty) {
            return const PitchEmptyState(
              eyebrow: 'Standings',
              title: 'Groups not drawn yet',
              subtitle: 'Standings appear once the draw lands. Check back closer to kickoff.',
              glyph: EmptyGlyph.trophy,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            itemCount: gs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (_, i) => _GroupCard(group: gs[i]),
          );
        },
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group});
  final WcGroup group;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.r4),
        border: Border.all(color: AppColors.borderSoft),
        gradient: const LinearGradient(
          colors: [AppColors.surface2, AppColors.surface],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RichText(
            text: TextSpan(
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.84,
                color: AppColors.fg,
              ),
              children: [
                const TextSpan(text: 'GROUP '),
                TextSpan(
                  text: group.letter,
                  style: const TextStyle(
                    fontFamily: 'IowanOldStyle',
                    fontFamilyFallback: ['Charter', 'Georgia', 'serif'],
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w500,
                    color: AppColors.gold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const _HeaderRow(),
          for (final s in group.standings) _StandingRow(row: s),
        ],
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: const [
          SizedBox(width: 22),
          SizedBox(width: 22),
          Expanded(child: Eyebrow('Team', size: 9)),
          SizedBox(width: 26, child: Center(child: Eyebrow('P', size: 9))),
          SizedBox(width: 26, child: Center(child: Eyebrow('W', size: 9))),
          SizedBox(width: 26, child: Center(child: Eyebrow('D', size: 9))),
          SizedBox(width: 26, child: Center(child: Eyebrow('L', size: 9))),
          SizedBox(width: 32, child: Center(child: Eyebrow('GD', size: 9))),
          SizedBox(width: 30, child: Center(child: Eyebrow('Pts', size: 9))),
        ],
      ),
    );
  }
}

class _StandingRow extends StatelessWidget {
  const _StandingRow({required this.row});
  final GroupStandingRow row;
  @override
  Widget build(BuildContext context) {
    final qualifying = row.position <= 2;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.borderSoft, width: 1)),
      ),
      child: Row(
        children: [
          // Qualifying rail.
          Container(
            width: 2,
            height: 18,
            margin: const EdgeInsets.only(right: 8),
            color: qualifying ? AppColors.gold : Colors.transparent,
          ),
          SizedBox(
            width: 14,
            child: Text(
              '${row.position}',
              style: const TextStyle(
                fontFamily: 'JetBrainsMono',
                fontFamilyFallback: ['SF Mono', 'Menlo', 'monospace'],
                fontSize: 11,
                color: AppColors.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(
            width: 22, height: 22,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: PremiumImage(url: row.team.crestUrl, fit: BoxFit.contain),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              row.team.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: AppColors.fg,
                letterSpacing: -0.13,
              ),
            ),
          ),
          _Cell(text: row.played.toString()),
          _Cell(text: row.won.toString()),
          _Cell(text: row.drawn.toString()),
          _Cell(text: row.lost.toString()),
          _Cell(
            width: 32,
            text: (row.goalDiff >= 0 ? '+' : '') + row.goalDiff.toString(),
          ),
          _Cell(
            width: 30,
            text: row.points.toString(),
            color: AppColors.gold,
            weight: FontWeight.w800,
          ),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.text, this.width = 26, this.color, this.weight});
  final String text;
  final double width;
  final Color? color;
  final FontWeight? weight;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'JetBrainsMono',
          fontFamilyFallback: const ['SF Mono', 'Menlo', 'monospace'],
          fontSize: 11,
          color: color ?? AppColors.muted,
          fontWeight: weight ?? FontWeight.w600,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
