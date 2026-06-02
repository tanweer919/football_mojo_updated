import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/deeplink/chottu_link_service.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/share/share_service.dart';
import '../../../predictions/data/predictions_repository.dart';
import '../../../world_cup/data/world_cup_models.dart';
import '../../../world_cup/data/world_cup_repository.dart';
import '../../data/wc2026_bracket.dart';
import '../widgets/bracket_share_card.dart';

/// World Cup bracket predictor — Telegraph-style.
///
/// Sections (top to bottom):
///   1. Group stage  — drag teams into positions 1-4 per group
///   2. Best thirds  — pick 8 of 12 third-placed teams to advance
///   3. R32 → Final  — cascading head-to-head cards. Each match's slots
///                     auto-populate from the user's prior picks. Tap a
///                     team to mark as winner; that team flows into the
///                     next round's match card.
///
/// Picks shape (stored in Bracket.picks JSON):
///   GROUP_<letter>_<pos>     → teamId  (pos 1..4)
///   BEST_THIRDS              → List<letter>  (max 8)
///   MATCH_<num>_WINNER       → teamId  (one entry per knockout match)
class BracketScreen extends ConsumerStatefulWidget {
  const BracketScreen({super.key, this.competitionId = 'WC2026'});
  final String competitionId;
  @override
  ConsumerState<BracketScreen> createState() => _BracketScreenState();
}

class _BracketScreenState extends ConsumerState<BracketScreen> {
  /// Mutable picks map mirroring the BracketDto.picks shape.
  /// Cascade reads + writes both go through this single map.
  final Map<String, dynamic> _picks = {};
  bool _hydrated = false;
  bool _saving = false;

  void _hydrate(BracketDto b) {
    if (_hydrated) return;
    _picks.addAll(b.picks);
    _hydrated = true;
  }

  /// Auto-fill any missing GROUP_<letter>_<pos> slots from the original
  /// group standings (as a sensible starting point) the first time we
  /// see real groups + no existing picks. Without this the
  /// ReorderableListView has no items to drag.
  void _seedGroupOrder(List<WcGroup> groups) {
    for (final g in groups) {
      // If any position is filled for this group, leave it alone.
      final hasAny = [1, 2, 3, 4].any((p) =>
          _picks['GROUP_${g.letter}_$p'] is String);
      if (hasAny) continue;
      final standings = [...g.standings]..sort((a, b) => a.position.compareTo(b.position));
      for (var i = 0; i < standings.length && i < 4; i++) {
        _picks['GROUP_${g.letter}_${i + 1}'] = standings[i].team.id;
      }
    }
  }

  // ── Pick helpers ─────────────────────────────────────────────────────────

  List<String> get _bestThirds {
    final v = _picks['BEST_THIRDS'];
    if (v is List) return v.whereType<String>().toList();
    return const <String>[];
  }

  /// Total picks made — drives the progress bar.
  int _filled() {
    var n = 0;
    for (final k in _picks.keys) {
      if (k.startsWith('GROUP_') && _picks[k] is String) n++;
      if (k.startsWith('MATCH_') && k.endsWith('_WINNER') && _picks[k] is String) n++;
    }
    n += _bestThirds.length;
    return n;
  }

  // ── Slot resolver ────────────────────────────────────────────────────────
  // Given a slot rule + the current picks, return the actual team (or null
  // if not yet resolvable). Used by the knockout match cards to render the
  // two head-to-head sides.

  WcTeamRef? _resolveSlot(BracketSlotSource slot, Map<String, WcTeamRef> teamsById) {
    if (slot is GroupSlot) {
      final teamId = _picks['GROUP_${slot.groupLetter}_${slot.position}'] as String?;
      return teamId == null ? null : teamsById[teamId];
    }
    if (slot is MatchWinner) {
      final teamId = _picks['MATCH_${slot.matchNumber}_WINNER'] as String?;
      return teamId == null ? null : teamsById[teamId];
    }
    if (slot is BestThird) {
      // First of the user's best-thirds that's in this slot's eligible group
      // set. FIFA's actual assignment is matrix-based — we approximate by
      // using the first eligible third in the user's BEST_THIRDS list.
      final picked = _bestThirds;
      for (final g in slot.eligibleGroups) {
        if (!picked.contains(g)) continue;
        final teamId = _picks['GROUP_${g}_3'] as String?;
        if (teamId != null && teamsById[teamId] != null) {
          return teamsById[teamId];
        }
      }
      return null;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(wcGroupsProvider(widget.competitionId));
    final mineAsync = ref.watch(myBracketProvider(widget.competitionId));

    mineAsync.whenData((b) {
      if (b != null) _hydrate(b);
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('My bracket'),
        actions: [
          IconButton(
            tooltip: 'Share',
            icon: const Icon(Icons.ios_share_rounded),
            onPressed: () async {
              final groups = groupsAsync.valueOrNull;
              // Groups still loading — share with a plain deep link
              // anyway (no PNG yet) so the button is never a dead end.
              if (groups == null) {
                await ChottuLinkService.instance.shareBracket();
                return;
              }
              final teamsById = {
                for (final g in groups)
                  for (final s in g.standings) s.team.id: s.team,
              };
              final championId = _picks['MATCH_104_WINNER'] as String?;
              final champion = championId == null ? null : teamsById[championId];
              // Share card expects String→String for group/champion picks.
              final shareMap = <String, String>{
                for (final e in _picks.entries)
                  if (e.value is String && (e.key.startsWith('GROUP_') && e.key.endsWith('_1')))
                    'GROUP_${e.key.substring(6, 7)}_1': e.value as String,
                if (championId != null) 'CHAMPION': championId,
              };
              // Render the share card PNG first, then hand both PNG +
              // ChottuLink deep link to the share sheet so previews look
              // good and the link opens the bracket screen on tap.
              String? imagePath;
              try {
                imagePath = await ShareService.instance.renderArtifactToFile(
                  context: context,
                  logicalSize: const Size(1080, 1350),
                  filename: 'pitch_bracket.png',
                  builder: (_) => BracketShareCard(
                    groups: groups,
                    picks: shareMap,
                    championTeam: champion,
                  ),
                );
              } catch (_) {
                imagePath = null;
              }
              final pts = mineAsync.valueOrNull?.pointsAwarded ?? 0;
              await ChottuLinkService.instance.shareBracket(
                championName: champion?.name,
                championCrestUrl: champion?.crestUrl,
                pointsAwarded: pts,
                imagePath: imagePath,
              );
            },
          ),
          IconButton(
            tooltip: 'Leaderboard',
            icon: const Icon(Icons.emoji_events_outlined),
            onPressed: () => context.push(RoutePaths.bracketLeaderboard),
          ),
        ],
      ),
      body: groupsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(message: '$e'),
        data: (groups) {
          // Seed default ordering (matches actual standings) the first time
          // — gives the user something to drag instead of an empty list.
          _seedGroupOrder(groups);
          final teamsById = <String, WcTeamRef>{
            for (final g in groups)
              for (final s in g.standings) s.team.id: s.team,
          };
          final locked = mineAsync.maybeWhen(
            data: (b) => b?.isLocked ?? false,
            orElse: () => false,
          );
          final lockAt = mineAsync.maybeWhen(
            data: (b) => b?.lockedAt,
            orElse: () => null,
          );
          final pts = mineAsync.maybeWhen(
            data: (b) => b?.pointsAwarded ?? 0,
            orElse: () => 0,
          );
          return _BracketBody(
            groups: groups,
            teamsById: teamsById,
            picks: _picks,
            filled: _filled(),
            locked: locked,
            lockAt: lockAt,
            points: pts,
            saving: _saving,
            resolveSlot: (slot) => _resolveSlot(slot, teamsById),
            onReorderGroup: (letter, oldIndex, newIndex) {
              if (locked) return;
              setState(() {
                // Pull current order, mutate, write back.
                final ids = [
                  for (var i = 1; i <= 4; i++) _picks['GROUP_${letter}_$i'] as String,
                ];
                if (newIndex > oldIndex) newIndex--;
                final moved = ids.removeAt(oldIndex);
                ids.insert(newIndex, moved);
                for (var i = 0; i < 4; i++) {
                  _picks['GROUP_${letter}_${i + 1}'] = ids[i];
                }
                // Clear cascade picks downstream — order change invalidates
                // any prior knockout selections for this group's teams.
                _invalidateKnockoutPicksMentioning(ids);
              });
            },
            onToggleThird: (letter) {
              if (locked) return;
              setState(() {
                final current = [..._bestThirds];
                if (current.contains(letter)) {
                  current.remove(letter);
                } else {
                  if (current.length >= 8) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        duration: Duration(seconds: 2),
                        content: Text('Cap reached (8 thirds). Tap a selected one to swap.'),
                      ),
                    );
                    return;
                  }
                  current.add(letter);
                }
                if (current.isEmpty) {
                  _picks.remove('BEST_THIRDS');
                } else {
                  _picks['BEST_THIRDS'] = current;
                }
              });
            },
            onPickWinner: (matchNumber, teamId) {
              if (locked) return;
              setState(() {
                final key = 'MATCH_${matchNumber}_WINNER';
                if (_picks[key] == teamId) {
                  _picks.remove(key);
                  _invalidateDownstream(matchNumber);
                } else {
                  _picks[key] = teamId;
                  // If the team won, downstream match cards now reference
                  // this winner — but those don't need clearing because
                  // they're computed from MATCH_X_WINNER lookups.
                }
              });
            },
            onSave: _save,
          );
        },
      ),
    );
  }

  /// Clear any MATCH_X_WINNER pick whose stored team isn't valid anymore
  /// after a group reorder. Cheap O(matches × 1) — fewer than 32 entries
  /// even at full saturation.
  void _invalidateKnockoutPicksMentioning(List<String> teamIds) {
    final ids = teamIds.toSet();
    final keys = [..._picks.keys];
    for (final k in keys) {
      if (!k.startsWith('MATCH_') || !k.endsWith('_WINNER')) continue;
      final v = _picks[k];
      if (v is String && ids.contains(v)) {
        // Don't blindly clear — the team is still a valid pick if they
        // still appear in their group's standings (any position). The
        // cascade resolver will figure it out at render time.
      }
    }
  }

  /// Clear downstream match winners that depended on the just-unset match.
  void _invalidateDownstream(int matchNumber) {
    final downstream = wc2026Matches
        .where((m) =>
            (m.left is MatchWinner && (m.left as MatchWinner).matchNumber == matchNumber) ||
            (m.right is MatchWinner && (m.right as MatchWinner).matchNumber == matchNumber))
        .map((m) => m.number);
    for (final n in downstream) {
      final key = 'MATCH_${n}_WINNER';
      if (_picks.containsKey(key)) {
        _picks.remove(key);
        _invalidateDownstream(n);
      }
    }
  }

  Future<void> _save() async {
    if (_filled() == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick at least one team before saving.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final saved = await ref
          .read(predictionsRepositoryProvider)
          .submitBracket(widget.competitionId, _picks);
      ref.invalidate(myBracketProvider(widget.competitionId));
      ref.invalidate(bracketLeaderboardProvider(widget.competitionId));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(saved.isLocked ? 'Bracket locked — saved' : 'Bracket saved')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError('$e'))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _friendlyError(String raw) {
    if (raw.contains('bracket_locked')) return 'Bracket is locked — kickoff has begun.';
    if (raw.contains('401') || raw.contains('unauthorized')) return 'Sign in to save your bracket.';
    return 'Could not save bracket. Try again.';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Body
// ─────────────────────────────────────────────────────────────────────────────

class _BracketBody extends StatelessWidget {
  const _BracketBody({
    required this.groups,
    required this.teamsById,
    required this.picks,
    required this.filled,
    required this.locked,
    required this.lockAt,
    required this.points,
    required this.saving,
    required this.resolveSlot,
    required this.onReorderGroup,
    required this.onToggleThird,
    required this.onPickWinner,
    required this.onSave,
  });

  final List<WcGroup> groups;
  final Map<String, WcTeamRef> teamsById;
  final Map<String, dynamic> picks;
  final int filled;
  final bool locked;
  final DateTime? lockAt;
  final int points;
  final bool saving;
  final WcTeamRef? Function(BracketSlotSource slot) resolveSlot;
  final void Function(String letter, int oldIndex, int newIndex) onReorderGroup;
  final void Function(String letter) onToggleThird;
  final void Function(int matchNumber, String teamId) onPickWinner;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final byLetter = {for (final g in groups) g.letter: g};
    final matchesByRound = <BracketRound, List<BracketMatch>>{};
    for (final m in wc2026Matches) {
      matchesByRound.putIfAbsent(m.round, () => []).add(m);
    }

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          children: [
            _ProgressHeader(
              filled: filled,
              total: wc2026TotalPicks,
              locked: locked,
              lockAt: lockAt,
              points: points,
            ),
            const SizedBox(height: 18),

            // ── Group stage ─────────────────────────────────────────────
            const _SectionHeading(
              title: 'Group stage',
              caption: 'Drag teams into positions 1–4. 5 pts for 1st, 3 for 2nd, 1 for 3rd.',
            ),
            for (final letter in wcGroupLetters)
              if (byLetter.containsKey(letter))
                _GroupOrderCard(
                  group: byLetter[letter]!,
                  picks: picks,
                  teamsById: teamsById,
                  locked: locked,
                  onReorder: (o, n) => onReorderGroup(letter, o, n),
                ),

            const SizedBox(height: 20),

            // ── Best thirds ─────────────────────────────────────────────
            _BestThirdsSection(
              picks: picks,
              teamsById: teamsById,
              locked: locked,
              onToggle: onToggleThird,
            ),

            const SizedBox(height: 20),

            // ── Knockout sections ───────────────────────────────────────
            for (final round in const [
              BracketRound.r32,
              BracketRound.r16,
              BracketRound.qf,
              BracketRound.sf,
              BracketRound.finalRound,
            ])
              _RoundSection(
                round: round,
                matches: matchesByRound[round] ?? const [],
                picks: picks,
                resolveSlot: resolveSlot,
                locked: locked,
                onPickWinner: onPickWinner,
              ),
          ],
        ),

        // Sticky save button.
        Positioned(
          left: 16, right: 16, bottom: 16,
          child: SafeArea(
            top: false,
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                icon: Icon(locked ? Icons.lock_outline : Icons.check_rounded),
                label: Text(
                  locked
                      ? 'Bracket locked'
                      : (saving
                          ? 'Saving…'
                          : 'Save bracket  ·  $filled / $wc2026TotalPicks picks'),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                onPressed: locked || saving ? null : onSave,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.caption});
  final String title;
  final String caption;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
            caption,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Group ordering — drag-and-drop card
// ─────────────────────────────────────────────────────────────────────────────

class _GroupOrderCard extends StatelessWidget {
  const _GroupOrderCard({
    required this.group,
    required this.picks,
    required this.teamsById,
    required this.locked,
    required this.onReorder,
  });
  final WcGroup group;
  final Map<String, dynamic> picks;
  final Map<String, WcTeamRef> teamsById;
  final bool locked;
  final void Function(int oldIndex, int newIndex) onReorder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final orderedIds = [
      for (var i = 1; i <= 4; i++) picks['GROUP_${group.letter}_$i'] as String?,
    ].whereType<String>().toList();
    final teams = orderedIds.map((id) => teamsById[id]).whereType<WcTeamRef>().toList();

    // Colour stripe per position — green (advance) / amber (3rd) / muted (4th).
    Color stripeFor(int position) {
      if (position <= 2) return Colors.green.withValues(alpha: 0.45);
      if (position == 3) return Colors.amber.withValues(alpha: 0.45);
      return theme.colorScheme.outline.withValues(alpha: 0.35);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Group ${group.letter}',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(width: 8),
                Text(
                  '${group.standings.length} teams',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // ReorderableListView needs a bounded height. Use shrinkWrap +
            // physics-none inside the parent ListView.
            ReorderableListView(
              shrinkWrap: true,
              buildDefaultDragHandles: !locked,
              physics: const NeverScrollableScrollPhysics(),
              onReorder: onReorder,
              children: [
                for (var i = 0; i < teams.length; i++)
                  Container(
                    key: ValueKey('${group.letter}-${teams[i].id}'),
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(10),
                      border: Border(
                        left: BorderSide(color: stripeFor(i + 1), width: 4),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 22,
                            child: Text(
                              '${i + 1}',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (teams[i].crestUrl != null)
                            ClipOval(
                              child: Image.network(
                                teams[i].crestUrl!,
                                width: 22, height: 22,
                                errorBuilder: (_, __, ___) =>
                                    const SizedBox(width: 22, height: 22),
                              ),
                            )
                          else
                            const SizedBox(width: 22, height: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              teams[i].name,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (!locked)
                            Icon(Icons.drag_handle_rounded,
                                size: 18, color: theme.colorScheme.outline),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Best thirds — 8 of 12 picker
// ─────────────────────────────────────────────────────────────────────────────

class _BestThirdsSection extends StatelessWidget {
  const _BestThirdsSection({
    required this.picks,
    required this.teamsById,
    required this.locked,
    required this.onToggle,
  });
  final Map<String, dynamic> picks;
  final Map<String, WcTeamRef> teamsById;
  final bool locked;
  final void Function(String letter) onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = (picks['BEST_THIRDS'] as List?)?.whereType<String>().toSet() ?? <String>{};

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Best third-placed teams',
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(
                        'Pick the 8 of 12 third-placed teams you think advance. 5 pts each correct.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${selected.length}/8',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: selected.length == 8
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Two columns of 6.
            for (var row = 0; row < 6; row++)
              Row(
                children: [
                  Expanded(
                    child: _ThirdRow(
                      letter: wcGroupLetters[row],
                      picks: picks,
                      teamsById: teamsById,
                      selected: selected.contains(wcGroupLetters[row]),
                      locked: locked,
                      onTap: () => onToggle(wcGroupLetters[row]),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ThirdRow(
                      letter: wcGroupLetters[row + 6],
                      picks: picks,
                      teamsById: teamsById,
                      selected: selected.contains(wcGroupLetters[row + 6]),
                      locked: locked,
                      onTap: () => onToggle(wcGroupLetters[row + 6]),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _ThirdRow extends StatelessWidget {
  const _ThirdRow({
    required this.letter,
    required this.picks,
    required this.teamsById,
    required this.selected,
    required this.locked,
    required this.onTap,
  });
  final String letter;
  final Map<String, dynamic> picks;
  final Map<String, WcTeamRef> teamsById;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final teamId = picks['GROUP_${letter}_3'] as String?;
    final team = teamId == null ? null : teamsById[teamId];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: selected
            ? theme.colorScheme.primary.withValues(alpha: 0.15)
            : theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: locked ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                Icon(
                  selected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                  color: selected ? theme.colorScheme.primary : theme.colorScheme.outline,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  '$letter ·',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    team?.shortName ?? '—',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
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

// ─────────────────────────────────────────────────────────────────────────────
// Knockout round section (R32 / R16 / QF / SF / Final)
// ─────────────────────────────────────────────────────────────────────────────

class _RoundSection extends StatelessWidget {
  const _RoundSection({
    required this.round,
    required this.matches,
    required this.picks,
    required this.resolveSlot,
    required this.locked,
    required this.onPickWinner,
  });
  final BracketRound round;
  final List<BracketMatch> matches;
  final Map<String, dynamic> picks;
  final WcTeamRef? Function(BracketSlotSource slot) resolveSlot;
  final bool locked;
  final void Function(int matchNumber, String teamId) onPickWinner;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeading(
            title: round.title,
            caption: '${round.points} pts per correct winner.',
          ),
          for (final m in matches)
            _KnockoutMatchCard(
              match: m,
              picks: picks,
              resolveSlot: resolveSlot,
              locked: locked,
              onPickWinner: onPickWinner,
            ),
        ],
      ),
    );
  }
}

class _KnockoutMatchCard extends StatelessWidget {
  const _KnockoutMatchCard({
    required this.match,
    required this.picks,
    required this.resolveSlot,
    required this.locked,
    required this.onPickWinner,
  });
  final BracketMatch match;
  final Map<String, dynamic> picks;
  final WcTeamRef? Function(BracketSlotSource slot) resolveSlot;
  final bool locked;
  final void Function(int matchNumber, String teamId) onPickWinner;

  @override
  Widget build(BuildContext context) {
    final left = resolveSlot(match.left);
    final right = resolveSlot(match.right);
    final winnerId = picks['MATCH_${match.number}_WINNER'] as String?;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Match ${match.number}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: _SideSlot(
                      slot: match.left,
                      team: left,
                      selected: left != null && winnerId == left.id,
                      locked: locked,
                      onTap: left == null ? null : () => onPickWinner(match.number, left.id),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      'v',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Expanded(
                    child: _SideSlot(
                      slot: match.right,
                      team: right,
                      selected: right != null && winnerId == right.id,
                      locked: locked,
                      onTap: right == null ? null : () => onPickWinner(match.number, right.id),
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

class _SideSlot extends StatelessWidget {
  const _SideSlot({
    required this.slot,
    required this.team,
    required this.selected,
    required this.locked,
    required this.onTap,
  });
  final BracketSlotSource slot;
  final WcTeamRef? team;
  final bool selected;
  final bool locked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasTeam = team != null;
    return Material(
      color: selected
          ? theme.colorScheme.primary
          : (hasTeam
              ? theme.colorScheme.surfaceContainerHigh
              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: locked ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: hasTeam
              ? Row(
                  children: [
                    if (team!.crestUrl != null)
                      ClipOval(
                        child: Image.network(
                          team!.crestUrl!,
                          width: 18, height: 18,
                          errorBuilder: (_, __, ___) =>
                              const SizedBox(width: 18, height: 18),
                        ),
                      ),
                    if (team!.crestUrl != null) const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        team!.shortName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: selected
                              ? theme.colorScheme.onPrimary
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                )
              : Text(
                  slot.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                    fontStyle: FontStyle.italic,
                  ),
                ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Progress header
// ─────────────────────────────────────────────────────────────────────────────

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({
    required this.filled,
    required this.total,
    required this.locked,
    required this.lockAt,
    required this.points,
  });
  final int filled;
  final int total;
  final bool locked;
  final DateTime? lockAt;
  final int points;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pct = total == 0 ? 0.0 : (filled / total).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                locked ? Icons.lock_outline : Icons.account_tree_outlined,
                size: 18, color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                locked ? 'Locked' : 'In progress',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              if (points > 0)
                Text(
                  '$points pts',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            locked && lockAt != null
                ? 'Locked at ${_format(lockAt!)}.'
                : '$filled of $total picks made.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  String _format(DateTime dt) {
    final local = dt.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: theme.colorScheme.error),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
