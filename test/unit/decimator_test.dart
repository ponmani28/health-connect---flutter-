import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_connect/core/decimator.dart';
import 'package:health_connect/data/models/chart_point.dart';

void main() {
  List<ChartPoint> generateSeries(int count, {double base = 100, double step = 5}) {
    final start = DateTime(2026, 1, 1, 12, 0, 0);
    return List.generate(count, (i) {
      return ChartPoint(
        timestamp: start.add(Duration(minutes: i)),
        value: base + sin(i * 0.5) * 20 + (i * step) % 30,
      );
    });
  }

  group('LTTBDecimator', () {
    const decimator = LTTBDecimator();

    test('returns unchanged when below threshold', () {
      final points = generateSeries(10);
      final result = decimator.decimate(points, 50);
      expect(result.points.length, 10);
      expect(result.originalCount, 10);
    });

    test('decimates when above threshold', () {
      final points = generateSeries(1000);
      final result = decimator.decimate(points, 100);
      expect(result.points.length, 100);
      expect(result.originalCount, 1000);
    });

    test('preserves first and last points', () {
      final points = generateSeries(500);
      final result = decimator.decimate(points, 50);
      expect(result.points.first, points.first);
      expect(result.points.last, points.last);
    });

    test('handles empty list', () {
      final result = decimator.decimate([], 10);
      expect(result.points, isEmpty);
      expect(result.originalCount, 0);
    });

    test('threshold of 3 minimum works correctly', () {
      final points = generateSeries(100);
      final result = decimator.decimate(points, 3);
      expect(result.points.length, greaterThanOrEqualTo(3));
    });
  });

  group('BucketAveragingDecimator', () {
    const decimator = BucketAveragingDecimator();

    test('returns unchanged when below threshold', () {
      final points = generateSeries(5);
      final result = decimator.decimate(points, 10);
      expect(result.points.length, 5);
    });

    test('averages values within buckets', () {
      final points = <ChartPoint>[
        ChartPoint(
          timestamp: DateTime(2026, 1, 1, 12, 0),
          value: 10,
        ),
        ChartPoint(
          timestamp: DateTime(2026, 1, 1, 12, 1),
          value: 20,
        ),
        ChartPoint(
          timestamp: DateTime(2026, 1, 1, 12, 2),
          value: 30,
        ),
        ChartPoint(
          timestamp: DateTime(2026, 1, 1, 12, 3),
          value: 40,
        ),
      ];
      final result = decimator.decimate(points, 2);
      expect(result.points.length, 2);
      expect(result.points.first.value, closeTo(15, 0.001));
      expect(result.points.last.value, closeTo(35, 0.001));
    });
  });

  group('ChartMathUtils.findNearest', () {
    test('finds nearest point by x position', () {
      final points = <ChartPoint>[
        ChartPoint(
          timestamp: DateTime(2026, 1, 1, 12, 0),
          value: 10,
        ),
        ChartPoint(
          timestamp: DateTime(2026, 1, 1, 12, 10),
          value: 20,
        ),
        ChartPoint(
          timestamp: DateTime(2026, 1, 1, 12, 20),
          value: 30,
        ),
      ];
      final rect = Rect.fromLTRB(10, 0, 210, 100);

      final middle = ChartMathUtils.findNearest(
        points,
        const Offset(110, 50),
        rect,
        minTime: DateTime.fromMillisecondsSinceEpoch(
          DateTime(2026, 1, 1, 11, 59).millisecondsSinceEpoch,
        ),
        maxTime: DateTime.fromMillisecondsSinceEpoch(
          DateTime(2026, 1, 1, 12, 21).millisecondsSinceEpoch,
        ),
        minValue: 5,
        maxValue: 35,
      );

      expect(middle, isNotNull);
      expect(middle!.value, 20);
    });

    test('returns null for empty points', () {
      final nearest = ChartMathUtils.findNearest(
        [],
        const Offset(50, 50),
        Rect.fromLTWH(0, 0, 100, 100),
        minTime: DateTime(2026),
        maxTime: DateTime(2026, 1, 2),
        minValue: 0,
        maxValue: 100,
      );
      expect(nearest, isNull);
    });
  });
}