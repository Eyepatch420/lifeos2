import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_x.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/module_header.dart';
import '../../data/models/commitments.dart';
import '../../data/models/enums.dart';
import '../../data/stores/commitments_store.dart';
import 'add_membership_sheet.dart';
import 'membership_detail_screen.dart';

/// PRD 7.1 — memberships overview with normalised annual cost and expiries.
class MembershipsScreen extends StatefulWidget {
  const MembershipsScreen({super.key});

  @override
  State<MembershipsScreen> createState() => _MembershipsScreenState();
}

class _MembershipsScreenState extends State<MembershipsScreen> {
  int _tab = 0;
  static const List<String> _tabs = <String>[
    'All', 'Health', 'Fitness', 'Club', 'Other'
  ];

  MembershipCategory? get _filter => switch (_tab) {
        1 => MembershipCategory.health,
        2 => MembershipCategory.fitness,
        3 => MembershipCategory.club,
        4 => MembershipCategory.other,
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final CommitmentsStore store = context.watch<CommitmentsStore>();
    final DateTime now = DateTime.now();
    final List<Membership> expiring = store.expiringMemberships(now);
    final List<Membership> shown = store.membershipsIn(_filter);

    // Group by category for section headers.
    final Map<MembershipCategory, List<Membership>> grouped =
        <MembershipCategory, List<Membership>>{};
    for (final Membership m in shown) {
      grouped.putIfAbsent(m.category, () => <Membership>[]).add(m);
    }

    return Scaffold(
      body: Column(
        children: <Widget>[
          ModuleHeader(
            color: AppColors.memberships,
            title: 'Memberships',
            leading: Navigator.canPop(context)
                ? IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  )
                : null,
            actions: <Widget>[
              HeaderIconButton(
                icon: Icons.add,
                tooltip: 'Add membership',
                onPressed: () => AddMembershipSheet.show(context),
              ),
            ],
            stats: <Widget>[
              HeaderStat(
                  label: 'Active',
                  value: '${store.activeMemberships.length}'),
              HeaderStat(
                label: 'Expiring soon',
                value: '${expiring.length}',
                valueColor: expiring.isEmpty
                    ? Colors.white
                    : const Color(0xFFFAC775),
              ),
              HeaderStat(
                  label: 'Annual cost',
                  value: formatRupeesCompact(store.totalAnnualCost)),
            ],
            tabs: _tabs,
            selectedTab: _tab,
            onTabSelected: (int i) => setState(() => _tab = i),
          ),
          Expanded(
            child: store.activeMemberships.isEmpty
                ? EmptyState(
                    icon: Icons.badge_outlined,
                    title: 'No memberships tracked',
                    message: 'Add a gym, club or health plan to track renewals.',
                    actionLabel: 'Add membership',
                    onAction: () => AddMembershipSheet.show(context),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                    children: <Widget>[
                      // PRD 7.1 FR2 / AC3 — banner shows regardless of tab.
                      if (expiring.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: InfoBanner(
                            tone: ChipTone.warning,
                            icon: Icons.error_outline,
                            title: '${expiring.length} membership'
                                '${expiring.length == 1 ? '' : 's'} expiring soon',
                            text: '',
                            child: Column(
                              children: <Widget>[
                                for (final Membership m in expiring)
                                  Padding(
                                    padding:
                                        const EdgeInsets.only(bottom: 5),
                                    child: Row(
                                      children: <Widget>[
                                        Expanded(
                                          child: Text(
                                            m.name,
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: AppColors.warningText),
                                          ),
                                        ),
                                        StatusChip.tone(
                                          'Expires ${fmtShortDate.format(m.expiryDate)}'
                                          ' · ${m.daysLeftFrom(now)}d',
                                          m.daysLeftFrom(now) <= 7
                                              ? ChipTone.danger
                                              : ChipTone.neutral,
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      for (final MembershipCategory c in grouped.keys) ...<Widget>[
                        SectionLabel(c.label),
                        AppCard(
                          child: Column(
                            children: <Widget>[
                              for (int i = 0; i < grouped[c]!.length; i++) ...<Widget>[
                                _row(context, grouped[c]![i], now),
                                if (i != grouped[c]!.length - 1)
                                  Divider(height: 1, color: context.hairline),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Center(
                        child: Text(
                          '${store.activeMemberships.length} memberships · '
                          '${formatRupees(store.totalAnnualCost)}/yr',
                          style: TextStyle(
                              fontSize: 11.5, color: context.txtTertiary),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_memberships',
        backgroundColor: AppColors.memberships,
        tooltip: 'Add membership',
        onPressed: () => AddMembershipSheet.show(context),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _row(BuildContext context, Membership m, DateTime now) {
    final int days = m.daysLeftFrom(now);
    final String chip = m.statusChip(now);
    final ChipTone tone = switch (chip) {
      'Urgent' || 'Expired' => ChipTone.danger,
      'Soon' => ChipTone.warning,
      _ => ChipTone.success,
    };
    final Color barColor = switch (chip) {
      'Urgent' || 'Expired' => AppColors.dangerBright,
      'Soon' => AppColors.warning,
      _ => AppColors.memberships,
    };
    final IconData icon = switch (m.category) {
      MembershipCategory.fitness => Icons.fitness_center,
      MembershipCategory.health => Icons.medical_services_outlined,
      MembershipCategory.club => Icons.location_city_outlined,
      MembershipCategory.other => Icons.card_membership,
    };

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute<void>(
            builder: (_) => MembershipDetailScreen(id: m.id)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: <Widget>[
            IconTile(icon: icon, color: barColor),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    m.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: context.txtPrimary,
                    ),
                  ),
                  Text(
                    '${formatRupees(m.cost)}/${_cycleShort(m.cycle)}'
                    '${m.location.isEmpty ? '' : ' · ${m.location}'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11.5, color: context.txtSecondary),
                  ),
                  const SizedBox(height: 5),
                  ThinProgressBar(
                      value: m.progressFrom(now), color: barColor, height: 4),
                  const SizedBox(height: 3),
                  Text(
                    days < 0
                        ? 'Expired ${-days} days ago'
                        : 'Expires ${fmtShortDate.format(m.expiryDate)} · '
                            '$days days left',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: days <= 7
                          ? AppColors.danger
                          : context.txtTertiary,
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
                const SizedBox(height: 6),
                Icon(Icons.chevron_right, size: 18, color: context.txtTertiary),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _cycleShort(BillingCycle c) => switch (c) {
        BillingCycle.monthly => 'mo',
        BillingCycle.quarterly => 'qtr',
        BillingCycle.halfYearly => '6mo',
        BillingCycle.yearly => 'yr',
        BillingCycle.weekly => 'wk',
        BillingCycle.oneTime => 'one-time',
      };
}
