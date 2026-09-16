import 'package:get/get.dart';
import 'package:health/health.dart';
import '../../data/repositories/health_repository.dart';

class PermissionsController extends GetxController {
  final HealthRepository _repository;

  PermissionsController({HealthRepository? repository})
      : _repository = repository ?? Get.find<HealthRepository>();

  final RxBool stepsGranted = false.obs;
  final RxBool heartRateGranted = false.obs;
  final RxBool allGranted = false.obs;
  final RxBool isLoading = false.obs;
  final RxBool isInitialized = false.obs;
  final RxString errorMessage = ''.obs;

  @override
  void onInit() {
    super.onInit();
    checkPermissions();
  }

  Future<void> checkPermissions() async {
    isLoading.value = true;
    errorMessage.value = '';

    try {
      final initialized = await _repository.initialize();
      isInitialized.value = initialized;

      if (!initialized) {
        errorMessage.value = 'Health Connect is not available on this device';
        isLoading.value = false;
        return;
      }

      final result = await _repository.checkPermissions();
      stepsGranted.value = result['steps'] == true;
      heartRateGranted.value = result['heartRate'] == true;
      allGranted.value = result['allGranted'] == true;
    } catch (e) {
      errorMessage.value = 'Failed to check permissions: $e';
    }

    isLoading.value = false;
  }

  Future<void> requestPermissions() async {
    isLoading.value = true;
    errorMessage.value = '';

    try {
      final health = Health();
      final types = [HealthDataType.STEPS, HealthDataType.HEART_RATE];
      final requested = await health.requestAuthorization(types);
      stepsGranted.value = requested;
      heartRateGranted.value = requested;
      allGranted.value = requested;

      if (!allGranted.value) {
        errorMessage.value = 'Permissions not fully granted';
      } else {
        final result = await _repository.checkPermissions();
        stepsGranted.value = result['steps'] == true;
        heartRateGranted.value = result['heartRate'] == true;
        allGranted.value = result['allGranted'] == true;
      }
    } catch (e) {
      errorMessage.value = 'Failed to request permissions: $e';
    }

    isLoading.value = false;
  }

  void navigateToDashboard() {
    if (allGranted.value) {
      Get.offAllNamed('/dashboard');
    }
  }
}
