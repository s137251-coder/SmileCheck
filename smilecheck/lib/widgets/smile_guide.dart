import 'package:flutter/material.dart';

import '../core/app_theme.dart';

/// The aiming frame drawn over the live preview (spec 6.2).
///
/// It dims everything outside a rounded window, marks the corners, and shows a
/// soft mouth arc so the user knows where to put their smile. The window is
/// slightly wider than tall because a smile is a wide subject.
class SmileGuide extends StatefulWidget {
  const SmileGuide({super.key, this.active = true});

  /// When false the guide holds still, used while a capture is in flight.
  final bool active;

  @override
  State<SmileGuide> createState() => _SmileGuideState();
}

class _SmileGuideState extends State<SmileGuide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) => CustomPaint(
          painter: _SmileGuidePainter(
            glow: widget.active ? _pulse.value : 0.4,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _SmileGuidePainter extends CustomPainter {
  const _SmileGuidePainter({required this.glow});

  /// 0..1 breathing value driving the bracket brightness.
  final double glow;

  static const double _widthFactor = 0.78;
  static const double _aspect = 1.22;

  @override
  void paint(Canvas canvas, Size size) {
    final windowWidth = size.width * _widthFactor;
    final windowHeight = windowWidth * _aspect;
    final window = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.46),
      width: windowWidth,
      height: windowHeight,
    );
    final rounded = RRect.fromRectAndRadius(window, const Radius.circular(34));

    // Dim the surround by punching the window out of a full-bleed scrim.
    final scrim = Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      Path()..addRRect(rounded),
    );
    canvas.drawPath(
      scrim,
      Paint()..color = AppColors.background.withValues(alpha: 0.62),
    );

    final accent = AppColors.accent.withValues(alpha: 0.35 + (glow * 0.45));

    canvas.drawRRect(
      rounded,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.white.withValues(alpha: 0.18),
    );

    _paintCorners(canvas, window, accent);
    _paintMouthHint(canvas, window);
  }

  /// Four L-shaped brackets, the familiar "line up here" affordance.
  void _paintCorners(Canvas canvas, Rect window, Color color) {
    const arm = 30.0;
    const inset = 6.0;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.4
      ..strokeCap = StrokeCap.round
      ..color = color;

    final corners = <List<Offset>>[
      [
        window.topLeft + const Offset(inset, inset + arm),
        window.topLeft + const Offset(inset, inset),
        window.topLeft + const Offset(inset + arm, inset),
      ],
      [
        window.topRight + const Offset(-inset - arm, inset),
        window.topRight + const Offset(-inset, inset),
        window.topRight + const Offset(-inset, inset + arm),
      ],
      [
        window.bottomRight + const Offset(-inset, -inset - arm),
        window.bottomRight + const Offset(-inset, -inset),
        window.bottomRight + const Offset(-inset - arm, -inset),
      ],
      [
        window.bottomLeft + const Offset(inset + arm, -inset),
        window.bottomLeft + const Offset(inset, -inset),
        window.bottomLeft + const Offset(inset, -inset - arm),
      ],
    ];

    for (final corner in corners) {
      canvas.drawPath(
        Path()
          ..moveTo(corner[0].dx, corner[0].dy)
          ..lineTo(corner[1].dx, corner[1].dy)
          ..lineTo(corner[2].dx, corner[2].dy),
        paint,
      );
    }
  }

  /// A dashed smile arc in the lower third, where the mouth should sit.
  void _paintMouthHint(Canvas canvas, Rect window) {
    final arcRect = Rect.fromCenter(
      center: Offset(window.center.dx, window.center.dy + window.height * 0.16),
      width: window.width * 0.5,
      height: window.height * 0.22,
    );

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.34);

    // Hand-stepped dashes: a short arc, a gap, repeated across the sweep.
    const start = 0.25;
    const sweep = 2.64;
    const segments = 9;
    const step = sweep / segments;
    for (var i = 0; i < segments; i += 2) {
      canvas.drawArc(arcRect, start + (i * step), step, false, paint);
    }
  }

  @override
  bool shouldRepaint(_SmileGuidePainter oldDelegate) =>
      oldDelegate.glow != glow;
}
