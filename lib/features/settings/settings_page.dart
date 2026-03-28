import 'package:flutter/material.dart';
import 'package:mood_tracker/features/dashboard/dashboard_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderPage(
      title: 'Settings',
      description: 'Preferences and integrations will be managed here.',
      icon: Icons.settings_rounded,
    );
  }
}
