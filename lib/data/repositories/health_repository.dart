import 'dart:async';
import 'dart:collection';
import 'package:get/get.dart';
import '../models/health_event.dart';
import '../sources/platform_channel.dart';
import '../sources/sim_source.dart';
import '../../core/constants.dart';

class HealthRepository {
  final PlatformChannel _platformChannel;
  final SimSource _simSource;

  final RxList<HealthEvent> allEvents = <HealthEvent>[].obs;

  final _eventController = StreamController<HealthEvent>.broadcast();
  Stream<HealthEvent> get eventStream => _eventController.stream;

  StreamSubscription? _nativeSubscription;
  StreamSubscription? _simSubscription;

  final Set<String> _seenRecordIds = {};
  final Queue<HealthEvent> _eventBuffer = Queue<HealthEvent>();
  Timer? _debounceTimer;
  bool _nativeListening = false;

  HealthRepository({
    PlatformChannel? platformChannel,
    SimSource? simSource,
  })  : _platformChannel = platformChannel ?? PlatformChannel(),
        _simSource = simSource ?? SimSource();

  Future<bool> initialize() async {
    return await _platformChannel.initialize();
  }

  Future<Map<String, dynamic>> checkPermissions() async {
    return await _platformChannel.checkPermissions();
  }

  Future<Map<String, dynamic>> requestPermissions() async {
    return await _platformChannel.requestPermissions();
  }

  Future<void> loadInitialData() async {
    final now = DateTime.now();
    final stepsToday = await _platformChannel.readStepsToday();
    if (stepsToday > 0) {
      allEvents.add(HealthEvent(
        type: HealthEventType.steps,
        timestamp: now,
        value: stepsToday.toDouble(),
        sourceId: 'initial_load',
        recordId: 'initial_steps_${now.millisecondsSinceEpoch}',
      ));
    }

    final hrData = await _platformChannel.readLatestHeartRate();
    final hrBpm = (hrData['bpm'] as num?)?.toDouble() ?? 0;
    if (hrBpm > 0) {
      final hrTimestamp = DateTime.fromMillisecondsSinceEpoch(
        hrData['timestamp'] as int? ?? now.millisecondsSinceEpoch,
      );
      allEvents.add(HealthEvent(
        type: HealthEventType.heartRate,
        timestamp: hrTimestamp,
        value: hrBpm,
        sourceId: 'initial_load',
        recordId: 'initial_hr_${hrTimestamp.millisecondsSinceEpoch}',
      ));
    }
  }

  Future<void> startNativeListening() async {
    if (_nativeListening) return;
    _nativeListening = true;

    await _platformChannel.startListening();
    _nativeSubscription = _platformChannel.eventStream.listen((events) {
      for (final eventMap in events) {
        final event = HealthEvent.fromMap(eventMap);
        _processEvent(event);
      }
    });
  }

  void startSimListening() {
    _simSubscription = _simSource.eventStream.listen((event) {
      _processEvent(event);
    });
  }

  void stopSimListening() {
    _simSubscription?.cancel();
    _simSubscription = null;
  }

  void startSimSource() => _simSource.start();
  void stopSimSource() => _simSource.stop();
  bool get isSimActive => _simSource.isActive;

  void _processEvent(HealthEvent event) {
    if (event.recordId.isNotEmpty && _seenRecordIds.contains(event.recordId)) {
      return;
    }
    if (event.recordId.isNotEmpty) {
      _seenRecordIds.add(event.recordId);
      if (_seenRecordIds.length > 5000) {
        _seenRecordIds.clear();
      }
    }

    _eventBuffer.addLast(event);
    _debounceTimer?.cancel();
    _debounceTimer = Timer(AppConstants.debounceDuration, _flushBuffer);
  }

  void _flushBuffer() {
    while (_eventBuffer.isNotEmpty) {
      final event = _eventBuffer.removeFirst();
      allEvents.add(event);
      _eventController.add(event);
    }

    if (allEvents.length > 10000) {
      allEvents.removeRange(0, allEvents.length - 5000);
    }
  }

  List<HealthEvent> getStepsEvents() {
    return allEvents
        .where((e) => e.type == HealthEventType.steps)
        .toList();
  }

  List<HealthEvent> getHeartRateEvents() {
    return allEvents
        .where((e) => e.type == HealthEventType.heartRate)
        .toList();
  }

  List<HealthEvent> getStepsEventsInWindow(Duration window) {
    final cutoff = DateTime.now().subtract(window);
    return allEvents
        .where((e) => e.type == HealthEventType.steps && e.timestamp.isAfter(cutoff))
        .toList();
  }

  List<HealthEvent> getHeartRateEventsInWindow(Duration window) {
    final cutoff = DateTime.now().subtract(window);
    return allEvents
        .where((e) =>
            e.type == HealthEventType.heartRate && e.timestamp.isAfter(cutoff))
        .toList();
  }

  double getTotalStepsToday() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    return allEvents
        .where((e) =>
            e.type == HealthEventType.steps &&
            e.timestamp.isAfter(startOfDay))
        .fold(0.0, (sum, e) => sum + e.value);
  }

  double getLatestHeartRate() {
    final hrEvents = getHeartRateEvents();
    if (hrEvents.isEmpty) return 0;
    hrEvents.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return hrEvents.first.value;
  }

  DateTime? getLatestHeartRateTimestamp() {
    final hrEvents = getHeartRateEvents();
    if (hrEvents.isEmpty) return null;
    hrEvents.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return hrEvents.first.timestamp;
  }

  void injectEventsForTest(List<HealthEvent> events) {
    for (final event in events) {
      _processEvent(event);
    }
    _flushBuffer();
  }

  void injectForTest(HealthEvent event) {
    _processEvent(event);
  }

  void startTestOnly() {}

  void flushForTest() {
    _flushBuffer();
  }

  int get stepsEventsCount => getStepsEvents().length;

  int get heartRateEventsCount => getHeartRateEvents().length;

  void clearEvents() {
    allEvents.clear();
    _seenRecordIds.clear();
    _eventBuffer.clear();
  }

  Future<void> stopNativeListening() async {
    _nativeListening = false;
    _nativeSubscription?.cancel();
    _nativeSubscription = null;
    await _platformChannel.stopListening();
  }

  void dispose() {
    _nativeSubscription?.cancel();
    _simSubscription?.cancel();
    _debounceTimer?.cancel();
    _eventController.close();
    _simSource.dispose();
    _platformChannel.dispose();
  }
}
