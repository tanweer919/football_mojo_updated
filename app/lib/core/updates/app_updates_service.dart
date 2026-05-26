import 'dart:async';
import 'dart:io';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart' as shorebird;
import 'package:url_launcher/url_launcher.dart';

/// Cross-platform update layer that COMPLEMENTS (not replaces) Play Store's
/// in-app update API. Two responsibilities:
///
///   1. **Shorebird code push** — Dart-only patches. Downloads silently,
///      applies on next cold start. We surface a "patch ready" banner so the
///      user can choose to restart sooner.
///
///   2. **Firebase Remote Config version gate** — emergency hatch:
///        - If installed < `min_required_version_*` → blocking ForceUpdateGate
///        - On iOS (no native in-app update API) if installed <
///          `recommended_version_ios` → in-app banner with App Store CTA
///      Android "recommended" updates are handled by `InAppUpdateService`
///      (native Play banner), so we DON'T render anything for them.
///
/// Play Store in-app update (Android) lives in [InAppUpdateService] —
/// orchestrated together from deferred bootstrap.
class AppUpdatesService {
  AppUpdatesService._();

  static final _shorebird = shorebird.ShorebirdUpdater();
  static shorebird.ShorebirdUpdater get shorebirdUpdater => _shorebird;

  /// Reactive state for the [UpdateBanner] / [ForceUpdateGate] widgets.
  static final ValueNotifier<UpdateStatus> status =
      ValueNotifier(const UpdateStatus.idle());

  /// Called by the deferred bootstrap after the first frame, AND on every
  /// resume from background. Idempotent.
  static Future<void> checkAll() async {
    if (kDebugMode || kIsWeb) return;
    await Future.wait([
      _checkShorebirdPatch(),
      _checkVersionGate(),
    ]);
  }

  // ── Shorebird ──────────────────────────────────────────────────────────────

  static Future<void> _checkShorebirdPatch() async {
    if (!_shorebird.isAvailable) return;
    try {
      final patchStatus = await _shorebird.checkForUpdate();
      if (patchStatus == shorebird.UpdateStatus.outdated) {
        await _shorebird.update();
        if (status.value is! UpdateForceRequired) {
          status.value = const UpdateStatus.patchReady();
        }
      }
    } catch (e) {
      debugPrint('Shorebird patch check failed: $e');
    }
  }

  // ── Firebase Remote Config version gate ───────────────────────────────────

  static Future<void> _checkVersionGate() async {
    try {
      final rc = FirebaseRemoteConfig.instance;
      await rc.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 8),
        minimumFetchInterval: const Duration(minutes: 30),
      ));
      await rc.setDefaults(<String, dynamic>{
        'min_required_version_android': '',
        'min_required_version_ios': '',
        'recommended_version_ios': '',           // Android recommended handled by Play's native banner
        'force_update_message': 'Please update to continue using FootballMojo.',
      });
      await rc.fetchAndActivate();

      final installed = (await PackageInfo.fromPlatform()).version;
      final platformKey = Platform.isIOS ? 'ios' : 'android';
      final minRequired = rc.getString('min_required_version_$platformKey');

      if (minRequired.isNotEmpty && _compareSemver(installed, minRequired) < 0) {
        status.value = UpdateStatus.forceRequired(
          installed: installed,
          required: minRequired,
          message: rc.getString('force_update_message'),
        );
        return;
      }

      // iOS-only recommended banner. Android relies on Play's native UI.
      if (Platform.isIOS) {
        final recommended = rc.getString('recommended_version_ios');
        if (recommended.isNotEmpty && _compareSemver(installed, recommended) < 0) {
          if (status.value is UpdateIdle) {
            status.value = UpdateStatus.recommended(installed: installed, target: recommended);
          }
        }
      }
    } catch (e) {
      debugPrint('Remote Config version gate skipped: $e');
    }
  }

  /// Opens the store from the force-update / iOS recommended banner.
  static Future<void> openStore() async {
    final url = Platform.isIOS
        ? Uri.parse('https://apps.apple.com/app/idYOUR_APP_ID')    // TODO: replace
        : Uri.parse('market://details?id=com.footballmojo');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      await launchUrl(Uri.parse('https://play.google.com/store/apps/details?id=com.footballmojo'));
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sealed states surfaced to the UI.
// ─────────────────────────────────────────────────────────────────────────────

sealed class UpdateStatus {
  const UpdateStatus();
  const factory UpdateStatus.idle() = UpdateIdle;
  const factory UpdateStatus.patchReady() = UpdatePatchReady;
  const factory UpdateStatus.recommended({required String installed, required String target}) = UpdateRecommended;
  const factory UpdateStatus.forceRequired({
    required String installed,
    required String required,
    required String message,
  }) = UpdateForceRequired;
}

class UpdateIdle        extends UpdateStatus { const UpdateIdle(); }
class UpdatePatchReady  extends UpdateStatus { const UpdatePatchReady(); }
class UpdateRecommended extends UpdateStatus {
  const UpdateRecommended({required this.installed, required this.target});
  final String installed, target;
}
class UpdateForceRequired extends UpdateStatus {
  const UpdateForceRequired({required this.installed, required this.required, required this.message});
  final String installed, required, message;
}

int _compareSemver(String a, String b) {
  final aParts = a.split('-').first.split('.').map(int.tryParse).toList();
  final bParts = b.split('-').first.split('.').map(int.tryParse).toList();
  for (var i = 0; i < 3; i++) {
    final av = (i < aParts.length ? aParts[i] : 0) ?? 0;
    final bv = (i < bParts.length ? bParts[i] : 0) ?? 0;
    if (av != bv) return av - bv;
  }
  return 0;
}
