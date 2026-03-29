import 'package:mood_tracker/features/wearables/models/wearable_metric_type.dart';
import 'package:mood_tracker/features/wearables/models/wearable_provider.dart';

class DailyWearableMetric {
  const DailyWearableMetric({
    required this.provider,
    required this.metricType,
    required this.date,
    required this.value,
    required this.unit,
    this.sourceId,
  });

  final WearableProvider provider;
  final WearableMetricType metricType;
  final DateTime date;
  final double value;
  final String unit;
  final String? sourceId;

  Map<String, dynamic> toJson() {
    return {
      'provider': provider.storageKey,
      'metricType': metricType.storageKey,
      'date': date.toIso8601String(),
      'value': value,
      'unit': unit,
      'sourceId': sourceId,
    };
  }

  static DailyWearableMetric fromJson(Map<String, dynamic> json) {
    return DailyWearableMetric(
      provider: WearableProvider.fromStorageKey(json['provider'] as String),
      metricType: WearableMetricType.fromStorageKey(
        json['metricType'] as String,
      ),
      date: DateTime.parse(json['date'] as String),
      value: (json['value'] as num).toDouble(),
      unit: json['unit'] as String,
      sourceId: json['sourceId'] as String?,
    );
  }
}
