import 'package:flutter/foundation.dart';
import 'package:mood_tracker/features/wearables/models/fitbit_callback_debug.dart';

class FitbitCallbackDebugStore {
  final ValueNotifier<FitbitCallbackDebug?> lastCallback = ValueNotifier(null);

  void updateFromUri(Uri uri) {
    lastCallback.value = FitbitCallbackDebug(
      uri: uri,
      code: uri.queryParameters['code'],
      state: uri.queryParameters['state'],
    );
  }
}

final fitbitCallbackDebugStore = FitbitCallbackDebugStore();
