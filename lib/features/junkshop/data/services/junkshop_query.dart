import 'package:ecokuha/core/supabase/supabase_helpers.dart';

/// Legacy-shaped document (`id` + `data()`) returned by [JunkshopQuery], so
/// report/analytics screens can keep their doc-based aggregation code.
class JDoc {
  JDoc(this._data);
  final Map<String, dynamic> _data;
  String get id => _data['id'].toString();
  Map<String, dynamic> data() => _data;
}

class JSnap {
  const JSnap(this.docs);
  final List<JDoc> docs;
  bool get isEmpty => docs.isEmpty;
  bool get isNotEmpty => docs.isNotEmpty;
}

/// Small query helpers for the junkshop's own rows (RLS restricts everything to
/// `junkshop_id = auth.uid()` anyway). All docs are mapped with `rowToDoc`, so
/// field names are the legacy camelCase ones (`createdAt`, `totalAmount`, ...).
class JunkshopQuery {
  JunkshopQuery._();

  /// Rows of [table] (`sales`, `purchases`, `junkshop_materials`, `activity_logs`,
  /// ...) of [junkshopId], optionally restricted to `created_at` in [from]..[to].
  static Future<JSnap> table(
    String table,
    String junkshopId, {
    DateTime? from,
    DateTime? to,
    Map<String, Object>? eq,
    String? orderBy,
    bool desc = false,
    int? limit,
  }) async {
    var query = supabase.from(table).select().eq('junkshop_id', junkshopId);
    if (from != null) {
      query = query.gte('created_at', from.toUtc().toIso8601String());
    }
    if (to != null) {
      query = query.lte('created_at', to.toUtc().toIso8601String());
    }
    eq?.forEach((k, v) => query = query.eq(k, v));
    final ordered = orderBy != null
        ? query.order(orderBy, ascending: !desc)
        : query;
    final rows = limit != null ? await ordered.limit(limit) : await ordered;
    return JSnap(_wrap(table, rows));
  }

  /// Postings of this junkshop (all statuses when [statuses] is null).
  static Future<JSnap> postings(
    String junkshopId, {
    List<String>? statuses,
  }) async {
    var query = supabase.from('postings').select().eq('junkshop_id', junkshopId);
    if (statuses != null) query = query.inFilter('status', statuses);
    final rows = await query;
    return JSnap(_wrap('postings', rows));
  }

  /// Paid household collections (`status='completed' and is_reviewed`) of this
  /// junkshop; replaces the old `junkshops/{id}/collections` copy. The docs get
  /// legacy fields `householdName`, `collectorName`, `completedAt`, `purchasedItems`
  /// (as a plain list).
  static Future<JSnap> collections(
    String junkshopId, {
    DateTime? from,
    DateTime? to,
    String dateColumn = 'reviewed_at',
  }) async {
    var query = supabase
        .from('postings')
        .select()
        .eq('junkshop_id', junkshopId)
        .eq('status', 'completed')
        .eq('is_reviewed', true);
    if (from != null) {
      query = query.gte(dateColumn, from.toUtc().toIso8601String());
    }
    if (to != null) {
      query = query.lte(dateColumn, to.toUtc().toIso8601String());
    }
    final rows = await query;
    return JSnap(
      rowsToDocs('postings', rows).map((d) {
        final purchased = d['purchasedItems'];
        d['purchasedItems'] = purchased is Map
            ? (purchased['list'] ?? [])
            : (purchased ?? []);
        final household = d['household'];
        if (household is Map) {
          d['householdName'] ??= household['full_name'] ?? household['name'];
          d['householdProfileImage'] ??= household['profile_image_url'];
        }
        final collector = d['collector'];
        if (collector is Map) {
          d['collectorName'] ??= collector['full_name'] ?? collector['name'];
          d['collectorProfileImage'] ??= collector['profile_image_url'];
        }
        return JDoc(d);
      }).toList(),
    );
  }

  static List<JDoc> _wrap(String table, List<dynamic> rows) {
    return rowsToDocs(table, rows).map((d) {
      if (table == 'purchases') {
        // legacy field aliases used by older report code
        d['date'] = d['createdAt'];
        d['timestamp'] = d['createdAt'];
        d['purchasedAt'] = d['createdAt'];
        d['totalPrice'] ??= d['totalAmount'];
      } else if (table == 'postings') {
        final collector = d['collector'];
        if (collector is Map) {
          d['collectorName'] ??= collector['full_name'] ?? collector['name'];
        }
        final household = d['household'];
        if (household is Map) {
          d['householdName'] ??= household['full_name'] ?? household['name'];
        }
      }
      return JDoc(d);
    }).toList();
  }
}
