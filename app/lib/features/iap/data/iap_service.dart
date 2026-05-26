import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Halal-compliant IAP catalog. Three kinds of SKU only:
///   - Subscriptions:       pro_monthly, pro_yearly
///   - Defined consumables: gem packs of a known size
///   - Direct named items:  specific player cards (added at runtime)
/// We intentionally OMIT random/blind packs — only named or fixed-content
/// purchases are halal-safe.
class IapCatalog {
  static const proMonthly = 'fm_pro_monthly';
  static const proYearly  = 'fm_pro_yearly';
  static const gems500    = 'fm_gems_500';
  static const gems1200   = 'fm_gems_1200';
  static const gems3000   = 'fm_gems_3000';

  static const knownIds = <String>{
    proMonthly, proYearly, gems500, gems1200, gems3000,
  };
}

const _kProActiveKey = 'iap.pro.active';

/// Mutable Pro-entitlement flag. Server is authoritative; this local flag
/// keeps the UI snappy (e.g. hiding ads instantly after a successful purchase).
class ProEntitlementNotifier extends Notifier<bool> {
  @override
  bool build() {
    _hydrate();
    return false;
  }

  Future<void> _hydrate() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_kProActiveKey) ?? false;
  }

  Future<void> set(bool active) async {
    state = active;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kProActiveKey, active);
  }
}

final isProActiveProvider =
    NotifierProvider<ProEntitlementNotifier, bool>(ProEntitlementNotifier.new);

class IapService {
  IapService._(this._iap, this._onPurchase);

  final InAppPurchase _iap;
  final Future<void> Function(PurchaseDetails) _onPurchase;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  List<ProductDetails>? _cached;

  static Future<IapService> create({
    required Future<void> Function(PurchaseDetails) onPurchase,
  }) async {
    final svc = IapService._(InAppPurchase.instance, onPurchase);
    svc._sub = svc._iap.purchaseStream.listen((purchases) async {
      for (final p in purchases) {
        try { await svc._onPurchase(p); } catch (_) {}
        if (p.pendingCompletePurchase) await svc._iap.completePurchase(p);
      }
    });
    return svc;
  }

  Future<bool> isAvailable() => _iap.isAvailable();

  Future<List<ProductDetails>> products() async {
    if (_cached != null) return _cached!;
    final res = await _iap.queryProductDetails(IapCatalog.knownIds);
    if (res.notFoundIDs.isNotEmpty && kDebugMode) {
      debugPrint('IAP not found: ${res.notFoundIDs}');
    }
    return _cached = res.productDetails;
  }

  Future<void> purchaseSubscription(ProductDetails product) =>
      _iap.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: product));

  Future<void> purchaseConsumable(ProductDetails product) =>
      _iap.buyConsumable(purchaseParam: PurchaseParam(productDetails: product));

  Future<void> restorePurchases() => _iap.restorePurchases();

  void dispose() => _sub?.cancel();
}

/// Lazily-initialised IAP service. The callback flips the local Pro flag for
/// subscription SKUs. Gem packs need server-side verification + wallet credit;
/// that happens via a backend `/v1/iap/verify` call (not implemented in this
/// scaffold — wire up when the gem wallet UI lands).
final iapServiceProvider = FutureProvider<IapService>((ref) async {
  final svc = await IapService.create(
    onPurchase: (p) async {
      if (p.status != PurchaseStatus.purchased && p.status != PurchaseStatus.restored) return;
      if (p.productID == IapCatalog.proMonthly || p.productID == IapCatalog.proYearly) {
        await ref.read(isProActiveProvider.notifier).set(true);
      }
    },
  );
  ref.onDispose(svc.dispose);
  return svc;
});

final iapProductsProvider = FutureProvider<List<ProductDetails>>((ref) async {
  if (kIsWeb || !(Platform.isIOS || Platform.isAndroid)) return [];
  final svc = await ref.read(iapServiceProvider.future);
  if (!await svc.isAvailable()) return [];
  return svc.products();
});
