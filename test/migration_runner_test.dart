import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/data/stores/migration_runner.dart';

void main() {
  setUp(() => MigrationRunner.clearForTest());

  test('a registered migration is applied to bump the blob forward', () {
    MigrationRunner.register('k', 1, (Map<String, dynamic> blob) {
      return <String, dynamic>{'value': (blob['value'] as int) + 1};
    });

    final Map<String, dynamic> result = MigrationRunner.run(
      'k',
      <String, dynamic>{'value': 10, '_v': 1},
      currentVersion: 2,
      seedFallback: () => <String, dynamic>{'value': -1},
    );

    expect(result['value'], 11);
  });

  test('sequential migrations apply in order', () {
    MigrationRunner.register('k', 1, (Map<String, dynamic> blob) =>
        <String, dynamic>{'value': (blob['value'] as int) + 1});
    MigrationRunner.register('k', 2, (Map<String, dynamic> blob) =>
        <String, dynamic>{'value': (blob['value'] as int) * 10});

    final Map<String, dynamic> result = MigrationRunner.run(
      'k',
      <String, dynamic>{'value': 1, '_v': 1},
      currentVersion: 3,
      seedFallback: () => <String, dynamic>{'value': -1},
    );

    // (1 + 1) * 10 = 20 — proves v1->v2 ran before v2->v3.
    expect(result['value'], 20);
  });

  test('a blob with no _v field is treated as version 1', () {
    MigrationRunner.register('k', 1, (Map<String, dynamic> blob) =>
        <String, dynamic>{'value': (blob['value'] as int) + 100});

    final Map<String, dynamic> result = MigrationRunner.run(
      'k',
      <String, dynamic>{'value': 5}, // no _v
      currentVersion: 2,
      seedFallback: () => <String, dynamic>{'value': -1},
    );

    expect(result['value'], 105);
  });

  test('a blob already at the current version is untouched', () {
    MigrationRunner.register('k', 1, (Map<String, dynamic> blob) =>
        <String, dynamic>{'value': (blob['value'] as int) + 100});

    final Map<String, dynamic> result = MigrationRunner.run(
      'k',
      <String, dynamic>{'value': 5, '_v': 2},
      currentVersion: 2,
      seedFallback: () => <String, dynamic>{'value': -1},
    );

    expect(result['value'], 5);
  });

  test('a failing migration falls back to seed data instead of throwing', () {
    MigrationRunner.register('k', 1, (Map<String, dynamic> blob) {
      throw const FormatException('corrupt');
    });

    final Map<String, dynamic> result = MigrationRunner.run(
      'k',
      <String, dynamic>{'_v': 1},
      currentVersion: 2,
      seedFallback: () => <String, dynamic>{'value': 'seed'},
    );

    expect(result['value'], 'seed');
  });

  test('an unrecognised shape (missing expected key) falls back to seed', () {
    MigrationRunner.register('k', 1, (Map<String, dynamic> blob) =>
        <String, dynamic>{'value': (blob['nonexistent'] as int) + 1});

    final Map<String, dynamic> result = MigrationRunner.run(
      'k',
      <String, dynamic>{'_v': 1},
      currentVersion: 2,
      seedFallback: () => <String, dynamic>{'value': 'seed'},
    );

    expect(result['value'], 'seed');
  });

  test('a store key with no registered migrations returns the blob as-is', () {
    final Map<String, dynamic> result = MigrationRunner.run(
      'unregistered_key',
      <String, dynamic>{'value': 42, '_v': 1},
      currentVersion: 5,
      seedFallback: () => <String, dynamic>{'value': -1},
    );

    expect(result['value'], 42);
  });
}
