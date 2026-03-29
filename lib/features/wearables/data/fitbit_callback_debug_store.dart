import 'package:flutter/foundation.dart';
import 'package:mood_tracker/features/wearables/models/fitbit_callback_debug.dart';
import 'package:mood_tracker/features/wearables/data/fitbit_oauth_session_store.dart';

class FitbitCallbackDebugStore {
  final ValueNotifier<FitbitCallbackDebug?> lastCallback = ValueNotifier(null);

  void updateFromUri(Uri uri) {
    final state = uri.queryParameters['state'];
    lastCallback.value = FitbitCallbackDebug(
      uri: uri,
      code: uri.queryParameters['code'],
      state: state,
      stateMatched: fitbitOAuthSessionStore.matchesCallbackState(state),
    );
  }
}

final fitbitCallbackDebugStore = FitbitCallbackDebugStore();
