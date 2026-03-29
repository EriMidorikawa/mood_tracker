import 'package:flutter/material.dart';
import 'package:mood_tracker/app/settings_menu_button.dart';
import 'package:mood_tracker/features/daily_log/daily_log_page.dart';
import 'package:mood_tracker/features/daily_log/models/daily_log_entry.dart';

class HistoryPage extends StatefulWidget {
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
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    final today = _dateOnly(DateTime.now());
    _visibleMonth = DateTime(today.year, today.month);
  }

  @override
  Widget build(BuildContext context) {
    final today = _dateOnly(DateTime.now());
    final loggedDates = {
      for (final entry in widget.entries) _dateKey(entry.loggedAt),
    };
    final days = _buildMonthCells(_visibleMonth);
    final canGoNext = !_isSameMonth(_visibleMonth, today);

    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: const [SettingsMenuButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _MonthHeader(
            month: _visibleMonth,
            canGoNext: canGoNext,
            onPrevious: () {
              setState(() {
                _visibleMonth = DateTime(
                  _visibleMonth.year,
                  _visibleMonth.month - 1,
                );
              });
            },
            onNext: canGoNext
                ? () {
                    setState(() {
                      _visibleMonth = DateTime(
                        _visibleMonth.year,
                        _visibleMonth.month + 1,
                      );
                    });
                  }
                : null,
          ),
          const SizedBox(height: 12),
          Text(
            'Tap a recorded day to edit it, or an empty day to start a log.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          _WeekdayHeader(),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: days.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.9,
            ),
            itemBuilder: (context, index) {
              final cell = days[index];
              if (cell == null) {
                return const SizedBox.shrink();
              }

              final date = _dateOnly(cell);
              final isFuture = date.isAfter(today);
              final isLogged = loggedDates.contains(_dateKey(date));
              final isToday = date == today;

              return _CalendarDayCell(
                date: date,
                isFuture: isFuture,
                isLogged: isLogged,
                isToday: isToday,
                onTap: isFuture ? null : () => _openLog(context, date),
              );
            },
          ),
          if (widget.entries.isEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'No logs yet. You can start by tapping any past or current day.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openLog(BuildContext context, DateTime logDate) async {
    final entry = await widget.loadEntryByDate(logDate);
    if (!context.mounted) {
      return;
    }

    final title = entry == null
        ? 'Log ${_formatDate(logDate)}'
        : 'Edit ${_formatDate(logDate)}';

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DailyLogPage(
          initialEntry: entry,
          initialDate: entry == null ? logDate : null,
          onSave: widget.onSaveEntry,
          popOnSave: true,
          showSettingsMenu: false,
          title: title,
        ),
      ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.month,
    required this.canGoNext,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime month;
  final bool canGoNext;
  final VoidCallback onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Text(
            _formatMonthYear(month),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        IconButton(
          onPressed: canGoNext ? onNext : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Row(
      children: [
        for (final label in labels)
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
      ],
    );
  }
}

class _CalendarDayCell extends StatelessWidget {
  const _CalendarDayCell({
    required this.date,
    required this.isFuture,
    required this.isLogged,
    required this.isToday,
    required this.onTap,
  });

  final DateTime date;
  final bool isFuture;
  final bool isLogged;
  final bool isToday;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final backgroundColor = isToday
        ? colorScheme.primaryContainer
        : colorScheme.surface;
    final borderColor = isToday
        ? colorScheme.primary
        : colorScheme.outlineVariant;
    final textColor = isFuture ? colorScheme.outline : colorScheme.onSurface;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  '${date.day}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: textColor,
                      ),
                ),
                const Spacer(),
                if (isLogged)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  )
                else
                  const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

List<DateTime?> _buildMonthCells(DateTime month) {
  final firstDay = DateTime(month.year, month.month, 1);
  final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
  final leadingEmpty = firstDay.weekday - DateTime.monday;

  return [
    for (var i = 0; i < leadingEmpty; i++) null,
    for (var day = 1; day <= daysInMonth; day++)
      DateTime(month.year, month.month, day),
  ];
}

bool _isSameMonth(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month;
}

DateTime _dateOnly(DateTime dateTime) {
  return DateTime(dateTime.year, dateTime.month, dateTime.day);
}

String _dateKey(DateTime dateTime) {
  final year = dateTime.year.toString().padLeft(4, '0');
  final month = dateTime.month.toString().padLeft(2, '0');
  final day = dateTime.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
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

String _formatMonthYear(DateTime dateTime) {
  const months = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  return '${months[dateTime.month - 1]} ${dateTime.year}';
}
