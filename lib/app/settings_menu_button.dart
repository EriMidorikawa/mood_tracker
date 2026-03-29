import 'package:flutter/material.dart';
import 'package:mood_tracker/features/settings/settings_page.dart';

void openSettingsPage(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => const SettingsPage(),
    ),
  );
}

class SettingsMenuButton extends StatelessWidget {
  const SettingsMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_AppMenuAction>(
      icon: const Icon(Icons.more_vert),
      onSelected: (value) {
        switch (value) {
          case _AppMenuAction.settings:
            openSettingsPage(context);
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem<_AppMenuAction>(
          value: _AppMenuAction.settings,
          child: Text('Settings'),
        ),
      ],
    );
  }
}

enum _AppMenuAction {
  settings,
}
