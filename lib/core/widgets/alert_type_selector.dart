import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../data/models/enums.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'common.dart';

/// PRD 2.3 + G.2 — THE shared three-tier alert selector.
///
/// Deliberately one component reused by Reminders (2.2), Memberships (7.3),
/// Bills (8.2) and Documents (9.2), so the Force-Confirm warning and repeat
/// interval can never diverge between modules.
class AlertTypeSelector extends StatefulWidget {
  const AlertTypeSelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.repeatMinutes = 2,
    this.onRepeatChanged,
    this.showRepeatInterval = true,
  });

  final AlertType value;
  final ValueChanged<AlertType> onChanged;
  final int repeatMinutes;
  final ValueChanged<int>? onRepeatChanged;
  final bool showRepeatInterval;

  static (IconData, Color) _visual(AlertType t) => switch (t) {
        AlertType.notification => (Icons.notifications_none, AppColors.success),
        AlertType.alarm => (Icons.alarm, AppColors.warning),
        AlertType.forceConfirm => (Icons.shield_outlined, AppColors.danger),
      };

  @override
  State<AlertTypeSelector> createState() => _AlertTypeSelectorState();
}

class _AlertTypeSelectorState extends State<AlertTypeSelector> {
  bool _notifsEnabled = true;
  bool _exactAlarmEnabled = true;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final bool n = await NotificationService.hasNotificationPermission();
    final bool e = await NotificationService.hasExactAlarmPermission();
    if (mounted) {
      setState(() {
        _notifsEnabled = n;
        _exactAlarmEnabled = e;
      });
    }
  }

  /// PRD 2.3 FR3 / AC3 — iOS cannot guarantee an un-dismissable alarm, so the
  /// limitation is disclosed at the point of selection rather than discovered
  /// later by the user.
  static bool get _forceConfirmFullySupported {
    if (kIsWeb) return false;
    try {
      return Platform.isAndroid;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Alert type',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: context.txtSecondary,
          ),
        ),
        const SizedBox(height: 6),
        for (final AlertType t in AlertType.values) _option(context, t),
      ],
    );
  }

  Widget _option(BuildContext context, AlertType t) {
    final bool selected = widget.value == t;
    final (IconData icon, Color accent) = AlertTypeSelector._visual(t);
    final bool isForce = t == AlertType.forceConfirm;

    // PRD G.2 — if permissions are missing, the feature is disabled to
    // prevent the user setting an alert that will never fire.
    final bool permissionMissing = switch (t) {
      AlertType.notification => !_notifsEnabled,
      AlertType.alarm || AlertType.forceConfirm => !_exactAlarmEnabled,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: InkWell(
        onTap: permissionMissing ? null : () => widget.onChanged(t),
        borderRadius: BorderRadius.circular(10),
        child: Opacity(
          opacity: permissionMissing ? 0.6 : 1.0,
          child: Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: selected
                  ? accent.withValues(alpha: 0.08)
                  : Colors.transparent,
              border: Border.all(
                color: selected ? accent : context.hairline,
                width: selected ? 1.5 : 0.8,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // Radio behaviour: exactly one selection (PRD 2.3 FR1).
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(
                        selected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        size: 17,
                        color: selected ? accent : context.txtTertiary,
                      ),
                    ),
                    const SizedBox(width: 9),
                    IconTile(icon: icon, color: accent, size: 32),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            t.label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: selected ? accent : context.txtPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            t.description,
                            style: TextStyle(
                              fontSize: 11.5,
                              height: 1.35,
                              color: context.txtSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (permissionMissing) ...<Widget>[
                  const SizedBox(height: 8),
                  InfoBanner(
                    tone: ChipTone.danger,
                    icon: Icons.error_outline,
                    text: t == AlertType.notification
                        ? 'Notification permission is required to use this tier. '
                            'Please enable it in System Settings.'
                        : 'Exact alarm permission is required for this tier. '
                            'Please enable it in System Settings.',
                  ),
                ],

                // Warning + repeat interval appear only while Force Confirm is
                // selected, and disappear when it is deselected (PRD 2.3 FR2).
                if (isForce && selected) ...<Widget>[
                  const SizedBox(height: 10),
                  InfoBanner(
                    tone: ChipTone.warning,
                    icon: Icons.info_outline,
                    text: _forceConfirmFullySupported
                        ? 'This will override Do Not Disturb. Make sure notification '
                            'permission is set to "Allow always" and battery '
                            'optimisation is disabled for DigiDaily.'
                        : 'On this platform the system does not allow a fully '
                            'un-dismissable alarm. DigiDaily will use the most '
                            'insistent alert available (time-sensitive, repeating), '
                            'but it can still be dismissed from the lock screen.',
                  ),
                  if (widget.showRepeatInterval &&
                      widget.onRepeatChanged != null) ...<Widget>[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Repeat interval',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: context.txtSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: <Widget>[
                        for (final int m in <int>[1, 2, 5, 10])
                          ChoicePill(
                            label: '$m min',
                            selected: widget.repeatMinutes == m,
                            color: AppColors.danger,
                            onTap: () => widget.onRepeatChanged!(m),
                          ),
                      ],
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact badge showing a configured alert type on list rows.
class AlertTypeBadge extends StatelessWidget {
  const AlertTypeBadge(this.type, {super.key});
  final AlertType type;

  @override
  Widget build(BuildContext context) {
    if (type == AlertType.notification) return const SizedBox.shrink();
    final (IconData icon, Color color) = AlertTypeSelector._visual(type);
    return Tooltip(
      message: type.label,
      child: Icon(icon, size: 14, color: color),
    );
  }
}
