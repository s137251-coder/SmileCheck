import 'package:flutter_test/flutter_test.dart';

import 'package:smilecheck/services/analysis_service.dart';

void main() {
  test('uses a transparent local fallback when the model is unavailable', () async {
    final service = AnalysisService();

    final result = await service.analyzeImage(imagePath: 'local-smile.jpg');

    expect(service.isModelLoaded, isFalse);
    expect(result.label, 'Healthy smile pattern');
    expect(result.notes, contains('Add the SmileCheck model'));

    service.dispose();
  });
}
