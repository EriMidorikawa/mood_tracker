import 'package:mood_tracker/features/daily_log/data/local_daily_log_repository.dart';
import 'package:mood_tracker/features/wearables/data/fitbit_oauth_token_store.dart';
import 'package:mood_tracker/features/wearables/data/local_wearable_repository.dart';

class LocalAppResetService {
  LocalAppResetService({
    LocalDailyLogRepository? dailyLogRepository,
    LocalWearableRepository? wearableRepository,
    FitbitOAuthTokenStore? fitbitTokenStore,
  })  : _dailyLogRepository = dailyLogRepository ?? LocalDailyLogRepository(),
        _wearableRepository = wearableRepository ?? LocalWearableRepository(),
        _fitbitTokenStore = fitbitTokenStore ?? FitbitOAuthTokenStore();

  final LocalDailyLogRepository _dailyLogRepository;
  final LocalWearableRepository _wearableRepository;
  final FitbitOAuthTokenStore _fitbitTokenStore;

  Future<void> resetLocalAppData() async {
    await _dailyLogRepository.clear();
    await _wearableRepository.clearDailyMetrics();
    await _wearableRepository.clearConnections();
    await _fitbitTokenStore.clear();
  }
}
