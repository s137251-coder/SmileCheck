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

/// Why the result turned out the way it did.
///
/// The domain layer emits a code and, where useful, one parameter. Turning that
/// into a sentence is the UI's job, because only the UI knows the language.
enum ResultReason {
  modelClean,
  modelNeedsCheck,
  noFrame,
  modelMissing,
  modelWrongRank,
  modelWrongChannels,
  modelWrongInputType,
  modelWrongOutputs,
  modelOpenFailed,
  modelRunFailed,
  decodeFailed,
  timedOut,
}

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
    required this.reason,
    this.reasonValue,
    this.reasonDetail,
    this.stats = ImageStats.zero,
    this.imagePath,
  });

  /// 0..100. A cleanliness probability in [AnalysisMode.model], a capture
  /// quality estimate in [AnalysisMode.demo].
  final double score;
  final Verdict verdict;
  final AnalysisMode mode;
  final ResultReason reason;

  /// Numeric parameter for [reason], e.g. the model's output class count.
  final int? reasonValue;

  /// Technical detail for [reason], such as an exception message or a tensor
  /// type name. Deliberately not translated.
  final String? reasonDetail;

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
      reason: clean ? ResultReason.modelClean : ResultReason.modelNeedsCheck,
      stats: stats,
      imagePath: imagePath,
    );
  }

  /// Builds the honest fallback: the frame was measured locally, but nothing
  /// classified the teeth, so no clean/dirty claim is made.
  factory AnalysisResult.demo({
    required ImageStats stats,
    required ResultReason reason,
    int? reasonValue,
    String? reasonDetail,
    String? imagePath,
  }) {
    return AnalysisResult(
      score: stats.captureQuality,
      verdict: Verdict.inconclusive,
      mode: AnalysisMode.demo,
      reason: reason,
      reasonValue: reasonValue,
      reasonDetail: reasonDetail,
      stats: stats,
      imagePath: imagePath,
    );
  }

  factory AnalysisResult.failure(ResultReason reason, {String? detail}) {
    return AnalysisResult(
      score: 0,
      verdict: Verdict.failed,
      mode: AnalysisMode.error,
      reason: reason,
      reasonDetail: detail,
    );
  }

  Map<String, dynamic> toJson() => {
        'score': score,
        'verdict': verdict.name,
        'mode': mode.name,
        'reason': reason.name,
        if (reasonValue != null) 'reasonValue': reasonValue,
        if (reasonDetail != null) 'reasonDetail': reasonDetail,
        'stats': stats.toJson(),
      };
}
