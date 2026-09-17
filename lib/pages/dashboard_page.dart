import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:health/health.dart';

import '../controllers/health_controller.dart';
import '../models/metric.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<HealthController>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Dashboard'),
        backgroundColor: theme.colorScheme.inversePrimary,
        actions: [
          Obx(
            () => IconButton(
              tooltip: 'Refresh data',
              onPressed: controller.busy.value || !controller.permissionsGranted.value
                  ? null
                  : controller.reload,
              icon: const Icon(Icons.refresh),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: controller.reload,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              const _StatusCard(),
              const SizedBox(height: 16),
              Obx(
                () => controller.busy.value
                    ? const Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: LinearProgressIndicator(
                          minHeight: 3,
                          borderRadius: BorderRadius.all(Radius.circular(2)),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              Obx(
                () => controller.available.value
                    ? _MetricsGrid(metrics: controller.metrics)
                    : const SizedBox.shrink(),
              ),
              if (controller.available.value) const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = Get.find<HealthController>();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Obx(() {
          final installed = c.available.value;
          final granted = c.permissionsGranted.value;
          final lastSync = c.lastSync.value;
          final note = c.availabilityNote.value;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor:
                        (installed ? Colors.green : Colors.orange)
                            .withValues(alpha: 0.15),
                    child: Icon(
                      installed
                          ? Icons.health_and_safety
                          : Icons.error_outline,
                      color: installed ? Colors.green : Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Health Connect',
                            style: theme.textTheme.titleMedium),
                        Text(
                          note,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (granted)
                    const Chip(
                      avatar: Icon(
                        Icons.check_circle,
                        size: 18,
                        color: Colors.green,
                      ),
                      label: Text('Access'),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (!installed)
                ElevatedButton.icon(
                  onPressed: c.busy.value ? null : c.installHealthConnect,
                  icon: const Icon(Icons.system_update_alt),
                  label: Text(
                    note == 'Update required'
                        ? 'Update Health Connect'
                        : 'Install Health Connect',
                  ),
                )
              else if (!granted)
                FilledButton.icon(
                  onPressed: c.busy.value ? null : c.requestPermissions,
                  icon: const Icon(Icons.lock_open),
                  label: const Text('Grant read access'),
                )
              else
                Row(
                  children: [
                    const Icon(Icons.cloud_done, size: 18, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        lastSync == null
                            ? 'Waiting for first sync'
                            : 'Last synced ${_clock(lastSync)}',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
            ],
          );
        }),
      ),
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.metrics});

  final List<Metric> metrics;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.25,
      children: [for (final m in metrics) _MetricCard(metric: m)],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});

  final Metric metric;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: metric.color.withValues(alpha: 0.07),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Obx(() {
          final value = metric.value.value;
          final error = metric.error.value;
          final recordedAt = metric.recordedAt.value;
          final formatted = _formatMetric(metric, value);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: metric.color.withValues(alpha: 0.15),
                    child: Icon(metric.icon, size: 18, color: metric.color),
                  ),
                  const Spacer(),
                  if (error != null)
                    Tooltip(
                      message: error,
                      child: const Icon(
                        Icons.error_outline,
                        size: 16,
                        color: Colors.orange,
                      ),
                    ),
                ],
              ),
              const Spacer(),
              Text(
                metric.label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  formatted.$1,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: error != null ? Colors.orange : null,
                  ),
                ),
              ),
              Row(
                children: [
                  Text(
                    formatted.$2,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  if (recordedAt != null)
                    Text(
                      _clock(recordedAt),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ],
          );
        }),
      ),
    );
  }
}

(String, String) _formatMetric(Metric m, double? v) {
  if (v == null) {
    return (m.error.value != null ? 'Error' : '-', m.unit);
  }
  switch (m.type) {
    case HealthDataType.STEPS:
      return (v.round().toString(), 'steps');
    case HealthDataType.ACTIVE_ENERGY_BURNED:
      return (v.round().toString(), 'kcal');
    case HealthDataType.DISTANCE_DELTA:
      if (v >= 1000) {
        return ((v / 1000).toStringAsFixed(2), 'km');
      }
      return (v.round().toString(), 'm');
    case HealthDataType.FLIGHTS_CLIMBED:
      return (v.round().toString(), 'floors');
    case HealthDataType.HEART_RATE:
    case HealthDataType.RESTING_HEART_RATE:
      return (v.round().toString(), 'bpm');
    case HealthDataType.BLOOD_OXYGEN:
      return (v.round().toString(), '%');
    case HealthDataType.HEART_RATE_VARIABILITY_RMSSD:
      return (v.round().toString(), 'ms');
    case HealthDataType.HEIGHT:
      return ((v * 100).round().toString(), 'cm');
    case HealthDataType.WEIGHT:
      return (v.toStringAsFixed(1), 'kg');
    default:
      return (v.toStringAsFixed(1), m.unit);
  }
}

String _clock(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:'
    '${t.minute.toString().padLeft(2, '0')}:'
    '${t.second.toString().padLeft(2, '0')}';
