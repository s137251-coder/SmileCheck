import 'package:flutter_test/flutter_test.dart';

import 'package:tflite_flutter/tflite_flutter.dart';

import 'package:smilecheck/models/analysis_result.dart';
import 'package:smilecheck/models/image_stats.dart';
import 'package:smilecheck/services/analysis_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AnalysisService', () {
    test('reports demo mode when there is no frame to analyse', () async {
      final service = AnalysisService();
      addTearDown(service.dispose);

      final result = await service.analyzeImage();

      expect(result.mode, AnalysisMode.demo);
      expect(result.verdict, Verdict.inconclusive);
      expect(result.isModelBacked, isFalse);
    });

    test('never claims a verdict without a contract-matching model', () async {
      final service = AnalysisService();
      addTearDown(service.dispose);

      final result = await service.analyzeImage(imagePath: 'missing-file.jpg');

      expect(result.isModelBacked, isFalse);
      expect(result.headline, isNot('Looks clean'));
      expect(result.headline, isNot('Check needed'));
    });

    test('never promotes the bundled asset to a usable model', () async {
      final service = AnalysisService();
      addTearDown(service.dispose);

      await service.analyzeImage(imagePath: 'missing-file.jpg');

      expect(service.isModelUsable, isFalse);
      expect(service.report.status, isNot(ModelStatus.ready));
    });
  });

  group('ModelContract', () {
    test('rejects the ImageNet signature the repo currently ships', () {
      // mobilenet_v1_1.0_224_quant: 224x224 uint8 in, 1001 classes out.
      final report = ModelContract.validate(
        inputShape: const [1, 224, 224, 3],
        inputType: TensorType.uint8,
        outputShape: const [1, 1001],
      );

      expect(report.status, ModelStatus.incompatible);
      expect(report.isReady, isFalse);
      expect(report.detail, contains('1001'));
    });

    test('accepts the documented binary contract', () {
      final quantised = ModelContract.validate(
        inputShape: const [1, 224, 224, 3],
        inputType: TensorType.uint8,
        outputShape: const [1, 2],
      );
      final float = ModelContract.validate(
        inputShape: const [1, 128, 128, 1],
        inputType: TensorType.float32,
        outputShape: const [1, 2],
      );

      expect(quantised.isReady, isTrue);
      expect(float.isReady, isTrue);
    });

    test('rejects unsupported ranks, channels and input types', () {
      expect(
        ModelContract.validate(
          inputShape: const [1, 224, 224],
          inputType: TensorType.uint8,
          outputShape: const [1, 2],
        ).isReady,
        isFalse,
      );
      expect(
        ModelContract.validate(
          inputShape: const [1, 224, 224, 4],
          inputType: TensorType.uint8,
          outputShape: const [1, 2],
        ).isReady,
        isFalse,
      );
      expect(
        ModelContract.validate(
          inputShape: const [1, 224, 224, 3],
          inputType: TensorType.int8,
          outputShape: const [1, 2],
        ).isReady,
        isFalse,
      );
    });
  });

  group('AnalysisResult', () {
    test('uses one threshold for the verdict and its wording', () {
      const stats = ImageStats(brightness: 0.5, contrast: 0.2, sharpness: 0.1);

      final justClean = AnalysisResult.fromModel(
        score: AnalysisThresholds.clean,
        stats: stats,
      );
      final justBelow = AnalysisResult.fromModel(
        score: AnalysisThresholds.clean - 0.1,
        stats: stats,
      );

      expect(justClean.verdict, Verdict.clean);
      expect(justClean.headline, 'Looks clean');
      expect(justClean.label, 'No food particles detected');

      expect(justBelow.verdict, Verdict.needsCheck);
      expect(justBelow.headline, 'Check needed');
      expect(justBelow.label, 'Food particles detected');
    });
  });

  group('ImageStats', () {
    test('scores a well-exposed, sharp frame highly', () {
      const good = ImageStats(brightness: 0.55, contrast: 0.24, sharpness: 0.13);

      expect(good.captureQuality, greaterThan(95));
      expect(good.primaryHint, isNull);
    });

    test('penalises a dark frame and explains why', () {
      const dark = ImageStats(brightness: 0.06, contrast: 0.03, sharpness: 0.01);

      expect(dark.captureQuality, lessThan(25));
      expect(dark.primaryHint, contains('dark'));
    });

    test('penalises a blown-out frame as well as a dark one', () {
      const blown = ImageStats(brightness: 0.97, contrast: 0.05, sharpness: 0.02);

      expect(blown.captureQuality, lessThan(45));
      expect(blown.primaryHint, contains('over-exposed'));
    });

    test('stays within 0..100 for every input', () {
      const extreme = ImageStats(brightness: 1, contrast: 1, sharpness: 1);

      expect(extreme.captureQuality, inInclusiveRange(0, 100));
      expect(ImageStats.zero.captureQuality, 0);
    });
  });
}
