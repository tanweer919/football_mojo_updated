import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/auth_repository.dart';
import '../../../../core/auth/sign_in_sheet.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/widgets/eyebrow.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/pitch_buttons.dart';
import '../../../../core/widgets/pitch_scaffold.dart';
import '../../../../core/widgets/premium_image.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../album/data/models/card_models.dart';
import '../../../album/data/repositories/album_repository.dart';
import '../../../album/presentation/screens/card_reward_reveal_screen.dart';
import '../../../iap/data/gems_repository.dart';
import '../../../iap/presentation/widgets/gem_chip.dart';

/// Gem shop — the place gems become useful. Two halal-safe ways to spend:
///   1. Transparent bundles ("packs" whose exact contents are shown up front)
///   2. Single cards at a known gem price
/// Both reveal the freshly-minted card(s) with the celebratory animation.
/// No mystery packs / paid randomness — that promise is shown to the user.
class GemShopScreen extends ConsumerStatefulWidget {
  const GemShopScreen({super.key});
  @override
  ConsumerState<GemShopScreen> createState() => _GemShopScreenState();
}

class _GemShopScreenState extends ConsumerState<GemShopScreen> {
  /// IDs (bundle or template) with a purchase in flight — disables their CTA.
  final Set<String> _busy = {};

  @override
  Widget build(BuildContext context) {
    final bundles = ref.watch(cardBundlesProvider);
    final singles = ref.watch(storeFeaturedProvider);

    return PitchScreen(
      title: 'Shop',
      onBack: () => context.canPop() ? context.pop() : context.go(RoutePaths.market),
      trailing: const GemChip(),
      scrollable: false,
      bottomSafeArea: false,
      child: RefreshIndicator(
        color: AppColors.gold,
        backgroundColor: AppColors.surface,
        onRefresh: () async {
          ref.invalidate(cardBundlesProvider);
          ref.invalidate(storeFeaturedProvider);
          ref.invalidate(gemBalanceProvider);
          await Future.wait<dynamic>([
            ref.read(cardBundlesProvider.future),
            ref.read(storeFeaturedProvider.future),
          ]);
        },
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 4, 16, PitchScreen.bottomInset(context)),
          children: [
            const _ShopIntro(),
            const SizedBox(height: 18),
            const _SectionLabel('Bundles', 'Known contents · save vs buying singly'),
            const SizedBox(height: 10),
            bundles.when(
              loading: () => const SkeletonList(itemHeight: 150),
              error: (e, _) => ErrorView(
                message: '$e',
                onRetry: () => ref.invalidate(cardBundlesProvider),
              ),
              data: (list) => list.isEmpty
                  ? const _EmptyNote('No bundles available right now.')
                  : Column(
                      children: [
                        for (final b in list) ...[
                          _BundleCard(
                            bundle: b,
                            busy: _busy.contains(b.id),
                            onBuy: () => _buyBundle(b),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ],
                    ),
            ),
            const SizedBox(height: 14),
            const _SectionLabel('Single cards', 'Buy the exact card you want'),
            const SizedBox(height: 10),
            singles.when(
              loading: () => const SkeletonList(itemHeight: 84),
              error: (e, _) => ErrorView(
                message: '$e',
                onRetry: () => ref.invalidate(storeFeaturedProvider),
              ),
              data: (list) => list.isEmpty
                  ? const _EmptyNote('No cards for sale right now.')
                  : Column(
                      children: [
                        for (final t in list) ...[
                          _SingleCardRow(
                            template: t,
                            busy: _busy.contains(t.id),
                            onBuy: () => _buySingle(t),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Purchase flows ────────────────────────────────────────────────────

  /// Ensure a real (non-anonymous) account before spending gems — mirrors the
  /// lineup-save gate. Returns true when signed in.
  Future<bool> _ensureSignedIn() async {
    final existing = ref.read(authRepositoryProvider).currentUser;
    if (existing != null && !existing.isAnonymous) return true;
    final user = await quickSignIn(context, ref);
    return user != null;
  }

  Future<void> _buyBundle(CardBundleDto b) async {
    if (_busy.contains(b.id)) return;
    if (!await _ensureSignedIn() || !mounted) return;
    final ok = await _confirm(
      title: 'Buy “${b.name}”?',
      body: '${b.gemPrice} gems for ${b.cardCount} cards'
          '${b.saving > 0 ? ' · save ${b.saving}' : ''}.',
    );
    if (ok != true || !mounted) return;

    setState(() => _busy.add(b.id));
    try {
      final cards = await ref.read(albumRepositoryProvider).purchaseBundle(b.id);
      _invalidateAfterPurchase();
      if (mounted) await _revealCards(cards);
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _busy.remove(b.id));
    }
  }

  Future<void> _buySingle(StoreTemplate t) async {
    if (_busy.contains(t.id)) return;
    if (!await _ensureSignedIn() || !mounted) return;
    final ok = await _confirm(
      title: 'Buy ${t.playerName ?? 'this card'}?',
      body: '${t.gemPrice} gems.',
    );
    if (ok != true || !mounted) return;

    setState(() => _busy.add(t.id));
    try {
      final card = await ref.read(albumRepositoryProvider).purchaseTemplate(t.id);
      _invalidateAfterPurchase();
      if (mounted) await _revealCards([card]);
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _busy.remove(t.id));
    }
  }

  void _invalidateAfterPurchase() {
    ref.invalidate(gemBalanceProvider);
    ref.invalidate(albumProvider);
    ref.invalidate(cardBundlesProvider);
    ref.invalidate(storeFeaturedProvider);
  }

  /// Reveal each minted card with the celebratory animation, one after the
  /// next (the "card-by-card" bundle reveal).
  Future<void> _revealCards(List<OwnedCardDto> cards) async {
    for (var i = 0; i < cards.length; i++) {
      if (!mounted) return;
      await Navigator.of(context, rootNavigator: true).push<bool>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => CardRewardRevealScreen(
            card: cards[i],
            eyebrow: cards.length > 1 ? 'Card ${i + 1} of ${cards.length}' : 'Purchased',
            title: 'A new card for\nyour collection.',
          ),
        ),
      );
    }
  }

  Future<bool?> _confirm({required String title, required String body}) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface2,
        title: Text(title, style: const TextStyle(color: AppColors.fg, fontSize: 17, fontWeight: FontWeight.w800)),
        content: Text(body, style: const TextStyle(color: AppColors.fgSoft, fontSize: 14, height: 1.4)),
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
  }

  void _showError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(gemPurchaseErrorMessage(e)),
        backgroundColor: AppColors.surface3,
        duration: const Duration(seconds: 4),
      ),
    );
  }
}

// ─── Pieces ────────────────────────────────────────────────────────────────

class _ShopIntro extends StatelessWidget {
  const _ShopIntro();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.r4),
        border: Border.all(color: AppColors.goldHairline),
        gradient: const LinearGradient(
          colors: [Color(0xFF1F1814), Color(0xFF110C09)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
      ),
      child: const Row(
        children: [
          Icon(Icons.verified_outlined, size: 18, color: AppColors.gold),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Spend gems on cards you choose. Every bundle shows exactly what’s '
              'inside before you buy — no mystery packs.',
              style: TextStyle(fontFamily: 'Inter', fontSize: 12.5, color: AppColors.fgSoft, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.title, this.sub);
  final String title;
  final String sub;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontFamily: 'Inter', fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.3, color: AppColors.fg)),
        const SizedBox(height: 2),
        Eyebrow(sub, size: 10),
      ],
    );
  }
}

class _EmptyNote extends StatelessWidget {
  const _EmptyNote(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Text(text, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
      ),
    );
  }
}

Color _rarityColor(CardRarity r) => switch (r) {
      CardRarity.COMMON => const Color(0xFF8C8E91),
      CardRarity.UNCOMMON => const Color(0xFF4FB976),
      CardRarity.RARE => const Color(0xFF5BA9F7),
      CardRarity.EPIC => const Color(0xFFA268D5),
      CardRarity.LEGENDARY => AppColors.gold,
      CardRarity.ICONIC => const Color(0xFFD656B5),
    };

/// A small rarity-bordered thumbnail of a card's art, with an owned tick.
class _CardThumb extends StatelessWidget {
  const _CardThumb({required this.artUrl, required this.rarity, this.owned = false, this.width = 58});
  final String artUrl;
  final CardRarity rarity;
  final bool owned;
  final double width;
  @override
  Widget build(BuildContext context) {
    final c = _rarityColor(rarity);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: width,
          height: width * 1.4,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: c.withValues(alpha: 0.7), width: 1.5),
            color: AppColors.surface3,
          ),
          clipBehavior: Clip.antiAlias,
          child: PremiumImage(url: artUrl, fit: BoxFit.cover),
        ),
        if (owned)
          Positioned(
            top: -5, right: -5,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(color: AppColors.bgDeep, shape: BoxShape.circle),
              child: const Icon(Icons.check_circle, size: 14, color: AppColors.pitch),
            ),
          ),
      ],
    );
  }
}

class _GemPriceTag extends StatelessWidget {
  const _GemPriceTag(this.gems, {this.strike});
  final int gems;
  final int? strike;
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (strike != null && strike! > gems) ...[
          Text('$strike',
              style: const TextStyle(
                fontFamily: 'JetBrainsMono',
                fontFamilyFallback: ['SF Mono', 'Menlo', 'monospace'],
                fontSize: 11,
                color: AppColors.muted,
                decoration: TextDecoration.lineThrough,
              )),
          const SizedBox(width: 5),
        ],
        const Icon(Icons.diamond_outlined, size: 13, color: AppColors.gold),
        const SizedBox(width: 3),
        Text('$gems',
            style: const TextStyle(
              fontFamily: 'JetBrainsMono',
              fontFamilyFallback: ['SF Mono', 'Menlo', 'monospace'],
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.gold,
            )),
      ],
    );
  }
}

class _BundleCard extends StatelessWidget {
  const _BundleCard({required this.bundle, required this.busy, required this.onBuy});
  final CardBundleDto bundle;
  final bool busy;
  final VoidCallback onBuy;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.r4),
        border: Border.all(color: AppColors.borderSoft),
        color: AppColors.surface2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(bundle.name,
                        style: const TextStyle(
                            fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.fg)),
                    if (bundle.description != null) ...[
                      const SizedBox(height: 2),
                      Text(bundle.description!,
                          style: const TextStyle(fontFamily: 'Inter', fontSize: 11.5, color: AppColors.muted, height: 1.35)),
                    ],
                  ],
                ),
              ),
              if (bundle.saving > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.pitch.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: AppColors.pitch.withValues(alpha: 0.4)),
                  ),
                  child: Text('SAVE ${bundle.saving}',
                      style: const TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontFamilyFallback: ['SF Mono', 'Menlo', 'monospace'],
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: AppColors.pitch,
                        letterSpacing: 0.5,
                      )),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Exact contents — the transparency that keeps this halal.
          SizedBox(
            height: 58 * 1.4,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: bundle.cards.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final c = bundle.cards[i];
                return _CardThumb(artUrl: c.artUrl, rarity: c.rarity, owned: c.ownedByMe);
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _GemPriceTag(bundle.gemPrice, strike: bundle.singleTotal),
              const Spacer(),
              SizedBox(
                width: 116,
                child: GoldButton(
                  label: busy ? '…' : 'Buy bundle',
                  expand: true,
                  onPressed: busy ? null : onBuy,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SingleCardRow extends StatelessWidget {
  const _SingleCardRow({required this.template, required this.busy, required this.onBuy});
  final StoreTemplate template;
  final bool busy;
  final VoidCallback onBuy;
  @override
  Widget build(BuildContext context) {
    final soldOut = template.isSoldOut;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.r4),
        border: Border.all(color: AppColors.borderSoft),
        color: AppColors.surface2,
      ),
      child: Row(
        children: [
          _CardThumb(artUrl: template.artUrl, rarity: template.rarity, width: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(template.playerName ?? template.edition,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.fg)),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(template.rarity.name,
                        style: TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontFamilyFallback: const ['SF Mono', 'Menlo', 'monospace'],
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: _rarityColor(template.rarity),
                          letterSpacing: 0.6,
                        )),
                    if (template.teamName != null) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(template.teamName!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.muted)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 5),
                _GemPriceTag(template.gemPrice),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 84,
            child: GoldButton(
              label: soldOut ? 'Sold out' : (busy ? '…' : 'Buy'),
              expand: true,
              small: true,
              onPressed: (soldOut || busy) ? null : onBuy,
            ),
          ),
        ],
      ),
    );
  }
}
