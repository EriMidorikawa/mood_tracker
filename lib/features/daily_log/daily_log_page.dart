import 'package:flutter/material.dart';
import 'package:mood_tracker/features/daily_log/data/daily_log_seed.dart';
import 'package:mood_tracker/features/daily_log/models/daily_log_entry.dart';
import 'package:mood_tracker/features/daily_log/models/daily_log_question.dart';

class DailyLogPage extends StatefulWidget {
  const DailyLogPage({
    super.key,
    this.initialEntry,
    required this.onSave,
  });

  final DailyLogEntry? initialEntry;
  final ValueChanged<DailyLogEntry> onSave;

  @override
  State<DailyLogPage> createState() => _DailyLogPageState();
}

class _DailyLogPageState extends State<DailyLogPage> {
  late Map<String, int> _responses;
  late DateTime _selectedLogDate;
  late final TextEditingController _memoController;

  @override
  void initState() {
    super.initState();
    _memoController = TextEditingController();
    _applyEntry(widget.initialEntry);
  }

  @override
  void didUpdateWidget(covariant DailyLogPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialEntry != widget.initialEntry) {
      _applyEntry(widget.initialEntry);
    }
  }

  @override
  void dispose() {
    _memoController.dispose();
    super.dispose();
  }

  void _applyEntry(DailyLogEntry? entry) {
    _responses = {
      for (final question in dailyLogQuestions)
        question.id: entry?.responses[question.id] ?? 3,
    };
    _selectedLogDate = _dateOnly(entry?.loggedAt ?? DateTime.now());
    _memoController.text = entry?.note ?? '';
  }

  void _save() {
    FocusScope.of(context).unfocus();
    widget.onSave(
      DailyLogEntry(
        loggedAt: _selectedLogDate,
        responses: Map.unmodifiable(_responses),
        note: _memoController.text.trim(),
      ),
    );
  }

  Future<void> _pickLogDate() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedLogDate,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
    );

    if (pickedDate == null) {
      return;
    }

    setState(() {
      _selectedLogDate = _dateOnly(pickedDate);
    });
  }

  @override
  Widget build(BuildContext context) {
    final logDate = _formatDate(_selectedLogDate);

    return Scaffold(
      appBar: AppBar(title: const Text('Daily Log')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Text(
            'Check in with how you feel today.',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.event_outlined),
              title: const Text('Log date'),
              subtitle: Text(logDate),
              trailing: const Icon(Icons.edit_calendar_outlined),
              onTap: _pickLogDate,
            ),
          ),
          const SizedBox(height: 16),
          for (final question in dailyLogQuestions) ...[
            _QuestionCard(
              question: question,
              value: _responses[question.id]!,
              onChanged: (value) {
                setState(() {
                  _responses[question.id] = value;
                });
              },
            ),
            const SizedBox(height: 12),
          ],
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Notes', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _memoController,
                    minLines: 4,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      hintText: 'Optional notes about meals, cravings, or mood.',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.question,
    required this.value,
    required this.onChanged,
  });

  final DailyLogQuestion question;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(question.label, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              '1 = ${question.lowLabel}  |  5 = ${question.highLabel}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(5, (index) {
                final score = index + 1;

                return ChoiceChip(
                  label: Text('$score'),
                  selected: value == score,
                  onSelected: (_) => onChanged(score),
                );
              }),
            ),
          ],
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
  final day = dateTime.day;
  final year = dateTime.year;

  return '$month $day, $year';
}

DateTime _dateOnly(DateTime dateTime) {
  return DateTime(dateTime.year, dateTime.month, dateTime.day);
}
