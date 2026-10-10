# EcoKuha

A Flutter app for waste pickup and recycling in Davao del Norte, Philippines.
It connects **households**, **collectors** and **junkshops**.

## Stack

- Flutter / Dart, BLoC state management, `get_it` dependency injection
- Supabase (Postgres + RLS, Auth, Storage, Realtime, pg_cron)

## Getting started

```bash
flutter pub get
flutter run                          # Android / iOS / desktop
flutter run -d web-server --web-port 8080   # Web (open http://localhost:8080)
```

The Supabase URL and publishable key default to the project in
`lib/core/supabase/supabase_config.dart`. Override them per environment:

```bash
flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_PUBLISHABLE_KEY=...
```

Supabase Auth must have **Confirm email** turned off for sign-up to log in immediately.

## Database

Schema, RLS policies, triggers, storage policies and cron jobs live in
`supabase/migrations/` and are applied in filename order.

## Status of features

| Feature | Status |
| --- | --- |
| Household, Collector, Junkshop flows | Working |
| Chat between users | Working |
| Promotions | Working |
| Maps | On hold (Google Maps provider shut down) |
| AI waste detection | On hold (disabled) |
| Push notifications | On hold |
| Collector payment methods | Not implemented yet |

## Tests

```bash
flutter analyze
flutter test
```
