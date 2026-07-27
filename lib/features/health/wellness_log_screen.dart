import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_x.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/module_header.dart';
import '../../data/models/enums.dart';
import '../../data/models/health.dart';
import '../../data/stores/health_store.dart';
import 'vitals_screen.dart';

/// PRD 5.3 — daily mood + symptom log, distinct from objective vitals.
class WellnessLogScreen extends StatefulWidget {
  const WellnessLogScreen({super.key});

  @override
  State<WellnessLogScreen> createState() => _WellnessLogScreenState();
}

class _WellnessLogScreenState extends State<WellnessLogScreen> {
  int _tab = 0;
  static const List<String> _tabs = <String>['Log', 'Vitals', 'Trends'];

  Mood _mood = Mood.okay;
  final Set<String> _symptoms = <String>{};
  final TextEditingController _note = TextEditingController();
  String _energy = 'Medium';
  double? _sleepHours;
  bool _loadedToday = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _loadTodayIfNeeded(HealthStore health) {
    if (_loadedToday) return;
    final WellnessEntry? e = health.entryOn(DateTime.now());
    if (e != null) {
      _mood = e.mood;
      _symptoms.addAll(e.symptoms);
      _note.text = e.note;
      _energy = e.energy;
      _sleepHours = e.sleepHours;
    }
    _loadedToday = true;
  }

  @override
  Widget build(BuildContext context) {
    final HealthStore health = context.watch<HealthStore>();
    _loadTodayIfNeeded(health);

    return Scaffold(
      body: Column(
        children: <Widget>[
          ModuleHeader(
            color: AppColors.wellness,
            title: 'Wellness log',
            leading: Navigator.canPop(context)
                ? IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  )
                : null,
            tabs: _tabs,
            selectedTab: _tab,
            onTabSelected: (int i) => setState(() => _tab = i),
          ),
          Expanded(
            child: switch (_tab) {
              1 => const VitalsScreen(embedded: true),
              2 => _trendsTab(context, health),
              _ => _logTab(context, health),
            },
          ),
        ],
      ),
    );
  }

  // ---- Log tab -----------------------------------------------------------

  Widget _logTab(BuildContext context, HealthStore health) {
    final DateTime now = DateTime.now();
    final bool alreadyLogged = health.hasEntryToday(now);
    final List<WellnessEntry> recent = health.wellnessEntries;

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: <Widget>[
        AppCard(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'HOW ARE YOU FEELING TODAY?',
                style: TextStyle(
                  fontSize: 10.5,
                  letterSpacing: 0.6,
                  fontWeight: FontWeight.w600,
                  color: context.txtTertiary,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  for (final Mood m in Mood.values) ...<Widget>[
                    Expanded(child: _moodOption(m)),
                    if (m != Mood.great) const SizedBox(width: 6),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'ANY SYMPTOMS?',
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
                  for (final String s in health.symptomOptions)
                    ChoicePill(
                      label: s,
                      selected: _symptoms.contains(s),
                      color: AppColors.danger,
                      onTap: () => setState(() {
                        if (_symptoms.contains(s)) {
                          _symptoms.remove(s);
                        } else {
                          _symptoms.add(s);
                        }
                      }),
                    ),
                  // PRD 5.3 FR2 — user-extensible symptom vocabulary.
                  ChoicePill(
                    label: 'Add',
                    icon: Icons.add,
                    selected: false,
                    onTap: () => _addSymptom(health),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  Expanded(
                    child: FieldWrap(
                      label: 'Energy',
                      child: DropdownButtonFormField<String>(
                        initialValue: _energy,
                        isExpanded: true,
                        items: const <DropdownMenuItem<String>>[
                          DropdownMenuItem<String>(
                              value: 'Low', child: Text('Low')),
                          DropdownMenuItem<String>(
                              value: 'Medium', child: Text('Medium')),
                          DropdownMenuItem<String>(
                              value: 'High', child: Text('High')),
                        ],
                        onChanged: (String? v) =>
                            setState(() => _energy = v ?? 'Medium'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FieldWrap(
                      label: 'Sleep (hrs)',
                      child: TextFormField(
                        initialValue: _sleepHours?.toString() ?? '',
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(hintText: 'e.g. 7'),
                        onChanged: (String v) =>
                            _sleepHours = double.tryParse(v.trim()),
                      ),
                    ),
                  ),
                ],
              ),
              FieldWrap(
                label: 'Note (optional)',
                child: TextField(
                  controller: _note,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration:
                      const InputDecoration(hintText: 'Anything worth noting…'),
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.wellness,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  onPressed: () => _save(health, alreadyLogged),
                  child: Text(alreadyLogged
                      ? "Update today's log"
                      : "Save today's log"),
                ),
              ),
              if (alreadyLogged)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    "You've already logged today — saving will update it.",
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(fontSize: 11.5, color: context.txtTertiary),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const SectionLabel('Recent entries'),
        if (recent.isEmpty)
          const AppCard(
            child: EmptyState(
              icon: Icons.event_note_outlined,
              title: 'No entries yet',
              message: 'Your daily logs will appear here.',
            ),
          )
        else
          AppCard(
            child: Column(
              children: <Widget>[
                for (int i = 0; i < recent.length; i++) ...<Widget>[
                  _entryRow(context, recent[i]),
                  if (i != recent.length - 1)
                    Divider(height: 1, color: context.hairline),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _moodOption(Mood m) {
    final bool sel = _mood == m;
    final IconData icon = switch (m) {
      Mood.poor => Icons.sentiment_very_dissatisfied,
      Mood.low => Icons.sentiment_dissatisfied,
      Mood.okay => Icons.sentiment_neutral,
      Mood.good => Icons.sentiment_satisfied,
      Mood.great => Icons.sentiment_very_satisfied,
    };
    final Color color = switch (m) {
      Mood.poor => AppColors.danger,
      Mood.low => AppColors.warning,
      Mood.okay => AppColors.wellness,
      Mood.good => AppColors.success,
      Mood.great => AppColors.teal,
    };

    return InkWell(
      onTap: () => setState(() => _mood = m),
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 2),
        decoration: BoxDecoration(
          color: sel ? color.withValues(alpha: 0.12) : Colors.transparent,
          border: Border.all(
            color: sel ? color : context.hairline,
            width: sel ? 1.5 : 0.8,
          ),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Column(
          children: <Widget>[
            Icon(icon, size: 22, color: sel ? color : context.txtTertiary),
            const SizedBox(height: 3),
            Text(
              m.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                color: sel ? color : context.txtSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _entryRow(BuildContext context, WellnessEntry e) {
    final IconData icon = switch (e.mood) {
      Mood.poor => Icons.sentiment_very_dissatisfied,
      Mood.low => Icons.sentiment_dissatisfied,
      Mood.okay => Icons.sentiment_neutral,
      Mood.good => Icons.sentiment_satisfied,
      Mood.great => Icons.sentiment_very_satisfied,
    };
    final Color color = switch (e.mood) {
      Mood.poor => AppColors.danger,
      Mood.low => AppColors.warning,
      Mood.okay => AppColors.wellness,
      Mood.good => AppColors.success,
      Mood.great => AppColors.teal,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 40,
            child: Column(
              children: <Widget>[
                Icon(icon, size: 22, color: color),
                const SizedBox(height: 2),
                Text(e.mood.label,
                    style: TextStyle(fontSize: 9, color: context.txtTertiary)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  e.symptomSummary,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.txtPrimary,
                  ),
                ),
                Text(
                  <String>[
                    relativeDayLabel(e.date, DateTime.now()),
                    'Energy: ${e.energy}',
                    if (e.sleepHours != null) 'Sleep: ${e.sleepHours}h',
                  ].join(' · '),
                  style: TextStyle(fontSize: 11.5, color: context.txtSecondary),
                ),
                if (e.note.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      e.note,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11.5,
                          fontStyle: FontStyle.italic,
                          color: context.txtTertiary),
                    ),
                  ),
              ],
            ),
          ),
          if (e.note.isNotEmpty) StatusChip.tone('Note', ChipTone.warning),
        ],
      ),
    );
  }

  // ---- Trends tab --------------------------------------------------------

  Widget _trendsTab(BuildContext context, HealthStore health) {
    final List<WellnessEntry> entries = health.wellnessEntries.take(14).toList()
      ..sort((WellnessEntry a, WellnessEntry b) => a.date.compareTo(b.date));

    if (entries.isEmpty) {
      return const EmptyState(
        icon: Icons.show_chart,
        title: 'No trend data yet',
        message: 'Log a few days to see how your mood changes over time.',
      );
    }

    final Map<String, int> symptomCounts = <String, int>{};
    for (final WellnessEntry e in entries) {
      for (final String s in e.symptoms) {
        symptomCounts[s] = (symptomCounts[s] ?? 0) + 1;
      }
    }
    final List<MapEntry<String, int>> topSymptoms = symptomCounts.entries
        .toList()
      ..sort((MapEntry<String, int> a, MapEntry<String, int> b) =>
          b.value.compareTo(a.value));

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: <Widget>[
        const SectionLabel('Mood over time'),
        AppCard(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            height: 88,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                for (final WellnessEntry e in entries)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: <Widget>[
                          Container(
                            height: (e.mood.score / 5 * 58).clamp(6, 58),
                            decoration: BoxDecoration(
                              color: switch (e.mood) {
                                Mood.poor => AppColors.danger,
                                Mood.low => AppColors.warning,
                                Mood.okay => AppColors.wellness,
                                Mood.good => AppColors.success,
                                Mood.great => AppColors.teal,
                              },
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(3)),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            fmtDayNum.format(e.date),
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
        ),
        const SizedBox(height: 14),
        const SectionLabel('Most frequent symptoms'),
        if (topSymptoms.isEmpty)
          const AppCard(
            child: EmptyState(
              icon: Icons.check_circle_outline,
              title: 'No symptoms logged',
              message: "That's good news.",
            ),
          )
        else
          AppCard(
            child: Column(
              children: <Widget>[
                for (int i = 0; i < topSymptoms.length; i++) ...<Widget>[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            topSymptoms[i].key,
                            style: TextStyle(
                                fontSize: 13, color: context.txtPrimary),
                          ),
                        ),
                        SizedBox(
                          width: 90,
                          child: ThinProgressBar(
                            value:
                                topSymptoms[i].value / topSymptoms.first.value,
                            color: AppColors.wellness,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${topSymptoms[i].value} day'
                          '${topSymptoms[i].value == 1 ? '' : 's'}',
                          style: TextStyle(
                              fontSize: 11.5, color: context.txtSecondary),
                        ),
                      ],
                    ),
                  ),
                  if (i != topSymptoms.length - 1)
                    Divider(height: 1, color: context.hairline),
                ],
              ],
            ),
          ),
      ],
    );
  }

  // ---- actions -----------------------------------------------------------

  Future<void> _addSymptom(HealthStore health) async {
    final TextEditingController c = TextEditingController();
    final String? v = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Add a symptom'),
        content: TextField(
          controller: c,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'e.g. Back pain'),
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
    health.addSymptomOption(v.trim());
    setState(() => _symptoms.add(v.trim()));
  }

  /// PRD 5.3 AC2 — re-saving an already-logged day updates it, with an
  /// explicit confirmation so the behaviour is never surprising.
  Future<void> _save(HealthStore health, bool alreadyLogged) async {
    if (alreadyLogged) {
      final bool ok = await confirmDialog(
        context,
        title: "Update today's entry?",
        message: 'You already logged today. Saving will replace that entry.',
        confirmLabel: 'Update',
        destructive: false,
      );
      if (!ok) return;
    }
    health.saveWellness(WellnessEntry(
      date: dayKey(DateTime.now()),
      mood: _mood,
      symptoms: _symptoms.toList(),
      note: _note.text.trim(),
      energy: _energy,
      sleepHours: _sleepHours,
    ));
    if (mounted) {
      showSnack(context, alreadyLogged ? 'Entry updated' : 'Logged for today');
    }
  }
}
