import 'dart:convert';
import 'junkshop_data_service.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

/// Registry for AI function calls - maps function names to actual data queries
class AiFunctionRegistry {
  final JunkshopDataService _dataService;

  AiFunctionRegistry(this._dataService);

  /// Get list of available functions for AI system prompt
  static String getFunctionsDescription() {
    return '''
You have access to the following functions to query real-time junkshop data:

**Sales & Revenue:**
1. getSalesToday() - Get today's sales summary including total amount and transactions
2. getSalesForPeriod(days: int) - Get sales data for the last N days (e.g., 7, 30)

**Inventory Management:**
3. getInventoryStatus() - Get current inventory including low stock alerts
4. getInventoryValue() - Get total value of all inventory
5. getMaterialPrices() - Get current buy/sell prices for all materials

**Analytics:**
6. getTopMaterials(period: int, limit: int, sortBy: string) - Get top materials by quantity or value
   - period: number of days to analyze (e.g., 7, 30)
   - limit: how many top items to return (default 5)
   - sortBy: "quantity" or "value"

**Collections & Operations:**
7. getCollectionsToday() - Get today's completed collections/pickups
8. getPurchasesToday() - Get today's purchases (manual onsite collections)
9. getPurchasesForPeriod(days: int) - Get purchase data for the last N days
10. getActiveCollectors() - Get collectors currently on route
11. getPendingPickups() - Get pending pickup requests waiting for assignment

**Dashboard:**
12. getDashboardSummary() - Get comprehensive dashboard overview

**IMPORTANT:** When you need data, you MUST respond with ONLY a valid JSON function call, nothing else. Do not add any text before or after the JSON.

**CORRECT Examples:**
{"function": "getInventoryStatus", "parameters": {}}
{"function": "getSalesToday", "parameters": {}}
{"function": "getSalesForPeriod", "parameters": {"days": 30}}
{"function": "getTopMaterials", "parameters": {"period": 7, "limit": 5, "sortBy": "value"}}

**WRONG - DO NOT DO THIS:**
Sure, I'll get that data for you: {"function": "getSalesToday"}
Let me check: {"function": "getInventoryStatus"}

Return ONLY the JSON, no other text. After you receive the function result, then format it conversationally.
''';
  }

  /// Execute a function call from AI
  Future<Map<String, dynamic>> executeFunction(String functionCall) async {
    try {
      // Parse function call JSON
      final Map<String, dynamic> call = json.decode(functionCall);
      final String functionName = call['function'] ?? '';
      final Map<String, dynamic> parameters = call['parameters'] ?? {};

      if (kDebugMode) print('🤖 Executing AI function: $functionName with params: $parameters');

      // Route to appropriate function
      switch (functionName) {
        case 'getSalesToday':
          return await _dataService.getSalesToday();

        case 'getSalesForPeriod':
          final days = parameters['days'] as int? ?? 7;
          return await _dataService.getSalesForPeriod(days);

        case 'getInventoryStatus':
          return await _dataService.getInventoryStatus();

        case 'getInventoryValue':
          return await _dataService.getInventoryValue();

        case 'getMaterialPrices':
          return await _dataService.getMaterialPrices();

        case 'getTopMaterials':
          final period = parameters['period'] as int? ?? 7;
          final limit = parameters['limit'] as int? ?? 5;
          final sortBy = parameters['sortBy'] as String? ?? 'quantity';
          return await _dataService.getTopMaterials(
            period: period,
            limit: limit,
            sortBy: sortBy,
          );

        case 'getCollectionsToday':
          return await _dataService.getCollectionsToday();

        case 'getPurchasesToday':
          return await _dataService.getPurchasesToday();

        case 'getPurchasesForPeriod':
          final days = parameters['days'] as int? ?? 7;
          return await _dataService.getPurchasesForPeriod(days);

        case 'getActiveCollectors':
          return await _dataService.getActiveCollectors();

        case 'getPendingPickups':
          return await _dataService.getPendingPickups();

        case 'getDashboardSummary':
          return await _dataService.getDashboardSummary();

        default:
          return {
            'error': 'Unknown function: $functionName',
            'availableFunctions': [
              'getSalesToday',
              'getSalesForPeriod',
              'getInventoryStatus',
              'getInventoryValue',
              'getMaterialPrices',
              'getTopMaterials',
              'getCollectionsToday',
              'getPurchasesToday',
              'getPurchasesForPeriod',
              'getActiveCollectors',
              'getPendingPickups',
              'getDashboardSummary',
            ],
          };
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error executing function: $e');
      return {'error': 'Failed to execute function: $e'};
    }
  }

  /// Check if a message contains a function call
  static bool isFunctionCall(String message) {
    // Simply check if message contains "function" and valid JSON structure
    if (!message.contains('"function"')) {
      return false;
    }

    final extracted = extractFunctionCall(message);
    return extracted != null;
  }

  /// Extract JSON function call from message (even if there's extra text)
  static String? extractFunctionCall(String message) {
    try {
      // Find the first occurrence of opening brace
      final startIndex = message.indexOf('{');
      if (startIndex == -1) {
        if (kDebugMode) print('⚠️ No opening brace found');
        return null;
      }

      // Find matching closing brace
      int braceCount = 0;
      int endIndex = -1;

      for (int i = startIndex; i < message.length; i++) {
        if (message[i] == '{') {
          braceCount++;
        } else if (message[i] == '}') {
          braceCount--;
          if (braceCount == 0) {
            endIndex = i;
            break;
          }
        }
      }

      if (endIndex == -1) {
        if (kDebugMode) print('⚠️ No matching closing brace found');
        return null;
      }

      // Extract the JSON substring
      final jsonStr = message.substring(startIndex, endIndex + 1);
      if (kDebugMode) print('📝 Extracted substring: $jsonStr');

      // Validate it's proper JSON with function key
      try {
        final decoded = json.decode(jsonStr);
        if (decoded is Map && decoded.containsKey('function')) {
          if (kDebugMode) print('✅ Valid function call JSON');
          return jsonStr;
        } else {
          if (kDebugMode) print('⚠️ JSON missing "function" key');
          return null;
        }
      } catch (e) {
        if (kDebugMode) print('⚠️ Invalid JSON: $e');
        return null;
      }
    } catch (e) {
      if (kDebugMode) print('⚠️ Error extracting function call: $e');
      return null;
    }
  }

  /// Format function result for AI context
  static String formatFunctionResult(Map<String, dynamic> result) {
    return '''
Function execution result:
${json.encode(result)}

Please format this data in a natural, conversational way for the user.
''';
  }
}
