import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/entry.dart';

abstract class EntriesRepository {
  /// Saves a new entry. `private == true` keeps it fully private
  /// (`visibility=private`, `moderation_status=private`). `private == false`
  /// stages it for sharing (`visibility=shared`, `moderation_status=pending`);
  /// the caller must then run the moderation gate to make it poolable.
  Future<Entry> saveDraft({required String body, required bool private});
  Future<List<Entry>> myEntries({String? search});
  Future<void> updateBody(String id, String body);

  /// Author soft-delete: marks the entry `removed` so it stops being served.
  Future<void> softDelete(String id);
}

class SupabaseEntriesRepository implements EntriesRepository {
  SupabaseEntriesRepository(this._client);
  final SupabaseClient _client;

  String get _uid => _client.auth.currentUser!.id;

  @override
  Future<Entry> saveDraft({
    required String body,
    required bool private,
  }) async {
    final payload = {
      'author_id': _uid,
      'body': body,
      'visibility': private ? 'private' : 'shared',
      'moderation_status': private ? 'private' : 'pending',
      // is_shareable intentionally omitted; RLS forces it false on insert.
    };
    final row =
        await _client.from('entries').insert(payload).select().single();
    return Entry.fromJson(row);
  }

  @override
  Future<List<Entry>> myEntries({String? search}) async {
    var query = _client
        .from('entries')
        .select()
        .eq('author_id', _uid)
        .neq('moderation_status', 'removed');
    if (search != null && search.trim().isNotEmpty) {
      query = query.ilike('body', '%${search.trim()}%');
    }
    final rows = await query.order('created_at', ascending: false);
    return (rows as List)
        .map((r) => Entry.fromJson((r as Map).cast<String, dynamic>()))
        .toList();
  }

  @override
  Future<void> updateBody(String id, String body) async {
    // RLS + trigger permit body edits only on own, non-poolable entries.
    await _client
        .from('entries')
        .update({'body': body}).eq('id', id).eq('author_id', _uid);
  }

  @override
  Future<void> softDelete(String id) async {
    await _client
        .from('entries')
        .update({'moderation_status': 'removed'})
        .eq('id', id)
        .eq('author_id', _uid);
  }
}
