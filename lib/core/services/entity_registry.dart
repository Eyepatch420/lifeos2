import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/entity_ref.dart';
import '../../data/stores/alarm_store.dart';
import '../../data/stores/commitments_store.dart';
import '../../data/stores/expense_store.dart';
import '../../data/stores/health_store.dart';
import '../../data/stores/lists_notes_store.dart';
import '../../data/stores/planner_store.dart';
import '../../data/stores/reminder_store.dart';
import '../theme/app_colors.dart';
import 'entity_navigator.dart';

/// Everything the linking/search/deep-link system needs to know about one
/// [EntityType], in one place, so adding a new linkable module means
/// registering one handler here rather than touching every call site that
/// resolves, labels, or navigates to entities.
class EntityHandler {
  const EntityHandler({
    required this.icon,
    required this.color,
    required this.resolve,
    required this.labelOf,
    required this.open,
  });

  final IconData icon;
  final Color color;

  /// Looks up the live record for [id], or null if it no longer exists.
  final Object? Function(BuildContext context, String id) resolve;

  /// The record's current display label — always derived live from
  /// [resolve], never frozen at link-creation time.
  final String Function(Object record) labelOf;

  /// Opens the right screen for [id], optionally highlighting it if the
  /// target screen supports a `highlightId`.
  final void Function(BuildContext context, String id) open;
}

/// Owns [EntityType] metadata and per-type resolve/label/navigate handlers.
class EntityRegistry {
  const EntityRegistry._();

  static Map<EntityType, EntityHandler>? _handlers;

  static Map<EntityType, EntityHandler> _ensure() {
    return _handlers ??= <EntityType, EntityHandler>{
      EntityType.reminder: EntityHandler(
        icon: Icons.notifications_none,
        color: AppColors.reminders,
        resolve: (BuildContext c, String id) =>
            c.read<ReminderStore>().byId(id),
        labelOf: (Object r) => (r as dynamic).title as String,
        open: (BuildContext c, String id) =>
            EntityNavigatorTargets.openReminders(c, highlightId: id),
      ),
      EntityType.habit: EntityHandler(
        icon: Icons.repeat,
        color: AppColors.success,
        resolve: (BuildContext c, String id) =>
            c.read<PlannerStore>().habitById(id),
        labelOf: (Object h) => (h as dynamic).name as String,
        open: (BuildContext c, String id) =>
            EntityNavigatorTargets.openPlanner(c, highlightId: id),
      ),
      EntityType.plannerEvent: EntityHandler(
        icon: Icons.event_outlined,
        color: AppColors.planner,
        resolve: (BuildContext c, String id) =>
            c.read<PlannerStore>().eventById(id),
        labelOf: (Object e) => (e as dynamic).title as String,
        open: (BuildContext c, String id) =>
            EntityNavigatorTargets.openPlanner(c, highlightId: id),
      ),
      EntityType.expenseTransaction: EntityHandler(
        icon: Icons.currency_rupee,
        color: AppColors.expenses,
        resolve: (BuildContext c, String id) =>
            c.read<ExpenseStore>().transactionById(id),
        labelOf: (Object t) => (t as dynamic).description as String,
        open: (BuildContext c, String id) =>
            EntityNavigatorTargets.openExpenses(c, highlightId: id),
      ),
      EntityType.budgetCategory: EntityHandler(
        icon: Icons.pie_chart_outline,
        color: AppColors.expenses,
        resolve: (BuildContext c, String id) =>
            c.read<ExpenseStore>().categoryById(id),
        labelOf: (Object cat) => (cat as dynamic).name as String,
        open: (BuildContext c, String id) =>
            EntityNavigatorTargets.openExpenses(c, highlightId: id),
      ),
      EntityType.bill: EntityHandler(
        icon: Icons.receipt_long_outlined,
        color: AppColors.bills,
        resolve: (BuildContext c, String id) =>
            c.read<CommitmentsStore>().billById(id),
        labelOf: (Object b) => (b as dynamic).name as String,
        open: (BuildContext c, String id) =>
            EntityNavigatorTargets.openBills(c, highlightId: id),
      ),
      EntityType.membership: EntityHandler(
        icon: Icons.badge_outlined,
        color: AppColors.memberships,
        resolve: (BuildContext c, String id) =>
            c.read<CommitmentsStore>().membershipById(id),
        labelOf: (Object m) => (m as dynamic).name as String,
        open: (BuildContext c, String id) =>
            EntityNavigatorTargets.openMembership(c, id),
      ),
      EntityType.storedDocument: EntityHandler(
        icon: Icons.folder_outlined,
        color: AppColors.documents,
        resolve: (BuildContext c, String id) =>
            c.read<CommitmentsStore>().documentById(id),
        labelOf: (Object d) => (d as dynamic).name as String,
        open: (BuildContext c, String id) =>
            EntityNavigatorTargets.openDocuments(c, highlightId: id),
      ),
      EntityType.taskList: EntityHandler(
        icon: Icons.checklist_outlined,
        color: AppColors.lists,
        resolve: (BuildContext c, String id) =>
            c.read<ListsNotesStore>().listById(id),
        labelOf: (Object l) => (l as dynamic).name as String,
        open: (BuildContext c, String id) =>
            EntityNavigatorTargets.openList(c, id),
      ),
      EntityType.note: EntityHandler(
        icon: Icons.sticky_note_2_outlined,
        color: AppColors.notes,
        resolve: (BuildContext c, String id) =>
            c.read<ListsNotesStore>().noteById(id),
        labelOf: (Object n) => (n as dynamic).title as String,
        open: (BuildContext c, String id) =>
            EntityNavigatorTargets.openNote(c, id),
      ),
      EntityType.labReport: EntityHandler(
        icon: Icons.monitor_heart_outlined,
        color: AppColors.health,
        resolve: (BuildContext c, String id) =>
            c.read<HealthStore>().reportById(id),
        labelOf: (Object r) => (r as dynamic).name as String,
        open: (BuildContext c, String id) =>
            EntityNavigatorTargets.openReport(c, id),
      ),
      EntityType.alarm: EntityHandler(
        icon: Icons.alarm,
        color: AppColors.clock,
        resolve: (BuildContext c, String id) => c.read<AlarmStore>().byId(id),
        labelOf: (Object a) => (a as dynamic).label as String,
        open: (BuildContext c, String id) =>
            EntityNavigatorTargets.openClock(c, highlightId: id),
      ),
    };
  }

  static EntityHandler handlerFor(EntityType type) => _ensure()[type]!;
}
