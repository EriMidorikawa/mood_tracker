import 'package:flutter/material.dart';
import 'package:mood_tracker/features/wearables/data/fitbit_api_client.dart';
import 'package:mood_tracker/features/wearables/data/fitbit_callback_debug_store.dart';
import 'package:mood_tracker/features/wearables/data/fitbit_oauth_client.dart';
import 'package:mood_tracker/features/wearables/data/fitbit_oauth_session_store.dart';
import 'package:mood_tracker/features/wearables/data/fitbit_oauth_token_store.dart';
import 'package:mood_tracker/features/wearables/data/fitbit_source_adapter.dart';
import 'package:mood_tracker/features/wearables/data/local_wearable_repository.dart';
import 'package:mood_tracker/features/wearables/models/daily_wearable_metric.dart';
import 'package:mood_tracker/features/wearables/models/fitbit_callback_debug.dart';
import 'package:mood_tracker/features/wearables/models/fitbit_oauth_token.dart';
import 'package:mood_tracker/features/wearables/models/fitbit_oauth_preparation.dart';
import 'package:mood_tracker/features/wearables/models/wearable_connection.dart';
import 'package:mood_tracker/features/wearables/models/wearable_metric_type.dart';
import 'package:mood_tracker/features/wearables/models/wearable_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const _fitbitBackfillDays = 30;

  final _wearableRepository = LocalWearableRepository();
  final _fitbitOAuthClient = FitbitOAuthClient();
  final _fitbitTokenStore = FitbitOAuthTokenStore();
  WearableConnection? _fitbitConnection;
  bool _isSyncingFitbit = false;
  bool _isBackfillingFitbit = false;
  int _fitbitBackfillProgress = 0;
  int _fitbitBackfillTarget = _fitbitBackfillDays;
  bool _isHandlingFitbitCallback = false;
  String? _fitbitSyncResult;
  String? _lastHandledCallbackUri;

  @override
  void initState() {
    super.initState();
    _loadFitbitConnection();
    fitbitCallbackDebugStore.lastCallback.addListener(_handleFitbitCallback);
  }

  @override
  void dispose() {
    fitbitCallbackDebugStore.lastCallback.removeListener(_handleFitbitCallback);
    super.dispose();
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
                    'Fitbit',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Connect Fitbit and sync your recent sleep and resting heart rate data.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Status: $_fitbitStatusLabel',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _fitbitConnection?.lastSyncedAt != null
                        ? 'Last synced: ${_formatDateTime(_fitbitConnection!.lastSyncedAt!)}'
                        : 'Last synced: Never',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  ValueListenableBuilder<FitbitOAuthPreparation?>(
                    valueListenable: fitbitOAuthSessionStore.preparedSession,
                    builder: (context, preparation, _) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          OutlinedButton(
                            onPressed: () {
                              fitbitOAuthSessionStore.prepareAuthorization();
                            },
                            child: const Text('Prepare authorization'),
                          ),
                          const SizedBox(height: 8),
                          FilledButton.tonal(
                            onPressed: preparation == null
                                ? null
                                : () => _openFitbitAuthorization(preparation),
                            child: const Text('Open Fitbit authorization'),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  ValueListenableBuilder<FitbitCallbackDebug?>(
                    valueListenable: fitbitCallbackDebugStore.lastCallback,
                    builder: (context, callback, _) {
                      if (callback == null) {
                        return Text(
                          'Last Fitbit callback URI: Not received yet',
                          style: Theme.of(context).textTheme.bodySmall,
                        );
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Last Fitbit callback URI: ${callback.uri}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          if (callback.code != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'code: ${callback.code}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                          if (callback.state != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'state: ${callback.state}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                          if (callback.stateMatched != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Last callback state matched: ${callback.stateMatched}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _isSyncingFitbit ? null : _syncFitbitData,
                    child: Text(
                      _isSyncingFitbit
                          ? 'Syncing Fitbit data...'
                          : 'Sync Fitbit data',
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.tonal(
                    onPressed: _isBackfillingFitbit ? null : _backfillFitbitData,
                    child: Text(
                      _isBackfillingFitbit
                          ? 'Backfilling Fitbit data...'
                          : 'Backfill Fitbit data (Last 30 days)',
                    ),
                  ),
                  if (_isBackfillingFitbit) ...[
                    const SizedBox(height: 8),
                    Text(
                      '$_fitbitBackfillProgress / $_fitbitBackfillTarget',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _fitbitConnection == null
                        ? null
                        : _disconnectFitbit,
                    child: const Text('Disconnect'),
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

  Future<void> _syncFitbitData() async {
    setState(() {
      _isSyncingFitbit = true;
      _fitbitSyncResult = null;
    });

    try {
      final token = await _requireValidFitbitToken(
        expiredMessage: 'Fitbit session expired. Please authorize again.',
        missingMessage: 'Fitbit authorization required',
        failureMessage: 'Could not sync Fitbit data. Please authorize again.',
      );

      final today = _dateOnly(DateTime.now());
      final now = DateTime.now();
      final fitbitAdapter = FitbitSourceAdapter(
        fetchSnapshot:
            FitbitApiClient(accessToken: token.accessToken).fetchDailySnapshot,
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
        _fitbitSyncResult = 'Synced Fitbit data for ${_formatDate(today)}';
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

  Future<void> _backfillFitbitData() async {
    setState(() {
      _isBackfillingFitbit = true;
      _fitbitBackfillProgress = 0;
      _fitbitBackfillTarget = _fitbitBackfillDays;
      _fitbitSyncResult = 'Backfilling Fitbit data...';
    });

    var importedDays = 0;
    var failedDays = 0;
    try {
      final token = await _requireValidFitbitToken(
        expiredMessage: 'Fitbit session expired. Please authorize again.',
        missingMessage: 'Fitbit authorization required',
        failureMessage: 'Could not sync Fitbit data. Please authorize again.',
      );

      final today = _dateOnly(DateTime.now());
      final startDate = today.subtract(
        const Duration(days: _fitbitBackfillDays - 1),
      );
      final existingMetrics = await _wearableRepository.loadDailyMetricsInRange(
        startDate: startDate,
        endDate: today,
        provider: WearableProvider.fitbit,
      );
      final missingDates = _buildMissingFitbitBackfillDates(
        existingMetrics: existingMetrics,
        startDate: startDate,
        endDate: today,
      );

      if (missingDates.isEmpty) {
        setState(() {
          _isBackfillingFitbit = false;
          _fitbitBackfillProgress = 0;
          _fitbitBackfillTarget = 0;
          _fitbitSyncResult = 'Last $_fitbitBackfillDays days already imported';
        });
        return;
      }

      setState(() {
        _fitbitBackfillTarget = missingDates.length;
      });

      final fitbitAdapter = FitbitSourceAdapter(
        fetchSnapshot:
            FitbitApiClient(accessToken: token.accessToken).fetchDailySnapshot,
      );

      for (final date in missingDates) {
        try {
          final metrics = await fitbitAdapter.fetchDailyMetrics(date);
          await _wearableRepository.upsertDailyMetrics(metrics);
          importedDays += 1;
        } catch (_) {
          failedDays += 1;
        }

        if (mounted) {
          setState(() {
            _fitbitBackfillProgress = importedDays + failedDays;
          });
        }
      }

      final now = DateTime.now();
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
        _isBackfillingFitbit = false;
        _fitbitBackfillProgress = importedDays + failedDays;
        _fitbitBackfillTarget = missingDates.length;
        _fitbitSyncResult = failedDays == 0
            ? 'Imported ${missingDates.length} days of Fitbit data'
            : 'Imported $importedDays of ${missingDates.length} days. Some days could not be synced.';
      });
    } on FitbitApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isBackfillingFitbit = false;
        _fitbitBackfillProgress = importedDays;
        _fitbitBackfillTarget = _fitbitBackfillTarget == 0
            ? _fitbitBackfillDays
            : _fitbitBackfillTarget;
        _fitbitSyncResult = importedDays == 0
            ? error.message
            : 'Imported $importedDays of $_fitbitBackfillTarget days. Some days could not be synced.';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isBackfillingFitbit = false;
        _fitbitBackfillProgress = importedDays;
        _fitbitBackfillTarget = _fitbitBackfillTarget == 0
            ? _fitbitBackfillDays
            : _fitbitBackfillTarget;
        _fitbitSyncResult =
            'No Fitbit data was imported. Some days could not be synced.';
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

  String get _fitbitStatusLabel {
    if (_fitbitConnection?.isConnected != true) {
      return 'Not connected';
    }

    return 'Connected';
  }

  Future<FitbitOAuthToken> _requireValidFitbitToken({
    required String missingMessage,
    required String expiredMessage,
    required String failureMessage,
  }) async {
    final token = await _fitbitTokenStore.loadToken();
    if (token == null) {
      throw FitbitApiException(missingMessage);
    }

    if (!token.isExpired) {
      return token;
    }

    final existingConnection = await _wearableRepository.loadConnection(
      WearableProvider.fitbit,
    );
    await _wearableRepository.upsertConnection(
      WearableConnection(
        provider: WearableProvider.fitbit,
        isConnected: false,
        accountLabel: existingConnection?.accountLabel,
        connectedAt: existingConnection?.connectedAt,
        lastSyncedAt: null,
      ),
    );
    final updatedConnection = await _wearableRepository.loadConnection(
      WearableProvider.fitbit,
    );
    if (mounted) {
      setState(() {
        _fitbitConnection = updatedConnection;
        _fitbitSyncResult = failureMessage;
      });
    }

    throw FitbitApiException(expiredMessage);
  }

  Future<void> _disconnectFitbit() async {
    final existingConnection = _fitbitConnection;
    if (existingConnection == null) {
      return;
    }

    await _wearableRepository.upsertConnection(
      WearableConnection(
        provider: WearableProvider.fitbit,
        isConnected: false,
        accountLabel: existingConnection.accountLabel,
        connectedAt: existingConnection.connectedAt,
        lastSyncedAt: null,
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
      _fitbitSyncResult = 'Fitbit disconnected locally';
    });
  }

  Future<void> _openFitbitAuthorization(
    FitbitOAuthPreparation preparation,
  ) async {
    final opened = await launchUrl(
      preparation.authorizationUri,
      mode: LaunchMode.externalApplication,
    );
    if (!mounted || opened) {
      return;
    }

    setState(() {
      _fitbitSyncResult = 'Could not open Fitbit authorization URL';
    });
  }

  Future<void> _handleFitbitCallback() async {
    final callback = fitbitCallbackDebugStore.lastCallback.value;
    if (callback == null ||
        callback.code == null ||
        callback.stateMatched != true ||
        callback.uri.toString() == _lastHandledCallbackUri ||
        _isHandlingFitbitCallback) {
      return;
    }

    final preparation = fitbitOAuthSessionStore.preparedSession.value;
    if (preparation == null) {
      return;
    }

    _lastHandledCallbackUri = callback.uri.toString();
    setState(() {
      _isHandlingFitbitCallback = true;
      _fitbitSyncResult = 'Completing Fitbit authorization...';
    });

    try {
      final token = await _fitbitOAuthClient.exchangeAuthorizationCode(
        code: callback.code!,
        codeVerifier: preparation.codeVerifier,
      );
      await _fitbitTokenStore.saveToken(token);

      final now = DateTime.now();
      final existingConnection = await _wearableRepository.loadConnection(
        WearableProvider.fitbit,
      );
      await _wearableRepository.upsertConnection(
        WearableConnection(
          provider: WearableProvider.fitbit,
          isConnected: true,
          accountLabel: existingConnection?.accountLabel,
          connectedAt: existingConnection?.connectedAt ?? now,
          lastSyncedAt: existingConnection?.lastSyncedAt,
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
        _isHandlingFitbitCallback = false;
        _fitbitSyncResult = 'Fitbit authorization completed';
      });
    } on FitbitOAuthException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isHandlingFitbitCallback = false;
        _fitbitSyncResult = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isHandlingFitbitCallback = false;
        _fitbitSyncResult = 'Fitbit token exchange failed';
      });
    }
  }
}

List<DateTime> _buildMissingFitbitBackfillDates({
  required List<DailyWearableMetric> existingMetrics,
  required DateTime startDate,
  required DateTime endDate,
}) {
  final metricTypesByDate = <String, Set<WearableMetricType>>{};
  for (final metric in existingMetrics) {
    final dateKey = _dateKey(metric.date);
    metricTypesByDate.putIfAbsent(dateKey, () => <WearableMetricType>{}).add(
      metric.metricType,
    );
  }

  final missingDates = <DateTime>[];
  var cursor = _dateOnly(startDate);
  final end = _dateOnly(endDate);
  while (!cursor.isAfter(end)) {
    final metricTypes = metricTypesByDate[_dateKey(cursor)] ?? const {};
    if (!(metricTypes.contains(WearableMetricType.sleepDurationMin) &&
        metricTypes.contains(WearableMetricType.restingHeartRateBpm))) {
      missingDates.add(cursor);
    }
    cursor = cursor.add(const Duration(days: 1));
  }

  return missingDates;
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
