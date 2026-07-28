import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/attachment_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_x.dart';
import '../../core/widgets/alert_type_selector.dart';
import '../../core/widgets/common.dart';
import '../../data/models/commitments.dart';
import '../../data/models/enums.dart';
import '../../data/models/expense.dart';
import '../../data/stores/commitments_store.dart';
import '../../data/stores/expense_store.dart';
import '../../data/stores/id_gen.dart';
import '../../data/stores/settings_store.dart';

/// PRD 7.3 — add / edit a membership, reusing the shared alert selector (2.3).
class AddMembershipSheet extends StatefulWidget {
  const AddMembershipSheet({super.key, this.existing});

  final Membership? existing;

  static Future<void> show(BuildContext context, {Membership? existing}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddMembershipSheet(existing: existing),
    );
  }

  @override
  State<AddMembershipSheet> createState() => _AddMembershipSheetState();
}

class _AddMembershipSheetState extends State<AddMembershipSheet> {
  late MembershipCategory _category;
  final TextEditingController _name = TextEditingController();
  final TextEditingController _location = TextEditingController();
  final TextEditingController _cost = TextEditingController();
  late BillingCycle _cycle;
  late DateTime _start;
  late DateTime _expiry;
  int _leadDays = 7;
  late AlertType _alert;
  int _repeatMinutes = 2;
  String? _cardPath;
  bool _linkToExpense = false;
  final TextEditingController _note = TextEditingController();
  bool _submitted = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final Membership? e = widget.existing;
    _category = e?.category ?? MembershipCategory.fitness;
    _cycle = e?.cycle ?? BillingCycle.monthly;
    _start = e?.startDate ?? DateTime.now();
    _expiry = e?.expiryDate ?? DateTime.now().add(const Duration(days: 30));
    _leadDays = e?.reminderLeadDays ?? 7;
    _alert = e?.alertType ?? context.read<SettingsStore>().defaultAlertType;
    if (e != null) {
      _name.text = e.name;
      _location.text = e.location;
      _cost.text = e.cost.toStringAsFixed(0);
      _note.text = e.note;
      _cardPath = e.cardImagePath;
      _repeatMinutes = e.forceConfirmIntervalMinutes;
      _linkToExpense = e.linkedExpenseId != null;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _location.dispose();
    _cost.dispose();
    _note.dispose();
    super.dispose();
  }

  String? get _nameError {
    if (!_submitted) return null;
    return _name.text.trim().isEmpty ? 'Membership name is required' : null;
  }

  String? get _costError {
    if (!_submitted) return null;
    final double? v = double.tryParse(_cost.text.trim());
    if (v == null) return 'Enter a valid cost';
    if (v <= 0) return 'Cost must be greater than zero';
    return null;
  }

  /// PRD 7.3 AC1 — expiry must be strictly after start.
  String? get _dateError {
    if (!_submitted) return null;
    return !_expiry.isAfter(_start)
        ? 'Expiry date must be after the start date'
        : null;
  }

  bool get _isValid {
    final double? c = double.tryParse(_cost.text.trim());
    return _name.text.trim().isNotEmpty &&
        c != null &&
        c > 0 &&
        _expiry.isAfter(_start);
  }

  void _save() {
    setState(() => _submitted = true);
    if (!_isValid) return;

    final CommitmentsStore store = context.read<CommitmentsStore>();
    final int paise = ((double.tryParse(_cost.text.trim()) ?? 0) * 100).round();

    String? linkedId = widget.existing?.linkedExpenseId;

    // PRD 7.3 AC2 — creates a matching recurring transaction in Expenses.
    if (_linkToExpense && linkedId == null) {
      final ExpenseStore expenses = context.read<ExpenseStore>();
      final String txnId = IdGen.next('txn');
      expenses.add(ExpenseTransaction(
        id: txnId,
        type: TransactionType.recurring,
        amountPaise: paise,
        description: _name.text.trim(),
        categoryId: expenses.categories.last.id,
        date: DateTime.now(),
        recurringCycle: _cycle,
        note: 'Auto-created from membership',
      ));
      linkedId = txnId;
    }

    final Membership m = Membership(
      id: widget.existing?.id ?? IdGen.next('mem'),
      name: _name.text.trim(),
      category: _category,
      costPaise: paise,
      cycle: _cycle,
      startDate: _start,
      expiryDate: _expiry,
      location: _location.text.trim(),
      reminderLeadDays: _leadDays,
      alertType: _alert,
      reminderEnabled: widget.existing?.reminderEnabled ?? true,
      active: widget.existing?.active ?? true,
      linkedExpenseId: linkedId,
      note: _note.text.trim(),
      // Collected by the alert selector but previously never stored.
      forceConfirmIntervalMinutes: _repeatMinutes,
      remindLaterUntil: widget.existing?.remindLaterUntil,
      cardImagePath: _cardPath,
      history: widget.existing?.history,
    );

    if (_isEdit) {
      store.updateMembership(m);
    } else {
      store.addMembership(m);
    }
    Navigator.pop(context);
    showSnack(context, _isEdit ? 'Membership updated' : 'Membership saved');
  }

  @override
  Widget build(BuildContext context) {
    return SheetScaffold(
      title: _isEdit ? 'Edit membership' : 'Add membership',
      actionLabel: _isEdit ? 'Save changes' : 'Save membership',
      actionColor: AppColors.memberships,
      onAction: _save,
      children: <Widget>[
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          childAspectRatio: 3.6,
          children: <Widget>[
            for (final MembershipCategory c in MembershipCategory.values)
              _categoryChip(c),
          ],
        ),
        const SizedBox(height: 14),
        FieldWrap(
          label: 'Membership name',
          error: _nameError,
          child: TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'e.g. Cult.fit gym'),
            onChanged: (_) => setState(() {}),
          ),
        ),
        FieldWrap(
          label: 'Location / centre',
          child: TextField(
            controller: _location,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              hintText: 'e.g. Andheri West branch',
              prefixIcon: Icon(Icons.place_outlined, size: 18),
            ),
          ),
        ),
        Row(
          children: <Widget>[
            Expanded(
              child: FieldWrap(
                label: 'Cost',
                error: _costError,
                child: TextField(
                  controller: _cost,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(prefixText: '₹ '),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FieldWrap(
                label: 'Billing cycle',
                child: DropdownButtonFormField<BillingCycle>(
                  initialValue: _cycle,
                  isExpanded: true,
                  items: <DropdownMenuItem<BillingCycle>>[
                    for (final BillingCycle c in BillingCycle.values)
                      DropdownMenuItem<BillingCycle>(
                          value: c, child: Text(c.label)),
                  ],
                  onChanged: (BillingCycle? v) =>
                      setState(() => _cycle = v ?? BillingCycle.monthly),
                ),
              ),
            ),
          ],
        ),
        FieldWrap(
          label: 'Validity',
          error: _dateError,
          child: Row(
            children: <Widget>[
              Expanded(
                child: _dateField(context, 'Start', _start, (DateTime d) {
                  setState(() => _start = d);
                }),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _dateField(context, 'Expiry', _expiry, (DateTime d) {
                  setState(() => _expiry = d);
                }),
              ),
            ],
          ),
        ),
        FieldWrap(
          label: 'Remind me before expiry',
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              for (final int d in <int>[3, 7, 15, 30])
                ChoicePill(
                  label: d == 30 ? '1 month' : '$d days',
                  selected: _leadDays == d,
                  color: AppColors.memberships,
                  onTap: () => setState(() => _leadDays = d),
                ),
            ],
          ),
        ),
        // PRD 7.3 AC3 — the exact same shared component as Reminders.
        AlertTypeSelector(
          value: _alert,
          onChanged: (AlertType t) => setState(() => _alert = t),
          repeatMinutes: _repeatMinutes,
          onRepeatChanged: (int m) => setState(() => _repeatMinutes = m),
        ),
        const Divider(height: 20),
        Text(
          'OPTIONAL',
          style: TextStyle(
            fontSize: 10.5,
            letterSpacing: 0.6,
            fontWeight: FontWeight.w600,
            color: context.txtTertiary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: <Widget>[
            ChoicePill(
              label: _cardPath == null
                  ? 'Scan membership card'
                  : 'Card attached',
              icon: Icons.camera_alt_outlined,
              selected: _cardPath != null,
              color: AppColors.memberships,
              onTap: _scanCard,
            ),
            ChoicePill(
              label: 'Link to expense',
              icon: Icons.link,
              selected: _linkToExpense,
              color: AppColors.memberships,
              onTap: () => setState(() => _linkToExpense = !_linkToExpense),
            ),
            ChoicePill(
              label: _note.text.isEmpty ? 'Add note' : 'Note added',
              icon: Icons.notes,
              selected: _note.text.isNotEmpty,
              color: AppColors.memberships,
              onTap: _promptNote,
            ),
          ],
        ),
        if (_linkToExpense) ...<Widget>[
          const SizedBox(height: 10),
          InfoBanner(
            tone: ChipTone.info,
            icon: Icons.currency_rupee,
            text: 'A recurring ${_cycle.label.toLowerCase()} transaction of '
                '₹${_cost.text.isEmpty ? '0' : _cost.text} will be created in '
                'Expenses so this cost is tracked automatically.',
          ),
        ],
      ],
    );
  }

  Widget _categoryChip(MembershipCategory c) {
    final bool sel = _category == c;
    final IconData icon = switch (c) {
      MembershipCategory.fitness => Icons.fitness_center,
      MembershipCategory.health => Icons.medical_services_outlined,
      MembershipCategory.club => Icons.location_city_outlined,
      MembershipCategory.other => Icons.card_membership,
    };
    final String label = switch (c) {
      MembershipCategory.fitness => 'Fitness / Gym',
      MembershipCategory.health => 'Health plan',
      MembershipCategory.club => 'Club',
      MembershipCategory.other => 'Other',
    };
    return InkWell(
      onTap: () => setState(() => _category = c),
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: sel
              ? AppColors.memberships.withValues(alpha: 0.12)
              : Colors.transparent,
          border: Border.all(
            color: sel ? AppColors.memberships : context.hairline,
            width: sel ? 1.5 : 0.8,
          ),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          children: <Widget>[
            Icon(icon,
                size: 16,
                color: sel ? AppColors.memberships : context.txtSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                  color: sel ? AppColors.memberships : context.txtSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateField(BuildContext context, String label, DateTime value,
      ValueChanged<DateTime> onChanged) {
    return InkWell(
      onTap: () async {
        final DateTime? p = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (p != null) onChanged(p);
      },
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(
          '${fmtShortDate.format(value)} ${value.year}',
          style: const TextStyle(fontSize: 13),
        ),
      ),
    );
  }

  Future<void> _promptNote() async {
    final TextEditingController c = TextEditingController(text: _note.text);
    final String? v = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Note'),
        content: TextField(controller: c, maxLines: 3),
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

  /// Photographs the physical card and stores it with the membership.
  Future<void> _scanCard() async {
    if (_cardPath != null) {
      setState(() => _cardPath = null);
      return;
    }
    final bool? camera = await showModalBottomSheet<bool>(
      context: context,
      builder: (BuildContext c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Photograph the card'),
              onTap: () => Navigator.pop(c, true),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from photos'),
              onTap: () => Navigator.pop(c, false),
            ),
          ],
        ),
      ),
    );
    if (camera == null) return;
    final String? path =
        await AttachmentService.pickImage(fromCamera: camera);
    if (path == null || !mounted) return;
    setState(() => _cardPath = path);
  }
}
