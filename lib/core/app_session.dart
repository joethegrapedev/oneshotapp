import 'package:flutter/foundation.dart';

import '../data/auth_repository.dart';
import '../data/profile_repository.dart';
import '../models/profile.dart';
import '../services/purchases_service.dart';

/// Central gating state used by the router's redirect logic.
///
/// Tracks three gates in order: signed in → onboarded (18+ & ToS) → entitled
/// (paywall). It is a [ChangeNotifier] so GoRouter can use it as a
/// `refreshListenable`; flows call [refresh] after they change state.
class AppSession extends ChangeNotifier {
  AppSession({
    required AuthRepository auth,
    required ProfileRepository profiles,
    required PurchasesService purchases,
  })  : _auth = auth,
        _profiles = profiles,
        _purchases = purchases;

  final AuthRepository _auth;
  final ProfileRepository _profiles;
  final PurchasesService _purchases;

  bool _bootstrapped = false;
  bool _signedIn = false;
  bool _onboarded = false;
  bool _entitled = false;
  Profile? _profile;

  bool get bootstrapped => _bootstrapped;
  bool get signedIn => _signedIn;
  bool get onboarded => _onboarded;
  bool get entitled => _entitled;
  Profile? get profile => _profile;

  /// Called once at startup: ensures an (anonymous) session and profile, then
  /// loads gate state.
  Future<void> bootstrap() async {
    await _auth.ensureSignedIn();
    await _purchases.configure();
    await refresh();
    _bootstrapped = true;
    notifyListeners();
  }

  /// Reloads profile + entitlement and notifies listeners (router re-evaluates).
  Future<void> refresh() async {
    _signedIn = _auth.currentSession != null;
    if (_signedIn) {
      try {
        _profile = await _profiles.ensureProfile();
        _onboarded = _profile?.isOnboarded ?? false;
      } catch (_) {
        _onboarded = false;
      }
      _entitled = await _purchases.isEntitled;
    } else {
      _onboarded = false;
      _entitled = false;
      _profile = null;
    }
    notifyListeners();
  }
}
