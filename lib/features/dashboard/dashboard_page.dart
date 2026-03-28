import 'package:flutter/material.dart';
import 'package:mood_tracker/features/daily_log/daily_log_models.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({
    super.key,
    this.latestEntry,
  });

  final DailyLogEntry? latestEntry;

  @override
  Widget build(BuildContext context) {
    if (latestEntry == null) {
      return const PlaceholderPage(
        title: 'Dashboard',
        description: 'Save a daily log to preview your latest check-in here.',
        icon: Icons.dashboard_rounded,
      );
    }

    final averageScore = latestEntry!.responses.values.fold<int>(
          0,
          (sum, value) => sum + value,
        ) /
        latestEntry!.responses.length;

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Latest Check-in',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Recorded for ${_formatDate(latestEntry!.loggedAt)}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _SummaryChip(
                        label: 'Record date',
                        value: _formatDate(latestEntry!.loggedAt),
                        icon: Icons.event_outlined,
                      ),
                      _SummaryChip(
                        label: 'Average',
                        value: averageScore.toStringAsFixed(1),
                        icon: Icons.auto_graph_rounded,
                      ),
                      _SummaryChip(
                        label: 'Mood',
                        value: '${latestEntry!.responses['mood'] ?? 0}/5',
                        icon: Icons.mood_outlined,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Scores',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  for (final question in dailyLogQuestions) ...[
                    _ScoreRow(
                      label: question.label,
                      value: latestEntry!.responses[question.id] ?? 0,
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Notes',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    latestEntry!.note.isEmpty
                        ? 'No notes added yet.'
                        : latestEntry!.note,
                    style: Theme.of(context).textTheme.bodyMedium,
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

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelMedium),
              Text(value, style: Theme.of(context).textTheme.titleSmall),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({
    required this.label,
    required this.value,
  });

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.bodyLarge),
            ),
            Text('$value / 5', style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: value / 5,
          minHeight: 8,
          borderRadius: BorderRadius.circular(999),
        ),
      ],
    );
  }
}

class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 64),
              const SizedBox(height: 16),
              Text(title, style: textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                description,
                textAlign: TextAlign.center,
                style: textTheme.bodyLarge,
              ),
            ],
          ),
        ),
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

  final month = months[dateTime.month - 1];
  return '$month ${dateTime.day}, ${dateTime.year}';
}
