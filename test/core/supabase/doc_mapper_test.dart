import 'package:ecokuha/core/supabase/doc_mapper.dart';
import 'package:ecokuha/core/supabase/timestamp.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('rowToDoc', () {
    test('households: ISO strings stay strings, legacy aliases are emitted', () {
      final doc = rowToDoc('households', {
        'id': 'u1',
        'full_name': 'Test User',
        'profile_image_url': 'https://x/y.jpg',
        'is_active': true,
        'created_at': '2026-10-10T00:00:00Z',
        'extra': {'customField': 7},
      });
      expect(doc['id'], 'u1');
      expect(doc['profileImageUrl'], 'https://x/y.jpg');
      expect(doc['profile_image_url'], 'https://x/y.jpg');
      expect(doc['isActive'], true);
      expect(doc['created_at'], '2026-10-10T00:00:00Z');
      expect(doc['customField'], 7, reason: 'extra keys are flattened');
    });

    test('messages: created_at becomes a Timestamp under "timestamp"', () {
      final doc = rowToDoc('messages', {
        'id': 'm1',
        'conversation_id': 'c1',
        'created_at': '2026-10-10T08:00:00Z',
      });
      expect(doc['timestamp'], isA<Timestamp>());
      expect(doc['conversationId'], 'c1');
      expect((doc['timestamp'] as Timestamp).toDate().toUtc(),
          DateTime.utc(2026, 10, 10, 8));
    });
  });

  group('docToRow', () {
    test('maps legacy keys to columns and encodes timestamps', () {
      final row = docToRow('messages', {
        'conversationId': 'c1',
        'timestamp': Timestamp.fromDate(DateTime.utc(2026, 1, 2, 3)),
      });
      expect(row['conversation_id'], 'c1');
      expect(row['created_at'], '2026-01-02T03:00:00.000Z');
    });

    test('unknown keys on tables with an extra column go to extra', () {
      final row = docToRow('households', {
        'full_name': 'A',
        'someLegacyField': 'keep me',
        'nullLegacy': null,
      });
      expect(row['full_name'], 'A');
      expect(row.containsKey('someLegacyField'), isFalse);
      expect(row['extra'], {'someLegacyField': 'keep me'});
    });

    test('forUpdate: false drops nulls so column defaults apply', () {
      final row = docToRow('households', {'full_name': null, 'phone': '09'},
          forUpdate: false);
      expect(row.containsKey('full_name'), isFalse);
      expect(row['phone'], '09');
    });
  });

  test('rowToDoc(docToRow(x)) keeps real columns for postings', () {
    final row = docToRow('postings', {
      'householdId': 'h1',
      'status': 'pending',
      'items': [
        {'name': 'PET', 'quantity': 2}
      ],
    });
    expect(row['household_id'], 'h1');
    final back = rowToDoc('postings', row);
    expect(back['householdId'], 'h1');
    expect(back['status'], 'pending');
    expect((back['items'] as List).first['name'], 'PET');
  });
}
