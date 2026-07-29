/// Every kind of record that can be the target of a cross-module link,
/// a search result, or a notification tap.
///
/// Superset of the informal `NotificationRoute.kind` strings already used by
/// `notification_service.dart` (reminder/habit/event/alarm/bill/membership/
/// document) plus the record kinds that show up in search/links but weren't
/// named there (note/taskList/labReport/expenseTransaction/budgetCategory).
enum EntityType {
  reminder,
  habit,
  plannerEvent,
  expenseTransaction,
  budgetCategory,
  bill,
  membership,
  storedDocument,
  taskList,
  note,
  labReport,
  alarm,
}

/// A typed, id-based pointer to a record in another module.
///
/// Deliberately carries only `(type, id)` — never a display name or label —
/// so a rename of the target is automatically reflected wherever the
/// reference is resolved, instead of the label going stale.
class EntityRef {
  const EntityRef(this.type, this.id);

  final EntityType type;
  final String id;

  /// `'type:id'` — same shape as the notification payload convention, so
  /// existing `NotificationRoute` parsing and this can share format logic.
  String toPayload() => '${type.name}:$id';

  static EntityRef? fromPayload(String payload) {
    final int sep = payload.indexOf(':');
    if (sep <= 0) return null;
    final String typeName = payload.substring(0, sep);
    final String id = payload.substring(sep + 1);
    for (final EntityType t in EntityType.values) {
      if (t.name == typeName) return EntityRef(t, id);
    }
    return null;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'type': type.name,
        'id': id,
      };

  static EntityRef? fromJson(Map<String, dynamic>? j) {
    if (j == null) return null;
    final String? typeName = j['type'] as String?;
    final String? id = j['id'] as String?;
    if (typeName == null || id == null) return null;
    for (final EntityType t in EntityType.values) {
      if (t.name == typeName) return EntityRef(t, id);
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is EntityRef && other.type == type && other.id == id;

  @override
  int get hashCode => Object.hash(type, id);

  @override
  String toString() => toPayload();
}
