import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:digidaily/data/models/commitments.dart';
import 'package:digidaily/data/models/enums.dart';
import 'package:digidaily/data/stores/commitments_store.dart';
import 'package:digidaily/data/stores/expense_store.dart';
import 'package:digidaily/data/stores/persistence.dart';
import 'package:digidaily/features/bills/bills_screen.dart';
import 'package:digidaily/features/memberships/membership_detail_screen.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Persistence.reset();
  });

  Widget wrap(CommitmentsStore commitments, ExpenseStore expenses, Widget child) {
    return MultiProvider(
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<CommitmentsStore>.value(value: commitments),
        ChangeNotifierProvider<ExpenseStore>.value(value: expenses),
      ],
      child: MaterialApp(home: child),
    );
  }

  testWidgets('marking a bill paid logs a real expense transaction',
      (WidgetTester tester) async {
    final CommitmentsStore commitments = CommitmentsStore();
    final ExpenseStore expenses = ExpenseStore();
    final int before = expenses.allTransactions.length;

    final Bill bill = Bill(
      id: 'test_bill',
      name: 'Test Wifi Bill',
      kind: BillKind.bill,
      amountPaise: 123400,
      cycle: BillingCycle.monthly,
      dueDate: DateTime.now(),
    );
    commitments.addBill(bill);

    await tester.pumpWidget(wrap(commitments, expenses, const BillsScreen()));
    await tester.pumpAndSettle();

    // Open the bill's long-press menu and tap "Mark as paid".
    await tester.longPress(find.text('Test Wifi Bill').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark as paid'));
    await tester.pumpAndSettle();

    expect(expenses.allTransactions.length, before + 1);
    expect(
      expenses.allTransactions.any((t) =>
          t.description == 'Test Wifi Bill' && t.amountPaise == 123400),
      isTrue,
    );
  });

  testWidgets('renewing a membership logs a real expense transaction',
      (WidgetTester tester) async {
    final CommitmentsStore commitments = CommitmentsStore();
    final ExpenseStore expenses = ExpenseStore();
    final int before = expenses.allTransactions.length;

    final Membership m = Membership(
      id: 'test_mem',
      name: 'Test Gym',
      category: MembershipCategory.fitness,
      costPaise: 250000,
      cycle: BillingCycle.monthly,
      startDate: DateTime.now().subtract(const Duration(days: 25)),
      expiryDate: DateTime.now().add(const Duration(days: 5)),
    );
    commitments.addMembership(m);

    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      wrap(commitments, expenses, const MembershipDetailScreen(id: 'test_mem')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mark as renewed'));
    await tester.pumpAndSettle();

    expect(expenses.allTransactions.length, before + 1);
    expect(
      expenses.allTransactions
          .any((t) => t.description == 'Test Gym renewal' && t.amountPaise == 250000),
      isTrue,
    );
    expect(m.linkedExpenseId, isNotNull);
  });
}
