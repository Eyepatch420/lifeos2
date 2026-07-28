import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/backup_service.dart';
import '../../core/services/share_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_x.dart';
import '../../core/widgets/alert_type_selector.dart';
import '../../core/widgets/common.dart';
import '../../data/models/enums.dart';
import '../../data/stores/commitments_store.dart';
import '../../data/stores/expense_store.dart';
import '../../data/stores/health_store.dart';
import '../../data/stores/lists_notes_store.dart';
import '../../data/stores/planner_store.dart';
import '../../data/stores/reminder_store.dart';
import '../../data/stores/settings_store.dart';

/// PRD 10.1 — profile, shared defaults, privacy and appearance.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final SettingsStore s = context.watch<SettingsStore>();
    final ReminderStore reminders = context.watch<ReminderStore>();

    return Scaffold(
      body: Column(
        children: <Widget>[
          _header(context, s),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              children: <Widget>[
                const SectionLabel('Reminders'),
                AppCard(
                  child: Column(
                    children: <Widget>[
                      _tile(
                        context,
                        icon: Icons.notifications_none,
                        color: AppColors.info,
                        title: 'Default alert type',
                        subtitle: s.defaultAlertType.label,
                        onTap: () => _pickAlertType(context, s),
                      ),
                      Divider(height: 1, color: context.hairline),
                      _tile(
                        context,
                        icon: Icons.nightlight_outlined,
                        color: AppColors.info,
                        title: 'Do not disturb window',
                        subtitle:
                            '${formatTimeOfDay(s.dndStart)} – ${formatTimeOfDay(s.dndEnd)}',
                        onTap: () => _pickDnd(context, s),
                      ),
                      Divider(height: 1, color: context.hairline),
                      _tile(
                        context,
                        icon: Icons.snooze,
                        color: AppColors.info,
                        title: 'Default snooze duration',
                        subtitle: '${s.defaultSnoozeMinutes} minutes',
                        onTap: () => _pickSnooze(context, s),
                      ),
                      Divider(height: 1, color: context.hairline),
                      SwitchListTile(
                        value: s.weeklyDigestEnabled,
                        activeThumbColor: AppColors.checkGreen,
                        secondary: const IconTile(
                            icon: Icons.summarize_outlined,
                            color: AppColors.info),
                        title: const Text('Weekly insights digest',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: const Text(
                          'Sunday summary of streaks, budget and renewals',
                          style: TextStyle(fontSize: 12),
                        ),
                        onChanged: s.setWeeklyDigest,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const SectionLabel('Data & privacy'),
                AppCard(
                  child: Column(
                    children: <Widget>[
                      SwitchListTile(
                        value: s.appLockEnabled,
                        activeThumbColor: AppColors.checkGreen,
                        secondary: const IconTile(
                            icon: Icons.lock_outline, color: AppColors.success),
                        title: const Text('App lock',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: const Text('Fingerprint / Face ID / PIN',
                            style: TextStyle(fontSize: 12)),
                        onChanged: (bool v) {
                          s.setAppLock(v);
                          showSnack(
                            context,
                            v
                                ? 'App lock on — you will authenticate on next open'
                                : 'App lock off',
                          );
                        },
                      ),
                      Divider(height: 1, color: context.hairline),
                      _tile(
                        context,
                        icon: Icons.file_download_outlined,
                        color: AppColors.success,
                        title: 'Export all data',
                        subtitle: 'JSON / CSV backup of every module',
                        onTap: () => _export(context),
                      ),
                      Divider(height: 1, color: context.hairline),
                      _tile(
                        context,
                        icon: Icons.restore_outlined,
                        color: AppColors.success,
                        title: 'Backup & restore',
                        subtitle: 'Save a backup file, or restore from one',
                        onTap: () => _backupAndRestore(context),
                      ),
                      Divider(height: 1, color: context.hairline),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        leading: const IconTile(
                            icon: Icons.smartphone, color: AppColors.success),
                        title: const Text('All data stays on device',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: const Text('No server sync · local only',
                            style: TextStyle(fontSize: 12)),
                        trailing:
                            StatusChip.tone('On-device', ChipTone.success),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const SectionLabel('Appearance'),
                AppCard(
                  child: Column(
                    children: <Widget>[
                      _tile(
                        context,
                        icon: Icons.palette_outlined,
                        color: AppColors.warning,
                        title: 'Theme',
                        subtitle: switch (s.themeMode) {
                          ThemeMode.light => 'Light',
                          ThemeMode.dark => 'Dark',
                          ThemeMode.system => 'System default',
                        },
                        onTap: () => _pickTheme(context, s),
                      ),
                      Divider(height: 1, color: context.hairline),
                      _tile(
                        context,
                        icon: Icons.language,
                        color: AppColors.warning,
                        title: 'Language',
                        subtitle: s.language,
                        onTap: () => _pickLanguage(context, s),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const SectionLabel('Health defaults'),
                AppCard(
                  child: Column(
                    children: <Widget>[
                      _tile(
                        context,
                        icon: Icons.water_drop_outlined,
                        color: AppColors.purple,
                        title: 'Daily water goal',
                        subtitle:
                            '${(reminders.water.goalMl / 1000).toStringAsFixed(1)} L',
                        onTap: () => _pickWaterGoal(context, reminders),
                      ),
                      Divider(height: 1, color: context.hairline),
                      _tile(
                        context,
                        icon: Icons.person_outline,
                        color: AppColors.purple,
                        title: 'Profile',
                        subtitle:
                            '${s.age ?? '—'} yrs · ${s.weightKg ?? '—'} kg',
                        onTap: () => _editProfile(context, s),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const SectionLabel('About'),
                AppCard(
                  child: Column(
                    children: <Widget>[
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        leading: const IconTile(
                            icon: Icons.info_outline,
                            color: AppColors.textSecondary),
                        title: const Text('Version',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        // Read from the package rather than hardcoded, so it
                        // can't drift away from what was actually shipped.
                        subtitle: FutureBuilder<PackageInfo>(
                          future: PackageInfo.fromPlatform(),
                          builder: (BuildContext c,
                              AsyncSnapshot<PackageInfo> snap) {
                            final PackageInfo? i = snap.data;
                            return Text(
                              i == null
                                  ? '—'
                                  : '${i.version} (build ${i.buildNumber})',
                              style: const TextStyle(fontSize: 12),
                            );
                          },
                        ),
                      ),
                      Divider(height: 1, color: context.hairline),
                      _tile(
                        context,
                        icon: Icons.policy_outlined,
                        color: AppColors.textSecondary,
                        title: 'Privacy policy',
                        subtitle: 'How your data is handled',
                        onTap: () => _openUrl(
                            context, Uri.parse('https://lifeos.app/privacy')),
                      ),
                      Divider(height: 1, color: context.hairline),
                      _tile(
                        context,
                        icon: Icons.mail_outline,
                        color: AppColors.textSecondary,
                        title: 'Support',
                        subtitle: 'support@lifeos.app',
                        onTap: () => _openUrl(
                            context,
                            Uri(
                              scheme: 'mailto',
                              path: 'support@lifeos.app',
                              queryParameters: <String, String>{
                                'subject': 'LifeOS support',
                              },
                            )),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, SettingsStore s) {
    return Container(
      color: AppColors.home,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 14, 16),
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  if (Navigator.canPop(context))
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    )
                  else
                    const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      'Settings',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 0, 0),
                child: Row(
                  children: <Widget>[
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.white.withValues(alpha: 0.22),
                      child: Text(
                        s.initial,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            s.name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            s.email,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined,
                          color: Colors.white, size: 20),
                      onPressed: () => _editProfile(context, s),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      leading: IconTile(icon: icon, color: color),
      title: Text(title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }

  // ---- actions -----------------------------------------------------------

  Future<void> _pickAlertType(BuildContext context, SettingsStore s) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext ctx, StateSetter setModal) => SheetScaffold(
          title: 'Default alert type',
          actionLabel: 'Done',
          onAction: () => Navigator.pop(ctx),
          children: <Widget>[
            // PRD 10.1 AC1 — this only pre-selects for NEW reminders.
            const InfoBanner(
              tone: ChipTone.neutral,
              icon: Icons.info_outline,
              text: 'This pre-selects the alert type for new reminders, bills '
                  'and memberships. Existing items keep their own setting.',
            ),
            const SizedBox(height: 14),
            AlertTypeSelector(
              value: s.defaultAlertType,
              onChanged: (AlertType t) {
                s.setDefaultAlertType(t);
                setModal(() {});
              },
              showRepeatInterval: false,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDnd(BuildContext context, SettingsStore s) async {
    final TimeOfDay? start = await showTimePicker(
        context: context, initialTime: s.dndStart, helpText: 'DND starts at');
    if (start == null || !context.mounted) return;
    final TimeOfDay? end = await showTimePicker(
        context: context, initialTime: s.dndEnd, helpText: 'DND ends at');
    if (end == null) return;
    s.setDnd(start, end);
  }

  Future<void> _pickSnooze(BuildContext context, SettingsStore s) async {
    final int? v = await showDialog<int>(
      context: context,
      builder: (BuildContext ctx) => SimpleDialog(
        title: const Text('Default snooze duration'),
        children: <Widget>[
          for (final int m in <int>[5, 10, 15, 30, 60])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, m),
              child: Text('$m minutes'),
            ),
        ],
      ),
    );
    if (v != null) s.setSnooze(v);
  }

  Future<void> _pickTheme(BuildContext context, SettingsStore s) async {
    final ThemeMode? v = await showDialog<ThemeMode>(
      context: context,
      builder: (BuildContext ctx) => SimpleDialog(
        title: const Text('Theme'),
        children: <Widget>[
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, ThemeMode.system),
            child: const Text('System default'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, ThemeMode.light),
            child: const Text('Light'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, ThemeMode.dark),
            child: const Text('Dark'),
          ),
        ],
      ),
    );
    if (v != null) s.setThemeMode(v);
  }

  Future<void> _pickLanguage(BuildContext context, SettingsStore s) async {
    const List<String> langs = <String>[
      'English',
      'हिन्दी',
      'मराठी',
      'বাংলা',
      'தமிழ்'
    ];
    final String? v = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => SimpleDialog(
        title: const Text('Language'),
        children: <Widget>[
          for (final String l in langs)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, l),
              child: Text(l),
            ),
        ],
      ),
    );
    if (v != null) s.setLanguage(v);
  }

  /// PRD 10.1 AC4 — changing the goal affects future days, not past logs.
  Future<void> _pickWaterGoal(
      BuildContext context, ReminderStore reminders) async {
    int goal = reminders.water.goalMl;
    final int? v = await showDialog<int>(
      context: context,
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext ctx, StateSetter setLocal) => AlertDialog(
          title: const Text('Daily water goal'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text('${(goal / 1000).toStringAsFixed(1)} L',
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w700)),
              Slider(
                value: goal.toDouble(),
                min: 500,
                max: 5000,
                divisions: 45,
                onChanged: (double x) =>
                    setLocal(() => goal = (x / 100).round() * 100),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, goal),
                child: const Text('Save')),
          ],
        ),
      ),
    );
    if (v != null) reminders.setWaterGoal(v);
  }

  Future<void> _editProfile(BuildContext context, SettingsStore s) async {
    final TextEditingController name = TextEditingController(text: s.name);
    final TextEditingController email = TextEditingController(text: s.email);
    final TextEditingController age =
        TextEditingController(text: s.age?.toString() ?? '');
    final TextEditingController weight =
        TextEditingController(text: s.weightKg?.toString() ?? '');

    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Edit profile'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Name'),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: email,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: age,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Age'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: weight,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration:
                          const InputDecoration(labelText: 'Weight (kg)'),
                    ),
                  ),
                ],
              ),
            ],
          ),
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
    s.setName(name.text.trim().isEmpty ? s.name : name.text.trim());
    s.setEmail(email.text.trim());
    s.setProfile(
      age: int.tryParse(age.text.trim()),
      weightKg: double.tryParse(weight.text.trim()),
    );
  }

  /// PRD 10.1 AC3 — a complete archive across every module, user-initiated.
  Future<void> _export(BuildContext context) async {
    final ReminderStore r = context.read<ReminderStore>();
    final PlannerStore p = context.read<PlannerStore>();
    final ExpenseStore e = context.read<ExpenseStore>();
    final HealthStore h = context.read<HealthStore>();
    final ListsNotesStore ln = context.read<ListsNotesStore>();
    final CommitmentsStore c = context.read<CommitmentsStore>();

    final Map<String, int> counts = <String, int>{
      'Reminders': r.all.length,
      'Habits': p.habits.length,
      'Planner events': p.events.length,
      'Transactions': e.allTransactions.length,
      'Budget categories': e.categories.length,
      'Lab reports': h.reports.length,
      'Wellness entries': h.wellnessEntries.length,
      'Lists': ln.lists.length,
      'Notes': ln.notes.length,
      'Memberships': c.memberships.length,
      'Bills': c.bills.length,
      'Documents': c.documents.length,
    };
    final int total = counts.values.fold<int>(0, (int s, int v) => s + v);

    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Export all data'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('$total records across ${counts.length} data types.',
                  style: const TextStyle(fontSize: 13.5)),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: SingleChildScrollView(
                  child: Column(
                    children: <Widget>[
                      for (final MapEntry<String, int> en in counts.entries)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: <Widget>[
                              Expanded(
                                  child: Text(en.key,
                                      style: const TextStyle(fontSize: 12.5))),
                              Text('${en.value}',
                                  style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            key: const Key('export_json'),
            onPressed: () async {
              Navigator.pop(ctx);
              // Writes a real file and opens the share sheet — this button
              // previously only showed a snackbar and exported nothing.
              final String path = await ShareService.shareAsFile(
                BackupService.buildBackup(),
                BackupService.suggestedFileName(),
                subject: 'LifeOS backup — $total records',
              );
              if (context.mounted) {
                showSnack(context, 'Saved to ${path.split('/').last}');
              }
            },
            child: const Text('Export JSON'),
          ),
        ],
      ),
    );
  }

  /// Opens a URL in the browser / mail app, reporting honestly when no app
  /// on the device can handle it.
  Future<void> _openUrl(BuildContext context, Uri uri) async {
    final bool launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    ).catchError((_) => false);
    if (!launched && context.mounted) {
      showSnack(context, 'No app available to open this');
    }
  }

  /// Real backup / restore (PRD 10.1). Restore rewrites stored state and asks
  /// for a relaunch, so it is applied all-or-nothing rather than half-live.
  Future<void> _backupAndRestore(BuildContext context) async {
    final String? action = await showModalBottomSheet<String>(
      context: context,
      builder: (BuildContext sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Backup & restore',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.save_alt_outlined),
              title: const Text('Save a backup file'),
              subtitle: const Text(
                  'Everything from every module, as one JSON file',
                  style: TextStyle(fontSize: 12)),
              onTap: () => Navigator.pop(sheet, 'backup'),
            ),
            ListTile(
              leading: const Icon(Icons.restore_outlined),
              title: const Text('Restore from a backup'),
              subtitle: const Text('Replaces everything currently on this device',
                  style: TextStyle(fontSize: 12)),
              onTap: () => Navigator.pop(sheet, 'restore'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (action == null || !context.mounted) return;

    if (action == 'backup') {
      final String path = await ShareService.shareAsFile(
        BackupService.buildBackup(),
        BackupService.suggestedFileName(),
        subject: 'LifeOS backup',
      );
      if (context.mounted) {
        showSnack(context, 'Backup saved as ${path.split('/').last}');
      }
      return;
    }

    // Restore is destructive — confirm before touching anything.
    final bool ok = await confirmDialog(
      context,
      title: 'Restore from a backup?',
      message: 'Everything currently in LifeOS on this device will be '
          'replaced by the contents of the backup file. This cannot be undone.',
      confirmLabel: 'Choose file',
    );
    if (!ok || !context.mounted) return;

    final RestoreResult result = await BackupService.restoreFromFile();
    if (!context.mounted || result.cancelled) return;

    if (!result.isSuccess) {
      showSnack(context, result.error ?? 'Restore failed');
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Backup restored'),
        content: Text(
          '${result.sectionsRestored} section'
          '${result.sectionsRestored == 1 ? '' : 's'} restored. '
          'Close and reopen LifeOS to see your restored data.',
          style: const TextStyle(fontSize: 13.5, height: 1.5),
        ),
        actions: <Widget>[
          FilledButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Got it')),
        ],
      ),
    );
  }
}
