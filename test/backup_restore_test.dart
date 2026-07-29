import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/services/backup_service.dart';
import 'package:lifeos/data/models/commitments.dart';
import 'package:lifeos/data/models/enums.dart';
import 'package:lifeos/data/stores/commitments_store.dart';
import 'package:lifeos/data/stores/persistence.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Persistence.reset();
  });

  test('export contains appVersion alongside formatVersion and timestamp', () async {
    final String backup = await BackupService.buildBackup();
    final Map<String, dynamic> parsed = jsonDecode(backup) as Map<String, dynamic>;
    expect(parsed.containsKey('appVersion'), isTrue);
    expect(parsed.containsKey('formatVersion'), isTrue);
    expect(parsed.containsKey('exportedAt'), isTrue);
  });

  test('a merge restore unions two commitments blobs by id, incoming wins on conflict', () {
    final Bill original = Bill(
      id: 'bill_shared',
      name: 'Old name',
      kind: BillKind.bill,
      amountPaise: 1000,
      cycle: BillingCycle.monthly,
      dueDate: DateTime(2026, 1, 1),
    );
    final Bill onlyInCurrent = Bill(
      id: 'bill_current_only',
      name: 'Current only',
      kind: BillKind.bill,
      amountPaise: 2000,
      cycle: BillingCycle.monthly,
      dueDate: DateTime(2026, 1, 1),
    );
    final CommitmentsStore current = CommitmentsStore();
    current.addBill(original);
    current.addBill(onlyInCurrent);
    Persistence.save('commitments', <String, dynamic>{
      'memberships': <dynamic>[],
      'bills': <dynamic>[original.toJson(), onlyInCurrent.toJson()],
      'documents': <dynamic>[],
    });

    // Incoming backup: same shared bill (renamed) + one bill only it has.
    final Bill renamed = Bill(
      id: 'bill_shared',
      name: 'New name from backup',
      kind: BillKind.bill,
      amountPaise: 1500,
      cycle: BillingCycle.monthly,
      dueDate: DateTime(2026, 2, 1),
    );
    final Bill onlyInIncoming = Bill(
      id: 'bill_incoming_only',
      name: 'Incoming only',
      kind: BillKind.bill,
      amountPaise: 3000,
      cycle: BillingCycle.monthly,
      dueDate: DateTime(2026, 1, 1),
    );
    final Map<String, dynamic> incomingBlob = <String, dynamic>{
      'memberships': <dynamic>[],
      'bills': <dynamic>[renamed.toJson(), onlyInIncoming.toJson()],
      'documents': <dynamic>[],
    };

    final Map<String, dynamic> merged =
        BackupServiceTestHooks.merge('commitments', Persistence.load('commitments'), incomingBlob);

    final List<dynamic> mergedBills = merged['bills'] as List<dynamic>;
    final Map<String, dynamic> byId = <String, dynamic>{
      for (final dynamic b in mergedBills) (b as Map<String, dynamic>)['id'] as String: b,
    };

    expect(byId.length, 3); // shared + current-only + incoming-only
    expect(byId['bill_shared']!['name'], 'New name from backup'); // incoming wins
    expect(byId['bill_current_only'], isNotNull); // preserved from current
    expect(byId['bill_incoming_only'], isNotNull); // added from incoming
  });

  test('a corrupted backup (array field holding a non-list) is rejected before writing anything', () async {
    final String malformed = jsonEncode(<String, dynamic>{
      'app': 'LifeOS',
      'formatVersion': BackupService.formatVersion,
      'appVersion': '1.0.0',
      'exportedAt': DateTime.now().toIso8601String(),
      'data': <String, dynamic>{
        'commitments': <String, dynamic>{'bills': 'not a list'},
      },
    });

    // Exercise the same validation restoreFromFile uses internally.
    final Map<String, dynamic> parsed = jsonDecode(malformed) as Map<String, dynamic>;
    final String? error = BackupServiceTestHooks.validate(parsed);
    expect(error, isNotNull);
    expect(error, contains('commitments'));
  });

  test('a backup missing the LifeOS app marker is rejected', () {
    final Map<String, dynamic> parsed = <String, dynamic>{
      'app': 'SomeOtherApp',
      'formatVersion': 1,
      'data': <String, dynamic>{},
    };
    expect(BackupServiceTestHooks.validate(parsed), isNotNull);
  });

  test('a backup from a newer format version is rejected', () {
    final Map<String, dynamic> parsed = <String, dynamic>{
      'app': 'LifeOS',
      'formatVersion': BackupService.formatVersion + 1,
      'data': <String, dynamic>{'settings': <String, dynamic>{}},
    };
    expect(BackupServiceTestHooks.validate(parsed), isNotNull);
  });
}
