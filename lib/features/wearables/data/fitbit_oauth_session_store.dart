import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:mood_tracker/features/wearables/models/fitbit_oauth_preparation.dart';

class FitbitOAuthSessionStore {
  FitbitOAuthSessionStore({
    String? clientId,
    List<String>? scopes,
  })  : _clientId = clientId ?? const String.fromEnvironment('FITBIT_CLIENT_ID'),
        _scopes = scopes ?? const ['sleep', 'heartrate'];

  static const redirectUri = 'moodtracker://fitbit-callback';

  final String _clientId;
  final List<String> _scopes;
  final ValueNotifier<FitbitOAuthPreparation?> preparedSession =
      ValueNotifier(null);

  FitbitOAuthPreparation prepareAuthorization() {
    final state = _generateRandomToken();
    final codeVerifier = _generateRandomToken(length: 64);
    final codeChallenge = _buildCodeChallenge(codeVerifier);
    final authorizationUri = Uri.https(
      'www.fitbit.com',
      '/oauth2/authorize',
      {
        'client_id': _clientId,
        'redirect_uri': redirectUri,
        'response_type': 'code',
        'scope': _scopes.join(' '),
        'state': state,
        'code_challenge': codeChallenge,
        'code_challenge_method': 'S256',
      },
    );

    final preparation = FitbitOAuthPreparation(
      state: state,
      codeVerifier: codeVerifier,
      codeChallenge: codeChallenge,
      authorizationUri: authorizationUri,
    );
    preparedSession.value = preparation;
    return preparation;
  }

  bool? matchesCallbackState(String? callbackState) {
    final preparedState = preparedSession.value?.state;
    if (preparedState == null || callbackState == null) {
      return null;
    }

    return preparedState == callbackState;
  }

  String _generateRandomToken({int length = 32}) {
    final random = Random.secure();
    final bytes = List<int>.generate(length, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  String _buildCodeChallenge(String codeVerifier) {
    final digest = sha256.convert(utf8.encode(codeVerifier));
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }
}

final fitbitOAuthSessionStore = FitbitOAuthSessionStore();
