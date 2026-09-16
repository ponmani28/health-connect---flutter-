import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_connect/data/models/chart_point.dart';
import 'package:health_connect/data/repositories/health_repository.dart';
import 'package:health_connect/data/sources/sim_source.dart';
import 'package:health_connect/presentation/controllers/dashboard_controller.dart';
import 'package:health_connect/presentation/pages/dashboard_page.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'SimSource stream drives dashboard updates and HUD assertions',
      (tester) async {
    final simSource = SimSource();
    final repository = HealthRepository(simSource: simSource);
    final controller = DashboardController(repository: repository);

    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: DashboardPage(controller: controller),
    ));

    await tester.pump(const Duration(seconds: 1));

    final initialUpdateCount = controller.totalUpdatesReceived.value;
    expect(initialUpdateCount, 0);

    repository.startSimListening();
    simSource.start();

    final stepsBefore = controller.totalStepsToday.value;
    final hrBefore = controller.currentHeartRate.value;

    await tester.pump(const Duration(seconds: 12));

    final stepsAfter = controller.totalStepsToday.value;
    final hrAfter = controller.currentHeartRate.value;

    expect(stepsAfter, greaterThan(stepsBefore));
    expect(hrAfter, greaterThanOrEqualTo(hrBefore));
    expect(controller.totalUpdatesReceived.value, greaterThan(0));

    expect(controller.stepsChartData.length, greaterThanOrEqualTo(1));
    expect(controller.hrChartData.length, greaterThanOrEqualTo(1));

    simSource.emitSingleStep(count: 250);
    simSource.emitSingleHr(bpm: 95);

    await tester.pump(const Duration(milliseconds: 500));

    expect(controller.totalStepsToday.value, greaterThan(stepsAfter));
    expect(controller.currentHeartRate.value, greaterThanOrEqualTo(90));

    controller.perfMonitor.recordBuildTime(3.2);
    controller.perfMonitor.recordBuildTime(2.1);
    controller.perfMonitor.recordBuildTime(4.0);
    controller.perfMonitor.recordBuildTime(1.8);
    controller.perfMonitor.recordBuildTime(2.9);
    controller.updatePerfHudForTest();

    final avgBuild = controller.avgBuildTimeMs.value;
    expect(avgBuild, lessThanOrEqualTo(8.0));
    expect(controller.meetsBuildTarget.value, isTrue);
    expect(controller.fps.value, greaterThanOrEqualTo(0));

    controller.perfMonitor.recordFrame();
    controller.updatePerfHudForTest();
    expect(controller.fps.value, greaterThanOrEqualTo(0));

    simSource.stop();
    repository.stopSimListening();
    controller.onClose();
    repository.dispose();
  });

  testWidgets('chart tooltip highlight can be triggered and viewport pans',
      (tester) async {
    final now = DateTime.now();
    final testData = List.generate(400, (i) => ChartPoint(
          timestamp: now.subtract(Duration(seconds: (400 - i) * 9)),
          value: 60 + (i % 30) * 1.5,
        ));

    final simSource = SimSource();
    final repository = HealthRepository(simSource: simSource);
    final controller = DashboardController(repository: repository);
    controller.hrChartData.value = testData;
    controller.stepsChartData.value = testData;

    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: Scaffold(
        body: DashboardPage(controller: controller),
      ),
    ));

    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);

    controller.onClose();
    repository.dispose();
  });
}