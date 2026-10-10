import 'package:ecokuha/core/supabase/supabase_helpers.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

/// Helper function to create test logs for development
Future<void> createTestLogs() async {
  final uid = currentUid;
  if (uid == null) return;

  final now = DateTime.now();

  // Create sample logs
  final testLogs = <Map<String, dynamic>>[
    {
      'type': 'purchase',
      'message': 'Purchased 10kg of plastic bottles from household',
      'created_at': now,
      'details': {
        'materialName': 'Plastic Bottles',
        'quantity': 10.0,
        'totalPrice': 500.0,
        'collectorId': 'test_collector_123',
      },
    },
    {
      'type': 'sale',
      'message': 'Sold 25kg of aluminum cans to recycling center',
      'created_at': now.subtract(const Duration(hours: 2)),
      'details': {
        'materialName': 'Aluminum Cans',
        'quantity': 25.0,
        'totalPrice': 2125.0,
      },
    },
    {
      'type': 'posting',
      'message': 'New posting assigned from household',
      'created_at': now.subtract(const Duration(hours: 5)),
      'details': {
        'postingId': 'posting_456',
        'householdId': 'household_789',
        'status': 'assigned',
      },
    },
    {
      'type': 'collector',
      'message': 'Collector completed pickup task',
      'created_at': now.subtract(const Duration(days: 1)),
      'details': {
        'collectorId': 'collector_123',
        'collectorName': 'John Doe',
        'postingId': 'posting_456',
        'status': 'completed',
      },
    },
    {
      'type': 'system',
      'message': 'Daily inventory report generated',
      'created_at': now.subtract(const Duration(days: 2)),
      'details': {'reportType': 'inventory', 'totalItems': 150},
    },
    {
      'type': 'error',
      'message': 'Failed to process payment transaction',
      'created_at': now.subtract(const Duration(days: 3)),
      'details': {
        'errorCode': 'PAYMENT_FAILED',
        'transactionId': 'txn_789',
        'amount': 1500.0,
      },
    },
  ];

  await supabase.from('junkshop_logs').insert([
    for (final log in testLogs)
      {
        'junkshop_id': uid,
        'user_id': uid,
        'type': log['type'],
        'message': log['message'],
        'details': log['details'],
        'created_at': (log['created_at'] as DateTime)
            .toUtc()
            .toIso8601String(),
      },
  ]);

  if (kDebugMode) print('✅ Created ${testLogs.length} test logs');
}
