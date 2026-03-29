enum WearableMetricType {
  restingHeartRate('resting_heart_rate'),
  sleepMinutes('sleep_minutes'),
  steps('steps'),
  caloriesBurned('calories_burned');

  const WearableMetricType(this.storageKey);

  final String storageKey;

  static WearableMetricType fromStorageKey(String value) {
    return WearableMetricType.values.firstWhere(
      (metricType) => metricType.storageKey == value,
      orElse: () => WearableMetricType.steps,
    );
  }
}
