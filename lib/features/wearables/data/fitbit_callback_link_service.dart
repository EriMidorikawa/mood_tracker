import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:mood_tracker/features/wearables/data/fitbit_callback_debug_store.dart';

class FitbitCallbackLinkService {
  FitbitCallbackLinkService({AppLinks? appLinks})
      : _appLinks = appLinks ?? AppLinks();

  final AppLinks _appLinks;
  StreamSubscription<Uri>? _subscription;

  Future<void> start() async {
    final initialUri = await _appLinks.getInitialLink();
    if (initialUri != null) {
      _handleUri(initialUri);
    }

    _subscription ??= _appLinks.uriLinkStream.listen(_handleUri);
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  void _handleUri(Uri uri) {
    if (uri.scheme != 'moodtracker' || uri.host != 'fitbit-callback') {
      return;
    }

    fitbitCallbackDebugStore.updateFromUri(uri);
  }
}
