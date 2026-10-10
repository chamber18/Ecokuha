// ---------------------------------------------------------------------------
// UserCollectionHelper (Supabase)
//
// Resolves a user's row across the role tables `households`, `collectors`,
// `junkshops` (row id == auth uid). Data is returned "legacy shaped" via
// `rowToDoc` (Firestore field names; user timestamps are ISO strings).
//
// NEW API (all static, no FirebaseFirestore argument any more):
//
//   String tableForRole(String role)            // 'household' -> 'households', ...
//   String getCollectionForRole(String role)    // alias of tableForRole (returns the TABLE NAME)
//   String getSubcollectionPath(String role)    // alias of tableForRole
//   String? roleForTable(String table)          // 'collectors' -> 'collector'
//   Future<String?> findUserRole(String uid)    // 'household' | 'collector' | 'junkshop' | null
//   Future<Map<String,dynamic>?> findUserDoc(String uid)   // legacy-shaped doc (or null)
//   Future<Map<String,dynamic>?> getUserData(String uid)   // same as findUserDoc
//   Future<Map<String,dynamic>?> getUserDocData(String uid, String role)
//   Future<void> updateUserDoc(String uid, String role, Map<String,dynamic> data)
//   Future<void> setUserDoc(String uid, String role, Map<String,dynamic> data) // upsert
//   Future<UserDocRef?> findUserDocument(String uid)       // role unknown, null if none
//   UserDocRef getUserDocument(String userId, String role) // Firestore-like handle:
//        .get() -> Map? (legacy doc), .update(map), .set(map, merge: true), .exists()
//   Future<List<Map<String,dynamic>>> queryUsersByRole(String role)
//   String? getRoleFromData(Map? data)
//
// Migration notes for callers:
//   * `getUserDocument(firestore, uid, role)` -> `getUserDocument(uid, role)`; the
//     result is a `UserDocRef` (no DocumentSnapshot): `final data = await ref.get();`
//     (a Map or null instead of snapshot.data()); `ref.update({...})` takes legacy keys
//     (docToRow is applied; use null instead of FieldValue.delete()).
//   * `getCollectionForRole(firestore, role)` returned a CollectionReference; it now
//     returns the table name, use `supabase.from(UserCollectionHelper.getCollectionForRole(role))`
//     and snake_case column names in filters.
//   * `getUserData(firestore, uid)` -> `getUserData(uid)`.
//   * system managed `total_*` stat columns are never written by `update`/`set`.
// ---------------------------------------------------------------------------

import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase/supabase_helpers.dart' as sb;

/// Firestore-like handle to one user row.
class UserDocRef {
  UserDocRef(this.table, this.id, [SupabaseClient? client])
    : _client = client ?? sb.supabase;

  final String table;
  final String id;
  final SupabaseClient _client;

  /// Legacy-shaped doc or null when the row doesn't exist.
  Future<Map<String, dynamic>?> get() async {
    final row = await _client.from(table).select().eq('id', id).maybeSingle();
    if (row == null) return null;
    return sb.rowToDoc(table, Map<String, dynamic>.from(row));
  }

  Future<bool> exists() async {
    final row = await _client.from(table).select('id').eq('id', id).maybeSingle();
    return row != null;
  }

  /// Partial update using legacy keys (null clears a column). Dotted keys
  /// ('junkshop_profile.business.name') are merged into the stored jsonb;
  /// plain map values replace the column (Firestore update semantics).
  Future<void> update(Map<String, dynamic> data) async {
    final row = UserCollectionHelper._sanitize(
      table,
      sb.docToRow(table, await _prepare(data, mergeMaps: false)),
    );
    if (row.isEmpty) return;
    await _client.from(table).update(row).eq('id', id);
  }

  /// merge: true -> deep-merged partial write; creates the row when missing.
  Future<void> set(Map<String, dynamic> data, {bool merge = false}) async {
    if (merge && await exists()) {
      final row = UserCollectionHelper._sanitize(table, sb.docToRow(table, await _prepare(data)));
      row.remove('id');
      if (row.isNotEmpty) await _client.from(table).update(row).eq('id', id);
    } else {
      final row = UserCollectionHelper._sanitize(table, sb.docToRow(table, data));
      row['id'] = id;
      await _client.from(table).upsert(row);
    }
  }

  /// Expands dotted keys and deep-merges map values with the stored value.
  Future<Map<String, dynamic>> _prepare(
    Map<String, dynamic> data, {
    bool mergeMaps = true,
  }) async {
    final needsMerge = data.entries.any(
      (e) => e.key.contains('.') || (mergeMaps && e.value is Map),
    );
    if (!needsMerge) return data;
    final current = await get() ?? <String, dynamic>{};
    final out = <String, dynamic>{};
    data.forEach((key, value) {
      if (key.contains('.')) {
        final parts = key.split('.');
        final top = parts.first;
        final base = out[top] is Map
            ? Map<String, dynamic>.from(out[top] as Map)
            : (current[top] is Map
                  ? Map<String, dynamic>.from(current[top] as Map)
                  : <String, dynamic>{});
        var node = base;
        for (var i = 1; i < parts.length - 1; i++) {
          final next = node[parts[i]];
          node[parts[i]] = next is Map
              ? Map<String, dynamic>.from(next)
              : <String, dynamic>{};
          node = node[parts[i]] as Map<String, dynamic>;
        }
        node[parts.last] = value;
        out[top] = base;
      } else if (mergeMaps && value is Map && current[key] is Map) {
        out[key] = UserCollectionHelper._deepMerge(
          Map<String, dynamic>.from(current[key] as Map),
          Map<String, dynamic>.from(value),
        );
      } else {
        out[key] = value;
      }
    });
    return out;
  }

  Future<void> delete() async {
    await _client.from(table).delete().eq('id', id);
  }
}

/// Helper class to resolve user rows by role.
///
/// Tables: households / collectors / junkshops (id = auth uid).
class UserCollectionHelper {
  UserCollectionHelper._();

  static const String _householdsCollection = 'households';
  static const String _collectorsCollection = 'collectors';
  static const String _junkshopsCollection = 'junkshops';

  static const List<String> _tables = [
    _householdsCollection,
    _collectorsCollection,
    _junkshopsCollection,
  ];

  /// Columns that must never be written by the client.
  static const Set<String> _systemColumns = {
    'total_collections',
    'total_earnings',
    'total_recycled_kg',
    'carbon_offset',
    'stats_updated_at',
  };

  static Map<String, dynamic> _sanitize(String table, Map<String, dynamic> row) {
    final out = Map<String, dynamic>.from(row);
    out.removeWhere((k, _) => _systemColumns.contains(k));
    return out;
  }

  static Map<String, dynamic> _deepMerge(
    Map<String, dynamic> base,
    Map<String, dynamic> patch,
  ) {
    final out = Map<String, dynamic>.from(base);
    patch.forEach((k, v) {
      if (v is Map && out[k] is Map) {
        out[k] = _deepMerge(
          Map<String, dynamic>.from(out[k] as Map),
          Map<String, dynamic>.from(v),
        );
      } else {
        out[k] = v;
      }
    });
    return out;
  }

  /// Table name for a role.
  static String tableForRole(String role) {
    switch (role.toLowerCase()) {
      case 'household':
        return _householdsCollection;
      case 'collector':
        return _collectorsCollection;
      case 'junkshop':
        return _junkshopsCollection;
      default:
        throw ArgumentError('Invalid role: $role');
    }
  }

  /// Alias of [tableForRole] (returns the table name, not a collection ref).
  static String getCollectionForRole(String role) => tableForRole(role);

  /// Alias of [tableForRole].
  static String getSubcollectionPath(String role) => tableForRole(role);

  /// 'households' -> 'household', etc.
  static String? roleForTable(String table) {
    switch (table) {
      case _householdsCollection:
        return 'household';
      case _collectorsCollection:
        return 'collector';
      case _junkshopsCollection:
        return 'junkshop';
    }
    return null;
  }

  /// Handle for a user row when the role is known.
  static UserDocRef getUserDocument(String userId, String role) =>
      UserDocRef(tableForRole(role), userId);

  /// Handle for a user row when the role is unknown (households -> collectors
  /// -> junkshops). Null if the user has no row.
  static Future<UserDocRef?> findUserDocument(String userId) async {
    for (final table in _tables) {
      final ref = UserDocRef(table, userId);
      if (await ref.exists()) return ref;
    }
    return null;
  }

  /// Role ('household' | 'collector' | 'junkshop') of the user, or null.
  static Future<String?> findUserRole(String userId) async {
    final ref = await findUserDocument(userId);
    return ref == null ? null : roleForTable(ref.table);
  }

  /// Legacy-shaped user doc when the role is unknown.
  static Future<Map<String, dynamic>?> findUserDoc(String userId) async {
    for (final table in _tables) {
      final row = await sb.supabase
          .from(table)
          .select()
          .eq('id', userId)
          .maybeSingle();
      if (row != null) return sb.rowToDoc(table, Map<String, dynamic>.from(row));
    }
    return null;
  }

  /// Same as [findUserDoc].
  static Future<Map<String, dynamic>?> getUserData(String userId) =>
      findUserDoc(userId);

  /// Legacy-shaped user doc when the role is known.
  static Future<Map<String, dynamic>?> getUserDocData(String userId, String role) =>
      getUserDocument(userId, role).get();

  /// Partial update of the user's row (legacy keys; null clears a value).
  static Future<void> updateUserDoc(
    String userId,
    String role,
    Map<String, dynamic> data,
  ) => getUserDocument(userId, role).update(data);

  /// Upsert the user's row (legacy keys).
  static Future<void> setUserDoc(
    String userId,
    String role,
    Map<String, dynamic> data,
  ) => getUserDocument(userId, role).set(data);

  /// All users of a role as legacy-shaped docs.
  static Future<List<Map<String, dynamic>>> queryUsersByRole(String role) async {
    final table = tableForRole(role);
    final rows = await sb.supabase.from(table).select();
    return sb.rowsToDocs(table, rows);
  }

  /// Helper to determine role from user data
  static String? getRoleFromData(Map<String, dynamic>? data) {
    return data?['role']?.toString();
  }
}
