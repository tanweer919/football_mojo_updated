import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/widgets/eyebrow.dart';
import '../../../../core/widgets/pitch_buttons.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../album/data/models/card_models.dart';
import '../../data/market_models.dart';
import '../../data/market_repository.dart';

/// Modal sheet that lets the user edit every catalogue filter (rarity,
/// edition, position, country, team, availability, ownership). Returns the
/// next filter state, or `null` if the user dismissed without applying.
Future<MarketFilters?> showMarketFilterSheet(
  BuildContext context,
  WidgetRef _ref,
  MarketFilters initial,
) async {
  return showModalBottomSheet<MarketFilters>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _MarketFilterSheet(initial: initial),
  );
}

class _MarketFilterSheet extends ConsumerStatefulWidget {
  const _MarketFilterSheet({required this.initial});
  final MarketFilters initial;
  @override
  ConsumerState<_MarketFilterSheet> createState() => _MarketFilterSheetState();
}

class _MarketFilterSheetState extends ConsumerState<_MarketFilterSheet> {
  late MarketFilters _draft = widget.initial;

  @override
  Widget build(BuildContext context) {
    final facetsAsync = ref.watch(marketFacetsProvider);
    // Limit height so on tall screens we don't push controls past the
    // keyboard / fold; on short screens we let the inner list scroll.
    final maxH = MediaQuery.sizeOf(context).height * 0.85;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              children: [
                const Text(
                  'Filters',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.36,
                    color: AppColors.fg,
                  ),
                ),
                const Spacer(),
                if (!_draft.isPristine)
                  GestureDetector(
                    onTap: () => setState(() => _draft = const MarketFilters()),
                    child: const Eyebrow('Reset', gold: true, size: 11),
                  ),
              ],
            ),
          ),
          const Divider(color: AppColors.borderSoft, height: 1),
          Expanded(
            child: facetsAsync.when(
              loading: () => const _SheetSkeleton(),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('$e', style: const TextStyle(color: AppColors.live)),
                ),
              ),
              data: (f) => _FilterBody(
                facets: f,
                draft: _draft,
                onChanged: (next) => setState(() => _draft = next),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.viewPaddingOf(context).bottom + 16),
            child: Row(
              children: [
                Expanded(
                  child: GhostButton(
                    label: 'Cancel',
                    onPressed: () => Navigator.pop(context),
                    expand: true,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GoldButton(
                    label: 'Apply',
                    onPressed: () => Navigator.pop(context, _draft),
                    expand: true,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBody extends StatelessWidget {
  const _FilterBody({
    required this.facets,
    required this.draft,
    required this.onChanged,
  });
  final MarketFacets facets;
  final MarketFilters draft;
  final ValueChanged<MarketFilters> onChanged;

  static const _rarityOrder = [
    CardRarity.ICONIC,
    CardRarity.LEGENDARY,
    CardRarity.EPIC,
    CardRarity.RARE,
    CardRarity.UNCOMMON,
    CardRarity.COMMON,
  ];

  String _rarityLabel(CardRarity r) => rarityLabel(r);

  @override
  Widget build(BuildContext context) {
    // Build facet-count lookup so chips can display counts inline.
    int rarityCount(CardRarity r) =>
        facets.rarities.firstWhere(
              (b) => b.value == r.name,
              orElse: () => const FacetBucket(value: '', count: 0),
            ).count;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      children: [
        _Section(
          label: 'Rarity',
          child: Wrap(
            spacing: 8, runSpacing: 8,
            children: [
              for (final r in _rarityOrder)
                _ChipToggle(
                  label: _rarityLabel(r),
                  count: rarityCount(r),
                  selected: draft.rarities.contains(r),
                  onTap: () {
                    final next = {...draft.rarities};
                    next.contains(r) ? next.remove(r) : next.add(r);
                    onChanged(draft.copyWith(rarities: next));
                  },
                ),
            ],
          ),
        ),
        _Section(
          label: 'Position',
          child: Wrap(
            spacing: 8, runSpacing: 8,
            children: [
              for (final b in facets.positions)
                _ChipToggle(
                  label: b.value,
                  count: b.count,
                  selected: draft.positions.contains(b.value),
                  onTap: () {
                    final next = {...draft.positions};
                    next.contains(b.value) ? next.remove(b.value) : next.add(b.value);
                    onChanged(draft.copyWith(positions: next));
                  },
                ),
            ],
          ),
        ),
        _Section(
          label: 'Edition',
          child: Wrap(
            spacing: 8, runSpacing: 8,
            children: [
              for (final b in facets.editions)
                _ChipToggle(
                  label: b.value,
                  count: b.count,
                  selected: draft.editions.contains(b.value),
                  onTap: () {
                    final next = {...draft.editions};
                    next.contains(b.value) ? next.remove(b.value) : next.add(b.value);
                    onChanged(draft.copyWith(editions: next));
                  },
                ),
            ],
          ),
        ),
        _Section(
          label: 'Country',
          child: Wrap(
            spacing: 8, runSpacing: 8,
            children: [
              for (final b in facets.countries.take(30))
                _ChipToggle(
                  label: b.value,
                  count: b.count,
                  selected: draft.countries.contains(b.value),
                  onTap: () {
                    final next = {...draft.countries};
                    next.contains(b.value) ? next.remove(b.value) : next.add(b.value);
                    onChanged(draft.copyWith(countries: next));
                  },
                ),
            ],
          ),
        ),
        _Section(
          label: 'Team',
          child: Wrap(
            spacing: 8, runSpacing: 8,
            children: [
              for (final b in facets.teams.take(40))
                _ChipToggle(
                  label: (b.label ?? b.value),
                  count: b.count,
                  selected: draft.teamIds.contains(b.value),
                  onTap: () {
                    final next = {...draft.teamIds};
                    next.contains(b.value) ? next.remove(b.value) : next.add(b.value);
                    onChanged(draft.copyWith(teamIds: next));
                  },
                ),
            ],
          ),
        ),
        _Section(
          label: 'Availability',
          child: Wrap(
            spacing: 8, runSpacing: 8,
            children: [
              for (final v in MarketAvailability.values)
                _ChipToggle(
                  label: v.label,
                  selected: draft.availability == v,
                  onTap: () => onChanged(draft.copyWith(availability: v)),
                ),
            ],
          ),
        ),
        _Section(
          label: 'Collection',
          child: Wrap(
            spacing: 8, runSpacing: 8,
            children: [
              for (final v in MarketOwnership.values)
                _ChipToggle(
                  label: v.label,
                  selected: draft.ownership == v,
                  onTap: () => onChanged(draft.copyWith(ownership: v)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.label, required this.child});
  final String label;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Eyebrow(label, gold: true, size: 10),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _ChipToggle extends StatelessWidget {
  const _ChipToggle({
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
  });
  final String label;
  final bool selected;
  final int? count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.gold.withValues(alpha: 0.14) : AppColors.surface2,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: selected ? AppColors.goldHairline : AppColors.borderSoft,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: selected ? AppColors.gold : AppColors.fg,
              ),
            ),
            if (count != null && count! > 0) ...[
              const SizedBox(width: 6),
              Text(
                '$count',
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontFamilyFallback: const ['SF Mono', 'Menlo', 'monospace'],
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: selected ? AppColors.goldSoft : AppColors.muted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SheetSkeleton extends StatelessWidget {
  const _SheetSkeleton();
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: const [
        Skeleton(height: 20, radius: 4, width: 80),
        SizedBox(height: 10),
        Skeleton(height: 36, radius: AppRadii.full),
        SizedBox(height: 20),
        Skeleton(height: 20, radius: 4, width: 80),
        SizedBox(height: 10),
        Skeleton(height: 36, radius: AppRadii.full),
        SizedBox(height: 20),
        Skeleton(height: 20, radius: 4, width: 80),
        SizedBox(height: 10),
        Skeleton(height: 36, radius: AppRadii.full),
      ],
    );
  }
}
