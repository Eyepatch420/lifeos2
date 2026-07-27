import 'package:flutter/material.dart';

/// The coloured module header used at the top of every module screen, with an
/// optional stats row and an optional tab strip — matching the mockups.
class ModuleHeader extends StatelessWidget {
  const ModuleHeader({
    super.key,
    required this.color,
    required this.title,
    this.subtitle,
    this.actions = const <Widget>[],
    this.leading,
    this.stats,
    this.tabs,
    this.selectedTab,
    this.onTabSelected,
    this.hero,
    this.bottomPadding = 0,
  });

  final Color color;
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget? leading;

  /// Row of HeaderStat widgets.
  final List<Widget>? stats;

  /// Underlined tab strip (All / Identity / Financial …).
  final List<String>? tabs;
  final int? selectedTab;
  final ValueChanged<int>? onTabSelected;

  /// Large hero block (e.g. the expenses spend figure).
  final Widget? hero;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 8, 6),
              child: Row(
                children: <Widget>[
                  if (leading != null) leading!,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        if (subtitle != null)
                          Text(
                            subtitle!,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...actions,
                ],
              ),
            ),
            if (hero != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 2, 14, 10),
                child: hero,
              ),
            if (stats != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
                child: Row(
                  children: <Widget>[
                    for (int i = 0; i < stats!.length; i++) ...<Widget>[
                      Expanded(child: stats![i]),
                      if (i != stats!.length - 1) const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
            if (tabs != null && tabs!.isNotEmpty)
              SizedBox(
                height: 38,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  itemCount: tabs!.length,
                  itemBuilder: (BuildContext context, int i) {
                    final bool active = (selectedTab ?? 0) == i;
                    return InkWell(
                      onTap: () => onTabSelected?.call(i),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: active ? Colors.white : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                        child: Text(
                          tabs![i],
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight:
                                active ? FontWeight.w600 : FontWeight.w400,
                            color: active
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            SizedBox(height: bottomPadding),
          ],
        ),
      ),
    );
  }
}

/// White-on-colour icon button for module headers.
class HeaderIconButton extends StatelessWidget {
  const HeaderIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 20, color: Colors.white.withValues(alpha: 0.9)),
      onPressed: onPressed,
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
    );
  }
}

/// Segmented control rendered on a coloured header (Overview/Transactions/...).
class HeaderSegments extends StatelessWidget {
  const HeaderSegments({
    super.key,
    required this.items,
    required this.selected,
    required this.onSelected,
    required this.color,
  });

  final List<String> items;
  final int selected;
  final ValueChanged<int> onSelected;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: <Widget>[
          for (int i = 0; i < items.length; i++)
            Expanded(
              child: InkWell(
                onTap: () => onSelected(i),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected == i ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    items[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          selected == i ? FontWeight.w600 : FontWeight.w400,
                      color: selected == i
                          ? color
                          : Colors.white.withValues(alpha: 0.75),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
