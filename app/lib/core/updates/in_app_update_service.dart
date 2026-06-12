import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';

/// Play Store In-App Update wrapper (Android only). The plugin renders its
/// OWN native UI for both flexible (download banner) and immediate (full-screen
/// blocking) flows — Flutter doesn't draw anything. We just decide which mode
/// to invoke based on the update's priority.
///
/// Update priority is set per-release in Play Developer Console / API
/// (0–5). We treat 5 as "critical, must update now"; anything below is flexible.
///
/// Fire-and-forget: never blocks the UI, never throws. Safe to call on every
/// app resume.
class InAppUpdateService {
  /// Treat updates published with `inAppUpdatePriority >= 5` as critical.
  /// Set this in the Play Developer API at release time.
  static const int _immediatePriority = 5;

  AppUpdateInfo? _lastInfo;
  AppUpdateInfo? get lastInfo => _lastInfo;

  // `check()` runs on every app resume. The native update UI is its own
  // activity, so dismissing it (or tapping Update) resumes our app and fires
  // check() again. Without these guards that re-launches the flow on a loop —
  // the dialog "reappears" and you have to tap Update several times.
  //   _running  — a check/flow is in flight; don't start a second one.
  //   _offered  — we've already surfaced the update prompt this session; don't
  //               nag again on every resume (Settings has a manual re-check,
  //               and truly-forced updates use the remote-config ForceGate).
  bool _running = false;
  bool _offered = false;

  Future<void> check() async {
    if (!Platform.isAndroid) return;
    if (kDebugMode) {
      debugPrint('InAppUpdate: skipping in debug mode');
      return;
    }
    if (_running) return;
    _running = true;
    try {
      _lastInfo = await InAppUpdate.checkForUpdate();
      final info = _lastInfo;
      if (info == null) return;

      switch (info.updateAvailability) {
        case UpdateAvailability.updateAvailable:
          if (_offered) return; // already prompted this session
          _offered = true;
          await _handle(info);
          break;
        case UpdateAvailability.developerTriggeredUpdateInProgress:
          // A previously-started flexible update finished downloading while
          // the app was backgrounded; complete it now.
          await _completeFlexible();
          break;
        case UpdateAvailability.updateNotAvailable:
        case UpdateAvailability.unknown:
          break;
      }
    } catch (e) {
      // Updates must never crash the app.
      debugPrint('InAppUpdate: check failed: $e');
    } finally {
      _running = false;
    }
  }

  Future<void> _handle(AppUpdateInfo info) async {
    final priority = info.updatePriority;
    if (priority >= _immediatePriority && info.immediateUpdateAllowed) {
      await _startImmediate();
      return;
    }
    if (info.flexibleUpdateAllowed) {
      await _startFlexible();
    }
  }

  Future<void> _startImmediate() async {
    try {
      await InAppUpdate.performImmediateUpdate();
    } catch (e) {
      debugPrint('InAppUpdate: immediate update failed: $e');
    }
  }

  Future<void> _startFlexible() async {
    try {
      await InAppUpdate.startFlexibleUpdate();
      await _completeFlexible();
    } catch (e) {
      debugPrint('InAppUpdate: flexible update failed: $e');
    }
  }

  Future<void> _completeFlexible() async {
    try {
      await InAppUpdate.completeFlexibleUpdate();
    } catch (e) {
      // Download may not be done yet — Play will complete on background.
      debugPrint('InAppUpdate: completeFlexible deferred: $e');
    }
  }

  /// Manual entry point — e.g. from a Settings "Check for updates" tile.
  /// User-initiated, so it bypasses the once-per-session limit, but still won't
  /// stack on top of an in-flight flow.
  Future<bool> checkAndPromptManually() async {
    if (!Platform.isAndroid || _running) return false;
    _running = true;
    try {
      _lastInfo = await InAppUpdate.checkForUpdate();
      if (_lastInfo?.updateAvailability == UpdateAvailability.updateAvailable) {
        _offered = true;
        await _handle(_lastInfo!);
        return true;
      }
    } catch (e) {
      debugPrint('InAppUpdate: manual check failed: $e');
    } finally {
      _running = false;
    }
    return false;
  }
}
