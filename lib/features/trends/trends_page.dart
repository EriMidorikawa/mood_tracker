import 'package:flutter/material.dart';
import 'package:mood_tracker/app/settings_menu_button.dart';
import 'package:mood_tracker/features/daily_log/models/daily_log_entry.dart';

class TrendsPage extends StatefulWidget {
  const TrendsPage({super.key, required this.entries});

  final List<DailyLogEntry> entries;

  @override
  State<TrendsPage> createState() => _TrendsPageState();
}

class _TrendsPageState extends State<TrendsPage> {
  _TrendMetricId _selectedMetric = _TrendMetricId.mood;
  _TrendMetricId? _comparisonMetric;
  _TrendPeriod _selectedPeriod = _TrendPeriod.sevenDays;
  int? _selectedYear;

  @override
  void initState() {
    super.initState();
    _selectedYear = _availableYears.lastOrNull ?? DateTime.now().year;
  }

  @override
  void didUpdateWidget(covariant TrendsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final availableYears = _availableYears;
    if (availableYears.isEmpty) {
      _selectedYear = DateTime.now().year;
      return;
    }

    if (!availableYears.contains(_selectedYear)) {
      _selectedYear = availableYears.last;
    }
  }

  List<int> get _availableYears {
    final years = {
      for (final entry in widget.entries) entry.loggedAt.year,
    }.toList()
      ..sort();
    return years;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final primaryMetric = _metricById(_selectedMetric);
    final secondaryMetric = _comparisonMetric == null
        ? null
        : _metricById(_comparisonMetric!);
    final chartData = _buildChartData(
      entries: widget.entries,
      primaryMetric: primaryMetric,
      comparisonMetric: secondaryMetric,
      period: _selectedPeriod,
      selectedYear: _selectedYear ?? DateTime.now().year,
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
            secondaryMetric == null
                ? primaryMetric.label
                : '${primaryMetric.label} + ${secondaryMetric.label}',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: primaryMetric.color,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 16),
          _MetricSelectorRow(
            metrics: _mentalMetrics,
            selectedMetric: _selectedMetric,
            onSelected: _handlePrimaryMetricSelected,
          ),
          const SizedBox(height: 10),
          _MetricSelectorRow(
            metrics: _appetiteMetrics,
            selectedMetric: _selectedMetric,
            onSelected: _handlePrimaryMetricSelected,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              PopupMenuButton<_TrendMetricId?>(
                onSelected: _handleCompareMetricSelected,
                itemBuilder: (context) {
                  final availableMetrics = _trendMetrics
                      .where((metric) => metric.id != _selectedMetric)
                      .toList();

                  return [
                    for (final metric in availableMetrics)
                      PopupMenuItem<_TrendMetricId?>(
                        value: metric.id,
                        child: Text(metric.label),
                      ),
                    if (_comparisonMetric != null)
                      const PopupMenuItem<_TrendMetricId?>(
                        value: null,
                        child: Text('Remove compare'),
                      ),
                  ];
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: colorScheme.outlineVariant),
                    color: colorScheme.surface,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        _comparisonMetric == null
                            ? 'Compare'
                            : 'Compare: ${secondaryMetric!.label}',
                      ),
                    ],
                  ),
                ),
              ),
              if (secondaryMetric != null)
                InputChip(
                  label: Text(secondaryMetric.label),
                  avatar: CircleAvatar(
                    radius: 8,
                    backgroundColor: secondaryMetric.color,
                  ),
                  onDeleted: () {
                    setState(() {
                      _comparisonMetric = null;
                    });
                  },
                ),
            ],
          ),
          const SizedBox(height: 16),
          SegmentedButton<_TrendPeriod>(
            segments: const [
              ButtonSegment<_TrendPeriod>(
                value: _TrendPeriod.sevenDays,
                label: Text('7D'),
              ),
              ButtonSegment<_TrendPeriod>(
                value: _TrendPeriod.thirtyDays,
                label: Text('30D'),
              ),
              ButtonSegment<_TrendPeriod>(
                value: _TrendPeriod.threeMonths,
                label: Text('3M'),
              ),
              ButtonSegment<_TrendPeriod>(
                value: _TrendPeriod.oneYear,
                label: Text('1Y'),
              ),
            ],
            selected: {_selectedPeriod},
            onSelectionChanged: (selection) {
              setState(() {
                _selectedPeriod = selection.first;
                if (_selectedPeriod == _TrendPeriod.oneYear &&
                    !_availableYears.contains(_selectedYear)) {
                  _selectedYear = _availableYears.lastOrNull;
                }
              });
            },
          ),
          if (_selectedPeriod == _TrendPeriod.oneYear &&
              _availableYears.isNotEmpty) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _selectedYear,
              decoration: const InputDecoration(
                labelText: 'Year',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final year in _availableYears.reversed)
                  DropdownMenuItem<int>(
                    value: year,
                    child: Text('$year'),
                  ),
              ],
              onChanged: (value) {
                if (value == null) {
                  return;
                }

                setState(() {
                  _selectedYear = value;
                });
              },
            ),
          ],
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SizedBox(
                  height: 320,
                  child: CustomPaint(
                    painter: _TrendChartPainter(
                      series: chartData.series,
                      xAxisLabels: chartData.xAxisLabels,
                      verticalMarkers: chartData.verticalMarkers,
                      emptyMessage: chartData.hasAnyData
                          ? null
                          : 'No logs in this period.',
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
                if (secondaryMetric != null) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        _SeriesLegendChip(metric: primaryMetric),
                        _SeriesLegendChip(metric: secondaryMetric),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handlePrimaryMetricSelected(_TrendMetricId metric) {
    setState(() {
      _selectedMetric = metric;
      if (_comparisonMetric == metric) {
        _comparisonMetric = null;
      }
    });
  }

  void _handleCompareMetricSelected(_TrendMetricId? metric) {
    setState(() {
      _comparisonMetric = metric;
    });
  }
}

class _MetricSelectorRow extends StatelessWidget {
  const _MetricSelectorRow({
    required this.metrics,
    required this.selectedMetric,
    required this.onSelected,
  });

  final List<_TrendMetric> metrics;
  final _TrendMetricId selectedMetric;
  final ValueChanged<_TrendMetricId> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var index = 0; index < metrics.length; index++) ...[
          if (index > 0) const SizedBox(width: 8),
          Expanded(
            child: _MetricChoiceChip(
              metric: metrics[index],
              isSelected: metrics[index].id == selectedMetric,
              onSelected: () => onSelected(metrics[index].id),
            ),
          ),
        ],
      ],
    );
  }
}

class _MetricChoiceChip extends StatelessWidget {
  const _MetricChoiceChip({
    required this.metric,
    required this.isSelected,
    required this.onSelected,
  });

  final _TrendMetric metric;
  final bool isSelected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onSelected,
        child: Ink(
          decoration: BoxDecoration(
            color: isSelected
                ? metric.color.withValues(alpha: 0.18)
                : colorScheme.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isSelected ? metric.color : colorScheme.outlineVariant,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Center(
            child: Text(
              metric.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: isSelected ? metric.color : colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SeriesLegendChip extends StatelessWidget {
  const _SeriesLegendChip({required this.metric});

  final _TrendMetric metric;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: metric.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: metric.color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: metric.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(metric.label),
        ],
      ),
    );
  }
}

class _TrendChartPainter extends CustomPainter {
  const _TrendChartPainter({
    required this.series,
    required this.xAxisLabels,
    required this.verticalMarkers,
    required this.emptyMessage,
  });

  final List<_ChartSeries> series;
  final List<_AxisLabel> xAxisLabels;
  final List<double> verticalMarkers;
  final String? emptyMessage;

  static const _leftPadding = 22.0;
  static const _topPadding = 8.0;
  static const _rightPadding = 10.0;
  static const _bottomPadding = 28.0;

  @override
  void paint(Canvas canvas, Size size) {
    final chartRect = Rect.fromLTWH(
      _leftPadding,
      _topPadding,
      size.width - _leftPadding - _rightPadding,
      size.height - _topPadding - _bottomPadding,
    );

    final gridPaint = Paint()
      ..color = const Color(0xFFD9DCE7)
      ..strokeWidth = 1;
    final axisTextStyle = const TextStyle(
      color: Color(0xFF6D7488),
      fontSize: 12,
    );

    for (var value = 1; value <= 5; value++) {
      final y = _yForValue(chartRect, value.toDouble());
      canvas.drawLine(
        Offset(chartRect.left, y),
        Offset(chartRect.right, y),
        gridPaint,
      );

      _paintText(
        canvas,
        '$value',
        Offset(0, y - 8),
        axisTextStyle,
      );
    }

    final monthMarkerPaint = Paint()
      ..color = const Color(0xFFBFC6D8)
      ..strokeWidth = 1;
    for (final ratio in verticalMarkers) {
      final x = _xForRatio(chartRect, ratio);
      canvas.drawLine(
        Offset(x, chartRect.top),
        Offset(x, chartRect.bottom),
        monthMarkerPaint,
      );
    }

    for (final chartSeries in series) {
      _paintSeries(canvas, chartRect, chartSeries);
    }

    _paintCenterTicks(canvas, chartRect);

    for (final label in xAxisLabels) {
      final x = _xForRatio(chartRect, label.positionRatio);
      _paintText(
        canvas,
        label.text,
        Offset(x - 14, chartRect.bottom + 8),
        axisTextStyle,
      );
    }

    if (emptyMessage != null) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: emptyMessage,
          style: axisTextStyle.copyWith(fontSize: 13),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: chartRect.width - 24);
      textPainter.paint(
        canvas,
        Offset(
          chartRect.left + (chartRect.width - textPainter.width) / 2,
          chartRect.top + (chartRect.height - textPainter.height) / 2,
        ),
      );
    }
  }

  void _paintSeries(Canvas canvas, Rect chartRect, _ChartSeries series) {
    final pointPaint = Paint()..color = series.color;
    final linePaint = Paint()
      ..color = series.color.withValues(alpha: 0.42)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    Offset? previousPoint;
    int? previousIndex;

    for (var index = 0; index < series.values.length; index++) {
      final value = series.values[index];
      if (value == null) {
        previousPoint = null;
        previousIndex = null;
        continue;
      }

      final point = Offset(
        _xForRatio(chartRect, _ratioForIndex(index, series.values.length)),
        _yForValue(chartRect, value),
      );

      if (previousPoint != null && previousIndex == index - 1) {
        canvas.drawLine(previousPoint, point, linePaint);
      }

      canvas.drawCircle(point, 2.4, pointPaint);
      previousPoint = point;
      previousIndex = index;
    }
  }

  void _paintCenterTicks(Canvas canvas, Rect chartRect) {
    final tickPaint = Paint()
      ..color = const Color(0xFF7C8294).withValues(alpha: 0.55)
      ..strokeWidth = 1;
    final centerY = _yForValue(chartRect, 3);

    final totalSlots = series.isEmpty ? 0 : series.first.values.length;
    for (var index = 0; index < totalSlots; index++) {
      final x = _xForRatio(chartRect, _ratioForIndex(index, totalSlots));
      canvas.drawLine(
        Offset(x, centerY - 4),
        Offset(x, centerY + 4),
        tickPaint,
      );
    }
  }

  static double _xForRatio(Rect chartRect, double ratio) {
    return chartRect.left + (chartRect.width * ratio);
  }

  static double _ratioForIndex(int index, int total) {
    if (total <= 1) {
      return 1;
    }

    return index / (total - 1);
  }

  static double _yForValue(Rect chartRect, double value) {
    final normalized = (value - 1) / 4;
    return chartRect.bottom - (chartRect.height * normalized);
  }

  void _paintText(
    Canvas canvas,
    String text,
    Offset offset,
    TextStyle style,
  ) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _TrendChartPainter oldDelegate) {
    return oldDelegate.series != series ||
        oldDelegate.xAxisLabels != xAxisLabels ||
        oldDelegate.verticalMarkers != verticalMarkers ||
        oldDelegate.emptyMessage != emptyMessage;
  }
}

_TrendChartData _buildChartData({
  required List<DailyLogEntry> entries,
  required _TrendMetric primaryMetric,
  required _TrendMetric? comparisonMetric,
  required _TrendPeriod period,
  required int selectedYear,
}) {
  final slotDates = _buildSlotDates(period, selectedYear);
  final series = <_ChartSeries>[
    _ChartSeries(
      metric: primaryMetric,
      values: _buildSeriesValues(entries, primaryMetric.id.key, period, slotDates),
      color: primaryMetric.color,
    ),
  ];

  if (comparisonMetric != null) {
    series.add(
      _ChartSeries(
        metric: comparisonMetric,
        values: _buildSeriesValues(
          entries,
          comparisonMetric.id.key,
          period,
          slotDates,
        ),
        color: comparisonMetric.color,
      ),
    );
  }

  return _TrendChartData(
    series: series,
    xAxisLabels: _buildXAxisLabels(period, slotDates),
    verticalMarkers: _buildVerticalMarkers(period, slotDates),
    hasAnyData: series.any((series) => series.values.any((value) => value != null)),
  );
}

List<DateTime> _buildSlotDates(_TrendPeriod period, int selectedYear) {
  final today = _dateOnly(DateTime.now());
  switch (period) {
    case _TrendPeriod.sevenDays:
      return [
        for (var offset = 6; offset >= 0; offset--)
          today.subtract(Duration(days: offset)),
      ];
    case _TrendPeriod.thirtyDays:
      return [
        for (var offset = 29; offset >= 0; offset--)
          today.subtract(Duration(days: offset)),
      ];
    case _TrendPeriod.threeMonths:
      final currentWeek = _startOfWeek(today);
      return [
        for (var offset = 12; offset >= 0; offset--)
          currentWeek.subtract(Duration(days: offset * 7)),
      ];
    case _TrendPeriod.oneYear:
      final start = DateTime(selectedYear, 1, 1);
      final end = selectedYear == today.year ? today : DateTime(selectedYear, 12, 31);
      final slots = <DateTime>[];
      var cursor = start;
      while (!cursor.isAfter(end)) {
        slots.add(cursor);
        cursor = cursor.add(const Duration(days: 14));
      }
      return slots;
  }
}

List<double?> _buildSeriesValues(
  List<DailyLogEntry> entries,
  String metricKey,
  _TrendPeriod period,
  List<DateTime> slotDates,
) {
  switch (period) {
    case _TrendPeriod.sevenDays:
    case _TrendPeriod.thirtyDays:
      final entryByDate = {
        for (final entry in entries) _dateKey(entry.loggedAt): entry,
      };
      return [
        for (final date in slotDates)
          entryByDate[_dateKey(date)]?.responses[metricKey]?.toDouble(),
      ];
    case _TrendPeriod.threeMonths:
      return [
        for (final start in slotDates)
          _averageForRange(
            entries: entries,
            metricKey: metricKey,
            start: start,
            end: start.add(const Duration(days: 6)),
          ),
      ];
    case _TrendPeriod.oneYear:
      return [
        for (final start in slotDates)
          _averageForRange(
            entries: entries,
            metricKey: metricKey,
            start: start,
            end: start.add(const Duration(days: 13)),
          ),
      ];
  }
}

double? _averageForRange({
  required List<DailyLogEntry> entries,
  required String metricKey,
  required DateTime start,
  required DateTime end,
}) {
  var total = 0;
  var count = 0;

  for (final entry in entries) {
    final loggedAt = _dateOnly(entry.loggedAt);
    if (loggedAt.isBefore(start) || loggedAt.isAfter(end)) {
      continue;
    }

    final value = entry.responses[metricKey];
    if (value == null) {
      continue;
    }

    total += value;
    count += 1;
  }

  if (count == 0) {
    return null;
  }

  return total / count;
}

List<double> _buildVerticalMarkers(_TrendPeriod period, List<DateTime> slotDates) {
  if (slotDates.length < 2) {
    return const [];
  }

  switch (period) {
    case _TrendPeriod.sevenDays:
    case _TrendPeriod.thirtyDays:
      return const [];
    case _TrendPeriod.threeMonths:
      return _buildMonthMarkerRatios(
        slotDates: slotDates,
      );
    case _TrendPeriod.oneYear:
      return _buildMonthMarkerRatios(
        slotDates: slotDates,
      );
  }
}

List<_AxisLabel> _buildXAxisLabels(_TrendPeriod period, List<DateTime> slotDates) {
  if (slotDates.isEmpty) {
    return const [];
  }

  switch (period) {
    case _TrendPeriod.sevenDays:
    case _TrendPeriod.thirtyDays:
      return [
        _AxisLabel(
          text: _formatShortDate(slotDates.first),
          positionRatio: 0,
        ),
        _AxisLabel(
          text: _formatShortDate(slotDates.last),
          positionRatio: 1,
        ),
      ];
    case _TrendPeriod.threeMonths:
      return _buildMonthLabels(
        slotDates: slotDates,
        monthStep: 1,
      );
    case _TrendPeriod.oneYear:
      return _buildMonthLabels(
        slotDates: slotDates,
        monthStep: 3,
      );
  }
}

List<double> _buildMonthMarkerRatios({
  required List<DateTime> slotDates,
}) {
  final start = slotDates.first;
  final end = slotDates.last;
  final markers = <double>[];

  var cursor = DateTime(start.year, start.month, 1);
  if (cursor.isBefore(start)) {
    cursor = DateTime(start.year, start.month + 1, 1);
  }

  while (!cursor.isAfter(end)) {
    final ratio = _ratioForDate(start, end, cursor);
    if (ratio > 0 && ratio < 1) {
      markers.add(ratio);
    }
    cursor = DateTime(cursor.year, cursor.month + 1, 1);
  }

  return markers;
}

List<_AxisLabel> _buildMonthLabels({
  required List<DateTime> slotDates,
  required int monthStep,
}) {
  final start = slotDates.first;
  final end = slotDates.last;
  final labels = <_AxisLabel>[];

  var cursor = DateTime(start.year, start.month, 1);
  if (cursor.isBefore(start)) {
    cursor = DateTime(start.year, start.month + 1, 1);
  }

  var monthIndex = 0;
  while (!cursor.isAfter(end)) {
    if (monthIndex % monthStep == 0) {
      labels.add(
        _AxisLabel(
          text: _monthName(cursor.month),
          positionRatio: _ratioForDate(start, end, cursor),
        ),
      );
    }
    monthIndex += 1;
    cursor = DateTime(cursor.year, cursor.month + 1, 1);
  }

  return labels;
}

double _ratioForDate(DateTime start, DateTime end, DateTime date) {
  final totalDays = end.difference(start).inDays;
  if (totalDays <= 0) {
    return 0;
  }

  return date.difference(start).inDays / totalDays;
}

DateTime _dateOnly(DateTime dateTime) {
  return DateTime(dateTime.year, dateTime.month, dateTime.day);
}

DateTime _startOfWeek(DateTime dateTime) {
  final date = _dateOnly(dateTime);
  return date.subtract(Duration(days: date.weekday - DateTime.monday));
}

String _dateKey(DateTime dateTime) {
  final year = dateTime.year.toString().padLeft(4, '0');
  final month = dateTime.month.toString().padLeft(2, '0');
  final day = dateTime.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

String _formatShortDate(DateTime dateTime) {
  return '${_monthName(dateTime.month)} ${dateTime.day}';
}

String _monthName(int month) {
  const months = [
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

  return months[month - 1];
}

_TrendMetric _metricById(_TrendMetricId id) {
  return _trendMetrics.firstWhere((metric) => metric.id == id);
}

enum _TrendPeriod {
  sevenDays,
  thirtyDays,
  threeMonths,
  oneYear,
}

enum _TrendMetricId {
  mood('mood'),
  motivation('motivation'),
  fatigue('fatigue'),
  hunger('hunger'),
  sweetCraving('sweet_craving');

  const _TrendMetricId(this.key);

  final String key;
}

class _TrendMetric {
  const _TrendMetric({
    required this.id,
    required this.label,
    required this.color,
  });

  final _TrendMetricId id;
  final String label;
  final Color color;
}

class _TrendChartData {
  const _TrendChartData({
    required this.series,
    required this.xAxisLabels,
    required this.verticalMarkers,
    required this.hasAnyData,
  });

  final List<_ChartSeries> series;
  final List<_AxisLabel> xAxisLabels;
  final List<double> verticalMarkers;
  final bool hasAnyData;
}

class _ChartSeries {
  const _ChartSeries({
    required this.metric,
    required this.values,
    required this.color,
  });

  final _TrendMetric metric;
  final List<double?> values;
  final Color color;
}

class _AxisLabel {
  const _AxisLabel({
    required this.text,
    required this.positionRatio,
  });

  final String text;
  final double positionRatio;
}

const _trendMetrics = <_TrendMetric>[
  _TrendMetric(
    id: _TrendMetricId.mood,
    label: 'Mood',
    color: Color(0xFF3E8E69),
  ),
  _TrendMetric(
    id: _TrendMetricId.motivation,
    label: 'Motivation',
    color: Color(0xFF4D74C8),
  ),
  _TrendMetric(
    id: _TrendMetricId.fatigue,
    label: 'Fatigue',
    color: Color(0xFFB46943),
  ),
  _TrendMetric(
    id: _TrendMetricId.hunger,
    label: 'Hunger',
    color: Color(0xFF8B6BB8),
  ),
  _TrendMetric(
    id: _TrendMetricId.sweetCraving,
    label: 'Sweet Craving',
    color: Color(0xFFC4537A),
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

extension<T> on List<T> {
  T? get lastOrNull => isEmpty ? null : last;
}
