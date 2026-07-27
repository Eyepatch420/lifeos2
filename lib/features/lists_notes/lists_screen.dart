import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/module_header.dart';
import '../../data/models/enums.dart';
import '../../data/models/lists_notes.dart';
import '../../data/stores/lists_notes_store.dart';
import 'add_list_sheet.dart';
import 'list_detail_screen.dart';
import 'notes_screen.dart';

/// PRD 6.1 — Lists main. The "Notes" action in the header is the shared
/// entry point requested in PRD Gap 1, keeping Lists and Notes one hop apart
/// without collapsing two different data models into one screen.
class ListsScreen extends StatefulWidget {
  const ListsScreen({super.key});

  @override
  State<ListsScreen> createState() => _ListsScreenState();
}

class _ListsScreenState extends State<ListsScreen> {
  int _tab = 0;
  bool _sortByProgress = false;

  static const List<String> _tabs = <String>[
    'All',
    'To-do',
    'Shopping',
    'Checklist',
    'Custom'
  ];

  ListType? get _filter => switch (_tab) {
        1 => ListType.todo,
        2 => ListType.shopping,
        3 => ListType.checklist,
        4 => ListType.custom,
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final ListsNotesStore store = context.watch<ListsNotesStore>();
    final List<TaskList> pinned = store.pinnedLists;
    final List<TaskList> others = store.filteredLists(_filter);

    if (_sortByProgress) {
      others.sort((TaskList a, TaskList b) => b.progress.compareTo(a.progress));
    }

    return Scaffold(
      body: Column(
        children: <Widget>[
          ModuleHeader(
            color: AppColors.lists,
            title: 'Lists',
            leading: Navigator.canPop(context)
                ? IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  )
                : null,
            actions: <Widget>[
              HeaderIconButton(
                icon: Icons.sticky_note_2_outlined,
                tooltip: 'Notes',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const NotesScreen()),
                ),
              ),
              HeaderIconButton(
                icon: _sortByProgress ? Icons.sort : Icons.sort_by_alpha,
                tooltip: 'Sort',
                onPressed: () =>
                    setState(() => _sortByProgress = !_sortByProgress),
              ),
            ],
            tabs: _tabs,
            selectedTab: _tab,
            onTabSelected: (int i) => setState(() => _tab = i),
          ),
          Expanded(
            child: (pinned.isEmpty && others.isEmpty)
                ? EmptyState(
                    icon: Icons.checklist_outlined,
                    title: 'No lists yet',
                    message: _filter == null
                        ? 'Create your first list with the + button.'
                        : 'No ${_tabs[_tab].toLowerCase()} lists.',
                    actionLabel: 'Create list',
                    onAction: () =>
                        AddListSheet.show(context, initialType: _filter),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                    children: <Widget>[
                      if (pinned.isNotEmpty) ...<Widget>[
                        const SectionLabel('Pinned'),
                        for (final TaskList l in pinned)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _pinnedCard(context, store, l),
                          ),
                        const SizedBox(height: 6),
                      ],
                      SectionLabel('All lists',
                          trailing: '${others.length} lists'),
                      if (others.isEmpty)
                        const AppCard(
                          child: EmptyState(
                            icon: Icons.filter_alt_outlined,
                            title: 'Nothing here',
                            message: 'No lists match this filter.',
                          ),
                        )
                      else
                        AppCard(
                          child: Column(
                            children: <Widget>[
                              for (int i = 0;
                                  i < others.length;
                                  i++) ...<Widget>[
                                _listRow(context, store, others[i]),
                                if (i != others.length - 1)
                                  Divider(height: 1, color: context.hairline),
                              ],
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.lists,
        tooltip: 'New list',
        onPressed: () => AddListSheet.show(context, initialType: _filter),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  /// Pinned card shows up to 3 items inline, each directly checkable
  /// (PRD 6.1 FR2 / AC1).
  Widget _pinnedCard(BuildContext context, ListsNotesStore store, TaskList l) {
    final List<ChecklistItem> items = l.allItems;
    final List<ChecklistItem> preview = items.take(3).toList();
    final int remaining = items.length - preview.length;

    return AppCard(
      child: Column(
        children: <Widget>[
          InkWell(
            onTap: () => _open(context, l),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: l.color,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          l.name,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: context.txtPrimary,
                          ),
                        ),
                        Text(
                          '${l.doneCount} of ${l.total} done'
                          '${l.linkedLabel == null ? '' : ' · ${l.linkedLabel}'}',
                          style: TextStyle(
                              fontSize: 11.5, color: context.txtSecondary),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 62,
                    child: ThinProgressBar(value: l.progress, color: l.color),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.chevron_right,
                      size: 18, color: context.txtTertiary),
                ],
              ),
            ),
          ),
          for (final ChecklistItem i in preview) ...<Widget>[
            Divider(height: 1, color: context.hairline),
            InkWell(
              onTap: () => store.toggleItem(l, i),
              child: Padding(
                padding: const EdgeInsets.only(
                    left: 34, right: 12, top: 8, bottom: 8),
                child: Row(
                  children: <Widget>[
                    _checkbox(context, i.done),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        i.text,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: i.done
                              ? context.txtSecondary
                              : context.txtPrimary,
                          decoration:
                              i.done ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (remaining > 0)
            InkWell(
              onTap: () => _open(context, l),
              child: Padding(
                padding: const EdgeInsets.only(
                    left: 34, right: 12, top: 7, bottom: 9),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '+$remaining more item${remaining == 1 ? '' : 's'}',
                    style:
                        TextStyle(fontSize: 11.5, color: context.txtTertiary),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _listRow(BuildContext context, ListsNotesStore store, TaskList l) {
    final IconData icon = switch (l.type) {
      ListType.todo => Icons.checklist,
      ListType.shopping => Icons.shopping_cart_outlined,
      ListType.checklist => Icons.fact_check_outlined,
      ListType.custom => Icons.dashboard_customize_outlined,
    };

    return Dismissible(
      key: ValueKey<String>('list_${l.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: AppColors.dangerBright,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        final bool ok = await confirmDialog(
          context,
          title: 'Delete ${l.name}?',
          message: 'This removes the list and all ${l.total} of its items. '
              'This cannot be undone.',
        );
        if (ok) store.deleteList(l.id);
        return false;
      },
      child: InkWell(
        onTap: () => _open(context, l),
        onLongPress: () => _listMenu(context, store, l),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: <Widget>[
              IconTile(icon: icon, color: l.color),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      l.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: context.txtPrimary,
                      ),
                    ),
                    Text(
                      '${l.total} items · ${l.doneCount} done'
                      '${l.linkedModule == null ? '' : ' · linked to ${l.linkedModule}'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11.5, color: context.txtSecondary),
                    ),
                    const SizedBox(height: 5),
                    ThinProgressBar(
                        value: l.progress, color: l.color, height: 4),
                  ],
                ),
              ),
              const SizedBox(width: 9),
              StatusChip.tone(
                  l.type.label,
                  switch (l.type) {
                    ListType.todo => ChipTone.danger,
                    ListType.shopping => ChipTone.warning,
                    ListType.checklist => ChipTone.purple,
                    ListType.custom => ChipTone.success,
                  }),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, size: 18, color: context.txtTertiary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _checkbox(BuildContext context, bool done) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: done ? AppColors.checkGreen : Colors.transparent,
        border: Border.all(
          color: done ? AppColors.checkGreen : AppColors.borderSecondary,
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(5),
      ),
      child:
          done ? const Icon(Icons.check, size: 12, color: Colors.white) : null,
    );
  }

  void _open(BuildContext context, TaskList l) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => ListDetailScreen(listId: l.id)),
    );
  }

  Future<void> _listMenu(
      BuildContext context, ListsNotesStore store, TaskList l) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading:
                  Icon(l.pinned ? Icons.push_pin : Icons.push_pin_outlined),
              title: Text(l.pinned ? 'Unpin from home' : 'Pin to home'),
              onTap: () {
                store.togglePinList(l);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit list'),
              onTap: () {
                Navigator.pop(ctx);
                AddListSheet.show(context, existing: l);
              },
            ),
            ListTile(
              leading: const Icon(Icons.ios_share),
              title: const Text('Share list'),
              onTap: () {
                Navigator.pop(ctx);
                showSnack(context, '${l.name} copied to clipboard');
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline,
                  color: AppColors.dangerBright),
              title: const Text('Delete list',
                  style: TextStyle(color: AppColors.dangerBright)),
              onTap: () async {
                Navigator.pop(ctx);
                final bool ok = await confirmDialog(
                  context,
                  title: 'Delete ${l.name}?',
                  message: 'This removes the list and all its items. '
                      'This cannot be undone.',
                );
                if (ok) store.deleteList(l.id);
              },
            ),
          ],
        ),
      ),
    );
  }
}
