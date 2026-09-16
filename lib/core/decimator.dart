import 'dart:math';
import 'dart:ui';
import '../data/models/chart_point.dart';

class LTTBDecimator {
  const LTTBDecimator();

  DecimatedSeries decimate(
      List<ChartPoint> points, int threshold) {
    if (points.isEmpty) {
      return const DecimatedSeries(points: [], originalCount: 0);
    }
    if (points.length <= threshold || threshold < 3) {
      return DecimatedSeries(points: points, originalCount: points.length);
    }
    return DecimatedSeries(
      points: lttb(points, threshold),
      originalCount: points.length,
    );
  }

  List<ChartPoint> lttb(List<ChartPoint> data, int threshold) {
    final sampled = <ChartPoint>[data.first];
    final every = (data.length - 2) / (threshold - 2);

    for (var bucketIndex = 0; bucketIndex < threshold - 2; bucketIndex++) {
      final avgRangeStart =
          max(1, ((bucketIndex + 1) * every).floor());
      final avgRangeEnd = min(data.length - 1, ((bucketIndex + 2) * every).floor() + 1);
      final avgStart = max(avgRangeStart, avgRangeEnd - 1);

      var avgX = 0.0;
      var avgY = 0.0;
      final n = avgRangeEnd - avgStart;
      for (var j = avgStart; j < avgRangeEnd; j++) {
        avgX += data[j].timestamp.millisecondsSinceEpoch;
        avgY += data[j].value;
      }
      if (n > 0) {
        avgX /= n;
        avgY /= n;
      } else {
        avgX = data[avgStart].timestamp.millisecondsSinceEpoch.toDouble();
        avgY = data[avgStart].value;
      }

      final currentPoint = sampled.last;
      final currentX =
          currentPoint.timestamp.millisecondsSinceEpoch.toDouble();
      final currentY = currentPoint.value;

      final rangeOffs = (bucketIndex * every).floor() + 1;
      final rangeTo = min(data.length - 1, ((bucketIndex + 1) * every + 1).floor());

      double maxArea = -1;
      var nextIndex = rangeOffs;

      for (var j = rangeOffs; j < rangeTo; j++) {
        final jX = data[j].timestamp.millisecondsSinceEpoch.toDouble();
        final jY = data[j].value;
        final area = ((jX - currentX) * (avgY - currentY) -
                (jY - currentY) * (avgX - currentX))
            .abs();
        if (area > maxArea) {
          maxArea = area;
          nextIndex = j;
        }
      }

      if (nextIndex < 0 || nextIndex >= data.length) {
        nextIndex = min(data.length - 1, max(0, rangeOffs));
      }
      sampled.add(data[nextIndex]);
    }

    sampled.add(data.last);
    return sampled;
  }
}

class BucketAveragingDecimator {
  const BucketAveragingDecimator();

  DecimatedSeries decimate(
      List<ChartPoint> points, int threshold) {
    if (points.isEmpty) {
      return const DecimatedSeries(points: [], originalCount: 0);
    }
    if (points.length <= threshold || threshold < 2) {
      return DecimatedSeries(points: points, originalCount: points.length);
    }

    final bucketSize = (points.length / threshold).ceil();
    final sampled = <ChartPoint>[];

    for (var i = 0; i < points.length; i += bucketSize) {
      final end = min(i + bucketSize, points.length);
      final bucket = points.sublist(i, end);

      var sumTs = 0;
      var sumVals = 0.0;
      for (final p in bucket) {
        sumTs += p.timestamp.millisecondsSinceEpoch;
        sumVals += p.value;
      }

      sampled.add(ChartPoint(
        timestamp:
            DateTime.fromMillisecondsSinceEpoch(sumTs ~/ bucket.length),
        value: sumVals / bucket.length,
      ));
    }

    return DecimatedSeries(points: sampled, originalCount: points.length);
  }
}

class ChartMathUtils {
  ChartMathUtils._();

  static ChartPoint? findNearest(
    List<ChartPoint> points,
    Offset localPosition,
    Rect plotRect, {
    required DateTime minTime,
    required DateTime maxTime,
    required double minValue,
    required double maxValue,
  }) {
    if (points.isEmpty) return null;

    final xRatio =
        ((localPosition.dx - plotRect.left) / plotRect.width).clamp(0.0, 1.0);
    final spanMs =
        maxTime.millisecondsSinceEpoch - minTime.millisecondsSinceEpoch;
    final targetMs =
        minTime.millisecondsSinceEpoch + spanMs * xRatio;

    var best = points.first;
    var bestDistance =
        (best.timestamp.millisecondsSinceEpoch - targetMs).abs();

    for (final point in points) {
      final distance = (point.timestamp.millisecondsSinceEpoch - targetMs)
          .abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        best = point;
      }
    }

    return best;
  }
}