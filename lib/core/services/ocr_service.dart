import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// One value pulled out of a scanned document, always presented to the user
/// for review before anything is saved (no silent auto-fill).
class ScannedMarker {
  ScannedMarker({required this.name, required this.value, this.unit = ''});
  String name;
  double value;
  String unit;
}

/// On-device text recognition (ML Kit). Used for receipt amounts and lab
/// report markers. Fully offline — nothing leaves the device.
class OcrService {
  const OcrService._();

  static final TextRecognizer _recognizer = TextRecognizer();

  static Future<String> readText(String imagePath) async {
    try {
      final RecognizedText result =
          await _recognizer.processImage(InputImage.fromFilePath(imagePath));
      return result.text;
    } catch (_) {
      return '';
    }
  }

  /// Largest currency-looking number on a receipt — that is almost always the
  /// total rather than a line item.
  static double? parseAmount(String text) {
    final RegExp re = RegExp(r'(?:₹|rs\.?|inr)?\s*(\d{1,3}(?:,\d{2,3})*(?:\.\d{1,2})?)',
        caseSensitive: false);
    double? best;
    for (final RegExpMatch m in re.allMatches(text)) {
      final double? v = double.tryParse(m.group(1)!.replaceAll(',', ''));
      if (v == null || v <= 0) continue;
      if (best == null || v > best) best = v;
    }
    return best;
  }

  /// First non-empty line is nearly always the merchant/lab name.
  static String? parseMerchant(String text) {
    for (final String line in text.split('\n')) {
      final String t = line.trim();
      if (t.length >= 3 && RegExp(r'[A-Za-z]').hasMatch(t)) return t;
    }
    return null;
  }

  /// Pulls `Name  12.3 unit` style rows out of a lab report. The caller must
  /// show these in an editable form — extraction is a starting point, not
  /// a source of truth (PRD 5.2 disclaimer).
  static List<ScannedMarker> parseMarkers(String text) {
    final List<ScannedMarker> out = <ScannedMarker>[];
    final RegExp row = RegExp(
        r'^([A-Za-z][A-Za-z0-9 \-/()]{2,40}?)[\s:.]+(\d+(?:\.\d+)?)\s*([a-zA-Z%/µ]+(?:/[a-zA-Z]+)?)?',
        multiLine: true);
    for (final RegExpMatch m in row.allMatches(text)) {
      final double? v = double.tryParse(m.group(2)!);
      if (v == null) continue;
      final String name = m.group(1)!.trim();
      if (name.length < 3) continue;
      out.add(ScannedMarker(
        name: name,
        value: v,
        unit: (m.group(3) ?? '').trim(),
      ));
    }
    return out;
  }

  static Future<void> dispose() => _recognizer.close();
}
