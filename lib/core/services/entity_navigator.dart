import 'package:flutter/material.dart';

import '../../data/models/entity_ref.dart';
import '../../features/bills/bills_screen.dart';
import '../../features/clock/clock_screen.dart';
import '../../features/documents/document_vault_screen.dart';
import '../../features/expenses/expenses_screen.dart';
import '../../features/health/report_detail_screen.dart';
import '../../features/lists_notes/list_detail_screen.dart';
import '../../features/lists_notes/note_detail_screen.dart';
import '../../features/memberships/membership_detail_screen.dart';
import '../../features/planner/planner_screen.dart';
import '../../features/reminders/reminders_screen.dart';
import 'entity_registry.dart';

/// The actual `Navigator.push` calls each [EntityType] resolves to. Kept
/// separate from [EntityRegistry] so the registry's handler map can stay
/// declarative while the widget-construction detail lives here.
class EntityNavigatorTargets {
  const EntityNavigatorTargets._();

  static void openReminders(BuildContext context, {String? highlightId}) =>
      Navigator.push(
        context,
        MaterialPageRoute<void>(
            builder: (_) => RemindersScreen(highlightId: highlightId)),
      );

  static void openPlanner(BuildContext context, {String? highlightId}) =>
      Navigator.push(
        context,
        MaterialPageRoute<void>(
            builder: (_) => PlannerScreen(highlightId: highlightId)),
      );

  static void openExpenses(BuildContext context, {String? highlightId}) =>
      Navigator.push(
        context,
        MaterialPageRoute<void>(
            builder: (_) => ExpensesScreen(highlightId: highlightId)),
      );

  static void openBills(BuildContext context, {String? highlightId}) =>
      Navigator.push(
        context,
        MaterialPageRoute<void>(
            builder: (_) => BillsScreen(highlightId: highlightId)),
      );

  static void openMembership(BuildContext context, String id) => Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => MembershipDetailScreen(id: id)),
      );

  static void openDocuments(BuildContext context, {String? highlightId}) =>
      Navigator.push(
        context,
        MaterialPageRoute<void>(
            builder: (_) => DocumentVaultScreen(highlightId: highlightId)),
      );

  static void openList(BuildContext context, String id) => Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => ListDetailScreen(listId: id)),
      );

  static void openNote(BuildContext context, String id) => Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => NoteDetailScreen(noteId: id)),
      );

  static void openReport(BuildContext context, String id) => Navigator.push(
        context,
        MaterialPageRoute<void>(
            builder: (_) => ReportDetailScreen(reportId: id)),
      );

  static void openClock(BuildContext context, {String? highlightId}) =>
      Navigator.push(
        context,
        MaterialPageRoute<void>(
            builder: (_) => ClockScreen(highlightId: highlightId)),
      );
}

/// Opens the right screen for an [EntityRef] via [EntityRegistry]'s handler.
class EntityNavigator {
  const EntityNavigator._();

  static void open(BuildContext context, EntityRef ref) {
    EntityRegistry.handlerFor(ref.type).open(context, ref.id);
  }
}
