class FitbitCallbackDebug {
  const FitbitCallbackDebug({
    required this.uri,
    this.code,
    this.state,
    this.stateMatched,
  });

  final Uri uri;
  final String? code;
  final String? state;
  final bool? stateMatched;
}
