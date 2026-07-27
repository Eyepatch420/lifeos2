import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_x.dart';
import '../../core/widgets/common.dart';
import '../../data/models/enums.dart';
import '../../data/models/lists_notes.dart';
import '../../data/stores/lists_notes_store.dart';
import '../health/report_detail_screen.dart';
import '../planner/planner_screen.dart';
import 'note_editor_screen.dart';

/// PRD 6.5 — full note view, including structured action items and links.
class NoteDetailScreen extends StatelessWidget {
  const NoteDetailScreen({super.key, required this.noteId});

  final String noteId;

  @override
  Widget build(BuildContext context) {
    final ListsNotesStore store = context.watch<ListsNotesStore>();
    final Note? note = store.noteById(noteId);

    if (note == null) {
      return Scaffold(
        appBar: AppBar(
            backgroundColor: AppColors.notes, title: const Text('Note')),
        body: const EmptyState(
          icon: Icons.link_off,
          title: 'Note not found',
          message: 'It may have been deleted.',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.notes,
        title: const Text('Note'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                  builder: (_) => NoteEditorScreen(existing: note)),
            ),
          ),
          IconButton(
            tooltip: note.pinned ? 'Unpin' : 'Pin',
            icon: Icon(note.pinned ? Icons.push_pin : Icons.push_pin_outlined),
            onPressed: () => store.togglePinNote(note),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: <Widget>[
          AppCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  note.title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                    color: context.txtPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: <Widget>[
                    Text(
                      '${fmtShortDate.format(note.updatedAt)} '
                      '${note.updatedAt.year} · ${fmtTime.format(note.updatedAt)}',
                      style: TextStyle(
                          fontSize: 10.5, color: context.txtTertiary),
                    ),
                    const SizedBox(width: 8),
                    StatusChip.tone(note.category.label, switch (note.category) {
                      NoteCategory.health => ChipTone.purple,
                      NoteCategory.finance => ChipTone.success,
                      NoteCategory.personal => ChipTone.info,
                      NoteCategory.work => ChipTone.warning,
                      NoteCategory.uncategorised => ChipTone.neutral,
                    }),
                  ],
                ),
                Divider(height: 20, color: context.hairline),
                if (note.body.trim().isNotEmpty) ...<Widget>[
                  Text(
                    'SUMMARY',
                    style: TextStyle(
                      fontSize: 10.5,
                      letterSpacing: 0.6,
                      fontWeight: FontWeight.w600,
                      color: context.txtTertiary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    note.body,
                    style: TextStyle(
                        fontSize: 13.5, height: 1.65, color: context.txtPrimary),
                  ),
                ],
                // PRD 6.5 FR1 — action items are real data, not markdown text.
                if (note.actionItems.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 16),
                  Text(
                    'ACTION ITEMS',
                    style: TextStyle(
                      fontSize: 10.5,
                      letterSpacing: 0.6,
                      fontWeight: FontWeight.w600,
                      color: context.txtTertiary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  for (final ChecklistItem i in note.actionItems)
                    InkWell(
                      onTap: () => store.toggleNoteAction(note, i),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Container(
                              width: 18,
                              height: 18,
                              margin: const EdgeInsets.only(top: 1),
                              decoration: BoxDecoration(
                                color: i.done
                                    ? AppColors.checkGreen
                                    : Colors.transparent,
                                border: Border.all(
                                  color: i.done
                                      ? AppColors.checkGreen
                                      : AppColors.borderSecondary,
                                  width: 1.5,
                                ),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: i.done
                                  ? const Icon(Icons.check,
                                      size: 12, color: Colors.white)
                                  : null,
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                i.text,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  color: i.done
                                      ? context.txtSecondary
                                      : context.txtPrimary,
                                  decoration: i.done
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
                if (note.calloutTitle != null) ...<Widget>[
                  const SizedBox(height: 16),
                  Text(
                    note.calloutTitle!.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10.5,
                      letterSpacing: 0.6,
                      fontWeight: FontWeight.w600,
                      color: context.txtTertiary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: context.fieldColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      note.calloutBody ?? '',
                      style: TextStyle(
                          fontSize: 12.5, color: context.txtSecondary),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (note.links.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            AppCard(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'LINKED TO',
                    style: TextStyle(
                      fontSize: 10.5,
                      letterSpacing: 0.6,
                      fontWeight: FontWeight.w600,
                      color: context.txtTertiary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // PRD 6.5 AC1 — each link opens its EXACT target.
                  for (final NoteLink l in note.links)
                    InkWell(
                      onTap: () => _openLink(context, l),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: <Widget>[
                            Icon(
                              switch (l.module) {
                                'Health' => Icons.monitor_heart_outlined,
                                'Planner' => Icons.calendar_today_outlined,
                                'Expenses' => Icons.currency_rupee,
                                _ => Icons.link,
                              },
                              size: 16,
                              color: AppColors.purple,
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                l.label,
                                style: TextStyle(
                                    fontSize: 12.5, color: context.txtPrimary),
                              ),
                            ),
                            Icon(Icons.chevron_right,
                                size: 17, color: context.txtTertiary),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => showSnack(context, 'Note shared'),
                  icon: const Icon(Icons.ios_share, size: 16),
                  label: const Text('Share', style: TextStyle(fontSize: 12.5)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  // PRD 6.5 AC2 — copies the COMPLETE content incl. actions.
                  onPressed: () {
                    store.noteAsPlainText(note);
                    showSnack(context,
                        'Full note (with action items) copied to clipboard');
                  },
                  icon: const Icon(Icons.copy_outlined, size: 16),
                  label: const Text('Copy text',
                      style: TextStyle(fontSize: 12.5)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => showSnack(context, 'Exported as PDF'),
                  icon: const Icon(Icons.file_download_outlined, size: 16),
                  label:
                      const Text('Export', style: TextStyle(fontSize: 12.5)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openLink(BuildContext context, NoteLink l) {
    if (l.module == 'Health' && l.targetId != null) {
      Navigator.push(
        context,
        MaterialPageRoute<void>(
            builder: (_) => ReportDetailScreen(reportId: l.targetId!)),
      );
      return;
    }
    if (l.module == 'Planner') {
      Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => const PlannerScreen()),
      );
      return;
    }
    showSnack(context, 'Opening ${l.label}…');
  }
}
