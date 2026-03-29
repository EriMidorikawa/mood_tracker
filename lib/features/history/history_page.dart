import 'package:flutter/material.dart';
import 'package:mood_tracker/app/settings_menu_button.dart';
import 'package:mood_tracker/features/daily_log/daily_log_page.dart';
import 'package:mood_tracker/features/daily_log/models/daily_log_entry.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({
    super.key,
    required this.entries,
    required this.loadEntryByDate,
    required this.onSaveEntry,
  });

  final List<DailyLogEntry> entries;
  final Future<DailyLogEntry?> Function(DateTime) loadEntryByDate;
  final Future<void> Function(DailyLogEntry) onSaveEntry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: const [SettingsMenuButton()],
      ),
      body: entries.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Saved logs will appear here. Add a Daily Log to start building history.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: entries.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final entry = entries[index];
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    title: Text(_formatDate(entry.loggedAt)),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          _MetricChip(
                            label: 'Mood',
                            value: entry.responses['mood'] ?? 0,
                          ),
                          _MetricChip(
                            label: 'General craving',
                            value: entry.responses['craving'] ?? 0,
                          ),
                          _MetricChip(
                            label: 'Hunger',
                            value: entry.responses['hunger'] ?? 0,
                          ),
                        ],
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _openEditor(context, entry.loggedAt),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _openEditor(BuildContext context, DateTime logDate) async {
    final entry = await loadEntryByDate(logDate);
    if (!context.mounted || entry == null) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DailyLogPage(
          initialEntry: entry,
          onSave: onSaveEntry,
          popOnSave: true,
          showSettingsMenu: false,
          title: 'Edit ${_formatDate(entry.loggedAt)}',
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.label,
    required this.value,
  });

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text('$label: $value/5'),
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

  final month = months[dateTime.month - 1];
  return '$month ${dateTime.day}, ${dateTime.year}';
}
