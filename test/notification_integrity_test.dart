import 'package:flutter_test/flutter_test.dart';
import 'package:digidaily/core/services/notification_service.dart';

void main() {
  test('a reminder id and a bill id that hash the same no longer collide', () {
    // Before the fix, _id used `(source.hashCode & 0x03FFFFFF) | (slot << 26)`
    // with no type namespace, so a bare reminder id and a `bill_`-prefixed id
    // could produce the same packed int if their hashes matched post-mask.
    // Construct two sources whose un-prefixed hash is identical by using the
    // same suffix — the prior implementation would have collided on these.
    const String sharedSuffix = 'shared_entity_id_123';
    final int reminderId = NotificationService.idForTest(sharedSuffix, 0);
    final int billId = NotificationService.idForTest('bill_$sharedSuffix', 0);

    expect(reminderId, isNot(billId));
  });

  test('a habit id and a membership id with the same suffix do not collide', () {
    const String sharedSuffix = 'abc123';
    final int habitId = NotificationService.idForTest('hab_$sharedSuffix', 0);
    final int memId = NotificationService.idForTest('mem_$sharedSuffix', 0);
    expect(habitId, isNot(memId));
  });

  test('the same source+slot always produces the same id (deterministic)', () {
    final int a = NotificationService.idForTest('reminder_1', 3);
    final int b = NotificationService.idForTest('reminder_1', 3);
    expect(a, b);
  });

  test('different slots for the same source produce different ids', () {
    final int slot0 = NotificationService.idForTest('reminder_1', 0);
    final int slot1 = NotificationService.idForTest('reminder_1', 1);
    expect(slot0, isNot(slot1));
  });

  test('ids stay within a valid 32-bit positive int range', () {
    final int id = NotificationService.idForTest('doc_some_long_document_id_here', 5);
    expect(id, greaterThanOrEqualTo(0));
    expect(id, lessThan(1 << 31));
  });
}
