import 'package:mood_tracker/features/wearables/models/wearable_metric_type.dart';
import 'package:mood_tracker/features/wearables/models/wearable_provider.dart';

class WearableMeasurement {
  const WearableMeasurement({
    required this.provider,
    required this.metricType,
    required this.recordedAt,
    required this.value,
    required this.unit,
  });

  final WearableProvider provider;
  final WearableMetricType metricType;
  final DateTime recordedAt;
  final double value;
  final String unit;

  Map<String, dynamic> toJson() {
    return {
      'provider': provider.storageKey,
      'metricType': metricType.storageKey,
      'recordedAt': recordedAt.toIso8601String(),
      'value': value,
      'unit': unit,
    };
  }

  static WearableMeasurement fromJson(Map<String, dynamic> json) {
    return WearableMeasurement(
      provider: WearableProvider.fromStorageKey(json['provider'] as String),
      metricType: WearableMetricType.fromStorageKey(
        json['metricType'] as String,
      ),
      recordedAt: DateTime.parse(json['recordedAt'] as String),
      value: (json['value'] as num).toDouble(),
      unit: json['unit'] as String,
    );
  }
}
