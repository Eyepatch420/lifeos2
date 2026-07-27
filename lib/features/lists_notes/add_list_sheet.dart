import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/models/enums.dart';
import '../../data/models/lists_notes.dart';
import '../../data/stores/id_gen.dart';
import '../../data/stores/lists_notes_store.dart';

/// PRD 6.3 — create or edit a list.
class AddListSheet extends StatefulWidget {
  const AddListSheet({super.key, this.existing, this.initialType});

  final TaskList? existing;
  final ListType? initialType;

  static Future<void> show(BuildContext context,
      {TaskList? existing, ListType? initialType}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          AddListSheet(existing: existing, initialType: initialType),
    );
  }

  @override
  State<AddListSheet> createState() => _AddListSheetState();
}

class _AddListSheetState extends State<AddListSheet> {
  final TextEditingController _name = TextEditingController();
  late ListType _type;
  late int _color;
  bool _pinned = false;
  bool _shared = false;
  String? _linkedModule;
  bool _submitted = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final TaskList? e = widget.existing;
    _type = e?.type ?? widget.initialType ?? ListType.todo;
    _color = e?.colorValue ?? AppColors.picker[1].toARGB32();
    _pinned = e?.pinned ?? false;
    _shared = e?.shared ?? false;
    _linkedModule = e?.linkedModule;
    if (e != null) _name.text = e.name;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  /// PRD 6.3 AC1 — a blank/placeholder name is blocked.
  String? get _nameError {
    if (!_submitted) return null;
    return _name.text.trim().isEmpty ? 'Give the list a name' : null;
  }

  bool get _isValid => _name.text.trim().isNotEmpty;

  void _save() {
    setState(() => _submitted = true);
    if (!_isValid) return;
    final ListsNotesStore store = context.read<ListsNotesStore>();

    if (_isEdit) {
      final TaskList l = widget.existing!;
      l
        ..name = _name.text.trim()
        ..type = _type
        ..colorValue = _color
        ..pinned = _pinned
        ..shared = _shared
        ..linkedModule = _linkedModule;
      store.updateList(l);
    } else {
      store.addList(TaskList(
        id: IdGen.next('list'),
        name: _name.text.trim(),
        type: _type,
        colorValue: _color,
        pinned: _pinned,
        shared: _shared,
        linkedModule: _linkedModule,
      ));
    }
    Navigator.pop(context);
    showSnack(context, _isEdit ? 'List updated' : 'List created');
  }

  @override
  Widget build(BuildContext context) {
    return SheetScaffold(
      title: _isEdit ? 'Edit list' : 'New list',
      actionLabel: _isEdit ? 'Save changes' : 'Create list',
      actionColor: AppColors.lists,
      onAction: _save,
      children: <Widget>[
        FieldWrap(
          label: 'List name',
          error: _nameError,
          child: TextField(
            controller: _name,
            autofocus: !_isEdit,
            textCapitalization: TextCapitalization.sentences,
            decoration:
                const InputDecoration(hintText: 'e.g. Doctor visit checklist'),
            onChanged: (_) => setState(() {}),
          ),
        ),
        FieldWrap(
          label: 'Type',
          child: GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 3.6,
            children: <Widget>[
              for (final ListType t in ListType.values) _typeChip(t),
            ],
          ),
        ),
        FieldWrap(
          label: 'Colour',
          child: Wrap(
            spacing: 10,
            runSpacing: 8,
            children: <Widget>[
              for (final Color c in AppColors.picker)
                InkWell(
                  onTap: () => setState(() => _color = c.toARGB32()),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: _color == c.toARGB32()
                          ? Border.all(color: context.txtPrimary, width: 2)
                          : null,
                    ),
                    child: _color == c.toARGB32()
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : null,
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 20),
        Text(
          'OPTIONAL',
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
            ChoicePill(
              label: 'Pin to home',
              icon: Icons.push_pin_outlined,
              selected: _pinned,
              color: AppColors.lists,
              onTap: () => setState(() => _pinned = !_pinned),
            ),
            ChoicePill(
              label: _linkedModule == null
                  ? 'Link to module'
                  : 'Linked: $_linkedModule',
              icon: Icons.link,
              selected: _linkedModule != null,
              color: AppColors.lists,
              onTap: _pickModule,
            ),
            ChoicePill(
              label: 'Share list',
              icon: Icons.group_outlined,
              selected: _shared,
              color: AppColors.lists,
              onTap: () => setState(() => _shared = !_shared),
            ),
          ],
        ),
      ],
    );
  }

  Widget _typeChip(ListType t) {
    final bool sel = _type == t;
    final IconData icon = switch (t) {
      ListType.todo => Icons.checklist,
      ListType.shopping => Icons.shopping_cart_outlined,
      ListType.checklist => Icons.fact_check_outlined,
      ListType.custom => Icons.dashboard_customize_outlined,
    };
    return InkWell(
      onTap: () => setState(() => _type = t),
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: sel
              ? AppColors.lists.withValues(alpha: 0.10)
              : Colors.transparent,
          border: Border.all(
            color: sel ? AppColors.lists : context.hairline,
            width: sel ? 1.5 : 0.8,
          ),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          children: <Widget>[
            Icon(icon,
                size: 16, color: sel ? AppColors.lists : context.txtSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                t.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                  color: sel ? AppColors.lists : context.txtSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickModule() async {
    const List<String> modules = <String>[
      'Reminders',
      'Planner',
      'Expenses',
      'Health',
      'Memberships',
      'Documents'
    ];
    final String? picked = await showModalBottomSheet<String>(
      context: context,
      builder: (BuildContext ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.link_off),
              title: const Text('No link'),
              onTap: () => Navigator.pop(ctx, ''),
            ),
            for (final String m in modules)
              ListTile(
                leading: const Icon(Icons.link),
                title: Text(m),
                onTap: () => Navigator.pop(ctx, m),
              ),
          ],
        ),
      ),
    );
    if (picked != null) {
      setState(() => _linkedModule = picked.isEmpty ? null : picked);
    }
  }
}
