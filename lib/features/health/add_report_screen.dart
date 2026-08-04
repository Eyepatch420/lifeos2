import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/attachment_service.dart';
import '../../core/services/ocr_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_x.dart';
import '../../core/widgets/common.dart';
import '../../data/models/enums.dart';
import '../../data/models/health.dart';
import '../../data/stores/health_store.dart';
import '../../data/stores/id_gen.dart';

/// PRD 5.1 / 5.2 — add a lab report by scanning it, then reviewing every
/// extracted value. Extraction is a starting point, never the source of
/// truth, so nothing is saved until the user has seen and confirmed it.
class AddReportScreen extends StatefulWidget {
  const AddReportScreen({super.key, this.existing});

  final LabReport? existing;

  @override
  State<AddReportScreen> createState() => _AddReportScreenState();
}

/// One editable row in the review form.
class _MarkerDraft {
  _MarkerDraft({
    String name = '',
    String value = '',
    String unit = '',
    String low = '',
    String high = '',
  })  : name = TextEditingController(text: name),
        value = TextEditingController(text: value),
        unit = TextEditingController(text: unit),
        low = TextEditingController(text: low),
        high = TextEditingController(text: high);

  final TextEditingController name;
  final TextEditingController value;
  final TextEditingController unit;
  final TextEditingController low;
  final TextEditingController high;

  void dispose() {
    name.dispose();
    value.dispose();
    unit.dispose();
    low.dispose();
    high.dispose();
  }

  bool get isEmpty =>
      name.text.trim().isEmpty && value.text.trim().isEmpty;

  LabMarker? toMarker() {
    final String n = name.text.trim();
    final double? v = double.tryParse(value.text.trim());
    if (n.isEmpty || v == null) return null;
    final (double, double, String)? ref = OcrService.rangeFor(n);
    return LabMarker(
      name: n,
      value: v,
      unit: unit.text.trim().isEmpty ? (ref?.$3 ?? '') : unit.text.trim(),
      normalLow: double.tryParse(low.text.trim()) ?? ref?.$1 ?? 0,
      normalHigh: double.tryParse(high.text.trim()) ?? ref?.$2 ?? 0,
    );
  }
}

class _AddReportScreenState extends State<AddReportScreen> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _lab = TextEditingController();
  final List<_MarkerDraft> _markers = <_MarkerDraft>[];
  DateTime _date = DateTime.now();
  bool _scanning = false;
  bool _autoExtracted = false;
  bool _submitted = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final LabReport? e = widget.existing;
    if (e != null) {
      _name.text = e.name;
      _lab.text = e.lab;
      _date = e.date;
      _autoExtracted = e.autoExtracted;
      for (final LabMarker m in e.markers) {
        _markers.add(_MarkerDraft(
          name: m.name,
          value: m.value.toString(),
          unit: m.unit,
          low: m.normalLow.toString(),
          high: m.normalHigh.toString(),
        ));
      }
    }
    if (_markers.isEmpty) _markers.add(_MarkerDraft());
  }

  @override
  void dispose() {
    _name.dispose();
    _lab.dispose();
    for (final _MarkerDraft d in _markers) {
      d.dispose();
    }
    super.dispose();
  }

  /// Real on-device OCR. Fills the form; the user reviews before saving.
  Future<void> _scan({required bool fromCamera}) async {
    final String? path =
        await AttachmentService.pickImage(fromCamera: fromCamera);
    if (path == null || !mounted) return;

    setState(() => _scanning = true);
    final String text = await OcrService.readText(path);
    if (!mounted) return;

    final List<ScannedMarker> found = OcrService.parseMarkers(text);

    setState(() {
      _scanning = false;
      _autoExtracted = true;
      if (_name.text.trim().isEmpty) {
        _name.text = OcrService.parseMerchant(text) ?? 'Lab report';
      }
      if (found.isNotEmpty) {
        // Drop the blank starter row before adding what we found.
        _markers.removeWhere((_MarkerDraft d) => d.isEmpty);
        for (final ScannedMarker m in found) {
          final (double, double, String)? ref = OcrService.rangeFor(m.name);
          _markers.add(_MarkerDraft(
            name: m.name,
            value: m.value.toString(),
            unit: m.unit.isEmpty ? (ref?.$3 ?? '') : m.unit,
            low: ref?.$1.toString() ?? '',
            high: ref?.$2.toString() ?? '',
          ));
        }
      }
      if (_markers.isEmpty) _markers.add(_MarkerDraft());
    });

    showSnack(
      context,
      found.isEmpty
          ? 'No values could be read — add them manually below'
          : 'Found ${found.length} value${found.length == 1 ? '' : 's'} — '
              'check each one before saving',
    );
  }

  Future<void> _pickScanSource() async {
    final bool? camera = await showModalBottomSheet<bool>(
      context: context,
      builder: (BuildContext c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Photograph the report'),
              onTap: () => Navigator.pop(c, true),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose an image'),
              onTap: () => Navigator.pop(c, false),
            ),
          ],
        ),
      ),
    );
    if (camera == null) return;
    await _scan(fromCamera: camera);
  }

  String? get _nameError {
    if (!_submitted) return null;
    return _name.text.trim().isEmpty ? 'A report name is required' : null;
  }

  List<LabMarker> get _validMarkers => _markers
      .map((_MarkerDraft d) => d.toMarker())
      .whereType<LabMarker>()
      .toList();

  void _save() {
    setState(() => _submitted = true);
    if (_name.text.trim().isEmpty) return;
    if (_validMarkers.isEmpty) {
      showSnack(context, 'Add at least one value with a name and a number');
      return;
    }

    final HealthStore store = context.read<HealthStore>();
    final LabReport report = LabReport(
      id: widget.existing?.id ?? IdGen.next('rep'),
      name: _name.text.trim(),
      lab: _lab.text.trim().isEmpty ? 'Unknown lab' : _lab.text.trim(),
      date: _date,
      markers: _validMarkers,
      autoExtracted: _autoExtracted,
    );

    if (_isEdit) {
      store.updateReport(report);
    } else {
      store.addReport(report);
    }
    Navigator.pop(context);
    showSnack(context, _isEdit ? 'Report updated' : 'Report saved');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.health,
        title: Text(_isEdit ? 'Edit report' : 'Add lab report'),
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
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
        children: <Widget>[
          if (!_isEdit)
            AppCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const IconTile(
                          icon: Icons.document_scanner_outlined,
                          color: AppColors.health,
                          size: 34),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Scan the report to read its values automatically. '
                          'Everything stays editable below.',
                          style: TextStyle(
                              fontSize: 12.5,
                              height: 1.4,
                              color: context.txtSecondary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _scanning ? null : _pickScanSource,
                      icon: _scanning
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.center_focus_strong, size: 18),
                      label: Text(_scanning ? 'Reading…' : 'Scan report'),
                      style: FilledButton.styleFrom(
                          backgroundColor: AppColors.health),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          AppCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: <Widget>[
                FieldWrap(
                  label: 'Report name',
                  error: _nameError,
                  child: TextField(
                    controller: _name,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                        hintText: 'e.g. Complete blood count'),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                FieldWrap(
                  label: 'Lab / source',
                  child: TextField(
                    controller: _lab,
                    textCapitalization: TextCapitalization.words,
                    decoration:
                        const InputDecoration(hintText: 'e.g. SRL Diagnostics'),
                  ),
                ),
                FieldWrap(
                  label: 'Report date',
                  child: InkWell(
                    onTap: () async {
                      final DateTime? p = await showDatePicker(
                        context: context,
                        initialDate: _date,
                        firstDate: DateTime(2015),
                        lastDate: DateTime.now(),
                      );
                      if (p != null && mounted) setState(() => _date = p);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(),
                      child: Row(
                        children: <Widget>[
                          const Icon(Icons.calendar_today_outlined, size: 16),
                          const SizedBox(width: 8),
                          Text(fmtShortDate.format(_date)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SectionLabel('Values', trailing: '${_validMarkers.length} valid'),
          for (int i = 0; i < _markers.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _markerCard(i),
            ),
          const SizedBox(height: 4),
          OutlinedButton.icon(
            onPressed: () => setState(() => _markers.add(_MarkerDraft())),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add another value'),
          ),
          const SizedBox(height: 12),
          // PRD 5.2 — the disclaimer must be permanent, not dismissible.
          const InfoBanner(
            tone: ChipTone.warning,
            icon: Icons.info_outline,
            title: 'Always verify with your doctor',
            text: 'DigiDaily shows values against common reference ranges. It '
                'does not diagnose anything.',
          ),
        ],
      ),
    );
  }

  Widget _markerCard(int index) {
    final _MarkerDraft d = _markers[index];
    final LabMarker? preview = d.toMarker();

    return AppCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: d.name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Marker',
                    hintText: 'e.g. Haemoglobin',
                    isDense: true,
                  ),
                  onChanged: (String v) {
                    // Auto-fill the known range as soon as we recognise it.
                    final (double, double, String)? ref =
                        OcrService.rangeFor(v);
                    if (ref != null && d.low.text.isEmpty) {
                      d.low.text = ref.$1.toString();
                      d.high.text = ref.$2.toString();
                      if (d.unit.text.isEmpty) d.unit.text = ref.$3;
                    }
                    setState(() {});
                  },
                ),
              ),
              if (_markers.length > 1)
                IconButton(
                  tooltip: 'Remove',
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(() {
                    _markers.removeAt(index).dispose();
                  }),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: d.value,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Value', isDense: true),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: d.unit,
                  decoration:
                      const InputDecoration(labelText: 'Unit', isDense: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: d.low,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Normal from', isDense: true),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: d.high,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Normal to', isDense: true),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          if (preview != null) ...<Widget>[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: StatusChip.tone(
                preview.status.label,
                switch (preview.status) {
                  MarkerStatus.normal => ChipTone.success,
                  MarkerStatus.borderline => ChipTone.warning,
                  MarkerStatus.abnormal => ChipTone.danger,
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
