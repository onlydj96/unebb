import 'package:flutter/material.dart';

/// AnimatedSwitcher for step-by-step flows (review, word practice).
///
/// * Views that are fading out ignore taps — a second tap on the old
///   "Next word" button used to act twice and skip a word.
/// * Every child keeps the same keyed wrapper whether it is current or
///   outgoing. Wrapping only the outgoing child changed its parent, so Flutter
///   remounted it at every transition: `initState` ran again (voice views
///   re-spoke the word, text fields grabbed focus while fading out).
class PhaseSwitcher extends StatelessWidget {
  const PhaseSwitcher({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 250),
  });

  /// Give each phase a distinct key so the switch animates.
  final Widget child;
  final Duration duration;

  /// Layout used by [PhaseSwitcher]; exposed for reuse with a custom
  /// AnimatedSwitcher.
  static Widget layoutBuilder(Widget? current, List<Widget> previous) {
    return Stack(
      alignment: Alignment.center,
      children: [
        for (final child in previous)
          IgnorePointer(key: child.key, child: child),
        if (current != null)
          IgnorePointer(key: current.key, ignoring: false, child: current),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return AnimatedSwitcher(
      duration: reduceMotion ? Duration.zero : duration,
      layoutBuilder: layoutBuilder,
      child: child,
    );
  }
}
