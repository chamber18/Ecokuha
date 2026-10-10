# EcoKuha – AI Coding Instructions

**Mission:** Flutter app connecting households, collectors and junkshops for waste pickup and recycling (Davao del Norte, PH). Per-role dashboards, chat, promotions and pickup workflows, backed by Supabase.

## Architecture

- Clean-architecture feature folders under `lib/features/<feature>/{data,domain,presentation}`.
- State management: BLoC. Dependency injection: `get_it` (`lib/core/di`).
- Backend: Supabase (Postgres + RLS, Auth, Storage, Realtime, pg_cron).
- Data layer keeps a document-shaped API over Postgres via `lib/core/supabase/`:
  `doc_mapper.dart` (row <-> doc maps), `timestamp.dart` (Timestamp shim), `supabase_helpers.dart` (storage helpers), `supabase_config.dart` (URL/key/buckets).
- All database access goes through repositories/datasources; never query Supabase directly from widgets.

## Database

- Schema, RLS, triggers, storage policies and cron jobs live in `supabase/migrations/` (apply in filename order).
- Helpers and triggers live in the `private` schema. System-managed columns are written by triggers using the `app.system_update` flag.
- When adding a table, add RLS policies and a mapping in `doc_mapper.dart`.

## Conventions

- Brand name is **EcoKuha** (package `ecokuha`, app id `com.example.ecokuha`). Do not use the old "BBP Tracker" name.
- Keep `flutter analyze` at zero issues and `flutter test` green before finishing a change.
- Write doc comments for public classes and non-obvious logic.

## Features on hold

Maps (Google Maps provider shut down), AI waste detection (stubbed in `lib/features/ai/data/datasources/ai_detection_datasource.dart`) and push notifications. Do not re-enable without confirming with the team.

## Build notes

- JDK 24 needs Gradle 8.14.3 and Kotlin 2.1.21 (already configured).
- Windows: if Flutter fails writing `windows/flutter/generated_plugin*` (errno 1224), delete those files and retry.
- Web: `flutter run -d web-server --web-port 8080`.
