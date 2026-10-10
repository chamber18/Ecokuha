/// Supabase connection settings.
///
/// The URL and publishable (anon) key are safe to ship in the client: access is
/// enforced by Row Level Security. Override per environment with:
///   flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_PUBLISHABLE_KEY=...
class SupabaseConfig {
  SupabaseConfig._();

  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://wqrqbyayiivvxprzorrs.supabase.co',
  );

  static const String publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_LnGDwdYXRrIh6TeiZFEJEg_R4UX_3wr',
  );

  /// Storage buckets (see supabase/migrations/*_ecokuha_schema.sql).
  static const String profileImagesBucket = 'profile-images'; // {uid}/profile.jpg
  static const String postingImagesBucket = 'posting-images'; // {uid}/{file}
  static const String userUploadsBucket = 'user-uploads'; // {uid}/postings/{taskId}/{category}/{file}
  static const String promotionsBucket = 'promotions'; // {junkshopId}/{file}
  static const String documentsBucket = 'documents'; // PRIVATE: {uid}/{role}/{type}_{ts}.jpg
}
