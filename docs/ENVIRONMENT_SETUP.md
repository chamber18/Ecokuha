# Environment Setup

EcoKuha uses Supabase. No secrets are required in the client: the project URL and
publishable (anon) key are safe to ship because access is enforced by Row Level Security.

## Configuration

Defaults are in `lib/core/supabase/supabase_config.dart`. Override at build or run time:

```bash
flutter run --dart-define=SUPABASE_URL=https://<project>.supabase.co \
            --dart-define=SUPABASE_PUBLISHABLE_KEY=<publishable key>
```

## `.env` file

A `.env` file (gitignored) is bundled as an asset. It is optional; the app starts without
real values. Never commit real secrets.

## Supabase dashboard settings

- Authentication → Providers → Email → **Confirm email: OFF**
- Google sign-in requires configuring the Google provider for the app's package id
  (`com.example.ecokuha`).

## Troubleshooting

- Sign-in fails right after registration: check that Confirm email is off.
- Data not loading: check Row Level Security policies and the migrations in `supabase/migrations/`.
- Android build on JDK 24 needs Gradle 8.14.3 (already configured).
