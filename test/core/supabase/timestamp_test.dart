import 'package:ecokuha/core/supabase/timestamp.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Timestamp', () {
    test('round-trips DateTime and ISO strings', () {
      final d = DateTime.utc(2026, 10, 10, 12, 30, 45, 123);
      final ts = Timestamp.fromDate(d);
      expect(ts.toDate().toUtc(), d);
      expect(Timestamp.tryParse(ts.toIso8601String()), ts);
    });

    test('tryParse handles null, empty and invalid input', () {
      expect(Timestamp.tryParse(null), isNull);
      expect(Timestamp.tryParse(''), isNull);
      expect(Timestamp.tryParse('not a date'), isNull);
    });

    test('compares and sorts chronologically', () {
      final a = Timestamp.fromDate(DateTime.utc(2026, 1, 1));
      final b = Timestamp.fromDate(DateTime.utc(2026, 1, 2));
      expect(a.compareTo(b), isNegative);
      expect([b, a]..sort(), [a, b]);
      expect(a == Timestamp.fromDate(DateTime.utc(2026, 1, 1)), isTrue);
    });
  });

  group('toDateTime / toIsoString', () {
    final d = DateTime.utc(2026, 5, 4, 3, 2, 1);

    test('accepts every supported input type', () {
      expect(toDateTime(d), d);
      expect(toDateTime(Timestamp.fromDate(d))!.toUtc(), d);
      expect(toDateTime('2026-05-04T03:02:01Z')!.toUtc(), d);
      expect(toDateTime(d.millisecondsSinceEpoch)!.toUtc(), d);
      expect(toDateTime(null), isNull);
      expect(toDateTime(<String, dynamic>{}), isNull);
    });

    test('toIsoString always returns UTC', () {
      expect(toIsoString(d), '2026-05-04T03:02:01.000Z');
      expect(toIsoString(null), isNull);
    });
  });
}
