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
  int _selectedDays = 7;
  _TrendMetric _selectedMetric = _trendMetrics.first;

  @override
  Widget build(BuildContext context) {
    final points = _buildMetricPoints(
      entries: widget.entries,
      days: _selectedDays,
      metricKey: _selectedMetric.key,
    );
    final loggedValues = points
        .where((point) => point.value != null)
        .map((point) => point.value!)
        .toList();
    final latestValue = loggedValues.isEmpty ? null : loggedValues.last;
    final averageValue = loggedValues.isEmpty
        ? null
        : loggedValues.reduce((sum, value) => sum + value) / loggedValues.length;

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
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          SegmentedButton<_TrendMetric>(
            segments: _trendMetrics
                .map(
                  (metric) => ButtonSegment<_TrendMetric>(
                    value: metric,
                    label: Text(metric.label),
                  ),
                )
                .toList(),
            selected: {_selectedMetric},
            onSelectionChanged: (selection) {
              setState(() {
                _selectedMetric = selection.first;
              });
            },
          ),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment<int>(value: 7, label: Text('7 days')),
              ButtonSegment<int>(value: 30, label: Text('30 days')),
            ],
            selected: {_selectedDays},
            onSelectionChanged: (selection) {
              setState(() {
                _selectedDays = selection.first;
              });
            },
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 240,
                    child: _MetricChart(points: points),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: Text(_formatShortDate(points.first.date))),
                      Text(_formatShortDate(points.last.date)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _SummaryPill(
                    label: 'Latest',
                    value: latestValue == null ? '--' : '$latestValue',
                  ),
                  _SummaryPill(
                    label: 'Avg',
                    value: averageValue == null
                        ? '--'
                        : averageValue.toStringAsFixed(1),
                  ),
                  _SummaryPill(
                    label: 'Logged days',
                    value: '${loggedValues.length}',
                  ),
                ],
              ),
            ),
          ),
          if (loggedValues.isEmpty) ...[
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
}

class _MetricChart extends StatelessWidget {
  const _MetricChart({
    required this.points,
  });

  final List<_MetricPoint> points;

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
  });

  final List<_MetricPoint> points;
  final ColorScheme colorScheme;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = colorScheme.outlineVariant
      ..strokeWidth = 1;
    final linePaint = Paint()
      ..color = colorScheme.primary
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final pointPaint = Paint()
      ..color = colorScheme.primary
      ..style = PaintingStyle.fill;
    final missingPaint = Paint()
      ..color = colorScheme.outline
      ..strokeWidth = 1.5;

    for (var scale = 1; scale <= 5; scale++) {
      final y = _yForValue(scale.toDouble(), size.height);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final stepX = points.length == 1 ? 0.0 : size.width / (points.length - 1);
    Offset? previousPoint;
    var previousIndex = -1;

    for (var index = 0; index < points.length; index++) {
      final point = points[index];
      final x = stepX * index;

      if (point.value == null) {
        final centerY = size.height / 2;
        canvas.drawLine(
          Offset(x, centerY - 6),
          Offset(x, centerY + 6),
          missingPaint,
        );
        previousPoint = null;
        previousIndex = -1;
        continue;
      }

      final currentPoint = Offset(
        x,
        _yForValue(point.value!.toDouble(), size.height),
      );

      if (previousPoint != null && previousIndex == index - 1) {
        canvas.drawLine(previousPoint, currentPoint, linePaint);
      }

      canvas.drawCircle(currentPoint, 4, pointPaint);
      previousPoint = currentPoint;
      previousIndex = index;
    }
  }

  double _yForValue(double value, double height) {
    final normalized = (5 - value) / 4;
    return normalized * height;
  }

  @override
  bool shouldRepaint(covariant _MetricChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.colorScheme != colorScheme;
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text('$label: $value'),
    );
  }
}

class _MetricPoint {
  const _MetricPoint({
    required this.date,
    required this.value,
  });

  final DateTime date;
  final int? value;
}

class _TrendMetric {
  const _TrendMetric({
    required this.key,
    required this.label,
  });

  final String key;
  final String label;
}

const _trendMetrics = <_TrendMetric>[
  _TrendMetric(key: 'mood', label: 'Mood'),
  _TrendMetric(key: 'motivation', label: 'Motivation'),
  _TrendMetric(key: 'fatigue', label: 'Fatigue'),
];

List<_MetricPoint> _buildMetricPoints({
  required List<DailyLogEntry> entries,
  required int days,
  required String metricKey,
}) {
  final today = _dateOnly(DateTime.now());
  final start = today.subtract(Duration(days: days - 1));
  final valuesByDate = <String, int>{};

  for (final entry in entries) {
    final entryDate = _dateOnly(entry.loggedAt);
    if (entryDate.isBefore(start) || entryDate.isAfter(today)) {
      continue;
    }

    final value = entry.responses[metricKey];
    if (value != null) {
      valuesByDate[_dateKey(entryDate)] = value;
    }
  }

  return List.generate(days, (index) {
    final date = start.add(Duration(days: index));
    return _MetricPoint(
      date: date,
      value: valuesByDate[_dateKey(date)],
    );
  });
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
