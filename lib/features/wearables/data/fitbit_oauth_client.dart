import 'dart:convert';
import 'dart:io';

import 'package:mood_tracker/features/wearables/config/fitbit_config.dart';
import 'package:mood_tracker/features/wearables/data/fitbit_oauth_session_store.dart';
import 'package:mood_tracker/features/wearables/models/fitbit_oauth_token.dart';

class FitbitOAuthClient {
  FitbitOAuthClient({
    String? clientId,
    String? clientSecret,
  })  : _clientId = clientId ?? FitbitConfig.clientId,
        _clientSecret = clientSecret ?? FitbitConfig.clientSecret;

  final String _clientId;
  final String _clientSecret;

  Future<FitbitOAuthToken> exchangeAuthorizationCode({
    required String code,
    required String codeVerifier,
  }) async {
    if (_clientId.isEmpty) {
      throw const FitbitOAuthException('FITBIT_CLIENT_ID is not configured.');
    }
    if (_clientSecret.isEmpty) {
      throw const FitbitOAuthException('FITBIT_CLIENT_SECRET is not configured.');
    }

    final httpClient = HttpClient();
    try {
      final request = await httpClient.postUrl(
        Uri.https('api.fitbit.com', '/oauth2/token'),
      );
      request.headers.set(
        HttpHeaders.contentTypeHeader,
        'application/x-www-form-urlencoded',
      );
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (_clientSecret.isNotEmpty) {
        final credentials = base64Encode(utf8.encode('$_clientId:$_clientSecret'));
        request.headers.set(
          HttpHeaders.authorizationHeader,
          'Basic $credentials',
        );
      }

      request.write(
        Uri(queryParameters: {
          'client_id': _clientId,
          'grant_type': 'authorization_code',
          'redirect_uri': FitbitOAuthSessionStore.redirectUri,
          'code': code,
          'code_verifier': codeVerifier,
        }).query,
      );

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw FitbitOAuthException(
          buildFitbitTokenExchangeErrorMessage(
            statusCode: response.statusCode,
            responseBody: responseBody,
          ),
        );
      }

      final decoded = jsonDecode(responseBody) as Map<String, dynamic>;
      final accessToken = decoded['access_token'] as String?;
      final refreshToken = decoded['refresh_token'] as String?;
      final expiresIn = decoded['expires_in'] as int?;
      if (accessToken == null || refreshToken == null || expiresIn == null) {
        throw const FitbitOAuthException(
          'Fitbit token exchange failed: invalid token response.',
        );
      }

      return FitbitOAuthToken(
        accessToken: accessToken,
        refreshToken: refreshToken,
        expiresAt: DateTime.now().add(Duration(seconds: expiresIn)),
      );
    } finally {
      httpClient.close(force: true);
    }
  }
}

String buildFitbitTokenExchangeErrorMessage({
  required int statusCode,
  required String responseBody,
}) {
  final errorCode = _extractFitbitOAuthErrorCode(responseBody);
  if (statusCode == 401 || errorCode == 'invalid_client') {
    final code = errorCode ?? 'invalid_client';
    return 'Fitbit token exchange failed ($statusCode): $code. '
        'Rebuild the app with the current FITBIT_CLIENT_SECRET.';
  }

  if (statusCode == 429) {
    return 'Fitbit token exchange failed (429): rate limit reached.';
  }

  if (errorCode != null) {
    return 'Fitbit token exchange failed ($statusCode): $errorCode.';
  }

  return 'Fitbit token exchange failed ($statusCode).';
}

String? _extractFitbitOAuthErrorCode(String responseBody) {
  try {
    final decoded = jsonDecode(responseBody);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    final error = decoded['error'];
    if (error is String && error.isNotEmpty) {
      return error;
    }

    final errors = decoded['errors'];
    if (errors is List) {
      for (final item in errors) {
        if (item is! Map<String, dynamic>) {
          continue;
        }

        final errorType = item['errorType'];
        if (errorType is String && errorType.isNotEmpty) {
          return errorType;
        }
      }
    }
  } catch (_) {
    return null;
  }

  return null;
}

class FitbitOAuthException implements Exception {
  const FitbitOAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}
