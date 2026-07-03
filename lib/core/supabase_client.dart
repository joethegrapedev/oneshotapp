import 'package:supabase_flutter/supabase_flutter.dart';

/// Convenience accessor for the initialized Supabase client.
///
/// `Supabase.initialize(...)` is called once in `main.dart`; everything else
/// reaches the client through this getter so tests can inject a fake by
/// overriding the Riverpod provider that wraps it.
SupabaseClient get supabase => Supabase.instance.client;
