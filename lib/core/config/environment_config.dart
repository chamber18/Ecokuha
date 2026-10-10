class EnvironmentConfig {
  // Private constructor
  EnvironmentConfig._();

  // Singleton instance
  static final EnvironmentConfig _instance = EnvironmentConfig._();
  static EnvironmentConfig get instance => _instance;

  // Environment variables map (will be loaded from .env or fallback to hardcoded values)
  static Map<String, String> _env = {};

  /// Initialize environment configuration
  /// In a real app, you would load from .env file using flutter_dotenv
  /// For now, we'll use fallback values
  static void initialize() {
    // await dotenv.load(fileName: ".env");
    // _env = dotenv.env;

    // Fallback configuration for development
    _env = {
      'API_BASE_URL_DEV': 'http://localhost:3000/api/v1',
      'API_BASE_URL_STAGING': 'https://staging-api.EcoKuha.com/api/v1',
      'API_BASE_URL_PROD': 'https://api.EcoKuha.com/api/v1',
      'API_KEY': 'dev_api_key_placeholder',
      'GOOGLE_MAPS_API_KEY': 'your_google_maps_key_here',
      'DEBUG_MODE': 'true',
      'ENABLE_LOGGING': 'true',
      'MOCK_API_RESPONSES': 'true', // Enable mock responses for development
    };
  }

  // API Configuration
  static String get apiBaseUrl {
    const environment = String.fromEnvironment(
      'ENVIRONMENT',
      defaultValue: 'dev',
    );
    switch (environment) {
      case 'prod':
        return _env['API_BASE_URL_PROD'] ?? 'https://api.EcoKuha.com/api/v1';
      case 'staging':
        return _env['API_BASE_URL_STAGING'] ??
            'https://staging-api.EcoKuha.com/api/v1';
      default:
        return _env['API_BASE_URL_DEV'] ?? 'http://localhost:3000/api/v1';
    }
  }

  static String get apiKey => _env['API_KEY'] ?? '';

  // Google Services
  static String get googleClientId => _env['GOOGLE_CLIENT_ID'] ?? '';
  static String get googleMapsApiKey => _env['GOOGLE_MAPS_API_KEY'] ?? '';

  // Apple Sign In
  static String get appleClientId => _env['APPLE_CLIENT_ID'] ?? '';

  // Development flags
  static bool get isDebugMode => _env['DEBUG_MODE']?.toLowerCase() == 'true';
  static bool get enableLogging =>
      _env['ENABLE_LOGGING']?.toLowerCase() == 'true';
  static bool get mockApiResponses =>
      _env['MOCK_API_RESPONSES']?.toLowerCase() == 'true';

  // Test credentials (only for development)
  static String get testUserEmail =>
      _env['TEST_USER_EMAIL'] ?? 'test@EcoKuha.com';
  static String get testUserPassword =>
      _env['TEST_USER_PASSWORD'] ?? 'test123456';

  // API Timeouts
  static int get connectTimeout => 30000; // 30 seconds
  static int get receiveTimeout => 30000; // 30 seconds

  /// Check if all required environment variables are set
  static bool get isConfigured {
    return apiKey.isNotEmpty && apiBaseUrl.isNotEmpty;
  }

  /// Get environment info for debugging
  static Map<String, dynamic> getDebugInfo() {
    return {
      'environment': const String.fromEnvironment(
        'ENVIRONMENT',
        defaultValue: 'dev',
      ),
      'apiBaseUrl': apiBaseUrl,
      'isDebugMode': isDebugMode,
      'enableLogging': enableLogging,
      'mockApiResponses': mockApiResponses,
      'isConfigured': isConfigured,
    };
  }
}
