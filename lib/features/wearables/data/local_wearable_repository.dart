import 'dart:convert';

import 'package:mood_tracker/features/wearables/models/daily_wearable_metric.dart';
import 'package:mood_tracker/features/wearables/models/wearable_connection.dart';
import 'package:mood_tracker/features/wearables/models/wearable_measurement.dart';
import 'package:mood_tracker/features/wearables/models/wearable_metric_type.dart';
import 'package:mood_tracker/features/wearables/models/wearable_provider.dart';
import 'package:mood_tracker/shared/date_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalWearableRepository {
  static const _connectionsKey = 'wearables.connections';
  static const _measurementsKey = 'wearables.measurements';
  static const _dailyMetricsKey = 'wearables.daily_metrics';

  Future<List<WearableConnection>> loadConnections() async {
    final decoded = await _readJsonList(_connectionsKey);
    return decoded
        .map((item) => WearableConnection.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<WearableConnection?> loadConnection(WearableProvider provider) async {
    final connections = await loadConnections();
    for (final connection in connections) {
      if (connection.provider == provider) {
        return connection;
      }
    }
    return null;
  }

  Future<void> upsertConnection(WearableConnection connection) async {
    final connections = await loadConnections();
    final nextConnections = [
      for (final item in connections)
        if (item.provider != connection.provider) item,
      connection,
    ];

    await _writeJsonList(
      _connectionsKey,
      [
        for (final item in nextConnections) item.toJson(),
      ],
    );
  }

  Future<List<WearableMeasurement>> loadMeasurements({
    WearableProvider? provider,
    WearableMetricType? metricType,
  }) async {
    final decoded = await _readJsonList(_measurementsKey);
    final items = decoded
        .map((item) => WearableMeasurement.fromJson(item as Map<String, dynamic>))
        .toList();

    return [
      for (final item in items)
        if ((provider == null || item.provider == provider) &&
            (metricType == null || item.metricType == metricType))
          item,
    ];
  }

  Future<void> saveMeasurements(List<WearableMeasurement> measurements) async {
    await _writeJsonList(
      _measurementsKey,
      [
        for (final item in measurements) item.toJson(),
      ],
    );
  }

  Future<DailyWearableMetric?> aggregateDailyMetric({
    required WearableProvider provider,
    required WearableMetricType metricType,
    required DateTime date,
  }) async {
    final day = dateOnly(date);
    final measurements = await loadMeasurements(
      provider: provider,
      metricType: metricType,
    );

    final values = [
      for (final measurement in measurements)
        if (dateOnly(measurement.recordedAt) == day) measurement.value,
    ];

    // Keep the same missing-data policy as Daily Log / Trends:
    // no record for the day means no value for the day.
    if (values.isEmpty) {
      return null;
    }

    final aggregatedValue = switch (metricType.aggregationRule) {
      WearableAggregationRule.dailySum => values.fold<double>(
          0,
          (sum, value) => sum + value,
        ),
      WearableAggregationRule.dailyAverage =>
        values.reduce((sum, value) => sum + value) / values.length,
    };

    return DailyWearableMetric(
      provider: provider,
      metricType: metricType,
      date: day,
      value: aggregatedValue,
      unit: metricType.canonicalUnit,
    );
  }

  Future<List<DailyWearableMetric>> loadDailyMetrics({
    WearableProvider? provider,
    WearableMetricType? metricType,
  }) async {
    final decoded = await _readJsonList(_dailyMetricsKey);
    final items = decoded
        .map((item) => DailyWearableMetric.fromJson(item as Map<String, dynamic>))
        .toList();

    return [
      for (final item in items)
        if ((provider == null || item.provider == provider) &&
            (metricType == null || item.metricType == metricType))
          item,
    ];
  }

  Future<List<DailyWearableMetric>> loadDailyMetricsInRange({
    required DateTime startDate,
    required DateTime endDate,
    WearableProvider? provider,
    WearableMetricType? metricType,
  }) async {
    final start = dateOnly(startDate);
    final end = dateOnly(endDate);
    final metrics = await loadDailyMetrics(
      provider: provider,
      metricType: metricType,
    );

    final filtered = [
      for (final metric in metrics)
        if (!dateOnly(metric.date).isBefore(start) &&
            !dateOnly(metric.date).isAfter(end))
          metric,
    ]..sort((a, b) => dateOnly(a.date).compareTo(dateOnly(b.date)));

    return filtered;
  }

  Future<void> saveDailyMetrics(List<DailyWearableMetric> metrics) async {
    await _writeJsonList(
      _dailyMetricsKey,
      [
        for (final item in metrics) item.toJson(),
      ],
    );
  }

  Future<void> upsertDailyMetrics(List<DailyWearableMetric> metrics) async {
    final existingMetrics = await loadDailyMetrics();
    final nextMetrics = [
      for (final existing in existingMetrics)
        if (!_containsSameDailyMetric(metrics, existing)) existing,
      ...metrics,
    ];

    await saveDailyMetrics(nextMetrics);
  }

  Future<void> clearDailyMetrics() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_dailyMetricsKey);
  }

  Future<void> clearConnections() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_connectionsKey);
  }

  Future<List<dynamic>> _readJsonList(String key) async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(key);
    if (raw == null || raw.isEmpty) {
      return const [];
    }

    return jsonDecode(raw) as List<dynamic>;
  }

  Future<void> _writeJsonList(String key, List<Object?> items) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(key, jsonEncode(items));
  }
}

bool _containsSameDailyMetric(
  List<DailyWearableMetric> metrics,
  DailyWearableMetric candidate,
) {
  for (final metric in metrics) {
    if (metric.provider == candidate.provider &&
        metric.metricType == candidate.metricType &&
        dateOnly(metric.date) == dateOnly(candidate.date)) {
      return true;
    }
  }

  return false;
}
