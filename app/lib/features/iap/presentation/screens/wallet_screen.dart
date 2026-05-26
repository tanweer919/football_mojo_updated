import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/rarity_theme.dart';
import '../../../../core/router/route_paths.dart';
import '../../../album/data/repositories/album_repository.dart';
import '../../data/gems_repository.dart';

/// Gem wallet — balance, daily claim, earn rules, spend catalog, history.
class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balance = ref.watch(gemBalanceProvider);
    final catalog = ref.watch(gemCatalogProvider);
    final history = ref.watch(gemHistoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Gems')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(gemBalanceProvider);
          ref.invalidate(gemHistoryProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _BalanceCard(
              balance: balance,
              onClaim: () async {
                try {
                  final result =
                      await ref.read(gemsRepositoryProvider).claimDaily();
                  ref.invalidate(gemBalanceProvider);
                  ref.invalidate(gemHistoryProvider);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(result.awarded > 0
                          ? '+${result.awarded} gems claimed!'
                          : 'Already claimed today.'),
                    ));
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$e')),
                    );
                  }
                }
              },
            ),
            const SizedBox(height: 18),
            Text('Earn',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            _EarnRules(catalog: catalog),
            const SizedBox(height: 18),
            Text('Store',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            _Store(
              onPurchased: () {
                ref.invalidate(gemBalanceProvider);
                ref.invalidate(gemHistoryProvider);
                ref.invalidate(storeFeaturedProvider);
              },
            ),
            const SizedBox(height: 18),
            Text('Other spends',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            _SpendCatalog(catalog: catalog),
            const SizedBox(height: 22),
            Text('Recent activity',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            _HistoryList(history: history),
          ],
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.balance, required this.onClaim});
  final AsyncValue<GemBalance> balance;
  final Future<void> Function() onClaim;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.16),
            theme.colorScheme.primary.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.diamond_rounded, size: 36, color: theme.colorScheme.primary),
          const SizedBox(width: 14),
          Expanded(
            child: balance.when(
              loading: () => const SizedBox(
                height: 36,
                child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              error: (e, _) => Text('$e'),
              data: (b) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${b.balance}',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      height: 1.0,
                    ),
                  ).animate().fade(duration: 200.ms),
                  const SizedBox(height: 2),
                  Text('Gems', style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ),
          balance.maybeWhen(
            data: (b) => FilledButton.icon(
              onPressed: b.canClaimDaily ? onClaim : null,
              icon: const Icon(Icons.calendar_today_rounded, size: 16),
              label: Text(b.canClaimDaily ? 'Claim daily' : 'Claimed'),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _EarnRules extends StatelessWidget {
  const _EarnRules({required this.catalog});
  final AsyncValue<GemCatalog> catalog;

  @override
  Widget build(BuildContext context) {
    return catalog.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('$e'),
      data: (c) {
        final r = c.earnRules;
        final fantasy = (r['fantasy'] as Map?) ?? const {};
        Widget row(String label, dynamic val, IconData icon) => _RuleRow(
              icon: icon,
              label: label,
              amount: val is num ? val.toInt() : 0,
            );
        return Column(
          children: [
            row('Correct prediction', r['predictionResult'], Icons.check_circle_outline_rounded),
            row('Exact-score prediction', r['predictionExact'], Icons.star_outline_rounded),
            row('Bracket — group winner', r['bracketGroupWinner'], Icons.tour_outlined),
            row('Bracket — group runner-up', r['bracketRunnerUp'], Icons.tour_outlined),
            row('Bracket — champion', r['bracketChampion'], Icons.emoji_events_outlined),
            row('Daily login', r['dailyLogin'], Icons.calendar_today_outlined),
            row('Fantasy #1 this gameweek', fantasy['top1'], Icons.emoji_events_rounded),
            row('Fantasy top 10', fantasy['top10'], Icons.emoji_events_outlined),
            row('Fantasy top 100', fantasy['top100'], Icons.emoji_events_outlined),
          ],
        );
      },
    );
  }
}

class _SpendCatalog extends StatelessWidget {
  const _SpendCatalog({required this.catalog});
  final AsyncValue<GemCatalog> catalog;

  @override
  Widget build(BuildContext context) {
    return catalog.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('$e'),
      data: (c) {
        return Column(
          children: [
            for (final entry in c.packs.entries)
              _RuleRow(
                icon: Icons.inventory_2_outlined,
                label: '${_titleCase(entry.key)} card pack',
                amount: entry.value,
                debit: true,
              ),
            _RuleRow(
              icon: Icons.palette_outlined,
              label: 'Profile flair',
              amount: c.profileFlair,
              debit: true,
            ),
            _RuleRow(
              icon: Icons.swap_horiz_rounded,
              label: 'Captain re-roll',
              amount: c.captainReroll,
              debit: true,
            ),
          ],
        );
      },
    );
  }

  static String _titleCase(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

class _Store extends ConsumerWidget {
  const _Store({required this.onPurchased});
  final VoidCallback onPurchased;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final featured = ref.watch(storeFeaturedProvider);
    return featured.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Text('$e'),
      data: (list) {
        if (list.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'No featured cards on sale right now. Check back when the next drop opens.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          );
        }
        return SizedBox(
          height: 200,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(vertical: 2),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) => _StoreCard(
              template: list[i],
              onPurchased: onPurchased,
            ),
          ),
        );
      },
    );
  }
}

class _StoreCard extends ConsumerStatefulWidget {
  const _StoreCard({required this.template, required this.onPurchased});
  final StoreTemplate template;
  final VoidCallback onPurchased;
  @override
  ConsumerState<_StoreCard> createState() => _StoreCardState();
}

class _StoreCardState extends ConsumerState<_StoreCard> {
  bool _buying = false;

  Future<void> _buy() async {
    setState(() => _buying = true);
    try {
      await ref
          .read(albumRepositoryProvider)
          .purchaseTemplate(widget.template.id);
      widget.onPurchased();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Minted ${widget.template.edition}!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_friendly('$e'))),
        );
      }
    } finally {
      if (mounted) setState(() => _buying = false);
    }
  }

  String _friendly(String raw) {
    if (raw.contains('insufficient_gems')) return 'Not enough gems.';
    if (raw.contains('sold_out')) return 'Sold out.';
    if (raw.contains('per_user_cap_reached')) return 'Already at your cap.';
    if (raw.contains('drop_closed')) return 'Drop has closed.';
    return 'Purchase failed. Try again.';
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.template;
    final theme = RarityTheme.of(t.rarity);
    final isSoldOut = t.isSoldOut;
    return SizedBox(
      width: 152,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          // Tapping anywhere except the Buy button opens the full market
          // detail (mint history, form, holders) so users see what they're
          // buying before they spend gems.
          onTap: () => context.push(
            RoutePaths.marketCard.replaceAll(':templateId', t.id),
          ),
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              gradient: theme.gradient,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: theme.frame, width: 1.2),
            ),
            child: Column(
              children: [
                Expanded(
                  child: Stack(
                fit: StackFit.expand,
                children: [
                  if (t.artUrl.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: t.artUrl,
                      fit: BoxFit.contain,
                      errorWidget: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        theme.label.toUpperCase(),
                        style: TextStyle(
                          color: theme.accent,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ),
                  if (t.totalSupply > 0)
                    Positioned(
                      bottom: 4,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          isSoldOut ? 'SOLD OUT' : '${t.mintedCount}/${t.totalSupply}',
                          style: TextStyle(
                            color: isSoldOut
                                ? Colors.redAccent.shade100
                                : theme.accent,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (t.playerName ?? t.edition).toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.diamond_rounded,
                          size: 12, color: theme.accent),
                      const SizedBox(width: 4),
                      Text(
                        '${t.gemPrice}',
                        style: TextStyle(
                          color: theme.accent,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const Spacer(),
                      SizedBox(
                        height: 26,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: Size.zero,
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: (isSoldOut || _buying) ? null : _buy,
                          child: Text(
                            _buying ? '…' : (isSoldOut ? '—' : 'Buy'),
                            style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
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

class _RuleRow extends StatelessWidget {
  const _RuleRow({
    required this.icon,
    required this.label,
    required this.amount,
    this.debit = false,
  });
  final IconData icon;
  final String label;
  final int amount;
  final bool debit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = debit ? theme.colorScheme.error : theme.colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          Text(
            '${debit ? '−' : '+'}$amount',
            style: theme.textTheme.titleSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryList extends StatelessWidget {
  const _HistoryList({required this.history});
  final AsyncValue<GemHistoryPage> history;

  @override
  Widget build(BuildContext context) {
    return history.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Text('$e'),
      data: (page) {
        if (page.rows.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Text(
              'No activity yet — play to earn gems.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          );
        }
        return Column(
          children: [
            for (final tx in page.rows) _HistoryRow(tx: tx),
          ],
        );
      },
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.tx});
  final GemTxn tx;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final positive = tx.amount > 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            positive ? Icons.add_circle_outline_rounded : Icons.remove_circle_outline_rounded,
            size: 18,
            color: positive ? theme.colorScheme.primary : theme.colorScheme.error,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.description ?? _humanSource(tx.source),
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  _formatDate(tx.createdAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${positive ? '+' : ''}${tx.amount}',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: positive ? theme.colorScheme.primary : theme.colorScheme.error,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  String _humanSource(String s) => s
      .toLowerCase()
      .replaceAll('_', ' ')
      .replaceAllMapped(RegExp(r'(^| )([a-z])'), (m) => '${m[1]}${m[2]!.toUpperCase()}');

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}
