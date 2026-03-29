import 'package:flutter/material.dart';
import 'package:mood_tracker/features/wearables/data/fitbit_api_client.dart';
import 'package:mood_tracker/features/wearables/data/fitbit_source_adapter.dart';
import 'package:mood_tracker/features/wearables/data/local_wearable_repository.dart';
import 'package:mood_tracker/features/wearables/models/daily_wearable_metric.dart';
import 'package:mood_tracker/features/wearables/models/wearable_connection.dart';
import 'package:mood_tracker/features/wearables/models/wearable_metric_type.dart';
import 'package:mood_tracker/features/wearables/models/wearable_provider.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _wearableRepository = LocalWearableRepository();
  final _fitbitClient = FitbitApiClient();
  WearableConnection? _fitbitConnection;
  bool _isSavingSample = false;
  String? _sampleSaveResult;
  bool _isSyncingFitbit = false;
  String? _fitbitSyncResult;

  @override
  void initState() {
    super.initState();
    _loadFitbitConnection();
  }

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
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fitbit sync',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sync today\'s Fitbit wearable metrics once.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Status: ${_fitbitConnection?.isConnected == true ? 'Connected' : 'Not connected'}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (_fitbitConnection?.lastSyncedAt case final lastSyncedAt?) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Last synced: ${_formatDateTime(lastSyncedAt)}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _isSyncingFitbit ? null : _syncFitbitData,
                    child: Text(
                      _isSyncingFitbit
                          ? 'Syncing Fitbit data...'
                          : 'Sync Fitbit data',
                    ),
                  ),
                  if (_fitbitSyncResult != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _fitbitSyncResult!,
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

  Future<void> _syncFitbitData() async {
    setState(() {
      _isSyncingFitbit = true;
      _fitbitSyncResult = null;
    });

    try {
      final today = _dateOnly(DateTime.now());
      final now = DateTime.now();
      final fitbitAdapter = FitbitSourceAdapter(
        fetchSnapshot: _fitbitClient.fetchDailySnapshot,
      );
      final metrics = await fitbitAdapter.fetchDailyMetrics(today);
      await _wearableRepository.upsertDailyMetrics(metrics);
      final existingConnection = await _wearableRepository.loadConnection(
        WearableProvider.fitbit,
      );
      await _wearableRepository.upsertConnection(
        WearableConnection(
          provider: WearableProvider.fitbit,
          isConnected: true,
          accountLabel: existingConnection?.accountLabel,
          connectedAt: existingConnection?.connectedAt ?? now,
          lastSyncedAt: now,
        ),
      );
      final updatedConnection = await _wearableRepository.loadConnection(
        WearableProvider.fitbit,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _fitbitConnection = updatedConnection;
        _isSyncingFitbit = false;
        _fitbitSyncResult = 'Fitbit data synced';
      });
    } on FitbitApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSyncingFitbit = false;
        _fitbitSyncResult = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSyncingFitbit = false;
        _fitbitSyncResult = 'Fitbit sync failed';
      });
    }
  }

  Future<void> _loadFitbitConnection() async {
    final connection = await _wearableRepository.loadConnection(
      WearableProvider.fitbit,
    );
    if (!mounted) {
      return;
    }

    setState(() {
      _fitbitConnection = connection;
    });
  }
}

DateTime _dateOnly(DateTime dateTime) {
  return DateTime(dateTime.year, dateTime.month, dateTime.day);
}

String _formatDateTime(DateTime dateTime) {
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
  final hour24 = dateTime.hour;
  final minute = dateTime.minute.toString().padLeft(2, '0');
  final period = hour24 >= 12 ? 'PM' : 'AM';
  final hour12 = hour24 == 0
      ? 12
      : hour24 > 12
          ? hour24 - 12
          : hour24;

  return '$month $day, $year $hour12:$minute $period';
}
