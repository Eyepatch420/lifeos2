import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/services/entity_link_service.dart';
import 'package:lifeos/core/services/entity_resolver.dart';
import 'package:lifeos/data/models/commitments.dart';
import 'package:lifeos/data/models/entity_ref.dart';
import 'package:lifeos/data/models/enums.dart';
import 'package:lifeos/data/models/lists_notes.dart';
import 'package:lifeos/data/stores/commitments_store.dart';
import 'package:lifeos/data/stores/persistence.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Persistence.reset();
  });

  Widget wrap(CommitmentsStore commitments, Widget child) => MultiProvider(
        providers: <SingleChildWidget>[
          ChangeNotifierProvider<CommitmentsStore>.value(value: commitments),
        ],
        child: MaterialApp(home: child),
      );

  testWidgets('EntityResolver resolves a live record by ref',
      (WidgetTester tester) async {
    final CommitmentsStore commitments = CommitmentsStore();
    final Membership m = Membership(
      id: 'mem_test',
      name: 'Test Gym',
      category: MembershipCategory.fitness,
      costPaise: 100000,
      cycle: BillingCycle.monthly,
      startDate: DateTime.now(),
      expiryDate: DateTime.now().add(const Duration(days: 30)),
    );
    commitments.addMembership(m);

    late BuildContext ctx;
    await tester.pumpWidget(wrap(
      commitments,
      Builder(builder: (BuildContext c) {
        ctx = c;
        return const SizedBox();
      }),
    ));

    const EntityRef ref = EntityRef(EntityType.membership, 'mem_test');
    expect(EntityResolver.exists(ctx, ref), isTrue);
    expect(EntityResolver.labelFor(ctx, ref), 'Test Gym');
  });

  testWidgets('a rename propagates automatically through live resolution',
      (WidgetTester tester) async {
    final CommitmentsStore commitments = CommitmentsStore();
    final Membership m = Membership(
      id: 'mem_test',
      name: 'Original Name',
      category: MembershipCategory.fitness,
      costPaise: 100000,
      cycle: BillingCycle.monthly,
      startDate: DateTime.now(),
      expiryDate: DateTime.now().add(const Duration(days: 30)),
    );
    commitments.addMembership(m);

    late BuildContext ctx;
    await tester.pumpWidget(wrap(
      commitments,
      Builder(builder: (BuildContext c) {
        ctx = c;
        return const SizedBox();
      }),
    ));

    const EntityRef ref = EntityRef(EntityType.membership, 'mem_test');
    expect(EntityResolver.labelFor(ctx, ref), 'Original Name');

    m.name = 'Renamed Gym';
    commitments.updateMembership(m);
    await tester.pump();

    // No re-save of the link was needed — labelFor reads the live record.
    expect(EntityResolver.labelFor(ctx, ref), 'Renamed Gym');
  });

  testWidgets(
      'a deleted target resolves to null (no crash) instead of a dead screen',
      (WidgetTester tester) async {
    final CommitmentsStore commitments = CommitmentsStore();
    final Bill b = Bill(
      id: 'bill_test',
      name: 'Test Bill',
      kind: BillKind.bill,
      amountPaise: 5000,
      cycle: BillingCycle.monthly,
      dueDate: DateTime.now(),
    );
    commitments.addBill(b);

    late BuildContext ctx;
    await tester.pumpWidget(wrap(
      commitments,
      Builder(builder: (BuildContext c) {
        ctx = c;
        return const SizedBox();
      }),
    ));

    const EntityRef ref = EntityRef(EntityType.bill, 'bill_test');
    expect(EntityResolver.exists(ctx, ref), isTrue);

    commitments.deleteBill('bill_test');
    await tester.pump();

    expect(EntityResolver.exists(ctx, ref), isFalse);
    expect(EntityResolver.labelFor(ctx, ref), isNull);
  });

  testWidgets('EntityLinkService.validate flags exactly the broken links',
      (WidgetTester tester) async {
    final CommitmentsStore commitments = CommitmentsStore();
    commitments.addMembership(Membership(
      id: 'mem_alive',
      name: 'Alive Membership',
      category: MembershipCategory.fitness,
      costPaise: 100000,
      cycle: BillingCycle.monthly,
      startDate: DateTime.now(),
      expiryDate: DateTime.now().add(const Duration(days: 30)),
    ));

    late BuildContext ctx;
    await tester.pumpWidget(wrap(
      commitments,
      Builder(builder: (BuildContext c) {
        ctx = c;
        return const SizedBox();
      }),
    ));

    final List<(String, EntityRef)> links = <(String, EntityRef)>[
      ('Note: some note', const EntityRef(EntityType.membership, 'mem_alive')),
      ('Note: other note', const EntityRef(EntityType.membership, 'mem_deleted')),
    ];

    final List<BrokenLink> broken = EntityLinkService.validate(ctx, links);
    expect(broken.length, 1);
    expect(broken.single.owner, 'Note: other note');
    expect(broken.single.ref.id, 'mem_deleted');
  });

  test('NoteLink infers an EntityRef from legacy module+targetId fields', () {
    final NoteLink link =
        NoteLink(module: 'Health', label: 'CBC Panel', targetId: 'rep_1');
    expect(link.ref, isNotNull);
    expect(link.ref!.type, EntityType.labReport);
    expect(link.ref!.id, 'rep_1');
  });

  test('NoteLink with an unrecognised module and no targetId has no ref', () {
    final NoteLink link = NoteLink(module: 'Unknown', label: 'Something');
    expect(link.ref, isNull);
  });

  test('EntityRef payload round-trips through toPayload/fromPayload', () {
    const EntityRef ref = EntityRef(EntityType.bill, 'bill_123');
    final String payload = ref.toPayload();
    final EntityRef? parsed = EntityRef.fromPayload(payload);
    expect(parsed, ref);
  });
}
