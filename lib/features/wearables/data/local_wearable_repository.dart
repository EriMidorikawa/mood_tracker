import 'dart:convert';

import 'package:mood_tracker/features/wearables/models/daily_wearable_metric.dart';
import 'package:mood_tracker/features/wearables/models/wearable_connection.dart';
import 'package:mood_tracker/features/wearables/models/wearable_measurement.dart';
import 'package:mood_tracker/features/wearables/models/wearable_metric_type.dart';
import 'package:mood_tracker/features/wearables/models/wearable_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalWearableRepository {
  static const _connectionsKey = 'wearables.connections';
  static const _measurementsKey = 'wearables.measurements';
  static const _dailyMetricsKey = 'wearables.daily_metrics';

  Future<List<WearableConnection>> loadConnections() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_connectionsKey);
    if (raw == null || raw.isEmpty) {
      return const [];
    }

    final decoded = jsonDecode(raw) as List<dynamic>;
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
    final preferences = await SharedPreferences.getInstance();
    final connections = await loadConnections();
    final nextConnections = [
      for (final item in connections)
        if (item.provider != connection.provider) item,
      connection,
    ];

    await preferences.setString(
      _connectionsKey,
      jsonEncode([
        for (final item in nextConnections) item.toJson(),
      ]),
    );
  }

  Future<List<WearableMeasurement>> loadMeasurements({
    WearableProvider? provider,
    WearableMetricType? metricType,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_measurementsKey);
    if (raw == null || raw.isEmpty) {
      return const [];
    }

    final decoded = jsonDecode(raw) as List<dynamic>;
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
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _measurementsKey,
      jsonEncode([
        for (final item in measurements) item.toJson(),
      ]),
    );
  }

  Future<List<DailyWearableMetric>> loadDailyMetrics({
    WearableProvider? provider,
    WearableMetricType? metricType,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_dailyMetricsKey);
    if (raw == null || raw.isEmpty) {
      return const [];
    }

    final decoded = jsonDecode(raw) as List<dynamic>;
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

  Future<void> saveDailyMetrics(List<DailyWearableMetric> metrics) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _dailyMetricsKey,
      jsonEncode([
        for (final item in metrics) item.toJson(),
      ]),
    );
  }
}
