import 'package:flutter/material.dart';

import 'screens/splash_screen.dart';

class SmileCheckApp extends StatelessWidget {
  const SmileCheckApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmileCheck',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3ECF8E),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5FBF8),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F172A),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
