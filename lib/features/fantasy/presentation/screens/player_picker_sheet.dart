import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/motion.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/premium_image.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../data/models/fantasy_models.dart';
import '../providers/fantasy_providers.dart';

/// Modal sheet to pick a player at a given position. Premium card-style list:
/// avatar, name, team crest, form, price chip. Inaffordable players are
/// dimmed but still rendered.
Future<String?> showPlayerPicker(
  BuildContext context, {
  required String tournamentSlug,
  required PlayerPosition position,
  required Set<String> excludePlayerIds,
  required double remainingBudget,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.88),
    builder: (_) => _PickerSheet(
      slug: tournamentSlug,
      position: position,
      exclude: excludePlayerIds,
      remainingBudget: remainingBudget,
    ),
  );
}

enum _Sort { price, form, name }

class _PickerSheet extends ConsumerStatefulWidget {
  const _PickerSheet({
    required this.slug,
    required this.position,
    required this.exclude,
    required this.remainingBudget,
  });
  final String slug;
  final PlayerPosition position;
  final Set<String> exclude;
  final double remainingBudget;
  @override
  ConsumerState<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends ConsumerState<_PickerSheet> {
  String _query = '';
  _Sort _sort = _Sort.price;
  bool _onlyAffordable = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final async = ref.watch(selectablePlayersProvider(widget.slug));
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg, 0, AppSpacing.lg, MediaQuery.viewInsetsOf(context).bottom + AppSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Header(position: widget.position, remainingBudget: widget.remainingBudget),
          const SizedBox(height: AppSpacing.md),
          TextField(
            decoration: InputDecoration(
              hintText: 'Search players or teams',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.lg),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHigh,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _Chip(
                  label: 'Price ↓',
                  selected: _sort == _Sort.price,
                  onTap: () => setState(() => _sort = _Sort.price),
                  icon: Icons.sell_outlined,
                ),
                _Chip(
                  label: 'Form',
                  selected: _sort == _Sort.form,
                  onTap: () => setState(() => _sort = _Sort.form),
                  icon: Icons.trending_up,
                ),
                _Chip(
                  label: 'A-Z',
                  selected: _sort == _Sort.name,
                  onTap: () => setState(() => _sort = _Sort.name),
                  icon: Icons.sort_by_alpha,
                ),
                const VerticalDivider(width: 16),
                _Chip(
                  label: 'In budget',
                  selected: _onlyAffordable,
                  onTap: () => setState(() => _onlyAffordable = !_onlyAffordable),
                  icon: Icons.account_balance_wallet_outlined,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: async.when(
              loading: () => const SkeletonList(itemHeight: 72),
              error: (e, _) => ErrorView(
                message: '$e',
                onRetry: () => ref.invalidate(selectablePlayersProvider(widget.slug)),
              ),
              data: (all) {
                final filtered = all
                    .where((p) =>
                        p.position == widget.position && !widget.exclude.contains(p.playerId))
                    .where((p) {
                  if (!_onlyAffordable) return true;
                  return p.price <= widget.remainingBudget + 0.001;
                }).where((p) {
                  if (_query.isEmpty) return true;
                  return p.player.name.toLowerCase().contains(_query) ||
                      p.player.team.name.toLowerCase().contains(_query);
                }).toList()
                  ..sort(_sorter);

                if (filtered.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text('No players match those filters'),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (_, i) {
                    final v = filtered[i];
                    final affordable = v.price <= widget.remainingBudget + 0.001;
                    return _PlayerRow(
                      v: v,
                      affordable: affordable,
                      onTap: affordable ? () => Navigator.of(context).pop(v.playerId) : null,
                      index: i,
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

  int _sorter(PlayerValuationDto a, PlayerValuationDto b) {
    switch (_sort) {
      case _Sort.price:
        return b.price.compareTo(a.price);
      case _Sort.form:
        return b.recentForm.compareTo(a.recentForm);
      case _Sort.name:
        return a.player.name.compareTo(b.player.name);
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.position, required this.remainingBudget});
  final PlayerPosition position;
  final double remainingBudget;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(
            _label(position).toUpperCase(),
            style: TextStyle(
              color: theme.colorScheme.onPrimaryContainer,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            'Pick a player',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'BUDGET',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
            Text(
              remainingBudget.toStringAsFixed(1),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: theme.colorScheme.primary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _label(PlayerPosition p) => switch (p) {
        PlayerPosition.GK => 'goalkeeper',
        PlayerPosition.DEF => 'defender',
        PlayerPosition.MID => 'midfielder',
        PlayerPosition.FWD => 'forward',
      };
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.icon,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? theme.colorScheme.primaryContainer
                : theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: selected
                  ? theme.colorScheme.primary.withValues(alpha: 0.4)
                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: selected
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: selected
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayerRow extends StatelessWidget {
  const _PlayerRow({
    required this.v,
    required this.affordable,
    required this.onTap,
    required this.index,
  });
  final PlayerValuationDto v;
  final bool affordable;
  final VoidCallback? onTap;
  final int index;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formColor = v.recentForm >= 7
        ? const Color(0xFF34D399)
        : v.recentForm >= 4
            ? const Color(0xFFFBBF24)
            : theme.colorScheme.onSurfaceVariant;

    return Opacity(
      opacity: affordable ? 1.0 : 0.55,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              ClipOval(
                child: SizedBox(
                  width: 44, height: 44,
                  child: v.player.photoUrl != null
                      ? PremiumImage(url: v.player.photoUrl, fit: BoxFit.cover)
                      : Container(
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: Icon(Icons.person, color: theme.colorScheme.onSurfaceVariant),
                        ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      v.player.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 14, height: 14,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.colorScheme.surfaceContainerHighest,
                          ),
                          child: v.player.team.crestUrl != null
                              ? ClipOval(
                                  child: PremiumImage(
                                    url: v.player.team.crestUrl,
                                    fit: BoxFit.contain,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            v.player.team.shortName ?? v.player.team.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: affordable
                          ? theme.colorScheme.primary.withValues(alpha: 0.15)
                          : theme.colorScheme.error.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      v.price.toStringAsFixed(1),
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: affordable
                            ? theme.colorScheme.primary
                            : theme.colorScheme.error,
                        fontWeight: FontWeight.w900,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.trending_up, size: 12, color: formColor),
                      const SizedBox(width: 2),
                      Text(
                        v.recentForm.toStringAsFixed(1),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: formColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).animate().fade(
        duration: AppMotion.sm,
        delay: (20 * index.clamp(0, 12)).ms,
        curve: AppMotion.enter);
  }
}
