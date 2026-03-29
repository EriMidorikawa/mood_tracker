import 'package:mood_tracker/features/wearables/models/wearable_provider.dart';

class WearableConnection {
  const WearableConnection({
    required this.provider,
    required this.isConnected,
    this.accountLabel,
    this.connectedAt,
    this.lastSyncedAt,
  });

  final WearableProvider provider;
  final bool isConnected;
  final String? accountLabel;
  final DateTime? connectedAt;
  final DateTime? lastSyncedAt;

  Map<String, dynamic> toJson() {
    return {
      'provider': provider.storageKey,
      'isConnected': isConnected,
      'accountLabel': accountLabel,
      'connectedAt': connectedAt?.toIso8601String(),
      'lastSyncedAt': lastSyncedAt?.toIso8601String(),
    };
  }

  static WearableConnection fromJson(Map<String, dynamic> json) {
    return WearableConnection(
      provider: WearableProvider.fromStorageKey(json['provider'] as String),
      isConnected: json['isConnected'] as bool? ?? false,
      accountLabel: json['accountLabel'] as String?,
      connectedAt: _parseDateTime(json['connectedAt'] as String?),
      lastSyncedAt: _parseDateTime(json['lastSyncedAt'] as String?),
    );
  }
}

DateTime? _parseDateTime(String? value) {
  if (value == null || value.isEmpty) {
    return null;
  }

  return DateTime.tryParse(value);
}
