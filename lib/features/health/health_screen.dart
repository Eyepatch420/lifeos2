import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_x.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/module_header.dart';
import '../../data/models/commitments.dart';
import '../../data/models/enums.dart';
import '../../data/models/health.dart';
import '../../data/stores/commitments_store.dart';
import '../../data/stores/health_store.dart';
import '../documents/document_vault_screen.dart';
import 'report_detail_screen.dart';
import 'vitals_screen.dart';
import 'wellness_log_screen.dart';

/// PRD 5.1 — Health hub: reports, marker trends and health documents.
class HealthScreen extends StatefulWidget {
  const HealthScreen({super.key});

  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen> {
  int _tab = 0;
  static const List<String> _tabs = <String>[
    'Overview',
    'Reports',
    'Trends',
    'Vitals'
  ];

  @override
  Widget build(BuildContext context) {
    final HealthStore health = context.watch<HealthStore>();
    final DateTime now = DateTime.now();

    return Scaffold(
      body: Column(
        children: <Widget>[
          ModuleHeader(
            color: AppColors.health,
            title: 'Health',
            leading: Navigator.canPop(context)
                ? IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  )
                : null,
            actions: <Widget>[
              HeaderIconButton(
                icon: Icons.mood,
                tooltip: 'Wellness log',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                      builder: (_) => const WellnessLogScreen()),
                ),
              ),
              HeaderIconButton(
                icon: Icons.add,
                tooltip: 'Add report',
                onPressed: _addReport,
              ),
            ],
            stats: <Widget>[
              HeaderStat(
                  label: 'Reports',
                  value: '${health.reportCount}',
                  sub: 'scanned'),
              HeaderStat(
                  label: 'Last scan',
                  value: health.lastScanLabel(now),
                  sub: 'ago'),
              HeaderStat(
                  label: 'Markers',
                  value: '${health.trackedMarkerCount}',
                  sub: 'tracked'),
            ],
            tabs: _tabs,
            selectedTab: _tab,
            onTabSelected: (int i) => setState(() => _tab = i),
          ),
          Expanded(
            child: switch (_tab) {
              1 => _reportsTab(context, health),
              2 => _trendsTab(context, health),
              3 => const VitalsScreen(embedded: true),
              _ => _overviewTab(context, health, now),
            },
          ),
        ],
      ),
    );
  }

  // ---- Overview ----------------------------------------------------------

  Widget _overviewTab(BuildContext context, HealthStore health, DateTime now) {
    final WellnessEntry? today = health.entryOn(now);
    final List<String> concerning = health.markerNames
        .where((String n) => health.hasConcerningTrend(n))
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: <Widget>[
        if (concerning.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InfoBanner(
              tone: ChipTone.danger,
              icon: Icons.trending_up,
              title: '${concerning.length} marker'
                  '${concerning.length == 1 ? '' : 's'} trending up',
              text: '${concerning.join(', ')} — rising across your last few '
                  'reports. Worth discussing with your doctor.',
              onTap: () => setState(() => _tab = 2),
            ),
          ),
        AppCard(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => const WellnessLogScreen()),
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            children: <Widget>[
              IconTile(
                  icon: today == null ? Icons.mood_bad : Icons.mood,
                  color: AppColors.wellness,
                  size: 38),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      today == null
                          ? "Log today's wellness"
                          : "Today: feeling ${today.mood.label}",
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: context.txtPrimary,
                      ),
                    ),
                    Text(
                      today == null
                          ? 'Mood, symptoms and a quick note'
                          : today.symptomSummary,
                      style:
                          TextStyle(fontSize: 12, color: context.txtSecondary),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 20),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const SectionLabel('Key markers'),
        _keyMarkers(context, health),
        const SizedBox(height: 14),
        SectionLabel('Recent reports',
            trailing: 'All reports',
            onTrailingTap: () => setState(() => _tab = 1)),
        _reportList(context, health, limit: 3),
        const SizedBox(height: 14),
        _documents(context),
      ],
    );
  }

  Widget _keyMarkers(BuildContext context, HealthStore health) {
    final List<String> names = health.markerNames.take(3).toList();
    if (names.isEmpty) {
      return const AppCard(
        child: EmptyState(
          icon: Icons.science_outlined,
          title: 'No lab data yet',
          message: 'Add a report to start tracking markers.',
        ),
      );
    }
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: <Widget>[
          for (int i = 0; i < names.length; i++) ...<Widget>[
            _markerTrendRow(context, health, names[i]),
            if (i != names.length - 1) const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }

  Widget _markerTrendRow(
      BuildContext context, HealthStore health, String name) {
    final List<MapEntry<DateTime, LabMarker>> hist = health.markerHistory(name);
    if (hist.isEmpty) return const SizedBox.shrink();
    final LabMarker latest = hist.last.value;
    final double maxV = hist.fold<double>(
        0,
        (double m, MapEntry<DateTime, LabMarker> e) =>
            e.value.value > m ? e.value.value : m);
    final Color tone = switch (latest.status) {
      MarkerStatus.normal => AppColors.success,
      MarkerStatus.borderline => AppColors.warning,
      MarkerStatus.abnormal => AppColors.danger,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.txtPrimary,
                ),
              ),
            ),
            Text(
              '${latest.value} ${latest.unit}',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: tone),
            ),
            const SizedBox(width: 5),
            StatusChip.tone(
              latest.status.label,
              switch (latest.status) {
                MarkerStatus.normal => ChipTone.success,
                MarkerStatus.borderline => ChipTone.warning,
                MarkerStatus.abnormal => ChipTone.danger,
              },
            ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 34,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              for (final MapEntry<DateTime, LabMarker> e in hist)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: <Widget>[
                        Container(
                          height: maxV == 0
                              ? 2
                              : (e.value.value / maxV * 26).clamp(3, 26),
                          decoration: BoxDecoration(
                            color: e.key == hist.last.key
                                ? tone
                                : tone.withValues(alpha: 0.4),
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(2)),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          fmtMonthShort.format(e.key),
                          style: TextStyle(
                              fontSize: 8, color: context.txtTertiary),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        // PRD 5.1 AC2 — only fires with >=3 consistently-rising points.
        if (health.hasConcerningTrend(name)) ...<Widget>[
          const SizedBox(height: 8),
          InfoBanner(
            tone: ChipTone.danger,
            icon: Icons.warning_amber_outlined,
            text: '$name rising over ${hist.length} reports. '
                'Consider discussing with your doctor.',
          ),
        ],
      ],
    );
  }

  // ---- Reports -----------------------------------------------------------

  Widget _reportsTab(BuildContext context, HealthStore health) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: <Widget>[
        SectionLabel('Blood reports',
            trailing: '+ Add scan', onTrailingTap: _addReport),
        _reportList(context, health),
      ],
    );
  }

  Widget _reportList(BuildContext context, HealthStore health, {int? limit}) {
    final List<LabReport> reports =
        limit == null ? health.reports : health.reports.take(limit).toList();

    if (reports.isEmpty) {
      return AppCard(
        child: EmptyState(
          icon: Icons.description_outlined,
          title: 'No reports yet',
          message: 'Scan or add a lab report to track your markers over time.',
          actionLabel: 'Add report',
          onAction: _addReport,
        ),
      );
    }

    return AppCard(
      child: Column(
        children: <Widget>[
          for (int i = 0; i < reports.length; i++) ...<Widget>[
            ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              leading: const IconTile(
                  icon: Icons.description_outlined, color: AppColors.purple),
              title: Text(reports[i].name,
                  style: const TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w600)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '${reports[i].lab} · ${fmtShortDate.format(reports[i].date)}',
                    style: const TextStyle(fontSize: 11.5),
                  ),
                  const SizedBox(height: 4),
                  StatusChip.tone(
                    reports[i].summaryBadge,
                    reports[i].countOf(MarkerStatus.abnormal) > 0
                        ? ChipTone.danger
                        : (reports[i].countOf(MarkerStatus.borderline) > 0
                            ? ChipTone.warning
                            : ChipTone.success),
                  ),
                ],
              ),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                    builder: (_) =>
                        ReportDetailScreen(reportId: reports[i].id)),
              ),
            ),
            if (i != reports.length - 1)
              Divider(height: 1, color: context.hairline),
          ],
        ],
      ),
    );
  }

  // ---- Trends ------------------------------------------------------------

  Widget _trendsTab(BuildContext context, HealthStore health) {
    final List<String> names = health.markerNames;
    if (names.isEmpty) {
      return const EmptyState(
        icon: Icons.show_chart,
        title: 'No trend data',
        message: 'Add at least two reports to see how markers move over time.',
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: <Widget>[
        const SectionLabel('All tracked markers'),
        for (final String n in names)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              padding: const EdgeInsets.all(12),
              child: _markerTrendRow(context, health, n),
            ),
          ),
      ],
    );
  }

  // ---- Documents ---------------------------------------------------------

  Widget _documents(BuildContext context) {
    final CommitmentsStore store = context.watch<CommitmentsStore>();
    final List<StoredDocument> docs = store
        .documentsIn(DocCategory.medical)
        .followedBy(store.documentsIn(DocCategory.insurance))
        .take(4)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionLabel(
          'Health documents',
          trailing: 'All docs',
          onTrailingTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
                builder: (_) => const DocumentVaultScreen()),
          ),
        ),
        if (docs.isEmpty)
          const AppCard(
            child: EmptyState(
              icon: Icons.folder_outlined,
              title: 'No health documents',
              message: 'Prescriptions and insurance policies appear here.',
            ),
          )
        else
          AppCard(
            child: Column(
              children: <Widget>[
                for (int i = 0; i < docs.length; i++) ...<Widget>[
                  ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                    leading: IconTile(
                      icon: docs[i].category == DocCategory.medical
                          ? Icons.medication_outlined
                          : Icons.verified_user_outlined,
                      color: docs[i].category == DocCategory.medical
                          ? AppColors.info
                          : AppColors.success,
                    ),
                    title: Text(docs[i].name,
                        style: const TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      docs[i].expiryDate == null
                          ? docs[i].note
                          : 'Valid till ${fmtShortDate.format(docs[i].expiryDate!)}',
                      style: const TextStyle(fontSize: 11.5),
                    ),
                    trailing: docs[i].locked
                        ? const Icon(Icons.lock_outline, size: 16)
                        : const Icon(Icons.chevron_right, size: 20),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                          builder: (_) => const DocumentVaultScreen()),
                    ),
                  ),
                  if (i != docs.length - 1)
                    Divider(height: 1, color: context.hairline),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _addReport() async {
    final HealthStore store = context.read<HealthStore>();
    final TextEditingController name = TextEditingController();
    final TextEditingController lab = TextEditingController();
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Add lab report'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text(
              'Scan a report and LifeOS extracts its values automatically. '
              'Extracted values stay editable — always verify with your doctor.',
              style: TextStyle(fontSize: 12.5, height: 1.4),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Report name'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: lab,
              decoration: const InputDecoration(labelText: 'Lab / source'),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Scan & add')),
        ],
      ),
    );
    if (ok != true || name.text.trim().isEmpty) return;
    store.addReport(LabReport(
      id: 'rep_${DateTime.now().millisecondsSinceEpoch}',
      name: name.text.trim(),
      lab: lab.text.trim().isEmpty ? 'Unknown lab' : lab.text.trim(),
      date: DateTime.now(),
      markers: <LabMarker>[
        LabMarker(
            name: 'Haemoglobin',
            value: 13.6,
            unit: 'g/dL',
            normalLow: 12,
            normalHigh: 17),
        LabMarker(
            name: 'HbA1c',
            value: 6.9,
            unit: '%',
            normalLow: 4,
            normalHigh: 5.6),
      ],
    ));
    if (mounted) showSnack(context, 'Report added — verify the values');
  }
}
