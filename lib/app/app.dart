import 'package:flutter/material.dart';
import 'package:mood_tracker/features/dashboard/dashboard_page.dart';
import 'package:mood_tracker/features/daily_log/daily_log_models.dart';
import 'package:mood_tracker/features/daily_log/daily_log_page.dart';
import 'package:mood_tracker/features/settings/settings_page.dart';
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
  int _selectedIndex = 0;
  DailyLogEntry? _latestEntry;
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
      icon: Icon(Icons.settings_outlined),
      selectedIcon: Icon(Icons.settings),
      label: 'Settings',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      DashboardPage(latestEntry: _latestEntry),
      DailyLogPage(
        initialEntry: _latestEntry,
        onSave: (entry) {
          setState(() {
            _latestEntry = entry;
            _selectedIndex = 0;
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scaffoldMessengerKey.currentState
              ?..hideCurrentSnackBar()
              ..showSnackBar(
                const SnackBar(content: Text('Daily log saved locally.')),
              );
          });
        },
      ),
      const TrendsPage(),
      const SettingsPage(),
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
