import 'package:flutter/material.dart';
import 'package:mood_tracker/features/settings/settings_page.dart';

Future<void> openSettingsPage(BuildContext context) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => const SettingsPage(),
    ),
  );
}

class SettingsMenuButton extends StatelessWidget {
  const SettingsMenuButton({
    super.key,
    this.onSettingsClosed,
  });

  final Future<void> Function()? onSettingsClosed;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_AppMenuAction>(
      icon: const Icon(Icons.more_vert),
      onSelected: (value) async {
        switch (value) {
          case _AppMenuAction.settings:
            await openSettingsPage(context);
            await onSettingsClosed?.call();
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
