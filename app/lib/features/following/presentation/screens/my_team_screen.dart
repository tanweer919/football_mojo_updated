import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/ads/ad_widgets.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/widgets/countdown_text.dart';
import '../../../../core/widgets/empty_states.dart';
import '../../../../core/widgets/eyebrow.dart';
import '../../../home/presentation/providers/home_dashboard_providers.dart';
import '../../../news/data/models/news_article.dart';
import '../../../news/presentation/widgets/news_thumb.dart';
import '../../../profile/data/profile_models.dart' show ProfileTeam;
import '../../../profile/data/profile_repository.dart';
import '../../../scores/data/models/match_dto.dart';
import '../../../scores/presentation/widgets/match_card.dart';
import '../../../world_cup/data/world_cup_repository.dart';

const _wc = 'WC2026';

/// "My Team" — the followed-team home: countdown to the next match, the team's
/// group table, and their fixtures. Built off the backend follow list.
class MyTeamScreen extends ConsumerStatefulWidget {
  const MyTeamScreen({super.key});
  @override
  ConsumerState<MyTeamScreen> createState() => _MyTeamScreenState();
}

class _MyTeamScreenState extends ConsumerState<MyTeamScreen> {
  String? _teamId;

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(myProfileProvider);
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        // Tab navigation doesn't push a route, so there's no automatic back
        // button — add one that pops when possible, else returns Home.
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(RoutePaths.home),
        ),
        title: const Text('My Team'),
        actions: [
          IconButton(
            tooltip: 'Edit teams',
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => context.push(RoutePaths.teamPicker),
          ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
        error: (e, _) => Center(child: Text('$e')),
        data: (profile) {
          final teams = profile?.followedTeams ?? const <ProfileTeam>[];
          if (teams.isEmpty) return _Empty();
          final selected =
              teams.firstWhere((t) => t.id == _teamId, orElse: () => teams.first);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            children: [
              if (teams.length > 1) ...[
                _TeamChips(
                  teams: teams,
                  selectedId: selected.id,
                  onSelect: (id) => setState(() => _teamId = id),
                ),
                const SizedBox(height: 12),
              ],
              _TeamHeader(team: selected),
              const SizedBox(height: 16),
              _NextMatchCard(teamId: selected.id),
              const SizedBox(height: 20),
              _SectionLabel('Group standings'),
              const SizedBox(height: 8),
              _TeamGroup(teamId: selected.id),
              const SizedBox(height: 16),
              const Center(child: PitchBannerAd(large: true)),
              const SizedBox(height: 20),
              _SectionLabel('Fixtures'),
              const SizedBox(height: 8),
              _TeamFixtures(teamId: selected.id),
              const SizedBox(height: 20),
              _TeamStories(teamId: selected.id),
            ],
          );
        },
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const PitchEmptyState(
              eyebrow: 'My Team',
              title: 'Follow a team',
              subtitle:
                  'Pick a team to get a countdown to their next match, their group table and every fixture in one place.',
              glyph: EmptyGlyph.football,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => context.push(RoutePaths.teamPicker),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Choose a team'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TeamChips extends StatelessWidget {
  const _TeamChips({required this.teams, required this.selectedId, required this.onSelect});
  final List<ProfileTeam> teams;
  final String selectedId;
  final ValueChanged<String> onSelect;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: teams.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final t = teams[i];
          final sel = t.id == selectedId;
          return ChoiceChip(
            selected: sel,
            onSelected: (_) => onSelect(t.id),
            avatar: t.crestUrl != null
                ? ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: t.crestUrl!,
                      width: 20,
                      height: 20,
                      fit: BoxFit.contain,
                    ),
                  )
                : null,
            label: Text(t.shortName),
            labelStyle: TextStyle(
              fontWeight: FontWeight.w700,
              color: sel ? AppColors.bgDeep : AppColors.fg,
            ),
            selectedColor: AppColors.gold,
            backgroundColor: AppColors.surface2,
          );
        },
      ),
    );
  }
}

class _TeamHeader extends StatelessWidget {
  const _TeamHeader({required this.team});
  final ProfileTeam team;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 56,
          height: 56,
          child: team.crestUrl != null
              ? CachedNetworkImage(imageUrl: team.crestUrl!, fit: BoxFit.contain)
              : const Icon(Icons.shield_outlined, color: AppColors.muted, size: 40),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                team.name,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: AppColors.fg,
                ),
              ),
              if (team.competitionName != null)
                Eyebrow(team.competitionName!, gold: true, size: 10),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: AppColors.fg,
          letterSpacing: -0.3,
        ),
      );
}

/// All WC fixtures involving the team (from the home fixtures bundle).
List<MatchDto> _teamMatches(WidgetRef ref, String teamId) {
  final f = ref.watch(homeFixturesProvider).valueOrNull;
  if (f == null) return const [];
  bool involves(MatchDto m) => m.homeTeam.id == teamId || m.awayTeam.id == teamId;
  return [...f.upcoming.where(involves), ...f.recent.where(involves)];
}

class _NextMatchCard extends ConsumerWidget {
  const _NextMatchCard({required this.teamId});
  final String teamId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matches = _teamMatches(ref, teamId);
    // Next = the live one if any, else the earliest upcoming.
    final live = matches.where((m) => m.isLive).toList()
      ..sort((a, b) => a.kickoffAt.compareTo(b.kickoffAt));
    final upcoming = matches.where((m) => !m.isLive && !m.isFinished).toList()
      ..sort((a, b) => a.kickoffAt.compareTo(b.kickoffAt));
    final next = live.isNotEmpty ? live.first : (upcoming.isNotEmpty ? upcoming.first : null);
    if (next == null) {
      return _box(
        const Text('No upcoming match scheduled.',
            style: TextStyle(color: AppColors.muted, fontSize: 13)),
      );
    }
    return _box(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Eyebrow(next.isLive ? 'LIVE NOW' : 'UNTIL NEXT MATCH', gold: !next.isLive),
          ),
          const SizedBox(height: 8),
          Center(
            child: next.isLive
                ? const Text("It's on — tap below to follow live.",
                    style: TextStyle(color: AppColors.live, fontWeight: FontWeight.w800))
                : CountdownText(
                    target: next.kickoffAt,
                    expiredLabel: 'Kicking off',
                    style: const TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontFamilyFallback: ['SF Mono', 'Menlo', 'monospace'],
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppColors.gold,
                      letterSpacing: 1,
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          MatchCard(match: next),
        ],
      ),
    );
  }

  Widget _box(Widget child) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.r4),
          border: Border.all(color: AppColors.goldHairline),
          gradient: const LinearGradient(
            colors: [Color(0xFF1A1714), Color(0xFF0F0D0B)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: child,
      );
}

class _TeamGroup extends ConsumerWidget {
  const _TeamGroup({required this.teamId});
  final String teamId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(wcGroupsProvider(_wc)).valueOrNull;
    if (groups == null || groups.isEmpty) {
      return const Text('Group standings update live as matches are played.',
          style: TextStyle(color: AppColors.muted, fontSize: 13));
    }
    final group = groups.firstWhere(
      (g) => g.standings.any((s) => s.team.id == teamId),
      orElse: () => groups.first,
    );
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.r4),
        border: Border.all(color: AppColors.borderSoft),
        color: AppColors.surface,
      ),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          for (final s in group.standings)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              child: Row(
                children: [
                  SizedBox(
                    width: 18,
                    child: Text('${s.position}',
                        style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                  ),
                  Expanded(
                    child: Text(
                      s.team.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: s.team.id == teamId ? FontWeight.w900 : FontWeight.w600,
                        color: s.team.id == teamId ? AppColors.gold : AppColors.fg,
                      ),
                    ),
                  ),
                  _stat('${s.played}'),
                  _stat(s.goalDiff >= 0 ? '+${s.goalDiff}' : '${s.goalDiff}'),
                  _stat('${s.points}', bold: true),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _stat(String v, {bool bold = false}) => SizedBox(
        width: 34,
        child: Text(
          v,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
            color: bold ? AppColors.fg : AppColors.fgSoft,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      );
}

/// "Latest news" about the team — a few tappable story rows. Hides itself
/// (label included) when there are no stories.
class _TeamStories extends ConsumerWidget {
  const _TeamStories({required this.teamId});
  final String teamId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items =
        ref.watch(teamNewsProvider(teamId)).valueOrNull ?? const <NewsArticleDto>[];
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel('Latest news'),
        const SizedBox(height: 8),
        for (final a in items.take(5)) _NewsRow(article: a),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _NewsRow extends StatelessWidget {
  const _NewsRow({required this.article});
  final NewsArticleDto article;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push('/news/${article.id}'),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 64,
              height: 48,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: NewsThumb(imageUrl: article.imageUrl, source: article.source, dense: true),
              ),
            ),
            const SizedBox(width: 12),
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
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.fg,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    article.source,
                    style: const TextStyle(color: AppColors.muted, fontSize: 11),
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

class _TeamFixtures extends ConsumerWidget {
  const _TeamFixtures({required this.teamId});
  final String teamId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(homeFixturesProvider);
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator(color: AppColors.gold)),
      ),
      error: (_, __) => const Text('Fixtures unavailable.',
          style: TextStyle(color: AppColors.muted, fontSize: 13)),
      data: (f) {
        bool involves(MatchDto m) => m.homeTeam.id == teamId || m.awayTeam.id == teamId;
        final list = [
          ...f.upcoming.where(involves),
          ...f.recent.where(involves),
        ];
        if (list.isEmpty) {
          return const Text('No fixtures in the current window.',
              style: TextStyle(color: AppColors.muted, fontSize: 13));
        }
        return Column(
          children: [
            for (var i = 0; i < list.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: MatchCard(match: list[i], indexInList: i),
              ),
          ],
        );
      },
    );
  }
}
