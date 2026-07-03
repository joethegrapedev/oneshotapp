import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/served_entry.dart';

abstract class PoolRepository {
  /// Serves one random cleared entry from a stranger, recording a match.
  /// Returns null on cold-start (nothing available for this reader).
  Future<ServedEntry?> serveOne();

  /// Reports a served entry: removes it from this reader's view and the pool,
  /// opens a `reports` row for 24h review.
  Future<void> report(String entryId, String reason);

  /// Blocks an author: their content is never served to this user again.
  Future<void> block(String authorId);
}

class SupabasePoolRepository implements PoolRepository {
  SupabasePoolRepository(this._client);
  final SupabaseClient _client;

  String get _uid => _client.auth.currentUser!.id;

  @override
  Future<ServedEntry?> serveOne() async {
    final data = await _client.rpc('serve_entry');
    if (data == null) return null;
    // The SECURITY DEFINER function returns a single row (or a 1-element set).
    final Map<String, dynamic> row;
    if (data is List) {
      if (data.isEmpty) return null;
      row = (data.first as Map).cast<String, dynamic>();
    } else if (data is Map) {
      row = data.cast<String, dynamic>();
    } else {
      return null;
    }
    if (row['id'] == null) return null;
    return ServedEntry.fromJson(row);
  }

  @override
  Future<void> report(String entryId, String reason) async {
    await _client.rpc(
      'apply_report',
      params: {
        'p_entry_id': entryId,
        'p_reason': reason,
      },
    );
  }

  @override
  Future<void> block(String authorId) async {
    await _client.from('blocks').upsert(
      {
        'blocker_id': _uid,
        'blocked_id': authorId,
      },
    );
  }
}
