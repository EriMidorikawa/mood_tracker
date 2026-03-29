import 'package:flutter/material.dart';
import 'package:mood_tracker/features/daily_log/models/daily_log_entry.dart';

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

    final sections = <_DashboardSection>[
      const _DashboardSection(
        title: 'Mind & Energy',
        items: [
          _DashboardMetric('Mood', 'mood'),
          _DashboardMetric('Motivation', 'motivation'),
          _DashboardMetric('Fatigue', 'fatigue'),
        ],
      ),
      const _DashboardSection(
        title: 'Appetite & Cravings',
        items: [
          _DashboardMetric('Hunger', 'hunger'),
          _DashboardMetric('General craving', 'craving'),
          _DashboardMetric('Salty craving', 'salty_craving'),
          _DashboardMetric('Sweet craving', 'sweet_craving'),
        ],
      ),
      const _DashboardSection(
        title: 'Eating Experience',
        items: [
          _DashboardMetric(
            'Post-meal satisfaction',
            'post_meal_satisfaction',
          ),
          _DashboardMetric('Overeating feeling', 'overeating_feeling'),
        ],
      ),
    ];

    final hasNote = latestEntry!.note.trim().isNotEmpty;

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
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _SummaryChip(
                    label: 'Record date',
                    value: _formatDate(latestEntry!.loggedAt),
                    icon: Icons.event_outlined,
                  ),
                  _SummaryChip(
                    label: 'Notes',
                    value: hasNote ? 'Added' : 'None',
                    icon: hasNote
                        ? Icons.sticky_note_2_outlined
                        : Icons.note_alt_outlined,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          for (final section in sections) ...[
            _SectionCard(
              section: section,
              responses: latestEntry!.responses,
            ),
            const SizedBox(height: 16),
          ],
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
                    hasNote ? latestEntry!.note : 'No notes added yet.',
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

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.section,
    required this.responses,
  });

  final _DashboardSection section;
  final Map<String, int> responses;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(section.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            for (var index = 0; index < section.items.length; index++) ...[
              _ScoreRow(
                label: section.items[index].label,
                value: responses[section.items[index].responseKey] ?? 0,
              ),
              if (index < section.items.length - 1) const SizedBox(height: 12),
            ],
          ],
        ),
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

class _DashboardSection {
  const _DashboardSection({
    required this.title,
    required this.items,
  });

  final String title;
  final List<_DashboardMetric> items;
}

class _DashboardMetric {
  const _DashboardMetric(this.label, this.responseKey);

  final String label;
  final String responseKey;
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
