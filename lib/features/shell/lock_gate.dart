import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../data/stores/settings_store.dart';

/// PRD 10.1 — when app lock is on, the app content stays hidden until the
/// user authenticates. Re-locks when the app returns from the background.
class LockGate extends StatefulWidget {
  const LockGate({super.key, required this.child});

  final Widget child;

  @override
  State<LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<LockGate> with WidgetsBindingObserver {
  bool _unlocked = false;
  bool _prompting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybePrompt());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Lock again as soon as the app leaves the foreground.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      if (context.read<SettingsStore>().appLockEnabled) {
        setState(() => _unlocked = false);
      }
    } else if (state == AppLifecycleState.resumed) {
      _maybePrompt();
    }
  }

  Future<void> _maybePrompt() async {
    if (!mounted || _prompting || _unlocked) return;
    if (!context.read<SettingsStore>().appLockEnabled) return;
    _prompting = true;
    final bool ok =
        await AuthService.authenticate('Unlock LifeOS to view your data');
    _prompting = false;
    if (!mounted) return;
    if (ok) setState(() => _unlocked = true);
  }

  @override
  Widget build(BuildContext context) {
    final bool locked =
        context.watch<SettingsStore>().appLockEnabled && !_unlocked;
    if (!locked) return widget.child;

    return Scaffold(
      backgroundColor: AppColors.home,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.lock_outline, size: 56, color: Colors.white),
            const SizedBox(height: 16),
            const Text(
              'LifeOS is locked',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Authenticate to continue',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: _maybePrompt,
              icon: const Icon(Icons.fingerprint),
              label: const Text('Unlock'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.home,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
