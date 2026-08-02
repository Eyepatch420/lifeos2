import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/share_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_x.dart';
import '../../core/widgets/common.dart';
import '../../data/models/enums.dart';
import '../../data/models/health.dart';
import '../../data/stores/health_store.dart';

/// PRD 5.4 — vitals cards, BP trend and the doctor-ready export.
class VitalsScreen extends StatelessWidget {
  const VitalsScreen({super.key, this.embedded = false});

  /// When embedded it renders as a tab inside HealthScreen (no own AppBar).
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final Widget body = _body(context);
    if (embedded) return body;
    return Scaffold(
      appBar: AppBar(
          backgroundColor: AppColors.health, title: const Text('Vitals')),
      body: body,
    );
  }

  Widget _body(BuildContext context) {
    final HealthStore health = context.watch<HealthStore>();

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: <Widget>[
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.45,
          children: <Widget>[
            for (final VitalKind k in VitalKind.values)
              _vitalCard(context, health, k),
          ],
        ),
        const SizedBox(height: 14),
        _bpTrend(context, health),
        const SizedBox(height: 14),
        _exportCard(context, health),
      ],
    );
  }

  Widget _vitalCard(BuildContext context, HealthStore health, VitalKind kind) {
    final VitalReading? v = health.latestVital(kind);
    final double? delta = health.deltaFromPrevious(kind);

    final IconData icon = switch (kind) {
      VitalKind.bloodPressure => Icons.favorite_outline,
      VitalKind.bloodSugar => Icons.water_drop_outlined,
      VitalKind.weight => Icons.monitor_weight_outlined,
      VitalKind.sleep => Icons.bedtime_outlined,
    };
    final Color color = switch (kind) {
      VitalKind.bloodPressure => AppColors.danger,
      VitalKind.bloodSugar => AppColors.info,
      VitalKind.weight => AppColors.purple,
      VitalKind.sleep => AppColors.warning,
    };

    return AppCard(
      onTap: () => _logVital(context, health, kind),
      padding: const EdgeInsets.all(11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  kind.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: context.txtSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (v == null)
            Expanded(
              child: Center(
                child: Text(
                  'Not logged',
                  style: TextStyle(fontSize: 12.5, color: context.txtTertiary),
                ),
              ),
            )
          else ...<Widget>[
            Text.rich(
              TextSpan(children: <InlineSpan>[
                TextSpan(
                  text: v.display,
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    color: context.txtPrimary,
                  ),
                ),
                TextSpan(
                  text: ' ${kind.unit}',
                  style: TextStyle(fontSize: 12, color: context.txtSecondary),
                ),
              ]),
            ),
            const SizedBox(height: 2),
            Text(
              '${v.context.isEmpty ? '' : '${v.context} · '}'
              '${relativeDayLabel(v.takenAt, DateTime.now())}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10.5, color: context.txtTertiary),
            ),
            const Spacer(),
            Row(
              children: <Widget>[
                StatusChip.tone(
                  v.statusLabel,
                  switch (v.status) {
                    MarkerStatus.normal => ChipTone.success,
                    MarkerStatus.borderline => ChipTone.warning,
                    MarkerStatus.abnormal => ChipTone.danger,
                  },
                ),
                const SizedBox(width: 5),
                // PRD 5.4 AC2 — delta vs. the immediately prior reading.
                if (delta != null && delta.abs() > 0.01)
                  Flexible(
                    child: Text(
                      '${delta > 0 ? '+' : ''}${delta.toStringAsFixed(1)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: context.txtSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _bpTrend(BuildContext context, HealthStore health) {
    final List<VitalReading> hist =
        health.vitalHistory(VitalKind.bloodPressure);
    if (hist.isEmpty) {
      return const AppCard(
        child: EmptyState(
          icon: Icons.show_chart,
          title: 'No blood pressure readings',
          message: 'Log a reading to start tracking your 7-day trend.',
        ),
      );
    }
    final double maxV = hist.fold<double>(
        0, (double m, VitalReading r) => r.value > m ? r.value : m);
    final bool rising = health.vitalTrendRising(VitalKind.bloodPressure);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SectionLabel('Blood pressure · last 7 days'),
        AppCard(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: <Widget>[
              SizedBox(
                height: 66,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    for (final VitalReading r in hist)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: <Widget>[
                              Text(
                                r.value.toStringAsFixed(0),
                                style: TextStyle(
                                    fontSize: 8.5, color: context.txtTertiary),
                              ),
                              const SizedBox(height: 2),
                              Container(
                                height: maxV == 0
                                    ? 3
                                    : (r.value / maxV * 42).clamp(3, 42),
                                decoration: BoxDecoration(
                                  color: switch (r.status) {
                                    MarkerStatus.normal => AppColors.success,
                                    MarkerStatus.borderline =>
                                      AppColors.warning,
                                    MarkerStatus.abnormal =>
                                      AppColors.dangerBright,
                                  },
                                  borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(2)),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                fmtDayName.format(r.takenAt).substring(0, 1),
                                style: TextStyle(
                                    fontSize: 9, color: context.txtTertiary),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (rising) ...<Widget>[
                const SizedBox(height: 8),
                const InfoBanner(
                  tone: ChipTone.danger,
                  icon: Icons.trending_up,
                  text: 'Blood pressure rising this week. '
                      'Worth discussing with your doctor.',
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// PRD 5.4 FR3 / AC3 — combined export with an explicit date range.
  Widget _exportCard(BuildContext context, HealthStore health) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SectionLabel('Generate doctor report'),
        AppCard(
          onTap: () => _showExport(context, health, 30),
          padding: const EdgeInsets.all(12),
          child: Row(
            children: <Widget>[
              const IconTile(
                  icon: Icons.file_download_outlined,
                  color: AppColors.wellness,
                  size: 36),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Export wellness summary',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: context.txtPrimary,
                      ),
                    ),
                    Text(
                      'Symptoms + vitals + reports · last 30 days',
                      style: TextStyle(
                          fontSize: 11.5, color: context.txtSecondary),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 20),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showExport(
      BuildContext context, HealthStore health, int days) async {
    int selected = days;
    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext ctx, StateSetter setLocal) {
          final String text =
              health.exportDoctorReport(DateTime.now(), days: selected);
          return AlertDialog(
            title: const Text('Doctor report'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Wrap(
                    spacing: 6,
                    children: <Widget>[
                      for (final int d in <int>[7, 30, 90])
                        ChoicePill(
                          label: '$d days',
                          selected: selected == d,
                          color: AppColors.wellness,
                          onTap: () => setLocal(() => selected = d),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 260),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: ctx.fieldColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SingleChildScrollView(
                      child: Text(text,
                          style: const TextStyle(
                              fontSize: 10.5, fontFamily: 'monospace')),
                    ),
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close')),
              FilledButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  // The summary was previously generated and then discarded.
                  await ShareService.shareAsFile(
                    text,
                    'digilife-health-summary-${selected}d.txt',
                    subject: 'Health summary — last $selected days',
                  );
                },
                child: const Text('Share report'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _logVital(
      BuildContext context, HealthStore health, VitalKind kind) async {
    final TextEditingController v1 = TextEditingController();
    final TextEditingController v2 = TextEditingController();
    try {
      await _logVitalDialog(context, health, kind, v1, v2);
    } finally {
      v1.dispose();
      v2.dispose();
    }
  }

  Future<void> _logVitalDialog(
    BuildContext context,
    HealthStore health,
    VitalKind kind,
    TextEditingController v1,
    TextEditingController v2,
  ) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text('Log ${kind.label.toLowerCase()}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: v1,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText:
                    kind == VitalKind.bloodPressure ? 'Systolic' : kind.label,
                suffixText: kind.unit,
              ),
            ),
            if (kind == VitalKind.bloodPressure) ...<Widget>[
              const SizedBox(height: 10),
              TextField(
                controller: v2,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Diastolic', suffixText: 'mmHg'),
              ),
            ],
          ],
        ),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save')),
        ],
      ),
    );
    if (ok != true) return;
    final double? value = double.tryParse(v1.text.trim());
    if (value == null) {
      if (context.mounted) showSnack(context, 'Enter a valid number');
      return;
    }
    health.addVital(VitalReading(
      kind: kind,
      value: value,
      secondaryValue: double.tryParse(v2.text.trim()),
      takenAt: DateTime.now(),
      context: 'Manual entry',
    ));
    if (context.mounted) showSnack(context, '${kind.label} logged');
  }
}
