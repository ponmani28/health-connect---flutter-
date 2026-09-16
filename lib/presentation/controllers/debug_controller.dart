import 'package:get/get.dart';
import '../../data/repositories/health_repository.dart';
import '../../data/sources/sim_source.dart';

class DebugController extends GetxController {
  final HealthRepository _repository;
  final SimSource _simSource;

  DebugController({
    HealthRepository? repository,
    SimSource? simSource,
  })  : _repository = repository ?? Get.find<HealthRepository>(),
        _simSource = simSource ?? Get.find<SimSource>();

  final RxBool simEnabled = false.obs;
  final RxInt emittedSteps = 0.obs;
  final RxDouble emittedHr = 0.0.obs;
  final RxInt totalEventsEmitted = 0.obs;

  void toggleSimSource() {
    simEnabled.value = !simEnabled.value;
    if (simEnabled.value) {
      _repository.startSimListening();
      _repository.startSimSource();
    } else {
      _repository.stopSimSource();
    }
  }

  void emitSteps({int count = 100}) {
    _simSource.emitSingleStep(count: count);
    emittedSteps.value += count;
    totalEventsEmitted.value++;
  }

  void emitHeartRate({double bpm = 80}) {
    _simSource.emitSingleHr(bpm: bpm);
    emittedHr.value = bpm;
    totalEventsEmitted.value++;
  }

  void injectHistory() {
    final events = _simSource.generateSyntheticHistory(hoursBack: 2);
    _repository.injectEventsForTest(events);
    totalEventsEmitted.value += events.length;
  }

  void clearAllData() {
    _repository.clearEvents();
    emittedSteps.value = 0;
    emittedHr.value = 0;
    totalEventsEmitted.value = 0;
  }

  @override
  void onClose() {
    _repository.stopSimSource();
    super.onClose();
  }
}
