import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/moderation_outcome.dart';

abstract class ModerationRepository {
  /// Submits a staged (`pending`) entry to the authoritative server gate.
  /// The edge function is the only thing that can promote an entry to poolable.
  Future<ModerationOutcome> submitForSharing(String entryId);
}

class SupabaseModerationRepository implements ModerationRepository {
  SupabaseModerationRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<ModerationOutcome> submitForSharing(String entryId) async {
    final res = await _client.functions.invoke(
      'moderate-and-pool',
      body: {'entry_id': entryId},
    );
    final data = res.data;
    if (data is Map) {
      return ModerationOutcome.fromJson(data.cast<String, dynamic>());
    }
    throw StateError('Unexpected moderation response: $data');
  }
}
