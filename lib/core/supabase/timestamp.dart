/// Lightweight timestamp value used by document-shaped maps returned from
/// `doc_mapper.dart`. It keeps the `.toDate()` call style the UI code already
/// uses, but has no dependency on any backend SDK.
class Timestamp implements Comparable<Timestamp> {
  const Timestamp(this.seconds, this.nanoseconds);

  final int seconds;
  final int nanoseconds;

  factory Timestamp.now() => Timestamp.fromDate(DateTime.now());

  factory Timestamp.fromDate(DateTime date) {
    final micros = date.microsecondsSinceEpoch;
    return Timestamp(micros ~/ 1000000, (micros % 1000000) * 1000);
  }

  factory Timestamp.fromMillisecondsSinceEpoch(int ms) =>
      Timestamp.fromDate(DateTime.fromMillisecondsSinceEpoch(ms));

  factory Timestamp.fromMicrosecondsSinceEpoch(int us) =>
      Timestamp.fromDate(DateTime.fromMicrosecondsSinceEpoch(us));

  /// Parses an ISO-8601 string (what Postgres/PostgREST returns).
  static Timestamp? tryParse(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    final d = DateTime.tryParse(iso);
    return d == null ? null : Timestamp.fromDate(d);
  }

  DateTime toDate() =>
      DateTime.fromMicrosecondsSinceEpoch(seconds * 1000000 + nanoseconds ~/ 1000);

  int get millisecondsSinceEpoch => seconds * 1000 + nanoseconds ~/ 1000000;
  int get microsecondsSinceEpoch => seconds * 1000000 + nanoseconds ~/ 1000;

  /// ISO-8601 in UTC, safe to send to Postgres.
  String toIso8601String() => toDate().toUtc().toIso8601String();

  /// Lets `jsonEncode` serialise a Timestamp stored inside a nested map.
  String toJson() => toIso8601String();

  @override
  int compareTo(Timestamp other) => microsecondsSinceEpoch.compareTo(other.microsecondsSinceEpoch);

  @override
  bool operator ==(Object other) => other is Timestamp && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(seconds, nanoseconds);

  @override
  String toString() => toIso8601String();
}

/// Converts any date-like value (Timestamp, DateTime, ISO string, epoch ms)
/// to a [DateTime], or null.
DateTime? toDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is Timestamp) return value.toDate();
  if (value is String) return DateTime.tryParse(value);
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  return null;
}

/// Converts any date-like value to an ISO-8601 UTC string, or null.
String? toIsoString(dynamic value) =>
    toDateTime(value)?.toUtc().toIso8601String();
