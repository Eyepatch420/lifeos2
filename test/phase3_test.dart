import 'package:flutter_test/flutter_test.dart';
import 'package:digilife/core/services/ocr_service.dart';
import 'package:digilife/data/models/enums.dart';
import 'package:digilife/data/models/expense.dart';
import 'package:digilife/data/stores/expense_store.dart';

void main() {
  group('receipt OCR parsing', () {
    const String receipt = '''
STARBUCKS COFFEE
Linking Road, Bandra
Latte              180.00
Croissant          200.00
Subtotal           380.00
GST                 68.40
TOTAL             ₹448.40
Card ****1234
''';

    test('picks the largest amount as the total', () {
      // Line items must not win over the total.
      expect(OcrService.parseAmount(receipt), 448.40);
    });

    test('reads the merchant from the first text line', () {
      expect(OcrService.parseMerchant(receipt), 'STARBUCKS COFFEE');
    });

    test('handles thousands separators', () {
      expect(OcrService.parseAmount('TOTAL ₹1,299.50'), 1299.50);
    });

    test('returns null when there is no amount at all', () {
      expect(OcrService.parseAmount('no numbers here'), isNull);
    });
  });

  group('lab report marker parsing', () {
    test('extracts name, value and unit rows', () {
      final List<ScannedMarker> markers = OcrService.parseMarkers('''
Haemoglobin 13.6 g/dL
HbA1c 6.9 %
''');
      expect(markers.length, greaterThanOrEqualTo(2));
      expect(markers.first.name, 'Haemoglobin');
      expect(markers.first.value, 13.6);
      expect(markers.first.unit, 'g/dL');
    });
  });

  group('deleting a budget category never loses spending', () {
    test('transactions are reassigned, not orphaned', () {
      final ExpenseStore store = ExpenseStore();
      final String victim = store.categories.first.id;
      final int before = store.allTransactions.length;

      store.add(ExpenseTransaction(
        id: 'tx_test',
        type: TransactionType.expense,
        amountPaise: 50000,
        description: 'Test spend',
        categoryId: victim,
        date: DateTime.now(),
      ));

      store.deleteCategory(victim);

      // Nothing was deleted along with the category.
      expect(store.allTransactions.length, before + 1);
      // And the transaction now points at a category that still exists.
      final ExpenseTransaction moved = store.allTransactions
          .firstWhere((ExpenseTransaction t) => t.id == 'tx_test');
      expect(moved.categoryId, isNot(victim));
      expect(
        store.categories.any((BudgetCategory c) => c.id == moved.categoryId),
        isTrue,
      );
    });

    test('the last remaining category cannot be deleted', () {
      final ExpenseStore store = ExpenseStore();
      while (store.categories.length > 1) {
        store.deleteCategory(store.categories.first.id);
      }
      store.deleteCategory(store.categories.first.id);
      expect(store.categories.length, 1);
    });
  });

  group('transaction serialization', () {
    test('a scanned receipt path survives a save/load', () {
      final ExpenseTransaction t = ExpenseTransaction(
        id: 'tx1',
        type: TransactionType.expense,
        amountPaise: 44840,
        description: 'Starbucks',
        categoryId: 'cat_food',
        date: DateTime(2026, 7, 27),
        receiptPath: '/data/attachments/receipt.jpg',
      );
      final ExpenseTransaction back =
          ExpenseTransaction.fromJson(t.toJson());
      expect(back.receiptPath, '/data/attachments/receipt.jpg');
      expect(back.amountPaise, 44840);
    });
  });
}
