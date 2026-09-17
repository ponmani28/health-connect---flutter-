import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:health/health.dart';

import '../models/metric.dart';

class HealthController extends GetxController {
  final Health _health = Health();

  /// Data types this dashboard reads (all declared in AndroidManifest.xml).
  static const List<HealthDataType> readTypes = [
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

  late final List<Metric> metrics = [
    Metric(
      type: HealthDataType.STEPS,
      label: 'Steps',
      unit: 'steps',
      icon: Icons.directions_walk,
      color: const Color(0xFF12A5ED),
      today: true,
    ),
    Metric(
      type: HealthDataType.ACTIVE_ENERGY_BURNED,
      label: 'Active Energy',
      unit: 'kcal',
      icon: Icons.local_fire_department,
      color: Colors.orange,
      today: true,
    ),
    Metric(
      type: HealthDataType.DISTANCE_DELTA,
      label: 'Distance',
      unit: 'm',
      icon: Icons.route,
      color: Colors.teal,
      today: true,
    ),
    Metric(
      type: HealthDataType.FLIGHTS_CLIMBED,
      label: 'Floors',
      unit: 'floors',
      icon: Icons.stairs,
      color: Colors.purple,
      today: true,
    ),
    Metric(
      type: HealthDataType.HEART_RATE,
      label: 'Heart Rate',
      unit: 'bpm',
      icon: Icons.favorite,
      color: Colors.redAccent,
    ),
    Metric(
      type: HealthDataType.RESTING_HEART_RATE,
      label: 'Resting HR',
      unit: 'bpm',
      icon: Icons.monitor_heart,
      color: Colors.pink,
      lookback: const Duration(days: 7),
    ),
    Metric(
      type: HealthDataType.BLOOD_OXYGEN,
      label: 'Blood Oxygen',
      unit: '%',
      icon: Icons.air,
      color: Colors.cyan,
    ),
    Metric(
      type: HealthDataType.HEART_RATE_VARIABILITY_RMSSD,
      label: 'HRV (RMSSD)',
      unit: 'ms',
      icon: Icons.waves,
      color: Colors.indigo,
    ),
    Metric(
      type: HealthDataType.WEIGHT,
      label: 'Weight',
      unit: 'kg',
      icon: Icons.monitor_weight,
      color: Colors.brown,
      lookback: const Duration(days: 30),
    ),
    Metric(
      type: HealthDataType.HEIGHT,
      label: 'Height',
      unit: 'cm',
      icon: Icons.height,
      color: Colors.lightGreen,
      lookback: const Duration(days: 90),
    ),
  ];

  final RxBool busy = false.obs;
  final RxBool available = false.obs;
  final RxString availabilityNote = 'Checking.'.obs;
  final RxBool permissionsGranted = false.obs;
  final Rxn<DateTime> lastSync = Rxn<DateTime>();

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addPostFrameCallback((_) => initialize());
  }

  /// 1) Initialize the plugin and check Health Connect availability.
  Future<void> initialize() async {
    busy.value = true;
    try {
      await _health.configure();

      final status = await _health.getHealthConnectSdkStatus();
      available.value =
          status == HealthConnectSdkStatus.sdkAvailable &&
          await _health.isHealthConnectAvailable();
      availabilityNote.value = switch (status) {
        HealthConnectSdkStatus.sdkAvailable => 'Available',
        HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired =>
          'Update required',
        HealthConnectSdkStatus.sdkUnavailable => 'Not installed',
        null => 'Unknown',
      };

      if (available.value) {
        final granted = await _health.hasPermissions(
          readTypes,
          permissions: List.filled(readTypes.length, HealthDataAccess.READ),
        );
        permissionsGranted.value = granted ?? false;
        if (permissionsGranted.value) {
          await reload();
        }
      }
    } catch (e) {
      _show('Initialization failed: $e');
    } finally {
      busy.value = false;
    }
  }

  /// 2) Request READ access for every metric on the dashboard.
  Future<void> requestPermissions() async {
    busy.value = true;
    try {
      final granted = await _health.requestAuthorization(
        readTypes,
        permissions: List.filled(readTypes.length, HealthDataAccess.READ),
      );
      permissionsGranted.value = granted;
      _show(
        granted
            ? 'Access granted. Loading data.'
            : 'Access not granted. Change it any time in '
                  'Health Connect > Data & access.',
      );
      if (granted) {
        await reload();
      }
    } catch (e) {
      _show('Permission request failed: $e');
    } finally {
      busy.value = false;
    }
  }

  /// 3) Read every metric: daily totals for activity, latest sample for vitals.
  Future<void> reload() async {
    if (!permissionsGranted.value) {
      _show('Grant access to Health Connect first.');
      return;
    }

    busy.value = true;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    for (final m in metrics) {
      m.reset();
      try {
        if (m.today && m.type == HealthDataType.STEPS) {
          // Native aggregate for the total step count.
          final total = await _health.getTotalStepsInInterval(
            startOfDay,
            now,
          );
          m.value.value = total?.toDouble();
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
            m.value.value = sum;
          } else if (points.isNotEmpty) {
            // Newest sample wins.
            final newest = points.reduce(
              (a, b) => a.dateFrom.isBefore(b.dateFrom) ? b : a,
            );
            m.value.value = _numericValue(newest);
            m.recordedAt.value = newest.dateFrom;
          }
        }
      } catch (e) {
        m.error.value = e.toString();
      }
    }

    lastSync.value = DateTime.now();
    busy.value = false;
  }

  double _numericValue(HealthDataPoint p) =>
      (p.value as NumericHealthValue).numericValue.toDouble();

  Future<void> installHealthConnect() => _health.installHealthConnect();

  void _show(String message) {
    Get.snackbar(
      'Health Connect',
      message,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(12),
      borderRadius: 12,
    );
  }
}