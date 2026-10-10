import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ecokuha/core/supabase/supabase_helpers.dart' as helpers;
import '../models/collection_task_model.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

abstract class ICollectorTasksRepository {
  Future<List<CollectorTask>> fetchMyTasks(String collectorId);
  Stream<List<CollectorTask>> getMyTasksStream(String collectorId);
}

class CollectorTasksRepository implements ICollectorTasksRepository {
  final SupabaseClient _db;

  CollectorTasksRepository({SupabaseClient? supabase})
    : _db = supabase ?? Supabase.instance.client;

  static const _activeStatuses = [
    'assigned',
    'in_transit',
    'arrived',
    'collecting',
  ];

  List<CollectorTask> _toTasks(List<dynamic> rows) {
    final tasks = rows
        .map((r) => Map<String, dynamic>.from(r as Map))
        .where((r) => _activeStatuses.contains(r['status']?.toString()))
        .map((r) => CollectorTask.fromMap(helpers.rowToDoc('postings', r)))
        .toList();

    // Sort by assigned time (most recent first)
    tasks.sort((a, b) {
      final ta = a.assignedAt?.millisecondsSinceEpoch ?? 0;
      final tb = b.assignedAt?.millisecondsSinceEpoch ?? 0;
      return tb.compareTo(ta);
    });
    return tasks;
  }

  @override
  Stream<List<CollectorTask>> getMyTasksStream(String collectorId) {
    return _db
        .from('postings')
        .stream(primaryKey: ['id'])
        .eq('collector_id', collectorId)
        .map(_toTasks);
  }

  @override
  Future<List<CollectorTask>> fetchMyTasks(String collectorId) async {
    try {
      final rows = await _db
          .from('postings')
          .select()
          .eq('collector_id', collectorId)
          .inFilter('status', _activeStatuses);
      return _toTasks(rows);
    } catch (e) {
      if (kDebugMode) print('Error fetching collector tasks: $e');
      rethrow;
    }
  }
}