import 'package:clarity_flutter/clarity_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Microsoft Clarity session recording + heatmaps. Best-effort:
/// never throws, never blocks the UI thread.
///
/// Project id from `--dart-define=CLARITY_PROJECT_ID=...`. The route observer
/// is constructed eagerly so go_router can register it before init completes;
/// the SDK queues calls until `initialize()` succeeds.
class ClarityService {
  static const String _projectId = String.fromEnvironment(
    'CLARITY_PROJECT_ID',
    defaultValue: 'wqeqsghl60',
  );

  bool _initialized = false;
  bool get isInitialized => _initialized;

  late final ClarityRouteObserver routeObserver = ClarityRouteObserver(this);

  /// Must be called with a BuildContext after the widget tree is built.
  /// Defer via `addPostFrameCallback` from the first screen.
  bool initialize(BuildContext context) {
    if (_initialized) return true;
    if (_projectId.isEmpty) {
      debugPrint('Clarity: skipped (debug=$kDebugMode, projectId set=${_projectId.isNotEmpty})');
      return false;
    }
    try {
      final ok = Clarity.initialize(
        context,
        ClarityConfig(projectId: _projectId, logLevel: LogLevel.None),
      );
      _initialized = ok;
      if (ok) {
        Clarity.setOnSessionStartedCallback((sessionId) {
          debugPrint('Clarity session started: $sessionId');
        });
      }
      return ok;
    } catch (e) {
      debugPrint('Clarity init failed: $e');
      return false;
    }
  }

  void setUserIdentity({required String userId, String? customSessionId}) {
    if (!_initialized) return;
    try {
      Clarity.setCustomUserId(userId);
      Clarity.setCustomTag('UserId', userId);
      if (customSessionId != null) Clarity.setCustomSessionId(customSessionId);
    } catch (_) {}
  }

  /// On sign-out — segments the recording so the post-logout session isn't
  /// attributed to the previous user.
  void clearUserIdentity() {
    if (!_initialized) return;
    try {
      Clarity.startNewSession((_) {});
    } catch (_) {}
  }

  bool sendCustomEvent(String name) {
    if (!_initialized) return false;
    try { return Clarity.sendCustomEvent(name); } catch (_) { return false; }
  }

  bool setTag(String key, String value) {
    if (!_initialized) return false;
    try { return Clarity.setCustomTag(key, value); } catch (_) { return false; }
  }

  bool setCurrentScreen(String? name) {
    if (!_initialized) return false;
    try { return Clarity.setCurrentScreenName(name); } catch (_) { return false; }
  }

  String? getCurrentSessionUrl() {
    if (!_initialized) return null;
    try { return Clarity.getCurrentSessionUrl(); } catch (_) { return null; }
  }

  bool pause()  { try { return Clarity.pause();  } catch (_) { return false; } }
  bool resume() { try { return Clarity.resume(); } catch (_) { return false; } }
}

/// Route observer that names each Clarity "page" after the current go_router
/// route. Lightweight — only emits when the route name actually changes.
class ClarityRouteObserver extends RouteObserver<PageRoute<dynamic>> {
  // Kept as a positional param so call-sites match the documented pattern,
  // but unused — we call the Clarity SDK directly because the calls are
  // queued internally if init hasn't completed yet.
  ClarityRouteObserver(ClarityService _);
  String? _last;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _update(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _update(previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _update(newRoute);
  }

  void _update(Route<dynamic>? route) {
    final name = _extract(route);
    if (name == null || name == _last) return;
    _last = name;
    try {
      // Call the SDK directly so the screen name lands even if [_clarity]
      // hasn't finished initialising — the SDK queues these.
      Clarity.setCurrentScreenName(name);
    } catch (_) {}
  }

  String? _extract(Route<dynamic>? route) {
    final raw = route?.settings.name;
    if (raw == null || raw.isEmpty) return null;
    var s = raw.startsWith('/') ? raw.substring(1) : raw;
    if (s.isEmpty) return 'Home';
    // /matches/123 → Matches/123 ; /fantasy/wc2026-global-cup/builder → Fantasy/Wc2026GlobalCup/Builder
    return s.split('/').where((p) => p.isNotEmpty).map((p) {
      return p.split('-')
          .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
          .join();
    }).join('/');
  }
}
