import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:unebb/core/l10n/l10n.dart';
import 'package:unebb/core/theme/app_colors.dart';
import 'package:unebb/core/theme/app_typography.dart';

/// The UnEbb logo symbol — `assets/logo/logo.svg` without its tile and
/// wordmark: an open book whose crimson page (✕, forgetting) and mint page
/// (✓, recall) are joined by an arc — memory moving from ebb to flow.
///
/// Drawn from the SVG's paths, so it stays sharp at any size without an SVG
/// dependency.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 40, this.onDark = false});

  /// Height of the mark; the width follows the logo's proportions.
  final double size;

  /// Inverted cover for dark surfaces: a paper cover whose rim is knocked
  /// out to cocoa.
  final bool onDark;

  /// Width / height of the symbol.
  static final double aspectRatio =
      BrandMarkPainter.viewport.width / BrandMarkPainter.viewport.height;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size(size * aspectRatio, size),
        painter: BrandMarkPainter(onDark: onDark),
      ),
    );
  }
}

/// Paints the logo symbol scaled to the canvas height.
class BrandMarkPainter extends CustomPainter {
  const BrandMarkPainter({this.onDark = false, this.arcLevels});

  final bool onDark;

  /// Opacity of the three arc segments, ebb → flow. Null draws them fully.
  final List<double>? arcLevels;

  /// The symbol's bounds on the SVG's 1024 × 1024 artboard.
  static const Rect viewport = Rect.fromLTRB(220, 185, 804, 677);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.height / viewport.height;
    canvas
      ..save()
      ..scale(scale)
      ..translate(-viewport.left, -viewport.top);

    // Memory transition arc.
    _stroke(canvas, _curve(374, 259, 401, 234, 428, 226), 36,
        AppColors.logoArcEbb.withValues(alpha: _level(0)));
    _stroke(canvas, _curve(474, 215, 511, 204, 548, 215), 40,
        AppColors.logoArcMid.withValues(alpha: _level(1)));
    _stroke(canvas, _curve(591, 226, 629, 236, 652, 260), 42,
        AppColors.mint.withValues(alpha: _level(2)));

    // ✕ and ✓ badges.
    canvas.drawCircle(
        const Offset(300, 306), 59, Paint()..color = AppColors.crimson);
    _stroke(
      canvas,
      Path()
        ..moveTo(281, 287)
        ..lineTo(319, 325)
        ..moveTo(319, 287)
        ..lineTo(281, 325),
      16,
      AppColors.paper,
    );
    canvas.drawCircle(
        const Offset(722, 306), 59, Paint()..color = AppColors.logoCheck);
    _stroke(
      canvas,
      Path()
        ..moveTo(696, 306)
        ..lineTo(714, 326)
        ..lineTo(750, 284),
      17,
      AppColors.paper,
    );

    // Book: cover, paper rim, then the two pages.
    canvas
      ..drawPath(
        _cover,
        Paint()..color = onDark ? AppColors.paper : AppColors.cocoa,
      )
      ..drawPath(
        _rimLeft,
        Paint()..color = onDark ? AppColors.cocoa : AppColors.paper,
      )
      ..drawPath(
        _rimRight,
        Paint()..color = onDark ? AppColors.cocoa : AppColors.paper,
      )
      ..drawPath(_pageLeft, Paint()..color = AppColors.crimson)
      ..drawPath(_pageRight, Paint()..color = AppColors.mint)
      ..restore();
  }

  double _level(int i) => arcLevels?[i].clamp(0.0, 1.0) ?? 1.0;

  static Path _curve(
    double x0,
    double y0,
    double cx,
    double cy,
    double x1,
    double y1,
  ) =>
      Path()
        ..moveTo(x0, y0)
        ..quadraticBezierTo(cx, cy, x1, y1);

  static void _stroke(Canvas canvas, Path path, double width, Color color) {
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  static final Path _cover = Path()
    ..moveTo(314, 405)
    ..quadraticBezierTo(277, 399, 264, 433)
    ..lineTo(231, 589)
    ..quadraticBezierTo(222, 622, 252, 629)
    ..quadraticBezierTo(375, 589, 483, 657)
    ..quadraticBezierTo(506, 678, 518, 666)
    ..quadraticBezierTo(630, 585, 766, 629)
    ..quadraticBezierTo(797, 637, 792, 601)
    ..lineTo(765, 434)
    ..quadraticBezierTo(756, 405, 718, 405)
    ..lineTo(734, 584)
    ..quadraticBezierTo(609, 552, 513, 629)
    ..quadraticBezierTo(417, 550, 290, 584)
    ..close();

  static final Path _rimLeft = Path()
    ..moveTo(338, 388)
    ..quadraticBezierTo(427, 385, 503, 470)
    ..lineTo(503, 604)
    ..quadraticBezierTo(412, 540, 285, 570)
    ..lineTo(314, 413)
    ..quadraticBezierTo(319, 393, 338, 388)
    ..close();

  static final Path _rimRight = Path()
    ..moveTo(686, 388)
    ..quadraticBezierTo(597, 385, 521, 470)
    ..lineTo(521, 604)
    ..quadraticBezierTo(612, 540, 739, 570)
    ..lineTo(710, 413)
    ..quadraticBezierTo(705, 393, 686, 388)
    ..close();

  static final Path _pageLeft = Path()
    ..moveTo(362, 363)
    ..quadraticBezierTo(437, 363, 503, 446)
    ..lineTo(503, 596)
    ..quadraticBezierTo(428, 532, 312, 546)
    ..lineTo(339, 387)
    ..quadraticBezierTo(344, 363, 362, 363)
    ..close();

  static final Path _pageRight = Path()
    ..moveTo(662, 363)
    ..quadraticBezierTo(587, 363, 521, 446)
    ..lineTo(521, 596)
    ..quadraticBezierTo(596, 532, 712, 546)
    ..lineTo(685, 387)
    ..quadraticBezierTo(680, 363, 662, 363)
    ..close();

  @override
  bool shouldRepaint(BrandMarkPainter oldDelegate) {
    if (oldDelegate.onDark != onDark) return true;
    final a = oldDelegate.arcLevels;
    final b = arcLevels;
    if (a == null || b == null) return a != b;
    for (var i = 0; i < b.length; i++) {
      if (a[i] != b[i]) return true;
    }
    return false;
  }
}

/// The "UnEbb" logotype — "Un" in cocoa, "Ebb" in crimson, set in Nunito
/// Black as in the logo — optionally preceded by the mark.
class BrandWordmark extends StatelessWidget {
  const BrandWordmark({
    super.key,
    this.fontSize = 22,
    this.showMark = true,
    this.onDark = false,
  });

  final double fontSize;
  final bool showMark;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final style = AppTypography.logotype.copyWith(
      fontSize: fontSize,
      letterSpacing: -0.042 * fontSize,
    );
    return Semantics(
      label: context.l10n.appTitle,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showMark) ...[
            BrandMark(size: fontSize * 1.3, onDark: onDark),
            SizedBox(width: fontSize * 0.4),
          ],
          Text.rich(
            TextSpan(
              style: style,
              children: [
                TextSpan(
                  text: 'Un',
                  style: TextStyle(
                    color: onDark ? AppColors.textOnDark : AppColors.cocoa,
                  ),
                ),
                TextSpan(
                  text: 'Ebb',
                  // Crimson is ~2:1 on cocoa; use the logo's light tint.
                  style: TextStyle(
                    color: onDark ? AppColors.logoArcEbb : AppColors.crimson,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The stacked logo: mark above the logotype, as on the app icon.
class BrandLockup extends StatelessWidget {
  const BrandLockup({super.key, this.markSize = 88});

  final double markSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        BrandMark(size: markSize),
        SizedBox(height: markSize * 0.16),
        BrandWordmark(showMark: false, fontSize: markSize * 0.52),
      ],
    );
  }
}

/// The mark while something is being worked on: the recall arc lights up
/// segment by segment, from ebb to flow. Static when the platform asks for
/// reduced motion.
class BrandPulse extends StatefulWidget {
  const BrandPulse({super.key, this.size = 52});

  /// Height of the mark.
  final double size;

  @override
  State<BrandPulse> createState() => _BrandPulseState();
}

class _BrandPulseState extends State<BrandPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );

  bool _static = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _static = MediaQuery.of(context).disableAnimations;
    if (_static) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// A wave that lights each segment in turn, then lets it fade back.
  static double _level(int segment, double t) {
    final phase = (t - segment * 0.18) % 1.0;
    if (phase > 0.5) return 0.2;
    return 0.2 + 0.8 * math.sin(math.pi * phase / 0.5);
  }

  @override
  Widget build(BuildContext context) {
    final size = Size(widget.size * BrandMark.aspectRatio, widget.size);
    if (_static) {
      return ExcludeSemantics(
        child: CustomPaint(size: size, painter: const BrandMarkPainter()),
      );
    }
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          return CustomPaint(
            size: size,
            painter: BrandMarkPainter(
              arcLevels: [_level(0, t), _level(1, t), _level(2, t)],
            ),
          );
        },
      ),
    );
  }
}
