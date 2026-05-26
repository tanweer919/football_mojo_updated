import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../ads/admob_service.dart';

class InlineBannerAd extends ConsumerWidget {
  const InlineBannerAd({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (kIsWeb) return const SizedBox.shrink();
    final ad = ref.watch(bannerAdProvider);
    return SizedBox(
      height: AdSize.banner.height.toDouble(),
      width:  AdSize.banner.width.toDouble(),
      child: AdWidget(ad: ad),
    );
  }
}
