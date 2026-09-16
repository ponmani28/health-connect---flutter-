import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../data/models/chart_point.dart';
import 'chart_painter.dart';

class HealthChart extends StatefulWidget {
  final List<ChartPoint> points;
  final Color lineColor;
  final Color areaColor;
  final String title;
  final String unit;
  final Duration window;
  final VoidCallback? onViewportChanged;

  const HealthChart({
    super.key,
    required this.points,
    required this.lineColor,
    required this.areaColor,
    required this.title,
    required this.unit,
    required this.window,
    this.onViewportChanged,
  });

  @override
  State<HealthChart> createState() => _HealthChartState();
}

class _HealthChartState extends State<HealthChart> {
  late double _viewportStartMs;
  late double _viewportEndMs;
  double _minValue = 0;
  double _maxValue = 100;
  ChartPoint? _highlightedPoint;
  double _gestureStartMs = 0;
  double _gestureStartWidthMs = 0;
  double _lastFocalDx = 0;
  double _lastFocalDy = 0;

  @override
  void initState() {
    super.initState();
    _resetViewport();
  }

  void _resetViewport() {
    final end = DateTime.now().millisecondsSinceEpoch.toDouble();
    _viewportStartMs = end - widget.window.inMilliseconds.toDouble();
    _viewportEndMs = end;
    _computeBounds();
  }

  void _computeBounds() {
    final visible = widget.points
        .where((p) =>
            p.timestamp.millisecondsSinceEpoch >= _viewportStartMs &&
            p.timestamp.millisecondsSinceEpoch <= _viewportEndMs)
        .toList();

    if (visible.isEmpty) {
      _minValue = 0;
      _maxValue = 100;
      return;
    }

    var min = visible.first.value;
    var max = visible.first.value;
    for (final p in visible) {
      if (p.value < min) min = p.value;
      if (p.value > max) max = p.value;
    }

    final padding = max - min;
    if (padding <= 0) {
      _minValue = min - 5;
      _maxValue = min + 5;
    } else {
      _minValue = min - padding * 0.1;
      _maxValue = max + padding * 0.1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (widget.points.isEmpty) {
          return const SizedBox();
        }
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onScaleStart: (details) {
            _gestureStartMs = _viewportStartMs;
            _gestureStartWidthMs = _viewportEndMs - _viewportStartMs;
            _lastFocalDx = details.focalPoint.dx;
            _lastFocalDy = details.focalPoint.dy;
          },
          onScaleUpdate: (details) {
            final focalDeltaDx = details.focalPoint.dx - _lastFocalDx;

            if (details.scale != 1.0 && details.pointerCount >= 2) {
              _handlePinchZoom(details);
            } else if (focalDeltaDx != 0 && details.pointerCount == 1) {
              _handlePan(focalDeltaDx);
            }

            _lastFocalDx = details.focalPoint.dx;
            _lastFocalDy = details.focalPoint.dy;
          },
          onScaleEnd: (details) {
            widget.onViewportChanged?.call();
          },
          onTapDown: (details) {
            setState(() {
              _highlightedPoint = _findHighlight(details.localPosition);
            });
          },
          child: CustomPaint(
            size: Size(constraints.maxWidth, 240),
            painter: ChartPainter(
              points: widget.points,
              lineColor: widget.lineColor,
              areaColor: widget.areaColor,
              gridColor: theme.dividerColor.withOpacity(0.3),
              axisTextColor: theme.colorScheme.onSurface.withOpacity(0.6),
              title: widget.title,
              unit: widget.unit,
              highlightedPoint: _highlightedPoint,
              viewportStartMs: _viewportStartMs,
              viewportEndMs: _viewportEndMs,
              minValue: _minValue,
              maxValue: _maxValue,
            ),
          ),
        );
      },
    );
  }

  void _handlePan(double deltaDx) {
    setState(() {
      final widthMs = _viewportEndMs - _viewportStartMs;
      final dxToMs = widthMs / 300.0;
      final shift = -deltaDx * dxToMs;
      final newStart = _viewportStartMs + shift;
      final newEnd = _viewportEndMs + shift;

      final nowMs = DateTime.now().millisecondsSinceEpoch.toDouble();
      final bounds = _getDataBoundsMs();

      if (newEnd > nowMs) {
        final overflow = newEnd - nowMs;
        final clampedStart = (_viewportStartMs - overflow).clamp(bounds.$1, bounds.$2 - widthMs);
        _viewportStartMs = clampedStart;
        _viewportEndMs = clampedStart + widthMs;
      } else if (newStart < bounds.$1) {
        final underflow = bounds.$1 - newStart;
        final clampedEnd = (_viewportEndMs + underflow).clamp(bounds.$1 + widthMs, nowMs);
        _viewportEndMs = clampedEnd;
        _viewportStartMs = clampedEnd - widthMs;
      } else {
        _viewportStartMs = newStart;
        _viewportEndMs = newEnd;
      }

      _computeBounds();
    });
  }

  (double, double) _getDataBoundsMs() {
    if (widget.points.isEmpty) {
      final now = DateTime.now().millisecondsSinceEpoch.toDouble();
      return (now - widget.window.inMilliseconds.toDouble(), now);
    }

    final first = widget.points.first.timestamp.millisecondsSinceEpoch.toDouble();
    final last = widget.points.last.timestamp.millisecondsSinceEpoch.toDouble();
    final now = DateTime.now().millisecondsSinceEpoch.toDouble();

    final min = first < now - widget.window.inMilliseconds.toDouble()
        ? first
        : now - widget.window.inMilliseconds.toDouble();
    return (min, now);
  }

  void _handlePinchZoom(details) {
    setState(() {
      final widthMs = _viewportEndMs - _viewportStartMs;
      final newWidthMs = (widthMs / details.scale).clamp(
        widget.window.inMilliseconds.toDouble() / 20.0,
        widget.window.inMilliseconds.toDouble(),
      );

      final focalRatio = _computeFocalRatio(details.focalPoint.dx);
      final centerMs =
          _viewportStartMs + widthMs * focalRatio;
      final newStart = (centerMs - newWidthMs * focalRatio).clamp(
        _getDataBoundsMs().$1,
        _getDataBoundsMs().$2 - newWidthMs,
      );
      _viewportStartMs = newStart;
      _viewportEndMs = newStart + newWidthMs;

      _computeBounds();
    });
  }

  double _computeFocalRatio(double focalDx) {
    const paddingLeft = 8.0;
    const paddingRight = 8.0;
    final chartWidth = 300.0;
    final effectiveWidth = chartWidth - paddingLeft - paddingRight;
    if (effectiveWidth <= 0) return 0.5;
    return ((focalDx - paddingLeft) / effectiveWidth).clamp(0.0, 1.0);
  }

  ChartPoint? _findHighlight(Offset localPosition) {
    if (widget.points.isEmpty) return null;

    const paddingLeft = 8.0;
    const paddingRight = 8.0;
    const paddingBottom = 28.0;
    final chartWidth = 300.0;
    final chartHeight = 240.0;
    final plotWidth = chartWidth - paddingLeft - paddingRight;
    final plotHeight = chartHeight - paddingBottom;

    final xRatio = ((localPosition.dx - paddingLeft) / plotWidth).clamp(0.0, 1.0);
    final fakeRect = Rect.fromLTRB(
      paddingLeft,
      0,
      chartWidth - paddingRight,
      plotHeight,
    );
    return ChartMathUtils.findNearest(
      widget.points.take(300).toList(),
      Offset(paddingLeft + plotWidth * xRatio, localPosition.dy),
      fakeRect,
      minTime: DateTime.fromMillisecondsSinceEpoch(_viewportStartMs.round()),
      maxTime: DateTime.fromMillisecondsSinceEpoch(_viewportEndMs.round()),
      minValue: _minValue,
      maxValue: _maxValue,
    );
  }

  @override
  void didUpdateWidget(covariant HealthChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.points != widget.points) {
      _computeBounds();
    }
  }
}