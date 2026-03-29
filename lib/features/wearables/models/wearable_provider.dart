enum WearableProvider {
  manual('manual'),
  fitbit('fitbit');

  const WearableProvider(this.storageKey);

  final String storageKey;

  static WearableProvider fromStorageKey(String value) {
    return WearableProvider.values.firstWhere(
      (provider) => provider.storageKey == value,
      orElse: () => WearableProvider.manual,
    );
  }
}
