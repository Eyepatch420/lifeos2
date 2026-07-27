import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/attachment_service.dart';
import '../../core/services/ocr_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_x.dart';
import '../../core/widgets/common.dart';
import '../../data/models/enums.dart';
import '../../data/models/expense.dart';
import '../../data/stores/expense_store.dart';
import '../../data/stores/id_gen.dart';

/// PRD 4.4 — add/edit a transaction. Closes PRD Gap 7 by fully specifying the
/// Transfer (destination account) and Recurring (cycle) type-specific fields.
class AddTransactionSheet extends StatefulWidget {
  const AddTransactionSheet({super.key, this.existing});

  final ExpenseTransaction? existing;

  static Future<void> show(BuildContext context,
      {ExpenseTransaction? existing}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddTransactionSheet(existing: existing),
    );
  }

  @override
  State<AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends State<AddTransactionSheet> {
  TransactionType _type = TransactionType.expense;
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _desc = TextEditingController();
  final TextEditingController _note = TextEditingController();
  final TextEditingController _account = TextEditingController();
  String? _categoryId;
  PaymentMethod _method = PaymentMethod.upi;
  DateTime _date = DateTime.now();
  BillingCycle _recurringCycle = BillingCycle.monthly;
  int _splitWays = 1;
  final List<String> _tags = <String>[];
  bool _receiptScanned = false;
  String? _receiptPath;
  bool _submitted = false;
  bool _showAllCategories = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final ExpenseTransaction? e = widget.existing;
    if (e != null) {
      _type = e.type;
      _amount.text = e.amount.toStringAsFixed(2);
      _desc.text = e.description;
      _note.text = e.note;
      _categoryId = e.categoryId;
      _method = e.method;
      _date = e.date;
      _splitWays = e.splitWays;
      _tags.addAll(e.tags);
      _receiptPath = e.receiptPath;
      _receiptScanned = e.receiptPath != null;
      _account.text = e.transferToAccount ?? '';
      _recurringCycle = e.recurringCycle ?? BillingCycle.monthly;
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _desc.dispose();
    _note.dispose();
    _account.dispose();
    super.dispose();
  }

  double get _amountValue => double.tryParse(_amount.text.trim()) ?? 0;

  /// PRD 4.4 AC1 — numeric only, 2-decimal currency precision.
  String? get _amountError {
    if (!_submitted) return null;
    if (_amount.text.trim().isEmpty) return 'Enter an amount';
    if (double.tryParse(_amount.text.trim()) == null) {
      return 'Enter a valid number';
    }
    if (_amountValue <= 0) return 'Amount must be greater than zero';
    return null;
  }

  String? get _categoryError {
    if (!_submitted) return null;
    if (_type == TransactionType.transfer) return null;
    return _categoryId == null ? 'Choose a category' : null;
  }

  String? get _accountError {
    if (!_submitted || _type != TransactionType.transfer) return null;
    return _account.text.trim().isEmpty
        ? 'Enter the destination account'
        : null;
  }

  /// PRD 4.4 AC2 — Save stays disabled until amount > 0 and a category is set.
  bool get _isValid =>
      _amountValue > 0 &&
      (_type == TransactionType.transfer || _categoryId != null) &&
      (_type != TransactionType.transfer || _account.text.trim().isNotEmpty);

  void _save() {
    setState(() => _submitted = true);
    if (!_isValid) return;

    final ExpenseStore store = context.read<ExpenseStore>();
    final ExpenseTransaction t = ExpenseTransaction(
      id: widget.existing?.id ?? IdGen.next('txn'),
      type: _type,
      amountPaise: (_amountValue * 100).round(),
      description: _desc.text.trim().isEmpty ? _type.label : _desc.text.trim(),
      categoryId: _categoryId ?? store.categories.last.id,
      date: _date,
      method: _method,
      tags: List<String>.from(_tags),
      note: _note.text.trim(),
      splitWays: _splitWays,
      // The scanned image was previously discarded on save.
      receiptPath: _receiptPath ?? widget.existing?.receiptPath,
      transferToAccount:
          _type == TransactionType.transfer ? _account.text.trim() : null,
      recurringCycle:
          _type == TransactionType.recurring ? _recurringCycle : null,
    );

    if (_isEdit) {
      store.update(t);
    } else {
      store.add(t);
    }
    Navigator.pop(context);
    showSnack(context, _isEdit ? 'Transaction updated' : 'Transaction saved');
  }

  @override
  Widget build(BuildContext context) {
    final ExpenseStore store = context.watch<ExpenseStore>();
    final List<BudgetCategory> cats = store.categories;
    final List<BudgetCategory> shown =
        _showAllCategories ? cats : cats.take(3).toList();

    return SheetScaffold(
      title: _isEdit ? 'Edit transaction' : 'Add transaction',
      actionLabel:
          _isEdit ? 'Save changes' : 'Save ${_type.label.toLowerCase()}',
      actionColor: AppColors.expenses,
      onAction: _save,
      children: <Widget>[
        Row(
          children: <Widget>[
            for (final TransactionType t in TransactionType.values) ...<Widget>[
              Expanded(child: _typeButton(t)),
              if (t != TransactionType.recurring) const SizedBox(width: 6),
            ],
          ],
        ),
        const SizedBox(height: 14),
        FieldWrap(
          label: 'Amount',
          error: _amountError,
          child: TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              prefixText: '₹ ',
              prefixStyle: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.expenses,
              ),
              hintText: '0.00',
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide:
                    const BorderSide(color: AppColors.expenses, width: 1.5),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        FieldWrap(
          label: 'Description',
          child: TextField(
            controller: _desc,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'e.g. Starbucks'),
          ),
        ),
        if (_type == TransactionType.transfer)
          FieldWrap(
            label: 'Transfer to account',
            error: _accountError,
            child: TextField(
              controller: _account,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                hintText: 'e.g. HDFC Savings ••4321',
                prefixIcon: Icon(Icons.account_balance_outlined, size: 18),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
        if (_type == TransactionType.recurring)
          FieldWrap(
            label: 'Repeats',
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                for (final BillingCycle c in <BillingCycle>[
                  BillingCycle.weekly,
                  BillingCycle.monthly,
                  BillingCycle.quarterly,
                  BillingCycle.yearly,
                ])
                  ChoicePill(
                    label: c.label,
                    selected: _recurringCycle == c,
                    color: AppColors.expenses,
                    onTap: () => setState(() => _recurringCycle = c),
                  ),
              ],
            ),
          ),
        if (_type != TransactionType.transfer)
          FieldWrap(
            label: 'Category',
            error: _categoryError,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                  childAspectRatio: 3.6,
                  children: <Widget>[
                    for (final BudgetCategory c in shown) _categoryChip(c),
                    if (!_showAllCategories && cats.length > 3)
                      InkWell(
                        onTap: () => setState(() => _showAllCategories = true),
                        borderRadius: BorderRadius.circular(9),
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: context.hairline),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Icon(Icons.more_horiz,
                                  size: 16, color: context.txtSecondary),
                              const SizedBox(width: 6),
                              Text('More…',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: context.txtSecondary)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        FieldWrap(
          label: 'Payment method',
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              for (final PaymentMethod m in PaymentMethod.values)
                ChoicePill(
                  label: m.label,
                  icon: switch (m) {
                    PaymentMethod.upi => Icons.smartphone,
                    PaymentMethod.card => Icons.credit_card,
                    PaymentMethod.cash => Icons.payments_outlined,
                    PaymentMethod.netBanking => Icons.account_balance_outlined,
                  },
                  selected: _method == m,
                  color: AppColors.expenses,
                  onTap: () => setState(() => _method = m),
                ),
            ],
          ),
        ),
        FieldWrap(
          label: 'Date',
          child: InkWell(
            onTap: () async {
              final DateTime? p = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2015),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (p != null) {
                setState(() => _date =
                    DateTime(p.year, p.month, p.day, _date.hour, _date.minute));
              }
            },
            child: InputDecorator(
              decoration: const InputDecoration(),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.calendar_today_outlined,
                      size: 16, color: AppColors.expenses),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${relativeDayLabel(_date, DateTime.now())}, '
                      '${fmtShortDate.format(_date)} ${_date.year}',
                    ),
                  ),
                  const Icon(Icons.expand_more, size: 18),
                ],
              ),
            ),
          ),
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
              label: _receiptScanned ? 'Receipt attached' : 'Scan receipt',
              icon: Icons.camera_alt_outlined,
              selected: _receiptScanned,
              color: AppColors.expenses,
              onTap: _scanReceipt,
            ),
            ChoicePill(
              label:
                  _splitWays > 1 ? 'Split $_splitWays ways' : 'Split expense',
              icon: Icons.group_outlined,
              selected: _splitWays > 1,
              color: AppColors.expenses,
              onTap: _promptSplit,
            ),
            ChoicePill(
              label: _tags.isEmpty ? 'Add tags' : _tags.join(', '),
              icon: Icons.label_outline,
              selected: _tags.isNotEmpty,
              color: AppColors.expenses,
              onTap: _promptTags,
            ),
            ChoicePill(
              label: _note.text.isEmpty ? 'Note' : 'Note added',
              icon: Icons.notes,
              selected: _note.text.isNotEmpty,
              color: AppColors.expenses,
              onTap: _promptNote,
            ),
          ],
        ),
        // PRD 4.4 AC4 — makes the own-share rule visible before saving.
        if (_splitWays > 1) ...<Widget>[
          const SizedBox(height: 10),
          InfoBanner(
            tone: ChipTone.info,
            icon: Icons.group_outlined,
            text: 'Total ${formatRupees(_amountValue, decimals: true)} split '
                '$_splitWays ways. Only your share '
                '(${formatRupees(_amountValue / _splitWays, decimals: true)}) '
                'counts toward your budget.',
          ),
        ],
      ],
    );
  }

  Widget _typeButton(TransactionType t) {
    final bool active = _type == t;
    final IconData icon = switch (t) {
      TransactionType.expense => Icons.arrow_outward,
      TransactionType.income => Icons.south_west,
      TransactionType.transfer => Icons.swap_horiz,
      TransactionType.recurring => Icons.autorenew,
    };
    return InkWell(
      onTap: () => setState(() {
        _type = t;
        _submitted = false;
      }),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: active
              ? AppColors.expenses.withValues(alpha: 0.10)
              : Colors.transparent,
          border: Border.all(
            color: active ? AppColors.expenses : context.hairline,
            width: active ? 1.5 : 0.8,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: <Widget>[
            Icon(icon,
                size: 18,
                color: active ? AppColors.expenses : context.txtSecondary),
            const SizedBox(height: 3),
            Text(
              t.label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                color: active ? AppColors.expenses : context.txtSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryChip(BudgetCategory c) {
    final bool sel = _categoryId == c.id;
    return InkWell(
      onTap: () => setState(() => _categoryId = c.id),
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: sel ? c.color.withValues(alpha: 0.12) : Colors.transparent,
          border: Border.all(
            color: sel ? c.color : context.hairline,
            width: sel ? 1.4 : 0.8,
          ),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          children: <Widget>[
            Icon(c.icon, size: 16, color: sel ? c.color : context.txtSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                c.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                  color: sel ? c.color : context.txtSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// PRD 4.4 AC3 — real on-device OCR pre-fills, and every pre-filled field
  /// stays editable. Nothing leaves the device.
  Future<void> _scanReceipt() async {
    final bool? fromCamera = await showModalBottomSheet<bool>(
      context: context,
      builder: (BuildContext c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Text(
                'Scan a receipt to fill in the amount and merchant. '
                'You can edit everything before saving.',
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
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
    if (fromCamera == null) return;

    final String? path =
        await AttachmentService.pickImage(fromCamera: fromCamera);
    if (path == null || !mounted) return;

    final String text = await OcrService.readText(path);
    if (!mounted) return;

    final double? amount = OcrService.parseAmount(text);
    final String? merchant = OcrService.parseMerchant(text);

    setState(() {
      _receiptScanned = true;
      _receiptPath = path;
      if (amount != null) _amount.text = amount.toStringAsFixed(2);
      if (merchant != null && _desc.text.trim().isEmpty) {
        _desc.text = merchant;
      }
    });

    showSnack(
      context,
      amount == null
          ? 'Receipt attached, but no amount was found — enter it manually'
          : 'Scanned ₹${amount.toStringAsFixed(2)} — check before saving',
    );
  }

  Future<void> _promptSplit() async {
    final int? v = await showDialog<int>(
      context: context,
      builder: (BuildContext ctx) => SimpleDialog(
        title: const Text('Split between how many people?'),
        children: <Widget>[
          for (final int n in <int>[1, 2, 3, 4, 5, 6, 8, 10])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, n),
              child: Text(n == 1 ? 'No split' : '$n ways'),
            ),
        ],
      ),
    );
    if (v != null) setState(() => _splitWays = v);
  }

  Future<void> _promptTags() async {
    final TextEditingController c =
        TextEditingController(text: _tags.join(', '));
    final String? v = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Tags'),
        content: TextField(
          controller: c,
          decoration: const InputDecoration(
              hintText: 'comma separated, e.g. work, reimbursable'),
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
    if (v != null) {
      setState(() {
        _tags
          ..clear()
          ..addAll(v
              .split(',')
              .map((String s) => s.trim())
              .where((String s) => s.isNotEmpty));
      });
    }
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
}
