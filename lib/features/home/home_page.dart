import 'package:flutter/material.dart';
import 'package:mood_tracker/app/settings_menu_button.dart';
import 'package:mood_tracker/features/daily_log/models/daily_log_entry.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.onOpenTodayLog,
    required this.onOpenSettings,
    this.todayEntry,
  });

  final VoidCallback onOpenTodayLog;
  final Future<void> Function() onOpenSettings;
  final DailyLogEntry? todayEntry;

  @override
  Widget build(BuildContext context) {
    final hasTodayLog = todayEntry != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          SettingsMenuButton(onSettingsClosed: onOpenSettings),
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
                      'Saved for ${_formatDate(todayEntry!.loggedAt)}',
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
                    'Not connected yet.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () {
                      onOpenSettings();
                    },
                    child: const Text('Open Settings'),
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

String _formatDate(DateTime dateTime) {
  const months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  return '${months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year}';
}
