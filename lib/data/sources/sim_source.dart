import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/health_event.dart';

class SimSource {
  StreamController<HealthEvent>? _controller;
  Timer? _stepsTimer;
  Timer? _hrTimer;
  bool _isActive = false;

  int _simulatedSteps = 0;
  double _simulatedHr = 72.0;
  final Random _random = Random();

  Stream<HealthEvent> get eventStream {
    _controller ??= StreamController<HealthEvent>.broadcast();
    return _controller!.stream;
  }

  bool get isActive => _isActive;

  void start() {
    if (kReleaseMode) return;
    if (_isActive) return;
    _isActive = true;
    _controller ??= StreamController<HealthEvent>.broadcast();

    _stepsTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!_isActive) return;
      final stepsBurst = _random.nextInt(20) + 5;
      _simulatedSteps += stepsBurst;
      _controller?.add(HealthEvent(
        type: HealthEventType.steps,
        timestamp: DateTime.now(),
        value: stepsBurst.toDouble(),
        sourceId: 'sim_source',
        recordId: 'sim_steps_${DateTime.now().millisecondsSinceEpoch}',
      ));
    });

    _hrTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_isActive) return;
      final delta = _random.nextDouble() * 6 - 3;
      _simulatedHr = max(55.0, min(120.0, _simulatedHr + delta));
      _controller?.add(HealthEvent(
        type: HealthEventType.heartRate,
        timestamp: DateTime.now(),
        value: _simulatedHr.roundToDouble(),
        sourceId: 'sim_source',
        recordId: 'sim_hr_${DateTime.now().millisecondsSinceEpoch}',
      ));
    });
  }

  void stop() {
    _isActive = false;
    _stepsTimer?.cancel();
    _hrTimer?.cancel();
    _stepsTimer = null;
    _hrTimer = null;
  }

  int get totalSimulatedSteps => _simulatedSteps;

  double get currentSimulatedHr => _simulatedHr;

  void reset() {
    stop();
    _simulatedSteps = 0;
    _simulatedHr = 72.0;
  }

  void emitSingleStep({int count = 100}) {
    if (_controller == null || _controller!.isClosed) return;
    _simulatedSteps += count;
    _controller!.add(HealthEvent(
      type: HealthEventType.steps,
      timestamp: DateTime.now(),
      value: count.toDouble(),
      sourceId: 'sim_source',
      recordId: 'sim_steps_manual_${DateTime.now().millisecondsSinceEpoch}',
    ));
  }

  void emitSingleHr({double bpm = 80}) {
    if (_controller == null || _controller!.isClosed) return;
    _simulatedHr = bpm;
    _controller!.add(HealthEvent(
      type: HealthEventType.heartRate,
      timestamp: DateTime.now(),
      value: bpm,
      sourceId: 'sim_source',
      recordId: 'sim_hr_manual_${DateTime.now().millisecondsSinceEpoch}',
    ));
  }

  List<HealthEvent> generateSyntheticHistory({
    int hoursBack = 2,
    int stepBurstsPerHour = 30,
  }) {
    final events = <HealthEvent>[];
    final now = DateTime.now();
    final startTime = now.subtract(Duration(hours: hoursBack));
    int cumulativeSteps = 0;

    for (var t = startTime; t.isBefore(now); t = t.add(const Duration(minutes: 1))) {
      if (_random.nextInt(4) == 0) {
        final steps = _random.nextInt(15) + 3;
        cumulativeSteps += steps;
        events.add(HealthEvent(
          type: HealthEventType.steps,
          timestamp: t,
          value: steps.toDouble(),
          sourceId: 'sim_source',
          recordId: 'hist_steps_${t.millisecondsSinceEpoch}',
        ));
      }

      if (_random.nextInt(6) == 0) {
        final hr = 60.0 + _random.nextDouble() * 40;
        events.add(HealthEvent(
          type: HealthEventType.heartRate,
          timestamp: t,
          value: hr.roundToDouble(),
          sourceId: 'sim_source',
          recordId: 'hist_hr_${t.millisecondsSinceEpoch}',
        ));
      }
    }

    _simulatedSteps = cumulativeSteps;
    return events;
  }

  void dispose() {
    stop();
    _controller?.close();
    _controller = null;
  }
}
