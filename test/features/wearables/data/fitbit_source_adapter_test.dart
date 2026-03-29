import 'package:flutter_test/flutter_test.dart';
import 'package:mood_tracker/features/wearables/data/fitbit_source_adapter.dart';
import 'package:mood_tracker/features/wearables/models/wearable_metric_type.dart';
import 'package:mood_tracker/features/wearables/models/wearable_provider.dart';

void main() {
  final sourceDate = DateTime(2026, 3, 29, 18, 45);

  test(
    'creates two daily wearable metrics when sleep and resting heart rate exist',
    () async {
      final adapter = FitbitSourceAdapter(
        fetchSnapshot: (_) async => FitbitDailySnapshot(
          date: sourceDate,
          sleepDurationMin: 420,
          restingHeartRateBpm: 56,
        ),
      );

      final metrics = await adapter.fetchDailyMetrics(sourceDate);

      expect(metrics, hasLength(2));

      expect(metrics[0].provider, WearableProvider.fitbit);
      expect(metrics[0].metricType, WearableMetricType.sleepDurationMin);
      expect(metrics[0].unit, WearableMetricType.sleepDurationMin.canonicalUnit);
      expect(metrics[0].value, 420);
      expect(metrics[0].date, DateTime(2026, 3, 29));

      expect(metrics[1].provider, WearableProvider.fitbit);
      expect(metrics[1].metricType, WearableMetricType.restingHeartRateBpm);
      expect(
        metrics[1].unit,
        WearableMetricType.restingHeartRateBpm.canonicalUnit,
      );
      expect(metrics[1].value, 56);
      expect(metrics[1].date, DateTime(2026, 3, 29));
    },
  );

  test('creates only sleep metric when only sleep exists', () async {
    final adapter = FitbitSourceAdapter(
      fetchSnapshot: (_) async => FitbitDailySnapshot(
        date: sourceDate,
        sleepDurationMin: 398,
      ),
    );

    final metrics = await adapter.fetchDailyMetrics(sourceDate);

    expect(metrics, hasLength(1));
    expect(metrics.single.provider, WearableProvider.fitbit);
    expect(metrics.single.metricType, WearableMetricType.sleepDurationMin);
    expect(metrics.single.unit, WearableMetricType.sleepDurationMin.canonicalUnit);
    expect(metrics.single.value, 398);
    expect(metrics.single.date, DateTime(2026, 3, 29));
  });

  test(
    'creates only resting heart rate metric when only resting heart rate exists',
    () async {
      final adapter = FitbitSourceAdapter(
        fetchSnapshot: (_) async => FitbitDailySnapshot(
          date: sourceDate,
          restingHeartRateBpm: 61,
        ),
      );

      final metrics = await adapter.fetchDailyMetrics(sourceDate);

      expect(metrics, hasLength(1));
      expect(metrics.single.provider, WearableProvider.fitbit);
      expect(metrics.single.metricType, WearableMetricType.restingHeartRateBpm);
      expect(
        metrics.single.unit,
        WearableMetricType.restingHeartRateBpm.canonicalUnit,
      );
      expect(metrics.single.value, 61);
      expect(metrics.single.date, DateTime(2026, 3, 29));
    },
  );

  test('creates no metrics when both snapshot values are null', () async {
    final adapter = FitbitSourceAdapter(
      fetchSnapshot: (_) async => FitbitDailySnapshot(
        date: sourceDate,
      ),
    );

    final metrics = await adapter.fetchDailyMetrics(sourceDate);

    expect(metrics, isEmpty);
  });
}
