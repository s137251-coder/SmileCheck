import 'dart:async';

import 'package:flutter/material.dart';

import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(_navigateToHome());
  }

  Future<void> _navigateToHome() async {
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3ECF8E),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: const Icon(
                    Icons.sentiment_satisfied_alt_rounded,
                    color: Colors.white,
                    size: 58,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'SmileCheck',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Local smile safety check',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 30),
                const CircularProgressIndicator(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
