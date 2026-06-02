import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/deeplink/chottu_link_service.dart';
import '../../../../core/responsive/breakpoints.dart';
import '../../../../core/widgets/empty_states.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_skeletons.dart';
import '../../../competitions/data/competitions_repository.dart';
import '../../../competitions/presentation/widgets/competition_chip_selector.dart';
import '../../../scores/data/repositories/scores_repository.dart';
import '../../../scores/data/models/match_dto.dart';
import '../../../scores/presentation/widgets/match_card.dart';

/// Fixtures by day. Horizontal day-strip header + list/grid of matches.
class MatchesScreen extends ConsumerStatefulWidget {
  const MatchesScreen({super.key});
  @override
  ConsumerState<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends ConsumerState<MatchesScreen> {
  DateTime _day = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(scoresRepositoryProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Matches'),
        actions: [
          IconButton(
            tooltip: 'Share',
            icon: const Icon(Icons.ios_share_rounded),
            onPressed: () => ChottuLinkService.instance.shareApp(),
          ),
        ],
      ),
      // SafeArea(bottom: true) keeps the day-strip + match list off the
      // system gesture pill on edge-to-edge devices. Top is handled by
      // the AppBar.
      body: SafeArea(
        top: false,
        child: CenteredContent(
        child: Column(
          children: [
            const CompetitionChipSelector(),
            _DayStrip(
              selected: _day,
              onChanged: (d) => setState(() => _day = d),
            ),
            const Divider(height: 1),
            Expanded(
              child: Consumer(builder: (context, ref, _) {
                final selectedCompetition = ref.watch(selectedCompetitionProvider);
                return FutureBuilder<List<MatchDto>>(
                  key: ValueKey('${_day.toIso8601String().substring(0, 10)}:${selectedCompetition ?? 'all'}'),
                  future: repo.fetchFixtures(day: _day),
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 130),
                        itemCount: 5,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, __) => const MatchCardSkeleton(),
                      );
                    }
                    if (snap.hasError) {
                      return ErrorView(message: '${snap.error}', onRetry: () => setState(() {}));
                    }
                    final all = snap.data ?? const <MatchDto>[];
                    final matches = selectedCompetition == null
                        ? all
                        : all.where((m) => m.competitionId == selectedCompetition).toList();
                    if (matches.isEmpty) {
                      return const SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(20, 12, 20, 130),
                        physics: AlwaysScrollableScrollPhysics(),
                        child: PitchEmptyState(
                          eyebrow: 'No fixtures',
                          title: 'No matches on this day',
                          subtitle: 'Pick a different date from the strip above. WC, UCL and Big-Five fixtures land here as soon as they’re scheduled.',
                          glyph: EmptyGlyph.football,
                        ),
                      );
                    }
                    final cols = context.columnsFor(mobile: 1, tablet: 2, desktop: 3);
                    // Bottom padding clears the floating tabbar (~110px) so
                    // the last card isn't covered.
                    const bottomGap = 130.0;
                    return cols == 1
                        ? ListView.separated(
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, bottomGap),
                            itemCount: matches.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (_, i) => MatchCard(match: matches[i], indexInList: i),
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, bottomGap),
                            itemCount: matches.length,
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: cols,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              mainAxisExtent: 132,
                            ),
                            itemBuilder: (_, i) => MatchCard(match: matches[i], indexInList: i),
                          );
                  },
                );
              }),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _DayStrip extends StatelessWidget {
  const _DayStrip({required this.selected, required this.onChanged});
  final DateTime selected;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final start = today.subtract(const Duration(days: 3));
    final theme = Theme.of(context);
    return SizedBox(
      height: 72,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        scrollDirection: Axis.horizontal,
        itemCount: 14,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final d = start.add(Duration(days: i));
          final isSelected = _sameDay(d, selected);
          return AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: isSelected ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => onChanged(d),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        DateFormat.E().format(d),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('d MMM').format(d),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
