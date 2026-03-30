import 'package:flutter/material.dart';
import 'package:mood_tracker/features/daily_log/data/local_daily_log_repository.dart';
import 'package:mood_tracker/features/wearables/data/fitbit_api_client.dart';
import 'package:mood_tracker/features/wearables/data/fitbit_callback_debug_store.dart';
import 'package:mood_tracker/features/wearables/data/fitbit_oauth_client.dart';
import 'package:mood_tracker/features/wearables/data/fitbit_oauth_session_store.dart';
import 'package:mood_tracker/features/wearables/data/fitbit_oauth_token_store.dart';
import 'package:mood_tracker/features/wearables/data/fitbit_sync_service.dart';
import 'package:mood_tracker/features/wearables/data/local_wearable_repository.dart';
import 'package:mood_tracker/features/wearables/models/fitbit_callback_debug.dart';
import 'package:mood_tracker/features/wearables/models/fitbit_oauth_preparation.dart';
import 'package:mood_tracker/features/wearables/models/wearable_connection.dart';
import 'package:mood_tracker/features/wearables/models/wearable_provider.dart';
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
  final _fitbitSyncService = FitbitSyncService();
  WearableConnection? _fitbitConnection;
  _FitbitSettingsState _fitbitState = const _FitbitSettingsState();
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
                    onPressed: _fitbitState.isHandlingCallback ||
                            _fitbitState.isSyncing
                        ? null
                        : _handleFitbitPrimaryAction,
                    child: Text(
                      _fitbitState.isHandlingCallback
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
                    selected: {_fitbitState.selectedBackfillDays},
                    onSelectionChanged: _fitbitState.isBackfilling
                        ? null
                        : (selection) {
                            setState(() {
                              _fitbitState = _fitbitState.copyWith(
                                selectedBackfillDays: selection.first,
                                backfillTarget: selection.first,
                              );
                            });
                          },
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed:
                        _fitbitState.isBackfilling ? null : _backfillFitbitData,
                    child: Text(
                      _fitbitState.isBackfilling
                          ? 'Backfilling Fitbit data...'
                          : 'Backfill last ${_fitbitState.selectedBackfillDays} days',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Import recent Fitbit history for the last ${_fitbitState.selectedBackfillDays} days.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (_fitbitState.isBackfilling) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${_fitbitState.backfillProgress} / ${_fitbitState.backfillTarget}',
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
                  if (_fitbitState.syncResult != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _fitbitState.syncResult!,
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
      _fitbitState = const _FitbitSettingsState(
        selectedBackfillDays: 90,
        backfillTarget: 90,
        syncResult: 'Local app data has been reset.',
      );
    });
  }

  Future<void> _syncFitbitData({bool rethrowFailure = false}) async {
    setState(() {
      _fitbitState = _fitbitState.copyWith(
        isSyncing: true,
        clearSyncResult: true,
      );
    });

    try {
      final result = await _fitbitSyncService.syncDay(
        date: DateTime.now(),
        expiredMessage: 'Fitbit session expired. Please authorize again.',
        missingMessage: 'Fitbit authorization required',
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _fitbitConnection = result.connection;
        _fitbitState = _fitbitState.copyWith(
          isSyncing: false,
          syncResult: 'Synced Fitbit data for ${formatShortDate(result.syncedDate)}',
        );
      });
    } on FitbitApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _fitbitState = _fitbitState.copyWith(
          isSyncing: false,
          syncResult: error.message,
        );
      });
      if (rethrowFailure) {
        rethrow;
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _fitbitState = _fitbitState.copyWith(
          isSyncing: false,
          syncResult: 'Fitbit sync failed',
        );
      });
      if (rethrowFailure) {
        rethrow;
      }
    }
  }

  Future<void> _backfillFitbitData() async {
    setState(() {
      _fitbitState = _fitbitState.copyWith(
        isBackfilling: true,
        backfillProgress: 0,
        backfillTarget: _fitbitState.selectedBackfillDays,
        syncResult: 'Backfilling Fitbit data...',
      );
    });

    var importedDays = 0;
    try {
      final result = await _fitbitSyncService.backfillRecentDays(
        days: _fitbitState.selectedBackfillDays,
        expiredMessage: 'Fitbit session expired. Please authorize again.',
        missingMessage: 'Fitbit authorization required',
        onProgress: (completed, target) {
          if (!mounted) {
            return;
          }

          setState(() {
            _fitbitState = _fitbitState.copyWith(
              backfillProgress: completed,
              backfillTarget: target,
            );
          });
        },
      );
      importedDays = result.importedDays;
      if (result.targetDays == 0) {
        setState(() {
          _fitbitState = _fitbitState.copyWith(
            isBackfilling: false,
            backfillProgress: 0,
            backfillTarget: 0,
            syncResult:
                'No new Fitbit data was needed. Skipped ${result.skippedDays} already imported days.',
          );
        });
        return;
      }
      if (!mounted) {
        return;
      }

      setState(() {
        _fitbitConnection = result.connection;
        _fitbitState = _fitbitState.copyWith(
          isBackfilling: false,
          backfillProgress: result.importedDays + result.failedDays,
          backfillTarget: result.targetDays,
          syncResult: result.failedDays == 0
              ? 'Imported ${result.importedDays} new days. Skipped ${result.skippedDays} already imported days.'
              : 'Imported ${result.importedDays} new days. Skipped ${result.skippedDays} already imported days. Some days could not be synced.',
        );
      });
    } on FitbitApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        final target = _fitbitState.backfillTarget == 0
            ? _fitbitState.selectedBackfillDays
            : _fitbitState.backfillTarget;
        _fitbitState = _fitbitState.copyWith(
          isBackfilling: false,
          backfillProgress: importedDays,
          backfillTarget: target,
          syncResult: importedDays == 0
              ? error.message
              : 'Imported $importedDays of $target days. Some days could not be synced.',
        );
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        final target = _fitbitState.backfillTarget == 0
            ? _fitbitState.selectedBackfillDays
            : _fitbitState.backfillTarget;
        _fitbitState = _fitbitState.copyWith(
          isBackfilling: false,
          backfillProgress: importedDays,
          backfillTarget: target,
          syncResult: 'No Fitbit data was imported. Some days could not be synced.',
        );
      });
    }
  }

  Future<void> _loadFitbitConnection() async {
    final connection = await _fitbitSyncService.loadConnection();
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

    final updatedConnection = await _fitbitSyncService.disconnect();
    if (!mounted) {
      return;
    }

      setState(() {
        _fitbitConnection = updatedConnection;
        _fitbitState = _fitbitState.copyWith(
          syncResult: 'Fitbit has been disconnected from this app.',
        );
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
      _fitbitState = _fitbitState.copyWith(
        syncResult: 'Could not open Fitbit authorization URL',
      );
    });
  }

  Future<void> _handleFitbitCallback() async {
    final preparedCallback = _prepareFitbitCallbackHandling();
    if (preparedCallback == null) {
      return;
    }

    _lastHandledCallbackUri = preparedCallback.callback.uri.toString();
    setState(() {
      _fitbitState = _fitbitState.copyWith(
        isHandlingCallback: true,
        syncResult: 'Completing Fitbit authorization...',
      );
    });

    try {
      await _exchangeFitbitCodeAndSaveToken(
        callback: preparedCallback.callback,
        preparation: preparedCallback.preparation,
      );
      final updatedConnection = await _markFitbitConnectionAsConnected();
      if (!mounted) {
        return;
      }

      setState(() {
        _fitbitConnection = updatedConnection;
        _fitbitState = _fitbitState.copyWith(
          isHandlingCallback: false,
          syncResult: 'Fitbit authorization completed',
        );
      });
      await _syncFitbitDataAfterCallback();
    } on FitbitOAuthException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _fitbitState = _fitbitState.copyWith(
          isHandlingCallback: false,
          syncResult: error.message,
        );
      });
    } on _FitbitCallbackStageException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _fitbitState = _fitbitState.copyWith(
          isHandlingCallback: false,
          syncResult: error.toUserMessage(),
        );
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _fitbitState = _fitbitState.copyWith(
          isHandlingCallback: false,
          syncResult: _formatUnexpectedFitbitCallbackFailure(error),
        );
      });
    }
  }

  _PreparedFitbitCallback? _prepareFitbitCallbackHandling() {
    final callback = fitbitCallbackDebugStore.lastCallback.value;
    if (!_shouldHandleFitbitCallback(callback)) {
      return null;
    }

    final preparation = fitbitOAuthSessionStore.preparedSession.value;
    if (preparation == null) {
      return null;
    }

    return _PreparedFitbitCallback(
      callback: callback!,
      preparation: preparation,
    );
  }

  bool _shouldHandleFitbitCallback(FitbitCallbackDebug? callback) {
    return callback != null &&
        callback.code != null &&
        callback.stateMatched == true &&
        callback.uri.toString() != _lastHandledCallbackUri &&
        !_fitbitState.isHandlingCallback;
  }

  Future<void> _exchangeFitbitCodeAndSaveToken({
    required FitbitCallbackDebug callback,
    required FitbitOAuthPreparation preparation,
  }) async {
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
  }

  Future<WearableConnection?> _markFitbitConnectionAsConnected() async {
    final now = DateTime.now();
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
  }

  Future<void> _syncFitbitDataAfterCallback() async {
    try {
      await _syncFitbitData(rethrowFailure: true);
    } catch (error) {
      throw _FitbitCallbackStageException(
        'Fitbit callback failed while syncing today\'s Fitbit data.',
        error,
      );
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

class _PreparedFitbitCallback {
  const _PreparedFitbitCallback({
    required this.callback,
    required this.preparation,
  });

  final FitbitCallbackDebug callback;
  final FitbitOAuthPreparation preparation;
}

class _FitbitSettingsState {
  const _FitbitSettingsState({
    this.isSyncing = false,
    this.isBackfilling = false,
    this.selectedBackfillDays = 90,
    this.backfillProgress = 0,
    this.backfillTarget = 90,
    this.isHandlingCallback = false,
    this.syncResult,
  });

  final bool isSyncing;
  final bool isBackfilling;
  final int selectedBackfillDays;
  final int backfillProgress;
  final int backfillTarget;
  final bool isHandlingCallback;
  final String? syncResult;

  _FitbitSettingsState copyWith({
    bool? isSyncing,
    bool? isBackfilling,
    int? selectedBackfillDays,
    int? backfillProgress,
    int? backfillTarget,
    bool? isHandlingCallback,
    String? syncResult,
    bool clearSyncResult = false,
  }) {
    return _FitbitSettingsState(
      isSyncing: isSyncing ?? this.isSyncing,
      isBackfilling: isBackfilling ?? this.isBackfilling,
      selectedBackfillDays:
          selectedBackfillDays ?? this.selectedBackfillDays,
      backfillProgress: backfillProgress ?? this.backfillProgress,
      backfillTarget: backfillTarget ?? this.backfillTarget,
      isHandlingCallback: isHandlingCallback ?? this.isHandlingCallback,
      syncResult: clearSyncResult ? null : (syncResult ?? this.syncResult),
    );
  }
}
