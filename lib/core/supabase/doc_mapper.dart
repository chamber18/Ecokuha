import 'timestamp.dart';

/// Converts between Postgres rows (snake_case columns) and the "document"
/// maps (legacy Firestore field names) that the existing UI/BLoC code reads.
///
///   rowToDoc('postings', row)  -> {'householdId': ..., 'dateOfCollection': Timestamp, ...}
///   docToRow('postings', doc)  -> {'household_id': ..., 'date_of_collection': '2026-..Z', ...}
///
/// * Keys that have no column are stored in the table's `extra` jsonb column.
/// * `extra` keys are flattened back into the document on read.
/// * Timestamps: columns listed in [_Table.iso] come back as ISO strings
///   (matching how Firestore stored them for user profiles); every other
///   timestamptz column comes back as a [Timestamp].
/// * Nested jsonb values (items, household, junkshop, ...) pass through
///   untouched; nested date strings are NOT converted. Use [toDateTime].

class _Table {
  const _Table({
    this.camel = false,
    this.keys = const {},
    this.iso = const {},
    this.times = const {},
    this.hasExtra = false,
  });

  /// Default legacy key = camelCase(column) when true, column name when false.
  final bool camel;

  /// column -> [primaryKey, ...aliases]. Aliases are emitted on read and
  /// accepted on write.
  final Map<String, List<String>> keys;

  /// timestamptz columns returned as ISO strings.
  final Set<String> iso;

  /// timestamptz columns returned as [Timestamp].
  final Set<String> times;

  final bool hasExtra;
}

const _userTimesIso = {'created_at', 'updated_at', 'last_login_at', 'approved_at', 'rejected_at'};

const Map<String, _Table> _tables = {
  'households': _Table(
    hasExtra: true,
    iso: _userTimesIso,
    times: {'stats_updated_at'},
    keys: {
      'profile_image_url': ['profile_image_url', 'profileImageUrl', 'profilePictureUrl'],
      'is_active': ['isActive', 'is_active'],
      'is_email_verified': ['is_email_verified', 'emailVerified'],
      'is_profile_complete': ['is_profile_complete', 'profileComplete'],
      'sign_in_provider': ['signInProvider', 'sign_in_provider'],
      'created_at': ['created_at', 'createdAt'],
      'updated_at': ['updated_at', 'updatedAt'],
      'last_login_at': ['last_login_at', 'lastLoginAt'],
    },
  ),
  'junkshops': _Table(
    hasExtra: true,
    iso: _userTimesIso,
    keys: {
      'profile_image_url': ['profile_image_url', 'profileImageUrl'],
      'is_active': ['isActive', 'is_active'],
      'is_verified': ['isVerified', 'is_verified'],
      'is_email_verified': ['is_email_verified', 'emailVerified'],
      'is_profile_complete': ['is_profile_complete', 'profileComplete'],
      'sign_in_provider': ['signInProvider', 'sign_in_provider'],
      'blocked_households': ['blockedHouseholds'],
      'service_radius': ['serviceRadius', 'service_radius'],
      'average_rating': ['averageRating'],
      'total_ratings': ['totalRatings'],
      'sum_of_ratings': ['sumOfRatings'],
      'business_name': ['business_name', 'businessName', 'name'],
      'created_at': ['created_at', 'createdAt'],
      'updated_at': ['updated_at', 'updatedAt'],
      'last_login_at': ['last_login_at', 'lastLoginAt'],
    },
  ),
  'collectors': _Table(
    hasExtra: true,
    iso: _userTimesIso,
    times: {'fired_at', 'last_active'},
    keys: {
      'profile_image_url': ['profile_image_url', 'profileImageUrl'],
      'is_active': ['isActive', 'is_active'],
      'is_email_verified': ['is_email_verified', 'emailVerified'],
      'is_profile_complete': ['is_profile_complete', 'profileComplete'],
      'sign_in_provider': ['signInProvider', 'sign_in_provider'],
      'preferred_junkshop_id': ['preferred_junkshop_id', 'assigned_junkshop_id', 'assignedJunkshopId'],
      'average_rating': ['averageRating', 'rating'],
      'total_ratings': ['totalRatings'],
      'sum_of_ratings': ['sumOfRatings'],
      'created_at': ['created_at', 'createdAt'],
      'updated_at': ['updated_at', 'updatedAt'],
      'last_login_at': ['last_login_at', 'lastLoginAt'],
    },
  ),
  'junkshop_materials': _Table(
    camel: true,
    times: {'created_at', 'updated_at'},
  ),
  'material_templates': _Table(
    camel: true,
    times: {'created_at', 'updated_at'},
  ),
  'purchases': _Table(
    camel: true,
    times: {'created_at'},
    keys: {
      'customer_name': ['customer_name', 'customerName'],
    },
  ),
  'sales': _Table(
    camel: true,
    times: {'created_at'},
    keys: {
      'buyer': ['buyer', 'customerName'],
    },
  ),
  'activity_logs': _Table(
    camel: true,
    times: {'created_at'},
    keys: {
      'created_at': ['timestamp', 'createdAt'],
    },
  ),
  'junkshop_logs': _Table(
    camel: true,
    times: {'created_at'},
    keys: {
      'created_at': ['timestamp', 'createdAt'],
    },
  ),
  'promotions': _Table(
    camel: true,
    times: {'start_date', 'end_date', 'created_at', 'updated_at'},
  ),
  'postings': _Table(
    camel: true,
    hasExtra: true,
    times: {
      'scheduled_date', 'date_of_collection', 'assigned_at', 'collector_failed_at', 'rating_deadline',
      'completed_at', 'collected_at', 'verified_at', 'reviewed_at', 'created_at', 'updated_at',
    },
    keys: {
      'id': ['id', 'postingId'],
      'junkshop_id': ['junkshopId', 'assignedJunkshopId'],
      'collector_id': ['collectorId', 'assignedCollectorId'],
    },
  ),
  'active_collections': _Table(
    camel: true,
    times: {'estimated_arrival', 'started_at', 'updated_at', 'last_updated'},
    keys: {
      'posting_id': ['postingId'],
    },
  ),
  'ratings': _Table(
    camel: true,
    times: {'created_at'},
    keys: {
      'target_type': ['type'],
      'rating': ['rating', 'overallRating'],
    },
  ),
  'leaderboard_rankings': _Table(
    times: {'updated_at'},
    keys: {
      'user_id': ['userId', 'user_id'],
    },
  ),
  'conversations': _Table(
    camel: true,
    times: {
      'last_message_timestamp', 'deletion_scheduled_at', 'deletion_due_at', 'created_at', 'updated_at',
    },
    keys: {
      'last_message_timestamp': ['lastMessageTimestamp', 'lastMessageTime'],
    },
  ),
  'messages': _Table(
    camel: true,
    times: {'created_at'},
    keys: {
      'created_at': ['timestamp', 'createdAt'],
      'conversation_id': ['conversationId'],
    },
  ),
};

String _camel(String snake) {
  final parts = snake.split('_');
  return parts.first +
      parts.skip(1).map((p) => p.isEmpty ? '' : p[0].toUpperCase() + p.substring(1)).join();
}

List<String> _keysFor(_Table t, String col) {
  final explicit = t.keys[col];
  if (explicit != null) return explicit;
  return [t.camel ? _camel(col) : col];
}

dynamic _encode(dynamic v) {
  if (v is Timestamp) return v.toIso8601String();
  if (v is DateTime) return v.toUtc().toIso8601String();
  if (v is Map) return v.map((k, val) => MapEntry(k.toString(), _encode(val)));
  if (v is Iterable) return v.map(_encode).toList();
  return v;
}

/// Row (snake_case, as returned by supabase) -> document map (legacy keys).
Map<String, dynamic> rowToDoc(String table, Map<String, dynamic> row) {
  final t = _tables[table] ?? const _Table();
  final doc = <String, dynamic>{};
  Map<String, dynamic>? extra;

  row.forEach((col, value) {
    if (col == 'extra' && t.hasExtra) {
      if (value is Map) extra = Map<String, dynamic>.from(value);
      return;
    }
    dynamic out = value;
    if (value is String && t.iso.contains(col)) {
      out = value; // keep ISO string
    } else if (t.times.contains(col)) {
      out = value is String ? Timestamp.tryParse(value) : value;
    } else if (value is List && col == 'unavailable_dates') {
      out = value
          .map((e) => e is String ? Timestamp.tryParse(e) : e)
          .whereType<Object>()
          .toList();
    }
    for (final k in _keysFor(t, col)) {
      doc[k] = out;
    }
  });

  extra?.forEach((k, v) => doc.putIfAbsent(k, () => v));
  return doc;
}

/// Document map (legacy keys) -> row for insert/update.
///
/// [forUpdate]: when false, null values are dropped so column defaults apply.
Map<String, dynamic> docToRow(
  String table,
  Map<String, dynamic> doc, {
  bool forUpdate = true,
}) {
  final t = _tables[table] ?? const _Table();

  // reverse lookup: legacy key -> column (primary keys win over aliases)
  final reverse = <String, String>{};
  final allCols = <String>{...t.keys.keys, ...t.iso, ...t.times};
  for (final col in allCols) {
    for (final k in _keysFor(t, col)) {
      reverse.putIfAbsent(k, () => col);
    }
  }

  final row = <String, dynamic>{};
  final extra = <String, dynamic>{};

  doc.forEach((key, value) {
    final col = reverse[key] ?? (t.camel ? _snake(key) : key);
    if (_knownColumns[table]?.contains(col) ?? true) {
      if (value == null && !forUpdate) return;
      row[col] = _encode(value);
    } else if (t.hasExtra) {
      if (value != null) extra[key] = _encode(value);
    }
  });

  if (extra.isNotEmpty) row['extra'] = extra;
  return row;
}

String _snake(String camel) => camel.replaceAllMapped(
      RegExp(r'[A-Z]'),
      (m) => '_${m[0]!.toLowerCase()}',
    );

/// Columns that exist per table (used to route unknown keys to `extra`).
/// Tables not listed accept any key.
const Map<String, Set<String>> _knownColumns = {
  'households': {
    'id', 'email', 'full_name', 'phone', 'date_of_birth', 'profile_image_url', 'role', 'city', 'location',
    'location_2', 'is_active', 'is_email_verified', 'is_profile_complete', 'application_status',
    'last_login_at', 'sign_in_provider', 'total_collections', 'total_earnings', 'total_recycled_kg',
    'carbon_offset', 'stats_updated_at', 'created_at', 'updated_at',
  },
  'junkshops': {
    'id', 'email', 'full_name', 'business_name', 'phone', 'profile_image_url', 'role', 'junkshop_profile',
    'settings', 'service_radius', 'latitude', 'longitude', 'blocked_households', 'is_active', 'is_verified',
    'is_email_verified', 'is_profile_complete', 'application_status', 'last_login_at', 'sign_in_provider',
    'average_rating', 'total_ratings', 'sum_of_ratings', 'created_at', 'updated_at',
  },
  'collectors': {
    'id', 'email', 'full_name', 'phone', 'profile_image_url', 'role', 'collector_profile',
    'application_status', 'application_attempts', 'approved_at', 'rejected_at', 'rejection_reason',
    'fired_at', 'preferred_junkshop_id', 'partner_junkshop_id', 'status', 'active_jobs', 'vehicle_type',
    'last_active', 'is_active', 'is_email_verified', 'is_profile_complete', 'last_login_at',
    'sign_in_provider', 'average_rating', 'total_ratings', 'sum_of_ratings', 'created_at', 'updated_at',
  },
  'postings': {
    'id', 'household_id', 'junkshop_id', 'collector_id', 'status', 'items', 'verified_items',
    'purchased_items', 'photos', 'household', 'junkshop', 'collector', 'location', 'unavailable_dates',
    'special_instructions', 'notes', 'conversation_id', 'scheduled_date', 'scheduled_time',
    'date_of_collection', 'assigned_at', 'collection_fee', 'post_attempt', 'declines', 'previous_collector',
    'collector_failure_reason', 'collector_failed_at', 'reschedule', 'cancellation', 'is_reviewed',
    'total_estimated_value', 'total_verified_value', 'estimated_total_weight', 'household_payment_amount',
    'total_collector_paid', 'total_junkshop_cost', 'profit', 'is_rated', 'is_collector_rated',
    'is_junkshop_rated', 'collector_rating', 'junkshop_rating', 'collector_rating_data',
    'junkshop_rating_data', 'rating_data', 'rating_deadline', 'completed_at', 'collected_at', 'verified_at',
    'reviewed_at', 'created_by', 'created_at', 'updated_at',
  },
};
