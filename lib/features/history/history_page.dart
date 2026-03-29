import 'package:flutter/material.dart';
import 'package:mood_tracker/features/daily_log/data/daily_log_seed.dart';
import 'package:mood_tracker/app/settings_menu_button.dart';
import 'package:mood_tracker/features/daily_log/daily_log_page.dart';
import 'package:mood_tracker/features/daily_log/models/daily_log_entry.dart';
import 'package:mood_tracker/features/wearables/models/daily_wearable_metric.dart';
import 'package:mood_tracker/features/wearables/models/wearable_metric_type.dart';

const _manualMarkerColor = Color(0xFF2F7D5B);
const _wearableMarkerColor = Color(0xFFCC7A00);

class HistoryPage extends StatefulWidget {
  const HistoryPage({
    super.key,
    required this.entries,
    required this.wearableMetrics,
    required this.loadEntryByDate,
    required this.onSaveEntry,
    required this.onSettingsClosed,
  });

  final List<DailyLogEntry> entries;
  final List<DailyWearableMetric> wearableMetrics;
  final Future<DailyLogEntry?> Function(DateTime) loadEntryByDate;
  final Future<void> Function(DailyLogEntry) onSaveEntry;
  final Future<void> Function() onSettingsClosed;

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
    final manualLoggedDates = {
      for (final entry in widget.entries) _dateKey(entry.loggedAt),
    };
    final wearableLoggedDates = {
      for (final metric in widget.wearableMetrics) _dateKey(metric.date),
    };
    final days = _buildMonthCells(_visibleMonth);
    final canGoNext = !_isSameMonth(_visibleMonth, today);

    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          SettingsMenuButton(onSettingsClosed: widget.onSettingsClosed),
        ],
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
          const SizedBox(height: 12),
          const _HistoryLegend(),
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
              final dateKey = _dateKey(date);
              final isToday = date == today;

              return _CalendarDayCell(
                date: date,
                isFuture: isFuture,
                hasManualLog: manualLoggedDates.contains(dateKey),
                hasWearableLog: wearableLoggedDates.contains(dateKey),
                isToday: isToday,
                onTap: isFuture ? null : () => _openLog(context, date),
              );
            },
          ),
          if (widget.entries.isEmpty && widget.wearableMetrics.isEmpty) ...[
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

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _HistoryDayDetailPage(
          logDate: logDate,
          entry: entry,
          wearableMetrics: [
            for (final metric in widget.wearableMetrics)
              if (_dateOnly(metric.date) == logDate) metric,
          ],
          loadEntryByDate: widget.loadEntryByDate,
          onSaveEntry: widget.onSaveEntry,
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
  const _WeekdayHeader();

  @override
  Widget build(BuildContext context) {
    const labels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
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
    required this.hasManualLog,
    required this.hasWearableLog,
    required this.isToday,
    required this.onTap,
  });

  final DateTime date;
  final bool isFuture;
  final bool hasManualLog;
  final bool hasWearableLog;
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
                _CalendarMarkers(
                  hasManualLog: hasManualLog,
                  hasWearableLog: hasWearableLog,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CalendarMarkers extends StatelessWidget {
  const _CalendarMarkers({
    required this.hasManualLog,
    required this.hasWearableLog,
  });

  final bool hasManualLog;
  final bool hasWearableLog;

  @override
  Widget build(BuildContext context) {
    if (!hasManualLog && !hasWearableLog) {
      return const SizedBox(height: 8);
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _HistoryMarkerDot(
          color: _manualMarkerColor,
          isVisible: hasManualLog,
        ),
        const SizedBox(width: 4),
        _HistoryMarkerDot(
          color: _wearableMarkerColor,
          isVisible: hasWearableLog,
        ),
      ],
    );
  }
}

class _HistoryMarkerDot extends StatelessWidget {
  const _HistoryMarkerDot({
    required this.color,
    required this.isVisible,
  });

  final Color color;
  final bool isVisible;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: isVisible ? color : Colors.transparent,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _HistoryLegend extends StatelessWidget {
  const _HistoryLegend();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        _LegendItem(
          color: _manualMarkerColor,
          label: 'Manual data',
        ),
        _LegendItem(
          color: _wearableMarkerColor,
          label: 'Wearable data',
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
  });

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _HistoryDayDetailPage extends StatefulWidget {
  const _HistoryDayDetailPage({
    required this.logDate,
    required this.entry,
    required this.wearableMetrics,
    required this.loadEntryByDate,
    required this.onSaveEntry,
  });

  final DateTime logDate;
  final DailyLogEntry? entry;
  final List<DailyWearableMetric> wearableMetrics;
  final Future<DailyLogEntry?> Function(DateTime) loadEntryByDate;
  final Future<void> Function(DailyLogEntry) onSaveEntry;

  @override
  State<_HistoryDayDetailPage> createState() => _HistoryDayDetailPageState();
}

class _HistoryDayDetailPageState extends State<_HistoryDayDetailPage> {
  DailyLogEntry? _entry;

  @override
  void initState() {
    super.initState();
    _entry = widget.entry;
  }

  @override
  Widget build(BuildContext context) {
    final sleepMetric = _metricForType(WearableMetricType.sleepDurationMin);
    final heartMetric = _metricForType(WearableMetricType.restingHeartRateBpm);

    return Scaffold(
      appBar: AppBar(
        title: Text(_formatDate(widget.logDate)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Daily Log',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  if (_entry == null)
                    Text(
                      'No manual log saved for this day.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    )
                  else ...[
                    for (final summary in _manualSummaries(_entry!)) ...[
                      _DetailRow(
                        label: summary.label,
                        value: summary.value,
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (_entry!.note.trim().isNotEmpty) ...[
                      _DetailRow(
                        label: 'Notes',
                        value: _entry!.note.trim(),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () async {
                      final title = _entry == null
                          ? 'Log ${_formatDate(widget.logDate)}'
                          : 'Edit ${_formatDate(widget.logDate)}';
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => DailyLogPage(
                            initialEntry: _entry,
                            initialDate:
                                _entry == null ? widget.logDate : null,
                            onSave: widget.onSaveEntry,
                            popOnSave: true,
                            showSettingsMenu: false,
                            title: title,
                          ),
                        ),
                      );
                      await _refreshEntry();
                    },
                    child: Text(_entry == null ? 'Add log' : 'Edit'),
                  ),
                ],
              ),
            ),
          ),
          if (sleepMetric != null || heartMetric != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Wearable',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    if (sleepMetric != null) ...[
                      _DetailRow(
                        label: 'Sleep Duration',
                        value: _formatSleepDuration(sleepMetric.value),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (heartMetric != null)
                      _DetailRow(
                        label: 'Resting Heart Rate',
                        value: '${heartMetric.value.round()} bpm',
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  DailyWearableMetric? _metricForType(WearableMetricType metricType) {
    for (final metric in widget.wearableMetrics) {
      if (metric.metricType == metricType) {
        return metric;
      }
    }
    return null;
  }

  Future<void> _refreshEntry() async {
    final updatedEntry = await widget.loadEntryByDate(widget.logDate);
    if (!mounted) {
      return;
    }

    setState(() {
      _entry = updatedEntry;
    });
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 132,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

class _ManualSummary {
  const _ManualSummary({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;
}

List<_ManualSummary> _manualSummaries(DailyLogEntry entry) {
  return [
    for (final question in dailyLogQuestions)
      _ManualSummary(
        label: question.label,
        value: '${entry.responses[question.id] ?? '-'}',
      ),
  ];
}

List<DateTime?> _buildMonthCells(DateTime month) {
  final firstDay = DateTime(month.year, month.month, 1);
  final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
  final leadingEmpty = firstDay.weekday % DateTime.daysPerWeek;

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

String _formatSleepDuration(double minutes) {
  final totalMinutes = minutes.round();
  final hours = totalMinutes ~/ 60;
  final remainingMinutes = totalMinutes % 60;
  return '${hours}h ${remainingMinutes}m';
}
