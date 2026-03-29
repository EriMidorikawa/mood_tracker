import 'package:flutter_test/flutter_test.dart';
import 'package:mood_tracker/features/wearables/data/local_wearable_repository.dart';
import 'package:mood_tracker/features/wearables/models/daily_wearable_metric.dart';
import 'package:mood_tracker/features/wearables/models/wearable_metric_type.dart';
import 'package:mood_tracker/features/wearables/models/wearable_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late LocalWearableRepository repository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = LocalWearableRepository();
  });

  test('saves and loads two daily metrics', () async {
    final today = DateTime(2026, 3, 29);
    final metrics = [
      DailyWearableMetric(
        provider: WearableProvider.manual,
        metricType: WearableMetricType.sleepDurationMin,
        date: today,
        value: 430,
        unit: 'min',
      ),
      DailyWearableMetric(
        provider: WearableProvider.manual,
        metricType: WearableMetricType.restingHeartRateBpm,
        date: today,
        value: 58,
        unit: 'bpm',
      ),
    ];

    await repository.upsertDailyMetrics(metrics);
    final loaded = await repository.loadDailyMetrics();

    expect(loaded, hasLength(2));
    expect(
      loaded.any(
        (metric) =>
            metric.provider == WearableProvider.manual &&
            metric.metricType == WearableMetricType.sleepDurationMin &&
            metric.value == 430,
      ),
      isTrue,
    );
    expect(
      loaded.any(
        (metric) =>
            metric.provider == WearableProvider.manual &&
            metric.metricType == WearableMetricType.restingHeartRateBpm &&
            metric.value == 58,
      ),
      isTrue,
    );
  });

  test('overwrites a metric with the same provider, type, and date', () async {
    final today = DateTime(2026, 3, 29);

    await repository.upsertDailyMetrics([
      DailyWearableMetric(
        provider: WearableProvider.fitbit,
        metricType: WearableMetricType.sleepDurationMin,
        date: today,
        value: 410,
        unit: 'min',
      ),
    ]);

    await repository.upsertDailyMetrics([
      DailyWearableMetric(
        provider: WearableProvider.fitbit,
        metricType: WearableMetricType.sleepDurationMin,
        date: today,
        value: 455,
        unit: 'min',
      ),
    ]);

    final loaded = await repository.loadDailyMetrics(
      provider: WearableProvider.fitbit,
      metricType: WearableMetricType.sleepDurationMin,
    );

    expect(loaded, hasLength(1));
    expect(loaded.single.value, 455);
  });

  test('keeps values for other providers and metric types', () async {
    final today = DateTime(2026, 3, 29);

    await repository.upsertDailyMetrics([
      DailyWearableMetric(
        provider: WearableProvider.manual,
        metricType: WearableMetricType.sleepDurationMin,
        date: today,
        value: 400,
        unit: 'min',
      ),
      DailyWearableMetric(
        provider: WearableProvider.fitbit,
        metricType: WearableMetricType.restingHeartRateBpm,
        date: today,
        value: 57,
        unit: 'bpm',
      ),
    ]);

    await repository.upsertDailyMetrics([
      DailyWearableMetric(
        provider: WearableProvider.manual,
        metricType: WearableMetricType.sleepDurationMin,
        date: today,
        value: 420,
        unit: 'min',
      ),
    ]);

    final allMetrics = await repository.loadDailyMetrics();

    expect(allMetrics, hasLength(2));
    expect(
      allMetrics.any(
        (metric) =>
            metric.provider == WearableProvider.manual &&
            metric.metricType == WearableMetricType.sleepDurationMin &&
            metric.value == 420,
      ),
      isTrue,
    );
    expect(
      allMetrics.any(
        (metric) =>
            metric.provider == WearableProvider.fitbit &&
            metric.metricType == WearableMetricType.restingHeartRateBpm &&
            metric.value == 57,
      ),
      isTrue,
    );
  });

  test('keeps missing days as record absence instead of filling values', () async {
    final today = DateTime(2026, 3, 29);
    final otherDay = DateTime(2026, 3, 28);

    await repository.upsertDailyMetrics([
      DailyWearableMetric(
        provider: WearableProvider.fitbit,
        metricType: WearableMetricType.sleepDurationMin,
        date: today,
        value: 440,
        unit: 'min',
      ),
    ]);

    final otherDayMetrics = await repository.loadDailyMetrics(
      provider: WearableProvider.fitbit,
      metricType: WearableMetricType.sleepDurationMin,
    );

    expect(
      otherDayMetrics.any(
        (metric) =>
            metric.date.year == otherDay.year &&
            metric.date.month == otherDay.month &&
            metric.date.day == otherDay.day,
      ),
      isFalse,
    );
  });

  test('loads daily metrics in ascending date order for a range', () async {
    await repository.upsertDailyMetrics([
      DailyWearableMetric(
        provider: WearableProvider.fitbit,
        metricType: WearableMetricType.sleepDurationMin,
        date: DateTime(2026, 3, 29),
        value: 401,
        unit: 'min',
        sourceId: 'fitbit',
      ),
      DailyWearableMetric(
        provider: WearableProvider.fitbit,
        metricType: WearableMetricType.sleepDurationMin,
        date: DateTime(2026, 3, 28),
        value: 432,
        unit: 'min',
        sourceId: 'fitbit',
      ),
    ]);

    final metrics = await repository.loadDailyMetricsInRange(
      startDate: DateTime(2026, 3, 27),
      endDate: DateTime(2026, 3, 29),
      provider: WearableProvider.fitbit,
      metricType: WearableMetricType.sleepDurationMin,
    );

    expect(metrics, hasLength(2));
    expect(metrics[0].date, DateTime(2026, 3, 28));
    expect(metrics[0].value, 432);
    expect(metrics[1].date, DateTime(2026, 3, 29));
    expect(metrics[1].value, 401);
    expect(metrics[0].sourceId, 'fitbit');
    expect(metrics[1].sourceId, 'fitbit');
  });
}
