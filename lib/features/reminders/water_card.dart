import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/stores/reminder_store.dart';

/// Water quick-log card (PRD 2.1). Reads and writes the SAME store data that
/// Home (1.1) shows, so the two can never disagree.
class WaterCard extends StatelessWidget {
  const WaterCard({super.key, required this.date, this.showGlasses = true});

  final DateTime date;
  final bool showGlasses;

  @override
  Widget build(BuildContext context) {
    final ReminderStore store = context.watch<ReminderStore>();
    final int consumed = store.waterOn(date);
    final int goal = store.water.goalMl;
    final double progress = store.waterProgress(date);
    final int glassSize = store.water.amountPerReminderMl;
    final int totalGlasses =
        glassSize <= 0 ? 0 : (goal / glassSize).ceil().clamp(0, 12);
    final int filledGlasses = glassSize <= 0
        ? 0
        : (consumed / glassSize).floor().clamp(0, totalGlasses);

    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.water_drop, size: 18, color: AppColors.info),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Water today',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.txtPrimary,
                  ),
                ),
              ),
              Text.rich(
                TextSpan(children: <InlineSpan>[
                  TextSpan(
                    text: '${(consumed / 1000).toStringAsFixed(2)} L',
                    style: const TextStyle(
                      color: AppColors.info,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  TextSpan(
                    text: ' / ${(goal / 1000).toStringAsFixed(1)} L',
                    style: TextStyle(fontSize: 13, color: context.txtSecondary),
                  ),
                ]),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ThinProgressBar(value: progress, color: AppColors.info, height: 6),
          if (showGlasses && totalGlasses > 0) ...<Widget>[
            const SizedBox(height: 10),
            Wrap(
              spacing: 5,
              runSpacing: 5,
              children: <Widget>[
                for (int i = 0; i < totalGlasses; i++)
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: i < filledGlasses
                          ? AppColors.infoBg
                          : Colors.transparent,
                      border: Border.all(
                        color: i < filledGlasses
                            ? AppColors.info
                            : context.hairline,
                        width: i < filledGlasses ? 1.4 : 0.8,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      i < filledGlasses
                          ? Icons.water_drop
                          : Icons.water_drop_outlined,
                      size: 14,
                      color: i < filledGlasses
                          ? AppColors.info
                          : context.txtTertiary,
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              for (final int ml in <int>[150, 250, 500]) ...<Widget>[
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      foregroundColor: AppColors.info,
                      side: const BorderSide(color: AppColors.info, width: 0.8),
                      backgroundColor: AppColors.infoBg.withValues(alpha: 0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () =>
                        context.read<ReminderStore>().addWater(date, ml),
                    child:
                        Text('+ $ml ml', style: const TextStyle(fontSize: 12)),
                  ),
                ),
                if (ml != 500) const SizedBox(width: 6),
              ],
              const SizedBox(width: 6),
              IconButton(
                tooltip: 'Undo last',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.undo, size: 18),
                onPressed: consumed <= 0
                    ? null
                    : () => context
                        .read<ReminderStore>()
                        .addWater(date, -glassSize),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
