import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_x.dart';
import '../../core/widgets/common.dart';
import '../../data/models/enums.dart';
import '../../data/models/health.dart';
import '../../data/stores/health_store.dart';

/// PRD 5.2 — full marker breakdown for one report, with the auto-extraction
/// disclaimer and per-marker historical trends.
class ReportDetailScreen extends StatelessWidget {
  const ReportDetailScreen({super.key, required this.reportId});

  final String reportId;

  @override
  Widget build(BuildContext context) {
    final HealthStore health = context.watch<HealthStore>();
    final LabReport? report = health.reportById(reportId);

    if (report == null) {
      return Scaffold(
        appBar: AppBar(
            backgroundColor: AppColors.health, title: const Text('Report')),
        body: const EmptyState(
          icon: Icons.link_off,
          title: 'Report not found',
          message: 'It may have been deleted.',
        ),
      );
    }

    final int normal = report.countOf(MarkerStatus.normal);
    final int borderline = report.countOf(MarkerStatus.borderline);
    final int abnormal = report.countOf(MarkerStatus.abnormal);

    return Scaffold(
      body: Column(
        children: <Widget>[
          Container(
            color: AppColors.health,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        IconButton(
                          icon:
                              const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Expanded(
                          child: Text(
                            report.name,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Share',
                          icon:
                              const Icon(Icons.ios_share, color: Colors.white),
                          onPressed: () => showSnack(
                              context, 'Report summary copied to clipboard'),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Text(
                        '${report.lab} · ${fmtShortDate.format(report.date)} '
                        '${report.date.year}'
                        '${report.autoExtracted ? ' · Auto-extracted' : ''}',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.7)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              children: <Widget>[
                // PRD 5.2 AC1 — summary counts always equal the rows below.
                AppCard(
                  child: Column(
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                                child: _summaryTile(context, 'Normal', normal,
                                    AppColors.success, AppColors.successBg)),
                            const SizedBox(width: 8),
                            Expanded(
                                child: _summaryTile(
                                    context,
                                    'Borderline',
                                    borderline,
                                    AppColors.warning,
                                    AppColors.warningBg)),
                            const SizedBox(width: 8),
                            Expanded(
                                child: _summaryTile(
                                    context,
                                    'Abnormal',
                                    abnormal,
                                    AppColors.danger,
                                    AppColors.dangerBg)),
                          ],
                        ),
                      ),
                      Divider(height: 1, color: context.hairline),
                      for (int i = 0;
                          i < report.markers.length;
                          i++) ...<Widget>[
                        _markerRow(context, health, report.markers[i]),
                        if (i != report.markers.length - 1)
                          Divider(height: 1, color: context.hairline),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                for (final LabMarker m in report.markers)
                  if (m.status != MarkerStatus.normal &&
                      health.markerHistory(m.name).length >= 2)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _trendCard(context, health, m),
                    ),
                const SizedBox(height: 4),
                // PRD 5.2 FR1 — persistent accuracy disclaimer.
                if (report.autoExtracted)
                  const InfoBanner(
                    tone: ChipTone.neutral,
                    icon: Icons.info_outline,
                    text: 'Values extracted automatically and may contain '
                        'errors. Tap any marker to correct it. '
                        'Always verify with your doctor.',
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryTile(
      BuildContext context, String label, int count, Color fg, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Column(
        children: <Widget>[
          Text(label, style: TextStyle(fontSize: 10.5, color: fg)),
          const SizedBox(height: 2),
          Text(
            '$count',
            style:
                TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: fg),
          ),
        ],
      ),
    );
  }

  Widget _markerRow(BuildContext context, HealthStore health, LabMarker m) {
    final Color tone = switch (m.status) {
      MarkerStatus.normal => AppColors.success,
      MarkerStatus.borderline => AppColors.warning,
      MarkerStatus.abnormal => AppColors.danger,
    };

    return InkWell(
      // PRD 5.2 AC3 — extracted values remain user-correctable.
      onTap: () => showSnack(
          context, 'Tap and hold a value to correct an extraction error'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    m.name,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: context.txtPrimary,
                    ),
                  ),
                  Text(
                    m.rangeLabel,
                    style:
                        TextStyle(fontSize: 11.5, color: context.txtSecondary),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  '${m.value}',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700, color: tone),
                ),
                Text(m.unit,
                    style:
                        TextStyle(fontSize: 10.5, color: context.txtTertiary)),
              ],
            ),
            const SizedBox(width: 9),
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
            ),
          ],
        ),
      ),
    );
  }

  Widget _trendCard(BuildContext context, HealthStore health, LabMarker m) {
    final List<MapEntry<DateTime, LabMarker>> hist =
        health.markerHistory(m.name);
    final double maxV = hist.fold<double>(
        0,
        (double acc, MapEntry<DateTime, LabMarker> e) =>
            e.value.value > acc ? e.value.value : acc);
    final bool concerning = health.hasConcerningTrend(m.name);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionLabel('${m.name} trend'),
        AppCard(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: <Widget>[
              SizedBox(
                height: 62,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    for (final MapEntry<DateTime, LabMarker> e in hist)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: <Widget>[
                              Text(
                                '${e.value.value}',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: e.key == hist.last.key
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                  color: context.txtTertiary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Container(
                                height: maxV == 0
                                    ? 3
                                    : (e.value.value / maxV * 38).clamp(3, 38),
                                decoration: BoxDecoration(
                                  color: switch (e.value.status) {
                                    MarkerStatus.normal => AppColors.success,
                                    MarkerStatus.borderline =>
                                      AppColors.warning,
                                    MarkerStatus.abnormal =>
                                      AppColors.dangerBright,
                                  }
                                      .withValues(
                                          alpha:
                                              e.key == hist.last.key ? 1 : 0.5),
                                  borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(2)),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                fmtMonthShort.format(e.key),
                                style: TextStyle(
                                    fontSize: 8.5, color: context.txtTertiary),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (concerning) ...<Widget>[
                const SizedBox(height: 8),
                InfoBanner(
                  tone: ChipTone.danger,
                  icon: Icons.warning_amber_outlined,
                  text: 'Rising trend across ${hist.length} reports. '
                      'Consult your doctor.',
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
