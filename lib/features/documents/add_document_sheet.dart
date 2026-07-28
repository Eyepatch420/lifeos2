import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/attachment_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_x.dart';
import '../../core/widgets/alert_type_selector.dart';
import '../../core/widgets/common.dart';
import '../../data/models/commitments.dart';
import '../../data/models/enums.dart';
import '../../data/stores/commitments_store.dart';
import '../../data/stores/id_gen.dart';
import '../../data/stores/settings_store.dart';

/// PRD 9.2 — add / edit a document.
///
/// Closes PRD Gap 3 (any file type, not just image/PDF) and PRD Gap 2
/// (optional per-document lock).
class AddDocumentSheet extends StatefulWidget {
  const AddDocumentSheet({super.key, this.existing});

  final StoredDocument? existing;

  static Future<void> show(BuildContext context, {StoredDocument? existing}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddDocumentSheet(existing: existing),
    );
  }

  @override
  State<AddDocumentSheet> createState() => _AddDocumentSheetState();
}

class _AddDocumentSheetState extends State<AddDocumentSheet> {
  late DocCategory _category;
  final TextEditingController _name = TextEditingController();
  final TextEditingController _note = TextEditingController();
  DateTime? _issue;
  DateTime? _expiry;
  int _leadMonths = 3;
  late AlertType _alert;
  bool _locked = false;
  bool _redact = false;
  String? _fileExtension;
  String? _filePath;
  bool _submitted = false;

  bool get _isEdit => widget.existing != null;

  /// PRD Gap 3 — the picker accepts every common file type, not just images.
  static const List<(String, IconData, String)> _fileTypes =
      <(String, IconData, String)>[
    ('pdf', Icons.picture_as_pdf_outlined, 'PDF'),
    ('jpg', Icons.image_outlined, 'Image'),
    ('png', Icons.image_outlined, 'PNG'),
    ('heic', Icons.image_outlined, 'HEIC'),
    ('docx', Icons.description_outlined, 'Word'),
    ('xlsx', Icons.table_chart_outlined, 'Excel'),
    ('txt', Icons.notes_outlined, 'Text'),
    ('zip', Icons.folder_zip_outlined, 'Archive'),
  ];

  @override
  void initState() {
    super.initState();
    final StoredDocument? e = widget.existing;
    _category = e?.category ?? DocCategory.identity;
    _issue = e?.issueDate;
    _expiry = e?.expiryDate;
    _leadMonths = e?.reminderLeadMonths ?? 3;
    _alert = e?.alertType ?? context.read<SettingsStore>().defaultAlertType;
    _locked = e?.locked ?? false;
    _redact = e?.redactSensitiveNumbers ?? false;
    _fileExtension = e?.fileExtension;
    _filePath = e?.filePath;
    if (e != null) {
      _name.text = e.name;
      _note.text = e.note;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
    super.dispose();
  }

  String? get _nameError {
    if (!_submitted) return null;
    return _name.text.trim().isEmpty ? 'Document name is required' : null;
  }

  bool get _isExpired =>
      _expiry != null && _expiry!.isBefore(dayKey(DateTime.now()));

  bool get _isValid => _name.text.trim().isNotEmpty;

  Future<void> _save() async {
    setState(() => _submitted = true);
    if (!_isValid) return;

    // PRD 9.2 AC1 — an already-past expiry requires explicit confirmation.
    if (_isExpired) {
      final bool ok = await confirmDialog(
        context,
        title: 'This document has already expired',
        message: 'The expiry date you entered '
            '(${fmtShortDate.format(_expiry!)} ${_expiry!.year}) is in the past. '
            'Save it anyway?',
        confirmLabel: 'Save anyway',
        cancelLabel: 'Change date',
        destructive: false,
      );
      if (!ok) return;
    }

    final CommitmentsStore store = context.read<CommitmentsStore>();
    final StoredDocument d = StoredDocument(
      id: widget.existing?.id ?? IdGen.next('doc'),
      name: _name.text.trim(),
      category: _category,
      issueDate: _issue,
      expiryDate: _expiry,
      reminderLeadMonths: _leadMonths,
      alertType: _alert,
      // Previously always taken from `existing`, so a newly attached file
      // was silently dropped on save.
      filePath: _filePath,
      fileExtension: _fileExtension,
      locked: _locked,
      redactSensitiveNumbers: _redact,
      note: _note.text.trim(),
      linkedModule: widget.existing?.linkedModule,
      linkedLabel: widget.existing?.linkedLabel,
    );

    if (_isEdit) {
      store.updateDocument(d);
    } else {
      store.addDocument(d);
    }
    if (!mounted) return;
    Navigator.pop(context);
    showSnack(context, _isEdit ? 'Document updated' : 'Document saved');
  }

  @override
  Widget build(BuildContext context) {
    return SheetScaffold(
      title: _isEdit ? 'Edit document' : 'Add document',
      actionLabel: _isEdit ? 'Save changes' : 'Save document',
      actionColor: AppColors.documents,
      onAction: _save,
      children: <Widget>[
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          childAspectRatio: 3.6,
          children: <Widget>[
            for (final DocCategory c in DocCategory.values) _categoryChip(c),
          ],
        ),
        const SizedBox(height: 14),
        FieldWrap(
          label: 'Document name',
          error: _nameError,
          child: TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'e.g. Driving licence'),
            onChanged: (_) => setState(() {}),
          ),
        ),
        Row(
          children: <Widget>[
            Expanded(
              child: FieldWrap(
                label: 'Issue date',
                child: _dateField(context, _issue, 'Not set',
                    (DateTime? d) => setState(() => _issue = d)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FieldWrap(
                label: 'Expiry date',
                error: _isExpired && _submitted ? 'Already expired' : null,
                child: _dateField(context, _expiry, 'No expiry',
                    (DateTime? d) => setState(() => _expiry = d)),
              ),
            ),
          ],
        ),
        if (_expiry != null) ...<Widget>[
          FieldWrap(
            label: 'Expiry reminder',
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                for (final int m in <int>[1, 3, 6, 12])
                  ChoicePill(
                    label: m == 12 ? '1 year' : '$m month${m == 1 ? '' : 's'}',
                    selected: _leadMonths == m,
                    color: AppColors.documents,
                    onTap: () => setState(() => _leadMonths = m),
                  ),
              ],
            ),
          ),
          AlertTypeSelector(
            value: _alert,
            onChanged: (AlertType t) => setState(() => _alert = t),
            showRepeatInterval: false,
          ),
          const SizedBox(height: 12),
        ],
        // PRD Gap 3 — general file picker supporting any type.
        FieldWrap(
          label: 'Attach file',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              InkWell(
                onTap: _pickFile,
                borderRadius: BorderRadius.circular(9),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: context.hairline, width: 1.2),
                    color: context.fieldColor,
                  ),
                  child: Column(
                    children: <Widget>[
                      Icon(
                        _fileExtension == null
                            ? Icons.upload_file_outlined
                            : Icons.check_circle_outline,
                        size: 24,
                        color: _fileExtension == null
                            ? context.txtTertiary
                            : AppColors.success,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _fileExtension == null
                            ? 'Scan with camera, or upload any file'
                            : '${_name.text.trim().isEmpty ? 'Document' : _name.text.trim()}.$_fileExtension attached',
                        style: TextStyle(
                            fontSize: 12.5, color: context.txtSecondary),
                      ),
                      if (_fileExtension == null)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            'PDF, images, Word, Excel, text, archives…',
                            style: TextStyle(
                                fontSize: 11, color: context.txtTertiary),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: <Widget>[
                  for (final (String ext, IconData icon, String label)
                      in _fileTypes)
                    ChoicePill(
                      label: label,
                      icon: icon,
                      selected: _fileExtension == ext,
                      color: AppColors.documents,
                      onTap: () => setState(() => _fileExtension = ext),
                    ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 20),
        // PRD Gap 2 — per-document lock, over and above the app-wide lock.
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _locked,
          activeThumbColor: AppColors.checkGreen,
          title: const Text('Lock this document',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          subtitle: const Text(
            'Require fingerprint or PIN every time it is opened, '
            'even when the app is already unlocked.',
            style: TextStyle(fontSize: 12),
          ),
          onChanged: (bool v) => setState(() => _locked = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _redact,
          activeThumbColor: AppColors.checkGreen,
          title: const Text('Mask ID numbers',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          subtitle: const Text(
            'Detects Aadhaar/PAN-style numbers and masks them in the stored '
            'file itself, not just on screen.',
            style: TextStyle(fontSize: 12),
          ),
          onChanged: (bool v) => setState(() => _redact = v),
        ),
        const SizedBox(height: 8),
        FieldWrap(
          label: 'Notes (optional)',
          child: TextField(
            controller: _note,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
                hintText: 'e.g. Renewal needs an eye test'),
          ),
        ),
      ],
    );
  }

  Widget _categoryChip(DocCategory c) {
    final bool sel = _category == c;
    final IconData icon = switch (c) {
      DocCategory.identity => Icons.badge_outlined,
      DocCategory.insurance => Icons.verified_user_outlined,
      DocCategory.medical => Icons.medical_information_outlined,
      DocCategory.property => Icons.home_outlined,
      DocCategory.vehicle => Icons.directions_car_outlined,
      DocCategory.other => Icons.insert_drive_file_outlined,
    };
    return InkWell(
      onTap: () => setState(() => _category = c),
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: sel
              ? AppColors.documents.withValues(alpha: 0.12)
              : Colors.transparent,
          border: Border.all(
            color: sel ? AppColors.documents : context.hairline,
            width: sel ? 1.5 : 0.8,
          ),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          children: <Widget>[
            Icon(icon,
                size: 16,
                color: sel ? AppColors.documents : context.txtSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                c.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                  color: sel ? AppColors.documents : context.txtSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateField(BuildContext context, DateTime? value, String placeholder,
      ValueChanged<DateTime?> onChanged) {
    return InkWell(
      onTap: () async {
        final DateTime? p = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(1950),
          lastDate: DateTime(2100),
        );
        if (p != null) onChanged(p);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          suffixIcon: value == null
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear, size: 16),
                  onPressed: () => onChanged(null),
                ),
        ),
        child: Text(
          value == null
              ? placeholder
              : '${fmtShortDate.format(value)} ${value.year}',
          style: TextStyle(
            fontSize: 13,
            color: value == null ? context.txtTertiary : context.txtPrimary,
          ),
        ),
      ),
    );
  }

  /// Attaches a real file, copied into app storage so the vault keeps working
  /// even if the original is moved (PRD 9.1, closes Gap 3 — any file type).
  Future<void> _pickFile() async {
    final String? source = await showModalBottomSheet<String>(
      context: context,
      builder: (BuildContext ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Attach a file',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Scan with camera'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from photos'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.folder_open_outlined),
              title: const Text('Browse all files'),
              subtitle: const Text('Any file type is supported',
                  style: TextStyle(fontSize: 12)),
              onTap: () => Navigator.pop(ctx, 'file'),
            ),
            if (_filePath != null)
              ListTile(
                leading: const Icon(Icons.delete_outline,
                    color: AppColors.dangerBright),
                title: const Text('Remove attachment'),
                onTap: () => Navigator.pop(ctx, 'clear'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;
    if (source == 'clear') {
      setState(() {
        _filePath = null;
        _fileExtension = null;
      });
      return;
    }

    final String? path = source == 'file'
        ? await AttachmentService.pickFile()
        : await AttachmentService.pickImage(fromCamera: source == 'camera');
    if (path == null || !mounted) return;
    setState(() {
      _filePath = path;
      _fileExtension = AttachmentService.extensionOf(path);
    });
  }
}
