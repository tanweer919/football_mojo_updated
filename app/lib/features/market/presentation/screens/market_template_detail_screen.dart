import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/auth/auth_repository.dart';
import '../../../../core/auth/sign_in_sheet.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/widgets/eyebrow.dart';
import '../../../../core/widgets/pcard.dart';
import '../../../../core/widgets/pitch_buttons.dart';
import '../../../../core/widgets/pitch_scaffold.dart';
import '../../../../core/widgets/premium_image.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../album/data/models/card_models.dart';
import '../../../album/data/repositories/album_repository.dart';
import '../../../album/presentation/screens/card_reward_reveal_screen.dart';
import '../../../iap/data/gems_repository.dart';
import '../../data/market_models.dart';
import '../../data/market_repository.dart';
import '../widgets/player_form_widgets.dart';

/// Sorare-style card detail page. Layout:
///   Hero PCard → Score + Level → Last scores (form stats) → Performance bars
///   → Card details table → Supply stats → My copies → Sets → History
class MarketTemplateDetailScreen extends ConsumerWidget {
  const MarketTemplateDetailScreen({super.key, required this.templateId});
  final String templateId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(marketTemplateProvider(templateId));
    return PitchScreen(
      title: 'Card',
      onBack: () => Navigator.of(context).maybePop(),
      child: detail.when(
        loading: () => const _DetailSkeleton(),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(24),
          child: Text('$e', style: const TextStyle(color: AppColors.live)),
        ),
        data: (d) => _DetailBody(detail: d, templateId: templateId),
      ),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.detail, required this.templateId});
  final MarketTemplateDetail detail;
  final String templateId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = detail.player;
    final s = detail.stats;
    final card = detail.template;
    final form = detail.formStats;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 4),
        // ─── 1. Hero PCard ───────────────────────────────────────────
        Center(
          child: SizedBox(
            width: 240,
            child: PCard(
              rarity: card.rarity,
              rating: _ratingFor(card.rarity),
              name: p?.name,
              position: p?.position,
              country: p?.country ?? p?.team?.countryCode,
              photoUrl: p?.photoUrl ?? card.artUrl,
              clubCrestUrl: p?.team?.crestUrl,
              leagueLabel: _shortEdition(card.edition),
              editionLabel: card.edition,
              heroTag: 'market-${card.id}',
            ),
          ),
        ),
        const SizedBox(height: 14),

        // ─── 2. Score + Level block ──────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _ScoreLevelBlock(card: card, form: form),
        ),
        const SizedBox(height: 16),

        // ─── 3. Name + edition + team ────────────────────────────────
        _NameBlock(detail: detail),

        // ─── 3b. Buy with gems — any priced card is buyable here ──────
        if (card.purchasable && card.gemPrice != null) ...[
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _BuyCardButton(
              templateId: templateId,
              gemPrice: card.gemPrice!,
              playerName: p?.name,
              soldOut: card.isSoldOut,
            ),
          ),
        ],

        // ─── 4. Last scores — form stats panel ───────────────────────
        if (form != null) ...[
          const _SectionTitle(title: 'Last scores'),
          const _SubTitle(title: 'Stats'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: PlayerFormPanel(
              last5Avg: form.last5.avg,
              last5N: form.last5.n,
              last10Avg: form.last10.avg,
              last10N: form.last10.n,
              last40Avg: form.last40.avg,
              last40N: form.last40.n,
            ),
          ),
        ],

        // ─── 5. Performance bars ─────────────────────────────────────
        if (detail.lastScores.isNotEmpty) ...[
          const _SubTitle(title: 'Performance'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: PerformanceBarsPanel(
              scores: detail.lastScores
                  .map((s) => PerformanceBarData(
                        totalPoints: s.totalPoints,
                        gameweekNumber: s.gameweekNumber,
                        breakdown: s.breakdown,
                      ))
                  .toList(),
            ),
          ),
        ],

        // ─── 6. Card details table ───────────────────────────────────
        const _SectionTitle(title: 'Card details'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _CardDetailsTable(detail: detail),
        ),

        // ─── 7. Supply stats ─────────────────────────────────────────
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _SupplyHero(stats: s),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _StatsGrid(stats: s),
        ),

        // ─── 8. My copies ────────────────────────────────────────────
        if (detail.myCopies.isNotEmpty) ...[
          const _SectionTitle(title: 'Your copies'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _MyCopiesList(copies: detail.myCopies, total: s.totalSupply),
          ),
        ],

        // ─── 9. Sets ─────────────────────────────────────────────────
        if (detail.sets.isNotEmpty) ...[
          const _SectionTitle(title: 'Sets'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8, runSpacing: 8,
              children: [
                for (final s in detail.sets) _SetChip(set: s),
              ],
            ),
          ),
        ],

        // ─── 10. History ─────────────────────────────────────────────
        const _SectionTitle(title: 'History'),
        _HistorySection(templateId: templateId),
        SizedBox(height: 32 + MediaQuery.viewPaddingOf(context).bottom),
      ],
    );
  }

  static int _ratingFor(CardRarity r) => switch (r) {
        CardRarity.COMMON => 75,
        CardRarity.UNCOMMON => 79,
        CardRarity.RARE => 84,
        CardRarity.EPIC => 88,
        CardRarity.LEGENDARY => 92,
        CardRarity.ICONIC => 95,
      };

  static String _shortEdition(String edition) {
    final dash = edition.indexOf('-');
    return dash < 0 ? edition : edition.substring(0, dash);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BUY WITH GEMS — lets any priced card be bought straight from its detail page
// ─────────────────────────────────────────────────────────────────────────────

class _BuyCardButton extends ConsumerStatefulWidget {
  const _BuyCardButton({
    required this.templateId,
    required this.gemPrice,
    required this.playerName,
    required this.soldOut,
  });
  final String templateId;
  final int gemPrice;
  final String? playerName;
  final bool soldOut;
  @override
  ConsumerState<_BuyCardButton> createState() => _BuyCardButtonState();
}

class _BuyCardButtonState extends ConsumerState<_BuyCardButton> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    if (widget.soldOut) {
      return const GoldButton(label: 'Sold out', expand: true, onPressed: null);
    }
    return GoldButton(
      label: _busy ? '…' : 'Buy with gems · ${widget.gemPrice}',
      icon: Icons.diamond_outlined,
      expand: true,
      onPressed: _busy ? null : _buy,
    );
  }

  Future<void> _buy() async {
    // Gate anonymous users into a real account before spending gems.
    final existing = ref.read(authRepositoryProvider).currentUser;
    if (existing == null || existing.isAnonymous) {
      final user = await quickSignIn(context, ref);
      if (user == null || !mounted) return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface2,
        title: Text('Buy ${widget.playerName ?? 'this card'}?',
            style: const TextStyle(color: AppColors.fg, fontSize: 17, fontWeight: FontWeight.w800)),
        content: Text('${widget.gemPrice} gems.',
            style: const TextStyle(color: AppColors.fgSoft, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Buy', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final card = await ref.read(albumRepositoryProvider).purchaseTemplate(widget.templateId);
      // Refresh balance, this card's detail (supply/ownership) + the album.
      ref.invalidate(gemBalanceProvider);
      ref.invalidate(albumProvider);
      ref.invalidate(storeFeaturedProvider);
      ref.invalidate(marketTemplateProvider(widget.templateId));
      if (!mounted) return;
      await Navigator.of(context, rootNavigator: true).push<bool>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => CardRewardRevealScreen(
            card: card,
            eyebrow: 'Purchased',
            title: 'A new card for\nyour collection.',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(gemPurchaseErrorMessage(e)),
            backgroundColor: AppColors.surface3,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION HEADERS
// ─────────────────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
      child: Text(
        title,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.36,
          color: AppColors.fg,
        ),
      ),
    );
  }
}

class _SubTitle extends StatelessWidget {
  const _SubTitle({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
      child: Text(
        title,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 15,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
          color: AppColors.fgSoft,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SCORE + LEVEL BLOCK — Sorare hex + XP bar under the hero card
// ─────────────────────────────────────────────────────────────────────────────

class _ScoreLevelBlock extends StatelessWidget {
  const _ScoreLevelBlock({required this.card, this.form});
  final MarketCard card;
  final MarketFormStats? form;

  @override
  Widget build(BuildContext context) {
    final hasScore = form != null && form!.last5.n > 0;
    final bonus = card.bonusPct;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (hasScore) ...[
          ScoreHexBadge(score: form!.last5.avg, size: 36),
          const SizedBox(width: 8),
        ],
        if (bonus > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.muted2.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.borderSoft),
            ),
            child: Text(
              '+$bonus%',
              style: const TextStyle(
                fontFamily: 'JetBrainsMono',
                fontFamilyFallback: ['SF Mono', 'Menlo', 'monospace'],
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.muted,
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NAME BLOCK
// ─────────────────────────────────────────────────────────────────────────────

class _NameBlock extends StatelessWidget {
  const _NameBlock({required this.detail});
  final MarketTemplateDetail detail;
  @override
  Widget build(BuildContext context) {
    final p = detail.player;
    final t = p?.team;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Eyebrow(
            '${rarityLabel(detail.template.rarity)} · ${detail.template.edition}',
            gold: true,
            size: 10,
          ),
          const SizedBox(height: 4),
          Text(
            p?.name ?? 'Untitled card',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.48,
              color: AppColors.fg,
            ),
          ),
          if (t != null) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (t.crestUrl != null) ...[
                  SizedBox(
                    width: 18, height: 18,
                    child: PremiumImage(url: t.crestUrl!, fit: BoxFit.contain),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  t.name,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CARD DETAILS TABLE — Sorare-style key-value rows
// ─────────────────────────────────────────────────────────────────────────────

class _CardDetailsTable extends StatelessWidget {
  const _CardDetailsTable({required this.detail});
  final MarketTemplateDetail detail;

  @override
  Widget build(BuildContext context) {
    final p = detail.player;
    final t = p?.team;
    final card = detail.template;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.r4),
        border: Border.all(color: AppColors.borderSoft),
        color: AppColors.surface2,
      ),
      child: Column(
        children: [
          if (t != null) _DetailRow(
            label: 'Team',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (t.crestUrl != null) ...[
                  SizedBox(
                    width: 20, height: 20,
                    child: PremiumImage(url: t.crestUrl!, fit: BoxFit.contain),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  t.name,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.fg,
                  ),
                ),
              ],
            ),
          ),
          if (p?.position != null)
            _DetailRow(label: 'Position', value: _formatPosition(p!.position!)),
          if (p?.country != null)
            _DetailRow(label: 'Country', value: p!.country!),
          _DetailRow(
            label: 'Rarity',
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _rarityColor(card.rarity).withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _rarityColor(card.rarity).withValues(alpha: 0.4)),
              ),
              child: Text(
                rarityLabel(card.rarity),
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: _rarityColor(card.rarity),
                ),
              ),
            ),
          ),
          _DetailRow(label: 'Edition', value: card.edition),
          _DetailRow(label: 'Supply', value: '${card.totalSupply}'),
          if (card.gemPrice != null)
            _DetailRow(
              label: 'Price',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.diamond_outlined, size: 14, color: AppColors.gold),
                  const SizedBox(width: 4),
                  Text(
                    '${card.gemPrice}',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.gold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static Color _rarityColor(CardRarity r) => switch (r) {
        CardRarity.COMMON    => AppColors.rCommon,
        CardRarity.UNCOMMON  => AppColors.rCommon,
        CardRarity.RARE      => AppColors.rRare,
        CardRarity.EPIC      => AppColors.rEpic,
        CardRarity.LEGENDARY => AppColors.rLegendary,
        CardRarity.ICONIC    => AppColors.rIconicA,
      };

  static String _formatPosition(String p) => switch (p) {
        'GK' => 'Goalkeeper',
        'DF' => 'Defender',
        'MF' => 'Midfielder',
        'FW' => 'Forward',
        _ => p,
      };
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, this.value, this.trailing});
  final String label;
  final String? value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: AppColors.muted,
            ),
          ),
          const Spacer(),
          if (trailing != null)
            trailing!
          else
            Text(
              value ?? '—',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.fg,
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SUPPLY HERO
// ─────────────────────────────────────────────────────────────────────────────

class _SupplyHero extends StatelessWidget {
  const _SupplyHero({required this.stats});
  final MarketTemplateStats stats;
  @override
  Widget build(BuildContext context) {
    final pct = stats.totalSupply == 0
        ? 0.0
        : (stats.mintedCount / stats.totalSupply).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.r4),
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1815), Color(0xFF100E0C)],
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
        ),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                '${stats.mintedCount}',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.12,
                  color: AppColors.gold,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  ' / ${stats.totalSupply} minted',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.muted,
                  ),
                ),
              ),
              const Spacer(),
              if (stats.remaining > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.pitch.withValues(alpha: 0.15),
                    border: Border.all(color: AppColors.pitchGlow),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '${stats.remaining} LEFT',
                    style: const TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontFamilyFallback: ['SF Mono', 'Menlo', 'monospace'],
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.pitch,
                      letterSpacing: 1.0,
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.live.withValues(alpha: 0.15),
                    border: Border.all(color: AppColors.live),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: const Text(
                    'SOLD OUT',
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontFamilyFallback: ['SF Mono', 'Menlo', 'monospace'],
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.live,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: SizedBox(
              height: 6,
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
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STATS GRID
// ─────────────────────────────────────────────────────────────────────────────

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});
  final MarketTemplateStats stats;
  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat.yMMMd();
    final low = stats.lowestSerial == null ? '—' : '#${stats.lowestSerial}';
    final high = stats.highestSerial == null ? '—' : '#${stats.highestSerial}';
    final first = stats.firstMintedAt == null ? '—' : fmt.format(stats.firstMintedAt!.toLocal());
    final last = stats.lastMintedAt == null ? '—' : fmt.format(stats.lastMintedAt!.toLocal());

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.r4),
        border: Border.all(color: AppColors.borderSoft),
        color: AppColors.surface2,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _StatTile(label: 'Owners', value: '${stats.uniqueOwners}')),
              _StatVRule(),
              Expanded(child: _StatTile(label: 'Remaining', value: '${stats.remaining}')),
              _StatVRule(),
              Expanded(child: _StatTile(label: 'You own', value: '${stats.ownedByMe}', gold: stats.ownedByMe > 0)),
            ],
          ),
          Container(height: 1, color: AppColors.borderSoft),
          Row(
            children: [
              Expanded(child: _StatTile(label: 'Lowest serial', value: low)),
              _StatVRule(),
              Expanded(child: _StatTile(label: 'Highest serial', value: high)),
            ],
          ),
          Container(height: 1, color: AppColors.borderSoft),
          Row(
            children: [
              Expanded(child: _StatTile(label: 'First minted', value: first)),
              _StatVRule(),
              Expanded(child: _StatTile(label: 'Last minted', value: last)),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatVRule extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 36, color: AppColors.borderSoft);
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, this.gold = false});
  final String label;
  final String value;
  final bool gold;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
              color: gold ? AppColors.gold : AppColors.fg,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 4),
          Eyebrow(label, size: 9),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MY COPIES
// ─────────────────────────────────────────────────────────────────────────────

class _MyCopiesList extends StatelessWidget {
  const _MyCopiesList({required this.copies, required this.total});
  final List<MarketOwnedCopy> copies;
  final int total;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.r3),
        border: Border.all(color: AppColors.borderSoft),
        color: AppColors.surface2,
      ),
      child: Column(
        children: [
          for (int i = 0; i < copies.length; i++) ...[
            if (i > 0) Container(height: 1, color: AppColors.borderSoft),
            _CopyRow(copy: copies[i], total: total),
          ],
        ],
      ),
    );
  }
}

class _CopyRow extends StatelessWidget {
  const _CopyRow({required this.copy, required this.total});
  final MarketOwnedCopy copy;
  final int total;
  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat.yMMMd();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.16),
              border: Border.all(color: AppColors.goldHairline),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '#${copy.serialNumber} / $total',
              style: const TextStyle(
                fontFamily: 'JetBrainsMono',
                fontFamilyFallback: ['SF Mono', 'Menlo', 'monospace'],
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.gold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _prettySource(copy.acquiredVia),
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.fg,
                  ),
                ),
                Text(
                  fmt.format(copy.mintedAt.toLocal()),
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    color: AppColors.muted,
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

// ─────────────────────────────────────────────────────────────────────────────
// SETS
// ─────────────────────────────────────────────────────────────────────────────

class _SetChip extends StatelessWidget {
  const _SetChip({required this.set});
  final MarketSetRef set;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        border: Border.all(color: AppColors.borderSoft),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.collections_bookmark_outlined, size: 14, color: AppColors.gold),
          const SizedBox(width: 6),
          Text(
            set.name,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.fg,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HISTORY
// ─────────────────────────────────────────────────────────────────────────────

class _HistorySection extends ConsumerWidget {
  const _HistorySection({required this.templateId});
  final String templateId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(marketHistoryProvider(templateId));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: async.when(
        loading: () => const _HistorySkeleton(),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(12),
          child: Text('$e', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
        ),
        data: (page) {
          if (page.events.isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'No history yet — this card hasn\'t been minted.',
                style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.45),
              ),
            );
          }
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.r4),
              color: AppColors.surface2,
              border: Border.all(color: AppColors.borderSoft),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Column(
              children: [
                for (int i = 0; i < page.events.length; i++)
                  _HistoryRow(event: page.events[i], isLast: i == page.events.length - 1),
                if (page.nextCursor != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: GhostButton(
                      label: 'Load more',
                      onPressed: () => ref.invalidate(marketHistoryProvider(templateId)),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.event, required this.isLast});
  final MarketHistoryEvent event;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final isMint = event.type == MarketEventType.mint;
    final color = isMint ? AppColors.gold : AppColors.info;
    final icon = isMint ? Icons.auto_awesome : Icons.swap_horiz;
    final fmt = DateFormat.yMMMd().add_jm();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 26, height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.18),
                  border: Border.all(color: color.withValues(alpha: 0.6)),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 14, color: color),
              ),
              if (!isLast)
                Container(
                  width: 1, height: 28,
                  color: AppColors.borderSoft,
                  margin: const EdgeInsets.only(top: 4),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Eyebrow(isMint ? 'Mint' : 'Trade', gold: isMint, size: 9),
                    const Spacer(),
                    Text(
                      _relative(event.at),
                      style: const TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontFamilyFallback: ['SF Mono', 'Menlo', 'monospace'],
                        fontSize: 10,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                _eventBody(),
                const SizedBox(height: 4),
                Text(
                  fmt.format(event.at.toLocal()),
                  style: const TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontFamilyFallback: ['SF Mono', 'Menlo', 'monospace'],
                    fontSize: 10,
                    color: AppColors.muted2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _eventBody() {
    if (event.type == MarketEventType.mint) {
      final serial = event.serialNumber ?? 0;
      final actor = event.actor?.handle ?? 'Unknown';
      final source = _prettySource(event.acquiredVia ?? '');
      return RichText(
        text: TextSpan(
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            color: AppColors.fg,
            height: 1.4,
          ),
          children: [
            TextSpan(
              text: '#$serial',
              style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.gold),
            ),
            const TextSpan(text: ' minted'),
            if (source != '—') ...[
              const TextSpan(text: ' via '),
              TextSpan(text: source, style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
            const TextSpan(text: ' → '),
            TextSpan(text: actor, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.fg)),
          ],
        ),
      );
    }
    final from = event.fromUser?.handle ?? '?';
    final to = event.toUser?.handle ?? '?';
    final serials = event.serialNumbers ?? const [];
    final serialLabel = serials.isEmpty
        ? '—'
        : (serials.length == 1 ? '#${serials.first}' : serials.map((s) => '#$s').join(', '));
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          color: AppColors.fg,
          height: 1.4,
        ),
        children: [
          TextSpan(text: serialLabel, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.info)),
          const TextSpan(text: ' traded '),
          TextSpan(text: from, style: const TextStyle(fontWeight: FontWeight.w700)),
          const TextSpan(text: ' → '),
          TextSpan(text: to, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// UTILITIES
// ─────────────────────────────────────────────────────────────────────────────

String _prettySource(String s) {
  switch (s) {
    case 'SIGNUP_GIFT':       return 'Signup gift';
    case 'DAILY_LOGIN':       return 'Daily login';
    case 'PREDICTION_REWARD': return 'Prediction reward';
    case 'ACHIEVEMENT':       return 'Achievement';
    case 'REWARDED_AD':       return 'Rewarded ad';
    case 'SET_COMPLETION':    return 'Set completion';
    case 'TRADE':             return 'Trade';
    case 'DIRECT_PURCHASE':   return 'Direct purchase';
    case 'ADMIN_GRANT':       return 'Admin grant';
    default:                  return s.isEmpty ? '—' : s;
  }
}

String _relative(DateTime at) {
  final diff = DateTime.now().difference(at);
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours   < 24) return '${diff.inHours}h ago';
  if (diff.inDays    < 7)  return '${diff.inDays}d ago';
  if (diff.inDays    < 30) return '${(diff.inDays / 7).floor()}w ago';
  if (diff.inDays    < 365) return '${(diff.inDays / 30).floor()}mo ago';
  return '${(diff.inDays / 365).floor()}y ago';
}

// ─────────────────────────────────────────────────────────────────────────────
// SKELETONS
// ─────────────────────────────────────────────────────────────────────────────

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          Center(child: Skeleton(height: 340, width: 240, radius: 16)),
          SizedBox(height: 14),
          Skeleton(height: 36, radius: 8),
          SizedBox(height: 16),
          Skeleton(height: 60, radius: 12),
          SizedBox(height: 16),
          Skeleton(height: 100, radius: 16),
          SizedBox(height: 16),
          Skeleton(height: 160, radius: 16),
          SizedBox(height: 16),
          Skeleton(height: 90, radius: 16),
        ],
      ),
    );
  }
}

class _HistorySkeleton extends StatelessWidget {
  const _HistorySkeleton();
  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Skeleton(height: 56, radius: 12),
        SizedBox(height: 8),
        Skeleton(height: 56, radius: 12),
        SizedBox(height: 8),
        Skeleton(height: 56, radius: 12),
      ],
    );
  }
}
