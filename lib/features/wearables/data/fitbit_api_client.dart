import 'dart:convert';
import 'dart:io';

import 'package:mood_tracker/features/wearables/data/fitbit_daily_snapshot_mapper.dart';
import 'package:mood_tracker/features/wearables/data/fitbit_source_adapter.dart';

class FitbitApiClient {
  FitbitApiClient({String? accessToken})
      : _accessToken =
            accessToken ?? const String.fromEnvironment('FITBIT_ACCESS_TOKEN'),
        _snapshotMapper = const FitbitDailySnapshotMapper();

  FitbitApiClient.withMapper({
    String? accessToken,
    FitbitDailySnapshotMapper mapper = const FitbitDailySnapshotMapper(),
  })  : _accessToken =
            accessToken ?? const String.fromEnvironment('FITBIT_ACCESS_TOKEN'),
        _snapshotMapper = mapper;

  final String _accessToken;
  final FitbitDailySnapshotMapper _snapshotMapper;

  bool get isConfigured => _accessToken.isNotEmpty;

  Future<FitbitDailySnapshot> fetchDailySnapshot(DateTime date) async {
    if (!isConfigured) {
      throw const FitbitApiException(
        'FITBIT_ACCESS_TOKEN is not configured.',
      );
    }

    final day = _dateOnly(date);
    final dateString = _formatDate(day);

    final sleepResponse = await _getJson(
      'https://api.fitbit.com/1.2/user/-/sleep/date/$dateString.json',
    );
    final heartResponse = await _getJson(
      'https://api.fitbit.com/1/user/-/activities/heart/date/$dateString/1d.json',
    );

    return _snapshotMapper.map(
      date: day,
      sleepResponse: sleepResponse,
      heartResponse: heartResponse,
    );
  }

  Future<Map<String, dynamic>> _getJson(String url) async {
    final httpClient = HttpClient();
    try {
      final request = await httpClient.getUrl(Uri.parse(url));
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer $_accessToken',
      );
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw FitbitApiException(
          'Fitbit API request failed (${response.statusCode}).',
        );
      }

      return jsonDecode(responseBody) as Map<String, dynamic>;
    } finally {
      httpClient.close(force: true);
    }
  }
}

class FitbitApiException implements Exception {
  const FitbitApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

DateTime _dateOnly(DateTime dateTime) {
  return DateTime(dateTime.year, dateTime.month, dateTime.day);
}

String _formatDate(DateTime dateTime) {
  final year = dateTime.year.toString().padLeft(4, '0');
  final month = dateTime.month.toString().padLeft(2, '0');
  final day = dateTime.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
