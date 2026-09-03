import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:smilecheck/app.dart';
import 'package:smilecheck/models/analysis_result.dart';
import 'package:smilecheck/models/image_stats.dart';
import 'package:smilecheck/screens/result_screen.dart';
import 'package:smilecheck/services/analysis_service.dart';
import 'package:smilecheck/services/camera_service.dart';

Widget _wrap(Widget child) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<CameraService>(create: (_) => CameraService()),
      Provider<AnalysisService>(create: (_) => AnalysisService()),
    ],
    child: child,
  );
}

void main() {
  testWidgets('splash brands the app and hands over to the camera',
      (tester) async {
    await tester.pumpWidget(_wrap(const SmileCheckApp()));

    expect(find.text('SmileCheck'), findsOneWidget);
    expect(find.text('Runs entirely on this device'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pump(const Duration(milliseconds: 600));

    // The camera cannot open under the test binding, so the home screen must
    // show its explained fallback rather than a bare preview.
    expect(find.text('Preparing camera...'), findsOneWidget);
  });

  testWidgets('a model verdict is shown with its score and wording',
      (tester) async {
    final result = AnalysisResult.fromModel(
      score: 91.4,
      stats: const ImageStats(brightness: 0.6, contrast: 0.2, sharpness: 0.1),
    );

    await tester.pumpWidget(
      MaterialApp(home: ResultScreen(result: result)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Looks clean'), findsOneWidget);
    expect(find.text('91'), findsOneWidget);
    expect(find.text('On-device model verdict'), findsOneWidget);
    expect(find.text('CLEANLINESS'), findsOneWidget);
  });

  testWidgets('demo mode never renders a clean or dirty verdict',
      (tester) async {
    final result = AnalysisResult.demo(
      stats: const ImageStats(brightness: 0.5, contrast: 0.2, sharpness: 0.1),
      reason: 'The bundled model returns 1001 classes.',
    );

    await tester.pumpWidget(
      MaterialApp(home: ResultScreen(result: result)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Demo mode - no trained model'), findsOneWidget);
    expect(find.text('No verdict yet'), findsOneWidget);
    expect(find.text('Looks clean'), findsNothing);
    expect(find.text('Check needed'), findsNothing);
  });

  testWidgets('a failed analysis says so instead of scoring the frame',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ResultScreen(result: AnalysisResult.failure('Decode failed.')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Analysis failed'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
  });
}
