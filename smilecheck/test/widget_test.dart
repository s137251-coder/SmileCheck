import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:smilecheck/app.dart';
import 'package:smilecheck/screens/processing_screen.dart';
import 'package:smilecheck/services/analysis_service.dart';
import 'package:smilecheck/services/camera_service.dart';

void main() {
  testWidgets('SmileCheck app launches', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<CameraService>(create: (_) => CameraService()),
          Provider<AnalysisService>(create: (_) => AnalysisService()),
        ],
        child: const SmileCheckApp(),
      ),
    );

    expect(find.text('SmileCheck'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1400));
    await tester.pump();

    expect(find.text('Start smile check'), findsOneWidget);
  });

  testWidgets('Processing screen completes the analysis flow', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<CameraService>(create: (_) => CameraService()),
          Provider<AnalysisService>(create: (_) => AnalysisService()),
        ],
        child: const MaterialApp(home: ProcessingScreen()),
      ),
    );

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();

    expect(find.text('Processing your smile'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pump();

    expect(find.text('Looks clean'), findsOneWidget);
  });
}
