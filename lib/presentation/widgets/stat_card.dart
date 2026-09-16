import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../data/models/chart_point.dart';

class NearbyPointLookup {
  NearbyPointLookup._();

  static double _mapX(double ms, double vpStart, double vpEnd, Rect plotRect) {
    final span = vpEnd - vpStart;
    if (span == 0) return plotRect.left;
    final t = (ms - vpStart) / span;
    return plotRect.left + plotRect.width * t.clamp(0, 1);
  }
}

class ChartTooltip {
  ChartTooltip._();

  static ChartPoint? findNearest(
    List<ChartPoint> points,
    Offset localPosition, {
    required Rect plotRect,
    required double viewportStartMs,
    required double viewportEndMs,
  }) {
    if (points.isEmpty) return null;

    var best = points.first;
    var bestDistance = double.infinity;

    final targetX = localPosition.dx;

    for (final point in points) {
      final x = NearbyPointLookup._mapX(
        point.timestamp.millisecondsSinceEpoch.toDouble(),
        viewportStartMs,
        viewportEndMs,
        plotRect,
      );
      final distance = (x - targetX).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        best = point;
      }
    }

    return best;
  }
}

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color accentColor;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: accentColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: accentColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PerformanceHud extends StatelessWidget {
  final double avgBuildTime;
  final double paintTime;
  final double fps;
  final bool meetsTarget;
  final int updateCount;

  const PerformanceHud({
    super.key,
    required this.avgBuildTime,
    required this.paintTime,
    required this.fps,
    required this.meetsTarget,
    required this.updateCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: meetsTarget ? const Color(0xFF1B5E20) : const Color(0xFF880E4F),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildMetric(
            label: 'Build',
            value: '${avgBuildTime.toStringAsFixed(2)}ms',
            ok: avgBuildTime <= AppConstants.maxBuildTimeMs,
          ),
          const _HudDivider(),
          _buildMetric(
            label: 'Paint',
            value: '${paintTime.toStringAsFixed(2)}ms',
            ok: paintTime < 16.7,
          ),
          const _HudDivider(),
          _buildMetric(
            label: 'FPS',
            value: '${fps.toStringAsFixed(0)}',
            ok: fps >= AppConstants.targetFps - 5,
          ),
          const _HudDivider(),
          _buildMetric(
            label: 'Updates',
            value: '$updateCount',
            ok: true,
          ),
        ],
      ),
    );
  }

  Widget _buildMetric({
    required String label,
    required String value,
    required bool ok,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 9,
          ),
        ),
        Row(
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              ok ? Icons.check_circle : Icons.warning,
              size: 10,
              color: ok ? Colors.greenAccent : Colors.orangeAccent,
            ),
          ],
        ),
      ],
    );
  }
}

class _HudDivider extends StatelessWidget {
  const _HudDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 28,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: Colors.white24,
    );
  }
}