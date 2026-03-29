class FitbitConfig {
  const FitbitConfig._();

  static const clientId = String.fromEnvironment(
    'FITBIT_CLIENT_ID',
    defaultValue: '23V4LV',
  );
  static const clientSecret = String.fromEnvironment('FITBIT_CLIENT_SECRET');

  static bool get hasClientId => clientId.isNotEmpty;
}
