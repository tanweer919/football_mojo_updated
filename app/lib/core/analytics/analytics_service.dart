import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Firebase Analytics wrapper. Mirrors [ClarityService]'s shape: best-effort,
/// never throws, tolerant of Firebase not being initialised (dev without
/// google-services config).
///
/// Screen tracking is automatic via [observer] (registered on `GoRouter`),
/// which emits a `screen_view` from each route's `settings.name`. User identity
/// is wired from `authStateChanges` in the deferred bootstrap. The handful of
/// domain helpers below cover the highest-value funnels.
class AnalyticsService {
  FirebaseAnalytics get instance => FirebaseAnalytics.instance;

  /// Sends `screen_view` on navigation. Constructed lazily so it survives even
  /// if Firebase init is still in flight — the SDK queues calls.
  late final FirebaseAnalyticsObserver observer =
      FirebaseAnalyticsObserver(analytics: instance);

  /// Collection on in release, off in debug (keeps local runs out of the
  /// production property). Call once from the deferred bootstrap.
  Future<void> setEnabled(bool enabled) async {
    try {
      await instance.setAnalyticsCollectionEnabled(enabled);
    } catch (e) {
      if (kDebugMode) debugPrint('Analytics setEnabled failed: $e');
    }
  }

  Future<void> setUser({required String uid, String? email}) async {
    try {
      await instance.setUserId(id: uid);
      if (email != null) {
        // Domain only — never store the raw address (PII-minimal).
        final at = email.indexOf('@');
        if (at >= 0 && at < email.length - 1) {
          await instance.setUserProperty(
            name: 'email_domain',
            value: email.substring(at + 1),
          );
        }
      }
    } catch (_) {}
  }

  Future<void> clearUser() async {
    try {
      await instance.setUserId(id: null);
    } catch (_) {}
  }

  Future<void> logEvent(String name, [Map<String, Object>? parameters]) async {
    try {
      await instance.logEvent(name: name, parameters: parameters);
    } catch (e) {
      if (kDebugMode) debugPrint('Analytics logEvent($name) failed: $e');
    }
  }

  // --- High-value domain events ------------------------------------------

  Future<void> logLogin(String method) async {
    try {
      await instance.logLogin(loginMethod: method);
    } catch (_) {}
  }

  Future<void> logSignUp(String method) async {
    try {
      await instance.logSignUp(signUpMethod: method);
    } catch (_) {}
  }

  Future<void> logGemPurchase({
    required String productId,
    int? gems,
    num? value,
    String currency = 'INR',
  }) =>
      logEvent('gem_purchase', {
        'product_id': productId,
        if (gems != null) 'gems': gems,
        if (value != null) 'value': value,
        'currency': currency,
      });

  Future<void> logCardClaim({required String source, String? cardId}) =>
      logEvent('card_claim', {
        'source': source,
        if (cardId != null) 'card_id': cardId,
      });

  Future<void> logFantasySubmit({required String contestId}) =>
      logEvent('fantasy_submit', {'contest_id': contestId});
}

/// App-wide singleton. Defined here (not in the bootstrap) so any layer can log
/// events without importing the whole deferred-bootstrap dependency graph.
final analyticsService = AnalyticsService();
