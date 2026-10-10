import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Core imports
import '../network/api_client.dart';
import '../config/environment_config.dart';
import '../config/feature_flags.dart';
import '../services/notification_service.dart';
import '../services/local_notification_service.dart';
import '../services/cache_service.dart';
import '../services/posting_upload_service.dart';

// Authentication imports
import '../../features/authentication/data/repositories/supabase_auth_repository_impl.dart';
import '../../features/authentication/domain/repositories/auth_repository.dart';
import '../../features/authentication/domain/usecases/login_usecase.dart';
import '../../features/authentication/domain/usecases/google_signin_usecase.dart';
import '../../features/authentication/domain/usecases/register_usecase.dart';
import '../../features/authentication/domain/usecases/logout_usecase.dart';
import '../../features/authentication/domain/usecases/get_current_user_usecase.dart';
import '../../features/authentication/presentation/bloc/login/login_bloc.dart';
import '../../features/authentication/presentation/bloc/register/register_bloc.dart';

// Feature BLoCs
import '../../features/household/presentation/bloc/home/home_bloc.dart';
import '../../features/household/presentation/bloc/profile/profile_bloc.dart'
    as household_profile;
import '../../features/collector/presentation/bloc/home/collector_home_bloc.dart';
import '../../features/collector/presentation/bloc/profile/collector_profile_bloc.dart';
import '../../features/junkshop/presentation/bloc/dashboard/dashboard_bloc.dart';
import '../../features/junkshop/presentation/bloc/profile/profile_bloc.dart'
    as junkshop_profile;
import 'package:ecokuha/features/household/data/repositories/household_posting_repository.dart';
import 'package:ecokuha/features/junkshop/data/repositories/pickups_repository.dart';
import 'package:ecokuha/features/junkshop/data/repositories/collectors_repository.dart';
import 'package:ecokuha/features/junkshop/domain/repositories/collectors_repository.dart';
import 'package:ecokuha/features/collector/data/repositories/collector_tasks_repository.dart';
import 'package:ecokuha/features/messaging/data/services/conversation_sync_service.dart';
import 'package:ecokuha/features/messaging/data/repositories/chat_repository.dart';
import 'package:ecokuha/features/junkshop/data/services/overview_analytics_service.dart';
import 'package:ecokuha/features/junkshop/data/services/material_analytics_service.dart';

// AI Detection imports
import '../../features/ai/data/datasources/ai_detection_datasource.dart';
import '../../features/ai/data/repositories/ai_detection_repository_impl.dart';
import '../../features/ai/domain/repositories/ai_detection_repository.dart';
import '../../features/ai/domain/usecases/detect_waste_usecase.dart';
import '../../features/ai/presentation/bloc/ai_detection/ai_detection_bloc.dart';

// Promotions imports
import '../../features/promotions/data/datasources/promotion_remote_datasource.dart';
import '../../features/promotions/data/repositories/promotion_repository_impl.dart';
import '../../features/promotions/domain/repositories/promotion_repository.dart';
import '../../features/promotions/domain/usecases/create_promotion.dart';
import '../../features/promotions/domain/usecases/get_active_promotions.dart';
import '../../features/promotions/domain/usecases/get_junkshop_promotions.dart';
import '../../features/promotions/domain/usecases/update_promotion.dart';
import '../../features/promotions/domain/usecases/cancel_promotion.dart';
import '../../features/promotions/presentation/bloc/junkshop_promotions/junkshop_promotions_bloc.dart';
import '../../features/promotions/presentation/bloc/household_promotions/household_promotions_bloc.dart';

final getIt = GetIt.instance;

Future<void> initializeDependencies() async {
  // Register PostingUploadService first — no dependencies, must be available immediately
  if (!getIt.isRegistered<PostingUploadService>()) {
    getIt.registerLazySingleton<PostingUploadService>(
      () => PostingUploadService(),
    );
  }

  // Initialize environment config
  EnvironmentConfig.initialize();

  // Load feature flags
  if (!getIt.isRegistered<FeatureFlags>()) {
    final featureFlags = FeatureFlags();
    await featureFlags.load();
    getIt.registerSingleton<FeatureFlags>(featureFlags);
  }

  // Initialize API client
  final apiClient = ApiClient();
  apiClient.initialize();

  //! External dependencies
  if (!getIt.isRegistered<SharedPreferences>()) {
    final sharedPreferences = await SharedPreferences.getInstance();
    getIt.registerLazySingleton<SharedPreferences>(() => sharedPreferences);
  }

  if (!getIt.isRegistered<http.Client>()) {
    final httpClient = http.Client();
    getIt.registerLazySingleton<http.Client>(() => httpClient);
  }

  if (!getIt.isRegistered<ApiClient>()) {
    getIt.registerLazySingleton<ApiClient>(() => apiClient);
  }

  // Supabase client (initialised in main.dart)
  if (!getIt.isRegistered<SupabaseClient>()) {
    getIt.registerLazySingleton<SupabaseClient>(() => Supabase.instance.client);
  }

  // Messaging Services
  if (!getIt.isRegistered<ConversationSyncService>()) {
    getIt.registerLazySingleton<ConversationSyncService>(
      () => ConversationSyncService(),
    );
  }

  if (!getIt.isRegistered<ChatRepository>()) {
    getIt.registerLazySingleton<ChatRepository>(() => ChatRepository());
  }

  // Cache Service
  if (!getIt.isRegistered<CacheService>()) {
    getIt.registerLazySingleton<CacheService>(() => CacheService());
  }

  // (PostingUploadService is registered at the top of this function)

  // Analytics Services
  if (!getIt.isRegistered<MaterialAnalyticsService>()) {
    getIt.registerLazySingleton<MaterialAnalyticsService>(
      () => MaterialAnalyticsService(),
    );
  }

  if (!getIt.isRegistered<OverviewAnalyticsService>()) {
    getIt.registerLazySingleton<OverviewAnalyticsService>(
      () => OverviewAnalyticsService(
        supabase: getIt<SupabaseClient>(),
        materialService: getIt<MaterialAnalyticsService>(),
        cacheService: getIt<CacheService>(),
      ),
    );
  }

  // Notification Services
  if (!getIt.isRegistered<LocalNotificationService>()) {
    getIt.registerLazySingleton<LocalNotificationService>(
      () => LocalNotificationService(),
    );
  }

  if (!getIt.isRegistered<NotificationService>()) {
    getIt.registerLazySingleton<NotificationService>(
      () => NotificationService(
        supabase: getIt<SupabaseClient>(),
        localNotificationService: getIt<LocalNotificationService>(),
      ),
    );
  }

  //! Authentication Feature
  // Repository
  if (!getIt.isRegistered<AuthRepository>()) {
    getIt.registerLazySingleton<AuthRepository>(
      () => SupabaseAuthRepositoryImpl(
        supabase: getIt<SupabaseClient>(),
        sharedPreferences: getIt<SharedPreferences>(),
      ),
    );
  }

  // Use Cases
  if (!getIt.isRegistered<LoginUseCase>()) {
    getIt.registerLazySingleton(
      () => LoginUseCase(repository: getIt<AuthRepository>()),
    );
  }
  if (!getIt.isRegistered<GoogleSignInUseCase>()) {
    getIt.registerLazySingleton(
      () => GoogleSignInUseCase(repository: getIt<AuthRepository>()),
    );
  }
  if (!getIt.isRegistered<RegisterUseCase>()) {
    getIt.registerLazySingleton(
      () => RegisterUseCase(repository: getIt<AuthRepository>()),
    );
  }
  if (!getIt.isRegistered<LogoutUseCase>()) {
    getIt.registerLazySingleton(
      () => LogoutUseCase(repository: getIt<AuthRepository>()),
    );
  }
  if (!getIt.isRegistered<GetCurrentUserUseCase>()) {
    getIt.registerLazySingleton(
      () => GetCurrentUserUseCase(repository: getIt<AuthRepository>()),
    );
  }

  // Authentication BLoCs
  getIt.registerFactory(
    () => LoginBloc(
      loginUseCase: getIt<LoginUseCase>(),
      googleSignInUseCase: getIt<GoogleSignInUseCase>(),
    ),
  );

  getIt.registerFactory(
    () => RegisterBloc(
      registerUseCase: getIt<RegisterUseCase>(),
      googleSignInUseCase: getIt<GoogleSignInUseCase>(),
    ),
  );

  //! Feature BLoCs - simple registration for now
  getIt.registerFactory(() => HomeBloc());
  getIt.registerFactory(() => CollectorHomeBloc());
  getIt.registerFactory(() => DashboardBloc());

  // Profile BLoCs
  getIt.registerFactory(
    () => household_profile.ProfileBloc(
      supabase: getIt<SupabaseClient>(),
    ),
  );

  getIt.registerFactory(
    () => CollectorProfileBloc(
      supabase: getIt<SupabaseClient>(),
    ),
  );

  getIt.registerFactory(
    () => junkshop_profile.ProfileBloc(
      supabase: getIt<SupabaseClient>(),
    ),
  );

  // Repositories
  if (!getIt.isRegistered<IHouseholdPostingRepository>()) {
    getIt.registerLazySingleton<IHouseholdPostingRepository>(
      () => HouseholdPostingRepository(
        supabase: getIt<SupabaseClient>(),
        flags: getIt<FeatureFlags>(),
      ),
    );
  }

  if (!getIt.isRegistered<IJunkshopPickupsRepository>()) {
    getIt.registerLazySingleton<IJunkshopPickupsRepository>(
      () => JunkshopPickupsRepository(supabase: getIt<SupabaseClient>()),
    );
  }

  if (!getIt.isRegistered<ICollectorsRepository>()) {
    getIt.registerLazySingleton<ICollectorsRepository>(
      () => CollectorsRepository(supabase: getIt<SupabaseClient>()),
    );
  }

  if (!getIt.isRegistered<ICollectorTasksRepository>()) {
    getIt.registerLazySingleton<ICollectorTasksRepository>(
      () => CollectorTasksRepository(supabase: getIt<SupabaseClient>()),
    );
  }

  //! AI Detection Feature
  if (!getIt.isRegistered<AiDetectionDatasource>()) {
    getIt.registerLazySingleton<AiDetectionDatasource>(
      () => AiDetectionDatasource(),
    );
  }

  if (!getIt.isRegistered<AiDetectionRepository>()) {
    getIt.registerLazySingleton<AiDetectionRepository>(
      () =>
          AiDetectionRepositoryImpl(datasource: getIt<AiDetectionDatasource>()),
    );
  }

  if (!getIt.isRegistered<DetectWasteUseCase>()) {
    getIt.registerLazySingleton(
      () => DetectWasteUseCase(getIt<AiDetectionRepository>()),
    );
  }

  getIt.registerFactory(
    () => AiDetectionBloc(
      repository: getIt<AiDetectionRepository>(),
      detectWasteUseCase: getIt<DetectWasteUseCase>(),
    ),
  );

  //! Promotions Feature
  if (!getIt.isRegistered<PromotionRemoteDataSource>()) {
    getIt.registerLazySingleton<PromotionRemoteDataSource>(
      () => PromotionRemoteDataSource(supabase: getIt<SupabaseClient>()),
    );
  }

  if (!getIt.isRegistered<PromotionRepository>()) {
    getIt.registerLazySingleton<PromotionRepository>(
      () => PromotionRepositoryImpl(
        remoteDataSource: getIt<PromotionRemoteDataSource>(),
      ),
    );
  }

  if (!getIt.isRegistered<CreatePromotion>()) {
    getIt.registerLazySingleton(
      () => CreatePromotion(getIt<PromotionRepository>()),
    );
  }

  if (!getIt.isRegistered<GetActivePromotions>()) {
    getIt.registerLazySingleton(
      () => GetActivePromotions(getIt<PromotionRepository>()),
    );
  }

  if (!getIt.isRegistered<GetJunkshopPromotions>()) {
    getIt.registerLazySingleton(
      () => GetJunkshopPromotions(getIt<PromotionRepository>()),
    );
  }

  if (!getIt.isRegistered<UpdatePromotion>()) {
    getIt.registerLazySingleton(
      () => UpdatePromotion(getIt<PromotionRepository>()),
    );
  }

  if (!getIt.isRegistered<CancelPromotion>()) {
    getIt.registerLazySingleton(
      () => CancelPromotion(getIt<PromotionRepository>()),
    );
  }

  getIt.registerFactory<JunkshopPromotionsBloc>(
    () => JunkshopPromotionsBloc(
      createPromotionUseCase: getIt<CreatePromotion>(),
      getJunkshopPromotions: getIt<GetJunkshopPromotions>(),
      updatePromotionUseCase: getIt<UpdatePromotion>(),
      cancelPromotion: getIt<CancelPromotion>(),
      repository: getIt<PromotionRepository>(),
    ),
  );

  getIt.registerFactory<HouseholdPromotionsBloc>(
    () => HouseholdPromotionsBloc(
      getActivePromotions: getIt<GetActivePromotions>(),
      repository: getIt<PromotionRepository>(),
    ),
  );
}
