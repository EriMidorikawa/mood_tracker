import 'package:flutter/foundation.dart';
import 'package:mood_tracker/features/wearables/data/fitbit_api_client.dart';
import 'package:mood_tracker/features/wearables/data/fitbit_callback_service.dart';
import 'package:mood_tracker/features/wearables/data/fitbit_oauth_client.dart';
import 'package:mood_tracker/features/wearables/data/fitbit_sync_service.dart';
import 'package:mood_tracker/features/wearables/models/fitbit_callback_debug.dart';
import 'package:mood_tracker/features/wearables/models/fitbit_oauth_preparation.dart';
import 'package:mood_tracker/features/wearables/models/wearable_connection.dart';
import 'package:mood_tracker/shared/format_utils.dart';

class FitbitSettingsController extends ChangeNotifier {
  FitbitSettingsController({
    FitbitSyncService? fitbitSyncService,
    FitbitCallbackService? fitbitCallbackService,
  })  : _fitbitSyncService = fitbitSyncService ?? FitbitSyncService(),
        _fitbitCallbackService =
            fitbitCallbackService ?? FitbitCallbackService();

  final FitbitSyncService _fitbitSyncService;
  final FitbitCallbackService _fitbitCallbackService;

  WearableConnection? _connection;
  FitbitSettingsState _state = const FitbitSettingsState();

  WearableConnection? get connection => _connection;
  FitbitSettingsState get state => _state;

  String get statusLabel {
    if (_connection?.isConnected != true) {
      return 'Not connected';
    }

    return 'Connected';
  }

  bool get hasConnection => _connection?.isConnected == true;

  bool get isSyncedToday {
    final lastSyncedAt = _connection?.lastSyncedAt;
    if (lastSyncedAt == null) {
      return false;
    }

    final now = DateTime.now();
    return lastSyncedAt.year == now.year &&
        lastSyncedAt.month == now.month &&
        lastSyncedAt.day == now.day;
  }

  String get primaryActionLabel {
    if (!hasConnection) {
      return 'Connect Fitbit';
    }

    return isSyncedToday ? 'Sync again' : 'Sync Fitbit';
  }

  Future<void> loadConnection() async {
    _connection = await _fitbitSyncService.loadConnection();
    notifyListeners();
  }

  FitbitCallbackContext? prepareCallbackContext({
    required FitbitCallbackDebug? callback,
    required FitbitOAuthPreparation? preparation,
    required String? lastHandledCallbackUri,
  }) {
    return _fitbitCallbackService.prepareCallbackContext(
      callback: callback,
      preparation: preparation,
      lastHandledCallbackUri: lastHandledCallbackUri,
      isHandlingCallback: _state.isHandlingCallback,
    );
  }

  void selectBackfillDays(int days) {
    _state = _state.copyWith(
      selectedBackfillDays: days,
      backfillTarget: days,
    );
    notifyListeners();
  }

  void showAuthorizationLaunchFailure() {
    _state = _state.copyWith(
      syncResult: 'Could not open Fitbit authorization URL',
    );
    notifyListeners();
  }

  void applyResetLocalAppDataState() {
    _connection = null;
    _state = const FitbitSettingsState(
      selectedBackfillDays: 90,
      backfillTarget: 90,
      syncResult: 'Local app data has been reset.',
    );
    notifyListeners();
  }

  Future<void> syncToday({bool rethrowFailure = false}) async {
    _state = _state.copyWith(
      isSyncing: true,
      clearSyncResult: true,
    );
    notifyListeners();

    try {
      final result = await _fitbitSyncService.syncDay(
        date: DateTime.now(),
        expiredMessage: 'Fitbit session expired. Please authorize again.',
        missingMessage: 'Fitbit authorization required',
      );
      _connection = result.connection;
      _state = _state.copyWith(
        isSyncing: false,
        syncResult: 'Synced Fitbit data for ${formatShortDate(result.syncedDate)}',
      );
      notifyListeners();
    } on FitbitApiException catch (error) {
      _state = _state.copyWith(
        isSyncing: false,
        syncResult: error.message,
      );
      notifyListeners();
      if (rethrowFailure) {
        rethrow;
      }
    } catch (_) {
      _state = _state.copyWith(
        isSyncing: false,
        syncResult: 'Fitbit sync failed',
      );
      notifyListeners();
      if (rethrowFailure) {
        rethrow;
      }
    }
  }

  Future<void> backfill() async {
    _state = _state.copyWith(
      isBackfilling: true,
      backfillProgress: 0,
      backfillTarget: _state.selectedBackfillDays,
      syncResult: 'Backfilling Fitbit data...',
    );
    notifyListeners();

    var importedDays = 0;
    try {
      final result = await _fitbitSyncService.backfillRecentDays(
        days: _state.selectedBackfillDays,
        expiredMessage: 'Fitbit session expired. Please authorize again.',
        missingMessage: 'Fitbit authorization required',
        onProgress: (completed, target) {
          _state = _state.copyWith(
            backfillProgress: completed,
            backfillTarget: target,
          );
          notifyListeners();
        },
      );
      importedDays = result.importedDays;
      if (result.targetDays == 0) {
        _state = _state.copyWith(
          isBackfilling: false,
          backfillProgress: 0,
          backfillTarget: 0,
          syncResult:
              'No new Fitbit data was needed. Skipped ${result.skippedDays} already imported days.',
        );
        notifyListeners();
        return;
      }

      _connection = result.connection;
      _state = _state.copyWith(
        isBackfilling: false,
        backfillProgress: result.importedDays + result.failedDays,
        backfillTarget: result.targetDays,
        syncResult: result.failedDays == 0
            ? 'Imported ${result.importedDays} new days. Skipped ${result.skippedDays} already imported days.'
            : 'Imported ${result.importedDays} new days. Skipped ${result.skippedDays} already imported days. Some days could not be synced.',
      );
      notifyListeners();
    } on FitbitApiException catch (error) {
      final target = _state.backfillTarget == 0
          ? _state.selectedBackfillDays
          : _state.backfillTarget;
      _state = _state.copyWith(
        isBackfilling: false,
        backfillProgress: importedDays,
        backfillTarget: target,
        syncResult: importedDays == 0
            ? error.message
            : 'Imported $importedDays of $target days. Some days could not be synced.',
      );
      notifyListeners();
    } catch (_) {
      final target = _state.backfillTarget == 0
          ? _state.selectedBackfillDays
          : _state.backfillTarget;
      _state = _state.copyWith(
        isBackfilling: false,
        backfillProgress: importedDays,
        backfillTarget: target,
        syncResult: 'No Fitbit data was imported. Some days could not be synced.',
      );
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    _connection = await _fitbitSyncService.disconnect();
    _state = _state.copyWith(
      syncResult: 'Fitbit has been disconnected from this app.',
    );
    notifyListeners();
  }

  Future<void> completeCallback(FitbitCallbackContext context) async {
    _state = _state.copyWith(
      isHandlingCallback: true,
      syncResult: 'Completing Fitbit authorization...',
    );
    notifyListeners();

    try {
      await _fitbitCallbackService.exchangeCodeAndSaveToken(context);
      _connection = await _fitbitCallbackService.markConnectionAsConnected();
      _state = _state.copyWith(
        isHandlingCallback: false,
        syncResult: 'Fitbit authorization completed',
      );
      notifyListeners();
      await _syncTodayAfterCallback();
    } on FitbitOAuthException catch (error) {
      _state = _state.copyWith(
        isHandlingCallback: false,
        syncResult: error.message,
      );
      notifyListeners();
    } on FitbitCallbackStageException catch (error) {
      _state = _state.copyWith(
        isHandlingCallback: false,
        syncResult: error.toUserMessage(),
      );
      notifyListeners();
    } catch (error) {
      _state = _state.copyWith(
        isHandlingCallback: false,
        syncResult: formatUnexpectedFitbitCallbackFailure(error),
      );
      notifyListeners();
    }
  }

  Future<void> _syncTodayAfterCallback() async {
    try {
      await syncToday(rethrowFailure: true);
    } catch (error) {
      throw FitbitCallbackStageException(
        'Fitbit callback failed while syncing today\'s Fitbit data.',
        error,
      );
    }
  }
}

class FitbitSettingsState {
  const FitbitSettingsState({
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

  FitbitSettingsState copyWith({
    bool? isSyncing,
    bool? isBackfilling,
    int? selectedBackfillDays,
    int? backfillProgress,
    int? backfillTarget,
    bool? isHandlingCallback,
    String? syncResult,
    bool clearSyncResult = false,
  }) {
    return FitbitSettingsState(
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
