import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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

/// PRD 8.2 — add / edit a bill, subscription, EMI or credit card.
/// EMI now captures installment count + per-installment amount, closing the
/// gap the mockups left open.
class AddBillSheet extends StatefulWidget {
  const AddBillSheet({super.key, this.existing});

  final Bill? existing;

  static Future<void> show(BuildContext context, {Bill? existing}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddBillSheet(existing: existing),
    );
  }

  @override
  State<AddBillSheet> createState() => _AddBillSheetState();
}

class _AddBillSheetState extends State<AddBillSheet> {
  late BillKind _kind;
  final TextEditingController _name = TextEditingController();
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _installments = TextEditingController();
  final TextEditingController _paidSoFar = TextEditingController();
  late BillingCycle _cycle;
  late DateTime _dueDate;
  int? _dayOfMonth;
  int _leadDays = 3;
  late AlertType _alert;
  int _repeatMinutes = 2;
  bool _autoPay = false;
  String? _linkedCategoryId;
  bool _submitted = false;

  bool get _isEdit => widget.existing != null;
  bool get _isEmi => _kind == BillKind.emi;

  @override
  void initState() {
    super.initState();
    final Bill? e = widget.existing;
    _kind = e?.kind ?? BillKind.bill;
    _cycle = e?.cycle ?? BillingCycle.monthly;
    _dueDate = e?.dueDate ?? DateTime.now().add(const Duration(days: 7));
    _dayOfMonth = e?.dayOfMonth ?? _dueDate.day;
    _leadDays = e?.reminderLeadDays ?? 3;
    _alert = e?.alertType ?? context.read<SettingsStore>().defaultAlertType;
    _autoPay = e?.autoPay ?? false;
    _linkedCategoryId = e?.linkedCategoryId;
    if (e != null) {
      _name.text = e.name;
      _amount.text = e.amount.toStringAsFixed(0);
      _installments.text = (e.installmentsTotal ?? '').toString();
      _paidSoFar.text = e.installmentsPaid.toString();
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _installments.dispose();
    _paidSoFar.dispose();
    super.dispose();
  }

  String? get _nameError {
    if (!_submitted) return null;
    return _name.text.trim().isEmpty ? 'Name is required' : null;
  }

  String? get _amountError {
    if (!_submitted) return null;
    final double? v = double.tryParse(_amount.text.trim());
    if (v == null) return 'Enter a valid amount';
    if (v <= 0) return 'Amount must be greater than zero';
    return null;
  }

  /// PRD 8.2 AC3 — EMI requires a total installment count.
  String? get _installmentsError {
    if (!_submitted || !_isEmi) return null;
    final int? total = int.tryParse(_installments.text.trim());
    if (total == null || total <= 0) return 'Enter the total installments';
    final int paid = int.tryParse(_paidSoFar.text.trim()) ?? 0;
    if (paid > total) return 'Paid cannot exceed total installments';
    return null;
  }

  bool get _isValid {
    final double? amt = double.tryParse(_amount.text.trim());
    if (_name.text.trim().isEmpty || amt == null || amt <= 0) return false;
    if (_isEmi) {
      final int? total = int.tryParse(_installments.text.trim());
      final int paid = int.tryParse(_paidSoFar.text.trim()) ?? 0;
      if (total == null || total <= 0 || paid > total) return false;
    }
    return true;
  }

  void _save() {
    setState(() => _submitted = true);
    if (!_isValid) return;

    final CommitmentsStore store = context.read<CommitmentsStore>();
    final Bill b = Bill(
      id: widget.existing?.id ?? IdGen.next('bill'),
      name: _name.text.trim(),
      kind: _kind,
      amountPaise: ((double.tryParse(_amount.text.trim()) ?? 0) * 100).round(),
      cycle: _cycle,
      dueDate: _dueDate,
      dayOfMonth: _dayOfMonth,
      autoPay: _autoPay,
      reminderLeadDays: _leadDays,
      alertType: _alert,
      active: widget.existing?.active ?? true,
      installmentsPaid:
          _isEmi ? (int.tryParse(_paidSoFar.text.trim()) ?? 0) : 0,
      installmentsTotal:
          _isEmi ? int.tryParse(_installments.text.trim()) : null,
      linkedCategoryId: _linkedCategoryId,
      lastPaidOn: widget.existing?.lastPaidOn,
      // Collected by the alert selector but previously never stored.
      forceConfirmIntervalMinutes: _repeatMinutes,
      snoozedUntil: widget.existing?.snoozedUntil,
    );

    if (_isEdit) {
      store.updateBill(b);
    } else {
      store.addBill(b);
    }
    Navigator.pop(context);
    showSnack(context, _isEdit ? 'Updated' : 'Saved');
  }

  @override
  Widget build(BuildContext context) {
    final ExpenseStore expenses = context.watch<ExpenseStore>();

    return SheetScaffold(
      title: _isEdit
          ? 'Edit ${_kind.label.toLowerCase()}'
          : 'Add bill or subscription',
      actionLabel:
          _isEdit ? 'Save changes' : 'Save ${_kind.label.toLowerCase()}',
      actionColor: AppColors.bills,
      onAction: _save,
      children: <Widget>[
        Row(
          children: <Widget>[
            for (final BillKind k in BillKind.values) ...<Widget>[
              Expanded(child: _kindButton(k)),
              if (k != BillKind.creditCard) const SizedBox(width: 6),
            ],
          ],
        ),
        const SizedBox(height: 14),
        FieldWrap(
          label: 'Name',
          error: _nameError,
          child: TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: switch (_kind) {
                BillKind.bill => 'e.g. Electricity bill',
                BillKind.subscription => 'e.g. Netflix',
                BillKind.emi => 'e.g. MacBook EMI',
                BillKind.creditCard => 'e.g. HDFC credit card',
              },
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        Row(
          children: <Widget>[
            Expanded(
              child: FieldWrap(
                label: _isEmi ? 'Per installment' : 'Amount',
                error: _amountError,
                child: TextField(
                  controller: _amount,
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
                label: 'Frequency',
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
        // EMI-specific fields.
        if (_isEmi)
          FieldWrap(
            label: 'Installments',
            error: _installmentsError,
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _paidSoFar,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Paid so far'),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _installments,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Total'),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
          ),
        if (_isEmi && _isValid)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InfoBanner(
              tone: ChipTone.info,
              icon: Icons.calculate_outlined,
              text: 'Total loan '
                  '${formatRupees((double.tryParse(_amount.text) ?? 0) * (int.tryParse(_installments.text) ?? 0))}'
                  ' · remaining '
                  '${formatRupees((double.tryParse(_amount.text) ?? 0) * ((int.tryParse(_installments.text) ?? 0) - (int.tryParse(_paidSoFar.text) ?? 0)))}.',
            ),
          ),
        FieldWrap(
          label: 'Due date',
          child: Column(
            children: <Widget>[
              InkWell(
                onTap: () async {
                  final DateTime? p = await showDatePicker(
                    context: context,
                    initialDate: _dueDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (p != null && mounted) {
                    setState(() {
                      _dueDate = p;
                      _dayOfMonth = p.day;
                    });
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(),
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.calendar_today_outlined,
                          size: 16, color: AppColors.bills),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${fmtShortDate.format(_dueDate)} ${_dueDate.year}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      const Icon(Icons.expand_more, size: 18),
                    ],
                  ),
                ),
              ),
              if (_cycle == BillingCycle.monthly && _dayOfMonth != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Repeats on the ${_ordinal(_dayOfMonth!)} of every month. '
                      'In shorter months it moves to the last day.',
                      style: TextStyle(
                          fontSize: 11.5, color: context.txtSecondary),
                    ),
                  ),
                ),
            ],
          ),
        ),
        FieldWrap(
          label: 'Reminder before due',
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              for (final int d in <int>[1, 3, 7, 15])
                ChoicePill(
                  label: '$d day${d == 1 ? '' : 's'}',
                  selected: _leadDays == d,
                  color: AppColors.bills,
                  onTap: () => setState(() => _leadDays = d),
                ),
            ],
          ),
        ),
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
              label: _linkedCategoryId == null
                  ? 'Link to expense category'
                  : 'Category: ${expenses.categoryById(_linkedCategoryId!).name}',
              icon: Icons.link,
              selected: _linkedCategoryId != null,
              color: AppColors.bills,
              onTap: () => _pickCategory(expenses),
            ),
            ChoicePill(
              label: 'Auto-pay tracking',
              icon: Icons.credit_card,
              selected: _autoPay,
              color: AppColors.bills,
              onTap: () => setState(() => _autoPay = !_autoPay),
            ),
          ],
        ),
        // PRD 8.2 AC2 — makes the auto-pay behaviour explicit before saving.
        if (_autoPay) ...<Widget>[
          const SizedBox(height: 10),
          const InfoBanner(
            tone: ChipTone.success,
            icon: Icons.info_outline,
            text: 'Auto-pay is on: this will not appear in overdue or '
                'due-soon alerts, but it is still logged as paid on its due '
                'date for expense tracking.',
          ),
        ],
      ],
    );
  }

  Widget _kindButton(BillKind k) {
    final bool active = _kind == k;
    final IconData icon = switch (k) {
      BillKind.bill => Icons.receipt_outlined,
      BillKind.subscription => Icons.autorenew,
      BillKind.emi => Icons.account_balance_outlined,
      BillKind.creditCard => Icons.credit_card,
    };
    return InkWell(
      onTap: () => setState(() {
        _kind = k;
        _submitted = false;
      }),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: active
              ? AppColors.bills.withValues(alpha: 0.10)
              : Colors.transparent,
          border: Border.all(
            color: active ? AppColors.bills : context.hairline,
            width: active ? 1.5 : 0.8,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: <Widget>[
            Icon(icon,
                size: 18,
                color: active ? AppColors.bills : context.txtSecondary),
            const SizedBox(height: 3),
            Text(
              k.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                color: active ? AppColors.bills : context.txtSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickCategory(ExpenseStore expenses) async {
    final String? picked = await showModalBottomSheet<String>(
      context: context,
      builder: (BuildContext ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.link_off),
              title: const Text('No category'),
              onTap: () => Navigator.pop(ctx, ''),
            ),
            for (final BudgetCategory c in expenses.categories)
              ListTile(
                leading: Icon(c.icon, color: c.color),
                title: Text(c.name),
                onTap: () => Navigator.pop(ctx, c.id),
              ),
          ],
        ),
      ),
    );
    if (picked != null) {
      setState(() => _linkedCategoryId = picked.isEmpty ? null : picked);
    }
  }

  String _ordinal(int n) {
    if (n >= 11 && n <= 13) return '${n}th';
    return switch (n % 10) {
      1 => '${n}st',
      2 => '${n}nd',
      3 => '${n}rd',
      _ => '${n}th',
    };
  }
}
