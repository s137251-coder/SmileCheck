import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:smilecheck/app.dart';
import 'package:smilecheck/core/locale_controller.dart';
import 'package:smilecheck/l10n/app_localizations.dart';
import 'package:smilecheck/models/analysis_result.dart';
import 'package:smilecheck/models/image_stats.dart';
import 'package:smilecheck/screens/result_screen.dart';
import 'package:smilecheck/services/analysis_service.dart';
import 'package:smilecheck/services/camera_service.dart';

const ImageStats _stats =
    ImageStats(brightness: 0.6, contrast: 0.2, sharpness: 0.1);

/// The full app, with a locale chosen up front so no preferences plugin is
/// touched during the test.
Widget _app({String language = 'en'}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<LocaleController>(
        create: (_) => LocaleController(initial: Locale(language)),
      ),
      ChangeNotifierProvider<CameraService>(create: (_) => CameraService()),
      Provider<AnalysisService>(create: (_) => AnalysisService()),
    ],
    child: const SmileCheckApp(),
  );
}

/// A single screen under the app's localization setup.
Widget _screen(Widget child, {String language = 'en'}) {
  return MaterialApp(
    locale: Locale(language),
    localizationsDelegates: L.localizationsDelegates,
    supportedLocales: L.supportedLocales,
    home: child,
  );
}

void main() {
  testWidgets('splash brands the app and hands over to the camera',
      (tester) async {
    await tester.pumpWidget(_app());

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
    final result = AnalysisResult.fromModel(score: 91.4, stats: _stats);

    await tester.pumpWidget(_screen(ResultScreen(result: result)));
    await tester.pumpAndSettle();

    expect(find.text('Looks clean'), findsOneWidget);
    expect(find.text('91'), findsOneWidget);
    expect(find.text('On-device model verdict'), findsOneWidget);
    expect(find.text('CLEANLINESS'), findsOneWidget);
  });

  testWidgets('demo mode never renders a clean or dirty verdict',
      (tester) async {
    final result = AnalysisResult.demo(
      stats: _stats,
      reason: ResultReason.modelWrongOutputs,
      reasonValue: 1001,
    );

    await tester.pumpWidget(_screen(ResultScreen(result: result)));
    await tester.pumpAndSettle();

    expect(find.text('Demo mode - no trained model'), findsOneWidget);
    expect(find.text('No verdict yet'), findsOneWidget);
    expect(find.text('Looks clean'), findsNothing);
    expect(find.text('Check needed'), findsNothing);
    expect(find.textContaining('1001'), findsOneWidget);
  });

  testWidgets('a failed analysis says so instead of scoring the frame',
      (tester) async {
    await tester.pumpWidget(
      _screen(
        ResultScreen(
          result: AnalysisResult.failure(
            ResultReason.decodeFailed,
            detail: 'boom',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Analysis failed'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
  });

  group('localization', () {
    testWidgets('renders the result in Hebrew, right to left', (tester) async {
      final result = AnalysisResult.fromModel(score: 91.4, stats: _stats);

      await tester.pumpWidget(_screen(
        ResultScreen(result: result),
        language: 'he',
      ));
      await tester.pumpAndSettle();

      expect(find.text('נראה נקי'), findsOneWidget);
      expect(find.text('ניקיון'), findsOneWidget);
      expect(find.text('Looks clean'), findsNothing);

      expect(Directionality.of(tester.element(find.text('נראה נקי'))),
          TextDirection.rtl);
    });

    testWidgets('substitutes parameters into the Hebrew reason text',
        (tester) async {
      final result = AnalysisResult.demo(
        stats: _stats,
        reason: ResultReason.modelWrongOutputs,
        reasonValue: 1001,
      );

      await tester.pumpWidget(_screen(
        ResultScreen(result: result),
        language: 'he',
      ));
      await tester.pumpAndSettle();

      expect(find.text('אין עדיין פסק דין'), findsOneWidget);
      expect(find.textContaining('1001'), findsOneWidget);
    });

    testWidgets('English stays left to right', (tester) async {
      final result = AnalysisResult.fromModel(score: 91.4, stats: _stats);

      await tester.pumpWidget(_screen(ResultScreen(result: result)));
      await tester.pumpAndSettle();

      expect(Directionality.of(tester.element(find.text('Looks clean'))),
          TextDirection.ltr);
    });

    testWidgets('the picker switches the whole app to Hebrew', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Preparing camera...'), findsOneWidget);

      // pumpAndSettle would hang here: the camera fallback shows an
      // indeterminate progress indicator, which never stops animating.
      // The button is labelled with the active language tag.
      await tester.tap(find.text('EN'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('עברית'), findsOneWidget);
      await tester.tap(find.text('עברית'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('מכינים את המצלמה...'), findsOneWidget);
      expect(find.text('HE'), findsOneWidget);
      expect(find.text('Preparing camera...'), findsNothing);
    });

    testWidgets('every supported locale resolves the same keys',
        (tester) async {
      for (final locale in LocaleController.supported) {
        await tester.pumpWidget(_screen(
          Builder(
            builder: (context) {
              final l = L.of(context);
              return Text('${l.checkAgain}|${l.headlineLooksClean}');
            },
          ),
          language: locale.languageCode,
        ));
        await tester.pumpAndSettle();

        final text = tester.widget<Text>(find.byType(Text)).data!;
        expect(text.split('|').where((part) => part.isEmpty), isEmpty,
            reason: 'missing translation for ${locale.languageCode}');
      }
    });
  });
}
