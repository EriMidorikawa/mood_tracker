import 'dart:convert';

import 'package:mood_tracker/features/wearables/models/fitbit_oauth_token.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FitbitOAuthTokenStore {
  static const _tokenKey = 'wearables.fitbit_oauth_token';

  Future<FitbitOAuthToken?> loadToken() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_tokenKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    return FitbitOAuthToken.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> saveToken(FitbitOAuthToken token) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_tokenKey, jsonEncode(token.toJson()));
  }

  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_tokenKey);
  }
}
