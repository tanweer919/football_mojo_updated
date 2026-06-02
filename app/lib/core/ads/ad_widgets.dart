import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/remote_app_config.dart';
import '../design/app_colors.dart';
import '../../features/iap/data/iap_service.dart';
import 'admob_service.dart';

/// Reusable banner ad widget that matches PITCH's dark theme.
///
/// Drop into any screen's column:
///   ```dart
///   const PitchBannerAd(),
///   ```
///
/// Renders nothing (and never even creates an ad) when the remote
/// `adsEnabled` flag is off or the user has PITCH Pro. Otherwise handles
/// loading, error, and disposal automatically, rendering as a
/// `SizedBox.shrink()` while loading or if the ad fails — zero layout
/// impact so the screen doesn't jump.
class PitchBannerAd extends ConsumerWidget {
  const PitchBannerAd({super.key, this.padding});
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adsEnabled = ref.watch(adsEnabledProvider);
    final isPro = ref.watch(isProActiveProvider);
    if (!adsEnabled || isPro) return const SizedBox.shrink();
    return _BannerBody(padding: padding);
  }
}

class _BannerBody extends StatefulWidget {
  const _BannerBody({this.padding});
  final EdgeInsetsGeometry? padding;

  @override
  State<_BannerBody> createState() => _BannerBodyState();
}

class _BannerBodyState extends State<_BannerBody> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _ad = AdmobService.instance.createBanner(
      onLoaded: () {
        if (mounted) setState(() => _loaded = true);
      },
      onFailed: (_) {
        if (mounted) setState(() => _loaded = false);
      },
    );
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _ad == null) return const SizedBox.shrink();
    final child = Container(
      height: _ad!.size.height.toDouble(),
      width: _ad!.size.width.toDouble(),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderSoft),
      ),
      clipBehavior: Clip.antiAlias,
      child: AdWidget(ad: _ad!),
    );
    if (widget.padding != null) {
      return Padding(padding: widget.padding!, child: child);
    }
    return child;
  }
}
