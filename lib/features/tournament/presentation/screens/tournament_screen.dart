import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/responsive/breakpoints.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../competitions/data/competition_models.dart';
import '../../../competitions/data/competitions_repository.dart';
import '../../../insights/data/insights_repository.dart';
import '../../../insights/presentation/widgets/group_standings.dart';
import '../../../insights/presentation/widgets/top_player_list.dart';

/// Competition screen — title, tabs and bracket visibility are all driven by
/// the server-supplied `CompetitionDto.shows{Bracket,Groups,Standings}` flags.
/// Works for a knockout tournament (WC 2026 → bracket + groups + top scorers)
/// AND for a league season (PL → standings + top scorers + assists, no bracket)
/// with zero code changes when new competitions are seeded.
class TournamentScreen extends ConsumerWidget {
  const TournamentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(competitionsProvider);

    return async.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const SizedBox.shrink()),
        body: const SkeletonList(itemHeight: 80),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: ErrorView(message: '$e', onRetry: () => ref.invalidate(competitionsProvider)),
      ),
      data: (list) {
        if (list.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Competitions')),
            body: const Center(child: Text('No active competitions')),
          );
        }
        return _CompetitionView(competition: list.first, allCompetitions: list);
      },
    );
  }
}

class _CompetitionView extends ConsumerStatefulWidget {
  const _CompetitionView({required this.competition, required this.allCompetitions});
  final CompetitionDto competition;
  final List<CompetitionDto> allCompetitions;
  @override
  ConsumerState<_CompetitionView> createState() => _CompetitionViewState();
}

class _CompetitionViewState extends ConsumerState<_CompetitionView> {
  late CompetitionDto _current = widget.competition;

  @override
  Widget build(BuildContext context) {
    final c = _current;
    final tabs = <_TabDef>[];
    // Leagues get a single standings table; tournaments get groups (visually distinct).
    if (c.isLeague    && c.showsStandings) tabs.add(const _TabDef('Standings', GroupStandings()));
    if (c.isTournament && c.showsGroups)   tabs.add(const _TabDef('Groups',    GroupStandings()));
    tabs.add(const _TabDef('Top scorers', _TopScorersTab()));
    tabs.add(const _TabDef('Top assists', _TopAssistsTab()));
    if (c.showsBracket) tabs.add(const _TabDef('Bracket', _BracketLink()));

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: GestureDetector(
            onTap: widget.allCompetitions.length > 1 ? _showCompetitionPicker : null,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(child: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
                if (widget.allCompetitions.length > 1) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_drop_down),
                ],
              ],
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'Injuries',
              icon: const Icon(Icons.medical_services_outlined),
              onPressed: () => context.push(RoutePaths.injuries),
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [for (final t in tabs) Tab(text: t.label)],
          ),
        ),
        body: CenteredContent(
          child: TabBarView(children: [for (final t in tabs) t.child]),
        ),
      ),
    );
  }

  void _showCompetitionPicker() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        top: false,
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final c in widget.allCompetitions)
              ListTile(
                title: Text(c.name),
                subtitle: Text('${c.season} · ${c.teamCount} teams'),
                trailing: c.id == _current.id ? const Icon(Icons.check) : null,
                onTap: () {
                  setState(() => _current = c);
                  Navigator.of(context).pop();
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _TabDef {
  const _TabDef(this.label, this.child);
  final String label;
  final Widget child;
}

class _TopScorersTab extends StatelessWidget {
  const _TopScorersTab();
  @override
  Widget build(BuildContext context) => TopPlayerList(
        provider: topScorersProvider, unit: 'goals',
        emptyMessage: 'Updates after the first match of the season.',
      );
}

class _TopAssistsTab extends StatelessWidget {
  const _TopAssistsTab();
  @override
  Widget build(BuildContext context) => TopPlayerList(
        provider: topAssistsProvider, unit: 'assists',
        emptyMessage: 'Updates after the first match of the season.',
      );
}

class _BracketLink extends StatelessWidget {
  const _BracketLink();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.account_tree_outlined, size: 64, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text('My bracket', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
              'Pick winners for every knockout match. Locks at first kickoff of the round.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Open bracket'),
              onPressed: () => context.push(RoutePaths.bracket),
            ),
          ],
        ),
      ),
    ).animate().fade(duration: 320.ms);
  }
}
