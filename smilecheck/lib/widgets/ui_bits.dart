import 'package:flutter/material.dart';

import '../core/app_theme.dart';

/// The SmileCheck mark: a rounded tile with a drawn smile arc.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 96, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? AppColors.accent;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: color == null ? AppColors.accentSweep : null,
        color: color,
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: [
          BoxShadow(
            color: tint.withValues(alpha: 0.35),
            blurRadius: size * 0.45,
            spreadRadius: -size * 0.08,
            offset: Offset(0, size * 0.12),
          ),
        ],
      ),
      child: CustomPaint(painter: _SmilePainter(size: size)),
    );
  }
}

class _SmilePainter extends CustomPainter {
  const _SmilePainter({required this.size});

  final double size;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final stroke = canvasSize.width * 0.085;
    final paint = Paint()
      ..color = const Color(0xFF06281D)
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final w = canvasSize.width;
    final h = canvasSize.height;

    // Two eyes and a wide smile, drawn rather than pulled from an icon font so
    // the mark scales cleanly at every size the app uses it.
    canvas.drawLine(
      Offset(w * 0.33, h * 0.34),
      Offset(w * 0.33, h * 0.42),
      paint,
    );
    canvas.drawLine(
      Offset(w * 0.67, h * 0.34),
      Offset(w * 0.67, h * 0.42),
      paint,
    );
    canvas.drawArc(
      Rect.fromLTWH(w * 0.24, h * 0.34, w * 0.52, h * 0.38),
      0.15,
      3.14159 - 0.3,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_SmilePainter oldDelegate) => false;
}

/// Translucent panel used for every card-like surface in the app.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.color,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.surface.withValues(alpha: 0.82),
        borderRadius: AppMetrics.card,
        border: Border.all(color: borderColor ?? AppColors.border),
      ),
      child: child,
    );
  }
}

/// Small labelled pill, used for the privacy promise and mode badges.
class InfoPill extends StatelessWidget {
  const InfoPill({
    super.key,
    required this.icon,
    required this.label,
    this.color = AppColors.accent,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: AppMetrics.pill,
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Round translucent control for the camera chrome.
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.active = false,
    this.size = 46,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool active;
  final double size;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: active
          ? AppColors.accent.withValues(alpha: 0.9)
          : Colors.black.withValues(alpha: 0.42),
      shape: CircleBorder(
        side: BorderSide(
          color: active ? Colors.transparent : AppColors.border,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(
            icon,
            size: size * 0.46,
            color: active ? const Color(0xFF04231A) : AppColors.textPrimary,
          ),
        ),
      ),
    );

    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// One measured value from the frame, shown as a labelled bar.
class MetricBar extends StatelessWidget {
  const MetricBar({
    super.key,
    required this.label,
    required this.value,
    required this.display,
    this.color = AppColors.info,
  });

  final String label;

  /// Fill ratio, 0..1.
  final double value;

  /// Text shown on the right, already formatted.
  final String display;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            Text(
              display,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: AppMetrics.pill,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: value.clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, fill, _) => LinearProgressIndicator(
              value: fill,
              minHeight: 6,
              backgroundColor: AppColors.surfaceRaised,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
      ],
    );
  }
}
