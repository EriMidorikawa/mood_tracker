import 'package:mood_tracker/features/wearables/models/daily_wearable_metric.dart';
import 'package:mood_tracker/features/wearables/models/wearable_metric_type.dart';
import 'package:mood_tracker/features/wearables/models/wearable_provider.dart';

class FitbitSourceAdapter {
  const FitbitSourceAdapter({
    required this.fetchSnapshot,
    this.sourceId = 'fitbit',
  });

  final Future<FitbitDailySnapshot> Function(DateTime date) fetchSnapshot;
  final String sourceId;

  Future<List<DailyWearableMetric>> fetchDailyMetrics(DateTime date) async {
    final day = _dateOnly(date);
    final snapshot = await fetchSnapshot(day);

    return [
      if (snapshot.sleepDurationMin != null)
        DailyWearableMetric(
          provider: WearableProvider.fitbit,
          metricType: WearableMetricType.sleepDurationMin,
          date: day,
          value: snapshot.sleepDurationMin!.toDouble(),
          unit: WearableMetricType.sleepDurationMin.canonicalUnit,
          sourceId: sourceId,
        ),
      if (snapshot.restingHeartRateBpm != null)
        DailyWearableMetric(
          provider: WearableProvider.fitbit,
          metricType: WearableMetricType.restingHeartRateBpm,
          date: day,
          value: snapshot.restingHeartRateBpm!,
          unit: WearableMetricType.restingHeartRateBpm.canonicalUnit,
          sourceId: sourceId,
        ),
    ];
  }
}

class FitbitDailySnapshot {
  const FitbitDailySnapshot({
    required this.date,
    this.sleepDurationMin,
    this.restingHeartRateBpm,
  });

  final DateTime date;
  final int? sleepDurationMin;
  final double? restingHeartRateBpm;
}

DateTime _dateOnly(DateTime dateTime) {
  return DateTime(dateTime.year, dateTime.month, dateTime.day);
}
