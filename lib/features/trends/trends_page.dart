import 'package:flutter/material.dart';
import 'package:mood_tracker/app/settings_menu_button.dart';
import 'package:mood_tracker/features/daily_log/models/daily_log_entry.dart';
import 'package:mood_tracker/features/wearables/models/daily_wearable_metric.dart';
import 'package:mood_tracker/features/wearables/models/wearable_metric_type.dart';
import 'package:mood_tracker/features/wearables/models/wearable_provider.dart';

class TrendsPage extends StatefulWidget {
  const TrendsPage({
    super.key,
    required this.entries,
    required this.wearableMetrics,
  });

  final List<DailyLogEntry> entries;
  final List<DailyWearableMetric> wearableMetrics;

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
      for (final metric in widget.wearableMetrics) metric.date.year,
    }.toList()
      ..sort();
    return years;
  }

  @override
  Widget build(BuildContext context) {
    final primaryMetric = _metricById(_selectedMetric);
    final secondaryMetric = _comparisonMetric == null
        ? null
        : _metricById(_comparisonMetric!);
    final subjectiveChartData = _buildSubjectiveChartData(
      entries: widget.entries,
      primaryMetric: primaryMetric,
      comparisonMetric: secondaryMetric,
      period: _selectedPeriod,
      selectedYear: _selectedYear ?? DateTime.now().year,
    );
    final fitbitMetrics = [
      for (final metric in widget.wearableMetrics)
        if (metric.provider == WearableProvider.fitbit) metric,
    ];
    final sleepChartData = _buildWearableChartData(
      metrics: fitbitMetrics,
      metric: _wearableMetrics[0],
      period: _selectedPeriod,
      selectedYear: _selectedYear ?? DateTime.now().year,
    );
    final heartChartData = _buildWearableChartData(
      metrics: fitbitMetrics,
      metric: _wearableMetrics[1],
      period: _selectedPeriod,
      selectedYear: _selectedYear ?? DateTime.now().year,
    );
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trends'),
        actions: const [SettingsMenuButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
          _TrendCard(
            title: 'Manual Trends',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
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
                SizedBox(
                  height: 320,
                  child: CustomPaint(
                    painter: _TrendChartPainter(
                      series: subjectiveChartData.series,
                      xAxisLabels: subjectiveChartData.xAxisLabels,
                      verticalMarkers: subjectiveChartData.verticalMarkers,
                      emptyMessage: subjectiveChartData.hasAnyData
                          ? null
                          : 'No manual logs in this period.',
                      yAxisSpec: const _ChartYAxisSpec.fixed(
                        min: 1,
                        max: 5,
                        ticks: [1, 2, 3, 4, 5],
                      ),
                      showCenterReferenceTicks: true,
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
          const SizedBox(height: 16),
          _TrendCard(
            title: 'Wearable Trends',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fitbit daily metrics',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                _WearableMetricSection(
                  title: 'Sleep Duration',
                  unitLabel: 'min',
                  color: _wearableMetrics[0].color,
                  chartData: sleepChartData,
                ),
                const SizedBox(height: 20),
                _WearableMetricSection(
                  title: 'Resting Heart Rate',
                  unitLabel: 'bpm',
                  color: _wearableMetrics[1].color,
                  chartData: heartChartData,
                ),
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

class _TrendCard extends StatelessWidget {
  const _TrendCard({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _WearableMetricSection extends StatelessWidget {
  const _WearableMetricSection({
    required this.title,
    required this.unitLabel,
    required this.color,
    required this.chartData,
  });

  final String title;
  final String unitLabel;
  final Color color;
  final _TrendChartData chartData;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$title ($unitLabel)',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 220,
          child: CustomPaint(
            painter: _TrendChartPainter(
              series: chartData.series,
              xAxisLabels: chartData.xAxisLabels,
              verticalMarkers: chartData.verticalMarkers,
              emptyMessage: chartData.hasAnyData
                  ? null
                  : 'No wearable data in this period.',
              yAxisSpec: chartData.yAxisSpec!,
              showCenterReferenceTicks: false,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ],
    );
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
    required this.yAxisSpec,
    required this.showCenterReferenceTicks,
  });

  final List<_ChartSeries> series;
  final List<_AxisLabel> xAxisLabels;
  final List<double> verticalMarkers;
  final String? emptyMessage;
  final _ChartYAxisSpec yAxisSpec;
  final bool showCenterReferenceTicks;

  static const _leftPadding = 32.0;
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

    for (final value in yAxisSpec.ticks) {
      final y = _yForValue(chartRect, value, yAxisSpec.min, yAxisSpec.max);
      canvas.drawLine(
        Offset(chartRect.left, y),
        Offset(chartRect.right, y),
        gridPaint,
      );
      _paintText(
        canvas,
        yAxisSpec.labelFor(value),
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

    if (showCenterReferenceTicks) {
      _paintCenterTicks(canvas, chartRect);
    }

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

  void _paintSeries(Canvas canvas, Rect chartRect, _ChartSeries chartSeries) {
    final pointPaint = Paint()..color = chartSeries.color;
    final linePaint = Paint()
      ..color = chartSeries.color.withValues(alpha: 0.42)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    Offset? previousPoint;
    int? previousIndex;

    for (var index = 0; index < chartSeries.values.length; index++) {
      final value = chartSeries.values[index];
      if (value == null) {
        previousPoint = null;
        previousIndex = null;
        continue;
      }

      final point = Offset(
        _xForRatio(chartRect, _ratioForIndex(index, chartSeries.values.length)),
        _yForValue(chartRect, value, yAxisSpec.min, yAxisSpec.max),
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
    final centerY = _yForValue(
      chartRect,
      (yAxisSpec.min + yAxisSpec.max) / 2,
      yAxisSpec.min,
      yAxisSpec.max,
    );

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

  static double _yForValue(
    Rect chartRect,
    double value,
    double min,
    double max,
  ) {
    final span = (max - min).abs() < 0.0001 ? 1 : max - min;
    final normalized = (value - min) / span;
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
        oldDelegate.emptyMessage != emptyMessage ||
        oldDelegate.yAxisSpec != yAxisSpec ||
        oldDelegate.showCenterReferenceTicks != showCenterReferenceTicks;
  }
}

_TrendChartData _buildSubjectiveChartData({
  required List<DailyLogEntry> entries,
  required _TrendMetric primaryMetric,
  required _TrendMetric? comparisonMetric,
  required _TrendPeriod period,
  required int selectedYear,
}) {
  final slotDates = _buildSlotDates(period, selectedYear);
  final series = <_ChartSeries>[
    _ChartSeries(
      label: primaryMetric.label,
      values: _buildSubjectiveSeriesValues(
        entries,
        primaryMetric.id.key,
        period,
        slotDates,
      ),
      color: primaryMetric.color,
    ),
  ];

  if (comparisonMetric != null) {
    series.add(
      _ChartSeries(
        label: comparisonMetric.label,
        values: _buildSubjectiveSeriesValues(
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

_TrendChartData _buildWearableChartData({
  required List<DailyWearableMetric> metrics,
  required _WearableTrendMetric metric,
  required _TrendPeriod period,
  required int selectedYear,
}) {
  final slotDates = _buildSlotDates(period, selectedYear);
  final values = _buildWearableSeriesValues(
    metrics,
    metric.metricType,
    period,
    slotDates,
  );

  return _TrendChartData(
    series: [
      _ChartSeries(
        label: metric.label,
        values: values,
        color: metric.color,
      ),
    ],
    xAxisLabels: _buildXAxisLabels(period, slotDates),
    verticalMarkers: _buildVerticalMarkers(period, slotDates),
    hasAnyData: values.any((value) => value != null),
    yAxisSpec: _buildWearableYAxisSpec(metric.metricType, values),
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
      final end = selectedYear == today.year
          ? today
          : DateTime(selectedYear, 12, 31);
      final slots = <DateTime>[];
      var cursor = start;
      while (!cursor.isAfter(end)) {
        slots.add(cursor);
        cursor = cursor.add(const Duration(days: 14));
      }
      return slots;
  }
}

List<double?> _buildSubjectiveSeriesValues(
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
          _averageEntryRange(
            entries: entries,
            metricKey: metricKey,
            start: start,
            end: start.add(const Duration(days: 6)),
          ),
      ];
    case _TrendPeriod.oneYear:
      return [
        for (final start in slotDates)
          _averageEntryRange(
            entries: entries,
            metricKey: metricKey,
            start: start,
            end: start.add(const Duration(days: 13)),
          ),
      ];
  }
}

List<double?> _buildWearableSeriesValues(
  List<DailyWearableMetric> metrics,
  WearableMetricType metricType,
  _TrendPeriod period,
  List<DateTime> slotDates,
) {
  final filteredMetrics = [
    for (final metric in metrics)
      if (metric.metricType == metricType) metric,
  ];

  switch (period) {
    case _TrendPeriod.sevenDays:
    case _TrendPeriod.thirtyDays:
      final metricByDate = {
        for (final metric in filteredMetrics) _dateKey(metric.date): metric,
      };
      return [
        for (final date in slotDates) metricByDate[_dateKey(date)]?.value,
      ];
    case _TrendPeriod.threeMonths:
      return [
        for (final start in slotDates)
          _averageWearableRange(
            metrics: filteredMetrics,
            start: start,
            end: start.add(const Duration(days: 6)),
          ),
      ];
    case _TrendPeriod.oneYear:
      return [
        for (final start in slotDates)
          _averageWearableRange(
            metrics: filteredMetrics,
            start: start,
            end: start.add(const Duration(days: 13)),
          ),
      ];
  }
}

double? _averageEntryRange({
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

  return count == 0 ? null : total / count;
}

double? _averageWearableRange({
  required List<DailyWearableMetric> metrics,
  required DateTime start,
  required DateTime end,
}) {
  var total = 0.0;
  var count = 0;

  for (final metric in metrics) {
    final date = _dateOnly(metric.date);
    if (date.isBefore(start) || date.isAfter(end)) {
      continue;
    }

    total += metric.value;
    count += 1;
  }

  return count == 0 ? null : total / count;
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
    case _TrendPeriod.oneYear:
      return _buildMonthMarkerRatios(slotDates: slotDates);
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
        _AxisLabel(text: _formatShortDate(slotDates.first), positionRatio: 0),
        _AxisLabel(text: _formatShortDate(slotDates.last), positionRatio: 1),
      ];
    case _TrendPeriod.threeMonths:
      return _buildMonthLabels(slotDates: slotDates, monthStep: 1);
    case _TrendPeriod.oneYear:
      return _buildMonthLabels(slotDates: slotDates, monthStep: 3);
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

_ChartYAxisSpec _buildWearableYAxisSpec(
  WearableMetricType metricType,
  List<double?> values,
) {
  final presentValues = <double>[
    ...values.whereType<double>(),
  ];
  if (presentValues.isEmpty) {
    switch (metricType) {
      case WearableMetricType.sleepDurationMin:
        return const _ChartYAxisSpec.fixed(
          min: 0,
          max: 600,
          ticks: [0, 300, 600],
        );
      case WearableMetricType.restingHeartRateBpm:
        return const _ChartYAxisSpec.fixed(
          min: 40,
          max: 80,
          ticks: [40, 60, 80],
        );
    }
  }

  var minValue = presentValues.first;
  var maxValue = presentValues.first;
  for (final value in presentValues.skip(1)) {
    if (value < minValue) {
      minValue = value;
    }
    if (value > maxValue) {
      maxValue = value;
    }
  }

  final range = (maxValue - minValue).abs();
  final padding = range < 1 ? _maxValue(1, maxValue * 0.1) : range * 0.2;
  final min = (minValue - padding).floorToDouble();
  final max = (maxValue + padding).ceilToDouble();
  final mid = (min + max) / 2;

  return _ChartYAxisSpec.fixed(
    min: min,
    max: max,
    ticks: [min, mid, max],
  );
}

double _maxValue(num a, num b) => a > b ? a.toDouble() : b.toDouble();

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

class _WearableTrendMetric {
  const _WearableTrendMetric({
    required this.metricType,
    required this.label,
    required this.color,
  });

  final WearableMetricType metricType;
  final String label;
  final Color color;
}

class _TrendChartData {
  const _TrendChartData({
    required this.series,
    required this.xAxisLabels,
    required this.verticalMarkers,
    required this.hasAnyData,
    this.yAxisSpec,
  });

  final List<_ChartSeries> series;
  final List<_AxisLabel> xAxisLabels;
  final List<double> verticalMarkers;
  final bool hasAnyData;
  final _ChartYAxisSpec? yAxisSpec;
}

class _ChartSeries {
  const _ChartSeries({
    required this.label,
    required this.values,
    required this.color,
  });

  final String label;
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

class _ChartYAxisSpec {
  const _ChartYAxisSpec.fixed({
    required this.min,
    required this.max,
    required this.ticks,
  }) : labelBuilder = null;

  final double min;
  final double max;
  final List<double> ticks;
  final String Function(double value)? labelBuilder;

  String labelFor(double value) {
    return labelBuilder?.call(value) ?? value.round().toString();
  }

  @override
  bool operator ==(Object other) {
    return other is _ChartYAxisSpec &&
        other.min == min &&
        other.max == max &&
        _listEquals(other.ticks, ticks);
  }

  @override
  int get hashCode => Object.hash(min, max, ticks.length);
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

const _wearableMetrics = <_WearableTrendMetric>[
  _WearableTrendMetric(
    metricType: WearableMetricType.sleepDurationMin,
    label: 'Sleep Duration',
    color: Color(0xFF4D74C8),
  ),
  _WearableTrendMetric(
    metricType: WearableMetricType.restingHeartRateBpm,
    label: 'Resting Heart Rate',
    color: Color(0xFFB46943),
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

bool _listEquals(List<double> a, List<double> b) {
  if (identical(a, b)) {
    return true;
  }
  if (a.length != b.length) {
    return false;
  }
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}

extension<T> on List<T> {
  T? get lastOrNull => isEmpty ? null : last;
}
