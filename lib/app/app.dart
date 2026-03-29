import 'package:flutter/material.dart';
import 'package:mood_tracker/features/dashboard/dashboard_page.dart';
import 'package:mood_tracker/features/daily_log/data/local_daily_log_repository.dart';
import 'package:mood_tracker/features/daily_log/models/daily_log_entry.dart';
import 'package:mood_tracker/features/daily_log/daily_log_page.dart';
import 'package:mood_tracker/features/history/history_page.dart';
import 'package:mood_tracker/features/trends/trends_page.dart';

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
  int _selectedIndex = 0;
  DailyLogEntry? _latestEntry;
  DailyLogEntry? _activeEntry;
  List<DailyLogEntry> _entries = const [];
  bool _isLoading = true;
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  static const _destinations = <NavigationDestination>[
    NavigationDestination(
      icon: Icon(Icons.dashboard_outlined),
      selectedIcon: Icon(Icons.dashboard),
      label: 'Dashboard',
    ),
    NavigationDestination(
      icon: Icon(Icons.edit_note_outlined),
      selectedIcon: Icon(Icons.edit_note),
      label: 'Daily Log',
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
  }

  Future<void> _loadData() async {
    final latestEntry = await _repository.loadLatestEntry();
    final entries = await _repository.loadEntriesSorted();
    if (!mounted) {
      return;
    }

    setState(() {
      _latestEntry = latestEntry;
      _activeEntry = latestEntry;
      _entries = entries;
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
      _latestEntry = entry;
      _activeEntry = entry;
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

  Future<void> _openEntryForDate(DateTime logDate) async {
    final entry = await _repository.loadEntryByDate(logDate);
    if (!mounted || entry == null) {
      return;
    }

    setState(() {
      _activeEntry = entry;
      _selectedIndex = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final pages = <Widget>[
      DashboardPage(
        latestEntry: _latestEntry,
      ),
      DailyLogPage(
        key: ValueKey(_activeEntry?.loggedAt.toIso8601String() ?? 'new-entry'),
        initialEntry: _activeEntry,
        onSave: _handleSave,
      ),
      const TrendsPage(),
      HistoryPage(
        entries: _entries,
        onOpenEntry: _openEntryForDate,
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
