class FitbitOAuthPreparation {
  const FitbitOAuthPreparation({
    required this.state,
    required this.codeVerifier,
    required this.codeChallenge,
    required this.authorizationUri,
  });

  final String state;
  final String codeVerifier;
  final String codeChallenge;
  final Uri authorizationUri;
}
