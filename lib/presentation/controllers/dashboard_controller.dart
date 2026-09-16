import 'dart:async';
import 'package:get/get.dart';
import '../../data/models/chart_point.dart';
import '../../data/models/health_event.dart';
import '../../data/repositories/health_repository.dart';
import '../../core/constants.dart';
import '../../core/perf_monitor.dart';

class DashboardController extends GetxController {
  final HealthRepository _repository;

  DashboardController({HealthRepository? repository})
      : _repository = repository ?? Get.find<HealthRepository>();

  final RxInt totalStepsToday = 0.obs;
  final RxDouble currentHeartRate = 0.0.obs;
  final Rxn<DateTime> heartRateTimestamp = Rxn<DateTime>();
  final RxString heartRateAge = ''.obs;

  final RxList<ChartPoint> stepsChartData = <ChartPoint>[].obs;
  final RxList<ChartPoint> hrChartData = <ChartPoint>[].obs;

  final RxDouble avgBuildTimeMs = 0.0.obs;
  final RxDouble lastPaintTimeMs = 0.0.obs;
  final RxDouble fps = 0.0.obs;
  final RxBool meetsBuildTarget = true.obs;
  final RxInt totalUpdatesReceived = 0.obs;

  final RxBool isListening = false.obs;

  final perfMonitor = PerformanceMonitor();
  Timer? _ageUpdateTimer;
  StreamSubscription? _eventSubscription;

  @override
  void onInit() {
    super.onInit();
    _startListening();
    _startHeartRateAgeUpdater();
  }

  void _startListening() async {
    _eventSubscription = _repository.eventStream.listen((event) {
      _processEvent(event);
    });

    isListening.value = true;
  }

  void _processEvent(HealthEvent event) {
    totalUpdatesReceived.value++;

    if (event.type == HealthEventType.steps) {
      totalStepsToday.value = _repository.getTotalStepsToday().toInt();
      _updateStepsChart();
    } else if (event.type == HealthEventType.heartRate) {
      currentHeartRate.value = event.value;
      heartRateTimestamp.value = event.timestamp;
      _updateHrChart();
    }

    perfMonitor.recordFrame();
    _updatePerfHud();
  }

  void _updateStepsChart() {
    const window = Duration(minutes: AppConstants.chartWindowMinutes);
    final events = _repository.getStepsEventsInWindow(window);
    final bucketed = _bucketizeEvents(
      events,
      const Duration(seconds: AppConstants.bucketSizeSeconds),
    );
    stepsChartData.value = bucketed;
  }

  void _updateHrChart() {
    const window = Duration(minutes: AppConstants.chartWindowMinutes);
    final events = _repository.getHeartRateEventsInWindow(window);
    final bucketed = _bucketizeEvents(
      events,
      const Duration(seconds: AppConstants.bucketSizeSeconds),
    );
    hrChartData.value = bucketed;
  }

  List<ChartPoint> _bucketizeEvents(
      List<HealthEvent> events, Duration bucketSize) {
    if (events.isEmpty) return [];

    events.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final buckets = <DateTime, List<HealthEvent>>{};

    for (final event in events) {
      final bucketKey = DateTime(
        event.timestamp.year,
        event.timestamp.month,
        event.timestamp.day,
        event.timestamp.hour,
        event.timestamp.minute,
        (event.timestamp.second ~/ bucketSize.inSeconds) * bucketSize.inSeconds,
      );
      buckets.putIfAbsent(bucketKey, () => []).add(event);
    }

    return buckets.entries.map<ChartPoint>((entry) {
      final avg = entry.value.map((e) => e.value).reduce((a, b) => a + b) /
          entry.value.length;
      return ChartPoint(timestamp: entry.key, value: avg);
    }).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  void _startHeartRateAgeUpdater() {
    _ageUpdateTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _updateHeartRateAge();
    });
  }

  void _updateHeartRateAge() {
    final ts = heartRateTimestamp.value;
    if (ts == null) {
      heartRateAge.value = 'No data';
      return;
    }
    final diff = DateTime.now().difference(ts);
    if (diff.inSeconds < 60) {
      heartRateAge.value = '${diff.inSeconds}s ago';
    } else if (diff.inMinutes < 60) {
      heartRateAge.value = '${diff.inMinutes}m ago';
    } else {
      heartRateAge.value = '${diff.inHours}h ago';
    }
  }

  void updateAgeForTest() {
    _updateHeartRateAge();
  }

  void _updatePerfHud() {
    avgBuildTimeMs.value = perfMonitor.avgBuildTimeMs;
    lastPaintTimeMs.value = perfMonitor.lastPaintTimeMs;
    fps.value = perfMonitor.fps;
    meetsBuildTarget.value = perfMonitor.meetsBuildTarget;
  }

  void updatePerfHudForTest() {
    _updatePerfHud();
  }

  void loadTestData(List<HealthEvent> events) {
    _repository.clearEvents();
    _repository.injectEventsForTest(events);
    totalStepsToday.value = _repository.getTotalStepsToday().toInt();
    final latestHr = _repository.getLatestHeartRate();
    if (latestHr > 0) {
      currentHeartRate.value = latestHr;
      heartRateTimestamp.value = _repository.getLatestHeartRateTimestamp();
    }
    _updateStepsChart();
    _updateHrChart();
  }

  void toggleSimSource() {
    if (_repository.isSimActive) {
      _repository.stopSimSource();
    } else {
      _repository.startSimListening();
      _repository.startSimSource();
    }
  }

  Future<void> refreshData() async {
    await _repository.loadInitialData();
    _updateStepsChart();
    _updateHrChart();
  }

  @override
  void onClose() {
    _ageUpdateTimer?.cancel();
    _eventSubscription?.cancel();
    _repository.stopSimSource();
    super.onClose();
  }
}
