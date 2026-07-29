import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/entity_navigator.dart';
import '../../core/services/entity_resolver.dart';
import '../../core/services/share_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_x.dart';
import '../../core/widgets/common.dart';
import '../../data/models/enums.dart';
import '../../data/models/lists_notes.dart';
import '../../data/stores/lists_notes_store.dart';
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
        appBar:
            AppBar(backgroundColor: AppColors.notes, title: const Text('Note')),
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
                      style:
                          TextStyle(fontSize: 10.5, color: context.txtTertiary),
                    ),
                    const SizedBox(width: 8),
                    StatusChip.tone(
                        note.category.label,
                        switch (note.category) {
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
                  // The editor's formatting buttons insert markdown, so render
                  // it here instead of showing the raw ** and ## characters.
                  _NoteBody(body: note.body),
                ],
                if (note.attachmentPaths.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 16),
                  Text(
                    'ATTACHMENTS',
                    style: TextStyle(
                      fontSize: 10.5,
                      letterSpacing: 0.6,
                      fontWeight: FontWeight.w600,
                      color: context.txtTertiary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 92,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: note.attachmentPaths.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (BuildContext c, int i) {
                        final String p = note.attachmentPaths[i];
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(p),
                            width: 92,
                            height: 92,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 92,
                              height: 92,
                              color: c.fieldColor,
                              child: Icon(Icons.broken_image_outlined,
                                  color: c.txtTertiary),
                            ),
                          ),
                        );
                      },
                    ),
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
                  // PRD 6.5 AC1 — each link opens its EXACT target. Labels
                  // resolve live via EntityResolver so a rename of the
                  // target is reflected without re-saving the link.
                  for (final NoteLink l in note.links)
                    _linkRow(context, l),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => ShareService.shareText(
                    store.noteAsPlainText(note),
                    subject: note.title,
                  ),
                  icon: const Icon(Icons.ios_share, size: 16),
                  label: const Text('Share', style: TextStyle(fontSize: 12.5)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  // PRD 6.5 AC2 — copies the COMPLETE content incl. actions.
                  onPressed: () async {
                    await ShareService.copy(store.noteAsPlainText(note));
                    if (!context.mounted) return;
                    showSnack(context,
                        'Full note (with action items) copied to clipboard');
                  },
                  icon: const Icon(Icons.copy_outlined, size: 16),
                  label:
                      const Text('Copy text', style: TextStyle(fontSize: 12.5)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final String safe = note.title
                        .replaceAll(RegExp(r'[^A-Za-z0-9 _-]'), '')
                        .trim();
                    await ShareService.shareAsFile(
                      store.noteAsPlainText(note),
                      '${safe.isEmpty ? 'note' : safe}.txt',
                      subject: note.title,
                    );
                  },
                  icon: const Icon(Icons.file_download_outlined, size: 16),
                  label: const Text('Export', style: TextStyle(fontSize: 12.5)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// A link row whose label and existence are resolved live from the
  /// target's store — a rename propagates automatically, and a deleted
  /// target shows "no longer exists" instead of opening a dead screen.
  Widget _linkRow(BuildContext context, NoteLink l) {
    final String? liveLabel =
        l.ref == null ? null : EntityResolver.labelFor(context, l.ref!);
    final bool broken = l.ref != null && liveLabel == null;
    final String label = liveLabel ?? l.label;

    return InkWell(
      onTap: broken
          ? () => showSnack(context, 'Linked item no longer exists')
          : () => l.ref != null
              ? EntityNavigator.open(context, l.ref!)
              : showSnack(context, 'Opening ${l.label}…'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: <Widget>[
            Icon(
              broken
                  ? Icons.link_off
                  : switch (l.module) {
                      'Health' => Icons.monitor_heart_outlined,
                      'Planner' => Icons.calendar_today_outlined,
                      'Expenses' => Icons.currency_rupee,
                      _ => Icons.link,
                    },
              size: 16,
              color: broken ? context.txtTertiary : AppColors.purple,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                broken ? 'Linked item no longer exists' : label,
                style: TextStyle(
                  fontSize: 12.5,
                  color: broken ? context.txtTertiary : context.txtPrimary,
                  fontStyle: broken ? FontStyle.italic : FontStyle.normal,
                ),
              ),
            ),
            if (!broken)
              Icon(Icons.chevron_right, size: 17, color: context.txtTertiary),
          ],
        ),
      ),
    );
  }
}

/// Renders exactly the markup the editor's formatting buttons can produce:
/// **bold**, _italic_, <u>underline</u>, "## " headings and "> " quotes.
/// Anything else is shown verbatim, so no content is ever swallowed.
class _NoteBody extends StatelessWidget {
  const _NoteBody({required this.body});

  final String body;

  static final RegExp _inline = RegExp(r'\*\*(.+?)\*\*|_(.+?)_|<u>(.+?)</u>');

  @override
  Widget build(BuildContext context) {
    final TextStyle base =
        TextStyle(fontSize: 13.5, height: 1.65, color: context.txtPrimary);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final String line in body.split('\n'))
          if (line.startsWith('## '))
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 2),
              child: Text(
                line.substring(3),
                style:
                    base.copyWith(fontSize: 15.5, fontWeight: FontWeight.w700),
              ),
            )
          else if (line.startsWith('> '))
            Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.only(left: 10),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: context.hairline, width: 3),
                ),
              ),
              child: Text(
                line.substring(2),
                style: base.copyWith(
                    fontStyle: FontStyle.italic, color: context.txtSecondary),
              ),
            )
          else
            RichText(text: TextSpan(style: base, children: _spans(line, base))),
      ],
    );
  }

  List<InlineSpan> _spans(String line, TextStyle base) {
    final List<InlineSpan> out = <InlineSpan>[];
    int cursor = 0;
    for (final RegExpMatch m in _inline.allMatches(line)) {
      if (m.start > cursor) {
        out.add(TextSpan(text: line.substring(cursor, m.start)));
      }
      if (m.group(1) != null) {
        out.add(TextSpan(
            text: m.group(1),
            style: base.copyWith(fontWeight: FontWeight.w700)));
      } else if (m.group(2) != null) {
        out.add(TextSpan(
            text: m.group(2),
            style: base.copyWith(fontStyle: FontStyle.italic)));
      } else {
        out.add(TextSpan(
            text: m.group(3),
            style: base.copyWith(decoration: TextDecoration.underline)));
      }
      cursor = m.end;
    }
    if (cursor < line.length) out.add(TextSpan(text: line.substring(cursor)));
    return out;
  }
}
