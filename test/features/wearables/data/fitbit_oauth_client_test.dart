import 'package:flutter_test/flutter_test.dart';
import 'package:mood_tracker/features/wearables/data/fitbit_oauth_client.dart';

void main() {
  group('FitbitOAuthClient', () {
    test('throws a clear error when client secret is missing', () async {
      final client = FitbitOAuthClient(
        clientId: '23V4LV',
        clientSecret: '',
      );

      await expectLater(
        () => client.exchangeAuthorizationCode(
          code: 'test-code',
          codeVerifier: 'test-verifier',
        ),
        throwsA(
          isA<FitbitOAuthException>().having(
            (error) => error.message,
            'message',
            'FITBIT_CLIENT_SECRET is not configured.',
          ),
        ),
      );
    });
  });

  group('buildFitbitTokenExchangeErrorMessage', () {
    test('returns rebuild guidance for invalid_client', () {
      final message = buildFitbitTokenExchangeErrorMessage(
        statusCode: 401,
        responseBody: '{"error":"invalid_client"}',
      );

      expect(
        message,
        'Fitbit token exchange failed (401): invalid_client. Rebuild the app with the current FITBIT_CLIENT_SECRET.',
      );
    });

    test('returns the OAuth error code for invalid_grant', () {
      final message = buildFitbitTokenExchangeErrorMessage(
        statusCode: 400,
        responseBody: '{"error":"invalid_grant"}',
      );

      expect(
        message,
        'Fitbit token exchange failed (400): invalid_grant.',
      );
    });

    test('returns rate limit message for 429', () {
      final message = buildFitbitTokenExchangeErrorMessage(
        statusCode: 429,
        responseBody: '{}',
      );

      expect(
        message,
        'Fitbit token exchange failed (429): rate limit reached.',
      );
    });
  });
}
