import 'package:flutter/material.dart';

import '../../data/models/entity_ref.dart';
import 'entity_registry.dart';

/// Resolves an [EntityRef] to its live record via [EntityRegistry], so a
/// label or "does this still exist" check always reflects the current store
/// state instead of whatever was true when the link was created.
class EntityResolver {
  const EntityResolver._();

  static Object? resolve(BuildContext context, EntityRef ref) =>
      EntityRegistry.handlerFor(ref.type).resolve(context, ref.id);

  static bool exists(BuildContext context, EntityRef ref) =>
      resolve(context, ref) != null;

  /// The target's current display label, or null if it no longer exists —
  /// callers show "Linked item no longer exists" in that case rather than a
  /// stale frozen label.
  static String? labelFor(BuildContext context, EntityRef ref) {
    final Object? record = resolve(context, ref);
    if (record == null) return null;
    return EntityRegistry.handlerFor(ref.type).labelOf(record);
  }
}
