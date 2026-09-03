import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/app_theme.dart';
import 'core/locale_controller.dart';
import 'l10n/app_localizations.dart';
import 'screens/splash_screen.dart';

class SmileCheckApp extends StatelessWidget {
  const SmileCheckApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Watching the controller here is what flips the whole tree, including
    // text direction: Hebrew is RTL and Flutter derives that from the locale.
    final locale = context.watch<LocaleController>().locale;

    return MaterialApp(
      title: 'SmileCheck',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      locale: locale,
      localizationsDelegates: L.localizationsDelegates,
      supportedLocales: L.supportedLocales,
      home: const SplashScreen(),
    );
  }
}
