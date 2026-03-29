import 'package:flutter/material.dart';
import 'package:mood_tracker/app/settings_menu_button.dart';
import 'package:mood_tracker/features/daily_log/models/daily_log_entry.dart';

class TrendsPage extends StatefulWidget {
  const TrendsPage({
    super.key,
    required this.entries,
  });

  final List<DailyLogEntry> entries;

  @override
  State<TrendsPage> createState() => _TrendsPageState();
}

class _TrendsPageState extends State<TrendsPage> {
  _TrendRange _selectedRange = _TrendRange.sevenDays;
  _TrendMetric _selectedMetric = _trendMetrics.first;
  int? _selectedYear;

  @override
  Widget build(BuildContext context) {
    final metricColor = _selectedMetric.color;
    final availableYears = _availableYears(widget.entries);
    final selectedYear = availableYears.contains(_selectedYear)
        ? _selectedYear!
        : (availableYears.isNotEmpty
            ? availableYears.first
            : DateTime.now().year);
    final series = _buildTrendSeries(
      entries: widget.entries,
      range: _selectedRange,
      metricKey: _selectedMetric.key,
      selectedYear: selectedYear,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trends'),
        actions: const [SettingsMenuButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            _selectedMetric.label,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: metricColor,
                ),
          ),
          const SizedBox(height: 8),
          _MetricSelectorRow(
            metrics: _mentalMetrics,
            selectedMetric: _selectedMetric,
            accentColor: metricColor,
            onSelected: _handleMetricSelected,
          ),
          const SizedBox(height: 8),
          _MetricSelectorRow(
            metrics: _appetiteMetrics,
            selectedMetric: _selectedMetric,
            accentColor: metricColor,
            onSelected: _handleMetricSelected,
          ),
          const SizedBox(height: 8),
          SegmentedButton<_TrendRange>(
            segments: const [
              ButtonSegment<_TrendRange>(
                value: _TrendRange.sevenDays,
                label: Text('7D'),
              ),
              ButtonSegment<_TrendRange>(
                value: _TrendRange.thirtyDays,
                label: Text('30D'),
              ),
              ButtonSegment<_TrendRange>(
                value: _TrendRange.threeMonths,
                label: Text('3M'),
              ),
              ButtonSegment<_TrendRange>(
                value: _TrendRange.thisYear,
                label: Text('1Y'),
              ),
            ],
            selected: {_selectedRange},
            onSelectionChanged: (selection) {
              setState(() {
                _selectedRange = selection.first;
              });
            },
          ),
          if (_selectedRange == _TrendRange.thisYear &&
              availableYears.isNotEmpty) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: DropdownMenu<int>(
                initialSelection: selectedYear,
                label: const Text('Year'),
                dropdownMenuEntries: availableYears
                    .map(
                      (year) => DropdownMenuEntry<int>(
                        value: year,
                        label: '$year',
                      ),
                    )
                    .toList(),
                onSelected: (year) {
                  if (year == null) {
                    return;
                  }

                  setState(() {
                    _selectedYear = year;
                  });
                },
              ),
            ),
          ],
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 300,
                    child: _MetricChart(
                      points: series.points,
                      accentColor: metricColor,
                      monthMarkers: series.monthMarkers,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (series.showRangeLabels)
                    Row(
                      children: [
                        Expanded(child: Text(series.startLabel)),
                        Text(series.endLabel),
                      ],
                    )
                  else
                    _MonthAxisLabels(monthMarkers: series.monthMarkers),
                ],
              ),
            ),
          ),
          if (series.loggedCount == 0) ...[
            const SizedBox(height: 16),
            Text(
              'No ${_selectedMetric.label.toLowerCase()} data was logged in this period yet.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }

  void _handleMetricSelected(_TrendMetric metric) {
    setState(() {
      _selectedMetric = metric;
    });
  }
}

class _MetricSelectorRow extends StatelessWidget {
  const _MetricSelectorRow({
    required this.metrics,
    required this.selectedMetric,
    required this.accentColor,
    required this.onSelected,
  });

  final List<_TrendMetric> metrics;
  final _TrendMetric selectedMetric;
  final Color accentColor;
  final ValueChanged<_TrendMetric> onSelected;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<_TrendMetric>(
      emptySelectionAllowed: true,
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }

          return accentColor;
        }),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return accentColor;
          }

          return null;
        }),
        side: WidgetStatePropertyAll(
          BorderSide(color: accentColor),
        ),
      ),
      segments: metrics
          .map(
            (metric) => ButtonSegment<_TrendMetric>(
              value: metric,
              label: Text(metric.label),
            ),
          )
          .toList(),
      selected: metrics.contains(selectedMetric) ? {selectedMetric} : const {},
      onSelectionChanged: (selection) {
        if (selection.isEmpty) {
          return;
        }

        onSelected(selection.first);
      },
    );
  }
}

class _MetricChart extends StatelessWidget {
  const _MetricChart({
    required this.points,
    required this.accentColor,
    required this.monthMarkers,
  });

  final List<_MetricPoint> points;
  final Color accentColor;
  final List<_MonthMarker> monthMarkers;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 24,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('5'),
              Text('4'),
              Text('3'),
              Text('2'),
              Text('1'),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: CustomPaint(
            painter: _MetricChartPainter(
              points: points,
              colorScheme: Theme.of(context).colorScheme,
              accentColor: accentColor,
              monthMarkers: monthMarkers,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ],
    );
  }
}

class _MetricChartPainter extends CustomPainter {
  const _MetricChartPainter({
    required this.points,
    required this.colorScheme,
    required this.accentColor,
    required this.monthMarkers,
  });

  final List<_MetricPoint> points;
  final ColorScheme colorScheme;
  final Color accentColor;
  final List<_MonthMarker> monthMarkers;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = colorScheme.outlineVariant
      ..strokeWidth = 1;
    final tickPaint = Paint()
      ..color = colorScheme.outline.withValues(alpha: 0.65)
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    final linePaint = Paint()
      ..color = accentColor.withValues(alpha: 0.45)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final pointPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill;
    final monthLinePaint = Paint()
      ..color = colorScheme.outline.withValues(alpha: 0.45)
      ..strokeWidth = 1;

    for (var scale = 1; scale <= 5; scale++) {
      final y = _yForValue(scale.toDouble(), size.height);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    for (final marker in monthMarkers) {
      final x = size.width * marker.position;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        monthLinePaint,
      );
    }

    final stepX = points.length == 1 ? 0.0 : size.width / (points.length - 1);
    Offset? previousPoint;
    var previousIndex = -1;

    for (var index = 0; index < points.length; index++) {
      final point = points[index];
      final x = stepX * index;

      if (point.value == null) {
        previousPoint = null;
        previousIndex = -1;
        continue;
      }

      final currentPoint = Offset(
        x,
        _yForValue(point.value!, size.height),
      );

      if (previousPoint != null && previousIndex == index - 1) {
        canvas.drawLine(previousPoint, currentPoint, linePaint);
      }

      canvas.drawCircle(currentPoint, 4, pointPaint);
      previousPoint = currentPoint;
      previousIndex = index;
    }

    final tickY = _yForValue(3, size.height);
    final tickHalfHeight = 3.5;
    for (var index = 0; index < points.length; index++) {
      final x = stepX * index;
      canvas.drawLine(
        Offset(x, tickY - tickHalfHeight),
        Offset(x, tickY + tickHalfHeight),
        tickPaint,
      );
    }
  }

  double _yForValue(double value, double height) {
    final normalized = (5 - value) / 4;
    return normalized * height;
  }

  @override
  bool shouldRepaint(covariant _MetricChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.colorScheme != colorScheme ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.monthMarkers != monthMarkers;
  }
}

class _MonthAxisLabels extends StatelessWidget {
  const _MonthAxisLabels({
    required this.monthMarkers,
  });

  final List<_MonthMarker> monthMarkers;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 20,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              for (final marker in monthMarkers)
                if (marker.showLabel)
                Positioned(
                  left: (constraints.maxWidth * marker.position).clamp(
                    0.0,
                    constraints.maxWidth - 28,
                  ),
                  child: Text(
                    marker.label,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _MetricPoint {
  const _MetricPoint({
    required this.date,
    required this.value,
  });

  final DateTime date;
  final double? value;
}

class _TrendMetric {
  const _TrendMetric({
    required this.key,
    required this.label,
    required this.color,
  });

  final String key;
  final String label;
  final Color color;
}

class _TrendSeries {
  const _TrendSeries({
    required this.points,
    required this.startLabel,
    required this.endLabel,
    required this.loggedCount,
    required this.showRangeLabels,
    required this.monthMarkers,
  });

  final List<_MetricPoint> points;
  final String startLabel;
  final String endLabel;
  final int loggedCount;
  final bool showRangeLabels;
  final List<_MonthMarker> monthMarkers;
}

class _MonthMarker {
  const _MonthMarker({
    required this.position,
    required this.label,
    required this.showLabel,
  });

  final double position;
  final String label;
  final bool showLabel;
}

enum _TrendRange {
  sevenDays,
  thirtyDays,
  threeMonths,
  thisYear,
}

const _trendMetrics = <_TrendMetric>[
  _TrendMetric(
    key: 'mood',
    label: 'Mood',
    color: Color(0xFF2E7D5B),
  ),
  _TrendMetric(
    key: 'motivation',
    label: 'Motivation',
    color: Color(0xFF2F6FDB),
  ),
  _TrendMetric(
    key: 'fatigue',
    label: 'Fatigue',
    color: Color(0xFFC56A1A),
  ),
  _TrendMetric(
    key: 'hunger',
    label: 'Hunger',
    color: Color(0xFF8E5CC2),
  ),
  _TrendMetric(
    key: 'sweet_craving',
    label: 'Sweet Craving',
    color: Color(0xFFD14E7A),
  ),
];

final _mentalMetrics = <_TrendMetric>[
  _trendMetrics[0],
  _trendMetrics[1],
  _trendMetrics[2],
];

final _appetiteMetrics = <_TrendMetric>[
  _trendMetrics[3],
  _trendMetrics[4],
];

_TrendSeries _buildTrendSeries({
  required List<DailyLogEntry> entries,
  required _TrendRange range,
  required String metricKey,
  required int selectedYear,
}) {
  switch (range) {
    case _TrendRange.sevenDays:
      return _buildDailySeries(
        entries: entries,
        days: 7,
        metricKey: metricKey,
      );
    case _TrendRange.thirtyDays:
      return _buildDailySeries(
        entries: entries,
        days: 30,
        metricKey: metricKey,
      );
    case _TrendRange.threeMonths:
      return _buildWeeklySeries(
        entries: entries,
        weeks: 13,
        metricKey: metricKey,
      );
    case _TrendRange.thisYear:
      return _buildThisYearSeries(
        entries: entries,
        metricKey: metricKey,
        selectedYear: selectedYear,
      );
  }
}

_TrendSeries _buildDailySeries({
  required List<DailyLogEntry> entries,
  required int days,
  required String metricKey,
}) {
  final today = _dateOnly(DateTime.now());
  final start = today.subtract(Duration(days: days - 1));
  final valuesByDate = <String, double>{};

  for (final entry in entries) {
    final entryDate = _dateOnly(entry.loggedAt);
    if (entryDate.isBefore(start) || entryDate.isAfter(today)) {
      continue;
    }

    final value = entry.responses[metricKey];
    if (value != null) {
      valuesByDate[_dateKey(entryDate)] = value.toDouble();
    }
  }

  final points = List.generate(days, (index) {
    final date = start.add(Duration(days: index));
    return _MetricPoint(
      date: date,
      value: valuesByDate[_dateKey(date)],
    );
  });

  return _TrendSeries(
    points: points,
    startLabel: _formatShortDate(points.first.date),
    endLabel: _formatShortDate(points.last.date),
    loggedCount: valuesByDate.length,
    showRangeLabels: true,
    monthMarkers: const [],
  );
}

_TrendSeries _buildWeeklySeries({
  required List<DailyLogEntry> entries,
  required int weeks,
  required String metricKey,
}) {
  final currentWeekStart = _startOfWeek(_dateOnly(DateTime.now()));
  final startWeek = currentWeekStart.subtract(Duration(days: (weeks - 1) * 7));
  final bucketValues = <String, List<int>>{};

  for (final entry in entries) {
    final entryDate = _dateOnly(entry.loggedAt);
    final weekStart = _startOfWeek(entryDate);
    if (weekStart.isBefore(startWeek) || weekStart.isAfter(currentWeekStart)) {
      continue;
    }

    final value = entry.responses[metricKey];
    if (value != null) {
      bucketValues.putIfAbsent(_dateKey(weekStart), () => []).add(value);
    }
  }

  final points = List.generate(weeks, (index) {
    final weekStart = startWeek.add(Duration(days: index * 7));
    final values = bucketValues[_dateKey(weekStart)];
    final average = values == null || values.isEmpty
        ? null
        : values.reduce((sum, value) => sum + value) / values.length;

    return _MetricPoint(
      date: weekStart,
      value: average,
    );
  });

  final monthMarkers = _buildMonthMarkers(
    startDate: points.first.date,
    endDate: points.last.date,
    labelEveryMonths: 1,
  );

  return _TrendSeries(
    points: points,
    startLabel: _formatShortDate(points.first.date),
    endLabel: _formatShortDate(points.last.date),
    loggedCount: points.where((point) => point.value != null).length,
    showRangeLabels: false,
    monthMarkers: monthMarkers,
  );
}

_TrendSeries _buildThisYearSeries({
  required List<DailyLogEntry> entries,
  required String metricKey,
  required int selectedYear,
}) {
  final today = _dateOnly(DateTime.now());
  final isCurrentYear = selectedYear == today.year;
  final periodEnd = isCurrentYear ? today : DateTime(selectedYear, 12, 31);
  final yearStart = DateTime(selectedYear, 1, 1);
  final bucketValues = <String, List<int>>{};

  for (final entry in entries) {
    final entryDate = _dateOnly(entry.loggedAt);
    if (entryDate.isBefore(yearStart) || entryDate.isAfter(periodEnd)) {
      continue;
    }

    final value = entry.responses[metricKey];
    if (value != null) {
      final periodStart = _startOfTwoWeekPeriod(entryDate, yearStart);
      bucketValues.putIfAbsent(_dateKey(periodStart), () => []).add(value);
    }
  }

  final points = <_MetricPoint>[];
  var cursor = yearStart;
  while (!cursor.isAfter(periodEnd)) {
    final values = bucketValues[_dateKey(cursor)];
    final average = values == null || values.isEmpty
        ? null
        : values.reduce((sum, value) => sum + value) / values.length;
    points.add(_MetricPoint(date: cursor, value: average));
    cursor = cursor.add(const Duration(days: 14));
  }

  final monthMarkers = _buildMonthMarkers(
    startDate: points.first.date,
    endDate: points.last.date,
    labelEveryMonths: 3,
  );

  return _TrendSeries(
    points: points,
    startLabel: _formatShortDate(points.first.date),
    endLabel: _formatShortDate(points.last.date),
    loggedCount: points.where((point) => point.value != null).length,
    showRangeLabels: false,
    monthMarkers: monthMarkers,
  );
}

List<int> _availableYears(List<DailyLogEntry> entries) {
  final years = entries.map((entry) => entry.loggedAt.year).toSet().toList()
    ..sort((a, b) => b.compareTo(a));
  return years;
}

DateTime _dateOnly(DateTime dateTime) {
  return DateTime(dateTime.year, dateTime.month, dateTime.day);
}

DateTime _startOfWeek(DateTime dateTime) {
  return dateTime.subtract(Duration(days: dateTime.weekday - DateTime.monday));
}

String _dateKey(DateTime dateTime) {
  final year = dateTime.year.toString().padLeft(4, '0');
  final month = dateTime.month.toString().padLeft(2, '0');
  final day = dateTime.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

String _formatShortDate(DateTime dateTime) {
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

  return '${months[dateTime.month - 1]} ${dateTime.day}';
}

List<_MonthMarker> _buildMonthMarkers({
  required DateTime startDate,
  required DateTime endDate,
  required int labelEveryMonths,
}) {
  final markers = <_MonthMarker>[];
  final totalDays = endDate.difference(startDate).inDays.toDouble();
  if (totalDays <= 0) {
    return markers;
  }

  var current = DateTime(startDate.year, startDate.month, 1);
  if (current.isBefore(startDate)) {
    current = DateTime(startDate.year, startDate.month + 1, 1);
  }

  while (!current.isAfter(endDate)) {
    final offsetDays = current.difference(startDate).inDays.toDouble();
    final position = (offsetDays / totalDays).clamp(0.0, 1.0);
    markers.add(
      _MonthMarker(
        position: position,
        label: _formatMonthLabel(current),
        showLabel: ((current.month - 1) % labelEveryMonths) == 0,
      ),
    );
    current = DateTime(current.year, current.month + 1, 1);
  }

  return markers;
}

DateTime _startOfTwoWeekPeriod(DateTime dateTime, DateTime anchorDate) {
  final offsetDays = dateTime.difference(anchorDate).inDays;
  final periodIndex = offsetDays ~/ 14;
  return anchorDate.add(Duration(days: periodIndex * 14));
}

String _formatMonthLabel(DateTime dateTime) {
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

  return months[dateTime.month - 1];
}
