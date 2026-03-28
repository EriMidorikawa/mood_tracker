import 'package:mood_tracker/features/daily_log/models/daily_log_entry.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalDailyLogRepository {
  static const _latestEntryKey = 'daily_log.latest_entry';

  Future<DailyLogEntry?> loadLatestEntry() async {
    final preferences = await SharedPreferences.getInstance();
    final rawEntry = preferences.getString(_latestEntryKey);
    if (rawEntry == null || rawEntry.isEmpty) {
      return null;
    }

    return DailyLogEntry.fromJsonString(rawEntry);
  }

  Future<void> saveLatestEntry(DailyLogEntry entry) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_latestEntryKey, entry.toJsonString());
  }
}
