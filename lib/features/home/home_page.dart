import 'package:flutter/material.dart';
import 'package:mood_tracker/app/settings_menu_button.dart';
import 'package:mood_tracker/features/daily_log/models/daily_log_entry.dart';
import 'package:mood_tracker/features/wearables/models/wearable_connection.dart';
import 'package:mood_tracker/shared/format_utils.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.onOpenTodayLog,
    required this.onOpenSettings,
    required this.onSettingsClosed,
    this.fitbitConnection,
    this.todayEntry,
  });

  final VoidCallback onOpenTodayLog;
  final Future<void> Function() onOpenSettings;
  final Future<void> Function() onSettingsClosed;
  final WearableConnection? fitbitConnection;
  final DailyLogEntry? todayEntry;

  @override
  Widget build(BuildContext context) {
    final hasTodayLog = todayEntry != null;
    final isFitbitConnected = fitbitConnection?.isConnected == true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          SettingsMenuButton(onSettingsClosed: onSettingsClosed),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Today',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasTodayLog
                        ? 'Today\'s log is saved.'
                        : 'Today\'s log is not recorded yet.',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (hasTodayLog) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Saved for ${formatShortDate(todayEntry!.loggedAt)}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: onOpenTodayLog,
                    child: Text(
                      hasTodayLog ? 'Edit today\'s log' : 'Log today',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fitbit',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isFitbitConnected ? 'Connected' : 'Not connected yet.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (fitbitConnection?.lastSyncedAt != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Last synced: ${formatDateTimeLabel(fitbitConnection!.lastSyncedAt!)}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () {
                      onOpenSettings();
                    },
                    child: Text(
                      isFitbitConnected ? 'Manage Fitbit' : 'Open Settings',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
