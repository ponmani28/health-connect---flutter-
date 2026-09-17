import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:health/health.dart';

/// One dashboard stat. Values are reactive so the UI updates via Obx.
class Metric {
  final HealthDataType type;
  final String label;
  final String unit;
  final IconData icon;
  final Color color;

  /// true -> sum over today; false -> latest sample within [lookback].
  final bool today;
  final Duration lookback;

  final Rx<double?> value = Rx<double?>(null);
  final Rxn<DateTime> recordedAt = Rxn<DateTime>();
  final Rx<String?> error = Rx<String?>(null);

  Metric({
    required this.type,
    required this.label,
    required this.unit,
    required this.icon,
    required this.color,
    this.today = false,
    this.lookback = const Duration(hours: 24),
  });

  void reset() {
    value.value = null;
    recordedAt.value = null;
    error.value = null;
  }
}