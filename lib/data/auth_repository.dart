import 'package:supabase_flutter/supabase_flutter.dart';

/// Anonymous-first auth. A user journals immediately as an anonymous auth user;
/// they may optionally link an email later for recovery across devices.
abstract class AuthRepository {
  Session? get currentSession;
  String? get currentUserId;
  Stream<AuthState> authStateChanges();
  Future<void> signInAnonymously();
  Future<void> ensureSignedIn();
  Future<void> linkEmail(String email);
  Future<void> signOut();
}

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);
  final SupabaseClient _client;

  GoTrueClient get _auth => _client.auth;

  @override
  Session? get currentSession => _auth.currentSession;

  @override
  String? get currentUserId => _auth.currentUser?.id;

  @override
  Stream<AuthState> authStateChanges() => _auth.onAuthStateChange;

  @override
  Future<void> signInAnonymously() async {
    await _auth.signInAnonymously();
  }

  @override
  Future<void> ensureSignedIn() async {
    if (_auth.currentSession == null) {
      await signInAnonymously();
    }
  }

  @override
  Future<void> linkEmail(String email) async {
    // Sends a magic link that, once confirmed, upgrades the anonymous user.
    await _auth.updateUser(UserAttributes(email: email));
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
