import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/notification_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/alarm.dart';
import '../../data/models/enums.dart';
import '../../data/models/reminder.dart';
import '../../data/stores/alarm_store.dart';
import '../../data/stores/commitments_store.dart';
import '../../data/stores/reminder_store.dart';
import '../../data/stores/settings_store.dart';
import '../memberships/membership_detail_screen.dart';
import '../reminders/ringing_screen.dart';
import '../bills/bills_screen.dart';
import '../clock/clock_screen.dart';
import '../documents/document_vault_screen.dart';
import '../expenses/expenses_screen.dart';
import '../health/health_screen.dart';
import '../health/wellness_log_screen.dart';
import '../home/consolidated_progress_screen.dart';
import '../home/home_screen.dart';
import '../lists_notes/lists_screen.dart';
import '../lists_notes/notes_screen.dart';
import '../memberships/memberships_screen.dart';
import '../planner/planner_screen.dart';
import '../reminders/reminders_screen.dart';
import '../search/global_search_screen.dart';
import '../settings/settings_screen.dart';

/// PRD Gap 4 resolution.
///
/// The mockups showed two conflicting 5-tab bars and 10 modules that cannot
/// fit in one. This shell keeps the four highest-frequency modules as fixed
/// tabs and routes everything else through a "More" hub, so no module is
/// unreachable and the primary tabs stay stable.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const List<Widget> _pages = <Widget>[
    HomeScreen(),
    RemindersScreen(),
    PlannerScreen(),
    ExpensesScreen(),
    MoreHubScreen(),
  ];

  @override
  void initState() {
    super.initState();
    NotificationService.tapped.addListener(_handleNotificationTap);
    // A tap that launched the app cold is already queued.
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _handleNotificationTap());
  }

  @override
  void dispose() {
    NotificationService.tapped.removeListener(_handleNotificationTap);
    super.dispose();
  }

  /// Routes a tapped notification to the thing it is about (PRD G.1).
  void _handleNotificationTap() {
    final NotificationRoute? route = NotificationService.tapped.value;
    if (route == null || !mounted) return;
    NotificationService.tapped.value = null;

    switch (route.kind) {
      case 'reminder':
        final Reminder? r = context.read<ReminderStore>().byId(route.id);
        if (r == null) return;
        if (r.alertType == AlertType.forceConfirm) {
          RingingScreen.show(
            context,
            RingingScreen(
              title: r.title,
              subtitle: r.subtitle.isEmpty ? 'Reminder' : r.subtitle,
              payload: 'reminder:${r.id}',
              intervalMinutes: r.forceConfirmIntervalMinutes,
              snoozeMinutes:
                  context.read<SettingsStore>().defaultSnoozeMinutes,
              onConfirm: () => context
                  .read<ReminderStore>()
                  .markDone(r, DateTime.now()),
              onSnooze: () => context.read<ReminderStore>().snooze(
                  r, context.read<SettingsStore>().defaultSnoozeMinutes),
            ),
          );
        } else {
          setState(() => _index = 1);
        }
      case 'alarm':
        final Alarm? a = context.read<AlarmStore>().byId(route.id);
        if (a == null) return;
        RingingScreen.show(
          context,
          RingingScreen(
            title: a.label.isEmpty ? 'Alarm' : a.label,
            subtitle: a.repeatLabel,
            payload: 'alarm:${a.id}',
            alertType: a.alertType,
            intervalMinutes: a.forceConfirmIntervalMinutes,
            snoozeMinutes: a.snoozeMinutes,
            onConfirm: () {
              final AlarmStore store = context.read<AlarmStore>();
              store.clearSnooze(a);
              if (!a.repeats) store.setEnabled(a, false);
            },
            onSnooze: () => context.read<AlarmStore>().snooze(a),
          ),
        );
      case 'habit':
      case 'event':
        setState(() => _index = 2);
      case 'bill':
        Navigator.push(context,
            MaterialPageRoute<void>(builder: (_) => const BillsScreen()));
      case 'membership':
        Navigator.push(
            context,
            MaterialPageRoute<void>(
                builder: (_) => MembershipDetailScreen(id: route.id)));
      case 'document':
        Navigator.push(
            context,
            MaterialPageRoute<void>(
                builder: (_) => const DocumentVaultScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (int i) => setState(() => _index = i),
        height: 66,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_none),
            selectedIcon: Icon(Icons.notifications),
            label: 'Reminders',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today),
            label: 'Planner',
          ),
          NavigationDestination(
            icon: Icon(Icons.currency_rupee),
            selectedIcon: Icon(Icons.currency_rupee),
            label: 'Expenses',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view),
            label: 'More',
          ),
        ],
      ),
    );
  }
}

class _MoreEntry {
  const _MoreEntry(this.label, this.icon, this.color, this.builder, this.badge);
  final String label;
  final IconData icon;
  final Color color;
  final WidgetBuilder builder;
  final String? Function(BuildContext)? badge;
}

/// The "More" hub — every remaining module, each with a live status badge.
class MoreHubScreen extends StatelessWidget {
  const MoreHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();

    final List<_MoreEntry> entries = <_MoreEntry>[
      _MoreEntry('Health', Icons.monitor_heart_outlined, AppColors.health,
          (_) => const HealthScreen(), null),
      _MoreEntry('Wellness log', Icons.mood, AppColors.wellness,
          (_) => const WellnessLogScreen(), null),
      _MoreEntry(
        'Clock — alarm & stopwatch',
        Icons.alarm,
        AppColors.clock,
        (_) => const ClockScreen(),
        (BuildContext c) {
          final int n = c.read<AlarmStore>().enabled.length;
          return n > 0 ? '$n on' : null;
        },
      ),
      _MoreEntry('Lists', Icons.checklist_outlined, AppColors.lists,
          (_) => const ListsScreen(), null),
      _MoreEntry('Notes', Icons.sticky_note_2_outlined, AppColors.notes,
          (_) => const NotesScreen(), null),
      _MoreEntry(
        'Memberships',
        Icons.badge_outlined,
        AppColors.memberships,
        (_) => const MembershipsScreen(),
        (BuildContext c) {
          final int n =
              c.read<CommitmentsStore>().expiringMemberships(now).length;
          return n > 0 ? '$n expiring' : null;
        },
      ),
      _MoreEntry(
        'Bills & subscriptions',
        Icons.receipt_long_outlined,
        AppColors.bills,
        (_) => const BillsScreen(),
        (BuildContext c) {
          final int n = c.read<CommitmentsStore>().overdueBills(now).length;
          return n > 0 ? '$n overdue' : null;
        },
      ),
      _MoreEntry(
        'Document vault',
        Icons.folder_outlined,
        AppColors.documents,
        (_) => const DocumentVaultScreen(),
        (BuildContext c) {
          final int n =
              c.read<CommitmentsStore>().expiringDocuments(now).length;
          return n > 0 ? '$n expiring' : null;
        },
      ),
      _MoreEntry('My progress', Icons.insights_outlined, AppColors.progress,
          (_) => const ConsolidatedProgressScreen(), null),
      _MoreEntry('Settings', Icons.settings_outlined, AppColors.textSecondary,
          (_) => const SettingsScreen(), null),
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.home,
        title: const Text('More'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Search everything',
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                  builder: (_) => const GlobalSearchScreen()),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: <Widget>[
          // Recommended feature from the PRD: one search across all modules.
          Card(
            elevation: 0,
            color: context.cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: context.hairline),
            ),
            child: ListTile(
              leading: const Icon(Icons.search, color: AppColors.home),
              title: const Text('Search everything',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              subtitle: const Text(
                'Reminders, notes, expenses, documents and more',
                style: TextStyle(fontSize: 12),
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                    builder: (_) => const GlobalSearchScreen()),
              ),
            ),
          ),
          const SizedBox(height: 10),
          for (final _MoreEntry e in entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                elevation: 0,
                color: context.cardColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: context.hairline),
                ),
                child: ListTile(
                  leading: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: e.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(e.icon, color: e.color, size: 20),
                  ),
                  title: Text(
                    e.label,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Builder(builder: (BuildContext c) {
                        final String? b = e.badge?.call(c);
                        if (b == null) return const SizedBox.shrink();
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.dangerBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            b,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.dangerText,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right, size: 20),
                    ],
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(builder: e.builder),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'All data stays on this device',
                style: TextStyle(fontSize: 11.5, color: context.txtTertiary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Helper so any screen can jump to a module tab from a deep link (PRD G.1).
class ShellNavigator {
  const ShellNavigator._();

  static void openReminders(BuildContext context) => Navigator.push(context,
      MaterialPageRoute<void>(builder: (_) => const RemindersScreen()));

  static void openPlanner(BuildContext context) => Navigator.push(
      context, MaterialPageRoute<void>(builder: (_) => const PlannerScreen()));

  static void openExpenses(BuildContext context) => Navigator.push(
      context, MaterialPageRoute<void>(builder: (_) => const ExpensesScreen()));

  static void openHealth(BuildContext context) => Navigator.push(
      context, MaterialPageRoute<void>(builder: (_) => const HealthScreen()));
}
