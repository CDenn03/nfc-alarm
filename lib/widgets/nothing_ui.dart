import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/alarm.dart';
import '../theme/nothing_colors.dart';
import '../theme/nothing_motion.dart';
import '../theme/nothing_typography.dart';

/// Emphasis levels for small status indicators.
enum NothingTone { neutral, active, muted, alert }

/// Rounded modular tile — the core building block of the interface.
class NothingPanel extends StatelessWidget {
  const NothingPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.color,
    this.borderColor,
    this.radius = NothingGeometry.radiusLarge,
    this.onTap,
    this.onTapSemanticLabel,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;
  final double radius;
  final VoidCallback? onTap;
  final String? onTapSemanticLabel;

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: padding, child: child);

    return Material(
      color: color ?? NothingColors.surface,
      clipBehavior: Clip.antiAlias,
      // Material cross-fades colour and shape, so enabled/disabled and
      // selected/unselected swaps animate instead of snapping.
      animationDuration: NothingMotion.of(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: borderColor == null
            ? BorderSide.none
            : BorderSide(color: borderColor!),
      ),
      child: onTap == null
          ? content
          : MergeSemantics(
              child: Semantics(
                label: onTapSemanticLabel,
                child: InkWell(onTap: onTap, child: content),
              ),
            ),
    );
  }
}

/// Uppercase technical heading with a signal dot, used above each module.
class NothingSectionLabel extends StatelessWidget {
  const NothingSectionLabel(
    this.label, {
    super.key,
    this.trailing,
    this.onDark = false,
  });

  final String label;
  final String? trailing;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final color = onDark ? NothingColors.outline : NothingColors.inkMuted;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: NothingColors.red,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Both sides stay flexible so a long rule summary wraps instead of
        // overflowing on a narrow screen or at a large text scale.
        Flexible(
          child: Text(
            label.toUpperCase(),
            style: NothingTypography.labelMedium.copyWith(color: color),
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              trailing!.toUpperCase(),
              textAlign: TextAlign.end,
              style: NothingTypography.labelSmall.copyWith(color: color),
            ),
          ),
        ],
      ],
    );
  }
}

/// Compact state indicator. Always pairs a word with its color so state is
/// never communicated by color alone.
class NothingStatusPill extends StatelessWidget {
  const NothingStatusPill(
    this.label, {
    super.key,
    this.tone = NothingTone.neutral,
    this.onDark = false,
  });

  final String label;
  final NothingTone tone;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    late final Color background;
    late final Color foreground;
    Color? border;

    switch (tone) {
      case NothingTone.active:
        background = NothingColors.red;
        foreground = NothingColors.white;
      case NothingTone.neutral:
        background = onDark ? NothingColors.white : NothingColors.ink;
        foreground = onDark ? NothingColors.ink : NothingColors.white;
      case NothingTone.muted:
        background = Colors.transparent;
        foreground = onDark ? NothingColors.outline : NothingColors.inkMuted;
        border = onDark ? NothingColors.inkMuted : NothingColors.outlineStrong;
      case NothingTone.alert:
        background = Colors.transparent;
        foreground = NothingColors.red;
        border = NothingColors.red;
    }

    return AnimatedContainer(
      duration: NothingMotion.of(context),
      curve: NothingMotion.curve,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border ?? Colors.transparent),
      ),
      child: AnimatedDefaultTextStyle(
        duration: NothingMotion.of(context),
        curve: NothingMotion.curve,
        style: NothingTypography.labelSmall.copyWith(color: foreground),
        child: Text(label.toUpperCase()),
      ),
    );
  }
}

/// Circular icon control with a guaranteed 48dp tap target.
class NothingCircleButton extends StatelessWidget {
  const NothingCircleButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.filled = false,
    this.danger = false,
    this.onDark = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool filled;
  final bool danger;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final Color foreground;
    final Color background;

    if (filled) {
      background = danger ? NothingColors.red : NothingColors.ink;
      foreground = NothingColors.white;
    } else {
      background = Colors.transparent;
      foreground = danger
          ? NothingColors.red
          : (onDark ? NothingColors.white : NothingColors.ink);
    }

    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      style: IconButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        minimumSize: const Size.square(NothingGeometry.minimumTapTarget),
        shape: const CircleBorder(),
        side: filled
            ? null
            : BorderSide(
                color: danger
                    ? NothingColors.red
                    : (onDark
                          ? NothingColors.inkMuted
                          : NothingColors.outlineStrong),
              ),
      ),
    );
  }
}

/// Monday-first weekday rail. Each day stays an independent toggle.
class NothingWeekdayRail extends StatelessWidget {
  const NothingWeekdayRail({
    super.key,
    required this.selected,
    required this.onToggle,
    this.onDark = false,
  });

  final List<bool> selected;
  final ValueChanged<int> onToggle;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < 7; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i == 6 ? 0 : 6),
              child: _WeekdayCell(
                initial: kDayInitials[i],
                name: kDayLabels[i],
                selected: selected[i],
                onTap: () => onToggle(i),
                onDark: onDark,
              ),
            ),
          ),
      ],
    );
  }
}

class _WeekdayCell extends StatelessWidget {
  const _WeekdayCell({
    required this.initial,
    required this.name,
    required this.selected,
    required this.onTap,
    required this.onDark,
  });

  final String initial;
  final String name;
  final bool selected;
  final VoidCallback onTap;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final foreground = selected
        ? NothingColors.white
        : (onDark ? NothingColors.outline : NothingColors.inkMuted);

    return MergeSemantics(
      child: Semantics(
        label: name,
        selected: selected,
        child: Material(
          color: selected ? NothingColors.red : Colors.transparent,
          clipBehavior: Clip.antiAlias,
          animationDuration: NothingMotion.of(context, NothingMotion.quick),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
            side: selected
                ? BorderSide.none
                : BorderSide(
                    color: onDark
                        ? NothingColors.inkMuted
                        : NothingColors.outlineStrong,
                  ),
          ),
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              height: NothingGeometry.minimumTapTarget,
              child: Center(
                child: ExcludeSemantics(
                  child: AnimatedDefaultTextStyle(
                    duration: NothingMotion.of(context, NothingMotion.quick),
                    curve: NothingMotion.curve,
                    style: NothingTypography.labelLarge.copyWith(
                      color: foreground,
                    ),
                    child: Text(initial),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Selectable pill used for tags, locations, and snooze lengths.
class NothingChoicePill extends StatelessWidget {
  const NothingChoicePill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? NothingColors.white : NothingColors.ink;

    return MergeSemantics(
      child: Semantics(
        selected: selected,
        child: Material(
          color: selected ? NothingColors.ink : Colors.transparent,
          clipBehavior: Clip.antiAlias,
          animationDuration: NothingMotion.of(context, NothingMotion.quick),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
            side: BorderSide(
              color: selected ? NothingColors.ink : NothingColors.outlineStrong,
            ),
          ),
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      selected ? Icons.check : (icon ?? Icons.circle_outlined),
                      size: 14,
                      color: foreground,
                    ),
                    const SizedBox(width: 8),
                    AnimatedDefaultTextStyle(
                      duration: NothingMotion.of(context, NothingMotion.quick),
                      curve: NothingMotion.curve,
                      style: NothingTypography.labelLarge.copyWith(
                        color: foreground,
                      ),
                      child: Text(label),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Radiating dot ring shown while waiting for a physical tag.
class NothingScanIndicator extends StatefulWidget {
  const NothingScanIndicator({super.key, this.size = 168});

  final double size;

  @override
  State<NothingScanIndicator> createState() => _NothingScanIndicatorState();
}

class _NothingScanIndicatorState extends State<NothingScanIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Respect the platform "remove animations" accessibility setting.
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }

    return SizedBox.square(
      dimension: widget.size,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => CustomPaint(
            size: Size.square(widget.size),
            painter: _DotPulsePainter(
              progress: _controller.value,
              animating: !reduceMotion,
            ),
          ),
        ),
      ),
    );
  }
}

/// Uniform dot-matrix grid with an outward pulse, masked to a circle.
///
/// Dots keep a fixed grid position and near-constant size — only their tone
/// changes — which is what reads as a dot-matrix display rather than a
/// conventional spinner.
class _DotPulsePainter extends CustomPainter {
  const _DotPulsePainter({required this.progress, required this.animating});

  static const _grid = 13;

  final double progress;
  final bool animating;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / _grid;
    final dotRadius = cell * 0.17;
    final center = size.center(Offset.zero);
    final maxDistance = size.width / 2;
    final paint = Paint()..style = PaintingStyle.fill;

    for (var row = 0; row < _grid; row++) {
      for (var column = 0; column < _grid; column++) {
        final offset = Offset((column + 0.5) * cell, (row + 0.5) * cell);
        final distance = (offset - center).distance / maxDistance;
        if (distance > 1) continue; // circular mask

        final double intensity;
        if (animating) {
          // Rings travel outward from the centre dot.
          final wave = (distance - progress) % 1.0;
          intensity = math.pow(1 - wave, 5).toDouble().clamp(0.0, 1.0);
        } else {
          intensity = (1 - distance).clamp(0.0, 1.0);
        }

        paint.color = Color.lerp(
          NothingColors.outline,
          NothingColors.red,
          intensity,
        )!;
        canvas.drawCircle(
          offset,
          dotRadius + dotRadius * 0.4 * intensity,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotPulsePainter oldDelegate) {
    return progress != oldDelegate.progress ||
        animating != oldDelegate.animating;
  }
}

/// Placeholder tile shown while real content loads.
///
/// Skeletons are preferred over a bare spinner because they set layout
/// expectations and read as meaningfully faster for the same wait.
class NothingSkeletonPanel extends StatefulWidget {
  const NothingSkeletonPanel({super.key, this.height = 108, this.lines = 2});

  final double height;
  final int lines;

  @override
  State<NothingSkeletonPanel> createState() => _NothingSkeletonPanelState();
}

class _NothingSkeletonPanelState extends State<NothingSkeletonPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = reduceMotion ? 0.5 : _controller.value;
        final tone = Color.lerp(
          NothingColors.canvas,
          NothingColors.outline,
          0.45 + t * 0.35,
        )!;

        return NothingPanel(
          padding: const EdgeInsets.all(18),
          child: SizedBox(
            height: widget.height,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _bar(tone, width: 132, height: 30),
                const Spacer(),
                for (var i = 0; i < widget.lines; i++) ...[
                  _bar(tone, width: i.isEven ? 180.0 : 110.0, height: 11),
                  if (i != widget.lines - 1) const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _bar(Color tone, {required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: tone,
        borderRadius: BorderRadius.circular(NothingGeometry.radiusSmall),
      ),
    );
  }
}

/// Fades and lifts its child into place, optionally staggered by position.
///
/// Entrances stay inside the 200–300ms band; the stagger is capped so a long
/// list never pushes the last item past the point where it feels sluggish.
class NothingEntrance extends StatefulWidget {
  const NothingEntrance({
    super.key,
    required this.child,
    this.index = 0,
    this.maxStaggered = 8,
  });

  final Widget child;
  final int index;
  final int maxStaggered;

  @override
  State<NothingEntrance> createState() => _NothingEntranceState();
}

class _NothingEntranceState extends State<NothingEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: NothingMotion.emphasized,
  );

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
      return;
    }
    final steps = widget.index.clamp(0, widget.maxStaggered);
    Future<void>.delayed(NothingMotion.stagger * steps, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: _controller,
      curve: NothingMotion.curve,
    );

    return AnimatedBuilder(
      animation: curved,
      builder: (context, child) => Opacity(
        opacity: curved.value,
        child: Transform.translate(
          offset: Offset(0, (1 - curved.value) * 12),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

/// Shows [child] only once work has outlived [NothingMotion.spinnerDelay], so
/// fast operations never flash a spinner.
class NothingDelayedSpinner extends StatefulWidget {
  const NothingDelayedSpinner({super.key, this.child});

  final Widget? child;

  @override
  State<NothingDelayedSpinner> createState() => _NothingDelayedSpinnerState();
}

class _NothingDelayedSpinnerState extends State<NothingDelayedSpinner> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(NothingMotion.spinnerDelay, () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: NothingMotion.of(context),
      curve: NothingMotion.curve,
      child: widget.child ?? const CircularProgressIndicator(),
    );
  }
}
