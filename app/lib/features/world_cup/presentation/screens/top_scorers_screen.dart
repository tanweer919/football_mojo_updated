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
import '../../../insights/data/insights_repository.dart';
import '../../../insights/data/models/top_player_dto.dart';

/// Top-scorers + top-assists for the headline competition. Two-tab segmented
/// control at the top, list below — same row template for both.
class TopScorersScreen extends ConsumerStatefulWidget {
  const TopScorersScreen({super.key});
  @override
  ConsumerState<TopScorersScreen> createState() => _TopScorersScreenState();
}

class _TopScorersScreenState extends ConsumerState<TopScorersScreen> {
  bool _showAssists = false;

  @override
  Widget build(BuildContext context) {
    final async = _showAssists
        ? ref.watch(topAssistsProvider)
        : ref.watch(topScorersProvider);
    return PitchScreen(
      title: 'Stats',
      onBack: () => context.canPop() ? context.pop() : context.go('/world-cup'),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
            child: _SegControl(
              showAssists: _showAssists,
              onChange: (v) => setState(() => _showAssists = v),
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                itemCount: 6,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, __) => const SkeletonBlock(height: 64, radius: 12),
              ),
              error: (_, __) => const PitchEmptyState(
                title: 'Stats unavailable',
                subtitle: 'Couldn’t reach the stats feed. Pull to retry.',
                glyph: EmptyGlyph.trophy,
              ),
              data: (rows) {
                if (rows.isEmpty) {
                  return PitchEmptyState(
                    eyebrow: _showAssists ? 'Top assists' : 'Top scorers',
                    title: 'No leaderboard yet',
                    subtitle: _showAssists
                        ? 'Assist leaders update as the matches are played.'
                        : 'The Golden Boot race is underway — first goals incoming.',
                    glyph: EmptyGlyph.trophy,
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _Row(
                    rank: i + 1,
                    player: rows[i],
                    label: _showAssists ? 'assists' : 'goals',
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SegControl extends StatelessWidget {
  const _SegControl({required this.showAssists, required this.onChange});
  final bool showAssists;
  final ValueChanged<bool> onChange;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.r3),
        color: AppColors.surface2,
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SegButton(
              label: 'Top scorers',
              active: !showAssists,
              onTap: () => onChange(false),
            ),
          ),
          Expanded(
            child: _SegButton(
              label: 'Top assists',
              active: showAssists,
              onTap: () => onChange(true),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegButton extends StatelessWidget {
  const _SegButton({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.r2),
          gradient: active
              ? const LinearGradient(
                  colors: [AppColors.surface3, AppColors.surface2],
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                )
              : null,
          border: active ? Border.all(color: AppColors.goldHairline) : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: active ? AppColors.gold : AppColors.muted,
            ),
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.rank, required this.player, required this.label});
  final int rank;
  final TopPlayerDto player;
  final String label;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.r3),
        border: Border.all(color: AppColors.borderSoft),
        color: AppColors.surface2,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '$rank',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: rank <= 3 ? AppColors.gold : AppColors.muted,
                letterSpacing: -0.36,
              ),
            ),
          ),
          ClipOval(
            child: SizedBox(
              width: 40, height: 40,
              child: PremiumImage(url: player.playerPhoto, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  player.playerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.21,
                    color: AppColors.fg,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (player.teamLogo != null) ...[
                      SizedBox(
                        width: 14, height: 14,
                        child: PremiumImage(url: player.teamLogo, fit: BoxFit.contain),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(
                        player.teamName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                player.statValue.toString(),
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.gold,
                  letterSpacing: -0.44,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              Eyebrow(label, size: 9),
            ],
          ),
        ],
      ),
    );
  }
}
