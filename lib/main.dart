import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/supabase/supabase_config.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/theme/app_colors.dart';
import 'core/config/environment_config.dart';
import 'core/di/service_locator.dart';
import 'core/services/notification_service.dart';
import 'core/services/cache_service.dart';
import 'core/services/carbon_factors_service.dart';
import 'features/messaging/data/services/conversation_sync_service.dart';
import 'features/ai/data/datasources/ai_detection_datasource.dart';
import 'features/authentication/presentation/screens/login_screen.dart';
import 'features/authentication/presentation/screens/forgot_password_screen.dart';
import 'screens/navigation_test_screen.dart';
import 'features/authentication/presentation/screens/role_selection_screen.dart';
import 'features/authentication/presentation/screens/welcome_screen.dart';
import 'features/authentication/presentation/screens/registration/household_registration_screen.dart';
import 'features/authentication/presentation/screens/registration/junkshop_registration/junkshop_step1_screen.dart';
import 'features/authentication/presentation/screens/registration/junkshop_registration/junkshop_step2_screen.dart';
import 'features/authentication/presentation/screens/registration/junkshop_registration/junkshop_step4_screen.dart';
import 'features/authentication/presentation/screens/registration/junkshop_registration/junkshop_step5_screen.dart';
import 'features/authentication/presentation/screens/registration/junkshop_registration/junkshop_pending_screen.dart';
import 'features/authentication/presentation/screens/registration/collector_registration/collector_step2_screen.dart';
import 'features/authentication/presentation/screens/registration/collector_registration/collector_step3_screen.dart';
import 'features/authentication/presentation/screens/registration/collector_registration/collector_step5_screen.dart';
import 'features/authentication/presentation/screens/registration/collector_registration/collector_pending_screen.dart';
import 'features/authentication/presentation/screens/register_screen.dart';
import 'features/household/presentation/screens/household_dashboard.dart';
import 'features/household/presentation/screens/schedule_pickup_screen.dart';
import 'features/household/presentation/screens/confirmation_screen.dart';
import 'features/collector/presentation/screens/dashboard_shell.dart'
    as collector_shell;
import 'features/collector/presentation/screens/task_details_screen.dart'
    as collector_task_details;
import 'features/collector/presentation/screens/earnings_screen.dart'
    as collector_earnings;
// Legacy collector screens (pre-feature-structure)
import 'screens/collector/routes_screen.dart' as legacy_routes;
import 'screens/collector/help_support_screen.dart' as legacy_help;
import 'screens/collector/collector_settings_screen.dart' as legacy_settings;
import 'features/junkshop/presentation/screens/junkshop_main_screen.dart';
import 'features/junkshop/presentation/screens/analytics/analytics_screen.dart';
import 'features/junkshop/presentation/screens/analytics/material_detail_screen.dart';
import 'features/junkshop/presentation/bloc/material_analytics/material_analytics_bloc.dart';
import 'features/junkshop/presentation/screens/analytics/all_sellers_screen.dart';
import 'features/junkshop/presentation/screens/analytics/all_buyers_screen.dart';
import 'features/promotions/presentation/screens/junkshop/manage_promotions_screen.dart';
import 'features/household/presentation/screens/history/history_screen.dart';
import 'features/household/presentation/screens/impact/carbon_impact_screen.dart';
import 'features/household/presentation/screens/materials/materials_breakdown_screen.dart';
import 'features/household/presentation/screens/profile/full_leaderboard_screen.dart';
import 'features/household/presentation/screens/material_scanning_screen.dart';
import 'features/junkshop/presentation/screens/profile/business_controls_screen.dart';
import 'features/junkshop/presentation/screens/profile/logs_screen.dart';
import 'features/household/presentation/screens/chat_screen.dart'
    show ConversationScreen;
import 'features/collector/presentation/screens/chat_detail_screen.dart'
    as collector_chat_detail;
import 'features/collector/presentation/screens/message_settings_screen.dart'
    as collector_message_settings;
import 'features/collector/presentation/screens/collection_detail_screen.dart';
import 'features/junkshop/presentation/screens/workers/worker_applications_screen.dart';
import 'features/ai/presentation/screens/waste_scanner_screen.dart';

// Simple BLoC providers without Firebase for now
import 'features/household/presentation/bloc/home/home_bloc.dart';
import 'features/collector/presentation/bloc/home/collector_home_bloc.dart';
import 'features/junkshop/presentation/bloc/dashboard/dashboard_bloc.dart';
import 'features/authentication/presentation/bloc/login/login_bloc.dart';
import 'features/ai/presentation/bloc/ai_detection/ai_detection_bloc.dart';

void main() async {
  // Initialize Flutter bindings
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // .env is optional; Supabase config has built-in defaults.
  }

  // Initialize Supabase (auth, database, storage, realtime)
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );

  // Initialize environment configuration
  EnvironmentConfig.initialize();

  // Initialize Hive cache service
  await CacheService.init();

  // Initialize dependency injection
  await initializeDependencies();

  // Initialize AI model
  try {
    final aiDatasource = getIt<AiDetectionDatasource>();
    await aiDatasource.loadModel();
    if (kDebugMode) print('Ã¢Å“â€¦ AI detection model loaded');
  } catch (e) {
    if (kDebugMode) print('Ã¢Å¡Â Ã¯Â¸Â Failed to load AI model: $e');
  }

  // Initialize carbon factors
  try {
    await CarbonFactorsService.instance.loadFactors();
    if (kDebugMode) print('Ã¢Å“â€¦ Carbon factors loaded');
  } catch (e) {
    if (kDebugMode) print('Ã¢Å¡Â Ã¯Â¸Â Failed to load carbon factors: $e');
  }

  // Start syncing all active conversations with their posting statuses
  try {
    final syncService = getIt<ConversationSyncService>();
    await syncService.syncAllActiveConversations();
    // Also cleanup any expired conversations
    await syncService.cleanupExpiredConversations();
    if (kDebugMode) print('Ã¢Å“â€¦ Conversation sync service initialized');
  } catch (e) {
    if (kDebugMode) print('Ã¢Å¡Â Ã¯Â¸Â Failed to initialize conversation sync: $e');
  }

  // Initialize notification services
  try {
    final notificationService = getIt<NotificationService>();
    await notificationService.initialize();
    if (kDebugMode) print('Ã¢Å“â€¦ Notification service initialized');
  } catch (e) {
    if (kDebugMode) print('Ã¢Å¡Â Ã¯Â¸Â Failed to initialize notifications: $e');
  }

  // Catch all Flutter errors during alpha testing
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    if (kDebugMode) print('Ã°Å¸â€Â´ FLUTTER ERROR: ${details.exception}');
    if (kDebugMode) print('Stack: ${details.stack}');
  };

  runApp(const EcoKuhaApp());
}

// Global navigator key for navigation from services (e.g., notification taps)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Custom scroll physics with controlled bounce
class ControlledBounceScrollPhysics extends BouncingScrollPhysics {
  const ControlledBounceScrollPhysics({super.parent});

  @override
  ControlledBounceScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return ControlledBounceScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    // Reduce the overscroll effect by 60% for a more controlled bounce
    if (position.outOfRange) {
      return offset * 0.4;
    }
    return offset;
  }

  @override
  double get maxFlingVelocity => 8000.0; // Limit fling speed

  @override
  double get dragStartDistanceMotionThreshold => 3.0; // More responsive
}

class AppScrollBehavior extends ScrollBehavior {
  const AppScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    // Remove glow/bounce indicators globally
    return child;
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    // Use controlled bounce physics for subtle, pleasant bounce
    return const ControlledBounceScrollPhysics();
  }
}

class EcoKuhaApp extends StatelessWidget {
  const EcoKuhaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<HomeBloc>(create: (context) => HomeBloc()),
        BlocProvider<CollectorHomeBloc>(
          create: (context) => CollectorHomeBloc(),
        ),
        BlocProvider<DashboardBloc>(create: (context) => DashboardBloc()),
        BlocProvider<LoginBloc>(create: (context) => getIt<LoginBloc>()),
        BlocProvider<AiDetectionBloc>(
          create: (context) => getIt<AiDetectionBloc>(),
        ),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'B.B.P. Tracker',
        debugShowCheckedModeBanner: false,
        scrollBehavior: const AppScrollBehavior(),
        theme: ThemeData(
          primarySwatch: MaterialColor(
            AppColors.primaryGreen.toARGB32(),
            const <int, Color>{
              50: Color(0xFFECFDF5),
              100: Color(0xFFD1FAE5),
              200: Color(0xFFA7F3D0),
              300: Color(0xFF6EE7B7),
              400: Color(0xFF34D399),
              500: AppColors.primaryGreen,
              600: Color(0xFF059669),
              700: Color(0xFF047857),
              800: Color(0xFF065F46),
              900: Color(0xFF064E3B),
            },
          ),
          fontFamily: 'Inter',
          scaffoldBackgroundColor: AppColors.backgroundLight,
          appBarTheme: const AppBarTheme(
            backgroundColor: AppColors.primaryGreen,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
        ),
        // Start with welcome screen for onboarding and clear entry points
        initialRoute: '/welcome',
        routes: {
          '/welcome': (context) => const WelcomeScreen(),
          '/login': (context) => const LoginScreen(),
          '/forgot-password': (context) => const ForgotPasswordScreen(),
          '/register': (context) {
            final args = ModalRoute.of(context)?.settings.arguments;
            String? role;
            if (args is Map<String, dynamic>) {
              role = args['role'] as String?;
            }
            return RegisterScreen(role: role);
          },
          '/navigation-test': (context) => const NavigationTestScreen(),
          '/role-selection': (context) => const RoleSelectionScreen(),
          '/household-register': (context) =>
              const HouseholdRegistrationScreen(),
          '/junkshop-register-1': (context) => const JunkshopStep1Screen(),
          '/junkshop-register-2': (context) => const JunkshopStep2Screen(),
          '/junkshop-register-4': (context) => const JunkshopStep4Screen(),
          '/junkshop-register-5': (context) => const JunkshopStep5Screen(),
          '/junkshop-pending': (context) => const JunkshopPendingScreen(),
          '/collector-register-1': (context) => const CollectorStep2Screen(),
          '/collector-register-2': (context) => const CollectorStep3Screen(),
          '/collector-register-3': (context) => const CollectorStep5Screen(),
          '/auth/collector-pending': (context) =>
              const CollectorPendingScreen(),
          // Main app screens
          '/household-home': (context) {
            final args =
                ModalRoute.of(context)?.settings.arguments
                    as Map<String, dynamic>?;
            final initialIndex = args?['initialIndex'] as int? ?? 0;
            final postingData = args?['postingData'] as Map<String, dynamic>?;
            final mode = args?['mode'] as String?;
            final postingId = args?['postingId'] as String?;
            final isRepost = args?['isRepost'] as bool? ?? false;
            final junkshopId = args?['junkshopId'] as String?;
            final promotionId = args?['promotionId'] as String?;
            final promotionData =
                args?['promotionData'] as Map<String, dynamic>?;
            return HouseholdDashboard(
              initialIndex: initialIndex,
              editPostingData: postingData,
              mode: mode,
              postingId: postingId,
              isRepost: isRepost,
              junkshopId: junkshopId,
              promotionId: promotionId,
              promotionData: promotionData,
            );
          },
          '/household-schedule-pickup': (context) =>
              const SchedulePickupScreen(),
          '/household-confirmation': (context) => const ConfirmationScreen(),
          '/household/history': (context) => const HistoryScreen(),
          '/household/carbon-impact': (context) {
            final args =
                ModalRoute.of(context)?.settings.arguments
                    as Map<String, dynamic>?;
            final userId = args?['userId'] as String?;
            if (userId == null) {
              return const Scaffold(
                body: Center(child: Text('User ID required')),
              );
            }
            return CarbonImpactScreen(userId: userId);
          },
          '/household/materials': (context) => const MaterialsBreakdownScreen(),
          '/household/leaderboard': (context) => const FullLeaderboardScreen(),
          '/ai-scanner': (context) => const WasteScannerScreen(),
          '/household/scan-material': (context) =>
              const MaterialScanningScreen(),
          '/household-scan-material': (context) =>
              const MaterialScanningScreen(),
          '/household/conversation': (context) {
            final args =
                ModalRoute.of(context)?.settings.arguments
                    as Map<String, dynamic>?;
            final conversation = args?['conversation'];
            if (conversation == null) {
              return const Scaffold(
                body: Center(child: Text('Conversation not found')),
              );
            }
            return ConversationScreen(conversation: conversation);
          },
          '/collector-home': (context) =>
              const collector_shell.CollectorDashboardShell(),
          // Collector module routes
          '/collector/collections': (context) =>
              const collector_shell.CollectorDashboardShell(initialIndex: 1),
          // Alias for legacy hyphenated route names used in some widgets
          '/collector-collections': (context) =>
              const collector_shell.CollectorDashboardShell(initialIndex: 1),
          '/collector/messages': (context) =>
              const collector_shell.CollectorDashboardShell(initialIndex: 2),
          '/collector-messages': (context) =>
              const collector_shell.CollectorDashboardShell(initialIndex: 2),
          '/collector/profile': (context) =>
              const collector_shell.CollectorDashboardShell(initialIndex: 3),
          '/collector-profile': (context) =>
              const collector_shell.CollectorDashboardShell(initialIndex: 3),
          // Messaging routes
          '/collector-chat-detail': (context) {
            final args = ModalRoute.of(context)?.settings.arguments;
            Map<String, dynamic>? conversation;
            if (args is Map<String, dynamic>) conversation = args;
            return collector_chat_detail.ChatDetailScreen(
              conversation: conversation,
            );
          },
          '/collector/chat-detail': (context) {
            final args = ModalRoute.of(context)?.settings.arguments;
            Map<String, dynamic>? conversation;
            if (args is Map<String, dynamic>) conversation = args;
            return collector_chat_detail.ChatDetailScreen(
              conversation: conversation,
            );
          },
          '/collector-message-settings': (context) =>
              const collector_message_settings.MessageSettingsScreen(),
          '/collector-earnings': (context) =>
              const collector_earnings.CollectorEarningsScreen(),
          '/collector-routes': (context) => const legacy_routes.RoutesScreen(),
          '/collector-settings': (context) =>
              const legacy_settings.CollectorSettingsScreen(),
          '/collector-help': (context) => const legacy_help.HelpSupportScreen(),
          // Task details with argument support (from multiple entry points)
          '/collector/task-details': (context) {
            final args = ModalRoute.of(context)?.settings.arguments;
            String taskId = '';
            String? householdId;
            String? docPath;
            if (args is Map) {
              taskId = args['taskId']?.toString() ?? '';
              householdId = args['householdId']?.toString();
              docPath = args['docPath']?.toString();
            } else {
              taskId = (args == null) ? '' : args.toString();
            }
            return collector_task_details.TaskDetailsScreen(
              taskId: taskId,
              householdId: householdId,
              docPath: docPath,
            );
          },
          // Legacy/alternate route name used in some widgets
          '/collector-task-details': (context) {
            final args = ModalRoute.of(context)?.settings.arguments;
            String taskId = '';
            String? householdId;
            String? docPath;
            if (args is Map) {
              taskId = args['taskId']?.toString() ?? '';
              householdId = args['householdId']?.toString();
              docPath = args['docPath']?.toString();
            } else {
              taskId = (args == null) ? '' : args.toString();
            }
            return collector_task_details.TaskDetailsScreen(
              taskId: taskId,
              householdId: householdId,
              docPath: docPath,
            );
          },
          '/collector-collection-detail': (context) {
            final args = ModalRoute.of(context)?.settings.arguments;
            final map = (args is Map<String, dynamic>)
                ? args
                : <String, dynamic>{};
            return CollectionDetailScreen(collection: map);
          },
          '/junkshop-dashboard': (context) {
            final args =
                ModalRoute.of(context)?.settings.arguments
                    as Map<String, dynamic>?;
            final initialIndex = args?['switchToTab'] as int? ?? 0;
            return JunkshopMainScreen(initialIndex: initialIndex);
          },
          '/junkshop/analytics': (context) => const AnalyticsScreen(),
          '/junkshop-analytics': (context) => const AnalyticsScreen(),
          '/junkshop/analytics/material-detail': (context) {
            final args =
                ModalRoute.of(context)?.settings.arguments
                    as Map<String, dynamic>?;
            return BlocProvider.value(
              value: args?['bloc'] as MaterialAnalyticsBloc,
              child: MaterialDetailScreen(
                materialName: args?['materialName'] ?? '',
              ),
            );
          },
          '/junkshop-analytics-material-detail': (context) {
            final args =
                ModalRoute.of(context)?.settings.arguments
                    as Map<String, dynamic>?;
            return BlocProvider.value(
              value: args?['bloc'] as MaterialAnalyticsBloc,
              child: MaterialDetailScreen(
                materialName: args?['materialName'] ?? '',
              ),
            );
          },
          '/junkshop/analytics/all-sellers': (context) =>
              const AllSellersScreen(),
          '/junkshop-analytics-all-sellers': (context) =>
              const AllSellersScreen(),
          '/junkshop/analytics/all-buyers': (context) =>
              const AllBuyersScreen(),
          '/junkshop-analytics-all-buyers': (context) =>
              const AllBuyersScreen(),
          '/junkshop/promotions': (context) => const ManagePromotionsScreen(),
          '/junkshop-promotions': (context) => const ManagePromotionsScreen(),
          '/junkshop/worker-applications': (context) =>
              const WorkerApplicationsScreen(),
          '/junkshop-worker-applications': (context) =>
              const WorkerApplicationsScreen(),
          '/junkshop/business-controls': (context) =>
              const BusinessControlsScreen(),
          '/junkshop-business-controls': (context) =>
              const BusinessControlsScreen(),
          '/junkshop/profile/logs': (context) => const LogsScreen(),
          '/junkshop-profile-logs': (context) => const LogsScreen(),
        },
        onUnknownRoute: (settings) {
          return MaterialPageRoute(
            builder: (context) => const RoleSelectionScreen(),
          );
        },
      ),
    );
  }
}

