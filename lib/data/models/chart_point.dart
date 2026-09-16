class ChartPoint {
  final DateTime timestamp;
  final double value;

  const ChartPoint({required this.timestamp, required this.value});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChartPoint &&
          timestamp == other.timestamp &&
          (value - other.value).abs() < 0.001;

  @override
  int get hashCode => Object.hash(timestamp, value);
}

class TimeBucket {
  final DateTime start;
  final DateTime end;
  final double aggregatedValue;
  final int count;

  const TimeBucket({
    required this.start,
    required this.end,
    required this.aggregatedValue,
    required this.count,
  });
}

class DecimatedSeries {
  final List<ChartPoint> points;
  final int originalCount;

  const DecimatedSeries({required this.points, required this.originalCount});
}
