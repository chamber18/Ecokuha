# EcoKuha · AI Agent Field Guide

**Mission:** Flutter app connecting households, collectors, and junkshops for waste collection. Features per-role dashboards, real-time tracking, AI-powered waste detection, and Firebase-backed workflows.

---

## Quick Reference

### User roles & navigation
- **Household:** Posts waste, tracks pickups → `HouseholdDashboard` (IndexedStack)
- **Collector:** Accepts tasks, navigates routes → `CollectorDashboardShell` (IndexedStack + initialIndex)
- **Junkshop:** Manages pickups, assigns collectors → `JunkshopMainScreen` (IndexedStack)

### Critical workflows
- **Posting flow:** Household creates posting → auto-creates conversation with junkshop → collector assignment → status sync via `ConversationSyncService`
- **Real-time sync:** `ConversationSyncService` listens to `/households/{userId}/postings/{postingId}` and updates `/conversations/{conversationId}`
- **Profile images:** Upload via Firebase Storage, store URLs in Firestore user docs

---

## Architecture & organization

### Feature structure (active development)
- All new work happens in `lib/features/**` with clean architecture layers:
  - `data/` → repositories, models, datasources (Firestore/HTTP)
  - `domain/` → entities, repositories (abstract interfaces), use cases
  - `presentation/` → screens, widgets, bloc
- **Active features:** `authentication`, `household`, `collector`, `junkshop`, `messaging`, `notifications`, `ai`, `maps`
- **Legacy code:** `lib/screens/` contains old experiments—avoid unless explicitly migrating

### Cross-feature communication
- Features **never** import each other directly
- Share primitives via `lib/core/entities/` or `lib/shared/**`
- Wire dependencies through `core/di/service_locator.dart` (GetIt)
- Each feature registers repositories → use cases → BLoCs in service locator

## Navigation system

- Route-table based (`main.dart` routes map) despite `go_router` being declared
- When adding screens, update **both** the primary route AND hyphenated aliases (e.g. `/collector/messages` + `/collector-messages`)
- Shell-based navigation: 
  - Household: `HouseholdDashboard` with `IndexedStack`
  - Collector: `CollectorDashboardShell` with `initialIndex` prop + `_onNavSelected` callback
  - Pass tab index to jump directly to a section without rebuilding the shell
- Route arguments: use `ModalRoute.of(context)?.settings.arguments` cast to `Map<String, dynamic>`

## State management with BLoC

### Conventions
- Structure: `lib/features/{feature}/presentation/bloc/{component}/` with separate files for bloc, event, state
- Naming: `{feature}_{component}_{bloc|event|state}.dart` (e.g. `collector_profile_bloc.dart`, `collector_profile_event.dart`)
- Events/States extend `Equatable` for easy comparison
- Bloc constructors are **side-effect free**—load data in `on<Event>` handlers

### Code commenting guidelines
- **DO NOT** add change/improvement comments like "Remove this to improve performance" or "TODO: refactor this"
- **DO** add brief comments only for important functions explaining their purpose
- Keep code clean—let the code speak for itself unless explaining complex business logic
- Example good comment: `/// Syncs conversation status with posting in real-time via Firestore listener`
- Example bad comment: `// This could be optimized` or `// Remove hardcoded value`

### Registration
1. Define use cases in `domain/usecases/`
2. Register repositories → use cases → blocs in `core/di/service_locator.dart`
3. For screen-level blocs still wired in `main.dart`, add to `MultiBlocProvider` (HomeBloc, CollectorHomeBloc, DashboardBloc)
4. Access via `BlocProvider.of<T>(context)` or `context.read<T>()`

## UI system & theming

### Theme architecture
- **Unified green branding:** `AppColors.primaryGreen` is the single brand color across all roles
- Never hardcode `Color` values—pull from `core/theme/app_colors.dart`
- Text styles: `core/theme/app_text_styles.dart` (Inter font family, h1-h5, body, caption, button styles)
- Spacing/layout: `core/theme/app_dimensions.dart`

### Shared components
- Reuse `lib/shared/widgets/common/` before creating variants:
  - `CustomButton`, `CustomCard`, `CustomTextField`, `CustomAppBar`, `CustomAvatar`, `StatusBadge`, `RatingStars`
- Keep new props optional and theme-aware
- When extending, add to `presentation/widgets/` within the feature, not globally

### Screen patterns
- Large prototype screens (700–1200 lines) live under `presentation/screens/`
- Extract reusable sections into `presentation/widgets/` to reduce complexity
- Reference designs: `UI/*.html` for layout/spacing specs

### Icons
- Three icon packages available: `font_awesome_flutter: ^10.7.0`, `hugeicons: ^1.0.2`, `fluentui_system_icons: ^1.1.273`
- Prefer consistent icon family per feature for visual coherence
- FontAwesome is most commonly used across the app

## Data, config, and flags
- Feature flags: `assets/config/feature_flags.json` (loaded by `core/config/feature_flags.dart`)
- Check flags via `getIt<FeatureFlags>().isEnabled('flag_name')`
- Examples: `firestore_posting`, `ai_detection`, `real_time_tracking`, `payment_integration`
- Other configs: `app_config.json`, `material_prices.json`, `locations_ph.json`, `carbon_factors.json`
- Firebase **is enabled**—`firebase_core: ^4.1.1`, `firebase_auth: ^6.1.0`, `cloud_firestore: ^6.0.2`, `firebase_storage: ^13.0.0`
- Repository pattern: interface in `domain/repositories/`, implementation in `data/repositories/`
- All Firestore access goes through repositories with `fromJson`/`toJson` models
- **Critical:** Keep `pubspec.yaml` assets section in sync when adding config files

### Firestore patterns
- **Subcollections:** Postings stored at `/households/{userId}/postings/{postingId}`, NOT in root collection
- **Collections:** Junkshop data uses subcollections: `/junkshops/{uid}/{Purchase|Sales|materials}`
- **Models:** Every Firestore model implements `fromJson(Map<String, dynamic>)` factory and `toJson()` method
- **Example:** `AuthUserModel.fromJson(userData)` and `userProfile.toJson()` in `firebase_auth_repository_impl.dart`
- **Repository constructor:** Accept optional Firestore instance for testing: `ChatRepository({FirebaseFirestore? firestore})`
- **Timestamps:** Always use `Timestamp.fromDate()` for date storage, convert back with `.toDate()` when reading

### Critical: Posting → Conversation workflow
1. **Household creates posting** in `post_items_screen.dart` → saves to `/households/{userId}/postings/{postingId}`
2. **Auto-create conversation** via `ChatRepository.createConversation()` with household + junkshop as participants
3. **Real-time sync** via `ConversationSyncService.syncConversationWithPosting()` keeps conversation `postingStatus` field in sync with actual posting status
4. **Collector assignment** updates both posting and conversation to include collector as third participant
5. All status changes (`pending` → `assigned` → `in_progress` → `completed`) propagate automatically via sync service

### Junkshop business workflows
- **Three-tier pricing:** Household posts → Collector verifies & prices → Junkshop reviews & sets final purchase prices
- **Item detail flow:** Original items → verifiedItems (collector) → purchasedItems (junkshop with `junkshopPricePerUnit`)
- **Stock health monitoring:** Dashboard categorizes materials by health (Critical 🔴 <3 days, Warning 🟡 3-7 days, Healthy 🟢 7-30 days, Overstocked 🔵 >30 days)
- **Metrics calculation:** Sales velocity = total sold ÷ 30 days, days remaining = current stock ÷ daily velocity
- **Carbon tracking:** Material-specific CO₂ factors from `carbon_factors.json` (e.g., Aluminum: 8.5 kg CO₂/kg, Glass: 0.3 kg CO₂/kg)

### Performance & caching
- **Cache-first strategy:** Use `CacheService` (Hive) for instant UI rendering with background refresh
- **Implementation pattern:** Load from cache → display immediately → fetch from Firebase → update cache
- **Cache boxes:** `history_cache`, `customers_cache`, `materials_cache`, `cache_metadata`
- **Staleness check:** 24-hour default, manual clear via pull-to-refresh
- **Screens using cache:** History, Customers tab, Materials inventory
- **Always cache serialized data** with `lastSync` timestamps in metadata box

## Tooling & workflows

### Essential commands
```powershell
flutter pub get                                    # Install dependencies
flutter run -d windows                             # Run on Windows (VS Code task available)
flutter run -d <device-id>                         # Run on Android device (find ID via `flutter devices`)
flutter clean; flutter pub get                     # Clean build artifacts and reinstall
flutter test                                       # Run tests
flutter analyze                                    # Static analysis
adb logcat -d | Select-String -Pattern "keyword"   # Android logs (PowerShell)
```

### Mock data upload & Firebase scripts
- **12-month dataset:** `12MONTHS_DATA/{postings|purchases|sales}_12mo.json` with metadata
- **Upload script:** `scripts/upload_mock_data.js` (Node.js + Firebase Admin SDK)
- **Target account:** Junkshop UID `4GqXUYTs0eVITdclw29GqF0BpzJ2`
- **Service account key:** Required in `scripts/firebase-service-account-key.json` (never commit!)
- **Run:** `cd scripts; node upload_mock_data.js` or `.\run_upload.ps1`
- **Volume:** 380 purchases, 119 sales, 280 postings (Dec 2024 - Nov 2025)
- **Other maintenance scripts:** `cleanup_completed_collections.js`, `migrate_to_junkshop_collections.js`, `sync_existing_promotions.js`
- **Script setup:** `cd scripts; npm install` to install Firebase Admin SDK dependencies
- **Pattern:** All scripts use `firebase-service-account-key.json` for admin access—keep this file secure and local only

### Firebase project setup
- **Project ID:** `EcoKuha-auth`
- **Android package:** `com.example.ecokuha`
- **Config files:** `android/app/google-services.json` (Android), `lib/firebase_options.dart` (auto-generated)
- **Firebase Console:** Enable Auth (Email/Password), Firestore, Storage, App Check
- **App Check:** Debug provider in dev, Play Integrity in production (configured in `main.dart`)

### Google Maps integration
- **Android API Key:** Stored in `android/app/src/main/AndroidManifest.xml`
- **Required APIs:** Maps SDK for Android, Geocoding API (both enabled in Google Cloud Console)
- **Usage:** Map picker for registration, reverse geocoding for "Use Current Location"
- **Troubleshooting:** Check logcat for `Maps|GoogleMap|Authorization|API` errors with `adb logcat | Select-String -Pattern "Maps"`

### Lint exclusions
- `analysis_options.yaml` excludes incomplete/legacy code:
  - `lib/features/household/data/**`, `lib/features/authentication/presentation/bloc/**`
  - `lib/screens/collector/collector_profile_screen.dart`, legacy junkshop old screens
  - `lib/dataconnect_generated/**` (package not installed)
- **Keep new code inside the linted surface**

### Testing
- Tests mirror feature structure: `test/{unit,widget,integration}/features/{feature}/`
- Test infrastructure exists with helpers: `test/helpers/pump_app.dart`, `test/helpers/mock_data.dart`
- Integration tests cover auth, junkshop flows, cross-feature messaging, and real-time tracking
- Default `test/widget_test.dart` is a placeholder—replace when adding actual widget tests

### Debugging & troubleshooting
- **Android logs:** `adb logcat -d | Select-String -Pattern "keyword"` (PowerShell)
- **Firebase issues:** Check console for App Check token errors, verify `firebase_options.dart` is current
- **Map issues:** Search logcat for `Maps|GoogleMap|Authorization|API` to diagnose Maps SDK/Geocoding errors
- **Build errors:** Run `flutter clean; flutter pub get` before investigating deeper
- **State issues:** Verify BLoC registration in `core/di/service_locator.dart` and `main.dart`'s `MultiBlocProvider`
- **Route not found:** Check both camelCase and hyphenated route aliases in `main.dart`

## Integration notes

### Global scroll behavior
- `AppScrollBehavior` in `main.dart` removes glow/overscroll indicators and forces `ClampingScrollPhysics`
- Don't override with platform-specific scroll physics in new widgets

### Firebase App Check
- Automatically activated in `main.dart` with debug provider (dev) or Play Integrity (release)
- Storage/Firestore operations get valid tokens without additional code

### Image handling
- `image_picker: ^1.0.4` for photo selection, `image_cropper: ^8.0.2` for editing, `image: ^4.2.0` for processing
- Upload to Firebase Storage through repository layer

### Error handling
- Use `dartz` Either<Failure, Success> pattern in domain/use case layer
- Present errors through BLoC states (e.g. `ProfileError`, `CollectorProfileError`)

### Navigation patterns
- Collector navigation is orchestrated by `CollectorDashboardShell` with a shared bottom nav
- Pass `initialIndex` or call `_onNavSelected` to jump tabs instead of rebuilding the shell
- Maintain both camelCase routes (`/collector/messages`) and hyphenated aliases (`/collector-messages`)
- Dashboard shells use `IndexedStack` to preserve state across tabs

## Project-specific gotchas

- **Firebase major versions:** All packages aligned to major v4-v6 to avoid Pigeon type conflicts
- **Windows development:** Primary platform. Firebase Storage/Auth work on Windows with proper App Check setup
- **Icons:** `font_awesome_flutter: ^10.7.0`, `hugeicons: ^1.0.2`, `fluentui_system_icons: ^1.1.273`—prefer consistent icon family per feature
- **Test placeholder:** `test/widget_test.dart` contains outdated counter test—ignore or replace when adding real tests
- **Documentation files:** Many `*_COMPLETE.md` files document implementation history—useful for understanding feature evolution but not authoritative for current state
- **PowerShell-first workflows:** Command examples use PowerShell syntax (e.g., `Select-String` for `adb logcat` filtering) as Windows is the primary dev platform
- **Legacy screens:** `lib/screens/` contains old experiments excluded from linting—avoid unless explicitly migrating
- **Service account security:** `scripts/firebase-service-account-key.json` grants full admin access—never commit, keep local only

## Documentation & history

- Project maintains extensive markdown documentation of features in root directory
- File naming pattern: `{FEATURE}_IMPLEMENTATION.md`, `{FEATURE}_COMPLETE.md`, `{FEATURE}_FIX.md`
- These docs capture implementation decisions and are valuable for understanding "why" behind code patterns
- Examples: `CONVERSATION_STATUS_SYNC_COMPLETE.md`, `FIREBASE_POSTING_STRUCTURE.md`, `WORKER_APPLICATION_SYSTEM_COMPLETE.md`

## When stuck

1. Check `core/di/service_locator.dart` for registered dependencies
2. Verify feature flag state in `assets/config/feature_flags.json`
3. Look for similar screens in the same role feature for patterns
4. Check `main.dart` routes for navigation setup
5. Review `analysis_options.yaml` exclusions if lints fail unexpectedly