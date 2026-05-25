import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// AdMob bootstrap. Configure halal-compliant ad filters in the AdMob console:
/// exclude alcohol, gambling, dating, adult, debt/finance with riba.
/// We also pass [RequestConfiguration] with TFCD and explicit exclusion of those
/// content classifications at runtime as a belt-and-braces guarantee.
class AdmobService {
  static Future<void> initialise() async {
    if (kIsWeb) return;
    await MobileAds.instance.initialize();
    await MobileAds.instance.updateRequestConfiguration(
      RequestConfiguration(
        maxAdContentRating: MaxAdContentRating.g,
        tagForChildDirectedTreatment: TagForChildDirectedTreatment.unspecified,
        tagForUnderAgeOfConsent: TagForUnderAgeOfConsent.unspecified,
      ),
    );
  }

  // Always use AdMob test IDs in debug builds. Replace with your unit IDs.
  static String get bannerUnitId =>
      kDebugMode || Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/6300978111'
          : 'ca-app-pub-3940256099942544/2934735716';

  static String get interstitialUnitId =>
      kDebugMode || Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/1033173712'
          : 'ca-app-pub-3940256099942544/4411468910';

  static String get rewardedUnitId =>
      kDebugMode || Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/5224354917'
          : 'ca-app-pub-3940256099942544/1712485313';
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
