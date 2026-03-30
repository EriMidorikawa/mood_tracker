import 'package:mood_tracker/features/wearables/data/fitbit_api_client.dart';
import 'package:mood_tracker/features/wearables/data/fitbit_oauth_token_store.dart';
import 'package:mood_tracker/features/wearables/data/fitbit_source_adapter.dart';
import 'package:mood_tracker/features/wearables/data/local_wearable_repository.dart';
import 'package:mood_tracker/features/wearables/models/daily_wearable_metric.dart';
import 'package:mood_tracker/features/wearables/models/fitbit_oauth_token.dart';
import 'package:mood_tracker/features/wearables/models/wearable_connection.dart';
import 'package:mood_tracker/features/wearables/models/wearable_metric_type.dart';
import 'package:mood_tracker/features/wearables/models/wearable_provider.dart';
import 'package:mood_tracker/shared/date_utils.dart';

class FitbitSyncService {
  FitbitSyncService({
    LocalWearableRepository? wearableRepository,
    FitbitOAuthTokenStore? tokenStore,
  })  : _wearableRepository = wearableRepository ?? LocalWearableRepository(),
        _tokenStore = tokenStore ?? FitbitOAuthTokenStore();

  final LocalWearableRepository _wearableRepository;
  final FitbitOAuthTokenStore _tokenStore;

  Future<WearableConnection?> loadConnection() {
    return _wearableRepository.loadConnection(WearableProvider.fitbit);
  }

  Future<FitbitOAuthToken> requireValidToken({
    required String missingMessage,
    required String expiredMessage,
  }) async {
    final token = await _tokenStore.loadToken();
    if (token == null) {
      throw FitbitApiException(missingMessage);
    }

    if (!token.isExpired) {
      return token;
    }

    await _updateFitbitConnection(
      (existingConnection) => WearableConnection(
        provider: WearableProvider.fitbit,
        isConnected: false,
        accountLabel: existingConnection?.accountLabel,
        connectedAt: existingConnection?.connectedAt,
        lastSyncedAt: null,
      ),
    );
    throw FitbitApiException(expiredMessage);
  }

  Future<FitbitDaySyncResult> syncDay({
    required DateTime date,
    required String missingMessage,
    required String expiredMessage,
  }) async {
    final token = await requireValidToken(
      missingMessage: missingMessage,
      expiredMessage: expiredMessage,
    );
    final day = dateOnly(date);
    final now = DateTime.now();
    final metrics = await _fetchDailyMetrics(
      accessToken: token.accessToken,
      date: day,
    );
    await _wearableRepository.upsertDailyMetrics(metrics);
    final connection = await _updateFitbitConnection(
      (existingConnection) => WearableConnection(
        provider: WearableProvider.fitbit,
        isConnected: true,
        accountLabel: existingConnection?.accountLabel,
        connectedAt: existingConnection?.connectedAt ?? now,
        lastSyncedAt: now,
      ),
    );

    return FitbitDaySyncResult(
      syncedDate: day,
      connection: connection,
    );
  }

  Future<FitbitDaySyncResult?> autoSyncTodayIfNeeded(
    WearableConnection? connection,
  ) async {
    if (connection?.isConnected != true) {
      return null;
    }

    final today = dateOnly(DateTime.now());
    if (dateOnly(connection!.lastSyncedAt ?? DateTime(2000)) == today) {
      return null;
    }

    final token = await _tokenStore.loadToken();
    if (token == null || token.isExpired) {
      return null;
    }

    final metrics = await _fetchDailyMetrics(
      accessToken: token.accessToken,
      date: today,
    );
    await _wearableRepository.upsertDailyMetrics(metrics);
    final now = DateTime.now();
    final updatedConnection = await _updateFitbitConnection(
      (existingConnection) => WearableConnection(
        provider: WearableProvider.fitbit,
        isConnected: true,
        accountLabel: existingConnection?.accountLabel ?? connection.accountLabel,
        connectedAt: existingConnection?.connectedAt ?? connection.connectedAt ?? now,
        lastSyncedAt: now,
      ),
    );

    return FitbitDaySyncResult(
      syncedDate: today,
      connection: updatedConnection,
    );
  }

  Future<FitbitBackfillResult> backfillRecentDays({
    required int days,
    required String missingMessage,
    required String expiredMessage,
    void Function(int completed, int target)? onProgress,
  }) async {
    final token = await requireValidToken(
      missingMessage: missingMessage,
      expiredMessage: expiredMessage,
    );

    final today = dateOnly(DateTime.now());
    final startDate = today.subtract(Duration(days: days - 1));
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
    final skippedDays = days - missingDates.length;

    if (missingDates.isEmpty) {
      return FitbitBackfillResult(
        connection: await loadConnection(),
        importedDays: 0,
        failedDays: 0,
        skippedDays: skippedDays,
        targetDays: 0,
        stopReason: null,
      );
    }

    var importedDays = 0;
    var failedDays = 0;
    FitbitBackfillStopReason? stopReason;
    for (final date in missingDates) {
      try {
        final metrics = await _fetchDailyMetrics(
          accessToken: token.accessToken,
          date: date,
        );
        await _wearableRepository.upsertDailyMetrics(metrics);
        importedDays += 1;
      } on FitbitApiException catch (error) {
        failedDays += 1;
        stopReason = _classifyBackfillStopReason(error);
        onProgress?.call(importedDays + failedDays, missingDates.length);
        if (stopReason != null) {
          break;
        }
        continue;
      } catch (_) {
        failedDays += 1;
      }

      onProgress?.call(importedDays + failedDays, missingDates.length);
    }

    final connection = importedDays > 0
        ? await _updateBackfillConnection()
        : await loadConnection();

    return FitbitBackfillResult(
      connection: connection,
      importedDays: importedDays,
      failedDays: failedDays,
      skippedDays: skippedDays,
      targetDays: missingDates.length,
      stopReason: stopReason,
    );
  }

  Future<WearableConnection?> disconnect() async {
    final existingConnection = await loadConnection();
    if (existingConnection == null) {
      return null;
    }

    return _updateFitbitConnection(
      (_) => WearableConnection(
        provider: WearableProvider.fitbit,
        isConnected: false,
        accountLabel: existingConnection.accountLabel,
        connectedAt: existingConnection.connectedAt,
        lastSyncedAt: null,
      ),
    );
  }

  Future<List<DailyWearableMetric>> _fetchDailyMetrics({
    required String accessToken,
    required DateTime date,
  }) {
    final fitbitAdapter = FitbitSourceAdapter(
      fetchSnapshot:
          FitbitApiClient(accessToken: accessToken).fetchDailySnapshot,
    );
    return fitbitAdapter.fetchDailyMetrics(date);
  }

  Future<WearableConnection?> _updateFitbitConnection(
    WearableConnection Function(WearableConnection? existingConnection)
        buildConnection,
  ) async {
    final existingConnection = await loadConnection();
    await _wearableRepository.upsertConnection(
      buildConnection(existingConnection),
    );
    return loadConnection();
  }

  Future<WearableConnection?> _updateBackfillConnection() {
    final now = DateTime.now();
    return _updateFitbitConnection(
      (existingConnection) => WearableConnection(
        provider: WearableProvider.fitbit,
        isConnected: true,
        accountLabel: existingConnection?.accountLabel,
        connectedAt: existingConnection?.connectedAt ?? now,
        lastSyncedAt: now,
      ),
    );
  }
}

class FitbitDaySyncResult {
  const FitbitDaySyncResult({
    required this.syncedDate,
    required this.connection,
  });

  final DateTime syncedDate;
  final WearableConnection? connection;
}

class FitbitBackfillResult {
  const FitbitBackfillResult({
    required this.connection,
    required this.importedDays,
    required this.failedDays,
    required this.skippedDays,
    required this.targetDays,
    required this.stopReason,
  });

  final WearableConnection? connection;
  final int importedDays;
  final int failedDays;
  final int skippedDays;
  final int targetDays;
  final FitbitBackfillStopReason? stopReason;
}

enum FitbitBackfillStopReason {
  authorizationRequired,
  rateLimited,
}

FitbitBackfillStopReason? _classifyBackfillStopReason(
  FitbitApiException error,
) {
  if (error.message.contains('(429)')) {
    return FitbitBackfillStopReason.rateLimited;
  }

  if (error.message.contains('(401)')) {
    return FitbitBackfillStopReason.authorizationRequired;
  }

  return null;
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
