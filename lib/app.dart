import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'data/stores/settings_store.dart';
import 'features/shell/app_shell.dart';
import 'features/shell/lock_gate.dart';

class DigiLifeApp extends StatelessWidget {
  const DigiLifeApp({super.key});

  @override
  Widget build(BuildContext context) {
    final SettingsStore settings = context.watch<SettingsStore>();
    return MaterialApp(
      title: 'DigiLife',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: settings.themeMode,
      home: const LockGate(child: AppShell()),
    );
  }
}
