import 'package:purchases_flutter/purchases_flutter.dart';

import 'purchases_service.dart';

/// DEV-ONLY [PurchasesService] that reports the user as always entitled so the
/// paywall is skipped during local runs. It performs no billing work and never
/// touches RevenueCat. Selected only when [Env.devForceEntitled] is set AND the
/// build is not a release build (see `purchasesServiceProvider`).
class DevEntitledPurchasesService implements PurchasesService {
  @override
  Future<void> configure() async {}

  @override
  Future<bool> get isEntitled async => true;

  @override
  Future<Offerings?> offerings() async => null;

  @override
  Future<bool> purchase(Package package) async => true;

  @override
  Future<bool> restore() async => true;
}
