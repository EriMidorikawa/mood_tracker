import 'package:mood_tracker/features/wearables/data/fitbit_oauth_client.dart';
import 'package:mood_tracker/features/wearables/data/fitbit_oauth_token_store.dart';
import 'package:mood_tracker/features/wearables/data/local_wearable_repository.dart';
import 'package:mood_tracker/features/wearables/models/fitbit_callback_debug.dart';
import 'package:mood_tracker/features/wearables/models/fitbit_oauth_preparation.dart';
import 'package:mood_tracker/features/wearables/models/wearable_connection.dart';
import 'package:mood_tracker/features/wearables/models/wearable_provider.dart';

class FitbitCallbackService {
  FitbitCallbackService({
    FitbitOAuthClient? oauthClient,
    FitbitOAuthTokenStore? tokenStore,
    LocalWearableRepository? wearableRepository,
  })  : _oauthClient = oauthClient ?? FitbitOAuthClient(),
        _tokenStore = tokenStore ?? FitbitOAuthTokenStore(),
        _wearableRepository = wearableRepository ?? LocalWearableRepository();

  final FitbitOAuthClient _oauthClient;
  final FitbitOAuthTokenStore _tokenStore;
  final LocalWearableRepository _wearableRepository;

  FitbitCallbackContext? prepareCallbackContext({
    required FitbitCallbackDebug? callback,
    required FitbitOAuthPreparation? preparation,
    required String? lastHandledCallbackUri,
    required bool isHandlingCallback,
  }) {
    if (!_shouldHandleCallback(
      callback: callback,
      lastHandledCallbackUri: lastHandledCallbackUri,
      isHandlingCallback: isHandlingCallback,
    )) {
      return null;
    }

    if (preparation == null) {
      return null;
    }

    return FitbitCallbackContext(
      callback: callback!,
      preparation: preparation,
    );
  }

  Future<void> exchangeCodeAndSaveToken(FitbitCallbackContext context) async {
    final token = await _oauthClient.exchangeAuthorizationCode(
      code: context.callback.code!,
      codeVerifier: context.preparation.codeVerifier,
    );

    try {
      await _tokenStore.saveToken(token);
    } catch (error) {
      throw FitbitCallbackStageException(
        'Fitbit callback failed while saving token.',
        error,
      );
    }
  }

  Future<WearableConnection?> markConnectionAsConnected() async {
    final now = DateTime.now();
    try {
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
      return _wearableRepository.loadConnection(WearableProvider.fitbit);
    } catch (error) {
      throw FitbitCallbackStageException(
        'Fitbit callback failed while updating local connection state.',
        error,
      );
    }
  }

  bool _shouldHandleCallback({
    required FitbitCallbackDebug? callback,
    required String? lastHandledCallbackUri,
    required bool isHandlingCallback,
  }) {
    return callback != null &&
        callback.code != null &&
        callback.stateMatched == true &&
        callback.uri.toString() != lastHandledCallbackUri &&
        !isHandlingCallback;
  }
}

class FitbitCallbackContext {
  const FitbitCallbackContext({
    required this.callback,
    required this.preparation,
  });

  final FitbitCallbackDebug callback;
  final FitbitOAuthPreparation preparation;
}

class FitbitCallbackStageException implements Exception {
  const FitbitCallbackStageException(this.prefix, this.cause);

  final String prefix;
  final Object cause;

  String toUserMessage() {
    if (cause is FitbitOAuthException) {
      return (cause as FitbitOAuthException).message;
    }

    final unexpectedMessage = formatUnexpectedFitbitCallbackFailure(cause);
    return '$prefix $unexpectedMessage';
  }
}

String formatUnexpectedFitbitCallbackFailure(Object error) {
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
