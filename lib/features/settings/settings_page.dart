import 'package:flutter/material.dart';
import 'package:mood_tracker/features/wearables/data/local_wearable_repository.dart';
import 'package:mood_tracker/features/wearables/models/daily_wearable_metric.dart';
import 'package:mood_tracker/features/wearables/models/wearable_metric_type.dart';
import 'package:mood_tracker/features/wearables/models/wearable_provider.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _wearableRepository = LocalWearableRepository();
  bool _isSavingSample = false;
  String? _sampleSaveResult;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(Icons.settings_rounded, size: 64),
          const SizedBox(height: 16),
          Text(
            'Settings',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Preferences and integrations will be managed here.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Wearable debug',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Save sample daily metrics for today.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _isSavingSample ? null : _saveSampleWearableData,
                    child: Text(
                      _isSavingSample
                          ? 'Saving sample wearable data...'
                          : 'Save sample wearable data',
                    ),
                  ),
                  if (_sampleSaveResult != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _sampleSaveResult!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveSampleWearableData() async {
    setState(() {
      _isSavingSample = true;
      _sampleSaveResult = null;
    });

    final today = _dateOnly(DateTime.now());
    final sampleMetrics = [
      DailyWearableMetric(
        provider: WearableProvider.manual,
        metricType: WearableMetricType.sleepDurationMin,
        date: today,
        value: 435,
        unit: WearableMetricType.sleepDurationMin.canonicalUnit,
      ),
      DailyWearableMetric(
        provider: WearableProvider.manual,
        metricType: WearableMetricType.restingHeartRateBpm,
        date: today,
        value: 58,
        unit: WearableMetricType.restingHeartRateBpm.canonicalUnit,
      ),
    ];

    await _wearableRepository.upsertDailyMetrics(sampleMetrics);
    if (!mounted) {
      return;
    }

    setState(() {
      _isSavingSample = false;
      _sampleSaveResult = 'Sample wearable data saved';
    });
  }
}

DateTime _dateOnly(DateTime dateTime) {
  return DateTime(dateTime.year, dateTime.month, dateTime.day);
}
