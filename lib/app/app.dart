import 'package:flutter/material.dart';
import 'package:mood_tracker/app/settings_menu_button.dart';
import 'package:mood_tracker/features/daily_log/data/local_daily_log_repository.dart';
import 'package:mood_tracker/features/daily_log/models/daily_log_entry.dart';
import 'package:mood_tracker/features/daily_log/daily_log_page.dart';
import 'package:mood_tracker/features/history/history_page.dart';
import 'package:mood_tracker/features/home/home_page.dart';
import 'package:mood_tracker/features/trends/trends_page.dart';
import 'package:mood_tracker/features/wearables/data/fitbit_api_client.dart';
import 'package:mood_tracker/features/wearables/data/fitbit_callback_link_service.dart';
import 'package:mood_tracker/features/wearables/data/fitbit_oauth_token_store.dart';
import 'package:mood_tracker/features/wearables/data/fitbit_source_adapter.dart';
import 'package:mood_tracker/features/wearables/data/local_wearable_repository.dart';
import 'package:mood_tracker/features/wearables/models/daily_wearable_metric.dart';
import 'package:mood_tracker/features/wearables/models/wearable_connection.dart';
import 'package:mood_tracker/features/wearables/models/wearable_provider.dart';

class MoodTrackerApp extends StatelessWidget {
  const MoodTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mood Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4F6BED),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F8FC),
      ),
      home: const AppShell(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _repository = LocalDailyLogRepository();
  final _wearableRepository = LocalWearableRepository();
  final _fitbitTokenStore = FitbitOAuthTokenStore();
  final _fitbitCallbackLinkService = FitbitCallbackLinkService();
  int _selectedIndex = 0;
  List<DailyLogEntry> _entries = const [];
  List<DailyWearableMetric> _wearableMetrics = const [];
  WearableConnection? _fitbitConnection;
  bool _isLoading = true;
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  static const _destinations = <NavigationDestination>[
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home),
      label: 'Home',
    ),
    NavigationDestination(
      icon: Icon(Icons.show_chart_outlined),
      selectedIcon: Icon(Icons.show_chart),
      label: 'Trends',
    ),
    NavigationDestination(
      icon: Icon(Icons.history_outlined),
      selectedIcon: Icon(Icons.history),
      label: 'History',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadDataAndMaybeAutoSync();
    _fitbitCallbackLinkService.start();
  }

  @override
  void dispose() {
    _fitbitCallbackLinkService.dispose();
    super.dispose();
  }

  Future<_AppShellData> _loadAppData() async {
    final entries = await _repository.loadEntriesSorted();
    final wearableMetrics = await _wearableRepository.loadDailyMetrics();
    final fitbitConnection = await _wearableRepository.loadConnection(
      WearableProvider.fitbit,
    );

    return _AppShellData(
      entries: entries,
      wearableMetrics: wearableMetrics,
      fitbitConnection: fitbitConnection,
    );
  }

  WearableConnection? _applyAppData(_AppShellData data) {
    if (!mounted) {
      return null;
    }

    setState(() {
      _entries = data.entries;
      _wearableMetrics = data.wearableMetrics;
      _fitbitConnection = data.fitbitConnection;
      _isLoading = false;
    });

    return data.fitbitConnection;
  }

  Future<void> _loadData() async {
    final data = await _loadAppData();
    _applyAppData(data);
  }

  Future<void> _loadDataAndMaybeAutoSync() async {
    final data = await _loadAppData();
    final fitbitConnection = _applyAppData(data);
    await _maybeAutoSyncFitbit(fitbitConnection);
  }

  Future<void> _maybeAutoSyncFitbit(WearableConnection? fitbitConnection) async {
    if (fitbitConnection?.isConnected != true) {
      return;
    }

    final today = _dateOnly(DateTime.now());
    if (_dateOnly(fitbitConnection!.lastSyncedAt ?? DateTime(2000)) == today) {
      return;
    }

    final token = await _fitbitTokenStore.loadToken();
    if (token == null || token.isExpired) {
      return;
    }

    try {
      final now = DateTime.now();
      final fitbitAdapter = FitbitSourceAdapter(
        fetchSnapshot:
            FitbitApiClient(accessToken: token.accessToken).fetchDailySnapshot,
      );
      final metrics = await fitbitAdapter.fetchDailyMetrics(today);
      await _wearableRepository.upsertDailyMetrics(metrics);
      await _wearableRepository.upsertConnection(
        WearableConnection(
          provider: WearableProvider.fitbit,
          isConnected: true,
          accountLabel: fitbitConnection.accountLabel,
          connectedAt: fitbitConnection.connectedAt ?? now,
          lastSyncedAt: now,
        ),
      );
      await _loadData();
    } catch (_) {
      // Keep startup resilient if auto sync cannot complete.
    }
  }

  Future<void> _openSettingsAndRefresh(BuildContext context) async {
    await openSettingsPage(context);
    await _loadData();
  }

  Future<void> _handleSave(DailyLogEntry entry) async {
    await _saveEntryAndRefreshUi(
      entry,
      selectedIndex: 0,
      snackBarMessage: 'Daily log saved locally.',
    );
  }

  Future<void> _saveEntryFromHistory(DailyLogEntry entry) async {
    await _saveEntryAndRefreshUi(
      entry,
      selectedIndex: 2,
      snackBarMessage: 'History log updated.',
    );
  }

  Future<void> _saveEntryAndRefreshUi(
    DailyLogEntry entry, {
    required int selectedIndex,
    required String snackBarMessage,
  }) async {
    await _repository.saveEntry(entry);
    final entries = await _repository.loadEntriesSorted();
    if (!mounted) {
      return;
    }

    setState(() {
      _entries = entries;
      _selectedIndex = selectedIndex;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scaffoldMessengerKey.currentState
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(snackBarMessage)),
        );
    });
  }

  Future<void> _openTodayLog(BuildContext context) async {
    final today = DateTime.now();
    final todayEntry = await _repository.loadEntryByDate(today);
    if (!context.mounted) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DailyLogPage(
          initialEntry: todayEntry,
          initialDate: todayEntry == null ? today : null,
          onSave: _handleSave,
          popOnSave: true,
          showSettingsMenu: false,
          title: todayEntry == null ? 'Log today' : 'Edit today\'s log',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final today = DateTime.now();
    DailyLogEntry? todayEntry;
    for (final entry in _entries) {
      if (entry.loggedAt.year == today.year &&
          entry.loggedAt.month == today.month &&
          entry.loggedAt.day == today.day) {
        todayEntry = entry;
        break;
      }
    }

    final pages = <Widget>[
      HomePage(
        todayEntry: todayEntry,
        fitbitConnection: _fitbitConnection,
        onOpenTodayLog: () => _openTodayLog(context),
        onOpenSettings: () => _openSettingsAndRefresh(context),
        onSettingsClosed: () => _loadData(),
      ),
      TrendsPage(
        entries: _entries,
        wearableMetrics: _wearableMetrics,
        onSettingsClosed: () => _loadData(),
      ),
      HistoryPage(
        entries: _entries,
        wearableMetrics: _wearableMetrics,
        loadEntryByDate: _repository.loadEntryByDate,
        onSaveEntry: _saveEntryFromHistory,
        onSettingsClosed: () => _loadData(),
      ),
    ];

    return ScaffoldMessenger(
      key: _scaffoldMessengerKey,
      child: Scaffold(
        body: pages[_selectedIndex],
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          destinations: _destinations,
          onDestinationSelected: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
        ),
      ),
    );
  }
}

DateTime _dateOnly(DateTime dateTime) {
  return DateTime(dateTime.year, dateTime.month, dateTime.day);
}

class _AppShellData {
  const _AppShellData({
    required this.entries,
    required this.wearableMetrics,
    required this.fitbitConnection,
  });

  final List<DailyLogEntry> entries;
  final List<DailyWearableMetric> wearableMetrics;
  final WearableConnection? fitbitConnection;
}
