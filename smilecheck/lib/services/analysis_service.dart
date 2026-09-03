import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import '../models/analysis_result.dart';
import '../models/image_stats.dart';
import 'image_preprocessor.dart';

/// Whether the bundled asset can actually produce a SmileCheck verdict.
enum ModelStatus {
  /// Not inspected yet.
  unknown,

  /// No file at the expected asset path.
  missing,

  /// A model loaded, but its signature is not the binary clean/dirty contract.
  incompatible,

  /// Loaded and matching the contract.
  ready,
}

/// What the interpreter reported about the bundled model.
class ModelReport {
  const ModelReport({
    required this.status,
    required this.detail,
    this.inputShape,
    this.outputShape,
  });

  final ModelStatus status;

  /// Human-readable explanation, shown verbatim in the UI.
  final String detail;
  final List<int>? inputShape;
  final List<int>? outputShape;

  bool get isReady => status == ModelStatus.ready;
}

/// The signature SmileCheck requires of a bundled model, kept as a pure
/// function of the tensor description so it can be exercised directly.
class ModelContract {
  const ModelContract._();

  /// A probability pair `[clean_score, dirty_score]`, as documented in
  /// README.md.
  static const int outputClasses = 2;

  /// Decides whether a model may be used for a verdict.
  ///
  /// This is the guard that stops a generic classifier from being read as a
  /// dental verdict: an ImageNet backbone exposes 1001 outputs, not 2, and its
  /// first two classes have nothing to do with a smile.
  static ModelReport validate({
    required List<int> inputShape,
    required TensorType inputType,
    required List<int> outputShape,
  }) {
    ModelReport reject(String detail) => ModelReport(
          status: ModelStatus.incompatible,
          detail: detail,
          inputShape: inputShape,
          outputShape: outputShape,
        );

    if (inputShape.length != 4) {
      return reject(
        'The bundled model expects a rank-${inputShape.length} input. '
        'SmileCheck needs [1, height, width, channels].',
      );
    }

    final channels = inputShape[3];
    if (channels != 1 && channels != 3) {
      return reject(
        'The bundled model expects $channels input channels. '
        'SmileCheck supports 1 or 3.',
      );
    }

    if (inputType != TensorType.float32 && inputType != TensorType.uint8) {
      return reject(
        'The bundled model takes ${inputType.name} input. SmileCheck supplies '
        'float32 or uint8.',
      );
    }

    final classes = outputShape.isEmpty ? 0 : outputShape.last;
    if (classes != outputClasses) {
      return reject(
        'The bundled model returns $classes classes, so it is a '
        'general-purpose classifier rather than a smile-cleanliness one. '
        'SmileCheck needs exactly $outputClasses outputs, [clean, dirty], so '
        'only capture quality is reported.',
      );
    }

    return ModelReport(
      status: ModelStatus.ready,
      detail: 'Local model ready: ${inputShape.join(' x ')} '
          '${inputType.name} in, $classes classes out.',
      inputShape: inputShape,
      outputShape: outputShape,
    );
  }
}

/// Runs the local smile analysis.
///
/// The service refuses to dress a fallback up as a prediction: unless a model
/// matching the documented contract loaded and ran, the result comes back as
/// [AnalysisMode.demo] with the reason attached.
class AnalysisService {
  AnalysisService({ImagePreprocessor? preprocessor})
      : _preprocessor = preprocessor ?? ImagePreprocessor();

  static const String modelAssetPath = 'assets/models/smilecheck.tflite';

  final ImagePreprocessor _preprocessor;

  Interpreter? _interpreter;
  ModelReport _report = const ModelReport(
    status: ModelStatus.unknown,
    detail: 'The local model has not been inspected yet.',
  );

  ModelReport get report => _report;

  bool get isModelUsable => _report.isReady && _interpreter != null;

  AnalysisResult? latestResult;

  Future<AnalysisResult> analyzeImage({String? imagePath}) async {
    await _ensureModel();

    if (imagePath == null) {
      return _remember(AnalysisResult.demo(
        stats: ImageStats.zero,
        reason: 'No frame was captured, so there was nothing to analyse. '
            'Check camera access and try again.',
      ));
    }

    final FramePayload payload;
    try {
      final shape = _report.inputShape;
      final hasShape = shape != null && shape.length >= 3;
      payload = await _preprocessor.prepare(
        imagePath,
        width: hasShape ? shape[2] : 224,
        height: hasShape ? shape[1] : 224,
      );
    } on Object catch (error) {
      return _remember(
        AnalysisResult.failure('The captured frame could not be read: $error'),
      );
    }

    if (isModelUsable) {
      final probability = _runInterpreter(payload);
      if (probability != null) {
        return _remember(AnalysisResult.fromModel(
          score: probability * 100,
          stats: payload.stats,
          imagePath: imagePath,
        ));
      }
    }

    return _remember(AnalysisResult.demo(
      stats: payload.stats,
      reason: _report.detail,
      imagePath: imagePath,
    ));
  }

  /// Returns the clean probability in 0..1, or null when inference failed.
  double? _runInterpreter(FramePayload payload) {
    final interpreter = _interpreter;
    if (interpreter == null) return null;

    try {
      final inputTensor = interpreter.getInputTensor(0);
      final outputTensor = interpreter.getOutputTensor(0);
      final channels = inputTensor.shape.length >= 4 ? inputTensor.shape[3] : 3;

      final input = <Object>[
        _preprocessor.toTensor(
          payload,
          channels: channels,
          quantised: inputTensor.type == TensorType.uint8,
        )
      ];
      final output = <List<num>>[List<num>.filled(ModelContract.outputClasses, 0)];

      interpreter.run(input, output);

      return _toCleanProbability(output.first, outputTensor);
    } on Object catch (error) {
      // A model that throws mid-run cannot be trusted for later frames either.
      _interpreter?.close();
      _interpreter = null;
      _report = ModelReport(
        status: ModelStatus.incompatible,
        detail: 'The local model failed during inference and was unloaded: '
            '$error',
        inputShape: _report.inputShape,
        outputShape: _report.outputShape,
      );
      return null;
    }
  }

  /// Turns the raw output pair into P(clean).
  ///
  /// Quantised outputs are dequantised with the tensor's own scale and zero
  /// point first. Values that can be negative are treated as logits and passed
  /// through a softmax; non-negative values are normalised by their sum.
  double _toCleanProbability(List<num> raw, Tensor outputTensor) {
    final params = outputTensor.params;
    final quantised =
        outputTensor.type == TensorType.uint8 && params.scale != 0;

    final clean = quantised
        ? (raw[0].toDouble() - params.zeroPoint) * params.scale
        : raw[0].toDouble();
    final dirty = quantised
        ? (raw[1].toDouble() - params.zeroPoint) * params.scale
        : raw[1].toDouble();

    if (clean < 0 || dirty < 0) {
      final peak = math.max(clean, dirty);
      final expClean = math.exp(clean - peak);
      final expDirty = math.exp(dirty - peak);
      return (expClean / (expClean + expDirty)).clamp(0.0, 1.0);
    }

    final total = clean + dirty;
    if (total <= 0) return 0;
    return (clean / total).clamp(0.0, 1.0);
  }

  /// Loads the asset once and records why it can or cannot be used.
  Future<void> _ensureModel() async {
    if (_report.status != ModelStatus.unknown) return;

    try {
      await rootBundle.load(modelAssetPath);
    } on Object {
      _report = const ModelReport(
        status: ModelStatus.missing,
        detail: 'No model is bundled. Add a binary clean/dirty model at '
            '$modelAssetPath to enable real verdicts.',
      );
      return;
    }

    Interpreter? candidate;
    try {
      candidate = await Interpreter.fromAsset(modelAssetPath);
      _report = _validate(candidate);
      if (_report.isReady) {
        _interpreter = candidate;
      } else {
        candidate.close();
      }
    } on Object catch (error) {
      candidate?.close();
      _report = ModelReport(
        status: ModelStatus.incompatible,
        detail: 'The bundled model could not be opened: $error',
      );
    }
  }

  ModelReport _validate(Interpreter interpreter) {
    final input = interpreter.getInputTensor(0);
    return ModelContract.validate(
      inputShape: input.shape,
      inputType: input.type,
      outputShape: interpreter.getOutputTensor(0).shape,
    );
  }

  AnalysisResult _remember(AnalysisResult result) {
    latestResult = result;
    if (kDebugMode) {
      debugPrint('SmileCheck result: ${result.toJson()}');
    }
    return result;
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }
}
