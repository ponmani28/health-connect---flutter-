import 'dart:collection';

class PerformanceMonitor {
  final Queue<double> _buildTimes = Queue<double>();
  final Queue<double> _paintTimes = Queue<double>();
  final Queue<int> _frameTimesUs = Queue<int>();

  static const int _maxSamples = 120;

  double _currentFps = 0;
  DateTime? _lastFrameTime;

  void recordBuildTime(double milliseconds) {
    _buildTimes.addLast(milliseconds);
    if (_buildTimes.length > _maxSamples) {
      _buildTimes.removeFirst();
    }
  }

  void recordPaintTime(double milliseconds) {
    _paintTimes.addLast(milliseconds);
    if (_paintTimes.length > _maxSamples) {
      _paintTimes.removeFirst();
    }
  }

  void recordFrame() {
    final now = DateTime.now();
    if (_lastFrameTime != null) {
      final delta = now.difference(_lastFrameTime!).inMicroseconds;
      _frameTimesUs.addLast(delta);
      if (_frameTimesUs.length > _maxSamples) {
        _frameTimesUs.removeFirst();
      }
      _computeFps();
    }
    _lastFrameTime = now;
  }

  void _computeFps() {
    if (_frameTimesUs.isEmpty) {
      _currentFps = 0;
      return;
    }
    final avgFrameTimeUs =
        _frameTimesUs.reduce((a, b) => a + b) / _frameTimesUs.length;
    _currentFps = avgFrameTimeUs > 0 ? 1000000.0 / avgFrameTimeUs : 0;
  }

  double get avgBuildTimeMs {
    if (_buildTimes.isEmpty) return 0;
    return _buildTimes.reduce((a, b) => a + b) / _buildTimes.length;
  }

  double get lastPaintTimeMs =>
      _paintTimes.isEmpty ? 0 : _paintTimes.last;

  double get avgPaintTimeMs {
    if (_paintTimes.isEmpty) return 0;
    return _paintTimes.reduce((a, b) => a + b) / _paintTimes.length;
  }

  double get fps => _currentFps;

  bool get meetsBuildTarget => avgBuildTimeMs <= 8.0;

  void reset() {
    _buildTimes.clear();
    _paintTimes.clear();
    _frameTimesUs.clear();
    _currentFps = 0;
    _lastFrameTime = null;
  }
}
