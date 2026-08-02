import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:digilife/data/models/commitments.dart';
import 'package:digilife/data/models/enums.dart';
import 'package:digilife/data/models/reminder.dart';
import 'package:digilife/data/stores/commitments_store.dart';
import 'package:digilife/data/stores/expense_store.dart';
import 'package:digilife/data/stores/persistence.dart';
import 'package:digilife/data/stores/reminder_store.dart';
import 'package:digilife/features/bills/bills_screen.dart';
import 'package:digilife/features/reminders/reminders_screen.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Persistence.reset();
  });

  testWidgets(
      'BillsScreen with a highlightId renders without error and shows the target row',
      (WidgetTester tester) async {
    final CommitmentsStore commitments = CommitmentsStore();
    final Bill target = Bill(
      id: 'bill_highlight_target',
      name: 'Highlighted Bill',
      kind: BillKind.bill,
      amountPaise: 5000,
      cycle: BillingCycle.monthly,
      dueDate: DateTime.now().add(const Duration(days: 5)),
    );
    commitments.addBill(target);

    await tester.pumpWidget(MultiProvider(
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<CommitmentsStore>.value(value: commitments),
        ChangeNotifierProvider<ExpenseStore>.value(value: ExpenseStore()),
      ],
      child: MaterialApp(
        home: const BillsScreen(highlightId: 'bill_highlight_target'),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Highlighted Bill'), findsOneWidget);
  });

  testWidgets(
      'RemindersScreen with a highlightId renders without error and shows the target row',
      (WidgetTester tester) async {
    final ReminderStore reminders = ReminderStore();
    final Reminder target = Reminder(
      id: 'rem_highlight_target',
      title: 'Highlighted Reminder',
      type: ReminderType.medicine,
      time: const TimeOfDay(hour: 9, minute: 0),
    );
    reminders.add(target);

    await tester.pumpWidget(MultiProvider(
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<ReminderStore>.value(value: reminders),
      ],
      child: MaterialApp(
        home: const RemindersScreen(highlightId: 'rem_highlight_target'),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Highlighted Reminder'), findsOneWidget);
  });

  testWidgets(
      'BillsScreen with no highlightId still renders normally (no regression)',
      (WidgetTester tester) async {
    final CommitmentsStore commitments = CommitmentsStore();
    commitments.addBill(Bill(
      id: 'bill_plain',
      name: 'Plain Bill',
      kind: BillKind.bill,
      amountPaise: 1000,
      cycle: BillingCycle.monthly,
      dueDate: DateTime.now().add(const Duration(days: 5)),
    ));

    await tester.pumpWidget(MultiProvider(
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<CommitmentsStore>.value(value: commitments),
        ChangeNotifierProvider<ExpenseStore>.value(value: ExpenseStore()),
      ],
      child: MaterialApp(home: const BillsScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Plain Bill'), findsOneWidget);
  });
}
