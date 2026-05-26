import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_paths.dart';
import '../../../../core/share/share_service.dart';
import '../../../predictions/data/predictions_repository.dart';
import '../../../world_cup/data/world_cup_models.dart';
import '../../../world_cup/data/world_cup_repository.dart';
import '../widgets/bracket_share_card.dart';

/// Bracket predictor for a tournament. WC 2026 default.
///
/// Picks model (matches the backend's flat `Bracket.picks` JSON):
///   GROUP_<letter>_1  → user's pick for 1st place           (3 pts each)
///   GROUP_<letter>_2  → user's pick for 2nd place           (1 pt each)
///   CHAMPION          → user's pick for the eventual winner (50 pts)
class BracketScreen extends ConsumerStatefulWidget {
  const BracketScreen({super.key, this.competitionId = 'WC2026'});
  final String competitionId;
  @override
  ConsumerState<BracketScreen> createState() => _BracketScreenState();
}

class _BracketScreenState extends ConsumerState<BracketScreen> {
  final Map<String, String> _picks = {};
  bool _hydrated = false;
  bool _saving = false;

  void _hydrate(BracketDto bracket) {
    if (_hydrated) return;
    _picks.addAll(bracket.picks);
    _hydrated = true;
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
            tooltip: 'Share bracket',
            icon: const Icon(Icons.ios_share_rounded),
            // Always tappable — the empty-state snackbar is clearer than a
            // silently-disabled icon (which renders at low opacity and is
            // easy to miss).
            onPressed: () async {
              if (_picks.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Make some picks first, then share your bracket.'),
                  ),
                );
                return;
              }
              final groups = groupsAsync.valueOrNull;
              if (groups == null) return;
              WcTeamRef? champion;
              final championId = _picks['CHAMPION'];
              if (championId != null) {
                for (final g in groups) {
                  for (final s in g.standings) {
                    if (s.team.id == championId) {
                      champion = s.team;
                      break;
                    }
                  }
                }
              }
              await ShareService.instance.shareArtifact(
                context: context,
                logicalSize: const Size(1080, 1350),
                text: 'My PITCH bracket for World Cup 2026 ⚽',
                filename: 'pitch_bracket.png',
                builder: (_) => BracketShareCard(
                  groups: groups,
                  picks: _picks,
                  championTeam: champion,
                ),
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
          final locked = mineAsync.maybeWhen(
            data: (b) => b?.isLocked ?? false,
            orElse: () => false,
          );
          final lockAt = mineAsync.maybeWhen(
            data: (b) => b?.lockedAt,
            orElse: () => null,
          );
          final pointsAwarded = mineAsync.maybeWhen(
            data: (b) => b?.pointsAwarded ?? 0,
            orElse: () => 0,
          );
          return _BracketBody(
            groups: groups,
            picks: _picks,
            locked: locked,
            lockAt: lockAt,
            pointsAwarded: pointsAwarded,
            saving: _saving,
            onPick: (key, teamId) {
              if (locked) return;
              setState(() {
                // Toggle off when the same slot is tapped twice.
                if (_picks[key] == teamId) {
                  _picks.remove(key);
                  return;
                }

                // One team = one role inside the group stage. Picking a team
                // for slot X auto-clears it from any OTHER group slot.
                // Champion is allowed to be the same team as a 1st-place
                // pick (you'd typically pick the same team for both).
                if (key.startsWith('GROUP_')) {
                  // Strip the trailing `_1` / `_2` to get the group key, then
                  // sweep both slots of that group + every other group's two
                  // slots, removing this teamId wherever it appears.
                  for (final existing in [..._picks.keys]) {
                    if (!existing.startsWith('GROUP_')) continue;
                    if (existing == key) continue;
                    if (_picks[existing] == teamId) {
                      _picks.remove(existing);
                    }
                  }
                }
                _picks[key] = teamId;
              });
            },
            onSave: _save,
          );
        },
      ),
    );
  }

  Future<void> _save() async {
    if (_picks.isEmpty) {
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
      // Refresh providers so locked/points reflect server state.
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
    if (raw.contains('bracket_locked')) {
      return 'Bracket is locked — kickoff has begun.';
    }
    if (raw.contains('401') || raw.contains('unauthorized')) {
      return 'Sign in to save your bracket.';
    }
    return 'Could not save bracket. Try again.';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Body
// ─────────────────────────────────────────────────────────────────────────────

class _BracketBody extends StatelessWidget {
  const _BracketBody({
    required this.groups,
    required this.picks,
    required this.locked,
    required this.lockAt,
    required this.pointsAwarded,
    required this.saving,
    required this.onPick,
    required this.onSave,
  });

  final List<WcGroup> groups;
  final Map<String, String> picks;
  final bool locked;
  final DateTime? lockAt;
  final int pointsAwarded;
  final bool saving;
  final void Function(String key, String teamId) onPick;
  final VoidCallback onSave;

  int get _filled => picks.length;
  int get _slots => groups.length * 2 + 1; // 2 per group + champion

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allTeams = <WcTeamRef>[
      for (final g in groups) ...g.standings.map((s) => s.team),
    ];
    // Stable, alphabetical team list for the champion picker.
    final sortedTeams = [...allTeams]..sort((a, b) => a.name.compareTo(b.name));

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          children: [
            _ProgressHeader(
              filled: _filled,
              slots: _slots,
              locked: locked,
              lockAt: lockAt,
              points: pointsAwarded,
            ),
            const SizedBox(height: 16),
            Text(
              'Group stage',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Pick the top two finishers in each group. 3 pts per group winner, 1 pt per runner-up.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < groups.length; i++)
              _GroupPicker(
                group: groups[i],
                picks: picks,
                locked: locked,
                onPick: onPick,
              ).animate().fade(duration: 220.ms, delay: (40 * i).ms).slideY(begin: 0.04, end: 0),
            const SizedBox(height: 24),
            Text(
              'Champion',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Who lifts the trophy? Worth 50 pts.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            _ChampionPicker(
              teams: sortedTeams,
              selectedTeamId: picks['CHAMPION'],
              locked: locked,
              onPick: (teamId) => onPick('CHAMPION', teamId),
            ),
          ],
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
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
                      : (saving ? 'Saving…' : 'Save bracket  ·  $_filled / $_slots picks'),
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

// ─────────────────────────────────────────────────────────────────────────────
// Group picker
// ─────────────────────────────────────────────────────────────────────────────

class _GroupPicker extends StatelessWidget {
  const _GroupPicker({
    required this.group,
    required this.picks,
    required this.locked,
    required this.onPick,
  });
  final WcGroup group;
  final Map<String, String> picks;
  final bool locked;
  final void Function(String key, String teamId) onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final winnerKey = 'GROUP_${group.letter}_1';
    final runnerKey = 'GROUP_${group.letter}_2';
    final winnerId = picks[winnerKey];
    final runnerId = picks[runnerKey];

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
                if (winnerId != null && runnerId != null)
                  Icon(Icons.check_circle_rounded,
                      size: 16, color: theme.colorScheme.primary),
              ],
            ),
            const SizedBox(height: 8),
            for (final row in group.standings)
              _TeamRow(
                team: row.team,
                isWinner: winnerId == row.team.id,
                isRunnerUp: runnerId == row.team.id,
                locked: locked,
                onTapWinner: () => onPick(winnerKey, row.team.id),
                onTapRunnerUp: () => onPick(runnerKey, row.team.id),
              ),
          ],
        ),
      ),
    );
  }
}

class _TeamRow extends StatelessWidget {
  const _TeamRow({
    required this.team,
    required this.isWinner,
    required this.isRunnerUp,
    required this.locked,
    required this.onTapWinner,
    required this.onTapRunnerUp,
  });
  final WcTeamRef team;
  final bool isWinner;
  final bool isRunnerUp;
  final bool locked;
  final VoidCallback onTapWinner;
  final VoidCallback onTapRunnerUp;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          if (team.crestUrl != null)
            ClipOval(
              child: Image.network(
                team.crestUrl!,
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
              team.shortName,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight:
                    (isWinner || isRunnerUp) ? FontWeight.w700 : FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          _SlotChip(label: '1st', selected: isWinner, locked: locked, onTap: onTapWinner),
          const SizedBox(width: 6),
          _SlotChip(label: '2nd', selected: isRunnerUp, locked: locked, onTap: onTapRunnerUp),
        ],
      ),
    );
  }
}

class _SlotChip extends StatelessWidget {
  const _SlotChip({
    required this.label,
    required this.selected,
    required this.locked,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = selected ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHigh;
    final fg = selected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: locked && !selected ? bg.withValues(alpha: 0.4) : bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: locked ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: fg,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Champion picker
// ─────────────────────────────────────────────────────────────────────────────

class _ChampionPicker extends StatelessWidget {
  const _ChampionPicker({
    required this.teams,
    required this.selectedTeamId,
    required this.locked,
    required this.onPick,
  });
  final List<WcTeamRef> teams;
  final String? selectedTeamId;
  final bool locked;
  final void Function(String teamId) onPick;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final t in teams)
              _ChampionChip(
                team: t,
                selected: selectedTeamId == t.id,
                locked: locked,
                onTap: () => onPick(t.id),
              ),
          ],
        ),
      ),
    );
  }
}

class _ChampionChip extends StatelessWidget {
  const _ChampionChip({
    required this.team,
    required this.selected,
    required this.locked,
    required this.onTap,
  });
  final WcTeamRef team;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.surfaceContainerHigh;
    final fg = selected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: locked ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (team.crestUrl != null)
                ClipOval(
                  child: Image.network(
                    team.crestUrl!,
                    width: 18, height: 18,
                    errorBuilder: (_, __, ___) =>
                        const SizedBox(width: 18, height: 18),
                  ),
                ),
              if (team.crestUrl != null) const SizedBox(width: 6),
              Text(
                team.shortName,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Progress / status header
// ─────────────────────────────────────────────────────────────────────────────

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({
    required this.filled,
    required this.slots,
    required this.locked,
    required this.lockAt,
    required this.points,
  });
  final int filled;
  final int slots;
  final bool locked;
  final DateTime? lockAt;
  final int points;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pct = slots == 0 ? 0.0 : (filled / slots).clamp(0.0, 1.0);
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
                : '$filled of $slots picks made.',
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
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '${local.year}-$m-$d $hh:$mm';
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
