import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile.dart';

abstract class ProfileRepository {
  /// Idempotently creates + returns the caller's profile row.
  Future<Profile> ensureProfile();
  Future<Profile> current();
  Future<void> confirmAge();
  Future<void> acceptTos(String version);

  /// Purges the caller's poolable entries + personal data, then deletes the
  /// auth user via the `delete-account` edge function.
  Future<void> deleteAccount();
}

class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository(this._client);
  final SupabaseClient _client;

  String get _uid => _client.auth.currentUser!.id;

  @override
  Future<Profile> ensureProfile() async {
    // Upsert-on-conflict so first launch creates, later launches no-op.
    final existing = await _client
        .from('profiles')
        .select()
        .eq('id', _uid)
        .maybeSingle();
    if (existing != null) return Profile.fromJson(existing);

    final inserted = await _client
        .from('profiles')
        .insert({'id': _uid})
        .select()
        .single();
    return Profile.fromJson(inserted);
  }

  @override
  Future<Profile> current() async {
    final row =
        await _client.from('profiles').select().eq('id', _uid).single();
    return Profile.fromJson(row);
  }

  @override
  Future<void> confirmAge() async {
    await _client
        .from('profiles')
        .update({'age_confirmed': true}).eq('id', _uid);
  }

  @override
  Future<void> acceptTos(String version) async {
    await _client.from('profiles').update({
      'tos_accepted_at': DateTime.now().toUtc().toIso8601String(),
      'tos_version': version,
    }).eq('id', _uid);
  }

  @override
  Future<void> deleteAccount() async {
    // The edge function does the service-role purge + auth user deletion.
    await _client.functions.invoke('delete-account');
  }
}
