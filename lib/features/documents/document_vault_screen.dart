import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/attachment_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/share_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_x.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/highlight_row.dart';
import '../../core/widgets/module_header.dart';
import '../../data/models/commitments.dart';
import '../../data/models/enums.dart';
import '../../data/stores/commitments_store.dart';
import 'add_document_sheet.dart';

/// PRD 9.1 — document vault with expiry alerts and a per-document lock
/// (closing PRD Gap 2).
class DocumentVaultScreen extends StatefulWidget {
  const DocumentVaultScreen({super.key, this.highlightId});

  /// A document id to flash/scroll to on open — set when arriving from
  /// search or a notification tap.
  final String? highlightId;

  @override
  State<DocumentVaultScreen> createState() => _DocumentVaultScreenState();
}

class _DocumentVaultScreenState extends State<DocumentVaultScreen> {
  int _tab = 0;

  /// Documents unlocked during this session only — locking re-arms on exit.
  final Set<String> _unlocked = <String>{};

  static const List<String> _tabs = <String>[
    'All',
    'Identity',
    'Financial',
    'Medical',
    'More'
  ];

  DocCategory? get _filter => switch (_tab) {
        1 => DocCategory.identity,
        2 => DocCategory.insurance,
        3 => DocCategory.medical,
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final CommitmentsStore store = context.watch<CommitmentsStore>();
    final DateTime now = DateTime.now();
    final List<StoredDocument> expiring = store.expiringDocuments(now);

    List<StoredDocument> shown;
    if (_tab == 4) {
      shown = store.documents
          .where((StoredDocument d) =>
              d.category == DocCategory.property ||
              d.category == DocCategory.vehicle ||
              d.category == DocCategory.other)
          .toList();
    } else {
      shown = store.documentsIn(_filter);
    }

    final Map<DocCategory, List<StoredDocument>> grouped =
        <DocCategory, List<StoredDocument>>{};
    for (final StoredDocument d in shown) {
      grouped.putIfAbsent(d.category, () => <StoredDocument>[]).add(d);
    }

    return Scaffold(
      body: Column(
        children: <Widget>[
          ModuleHeader(
            color: AppColors.documents,
            title: 'Document vault',
            leading: Navigator.canPop(context)
                ? IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  )
                : null,
            actions: <Widget>[
              HeaderIconButton(
                icon: Icons.add,
                tooltip: 'Add document',
                onPressed: () => AddDocumentSheet.show(context),
              ),
            ],
            tabs: _tabs,
            selectedTab: _tab,
            onTabSelected: (int i) => setState(() => _tab = i),
          ),
          Expanded(
            child: store.documents.isEmpty
                ? EmptyState(
                    icon: Icons.folder_outlined,
                    title: 'No documents stored',
                    message: 'Add IDs, insurance policies and certificates. '
                        'Everything stays encrypted on this device.',
                    actionLabel: 'Add document',
                    onAction: () => AddDocumentSheet.show(context),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                    children: <Widget>[
                      // PRD 9.1 FR1 — alert shows regardless of active tab.
                      if (expiring.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: InfoBanner(
                            tone: ChipTone.danger,
                            icon: Icons.warning_amber_outlined,
                            title: '${expiring.length} document'
                                '${expiring.length == 1 ? '' : 's'} expiring soon',
                            text: '',
                            child: Column(
                              children: <Widget>[
                                for (final StoredDocument d in expiring)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 5),
                                    child: Row(
                                      children: <Widget>[
                                        Expanded(
                                          child: Text(
                                            d.name,
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: AppColors.dangerText),
                                          ),
                                        ),
                                        StatusChip.tone(
                                          'Expires ${fmtShortDate.format(d.expiryDate!)}',
                                          (d.daysLeftFrom(now) ?? 999) <= 30
                                              ? ChipTone.danger
                                              : ChipTone.warning,
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      for (final DocCategory c in grouped.keys) ...<Widget>[
                        SectionLabel(_sectionName(c)),
                        AppCard(
                          child: Column(
                            children: <Widget>[
                              for (int i = 0;
                                  i < grouped[c]!.length;
                                  i++) ...<Widget>[
                                HighlightRow(
                                  highlighted: grouped[c]![i].id ==
                                      widget.highlightId,
                                  child: _row(
                                      context, store, grouped[c]![i], now),
                                ),
                                if (i != grouped[c]!.length - 1)
                                  Divider(height: 1, color: context.hairline),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (shown.isEmpty)
                        const AppCard(
                          child: EmptyState(
                            icon: Icons.filter_alt_outlined,
                            title: 'Nothing here',
                            message: 'No documents in this category.',
                          ),
                        ),
                      const SizedBox(height: 4),
                      const InfoBanner(
                        tone: ChipTone.neutral,
                        icon: Icons.lock_outline,
                        title: 'All documents stored on this device',
                        text:
                            'Encrypted at rest · never uploaded to any server.',
                      ),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_documents',
        backgroundColor: AppColors.documents,
        tooltip: 'Add document',
        onPressed: () => AddDocumentSheet.show(context),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  String _sectionName(DocCategory c) => switch (c) {
        DocCategory.identity => 'Identity',
        DocCategory.insurance => 'Insurance & financial',
        DocCategory.medical => 'Medical',
        DocCategory.property => 'Property',
        DocCategory.vehicle => 'Vehicle',
        DocCategory.other => 'Other',
      };

  Widget _row(BuildContext context, CommitmentsStore store, StoredDocument d,
      DateTime now) {
    final String chip = d.statusChip(now);
    final ChipTone tone = switch (chip) {
      'Urgent' || 'Expired' => ChipTone.danger,
      'Renew soon' => ChipTone.warning,
      'No expiry' => ChipTone.success,
      _ => ChipTone.success,
    };
    final int? days = d.daysLeftFrom(now);
    final bool isLocked = d.locked && !_unlocked.contains(d.id);

    return InkWell(
      onTap: () => _openDocument(context, store, d),
      onLongPress: () => _menu(context, store, d),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: <Widget>[
            IconTile(
              icon: isLocked ? Icons.lock_outline : _iconFor(d),
              color: switch (chip) {
                'Urgent' || 'Expired' => AppColors.danger,
                'Renew soon' => AppColors.warning,
                _ => AppColors.info,
              },
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          d.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: context.txtPrimary,
                          ),
                        ),
                      ),
                      if (d.locked) ...<Widget>[
                        const SizedBox(width: 5),
                        Icon(Icons.lock, size: 12, color: context.txtTertiary),
                      ],
                      if (d.redactSensitiveNumbers) ...<Widget>[
                        const SizedBox(width: 4),
                        Icon(Icons.visibility_off_outlined,
                            size: 12, color: context.txtTertiary),
                      ],
                    ],
                  ),
                  Text(
                    isLocked
                        ? 'Locked · tap to unlock'
                        : d.expiryDate == null
                            ? (d.note.isEmpty ? 'No expiry date' : d.note)
                            : 'Expires ${fmtShortDate.format(d.expiryDate!)} '
                                '${d.expiryDate!.year}'
                                '${days != null && days >= 0 ? ' · $days days' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: (days != null && days <= 30 && days >= 0)
                          ? AppColors.danger
                          : context.txtSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                StatusChip.tone(chip, tone),
                const SizedBox(height: 5),
                if (d.fileExtension != null)
                  Text(
                    '.${d.fileExtension}',
                    style: TextStyle(fontSize: 10, color: context.txtTertiary),
                  ),
              ],
            ),
            Icon(Icons.chevron_right, size: 18, color: context.txtTertiary),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(StoredDocument d) => switch (d.category) {
        DocCategory.identity => Icons.badge_outlined,
        DocCategory.insurance => Icons.verified_user_outlined,
        DocCategory.medical => Icons.medical_information_outlined,
        DocCategory.property => Icons.home_outlined,
        DocCategory.vehicle => Icons.directions_car_outlined,
        DocCategory.other => Icons.insert_drive_file_outlined,
      };

  /// PRD 9.1 AC3 (new) — a locked document requires authentication first.
  Future<void> _openDocument(
      BuildContext context, CommitmentsStore store, StoredDocument d) async {
    if (d.locked && !_unlocked.contains(d.id)) {
      final bool ok = await _authenticate(context, d);
      if (!ok) return;
      if (!mounted) return;
      setState(() => _unlocked.add(d.id));
    }
    if (!context.mounted) return;
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(d.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Shows the actual attached image; other file types fall back to
            // a type icon since we can't render them inline.
            if (d.filePath != null && AttachmentService.isImage(d.filePath!))
              ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: Image.file(
                  File(d.filePath!),
                  width: double.infinity,
                  height: 180,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      _previewPlaceholder(ctx, d, 'File is missing'),
                ),
              )
            else
              _previewPlaceholder(
                ctx,
                d,
                d.filePath == null
                    ? 'No file attached'
                    : '${d.name}.${d.fileExtension ?? 'file'}',
              ),
            const SizedBox(height: 12),
            if (d.issueDate != null)
              Text(
                  'Issued: ${fmtShortDate.format(d.issueDate!)} '
                  '${d.issueDate!.year}',
                  style: const TextStyle(fontSize: 12.5)),
            if (d.expiryDate != null)
              Text(
                  'Expires: ${fmtShortDate.format(d.expiryDate!)} '
                  '${d.expiryDate!.year}',
                  style: const TextStyle(fontSize: 12.5)),
            if (d.note.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(d.note, style: const TextStyle(fontSize: 12.5)),
              ),
            if (d.linkedModule != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.link, size: 14, color: AppColors.purple),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        'Linked to ${d.linkedModule}: ${d.linkedLabel ?? ''}',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.purpleText),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (d.filePath == null) {
                showSnack(context, 'No file attached to export');
                return;
              }
              ShareService.shareFilePath(d.filePath!, subject: d.name);
            },
            child: const Text('Export'),
          ),
        ],
      ),
    );
  }

  Widget _previewPlaceholder(
      BuildContext ctx, StoredDocument d, String label) {
    return Container(
      width: double.infinity,
      height: 130,
      decoration: BoxDecoration(
        color: ctx.fieldColor,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(_iconFor(d), size: 34, color: ctx.txtTertiary),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: ctx.txtSecondary),
          ),
          if (d.redactSensitiveNumbers)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'ID number masked in the stored file',
                style: TextStyle(fontSize: 11, color: ctx.txtTertiary),
              ),
            ),
        ],
      ),
    );
  }

  /// PRD Gap 2 — a real device credential prompt. Previously this was a plain
  /// dialog whose "Unlock" button simply returned true, so the lock protected
  /// nothing.
  Future<bool> _authenticate(BuildContext context, StoredDocument d) async {
    return AuthService.authenticate('Unlock "${d.name}"');
  }

  Future<void> _menu(
      BuildContext context, CommitmentsStore store, StoredDocument d) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: Icon(
                  d.locked ? Icons.lock_open_outlined : Icons.lock_outline),
              title: Text(
                  d.locked ? 'Remove document lock' : 'Lock this document'),
              subtitle: Text(
                d.locked
                    ? 'It will open without authentication'
                    : 'Require fingerprint / PIN to open',
                style: const TextStyle(fontSize: 12),
              ),
              onTap: () {
                store.toggleDocumentLock(d);
                _unlocked.remove(d.id);
                Navigator.pop(ctx);
                setState(() {});
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit details'),
              onTap: () {
                Navigator.pop(ctx);
                AddDocumentSheet.show(context, existing: d);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline,
                  color: AppColors.dangerBright),
              title: const Text('Delete document',
                  style: TextStyle(color: AppColors.dangerBright)),
              onTap: () async {
                Navigator.pop(ctx);
                final bool ok = await confirmDialog(
                  context,
                  title: 'Delete ${d.name}?',
                  message: 'The stored file will be permanently removed from '
                      'this device. This cannot be undone.',
                );
                if (ok) store.deleteDocument(d.id);
              },
            ),
          ],
        ),
      ),
    );
  }
}
