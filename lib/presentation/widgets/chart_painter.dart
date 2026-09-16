import 'package:flutter/material.dart';
import '../../data/models/chart_point.dart';

class ChartPainter extends CustomPainter {
  final List<ChartPoint> points;
  final Color lineColor;
  final Color areaColor;
  final Color gridColor;
  final Color axisTextColor;
  final String title;
  final String unit;
  final ChartPoint? highlightedPoint;
  final double viewportStartMs;
  final double viewportEndMs;
  final double minValue;
  final double maxValue;
  final bool showXLabels;
  final List<Duration> xLabelSteps;

  ChartPainter({
    required this.points,
    required this.lineColor,
    required this.areaColor,
    required this.gridColor,
    required this.axisTextColor,
    required this.title,
    required this.unit,
    this.highlightedPoint,
    required this.viewportStartMs,
    required this.viewportEndMs,
    required this.minValue,
    required this.maxValue,
    this.showXLabels = true,
    this.xLabelSteps = const [
      Duration(minutes: 60),
      Duration(minutes: 30),
      Duration(minutes: 15),
      Duration(minutes: 5),
    ],
  });

  static const double _paddingLeft = 8;
  static const double _paddingRight = 8;
  static const double _paddingTop = 8;
  static const double _paddingBottom = 28;

  late final Paint _linePaint;
  late final Paint _areaPaint;
  late final Paint _gridPaint;
  late final Paint _highlightGuidePaint;
  late final Paint _highlightDotPaint;
  late final Paint _highlightHaloPaint;

  @override
  void paint(Canvas canvas, Size size) {
    _initializePaints();

    final plotRect = Rect.fromLTRB(
      _paddingLeft,
      _paddingTop,
      size.width - _paddingRight,
      size.height - _paddingBottom,
    );

    _drawGrid(canvas, plotRect);
    _drawArea(canvas, plotRect);
    _drawXLabels(canvas, plotRect);
    _drawLegend(canvas);
    _drawHighlight(canvas, plotRect);
  }

  void _initializePaints() {
    _linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    _areaPaint = Paint()
      ..color = areaColor
      ..style = PaintingStyle.fill;

    _gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    _highlightGuidePaint = Paint()
      ..color = lineColor.withValues(alpha: 0.4)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    _highlightDotPaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    _highlightHaloPaint = Paint()
      ..color = lineColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
  }

  void _drawGrid(Canvas canvas, Rect plotRect) {
    for (var i = 0; i <= 4; i++) {
      final t = i / 4;
      final x = plotRect.left + plotRect.width * t;
      canvas.drawLine(
        Offset(x, plotRect.top),
        Offset(x, plotRect.bottom),
        _gridPaint,
      );
    }

    for (var i = 0; i <= 3; i++) {
      final t = i / 3;
      final y = plotRect.top + plotRect.height * (1 - t);
      canvas.drawLine(
        Offset(plotRect.left, y),
        Offset(plotRect.right, y),
        _gridPaint,
      );
    }

    final valueRange = maxValue - minValue;
    if (valueRange > 0) {
      for (var i = 0; i <= 3; i++) {
        final t = i / 3;
        final y = plotRect.top + plotRect.height * (1 - t);
        final value = minValue + valueRange * t;
        final label = value.toStringAsFixed(0);
        final textPainter = _buildTextPainter(label);
        textPainter.paint(
          canvas,
          Offset(0, y - textPainter.height / 2),
        );
      }
    }
  }

  double _mapX(double ms) {
    final span = viewportEndMs - viewportStartMs;
    if (span == 0) return 0;
    return (ms - viewportStartMs) / span;
  }

  double _mapY(double value) {
    final range = maxValue - minValue;
    if (range == 0) return 0;
    return 1 - (value - minValue) / range;
  }

  void _drawArea(Canvas canvas, Rect plotRect) {
    if (points.isEmpty) return;

    final path = Path();
    final valueRange = maxValue - minValue;

    if (valueRange <= 0) {
      _drawFlatLine(canvas, plotRect);
      return;
    }

    for (var i = 0; i < points.length; i++) {
      final point = points[i];
      final x = plotRect.left +
          plotRect.width * _mapX(point.timestamp.millisecondsSinceEpoch.toDouble());
      final y = plotRect.top +
          plotRect.height * _mapY(point.value);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, _linePaint);

    final areaPath = Path.from(path);
    areaPath
      ..lineTo(
        plotRect.left + plotRect.width,
        plotRect.bottom,
      )
      ..lineTo(plotRect.left, plotRect.bottom)
      ..close();
    canvas.drawPath(areaPath, _areaPaint);
  }

  void _drawFlatLine(Canvas canvas, Rect plotRect) {
    final y = plotRect.center.dy;
    final path = Path()
      ..moveTo(plotRect.left, y)
      ..lineTo(plotRect.right, y);
    canvas.drawPath(path, _linePaint);
  }

  void _drawXLabels(Canvas canvas, Rect plotRect) {
    if (!showXLabels || points.isEmpty) return;

    final displayPoints = _getLabelAnchors();
    if (displayPoints.isEmpty) return;

    for (final point in displayPoints) {
      final x = plotRect.left +
          plotRect.width *
              _mapX(point.timestamp.millisecondsSinceEpoch.toDouble());
      final timeLabel = '${point.timestamp.hour.toString().padLeft(2, '0')}'
          ':${point.timestamp.minute.toString().padLeft(2, '0')}';
      final textPainter = _buildTextPainter(timeLabel);
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, plotRect.bottom + 6),
      );
    }
  }

  List<ChartPoint> _getLabelAnchors() {
    final anchors = <ChartPoint>[];
    final spanMs = viewportEndMs - viewportStartMs;
    if (spanMs <= 0) return anchors;

    const labelCount = 4;
    for (var i = 0; i <= labelCount; i++) {
      final targetMs = viewportStartMs + spanMs * (i / labelCount);
      final anchor = _findNearestPointTime(targetMs);
      if (anchor != null && !anchors.contains(anchor)) {
        anchors.add(anchor);
      }
    }
    return anchors;
  }

  ChartPoint? _findNearestPointTime(double targetMs) {
    if (points.isEmpty) return null;
    var best = points.first;
    var bestDiff = (points.first.timestamp.millisecondsSinceEpoch - targetMs)
        .abs();
    for (final point in points) {
      final diff = (point.timestamp.millisecondsSinceEpoch - targetMs).abs();
      if (diff < bestDiff) {
        bestDiff = diff;
        best = point;
      }
    }
    return best;
  }

  void _drawHighlight(Canvas canvas, Rect plotRect) {
    final point = highlightedPoint;
    if (point == null) return;

    final x = plotRect.left +
        plotRect.width *
            _mapX(point.timestamp.millisecondsSinceEpoch.toDouble());
    final y = plotRect.top +
        plotRect.height * _mapY(point.value);

    final guideLine = Path()..moveTo(x, plotRect.top);
    guideLine.lineTo(x, plotRect.bottom);
    canvas.drawPath(guideLine, _highlightGuidePaint);

    canvas.drawCircle(Offset(x, y), 4.0, _highlightDotPaint);
    canvas.drawCircle(Offset(x, y), 7.0, _highlightHaloPaint);
  }

  void _drawLegend(Canvas canvas) {
    final textPainter = _buildTextPainter(title);
    textPainter.paint(canvas, const Offset(10, 2));
  }

  TextPainter _buildTextPainter(String text) {
    return TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: axisTextColor,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  @override
  bool shouldRepaint(covariant ChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.highlightedPoint != highlightedPoint ||
        oldDelegate.viewportStartMs != viewportStartMs ||
        oldDelegate.viewportEndMs != viewportEndMs ||
        oldDelegate.minValue != minValue ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.lineColor != lineColor;
  }
}