import 'dart:convert';

import 'package:mood_tracker/features/daily_log/models/daily_log_entry.dart';
import 'package:mood_tracker/shared/date_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalDailyLogRepository {
  static const _latestEntryKey = 'daily_log.latest_entry';
  static const _entriesByDateKey = 'daily_log.entries_by_date';

  Future<DailyLogEntry?> loadLatestEntry() async {
    final entries = await loadEntries();
    if (entries.isNotEmpty) {
      return _latestEntryFromEntries(entries);
    }

    final preferences = await SharedPreferences.getInstance();
    final rawEntry = preferences.getString(_latestEntryKey);
    if (rawEntry == null || rawEntry.isEmpty) {
      return null;
    }

    return DailyLogEntry.fromJsonString(rawEntry);
  }

  Future<DailyLogEntry?> loadEntryByDate(DateTime logDate) async {
    final entries = await loadEntries();
    return entries[dateKey(logDate)];
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

  Future<List<DailyLogEntry>> loadEntriesSorted() async {
    final entries = await loadEntries();
    final sortedEntries = entries.values.toList()
      ..sort((a, b) => b.loggedAt.compareTo(a.loggedAt));
    return sortedEntries;
  }

  Future<void> saveEntry(DailyLogEntry entry) async {
    final preferences = await SharedPreferences.getInstance();
    final entries = await loadEntries();

    // MVP rule: one saved entry per log date. Saving the same date overwrites it.
    entries[dateKey(entry.loggedAt)] = entry;

    final encodedEntries = <String, dynamic>{
      for (final entry in entries.entries) entry.key: entry.value.toJson(),
    };

    await preferences.setString(_entriesByDateKey, jsonEncode(encodedEntries));
    final latestEntry = _latestEntryFromEntries(entries);
    if (latestEntry != null) {
      await preferences.setString(_latestEntryKey, latestEntry.toJsonString());
    }
  }

  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_latestEntryKey);
    await preferences.remove(_entriesByDateKey);
  }
}

DailyLogEntry? _latestEntryFromEntries(Map<String, DailyLogEntry> entries) {
  if (entries.isEmpty) {
    return null;
  }

  final sortedEntries = entries.values.toList()
    ..sort((a, b) => b.loggedAt.compareTo(a.loggedAt));
  return sortedEntries.first;
}
