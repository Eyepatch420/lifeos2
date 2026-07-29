import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/share_service.dart';
import '../expenses/expenses_screen.dart';
import '../health/health_screen.dart';
import '../planner/planner_screen.dart';
import '../reminders/reminders_screen.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/models/lists_notes.dart';
import '../../data/stores/lists_notes_store.dart';
import 'add_list_sheet.dart';

/// PRD 6.2 — one list's items, optionally grouped into sections.
class ListDetailScreen extends StatefulWidget {
  const ListDetailScreen({super.key, required this.listId});

  final String listId;

  @override
  State<ListDetailScreen> createState() => _ListDetailScreenState();
}

class _ListDetailScreenState extends State<ListDetailScreen> {
  final TextEditingController _newItem = TextEditingController();

  @override
  void dispose() {
    _newItem.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ListsNotesStore store = context.watch<ListsNotesStore>();
    final TaskList? list = store.listById(widget.listId);

    if (list == null) {
      return Scaffold(
        appBar:
            AppBar(backgroundColor: AppColors.lists, title: const Text('List')),
        body: const EmptyState(
          icon: Icons.link_off,
          title: 'List not found',
          message: 'It may have been deleted.',
        ),
      );
    }

    return Scaffold(
      body: Column(
        children: <Widget>[
          _header(context, store, list),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              children: <Widget>[
                for (final ListSection s in list.sections)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _sectionCard(context, store, list, s),
                  ),
                _addItemRow(context, store, list),
                if (list.linkedModule != null) ...<Widget>[
                  const SizedBox(height: 12),
                  // PRD 6.2 FR5 / G.4 — tappable cross-module link.
                  InfoBanner(
                    tone: ChipTone.purple,
                    icon: Icons.link,
                    title: 'Linked to ${list.linkedModule} module',
                    text: list.linkedLabel ?? '',
                    onTap: () => _openLinkedModule(context, list),
                  ),
                ],
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    'Swipe an item left to delete it',
                    style:
                        TextStyle(fontSize: 11.5, color: context.txtTertiary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_list_detail',
        backgroundColor: list.color,
        tooltip: 'Add section',
        onPressed: () => _addSection(context, store, list),
        child: const Icon(Icons.playlist_add, color: Colors.white),
      ),
    );
  }

  Widget _header(BuildContext context, ListsNotesStore store, TaskList list) {
    return Container(
      color: list.color,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 14, 14),
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      list.name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Share',
                    icon: const Icon(Icons.ios_share, color: Colors.white),
                    onPressed: () => ShareService.shareText(
                        store.listAsPlainText(list),
                        subject: list.name),
                  ),
                  IconButton(
                    tooltip: 'Edit list',
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                    onPressed: () => AddListSheet.show(context, existing: list),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 12, top: 4),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: list.progress,
                          minHeight: 5,
                          backgroundColor: Colors.white.withValues(alpha: 0.25),
                          valueColor:
                              const AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${list.doneCount} of ${list.total} done',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.85)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionCard(BuildContext context, ListsNotesStore store,
      TaskList list, ListSection section) {
    final int done = section.items.where((ChecklistItem i) => i.done).length;

    return AppCard(
      child: Column(
        children: <Widget>[
          if (section.name.trim().isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: context.hairline)),
              ),
              child: Row(
                children: <Widget>[
                  Icon(Icons.label_outline,
                      size: 14, color: context.txtTertiary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Section: ${section.name}',
                      style: TextStyle(
                          fontSize: 11.5, color: context.txtSecondary),
                    ),
                  ),
                  Text(
                    '$done/${section.items.length}',
                    style:
                        TextStyle(fontSize: 11.5, color: context.txtTertiary),
                  ),
                ],
              ),
            ),
          if (section.items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Text(
                'No items in this section yet',
                style: TextStyle(fontSize: 12.5, color: context.txtTertiary),
              ),
            ),
          for (int i = 0; i < section.items.length; i++) ...<Widget>[
            _itemRow(context, store, list, section.items[i]),
            if (i != section.items.length - 1)
              Divider(height: 1, color: context.hairline),
          ],
        ],
      ),
    );
  }

  Widget _itemRow(BuildContext context, ListsNotesStore store, TaskList list,
      ChecklistItem item) {
    return Dismissible(
      key: ValueKey<String>('item_${item.id}'),
      direction: DismissDirection.endToStart,
      // Same 50% threshold as Reminders, so no accidental deletes (6.2 AC3).
      dismissThresholds: const <DismissDirection, double>{
        DismissDirection.endToStart: 0.5,
      },
      background: Container(
        color: AppColors.dangerBright,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) {
        store.deleteItem(list, item);
        showSnack(context, 'Item deleted');
      },
      child: InkWell(
        onTap: () => store.toggleItem(list, item),
        onLongPress: () => _editItem(context, store, item),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 19,
                height: 19,
                margin: const EdgeInsets.only(top: 1),
                decoration: BoxDecoration(
                  color: item.done ? AppColors.checkGreen : Colors.transparent,
                  border: Border.all(
                    color: item.done
                        ? AppColors.checkGreen
                        : AppColors.borderSecondary,
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: item.done
                    ? const Icon(Icons.check, size: 13, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      item.text,
                      style: TextStyle(
                        fontSize: 13,
                        color: item.done
                            ? context.txtSecondary
                            : context.txtPrimary,
                        decoration:
                            item.done ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    if (item.note.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'Note: ${item.note}',
                          style: TextStyle(
                              fontSize: 11.5, color: context.txtTertiary),
                        ),
                      ),
                  ],
                ),
              ),
              if (item.note.isNotEmpty)
                Icon(Icons.notes, size: 15, color: context.txtTertiary),
            ],
          ),
        ),
      ),
    );
  }

  /// PRD 6.2 FR4 — inline add, no modal.
  Widget _addItemRow(
      BuildContext context, ListsNotesStore store, TaskList list) {
    return Container(
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.hairline, style: BorderStyle.solid),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: <Widget>[
          Icon(Icons.add, size: 18, color: context.txtTertiary),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _newItem,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Add item…',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
              onSubmitted: (String v) => _submitItem(store, list, v),
            ),
          ),
          if (_newItem.text.trim().isNotEmpty)
            IconButton(
              icon: Icon(Icons.check, color: list.color),
              onPressed: () => _submitItem(store, list, _newItem.text),
            ),
        ],
      ),
    );
  }

  void _submitItem(ListsNotesStore store, TaskList list, String value) {
    if (value.trim().isEmpty) return;
    // Append to the last section so sectioned lists behave predictably.
    store.addItem(list, value, sectionIndex: list.sections.length - 1);
    _newItem.clear();
    setState(() {});
  }

  Future<void> _editItem(
      BuildContext context, ListsNotesStore store, ChecklistItem item) async {
    final TextEditingController text = TextEditingController(text: item.text);
    final TextEditingController note = TextEditingController(text: item.note);
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Edit item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: text,
              decoration: const InputDecoration(labelText: 'Item'),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: note,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save')),
        ],
      ),
    );
    if (ok != true || text.text.trim().isEmpty || !mounted) return;
    // Goes through the store so every other screen watching it rebuilds —
    // mutating the item directly left the rest of the app stale.
    context.read<ListsNotesStore>().updateItem(
          item,
          text: text.text.trim(),
          note: note.text.trim(),
        );
  }

  /// PRD G.4 — the cross-module link badge actually navigates.
  void _openLinkedModule(BuildContext context, TaskList list) {
    switch (list.linkedModule) {
      case 'Health':
        Navigator.push(context,
            MaterialPageRoute<void>(builder: (_) => const HealthScreen()));
      case 'Planner':
        Navigator.push(context,
            MaterialPageRoute<void>(builder: (_) => const PlannerScreen()));
      case 'Expenses':
        Navigator.push(context,
            MaterialPageRoute<void>(builder: (_) => const ExpensesScreen()));
      case 'Reminders':
        Navigator.push(context,
            MaterialPageRoute<void>(builder: (_) => const RemindersScreen()));
      default:
        showSnack(context, 'No screen linked yet');
    }
  }

  Future<void> _addSection(
      BuildContext context, ListsNotesStore store, TaskList list) async {
    final TextEditingController c = TextEditingController();
    final String? v = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('New section'),
        content: TextField(
          controller: c,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'e.g. Questions to ask'),
        ),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, c.text),
              child: const Text('Add')),
        ],
      ),
    );
    if (v == null || v.trim().isEmpty) return;
    store.addSection(list, v.trim());
  }
}
