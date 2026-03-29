import 'package:mood_tracker/features/wearables/data/fitbit_source_adapter.dart';

class FitbitDailySnapshotMapper {
  const FitbitDailySnapshotMapper();

  FitbitDailySnapshot map({
    required DateTime date,
    required Map<String, dynamic> sleepResponse,
    required Map<String, dynamic> heartResponse,
  }) {
    final day = _dateOnly(date);
    return FitbitDailySnapshot(
      date: day,
      sleepDurationMin: _parseSleepDurationMin(sleepResponse),
      restingHeartRateBpm: _parseRestingHeartRateBpm(heartResponse),
    );
  }
}

int? _parseSleepDurationMin(Map<String, dynamic> json) {
  final sleepItems = json['sleep'] as List<dynamic>?;
  if (sleepItems == null || sleepItems.isEmpty) {
    return null;
  }

  var totalMinutes = 0;
  var foundValue = false;

  for (final item in sleepItems) {
    final sleep = item as Map<String, dynamic>;
    final minutesAsleep = sleep['minutesAsleep'] as num?;
    if (minutesAsleep == null) {
      continue;
    }

    totalMinutes += minutesAsleep.toInt();
    foundValue = true;
  }

  return foundValue ? totalMinutes : null;
}

double? _parseRestingHeartRateBpm(Map<String, dynamic> json) {
  final heartItems = json['activities-heart'] as List<dynamic>?;
  if (heartItems == null || heartItems.isEmpty) {
    return null;
  }

  final firstItem = heartItems.first as Map<String, dynamic>;
  final value = firstItem['value'] as Map<String, dynamic>?;
  final restingHeartRate = value?['restingHeartRate'] as num?;
  return restingHeartRate?.toDouble();
}

DateTime _dateOnly(DateTime dateTime) {
  return DateTime(dateTime.year, dateTime.month, dateTime.day);
}
