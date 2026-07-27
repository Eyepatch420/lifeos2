import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Small uppercase section label used above cards throughout the app.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing, this.onTrailingTap});

  final String text;
  final String? trailing;
  final VoidCallback? onTrailingTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 6),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              text.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
                color: context.txtTertiary,
              ),
            ),
          ),
          if (trailing != null)
            InkWell(
              onTap: onTrailingTap,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  trailing!,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The standard white rounded card that every list sits inside.
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding, this.onTap});

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Widget content = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.hairline),
      ),
      child: Material(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: padding ?? EdgeInsets.zero,
          child: child,
        ),
      ),
    );
    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: content,
    );
  }
}

/// Rounded square icon tile used on every list row.
class IconTile extends StatelessWidget {
  const IconTile({
    super.key,
    required this.icon,
    required this.color,
    this.size = 34,
    this.bg,
  });

  final IconData icon;
  final Color color;
  final double size;
  final Color? bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg ?? color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Icon(icon, size: size * 0.5, color: color),
    );
  }
}

/// Small coloured status pill.
class StatusChip extends StatelessWidget {
  const StatusChip(
    this.label, {
    super.key,
    required this.fg,
    required this.bg,
    this.icon,
  });

  final String label;
  final Color fg;
  final Color bg;
  final IconData? icon;

  /// Maps a semantic tone to the palette so chips are consistent app-wide.
  factory StatusChip.tone(String label, ChipTone tone, {IconData? icon}) {
    switch (tone) {
      case ChipTone.success:
        return StatusChip(label,
            fg: AppColors.successText, bg: AppColors.successBg, icon: icon);
      case ChipTone.warning:
        return StatusChip(label,
            fg: AppColors.warningText, bg: AppColors.warningBg, icon: icon);
      case ChipTone.danger:
        return StatusChip(label,
            fg: AppColors.dangerText, bg: AppColors.dangerBg, icon: icon);
      case ChipTone.info:
        return StatusChip(label,
            fg: AppColors.infoText, bg: AppColors.infoBg, icon: icon);
      case ChipTone.purple:
        return StatusChip(label,
            fg: AppColors.purpleText, bg: AppColors.purpleBg, icon: icon);
      case ChipTone.neutral:
        return StatusChip(label,
            fg: AppColors.textSecondary, bg: AppColors.bgTertiary, icon: icon);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 11, color: fg),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
                fontSize: 10.5, color: fg, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

enum ChipTone { success, warning, danger, info, purple, neutral }

/// Thin progress bar. Fill is clamped to 100% so an over-budget bar can never
/// render wider than its container (PRD 4.2 AC3).
class ThinProgressBar extends StatelessWidget {
  const ThinProgressBar({
    super.key,
    required this.value,
    required this.color,
    this.height = 5,
    this.background,
  });

  final double value;
  final Color color;
  final double height;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final double v = value.isNaN ? 0 : value.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: LinearProgressIndicator(
        value: v,
        minHeight: height,
        backgroundColor: background ?? context.hairline,
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );
  }
}

/// Selectable pill used for frequency / lead-time / preset choices.
class ChoicePill extends StatelessWidget {
  const ChoicePill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final Color c = color ?? Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? c.withValues(alpha: 0.12) : Colors.transparent,
          border: Border.all(
            color: selected ? c : context.hairline,
            width: selected ? 1.4 : 0.8,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 14, color: selected ? c : context.txtSecondary),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: selected ? c : context.txtSecondary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Coloured banner used for warnings, alerts and disclaimers.
class InfoBanner extends StatelessWidget {
  const InfoBanner({
    super.key,
    required this.text,
    this.title,
    this.tone = ChipTone.info,
    this.icon,
    this.onTap,
    this.child,
  });

  final String text;
  final String? title;
  final ChipTone tone;
  final IconData? icon;
  final VoidCallback? onTap;
  final Widget? child;

  (Color, Color, Color) get _colors => switch (tone) {
        ChipTone.success => (
            AppColors.successBg,
            AppColors.successText,
            AppColors.success
          ),
        ChipTone.warning => (
            AppColors.warningBg,
            AppColors.warningText,
            AppColors.warning
          ),
        ChipTone.danger => (
            AppColors.dangerBg,
            AppColors.dangerText,
            AppColors.danger
          ),
        ChipTone.purple => (
            AppColors.purpleBg,
            AppColors.purpleText,
            AppColors.purple
          ),
        ChipTone.neutral => (
            AppColors.bgTertiary,
            AppColors.textSecondary,
            AppColors.textSecondary
          ),
        ChipTone.info => (AppColors.infoBg, AppColors.infoText, AppColors.info),
      };

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, Color accent) = _colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withValues(alpha: 0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon ?? Icons.info_outline, size: 17, color: accent),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (title != null)
                    Text(
                      title!,
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: fg),
                    ),
                  if (title != null) const SizedBox(height: 2),
                  Text(
                    text,
                    style: TextStyle(fontSize: 11.5, height: 1.4, color: fg),
                  ),
                  if (child != null) ...<Widget>[
                    const SizedBox(height: 8),
                    child!,
                  ],
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right, size: 18, color: accent),
          ],
        ),
      ),
    );
  }
}

/// Consistent empty state so no screen ever renders a blank void.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 40, color: context.txtTertiary),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: context.txtSecondary,
            ),
          ),
          if (message != null) ...<Widget>[
            const SizedBox(height: 5),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12.5, height: 1.4, color: context.txtTertiary),
            ),
          ],
          if (actionLabel != null && onAction != null) ...<Widget>[
            const SizedBox(height: 14),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

/// Hero stat tile shown inside coloured module headers.
class HeaderStat extends StatelessWidget {
  const HeaderStat({
    super.key,
    required this.label,
    required this.value,
    this.sub,
    this.valueColor,
  });

  final String label;
  final String value;
  final String? sub;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 10, color: Colors.white.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w600,
                color: valueColor ?? Colors.white,
              ),
            ),
          ),
          if (sub != null)
            Text(
              sub!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 10.5, color: Colors.white.withValues(alpha: 0.7)),
            ),
        ],
      ),
    );
  }
}

/// Standard confirm dialog. Returns true only on explicit confirmation, so
/// destructive actions always need a second deliberate tap (PRD 2.4).
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Delete',
  String cancelLabel = 'Cancel',
  bool destructive = true,
}) async {
  final bool? result = await showDialog<bool>(
    context: context,
    builder: (BuildContext ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text(title, style: const TextStyle(fontSize: 16)),
      content:
          Text(message, style: const TextStyle(fontSize: 13.5, height: 1.5)),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: AppColors.dangerBright)
              : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

void showSnack(BuildContext context, String message, {SnackBarAction? action}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      action: action,
      duration: const Duration(seconds: 3),
    ));
}

/// Bottom-sheet scaffold with the grab handle + title used by every Add flow.
class SheetScaffold extends StatelessWidget {
  const SheetScaffold({
    super.key,
    required this.title,
    required this.children,
    required this.actionLabel,
    required this.onAction,
    this.actionEnabled = true,
    this.actionColor,
  });

  final String title;
  final List<Widget> children;
  final String actionLabel;
  final VoidCallback onAction;
  final bool actionEnabled;
  final Color? actionColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderSecondary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: context.txtPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: actionColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: actionEnabled ? onAction : null,
                  child: Text(actionLabel),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Labelled form field wrapper used across all Add sheets.
class FieldWrap extends StatelessWidget {
  const FieldWrap({
    super.key,
    required this.label,
    required this.child,
    this.error,
  });

  final String label;
  final Widget child;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: context.txtSecondary,
            ),
          ),
          const SizedBox(height: 5),
          child,
          if (error != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              error!,
              style: const TextStyle(
                  fontSize: 11.5, color: AppColors.dangerBright),
            ),
          ],
        ],
      ),
    );
  }
}
