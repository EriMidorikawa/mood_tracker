import 'package:flutter/material.dart';
import 'package:mood_tracker/features/dashboard/dashboard_page.dart';

class TrendsPage extends StatelessWidget {
  const TrendsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderPage(
      title: 'Trends',
      description: 'Patterns and charts will be added here.',
      icon: Icons.show_chart_rounded,
    );
  }
}
