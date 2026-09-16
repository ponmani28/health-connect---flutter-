import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_connect/data/models/chart_point.dart';
import 'package:health_connect/presentation/widgets/chart_painter.dart';

void main() {
  final now = DateTime(2026, 1, 1, 12, 0, 30);

  List<ChartPoint> generateHeartRateSeries({int count = 40}) {
    return List.generate(count, (i) {
      return ChartPoint(
        timestamp: now.subtract(Duration(minutes: count - i)),
        value: 68.0 + (i % 7) * 3.5 + (i.isEven ? 4.0 : -2.0),
      );
    });
  }

  List<ChartPoint> generateStepsSeries({int count = 10}) {
    var cumulative = 0.0;
    return List.generate(count, (i) {
      cumulative += 150 + (i % 5) * 40;
      return ChartPoint(
        timestamp: now.subtract(Duration(minutes: count - i)),
        value: cumulative,
      );
    });
  }

  Widget buildChart({
    required List<ChartPoint> points,
    required Color lineColor,
    required Color areaColor,
    required String title,
    required double viewportStartMs,
    required double viewportEndMs,
    double minValue = 0,
    double maxValue = 120,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: RepaintBoundary(
          child: CustomPaint(
            size: const Size(320, 240),
            painter: ChartPainter(
              points: points,
              lineColor: lineColor,
              areaColor: areaColor,
              gridColor: Colors.grey.withValues(alpha: 0.3),
              axisTextColor: Colors.grey,
              title: title,
              unit: 'units',
              highlightedPoint: null,
              viewportStartMs: viewportStartMs,
              viewportEndMs: viewportEndMs,
              minValue: minValue,
              maxValue: maxValue,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('heart rate chart renders with fixed dataset',
      (tester) async {
    final series = generateHeartRateSeries();
    final vpStart =
        series.first.timestamp.millisecondsSinceEpoch.toDouble();
    final vpEnd = series.last.timestamp.millisecondsSinceEpoch.toDouble();

    await tester.pumpWidget(buildChart(
      points: series,
      lineColor: Colors.red,
      areaColor: Colors.red.withValues(alpha: 0.15),
      title: 'Heart Rate',
      viewportStartMs: vpStart,
      viewportEndMs: vpEnd,
      minValue: 55,
      maxValue: 110,
    ));

    await expectLater(
      find.byType(CustomPaint),
      matchesGoldenFile('goldens/heart_rate_chart.png'),
    );
  });

  testWidgets('steps chart with tooltip highlight renders correctly',
      (tester) async {
    final series = generateStepsSeries();
    final vpStart =
        series.first.timestamp.millisecondsSinceEpoch.toDouble();
    final vpEnd = series.last.timestamp.millisecondsSinceEpoch.toDouble();

    await tester.pumpWidget(buildChart(
      points: series,
      lineColor: Colors.blue,
      areaColor: Colors.blue.withValues(alpha: 0.15),
      title: 'Step Count',
      viewportStartMs: vpStart,
      viewportEndMs: vpEnd,
      minValue: 0,
      maxValue: 5000,
    ));

    await expectLater(
      find.byType(CustomPaint),
      matchesGoldenFile('goldens/steps_chart.png'),
    );
  });
}