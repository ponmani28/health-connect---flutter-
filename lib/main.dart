import 'package:flutter/material.dart';
import 'package:health/health.dart';

void main() {
  runApp(const HealthConnectDemoApp());
}

class HealthConnectDemoApp extends StatelessWidget {
  const HealthConnectDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Health Connect Dashboard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF12A5ED)),
        useMaterial3: true,
      ),
      home: const DashboardPage(),
    );
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final Health _health = Health();

  /// Data types this dashboard reads (all declared in AndroidManifest.xml).
  static const List<HealthDataType> _readTypes = [
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.DISTANCE_DELTA,
    HealthDataType.FLIGHTS_CLIMBED,
    HealthDataType.HEART_RATE,
    HealthDataType.RESTING_HEART_RATE,
    HealthDataType.BLOOD_OXYGEN,
    HealthDataType.HEART_RATE_VARIABILITY_RMSSD,
    HealthDataType.HEIGHT,
    HealthDataType.WEIGHT,
  ];

  /// Other Android-supported types that can be added later.
  static const List<(String, String)> _moreTypes = [
    ('Sleep', 'READ_SLEEP'),
    ('Body fat', 'READ_BODY_FAT'),
    ('Body temperature', 'READ_BODY_TEMPERATURE'),
    ('Blood glucose', 'READ_BLOOD_GLUCOSE'),
    ('Respiratory rate', 'READ_RESPIRATORY_RATE'),
    ('Water', 'READ_WATER'),
    ('Total calories', 'READ_TOTAL_CALORIES_BURNED'),
  ];

  late final List<_Metric> _metrics = [
    _Metric(
      type: HealthDataType.STEPS,
      label: 'Steps',
      unit: 'steps',
      icon: Icons.directions_walk,
      color: const Color(0xFF12A5ED),
      today: true,
    ),
    _Metric(
      type: HealthDataType.ACTIVE_ENERGY_BURNED,
      label: 'Active Energy',
      unit: 'kcal',
      icon: Icons.local_fire_department,
      color: Colors.orange,
      today: true,
    ),
    _Metric(
      type: HealthDataType.DISTANCE_DELTA,
      label: 'Distance',
      unit: 'm',
      icon: Icons.route,
      color: Colors.teal,
      today: true,
    ),
    _Metric(
      type: HealthDataType.FLIGHTS_CLIMBED,
      label: 'Floors',
      unit: 'floors',
      icon: Icons.stairs,
      color: Colors.purple,
      today: true,
    ),
    _Metric(
      type: HealthDataType.HEART_RATE,
      label: 'Heart Rate',
      unit: 'bpm',
      icon: Icons.favorite,
      color: Colors.redAccent,
    ),
    _Metric(
      type: HealthDataType.RESTING_HEART_RATE,
      label: 'Resting HR',
      unit: 'bpm',
      icon: Icons.monitor_heart,
      color: Colors.pink,
      lookback: const Duration(days: 7),
    ),
    _Metric(
      type: HealthDataType.BLOOD_OXYGEN,
      label: 'Blood Oxygen',
      unit: '%',
      icon: Icons.air,
      color: Colors.cyan,
    ),
    _Metric(
      type: HealthDataType.HEART_RATE_VARIABILITY_RMSSD,
      label: 'HRV (RMSSD)',
      unit: 'ms',
      icon: Icons.waves,
      color: Colors.indigo,
    ),
    _Metric(
      type: HealthDataType.WEIGHT,
      label: 'Weight',
      unit: 'kg',
      icon: Icons.monitor_weight,
      color: Colors.brown,
      lookback: const Duration(days: 30),
    ),
    _Metric(
      type: HealthDataType.HEIGHT,
      label: 'Height',
      unit: 'cm',
      icon: Icons.height,
      color: Colors.lightGreen,
      lookback: const Duration(days: 90),
    ),
  ];

  bool _busy = false;
  bool _available = false;
  String _availability = 'Checking…';
  bool _permissionsGranted = false;
  DateTime? _lastSync;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  /// 1) Initialize the plugin and check Health Connect availability.
  Future<void> _initialize() async {
    setState(() => _busy = true);
    try {
      await _health.configure();

      final status = await _health.getHealthConnectSdkStatus();
      _available = status == HealthConnectSdkStatus.sdkAvailable &&
          await _health.isHealthConnectAvailable();
      _availability = switch (status) {
        HealthConnectSdkStatus.sdkAvailable => 'Available',
        HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired =>
          'Update required',
        HealthConnectSdkStatus.sdkUnavailable => 'Not installed',
        null => 'Unknown',
      };

      if (_available) {
        final granted = await _health.hasPermissions(
          _readTypes,
          permissions: List.filled(_readTypes.length, HealthDataAccess.READ),
        );
        _permissionsGranted = granted ?? false;
        if (_permissionsGranted) {
          await _refresh();
        }
      }
    } catch (e) {
      _show('Initialization failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 2) Request READ access for every metric on the dashboard.
  Future<void> _requestPermissions() async {
    setState(() => _busy = true);
    try {
      final granted = await _health.requestAuthorization(
        _readTypes,
        permissions: List.filled(_readTypes.length, HealthDataAccess.READ),
      );
      _permissionsGranted = granted;
      _show(granted
          ? 'Access granted. Loading data…'
          : 'Access not granted. Change it any time in '
              'Health Connect > Data & access.');
      if (granted) {
        await _refresh();
      }
    } catch (e) {
      _show('Permission request failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 3) Read every metric: daily totals for activity, latest sample for vitals.
  Future<void> _refresh() async {
    if (!_permissionsGranted) {
      _show('Grant access to Health Connect first.');
      return;
    }

    setState(() => _busy = true);
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    for (final m in _metrics) {
      m.reset();
      try {
        if (m.today && m.type == HealthDataType.STEPS) {
          // Native aggregate for the total step count.
          final total = await _health.getTotalStepsInInterval(startOfDay, now);
          m.value = total?.toDouble();
        } else {
          final points = await _health.getHealthDataFromTypes(
            types: [m.type],
            startTime: m.today ? startOfDay : now.subtract(m.lookback),
            endTime: now,
          );

          if (m.today) {
            double sum = 0;
            for (final p in points) {
              sum += _numericValue(p);
            }
            m.value = sum;
          } else if (points.isNotEmpty) {
            // Newest sample wins.
            final newest = points
                .reduce((a, b) => a.dateFrom.isBefore(b.dateFrom) ? b : a);
            m.value = _numericValue(newest);
            m.recordedAt = newest.dateFrom;
          }
        }
      } catch (e) {
        m.error = e.toString();
      }
    }

    _lastSync = DateTime.now();
    if (mounted) setState(() => _busy = false);
  }

  double _numericValue(HealthDataPoint p) =>
      (p.value as NumericHealthValue).numericValue.toDouble();

  Future<void> _installHealthConnect() async {
    await _health.installHealthConnect();
  }

  void _show(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Dashboard'),
        backgroundColor: theme.colorScheme.inversePrimary,
        actions: [
          IconButton(
            tooltip: 'Refresh data',
            onPressed: _busy || !_permissionsGranted ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              _buildStatusCard(theme),
              const SizedBox(height: 16),
              if (_busy) ...[
                const LinearProgressIndicator(
                  minHeight: 3,
                  borderRadius: BorderRadius.all(Radius.circular(2)),
                ),
                const SizedBox(height: 16),
              ],
              if (_available) _buildMetricsGrid(theme),
              if (_available) const SizedBox(height: 24),
              _buildMoreDataCard(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard(ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor:
                      (_available ? Colors.green : Colors.orange)
                          .withValues(alpha: 0.15),
                  child: Icon(
                    _available ? Icons.health_and_safety : Icons.error_outline,
                    color: _available ? Colors.green : Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Health Connect',
                          style: theme.textTheme.titleMedium),
                      Text(_availability,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          )),
                    ],
                  ),
                ),
                if (_permissionsGranted)
                  const Chip(
                    avatar: Icon(Icons.check_circle,
                        size: 18, color: Colors.green),
                    label: Text('Access'),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (!_available)
              ElevatedButton.icon(
                onPressed: _busy ? null : _installHealthConnect,
                icon: const Icon(Icons.system_update_alt),
                label: Text(_availability == 'Update required'
                    ? 'Update Health Connect'
                    : 'Install Health Connect'),
              )
            else if (!_permissionsGranted)
              FilledButton.icon(
                onPressed: _busy ? null : _requestPermissions,
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
                      _lastSync == null
                          ? 'Waiting for first sync'
                          : 'Last synced '
                              '${_lastSync!.hour.toString().padLeft(2, '0')}:'
                              '${_lastSync!.minute.toString().padLeft(2, '0')}:'
                              '${_lastSync!.second.toString().padLeft(2, '0')}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsGrid(ThemeData theme) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.25,
      children: [
        for (final m in _metrics) _buildMetricCard(theme, m),
      ],
    );
  }

  Widget _buildMetricCard(ThemeData theme, _Metric m) {
    final formatted = _formatMetric(m);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: m.color.withValues(alpha: 0.07),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: m.color.withValues(alpha: 0.15),
                  child: Icon(m.icon, size: 18, color: m.color),
                ),
                const Spacer(),
                if (m.error != null)
                  Tooltip(
                    message: m.error!,
                    child: const Icon(Icons.error_outline,
                        size: 16, color: Colors.orange),
                  ),
              ],
            ),
            const Spacer(),
            Text(
              m.label,
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
                  color: m.error != null ? Colors.orange : null,
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
                if (m.recordedAt != null)
                  Text(
                    _clock(m.recordedAt!),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  (String, String) _formatMetric(_Metric m) {
    final v = m.value;
    if (v == null) {
      return (m.error != null ? 'Error' : '—', m.unit);
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

  Widget _buildMoreDataCard(ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('More data you can add',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (label, permission) in _moreTypes)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(label, style: theme.textTheme.bodySmall),
                        Text('android.permission.health.$permission',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontFamily: 'monospace',
                            )),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'These types need a matching '
              '<uses-permission android:name="android.permission.health.'
              'PERMISSION"/> entry in AndroidManifest.xml '
              '(e.g. android.permission.health.READ_SLEEP) plus the '
              'HealthDataType included in requestAuthorization().',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _clock(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}';
}

class _Metric {
  final HealthDataType type;
  final String label;
  final String unit;
  final IconData icon;
  final Color color;

  /// true -> sum over today; false -> latest sample within [lookback].
  final bool today;
  final Duration lookback;

  double? value;
  DateTime? recordedAt;
  String? error;

  _Metric({
    required this.type,
    required this.label,
    required this.unit,
    required this.icon,
    required this.color,
    this.today = false,
    this.lookback = const Duration(hours: 24),
  });

  void reset() {
    value = null;
    recordedAt = null;
    error = null;
  }
}