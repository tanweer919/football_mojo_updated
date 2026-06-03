import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/ads/admob_service.dart';
import '../../../../core/config/remote_app_config.dart';
import '../../../../core/network/api_error.dart';
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

    final status = ref.watch(rewardedAdStatusProvider).valueOrNull;
    final remaining = status?.remaining;
    // Daily cap hit → don't let them watch an ad for nothing.
    final capReached = remaining != null && remaining <= 0;
    final subtitle = capReached
        ? 'Daily limit reached — come back tomorrow'
        : (remaining != null && status != null)
            ? 'Watch a short ad for a free card · $remaining of ${status.cap} left today'
            : 'Watch a short ad to add a card to your collection';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: (_busy || capReached) ? null : _watchForCard,
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
              child: Icon(
                capReached ? Icons.lock_clock_outlined : Icons.card_giftcard,
                color: AppColors.gold,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Free card',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.fg,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
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
            else if (capReached)
              // Spent for today — show the count, not a (useless) Watch button.
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surface3,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: AppColors.borderSoft),
                ),
                child: Text(
                  '${status!.cap}/${status.cap}',
                  style: const TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontFamilyFallback: ['SF Mono', 'Menlo', 'monospace'],
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.muted,
                  ),
                ),
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
      ref.invalidate(rewardedAdStatusProvider); // decrement remaining → CTA disables at the cap
      if (!mounted) return;
      setState(() => _busy = false);
      // Celebrate with the reward reveal, then optionally open the card.
      // rootNavigator: true + fullscreenDialog so it covers the floating tab
      // bar — this CTA lives on the album (shell) screen, whose navigator sits
      // BEHIND the tab bar; a non-root push leaves the tab bar painted on top.
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
      // Read the backend error CODE from the response body — DioException
      // .toString() omits it, which is why every failure used to collapse to
      // the generic "could not grant" message.
      final code = apiErrorCode(e);
      if (code.contains('daily_cap')) {
        _toast("That's all the free cards for today — come back tomorrow!");
      } else if (code.contains('album_complete')) {
        _toast('You already own every card in this tier — nice!');
      } else if (code.contains('drop')) {
        _toast('That card drop is closed right now. Try again later.');
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
