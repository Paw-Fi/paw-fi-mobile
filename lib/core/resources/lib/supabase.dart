import 'package:supabase_flutter/supabase_flutter.dart';

// Use a getter to avoid accessing Supabase.instance before initialization.
// This prevents crashes caused by top-level initialization order when
// dotenv has not yet been loaded and Supabase.initialize not called.
SupabaseClient get supabase => Supabase.instance.client;
