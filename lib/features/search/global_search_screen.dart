import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_x.dart';
import '../../core/widgets/common.dart';
import '../../data/models/commitments.dart';
import '../../data/models/enums.dart';
import '../../data/models/expense.dart';
import '../../data/models/habit.dart';
import '../../data/models/health.dart';
import '../../data/models/lists_notes.dart';
import '../../data/models/reminder.dart';
import '../../data/stores/commitments_store.dart';
import '../../data/stores/expense_store.dart';
import '../../data/stores/health_store.dart';
import '../../data/stores/lists_notes_store.dart';
import '../../data/stores/planner_store.dart';
import '../../data/stores/reminder_store.dart';
import '../documents/document_vault_screen.dart';
import '../health/report_detail_screen.dart';
import '../lists_notes/list_detail_screen.dart';
import '../lists_notes/note_detail_screen.dart';
import '../memberships/membership_detail_screen.dart';
import '../planner/planner_screen.dart';
import '../reminders/reminders_screen.dart';

class _Result {
  const _Result({
    required this.title,
    required this.subtitle,
    required this.module,
    required this.icon,
    required this.color,
    required this.onOpen,
  });

  final String title;
  final String subtitle;
  final String module;
  final IconData icon;
  final Color color;
  final VoidCallback onOpen;
}

/// Recommended feature from the PRD: one search across every module, so
/// typing "Metformin" surfaces the reminder, the linked note and the document.
class GlobalSearchScreen extends StatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final TextEditingController _query = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  bool _matches(String haystack) =>
      haystack.toLowerCase().contains(_q.toLowerCase());

  List<_Result> _search(BuildContext context) {
    if (_q.trim().length < 2) return <_Result>[];
    final List<_Result> out = <_Result>[];

    for (final Reminder r in context.read<ReminderStore>().all) {
      if (_matches(r.title) || _matches(r.subtitle) || _matches(r.note)) {
        out.add(_Result(
          title: r.title,
          subtitle: '${formatTimeOfDay(r.time)} · ${r.subtitle}',
          module: 'Reminders',
          icon: r.icon,
          color: r.color,
          onOpen: () => Navigator.push(context,
              MaterialPageRoute<void>(builder: (_) => const RemindersScreen())),
        ));
      }
    }

    final PlannerStore planner = context.read<PlannerStore>();
    for (final Habit h in planner.habits) {
      if (_matches(h.name) || _matches(h.note)) {
        out.add(_Result(
          title: h.name,
          subtitle: '${h.durationMinutes} min habit',
          module: 'Planner',
          icon: h.icon,
          color: h.color,
          onOpen: () => Navigator.push(context,
              MaterialPageRoute<void>(builder: (_) => const PlannerScreen())),
        ));
      }
    }
    for (final PlannerEvent e in planner.events) {
      if (_matches(e.title) || _matches(e.location) || _matches(e.note)) {
        out.add(_Result(
          title: e.title,
          subtitle:
              '${relativeDayLabel(e.start, DateTime.now())} · ${e.badgeLabel}',
          module: 'Planner',
          icon: Icons.event_outlined,
          color: e.color,
          onOpen: () => Navigator.push(context,
              MaterialPageRoute<void>(builder: (_) => const PlannerScreen())),
        ));
      }
    }

    final ExpenseStore expenses = context.read<ExpenseStore>();
    for (final ExpenseTransaction t in expenses.allTransactions) {
      if (_matches(t.description) || _matches(t.note) || t.tags.any(_matches)) {
        final BudgetCategory c = expenses.categoryById(t.categoryId);
        out.add(_Result(
          title: t.description,
          subtitle:
              '${formatRupees(t.amount)} · ${c.name} · ${fmtShortDate.format(t.date)}',
          module: 'Expenses',
          icon: c.icon,
          color: c.color,
          onOpen: () => showSnack(context, 'Opening ${t.description}'),
        ));
      }
    }

    final ListsNotesStore ln = context.read<ListsNotesStore>();
    for (final TaskList l in ln.lists) {
      final bool itemHit =
          l.allItems.any((ChecklistItem i) => _matches(i.text));
      if (_matches(l.name) || itemHit) {
        out.add(_Result(
          title: l.name,
          subtitle: itemHit
              ? 'Contains a matching item · ${l.doneCount}/${l.total} done'
              : '${l.type.label} list · ${l.total} items',
          module: 'Lists',
          icon: Icons.checklist,
          color: l.color,
          onOpen: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
                builder: (_) => ListDetailScreen(listId: l.id)),
          ),
        ));
      }
    }
    for (final Note n in ln.notes) {
      if (_matches(n.title) ||
          _matches(n.body) ||
          n.actionItems.any((ChecklistItem i) => _matches(i.text))) {
        out.add(_Result(
          title: n.title,
          subtitle: '${n.category.label} note · '
              '${fmtShortDate.format(n.updatedAt)}',
          module: 'Notes',
          icon: Icons.sticky_note_2_outlined,
          color: AppColors.notes,
          onOpen: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
                builder: (_) => NoteDetailScreen(noteId: n.id)),
          ),
        ));
      }
    }

    final HealthStore health = context.read<HealthStore>();
    for (final LabReport r in health.reports) {
      final bool markerHit = r.markers.any((LabMarker m) => _matches(m.name));
      if (_matches(r.name) || _matches(r.lab) || markerHit) {
        out.add(_Result(
          title: r.name,
          subtitle: '${r.lab} · ${r.summaryBadge}',
          module: 'Health',
          icon: Icons.description_outlined,
          color: AppColors.health,
          onOpen: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
                builder: (_) => ReportDetailScreen(reportId: r.id)),
          ),
        ));
      }
    }

    final CommitmentsStore commitments = context.read<CommitmentsStore>();
    for (final Membership m in commitments.memberships) {
      if (_matches(m.name) || _matches(m.location)) {
        out.add(_Result(
          title: m.name,
          subtitle: '${formatRupees(m.cost)}/${m.cycle.label.toLowerCase()} · '
              '${m.statusChip(DateTime.now())}',
          module: 'Memberships',
          icon: Icons.badge_outlined,
          color: AppColors.memberships,
          onOpen: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
                builder: (_) => MembershipDetailScreen(id: m.id)),
          ),
        ));
      }
    }
    for (final Bill b in commitments.bills) {
      if (_matches(b.name)) {
        out.add(_Result(
          title: b.name,
          subtitle: '${formatRupees(b.amount)} · due '
              '${fmtShortDate.format(b.dueDate)}',
          module: 'Bills',
          icon: Icons.receipt_long_outlined,
          color: AppColors.bills,
          onOpen: () => showSnack(context, 'Opening ${b.name}'),
        ));
      }
    }
    for (final StoredDocument d in commitments.documents) {
      if (_matches(d.name) || _matches(d.note)) {
        out.add(_Result(
          title: d.name,
          subtitle: '${d.category.label} · '
              '${d.statusChip(DateTime.now())}'
              '${d.locked ? ' · Locked' : ''}',
          module: 'Documents',
          icon: d.locked ? Icons.lock_outline : Icons.folder_outlined,
          color: AppColors.documents,
          onOpen: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
                builder: (_) => const DocumentVaultScreen()),
          ),
        ));
      }
    }

    return out;
  }

  @override
  Widget build(BuildContext context) {
    final List<_Result> results = _search(context);
    final Map<String, List<_Result>> grouped = <String, List<_Result>>{};
    for (final _Result r in results) {
      grouped.putIfAbsent(r.module, () => <_Result>[]).add(r);
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.home,
        title: TextField(
          controller: _query,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          cursorColor: Colors.white,
          decoration: InputDecoration(
            hintText: 'Search reminders, notes, expenses…',
            hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.6), fontSize: 15),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
          ),
          onChanged: (String v) => setState(() => _q = v),
        ),
        actions: <Widget>[
          if (_q.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _query.clear();
                setState(() => _q = '');
              },
            ),
        ],
      ),
      body: _q.trim().length < 2
          ? const EmptyState(
              icon: Icons.search,
              title: 'Search everything',
              message: 'Type at least 2 characters to search across reminders, '
                  'habits, expenses, notes, lists, health records, '
                  'memberships, bills and documents.',
            )
          : results.isEmpty
              ? EmptyState(
                  icon: Icons.search_off,
                  title: 'No matches for "$_q"',
                  message: 'Try a different word or check the spelling.',
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                  children: <Widget>[
                    Text(
                      '${results.length} result${results.length == 1 ? '' : 's'} '
                      'across ${grouped.length} module'
                      '${grouped.length == 1 ? '' : 's'}',
                      style:
                          TextStyle(fontSize: 12, color: context.txtSecondary),
                    ),
                    const SizedBox(height: 10),
                    for (final String module in grouped.keys) ...<Widget>[
                      SectionLabel(module,
                          trailing: '${grouped[module]!.length}'),
                      AppCard(
                        child: Column(
                          children: <Widget>[
                            for (int i = 0;
                                i < grouped[module]!.length;
                                i++) ...<Widget>[
                              ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 2),
                                leading: IconTile(
                                  icon: grouped[module]![i].icon,
                                  color: grouped[module]![i].color,
                                ),
                                title: Text(
                                  grouped[module]![i].title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600),
                                ),
                                subtitle: Text(
                                  grouped[module]![i].subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11.5),
                                ),
                                trailing:
                                    const Icon(Icons.chevron_right, size: 20),
                                onTap: grouped[module]![i].onOpen,
                              ),
                              if (i != grouped[module]!.length - 1)
                                Divider(height: 1, color: context.hairline),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
    );
  }
}
