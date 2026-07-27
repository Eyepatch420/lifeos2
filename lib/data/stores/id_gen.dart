import 'dart:math';

/// Simple unique-id generator. Replace with UUIDs if the data layer is ever
/// swapped for a synced backend.
class IdGen {
  IdGen._();
  static final Random _r = Random();
  static int _seq = 0;

  static String next([String prefix = 'id']) {
    _seq++;
    return '${prefix}_${DateTime.now().millisecondsSinceEpoch}_${_seq}_${_r.nextInt(9999)}';
  }
}
