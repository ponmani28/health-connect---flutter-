import 'package:flutter_test/flutter_test.dart';
import 'package:health_connect/data/models/health_event.dart';
import 'package:health_connect/data/repositories/health_repository.dart';

void main() {
  group('HealthEvent deduplication', () {
    test('events with same recordId are de-duplicated', () async {
      final repository = HealthRepository();
      final now = DateTime(2026, 1, 1, 12, 0, 0);

      final event1 = HealthEvent(
        type: HealthEventType.steps,
        timestamp: now,
        value: 50,
        sourceId: 'source_a',
        recordId: 'rec_1',
      );
      final event2 = HealthEvent(
        type: HealthEventType.steps,
        timestamp: now.add(const Duration(seconds: 5)),
        value: 40,
        sourceId: 'source_a',
        recordId: 'rec_1',
      );

      repository.injectEventsForTest([event1, event2]);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      repository.flushForTest();

      expect(repository.stepsEventsCount, 1);

      repository.dispose();
    });

    test('different recordIds are both kept', () async {
      final repository = HealthRepository();
      repository.injectEventsForTest([
        HealthEvent(
          type: HealthEventType.steps,
          timestamp: DateTime(2026, 1, 1, 12, 0, 0),
          value: 50,
          sourceId: 'source_a',
          recordId: 'rec_1',
        ),
        HealthEvent(
          type: HealthEventType.steps,
          timestamp: DateTime(2026, 1, 1, 12, 0, 5),
          value: 40,
          sourceId: 'source_a',
          recordId: 'rec_2',
        ),
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      repository.flushForTest();

      expect(repository.stepsEventsCount, 2);

      repository.dispose();
    });

    test('empty recordIds are not de-duplicated', () async {
      final repository = HealthRepository();
      repository.injectEventsForTest([
        HealthEvent(
          type: HealthEventType.heartRate,
          timestamp: DateTime(2026, 1, 1, 12, 0, 0),
          value: 72,
          sourceId: 'source_a',
          recordId: '',
        ),
        HealthEvent(
          type: HealthEventType.heartRate,
          timestamp: DateTime(2026, 1, 1, 12, 0, 6),
          value: 74,
          sourceId: 'source_a',
          recordId: '',
        ),
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      repository.flushForTest();

      expect(repository.heartRateEventsCount, 2);

      repository.dispose();
    });
  });

  group('Event coalescing', () {
    test('multiple events within debounce window are flushed together', () async {
      final repository = HealthRepository();

      final now = DateTime(2026, 1, 1, 12, 0, 0);
      repository.startTestOnly();

      for (var i = 0; i < 10; i++) {
        repository.injectForTest(HealthEvent(
          type: HealthEventType.steps,
          timestamp: now.add(Duration(seconds: i)),
          value: 10.0,
          sourceId: 'coalesce_test',
          recordId: 'coalesce_$i',
        ));
        await Future<void>.delayed(const Duration(milliseconds: 30));
      }

      await Future<void>.delayed(const Duration(milliseconds: 400));
      repository.flushForTest();

      expect(repository.stepsEventsCount, 10);

      repository.dispose();
    });
  });

  group('HealthEvent.fromMap mapping', () {
    test('maps steps event map correctly', () {
      final event = HealthEvent.fromMap({
        'type': 'steps',
        'timestamp': 1767240000000,
        'value': 123.0,
        'sourceId': 'test_app',
        'recordId': 'abc123',
      });

      expect(event.type, HealthEventType.steps);
      expect(event.value, 123.0);
      expect(event.sourceId, 'test_app');
      expect(event.recordId, 'abc123');
      expect(
        event.timestamp,
        DateTime.fromMillisecondsSinceEpoch(1767240000000),
      );
    });

    test('maps heart rate event map correctly', () {
      final event = HealthEvent.fromMap({
        'type': 'heartRate',
        'timestamp': 1767240000000,
        'value': 85.0,
        'sourceId': 'fitbit',
        'recordId': 'hr1',
      });

      expect(event.type, HealthEventType.heartRate);
      expect(event.value, 85.0);
      expect(event.recordId, 'hr1');
    });

    test('round-trips through toMap', () {
      final original = HealthEvent(
        type: HealthEventType.heartRate,
        timestamp: DateTime(2026, 3, 5, 14, 30),
        value: 88.0,
        sourceId: 'src',
        recordId: 'r1',
      );

      final mapped = HealthEvent.fromMap(original.toMap());

      expect(mapped.type, original.type);
      expect(mapped.value, original.value);
      expect(mapped.timestamp, original.timestamp);
      expect(mapped.sourceId, original.sourceId);
      expect(mapped.recordId, original.recordId);
    });
  });
}