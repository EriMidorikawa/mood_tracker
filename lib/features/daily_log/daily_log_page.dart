import 'package:flutter/material.dart';
import 'package:mood_tracker/features/dashboard/dashboard_page.dart';

class DailyLogPage extends StatelessWidget {
  const DailyLogPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderPage(
      title: 'Daily Log',
      description: 'Mood entry and notes will be added here.',
      icon: Icons.edit_note_rounded,
    );
  }
}
