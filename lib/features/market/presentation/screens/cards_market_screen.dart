import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/widgets/eyebrow.dart';
import '../../../../core/widgets/pcard.dart';
import '../../../../core/widgets/pitch_buttons.dart';
import '../../../../core/widgets/pitch_scaffold.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../album/data/models/card_models.dart';
import '../../data/market_models.dart';
import '../../data/market_repository.dart';
import '../widgets/market_filter_sheet.dart';

/// `CardsMarketScreen` — public, anonymous-friendly browse of every minted
/// template in the catalogue. Two-column grid of `PCard`s with a sticky
/// filter bar above. Tap a card → `MarketTemplateDetailScreen`.
///
/// State management:
///   - filter state held locally in a `StatefulWidget` (cheap, scoped)
///   - first page comes from `marketFirstPageProvider.family(filters)` so
///     identical filter sets dedupe automatically
///   - subsequent pages are appended in-memory via `_loadMore` driven by a
///     ScrollController — Riverpod-family pagination is overkill here.
class CardsMarketScreen extends ConsumerStatefulWidget {
  const CardsMarketScreen({super.key});
  @override
  ConsumerState<CardsMarketScreen> createState() => _CardsMarketScreenState();
}

class _CardsMarketScreenState extends ConsumerState<CardsMarketScreen> {
  MarketFilters _filters = const MarketFilters();
  final _scroll = ScrollController();
  final _searchCtrl = TextEditingController();
  Timer? _searchDebounce;

  // Pagination buffer. Cards appended past the first page live here so a
  // filter change can reset cleanly without invalidating the Riverpod
  // family entry for the first page.
  final List<MarketCard> _extra = [];
  String? _nextCursor;
  bool _loadingMore = false;
  bool _exhausted = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _searchCtrl.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    if (pos.pixels > pos.maxScrollExtent - 600) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _exhausted) return;
    if (_nextCursor == null) return;
    _loadingMore = true;
    try {
      final page = await ref
          .read(marketRepositoryProvider)
          .list(_filters, cursor: _nextCursor);
      if (!mounted) return;
      setState(() {
        _extra.addAll(page.items);
        _nextCursor = page.nextCursor;
        if (page.nextCursor == null || page.items.isEmpty) _exhausted = true;
      });
    } catch (_) {
      // swallow — user can pull-to-refresh if it persists.
    } finally {
      _loadingMore = false;
    }
  }

  void _applyFilters(MarketFilters next) {
    if (next == _filters) return;
    setState(() {
      _filters = next;
      _extra.clear();
      _nextCursor = null;
      _exhausted = false;
    });
  }

  void _onSearchChanged(String v) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      _applyFilters(_filters.copyWith(search: v));
    });
  }

  @override
  Widget build(BuildContext context) {
    final first = ref.watch(marketFirstPageProvider(_filters));

    return PitchScreen(
      title: 'Market',
      // Browsing the market is the catalogue's "home" — back goes to the
      // tab home rather than popping into an empty stack.
      onBack: context.canPop() ? () => context.pop() : null,
      trailing: CircleIconButton(
        icon: Icons.collections_outlined,
        onPressed: () => context.go('/album'),
      ),
      scrollable: false,
      child: Column(
        children: [
          _SearchAndFilterBar(
            controller: _searchCtrl,
            filters: _filters,
            onSearchChanged: _onSearchChanged,
            onTapFilters: () async {
              final updated = await showMarketFilterSheet(context, ref, _filters);
              if (updated != null) _applyFilters(updated);
            },
            onSortChanged: (s) => _applyFilters(_filters.copyWith(sort: s)),
            onClear: () {
              _searchCtrl.clear();
              _applyFilters(const MarketFilters());
            },
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.gold,
              backgroundColor: AppColors.surface,
              onRefresh: () async {
                ref.invalidate(marketFirstPageProvider(_filters));
                setState(() {
                  _extra.clear();
                  _nextCursor = null;
                  _exhausted = false;
                });
                await ref.read(marketFirstPageProvider(_filters).future);
              },
              child: first.when(
                loading: () => const _GridSkeleton(),
                error: (e, _) => _ErrorBlock(
                  message: '$e',
                  onRetry: () => ref.invalidate(marketFirstPageProvider(_filters)),
                ),
                data: (page) {
                  if (_nextCursor == null && !_exhausted) {
                    // Latch the first cursor lazily once the page lands.
                    _nextCursor = page.nextCursor;
                    if (page.nextCursor == null) _exhausted = true;
                  }
                  final all = [...page.items, ..._extra];
                  if (all.isEmpty) return _EmptyBlock(onReset: () => _applyFilters(const MarketFilters()));
                  return _MarketGrid(
                    cards: all,
                    scroll: _scroll,
                    loadingMore: _loadingMore && !_exhausted,
                    totalShown: all.length,
                    onTap: (c) => context.push('/market/${c.id}'),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Search + filter bar ────────────────────────────────────────────────

class _SearchAndFilterBar extends StatelessWidget {
  const _SearchAndFilterBar({
    required this.controller,
    required this.filters,
    required this.onSearchChanged,
    required this.onTapFilters,
    required this.onSortChanged,
    required this.onClear,
  });
  final TextEditingController controller;
  final MarketFilters filters;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onTapFilters;
  final ValueChanged<MarketSort> onSortChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
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
                          controller: controller,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            color: AppColors.fg,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Search player or card…',
                            hintStyle: TextStyle(color: AppColors.muted, fontSize: 14),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 12),
                          ),
                          onChanged: onSearchChanged,
                          textInputAction: TextInputAction.search,
                        ),
                      ),
                      if (controller.text.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            controller.clear();
                            onSearchChanged('');
                          },
                          child: const Icon(Icons.close, size: 16, color: AppColors.muted),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _FilterButton(
                count: filters.activeCount,
                onTap: onTapFilters,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _SortPill(value: filters.sort, onChanged: onSortChanged),
              const Spacer(),
              if (!filters.isPristine)
                GestureDetector(
                  onTap: onClear,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Eyebrow('Clear all', gold: true, size: 10),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final active = count > 0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: active ? AppColors.gold.withValues(alpha: 0.12) : AppColors.surface2,
          borderRadius: BorderRadius.circular(AppRadii.r3),
          border: Border.all(
            color: active ? AppColors.goldHairline : AppColors.borderSoft,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.tune,
              size: 18,
              color: active ? AppColors.gold : AppColors.muted,
            ),
            const SizedBox(width: 8),
            Text(
              'Filters',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: active ? AppColors.gold : AppColors.fg,
              ),
            ),
            if (active) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.gold,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontFamilyFallback: ['SF Mono', 'Menlo', 'monospace'],
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E1810),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SortPill extends StatelessWidget {
  const _SortPill({required this.value, required this.onChanged});
  final MarketSort value;
  final ValueChanged<MarketSort> onChanged;
  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<MarketSort>(
      tooltip: 'Sort',
      color: AppColors.surface2,
      initialValue: value,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.r3)),
      itemBuilder: (_) => [
        for (final s in MarketSort.values)
          PopupMenuItem(
            value: s,
            child: Row(
              children: [
                Icon(
                  s == value ? Icons.check : Icons.sort,
                  size: 14,
                  color: s == value ? AppColors.gold : AppColors.muted,
                ),
                const SizedBox(width: 8),
                Text(s.label, style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.fg)),
              ],
            ),
          ),
      ],
      onSelected: onChanged,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: AppColors.borderSoft),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sort, size: 14, color: AppColors.muted),
            const SizedBox(width: 6),
            Text(
              value.label,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.fg,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more, size: 16, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

// ─── Grid ───────────────────────────────────────────────────────────────

class _MarketGrid extends StatelessWidget {
  const _MarketGrid({
    required this.cards,
    required this.scroll,
    required this.loadingMore,
    required this.totalShown,
    required this.onTap,
  });
  final List<MarketCard> cards;
  final ScrollController scroll;
  final bool loadingMore;
  final int totalShown;
  final ValueChanged<MarketCard> onTap;

  @override
  Widget build(BuildContext context) {
    final viewBottom = MediaQuery.viewPaddingOf(context).bottom;
    // The PitchScreen wrapper extends body under the floating tabbar; leave
    // ~110px so the last row clears the pill.
    final bottomPad = 110.0 + viewBottom + 16;
    return CustomScrollView(
      controller: scroll,
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Eyebrow('$totalShown cards', gold: true, size: 10),
                const Spacer(),
                if (loadingMore)
                  const SizedBox(
                    width: 12, height: 12,
                    child: CircularProgressIndicator(strokeWidth: 1.4, color: AppColors.muted),
                  ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.62, // pcard 0.66 + chrome below
            ),
            delegate: SliverChildBuilderDelegate(
              (ctx, i) => _MarketTile(card: cards[i], onTap: () => onTap(cards[i])),
              childCount: cards.length,
            ),
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: bottomPad)),
      ],
    );
  }
}

class _MarketTile extends StatelessWidget {
  const _MarketTile({required this.card, required this.onTap});
  final MarketCard card;
  final VoidCallback onTap;

  static int _ratingFor(CardRarity r) => switch (r) {
        CardRarity.COMMON => 75,
        CardRarity.UNCOMMON => 79,
        CardRarity.RARE => 84,
        CardRarity.EPIC => 88,
        CardRarity.LEGENDARY => 92,
        CardRarity.ICONIC => 95,
      };

  @override
  Widget build(BuildContext context) {
    final p = card.player;
    final ownedBadge = card.ownedByMe > 0;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              children: [
                PCard(
                  rarity: card.rarity,
                  rating: _ratingFor(card.rarity),
                  name: (p?.name ?? card.edition).toUpperCase(),
                  position: (p?.position ?? '—').toUpperCase(),
                  country: (p?.country ?? p?.team?.countryCode ?? '—').toUpperCase(),
                  photoUrl: p?.photoUrl ?? card.artUrl,
                  heroTag: 'market-${card.id}',
                ),
                if (ownedBadge)
                  Positioned(
                    top: 8, right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.pitch,
                        borderRadius: BorderRadius.circular(99),
                        boxShadow: const [BoxShadow(color: AppColors.pitchGlow, blurRadius: 8)],
                      ),
                      child: Text(
                        card.ownedByMe == 1 ? 'OWNED' : '${card.ownedByMe}×',
                        style: const TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontFamilyFallback: ['SF Mono', 'Menlo', 'monospace'],
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0B1A0E),
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
                if (card.isSoldOut)
                  Positioned(
                    bottom: 8, left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.live,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: const Text(
                        'SOLD OUT',
                        style: TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontFamilyFallback: ['SF Mono', 'Menlo', 'monospace'],
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF200807),
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          _SupplyBar(minted: card.mintedCount, total: card.totalSupply),
        ],
      ),
    );
  }
}

class _SupplyBar extends StatelessWidget {
  const _SupplyBar({required this.minted, required this.total});
  final int minted;
  final int total;
  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : (minted / total).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              '#$minted',
              style: const TextStyle(
                fontFamily: 'JetBrainsMono',
                fontFamilyFallback: ['SF Mono', 'Menlo', 'monospace'],
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.gold,
              ),
            ),
            const Spacer(),
            Text(
              '/ $total',
              style: const TextStyle(
                fontFamily: 'JetBrainsMono',
                fontFamilyFallback: ['SF Mono', 'Menlo', 'monospace'],
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.muted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: SizedBox(
            height: 3,
            child: Stack(
              children: [
                Container(color: AppColors.surface3),
                FractionallySizedBox(
                  widthFactor: pct,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.goldDeep, AppColors.gold],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── States ─────────────────────────────────────────────────────────────

class _GridSkeleton extends StatelessWidget {
  const _GridSkeleton();
  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.62,
      ),
      itemCount: 6,
      itemBuilder: (_, __) => const Skeleton(height: double.infinity, radius: 16),
    );
  }
}

class _EmptyBlock extends StatelessWidget {
  const _EmptyBlock({required this.onReset});
  final VoidCallback onReset;
  @override
  Widget build(BuildContext context) {
    return ListView(
      // Wrap in a ListView so RefreshIndicator still works on empty states.
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      children: [
        const SizedBox(height: 80),
        const Icon(Icons.search_off, size: 48, color: AppColors.muted2),
        const SizedBox(height: 12),
        const Center(child: Eyebrow('No cards match', gold: true, size: 11)),
        const SizedBox(height: 6),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            'Try fewer filters or clear the search.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.45),
          ),
        ),
        const SizedBox(height: 18),
        Center(
          child: GhostButton(label: 'Reset filters', onPressed: onReset),
        ),
      ],
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      children: [
        const SizedBox(height: 80),
        const Icon(Icons.error_outline, size: 48, color: AppColors.live),
        const SizedBox(height: 12),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, fontSize: 13, height: 1.45),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Center(child: GhostButton(label: 'Retry', onPressed: onRetry)),
      ],
    );
  }
}
