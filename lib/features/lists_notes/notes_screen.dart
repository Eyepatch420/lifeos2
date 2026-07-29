import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/share_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_x.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/module_header.dart';
import '../../data/models/enums.dart';
import '../../data/models/lists_notes.dart';
import '../../data/stores/lists_notes_store.dart';
import 'lists_screen.dart';
import 'note_detail_screen.dart';
import 'note_editor_screen.dart';

/// PRD 6.4 — Notes main list.
class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  int _tab = 0;
  bool _sortByTitle = false;

  static const List<String> _tabs = <String>[
    'All',
    'Health',
    'Finance',
    'Personal',
    'Work'
  ];

  NoteCategory? get _filter => switch (_tab) {
        1 => NoteCategory.health,
        2 => NoteCategory.finance,
        3 => NoteCategory.personal,
        4 => NoteCategory.work,
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final ListsNotesStore store = context.watch<ListsNotesStore>();
    final List<Note> pinned = store.pinnedNotes;
    final List<Note> others = store.filteredNotes(_filter);
    if (_sortByTitle) {
      others.sort((Note a, Note b) =>
          a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    }

    return Scaffold(
      body: Column(
        children: <Widget>[
          ModuleHeader(
            color: AppColors.notes,
            title: 'Notes',
            leading: Navigator.canPop(context)
                ? IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  )
                : null,
            actions: <Widget>[
              HeaderIconButton(
                icon: Icons.checklist_outlined,
                tooltip: 'Lists',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const ListsScreen()),
                ),
              ),
              HeaderIconButton(
                icon: _sortByTitle ? Icons.sort_by_alpha : Icons.sort,
                tooltip: 'Sort',
                onPressed: () => setState(() => _sortByTitle = !_sortByTitle),
              ),
            ],
            tabs: _tabs,
            selectedTab: _tab,
            onTabSelected: (int i) => setState(() => _tab = i),
          ),
          Expanded(
            child: (pinned.isEmpty && others.isEmpty)
                ? EmptyState(
                    icon: Icons.sticky_note_2_outlined,
                    title: 'No notes yet',
                    message: _filter == null
                        ? 'Write your first note with the + button.'
                        : 'No ${_tabs[_tab].toLowerCase()} notes.',
                    actionLabel: 'New note',
                    onAction: () => _openEditor(context),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                    children: <Widget>[
                      if (pinned.isNotEmpty) ...<Widget>[
                        const SectionLabel('Pinned'),
                        for (final Note n in pinned)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _noteCard(context, store, n),
                          ),
                        const SizedBox(height: 6),
                      ],
                      SectionLabel('Recent',
                          trailing: '${others.length} notes'),
                      if (others.isEmpty)
                        const AppCard(
                          child: EmptyState(
                            icon: Icons.filter_alt_outlined,
                            title: 'Nothing here',
                            message: 'No notes match this filter.',
                          ),
                        )
                      else
                        for (final Note n in others)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _noteCard(context, store, n),
                          ),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_notes',
        backgroundColor: AppColors.notes,
        tooltip: 'New note',
        onPressed: () => _openEditor(context),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _noteCard(BuildContext context, ListsNotesStore store, Note n) {
    final Color accent = switch (n.category) {
      NoteCategory.health => AppColors.purple,
      NoteCategory.finance => AppColors.teal,
      NoteCategory.personal => AppColors.info,
      NoteCategory.work => AppColors.notes,
      NoteCategory.uncategorised => AppColors.textTertiary,
    };

    return Dismissible(
      key: ValueKey<String>('note_${n.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        decoration: BoxDecoration(
          color: AppColors.dangerBright,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        final bool ok = await confirmDialog(
          context,
          title: 'Delete "${n.title}"?',
          message: 'This cannot be undone.',
        );
        if (ok) store.deleteNote(n.id);
        return false;
      },
      // A rounded box cannot use a Border whose sides differ in colour —
      // Flutter throws while painting and the card renders blank. The accent
      // stripe is therefore drawn as its own element, not as a border side.
      child: Material(
        color: context.cardColor,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: context.hairline, width: 0.5),
        ),
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
                builder: (_) => NoteDetailScreen(noteId: n.id)),
          ),
          onLongPress: () => _noteMenu(context, store, n),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Container(width: 3, color: accent),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                n.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: context.txtPrimary,
                                ),
                              ),
                            ),
                            if (n.pinned)
                              Icon(Icons.push_pin,
                                  size: 14, color: context.txtTertiary),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // PRD 6.4 AC1 — preview clamped to exactly 2 lines.
                        Text(
                          n.preview,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11.5,
                              height: 1.5,
                              color: context.txtSecondary),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: <Widget>[
                            Text(
                              '${fmtShortDate.format(n.updatedAt)} · ${n.wordCount} words',
                              style: TextStyle(
                                  fontSize: 10.5, color: context.txtTertiary),
                            ),
                            StatusChip.tone(
                                n.category.label,
                                switch (n.category) {
                                  NoteCategory.health => ChipTone.purple,
                                  NoteCategory.finance => ChipTone.success,
                                  NoteCategory.personal => ChipTone.info,
                                  NoteCategory.work => ChipTone.warning,
                                  NoteCategory.uncategorised =>
                                    ChipTone.neutral,
                                }),
                            if (n.links.isNotEmpty)
                              StatusChip.tone('Linked', ChipTone.info,
                                  icon: Icons.link),
                            if (n.actionItems.isNotEmpty)
                              StatusChip.tone(
                                '${n.actionItems.where((ChecklistItem i) => i.done).length}'
                                '/${n.actionItems.length} actions',
                                ChipTone.neutral,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openEditor(BuildContext context, {Note? existing}) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
          builder: (_) => NoteEditorScreen(existing: existing)),
    );
  }

  Future<void> _noteMenu(
      BuildContext context, ListsNotesStore store, Note n) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading:
                  Icon(n.pinned ? Icons.push_pin : Icons.push_pin_outlined),
              title: Text(n.pinned ? 'Unpin' : 'Pin to top'),
              onTap: () {
                store.togglePinNote(n);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit note'),
              onTap: () {
                Navigator.pop(ctx);
                _openEditor(context, existing: n);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: const Text('Copy text'),
              onTap: () async {
                Navigator.pop(ctx);
                await ShareService.copy(store.noteAsPlainText(n));
                if (!context.mounted) return;
                showSnack(context, 'Note copied to clipboard');
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline,
                  color: AppColors.dangerBright),
              title: const Text('Delete note',
                  style: TextStyle(color: AppColors.dangerBright)),
              onTap: () async {
                Navigator.pop(ctx);
                final bool ok = await confirmDialog(
                  context,
                  title: 'Delete "${n.title}"?',
                  message: 'This cannot be undone.',
                );
                if (ok) store.deleteNote(n.id);
              },
            ),
          ],
        ),
      ),
    );
  }
}
