import 'package:ecokuha/core/supabase/supabase_helpers.dart';
import 'package:ecokuha/features/junkshop/data/models/collector_model.dart';
import 'package:ecokuha/features/junkshop/domain/repositories/collectors_repository.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:supabase_flutter/supabase_flutter.dart';

class CollectorsRepository implements ICollectorsRepository {
  final SupabaseClient _db;

  CollectorsRepository({SupabaseClient? supabase})
    : _db = supabase ?? Supabase.instance.client;

  static const _activeStatuses = [
    'assigned',
    'ontheway',
    'in_transit',
    'arrived',
    'collecting',
  ];

  void _sortByRatingThenActivity(List<Collector> collectors) {
    collectors.sort((a, b) {
      final cmpRating = b.rating.compareTo(a.rating);
      if (cmpRating != 0) return cmpRating;
      final lastA = a.lastActive?.millisecondsSinceEpoch ?? 0;
      final lastB = b.lastActive?.millisecondsSinceEpoch ?? 0;
      return lastB.compareTo(lastA);
    });
  }

  void _sortCollectors(
    List<Collector> collectors,
    double? latitude,
    double? longitude,
  ) {
    if (latitude != null && longitude != null) {
      collectors.sort((a, b) {
        final distA = a.distanceFrom(latitude, longitude) ?? double.infinity;
        final distB = b.distanceFrom(latitude, longitude) ?? double.infinity;
        return distA.compareTo(distB);
      });
    } else {
      _sortByRatingThenActivity(collectors);
    }
  }

  @override
  Future<List<Collector>> getAvailableCollectors({
    double? latitude,
    double? longitude,
    int limit = 20,
  }) async {
    try {
      final junkshopUid = currentUid;
      if (junkshopUid == null) {
        if (kDebugMode) print('No authenticated user, returning empty list');
        return [];
      }

      final rows = await _db
          .from('collectors')
          .select()
          .eq('preferred_junkshop_id', junkshopUid)
          .eq('application_status', 'approved')
          .limit(limit);

      final collectors = <Collector>[];
      for (final row in rows) {
        final data = Map<String, dynamic>.from(row);

        final totalRatings = (data['total_ratings'] as num?)?.toInt() ?? 0;
        final rating = totalRatings > 0
            ? (data['average_rating'] as num?)?.toDouble() ?? 4.5
            : 4.5;

        final activeJobs = await _getActiveJobsCount(data['id'].toString());
        final status = _calculateStatus(
          data['last_active'],
          data['last_login_at'],
        );

        data['average_rating'] = rating;
        data['status'] = status;
        data['active_jobs'] = activeJobs;

        collectors.add(Collector.fromRow(data));
      }

      _sortCollectors(collectors, latitude, longitude);
      return collectors;
    } catch (e) {
      if (kDebugMode) print('Error fetching available collectors: $e');
      // Return empty list on error rather than throwing
      return [];
    }
  }

  Future<int> _getActiveJobsCount(String collectorId) async {
    try {
      final rows = await _db
          .from('postings')
          .select('id')
          .eq('collector_id', collectorId)
          .inFilter('status', _activeStatuses);
      return rows.length;
    } catch (e) {
      if (kDebugMode) print('Error counting active jobs for collector $collectorId: $e');
      return 0;
    }
  }

  String _calculateStatus(dynamic lastActiveField, dynamic lastLoginField) {
    // Try last_active first, then fall back to last_login_at
    final dynamic lastField = lastActiveField ?? lastLoginField;
    final lastDateTime = toDateTime(lastField)?.toLocal();
    if (lastDateTime == null) return 'offline';

    final now = DateTime.now();
    final isSameDay =
        lastDateTime.year == now.year &&
        lastDateTime.month == now.month &&
        lastDateTime.day == now.day;
    return isSameDay ? 'online' : 'offline';
  }

  @override
  Future<Collector?> getCollectorById(String collectorId) async {
    try {
      final row = await _db
          .from('collectors')
          .select()
          .eq('id', collectorId)
          .maybeSingle();
      if (row == null) return null;
      return Collector.fromRow(row);
    } catch (e) {
      if (kDebugMode) print('Error fetching collector $collectorId: $e');
      return null;
    }
  }

  @override
  Future<List<Collector>> getCollectors({int limit = 100}) async {
    try {
      final rows = await _db.from('collectors').select().limit(limit);
      final collectors = rows.map((r) => Collector.fromRow(r)).toList();
      _sortByRatingThenActivity(collectors);
      return collectors;
    } catch (e) {
      if (kDebugMode) print('Error fetching collectors: $e');
      return [];
    }
  }

  @override
  Future<List<Collector>> getCollectorsAssignedToJunkshop({
    required String junkshopId,
    int limit = 100,
  }) async {
    try {
      final rows = await _db
          .from('collectors')
          .select()
          .eq('preferred_junkshop_id', junkshopId)
          .eq('application_status', 'approved')
          .limit(limit);

      final collectors = rows.map((r) => Collector.fromRow(r)).toList();
      _sortByRatingThenActivity(collectors);
      return collectors;
    } catch (e) {
      if (kDebugMode) print('Error fetching collectors for junkshop $junkshopId: $e');
      return [];
    }
  }

  @override
  Stream<List<Collector>> watchAvailableCollectors({
    double? latitude,
    double? longitude,
    int limit = 20,
  }) {
    try {
      return _db
          .from('collectors')
          .stream(primaryKey: ['id'])
          .limit(limit)
          .map((rows) {
            final collectors = rows.map((r) => Collector.fromRow(r)).toList();
            _sortCollectors(collectors, latitude, longitude);
            return collectors;
          });
    } catch (e) {
      if (kDebugMode) print('Error watching available collectors: $e');
      return Stream.value([]);
    }
  }
}
