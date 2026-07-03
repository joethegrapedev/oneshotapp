import 'dart:io' show Platform;

import 'package:purchases_flutter/purchases_flutter.dart';

import '../core/env.dart';

/// RevenueCat wrapper. Configuration is driven from RevenueCat's dashboard
/// (offerings, prices, defaults) — nothing is hardcoded here except the
/// entitlement id. Prices localize to SGD automatically via Google Play /
/// StoreKit through RevenueCat's `StoreProduct.priceString`.
abstract class PurchasesService {
  Future<void> configure();
  Future<bool> get isEntitled;
  Future<Offerings?> offerings();
  Future<bool> purchase(Package package);
  Future<bool> restore();
}

class RevenueCatPurchasesService implements PurchasesService {
  bool _configured = false;

  String get _apiKey =>
      Platform.isIOS ? Env.revenueCatIosKey : Env.revenueCatAndroidKey;

  @override
  Future<void> configure() async {
    if (_configured) return;
    if (_apiKey.isEmpty) {
      // No key provided (e.g. tests / dev without billing). Leave unconfigured;
      // isEntitled will be false so the paywall still gates correctly.
      return;
    }
    await Purchases.setLogLevel(LogLevel.warn);
    await Purchases.configure(PurchasesConfiguration(_apiKey));
    _configured = true;
  }

  @override
  Future<bool> get isEntitled async {
    if (!_configured) return false;
    try {
      final info = await Purchases.getCustomerInfo();
      return info.entitlements.active.containsKey(Env.entitlementId);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<Offerings?> offerings() async {
    if (!_configured) return null;
    try {
      return await Purchases.getOfferings();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> purchase(Package package) async {
    if (!_configured) return false;
    try {
      final result = await Purchases.purchasePackage(package);
      return result.customerInfo.entitlements.active
          .containsKey(Env.entitlementId);
    } on PurchasesErrorCode {
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> restore() async {
    if (!_configured) return false;
    try {
      final info = await Purchases.restorePurchases();
      return info.entitlements.active.containsKey(Env.entitlementId);
    } catch (_) {
      return false;
    }
  }
}
