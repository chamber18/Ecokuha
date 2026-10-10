import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:supabase_flutter/supabase_flutter.dart';
class LeaderboardRepository {
  final SupabaseClient _db;

  LeaderboardRepository({SupabaseClient? supabase})
    : _db = supabase ?? Supabase.instance.client;

  /// Calculate engagement score: Collections (60%) + Earnings (40%)
  double _calculateScore(int collections, double earnings) {
    // Normalize earnings to points (₱100 = 1 point)
    final earningsPoints = earnings / 100;

    // Weight: 60% collections, 40% earnings
    return (collections * 0.6) + (earningsPoints * 0.4);
  }

  Map<String, dynamic> _householdToEntry(Map<String, dynamic> row) {
    final collections = ((row['total_collections'] ?? 0) as num).toInt();
    final earnings = ((row['total_earnings'] ?? 0) as num).toDouble();
    return {
      'id': row['id'].toString(),
      'rank': 0, // Will be assigned after sorting
      'full_name': row['full_name'] ?? 'Unknown',
      'profile_image_url': row['profile_image_url'],
      'total_collections': collections,
      'total_earnings': earnings,
      'total_recycled_kg': ((row['total_recycled_kg'] ?? 0) as num).toDouble(),
      'carbon_offset': ((row['carbon_offset'] ?? 0) as num).toDouble(),
      'score': _calculateScore(collections, earnings),
      'city': row['city'],
    };
  }

  /// Fetch top N households from pre-computed leaderboard rankings for a specific city
  /// Falls back to direct query if pre-computed rankings don't exist yet
  /// If city is null or empty, returns all households globally
  /// timePeriod: 'week' or 'month' (rankings are all-time; household stats are
  /// system-managed totals, so the period filter no longer narrows results)
  Future<List<Map<String, dynamic>>> getTopHouseholds({
    String? city,
    int limit = 10,
    String? timePeriod,
  }) async {
    try {
      // If city is provided, try city-filtered pre-computed rankings
      if (city != null && city.isNotEmpty) {
        final rows = await _db
            .from('leaderboard_rankings')
            .select()
            .eq('city', city)
            .order('rank', ascending: true)
            .limit(limit);

        if (rows.isNotEmpty) {
          return rows.map((data) {
            return {
              'id': data['user_id'].toString(),
              'rank': (data['rank'] as num).toInt(),
              'name': data['full_name'] as String? ?? 'Anonymous',
              'kg': (data['total_recycled_kg'] as num?)?.toDouble() ?? 0.0,
              'profileImageUrl': data['profile_image_url'] as String?,
              'totalCollections':
                  (data['total_collections'] as num?)?.toInt() ?? 0,
              'carbonOffset':
                  (data['carbon_offset'] as num?)?.toDouble() ?? 0.0,
            };
          }).toList();
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print(
          'Pre-computed rankings not available, falling back to direct query: $e',
        );
      }
    }

    // Fallback to direct household query
    try {
      if (kDebugMode) {
        print(
          '🔍 Fetching top $limit households${city != null && city.isNotEmpty ? ' in $city' : ' (all)'}${timePeriod != null ? ' for $timePeriod' : ''}',
        );
      }

      var query = _db.from('households').select();

      // Apply city filter if provided
      if (city != null && city.isNotEmpty) {
        query = query.eq('city', city);
      }

      final rows = await query;
      if (kDebugMode) print('📊 Found ${rows.length} total households');

      if (rows.isEmpty) {
        return [];
      }

      final households = rows
          .map((r) => _householdToEntry(Map<String, dynamic>.from(r)))
          .where(
            (household) =>
                (household['total_collections'] as int) > 0 ||
                (household['total_earnings'] as double) > 0,
          )
          .toList();

      if (households.isEmpty) {
        if (kDebugMode) print('📊 No active households found');
        return [];
      }

      // Sort by score descending
      households.sort(
        (a, b) => (b['score'] as double).compareTo(a['score'] as double),
      );

      // Assign ranks
      for (int i = 0; i < households.length; i++) {
        households[i]['rank'] = i + 1;
      }

      final topHouseholds = households.take(limit).toList();
      if (kDebugMode) print('✅ Returning top ${topHouseholds.length} households');

      return topHouseholds;
    } catch (e) {
      if (kDebugMode) print('❌ Error fetching top households: $e');
      rethrow;
    }
  }

  /// Get specific user's ranking within their city
  /// If city is null or empty, gets ranking globally
  /// Returns user's rank even if they have 0 stats (filtered out of top list)
  Future<Map<String, dynamic>?> getUserRanking({
    required String userId,
    String? city,
  }) async {
    try {
      if (kDebugMode) {
        print(
          '🔍 Fetching ranking for user $userId${city != null && city.isNotEmpty ? ' in $city' : ''}',
        );
      }

      var query = _db.from('households').select();

      if (city != null && city.isNotEmpty) {
        query = query.eq('city', city);
      }

      final rows = await query;

      if (rows.isEmpty) {
        return null;
      }

      // Calculate scores for ALL households (including those with 0 stats)
      final allHouseholds = rows
          .map((r) => _householdToEntry(Map<String, dynamic>.from(r)))
          .toList(); // Don't filter - include everyone for ranking

      // Sort by score
      allHouseholds.sort(
        (a, b) => (b['score'] as double).compareTo(a['score'] as double),
      );

      // Assign ranks to everyone
      for (int i = 0; i < allHouseholds.length; i++) {
        allHouseholds[i]['rank'] = i + 1;
      }

      // Find user's rank (even if they have 0 stats)
      final userRanking = allHouseholds.firstWhere(
        (h) => h['id'] == userId,
        orElse: () => {},
      );

      if (userRanking.isEmpty) {
        return null;
      }

      if (kDebugMode) {
        print(
          '✅ User rank: ${userRanking['rank']} (Score: ${userRanking['score']})',
        );
      }
      return userRanking;
    } catch (e) {
      if (kDebugMode) print('❌ Error fetching user ranking: $e');
      return null;
    }
  }

  /// Get user's city from their profile
  Future<String?> getUserCity(String userId) async {
    try {
      final row = await _db
          .from('households')
          .select('city')
          .eq('id', userId)
          .maybeSingle();
      return row?['city'] as String?;
    } catch (e) {
      if (kDebugMode) print('Error fetching user city: $e');
    }
    return null;
  }
}