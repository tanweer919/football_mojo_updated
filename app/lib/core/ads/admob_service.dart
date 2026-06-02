import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// AdMob bootstrap + ad-loading facade.
///
/// Ad strategy (good revenue, low annoyance):
///   - **Banner**: news feed, match details
///   - **Interstitial**: after every 3rd card-pack opening
///   - **Rewarded**: optional watch-to-earn bonus card drop
///
/// Configure halal-compliant ad filters in the AdMob console:
/// exclude alcohol, gambling, dating, adult, debt/finance with riba.
/// Runtime belt-and-braces via [RequestConfiguration].
class AdmobService {
  AdmobService._();
  static final instance = AdmobService._();

  bool _initialised = false;
  InterstitialAd? _interstitial;
  RewardedAd? _rewarded;

  /// Interstitial frequency cap — only show after every Nth trigger AND no
  /// more than once per [_interstitialCooldown]. Both guards apply, so a
  /// burst of triggers can never spam full-screen ads.
  int _interstitialTriggerCount = 0;
  static const _interstitialFrequency = 3;
  static const _interstitialCooldown = Duration(minutes: 4);
  DateTime? _lastInterstitialShownAt;

  // ── Ad Unit IDs ──────────────────────────────────────────────────────
  // Production IDs are injected at build time via --dart-define so the real
  // unit IDs never live in source control:
  //   flutter build appbundle \
  //     --dart-define=ADMOB_BANNER_ANDROID=ca-app-pub-XXXX/NNNN \
  //     --dart-define=ADMOB_INTERSTITIAL_ANDROID=... (etc, per platform)
  // In debug, OR whenever a prod ID isn't supplied, we fall back to Google's
  // official test units so debug clicks never risk the AdMob account.
  static const _testBannerAndroid = 'ca-app-pub-3940256099942544/6300978111';
  static const _testBannerIos = 'ca-app-pub-3940256099942544/2934735716';
  static const _testInterstitialAndroid = 'ca-app-pub-3940256099942544/1033173712';
  static const _testInterstitialIos = 'ca-app-pub-3940256099942544/4411468910';
  static const _testRewardedAndroid = 'ca-app-pub-3940256099942544/5224354917';
  static const _testRewardedIos = 'ca-app-pub-3940256099942544/1712485313';

  static const _prodBannerAndroid = String.fromEnvironment('ADMOB_BANNER_ANDROID');
  static const _prodBannerIos = String.fromEnvironment('ADMOB_BANNER_IOS');
  static const _prodInterstitialAndroid = String.fromEnvironment('ADMOB_INTERSTITIAL_ANDROID');
  static const _prodInterstitialIos = String.fromEnvironment('ADMOB_INTERSTITIAL_IOS');
  static const _prodRewardedAndroid = String.fromEnvironment('ADMOB_REWARDED_ANDROID');
  static const _prodRewardedIos = String.fromEnvironment('ADMOB_REWARDED_IOS');

  /// Returns the prod ID when supplied (release), else the test ID.
  static String _unit({
    required String prodAndroid,
    required String prodIos,
    required String testAndroid,
    required String testIos,
  }) {
    final isAndroid = Platform.isAndroid;
    if (!kDebugMode) {
      final prod = isAndroid ? prodAndroid : prodIos;
      if (prod.isNotEmpty) return prod;
    }
    return isAndroid ? testAndroid : testIos;
  }

  static String get bannerUnitId => _unit(
        prodAndroid: _prodBannerAndroid, prodIos: _prodBannerIos,
        testAndroid: _testBannerAndroid, testIos: _testBannerIos,
      );

  static String get interstitialUnitId => _unit(
        prodAndroid: _prodInterstitialAndroid, prodIos: _prodInterstitialIos,
        testAndroid: _testInterstitialAndroid, testIos: _testInterstitialIos,
      );

  static String get rewardedUnitId => _unit(
        prodAndroid: _prodRewardedAndroid, prodIos: _prodRewardedIos,
        testAndroid: _testRewardedAndroid, testIos: _testRewardedIos,
      );

  // ── Init ─────────────────────────────────────────────────────────────

  static Future<void> initialise() async {
    if (kIsWeb || instance._initialised) return;
    await MobileAds.instance.initialize();
    await MobileAds.instance.updateRequestConfiguration(
      RequestConfiguration(
        maxAdContentRating: MaxAdContentRating.g,
        tagForChildDirectedTreatment: TagForChildDirectedTreatment.unspecified,
        tagForUnderAgeOfConsent: TagForUnderAgeOfConsent.unspecified,
      ),
    );
    instance._initialised = true;
    debugPrint('✅ AdMob initialised');

    // Pre-cache interstitial + rewarded for snappy display.
    instance._loadInterstitial();
    instance._loadRewarded();
  }

  // ── Banner ───────────────────────────────────────────────────────────

  /// Creates a banner ad. Caller is responsible for calling `.dispose()`.
  BannerAd createBanner({
    AdSize size = AdSize.banner,
    void Function()? onLoaded,
    void Function(String error)? onFailed,
  }) {
    return BannerAd(
      adUnitId: bannerUnitId,
      size: size,
      request: const AdRequest(nonPersonalizedAds: true),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          debugPrint('✅ Banner loaded');
          onLoaded?.call();
        },
        onAdFailedToLoad: (ad, err) {
          debugPrint('❌ Banner failed: ${err.message}');
          ad.dispose();
          onFailed?.call(err.message);
        },
      ),
    )..load();
  }

  // ── Interstitial (frequency-capped) ──────────────────────────────────

  void _loadInterstitial() {
    InterstitialAd.load(
      adUnitId: interstitialUnitId,
      request: const AdRequest(nonPersonalizedAds: true),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitial = ad;
          debugPrint('✅ Interstitial cached');
        },
        onAdFailedToLoad: (err) {
          debugPrint('❌ Interstitial load failed: ${err.message}');
          _interstitial = null;
        },
      ),
    );
  }

  /// Trigger an interstitial. Only actually shows every [_interstitialFrequency]
  /// calls (e.g. every 3rd card-pack opening).
  void maybeShowInterstitial({VoidCallback? onDismissed}) {
    _interstitialTriggerCount++;
    if (_interstitialTriggerCount % _interstitialFrequency != 0) {
      onDismissed?.call();
      return;
    }
    // Time cooldown on top of the count cap — never two full-screen ads
    // within the cooldown window even if triggers come fast.
    final last = _lastInterstitialShownAt;
    if (last != null && DateTime.now().difference(last) < _interstitialCooldown) {
      onDismissed?.call();
      return;
    }
    final ad = _interstitial;
    if (ad == null) {
      debugPrint('⏩ Interstitial not ready, skipping');
      onDismissed?.call();
      _loadInterstitial();
      return;
    }
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitial = null;
        _loadInterstitial();
        onDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, err) {
        debugPrint('❌ Interstitial show failed: ${err.message}');
        ad.dispose();
        _interstitial = null;
        _loadInterstitial();
        onDismissed?.call();
      },
    );
    ad.show();
    _lastInterstitialShownAt = DateTime.now();
    _interstitial = null;
  }

  // ── Rewarded ─────────────────────────────────────────────────────────

  void _loadRewarded() {
    RewardedAd.load(
      adUnitId: rewardedUnitId,
      request: const AdRequest(nonPersonalizedAds: true),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewarded = ad;
          debugPrint('✅ Rewarded ad cached');
        },
        onAdFailedToLoad: (err) {
          debugPrint('❌ Rewarded load failed: ${err.message}');
          _rewarded = null;
        },
      ),
    );
  }

  /// Whether a rewarded ad is ready to show right now.
  bool get isRewardedReady => _rewarded != null;

  /// Shows a rewarded ad. [onReward] fires when the user earns the reward.
  void showRewarded({
    required void Function(int amount) onReward,
    VoidCallback? onDismissed,
    VoidCallback? onNotReady,
  }) {
    final ad = _rewarded;
    if (ad == null) {
      debugPrint('⏩ Rewarded not ready');
      onNotReady?.call();
      _loadRewarded();
      return;
    }
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewarded = null;
        _loadRewarded();
        onDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, err) {
        debugPrint('❌ Rewarded show failed: ${err.message}');
        ad.dispose();
        _rewarded = null;
        _loadRewarded();
        onDismissed?.call();
      },
    );
    ad.show(onUserEarnedReward: (_, reward) {
      onReward(reward.amount.toInt());
    });
    _rewarded = null;
  }
}

/// Stateless provider for a fresh BannerAd. Caller is responsible for [dispose].
final bannerAdProvider = Provider.autoDispose<BannerAd>((ref) {
  final ad = BannerAd(
    adUnitId: AdmobService.bannerUnitId,
    size: AdSize.banner,
    request: const AdRequest(nonPersonalizedAds: true),
    listener: const BannerAdListener(),
  )..load();
  ref.onDispose(ad.dispose);
  return ad;
});
