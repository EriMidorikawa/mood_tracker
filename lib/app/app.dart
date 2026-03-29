import 'package:flutter/material.dart';
import 'package:mood_tracker/app/settings_menu_button.dart';
import 'package:mood_tracker/features/daily_log/data/local_daily_log_repository.dart';
import 'package:mood_tracker/features/daily_log/models/daily_log_entry.dart';
import 'package:mood_tracker/features/daily_log/daily_log_page.dart';
import 'package:mood_tracker/features/history/history_page.dart';
import 'package:mood_tracker/features/home/home_page.dart';
import 'package:mood_tracker/features/trends/trends_page.dart';
import 'package:mood_tracker/features/wearables/data/fitbit_callback_link_service.dart';
import 'package:mood_tracker/features/wearables/data/local_wearable_repository.dart';
import 'package:mood_tracker/features/wearables/models/daily_wearable_metric.dart';

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
  final _fitbitCallbackLinkService = FitbitCallbackLinkService();
  int _selectedIndex = 0;
  List<DailyLogEntry> _entries = const [];
  List<DailyWearableMetric> _wearableMetrics = const [];
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
    _loadData();
    _fitbitCallbackLinkService.start();
  }

  @override
  void dispose() {
    _fitbitCallbackLinkService.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final entries = await _repository.loadEntriesSorted();
    final wearableMetrics = await _wearableRepository.loadDailyMetrics();
    if (!mounted) {
      return;
    }

    setState(() {
      _entries = entries;
      _wearableMetrics = wearableMetrics;
      _isLoading = false;
    });
  }

  Future<void> _handleSave(DailyLogEntry entry) async {
    await _repository.saveEntry(entry);
    final entries = await _repository.loadEntriesSorted();
    if (!mounted) {
      return;
    }

    setState(() {
      _entries = entries;
      _selectedIndex = 0;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scaffoldMessengerKey.currentState
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Daily log saved locally.')),
        );
    });
  }

  Future<void> _saveEntryFromHistory(DailyLogEntry entry) async {
    await _repository.saveEntry(entry);
    final entries = await _repository.loadEntriesSorted();
    if (!mounted) {
      return;
    }

    setState(() {
      _entries = entries;
      _selectedIndex = 2;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scaffoldMessengerKey.currentState
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('History log updated.')),
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
        onOpenTodayLog: () => _openTodayLog(context),
        onOpenSettings: () => openSettingsPage(context),
      ),
      TrendsPage(
        entries: _entries,
        wearableMetrics: _wearableMetrics,
      ),
      HistoryPage(
        entries: _entries,
        loadEntryByDate: _repository.loadEntryByDate,
        onSaveEntry: _saveEntryFromHistory,
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
