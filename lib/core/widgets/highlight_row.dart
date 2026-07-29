import 'package:flutter/material.dart';

/// Wraps a list row so it can flash and auto-scroll into view when it is the
/// deep-link target (from search or a notification tap).
///
/// Each module screen that accepts a `highlightId` wraps the matching row's
/// key widget with this instead of building its own scroll/flash logic —
/// keeps every "open the exact record" deep link consistent for free.
class HighlightRow extends StatefulWidget {
  const HighlightRow({
    super.key,
    required this.highlighted,
    required this.child,
  });

  /// Whether this row is the current deep-link target.
  final bool highlighted;
  final Widget child;

  @override
  State<HighlightRow> createState() => _HighlightRowState();
}

class _HighlightRowState extends State<HighlightRow>
    with SingleTickerProviderStateMixin {
  // Created only when actually highlighted — a non-highlighted row (the
  // overwhelming majority of rows in any list) never touches the ticker
  // machinery at all, and dispose() must not lazily create one just to
  // immediately dispose it (that crashes: the widget is already deactivated).
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    if (widget.highlighted) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 900),
      );
      _flash();
    }
  }

  void _flash() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Scrollable.ensureVisible(context,
          alignment: 0.2, duration: const Duration(milliseconds: 300));
      _controller?.forward(from: 0);
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AnimationController? controller = _controller;
    if (!widget.highlighted || controller == null) return widget.child;
    final Color flash = Theme.of(context).colorScheme.primary;
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, Widget? child) {
        final double t = 1 - controller.value;
        return Container(
          decoration: BoxDecoration(
            color: flash.withValues(alpha: 0.16 * t),
            borderRadius: BorderRadius.circular(10),
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
