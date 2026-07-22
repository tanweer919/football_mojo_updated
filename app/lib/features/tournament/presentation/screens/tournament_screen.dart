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
    final async = ref.watch(allCompetitionsProvider);

    return async.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const SizedBox.shrink()),
        body: const SkeletonList(itemHeight: 80),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: ErrorView(message: '$e', onRetry: () => ref.invalidate(allCompetitionsProvider)),
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

  /// Distinct leagues — the top-ranked (live/upcoming/most-recent) season of
  /// each — for the competition picker.
  List<CompetitionDto> get _leagues {
    final seen = <String>{};
    return [for (final c in widget.allCompetitions) if (seen.add(c.name)) c];
  }

  /// Seasons available for the currently-selected league, newest first.
  List<CompetitionDto> get _seasons {
    final list = widget.allCompetitions.where((c) => c.name == _current.name).toList();
    list.sort((a, b) => b.season.compareTo(a.season));
    return list;
  }

  static String _seasonLabel(CompetitionDto c) {
    final y = int.tryParse(c.season);
    if (y == null) return c.season;
    // Leagues span two calendar years (2025 → "2025/26"); one-off tournaments don't.
    return c.isLeague ? '$y/${((y + 1) % 100).toString().padLeft(2, '0')}' : '$y';
  }

  @override
  Widget build(BuildContext context) {
    final c = _current;
    final tabs = <_TabDef>[];
    // Leagues get a single standings table; tournaments get groups. Every tab is
    // keyed to the selected competition id so switching league/year switches data.
    if (c.isLeague     && c.showsStandings) tabs.add(_TabDef('Standings', GroupStandings(competitionId: c.id)));
    if (c.isTournament && c.showsGroups)    tabs.add(_TabDef('Groups',    GroupStandings(competitionId: c.id)));
    tabs.add(_TabDef('Top scorers', TopPlayerList(
      provider: topScorersProvider(c.id), unit: 'goals',
      emptyMessage: 'Updates after the first match of the season.')));
    tabs.add(_TabDef('Top assists', TopPlayerList(
      provider: topAssistsProvider(c.id), unit: 'assists',
      emptyMessage: 'Updates after the first match of the season.')));
    if (c.showsBracket) tabs.add(const _TabDef('Bracket', _BracketLink()));

    final seasons = _seasons;

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: GestureDetector(
            onTap: _leagues.length > 1 ? _showLeaguePicker : null,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(child: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
                if (_leagues.length > 1) const Icon(Icons.arrow_drop_down),
              ],
            ),
          ),
          actions: [
            // Year (season) selector — shown when the league has more than one season.
            if (seasons.length > 1)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: ActionChip(
                  avatar: const Icon(Icons.calendar_today_outlined, size: 15),
                  label: Text(_seasonLabel(c)),
                  onPressed: _showSeasonPicker,
                ),
              ),
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

  void _showLeaguePicker() => _picker(
        title: 'Competition',
        items: _leagues,
        // Switching league jumps to that league's newest available season.
        onPick: (c) => setState(() => _current = c),
        labelFor: (c) => c.name,
        subtitleFor: (c) => '${_seasonLabel(c)} · ${c.teamCount} teams',
        selected: (c) => c.name == _current.name,
      );

  void _showSeasonPicker() => _picker(
        title: '${_current.name} · season',
        items: _seasons,
        onPick: (c) => setState(() => _current = c),
        labelFor: _seasonLabel,
        subtitleFor: (c) => c.isLive ? 'In progress' : c.isUpcoming ? 'Upcoming' : 'Final',
        selected: (c) => c.id == _current.id,
      );

  void _picker({
    required String title,
    required List<CompetitionDto> items,
    required void Function(CompetitionDto) onPick,
    required String Function(CompetitionDto) labelFor,
    required String Function(CompetitionDto) subtitleFor,
    required bool Function(CompetitionDto) selected,
  }) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        top: false,
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text(title, style: Theme.of(context).textTheme.labelLarge),
            ),
            for (final item in items)
              ListTile(
                title: Text(labelFor(item)),
                subtitle: Text(subtitleFor(item)),
                trailing: selected(item) ? const Icon(Icons.check) : null,
                onTap: () {
                  onPick(item);
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
