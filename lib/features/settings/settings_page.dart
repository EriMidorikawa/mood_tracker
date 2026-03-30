import 'package:flutter/material.dart';
import 'package:mood_tracker/features/daily_log/data/local_daily_log_repository.dart';
import 'package:mood_tracker/features/wearables/data/fitbit_callback_debug_store.dart';
import 'package:mood_tracker/features/wearables/data/fitbit_oauth_session_store.dart';
import 'package:mood_tracker/features/wearables/data/fitbit_oauth_token_store.dart';
import 'package:mood_tracker/features/wearables/data/local_wearable_repository.dart';
import 'package:mood_tracker/features/settings/fitbit_settings_controller.dart';
import 'package:mood_tracker/features/wearables/models/fitbit_oauth_preparation.dart';
import 'package:mood_tracker/shared/format_utils.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const _backfillOptions = <int>[30, 90];

  final _dailyLogRepository = LocalDailyLogRepository();
  final _wearableRepository = LocalWearableRepository();
  final _fitbitTokenStore = FitbitOAuthTokenStore();
  final _fitbitController = FitbitSettingsController();
  String? _lastHandledCallbackUri;

  @override
  void initState() {
    super.initState();
    _fitbitController.loadConnection();
    fitbitCallbackDebugStore.lastCallback.addListener(_handleFitbitCallback);
  }

  @override
  void dispose() {
    fitbitCallbackDebugStore.lastCallback.removeListener(_handleFitbitCallback);
    _fitbitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(Icons.settings_rounded, size: 64),
          const SizedBox(height: 16),
          Text(
            'Settings',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Manage your mood tracking preferences and Fitbit connection.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          ListenableBuilder(
            listenable: _fitbitController,
            builder: (context, _) {
              final fitbitState = _fitbitController.state;
              return _FitbitSectionCard(
                statusLabel: _fitbitController.statusLabel,
                hasConnection: _fitbitController.hasConnection,
                lastSyncedAt: _fitbitController.connection?.lastSyncedAt,
                isHandlingCallback: fitbitState.isHandlingCallback,
                isBackfilling: fitbitState.isBackfilling,
                selectedBackfillDays: fitbitState.selectedBackfillDays,
                backfillProgress: fitbitState.backfillProgress,
                backfillTarget: fitbitState.backfillTarget,
                syncResult: fitbitState.syncResult,
                primaryActionLabel: _fitbitController.primaryActionLabel,
                backfillOptions: _backfillOptions,
                onPrimaryAction:
                    fitbitState.isHandlingCallback || fitbitState.isSyncing
                    ? null
                    : _handleFitbitPrimaryAction,
                onBackfillSelectionChanged: fitbitState.isBackfilling
                    ? null
                    : (selection) {
                        _fitbitController.selectBackfillDays(selection.first);
                      },
                onBackfill:
                    fitbitState.isBackfilling ? null : _backfillFitbitData,
                onDisconnect:
                    _fitbitController.connection == null ? null : _disconnectFitbit,
              );
            },
          ),
          const SizedBox(height: 16),
          _DangerZoneCard(
            onResetLocalAppData: _resetLocalAppData,
          ),
        ],
      ),
    );
  }

  Future<void> _resetLocalAppData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reset local app data?'),
          content: const Text(
            'This removes local daily logs, wearable data, Fitbit session, and connection state on this device only.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }

    await _dailyLogRepository.clear();
    await _wearableRepository.clearDailyMetrics();
    await _wearableRepository.clearConnections();
    await _fitbitTokenStore.clear();
    _fitbitController.applyResetLocalAppDataState();
  }

  Future<void> _syncFitbitData({bool rethrowFailure = false}) async {
    await _fitbitController.syncToday(rethrowFailure: rethrowFailure);
  }

  Future<void> _backfillFitbitData() async {
    await _fitbitController.backfill();
  }

  Future<void> _handleFitbitPrimaryAction() async {
    if (!_fitbitController.hasConnection) {
      final preparation = fitbitOAuthSessionStore.prepareAuthorization();
      await _openFitbitAuthorization(preparation);
      return;
    }

    await _syncFitbitData();
  }

  Future<void> _disconnectFitbit() async {
    final existingConnection = _fitbitController.connection;
    if (existingConnection == null) {
      return;
    }

    final shouldDisconnect = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Disconnect Fitbit?'),
          content: const Text(
            'You can reconnect later from Settings. Your previously synced data will stay in the app.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Disconnect'),
            ),
          ],
        );
      },
    );
    if (shouldDisconnect != true) {
      return;
    }

    await _fitbitController.disconnect();
  }

  Future<void> _openFitbitAuthorization(
    FitbitOAuthPreparation preparation,
  ) async {
    final opened = await launchUrl(
      preparation.authorizationUri,
      mode: LaunchMode.externalApplication,
    );
    if (!mounted || opened) {
      return;
    }

    _fitbitController.showAuthorizationLaunchFailure();
  }

  Future<void> _handleFitbitCallback() async {
    final callbackContext = _fitbitController.prepareCallbackContext(
      callback: fitbitCallbackDebugStore.lastCallback.value,
      preparation: fitbitOAuthSessionStore.preparedSession.value,
      lastHandledCallbackUri: _lastHandledCallbackUri,
    );
    if (callbackContext == null) {
      return;
    }

    _lastHandledCallbackUri = callbackContext.callback.uri.toString();
    await _fitbitController.completeCallback(callbackContext);
  }
}

class _FitbitSectionCard extends StatelessWidget {
  const _FitbitSectionCard({
    required this.statusLabel,
    required this.hasConnection,
    required this.lastSyncedAt,
    required this.isHandlingCallback,
    required this.isBackfilling,
    required this.selectedBackfillDays,
    required this.backfillProgress,
    required this.backfillTarget,
    required this.syncResult,
    required this.primaryActionLabel,
    required this.backfillOptions,
    required this.onPrimaryAction,
    required this.onBackfillSelectionChanged,
    required this.onBackfill,
    required this.onDisconnect,
  });

  final String statusLabel;
  final bool hasConnection;
  final DateTime? lastSyncedAt;
  final bool isHandlingCallback;
  final bool isBackfilling;
  final int selectedBackfillDays;
  final int backfillProgress;
  final int backfillTarget;
  final String? syncResult;
  final String primaryActionLabel;
  final List<int> backfillOptions;
  final VoidCallback? onPrimaryAction;
  final ValueChanged<Set<int>>? onBackfillSelectionChanged;
  final VoidCallback? onBackfill;
  final VoidCallback? onDisconnect;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Fitbit',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Connect Fitbit and sync your recent sleep and resting heart rate data.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Text(
              statusLabel,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            if (hasConnection) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Fitbit is connected',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 6),
              Text(
                'Connect Fitbit to import sleep and resting heart rate data.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 4),
            Text(
              lastSyncedAt != null
                  ? 'Last synced: ${formatDateTimeLabel(lastSyncedAt!)}'
                  : 'Last synced: Never',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onPrimaryAction,
              child: Text(
                isHandlingCallback ? 'Connecting Fitbit...' : primaryActionLabel,
              ),
            ),
            if (!hasConnection) ...[
              const SizedBox(height: 8),
              Text(
                'After tapping Connect Fitbit, we will open Fitbit in your browser to finish authorization.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 16),
            SegmentedButton<int>(
              segments: backfillOptions
                  .map(
                    (days) => ButtonSegment<int>(
                      value: days,
                      label: Text('Last $days days'),
                    ),
                  )
                  .toList(),
              selected: {selectedBackfillDays},
              onSelectionChanged: onBackfillSelectionChanged,
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onBackfill,
              child: Text(
                isBackfilling
                    ? 'Backfilling Fitbit data...'
                    : 'Backfill last $selectedBackfillDays days',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Import recent Fitbit history for the last $selectedBackfillDays days.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (isBackfilling) ...[
              const SizedBox(height: 8),
              Text(
                '$backfillProgress / $backfillTarget',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 8),
            TextButton(
              onPressed: onDisconnect,
              child: const Text('Disconnect'),
            ),
            if (syncResult != null) ...[
              const SizedBox(height: 12),
              Text(
                syncResult!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DangerZoneCard extends StatelessWidget {
  const _DangerZoneCard({
    required this.onResetLocalAppData,
  });

  final VoidCallback onResetLocalAppData;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Danger Zone',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Reset local app data',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'This will remove local daily logs, wearable data, saved Fitbit session, and connection state.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              'Fitbit account data on Fitbit will not be deleted.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onResetLocalAppData,
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('Reset local app data'),
            ),
          ],
        ),
      ),
    );
  }
}
