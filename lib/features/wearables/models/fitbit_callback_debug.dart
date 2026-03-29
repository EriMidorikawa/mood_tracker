class FitbitCallbackDebug {
  const FitbitCallbackDebug({
    required this.uri,
    this.code,
    this.state,
  });

  final Uri uri;
  final String? code;
  final String? state;
}
