import 'package:flutter_test/flutter_test.dart';
import 'package:mood_tracker/features/wearables/data/fitbit_daily_snapshot_mapper.dart';

void main() {
  const mapper = FitbitDailySnapshotMapper();
  final date = DateTime(2026, 3, 29);

  test('maps both sleep and resting heart rate when both are present', () {
    final snapshot = mapper.map(
      date: date,
      sleepResponse: {
        'sleep': [
          {'minutesAsleep': 320},
          {'minutesAsleep': 95},
        ],
      },
      heartResponse: {
        'activities-heart': [
          {
            'value': {'restingHeartRate': 57},
          },
        ],
      },
    );

    expect(snapshot.date, DateTime(2026, 3, 29));
    expect(snapshot.sleepDurationMin, 415);
    expect(snapshot.restingHeartRateBpm, 57);
  });

  test('maps sleep only and keeps resting heart rate as null', () {
    final snapshot = mapper.map(
      date: date,
      sleepResponse: {
        'sleep': [
          {'minutesAsleep': 401},
        ],
      },
      heartResponse: {
        'activities-heart': [],
      },
    );

    expect(snapshot.sleepDurationMin, 401);
    expect(snapshot.restingHeartRateBpm, isNull);
  });

  test('maps resting heart rate only and keeps sleep as null', () {
    final snapshot = mapper.map(
      date: date,
      sleepResponse: {
        'sleep': [],
      },
      heartResponse: {
        'activities-heart': [
          {
            'value': {'restingHeartRate': 61},
          },
        ],
      },
    );

    expect(snapshot.sleepDurationMin, isNull);
    expect(snapshot.restingHeartRateBpm, 61);
  });

  test('keeps both metrics as null when neither value is present', () {
    final snapshot = mapper.map(
      date: date,
      sleepResponse: {
        'sleep': [
          {'minutesAsleep': null},
        ],
      },
      heartResponse: {
        'activities-heart': [
          {
            'value': {},
          },
        ],
      },
    );

    expect(snapshot.sleepDurationMin, isNull);
    expect(snapshot.restingHeartRateBpm, isNull);
  });
}
