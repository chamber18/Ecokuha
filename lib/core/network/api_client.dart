import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/environment_config.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  late http.Client _client;
  late String _baseUrl;
  late Map<String, String> _defaultHeaders;

  /// Static base URL for direct access in repositories
  static String get baseUrl => EnvironmentConfig.apiBaseUrl;

  /// Initialize the API client with configuration
  void initialize() {
    _client = http.Client();
    _baseUrl = EnvironmentConfig.apiBaseUrl;
    _defaultHeaders = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    // Add API key if available
    if (EnvironmentConfig.apiKey.isNotEmpty) {
      _defaultHeaders['Authorization'] = 'Bearer ${EnvironmentConfig.apiKey}';
    }
  }

  /// GET request
  Future<http.Response> get(
    String endpoint, {
    Map<String, String>? headers,
    Map<String, String>? queryParams,
  }) async {
    final uri = _buildUri(endpoint, queryParams);
    final mergedHeaders = {..._defaultHeaders, ...?headers};

    try {
      final response = await _client
          .get(uri, headers: mergedHeaders)
          .timeout(Duration(milliseconds: EnvironmentConfig.receiveTimeout));

      _logRequest('GET', uri, response);
      return response;
    } catch (e) {
      _logError('GET', uri, e);
      rethrow;
    }
  }

  /// POST request
  Future<http.Response> post(
    String endpoint, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
    Map<String, String>? queryParams,
  }) async {
    final uri = _buildUri(endpoint, queryParams);
    final mergedHeaders = {..._defaultHeaders, ...?headers};
    final jsonBody = body != null ? json.encode(body) : null;

    try {
      final response = await _client
          .post(uri, headers: mergedHeaders, body: jsonBody)
          .timeout(Duration(milliseconds: EnvironmentConfig.receiveTimeout));

      _logRequest('POST', uri, response);
      return response;
    } catch (e) {
      _logError('POST', uri, e);
      rethrow;
    }
  }

  /// Build URI with query parameters
  Uri _buildUri(String endpoint, Map<String, String>? queryParams) {
    final url = '$_baseUrl$endpoint';
    final uri = Uri.parse(url);

    if (queryParams != null && queryParams.isNotEmpty) {
      return uri.replace(queryParameters: queryParams);
    }

    return uri;
  }

  /// Log successful requests (only in debug mode)
  void _logRequest(String method, Uri uri, http.Response response) {
    if (EnvironmentConfig.enableLogging) {
      if (kDebugMode) print('[$method] ${uri.toString()} - ${response.statusCode}');
    }
  }

  /// Log request errors (only in debug mode)
  void _logError(String method, Uri uri, dynamic error) {
    if (EnvironmentConfig.enableLogging) {
      if (kDebugMode) print('[$method] ${uri.toString()} - ERROR: $error');
    }
  }

  /// Update authorization token
  void updateAuthToken(String token) {
    _defaultHeaders['Authorization'] = 'Bearer $token';
  }

  /// Dispose the client
  void dispose() {
    _client.close();
  }
}
