class FitbitOAuthToken {
  const FitbitOAuthToken({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Map<String, dynamic> toJson() {
    return {
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'expiresAt': expiresAt.toIso8601String(),
    };
  }

  static FitbitOAuthToken fromJson(Map<String, dynamic> json) {
    return FitbitOAuthToken(
      accessToken: json['accessToken'] as String? ?? '',
      refreshToken: json['refreshToken'] as String? ?? '',
      expiresAt: DateTime.parse(json['expiresAt'] as String),
    );
  }
}
