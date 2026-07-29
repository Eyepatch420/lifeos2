import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_x.dart';
import '../../core/widgets/alert_type_selector.dart';
import '../../core/widgets/common.dart';
import '../../data/models/enums.dart';
import '../../data/models/habit.dart';
import '../../data/stores/id_gen.dart';
import '../../data/stores/planner_store.dart';

/// PRD 3.3 — unified add sheet for all four planner item types.
/// Closes PRD Gap 6 by fully specifying the Event / Appointment / Task tabs,
/// which the mockups left undefined.
class AddPlannerItemSheet extends StatefulWidget {
  const AddPlannerItemSheet({
    super.key,
    this.initialType,
    this.initialDate,
    this.existingHabit,
    this.existingEvent,
  });

  final PlannerItemType? initialType;
  final DateTime? initialDate;
  final Habit? existingHabit;
  final PlannerEvent? existingEvent;

  static Future<void> show(
    BuildContext context, {
    PlannerItemType? initialType,
    DateTime? initialDate,
    Habit? existingHabit,
    PlannerEvent? existingEvent,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddPlannerItemSheet(
        initialType: initialType,
        initialDate: initialDate,
        existingHabit: existingHabit,
        existingEvent: existingEvent,
      ),
    );
  }

  @override
  State<AddPlannerItemSheet> createState() => _AddPlannerItemSheetState();
}

class _AddPlannerItemSheetState extends State<AddPlannerItemSheet> {
  late PlannerItemType _type;
  final TextEditingController _title = TextEditingController();
  final TextEditingController _location = TextEditingController();
  final TextEditingController _note = TextEditingController();
  bool _submitted = false;

  // Habit
  int _durationMinutes = 30;
  TimeOfDay _preferredTime = const TimeOfDay(hour: 6, minute: 30);
  RepeatPattern _repeat = RepeatPattern.daily;
  Set<int> _days = <int>{1, 2, 3, 4, 5};
  int _colorValue = AppColors.picker[5].toARGB32();
  int _iconCode = Icons.directions_run.codePoint;
  int? _goalStreak;

  // Event / appointment / task
  late DateTime _date;
  TimeOfDay _startTime = const TimeOfDay(hour: 10, minute: 0);
  int _eventDuration = 60;
  int? _reminderLeadMinutes = 30;
  AlertType _alert = AlertType.alarm;

  bool get _isEdit =>
      widget.existingHabit != null || widget.existingEvent != null;

  @override
  void initState() {
    super.initState();
    _type = widget.existingHabit != null
        ? PlannerItemType.habit
        : widget.existingEvent?.type ??
            widget.initialType ??
            PlannerItemType.habit;
    _date = widget.initialDate ?? DateTime.now();

    final Habit? h = widget.existingHabit;
    if (h != null) {
      _title.text = h.name;
      _durationMinutes = h.durationMinutes;
      _preferredTime = h.preferredTime ?? _preferredTime;
      _repeat = h.repeat;
      _days = Set<int>.from(h.days);
      _colorValue = h.colorValue;
      _iconCode = h.iconCodePoint;
      _goalStreak = h.goalStreak;
      _note.text = h.note;
    }

    final PlannerEvent? e = widget.existingEvent;
    if (e != null) {
      _title.text = e.title;
      _location.text = e.location;
      _note.text = e.note;
      _date = e.start;
      _startTime = TimeOfDay(hour: e.start.hour, minute: e.start.minute);
      _eventDuration = e.durationMinutes;
      _colorValue = e.colorValue;
      _reminderLeadMinutes = e.reminderLeadMinutes;
      _alert = e.alertType;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    _note.dispose();
    super.dispose();
  }

  String? get _titleError {
    if (!_submitted) return null;
    return _title.text.trim().isEmpty ? 'A name is required' : null;
  }

  /// PRD 3.3 AC2 — "Specific days" with nothing selected is blocked.
  String? get _daysError {
    if (!_submitted || _type != PlannerItemType.habit) return null;
    if (_repeat != RepeatPattern.specificDays) return null;
    return _days.isEmpty ? 'Select at least one day' : null;
  }

  bool get _isValid =>
      _title.text.trim().isNotEmpty &&
      (_type != PlannerItemType.habit ||
          _repeat != RepeatPattern.specificDays ||
          _days.isNotEmpty);

  void _save() {
    setState(() => _submitted = true);
    if (!_isValid) return;
    final PlannerStore store = context.read<PlannerStore>();

    if (_type == PlannerItemType.habit) {
      final Habit h = Habit(
        id: widget.existingHabit?.id ?? IdGen.next('hab'),
        name: _title.text.trim(),
        durationMinutes: _durationMinutes,
        preferredTime: _preferredTime,
        repeat: _repeat,
        days: _days,
        colorValue: _colorValue,
        iconCodePoint: _iconCode,
        goalStreak: _goalStreak,
        note: _note.text.trim(),
        // Anchors a monthly habit to its day-of-month.
        startedOn: widget.existingHabit?.startedOn ?? _date,
        completions: widget.existingHabit?.completions,
      );
      if (widget.existingHabit != null) {
        store.updateHabit(h);
      } else {
        store.addHabit(h);
      }
    } else {
      final PlannerEvent e = PlannerEvent(
        id: widget.existingEvent?.id ?? IdGen.next('ev'),
        title: _title.text.trim(),
        type: _type,
        start: DateTime(_date.year, _date.month, _date.day, _startTime.hour,
            _startTime.minute),
        durationMinutes: _eventDuration,
        location: _location.text.trim(),
        note: _note.text.trim(),
        colorValue: _colorValue,
        done: widget.existingEvent?.done ?? false,
        reminderLeadMinutes: _reminderLeadMinutes,
        alertType: _alert,
      );
      if (widget.existingEvent != null) {
        store.updateEvent(e);
      } else {
        store.addEvent(e);
      }
    }

    Navigator.pop(context);
    showSnack(context, _isEdit ? 'Updated' : 'Added to planner');
  }

  @override
  Widget build(BuildContext context) {
    return SheetScaffold(
      title: _isEdit ? 'Edit item' : 'Add to planner',
      actionLabel:
          _isEdit ? 'Save changes' : 'Add ${_type.label.toLowerCase()}',
      actionColor: AppColors.planner,
      onAction: _save,
      children: <Widget>[
        Row(
          children: <Widget>[
            for (final PlannerItemType t in PlannerItemType.values) ...<Widget>[
              Expanded(child: _typeButton(t)),
              if (t != PlannerItemType.task) const SizedBox(width: 6),
            ],
          ],
        ),
        const SizedBox(height: 14),
        FieldWrap(
          label: switch (_type) {
            PlannerItemType.habit => 'Habit name',
            PlannerItemType.event => 'Event title',
            PlannerItemType.appointment => 'Appointment title',
            PlannerItemType.task => 'Task title',
          },
          error: _titleError,
          child: TextField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: switch (_type) {
                PlannerItemType.habit => 'e.g. Morning jog',
                PlannerItemType.event => 'e.g. Team standup',
                PlannerItemType.appointment => 'e.g. Dr. Mehta follow-up',
                PlannerItemType.task => 'e.g. Pay electricity bill',
              },
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        if (_type == PlannerItemType.habit) ..._habitFields(),
        if (_type != PlannerItemType.habit) ..._eventFields(),
        _colorPicker(),
        _optionalSection(),
      ],
    );
  }

  Widget _typeButton(PlannerItemType t) {
    final bool active = _type == t;
    final IconData icon = switch (t) {
      PlannerItemType.habit => Icons.repeat,
      PlannerItemType.event => Icons.event_outlined,
      PlannerItemType.appointment => Icons.medical_services_outlined,
      PlannerItemType.task => Icons.check_box_outlined,
    };
    return InkWell(
      onTap: () => setState(() {
        _type = t;
        _submitted = false;
      }),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active
              ? AppColors.planner.withValues(alpha: 0.10)
              : Colors.transparent,
          border: Border.all(
            color: active ? AppColors.planner : context.hairline,
            width: active ? 1.5 : 0.8,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: <Widget>[
            Icon(icon,
                size: 19,
                color: active ? AppColors.planner : context.txtSecondary),
            const SizedBox(height: 3),
            Text(
              t.label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                color: active ? AppColors.planner : context.txtSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _habitFields() {
    return <Widget>[
      Row(
        children: <Widget>[
          Expanded(
            child: FieldWrap(
              label: 'Duration',
              child: DropdownButtonFormField<int>(
                initialValue: _durationMinutes,
                isExpanded: true,
                items: <DropdownMenuItem<int>>[
                  for (final int m in <int>[5, 10, 15, 20, 30, 45, 60, 90])
                    DropdownMenuItem<int>(value: m, child: Text('$m min')),
                ],
                onChanged: (int? v) =>
                    setState(() => _durationMinutes = v ?? 30),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FieldWrap(
              label: 'Preferred time',
              child: InkWell(
                onTap: () async {
                  final TimeOfDay? p = await showTimePicker(
                      context: context, initialTime: _preferredTime);
                  if (p != null && mounted) setState(() => _preferredTime = p);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(),
                  child: Row(
                    children: <Widget>[
                      Expanded(child: Text(formatTimeOfDay(_preferredTime))),
                      const Icon(Icons.expand_more, size: 18),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      FieldWrap(
        label: 'Repeat',
        error: _daysError,
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          children: <Widget>[
            for (final RepeatPattern p in <RepeatPattern>[
              RepeatPattern.daily,
              RepeatPattern.specificDays,
              RepeatPattern.weekly,
              RepeatPattern.monthly,
            ])
              ChoicePill(
                label: p.label,
                selected: _repeat == p,
                onTap: () => setState(() => _repeat = p),
              ),
          ],
        ),
      ),
      if (_repeat == RepeatPattern.specificDays) _dayPicker(),
    ];
  }

  List<Widget> _eventFields() {
    return <Widget>[
      Row(
        children: <Widget>[
          Expanded(
            child: FieldWrap(
              label: 'Date',
              child: InkWell(
                onTap: () async {
                  final DateTime? p = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate:
                        DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
                  );
                  if (p != null && mounted) setState(() => _date = p);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          fmtShortDate.format(_date),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      const Icon(Icons.calendar_today_outlined, size: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FieldWrap(
              label: 'Start time',
              child: InkWell(
                onTap: () async {
                  final TimeOfDay? p = await showTimePicker(
                      context: context, initialTime: _startTime);
                  if (p != null && mounted) setState(() => _startTime = p);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(),
                  child: Row(
                    children: <Widget>[
                      Expanded(child: Text(formatTimeOfDay(_startTime))),
                      const Icon(Icons.expand_more, size: 18),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      if (_type != PlannerItemType.task)
        FieldWrap(
          label: 'Duration',
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              for (final int m in <int>[15, 30, 45, 60, 90, 120, 180])
                ChoicePill(
                  label: m >= 60
                      ? '${(m / 60).toStringAsFixed(m % 60 == 0 ? 0 : 1)} hr'
                      : '$m min',
                  selected: _eventDuration == m,
                  onTap: () => setState(() => _eventDuration = m),
                ),
            ],
          ),
        ),
      FieldWrap(
        label: _type == PlannerItemType.appointment
            ? 'Clinic / hospital'
            : 'Location (optional)',
        child: TextField(
          controller: _location,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: _type == PlannerItemType.appointment
                ? 'e.g. Kokilaben Hospital'
                : 'e.g. Google Meet',
            prefixIcon: const Icon(Icons.place_outlined, size: 18),
          ),
        ),
      ),
      FieldWrap(
        label: 'Remind me before',
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          children: <Widget>[
            ChoicePill(
              label: 'No reminder',
              selected: _reminderLeadMinutes == null,
              onTap: () => setState(() => _reminderLeadMinutes = null),
            ),
            for (final int m in <int>[10, 30, 60, 1440])
              ChoicePill(
                label: m == 1440 ? '1 day' : '$m min',
                selected: _reminderLeadMinutes == m,
                onTap: () => setState(() => _reminderLeadMinutes = m),
              ),
          ],
        ),
      ),
      // The alert tier was previously hardcoded to Alarm for every event.
      if (_reminderLeadMinutes != null)
        AlertTypeSelector(
          value: _alert,
          onChanged: (AlertType t) => setState(() => _alert = t),
        ),
    ];
  }

  Widget _dayPicker() {
    const List<String> labels = <String>['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return FieldWrap(
      label: 'Days',
      error: _daysError,
      child: Row(
        children: <Widget>[
          for (int i = 1; i <= 7; i++) ...<Widget>[
            InkWell(
              onTap: () => setState(() {
                if (_days.contains(i)) {
                  _days.remove(i);
                } else {
                  _days.add(i);
                }
              }),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _days.contains(i)
                      ? AppColors.planner.withValues(alpha: 0.12)
                      : Colors.transparent,
                  border: Border.all(
                    color: _days.contains(i)
                        ? AppColors.planner
                        : context.hairline,
                    width: _days.contains(i) ? 1.4 : 0.8,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  labels[i - 1],
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        _days.contains(i) ? FontWeight.w600 : FontWeight.w400,
                    color: _days.contains(i)
                        ? AppColors.planner
                        : context.txtSecondary,
                  ),
                ),
              ),
            ),
            if (i != 7) const SizedBox(width: 5),
          ],
        ],
      ),
    );
  }

  /// PRD 3.3 FR2 — colour is required with a sensible default and is used
  /// consistently in Plan view, Day view and Home streak cards.
  Widget _colorPicker() {
    return FieldWrap(
      label: 'Colour tag',
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        children: <Widget>[
          for (final Color c in AppColors.picker)
            InkWell(
              onTap: () => setState(() => _colorValue = c.toARGB32()),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: _colorValue == c.toARGB32()
                      ? Border.all(color: context.txtPrimary, width: 2)
                      : null,
                ),
                child: _colorValue == c.toARGB32()
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
            ),
        ],
      ),
    );
  }

  Widget _optionalSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 4),
        Text(
          'OPTIONAL',
          style: TextStyle(
            fontSize: 10.5,
            letterSpacing: 0.6,
            fontWeight: FontWeight.w600,
            color: context.txtTertiary,
          ),
        ),
        const SizedBox(height: 7),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: <Widget>[
            if (_type == PlannerItemType.habit)
              ChoicePill(
                label: _goalStreak == null
                    ? 'Set goal'
                    : 'Goal: $_goalStreak days',
                icon: Icons.flag_outlined,
                selected: _goalStreak != null,
                onTap: _promptGoal,
              ),
            ChoicePill(
              label: _note.text.isEmpty ? 'Add note' : 'Note added',
              icon: Icons.notes,
              selected: _note.text.isNotEmpty,
              onTap: _promptNote,
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _promptGoal() async {
    final int? v = await showDialog<int>(
      context: context,
      builder: (BuildContext ctx) => SimpleDialog(
        title: const Text('Target streak'),
        children: <Widget>[
          for (final int g in <int>[7, 14, 30, 60, 100])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, g),
              child: Text('$g days'),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, -1),
            child: const Text('No goal'),
          ),
        ],
      ),
    );
    if (v != null) setState(() => _goalStreak = v == -1 ? null : v);
  }

  Future<void> _promptNote() async {
    final TextEditingController c = TextEditingController(text: _note.text);
    final String? v = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Note'),
        content: TextField(
          controller: c,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Add a note…'),
        ),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, c.text),
              child: const Text('Save')),
        ],
      ),
    );
    if (v != null) setState(() => _note.text = v);
  }
}
