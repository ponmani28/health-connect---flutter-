class AppConstants {
  AppConstants._();

  static const String appName = 'Health Connect Dashboard';
  static const String packageName = 'com.example.health_connect';

  static const String salt =
      '0023fd6abf0ae1f5781f7ec5000af34eb6e2b99450b014bea186101054cf5077';

  static const int stepsPollingIntervalMs = 5000;
  static const int hrPollingIntervalMs = 5000;

  static const int chartWindowMinutes = 60;
  static const int chartDecimationTarget = 200;

  static const int maxRawRetentionDays = 7;
  static const int maxAggregateRetentionDays = 30;

  static const double targetFps = 60.0;
  static const double maxBuildTimeMs = 8.0;

  static const int bucketSizeSeconds = 60;
  static const int maxChartPoints = 300;

  static const Duration uiLatencyTarget = Duration(seconds: 10);
  static const Duration pollInterval = Duration(seconds: 5);

  static const Duration debounceDuration = Duration(milliseconds: 300);
}
