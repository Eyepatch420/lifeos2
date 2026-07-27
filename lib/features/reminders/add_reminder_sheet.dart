import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_x.dart';
import '../../core/widgets/alert_type_selector.dart';
import '../../core/widgets/common.dart';
import '../../data/models/enums.dart';
import '../../data/models/reminder.dart';
import '../../data/stores/id_gen.dart';
import '../../data/stores/reminder_store.dart';
import '../../data/stores/settings_store.dart';

/// PRD 2.2 — Add / edit reminder with three independent tabs
/// (Medicine / Water / Custom) plus the shared alert-type step (2.3).
class AddReminderSheet extends StatefulWidget {
  const AddReminderSheet({super.key, this.existing, this.initialType});

  final Reminder? existing;
  final ReminderType? initialType;

  static Future<void> show(BuildContext context,
      {Reminder? existing, ReminderType? initialType}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          AddReminderSheet(existing: existing, initialType: initialType),
    );
  }

  @override
  State<AddReminderSheet> createState() => _AddReminderSheetState();
}

class _AddReminderSheetState extends State<AddReminderSheet> {
  late ReminderType _type;

  // Shared
  final TextEditingController _title = TextEditingController();
  TimeOfDay _time = const TimeOfDay(hour: 8, minute: 0);
  RepeatPattern _repeat = RepeatPattern.daily;
  Set<int> _days = <int>{1, 2, 3, 4, 5};
  int _everyXHours = 2;
  late AlertType _alert;
  int _repeatMinutes = 2;
  String? _dependencyId;
  bool _submitted = false;

  // Medicine
  final TextEditingController _dose = TextEditingController();
  String _form = 'Tablet';
  String _duration = 'Ongoing';
  bool _attachPrescription = false;
  final TextEditingController _cost = TextEditingController();

  // Water
  int _goalMl = 2500;
  int _fromHour = 7;
  int _untilHour = 22;
  int _perReminderMl = 250;

  // Custom
  final TextEditingController _note = TextEditingController();
  int _iconCode = Icons.directions_walk.codePoint;
  String _notifStyle = 'Sound';

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final Reminder? e = widget.existing;
    _type = e?.type ?? widget.initialType ?? ReminderType.medicine;
    _alert = e?.alertType ??
        context.read<SettingsStore>().defaultAlertType; // PRD 10.1 FR1

    if (e != null) {
      _title.text = e.title;
      _time = e.time;
      _repeat = e.repeat;
      _days = Set<int>.from(e.specificDays.isEmpty ? _days : e.specificDays);
      _everyXHours = e.everyXHours;
      _repeatMinutes = e.forceConfirmIntervalMinutes;
      _dependencyId = e.dependencyId;
      _dose.text = e.dose;
      _form = e.form.isEmpty ? 'Tablet' : e.form;
      _duration = e.duration;
      _note.text = e.note;
      _iconCode = e.iconCodePoint;
    } else {
      final WaterConfig w = context.read<ReminderStore>().water;
      _goalMl = w.goalMl;
      _fromHour = w.fromHour;
      _untilHour = w.untilHour;
      _perReminderMl = w.amountPerReminderMl;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _dose.dispose();
    _cost.dispose();
    _note.dispose();
    super.dispose();
  }

  // ---- validation (PRD 2.2 AC1/AC2) ------------------------------------

  String? get _titleError {
    if (_type == ReminderType.water) return null;
    if (!_submitted) return null;
    return _title.text.trim().isEmpty
        ? (_type == ReminderType.medicine
            ? 'Medicine name is required'
            : 'Title is required')
        : null;
  }

  String? get _daysError {
    if (!_submitted) return null;
    if (_repeat != RepeatPattern.specificDays) return null;
    return _days.isEmpty ? 'Select at least one day' : null;
  }

  String? get _waterWindowError {
    if (!_submitted || _type != ReminderType.water) return null;
    return _untilHour <= _fromHour
        ? 'The "until" time must be after the "from" time'
        : null;
  }

  bool get _isValid =>
      (_type == ReminderType.water || _title.text.trim().isNotEmpty) &&
      (_repeat != RepeatPattern.specificDays || _days.isNotEmpty) &&
      (_type != ReminderType.water || _untilHour > _fromHour);

  void _save() {
    setState(() => _submitted = true);
    if (!_isValid) return;

    final ReminderStore store = context.read<ReminderStore>();

    if (_type == ReminderType.water) {
      // Water config is global, not a per-row record.
      store.updateWaterConfig(
        goalMl: _goalMl,
        everyHours: _everyXHours,
        fromHour: _fromHour,
        untilHour: _untilHour,
        amountPerReminderMl: _perReminderMl,
      );
    }

    final Reminder r = Reminder(
      id: widget.existing?.id ?? IdGen.next('rem'),
      title:
          _type == ReminderType.water ? 'Water reminder' : _title.text.trim(),
      type: _type,
      time: _type == ReminderType.water
          ? TimeOfDay(hour: _fromHour, minute: 0)
          : _time,
      subtitle: _buildSubtitle(),
      dose: _dose.text.trim(),
      form: _form,
      repeat: _type == ReminderType.water ? RepeatPattern.everyXHours : _repeat,
      specificDays: _days,
      everyXHours: _everyXHours,
      duration: _duration,
      alertType: _alert,
      forceConfirmIntervalMinutes: _repeatMinutes,
      enabled: widget.existing?.enabled ?? true,
      iconCodePoint: _iconForType(),
      colorValue: _colorForType(),
      dependencyId: _dependencyId,
      note: _note.text.trim(),
      completions: widget.existing?.completions,
    );

    if (_isEdit) {
      store.update(r);
    } else {
      store.add(r);
    }
    Navigator.pop(context);
    showSnack(context, _isEdit ? 'Reminder updated' : 'Reminder saved');
  }

  String _buildSubtitle() {
    switch (_type) {
      case ReminderType.medicine:
        final String d = _dose.text.trim();
        return <String>[
          if (d.isNotEmpty) d,
          if (_form.isNotEmpty) _form,
        ].join(' · ');
      case ReminderType.water:
        return '$_perReminderMl ml · Every $_everyXHours hrs';
      case ReminderType.custom:
        return _note.text.trim().isEmpty ? 'Custom' : _note.text.trim();
    }
  }

  int _iconForType() => switch (_type) {
        ReminderType.medicine => Icons.medication_outlined.codePoint,
        ReminderType.water => Icons.water_drop_outlined.codePoint,
        ReminderType.custom => _iconCode,
      };

  int _colorForType() => switch (_type) {
        ReminderType.medicine => 0xFF3B6D11,
        ReminderType.water => 0xFF185FA5,
        ReminderType.custom => 0xFF854F0B,
      };

  @override
  Widget build(BuildContext context) {
    return SheetScaffold(
      title: _isEdit ? 'Edit reminder' : 'New reminder',
      actionLabel: _isEdit ? 'Save changes' : 'Save reminder',
      actionColor: AppColors.reminders,
      onAction: _save,
      children: <Widget>[
        // Type tabs. Switching tabs does NOT carry values across (PRD 2.2 FR1).
        Row(
          children: <Widget>[
            for (final ReminderType t in ReminderType.values) ...<Widget>[
              Expanded(child: _typeButton(t)),
              if (t != ReminderType.custom) const SizedBox(width: 7),
            ],
          ],
        ),
        const SizedBox(height: 14),
        if (_type == ReminderType.medicine) ..._medicineFields(),
        if (_type == ReminderType.water) ..._waterFields(),
        if (_type == ReminderType.custom) ..._customFields(),
        const Divider(height: 24),
        AlertTypeSelector(
          value: _alert,
          onChanged: (AlertType t) => setState(() => _alert = t),
          repeatMinutes: _repeatMinutes,
          onRepeatChanged: (int m) => setState(() => _repeatMinutes = m),
        ),
        const SizedBox(height: 6),
      ],
    );
  }

  Widget _typeButton(ReminderType t) {
    final bool active = _type == t;
    final IconData icon = switch (t) {
      ReminderType.medicine => Icons.medication_outlined,
      ReminderType.water => Icons.water_drop_outlined,
      ReminderType.custom => Icons.notifications_none,
    };
    return InkWell(
      onTap: () => setState(() {
        _type = t;
        _submitted = false;
      }),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: active
              ? AppColors.reminders.withValues(alpha: 0.10)
              : Colors.transparent,
          border: Border.all(
            color: active ? AppColors.reminders : context.hairline,
            width: active ? 1.5 : 0.8,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: <Widget>[
            Icon(icon,
                size: 20,
                color: active ? AppColors.reminders : context.txtSecondary),
            const SizedBox(height: 4),
            Text(
              t.label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                color: active ? AppColors.reminders : context.txtSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- medicine tab -----------------------------------------------------

  List<Widget> _medicineFields() {
    return <Widget>[
      FieldWrap(
        label: 'Medicine name',
        error: _titleError,
        child: TextField(
          controller: _title,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'e.g. Metformin 500mg'),
          onChanged: (_) => setState(() {}),
        ),
      ),
      Row(
        children: <Widget>[
          Expanded(
            child: FieldWrap(
              label: 'Dose',
              child: TextField(
                controller: _dose,
                decoration: const InputDecoration(hintText: '500 mg'),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FieldWrap(
              label: 'Form',
              child: DropdownButtonFormField<String>(
                initialValue: _form,
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem<String>(
                      value: 'Tablet', child: Text('Tablet')),
                  DropdownMenuItem<String>(
                      value: 'Capsule', child: Text('Capsule')),
                  DropdownMenuItem<String>(
                      value: 'Syrup', child: Text('Syrup')),
                  DropdownMenuItem<String>(
                      value: 'Injection', child: Text('Injection')),
                  DropdownMenuItem<String>(
                      value: 'Drops', child: Text('Drops')),
                ],
                onChanged: (String? v) => setState(() => _form = v ?? 'Tablet'),
              ),
            ),
          ),
        ],
      ),
      _timeField(),
      _repeatField(),
      if (_repeat == RepeatPattern.specificDays) _dayPicker(),
      if (_repeat == RepeatPattern.everyXHours) _hoursField(),
      FieldWrap(
        label: 'Duration',
        child: DropdownButtonFormField<String>(
          initialValue: _duration,
          items: const <DropdownMenuItem<String>>[
            DropdownMenuItem<String>(value: 'Ongoing', child: Text('Ongoing')),
            DropdownMenuItem<String>(value: '7 days', child: Text('7 days')),
            DropdownMenuItem<String>(value: '14 days', child: Text('14 days')),
            DropdownMenuItem<String>(value: '1 month', child: Text('1 month')),
            DropdownMenuItem<String>(
                value: '3 months', child: Text('3 months')),
          ],
          onChanged: (String? v) => setState(() => _duration = v ?? 'Ongoing'),
        ),
      ),
      _optionalSection(<Widget>[
        ChoicePill(
          label: 'Attach prescription',
          icon: Icons.description_outlined,
          selected: _attachPrescription,
          onTap: () =>
              setState(() => _attachPrescription = !_attachPrescription),
        ),
        _dependencyPill(),
        ChoicePill(
          label: _cost.text.isEmpty ? 'Log cost' : 'Cost ₹${_cost.text}',
          icon: Icons.currency_rupee,
          selected: _cost.text.isNotEmpty,
          onTap: _promptCost,
        ),
      ]),
    ];
  }

  // ---- water tab --------------------------------------------------------

  List<Widget> _waterFields() {
    return <Widget>[
      FieldWrap(
        label: 'Daily goal',
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Slider(
                    value: _goalMl.toDouble(),
                    min: 500,
                    max: 5000,
                    divisions: 45,
                    label: '${(_goalMl / 1000).toStringAsFixed(1)} L',
                    activeColor: AppColors.info,
                    onChanged: (double v) =>
                        setState(() => _goalMl = (v / 100).round() * 100),
                  ),
                ),
                SizedBox(
                  width: 52,
                  child: Text(
                    '${(_goalMl / 1000).toStringAsFixed(1)} L',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.info,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Presets stay in sync with the slider (PRD 2.2 FR5): dragging to a
            // non-preset value deselects all pills.
            Wrap(
              spacing: 6,
              children: <Widget>[
                for (final int ml in <int>[1500, 2000, 2500, 3000])
                  ChoicePill(
                    label: '${(ml / 1000).toStringAsFixed(1)} L',
                    selected: _goalMl == ml,
                    color: AppColors.info,
                    onTap: () => setState(() => _goalMl = ml),
                  ),
              ],
            ),
          ],
        ),
      ),
      FieldWrap(
        label: 'Remind every',
        child: Wrap(
          spacing: 6,
          children: <Widget>[
            for (final int h in <int>[1, 2, 3, 4])
              ChoicePill(
                label: '$h hr${h > 1 ? 's' : ''}',
                selected: _everyXHours == h,
                color: AppColors.info,
                onTap: () => setState(() => _everyXHours = h),
              ),
          ],
        ),
      ),
      FieldWrap(
        label: 'Active hours',
        error: _waterWindowError,
        child: Row(
          children: <Widget>[
            Expanded(
              child: _hourDropdown(
                  'From', _fromHour, (int v) => setState(() => _fromHour = v)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _hourDropdown('Until', _untilHour,
                  (int v) => setState(() => _untilHour = v)),
            ),
          ],
        ),
      ),
      FieldWrap(
        label: 'Amount per reminder',
        child: Wrap(
          spacing: 6,
          children: <Widget>[
            for (final int ml in <int>[150, 250, 500])
              ChoicePill(
                label: '$ml ml',
                selected: _perReminderMl == ml,
                color: AppColors.info,
                onTap: () => setState(() => _perReminderMl = ml),
              ),
          ],
        ),
      ),
      InfoBanner(
        tone: ChipTone.info,
        icon: Icons.schedule,
        text: 'Reminders will fire roughly every $_everyXHours hrs between '
            '${_fmtHour(_fromHour)} and ${_fmtHour(_untilHour)} '
            '(${_occurrenceCount()} reminders/day).',
      ),
    ];
  }

  int _occurrenceCount() {
    if (_untilHour <= _fromHour || _everyXHours <= 0) return 0;
    return ((_untilHour - _fromHour) / _everyXHours).floor() + 1;
  }

  String _fmtHour(int h) =>
      formatTimeOfDay(TimeOfDay(hour: h.clamp(0, 23), minute: 0));

  Widget _hourDropdown(String label, int value, ValueChanged<int> onChanged) {
    return DropdownButtonFormField<int>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: <DropdownMenuItem<int>>[
        for (int h = 0; h < 24; h++)
          DropdownMenuItem<int>(value: h, child: Text(_fmtHour(h))),
      ],
      onChanged: (int? v) => onChanged(v ?? value),
    );
  }

  // ---- custom tab -------------------------------------------------------

  List<Widget> _customFields() {
    const List<IconData> icons = <IconData>[
      Icons.directions_walk,
      Icons.favorite_outline,
      Icons.menu_book_outlined,
      Icons.self_improvement,
      Icons.call_outlined,
      Icons.cleaning_services_outlined,
      Icons.pets_outlined,
      Icons.more_horiz,
    ];
    return <Widget>[
      FieldWrap(
        label: 'Title',
        error: _titleError,
        child: TextField(
          controller: _title,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'e.g. Evening walk'),
          onChanged: (_) => setState(() {}),
        ),
      ),
      FieldWrap(
        label: 'Note (optional)',
        child: TextField(
          controller: _note,
          maxLines: 2,
          decoration: const InputDecoration(hintText: 'Add a note…'),
        ),
      ),
      FieldWrap(
        label: 'Icon',
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final IconData i in icons)
              InkWell(
                onTap: () => setState(() => _iconCode = i.codePoint),
                borderRadius: BorderRadius.circular(9),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _iconCode == i.codePoint
                        ? AppColors.infoBg
                        : Colors.transparent,
                    border: Border.all(
                      color: _iconCode == i.codePoint
                          ? AppColors.info
                          : context.hairline,
                      width: _iconCode == i.codePoint ? 1.5 : 0.8,
                    ),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(i,
                      size: 18,
                      color: _iconCode == i.codePoint
                          ? AppColors.info
                          : context.txtSecondary),
                ),
              ),
          ],
        ),
      ),
      Row(
        children: <Widget>[
          Expanded(child: _timeField()),
          const SizedBox(width: 10),
          Expanded(child: _repeatField(compact: true)),
        ],
      ),
      if (_repeat == RepeatPattern.specificDays) _dayPicker(),
      FieldWrap(
        label: 'Notification style',
        child: Wrap(
          spacing: 6,
          children: <Widget>[
            for (final String s in <String>['Sound', 'Vibrate', 'Silent'])
              ChoicePill(
                label: s,
                selected: _notifStyle == s,
                onTap: () => setState(() => _notifStyle = s),
              ),
          ],
        ),
      ),
      _optionalSection(<Widget>[_dependencyPill()]),
    ];
  }

  // ---- shared field builders -------------------------------------------

  Widget _timeField() {
    return FieldWrap(
      label: 'Time',
      child: InkWell(
        onTap: () async {
          final TimeOfDay? picked =
              await showTimePicker(context: context, initialTime: _time);
          if (picked != null) setState(() => _time = picked);
        },
        borderRadius: BorderRadius.circular(9),
        child: InputDecorator(
          decoration: const InputDecoration(),
          child: Row(
            children: <Widget>[
              const Icon(Icons.schedule, size: 17, color: AppColors.info),
              const SizedBox(width: 8),
              Expanded(child: Text(formatTimeOfDay(_time))),
              const Icon(Icons.expand_more, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _repeatField({bool compact = false}) {
    final List<RepeatPattern> options = _type == ReminderType.medicine
        ? <RepeatPattern>[
            RepeatPattern.daily,
            RepeatPattern.specificDays,
            RepeatPattern.everyXHours,
            RepeatPattern.sos,
          ]
        : <RepeatPattern>[
            RepeatPattern.daily,
            RepeatPattern.specificDays,
            RepeatPattern.weekly,
            RepeatPattern.monthly,
          ];

    if (compact) {
      return FieldWrap(
        label: 'Frequency',
        error: _daysError,
        child: DropdownButtonFormField<RepeatPattern>(
          initialValue: options.contains(_repeat) ? _repeat : options.first,
          isExpanded: true,
          items: <DropdownMenuItem<RepeatPattern>>[
            for (final RepeatPattern p in options)
              DropdownMenuItem<RepeatPattern>(value: p, child: Text(p.label)),
          ],
          onChanged: (RepeatPattern? v) =>
              setState(() => _repeat = v ?? RepeatPattern.daily),
        ),
      );
    }

    return FieldWrap(
      label: 'Frequency',
      error: _daysError,
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: <Widget>[
          for (final RepeatPattern p in options)
            ChoicePill(
              label: p.label,
              selected: _repeat == p,
              onTap: () => setState(() => _repeat = p),
            ),
        ],
      ),
    );
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
                  color:
                      _days.contains(i) ? AppColors.infoBg : Colors.transparent,
                  border: Border.all(
                    color:
                        _days.contains(i) ? AppColors.info : context.hairline,
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
                        ? AppColors.info
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

  Widget _hoursField() {
    return FieldWrap(
      label: 'Every how many hours',
      child: Wrap(
        spacing: 6,
        children: <Widget>[
          for (final int h in <int>[2, 4, 6, 8, 12])
            ChoicePill(
              label: '$h hrs',
              selected: _everyXHours == h,
              onTap: () => setState(() => _everyXHours = h),
            ),
        ],
      ),
    );
  }

  Widget _optionalSection(List<Widget> chips) {
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
        Wrap(spacing: 6, runSpacing: 6, children: chips),
      ],
    );
  }

  /// PRD 2.1 FR7 / 2.2 FR6 — pick a reminder this one depends on.
  Widget _dependencyPill() {
    final ReminderStore store = context.read<ReminderStore>();
    final Reminder? dep =
        _dependencyId == null ? null : store.byId(_dependencyId!);
    return ChoicePill(
      label: dep == null ? 'Add dependency' : 'After: ${dep.title}',
      icon: Icons.link,
      selected: dep != null,
      onTap: () async {
        final List<Reminder> options = store.all
            .where((Reminder r) => r.id != widget.existing?.id)
            .toList();
        final String? picked = await showModalBottomSheet<String>(
          context: context,
          builder: (BuildContext ctx) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.clear),
                  title: const Text('No dependency'),
                  onTap: () => Navigator.pop(ctx, ''),
                ),
                for (final Reminder r in options)
                  ListTile(
                    leading: Icon(r.icon, color: r.color),
                    title: Text(r.title),
                    subtitle: Text(formatTimeOfDay(r.time)),
                    onTap: () => Navigator.pop(ctx, r.id),
                  ),
              ],
            ),
          ),
        );
        if (picked != null) {
          setState(() => _dependencyId = picked.isEmpty ? null : picked);
        }
      },
    );
  }

  Future<void> _promptCost() async {
    final TextEditingController c = TextEditingController(text: _cost.text);
    final String? v = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Log medicine cost'),
        content: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(prefixText: '₹ '),
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
    if (v != null) setState(() => _cost.text = v);
  }
}
