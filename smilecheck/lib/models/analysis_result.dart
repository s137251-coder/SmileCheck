import 'image_stats.dart';

/// Where a result came from. The UI never blurs these together: a verdict
/// produced by a trained model is presented differently from a local estimate.
enum AnalysisMode {
  /// A model matching the SmileCheck contract ran on the frame.
  model,

  /// No usable model, so only the local capture estimate is available.
  demo,

  /// The frame could not be analysed at all.
  error,
}

enum Verdict { clean, needsCheck, inconclusive, failed }

/// Single source of truth for the decision boundary, shared by the service that
/// produces a verdict and the screen that renders it.
class AnalysisThresholds {
  const AnalysisThresholds._();

  /// At or above this score the smile is reported as clean.
  static const double clean = 70;
}

class AnalysisResult {
  const AnalysisResult({
    required this.score,
    required this.verdict,
    required this.mode,
    required this.headline,
    required this.label,
    required this.notes,
    this.stats = ImageStats.zero,
    this.imagePath,
  });

  /// 0..100. A cleanliness probability in [AnalysisMode.model], a capture
  /// quality estimate in [AnalysisMode.demo].
  final double score;
  final Verdict verdict;
  final AnalysisMode mode;

  /// Large verdict text, e.g. "Looks clean".
  final String headline;

  /// Supporting classification line.
  final String label;

  /// Plain-language explanation of what actually happened.
  final String notes;

  final ImageStats stats;
  final String? imagePath;

  bool get isModelBacked => mode == AnalysisMode.model;

  /// Builds the clean / needs-check verdict from a model probability, using the
  /// one shared threshold.
  factory AnalysisResult.fromModel({
    required double score,
    required ImageStats stats,
    String? imagePath,
  }) {
    final clean = score >= AnalysisThresholds.clean;
    return AnalysisResult(
      score: score,
      verdict: clean ? Verdict.clean : Verdict.needsCheck,
      mode: AnalysisMode.model,
      headline: clean ? 'Looks clean' : 'Check needed',
      label: clean ? 'No food particles detected' : 'Food particles detected',
      notes: clean
          ? 'The on-device model found no residue around your smile.'
          : 'The on-device model flagged possible residue. Worth a quick rinse.',
      stats: stats,
      imagePath: imagePath,
    );
  }

  /// Builds the honest fallback: the frame was measured locally, but nothing
  /// classified the teeth, so no clean/dirty claim is made.
  factory AnalysisResult.demo({
    required ImageStats stats,
    required String reason,
    String? imagePath,
  }) {
    return AnalysisResult(
      score: stats.captureQuality,
      verdict: Verdict.inconclusive,
      mode: AnalysisMode.demo,
      headline: 'No verdict yet',
      label: 'Capture quality only',
      notes: reason,
      stats: stats,
      imagePath: imagePath,
    );
  }

  factory AnalysisResult.failure(String notes) {
    return AnalysisResult(
      score: 0,
      verdict: Verdict.failed,
      mode: AnalysisMode.error,
      headline: 'Analysis failed',
      label: 'Nothing was measured',
      notes: notes,
    );
  }

  Map<String, dynamic> toJson() => {
        'score': score,
        'verdict': verdict.name,
        'mode': mode.name,
        'headline': headline,
        'label': label,
        'notes': notes,
        'stats': stats.toJson(),
      };
}
