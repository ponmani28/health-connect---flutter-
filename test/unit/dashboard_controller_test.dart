import 'package:flutter_test/flutter_test.dart';
import 'package:health_connect/data/models/health_event.dart';
import 'package:health_connect/data/repositories/health_repository.dart';
import 'package:health_connect/presentation/controllers/dashboard_controller.dart';

void main() {
  late HealthRepository repository;
  late DashboardController controller;

  setUp(() {
    repository = HealthRepository();
    controller = DashboardController(repository: repository);
    controller.onInit();
  });

  tearDown(() {
    controller.onClose();
    repository.dispose();
  });

  group('DashboardController event mapping', () {
    test('steps events update totalStepsToday', () async {
      final now = DateTime.now();
      repository.injectEventsForTest([
        HealthEvent(
          type: HealthEventType.steps,
          timestamp: now.subtract(const Duration(minutes: 1)),
          value: 100,
          sourceId: 'test',
          recordId: 't1',
        ),
        HealthEvent(
          type: HealthEventType.steps,
          timestamp: now,
          value: 50,
          sourceId: 'test',
          recordId: 't2',
        ),
      ]);

      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(controller.totalStepsToday.value, 150);
      expect(controller.totalUpdatesReceived.value, 2);
      expect(controller.stepsChartData, isNotEmpty);
    });

    test('heart rate events update currentHeartRate and timestamp', () async {
      final now = DateTime.now();
      repository.injectEventsForTest([
        HealthEvent(
          type: HealthEventType.heartRate,
          timestamp: now.subtract(const Duration(minutes: 1)),
          value: 72,
          sourceId: 'test',
          recordId: 'hr1',
        ),
        HealthEvent(
          type: HealthEventType.heartRate,
          timestamp: now,
          value: 78,
          sourceId: 'test',
          recordId: 'hr2',
        ),
      ]);

      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(controller.currentHeartRate.value, 78);
      expect(controller.heartRateTimestamp.value, isNotNull);
      expect(controller.hrChartData, isNotEmpty);
    });

    test('mixed events update both state dimensions', () async {
      final now = DateTime.now();
      repository.injectEventsForTest([
        HealthEvent(
          type: HealthEventType.steps,
          timestamp: now,
          value: 300,
          sourceId: 'test',
          recordId: 's1',
        ),
        HealthEvent(
          type: HealthEventType.heartRate,
          timestamp: now,
          value: 90,
          sourceId: 'test',
          recordId: 'h1',
        ),
      ]);

      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(controller.totalStepsToday.value, 300);
      expect(controller.currentHeartRate.value, 90);
      expect(controller.totalUpdatesReceived.value, 2);
    });

    test('duplicate events do not increment update count', () async {
      final now = DateTime.now();
      final duplicateEvent = HealthEvent(
        type: HealthEventType.steps,
        timestamp: now,
        value: 55,
        sourceId: 'test',
        recordId: 'dedup',
      );

      repository.injectEventsForTest([duplicateEvent, duplicateEvent]);

      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(controller.totalUpdatesReceived.value, 1);
    });

    test('changing chart window brings in only recent events', () async {
      final now = DateTime.now();
      repository.injectEventsForTest([
        HealthEvent(
          type: HealthEventType.steps,
          timestamp: now,
          value: 10,
          sourceId: 'test',
          recordId: 'recent',
        ),
        HealthEvent(
          type: HealthEventType.steps,
          timestamp: now.subtract(const Duration(hours: 2)),
          value: 9999,
          sourceId: 'test',
          recordId: 'old',
        ),
      ]);

      await Future<void>.delayed(const Duration(milliseconds: 100));

      final stepsInWindow = repository
          .getStepsEventsInWindow(const Duration(minutes: 60))
          .length;
      expect(stepsInWindow, 1);
      expect(repository.stepsEventsCount, 2);
    });

    test('heartRateAge reflects data age', () async {
      final now = DateTime.now();
      repository.injectEventsForTest([
        HealthEvent(
          type: HealthEventType.heartRate,
          timestamp: now.subtract(const Duration(seconds: 10)),
          value: 70,
          sourceId: 'test',
          recordId: 'age1',
        ),
      ]);

      await Future<void>.delayed(const Duration(milliseconds: 100));
      controller.updateAgeForTest();

      expect(controller.heartRateAge.value, contains('s ago'));
    });

    test('loadTestData replaces events and updates cards', () async {
      final now = DateTime.now();
      final events = List.generate(50, (i) => HealthEvent(
            type: HealthEventType.steps,
            timestamp: now.subtract(Duration(minutes: i)),
            value: 10.0 + i,
            sourceId: 'test',
            recordId: 'load_$i',
          ));

      controller.loadTestData(events);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(controller.stepsChartData, isNotEmpty);
      expect(controller.totalUpdatesReceived.value, greaterThanOrEqualTo(1));
    });
  });
}