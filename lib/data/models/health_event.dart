enum HealthEventType { steps, heartRate }

class HealthEvent {
  final HealthEventType type;
  final DateTime timestamp;
  final double value;
  final String sourceId;
  final String recordId;

  const HealthEvent({
    required this.type,
    required this.timestamp,
    required this.value,
    required this.sourceId,
    required this.recordId,
  });

  factory HealthEvent.fromMap(Map<dynamic, dynamic> map) {
    return HealthEvent(
      type: map['type'] == 'steps'
          ? HealthEventType.steps
          : HealthEventType.heartRate,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      value: (map['value'] as num).toDouble(),
      sourceId: map['sourceId'] as String? ?? '',
      recordId: map['recordId'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'type': type == HealthEventType.steps ? 'steps' : 'heartRate',
        'timestamp': timestamp.millisecondsSinceEpoch,
        'value': value,
        'sourceId': sourceId,
        'recordId': recordId,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HealthEvent &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          timestamp == other.timestamp &&
          value == other.value;

  @override
  int get hashCode => Object.hash(type, timestamp, value);

  bool isDuplicateOf(HealthEvent other) =>
      type == other.type && recordId == other.recordId && recordId.isNotEmpty;
}
