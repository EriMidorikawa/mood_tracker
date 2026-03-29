enum WearableMetricType {
  sleepDurationMin(
    'sleep_duration_min',
    canonicalUnit: 'min',
    aggregationRule: WearableAggregationRule.dailySum,
  ),
  restingHeartRateBpm(
    'resting_heart_rate_bpm',
    canonicalUnit: 'bpm',
    aggregationRule: WearableAggregationRule.dailyAverage,
  );

  const WearableMetricType(
    this.storageKey, {
    required this.canonicalUnit,
    required this.aggregationRule,
  });

  final String storageKey;
  final String canonicalUnit;
  final WearableAggregationRule aggregationRule;

  static WearableMetricType fromStorageKey(String value) {
    return WearableMetricType.values.firstWhere(
      (metricType) => metricType.storageKey == value,
      orElse: () => WearableMetricType.sleepDurationMin,
    );
  }
}

enum WearableAggregationRule {
  dailySum,
  dailyAverage,
}
