import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos/core/services/ocr_service.dart';
import 'package:lifeos/data/models/enums.dart';
import 'package:lifeos/data/models/health.dart';
import 'package:lifeos/data/models/lists_notes.dart';
import 'package:lifeos/data/stores/health_store.dart';
import 'package:lifeos/data/stores/lists_notes_store.dart';

void main() {
  group('reference ranges classify scanned markers', () {
    test('a known marker gets its real range', () {
      final (double, double, String)? r = OcrService.rangeFor('Haemoglobin');
      expect(r, isNotNull);
      expect(r!.$1, 12);
      expect(r.$2, 17);
      expect(r.$3, 'g/dL');
    });

    test('lookup is case-insensitive and matches substrings', () {
      expect(OcrService.rangeFor('HBA1C'), isNotNull);
      expect(OcrService.rangeFor('Serum Creatinine'), isNotNull);
    });

    test('an unknown marker returns null so the user is asked', () {
      expect(OcrService.rangeFor('Zorblax factor'), isNull);
    });

    test('the range actually drives the status', () {
      final (double, double, String) r = OcrService.rangeFor('HbA1c')!;
      final LabMarker high = LabMarker(
          name: 'HbA1c',
          value: 6.9,
          unit: r.$3,
          normalLow: r.$1,
          normalHigh: r.$2);
      expect(high.status, MarkerStatus.abnormal);

      final LabMarker ok = LabMarker(
          name: 'HbA1c',
          value: 5.2,
          unit: r.$3,
          normalLow: r.$1,
          normalHigh: r.$2);
      expect(ok.status, MarkerStatus.normal);
    });
  });

  group('mis-scanned values can be corrected', () {
    test('updateMarker replaces the value in place', () {
      final HealthStore store = HealthStore()..seed();
      final LabReport report = store.reports.first;
      final LabMarker original = report.markers.first;

      store.updateMarker(
        report,
        0,
        LabMarker(
          name: original.name,
          value: 99.9,
          unit: original.unit,
          normalLow: original.normalLow,
          normalHigh: original.normalHigh,
        ),
      );

      expect(store.reportById(report.id)!.markers.first.value, 99.9);
      // The other markers are untouched.
      expect(store.reportById(report.id)!.markers.length,
          report.markers.length);
    });

    test('an out-of-range index is ignored rather than crashing', () {
      final HealthStore store = HealthStore()..seed();
      final LabReport report = store.reports.first;
      final int before = report.markers.length;
      store.updateMarker(report, 99,
          LabMarker(name: 'X', value: 1, unit: '', normalLow: 0, normalHigh: 2));
      expect(store.reportById(report.id)!.markers.length, before);
    });
  });

  group('reports can be edited and removed', () {
    test('updateReport swaps the stored report', () {
      final HealthStore store = HealthStore()..seed();
      final LabReport original = store.reports.first;
      store.updateReport(LabReport(
        id: original.id,
        name: 'Renamed report',
        lab: original.lab,
        date: original.date,
        markers: original.markers,
      ));
      expect(store.reportById(original.id)!.name, 'Renamed report');
    });

    test('deleteReport removes it', () {
      final HealthStore store = HealthStore()..seed();
      final int before = store.reportCount;
      store.deleteReport(store.reports.first.id);
      expect(store.reportCount, before - 1);
    });
  });

  group('list sharing renders real text', () {
    test('listAsPlainText includes every item and its state', () {
      final ListsNotesStore store = ListsNotesStore()..seed();
      final TaskList list = store.lists.first;
      final String text = store.listAsPlainText(list);

      expect(text, contains(list.name));
      for (final ChecklistItem i in list.allItems) {
        expect(text, contains(i.text));
      }
      expect(text, contains('${list.doneCount} of ${list.total} done'));
    });
  });

  group('list item edits go through the store', () {
    test('updateItem changes the text and notifies', () {
      final ListsNotesStore store = ListsNotesStore()..seed();
      final TaskList list = store.lists.first;
      final ChecklistItem item = list.allItems.first;

      bool notified = false;
      store.addListener(() => notified = true);

      store.updateItem(item, text: 'Corrected text', note: 'a note');

      expect(item.text, 'Corrected text');
      expect(item.note, 'a note');
      expect(notified, isTrue);
    });
  });

  group('note attachments survive a save/load', () {
    test('attachmentPaths round-trip', () {
      final Note n = Note(
        id: 'n1',
        title: 'Scan',
        body: 'body',
        createdAt: DateTime(2026, 7, 28),
        attachmentPaths: <String>['/data/a.jpg', '/data/b.jpg'],
      );
      final Note back = Note.fromJson(n.toJson());
      expect(back.attachmentPaths, <String>['/data/a.jpg', '/data/b.jpg']);
    });
  });
}
