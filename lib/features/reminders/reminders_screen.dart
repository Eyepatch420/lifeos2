import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_x.dart';
import '../../core/widgets/alert_type_selector.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/module_header.dart';
import '../../data/models/enums.dart';
import '../../data/models/reminder.dart';
import '../../data/stores/reminder_store.dart';
import '../../data/stores/settings_store.dart';
import 'add_reminder_sheet.dart';
import 'water_card.dart';

/// PRD 2.1 — Reminders main list, grouped by time of day, with quick logging,
/// swipe actions (2.4) and the missed indicator (AC3).
class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  int _tab = 0;
  DateTime _date = DateTime.now();

  static const List<String> _tabs = <String>[
    'All',
    'Medicine',
    'Water',
    'Custom'
  ];

  ReminderType? get _filter => switch (_tab) {
        1 => ReminderType.medicine,
        2 => ReminderType.water,
        3 => ReminderType.custom,
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final ReminderStore store = context.watch<ReminderStore>();
    final DateTime now = DateTime.now();
    final Map<String, List<Reminder>> grouped =
        store.groupedByBucket(_date, filter: _filter);
    final int missed = store.missedCount(_date, now);

    // PRD 2.1 AC4 — the water card shows on All and Water, hides on Medicine.
    final bool showWater = _tab == 0 || _tab == 2;

    return Scaffold(
      body: Column(
        children: <Widget>[
          ModuleHeader(
            color: AppColors.reminders,
            title: 'Reminders',
            subtitle: relativeDayLabel(_date, now),
            actions: <Widget>[
              HeaderIconButton(
                icon: Icons.calendar_today_outlined,
                tooltip: 'Change date',
                onPressed: _pickDate,
              ),
              HeaderIconButton(
                icon: Icons.tune,
                tooltip: 'Reminder settings',
                onPressed: _openDefaults,
              ),
            ],
            tabs: _tabs,
            selectedTab: _tab,
            onTabSelected: (int i) => setState(() => _tab = i),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
              children: <Widget>[
                if (missed > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InfoBanner(
                      tone: ChipTone.danger,
                      icon: Icons.error_outline,
                      title: '$missed reminder${missed > 1 ? 's' : ''} missed',
                      text:
                          'Swipe right on a card to mark it done, or long-press '
                          'for more options.',
                    ),
                  ),
                if (showWater) ...<Widget>[
                  WaterCard(date: _date),
                  const SizedBox(height: 12),
                ],
                if (grouped.isEmpty)
                  EmptyState(
                    icon: Icons.notifications_off_outlined,
                    title: 'No reminders here',
                    message: _filter == null
                        ? 'Add your first reminder with the + button.'
                        : 'No ${_tabs[_tab].toLowerCase()} reminders for this day.',
                    actionLabel: 'Add reminder',
                    onAction: () =>
                        AddReminderSheet.show(context, initialType: _filter),
                  ),
                for (final MapEntry<String, List<Reminder>> e
                    in grouped.entries)
                  _bucketSection(context, e.key, e.value, now),
                if (grouped.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Center(
                      child: Text(
                        'Swipe left to snooze or delete · right to mark done',
                        style: TextStyle(
                            fontSize: 11.5, color: context.txtTertiary),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.reminders,
        onPressed: () => AddReminderSheet.show(context, initialType: _filter),
        tooltip: 'Add reminder',
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _bucketSection(
      BuildContext context, String bucket, List<Reminder> items, DateTime now) {
    final ReminderStore store = context.read<ReminderStore>();
    final int missedHere =
        items.where((Reminder r) => store.isMissed(r, _date, now)).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionLabel(
          bucket,
          trailing: missedHere > 0 ? '$missedHere missed' : null,
        ),
        AppCard(
          child: Column(
            children: <Widget>[
              for (int i = 0; i < items.length; i++) ...<Widget>[
                _ReminderRow(
                  reminder: items[i],
                  date: _date,
                  now: now,
                ),
                if (i != items.length - 1)
                  Divider(height: 1, color: context.hairline),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _openDefaults() {
    final SettingsStore s = context.read<SettingsStore>();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext ctx, StateSetter setModal) => SheetScaffold(
          title: 'Reminder defaults',
          actionLabel: 'Done',
          actionColor: AppColors.reminders,
          onAction: () => Navigator.pop(ctx),
          children: <Widget>[
            Text(
              'These pre-select values for new reminders. Existing reminders '
              'are never changed.',
              style: TextStyle(fontSize: 12.5, color: ctx.txtSecondary),
            ),
            const SizedBox(height: 14),
            AlertTypeSelector(
              value: s.defaultAlertType,
              onChanged: (AlertType t) {
                s.setDefaultAlertType(t);
                setModal(() {});
              },
              showRepeatInterval: false,
            ),
            const Divider(height: 24),
            FieldWrap(
              label: 'Default snooze duration',
              child: Wrap(
                spacing: 6,
                children: <Widget>[
                  for (final int m in <int>[5, 10, 15, 30])
                    ChoicePill(
                      label: '$m min',
                      selected: s.defaultSnoozeMinutes == m,
                      onTap: () {
                        s.setSnooze(m);
                        setModal(() {});
                      },
                    ),
                ],
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.nightlight_outlined),
              title: const Text('Do not disturb window',
                  style: TextStyle(fontSize: 14)),
              subtitle: Text(
                '${formatTimeOfDay(s.dndStart)} – ${formatTimeOfDay(s.dndEnd)}',
                style: const TextStyle(fontSize: 12.5),
              ),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: () async {
                final TimeOfDay? start = await showTimePicker(
                    context: ctx,
                    initialTime: s.dndStart,
                    helpText: 'DND starts at');
                if (start == null) return;
                final TimeOfDay? end = await showTimePicker(
                    context: ctx,
                    initialTime: s.dndEnd,
                    helpText: 'DND ends at');
                if (end == null) return;
                s.setDnd(start, end);
                setModal(() {});
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// A single reminder row with swipe + long-press affordances (PRD 2.4).
class _ReminderRow extends StatelessWidget {
  const _ReminderRow({
    required this.reminder,
    required this.date,
    required this.now,
  });

  final Reminder reminder;
  final DateTime date;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final ReminderStore store = context.watch<ReminderStore>();
    final bool done = store.isDone(reminder, date);
    final bool missed = store.isMissed(reminder, date, now);
    final CompletionStatus? status = store.statusOn(reminder, date);
    final bool skipped = status == CompletionStatus.skipped;
    final bool blocked = store.isBlockedByDependency(reminder, date);
    final int streak = store.streakDays(reminder, now);

    return Dismissible(
      key: ValueKey<String>('rem_${reminder.id}_${date.toIso8601String()}'),
      // Right swipe = mark done; left swipe = snooze/delete menu.
      background: Container(
        color: AppColors.checkGreen,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.check, color: Colors.white, size: 20),
            SizedBox(width: 6),
            Text('Done',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
      secondaryBackground: Container(
        color: AppColors.dangerBright,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.snooze, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Icon(Icons.delete_outline, color: Colors.white, size: 20),
          ],
        ),
      ),
      // 50% threshold so a minor swipe can never trigger an action (2.4 AC1).
      dismissThresholds: const <DismissDirection, double>{
        DismissDirection.startToEnd: 0.5,
        DismissDirection.endToStart: 0.5,
      },
      confirmDismiss: (DismissDirection dir) async {
        if (dir == DismissDirection.startToEnd) {
          store.markDone(reminder, date);
          showSnack(context, '${reminder.title} marked done');
          return false; // keep the row in place
        }
        await _showSwipeActions(context, store);
        return false;
      },
      child: InkWell(
        onLongPress: () => _showContextMenu(context, store),
        onTap: () => AddReminderSheet.show(context, existing: reminder),
        child: Opacity(
          opacity: reminder.enabled ? 1 : 0.55,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: <Widget>[
                Container(
                  width: 4,
                  height: 40,
                  decoration: BoxDecoration(
                    color: missed ? AppColors.dangerBright : reminder.color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                IconTile(
                  icon: reminder.icon,
                  color: missed ? AppColors.danger : reminder.color,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              reminder.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: missed
                                    ? AppColors.danger
                                    : context.txtPrimary,
                                decoration: done || skipped
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),
                          AlertTypeBadge(reminder.alertType),
                        ],
                      ),
                      if (reminder.subtitle.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: Text(
                            reminder.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 11.5, color: context.txtSecondary),
                          ),
                        ),
                      const SizedBox(height: 3),
                      Wrap(
                        spacing: 5,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: <Widget>[
                          if (blocked)
                            StatusChip.tone(
                              'After ${store.byId(reminder.dependencyId!)?.title ?? 'previous'}',
                              ChipTone.purple,
                              icon: Icons.link,
                            ),
                          if (streak > 0)
                            StatusChip.tone(
                                '$streak day streak', ChipTone.warning,
                                icon: Icons.local_fire_department),
                          if (missed)
                            StatusChip.tone('Missed', ChipTone.danger),
                          if (skipped)
                            StatusChip.tone('Skipped today', ChipTone.neutral),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      formatTimeOfDay(reminder.time),
                      style: TextStyle(
                        fontSize: 12,
                        color: missed ? AppColors.danger : context.txtSecondary,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Transform.scale(
                      scale: 0.75,
                      child: Switch(
                        value: reminder.enabled,
                        activeThumbColor: AppColors.checkGreen,
                        onChanged: (bool v) => store.setEnabled(reminder, v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 4),
                // Done control: filled once complete, further taps are no-ops
                // beyond toggling back (PRD 2.1 AC5).
                InkWell(
                  onTap: () => store.toggleDone(reminder, date),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: 27,
                    height: 27,
                    decoration: BoxDecoration(
                      color: done ? AppColors.checkGreen : Colors.transparent,
                      border: Border.all(
                        color: done
                            ? AppColors.checkGreen
                            : (missed
                                ? AppColors.dangerBright
                                : AppColors.checkGreen),
                        width: 1.5,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check,
                      size: 15,
                      color: done
                          ? Colors.white
                          : (missed
                              ? AppColors.dangerBright
                              : AppColors.checkGreen),
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

  Future<void> _showSwipeActions(
      BuildContext context, ReminderStore store) async {
    final int snooze = context.read<SettingsStore>().defaultSnoozeMinutes;
    await showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.snooze, color: AppColors.warning),
              title: Text('Snooze $snooze min'),
              onTap: () {
                store.snooze(reminder, snooze);
                Navigator.pop(ctx);
                showSnack(context, 'Snoozed for $snooze minutes');
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline,
                  color: AppColors.dangerBright),
              title: const Text('Delete reminder',
                  style: TextStyle(color: AppColors.dangerBright)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(context, store);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// PRD 2.4 — long-press context menu.
  Future<void> _showContextMenu(
      BuildContext context, ReminderStore store) async {
    final int snooze = context.read<SettingsStore>().defaultSnoozeMinutes;
    await showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: <Widget>[
                  IconTile(
                      icon: reminder.icon, color: reminder.color, size: 30),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(reminder.title,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.check, color: AppColors.checkGreen),
              title: const Text('Mark as done'),
              onTap: () {
                store.markDone(reminder, date);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.snooze, color: AppColors.warning),
              title: Text('Snooze $snooze min'),
              onTap: () {
                store.snooze(reminder, snooze);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: AppColors.info),
              title: const Text('Edit reminder'),
              onTap: () {
                Navigator.pop(ctx);
                AddReminderSheet.show(context, existing: reminder);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: const Text('Duplicate'),
              subtitle: const Text('Opens a pre-filled copy to adjust',
                  style: TextStyle(fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                // PRD 2.4 FR4 — opens in edit mode BEFORE saving.
                AddReminderSheet.show(context,
                    existing: store.duplicate(reminder));
              },
            ),
            ListTile(
              leading: const Icon(Icons.skip_next_outlined),
              title: const Text('Skip today'),
              subtitle: const Text('Keeps your streak — not counted as missed',
                  style: TextStyle(fontSize: 12)),
              onTap: () {
                store.skipToday(reminder, date);
                Navigator.pop(ctx);
                showSnack(context, 'Skipped today · streak preserved');
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline,
                  color: AppColors.dangerBright),
              title: const Text('Delete reminder',
                  style: TextStyle(color: AppColors.dangerBright)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(context, store);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// PRD 2.4 AC2/AC3 — one shared delete path with explicit confirmation.
  Future<void> _confirmDelete(BuildContext context, ReminderStore store) async {
    final bool ok = await confirmDialog(
      context,
      title: 'Delete ${reminder.title}?',
      message: 'This will remove the reminder and its full history. '
          'This cannot be undone.',
    );
    if (ok) {
      store.delete(reminder.id);
      if (context.mounted) showSnack(context, 'Reminder deleted');
    }
  }
}
