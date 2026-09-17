import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import '../../data/repositories/health_repository.dart';

class PermissionsController extends GetxController with WidgetsBindingObserver {
  final HealthRepository _repository;

  PermissionsController({HealthRepository? repository})
    : _repository = repository ?? Get.find<HealthRepository>();

  final RxBool stepsGranted = false.obs;
  final RxBool heartRateGranted = false.obs;
  final RxBool allGranted = false.obs;
  final RxBool isLoading = false.obs;
  final RxBool isInitialized = false.obs;
  final RxString sdkStatus = 'unknown'.obs;
  final RxString errorMessage = ''.obs;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    checkPermissions();
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The Health Connect grant screen backgrounds the app; if the
    // requestPermissions() result never makes it back (e.g. the host
    // Activity was recreated while it was foregrounded), re-sync with
    // the actual OS-level grant state instead of trusting our stale cache.
    if (state == AppLifecycleState.resumed) {
      checkPermissions();
    }
  }

  Future<void> checkPermissions() async {
    isLoading.value = true;
    errorMessage.value = '';

    try {
      final initResult = await _repository.initialize();
      final initialized = initResult['available'] == true;
      isInitialized.value = initialized;
      sdkStatus.value = (initResult['status'] as String?) ?? 'not_available';

      if (!initialized) {
        errorMessage.value = _availabilityMessage();
        isLoading.value = false;
        return;
      }

      final result = await _repository.checkPermissions();
      stepsGranted.value = result['steps'] == true;
      heartRateGranted.value = result['heartRate'] == true;
      allGranted.value = result['allGranted'] == true;
      if (result['error'] != null) {
        errorMessage.value = 'Failed to check permissions: ${result['error']}';
      }
    } catch (e) {
      errorMessage.value = 'Failed to check permissions: $e';
    }

    isLoading.value = false;
  }

  Future<void> requestPermissions() async {
    isLoading.value = true;
    errorMessage.value = '';

    try {
      final result = await _repository.requestPermissions();
      stepsGranted.value = result['steps'] == true;
      heartRateGranted.value = result['heartRate'] == true;
      allGranted.value = result['allGranted'] == true;

      if (!allGranted.value) {
        errorMessage.value = result['error'] != null
            ? 'Failed to request permissions: ${result['error']}'
            : 'Permissions not fully granted';
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

  Future<void> installHealthConnect() async {
    errorMessage.value = '';
    await _repository.openHealthConnectStore();
  }

  String _availabilityMessage() {
    switch (sdkStatus.value) {
      case 'update_required':
        return 'The Health Connect app needs to be updated before this app '
            'can connect. Tap "Update Health Connect" below, then try again.';
      case 'not_installed':
        return 'The Health Connect app is not installed on this device. Tap '
            '"Install Health Connect" below, then try again.';
      case 'not_available':
      default:
        return 'Health Connect is not available on this device. It requires '
            'Android 8.0+ (API 28+) with the Health Connect app installed.';
    }
  }
}
