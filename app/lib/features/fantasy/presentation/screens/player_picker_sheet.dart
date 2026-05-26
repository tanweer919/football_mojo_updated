import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/widgets/eyebrow.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/premium_image.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../data/models/fantasy_models.dart';
import '../providers/fantasy_providers.dart';

/// Player picker — opens as a modal bottom sheet on top of the lineup
/// builder. Restricted to:
///   - the player's allowed positions (GK / DEF / MID / FWD, or any of
///     the three outfield positions for the UTL slot)
///   - the active fantasy tournament (WC-only for WC, club-only for club)
///   - players not already in the squad (`excludePlayerIds`)
Future<String?> showPlayerPicker(
  BuildContext context, {
  required String tournamentSlug,
  required Set<PlayerPosition> allowedPositions,
  required Set<String> excludePlayerIds,
  required double remainingBudget,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.surface,
    constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.92),
    builder: (_) => _PickerSheet(
      slug: tournamentSlug,
      allowedPositions: allowedPositions,
      exclude: excludePlayerIds,
      remainingBudget: remainingBudget,
    ),
  );
}

enum _Sort { price, form, goals, minutes, name }

class _PickerSheet extends ConsumerStatefulWidget {
  const _PickerSheet({
    required this.slug,
    required this.allowedPositions,
    required this.exclude,
    required this.remainingBudget,
  });
  final String slug;
  final Set<PlayerPosition> allowedPositions;
  final Set<String> exclude;
  final double remainingBudget;
  @override
  ConsumerState<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends ConsumerState<_PickerSheet> {
  String _query = '';
  _Sort _sort = _Sort.form;
  bool _onlyAffordable = true;
  bool _inFormOnly = false;       // rating ≥ 7.0
  bool _startersOnly = false;     // appearances ≥ 10
  /// For the UTL slot the user can narrow further to a single position
  /// (DEF / MID / FWD). Null = no extra restriction beyond `allowedPositions`.
  PlayerPosition? _positionFilter;
  /// Set when the user taps a team chip on a row — locks the list to that
  /// team until cleared via the chip in the active-filter region.
  String? _teamFilter;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(selectablePlayersProvider(widget.slug));
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Header(
            allowedPositions: widget.allowedPositions,
            remainingBudget: widget.remainingBudget,
          ),
          const SizedBox(height: 10),
          _SearchBar(onChanged: (v) => setState(() => _query = v.trim().toLowerCase())),
          const SizedBox(height: 10),
          _FilterStrip(
            allowedPositions: widget.allowedPositions,
            positionFilter: _positionFilter,
            onPositionFilter: (p) => setState(() => _positionFilter = p),
            onlyAffordable: _onlyAffordable,
            onAffordableTap: () => setState(() => _onlyAffordable = !_onlyAffordable),
            inFormOnly: _inFormOnly,
            onInFormTap: () => setState(() => _inFormOnly = !_inFormOnly),
            startersOnly: _startersOnly,
            onStartersTap: () => setState(() => _startersOnly = !_startersOnly),
            sort: _sort,
            onSortTap: () => setState(() => _sort = _nextSort(_sort)),
            teamFilter: _teamFilter,
            onClearTeam: () => setState(() => _teamFilter = null),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: async.when(
              loading: () => const SkeletonList(itemHeight: 76),
              error: (e, _) => ErrorView(
                message: '$e',
                onRetry: () => ref.invalidate(selectablePlayersProvider(widget.slug)),
              ),
              data: (all) {
                final filtered = _applyFilters(all)..sort(_sorter);
                if (filtered.isEmpty) {
                  return _Empty(
                    hint: _onlyAffordable
                        ? 'No players match within budget. Toggle "In budget" off to widen the search.'
                        : 'No players match the current filters.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final v = filtered[i];
                    final affordable = v.price <= widget.remainingBudget + 0.001;
                    return _PlayerRow(
                      v: v,
                      affordable: affordable,
                      onTap: affordable ? () => Navigator.of(context).pop(v.playerId) : null,
                      onTeamTap: () => setState(() => _teamFilter = v.player.team.name),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<PlayerValuationDto> _applyFilters(List<PlayerValuationDto> all) {
    return all.where((p) {
      // Position guard — UTL slot allows DEF/MID/FWD; the chip row can
      // narrow further.
      if (!widget.allowedPositions.contains(p.position)) return false;
      if (_positionFilter != null && p.position != _positionFilter) return false;
      // Already in squad.
      if (widget.exclude.contains(p.playerId)) return false;
      // Budget.
      if (_onlyAffordable && p.price > widget.remainingBudget + 0.001) return false;
      // Form — null seasonRating means "unknown form", excluded under
      // "in form" (we can't prove they're hot).
      if (_inFormOnly) {
        if (p.seasonRating == null || p.seasonRating! < 7.0) return false;
      }
      // Starters — ≥ 10 appearances last season as a proxy for "plays".
      if (_startersOnly && p.seasonAppearances < 10) return false;
      // Team-locked search (set by tapping a team chip on a row).
      if (_teamFilter != null && p.player.team.name != _teamFilter) return false;
      // Text search across player + team.
      if (_query.isNotEmpty) {
        final inName = p.player.name.toLowerCase().contains(_query);
        final inTeam = p.player.team.name.toLowerCase().contains(_query);
        if (!inName && !inTeam) return false;
      }
      return true;
    }).toList();
  }

  int _sorter(PlayerValuationDto a, PlayerValuationDto b) {
    switch (_sort) {
      case _Sort.price:
        return b.price.compareTo(a.price);
      case _Sort.form:
        // Null ratings sink to the bottom — unknown form ≠ great form.
        final aR = a.seasonRating ?? a.recentForm;
        final bR = b.seasonRating ?? b.recentForm;
        if (aR == bR) return b.price.compareTo(a.price);
        return bR.compareTo(aR);
      case _Sort.goals:
        // Assists weighted half — captures playmaker output too.
        final ag = a.seasonGoals + a.seasonAssists * 0.5;
        final bg = b.seasonGoals + b.seasonAssists * 0.5;
        if (ag == bg) return b.price.compareTo(a.price);
        return bg.compareTo(ag);
      case _Sort.minutes:
        if (a.seasonMinutes == b.seasonMinutes) return b.price.compareTo(a.price);
        return b.seasonMinutes.compareTo(a.seasonMinutes);
      case _Sort.name:
        return a.player.name.compareTo(b.player.name);
    }
  }

  /// Tap-to-cycle ordering: Form → Price → Goals → Minutes → A-Z → Form.
  _Sort _nextSort(_Sort current) {
    const order = [_Sort.form, _Sort.price, _Sort.goals, _Sort.minutes, _Sort.name];
    final i = order.indexOf(current);
    return order[(i + 1) % order.length];
  }
}

// ─── Header ───────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.allowedPositions, required this.remainingBudget});
  final Set<PlayerPosition> allowedPositions;
  final double remainingBudget;
  @override
  Widget build(BuildContext context) {
    final positionLabel = allowedPositions.length == 1
        ? _positionWord(allowedPositions.first)
        : 'Utility (DEF · MID · FWD)';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Eyebrow('Pick a player', gold: true, size: 10),
                const SizedBox(height: 2),
                Text(
                  positionLabel,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: AppColors.fg,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.16),
              border: Border.all(color: AppColors.goldHairline),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.account_balance_wallet_outlined, color: AppColors.gold, size: 14),
                const SizedBox(width: 6),
                Text(
                  remainingBudget.toStringAsFixed(1),
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.gold,
                    fontFeatures: [FontFeature.tabularFigures()],
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(width: 4),
                const Text(
                  'left',
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontFamilyFallback: ['SF Mono', 'Menlo', 'monospace'],
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: AppColors.goldDeep,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _positionWord(PlayerPosition p) => switch (p) {
        PlayerPosition.GK => 'Goalkeeper',
        PlayerPosition.DEF => 'Defender',
        PlayerPosition.MID => 'Midfielder',
        PlayerPosition.FWD => 'Forward',
      };
}

// ─── Search bar ───────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.onChanged});
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(AppRadii.r3),
          border: Border.all(color: AppColors.borderSoft),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            const Icon(Icons.search, size: 18, color: AppColors.muted),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: AppColors.fg),
                decoration: const InputDecoration(
                  hintText: 'Search players or clubs…',
                  hintStyle: TextStyle(color: AppColors.muted, fontSize: 14),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Filter strip ─────────────────────────────────────────────────────────

class _FilterStrip extends StatelessWidget {
  const _FilterStrip({
    required this.allowedPositions,
    required this.positionFilter,
    required this.onPositionFilter,
    required this.onlyAffordable,
    required this.onAffordableTap,
    required this.inFormOnly,
    required this.onInFormTap,
    required this.startersOnly,
    required this.onStartersTap,
    required this.sort,
    required this.onSortTap,
    required this.teamFilter,
    required this.onClearTeam,
  });
  final Set<PlayerPosition> allowedPositions;
  final PlayerPosition? positionFilter;
  final ValueChanged<PlayerPosition?> onPositionFilter;
  final bool onlyAffordable;
  final VoidCallback onAffordableTap;
  final bool inFormOnly;
  final VoidCallback onInFormTap;
  final bool startersOnly;
  final VoidCallback onStartersTap;
  final _Sort sort;
  final VoidCallback onSortTap;
  final String? teamFilter;
  final VoidCallback onClearTeam;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _Chip(
            label: _sortLabel(sort),
            icon: Icons.sort,
            selected: true,
            onTap: onSortTap,
          ),
          const _Sep(),
          _Chip(
            label: 'In budget',
            icon: Icons.account_balance_wallet_outlined,
            selected: onlyAffordable,
            onTap: onAffordableTap,
          ),
          _Chip(
            label: 'In form',
            icon: Icons.trending_up,
            selected: inFormOnly,
            onTap: onInFormTap,
            hint: 'Rating ≥ 7.0',
          ),
          _Chip(
            label: 'Starters',
            icon: Icons.event_available_outlined,
            selected: startersOnly,
            onTap: onStartersTap,
            hint: '≥ 10 apps last season',
          ),
          if (allowedPositions.length > 1) ...[
            const _Sep(),
            _Chip(
              label: 'All',
              selected: positionFilter == null,
              onTap: () => onPositionFilter(null),
            ),
            for (final p in [PlayerPosition.DEF, PlayerPosition.MID, PlayerPosition.FWD])
              if (allowedPositions.contains(p))
                _Chip(
                  label: p.name,
                  selected: positionFilter == p,
                  onTap: () => onPositionFilter(p),
                ),
          ],
          if (teamFilter != null) ...[
            const _Sep(),
            _Chip(
              label: 'Team: $teamFilter',
              icon: Icons.close,
              selected: true,
              onTap: onClearTeam,
            ),
          ],
        ],
      ),
    );
  }

  static String _sortLabel(_Sort s) => switch (s) {
        _Sort.form    => 'Form ↓',
        _Sort.price   => 'Price ↓',
        _Sort.goals   => 'Goals ↓',
        _Sort.minutes => 'Minutes ↓',
        _Sort.name    => 'A-Z',
      };
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.hint,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final chip = Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? AppColors.gold.withValues(alpha: 0.16) : AppColors.surface2,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: selected ? AppColors.goldHairline : AppColors.borderSoft,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 13,
                  color: selected ? AppColors.gold : AppColors.muted,
                ),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected ? AppColors.gold : AppColors.fgSoft,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return hint == null ? chip : Tooltip(message: hint!, child: chip);
  }
}

class _Sep extends StatelessWidget {
  const _Sep();
  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 18,
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        color: AppColors.borderSoft,
      );
}

// ─── Player row ────────────────────────────────────────────────────────────

class _PlayerRow extends StatelessWidget {
  const _PlayerRow({
    required this.v,
    required this.affordable,
    required this.onTap,
    required this.onTeamTap,
  });
  final PlayerValuationDto v;
  final bool affordable;
  final VoidCallback? onTap;
  final VoidCallback onTeamTap;

  @override
  Widget build(BuildContext context) {
    final rating = v.seasonRating ?? v.recentForm;
    final hasRating = v.seasonRating != null || v.recentForm > 0;
    final formColor = !hasRating
        ? AppColors.muted
        : rating >= 7.5
            ? AppColors.pitch
            : rating >= 7.0
                ? AppColors.gold
                : rating >= 6.5
                    ? AppColors.fgSoft
                    : AppColors.muted;

    return Opacity(
      opacity: affordable ? 1.0 : 0.55,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.r4),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(AppRadii.r4),
              border: Border.all(
                color: affordable
                    ? AppColors.borderSoft
                    : AppColors.live.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                _Avatar(url: v.player.photoUrl, lastName: v.player.name.split(' ').last),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        v.player.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.16,
                          color: AppColors.fg,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: onTeamTap,
                            behavior: HitTestBehavior.opaque,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 12, height: 12,
                                  child: v.player.team.crestUrl != null
                                      ? PremiumImage(url: v.player.team.crestUrl, fit: BoxFit.contain)
                                      : null,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  v.player.team.shortName ?? v.player.team.name,
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.surface3,
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              v.position.name,
                              style: const TextStyle(
                                fontFamily: 'JetBrainsMono',
                                fontFamilyFallback: ['SF Mono', 'Menlo', 'monospace'],
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.fgSoft,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ],
                      ),
                      // Season stat pills — only shown when we have data
                      // (avoids empty noise on freshly seeded squads).
                      if (v.seasonAppearances > 0) ...[
                        const SizedBox(height: 5),
                        Wrap(
                          spacing: 5,
                          runSpacing: 2,
                          children: [
                            _StatPill(label: 'APP', value: '${v.seasonAppearances}'),
                            if (v.seasonGoals > 0) _StatPill(label: 'GLS', value: '${v.seasonGoals}'),
                            if (v.seasonAssists > 0) _StatPill(label: 'AST', value: '${v.seasonAssists}'),
                            if (v.seasonMinutes > 0)
                              _StatPill(label: 'MIN', value: '${(v.seasonMinutes / 90).round()}×90'),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: affordable
                            ? AppColors.gold.withValues(alpha: 0.15)
                            : AppColors.live.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                          color: affordable ? AppColors.goldHairline : AppColors.live.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        v.price.toStringAsFixed(1),
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: affordable ? AppColors.gold : AppColors.live,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          letterSpacing: -0.14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: formColor.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: formColor.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_formIcon(rating, hasRating), size: 10, color: formColor),
                          const SizedBox(width: 3),
                          Text(
                            hasRating ? rating.toStringAsFixed(1) : '—',
                            style: TextStyle(
                              fontFamily: 'JetBrainsMono',
                              fontFamilyFallback: const ['SF Mono', 'Menlo', 'monospace'],
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: formColor,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Form glyph keyed to rating buckets — green up-arrow for hot, neutral
  /// dash for warm, down-arrow for cold, question mark for unknown.
  IconData _formIcon(double rating, bool has) {
    if (!has) return Icons.help_outline;
    if (rating >= 7.0) return Icons.trending_up;
    if (rating >= 6.5) return Icons.trending_flat;
    return Icons.trending_down;
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: AppColors.surface3,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'JetBrainsMono',
              fontFamilyFallback: ['SF Mono', 'Menlo', 'monospace'],
              fontSize: 7.5,
              fontWeight: FontWeight.w800,
              color: AppColors.muted,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(width: 3),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'JetBrainsMono',
              fontFamilyFallback: ['SF Mono', 'Menlo', 'monospace'],
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: AppColors.fgSoft,
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.lastName});
  final String? url;
  final String lastName;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44, height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surface3,
        border: Border.all(color: AppColors.borderSoft),
      ),
      clipBehavior: Clip.antiAlias,
      child: url != null && url!.isNotEmpty
          ? PremiumImage(url: url, fit: BoxFit.cover)
          : Center(
              child: Text(
                lastName.isEmpty ? '·' : lastName[0].toUpperCase(),
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.muted,
                ),
              ),
            ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.hint});
  final String hint;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, size: 36, color: AppColors.muted2),
            const SizedBox(height: 10),
            const Eyebrow('No matches', gold: true, size: 11),
            const SizedBox(height: 6),
            Text(
              hint,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
