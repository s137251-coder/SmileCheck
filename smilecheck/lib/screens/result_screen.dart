import 'dart:io';

import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/l10n_text.dart';
import '../l10n/app_localizations.dart';
import '../models/analysis_result.dart';
import '../widgets/score_ring.dart';
import '../widgets/ui_bits.dart';

/// Presentation rules for one verdict, kept together so colour and glyph can
/// never drift apart between the ring, the halo and the badge.
class _VerdictStyle {
  const _VerdictStyle({required this.color, required this.icon});

  final Color color;
  final IconData icon;

  factory _VerdictStyle.of(Verdict verdict) {
    switch (verdict) {
      case Verdict.clean:
        return const _VerdictStyle(
          color: AppColors.accent,
          icon: Icons.check_rounded,
        );
      case Verdict.needsCheck:
        return const _VerdictStyle(
          color: AppColors.danger,
          icon: Icons.warning_amber_rounded,
        );
      case Verdict.inconclusive:
        return const _VerdictStyle(
          color: AppColors.caution,
          icon: Icons.science_outlined,
        );
      case Verdict.failed:
        return const _VerdictStyle(
          color: AppColors.textMuted,
          icon: Icons.error_outline_rounded,
        );
    }
  }
}

class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key, required this.result});

  final AnalysisResult result;

  String _badge(L l) {
    switch (result.mode) {
      case AnalysisMode.model:
        return l.badgeModelVerdict;
      case AnalysisMode.demo:
        return l.badgeDemoMode;
      case AnalysisMode.error:
        return l.badgeAnalysisError;
    }
  }

  String _caption(L l) {
    switch (result.verdict) {
      case Verdict.clean:
      case Verdict.needsCheck:
        return l.captionCleanliness;
      case Verdict.inconclusive:
        return l.captionCaptureQuality;
      case Verdict.failed:
        return l.captionNoReading;
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = _VerdictStyle.of(result.verdict);
    final l = L.of(context);

    return Scaffold(
      body: Stack(
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(gradient: AppColors.backdrop),
            child: SizedBox.expand(),
          ),
          // Verdict-coloured halo behind the ring, so the outcome reads before
          // any text is parsed.
          Positioned(
            top: -140,
            left: -60,
            right: -60,
            child: IgnorePointer(
              child: Container(
                height: 460,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      style.color.withValues(alpha: 0.26),
                      style.color.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      AppMetrics.gutter,
                      14,
                      AppMetrics.gutter,
                      8,
                    ),
                    child: Column(
                      children: [
                        InfoPill(
                          icon: result.isModelBacked
                              ? Icons.memory_rounded
                              : Icons.info_outline_rounded,
                          label: _badge(l),
                          color: style.color,
                        ),
                        const SizedBox(height: 26),
                        ScoreRing(
                          score: result.score,
                          color: style.color,
                          caption: _caption(l),
                        ),
                        const SizedBox(height: 26),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(style.icon, color: style.color, size: 26),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                l.headlineFor(result.verdict),
                                style: Theme.of(context)
                                    .textTheme
                                    .displaySmall
                                    ?.copyWith(color: style.color),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l.labelFor(result.verdict),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 22),
                        _NotesPanel(result: result, color: style.color),
                        if (!result.stats.isEmpty) ...[
                          const SizedBox(height: 14),
                          _MeasurementsPanel(result: result),
                        ],
                        const SizedBox(height: 14),
                        InfoPill(
                          icon: Icons.lock_outline_rounded,
                          label: l.privacyNeverLeft,
                          color: AppColors.textMuted,
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppMetrics.gutter,
                    6,
                    AppMetrics.gutter,
                    20,
                  ),
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(context)
                        .popUntil((route) => route.isFirst),
                    icon: const Icon(Icons.refresh_rounded, size: 21),
                    label: Text(l.checkAgain),
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

/// Explains, in plain words, what produced the number above.
class _NotesPanel extends StatelessWidget {
  const _NotesPanel({required this.result, required this.color});

  final AnalysisResult result;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final hint = result.stats.primaryHint;

    return GlassPanel(
      borderColor: color.withValues(alpha: 0.22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, size: 19, color: color),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  l.reasonText(result),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          if (hint != null) ...[
            const Divider(height: 26, color: AppColors.border),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.lightbulb_outline_rounded,
                  size: 19,
                  color: AppColors.caution,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    l.captureHintText(hint),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// The measurements actually taken from the frame, alongside a thumbnail of it.
class _MeasurementsPanel extends StatelessWidget {
  const _MeasurementsPanel({required this.result});

  final AnalysisResult result;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final stats = result.stats;
    final path = result.imagePath;

    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (path != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.file(
                    File(path),
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.measurementsTitle,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontSize: 16,
                          ),
                    ),
                    Text(
                      l.measurementsSubtitle,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          MetricBar(
            label: l.metricBrightness,
            value: stats.brightness,
            display: '${(stats.brightness * 100).toStringAsFixed(0)}%',
            color: AppColors.info,
          ),
          const SizedBox(height: 16),
          MetricBar(
            label: l.metricContrast,
            value: (stats.contrast / 0.3).clamp(0.0, 1.0),
            display: stats.contrast.toStringAsFixed(3),
            color: AppColors.accent,
          ),
          const SizedBox(height: 16),
          MetricBar(
            label: l.metricSharpness,
            value: (stats.sharpness / 0.15).clamp(0.0, 1.0),
            display: stats.sharpness.toStringAsFixed(3),
            color: AppColors.caution,
          ),
        ],
      ),
    );
  }
}
