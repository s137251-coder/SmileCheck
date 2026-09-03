import 'package:flutter/material.dart';

import '../core/app_theme.dart';

/// The sweeping scan band drawn over the frozen frame while it is analysed
/// (spec 6.3). Purely decorative: it reports that work is happening, and stops
/// as soon as the caller drops it from the tree.
class ScanOverlay extends StatefulWidget {
  const ScanOverlay({super.key});

  @override
  State<ScanOverlay> createState() => _ScanOverlayState();
}

class _ScanOverlayState extends State<ScanOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _ScanPainter(
            progress: Curves.easeInOutSine.transform(_controller.value),
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _ScanPainter extends CustomPainter {
  const _ScanPainter({required this.progress});

  /// 0..1 position of the band, top to bottom.
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    // Faint horizontal rules give the sweep something to travel across.
    final rule = Paint()..color = Colors.white.withValues(alpha: 0.05);
    for (var y = 0.0; y < size.height; y += 18) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), rule);
    }

    final bandHeight = size.height * 0.22;
    final centre = progress * size.height;
    final band = Rect.fromLTRB(
      0,
      centre - bandHeight,
      size.width,
      centre + bandHeight,
    );

    canvas.drawRect(
      band,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.accent.withValues(alpha: 0),
            AppColors.accent.withValues(alpha: 0.28),
            AppColors.accent.withValues(alpha: 0),
          ],
        ).createShader(band),
    );

    canvas.drawRect(
      Rect.fromLTWH(0, centre - 1, size.width, 2),
      Paint()
        ..color = AppColors.accent.withValues(alpha: 0.9)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
  }

  @override
  bool shouldRepaint(_ScanPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
