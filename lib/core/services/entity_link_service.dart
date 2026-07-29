import 'package:flutter/material.dart';

import '../../data/models/entity_ref.dart';
import 'entity_resolver.dart';

/// One broken reference found during a validation pass — the record it
/// points at no longer exists.
class BrokenLink {
  const BrokenLink(this.owner, this.ref);

  /// A human-readable description of what holds the broken reference, e.g.
  /// "Note: Dr. Mehta visit summary".
  final String owner;
  final EntityRef ref;
}

/// Creation/removal/validation of [EntityRef] links.
///
/// Links themselves are just fields on the owning model (e.g.
/// `Membership.linkedExpenseRef`) — this service doesn't store anything of
/// its own. It centralises the "does this still resolve" check so every
/// screen and the post-restore integrity pass (see `BackupService`) share
/// one definition of "broken".
class EntityLinkService {
  const EntityLinkService._();

  /// Checks every `(owner, ref)` pair and returns the ones whose target no
  /// longer exists. Callers build the `owner`-labelled list from whichever
  /// store they're validating (see stores' `_seed`/`_load` for the shapes).
  static List<BrokenLink> validate(
    BuildContext context,
    List<(String owner, EntityRef ref)> links,
  ) {
    final List<BrokenLink> broken = <BrokenLink>[];
    for (final (String owner, EntityRef ref) in links) {
      if (!EntityResolver.exists(context, ref)) {
        broken.add(BrokenLink(owner, ref));
      }
    }
    return broken;
  }
}
