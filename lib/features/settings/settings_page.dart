import 'package:flutter/material.dart';
import 'package:mood_tracker/features/daily_log/data/local_daily_log_repository.dart';
import 'package:mood_tracker/features/wearables/data/fitbit_api_client.dart';
import 'package:mood_tracker/features/wearables/data/fitbit_callback_debug_store.dart';
import 'package:mood_tracker/features/wearables/data/fitbit_oauth_client.dart';
import 'package:mood_tracker/features/wearables/data/fitbit_oauth_session_store.dart';
import 'package:mood_tracker/features/wearables/data/fitbit_oauth_token_store.dart';
import 'package:mood_tracker/features/wearables/data/fitbit_source_adapter.dart';
import 'package:mood_tracker/features/wearables/data/local_wearable_repository.dart';
import 'package:mood_tracker/features/wearables/models/daily_wearable_metric.dart';
import 'package:mood_tracker/features/wearables/models/fitbit_oauth_token.dart';
import 'package:mood_tracker/features/wearables/models/fitbit_oauth_preparation.dart';
import 'package:mood_tracker/features/wearables/models/wearable_connection.dart';
import 'package:mood_tracker/features/wearables/models/wearable_metric_type.dart';
import 'package:mood_tracker/features/wearables/models/wearable_provider.dart';
import 'package:mood_tracker/shared/date_utils.dart';
import 'package:mood_tracker/shared/format_utils.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const _backfillOptions = <int>[30, 90];

  final _dailyLogRepository = LocalDailyLogRepository();
  final _wearableRepository = LocalWearableRepository();
  final _fitbitOAuthClient = FitbitOAuthClient();
  final _fitbitTokenStore = FitbitOAuthTokenStore();
  WearableConnection? _fitbitConnection;
  bool _isSyncingFitbit = false;
  bool _isBackfillingFitbit = false;
  int _selectedFitbitBackfillDays = 90;
  int _fitbitBackfillProgress = 0;
  int _fitbitBackfillTarget = 90;
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
            'Manage your mood tracking preferences and Fitbit connection.',
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
                    _fitbitStatusLabel,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  if (_hasFitbitConnection) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Fitbit is connected',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ] else ...[
                    const SizedBox(height: 6),
                    Text(
                      'Connect Fitbit to import sleep and resting heart rate data.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    _fitbitConnection?.lastSyncedAt != null
                        ? 'Last synced: ${formatDateTimeLabel(_fitbitConnection!.lastSyncedAt!)}'
                        : 'Last synced: Never',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _isHandlingFitbitCallback || _isSyncingFitbit
                        ? null
                        : _handleFitbitPrimaryAction,
                    child: Text(
                      _isHandlingFitbitCallback
                          ? 'Connecting Fitbit...'
                          : _fitbitPrimaryActionLabel,
                    ),
                  ),
                  if (!_hasFitbitConnection) ...[
                    const SizedBox(height: 8),
                    Text(
                      'After tapping Connect Fitbit, we will open Fitbit in your browser to finish authorization.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 16),
                  SegmentedButton<int>(
                    segments: _backfillOptions
                        .map(
                          (days) => ButtonSegment<int>(
                            value: days,
                            label: Text('Last $days days'),
                          ),
                        )
                        .toList(),
                    selected: {_selectedFitbitBackfillDays},
                    onSelectionChanged: _isBackfillingFitbit
                        ? null
                        : (selection) {
                            setState(() {
                              _selectedFitbitBackfillDays = selection.first;
                              _fitbitBackfillTarget = _selectedFitbitBackfillDays;
                            });
                          },
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _isBackfillingFitbit ? null : _backfillFitbitData,
                    child: Text(
                      _isBackfillingFitbit
                          ? 'Backfilling Fitbit data...'
                          : 'Backfill last $_selectedFitbitBackfillDays days',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Import recent Fitbit history for the last $_selectedFitbitBackfillDays days.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (_isBackfillingFitbit) ...[
                    const SizedBox(height: 8),
                    Text(
                      '$_fitbitBackfillProgress / $_fitbitBackfillTarget',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 8),
                  TextButton(
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
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Danger Zone',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Reset local app data',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This will remove local daily logs, wearable data, saved Fitbit session, and connection state.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Fitbit account data on Fitbit will not be deleted.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: _resetLocalAppData,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                    child: const Text('Reset local app data'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _resetLocalAppData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reset local app data?'),
          content: const Text(
            'This removes local daily logs, wearable data, Fitbit session, and connection state on this device only.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }

    await _dailyLogRepository.clear();
    await _wearableRepository.clearDailyMetrics();
    await _wearableRepository.clearConnections();
    await _fitbitTokenStore.clear();
    if (!mounted) {
      return;
    }

    setState(() {
      _fitbitConnection = null;
      _isSyncingFitbit = false;
      _isBackfillingFitbit = false;
      _selectedFitbitBackfillDays = 90;
      _fitbitBackfillProgress = 0;
      _fitbitBackfillTarget = _selectedFitbitBackfillDays;
      _isHandlingFitbitCallback = false;
      _fitbitSyncResult = 'Local app data has been reset.';
    });
  }

  Future<void> _syncFitbitData({bool rethrowFailure = false}) async {
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

      final today = dateOnly(DateTime.now());
      final now = DateTime.now();
      final fitbitAdapter = FitbitSourceAdapter(
        fetchSnapshot:
            FitbitApiClient(accessToken: token.accessToken).fetchDailySnapshot,
      );
      final metrics = await fitbitAdapter.fetchDailyMetrics(today);
      await _wearableRepository.upsertDailyMetrics(metrics);
      final updatedConnection = await _updateFitbitConnection(
        (existingConnection) => WearableConnection(
          provider: WearableProvider.fitbit,
          isConnected: true,
          accountLabel: existingConnection?.accountLabel,
          connectedAt: existingConnection?.connectedAt ?? now,
          lastSyncedAt: now,
        ),
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _fitbitConnection = updatedConnection;
        _isSyncingFitbit = false;
        _fitbitSyncResult = 'Synced Fitbit data for ${formatShortDate(today)}';
      });
    } on FitbitApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSyncingFitbit = false;
        _fitbitSyncResult = error.message;
      });
      if (rethrowFailure) {
        rethrow;
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSyncingFitbit = false;
        _fitbitSyncResult = 'Fitbit sync failed';
      });
      if (rethrowFailure) {
        rethrow;
      }
    }
  }

  Future<void> _backfillFitbitData() async {
    setState(() {
      _isBackfillingFitbit = true;
      _fitbitBackfillProgress = 0;
      _fitbitBackfillTarget = _selectedFitbitBackfillDays;
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

      final today = dateOnly(DateTime.now());
      final startDate = today.subtract(
        Duration(days: _selectedFitbitBackfillDays - 1),
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
      final skippedDays = _selectedFitbitBackfillDays - missingDates.length;

      if (missingDates.isEmpty) {
        setState(() {
          _isBackfillingFitbit = false;
          _fitbitBackfillProgress = 0;
          _fitbitBackfillTarget = 0;
          _fitbitSyncResult = 'No new Fitbit data was needed. Skipped '
              '$skippedDays already imported days.';
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
      final updatedConnection = await _updateFitbitConnection(
        (existingConnection) => WearableConnection(
          provider: WearableProvider.fitbit,
          isConnected: true,
          accountLabel: existingConnection?.accountLabel,
          connectedAt: existingConnection?.connectedAt ?? now,
          lastSyncedAt: now,
        ),
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
            ? 'Imported $importedDays new days. Skipped $skippedDays already imported days.'
            : 'Imported $importedDays new days. Skipped $skippedDays already imported days. Some days could not be synced.';
      });
    } on FitbitApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isBackfillingFitbit = false;
        _fitbitBackfillProgress = importedDays;
        _fitbitBackfillTarget = _fitbitBackfillTarget == 0
            ? _selectedFitbitBackfillDays
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
            ? _selectedFitbitBackfillDays
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

  bool get _hasFitbitConnection => _fitbitConnection?.isConnected == true;

  Future<WearableConnection?> _updateFitbitConnection(
    WearableConnection Function(WearableConnection? existingConnection)
        buildConnection,
  ) async {
    final existingConnection = await _wearableRepository.loadConnection(
      WearableProvider.fitbit,
    );
    await _wearableRepository.upsertConnection(
      buildConnection(existingConnection),
    );
    return _wearableRepository.loadConnection(WearableProvider.fitbit);
  }

  bool get _isFitbitSyncedToday {
    final lastSyncedAt = _fitbitConnection?.lastSyncedAt;
    if (lastSyncedAt == null) {
      return false;
    }

    final now = DateTime.now();
    return lastSyncedAt.year == now.year &&
        lastSyncedAt.month == now.month &&
        lastSyncedAt.day == now.day;
  }

  String get _fitbitPrimaryActionLabel {
    if (!_hasFitbitConnection) {
      return 'Connect Fitbit';
    }

    return _isFitbitSyncedToday ? 'Sync again' : 'Sync Fitbit';
  }

  Future<void> _handleFitbitPrimaryAction() async {
    if (!_hasFitbitConnection) {
      final preparation = fitbitOAuthSessionStore.prepareAuthorization();
      await _openFitbitAuthorization(preparation);
      return;
    }

    await _syncFitbitData();
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

    final updatedConnection = await _updateFitbitConnection(
      (existingConnection) => WearableConnection(
        provider: WearableProvider.fitbit,
        isConnected: false,
        accountLabel: existingConnection?.accountLabel,
        connectedAt: existingConnection?.connectedAt,
        lastSyncedAt: null,
      ),
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

    final shouldDisconnect = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Disconnect Fitbit?'),
          content: const Text(
            'You can reconnect later from Settings. Your previously synced data will stay in the app.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Disconnect'),
            ),
          ],
        );
      },
    );
    if (shouldDisconnect != true) {
      return;
    }

    final updatedConnection = await _updateFitbitConnection(
      (_) => WearableConnection(
        provider: WearableProvider.fitbit,
        isConnected: false,
        accountLabel: existingConnection.accountLabel,
        connectedAt: existingConnection.connectedAt,
        lastSyncedAt: null,
      ),
    );
    if (!mounted) {
      return;
    }

    setState(() {
      _fitbitConnection = updatedConnection;
      _fitbitSyncResult = 'Fitbit has been disconnected from this app.';
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
      try {
        await _fitbitTokenStore.saveToken(token);
      } catch (error) {
        throw _FitbitCallbackStageException(
          'Fitbit callback failed while saving token.',
          error,
        );
      }

      final now = DateTime.now();
      final updatedConnection = await (() async {
        try {
          return await _updateFitbitConnection(
            (existingConnection) => WearableConnection(
              provider: WearableProvider.fitbit,
              isConnected: true,
              accountLabel: existingConnection?.accountLabel,
              connectedAt: existingConnection?.connectedAt ?? now,
              lastSyncedAt: existingConnection?.lastSyncedAt,
            ),
          );
        } catch (error) {
          throw _FitbitCallbackStageException(
            'Fitbit callback failed while updating local connection state.',
            error,
          );
        }
      })();
      if (!mounted) {
        return;
      }

      setState(() {
        _fitbitConnection = updatedConnection;
        _isHandlingFitbitCallback = false;
        _fitbitSyncResult = 'Fitbit authorization completed';
      });
      try {
        await _syncFitbitData(rethrowFailure: true);
      } catch (error) {
        throw _FitbitCallbackStageException(
          'Fitbit callback failed while syncing today\'s Fitbit data.',
          error,
        );
      }
    } on FitbitOAuthException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isHandlingFitbitCallback = false;
        _fitbitSyncResult = error.message;
      });
    } on _FitbitCallbackStageException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isHandlingFitbitCallback = false;
        _fitbitSyncResult = error.toUserMessage();
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isHandlingFitbitCallback = false;
        _fitbitSyncResult = _formatUnexpectedFitbitCallbackFailure(error);
      });
    }
  }
}

String _formatUnexpectedFitbitCallbackFailure(Object error) {
  final message = switch (error) {
    final Exception exception => exception.toString(),
    _ => error.toString(),
  };
  final sanitizedMessage = message.trim();
  if (sanitizedMessage.isEmpty || sanitizedMessage == error.runtimeType.toString()) {
    return 'Unexpected Fitbit callback failure: ${error.runtimeType}';
  }

  return 'Unexpected Fitbit callback failure: ${error.runtimeType} ($sanitizedMessage)';
}

class _FitbitCallbackStageException implements Exception {
  const _FitbitCallbackStageException(this.prefix, this.cause);

  final String prefix;
  final Object cause;

  String toUserMessage() {
    if (cause is FitbitOAuthException) {
      return (cause as FitbitOAuthException).message;
    }

    final unexpectedMessage = _formatUnexpectedFitbitCallbackFailure(cause);
    return '$prefix $unexpectedMessage';
  }
}

List<DateTime> _buildMissingFitbitBackfillDates({
  required List<DailyWearableMetric> existingMetrics,
  required DateTime startDate,
  required DateTime endDate,
}) {
  final metricTypesByDate = <String, Set<WearableMetricType>>{};
  for (final metric in existingMetrics) {
    final dayKey = dateKey(metric.date);
    metricTypesByDate.putIfAbsent(dayKey, () => <WearableMetricType>{}).add(
      metric.metricType,
    );
  }

  final missingDates = <DateTime>[];
  var cursor = dateOnly(startDate);
  final end = dateOnly(endDate);
  while (!cursor.isAfter(end)) {
    final metricTypes = metricTypesByDate[dateKey(cursor)] ?? const {};
    if (!(metricTypes.contains(WearableMetricType.sleepDurationMin) &&
        metricTypes.contains(WearableMetricType.restingHeartRateBpm))) {
      missingDates.add(cursor);
    }
    cursor = cursor.add(const Duration(days: 1));
  }

  return missingDates;
}
