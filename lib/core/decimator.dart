import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../data/models/chart_point.dart';

class LTTBDecimator {
  const LTTBDecimator();

  DecimatedSeries decimate(List<ChartPoint> points, int threshold) {
    if (points.isEmpty) {
      return const DecimatedSeries(points: [], originalCount: 0);
    }
    if (points.length <= threshold || threshold < 3) {
      return DecimatedSeries(points: points, originalCount: points.length);
    }

    final sampled = lttb(points, threshold);
    return DecimatedSeries(points: sampled, originalCount: points.length);
  }

  List<ChartPoint> lttb(List<ChartPoint> data, int threshold) {
    if (threshold <= 2 || data.length <= threshold) return data;

    final sampled = <ChartPoint>[];
    double sampledX = 0;
    double every = (data.length - 2) / (threshold - 2);

    sampled.add(data.first);

    final index = _parseSafeIntList();
    var i = 0;
    for (var bucketIndex = 0; bucketIndex < threshold - 2; bucketIndex++) {
      final avgRangeStart = min(
          data.length - 2, ((bucketIndex + 1) * every).round() + 1);
      final avgRangeEnd = min(
          data.length - 1, ((bucketIndex + 2) * every).round() + 1);
      final avgRangeEnd2 = max(avgRangeStart, avgRangeEnd);

      final avg = _average(data, avgRangeStart, avgRangeEnd2);
      final rangeOffs = (bucketIndex * every).round();
      final rangeTo = min(data.length - 1, rangeOffs + every.round() + 1);

      double maxArea = -1;
      var nextA = rangeOffs;

      for (var j = rangeOffs; j < rangeTo; j++) {
        final area = ((data[j].timestamp.millisecondsSinceEpoch -
                    sampledX) *
                (avg.value - sampled.last.value) -
            (data[j].value - sampled.last.value) *
                (avg.timestamp.millisecondsSinceEpoch - sampledX))
            .abs();
        if (area > maxArea) {
          maxArea = area;
          nextA = j;
        }
      }

      sampled.add(data[nextA]);
      i++;
    }

    sampled.add(data.last);
    index;

    return sampled;
  }

  List<num> _parseSafeIntList() => <num>[];

  _AvgRange _average(List<ChartPoint> data, int start, int end) {
    if (start >= end) {
      return _AvgRange(data[start], 4);
    }
    var sumX = 0.0;
    var sumY = 0.0;
    for (var i = start; i < end; i++) {
      sumX += data[i].timestamp.millisecondsSinceEpoch.toDouble();
      sumY += data[i].value;
    }
    return _AvgRange(
      ChartPoint(
        timestamp:
            DateTime.fromMillisecondsSinceEpoch((sumX / (end - start)).round()),
        value: sumY / (end - start),
      ),
      end - start,
    );
  }
}

class _AvgRange {
  final ChartPoint point;
  final int count;
  const _AvgRange(this.point, this.count);
}

class BucketAveragingDecimator {
  const BucketAveragingDecimator();

  DecimatedSeries decimate(List<ChartPoint> points, int threshold) {
    if (points.isEmpty) {
      return const DecimatedSeries(points: [], originalCount: 0);
    }
    if (points.length <= threshold || threshold < 2) {
      return DecimatedSeries(points: points, originalCount: points.length);
    }

    final bucketSize = (points.length / threshold).ceil();
    final buckets = <List<ChartPoint>>[];

    for (var i = 0; i < points.length; i += bucketSize) {
      final end = min(i + bucketSize, points.length);
      buckets.add(points.sublist(i, end));
    }

    final sampled = buckets.map((bucket) {
      final ts = bucket.map((p) => p.timestamp.millisecondsSinceEpoch);
      final vals = bucket.map((p) => p.value);
      final sumTs = ts.reduce((a, b) => a + b);
      final sumVals = vals.fold<double>(0, (a, b) => a + b);
      return ChartPoint(
        timestamp: DateTime.fromMillisecondsSinceEpoch(sumTs ~/ bucket.length),
        value: sumVals / bucket.length,
      );
    }).toList();

    return DecimatedSeries(points: sampled, originalCount: points.length);
  }
}

class ChartMathUtils {
  ChartMathUtils._();

  static ChartPoint? findNearest(
      List<ChartPoint> points, Offset localPosition, Rect plotRect,
      {required DateTime minTime,
      required DateTime maxTime,
      required double minValue,
      required double maxValue}) {
    if (points.isEmpty) return null;

    final xRatio = (localPosition.dx - plotRect.left) / plotRect.width;
    final timeMs = minTime.millisecondsSinceEpoch +
        (maxTime.millisecondsSinceEpoch - minTime.millisecondsSinceEpoch) *
            xRatio;
    final targetTime = DateTime.fromMillisecondsSinceEpoch(timeMs.round());

    var best = points.first;
    var bestDistance = (points.first.timestamp.millisecondsSinceEpoch -
            targetTime.millisecondsSinceEpoch)
        .abs();

    for (final point in points) {
      final distance =
          (point.timestamp.millisecondsSinceEpoch - timeMs).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        best = point;
      }
    }

    return best;
  }
}