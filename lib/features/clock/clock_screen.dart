import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../reminders/ringing_screen.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_x.dart';
import '../../core/widgets/alert_type_selector.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/highlight_row.dart';
import '../../core/widgets/module_header.dart';
import '../../data/models/alarm.dart';
import '../../data/models/enums.dart';
import '../../data/stores/alarm_store.dart';
import '../../data/stores/id_gen.dart';
import '../../data/stores/settings_store.dart';

/// Clock — a single screen holding two sections: Alarm and Stopwatch.
///
/// The two sections share this one screen deliberately. Stopwatch state lives
/// in this State object (not in a store), so switching to the Alarm section
/// and back does NOT reset a running stopwatch.
class ClockScreen extends StatefulWidget {
  const ClockScreen({super.key, this.highlightId});

  /// An alarm id to flash/scroll to on open — set when arriving from search
  /// or a notification tap.
  final String? highlightId;

  @override
  State<ClockScreen> createState() => _ClockScreenState();
}

class _ClockScreenState extends State<ClockScreen> {
  int _section = 0; // 0 = Alarm, 1 = Stopwatch

  // ---- stopwatch state (persists across section switches) ----
  final Stopwatch _watch = Stopwatch();
  Timer? _ticker;
  final List<Lap> _laps = <Lap>[];
  Duration _lastLapAt = Duration.zero;

  // ---- alarm countdown refresh ----
  Timer? _clockTicker;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Keeps the "rings in …" countdown honest without a full rebuild storm.
    _clockTicker = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _clockTicker?.cancel();
    _watch.stop();
    super.dispose();
  }

  // ------------------------------------------------------------------
  // Stopwatch controls
  // ------------------------------------------------------------------

  void _startStopwatch() {
    _watch.start();
    // ~33 fps is plenty for a centisecond readout and stays smooth.
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 30), (_) {
      if (mounted) setState(() {});
    });
    setState(() {});
  }

  void _pauseStopwatch() {
    _watch.stop();
    _ticker?.cancel();
    _ticker = null;
    setState(() {});
  }

  void _resetStopwatch() {
    _watch
      ..stop()
      ..reset();
    _ticker?.cancel();
    _ticker = null;
    setState(() {
      _laps.clear();
      _lastLapAt = Duration.zero;
    });
  }

  void _recordLap() {
    final Duration total = _watch.elapsed;
    final Duration split = total - _lastLapAt;
    setState(() {
      _laps.insert(0, Lap(index: _laps.length + 1, split: split, total: total));
      _lastLapAt = total;
    });
  }

  Duration? get _bestLap => _laps.isEmpty
      ? null
      : _laps
          .map((Lap l) => l.split)
          .reduce((Duration a, Duration b) => a < b ? a : b);

  Duration? get _worstLap => _laps.length < 2
      ? null
      : _laps
          .map((Lap l) => l.split)
          .reduce((Duration a, Duration b) => a > b ? a : b);

  // ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final AlarmStore store = context.watch<AlarmStore>();
    final Alarm? next = store.nextAlarm(_now);

    return Scaffold(
      body: Column(
        children: <Widget>[
          ModuleHeader(
            color: AppColors.clock,
            title: 'Clock',
            subtitle: _section == 0
                ? (next == null
                    ? 'No alarms set'
                    : 'Next: ${formatTimeOfDay(next.time)} · ${next.timeUntilLabel(_now)}')
                : (_watch.isRunning ? 'Stopwatch running' : 'Stopwatch'),
            leading: Navigator.canPop(context)
                ? IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  )
                : null,
            tabs: const <String>['Alarm', 'Stopwatch'],
            selectedTab: _section,
            onTabSelected: (int i) => setState(() => _section = i),
          ),
          Expanded(
            // IndexedStack keeps both sections alive so the stopwatch keeps
            // running while you are looking at the alarms.
            child: IndexedStack(
              index: _section,
              children: <Widget>[
                _alarmSection(context, store),
                _stopwatchSection(context),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _section == 0
          ? FloatingActionButton(
              heroTag: 'fab_clock',
              backgroundColor: AppColors.clock,
              tooltip: 'Add alarm',
              onPressed: () => _openAlarmSheet(context),
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  // ==================================================================
  // SECTION 1 — ALARM
  // ==================================================================

  Widget _alarmSection(BuildContext context, AlarmStore store) {
    final List<Alarm> alarms = store.all;
    final Alarm? next = store.nextAlarm(_now);

    if (alarms.isEmpty) {
      return EmptyState(
        icon: Icons.alarm_off,
        title: 'No alarms yet',
        message: 'Add one with the + button. Alarms are separate from '
            'reminders — they simply ring at a time you choose.',
        actionLabel: 'Add alarm',
        onAction: () => _openAlarmSheet(context),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
      children: <Widget>[
        if (next != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InfoBanner(
              tone: ChipTone.info,
              icon: Icons.alarm_on,
              title: 'Next alarm ${next.timeUntilLabel(_now)}',
              text: '${formatTimeOfDay(next.time)}'
                  '${next.label.isEmpty ? '' : ' · ${next.label}'}'
                  ' · ${next.repeatLabel}',
            ),
          ),
        SectionLabel('Alarms', trailing: '${store.enabled.length} on'),
        AppCard(
          child: Column(
            children: <Widget>[
              for (int i = 0; i < alarms.length; i++) ...<Widget>[
                HighlightRow(
                  highlighted: alarms[i].id == widget.highlightId,
                  child: _alarmRow(
                      context, store, alarms[i], alarms[i].id == next?.id),
                ),
                if (i != alarms.length - 1)
                  Divider(height: 1, color: context.hairline),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: Text(
            'Swipe an alarm left to delete it',
            style: TextStyle(fontSize: 11.5, color: context.txtTertiary),
          ),
        ),
      ],
    );
  }

  Widget _alarmRow(
      BuildContext context, AlarmStore store, Alarm a, bool isNext) {
    return Dismissible(
      key: ValueKey<String>('alarm_${a.id}'),
      direction: DismissDirection.endToStart,
      dismissThresholds: const <DismissDirection, double>{
        DismissDirection.endToStart: 0.5,
      },
      background: Container(
        color: AppColors.dangerBright,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        final bool ok = await confirmDialog(
          context,
          title: 'Delete this alarm?',
          message: '${formatTimeOfDay(a.time)}'
              '${a.label.isEmpty ? '' : ' · ${a.label}'}. This cannot be undone.',
        );
        if (ok) store.delete(a.id);
        return false;
      },
      child: InkWell(
        onTap: () => _openAlarmSheet(context, existing: a),
        onLongPress: () => _alarmMenu(context, store, a),
        child: Opacity(
          opacity: a.enabled ? 1 : 0.5,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: <Widget>[
                          Text(
                            formatTimeOfDay(a.time),
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w300,
                              letterSpacing: -0.5,
                              color: context.txtPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          AlertTypeBadge(a.alertType),
                          if (isNext && a.enabled) ...<Widget>[
                            const SizedBox(width: 6),
                            StatusChip.tone('Next', ChipTone.info),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        <String>[
                          if (a.label.isNotEmpty) a.label,
                          a.repeatLabel,
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12, color: context.txtSecondary),
                      ),
                      if (a.enabled)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            'Rings ${a.timeUntilLabel(_now)}',
                            style: TextStyle(
                                fontSize: 11, color: context.txtTertiary),
                          ),
                        ),
                    ],
                  ),
                ),
                Switch(
                  value: a.enabled,
                  activeThumbColor: AppColors.checkGreen,
                  onChanged: (bool v) => store.setEnabled(a, v),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _alarmMenu(
      BuildContext context, AlarmStore store, Alarm a) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit alarm'),
              onTap: () {
                Navigator.pop(ctx);
                _openAlarmSheet(context, existing: a);
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.play_circle_outline, color: AppColors.clock),
              title: const Text('Preview how it rings'),
              onTap: () {
                Navigator.pop(ctx);
                RingingScreen.show(
                  context,
                  RingingScreen(
                    title: a.label.isEmpty ? 'Alarm' : a.label,
                    subtitle: '${formatTimeOfDay(a.time)} · ${a.repeatLabel}',
                    payload: 'alarm:${a.id}',
                    alertType: a.alertType,
                    intervalMinutes: a.forceConfirmIntervalMinutes,
                    snoozeMinutes: a.snoozeMinutes,
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.snooze, color: AppColors.warning),
              title: Text('Push forward ${a.snoozeMinutes} min'),
              onTap: () {
                store.snooze(a);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: const Text('Duplicate'),
              onTap: () {
                Navigator.pop(ctx);
                _openAlarmSheet(context, existing: store.duplicate(a));
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline,
                  color: AppColors.dangerBright),
              title: const Text('Delete alarm',
                  style: TextStyle(color: AppColors.dangerBright)),
              onTap: () async {
                Navigator.pop(ctx);
                final bool ok = await confirmDialog(
                  context,
                  title: 'Delete this alarm?',
                  message: '${formatTimeOfDay(a.time)}. This cannot be undone.',
                );
                if (ok) store.delete(a.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openAlarmSheet(BuildContext context, {Alarm? existing}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AlarmSheet(existing: existing),
    );
  }

  // ==================================================================
  // SECTION 2 — STOPWATCH
  // ==================================================================

  Widget _stopwatchSection(BuildContext context) {
    final Duration elapsed = _watch.elapsed;
    final bool running = _watch.isRunning;
    final bool started = elapsed > Duration.zero;

    return Column(
      children: <Widget>[
        const SizedBox(height: 24),
        // Big readout
        Column(
          children: <Widget>[
            Text(
              formatStopwatch(elapsed),
              style: TextStyle(
                fontSize: 56,
                fontWeight: FontWeight.w200,
                letterSpacing: -1.5,
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                color: context.txtPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              running ? 'Running' : (started ? 'Paused' : 'Ready'),
              style: TextStyle(
                fontSize: 12,
                letterSpacing: 0.5,
                color: running ? AppColors.clock : context.txtTertiary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Controls
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: started ? _resetStopwatch : null,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: context.hairline),
                  ),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Reset'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: running ? _pauseStopwatch : _startStopwatch,
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        running ? AppColors.warning : AppColors.clock,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  icon:
                      Icon(running ? Icons.pause : Icons.play_arrow, size: 20),
                  label:
                      Text(running ? 'Pause' : (started ? 'Resume' : 'Start')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: running ? _recordLap : null,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: context.hairline),
                  ),
                  icon: const Icon(Icons.flag_outlined, size: 18),
                  label: const Text('Lap'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Expanded(
          child: _laps.isEmpty
              ? EmptyState(
                  icon: Icons.timer_outlined,
                  title: started ? 'No laps recorded' : 'Stopwatch ready',
                  message: started
                      ? 'Tap Lap while it is running to record a split.'
                      : 'Tap Start to begin timing. You can switch to the Alarm '
                          'section and back without losing your time.',
                )
              : _lapList(context),
        ),
      ],
    );
  }

  Widget _lapList(BuildContext context) {
    final Duration? best = _bestLap;
    final Duration? worst = _worstLap;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 52,
                child: Text('LAP',
                    style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 0.6,
                        fontWeight: FontWeight.w600,
                        color: context.txtTertiary)),
              ),
              Expanded(
                child: Text('SPLIT',
                    style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 0.6,
                        fontWeight: FontWeight.w600,
                        color: context.txtTertiary)),
              ),
              Text('TOTAL',
                  style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 0.6,
                      fontWeight: FontWeight.w600,
                      color: context.txtTertiary)),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            itemCount: _laps.length,
            separatorBuilder: (_, __) =>
                Divider(height: 1, color: context.hairline),
            itemBuilder: (BuildContext context, int i) {
              final Lap lap = _laps[i];
              final bool isBest =
                  _laps.length > 1 && best != null && lap.split == best;
              final bool isWorst = _laps.length > 1 &&
                  worst != null &&
                  lap.split == worst &&
                  !isBest;
              final Color tone = isBest
                  ? AppColors.success
                  : (isWorst ? AppColors.danger : context.txtPrimary);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 11),
                child: Row(
                  children: <Widget>[
                    SizedBox(
                      width: 52,
                      child: Row(
                        children: <Widget>[
                          Text(
                            '${lap.index}'.padLeft(2, '0'),
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: context.txtSecondary),
                          ),
                          if (isBest || isWorst) ...<Widget>[
                            const SizedBox(width: 4),
                            Icon(
                              isBest
                                  ? Icons.arrow_downward
                                  : Icons.arrow_upward,
                              size: 11,
                              color: tone,
                            ),
                          ],
                        ],
                      ),
                    ),
                    Expanded(
                      child: Text(
                        formatStopwatch(lap.split),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: isBest || isWorst
                              ? FontWeight.w600
                              : FontWeight.w400,
                          fontFeatures: const <FontFeature>[
                            FontFeature.tabularFigures()
                          ],
                          color: tone,
                        ),
                      ),
                    ),
                    Text(
                      formatStopwatch(lap.total),
                      style: TextStyle(
                        fontSize: 13,
                        fontFeatures: const <FontFeature>[
                          FontFeature.tabularFigures()
                        ],
                        color: context.txtSecondary,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ====================================================================
// Add / edit alarm sheet
// ====================================================================

class _AlarmSheet extends StatefulWidget {
  const _AlarmSheet({this.existing});
  final Alarm? existing;

  @override
  State<_AlarmSheet> createState() => _AlarmSheetState();
}

class _AlarmSheetState extends State<_AlarmSheet> {
  late TimeOfDay _time;
  final TextEditingController _label = TextEditingController();
  late Set<int> _days;
  late AlertType _alert;
  int _snooze = 10;
  int _repeatMinutes = 2;
  bool _vibrate = true;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final Alarm? a = widget.existing;
    _time = a?.time ?? const TimeOfDay(hour: 7, minute: 0);
    _days = Set<int>.from(a?.repeatDays ?? <int>{});
    _alert = a?.alertType ?? context.read<SettingsStore>().defaultAlertType;
    _snooze =
        a?.snoozeMinutes ?? context.read<SettingsStore>().defaultSnoozeMinutes;
    _repeatMinutes = a?.forceConfirmIntervalMinutes ?? 2;
    _vibrate = a?.vibrate ?? true;
    if (a != null) _label.text = a.label;
  }

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  void _save() {
    final AlarmStore store = context.read<AlarmStore>();
    final Alarm a = Alarm(
      id: widget.existing?.id ?? IdGen.next('alm'),
      time: _time,
      label: _label.text.trim(),
      repeatDays: _days,
      enabled: widget.existing?.enabled ?? true,
      alertType: _alert,
      snoozeMinutes: _snooze,
      vibrate: _vibrate,
      forceConfirmIntervalMinutes: _repeatMinutes,
    );
    if (_isEdit && store.byId(a.id) != null) {
      store.update(a);
    } else {
      store.add(a);
    }
    Navigator.pop(context);
    showSnack(
      context,
      _isEdit
          ? 'Alarm updated'
          : 'Alarm set for ${a.timeUntilLabel(DateTime.now())}',
    );
  }

  @override
  Widget build(BuildContext context) {
    const List<String> dayLabels = <String>['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return SheetScaffold(
      title: _isEdit ? 'Edit alarm' : 'New alarm',
      actionLabel: _isEdit ? 'Save changes' : 'Set alarm',
      actionColor: AppColors.clock,
      onAction: _save,
      children: <Widget>[
        // Big tappable time
        Center(
          child: InkWell(
            onTap: () async {
              final TimeOfDay? picked =
                  await showTimePicker(context: context, initialTime: _time);
              if (picked != null && mounted) setState(() => _time = picked);
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                children: <Widget>[
                  Text(
                    formatTimeOfDay(_time),
                    style: TextStyle(
                      fontSize: 46,
                      fontWeight: FontWeight.w300,
                      letterSpacing: -1,
                      color: context.txtPrimary,
                    ),
                  ),
                  Text(
                    'Tap to change',
                    style:
                        TextStyle(fontSize: 11.5, color: context.txtTertiary),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        FieldWrap(
          label: 'Label (optional)',
          child: TextField(
            controller: _label,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'e.g. Morning jog'),
          ),
        ),
        FieldWrap(
          label: 'Repeat',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  for (int i = 1; i <= 7; i++) ...<Widget>[
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() {
                          if (_days.contains(i)) {
                            _days.remove(i);
                          } else {
                            _days.add(i);
                          }
                        }),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          height: 38,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _days.contains(i)
                                ? AppColors.clock.withValues(alpha: 0.12)
                                : Colors.transparent,
                            border: Border.all(
                              color: _days.contains(i)
                                  ? AppColors.clock
                                  : context.hairline,
                              width: _days.contains(i) ? 1.4 : 0.8,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            dayLabels[i - 1],
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: _days.contains(i)
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color: _days.contains(i)
                                  ? AppColors.clock
                                  : context.txtSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (i != 7) const SizedBox(width: 5),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: <Widget>[
                  ChoicePill(
                    label: 'Once',
                    selected: _days.isEmpty,
                    color: AppColors.clock,
                    onTap: () => setState(() => _days.clear()),
                  ),
                  ChoicePill(
                    label: 'Every day',
                    selected: _days.length == 7,
                    color: AppColors.clock,
                    onTap: () =>
                        setState(() => _days = <int>{1, 2, 3, 4, 5, 6, 7}),
                  ),
                  ChoicePill(
                    label: 'Weekdays',
                    selected: _days.length == 5 &&
                        _days.containsAll(<int>{1, 2, 3, 4, 5}),
                    color: AppColors.clock,
                    onTap: () => setState(() => _days = <int>{1, 2, 3, 4, 5}),
                  ),
                  ChoicePill(
                    label: 'Weekends',
                    selected:
                        _days.length == 2 && _days.containsAll(<int>{6, 7}),
                    color: AppColors.clock,
                    onTap: () => setState(() => _days = <int>{6, 7}),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _days.isEmpty
                    ? 'Rings once, then switches itself off.'
                    : 'Repeats: ${Alarm(id: 'x', time: _time, repeatDays: _days).repeatLabel}',
                style: TextStyle(fontSize: 11.5, color: context.txtSecondary),
              ),
            ],
          ),
        ),
        FieldWrap(
          label: 'Snooze duration',
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              for (final int m in <int>[5, 10, 15, 30])
                ChoicePill(
                  label: '$m min',
                  selected: _snooze == m,
                  color: AppColors.clock,
                  onTap: () => setState(() => _snooze = m),
                ),
            ],
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _vibrate,
          activeThumbColor: AppColors.checkGreen,
          title: const Text('Vibrate',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          onChanged: (bool v) => setState(() => _vibrate = v),
        ),
        const Divider(height: 20),
        // Same shared 3-tier component used by Reminders, Bills, Memberships.
        AlertTypeSelector(
          value: _alert,
          onChanged: (AlertType t) => setState(() => _alert = t),
          repeatMinutes: _repeatMinutes,
          onRepeatChanged: (int m) => setState(() => _repeatMinutes = m),
        ),
      ],
    );
  }
}
