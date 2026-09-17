import 'dart:async';
import 'package:flutter/services.dart';

class PlatformChannel {
  static const MethodChannel _method =
      MethodChannel('com.example.health_connect/method');
  static const EventChannel _event =
      EventChannel('com.example.health_connect/events');

  StreamController<List<Map<String, dynamic>>>? _eventController;
  StreamSubscription? _eventSubscription;
  bool _initialized = false;

  Future<Map<String, dynamic>> initialize() async {
    if (_initialized) return {'available': true};
    try {
      final result = await _method.invokeMethod<Map>('initialize');
      final map = Map<String, dynamic>.from(result ?? {});
      _initialized = map['available'] == true;
      return map;
    } catch (e) {
      return {'available': false, 'status': 'not_available', 'error': e.toString()};
    }
  }

  Stream<List<Map<String, dynamic>>> get eventStream {
    _eventController ??= StreamController<List<Map<String, dynamic>>>.broadcast();
    _eventSubscription ??= _event.receiveBroadcastStream().listen(
      (dynamic data) {
        if (data is List) {
          final events = data
              .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
              .toList();
          _eventController?.add(events);
        }
      },
      onError: (dynamic error) {
        _eventController?.addError(error);
      },
    );
    return _eventController!.stream;
  }

  Future<Map<String, dynamic>> checkPermissions() async {
    try {
      final result = await _method.invokeMethod<Map>('checkPermissions');
      return Map<String, dynamic>.from(result ?? {});
    } catch (e) {
      return {'allGranted': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> requestPermissions() async {
    try {
      final result = await _method.invokeMethod<Map>('requestPermissions');
      return Map<String, dynamic>.from(result ?? {});
    } catch (e) {
      return {'allGranted': false, 'error': e.toString()};
    }
  }

  Future<int> readStepsToday() async {
    try {
      final result = await _method.invokeMethod<Map>('readStepsToday');
      return (result?['total'] as num?)?.toInt() ?? 0;
    } catch (e) {
      return 0;
    }
  }

  Future<Map<String, dynamic>> readLatestHeartRate() async {
    try {
      final result = await _method.invokeMethod<Map>('readLatestHeartRate');
      return Map<String, dynamic>.from(result ?? {});
    } catch (e) {
      return {'bpm': 0, 'timestamp': 0};
    }
  }

  Future<bool> startListening() async {
    try {
      return await _method.invokeMethod<bool>('startListening') ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> stopListening() async {
    try {
      return await _method.invokeMethod<bool>('stopListening') ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> openHealthConnectStore() async {
    try {
      return await _method.invokeMethod<bool>('openHealthConnectStore') ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> readStepsRange(
      DateTime start, DateTime end) async {
    try {
      final result = await _method.invokeMethod<List>('readStepsRange', {
        'startMs': start.millisecondsSinceEpoch,
        'endMs': end.millisecondsSinceEpoch,
      });
      return (result ?? [])
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> readHeartRateRange(
      DateTime start, DateTime end) async {
    try {
      final result = await _method.invokeMethod<List>('readHeartRateRange', {
        'startMs': start.millisecondsSinceEpoch,
        'endMs': end.millisecondsSinceEpoch,
      });
      return (result ?? [])
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (e) {
      return [];
    }
  }

  void dispose() {
    _eventSubscription?.cancel();
    _eventController?.close();
    _eventController = null;
    _eventSubscription = null;
    _initialized = false;
  }
}
