import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/attachment_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/models/enums.dart';
import '../../data/models/lists_notes.dart';
import '../../data/stores/id_gen.dart';
import '../../data/stores/lists_notes_store.dart';

/// PRD 6.6 — note editor with formatting, categories and cross-module links.
class NoteEditorScreen extends StatefulWidget {
  const NoteEditorScreen({super.key, this.existing});

  final Note? existing;

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _body = TextEditingController();
  late NoteCategory _category;
  final List<ChecklistItem> _actions = <ChecklistItem>[];
  final List<NoteLink> _links = <NoteLink>[];
  final List<String> _attachments = <String>[];
  bool _dirty = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final Note? e = widget.existing;
    _category = e?.category ?? NoteCategory.uncategorised;
    if (e != null) {
      _title.text = e.title;
      _body.text = e.body;
      _actions.addAll(e.actionItems);
      _links.addAll(e.links);
      _attachments.addAll(e.attachmentPaths);
    }
    _title.addListener(_markDirty);
    _body.addListener(_markDirty);
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  /// PRD 6.6 AC2 — an empty title is auto-titled rather than blocking save,
  /// which is the documented choice for this app.
  String get _effectiveTitle {
    final String t = _title.text.trim();
    if (t.isNotEmpty) return t;
    final String firstLine = _body.text.trim().split('\n').first.trim();
    if (firstLine.isNotEmpty) {
      return firstLine.length > 40
          ? '${firstLine.substring(0, 40)}…'
          : firstLine;
    }
    return 'Untitled note';
  }

  bool get _hasContent =>
      _title.text.trim().isNotEmpty ||
      _body.text.trim().isNotEmpty ||
      _actions.isNotEmpty;

  void _save() {
    if (!_hasContent) {
      showSnack(context, 'Nothing to save yet');
      return;
    }
    final ListsNotesStore store = context.read<ListsNotesStore>();

    if (_isEdit) {
      final Note n = widget.existing!;
      n
        ..title = _effectiveTitle
        ..body = _body.text
        ..category = _category
        ..actionItems.clear()
        ..actionItems.addAll(_actions)
        ..links.clear()
        ..links.addAll(_links)
        ..attachmentPaths.clear()
        ..attachmentPaths.addAll(_attachments);
      store.updateNote(n);
    } else {
      store.addNote(Note(
        id: IdGen.next('note'),
        title: _effectiveTitle,
        body: _body.text,
        createdAt: DateTime.now(),
        category: _category,
        actionItems: List<ChecklistItem>.from(_actions),
        links: List<NoteLink>.from(_links),
        attachmentPaths: List<String>.from(_attachments),
      ));
    }
    Navigator.pop(context);
    showSnack(context, _isEdit ? 'Note updated' : 'Note saved');
  }

  /// Real photo attachment, copied into app storage (PRD 6.6).
  Future<void> _attachPhoto() async {
    final String? choice = await showModalBottomSheet<String>(
      context: context,
      builder: (BuildContext c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(c, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from photos'),
              onTap: () => Navigator.pop(c, 'gallery'),
            ),
            if (_attachments.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.delete_outline,
                    color: AppColors.dangerBright),
                title: Text('Remove all ${_attachments.length}'),
                onTap: () => Navigator.pop(c, 'clear'),
              ),
          ],
        ),
      ),
    );
    if (choice == null) return;
    if (choice == 'clear') {
      setState(() => _attachments.clear());
      return;
    }
    final String? path =
        await AttachmentService.pickImage(fromCamera: choice == 'camera');
    if (path == null || !mounted) return;
    setState(() => _attachments.add(path));
  }

  /// Explicit save + a guard on back navigation, so nothing is lost silently.
  Future<bool> _confirmLeave() async {
    if (!_dirty || !_hasContent) return true;
    final bool discard = await confirmDialog(
      context,
      title: 'Discard changes?',
      message: 'This note has unsaved changes.',
      confirmLabel: 'Discard',
      cancelLabel: 'Keep editing',
    );
    return discard;
  }

  void _wrapSelection(String prefix, [String? suffix]) {
    final TextSelection sel = _body.selection;
    final String text = _body.text;
    final String close = suffix ?? prefix;
    if (!sel.isValid || sel.isCollapsed) {
      final int pos = sel.isValid ? sel.start : text.length;
      final String next =
          text.substring(0, pos) + prefix + close + text.substring(pos);
      _body.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: pos + prefix.length),
      );
      return;
    }
    final String selected = text.substring(sel.start, sel.end);
    final String next = text.substring(0, sel.start) +
        prefix +
        selected +
        close +
        text.substring(sel.end);
    _body.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(
          offset: sel.end + prefix.length + close.length),
    );
  }

  void _prefixLine(String prefix) {
    final TextSelection sel = _body.selection;
    final String text = _body.text;
    final int pos = sel.isValid ? sel.start : text.length;
    int lineStart = text.lastIndexOf('\n', pos > 0 ? pos - 1 : 0);
    lineStart = lineStart == -1 ? 0 : lineStart + 1;
    final String next =
        text.substring(0, lineStart) + prefix + text.substring(lineStart);
    _body.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: pos + prefix.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) return;
        if (await _confirmLeave() && mounted) Navigator.pop(context);
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.notes,
          title: Text(_isEdit ? 'Edit note' : 'New note'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              if (await _confirmLeave() && mounted) Navigator.pop(context);
            },
          ),
          actions: <Widget>[
            TextButton(
              onPressed: _save,
              child: const Text('Save',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          children: <Widget>[
            AppCard(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: <Widget>[
                  TextField(
                    controller: _title,
                    textCapitalization: TextCapitalization.sentences,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: context.txtPrimary,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Note title',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  Divider(color: context.hairline),
                  TextField(
                    controller: _body,
                    maxLines: null,
                    minLines: 8,
                    textCapitalization: TextCapitalization.sentences,
                    style: TextStyle(
                        fontSize: 13.5,
                        height: 1.65,
                        color: context.txtPrimary),
                    decoration: const InputDecoration(
                      hintText: 'Start typing your note…',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            AppCard(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'FORMATTING',
                    style: TextStyle(
                      fontSize: 10.5,
                      letterSpacing: 0.6,
                      fontWeight: FontWeight.w600,
                      color: context.txtTertiary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: <Widget>[
                      _fmtButton(Icons.format_bold, 'Bold',
                          () => _wrapSelection('**')),
                      _fmtButton(Icons.format_italic, 'Italic',
                          () => _wrapSelection('_')),
                      _fmtButton(Icons.format_underlined, 'Underline',
                          () => _wrapSelection('<u>', '</u>')),
                      _fmtButton(Icons.format_list_bulleted, 'Bullet list',
                          () => _prefixLine('• ')),
                      _fmtButton(Icons.format_list_numbered, 'Numbered list',
                          () => _prefixLine('1. ')),
                      _fmtButton(Icons.checklist, 'Checklist',
                          () => _prefixLine('[ ] ')),
                      _fmtButton(
                          Icons.title, 'Heading', () => _prefixLine('## ')),
                      _fmtButton(
                          Icons.format_quote, 'Quote', () => _prefixLine('> ')),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            AppCard(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'CATEGORY & LINKS',
                    style: TextStyle(
                      fontSize: 10.5,
                      letterSpacing: 0.6,
                      fontWeight: FontWeight.w600,
                      color: context.txtTertiary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // PRD 6.6 FR2 — documented choice: single-select category.
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: <Widget>[
                      for (final NoteCategory c in NoteCategory.values)
                        ChoicePill(
                          label: c.label,
                          icon: Icons.label_outline,
                          selected: _category == c,
                          color: AppColors.notes,
                          onTap: () => setState(() {
                            _category = c;
                            _dirty = true;
                          }),
                        ),
                    ],
                  ),
                  Divider(height: 20, color: context.hairline),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: <Widget>[
                      ChoicePill(
                        label: 'Link to appointment',
                        icon: Icons.link,
                        selected:
                            _links.any((NoteLink l) => l.module == 'Planner'),
                        color: AppColors.notes,
                        onTap: () => _addLink('Planner', 'Appointment'),
                      ),
                      ChoicePill(
                        label: 'Link to report',
                        icon: Icons.link,
                        selected:
                            _links.any((NoteLink l) => l.module == 'Health'),
                        color: AppColors.notes,
                        onTap: () => _addLink('Health', 'Lab report'),
                      ),
                      ChoicePill(
                        label: _attachments.isEmpty
                            ? 'Attach photo'
                            : '${_attachments.length} photo'
                                '${_attachments.length == 1 ? '' : 's'}',
                        icon: Icons.photo_camera_outlined,
                        selected: _attachments.isNotEmpty,
                        color: AppColors.notes,
                        onTap: _attachPhoto,
                      ),
                    ],
                  ),
                  if (_links.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 10),
                    for (final NoteLink l in _links)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: <Widget>[
                            const Icon(Icons.link,
                                size: 15, color: AppColors.purple),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text('${l.module}: ${l.label}',
                                  style: const TextStyle(fontSize: 12)),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.close, size: 15),
                              onPressed: () => setState(() {
                                _links.remove(l);
                                _dirty = true;
                              }),
                            ),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
            AppCard(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          'ACTION ITEMS',
                          style: TextStyle(
                            fontSize: 10.5,
                            letterSpacing: 0.6,
                            fontWeight: FontWeight.w600,
                            color: context.txtTertiary,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _addAction,
                        icon: const Icon(Icons.add, size: 16),
                        label:
                            const Text('Add', style: TextStyle(fontSize: 12.5)),
                      ),
                    ],
                  ),
                  if (_actions.isEmpty)
                    Text(
                      'No action items yet',
                      style:
                          TextStyle(fontSize: 12.5, color: context.txtTertiary),
                    ),
                  for (final ChecklistItem i in _actions)
                    Row(
                      children: <Widget>[
                        Checkbox(
                          value: i.done,
                          visualDensity: VisualDensity.compact,
                          onChanged: (bool? v) => setState(() {
                            i.done = v ?? false;
                            _dirty = true;
                          }),
                        ),
                        Expanded(
                          child: Text(i.text,
                              style: const TextStyle(fontSize: 13)),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: () => setState(() {
                            _actions.remove(i);
                            _dirty = true;
                          }),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fmtButton(IconData icon, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: context.fieldColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: context.txtSecondary),
        ),
      ),
    );
  }

  Future<void> _addAction() async {
    final TextEditingController c = TextEditingController();
    final String? v = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('New action item'),
        content: TextField(
          controller: c,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'e.g. Book blood test'),
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
    setState(() {
      _actions.add(ChecklistItem(id: IdGen.next('act'), text: v.trim()));
      _dirty = true;
    });
  }

  Future<void> _addLink(String module, String label) async {
    final TextEditingController c = TextEditingController(text: label);
    final String? v = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text('Link to $module'),
        content: TextField(
          controller: c,
          decoration: const InputDecoration(labelText: 'What are you linking?'),
        ),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, c.text),
              child: const Text('Link')),
        ],
      ),
    );
    if (v == null || v.trim().isEmpty) return;
    setState(() {
      _links.add(NoteLink(module: module, label: v.trim()));
      _dirty = true;
    });
  }
}
