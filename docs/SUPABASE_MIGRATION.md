# Firebase -> Supabase migration guide

Backend: Supabase project `wqrqbyayiivvxprzorrs`. Schema: `supabase/migrations/*.sql` (READ IT FIRST: it is
the source of truth for tables, columns, RLS, triggers). Firebase is shut down; no Firebase package may remain.

## Shared layer (already written, do NOT edit `lib/core/supabase/*`)
Import `package:ecokuha/core/supabase/supabase_helpers.dart` (re-exports config, mapper, Timestamp):
- `supabase` -> `SupabaseClient`; `currentUid` / `requireUid()` -> signed-in user id (== role row id).
- `Timestamp` (our own class: `.toDate()`, `Timestamp.now()`, `Timestamp.fromDate()`), `toDateTime(any)`, `toIsoString(any)`.
- `rowToDoc(table, row)` -> legacy-shaped map (Firestore field names; e.g. postings: `householdId`, `dateOfCollection` as `Timestamp`);
  `docToRow(table, doc, forUpdate: true)` -> snake_case row for insert/update; unknown keys go to the `extra` jsonb.
  `rowsToDocs(table, rows)`. Use these so existing UI code that reads maps keeps working. Users tables
  (`households`,`collectors`,`junkshops`) return timestamps as ISO **strings** (as Firestore stored them);
  every other table returns `Timestamp`. Nested jsonb (items, household, junkshop, collector, verifiedItems...) is passed
  through as-is: dates inside them are ISO strings, so use `toDateTime(x)` on them (never `as Timestamp` on nested values).
- `uploadPublicFile(bucket:, path:, file:|bytes:)` -> public URL; `uploadPrivateDocument(path:, file:)` -> object path (store the
  PATH for the private `documents` bucket, resolve with `signedDocumentUrl(path)`); `deleteStorageObject(bucket, path)`.

## Hard rules
1. Remove EVERY import/use of `firebase_*`, `cloud_firestore`, `cloud_functions`, `firebase_storage`, `firebase_messaging`,
   `firebase_app_check`, `FirebaseAuth`, `Timestamp` from cloud_firestore, `FieldValue`, `Query`, `QuerySnapshot`,
   `DocumentSnapshot`, `GeoPoint`, `FirebaseImageProvider`... Use `package:supabase_flutter/supabase_flutter.dart` + the shared layer.
2. Constructors: wherever a class took `FirebaseFirestore firestore` / `FirebaseAuth auth|firebaseAuth` / `FirebaseFunctions functions`,
   replace ALL of them with ONE optional named param `SupabaseClient? supabase` (default `Supabase.instance.client`), e.g.
   `Foo({SupabaseClient? supabase, ...other existing params}) : _db = supabase ?? Supabase.instance.client;`. Keep every other
   param unchanged (even if previously positional, the Firebase one becomes named `supabase`). `lib/core/di/service_locator.dart`
   already calls these with `supabase: getIt<SupabaseClient>()`. Classes that used `FirebaseFirestore.instance` internally and had
   no ctor params keep a no-arg ctor (optionally accept `supabase`). Class renames: `FirebaseAuthRepositoryImpl` ->
   `SupabaseAuthRepositoryImpl` in `supabase_auth_repository_impl.dart` (constructor `({SupabaseClient? supabase, required SharedPreferences sharedPreferences})`).
3. Do NOT touch files you do not own (ownership is in your task). Do NOT edit `lib/core/supabase/*`, `pubspec.yaml`,
   `lib/main.dart`, `lib/core/di/service_locator.dart` (the lead owns them). If you need a shared change, handle it
   locally in your file and mention it in your report.
4. Keep behaviour identical: same public method signatures, return types and UI. Only the backend calls change.
5. Do not run `flutter pub`, `flutter run`, git commands, or touch the Supabase project. Verify with
   `dart analyze <your files>`; ignore errors that come from OTHER unfinished files (e.g. missing imports owned by others).
6. Delete the `// TODO`/dead Firebase code paths instead of leaving them commented out. Remove now-unused `google_sign_in`-free
   code only if it was Firebase-specific.

## Auth
| Firebase | Supabase |
|---|---|
| `createUserWithEmailAndPassword` | `supabase.auth.signUp(email:, password:, data: {...})` (project has email confirmation OFF: a session exists right after signUp; then insert the role row) |
| `signInWithEmailAndPassword` | `supabase.auth.signInWithPassword(...)` |
| Google sign-in | `GoogleSignIn` -> idToken/accessToken -> `supabase.auth.signInWithIdToken(provider: OAuthProvider.google, idToken:, accessToken:)` |
| `signOut` | `supabase.auth.signOut()` |
| `sendPasswordResetEmail` | `supabase.auth.resetPasswordForEmail(email)` |
| `sendEmailVerification` / `reload` / `emailVerified` | `supabase.auth.resend(type: OtpType.signup, email:)` / `supabase.auth.refreshSession()` / `user.emailConfirmedAt != null` |
| `authStateChanges()` | `supabase.auth.onAuthStateChange` (stream of `AuthState`; `.session?.user`) |
| `currentUser.uid` | `supabase.auth.currentUser!.id` (`currentUid`) |
| `FirebaseAuthException.code` | `AuthException.message` / `.statusCode` (map to the same user-facing messages) |
Role is determined by which table has a row for the uid (households -> collectors -> junkshops), exactly as before.
Registration inserts into `households` / `collectors` / `junkshops` with `id = uid` (RLS requires `id = auth.uid()`).

## Data mapping (Firestore -> tables)
| Firestore path | Table | Notes |
|---|---|---|
| `households/{uid}` | `households` | profile + stats (`total_collections`,`total_earnings`,... are SYSTEM-managed: never write them) |
| `collectors/{uid}` | `collectors` | `collector_profile` jsonb nested map; `preferred_junkshop_id` (also `assignedJunkshopId`/`assigned_junkshop_id`) is a real column (uuid FK) |
| `junkshops/{uid}` | `junkshops` | `junkshop_profile` + `settings` jsonb; `latitude`/`longitude` columns (copy from junkshop_profile.location); `business_name` column |
| `users/{uid}` + nested legacy `users/{role}/{role}/{uid}` | (dropped) | legacy; read the role table instead |
| `households/{h}/postings/{p}` + `collectionGroup('postings')` | `postings` (`household_id`,`junkshop_id`,`collector_id`) | `junkshop.id`/`collector.id` filters become `.eq('junkshop_id', ..)`/`.eq('collector_id', ..)`. When creating/assigning, ALWAYS set the real columns `junkshop_id` / `collector_id` AND keep the nested `junkshop`/`collector` snapshot maps. |
| `junkshops/{j}/collections/{postingId}` | `postings` where `status='completed' and is_reviewed` | no duplicate copy needed; the financial fields live on the posting (`total_collector_paid`,`total_junkshop_cost`,`profit`) |
| `activeCollections/{postingId}` | `active_collections` (PK `posting_id`) | |
| `junkshops/{j}/materials` | `junkshop_materials` | `.orderBy('category').orderBy('name')` ok |
| `junkshops/{j}/Purchase`,`Sales` | `purchases`, `sales` | `items` jsonb; `createdAt` -> `created_at` |
| `junkshops/{j}/activity_logs`, `logs` | `activity_logs`, `junkshop_logs` | doc field `timestamp` == column `created_at` |
| `junkshops/{j}/promotions` + root `promotions` | `promotions` (single table; no sync function) | |
| `junkshops/{j}/ratings`, `collectors/{c}/ratings` | `ratings` (`target_type`,`target_id`) | unique per (posting_id,target_type) |
| `{collectors\|junkshops}/{id}/stats/ratings` | columns `average_rating`,`total_ratings`,`sum_of_ratings` on collectors/junkshops | maintained by DB trigger |
| `material_templates` | `material_templates` | read-only for clients (admin writes) |
| `leaderboard_rankings` | `leaderboard_rankings` | refreshed nightly by pg_cron; read-only |
| `household_stats`, `achievements`, `waste_listings`, `collection_schedules`, `junkshop_schedules`, `waste_listing_model` | (not migrated: dead/legacy code) | if code only used by those missing models, delete the dead datasource methods |
| `conversations/{id}` | `conversations` (`id` is text) | `participants` uuid[]; `participantDetails`->`participant_details`; `unreadCounts`->`unread_counts` jsonb |
| `conversations/{id}/messages` | `messages` | `timestamp` == `created_at`; `senderId` is TEXT (`'system'`,`'ecokuha_assistant'` allowed) |
| `fcmToken` fields | `device_tokens` | push notifications are ON HOLD (see below) |

## Query / write translation
- `collection.where(a,'==',x)` -> `.eq('a', x)`; `isGreaterThan` -> `.gt`; `whereIn` -> `.inFilter('col', [..])`; `arrayContains` on an array column -> `.contains('participants', [uid])` (uuid[]) ;
  `orderBy(.., descending:true)` -> `.order('col', ascending:false)`; `limit(n)` -> `.limit(n)`; range -> `.gte()/.lte()`;
  `.doc(id).get()` -> `.maybeSingle()` / `.single()`; `collection.get()` -> `await ....select()`.
- Column names in filters are the snake_case columns (see schema), NOT the legacy doc keys.
- One-shot `add` -> `.insert(docToRow(table, doc, forUpdate:false)).select().single()` (ids are generated by the DB; use the returned `id`).
  `set(merge:true)` -> `.upsert(...)`; `update` -> `.update(docToRow(table, doc)).eq('id', id)`; `delete` -> `.delete().eq(..)`.
- `FieldValue.serverTimestamp()` -> omit the column when it is a DB default (`created_at`) or send `DateTime.now().toUtc().toIso8601String()` for explicit timeline fields.
  `FieldValue.delete()` -> set the column to `null`. `FieldValue.increment(n)` -> read-modify-write, or (for `unread_counts`) the RPC `increment_unread_counts`.
  `FieldValue.arrayUnion/arrayRemove` -> read the array, modify, write it back (arrays are real Postgres arrays).
- `snapshots()` realtime -> `supabase.from('t').stream(primaryKey: ['id'])` (ONE `.eq`/`.inFilter` filter allowed on a stream; apply other filters/sorting client-side) mapped through `rowsToDocs`.
  For `collectionGroup`/multi-filter listeners, stream on the main filter and filter the rest in Dart.
  Streams must return the same element types the callers expect (e.g. `Stream<List<Posting>>`).
- Batches/transactions -> sequential awaits (or a single multi-row `upsert`/`insert`). Race-prone counters already live in triggers.
- Cloud Functions callables are gone: `submitCollectorRating` / `submitJunkshopRating` -> `insert` into `ratings`
  (`posting_id`,`target_type`,`target_id`,`rated_by`,`rating`,`review_text`,`selected_reasons`); a trigger updates the posting + aggregates.
  The RLS policy enforces: caller is the household, posting is `completed`, deadline not passed, target matches. Map a unique-violation
  (`PostgrestException.code == '23505'`) to the old "already rated" error.
- Chat RPCs (`supabase.rpc(...)`): `increment_unread_counts(p_conversation_id, p_sender_id)` after sending a message;
  `mark_conversation_read(p_conversation_id)` to zero the caller's counter and mark messages read.
- Server-side jobs now in Postgres (delete the client equivalents that duplicate them only if clearly redundant):
  `checkOverdueCollections` (nightly pg_cron), leaderboard refresh (nightly), household stats (trigger), group-chat on collector approval (trigger).

## Storage (replaces Firebase Storage + `FirebaseImageProvider`)
| Old path | Bucket / object path |
|---|---|
| `profile_images/{uid}.jpg` (household, junkshop) | `profile-images` / `{uid}/profile.jpg` |
| `user_uploads/{uid}/profile/profile.jpg` (collector) | `profile-images` / `{uid}/profile.jpg` |
| `posting_images/posting_{uid}_{ts}_{i}.jpg` | `posting-images` / `{uid}/posting_{ts}_{i}.jpg` |
| `user_uploads/{uid}/postings/{taskId}/{category}/{file}` | `user-uploads` / `{uid}/postings/{taskId}/{category}/{file}` |
| `promotions/{junkshopId}/{file}` | `promotions` / `{junkshopId}/{file}` |
| `collectors/{uid}/documents/{type}_{ts}.jpg`, `junkshops/{uid}/documents/...` | `documents` (PRIVATE) / `{uid}/{role}/{type}_{ts}.jpg`; store the object PATH in `collector_profile.documents.*` / `junkshop_profile.documents.*` and show with `signedDocumentUrl` |
Every upload path MUST start with the uploader's own uid folder (storage RLS). Public buckets return normal URLs: images load with
`NetworkImage`/`CachedNetworkImage` (no special provider). `FirebaseImageProvider` is replaced by a plain `NetworkImage`-based provider.

## Push notifications: ON HOLD
Remove FCM (`firebase_messaging`, background handler, token refresh). `NotificationService` keeps local notifications
(`LocalNotificationService`) and public API (`initialize()` etc.) as no-op-safe stubs; token persistence writes to `device_tokens`
only if a token is ever provided. Do not reference Cloud Functions `notify*`.

## Features on hold (do not remove, but never block startup)
Google Maps provider and AI detection are shut down/halted. Do not delete those features; just make sure nothing in your files imports Firebase.
