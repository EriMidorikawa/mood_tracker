import 'dart:convert';

import 'package:mood_tracker/features/daily_log/models/daily_log_entry.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalDailyLogRepository {
  static const _latestEntryKey = 'daily_log.latest_entry';
  static const _entriesByDateKey = 'daily_log.entries_by_date';

  Future<DailyLogEntry?> loadLatestEntry() async {
    final entries = await loadEntries();
    if (entries.isNotEmpty) {
      final sortedEntries = entries.values.toList()
        ..sort((a, b) => b.loggedAt.compareTo(a.loggedAt));
      return sortedEntries.first;
    }

    final preferences = await SharedPreferences.getInstance();
    final rawEntry = preferences.getString(_latestEntryKey);
    if (rawEntry == null || rawEntry.isEmpty) {
      return null;
    }

    final entry = DailyLogEntry.fromJsonString(rawEntry);
    await saveEntry(entry);
    return entry;
  }

  Future<Map<String, DailyLogEntry>> loadEntries() async {
    final preferences = await SharedPreferences.getInstance();
    final rawEntries = preferences.getString(_entriesByDateKey);
    if (rawEntries == null || rawEntries.isEmpty) {
      return {};
    }

    final decoded = jsonDecode(rawEntries) as Map<String, dynamic>;
    return {
      for (final entry in decoded.entries)
        entry.key: DailyLogEntry.fromJson(entry.value as Map<String, dynamic>),
    };
  }

  Future<void> saveEntry(DailyLogEntry entry) async {
    final preferences = await SharedPreferences.getInstance();
    final entries = await loadEntries();
    entries[_dateKey(entry.loggedAt)] = entry;

    final encodedEntries = <String, dynamic>{
      for (final entry in entries.entries) entry.key: entry.value.toJson(),
    };

    await preferences.setString(_entriesByDateKey, jsonEncode(encodedEntries));
    await preferences.setString(_latestEntryKey, entry.toJsonString());
  }
}

String _dateKey(DateTime dateTime) {
  final year = dateTime.year.toString().padLeft(4, '0');
  final month = dateTime.month.toString().padLeft(2, '0');
  final day = dateTime.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
