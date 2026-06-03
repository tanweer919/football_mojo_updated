import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/ads/admob_service.dart';
import '../../../../core/config/remote_app_config.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../iap/data/iap_service.dart';
import '../../../profile/data/profile_repository.dart' show myProfileProvider;
import '../../data/repositories/album_repository.dart';
import '../screens/card_reward_reveal_screen.dart';

/// "Watch a short ad → free card" entry point. Opt-in (the most
/// user-friendly ad format) and a strong revenue driver. Lives on the
/// collection and wallet screens. Hidden entirely when ads are remotely
/// disabled or the user has PITCH Pro.
class FreeCardCta extends ConsumerStatefulWidget {
  const FreeCardCta({super.key});
  @override
  ConsumerState<FreeCardCta> createState() => _FreeCardCtaState();
}

class _FreeCardCtaState extends ConsumerState<FreeCardCta> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final adsEnabled = ref.watch(adsEnabledProvider);
    final isPro = ref.watch(isProActiveProvider);
    if (!adsEnabled || isPro) return const SizedBox.shrink();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _busy ? null : _watchForCard,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.r4),
          border: Border.all(color: AppColors.goldHairline),
          gradient: const LinearGradient(
            colors: [Color(0xFF221C14), Color(0xFF12100D)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.gold.withValues(alpha: 0.16),
                border: Border.all(color: AppColors.goldHairline),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.card_giftcard, color: AppColors.gold, size: 20),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Free card',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.fg,
                      letterSpacing: -0.2,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Watch a short ad to add a card to your collection',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: AppColors.muted,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (_busy)
              const SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.gold,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.play_arrow_rounded, size: 16, color: Color(0xFF1E1810)),
                    SizedBox(width: 2),
                    Text(
                      'Watch',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E1810),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _watchForCard() {
    setState(() => _busy = true);
    var earned = false;
    AdmobService.instance.showRewarded(
      onReward: (_) {
        earned = true;
        _claimCard();
      },
      onNotReady: () {
        if (!mounted) return;
        setState(() => _busy = false);
        _toast('Ad not ready yet — try again in a moment.');
      },
      onDismissed: () {
        // Reward is handled in onReward (fires first). If they closed early
        // without earning, just release the button.
        if (!mounted) return;
        if (!earned) setState(() => _busy = false);
      },
    );
  }

  Future<void> _claimCard() async {
    try {
      // ssvToken is the AdMob server-side-verification callback; the client
      // doesn't carry it, so we pass empty (SSV is enforced server-side only
      // when ADMOB_SSV_ENABLED).
      final card = await ref.read(albumRepositoryProvider).claimRewardedAd('');
      ref.invalidate(albumProvider);
      ref.invalidate(myProfileProvider);
      if (!mounted) return;
      setState(() => _busy = false);
      // Celebrate with the reward reveal, then optionally open the card.
      // rootNavigator: true so it covers the tab bar — this CTA lives on
      // shell screens (wallet/album), whose navigator sits BEHIND the
      // floating tabbar; a non-root push would leave the tabbar on top.
      final view = await Navigator.of(context, rootNavigator: true).push<bool>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => CardRewardRevealScreen(card: card),
        ),
      );
      if (view == true && mounted) context.push('/album/${card.id}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      final msg = '$e';
      if (msg.contains('daily_cap')) {
        _toast("That's all the free cards for today — come back tomorrow!");
      } else if (msg.contains('album_complete')) {
        _toast('You already own every card in this tier — nice!');
      } else {
        _toast('Could not grant your card. Please try again.');
      }
    }
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }
}
