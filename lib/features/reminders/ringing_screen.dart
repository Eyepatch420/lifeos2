import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../core/services/notification_service.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/enums.dart';

/// PRD 2.3 — the force-confirm tier. The alarm keeps sounding and re-arms
/// itself at [intervalMinutes] until the user explicitly confirms, so it
/// cannot be swiped away like an ordinary notification.
class RingingScreen extends StatefulWidget {
  const RingingScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.payload,
    this.alertType = AlertType.forceConfirm,
    this.intervalMinutes = 2,
    this.snoozeMinutes = 10,
    this.onConfirm,
    this.onSnooze,
  });

  final String title;
  final String subtitle;

  /// "reminder:<id>" / "alarm:<id>" — identifies the re-fire chain.
  final String payload;
  final AlertType alertType;
  final int intervalMinutes;
  final int snoozeMinutes;

  /// Returns false to reject the confirm (e.g. an unmet dependency) — the
  /// alarm keeps ringing and re-arms rather than closing silently.
  final bool Function()? onConfirm;
  final VoidCallback? onSnooze;

  static Future<void> show(BuildContext context, RingingScreen screen) {
    return Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => screen, fullscreenDialog: true),
    );
  }

  @override
  State<RingingScreen> createState() => _RingingScreenState();
}

class _RingingScreenState extends State<RingingScreen>
    with SingleTickerProviderStateMixin {
  final AudioPlayer _player = AudioPlayer();
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _startRinging();
  }

  Future<void> _startRinging() async {
    try {
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.play(
        AssetSource('Popular Alarm Clock Sound Effect.mp3'),
        volume: 1.0,
      );
    } catch (_) {
      // Audio focus can be denied; the notification sound still played.
    }
    // Arm the next re-fire immediately, so leaving this screen without
    // confirming still brings the alert back (PRD 2.3).
    if (widget.alertType == AlertType.forceConfirm) {
      await NotificationService.scheduleForceConfirmRepeat(
        widget.payload,
        widget.title,
        widget.subtitle,
        widget.intervalMinutes,
      );
    }
  }

  Future<void> _stopAudio() async {
    try {
      await _player.stop();
    } catch (_) {/* already stopped */}
  }

  @override
  void dispose() {
    _pulse.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (widget.onConfirm != null && !widget.onConfirm!()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Complete its dependency first'),
        ));
      }
      return;
    }
    await _stopAudio();
    await NotificationService.cancelForceConfirmRepeat(widget.payload);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _snooze() async {
    await _stopAudio();
    await NotificationService.cancelForceConfirmRepeat(widget.payload);
    widget.onSnooze?.call();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    // Back must not dismiss a force-confirm alert.
    return PopScope(
      canPop: widget.alertType != AlertType.forceConfirm,
      child: Scaffold(
        backgroundColor: AppColors.reminders,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Spacer(),
                ScaleTransition(
                  scale: Tween<double>(begin: 0.9, end: 1.08).animate(
                    CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
                  ),
                  child: Container(
                    width: 132,
                    height: 132,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.alarm,
                        size: 62, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                if (widget.alertType == AlertType.forceConfirm) ...<Widget>[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Repeats every ${widget.intervalMinutes} min until confirmed',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _confirm,
                    icon: const Icon(Icons.check),
                    label: Text(
                      widget.alertType == AlertType.forceConfirm
                          ? 'Confirm — I did it'
                          : 'Done',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.reminders,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _snooze,
                    icon: const Icon(Icons.snooze),
                    label: Text('Snooze ${widget.snoozeMinutes} min'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
